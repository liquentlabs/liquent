#!/bin/bash
set -euo pipefail

# ============================================================
# Liquent E2E Docker Runner (CI/CD)
#
# Usage:
#   ./liquent_e2e/run_docker.sh [options] [suite1] [suite2] ... [--exclude suite] [pytest_args]
#
# Options:
#   --build-only   Build liquent_node + liquent_cli into host
#                  target/quick-release/ and exit (no tests).
#   --skip-build   Do not cargo-build; require prebuilt binaries at
#                  host target/quick-release/{liquent_node,liquent_cli}.
#
# Examples:
#   ./liquent_e2e/run_docker.sh                    # Build + all suites
#   ./liquent_e2e/run_docker.sh --build-only       # Build once for CI
#   ./liquent_e2e/run_docker.sh --skip-build single_node
#   ./liquent_e2e/run_docker.sh single_node -k test_transfer
#
# Description:
#   Source is piped into Docker via tar (no full host mount — avoids
#   permission issues). Prebuilt binaries use a bind mount of
#   target/quick-release only.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOCKER_IMAGE="rust:1.88.0-bookworm"
BUILD_ONLY=0
SKIP_BUILD=0
ARGS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-only)
            BUILD_ONLY=1
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --)
            shift
            ARGS+=("$@")
            break
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "${BUILD_ONLY}" -eq 1 ] && [ "${SKIP_BUILD}" -eq 1 ]; then
    echo "error: --build-only and --skip-build are mutually exclusive" >&2
    exit 2
fi

if [ "${BUILD_ONLY}" -eq 1 ] && [ "${#ARGS[@]}" -gt 0 ]; then
    echo "error: --build-only does not accept suite / pytest args: ${ARGS[*]}" >&2
    exit 2
fi

echo "===== Liquent E2E Docker Runner ====="
echo "Repo Root: $REPO_ROOT"
echo "Image: $DOCKER_IMAGE"
echo "Build only: ${BUILD_ONLY}"
echo "Skip build: ${SKIP_BUILD}"
echo "Args: ${ARGS[*]:-<all suites>}"
echo "======================================"

PREBUILT_DIR="${REPO_ROOT}/target/quick-release"
mkdir -p "${PREBUILT_DIR}"

if [ "${SKIP_BUILD}" -eq 1 ]; then
    for bin in liquent_node liquent_cli; do
        if [ ! -x "${PREBUILT_DIR}/${bin}" ]; then
            echo "error: --skip-build requires executable ${PREBUILT_DIR}/${bin}" >&2
            exit 1
        fi
    done
fi

source_tar() {
    tar -C "$REPO_ROOT" \
        --exclude='target' \
        --exclude='.git' \
        --exclude='external/liquent_bench' \
        --exclude='external/liquent_chain_core_contracts' \
        -cf - .
}

# ---------------------------------------------------------------------------
# --build-only: compile once, write binaries to host target/quick-release
# ---------------------------------------------------------------------------
if [ "${BUILD_ONLY}" -eq 1 ]; then
    echo "===== Build-only → host target/quick-release ====="
    source_tar | docker run --rm -i \
        -e RUST_BACKTRACE=1 \
        -v "${PREBUILT_DIR}:/out" \
        "$DOCKER_IMAGE" \
        bash -c '
set -euo pipefail
mkdir -p /app && cd /app && tar xf -

echo "[Setup] Installing build dependencies..."
apt-get update >/dev/null 2>&1
apt-get install -y --no-install-recommends \
    clang llvm build-essential pkg-config libssl-dev libudev-dev \
    git curl ca-certificates >/dev/null 2>&1

export RUSTFLAGS="--cfg tokio_unstable -C debug-assertions=yes"

echo "[Build] liquent_node (quick-release)..."
cargo build --bin liquent_node --profile quick-release 2>&1 | tail -20

echo "[Build] liquent_cli (quick-release)..."
cargo build --bin liquent_cli --profile quick-release 2>&1 | tail -20

install -m 755 target/quick-release/liquent_node /out/liquent_node
install -m 755 target/quick-release/liquent_cli /out/liquent_cli
ls -la /out/liquent_node /out/liquent_cli
echo "===== Build-only completed ====="
'
    test -x "${PREBUILT_DIR}/liquent_node"
    test -x "${PREBUILT_DIR}/liquent_cli"
    echo "Host artifacts:"
    ls -la "${PREBUILT_DIR}/liquent_node" "${PREBUILT_DIR}/liquent_cli"
    exit 0
fi

# ---------------------------------------------------------------------------
# Test path: optional --skip-build
# ---------------------------------------------------------------------------
# Safely quote runner args for nested bash -c
RUNNER_ARGS=""
if [ "${#ARGS[@]}" -gt 0 ]; then
    printf -v RUNNER_ARGS '%q ' "${ARGS[@]}"
fi

DOCKER_VOL_ARGS=()
PHASE2_SCRIPT=""
if [ "${SKIP_BUILD}" -eq 1 ]; then
    DOCKER_VOL_ARGS+=(-v "${PREBUILT_DIR}:/prebuilt:ro")
    PHASE2_SCRIPT='
echo ""
echo "===== Phase 2: Using prebuilt binaries (no cargo build) ====="
mkdir -p /app/target/quick-release
cp -a /prebuilt/liquent_node /prebuilt/liquent_cli /app/target/quick-release/
chmod +x /app/target/quick-release/liquent_node /app/target/quick-release/liquent_cli
ls -la /app/target/quick-release/liquent_node /app/target/quick-release/liquent_cli
'
else
    PHASE2_SCRIPT='
echo ""
echo "===== Phase 2: Building Binaries ====="
export RUSTFLAGS="--cfg tokio_unstable -C debug-assertions=yes"

echo "[Step 4] Building liquent_node (quick-release)..."
cargo build --bin liquent_node --profile quick-release 2>&1 | tail -5

echo "[Step 5] Building liquent_cli (quick-release)..."
cargo build --bin liquent_cli --profile quick-release 2>&1 | tail -5
'
fi

source_tar | docker run --rm -i \
    -e RUST_BACKTRACE=1 \
    "${DOCKER_VOL_ARGS[@]+"${DOCKER_VOL_ARGS[@]}"}" \
    "$DOCKER_IMAGE" \
    bash -c "
set -euo pipefail
mkdir -p /app && cd /app && tar xf -

echo '===== Phase 1: Environment Setup ====='

echo '[Step 1] Installing system dependencies...'
apt-get update >/dev/null 2>&1
apt-get install -y --no-install-recommends \\
    clang llvm build-essential pkg-config libssl-dev libudev-dev \\
    procps git jq curl python3 python3-pip python3-venv \\
    nodejs npm protobuf-compiler bc gettext-base >/dev/null 2>&1

ln -sf /usr/bin/python3 /usr/bin/python

echo '[Step 2] Installing Foundry...'
curl -L https://foundry.paradigm.xyz 2>/dev/null | bash >/dev/null 2>&1
export PATH=\"\$HOME/.foundry/bin:\$PATH\"
foundryup >/dev/null 2>&1
echo '  Foundry installed: '\$(forge --version | head -1)

echo '[Step 3] Installing Python dependencies...'
pip install -r /app/liquent_e2e/requirements.txt --quiet --break-system-packages

${PHASE2_SCRIPT}

echo ''
echo '===== Phase 2b: E2E Solidity test contracts ====='
if [ -f /app/liquent_e2e/tests/contracts/randomness/foundry.toml ]; then
    (cd /app/liquent_e2e/tests/contracts/randomness && forge build)
fi

echo ''
echo '===== Phase 3: Running E2E Tests ====='
echo '[Step 7] Running runner.py...'
# Fresh container: hardcode PYTHONPATH. Do not expand host/container
# PYTHONPATH inside this double-quoted bash -c (outer set -u would
# treat comment refs as real expansions too).
export PYTHONPATH=/app:/app/liquent_e2e
cd /app/liquent_e2e
python3 runner.py --force-init --exclude long_test ${RUNNER_ARGS}

echo ''
echo '===== E2E Tests Completed Successfully ====='
"
