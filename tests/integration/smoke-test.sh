#!/usr/bin/env bash
# Smoke test: clones bgp-labs and verifies lab01 behavioral assumptions.
# Run inside a Lima VM via: limactl shell <vm> -- bash /path/to/smoke-test.sh
set -euo pipefail

REPO_URL="https://github.com/jkirklan/bgp-labs.git"
WORK_DIR="${HOME}/bgp-labs-smoke-$$"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

cleanup() {
  echo ""
  echo "Cleaning up..."
  cd "${WORK_DIR}" 2>/dev/null && {
    bash lab01-unreachable-network/teardown.sh 2>/dev/null || true
  }
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

echo "=== BGP Labs Smoke Test ==="
echo "Host: $(uname -a)"
echo "Podman: $(podman version --format '{{.Client.Version}}' 2>/dev/null || echo unknown)"
echo ""

# ── Clone repo ───────────────────────────────────────────────────────────────
echo "[1/5] Cloning repo..."
git clone --depth=1 "${REPO_URL}" "${WORK_DIR}" 2>&1 | tail -3
cd "${WORK_DIR}"

# ── Lab 00: build FRR image ───────────────────────────────────────────────────
echo ""
echo "[2/5] Building frr:latest (lab00)..."
ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
if podman build --platform "linux/${ARCH}" -t frr:latest containerfiles/frr/ 2>&1 | tail -5; then
  pass "frr:latest built"
else
  fail "frr:latest build failed"
  exit 1
fi

# ── Lab 01: setup ────────────────────────────────────────────────────────────
echo ""
echo "[3/5] Starting lab01..."
bash lab01-unreachable-network/setup.sh
sleep 3

# ── Exercise 1: ping should FAIL ─────────────────────────────────────────────
echo ""
echo "[4/5] Exercise 1 — ping 10.2.0.10 (should fail)..."
if podman exec lab01-host-a ping -c 3 -W 2 10.2.0.10 &>/dev/null; then
  fail "ping SUCCEEDED — should have failed (network isolation broken)"
else
  pass "ping correctly failed (network is isolated)"
fi

# ── Exercise 2: add static routes ────────────────────────────────────────────
echo ""
echo "[5/5] Adding static routes and verifying connectivity..."
podman exec -i lab01-host-a vtysh << 'EOF'
configure terminal
ip route 10.2.0.0/24 10.1.0.254
end
write memory
EOF

podman exec -i lab01-host-b vtysh << 'EOF'
configure terminal
ip route 10.1.0.0/24 10.2.0.254
end
write memory
EOF

sleep 1

if podman exec lab01-host-a ping -c 3 -W 2 10.2.0.10 &>/dev/null; then
  pass "ping SUCCEEDED after static routes (routing works)"
else
  fail "ping FAILED after static routes — routing broken"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==================================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "==================================="
[ "${FAIL}" -eq 0 ]
