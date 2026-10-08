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

## VXLAN — Tunneling L2 over L3

VXLAN (Virtual eXtensible LAN) is a good example of **layer encapsulation**: it takes
an L2 Ethernet frame and wraps it inside a UDP/IP packet so it can travel across an L3
network. The inner frame is the tenant's traffic; the outer IP/UDP headers are the
underlay transport.

```
Outer:  Ethernet (L2) → IP (L3) → UDP port 4789 (L4) → VXLAN header (VNI)
Inner:  Ethernet frame (L2) → IP packet (L3) → TCP/UDP (L4) → Application (L7)
```

This is called an **overlay** network — it creates a virtual L2 segment stretched
across an L3 underlay. From the tenant's perspective, two containers in the same
VXLAN VNI appear to be on the same Ethernet segment, even if they're on different
physical hosts separated by routers.

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
| VXLAN encapsulation | L2-in-L4/L3 | Overlay — stretch L2 segments across L3 fabric |
| VRF | L3 | Multiple isolated routing tables on one router |
| TCP port 179 (BGP) | L4 | Transport session for BGP messages |
