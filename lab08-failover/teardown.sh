#!/usr/bin/env bash
set -euo pipefail
echo "=== Lab 08: Teardown ==="
podman ps -aq --filter "name=^lab08-" | xargs -r podman rm -f 2>/dev/null || true
podman network rm lab08-primary-link lab08-backup-link 2>/dev/null || true
echo "Done."
