Subspace Storage Factorio Mod
=============================

**Warning:** this is a work in progress alpha and may not work as advertised.

Allows storing items and fluid into a limitless subspace that is shared across servers via Clusterio.
Currently requires Clusterio to work see [the repository and README for Clusterio](https://github.com/clusterio/clusterio) for instructions on setting it up.


Build Instructions
------------------

Install Node.js version 10 or later and run `npm install` then run `node build`.
It will output the built mod into the `dist` folder by default.
See `node build --help` for options.

Testing
------------------

To run the integration test:

```bash
# Basic test using a dummy clusterio_lib mod
npm test

# Test with the latest clusterio_lib from GitHub Actions
GITHUB_TOKEN=your_github_token npm test
```

The integration test will:
1. Download and set up a Factorio headless server
2. Build and install the Subspace Storage mod
3. When provided with a GitHub token, download the latest clusterio_lib from GitHub Actions
4. Run Factorio to verify that the mod loads correctly

Note: To download the clusterio_lib mod from GitHub Actions, you need a GitHub personal access token with the `public_repo` scope. If not provided, the test will fall back to using a dummy clusterio_lib mod.

### CI Configuration

For CI environments, you should store the GitHub token as a secret:

1. Go to your repository Settings → Secrets and variables → Actions
2. Add a new repository secret named `GH_PAT` with your GitHub personal access token
3. The CI workflow is already configured to use this secret when running tests
