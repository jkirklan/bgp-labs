#!/usr/bin/env bash
# smoke-all.sh — Run per-lab smoke tests for all BGP labs.
#
# Usage:
#   Lima VM:  limactl shell <vm> -- bash /path/to/smoke-all.sh
#   CI:       REPO_ROOT=$GITHUB_WORKSPACE bash tests/integration/smoke-all.sh
#   Local:    bash labs/tests/integration/smoke-all.sh
#
# Individual labs can be run in isolation:
#   bash labs/lab03-hello-bgp/smoke.sh   (after running setup.sh)
set -uo pipefail

TOTAL_PASS=0
TOTAL_FAIL=0
SKIPPED=0

# Resolve REPO_ROOT: prefer env var (CI), else climb from this script's location.
if [ -n "${REPO_ROOT:-}" ]; then
  CLONED=false
else
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
  CLONED=false
fi
LABS_DIR="${REPO_ROOT}/labs"

echo "=== BGP Labs Full Smoke Test ==="
echo "Host:   $(uname -a)"
echo "Podman: $(podman --version 2>/dev/null || echo unknown)"
echo "Labs:   ${LABS_DIR}"
echo ""

# ── Step 1: Build frr:latest ──────────────────────────────────────────────────
echo "[setup] Building frr:latest..."
ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
if podman build --platform "linux/${ARCH}" -t frr:latest "${REPO_ROOT}/containerfiles/frr/" 2>&1 | tail -3; then
  echo "  OK: frr:latest built"
else
  echo "  ERROR: frr:latest build failed — aborting"
  exit 1
fi
echo ""

# ── Lab runner helper ─────────────────────────────────────────────────────────
run_lab() {
  local lab_dir="$1"
  local lab_path="${LABS_DIR}/${lab_dir}"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Running: ${lab_dir}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ ! -f "${lab_path}/smoke.sh" ]; then
    echo "  SKIP: no smoke.sh found"
    SKIPPED=$((SKIPPED+1))
    return
  fi

  # lab00 has no containers — run its smoke.sh directly (no setup/teardown).
  if [ "${lab_dir}" = "lab00-build-your-router" ]; then
    bash "${lab_path}/smoke.sh"
    local rc=$?
    [ "$rc" -eq 0 ] && TOTAL_PASS=$((TOTAL_PASS+1)) || TOTAL_FAIL=$((TOTAL_FAIL+1))
    echo ""
    return
  fi

  # Standard labs: setup → smoke → teardown.
  echo "[setup] Starting ${lab_dir}..."
  if ! bash "${lab_path}/setup.sh" 2>&1 | tail -5; then
    echo "  ERROR: setup.sh failed for ${lab_dir}"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
    bash "${lab_path}/teardown.sh" 2>/dev/null || true
    echo ""
    return
  fi

  # Wait for FRR to settle beyond setup.sh's own sleep.
  sleep 3

  local smoke_out
  smoke_out=$(bash "${lab_path}/smoke.sh" 2>&1)
  local smoke_rc=$?
  echo "$smoke_out"

  if [ "$smoke_rc" -eq 0 ]; then
    TOTAL_PASS=$((TOTAL_PASS+1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL+1))
  fi

  echo "[teardown] Cleaning up ${lab_dir}..."
  bash "${lab_path}/teardown.sh" 2>/dev/null || true

  echo ""
}

# ── Run all labs ──────────────────────────────────────────────────────────────
LABS=(
  lab00-build-your-router
  lab01-unreachable-network
  lab02-l2-vs-l3-vlans
  lab03-hello-bgp
  lab04-transit
  lab05-many-paths
  lab06-route-filtering
  lab07-communities
  lab08-failover
  lab09-underlay-vs-overlay
  lab10-microsegmentation
  lab11-ibgp-fullmesh
  lab12-route-reflector
  lab13-path-selection
  lab14-l3vpn-vrf-leaking
  lab15-operational-bgp
  lab16-ipv6-bgp
)

for lab in "${LABS[@]}"; do
  run_lab "$lab"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════"
echo " SMOKE-ALL SUMMARY"
echo "═══════════════════════════════════════"
echo " Labs passed:  ${TOTAL_PASS}"
echo " Labs failed:  ${TOTAL_FAIL}"
echo " Skipped:      ${SKIPPED}"
echo "═══════════════════════════════════════"

[ "${TOTAL_FAIL}" -eq 0 ]
