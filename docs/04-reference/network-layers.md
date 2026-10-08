# Network Layers

## The OSI Model

The **OSI model** (Open Systems Interconnection) divides network communication into
seven numbered layers. Each layer has a specific job and hands off to the layer above
or below it. The model is a framework for understanding — real protocols don't always
fit neatly, but it gives you a shared vocabulary for diagnosing problems.

```
Layer 7 — Application   (HTTP, DNS, BGP, SSH)
Layer 6 — Presentation  (TLS/SSL encryption, data encoding)
Layer 5 — Session       (connection lifecycle management)
Layer 4 — Transport     (TCP, UDP — ports, reliability, flow control)
Layer 3 — Network       (IP — addressing and routing across networks)
Layer 2 — Data Link     (Ethernet, MAC addresses, ARP, VLANs, switching)
Layer 1 — Physical      (cables, radio, optical fiber, voltages)
```

In practice, layers 5 and 6 are rarely discussed separately — most modern protocols
collapse them into the application layer. The layers you'll encounter constantly in
these labs are **L2, L3, and L4**, with BGP living at L7.

## Layer 2 — Data Link

**What it does:** Delivers frames between two devices on the *same* network segment
(same broadcast domain). It has no concept of networks or routing — only "who is
directly attached to this wire."

**Addressing:** MAC addresses — 48-bit hardware identifiers (`aa:bb:cc:dd:ee:ff`).
Every network interface has one, burned in at manufacture (though software can
override it).

**Key protocols in these labs:**

| Protocol | Role |
|----------|------|
| Ethernet | The framing format — wraps IP packets in frames with src/dst MAC headers |
| ARP | Resolves an IP address to a MAC address on the local segment |
| VLANs (802.1Q) | Tag frames to create multiple logical segments on one physical wire |

**The hard boundary:** A broadcast sent at L2 reaches every device on the segment and
stops at the router. This is why ARP (which uses broadcast) can't cross subnet
boundaries. It's also why two hosts on different subnets *cannot* communicate
without a router — they can't resolve each other's MAC addresses.

**Tools:**
```bash
ip link show          # list interfaces (L2 view — MAC, state, MTU)
ip neigh show         # ARP table — IP → MAC mappings
```

## Layer 3 — Network

**What it does:** Routes packets between different networks. L3 doesn't care about
the physical wire — it sees only logical addresses and makes hop-by-hop forwarding
decisions to get a packet closer to its destination.

**Addressing:** IP addresses — 32-bit (IPv4) or 128-bit (IPv6) logical addresses
assigned in software. Unlike MAC addresses, IP addresses encode *location*: the
network prefix tells routers which direction to forward.

**Key protocols in these labs:**

| Protocol | Role |
|----------|------|
| IPv4 | The packet format — src/dst IP, TTL, protocol field |
| ICMP | Control messages — ping (`echo request/reply`), `Destination Unreachable`, TTL exceeded |
| Static routes | Manually configured forwarding entries (L3 only, no dynamic exchange) |
| BGP | Dynamic routing protocol that exchanges L3 reachability information between routers |

**The relationship with L2:** Every time an IP packet crosses a router, the L2
frame is *stripped and rebuilt*. The IP packet (L3) remains unchanged; the Ethernet
frame (L2) wraps it fresh for each hop with new src/dst MACs for that link.

```
host-a → router:  src MAC=host-a,  dst MAC=router-eth0   | src IP=host-a, dst IP=host-b
router → host-b:  src MAC=router-eth1, dst MAC=host-b    | src IP=host-a, dst IP=host-b
                  └──── L2 rebuilt each hop ────┘          └── L3 unchanged end-to-end ──┘
```

**Tools:**
```bash
ip addr show          # interface IPs (L3 addresses assigned to L2 interfaces)
ip route show         # routing table
vtysh -c "show ip route"  # FRR routing table (RIB)
ping                  # ICMP echo — tests L3 reachability end-to-end
```

## Layer 4 — Transport

**What it does:** Provides end-to-end communication between processes on two hosts.
L3 gets a packet to the right *machine*; L4 gets it to the right *process* on that
machine using port numbers.

**Key protocols:**

| Protocol | Characteristics |
|----------|----------------|
| TCP | Connection-oriented, reliable, ordered delivery, flow control — used by BGP, HTTP, SSH |
| UDP | Connectionless, best-effort, low overhead — used by DNS, VXLAN encapsulation |

**Port numbers:** A 16-bit number (0–65535) identifies the destination service.
BGP uses TCP port 179. When you see `neighbor X remote-as Y` in FRR config, FRR
opens a TCP connection to port 179 on that neighbor.

**Tools:**
```bash
ss -tnp               # show TCP connections and listening ports
```

## Layer 7 — Application (BGP)

**BGP operates at Layer 7** — it's an application that runs over TCP (L4), which
runs over IP (L3), which runs over Ethernet (L2). When two BGP routers peer:

1. TCP handshake on port 179 (L4)
2. BGP OPEN messages exchanged — negotiate ASN, capabilities (L7)
3. BGP UPDATE messages carry route advertisements (L7 payload)
4. The routes received are installed into the IP routing table (L3)

BGP is unique among routing protocols in using TCP rather than a raw IP or UDP
transport — TCP's reliability guarantees that UPDATE messages are delivered in order
and without loss.

## Overlay Tunneling Protocols

Overlay protocols take traffic from one layer and wrap it inside another layer's
headers so it can travel across a different kind of network. The inner traffic is the
tenant's payload; the outer headers are the underlay transport.

> **What you'll encounter:** If you work with OpenShift or Kubernetes, you'll see
> **Geneve** — it is the default overlay for OVN-Kubernetes (OpenShift's CNI) and is
> used by Antrea and Cilium. The labs in this series use VXLAN because it has simpler
> Linux tooling, but the concepts transfer directly: same encapsulation model, same
> VNI-based segmentation, same BGP EVPN control plane.

### Geneve — Extensible Overlay Encapsulation

Geneve (Generic Network Virtualization Encapsulation, RFC 8926) is the dominant overlay
protocol in modern Kubernetes and OpenShift environments. It uses UDP transport and adds
a **variable-length options header** for carrying arbitrary metadata alongside each frame.

```
Outer:  Ethernet (L2) → IP (L3) → UDP port 6081 (L4) → Geneve header (VNI + options)
Inner:  Ethernet frame (L2) → IP packet (L3) → TCP/UDP (L4) → Application (L7)
```

Key properties:
- **VNI** — 24-bit virtual network identifier; up to 16 million virtual segments
- **Options header** — TLV (type-length-value) fields let the control plane attach
  metadata to each packet: policy tags, flow IDs, timestamps, security labels
- **Used by** OVN-Kubernetes (OpenShift default), Antrea, Cilium (Geneve backend),
  Open vSwitch, and many cloud provider fabrics
- Designed to supersede VXLAN, NVGRE, and STT as a single extensible standard

### VXLAN — L2 over UDP/IP

VXLAN (Virtual eXtensible LAN) takes an L2 Ethernet frame and wraps it inside a
UDP/IP packet so it can travel across an L3 network. It predates Geneve and is
ubiquitous in data center fabrics, storage networks, and network virtualization
platforms (VMware NSX, Linux bridge-based overlays).

```
Outer:  Ethernet (L2) → IP (L3) → UDP port 4789 (L4) → VXLAN header (VNI)
Inner:  Ethernet frame (L2) → IP packet (L3) → TCP/UDP (L4) → Application (L7)
```

Key properties:
- **VNI** (VXLAN Network Identifier) — same 24-bit segment ID as Geneve
- **Fixed 8-byte header** — no options; simpler to implement and inspect
- **Multicast or unicast** underlay — VTEPs learn each other's addresses via BGP EVPN
  (as in Labs 09–10 and 14) or flood-and-learn
- **Stateless** — no connection setup; each packet is independently encapsulated

**Geneve vs. VXLAN at a glance:**

| | Geneve | VXLAN |
|---|---|---|
| UDP port | 6081 | 4789 |
| Header size | Variable (min 8 bytes + options) | Fixed (8 bytes) |
| Metadata | Arbitrary TLV options | None |
| Common in | OpenShift, Kubernetes (OVN-K, Antrea, Cilium) | Data center fabrics, VMware NSX, these labs |

Both protocols create an **overlay** network — from the tenant's perspective, two
containers in the same VNI appear to be on the same Ethernet segment, even if they're
on different physical hosts separated by routers. A Geneve VTEP and a VXLAN VTEP
cannot interoperate directly (different UDP ports and header formats), but the
BGP EVPN control plane used to distribute tunnel endpoint addresses works with both.

## Layer summary for these labs

| Concept | Layer | Why |
|---------|-------|-----|
| MAC address | L2 | Hardware identity on a single segment |
| ARP | L2 | Resolves IP → MAC within a broadcast domain |
| VLAN | L2 | Logical segment isolation on shared wire |
| IP address | L3 | Logical identity, encodes network location |
| Routing table / static routes | L3 | Forwarding decisions across networks |
| ICMP / ping | L3 | Reachability testing |
| BGP route exchange | L7 over L4/L3/L2 | Dynamic distribution of L3 routing information |
| Geneve encapsulation | L2-in-L4/L3 | Extensible overlay — OpenShift/K8s default (OVN-Kubernetes) |
| VXLAN encapsulation | L2-in-L4/L3 | Overlay — data center fabrics, VMware NSX, these labs |
| VRF | L3 | Multiple isolated routing tables on one router |
| TCP port 179 (BGP) | L4 | Transport session for BGP messages |
