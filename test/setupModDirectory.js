"use strict";
const fs = require('fs-extra');
const path = require('path');
const { createWriteStream } = require('fs');
const https = require('https');
const { pipeline } = require('stream/promises');
const { Extract } = require('unzipper');

// Factorio version to test with
const factorioVersion = process.env.FACTORIO_VERSION || '1.1.110';
const modVersion = process.env.MOD_VERSION;
// GitHub token for API access (can be passed as environment variable)
const githubToken = process.env.GITHUB_TOKEN;

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
exports.setupModDirectory = setupModDirectory;const downloadClusterioLib = async (modDir) => {
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
						fs.unlink(artifactZipPath, () => { });
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
		console.log("Mods in artifact:", modFiles);
		const validModFiles = modFiles.filter(file => checkModVersionAgainstFactorioVersion(
			file
				.replace('clusterio_lib_', '')
				.replace('.zip', ''),
			factorioVersion
		));

		if (validModFiles.length === 0) {
			throw new Error('Could not find clusterio_lib mod file in downloaded artifact');
		}

		// Copy the mod file to the mods directory
		for (const modFile of validModFiles) {
			await fs.copy(
				path.join(extractDir, modFile),
				path.join(modDir, modFile)
			);
		}

		// Clean up
		await fs.remove(artifactZipPath);
		await fs.remove(extractDir);

		console.log(`Successfully installed clusterio_lib mod:`, validModFiles);
	} catch (error) {
		throw new Error(`Failed to download clusterio_lib: ${error.message}`);
	}
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
const checkModVersionAgainstFactorioVersion = (modVersion, factorioVersion) => {
	const modVersionParts = modVersion.split('.');
	const factorioVersionParts = factorioVersion.split('.');

	switch (modVersionParts[2]) {
		case '20':
			return factorioVersionParts[0] === '2';
		case '11':
			return factorioVersionParts[0] === '1' && factorioVersionParts[1] === '1';
		case ('10', '18'):
			return factorioVersionParts[0] === '1' && factorioVersionParts[1] === '0';
		case '17':
			return factorioVersionParts[0] === '0' && factorioVersionParts[1] === '17';
		default:
			return false;
	}
};
