#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"
TOPO_PORT=8307

echo "=== Lab 07: Communities ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab07-transit-custa --subnet 10.0.10.0/30 2>/dev/null || true
podman network create lab07-transit-custb --subnet 10.0.20.0/30 2>/dev/null || true
podman network create lab07-transit-peer  --subnet 10.0.30.0/30 2>/dev/null || true

echo "Step 2: Starting routers ..."

podman run -d --name lab07-transit \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab07-transit-custa:interface_name=eth0,ip=10.0.10.1 \
    --network lab07-transit-custb:interface_name=eth1,ip=10.0.20.1 \
    --network lab07-transit-peer:interface_name=eth2,ip=10.0.30.1 \
    -v "${LAB_DIR}/configs/transit.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab07-cust-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab07-transit-custa:interface_name=eth0,ip=10.0.10.2 \
    -v "${LAB_DIR}/configs/cust-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab07-cust-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab07-transit-custb:interface_name=eth0,ip=10.0.20.2 \
    -v "${LAB_DIR}/configs/cust-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab07-peer \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab07-transit-peer:interface_name=eth0,ip=10.0.30.2 \
    -v "${LAB_DIR}/configs/peer.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

cd "${REPO_ROOT}"
python3 -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

python3 -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"

echo "Lab 07 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "All sessions start Established — configure community policy on transit."
