#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

echo ""
echo "Lab 07 is running."
echo ""
echo "Quick status:"
podman exec lab07-transit vtysh -c "show bgp summary" 2>/dev/null || echo "  transit: bgpd not ready yet"
echo ""
echo "See README.md for exercises."
