#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPO_PORT=8308

echo "=== Lab 08: Failover ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab08-primary-link --subnet 10.0.12.0/30 2>/dev/null || true
podman network create lab08-backup-link  --subnet 10.0.13.0/30 2>/dev/null || true

echo "Step 2: Starting routers ..."

podman run -d --name lab08-customer \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab08-primary-link:interface_name=eth0,ip=10.0.12.1 \
    --network lab08-backup-link:interface_name=eth1,ip=10.0.13.1 \
    -v "${LAB_DIR}/configs/customer.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab08-isp-primary \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab08-primary-link:interface_name=eth0,ip=10.0.12.2 \
    -v "${LAB_DIR}/configs/isp-primary.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab08-isp-backup \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab08-backup-link:interface_name=eth0,ip=10.0.13.2 \
    -v "${LAB_DIR}/configs/isp-backup.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

echo ""
echo "Lab 08 is running."
echo ""
echo "Quick status:"
podman exec lab08-customer vtysh -c "show ip route 0.0.0.0/0" 2>/dev/null || echo "  customer: routing table not ready yet"
echo ""
echo "See README.md for exercises."
