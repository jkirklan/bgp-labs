#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for pidfile in "${LAB_DIR}/.topology-watch.pid" "${LAB_DIR}/.packet-watch.pid"; do
  [[ -f "${pidfile}" ]] && { kill "$(cat "${pidfile}")" 2>/dev/null || true; rm -f "${pidfile}"; }
done

podman ps -aq --filter "name=^lab01-" | xargs -r podman rm -f 2>/dev/null || true

for net in lab01-net-a lab01-net-b; do
  podman network rm --force "${net}" 2>/dev/null || true
done

echo "Lab 01 torn down."
