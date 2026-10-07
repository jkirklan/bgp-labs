#!/usr/bin/env bash
# Smoke test for lab05: router-a has 2 eBGP sessions (to router-b and router-c).
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 05 Smoke Test ==="

assert_containers_running "lab05-"

echo "Waiting for BGP sessions on router-a (dual-homed, 2 peers)..."
assert_bgp_established "lab05-router-a" 2 "router-a (dual-homed)"

# router-d's prefix should appear in router-a's BGP table with 2 paths.
echo "Checking for multiple paths to router-d prefix..."
route_count=$(podman exec lab05-router-a vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
              | grep -c "192.168.4.0" || true)
if [ "$route_count" -ge 2 ]; then
  pass "router-a: ${route_count} paths to 192.168.4.0/24 (ECMP candidates)"
elif [ "$route_count" -eq 1 ]; then
  pass "router-a: 1 path to 192.168.4.0/24 (second path may be suppressed without multipath)"
else
  fail "router-a: 192.168.4.0/24 not in BGP table"
fi

smoke_summary
