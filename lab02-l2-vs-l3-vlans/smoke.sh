#!/usr/bin/env bash
# Smoke test for lab02: verify L2 isolation — same-VLAN pings OK, cross-VLAN fails.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 02 Smoke Test ==="

assert_containers_running "lab02-"

echo "Intra-VLAN: host-a1 should reach host-a2 (same VLAN A)..."
assert_ping_ok "lab02-host-a1" "192.168.10.2" "host-a1 → host-a2 (VLAN A)"

echo "Inter-VLAN: host-a1 should NOT reach host-b1 (different VLANs, no router)..."
assert_ping_fail "lab02-host-a1" "192.168.20.10" "host-a1 → host-b1 (cross-VLAN, no route)"

smoke_summary
