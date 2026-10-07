#!/usr/bin/env bash
# Smoke test for lab09: underlay BGP up, VXLAN overlay reachable.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 09 Smoke Test ==="

# VXLAN requires the vxlan kernel module — skip gracefully if unavailable.
if ! modinfo vxlan &>/dev/null 2>&1; then
  echo "  SKIP: vxlan kernel module not available on this host"
  echo "  (Run on a Linux host with kernel VXLAN support)"
  exit 0
fi

assert_containers_running "lab09-"

echo "Waiting for underlay BGP sessions..."
assert_bgp_established "lab09-vtep-a" 1 "vtep-a underlay BGP"
assert_bgp_established "lab09-vtep-b" 1 "vtep-b underlay BGP"

# Loopback routes should be exchanged via BGP.
if podman exec lab09-vtep-a vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "10.10.10.2"; then
  pass "vtep-a: learned vtep-b loopback 10.10.10.2/32 via BGP"
else
  fail "vtep-a: vtep-b loopback 10.10.10.2/32 not in BGP table"
fi

# VXLAN overlay: vtep-a's vxlan0 should reach vtep-b's vxlan0 (192.168.10.x).
echo "Testing VXLAN overlay reachability..."
if podman exec lab09-vtep-a ping -c 3 -W 3 192.168.10.2 &>/dev/null; then
  pass "vtep-a overlay (vxlan0) → vtep-b overlay (192.168.10.2)"
else
  fail "vtep-a cannot reach vtep-b via VXLAN overlay (192.168.10.2)"
fi

smoke_summary
