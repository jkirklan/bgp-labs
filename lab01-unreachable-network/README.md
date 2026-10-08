# Lab 01 — The Unreachable Network

## Objectives

- Observe why two hosts on separate networks cannot communicate without a router
- Add static routes using `vtysh` to enable reachability
- Understand why static routes don't scale to large networks

## Concepts

### Network Interfaces

A **network interface** is a logical attachment point to a network — either physical
(a NIC) or virtual (a veth, bridge, loopback, VXLAN, etc.). Every interface has:

- A **name** (`eth0`, `lo`, `vxlan0`, …)
- A **MAC address** — a hardware-level identifier unique to that interface
- One or more **IP addresses** with a **[prefix length](../docs/04-reference/subnets-and-cidr.md)** (e.g., `/24`)
- A **state** — UP (active) or DOWN

Inspect all interfaces inside a running container with:

```bash
podman exec lab01-host-a ip addr
```

Example output:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 ...
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    link/ether aa:bb:cc:11:22:33 brd ff:ff:ff:ff:ff:ff
    inet 192.168.101.10/24 brd 192.168.101.255 scope global eth0
```

Reading it line by line:

| Field | Meaning |
|-------|---------|
| `2: eth0:` | Interface index (2) and name (`eth0`) |
| `<BROADCAST,MULTICAST,UP,LOWER_UP>` | Interface flags — `UP` means the interface is enabled; `LOWER_UP` means the physical/virtual link is active |
| `mtu 1500` | Maximum Transmission Unit — the largest single frame this interface will send (bytes) |
| `link/ether aa:bb:cc:11:22:33` | The MAC address of this interface |
| `brd ff:ff:ff:ff:ff:ff` | The broadcast MAC address |
| `inet 192.168.101.10/24` | The IPv4 address and prefix length — `/24` means the first 24 bits are the network, leaving 8 bits for hosts (addresses 192.168.101.1–254) |
| `brd 192.168.101.255` | The broadcast address for this subnet — packets to this address reach all hosts on the subnet |
| `scope global` | This address is reachable from other networks (vs. `scope host` which is loopback-only) |

The loopback interface (`lo`, 127.0.0.1/8) is present in every network namespace and
is used for local communication — packets sent to 127.0.0.1 never leave the host.

### Network Routes

A **routing table** tells the kernel where to send packets. For each destination, it
records which interface to send out of and (for non-connected networks) which next-hop
IP to forward to.

View the kernel routing table:

```bash
podman exec lab01-host-a ip route show
```

Example output (before static routes are added):

```
192.168.101.0/24 dev eth0 proto kernel scope link src 192.168.101.10
```

| Field | Meaning |
|-------|---------|
| `192.168.101.0/24` | The destination network — packets to any address in this range match this entry |
| `dev eth0` | Send out interface `eth0` |
| `proto kernel` | This route was added automatically by the kernel when the IP address was assigned |
| `scope link` | The destination is directly reachable on this link — no next-hop needed |
| `src 192.168.101.10` | When originating a packet to this network, use this source IP |

When a packet arrives destined for `192.168.102.10`, the kernel checks the routing
table. There is no entry for `192.168.102.0/24`, and there is no default route
(`0.0.0.0/0`). The packet is dropped — which is exactly the failure this lab demonstrates.

After adding a static route, the table gains:

```
192.168.102.0/24 via 192.168.101.254 dev eth0 proto static
```

| Field | Meaning |
|-------|---------|
| `via 192.168.101.254` | Forward to this next-hop IP (lab01-router-a's interface on net-a) |
| `proto static` | This route was added manually, not by the kernel or a routing protocol |

**`ip route` vs. `vtysh show ip route`:** `ip route show` reads the Linux kernel
forwarding table directly. `vtysh show ip route` reads FRR's own routing table (the
RIB — Routing Information Base). FRR installs its selected routes into the kernel,
so both views should match. FRR's view adds extra context: how the route was learned
(C/S/B), administrative distance, and age — see [Route Source Codes](../docs/04-reference/routing-source-codes.md).

### ARP — Address Resolution Protocol

> ARP operates at **Layer 2** (Data Link). IP routing operates at **Layer 3** (Network).
> See [Network Layers](../docs/04-reference/network-layers.md) for a full breakdown of
> where each concept in these labs sits in the stack.

IP addresses are logical — they exist in software. To actually deliver a frame on a
local network, the sender needs the destination's **MAC address** (the hardware address
burned into the network interface). **ARP** (Address Resolution Protocol) is how a host
discovers that mapping.

When host-a wants to send a packet to 192.168.101.254 (the router) for the first time:

1. host-a broadcasts on the network: *"Who has 192.168.101.254? Tell 192.168.101.10"*
2. The router sees the broadcast, recognizes its own IP, and replies: *"192.168.101.254 is at aa:bb:cc:dd:ee:ff"*
3. host-a caches that mapping in its **ARP table** and uses the MAC for all subsequent frames

ARP only works within the same subnet — it uses broadcast, which doesn't cross router
boundaries. This is exactly why hosts on different subnets *must* go through a router:
host-a cannot ARP for host-b's MAC across subnets, so it ARPs for the *router's* MAC
instead and sends the packet there.

View the ARP table (neighbor cache) on a running container:

```bash
podman exec lab01-host-a ip neigh show
```

Example output after a successful ping:

```
192.168.101.254 dev eth0 lladdr aa:bb:cc:dd:ee:ff REACHABLE
```

| Field | Meaning |
|-------|---------|
| `192.168.101.254` | The IP address of the neighbor |
| `dev eth0` | Learned via this interface |
| `lladdr aa:bb:cc:dd:ee:ff` | The MAC address that owns this IP |
| `REACHABLE` | The entry was recently confirmed; `STALE` means it hasn't been used recently and will be re-verified on next use; `FAILED` means ARP got no response |

If a host is unreachable on the same subnet, an empty or `FAILED` ARP entry is usually
the first thing to check — it tells you whether the problem is at Layer 2 (ARP/MAC)
or Layer 3 (routing).

Every network interface belongs to a subnet — a broadcast domain where hosts
communicate directly using ARP. When a packet's destination is in a *different*
subnet, the sender must forward it to a **router** that has a path to that subnet.

Without a routing entry, the packet is dropped. This lab makes that failure visible
and shows how static routes repair it — and why you wouldn't want to manage them
manually at any real scale.

**Static routes** are manual entries you add yourself. They work for small,
stable topologies. When you have 1000 prefixes or routes that change dynamically,
you need a routing *protocol* — which is what BGP is.

## Topology

```mermaid
graph LR
    A["lab01-host-a<br>192.168.101.10/24"] <-->|"lab01-net-a<br>192.168.101.0/24"| R["lab01-router-a<br>192.168.101.254 | 192.168.102.254"]
    R <-->|"lab01-net-b<br>192.168.102.0/24"| B["lab01-host-b<br>192.168.102.10/24"]
```

All three containers run FRR. lab01-host-a and lab01-host-b act as end hosts;
lab01-router-a is the forwarder between the two networks.

## Setup

```bash
./setup.sh
```

Three containers start: lab01-host-a, lab01-host-b, lab01-router-a.

Wait 5 seconds for FRR to initialize before running verification commands.

## Exercises

**Exercise 1: Confirm the failure**

```bash
podman exec lab01-host-a ping -c 5 192.168.102.10
```

Expected: `Destination Host Unreachable` or no reply. lab01-host-a has no route to 192.168.102.0/24.

Inspect lab01-host-a's routing table:
```bash
podman exec -it lab01-host-a vtysh -c "show ip route"
```

You'll see a connected route for 192.168.101.0/24 but nothing for 192.168.102.0/24.

**Reading the routing table**

The output of `show ip route` on lab01-host-a (192.168.101.10, on network lab01-net-a: 192.168.101.0/24) looks like this:

```
C>* 192.168.101.0/24 is directly connected, eth0, 00:06:13
```

Breaking it down column by column:

| Field | Meaning |
|-------|---------|
| `C` / `S` / `B` | How the route was learned: **C**onnected, **S**tatic, **B**GP — see [Route Source Codes](../docs/04-reference/routing-source-codes.md) |
| `>` | This is the **selected** (best) route for this prefix |
| `*` | This route is installed in the **FIB** (forwarding table — packets actually use it) |
| `192.168.101.0/24` | The destination **prefix** — written as `network-address/prefix-length`. The `/24` means the first 24 bits are fixed, leaving 8 bits for hosts (256 addresses) |
| `[0/0]` | `[administrative-distance/metric]`. Connected routes have AD=0 — lowest possible, always preferred — see [Administrative Distance and Metric](../docs/04-reference/routing-ad-metric.md) |
| `eth0` | The outgoing interface |
| `00:06:13` | How long this route has been in the table |

What's missing from host-a's table: a route for `192.168.102.0/24`. Without it, host-a
doesn't know where to send packets destined for host-b — they get dropped.

The lab uses isolated internal networks (no bridge gateway), so host-a has only its
connected route. There is no default route. This is intentional — it mirrors how
real networks behave when routers aren't configured to forward traffic.

**Exercise 2: Add only the forward route — and watch it still fail**

Add a route on host-a so it knows how to reach host-b's network:

```bash
podman exec -i lab01-host-a vtysh << 'EOF'
configure terminal
ip route 192.168.102.0/24 192.168.101.254
end
write memory
EOF
```

Confirm the route is installed:

```bash
podman exec -it lab01-host-a vtysh -c "show ip route"
# Should now show: S>* 192.168.102.0/24 [1/0] via 192.168.101.254
```

Now ping again:

```bash
podman exec lab01-host-a ping -c 5 192.168.102.10
```

Expected: still no reply. host-a now knows how to *send* to host-b, but host-b has no
route back to `192.168.101.0/24`. The ICMP reply reaches the router, then gets dropped —
host-b doesn't know where to send a packet destined for 192.168.101.10.

This is the most common real-world mistake: the forward path works but the return path
doesn't, so the connection appears broken from both ends.

**Exercise 3: Add the return route — and watch it succeed**

Add the return route on host-b:

```bash
podman exec -i lab01-host-b vtysh << 'EOF'
configure terminal
ip route 192.168.101.0/24 192.168.102.254
end
write memory
EOF
```

Now ping again:

```bash
podman exec lab01-host-a ping -c 5 192.168.102.10
```

Expected: `!!!!!` (5 successful pings). Both halves of the path are now in place.

**Exercise 4: Think about scale**

lab01-router-a already has both subnets as connected routes. Now imagine 1000 subnets —
you'd need 1000 manual entries on every router. And if one subnet changes, you update
each router by hand. This is why BGP exists.

## Verification

```bash
# Routing tables
podman exec -it lab01-host-a vtysh -c "show ip route"
# Should show: S 192.168.102.0/24 [1/0] via 192.168.101.254

podman exec -it lab01-host-b vtysh -c "show ip route"
# Should show: S 192.168.101.0/24 [1/0] via 192.168.102.254

# Connectivity
podman exec lab01-host-a ping -c 5 192.168.102.10
# Should show: 5/5 packets received
```

## Troubleshooting

**`write memory` warns "Error renaming frr.conf.sav: Device or resource busy":**
Harmless. FRR cannot rename the bind-mounted config file before rewriting it, but the config is written and routes are installed correctly. The `[OK]` line confirms success.

**Ping still fails after adding static routes — packets leave but nothing comes back:**
This is the classic asymmetric routing trap. The forward path works but the return path
doesn't, so ping appears completely broken even though half the job is done.

Check each host's routing table:

```bash
podman exec -it lab01-host-a vtysh -c "show ip route"
podman exec -it lab01-host-b vtysh -c "show ip route"
```

Each host needs a route pointing toward the *other* host's subnet:

- host-a must have `192.168.102.0/24 via 192.168.101.254`
- host-b must have `192.168.101.0/24 via 192.168.102.254`

If one is missing, the sender's packets arrive at the destination just fine — but the
reply gets dropped because the replying host has no route back. tcpdump on the receiver
will show the ICMP echo request arriving; nothing leaves in response. Adding the missing
return route fixes it immediately.

**Debug container to inspect ARP:**
```bash
podman run --rm -it \
  --network container:lab01-host-a \
  docker.io/nicolaka/netshoot bash
# Inside: ip route, ping 192.168.102.10, ip neigh
```

