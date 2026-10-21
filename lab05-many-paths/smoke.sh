#!/usr/bin/env bash
# Smoke test for lab05: router-d has 2 eBGP sessions and two paths to 192.168.1.0/24.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 05 Smoke Test ==="

assert_containers_running "lab05-"

echo "Waiting for BGP sessions on router-d (2 providers)..."
assert_bgp_established "lab05-router-d" 2 "router-d (2 providers: router-b and router-c)"

# README Verification: router-d sees 192.168.1.0/24 via both paths.
echo "Checking router-d has two paths to 192.168.1.0/24..."
path_count=$(podman exec lab05-router-d vtysh -c "show bgp ipv4 unicast 192.168.1.0/24" 2>/dev/null \
             | sed -nE 's/.*Paths: \(([0-9]+) available.*/\1/p')
path_count=${path_count:-0}
if [ "$path_count" -ge 2 ]; then
  pass "router-d: ${path_count} paths to 192.168.1.0/24"
else
  fail "router-d: ${path_count} path(s) to 192.168.1.0/24 (expected 2)"
fi

smoke_summary
