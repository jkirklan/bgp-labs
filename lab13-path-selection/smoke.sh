#!/usr/bin/env bash
# Smoke test for lab13: all eBGP sessions Established, dual paths to router-d visible.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 13 Smoke Test ==="

assert_containers_running "lab13-"

echo "Waiting for BGP sessions..."
assert_bgp_established "lab13-router-a" 2 "router-a (2 providers: router-b and router-c)"
assert_bgp_established "lab13-router-d" 2 "router-d (2 customers: router-b and router-c)"

# router-a should see router-d's prefix (192.168.4.0/24) via both paths.
echo "Checking for router-d prefix reachability on router-a..."
if podman exec lab13-router-a vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.4.0"; then
  pass "router-a: 192.168.4.0/24 (router-d) is reachable via BGP"
else
  fail "router-a: 192.168.4.0/24 not in BGP table"
fi

# router-d should see router-a's prefix (pre-configured in router-a.conf).
if podman exec lab13-router-d vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.1.0"; then
  pass "router-d: 192.168.1.0/24 (router-a) is reachable via BGP"
else
  fail "router-d: 192.168.1.0/24 not in BGP table"
fi

smoke_summary
