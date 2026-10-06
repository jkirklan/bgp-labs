#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"

if ! podman image exists frr:latest; then
  echo "ERROR: frr:latest not found. Run Lab 00 first." >&2
  exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

podman network create --subnet 10.0.12.0/30 lab03-as1-as2-link
podman network create --subnet 192.168.1.0/24 lab03-as1-internal
podman network create --subnet 192.168.2.0/24 lab03-as2-internal

podman run -d --name lab03-router-a \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --network lab03-as1-as2-link:ip=10.0.12.1 \
  --network lab03-as1-internal:ip=192.168.1.1 \
  -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:Z" \
  frr:latest

podman run -d --name lab03-router-b \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --network lab03-as1-as2-link:ip=10.0.12.2 \
  --network lab03-as2-internal:ip=192.168.2.1 \
  -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:Z" \
  frr:latest

sleep 3

TOPO_PORT=8303
. "${REPO_ROOT}/scripts/start-watchers.sh"

echo "Lab 03 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "Watch packet-watch for BGP OPEN messages once lab03-router-b is configured."
