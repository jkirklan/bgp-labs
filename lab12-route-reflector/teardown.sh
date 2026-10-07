#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 12: Teardown ==="
pkill -f "topology_watch" 2>/dev/null || true
pkill -f "packet_watch" 2>/dev/null || true
podman ps -aq --filter "name=^lab12-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab12-as1-as2-link lab12-as2-core lab12-as2-as3-link lab12-as1-internal lab12-as3-internal 2>/dev/null || true
echo "Done."
