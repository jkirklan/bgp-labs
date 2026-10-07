#!/usr/bin/env bash
# Smoke test for lab04: containers running; router-a has BGP configured.
# NOTE: router-b has no BGP pre-configured — students add transit BGP in exercises.
#       Sessions will only be Established after students configure router-b.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 04 Smoke Test ==="

assert_containers_running "lab04-"

# Verify router-a and router-c have BGP configured and FRR is running.
for router in lab04-router-a lab04-router-c; do
  if podman exec "$router" vtysh -c "show bgp summary" &>/dev/null; then
    pass "${router}: FRR vtysh is responsive"
  else
    fail "${router}: vtysh not responsive"
  fi
done

# Verify underlay connectivity (physical layer is up).
if podman exec lab04-router-a ping -c 2 -W 2 10.0.12.2 &>/dev/null; then
  pass "router-a → router-b underlay reachable (10.0.12.2)"
else
  fail "router-a → router-b underlay unreachable"
fi

smoke_summary
