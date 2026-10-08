#!/usr/bin/env bash
# Smoke test for lab14: VRFs configured, underlay BGP up, CE-to-PE reachability,
# and VRF isolation confirmed (no cross-VRF routes before leaking).
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 14 Smoke Test ==="

if ! modinfo vxlan &>/dev/null 2>&1; then
  echo "  SKIP: vxlan kernel module not available on this host"
  exit 0
fi

assert_containers_running "lab14-"

echo "Waiting for underlay BGP sessions..."
assert_bgp_established "lab14-pe1" 1 "pe1 underlay BGP"
assert_bgp_established "lab14-pe2" 1 "pe2 underlay BGP"

echo "Checking VRF-A gateway reachability (CE-A1 -> PE1)..."
assert_ping_ok "lab14-ce-a1" "192.168.10.1" "ce-a1 -> pe1 VRF-A gateway"

echo "Checking VRF-B gateway reachability (CE-B1 -> PE1)..."
assert_ping_ok "lab14-ce-b1" "192.168.30.1" "ce-b1 -> pe1 VRF-B gateway"

echo "Checking VRF-A gateway reachability (CE-A2 -> PE2)..."
assert_ping_ok "lab14-ce-a2" "192.168.20.1" "ce-a2 -> pe2 VRF-A gateway"

echo "Checking VRF-B gateway reachability (CE-B2 -> PE2)..."
assert_ping_ok "lab14-ce-b2" "192.168.40.1" "ce-b2 -> pe2 VRF-B gateway"

echo "Confirming VRF isolation: VRF-A has no route to VRF-B prefix before leaking..."
# VRF-B prefix 192.168.30.0/24 must NOT appear in VRF-A routing table.
if podman exec lab14-pe1 ip route show vrf vrf-a 2>/dev/null | grep -q "192.168.30.0"; then
  fail "VRF isolation BROKEN: 192.168.30.0 (VRF-B) visible in VRF-A before route leaking"
else
  pass "VRF-A routing table does not contain VRF-B prefix (isolation intact)"
fi

echo "Confirming VRF-B has no route to VRF-A prefix before leaking..."
if podman exec lab14-pe1 ip route show vrf vrf-b 2>/dev/null | grep -q "192.168.10.0"; then
  fail "VRF isolation BROKEN: 192.168.10.0 (VRF-A) visible in VRF-B before route leaking"
else
  pass "VRF-B routing table does not contain VRF-A prefix (isolation intact)"
fi

echo "Checking VXLAN L3VNI interfaces exist on PE1..."
if podman exec lab14-pe1 ip -d link show vxlan100 &>/dev/null; then
  pass "vxlan100 (L3VNI 100, VRF-A) exists on pe1"
else
  fail "vxlan100 (L3VNI 100, VRF-A) missing on pe1"
fi
if podman exec lab14-pe1 ip -d link show vxlan200 &>/dev/null; then
  pass "vxlan200 (L3VNI 200, VRF-B) exists on pe1"
else
  fail "vxlan200 (L3VNI 200, VRF-B) missing on pe1"
fi

smoke_summary
