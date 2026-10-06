#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
LABS_PARENT="$(cd "${REPO_ROOT}/.." && pwd)"
TOPO_PORT=8306

echo "=== Lab 06: Route Filtering ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab06-as1-as2-link --subnet 10.0.12.0/30 2>/dev/null || true
podman network create lab06-as2-as3-link --subnet 10.0.23.0/30 2>/dev/null || true

echo "Step 2: Starting routers ..."

podman run -d --name lab06-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
    --network lab06-as1-as2-link:interface_name=eth0,ip=10.0.12.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab06-router-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
    --network lab06-as1-as2-link:interface_name=eth0,ip=10.0.12.2 \
    --network lab06-as2-as3-link:interface_name=eth1,ip=10.0.23.1 \
    -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab06-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
    --network lab06-as2-as3-link:interface_name=eth0,ip=10.0.23.2 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

[ -e "${LABS_PARENT}/labs" ] || ln -sf "${REPO_ROOT}" "${LABS_PARENT}/labs"
PYTHONPATH="${LABS_PARENT}" ${REPO_ROOT}/.venv/bin/python3 -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

PYTHONPATH="${LABS_PARENT}" ${REPO_ROOT}/.venv/bin/python3 -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"

echo "Lab 06 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "All sessions start Established — begin exercises to observe filtering behavior."
