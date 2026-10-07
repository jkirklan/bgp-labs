#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 11: Teardown ==="
pkill -f "topology_watch" 2>/dev/null || true
pkill -f "packet_watch" 2>/dev/null || true
podman ps -aq --filter "name=^lab11-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab11-as1-as2-link lab11-b1-b2-link lab11-as2-as3-link lab11-as1-internal lab11-as3-internal 2>/dev/null || true
echo "Done."
