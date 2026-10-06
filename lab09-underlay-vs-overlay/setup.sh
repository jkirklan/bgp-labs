#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
TOPO_PORT=8309

echo "=== Lab 09: Underlay vs Overlay ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run lab00-build-your-router/setup.sh first."
    exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating underlay network ..."
podman network create lab09-underlay --subnet 10.0.12.0/30 2>/dev/null || true

echo "Step 2: Starting VTEP routers ..."
podman run -d --name lab09-vtep-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
    --network lab09-underlay:interface_name=eth0,ip=10.0.12.1 \
    -v "${LAB_DIR}/configs/vtep-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab09-vtep-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
    --network lab09-underlay:interface_name=eth0,ip=10.0.12.2 \
    -v "${LAB_DIR}/configs/vtep-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Waiting 5s for FRR BGP to establish ..."
sleep 5

echo "Step 3: Configuring VXLAN tunnels (VNI 1001) ..."
echo "  (If this step fails with 'No such device': see Troubleshooting in README.md — VXLAN kernel module may need loading)"
podman exec lab09-vtep-a ip link add vxlan0 type vxlan id 1001 remote 10.0.12.2 dev eth0 dstport 4789
podman exec lab09-vtep-a ip link set vxlan0 up
podman exec lab09-vtep-a ip addr add 192.168.10.1/24 dev vxlan0

podman exec lab09-vtep-b ip link add vxlan0 type vxlan id 1001 remote 10.0.12.1 dev eth0 dstport 4789
podman exec lab09-vtep-b ip link set vxlan0 up
podman exec lab09-vtep-b ip addr add 192.168.10.2/24 dev vxlan0

echo "Step 4: Starting visualization tools ..."
. "${REPO_ROOT}/scripts/start-watchers.sh"

echo ""
echo "Lab 09 is up."
echo "  topology-watch: http://localhost:${TOPO_PORT}"
echo "  packet-watch:   running (dual-pane mode — underlay + overlay)"
echo ""
echo "BGP underlay established. VXLAN VNI 1001 configured."
echo "Run: podman exec lab09-vtep-a ping -c 3 192.168.10.2"
echo "Then watch packet-watch show UDP/4789 in UNDERLAY and ICMP in OVERLAY."
