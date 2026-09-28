#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"

echo "=== Lab 00: Build Your Router ==="
echo ""
echo "Step 1: Building frr:latest from containerfiles/frr/ ..."
cd "${REPO_ROOT}"
podman build --platform linux/amd64 -t frr:latest containerfiles/frr/
echo "frr:latest built successfully."
echo ""
echo "Step 2: Pulling debug container ..."
podman pull ghcr.io/container-images/debugging-tools
echo ""
echo "Done. Verify the build:"
echo "  podman run --rm frr:latest vtysh --version"
echo "  podman run --rm -it ghcr.io/container-images/debugging-tools bash"
