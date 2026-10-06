#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
LABS_PARENT="$(cd "${REPO_ROOT}/.." && pwd)"

echo "=== Lab 00: Build Your Router ==="
echo ""

# ── Prerequisite checks ──────────────────────────────────────────────────────

PASS=true

# 1. podman installed
if ! command -v podman &>/dev/null; then
    echo "ERROR: podman not found in PATH."
    echo "       macOS: install Podman Desktop from https://podman-desktop.io"
    echo "       Linux: sudo dnf install podman  (or apt-get install podman)"
    PASS=false
fi

if [ "${PASS}" = true ]; then
    # 2. podman version >= 4
    PODMAN_MAJOR="$(podman version --format '{{.Client.Version}}' 2>/dev/null | cut -d. -f1)"
    if [ -z "${PODMAN_MAJOR}" ] || [ "${PODMAN_MAJOR}" -lt 4 ]; then
        echo "ERROR: Podman 4.x or later required (found: $(podman version --format '{{.Client.Version}}' 2>/dev/null || echo 'unknown'))."
        echo "       Update Podman Desktop from https://podman-desktop.io"
        PASS=false
    fi
fi

if [ "${PASS}" = true ]; then
    # 3. On macOS, verify the Podman machine is running
    if [ "$(uname -s)" = "Darwin" ]; then
        if ! podman machine list --format '{{.Running}}' 2>/dev/null | grep -q "true"; then
            echo "ERROR: No running Podman machine found."
            echo "       Open Podman Desktop and start the machine, or run:"
            echo "         podman machine start"
            PASS=false
        fi
    fi
fi

if [ "${PASS}" = true ]; then
    # 4. Podman is reachable (machine running and socket available)
    if ! podman info &>/dev/null; then
        echo "ERROR: podman info failed — Podman daemon is not reachable."
        echo "       macOS: start the Podman machine in Podman Desktop."
        echo "       Linux: check that /etc/subuid and /etc/subgid have an entry for your user:"
        echo "         grep \"\$(whoami)\" /etc/subuid /etc/subgid"
        echo "         If missing: sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 \$(whoami)"
        PASS=false
    fi
fi

if [ "${PASS}" = true ]; then
    # 5. Sufficient disk space (5 GB minimum for image build)
    # On macOS, check space inside the Podman machine (where the build actually runs).
    # On Linux, check the local filesystem where container storage lives.
    if [ "$(uname -s)" = "Darwin" ]; then
        AVAIL_KB="$(podman machine ssh 'df -k / 2>/dev/null | awk NR==2{print $4}' 2>/dev/null || echo '')"
    elif command -v df &>/dev/null; then
        AVAIL_KB="$(df -k "${HOME}/.local/share/containers" 2>/dev/null | awk 'NR==2 {print $4}' || df -k "${LAB_DIR}" | awk 'NR==2 {print $4}')"
    fi
    if [ -n "${AVAIL_KB:-}" ] && [ "${AVAIL_KB}" -lt 5242880 ]; then
        AVAIL_GB="$(( AVAIL_KB / 1048576 ))"
        echo "WARNING: Only ~${AVAIL_GB} GB free for container storage. The FRR image build needs ~5 GB."
        echo "         Continuing anyway — free up space if the build fails."
    fi
fi

if [ "${PASS}" = false ]; then
    echo ""
    echo "Fix the errors above and re-run ./setup.sh"
    echo "See lab00-build-your-router/README.md ## Prerequisites for setup instructions."
    exit 1
fi

echo "Prerequisites OK."
echo ""

# ─────────────────────────────────────────────────────────────────────────────

ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
echo "Step 1: Building frr:latest from containerfiles/frr/ (platform: linux/${ARCH}) ..."
[ -e "${LABS_PARENT}/labs" ] || ln -sf "${REPO_ROOT}" "${LABS_PARENT}/labs"
podman build --platform "linux/${ARCH}" -t frr:latest "${REPO_ROOT}/containerfiles/frr/"
echo "frr:latest built successfully."
echo ""
echo "Step 2: Pulling debug container (nicolaka/netshoot) ..."
podman pull docker.io/nicolaka/netshoot:latest
echo ""
echo "Done. Verify the build:"
echo "  podman run --rm --entrypoint /usr/libexec/frr/watchfrr frr:latest --version"
echo "  podman run --rm -it docker.io/nicolaka/netshoot bash"
