#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
TOPO_PORT=8316

echo "=== Lab 16: BGP with IPv6 ==="

# Require frr:latest
if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

# Clean any previous run
"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab16-a-b-link --subnet 10.0.12.0/30 2>/dev/null || true
podman network create lab16-b-c-link --subnet 10.0.23.0/30 2>/dev/null || true

echo "Step 2: Starting routers ..."

# Router A — AS65001, announces 2001:db8:1::/48
podman run -d --name lab16-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    --network lab16-a-b-link:interface_name=eth0,ip=10.0.12.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B — AS65002, IPv6 transit
podman run -d --name lab16-router-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    --network lab16-a-b-link:interface_name=eth0,ip=10.0.12.2 \
    --network lab16-b-c-link:interface_name=eth1,ip=10.0.23.1 \
    -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router C — AS65003, announces 2001:db8:3::/48
podman run -d --name lab16-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    --network lab16-b-c-link:interface_name=eth0,ip=10.0.23.2 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 8s for FRR to assign IPv6 addresses and establish sessions ..."
sleep 8

. "${REPO_ROOT}/scripts/start-watchers.sh"

echo "Lab 16 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "IPv6 BGP sessions are peering over 2001:db8:12::/64 and 2001:db8:23::/64."
