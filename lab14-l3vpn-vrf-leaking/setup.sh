#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"
TOPO_PORT=8314

echo "=== Lab 14: L3VPN / VRF Route Leaking + EVPN Symmetric IRB ==="

if ! podman image exists frr:latest 2>/dev/null; then
    echo "ERROR: frr:latest not found. Run lab00-build-your-router/setup.sh first."
    exit 1
fi

if ! modinfo vxlan &>/dev/null 2>&1; then
    echo "WARNING: vxlan kernel module not detected. VXLAN steps may fail."
    echo "         On RHEL/Fedora: sudo modprobe vxlan"
fi

"${LAB_DIR}/teardown.sh" 2>/dev/null || true

echo "Step 1: Creating networks ..."
podman network create lab14-underlay   --subnet 10.0.12.0/30    2>/dev/null || true
podman network create lab14-ce-a1-link --subnet 192.168.10.0/24 2>/dev/null || true
podman network create lab14-ce-a2-link --subnet 192.168.20.0/24 2>/dev/null || true
podman network create lab14-ce-b1-link --subnet 192.168.30.0/24 2>/dev/null || true
podman network create lab14-ce-b2-link --subnet 192.168.40.0/24 2>/dev/null || true

echo "Step 2: Starting PE routers ..."
podman run -d --name lab14-pe1 \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab14-underlay:interface_name=eth0,ip=10.0.12.1 \
    --network lab14-ce-a1-link:interface_name=eth1,ip=192.168.10.1 \
    --network lab14-ce-b1-link:interface_name=eth2,ip=192.168.30.1 \
    -v "${LAB_DIR}/configs/pe1.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab14-pe2 \
    --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab14-underlay:interface_name=eth0,ip=10.0.12.2 \
    --network lab14-ce-a2-link:interface_name=eth1,ip=192.168.20.1 \
    --network lab14-ce-b2-link:interface_name=eth2,ip=192.168.40.1 \
    -v "${LAB_DIR}/configs/pe2.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Step 3: Starting CE hosts ..."
podman run -d --name lab14-ce-a1 \
    --cap-add NET_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab14-ce-a1-link:interface_name=eth0,ip=192.168.10.10 \
    -v "${LAB_DIR}/configs/ce-a1.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab14-ce-a2 \
    --cap-add NET_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab14-ce-a2-link:interface_name=eth0,ip=192.168.20.10 \
    -v "${LAB_DIR}/configs/ce-a2.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab14-ce-b1 \
    --cap-add NET_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab14-ce-b1-link:interface_name=eth0,ip=192.168.30.10 \
    -v "${LAB_DIR}/configs/ce-b1.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

podman run -d --name lab14-ce-b2 \
    --cap-add NET_ADMIN \
    --sysctl net.ipv4.ip_forward=1 \
    --network lab14-ce-b2-link:interface_name=eth0,ip=192.168.40.10 \
    -v "${LAB_DIR}/configs/ce-b2.conf:/etc/frr/frr.conf:ro,z" \
    frr:latest

echo "Waiting 4s for FRR to initialize ..."
sleep 4

echo "Step 4: Configuring VRFs on PE1 ..."
# VRF-A: enslave eth1, re-add IP (enslaving removes the Podman-assigned IP)
podman exec lab14-pe1 ip link add vrf-a type vrf table 100
podman exec lab14-pe1 ip link set vrf-a up
podman exec lab14-pe1 ip link set eth1 master vrf-a
podman exec lab14-pe1 ip addr add 192.168.10.1/24 dev eth1

# VRF-B: enslave eth2, re-add IP
podman exec lab14-pe1 ip link add vrf-b type vrf table 200
podman exec lab14-pe1 ip link set vrf-b up
podman exec lab14-pe1 ip link set eth2 master vrf-b
podman exec lab14-pe1 ip addr add 192.168.30.1/24 dev eth2

echo "Step 5: Configuring VXLAN L3VNI interfaces on PE1 ..."
# L3VNI 100 — VRF-A symmetric IRB VTEP
podman exec lab14-pe1 ip link add vxlan100 type vxlan id 100 dstport 4789 local 10.0.12.1 nolearning
podman exec lab14-pe1 ip link set vxlan100 up
podman exec lab14-pe1 ip link add br100 type bridge
podman exec lab14-pe1 ip link set vxlan100 master br100
podman exec lab14-pe1 ip link set br100 master vrf-a
podman exec lab14-pe1 ip link set br100 up

# L3VNI 200 — VRF-B symmetric IRB VTEP
podman exec lab14-pe1 ip link add vxlan200 type vxlan id 200 dstport 4789 local 10.0.12.1 nolearning
podman exec lab14-pe1 ip link set vxlan200 up
podman exec lab14-pe1 ip link add br200 type bridge
podman exec lab14-pe1 ip link set vxlan200 master br200
podman exec lab14-pe1 ip link set br200 master vrf-b
podman exec lab14-pe1 ip link set br200 up

echo "Step 6: Configuring VRFs on PE2 ..."
podman exec lab14-pe2 ip link add vrf-a type vrf table 100
podman exec lab14-pe2 ip link set vrf-a up
podman exec lab14-pe2 ip link set eth1 master vrf-a
podman exec lab14-pe2 ip addr add 192.168.20.1/24 dev eth1

podman exec lab14-pe2 ip link add vrf-b type vrf table 200
podman exec lab14-pe2 ip link set vrf-b up
podman exec lab14-pe2 ip link set eth2 master vrf-b
podman exec lab14-pe2 ip addr add 192.168.40.1/24 dev eth2

echo "Step 7: Configuring VXLAN L3VNI interfaces on PE2 ..."
podman exec lab14-pe2 ip link add vxlan100 type vxlan id 100 dstport 4789 local 10.0.12.2 nolearning
podman exec lab14-pe2 ip link set vxlan100 up
podman exec lab14-pe2 ip link add br100 type bridge
podman exec lab14-pe2 ip link set vxlan100 master br100
podman exec lab14-pe2 ip link set br100 master vrf-a
podman exec lab14-pe2 ip link set br100 up

podman exec lab14-pe2 ip link add vxlan200 type vxlan id 200 dstport 4789 local 10.0.12.2 nolearning
podman exec lab14-pe2 ip link set vxlan200 up
podman exec lab14-pe2 ip link add br200 type bridge
podman exec lab14-pe2 ip link set vxlan200 master br200
podman exec lab14-pe2 ip link set br200 master vrf-b
podman exec lab14-pe2 ip link set br200 up

echo "Waiting 6s for BGP and EVPN to converge ..."
sleep 6

echo "Step 8: Starting visualization tools ..."
. "${REPO_ROOT}/scripts/start-watchers.sh"

echo ""
echo "Lab 14 is up."
echo "  topology-watch: http://localhost:${TOPO_PORT}"
echo ""
echo "Topology:"
echo "  PE1 (AS65001, 10.0.12.1)  <-eBGP+EVPN->  PE2 (AS65002, 10.0.12.2)"
echo "  VRF-A:  CE-A1 192.168.10.10 (PE1) --- 192.168.20.10 CE-A2 (PE2)"
echo "  VRF-B:  CE-B1 192.168.30.10 (PE1) --- 192.168.40.10 CE-B2 (PE2)"
echo ""
echo "Verify underlay BGP:"
echo "  podman exec lab14-pe1 vtysh -c 'show bgp summary'"
echo ""
echo "Verify EVPN type-5 routes:"
echo "  podman exec lab14-pe1 vtysh -c 'show bgp l2vpn evpn route type prefix'"
echo ""
echo "Follow the README for exercises."
