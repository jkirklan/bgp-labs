#!/usr/bin/env bash
# Smoke test for lab00: verify frr:latest image exists and vtysh responds.
set -euo pipefail
SMOKE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tests/integration/smoke-lib.sh"
source "${SMOKE_LIB}"

echo "=== Lab 00 Smoke Test ==="

if podman image exists frr:latest 2>/dev/null; then
  pass "frr:latest image exists"
else
  fail "frr:latest image not found — run setup.sh first"
  smoke_summary
  exit 1
fi

# Verify vtysh binary responds inside the image. --entrypoint is required:
# docker-start.sh ignores arguments and always execs watchfrr (never exits).
if podman run --rm --entrypoint vtysh frr:latest --help 2>/dev/null | grep -q "Integrated shell for FRR"; then
  pass "vtysh --help identifies FRR"
else
  fail "vtysh --help did not return expected output"
fi

smoke_summary
