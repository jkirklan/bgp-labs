#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 06: Teardown ==="
podman ps -aq --filter "name=^lab06-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab06-as1-as2-link lab06-as2-as3-link 2>/dev/null || true
echo "Done."
