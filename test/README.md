# Subspace Storage Integration Tests

This directory contains integration tests for the Subspace Storage mod. These tests verify that the mod loads correctly and that its Lua commands interact with the game as expected.

## Test Files

- `integration.test.js`: Basic test that verifies the mod loads correctly
- `lua_commands_test.js`: Tests that verify the Lua commands interact with the game correctly

## Running the Tests

### Environment Variables

The tests use the following environment variables:

- `FACTORIO_VERSION`: The version of Factorio to test with (optional, defaults to 1.1.110)
- `MOD_VERSION`: The version of the mod to test with (optional)
- `GITHUB_TOKEN`: The GitHub token to use for downloading clusterio_lib from GitHub Actions (required for CI)

### Running the Basic Integration Test

```bash
node integration.test.js
```

This test verifies that the mod loads correctly without any errors.

### Running the Lua Commands Test

```bash
node lua_commands_test.js
```

This test verifies that the Lua commands interact with the game correctly.

## How the Tests Work

The tests work by:

1. Downloading a headless version of Factorio
2. Setting up a mod directory with the Subspace Storage mod and its dependencies
3. Creating a test save file
4. Running Factorio with Lua scripts that test specific functionality
5. Analyzing the output to determine if the tests passed or failed

## Adding New Tests

To add a new test:

1. Create a new Lua script in the `createTestScripts` function in `lua_commands_test.js`
2. The script should use `game.print("SUCCESS: ...")` to indicate success and `game.print("ERROR: ...")` to indicate failure
3. The test runner will count the number of successes and errors to determine if the test passed

## Troubleshooting

If the tests fail, check the output for error messages. Common issues include:

- Missing dependencies
- Incompatible Factorio version
- Errors in the Lua scripts

If you're having trouble with the tests, try running Factorio manually with the mod installed to see if there are any issues.
