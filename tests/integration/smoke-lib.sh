#!/usr/bin/env bash
# Shared helpers for per-lab smoke tests.
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/smoke-lib.sh"

SMOKE_PASS=0
SMOKE_FAIL=0

pass() { echo "  PASS: $1"; SMOKE_PASS=$((SMOKE_PASS+1)); }
fail() { echo "  FAIL: $1"; SMOKE_FAIL=$((SMOKE_FAIL+1)); }

# Assert all containers matching the prefix are running.
assert_containers_running() {
  local prefix="$1"
  local containers
  containers=$(podman ps --filter "name=^${prefix}" --format "{{.Names}}" 2>/dev/null)
  if [ -z "$containers" ]; then
    fail "No containers running with prefix '${prefix}'"
    return 1
  fi
  local all_ok=true
  while IFS= read -r name; do
    local status
    status=$(podman inspect --format "{{.State.Status}}" "$name" 2>/dev/null || echo "missing")
    if [ "$status" != "running" ]; then
      fail "Container ${name} is ${status} (expected running)"
      all_ok=false
    else
      pass "Container ${name} is running"
    fi
  done <<< "$containers"
  $all_ok
}

# Wait up to <timeout> seconds for a BGP session to show at least <min_count>
# Established peers on <container>.
wait_bgp_established() {
  local container="$1"
  local min_count="${2:-1}"
  local timeout="${3:-30}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    local count
    count=$(podman exec "$container" vtysh -c "show bgp summary" 2>/dev/null \
            | grep -c "Established" || true)
    if [ "$count" -ge "$min_count" ]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed+2))
  done
  return 1
}

# Assert at least <min_count> BGP sessions are Established on <container>.
assert_bgp_established() {
  local container="$1"
  local min_count="${2:-1}"
  local label="${3:-$container}"
  if wait_bgp_established "$container" "$min_count" 30; then
    local count
    count=$(podman exec "$container" vtysh -c "show bgp summary" 2>/dev/null \
            | grep -c "Established" || true)
    pass "${label}: ${count} BGP session(s) Established (expected ≥${min_count})"
  else
    local count
    count=$(podman exec "$container" vtysh -c "show bgp summary" 2>/dev/null \
            | grep -c "Established" || echo "0")
    fail "${label}: only ${count} BGP session(s) Established (expected ≥${min_count})"
  fi
}

# Assert a route prefix is present in the BGP table of <container>.
assert_route_present() {
  local container="$1"
  local prefix="$2"
  local label="${3:-$prefix on $container}"
  if podman exec "$container" vtysh -c "show bgp ipv4 unicast ${prefix}" 2>/dev/null \
     | grep -q "Route ${prefix}\|Network ${prefix}\|>${prefix}"; then
    pass "${label}: route present"
  else
    fail "${label}: route NOT present"
  fi
}

# Assert a route prefix is present in the IPv6 BGP table of <container>.
assert_ipv6_route_present() {
  local container="$1"
  local prefix="$2"
  local label="${3:-$prefix on $container}"
  if podman exec "$container" vtysh -c "show bgp ipv6 unicast ${prefix}" 2>/dev/null \
     | grep -q "Route ${prefix}\|Network ${prefix}\|>${prefix}"; then
    pass "${label}: IPv6 route present"
  else
    fail "${label}: IPv6 route NOT present"
  fi
}

# Assert a ping from <src_container> to <dst_ip> SUCCEEDS.
assert_ping_ok() {
  local container="$1"
  local dst="$2"
  local label="${3:-ping ${dst}}"
  if podman exec "$container" ping -c 3 -W 2 "$dst" &>/dev/null; then
    pass "${label}: ping succeeded"
  else
    fail "${label}: ping failed (expected success)"
  fi
}

# Assert a ping from <src_container> to <dst_ip> FAILS.
assert_ping_fail() {
  local container="$1"
  local dst="$2"
  local label="${3:-ping ${dst}}"
  if podman exec "$container" ping -c 3 -W 2 "$dst" &>/dev/null; then
    fail "${label}: ping succeeded (expected failure)"
  else
    pass "${label}: ping correctly failed"
  fi
}

# Assert an IPv6 ping SUCCEEDS.
assert_ping6_ok() {
  local container="$1"
  local dst="$2"
  local label="${3:-ping6 ${dst}}"
  if podman exec "$container" ping -6 -c 3 -W 3 "$dst" &>/dev/null; then
    pass "${label}: ping6 succeeded"
  else
    fail "${label}: ping6 failed (expected success)"
  fi
}

# Wait up to <timeout> seconds for at least <min_count> IPv6 BGP sessions.
wait_bgp6_established() {
  local container="$1"
  local min_count="${2:-1}"
  local timeout="${3:-30}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    local count
    count=$(podman exec "$container" vtysh -c "show bgp ipv6 unicast summary" 2>/dev/null \
            | grep -c "Established" || true)
    if [ "$count" -ge "$min_count" ]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed+2))
  done
  return 1
}

# Assert at least <min_count> IPv6 BGP sessions Established on <container>.
assert_bgp6_established() {
  local container="$1"
  local min_count="${2:-1}"
  local label="${3:-$container IPv6}"
  if wait_bgp6_established "$container" "$min_count" 30; then
    local count
    count=$(podman exec "$container" vtysh -c "show bgp ipv6 unicast summary" 2>/dev/null \
            | grep -c "Established" || true)
    pass "${label}: ${count} IPv6 BGP session(s) Established (expected ≥${min_count})"
  else
    local count
    count=$(podman exec "$container" vtysh -c "show bgp ipv6 unicast summary" 2>/dev/null \
            | grep -c "Established" || echo "0")
    fail "${label}: only ${count} IPv6 session(s) Established (expected ≥${min_count})"
  fi
}

# Print summary and exit with nonzero if any failures.
smoke_summary() {
  echo ""
  echo "-------------------------------"
  echo "Results: ${SMOKE_PASS} passed, ${SMOKE_FAIL} failed"
  echo "-------------------------------"
  [ "${SMOKE_FAIL}" -eq 0 ]
}
