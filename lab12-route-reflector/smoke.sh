#!/usr/bin/env bash
# Smoke test for lab12: eBGP sessions are pre-configured; iBGP (student exercise) is not.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 12 Smoke Test ==="

assert_containers_running "lab12-"

echo "Checking pre-configured eBGP sessions..."
# router-b1 has eBGP to router-a (AS65001).
assert_bgp_established "lab12-router-b1" 1 "router-b1 (eBGP to router-a)"
# router-b3 has eBGP to router-c (AS65003).
assert_bgp_established "lab12-router-b3" 1 "router-b3 (eBGP to router-c)"

echo ""
echo "NOTE: iBGP sessions to the Route Reflector are NOT expected yet."
echo "      Students configure router-rr with route-reflector-client in the exercises."

# router-rr should have FRR running even with no iBGP configured.
if podman exec lab12-router-rr vtysh -c "show version" &>/dev/null; then
  pass "router-rr: FRR is running and responsive"
else
  fail "router-rr: FRR not responsive"
fi

# Verify router-b1 can see external prefix (from AS65001) via its eBGP session.
if podman exec lab12-router-b1 vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.1.0\|10.0.12.1"; then
  pass "router-b1: external prefix visible via eBGP"
else
  fail "router-b1: no external prefix in BGP table"
fi

smoke_summary
