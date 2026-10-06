#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== Lab 09: Teardown ==="
podman ps -aq --filter "name=^lab09-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab09-underlay 2>/dev/null || true
[ -f "${LAB_DIR}/.topology-watch.pid" ] && kill "$(cat "${LAB_DIR}/.topology-watch.pid")" 2>/dev/null || true
[ -f "${LAB_DIR}/.packet-watch.pid"   ] && kill "$(cat "${LAB_DIR}/.packet-watch.pid")"   2>/dev/null || true
rm -f "${LAB_DIR}/.topology-watch.pid" "${LAB_DIR}/.packet-watch.pid"
echo "Done."
