#!/usr/bin/env node
"use strict";

const fs = require('fs-extra');
const path = require('path');
const https = require('https');
const { createWriteStream } = require('fs');
const { spawn } = require('child_process');
const tar = require('tar');
const { pipeline } = require('stream/promises');
const { Extract } = require('unzipper');

// Factorio version to test with
const factorioVersion = process.env.FACTORIO_VERSION || '2.0.39';
const modVersion = process.env.MOD_VERSION;
// GitHub token for API access (can be passed as environment variable)
const githubToken = process.env.GITHUB_TOKEN;

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

const downloadClusterioLib = async (modDir) => {
    console.log('Downloading clusterio_lib from GitHub Actions...');
    
    if (!githubToken) {
        throw new Error('GITHUB_TOKEN environment variable is required to download artifacts from GitHub Actions');
    }
    
    // First, get the latest workflow run ID
    const getLatestRunId = async () => {
        return new Promise((resolve, reject) => {
            const options = {
                hostname: 'api.github.com',
                path: '/repos/clusterio/clusterio/actions/runs?status=success&per_page=1',
                method: 'GET',
                headers: {
                    'User-Agent': 'subspace-storage-integration-test',
                    'Authorization': `token ${githubToken}`,
                    'Accept': 'application/vnd.github.v3+json'
                }
            };
            
            const req = https.request(options, (res) => {
                let data = '';
                
                res.on('data', (chunk) => {
                    data += chunk;
                });
                
                res.on('end', () => {
                    if (res.statusCode !== 200) {
                        reject(new Error(`Failed to get latest workflow run: ${res.statusCode}, ${data}`));
                        return;
                    }
                    
                    try {
                        const response = JSON.parse(data);
                        if (!response.workflow_runs || response.workflow_runs.length === 0) {
                            reject(new Error('No workflow runs found'));
                            return;
                        }
                        
                        resolve(response.workflow_runs[0].id);
                    } catch (error) {
                        reject(error);
                    }
                });
            });
            
            req.on('error', reject);
            req.end();
        });
    };
    
    // Get the artifact ID for clusterio_lib
    const getArtifactId = async (runId) => {
        return new Promise((resolve, reject) => {
            const options = {
                hostname: 'api.github.com',
                path: `/repos/clusterio/clusterio/actions/runs/${runId}/artifacts`,
                method: 'GET',
                headers: {
                    'User-Agent': 'subspace-storage-integration-test',
                    'Authorization': `token ${githubToken}`,
                    'Accept': 'application/vnd.github.v3+json'
                }
            };
            
            const req = https.request(options, (res) => {
                let data = '';
                
                res.on('data', (chunk) => {
                    data += chunk;
                });
                
                res.on('end', () => {
                    if (res.statusCode !== 200) {
                        reject(new Error(`Failed to get artifacts: ${res.statusCode}, ${data}`));
                        return;
                    }
                    
                    try {
                        const response = JSON.parse(data);
                        const artifact = response.artifacts.find(a => a.name === 'clusterio_lib');
                        if (!artifact) {
                            reject(new Error('No clusterio_lib artifact found'));
                            return;
                        }
                        
                        resolve(artifact.id);
                    } catch (error) {
                        reject(error);
                    }
                });
            });
            
            req.on('error', reject);
            req.end();
        });
    };
    
    // Download the artifact
    const downloadArtifact = async (artifactId) => {
        const artifactZipPath = path.join(__dirname, 'clusterio_lib_artifact.zip');
        
        return new Promise((resolve, reject) => {
            const options = {
                hostname: 'api.github.com',
                path: `/repos/clusterio/clusterio/actions/artifacts/${artifactId}/zip`,
                method: 'GET',
                headers: {
                    'User-Agent': 'subspace-storage-integration-test',
                    'Authorization': `token ${githubToken}`,
                    'Accept': 'application/vnd.github.v3+json'
                }
            };
            
            const req = https.request(options, (res) => {
                if (res.statusCode === 302) {
                    // Follow redirect
                    const file = createWriteStream(artifactZipPath);
                    https.get(res.headers.location, (redirectRes) => {
                        redirectRes.pipe(file);
                        file.on('finish', () => {
                            file.close();
                            resolve(artifactZipPath);
                        });
                    }).on('error', (err) => {
                        fs.unlink(artifactZipPath, () => {});
                        reject(err);
                    });
                } else {
                    reject(new Error(`Expected redirect, got ${res.statusCode}`));
                }
            });
            
            req.on('error', reject);
            req.end();
        });
    };
    
    try {
        // Step 1: Get the latest workflow run ID
        const runId = await getLatestRunId();
        console.log(`Found latest successful workflow run: ${runId}`);
        
        // Step 2: Get the artifact ID
        const artifactId = await getArtifactId(runId);
        console.log(`Found clusterio_lib artifact: ${artifactId}`);
        
        // Step 3: Download the artifact
        const artifactZipPath = await downloadArtifact(artifactId);
        console.log(`Downloaded artifact to: ${artifactZipPath}`);
        
        // Step 4: Extract the artifact
        const extractDir = path.join(__dirname, 'clusterio_lib_extract');
        await fs.ensureDir(extractDir);
        
        await pipeline(
            fs.createReadStream(artifactZipPath),
            Extract({ path: extractDir })
        );
        
        // Add delay to allow extraction to properly complete before reading the directory
        await new Promise(r => setTimeout(r, 500));

        // Step 5: Extract all files starting with clusterio_lib_ (older versions just won't be loaded by factorio)
        const files = await fs.readdir(extractDir);
        const modFiles = files.filter(file => file.startsWith('clusterio_lib_') && file.endsWith('.zip'));
        
        if (modFiles.length === 0) {
            throw new Error('Could not find clusterio_lib mod file in downloaded artifact');
        }
        
        // Copy the mod file to the mods directory
        for (const modFile of modFiles) {
            await fs.copy(
                path.join(extractDir, modFile), 
                path.join(modDir, modFile)
            );
        }
        
        // Clean up
        await fs.remove(artifactZipPath);
        await fs.remove(extractDir);
        
        console.log(`Successfully installed clusterio_lib mod:`, modFiles);
    } catch (error) {
        throw new Error(`Failed to download clusterio_lib: ${error.message}`);
    }
};

const setupModDirectory = async (factorioDir) => {
    const modDir = path.join(factorioDir, 'mods');
    await fs.ensureDir(modDir);
    
    // Find the mod file
    const modFile = await findModFile();
    console.log(`Using mod file: ${modFile}`);
    
    // Copy the mod file to the mods directory
    await fs.copy(modFile, path.join(modDir, path.basename(modFile)));
    
    // Download and install the real clusterio_lib from GitHub Actions
    if (!githubToken) {
        console.warn('GITHUB_TOKEN not provided, unable to download clusterio_lib from GitHub Actions');
        throw new Error('GITHUB_TOKEN not provided');
    }
    
    await downloadClusterioLib(modDir);
    
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
            
            // Check that the mod was loaded correctly
            if (!output.includes('Loading mod subspace_storage')) {
                reject(new Error('Could not find "Loading mod subspace_storage" in the output. The mod may not have been loaded correctly.'));
                return;
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
