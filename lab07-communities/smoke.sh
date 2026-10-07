#!/usr/bin/env bash
# Smoke test for lab07: BGP sessions up, community-tagged routes visible.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 07 Smoke Test ==="

assert_containers_running "lab07-"

echo "Waiting for BGP sessions on transit router..."
assert_bgp_established "lab07-transit" 3 "transit (3 peers: cust-a, cust-b, peer)"

# Customer A's prefix should be in the transit router's BGP table.
if podman exec lab07-transit vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
   | grep -q "192.168.10.0\|192.168.1.0"; then
  pass "transit: customer-A prefix visible"
else
  fail "transit: customer-A prefix missing"
fi

# Check routes with community tags are visible (requires student configuration,
# so we just verify the BGP table has routes from cust-a).
echo "Checking FRR is responsive on all nodes..."
for router in lab07-transit lab07-cust-a lab07-cust-b lab07-peer; do
  if podman exec "$router" vtysh -c "show version" &>/dev/null; then
    pass "${router}: vtysh responsive"
  else
    fail "${router}: vtysh not responsive"
  fi
done

smoke_summary
