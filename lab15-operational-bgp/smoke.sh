#!/usr/bin/env bash
# Smoke test for lab15: BGP sessions up; bogon prefixes visible before student filtering.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 15 Smoke Test ==="

assert_containers_running "lab15-"

echo "Waiting for BGP sessions..."
assert_bgp_established "lab15-router-a" 2 "router-a (2 peers)"
assert_bgp_established "lab15-router-b" 1 "router-b (peer to router-a)"

echo "Checking pre-filter state: bogon routes should be visible on router-a..."
# router-c announces RFC 1918 bogons — they appear before filtering.
for bogon in "10.0.0.0" "192.168.0.0" "172.16.0.0"; do
  if podman exec lab15-router-a vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
     | grep -q "${bogon}"; then
    pass "router-a: bogon ${bogon}/x present (pre-filter — expected)"
  else
    fail "router-a: bogon ${bogon}/x missing (should be visible before student applies filter)"
  fi
done

echo ""
echo "NOTE: After exercises, student applies prefix-lists to filter these bogons."
echo "      Re-run smoke test after filtering to confirm they disappear."

# max-prefix: router-a should NOT have hit the max-prefix limit yet.
if podman exec lab15-router-a vtysh -c "show bgp summary" 2>/dev/null \
   | grep -v "Established" | grep -q "PfxRcd"; then
  :  # table is showing, all is well
fi
bgp_state=$(podman exec lab15-router-a vtysh -c "show bgp summary" 2>/dev/null | grep "Established" | wc -l)
if [ "$bgp_state" -ge 2 ]; then
  pass "router-a: ${bgp_state} sessions Established (no max-prefix shutdown)"
else
  fail "router-a: sessions not Established — possible max-prefix shutdown?"
fi

smoke_summary
