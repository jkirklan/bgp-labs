#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
TOPO_PORT=8312

echo "=== Lab 12: Route Reflector ==="

# Require frr:latest
if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

# Clean any previous run
"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab12-as1-as2-link --subnet 10.0.12.0/30  2>/dev/null || true
podman network create lab12-as2-core     --subnet 10.0.20.0/24  2>/dev/null || true
podman network create lab12-as2-as3-link --subnet 10.0.23.0/30  2>/dev/null || true
podman network create lab12-as1-internal --subnet 192.168.1.0/24 2>/dev/null || true
podman network create lab12-as3-internal --subnet 192.168.3.0/24 2>/dev/null || true

echo "Step 2: Starting routers ..."

# Router A — AS65001, announces 192.168.1.0/24
podman run -d --name lab12-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab12-as1-as2-link:interface_name=eth0,ip=10.0.12.1 \
    --network lab12-as1-internal:interface_name=eth1,ip=192.168.1.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B1 — AS65002 border toward AS65001 (eBGP pre-configured, iBGP student adds)
podman run -d --name lab12-router-b1 \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab12-as1-as2-link:interface_name=eth0,ip=10.0.12.2 \
    --network lab12-as2-core:interface_name=eth1,ip=10.0.20.2 \
    -v "${LAB_DIR}/configs/router-b1.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B2 — AS65002 border toward AS65003 (eBGP pre-configured, iBGP student adds)
podman run -d --name lab12-router-b2 \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab12-as2-core:interface_name=eth0,ip=10.0.20.3 \
    --network lab12-as2-as3-link:interface_name=eth1,ip=10.0.23.1 \
    -v "${LAB_DIR}/configs/router-b2.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B3 — AS65002 internal router, no eBGP peers (student connects via RR)
podman run -d --name lab12-router-b3 \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab12-as2-core:interface_name=eth0,ip=10.0.20.4 \
    -v "${LAB_DIR}/configs/router-b3.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router RR — AS65002 route reflector (student configures RR sessions)
podman run -d --name lab12-router-rr \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab12-as2-core:interface_name=eth0,ip=10.0.20.1 \
    -v "${LAB_DIR}/configs/router-rr.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router C — AS65003, announces 192.168.3.0/24
podman run -d --name lab12-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab12-as2-as3-link:interface_name=eth0,ip=10.0.23.2 \
    --network lab12-as3-internal:interface_name=eth1,ip=192.168.3.1 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Routers started. Waiting 5s for FRR to initialize ..."
sleep 5

. "${REPO_ROOT}/scripts/start-watchers.sh"

echo "Lab 12 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "eBGP sessions to AS65001 and AS65003 come up automatically."
echo "AS65002 has NO iBGP sessions — configure the route reflector to connect them."
