#!/bin/bash
set -e

# ============================================================
# Liquent E2E Docker Builder
#
# Usage:
#   ./liquent_e2e/build_docker.sh
#
# Description:
#   Launches a Docker container to build liquent_node and liquent_cli.
#   Artifacts are stored in target/ (mounted from host).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Image used in scripts/e2e_test.sh
DOCKER_IMAGE="rust:1.88.0-bookworm"

echo "===== Building Liquent Binaries in Docker ====="
echo "Repo Root: $REPO_ROOT"
echo "Image: $DOCKER_IMAGE"
echo "==============================================="

docker run --rm -i \
    -v "$REPO_ROOT:/app" \
    -w /app \
    -e RUST_BACKTRACE=1 \
    "$DOCKER_IMAGE" \
    bash -c '
set -e

echo "[Setup] Installing system dependencies..."
apt-get update >/dev/null 2>&1
apt-get install -y --no-install-recommends \
    clang llvm build-essential pkg-config libssl-dev libudev-dev procps git jq curl \
    python3 python3-pip python3-venv >/dev/null 2>&1

echo "[Build] Starting build process..."
export RUSTFLAGS="--cfg tokio_unstable"
echo "Building liquent_node..."
cargo build --bin liquent_node --profile quick-release

echo "Building liquent_cli..."
cargo build --bin liquent_cli --profile quick-release

echo "Build complete!"
'
