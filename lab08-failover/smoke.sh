#!/usr/bin/env bash
# Smoke test for lab08: customer has 2 eBGP sessions (primary + backup ISPs).
# LOCAL_PREF determines which path is preferred.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 08 Smoke Test ==="

assert_containers_running "lab08-"

echo "Waiting for dual eBGP sessions on customer router..."
assert_bgp_established "lab08-customer" 2 "customer (primary + backup ISPs)"

# Both ISPs should see the customer's prefix.
for router in lab08-isp-primary lab08-isp-backup; do
  if podman exec "$router" vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
     | grep -q "192.168.100.0"; then
    pass "${router}: customer prefix 192.168.100.0/24 visible"
  else
    fail "${router}: customer prefix missing"
  fi
done

# Customer should see a default route or the ISP's prefix via both peers.
bgp_paths=$(podman exec lab08-customer vtysh -c "show bgp ipv4 unicast" 2>/dev/null \
            | grep -c "^>" || true)
if [ "$bgp_paths" -ge 1 ]; then
  pass "customer: ${bgp_paths} best BGP path(s) installed"
else
  fail "customer: no BGP paths in table"
fi

smoke_summary
