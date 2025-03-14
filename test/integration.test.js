#!/usr/bin/env node
"use strict";

const fs = require('fs-extra');
const path = require('path');
const { spawn } = require('child_process');
const { downloadFactorio } = require('./downloadFactorio');
const { setupModDirectory } = require('./setupModDirectory');

/*
Required environment variables:
- FACTORIO_VERSION: The version of Factorio to test with (optional, defaults to 1.1.110)
- MOD_VERSION: The version of the mod to test with (optional)
- GITHUB_TOKEN: The GitHub token to use for downloading clusterio_lib from GitHub Actions
*/

const runFactorio = async (factorioDir) => {
	console.log('Starting Factorio to test mod loading...');

	// Get the actual executable path - factorioDir is already the 'factorio' subdirectory
	const factorioBin = path.join(factorioDir, 'bin', 'x64', 'factorio');
	console.log(`Factorio executable path: ${factorioBin}`);

	// Mods:
	console.log("Mods:", await fs.readdir(path.join(factorioDir, 'mods')));

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
