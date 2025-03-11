#!/usr/bin/env node
"use strict";

const fs = require('fs-extra');
const path = require('path');
const https = require('https');
const { createWriteStream } = require('fs');
const { spawn } = require('child_process');
const tar = require('tar');

// Factorio version to test with
const factorioVersion = process.env.FACTORIO_VERSION || '2.0.39';
const modVersion = process.env.MOD_VERSION;

const downloadFactorio = async () => {
    const baseDir = path.join(__dirname, `factorio_${factorioVersion}`);
    const tarballPath = path.join(__dirname, `factorio_${factorioVersion}.tar.xz`);
    const downloadUrl = `https://factorio.com/get-download/${factorioVersion}/headless/linux64`;
    
    console.log(`Downloading Factorio ${factorioVersion} from ${downloadUrl}`);
    
    // The factorio executable will be in baseDir/factorio/bin/...
    const factorioDir = path.join(baseDir, 'factorio');
    
    if (await fs.pathExists(factorioDir)) {
        console.log('Factorio directory already exists, skipping download');
        return factorioDir;
    }
    
    await fs.ensureDir(baseDir);
    
    // Download the tarball
    await new Promise((resolve, reject) => {
        const file = createWriteStream(tarballPath);
        https.get(downloadUrl, (response) => {
            if (response.statusCode === 302 || response.statusCode === 301) {
                // Follow redirect
                https.get(response.headers.location, (redirectResponse) => {
                    redirectResponse.pipe(file);
                    file.on('finish', () => {
                        file.close();
                        resolve();
                    });
                }).on('error', reject);
            } else {
                response.pipe(file);
                file.on('finish', () => {
                    file.close();
                    resolve();
                });
            }
        }).on('error', reject);
    });
    
    console.log('Download complete, extracting...');
    
    // Extract to the base directory - the archive already contains a 'factorio' folder
    await new Promise((resolve, reject) => {
        const extract = spawn('tar', ['xf', tarballPath, '-C', baseDir]);
        
        extract.stdout?.on('data', (data) => {
            console.log(`stdout: ${data}`);
        });
        
        extract.stderr?.on('data', (data) => {
            console.error(`stderr: ${data}`);
        });
        
        extract.on('close', (code) => {
            if (code === 0) {
                resolve();
            } else {
                reject(new Error(`tar extraction failed with code ${code}`));
            }
        });
    });
    
    // Clean up the tarball
    await fs.unlink(tarballPath);
    
    console.log('Extraction complete');
    return factorioDir;
};

const findModFile = async () => {
    const distDir = path.join(__dirname, '..', 'dist');
    const files = await fs.readdir(distDir);
    
    let modFile;
    if (modVersion) {
        // Look for a specific version if specified
        modFile = files.find(file => file === `subspace_storage_${modVersion}.zip`);
    } else {
        // Get info.json to find all versions
        const infoJson = JSON.parse(await fs.readFile(path.join(__dirname, '..', 'src', 'info.json')));
        
        // Find the variant that corresponds to our factorio version
        const variant = infoJson.variants.find(v => v.factorio_version === factorioVersion.split('.').slice(0, 2).join('.'));
        
        if (!variant) {
            throw new Error(`No mod variant found for Factorio ${factorioVersion}`);
        }
        
        modFile = files.find(file => file === `subspace_storage_${variant.version}.zip`);
    }
    
    if (!modFile) {
        throw new Error('Could not find mod file in dist directory');
    }
    
    return path.join(distDir, modFile);
};

const setupModDirectory = async (factorioDir) => {
    const modDir = path.join(factorioDir, 'mods');
    await fs.ensureDir(modDir);
    
    // Find the mod file
    const modFile = await findModFile();
    console.log(`Using mod file: ${modFile}`);
    
    // Copy the mod file to the mods directory
    await fs.copy(modFile, path.join(modDir, path.basename(modFile)));
    
    // For dependency testing, we need to provide clusterio_lib
    // This is a simplified test so we'll create a dummy mod
    const clusterioLibDir = path.join(modDir, 'clusterio_lib');
    await fs.ensureDir(clusterioLibDir);
    
    // Create a minimal info.json for the dummy mod
    await fs.writeFile(path.join(clusterioLibDir, 'info.json'), JSON.stringify({
        name: "clusterio_lib",
        version: "1.0.0",
        title: "Clusterio Library",
        author: "Clusterio Team",
        factorio_version: factorioVersion.split('.').slice(0, 2).join('.'),
        dependencies: ["base >= 0.17.0"]
    }, null, 4));
    
    console.log(`Mods directory set up at: ${modDir}`);
    return modDir;
};

const runFactorio = async (factorioDir) => {
    console.log('Starting Factorio to test mod loading...');
    
    // Get the actual executable path - factorioDir is already the 'factorio' subdirectory
    const factorioBin = path.join(factorioDir, 'bin', 'x64', 'factorio');
    console.log(`Factorio executable path: ${factorioBin}`);
    
    return new Promise((resolve, reject) => {
        const factorio = spawn(factorioBin, [
            '--create', './test-map',
            '--mod-directory', path.join(factorioDir, 'mods'),
            '--benchmark', '1',  // Run for a short time then exit
            '--benchmark-ticks', '1',
            '--no-log-rotation'
        ]);
        
        let output = '';
        let errorOutput = '';
        
        factorio.stdout.on('data', (data) => {
            const text = data.toString();
            output += text;
            process.stdout.write(text);
        });
        
        factorio.stderr.on('data', (data) => {
            const text = data.toString();
            errorOutput += text;
            process.stderr.write(text);
        });
        
        factorio.on('close', (code) => {
            if (code !== 0) {
                reject(new Error(`Factorio exited with code ${code}: ${errorOutput}`));
                return;
            }
            
            // Check for critical errors in the output
            if (output.includes('Error') || output.includes('EXCEPTION')) {
                if (
                    output.includes('Error while loading mods') ||
                    output.includes('subspace_storage')
                ) {
                    reject(new Error(`Mod loading failed: ${output}`));
                    return;
                }
            }
            
            resolve();
        });
    });
};

const main = async () => {
    try {
        const factorioDir = await downloadFactorio();
        await setupModDirectory(factorioDir);
        await runFactorio(factorioDir);
        console.log('Integration test passed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('Integration test failed:', error);
        process.exit(1);
    }
};

main();
