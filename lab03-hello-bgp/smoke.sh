#!/usr/bin/env bash
# Smoke test for lab03: eBGP session established, prefixes exchanged.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 03 Smoke Test ==="

assert_containers_running "lab03-"

echo "Waiting for BGP sessions..."
assert_bgp_established "lab03-router-a" 1 "router-a (AS65001)"
assert_bgp_established "lab03-router-b" 1 "router-b (AS65002)"

echo "Checking route exchange..."
# router-b should have learned 192.168.1.0/24 from router-a
if podman exec lab03-router-b vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.1.0"; then
  pass "router-b: learned 192.168.1.0/24 from router-a"
else
  fail "router-b: 192.168.1.0/24 not in BGP table"
fi

# router-a should have learned 192.168.2.0/24 from router-b
if podman exec lab03-router-a vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.2.0"; then
  pass "router-a: learned 192.168.2.0/24 from router-b"
else
  fail "router-a: 192.168.2.0/24 not in BGP table"
fi

smoke_summary
