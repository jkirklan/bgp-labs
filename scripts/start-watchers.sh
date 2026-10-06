#!/usr/bin/env bash
# Source this file from a lab setup.sh to start topology-watch and packet-watch.
# Requires REPO_ROOT, LAB_DIR, and TOPO_PORT to be set in the calling environment.
#
# Usage: . "${REPO_ROOT}/scripts/start-watchers.sh"

LABS_PARENT="$(cd "${REPO_ROOT}/.." && pwd)"

[ -e "${LABS_PARENT}/labs" ] || ln -sf "${REPO_ROOT}" "${LABS_PARENT}/labs"

PYTHONPATH="${LABS_PARENT}" "${REPO_ROOT}/.venv/bin/python3" -c "
from labs.tools.topology_watch.app import create_app
create_app('${LAB_DIR}/lab.json').run(host='127.0.0.1', port=${TOPO_PORT})
" &
echo $! > "${LAB_DIR}/.topology-watch.pid"

PYTHONPATH="${LABS_PARENT}" "${REPO_ROOT}/.venv/bin/python3" -m labs.tools.packet_watch.packet_watch --lab-dir "${LAB_DIR}" &
echo $! > "${LAB_DIR}/.packet-watch.pid"
