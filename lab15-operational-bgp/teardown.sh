#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 15: Teardown ==="
pkill -f "topology_watch" 2>/dev/null || true
pkill -f "packet_watch" 2>/dev/null || true
podman ps -aq --filter "name=^lab15-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab15-a-b-link lab15-a-c-link 2>/dev/null || true
echo "Done."
