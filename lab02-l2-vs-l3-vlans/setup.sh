#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"

if ! podman image exists frr:latest; then
  echo "ERROR: frr:latest not found. Run Lab 00 first." >&2
  exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

podman network create --subnet 192.168.10.0/24 lab02-vlan10
podman network create --subnet 192.168.20.0/24 lab02-vlan20

podman run -d --name lab02-host-a1 \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --network lab02-vlan10:ip=192.168.10.10 \
  -v "${LAB_DIR}/configs/host-a1.conf:/etc/frr/frr.conf:Z" \
  frr:latest

podman run -d --name lab02-host-a2 \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --network lab02-vlan10:ip=192.168.10.11 \
  -v "${LAB_DIR}/configs/host-a2.conf:/etc/frr/frr.conf:Z" \
  frr:latest

podman run -d --name lab02-host-b1 \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --network lab02-vlan20:ip=192.168.20.10 \
  -v "${LAB_DIR}/configs/host-b1.conf:/etc/frr/frr.conf:Z" \
  frr:latest

podman run -d --name lab02-router-a \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --network lab02-vlan10:ip=192.168.10.254 \
  --network lab02-vlan20:ip=192.168.20.254 \
  -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:Z" \
  frr:latest

sleep 3

TOPO_PORT=8302
cd "${REPO_ROOT}"
python -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

python -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"

echo "Lab 02 is up. topology-watch: http://localhost:${TOPO_PORT}"
