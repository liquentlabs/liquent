# Rolling Upgrade Test

## Usage

### 1. Configure test parameters

```bash
cp test_params.toml.example test_params.toml
```

Edit `test_params.toml`:

```toml
[source]
bin_path = "../target/quick-release/v1.0.0/liquent_node"
# or: github = "liquentlabs/liquent"
# or: rev = "v1.0.0"
# or: project_path = "../"

[genesis_contracts]
repo = "https://github.com/liquentlabs/liquent_chain_core_contracts.git"
ref = "liquent-testnet-v1.0.0"

[hardforks]
alphaTime = 0
betaTime = 0
gammaTime = 1893456000
```

### 2. Render config files

```bash
python render_config.py
```

This generates `cluster.toml` and `genesis.toml` from templates.

To use a different params file:

```bash
python render_config.py my_scenario.toml
```

### 3. Run the test

```bash
# From project root
python liquent_e2e/runner.py rolling_upgrade
```

The upgrade target binary defaults to `target/quick-release/liquent_node`. Override via:

```bash
export LIQUENT_NEW_BINARY=/path/to/new/liquent_node
python liquent_e2e/runner.py rolling_upgrade
```
