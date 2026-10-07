#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
TOPO_PORT=8313

echo "=== Lab 13: BGP Path Selection ==="

# Require frr:latest
if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

# Clean any previous run
"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab13-a-b-link     --subnet 10.0.12.0/30   2>/dev/null || true
podman network create lab13-a-c-link     --subnet 10.0.13.0/30   2>/dev/null || true
podman network create lab13-b-d-link     --subnet 10.0.24.0/30   2>/dev/null || true
podman network create lab13-c-d-link     --subnet 10.0.34.0/30   2>/dev/null || true
podman network create lab13-as4-internal --subnet 192.168.4.0/24 2>/dev/null || true

echo "Step 2: Starting routers ..."

# Router A — AS65001, dual-homed customer
podman run -d --name lab13-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab13-a-b-link:interface_name=eth0,ip=10.0.12.1 \
    --network lab13-a-c-link:interface_name=eth1,ip=10.0.13.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B — AS65002, provider 1
podman run -d --name lab13-router-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab13-a-b-link:interface_name=eth0,ip=10.0.12.2 \
    --network lab13-b-d-link:interface_name=eth1,ip=10.0.24.1 \
    -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router C — AS65003, provider 2
podman run -d --name lab13-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab13-a-c-link:interface_name=eth0,ip=10.0.13.2 \
    --network lab13-c-d-link:interface_name=eth1,ip=10.0.34.1 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router D — AS65004, content AS announcing 192.168.4.0/24
podman run -d --name lab13-router-d \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab13-b-d-link:interface_name=eth0,ip=10.0.24.2 \
    --network lab13-c-d-link:interface_name=eth1,ip=10.0.34.2 \
    --network lab13-as4-internal:interface_name=eth2,ip=192.168.4.1 \
    -v "${LAB_DIR}/configs/router-d.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

. "${REPO_ROOT}/scripts/start-watchers.sh"

echo "Lab 13 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "All eBGP sessions come up automatically."
echo "router-a receives 192.168.4.0/24 via both providers — observe which path wins."
