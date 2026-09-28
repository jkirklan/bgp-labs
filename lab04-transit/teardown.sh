#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 04: Teardown ==="
podman ps -aq --filter "name=^lab04-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab04-as1-as2-link lab04-as2-as3-link lab04-as1-internal lab04-as3-internal 2>/dev/null || true
echo "Done."
