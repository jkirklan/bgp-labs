#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"
TOPO_PORT=8304

echo "=== Lab 04: Transit ==="

# Require frr:latest
if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run labs/lab00-build-your-router/setup.sh first."
    exit 1
fi

# Clean any previous run
"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab04-as1-as2-link --subnet 10.0.12.0/30 2>/dev/null || true
podman network create lab04-as2-as3-link --subnet 10.0.23.0/30 2>/dev/null || true
podman network create lab04-as1-internal --subnet 192.168.1.0/24 2>/dev/null || true
podman network create lab04-as3-internal --subnet 192.168.3.0/24 2>/dev/null || true

echo "Step 2: Starting routers ..."

# Router A — AS65001, connected to as1-as2-link and as1-internal
podman run -d --name lab04-router-a \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab04-as1-as2-link:interface_name=eth0,ip=10.0.12.1 \
    --network lab04-as1-internal:interface_name=eth1,ip=192.168.1.1 \
    -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router B — AS65002, transit provider
podman run -d --name lab04-router-b \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab04-as1-as2-link:interface_name=eth0,ip=10.0.12.2 \
    --network lab04-as2-as3-link:interface_name=eth1,ip=10.0.23.1 \
    -v "${LAB_DIR}/configs/router-b.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

# Router C — AS65003, connected to as2-as3-link and as3-internal
podman run -d --name lab04-router-c \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --network lab04-as2-as3-link:interface_name=eth0,ip=10.0.23.2 \
    --network lab04-as3-internal:interface_name=eth1,ip=192.168.3.1 \
    -v "${LAB_DIR}/configs/router-c.conf:/etc/frr/frr.conf:ro,z" \
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

echo "Lab 04 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "Sessions will show red (Idle) until router-b is configured."
