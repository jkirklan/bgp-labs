#!/usr/bin/env bash
# Smoke test for lab06: BGP sessions up; router-a announces 3 prefixes including
# 10.0.0.0/8 which ISP (router-b) should filter. Pre-filter state is verified here.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 06 Smoke Test ==="

assert_containers_running "lab06-"

echo "Waiting for BGP sessions..."
assert_bgp_established "lab06-router-a" 1 "router-a (customer)"
assert_bgp_established "lab06-router-b" 1 "router-b (ISP — router-a peer)"

# Before student applies filters, all 3 prefixes from router-a should be in router-b's table.
echo "Checking pre-filter state: all 3 customer prefixes visible at ISP..."
for prefix in "192.168.1.0" "192.168.2.0" "10.0.0.0"; do
  if podman exec lab06-router-b vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
     | grep -q "${prefix}"; then
    pass "router-b: ${prefix} present (pre-filter)"
  else
    fail "router-b: ${prefix} missing (should be present before filtering)"
  fi
done

smoke_summary
