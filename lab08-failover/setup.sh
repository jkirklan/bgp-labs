#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../.." && pwd)"
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

cd "${REPO_ROOT}"
${REPO_ROOT}/.venv/bin/python3 -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

${REPO_ROOT}/.venv/bin/python3 -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"

echo "Lab 08 is up. topology-watch: http://localhost:${TOPO_PORT}"
echo "Both sessions Established — primary link preferred (LOCAL_PREF=200)."
