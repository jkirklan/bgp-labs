#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for pidfile in "${LAB_DIR}/.topology-watch.pid" "${LAB_DIR}/.packet-watch.pid"; do
  [[ -f "${pidfile}" ]] && { kill "$(cat "${pidfile}")" 2>/dev/null || true; rm -f "${pidfile}"; }
done

podman ps -aq --filter "name=^lab03-" | xargs -r podman rm -f 2>/dev/null || true

for net in lab03-as1-as2-link lab03-as1-internal lab03-as2-internal; do
  podman network rm --force "${net}" 2>/dev/null || true
done

echo "Lab 03 torn down."
