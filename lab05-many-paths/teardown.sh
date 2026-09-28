#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 05: Teardown ==="
podman ps -aq --filter "name=^lab05-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab05-as1-as2-link lab05-as1-as3-link lab05-as2-as4-link lab05-as3-as4-link lab05-as1-internal 2>/dev/null || true
echo "Done."
