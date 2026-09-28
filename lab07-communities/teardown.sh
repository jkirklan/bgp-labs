#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 07: Teardown ==="
podman ps -aq --filter "name=^lab07-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab07-transit-custa lab07-transit-custb lab07-transit-peer 2>/dev/null || true
echo "Done."
