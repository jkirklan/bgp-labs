#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 16: Teardown ==="
pkill -f "topology_watch" 2>/dev/null || true
pkill -f "packet_watch" 2>/dev/null || true
podman ps -aq --filter "name=^lab16-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab16-a-b-link lab16-b-c-link 2>/dev/null || true
echo "Done."
