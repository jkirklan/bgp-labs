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
if wait_bgp_route lab13-router-a "192.168.4.0"; then
  pass "router-a: 192.168.4.0/24 (router-d) is reachable via BGP"
else
  fail "router-a: 192.168.4.0/24 not in BGP table"
fi

# README: router-a receives 192.168.4.0/24 via two independent paths.
for _ in $(seq 1 15); do  # second path can lag the first by a few seconds
  path_count=$(podman exec lab13-router-a vtysh -c "show bgp ipv4 unicast 192.168.4.0/24" 2>/dev/null \
               | sed -nE 's/.*Paths: \(([0-9]+) available.*/\1/p')
  path_count=${path_count:-0}
  [ "$path_count" -ge 2 ] && break
  sleep 2
done
if [ "$path_count" -ge 2 ]; then
  pass "router-a: ${path_count} paths to 192.168.4.0/24"
else
  fail "router-a: ${path_count} path(s) to 192.168.4.0/24 (expected 2)"
fi

smoke_summary
