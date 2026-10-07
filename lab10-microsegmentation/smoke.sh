#!/usr/bin/env bash
# Smoke test for lab10: dual-VNI VXLAN is up; VNI isolation confirmed.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 10 Smoke Test ==="

if ! modinfo vxlan &>/dev/null 2>&1; then
  echo "  SKIP: vxlan kernel module not available on this host"
  exit 0
fi

assert_containers_running "lab10-"

echo "Waiting for underlay BGP sessions..."
assert_bgp_established "lab10-vtep-a" 1 "vtep-a underlay BGP"
assert_bgp_established "lab10-vtep-b" 1 "vtep-b underlay BGP"

echo "Checking intra-VNI reachability (Tenant A: VNI 1001)..."
assert_ping_ok "lab10-vtep-a" "192.168.10.2" "vtep-a → vtep-b (VNI 1001, Tenant A)"

echo "Checking intra-VNI reachability (Tenant B: VNI 1002)..."
assert_ping_ok "lab10-vtep-a" "192.168.20.2" "vtep-a → vtep-b (VNI 1002, Tenant B)"

echo "Confirming VNI isolation: Tenant A cannot reach Tenant B addresses..."
# 192.168.10.x is VNI 1001; 192.168.20.x is VNI 1002.
# Without inter-VRF routing, they cannot reach each other.
# We verify that pinging from VNI1001 to VNI1002 fails (no route between VNIs on vtep-b).
if podman exec lab10-vtep-b ping -c 2 -W 2 -I vxlan0 192.168.20.1 &>/dev/null; then
  fail "VNI isolation BROKEN: vxlan0 (Tenant A) can reach vxlan1 (Tenant B)"
else
  pass "VNI isolation: Tenant A (vxlan0) cannot reach Tenant B (vxlan1)"
fi

smoke_summary
