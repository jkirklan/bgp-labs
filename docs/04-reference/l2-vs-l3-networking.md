# L2 vs L3 Networking

Two layers of the network stack handle communication in completely different ways.
Understanding the boundary between them explains why routers exist, why ARP fails
across subnets, and why VXLAN is needed to extend L2 across a routed network.

## Layer 2 — The Local Segment

**Layer 2 (data link layer)** is responsible for delivering frames between devices
on the **same physical or virtual segment** — the same switch, VLAN, or (in these
labs) the same Podman network.

Key properties:
- Addressing is by **MAC address** (e.g., `52:54:00:ab:cd:ef`) — a 48-bit hardware
  identifier assigned to each interface
- Communication happens via **broadcast** — ARP requests flood the entire segment
- There is **no concept of distance** — every host on the segment is one hop away
- Frames cannot leave the segment without a router

### ARP — How L2 Finds a MAC Address

When a host wants to send a packet to an IP address, it first needs the destination's
MAC address. It gets it with **ARP (Address Resolution Protocol)**:

1. Sender broadcasts: *"Who has 192.168.10.11? Tell 192.168.10.10."*
2. Every host on the segment receives the broadcast
3. The host with that IP replies: *"192.168.10.11 is at `52:54:00:ab:cd:ef`."*
4. Sender caches the mapping and sends the frame directly

If the destination IP is **not on the same segment**, the ARP broadcast gets no
answer from that destination — it never arrives there. The sender must use its
**default gateway** (a router interface on the same segment) instead.

## Layer 3 — Routing Between Segments

**Layer 3 (network layer)** is responsible for delivering packets **between
subnets** across one or more routers.

Key properties:
- Addressing is by **IP address** (e.g., `192.168.10.10/24`) — a 32-bit logical
  address assigned by configuration
- The `/24` **prefix length** defines the subnet — devices sharing the same prefix
  bits are on the same logical network
- Packets travel from router to router, each hop decrementing TTL and re-framing
  with new L2 headers
- Routers make forwarding decisions by looking up the destination IP in a
  **routing table**

### What a Router Does

A router has **multiple interfaces**, each on a different subnet. When a packet
arrives on one interface destined for a different subnet, the router:

1. Looks up the destination IP in its routing table
2. Finds the next-hop (another router or the destination subnet)
3. Sends the packet out the appropriate interface — with a new L2 frame for that segment

The original L2 frame is discarded at each hop. The IP packet persists end-to-end.

## The L2 / L3 Boundary

| | Layer 2 | Layer 3 |
|--|---------|---------|
| **Address** | MAC (48-bit, hardware) | IP (32-bit, configured) |
| **Scope** | Same segment only | Cross-subnet, any distance |
| **Discovery** | ARP broadcast | Routing table lookup |
| **Forwarding device** | Switch | Router |
| **Frame lifetime** | One hop | New frame per hop |

**The key rule:** ARP is L2. It only works within a broadcast domain. A host can
only ARP for addresses in its own subnet. For everything else, the packet goes to
the default gateway.

## The Split-Subnet Problem

What happens when two hosts are *supposed* to be on the same subnet (`192.168.10.0/24`)
but are physically (or virtually) separated — on different switches, racks, or
data center locations?

- Host A broadcasts an ARP for Host B's IP
- The broadcast is confined to Host A's local segment
- Host B never receives it
- The ping fails — not because IP routing is wrong, but because **ARP can't cross
  the segment boundary**

A router cannot fix this: routing is between subnets, not within one. The only
solution is to **extend the L2 domain** across the physical gap.

**VXLAN** (Lab 09) solves this by encapsulating L2 frames inside UDP packets.
The inner frame stays in the same broadcast domain (same VNI); the outer packet
is routed normally across the underlay. From the hosts' perspective, they are on
the same L2 segment — ARP works, MAC addresses resolve — but the frames travel
across a routed network.

## Lab References

| Lab | What you observe |
|-----|-----------------|
| [Lab 02](../../lab02-l2-vs-l3-vlans/README.md) | Same-subnet ping (ARP works); cross-subnet ping requires a router; split-subnet failure |
| [Lab 09](../../lab09-underlay-vs-overlay/README.md) | VXLAN extends L2 across a BGP-routed underlay |
| [Lab 10](../../lab10-microsegmentation/README.md) | VRF isolates L3 routing tables per tenant on top of VXLAN L2 |
