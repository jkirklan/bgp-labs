#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
TOPO_PORT=8315

echo "=== Lab 15: Operational BGP ==="

# Require frr:latest
if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

# Clean any previous run
"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab15-a-b-link --subnet 10.0.12.0/30 2>/dev/null || true
podman network create lab15-a-c-link --subnet 10.0.13.0/30 2>/dev/null || true

echo "Step 2: Starting routers ..."

# Router A — AS65001, the router we will harden
podman run -d --name lab15-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab15-a-b-link:interface_name=eth0,ip=10.0.12.1 \
    --network lab15-a-c-link:interface_name=eth1,ip=10.0.13.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B — AS65002, well-behaved provider (announces 203.0.113.0/24)
podman run -d --name lab15-router-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab15-a-b-link:interface_name=eth0,ip=10.0.12.2 \
    -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router C — AS65003, misconfigured peer (announces RFC 1918 bogons)
podman run -d --name lab15-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab15-a-c-link:interface_name=eth0,ip=10.0.13.2 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

. "${REPO_ROOT}/scripts/start-watchers.sh"

echo "Lab 15 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "WARNING: router-c is advertising bogon routes — router-a currently accepts them."
echo "Your job is to filter them out."
