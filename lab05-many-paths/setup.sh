#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"
TOPO_PORT=8305

echo "=== Lab 05: Many Paths ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab05-as1-as2-link --subnet 10.0.12.0/30 2>/dev/null || true
podman network create lab05-as1-as3-link --subnet 10.0.13.0/30 2>/dev/null || true
podman network create lab05-as2-as4-link --subnet 10.0.24.0/30 2>/dev/null || true
podman network create lab05-as3-as4-link --subnet 10.0.34.0/30 2>/dev/null || true

echo "Step 2: Starting routers ..."

podman run -d --name lab05-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab05-as1-as2-link:interface_name=eth0,ip=10.0.12.1 \
    --network lab05-as1-as3-link:interface_name=eth1,ip=10.0.13.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab05-router-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab05-as1-as2-link:interface_name=eth0,ip=10.0.12.2 \
    --network lab05-as2-as4-link:interface_name=eth1,ip=10.0.24.1 \
    -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab05-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab05-as1-as3-link:interface_name=eth0,ip=10.0.13.2 \
    --network lab05-as3-as4-link:interface_name=eth1,ip=10.0.34.1 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab05-router-d \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab05-as2-as4-link:interface_name=eth0,ip=10.0.24.2 \
    --network lab05-as3-as4-link:interface_name=eth1,ip=10.0.34.2 \
    -v "${LAB_DIR}/configs/router-d.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

cd "${REPO_ROOT}"
${REPO_ROOT}/.venv/bin/python3 -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

${REPO_ROOT}/.venv/bin/python3 -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"

echo "Lab 05 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "router-d sessions will show red until configured."
