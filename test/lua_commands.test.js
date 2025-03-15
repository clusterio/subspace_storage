#!/usr/bin/env node
"use strict";

const fs = require('fs-extra');
const path = require('path');
const { spawn } = require('child_process');
const net = require('net');
const crypto = require('crypto');
const Rcon = require('rcon-client').Rcon;
const { downloadFactorio } = require('./downloadFactorio');
const { setupModDirectory } = require('./setupModDirectory');

/*
Required environment variables:
- FACTORIO_VERSION: The version of Factorio to test with (optional, defaults to 1.1.110)
- MOD_VERSION: The version of the mod to test with (optional)
- GITHUB_TOKEN: The GitHub token to use for downloading clusterio_lib from GitHub Actions
*/

const FACTORIO_VERSION = process.env.FACTORIO_VERSION || "1.1.110";

// Create a temporary directory for test scripts
const createTestScripts = async (tempDir) => {
	const tests = {
		test_inventory_combinator: [`
			local surface = game.get_surface(1)
			local position = {x = 0, y = 0}
			local combinator = surface.create_entity{
				name = "subspace-resource-combinator",
				position = position,
				force = game.forces.player,
				raise_built = true
			}
			
			if not combinator then
				rcon.print("ERROR: Failed to create inventory combinator")
				return
			else
				global._test_combinator = combinator
			end`,
			`--[[ Set a simulated inventory ]]
			local itemsJson = '[["iron-plate",100,"normal"],["copper-plate",50,"normal"]]'
			UpdateInvData(itemsJson, true)
			`,
			`--[[ Verify the combinator state ]]
			local combinator = global._test_combinator
			local control = combinator.get_control_behavior()

			local success = true
			local function verify_signal(index, item_name, expected_count)
				if ${FACTORIO_VERSION.split(".")[0]} < 2 then
					local param = control.get_signal(index)
					if not param or param.signal.name ~= item_name or param.count ~= expected_count then
						rcon.print(string.format(
							"ERROR: Signal mismatch at index %d - Expected %s: %d, Got: %s: %d",
							index,
							item_name,
							expected_count,
							param and param.signal.name or "nil",
							param and param.count or 0
						))
						success = false
					end
				else
					local section = control.get_section(1)
					if not section or section.filters[index].value.name ~= item_name or section.filters[index].min ~= expected_count then
						rcon.print(string.format(
							"ERROR: Signal mismatch at index %d - Expected %s: %d, Got: %s: %d",
							index,
							item_name,
							expected_count,
							section and section.filters[index].value.name or "nil",
							section and section.filters[index].min or 0
						))
						success = false
					end
				end
			end
			
			verify_signal(1, "iron-plate", 100)
			verify_signal(2, "copper-plate", 50)
			
			if success then
				rcon.print("SUCCESS: Inventory combinator test passed")
			end
		`],
	};

	return tests;
};

// Function to create a save file
const createSaveFile = async (factorioDir) => {
	console.log('Creating initial save file...');

	const factorioBin = path.join(factorioDir, 'bin', 'x64', 'factorio');
	const savePath = path.join(factorioDir, 'test-save.zip');

	return new Promise((resolve, reject) => {
		const createSave = spawn(factorioBin, [
			'--create', savePath,
			'--mod-directory', path.join(factorioDir, 'mods'),
			'--map-gen-seed', '12345' // Fixed seed for deterministic tests
		]);

		createSave.on('close', (code) => {
			if (code !== 0) {
				reject(new Error(`Failed to create save file, exit code: ${code}`));
				return;
			}

			console.log('Save file created successfully');
			resolve(savePath);
		});
	});
};

// Function to start Factorio server with RCON enabled
const startFactorioServer = async (factorioDir, savePath) => {
	console.log('Starting Factorio server with RCON...');

	const factorioBin = path.join(factorioDir, 'bin', 'x64', 'factorio');
	const rconPassword = crypto.randomBytes(16).toString('hex');
	const rconPort = 27015;

	const factorio = spawn(factorioBin, [
		'--start-server', savePath,
		'--mod-directory', path.join(factorioDir, 'mods'),
		'--rcon-port', rconPort.toString(),
		'--rcon-password', rconPassword
	]);

	let output = '';
	let serverStarted = false;

	factorio.stdout.on('data', (data) => {
		const text = data.toString();
		output += text;
		process.stdout.write(text);

		if (text.includes('Starting RCON interface')) {
			serverStarted = true;
		}
	});

	factorio.stderr.on('data', (data) => {
		const text = data.toString();
		process.stderr.write(text);
	});

	// Wait for server to start
	return new Promise((resolve, reject) => {
		const checkStarted = () => {
			if (serverStarted) {
				resolve({
					process: factorio,
					rconPort,
					rconPassword,
					output: () => output
				});
			} else if (factorio.exitCode !== null) {
				reject(new Error(`Factorio server exited with code ${factorio.exitCode}`));
			} else {
				setTimeout(checkStarted, 100);
			}
		};

		checkStarted();
	});
};

// Function to run tests using RCON
const runTestsWithRcon = async (server, tests) => {
	console.log('Connecting to RCON...');

	const rcon = await Rcon.connect({
		host: 'localhost',
		port: server.rconPort,
		password: server.rconPassword,
		timeout: 5000
	});

	try {
		console.log('RCON authenticated, running tests...');

		const results = {
			success: 0,
			error: 0,
			details: []
		};

		// Run 2 commands to prime rcon
		await rcon.send('/c game.print("Hello, world!")');
		await rcon.send('/c game.print("Hello, world!")');

		// Run each test
		for (const [testName, testScripts] of Object.entries(tests)) {
			console.log(`Running test: ${testName}`);

			let combinedResponse = '';
			let hasError = false;
			let hasExecutionError = false;

			// Run each script in sequence with delay
			for (const script of testScripts) {
				// Send the Lua command via RCON
				const response = await rcon.send(`/c __subspace_storage__ ${script.replace(/\n/g, ' ')}`);
				combinedResponse += response + '\n';

				// Check for execution errors after each script
				const serverOutput = server.output();
				if (serverOutput.includes('Cannot execute command')) {
					hasExecutionError = true;
					break;
				}

				// Wait ~1 second between scripts
				await new Promise(resolve => setTimeout(resolve, 1000));
			}

			// Parse final results
			const successCount = (combinedResponse.match(/SUCCESS:/g) || []).length;
			const errorCount = hasExecutionError ? 1 : (combinedResponse.match(/ERROR:/g) || []).length;

			console.log(`Test results for ${testName}:`);
			console.log(`- Successes: ${successCount}`);
			console.log(`- Errors: ${errorCount}`);

			results.success += successCount;
			results.error += errorCount;

			results.details.push({
				name: testName,
				success: successCount,
				error: errorCount,
				output: combinedResponse
			});

			if (errorCount > 0 || hasExecutionError) {
				console.error(`❌ Test failed: ${testName}`);
				console.error(combinedResponse);
				if (hasExecutionError) {
					console.error('Server reported command execution error');
					console.error(server.output());
				}
			} else {
				console.log(`✅ Test passed: ${testName}`);
			}
		}

		return results;
	} finally {
		await rcon.end();
	}
};

const main = async () => {
	try {
		const factorioDir = await downloadFactorio();
		await setupModDirectory(factorioDir);

		// Always create a fresh save file
		const savePath = path.join(factorioDir, 'test-save.zip');
		await createSaveFile(factorioDir);

		// Create test scripts
		const tests = await createTestScripts(factorioDir);

		// Start Factorio server with RCON
		const server = await startFactorioServer(factorioDir, savePath);

		try {
			// Run tests
			const results = await runTestsWithRcon(server, tests);

			// Output summary
			console.log('\nTest Summary:');
			console.log(`- Total tests: ${Object.keys(tests).length}`);
			console.log(`- Total successes: ${results.success}`);
			console.log(`- Total errors: ${results.error}`);

			if (results.error > 0) {
				console.error('\nSome tests failed. Check the output above for details.');
				process.exit(1);
			} else {
				console.log('\nAll Lua command tests passed successfully!');
				process.exit(0);
			}
		} finally {
			// Kill the Factorio server
			server.process.kill();
			// Clean up the save file
			try {
				await fs.remove(savePath);
				console.log('Test save file cleaned up');
			} catch (err) {
				console.warn('Failed to clean up test save file:', err);
			}
		}
	} catch (error) {
		console.error('Integration test failed:', error);
		process.exit(1);
	}
};

main();
