#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
LABS_PARENT="$(cd "${REPO_ROOT}/.." && pwd)"
TOPO_PORT=8310

echo "=== Lab 10: Microsegmentation ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run lab00-build-your-router/setup.sh first."
    exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating underlay network ..."
podman network create lab10-underlay --subnet 10.0.12.0/30 2>/dev/null || true

echo "Step 2: Starting VTEP routers ..."
podman run -d --name lab10-vtep-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab10-underlay:interface_name=eth0,ip=10.0.12.1 \
    -v "${LAB_DIR}/configs/vtep-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab10-vtep-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab10-underlay:interface_name=eth0,ip=10.0.12.2 \
    -v "${LAB_DIR}/configs/vtep-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Waiting 5s for FRR BGP to establish ..."
sleep 5

echo "Step 3: Configuring VXLAN tunnels ..."

# vtep-a — VNI 1001 (Tenant A)
podman exec lab10-vtep-a ip link add vxlan0 type vxlan id 1001 remote 10.0.12.2 dev eth0 dstport 4789
podman exec lab10-vtep-a ip link set vxlan0 up
podman exec lab10-vtep-a ip addr add 192.168.10.1/24 dev vxlan0

# vtep-a — VNI 1002 (Tenant B)
podman exec lab10-vtep-a ip link add vxlan1 type vxlan id 1002 remote 10.0.12.2 dev eth0 dstport 4789
podman exec lab10-vtep-a ip link set vxlan1 up
podman exec lab10-vtep-a ip addr add 192.168.20.1/24 dev vxlan1

# vtep-b — VNI 1001 (Tenant A)
podman exec lab10-vtep-b ip link add vxlan0 type vxlan id 1001 remote 10.0.12.1 dev eth0 dstport 4789
podman exec lab10-vtep-b ip link set vxlan0 up
podman exec lab10-vtep-b ip addr add 192.168.10.2/24 dev vxlan0

# vtep-b — VNI 1002 (Tenant B)
podman exec lab10-vtep-b ip link add vxlan1 type vxlan id 1002 remote 10.0.12.1 dev eth0 dstport 4789
podman exec lab10-vtep-b ip link set vxlan1 up
podman exec lab10-vtep-b ip addr add 192.168.20.2/24 dev vxlan1

echo "Step 4: Starting visualization tools ..."
[ -e "${LABS_PARENT}/labs" ] || ln -sf "${REPO_ROOT}" "${LABS_PARENT}/labs"
PYTHONPATH="${LABS_PARENT}" ${REPO_ROOT}/.venv/bin/python3 -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

PYTHONPATH="${LABS_PARENT}" ${REPO_ROOT}/.venv/bin/python3 -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"

echo ""
echo "Lab 10 is up."
echo "  topology-watch: http://localhost:${TOPO_PORT}"
echo "  packet-watch:   running (dual-pane — shows both VNI 1001 and VNI 1002)"
echo ""
echo "Two VNIs configured:"
echo "  VNI 1001 (Tenant A): vtep-a 192.168.10.1 <-> vtep-b 192.168.10.2  (vxlan0)"
echo "  VNI 1002 (Tenant B): vtep-a 192.168.20.1 <-> vtep-b 192.168.20.2  (vxlan1)"
echo ""
echo "Follow the README for VRF microsegmentation exercises."
