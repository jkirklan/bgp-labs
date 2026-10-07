#!/usr/bin/env bash
# Smoke test for lab01: ping fails before static routes, succeeds after.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 01 Smoke Test ==="

assert_containers_running "lab01-"

echo "Exercise 1 — ping should fail before static routes..."
assert_ping_fail "lab01-host-a" "192.168.102.10" "host-a → 192.168.102.10 (no route)"

echo "Adding static routes..."
podman exec -i lab01-host-a vtysh << 'EOF'
configure terminal
ip route 192.168.102.0/24 192.168.101.254
end
write memory
EOF

podman exec -i lab01-host-b vtysh << 'EOF'
configure terminal
ip route 192.168.101.0/24 192.168.102.254
end
write memory
EOF

sleep 1
echo "Exercise 2 — ping should succeed after static routes..."
assert_ping_ok "lab01-host-a" "192.168.102.10" "host-a → 192.168.102.10 (with routes)"

smoke_summary
