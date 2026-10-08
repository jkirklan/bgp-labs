#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== Lab 14: Teardown ==="
podman ps -aq --filter "name=^lab14-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab14-underlay lab14-ce-a1-link lab14-ce-a2-link \
    lab14-ce-b1-link lab14-ce-b2-link 2>/dev/null || true
[ -f "${LAB_DIR}/.topology-watch.pid" ] && kill "$(cat "${LAB_DIR}/.topology-watch.pid")" 2>/dev/null || true
[ -f "${LAB_DIR}/.packet-watch.pid"   ] && kill "$(cat "${LAB_DIR}/.packet-watch.pid")"   2>/dev/null || true
rm -f "${LAB_DIR}/.topology-watch.pid" "${LAB_DIR}/.packet-watch.pid"
echo "Done."
