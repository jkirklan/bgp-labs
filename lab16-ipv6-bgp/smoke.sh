#!/usr/bin/env bash
# Smoke test for lab16: IPv6 BGP sessions Established, routes propagated end-to-end.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 16 Smoke Test ==="

assert_containers_running "lab16-"

echo "Waiting for IPv6 BGP sessions (NDP takes longer than IPv4 ARP)..."
sleep 4  # extra buffer; setup.sh already waits 8s

assert_bgp6_established "lab16-router-a" 1 "router-a IPv6 BGP (to router-b)"
assert_bgp6_established "lab16-router-b" 2 "router-b IPv6 BGP (router-a and router-c)"
assert_bgp6_established "lab16-router-c" 1 "router-c IPv6 BGP (to router-b)"

echo "Checking IPv6 route propagation..."
# router-a should learn 2001:db8:3::/48 from router-c via router-b.
if podman exec lab16-router-a vtysh -c "show bgp ipv6 unicast" 2>/dev/null \
   | grep -q "2001:db8:3"; then
  pass "router-a: learned 2001:db8:3::/48 from router-c (via transit)"
else
  fail "router-a: 2001:db8:3::/48 not in IPv6 BGP table"
fi

# router-c should learn 2001:db8:1::/48 from router-a via router-b.
if podman exec lab16-router-c vtysh -c "show bgp ipv6 unicast" 2>/dev/null \
   | grep -q "2001:db8:1"; then
  pass "router-c: learned 2001:db8:1::/48 from router-a (via transit)"
else
  fail "router-c: 2001:db8:1::/48 not in IPv6 BGP table"
fi

echo "Checking end-to-end IPv6 connectivity (link addresses)..."
# router-a should be able to ping router-b's far-side address.
assert_ping6_ok "lab16-router-a" "2001:db8:23::1" "router-a → router-b far side (2001:db8:23::1)"

smoke_summary
