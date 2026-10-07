#!/usr/bin/env bash
# Smoke test for lab11: eBGP sessions are pre-configured and Established.
# iBGP (the student exercise) is NOT expected to be Established yet.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 11 Smoke Test ==="

assert_containers_running "lab11-"

echo "Checking pre-configured eBGP sessions..."
# router-a (AS65001) has eBGP to router-b1 (AS65002).
assert_bgp_established "lab11-router-a"  1 "router-a (eBGP to router-b1)"
# router-b1 has eBGP to router-a (AS65001) — no iBGP yet.
assert_bgp_established "lab11-router-b1" 1 "router-b1 (eBGP to router-a)"
# router-b2 has eBGP to router-c (AS65003) — no iBGP yet.
assert_bgp_established "lab11-router-b2" 1 "router-b2 (eBGP to router-c)"
# router-c (AS65003) has eBGP to router-b2.
assert_bgp_established "lab11-router-c"  1 "router-c (eBGP to router-b2)"

echo ""
echo "NOTE: iBGP between router-b1 and router-b2 is NOT expected yet."
echo "      The student configures that in the exercises."

# router-a's prefix is visible on router-b1 (direct eBGP).
if podman exec lab11-router-b1 vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.1.0"; then
  pass "router-b1: 192.168.1.0/24 (router-a prefix) visible via eBGP"
else
  fail "router-b1: 192.168.1.0/24 missing"
fi

# router-c's prefix NOT visible on router-b1 yet (iBGP not configured).
bgp_table=$(podman exec lab11-router-b1 vtysh -c "show bgp ipv4 unicast" 2>/dev/null)
if echo "$bgp_table" | grep -q "192.168.3.0"; then
  fail "router-b1: 192.168.3.0/24 (router-c prefix) visible — iBGP configured too early?"
else
  pass "router-b1: 192.168.3.0/24 correctly absent (iBGP not yet configured)"
fi

smoke_summary
