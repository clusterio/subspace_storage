# Integration Tests for Subspace Storage

This directory contains integration tests for the Subspace Storage mod.

## How it works

The integration tests:

1. Download a headless version of Factorio based on the version specified
2. Find the appropriate mod zip file in the `dist/` directory for the Factorio version
3. Create a dummy `clusterio_lib` mod to satisfy dependencies
4. Start Factorio with the mod and check if it loads without crashing

## Running tests locally

First, build the mod:

```bash
npm run build
```

Then run the integration tests:

```bash
npm test
```

You can specify a specific Factorio version to test with:

```bash
FACTORIO_VERSION=2.0.39 npm test
```

You can also specify a specific mod version to test with:

```bash
MOD_VERSION=2.1.20 npm test
```

## Test Matrix in CI

In the GitHub Actions workflow, we run a test matrix with the following Factorio versions:

- 0.17.79
- 1.0.0
- 1.1.110
- 2.0.39

These match the respective Factorio versions that the mod supports (0.17, 1.0, 1.1, 2.0).
