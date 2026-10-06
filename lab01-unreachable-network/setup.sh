#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
LABS_PARENT="$(cd "${REPO_ROOT}/.." && pwd)"

if ! podman image exists frr:latest; then
  echo "ERROR: frr:latest not found. Build it first:" >&2
  echo "  cd ../lab00-build-your-router && ./setup.sh" >&2
  exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

podman network create --subnet 10.1.0.0/24 --internal lab01-net-a
podman network create --subnet 10.2.0.0/24 --internal lab01-net-b

podman run -d --name lab01-host-a \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --network lab01-net-a:ip=10.1.0.10 \
  -v "${LAB_DIR}/configs/host-a.conf:/etc/frr/frr.conf:Z" \
  frr:latest

podman run -d --name lab01-host-b \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --network lab01-net-b:ip=10.2.0.10 \
  -v "${LAB_DIR}/configs/host-b.conf:/etc/frr/frr.conf:Z" \
  frr:latest

podman run -d --name lab01-router-a \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --network lab01-net-a:ip=10.1.0.254 \
  --network lab01-net-b:ip=10.2.0.254 \
  -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:Z" \
  frr:latest

sleep 3

echo "Lab 01 is up."
echo "Note: topology-watch is not started for this lab — no BGP sessions to visualize."
