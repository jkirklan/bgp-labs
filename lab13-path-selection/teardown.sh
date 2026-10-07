#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 13: Teardown ==="
pkill -f "topology_watch" 2>/dev/null || true
pkill -f "packet_watch" 2>/dev/null || true
podman ps -aq --filter "name=^lab13-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab13-a-b-link lab13-a-c-link lab13-b-d-link lab13-c-d-link lab13-as4-internal 2>/dev/null || true
echo "Done."
