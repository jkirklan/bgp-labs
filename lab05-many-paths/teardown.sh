#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 05: Teardown ==="
pkill -f "topology_watch" 2>/dev/null || true
pkill -f "packet_watch" 2>/dev/null || true
podman ps -aq --filter "name=^lab05-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab05-as1-as2-link lab05-as1-as3-link lab05-as2-as4-link lab05-as3-as4-link 2>/dev/null || true
echo "Done."
