"use strict";
const fs = require('fs-extra');
const path = require('path');
const https = require('https');
const { pipeline } = require('stream/promises');

const factorioVersion = process.env.FACTORIO_VERSION || '1.1.110';
const modVersion = process.env.MOD_VERSION;

// Public release assets need no token and keep every test run on the same library version.
const clusterioRelease = 'v2.0.2';
const clusterioLibVersions = {
	'0.17': '2.1.17',
	'1.0': '2.1.18', // Factorio 1.0 loads mods built for 0.18.
	'1.1': '2.1.11',
	'2.0': '2.1.20',
	'2.1': '2.1.21',
};

const downloadFile = async (url, destination, redirects = 5) => {
	const response = await new Promise((resolve, reject) => {
		https.get(url, resolve).on('error', reject);
	});
	if ([301, 302, 303, 307, 308].includes(response.statusCode)) {
		response.resume();
		if (!redirects || !response.headers.location) {
			throw new Error(`Invalid or excessive redirects downloading ${url}`);
		}
		return downloadFile(new URL(response.headers.location, url), destination, redirects - 1);
	}
	if (response.statusCode !== 200) {
		response.resume();
		throw new Error(`Failed to download clusterio_lib: HTTP ${response.statusCode} from ${url}`);
	}
	await pipeline(response, fs.createWriteStream(destination));
};

const setupModDirectory = async (factorioDir) => {
	const factorioSeries = factorioVersion.split('.').slice(0, 2).join('.');
	const libraryVersion = clusterioLibVersions[factorioSeries];
	if (!libraryVersion) {
		throw new Error(`No clusterio_lib release configured for Factorio ${factorioVersion}`);
	}

	const modDir = path.join(factorioDir, 'mods');
	await fs.ensureDir(modDir);
	const modFile = await findModFile();
	console.log(`Using mod file: ${modFile}`);
	await fs.copy(modFile, path.join(modDir, path.basename(modFile)));

	const libraryFile = `clusterio_lib_${libraryVersion}.zip`;
	const url = `https://github.com/clusterio/clusterio/releases/download/${clusterioRelease}/${libraryFile}`;
	const destination = path.join(modDir, libraryFile);
	const temporary = `${destination}.tmp`;
	console.log(`Downloading ${libraryFile} from Clusterio ${clusterioRelease}...`);
	try {
		await downloadFile(url, temporary);
		await fs.move(temporary, destination, { overwrite: true });
	} finally {
		await fs.remove(temporary);
	}
	console.log(`Mods directory set up at: ${modDir}`);
	return modDir;
};
exports.setupModDirectory = setupModDirectory;

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
