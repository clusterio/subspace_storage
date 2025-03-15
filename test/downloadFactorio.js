"use strict";
const { spawn } = require('child_process');
const { createWriteStream } = require('fs');
const fs = require('fs-extra');
const https = require('https');
const path = require('path');

// Factorio version to test with
const factorioVersion = process.env.FACTORIO_VERSION || '1.1.110';

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
exports.downloadFactorio = downloadFactorio;
