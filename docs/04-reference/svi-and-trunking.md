# SVIs, Trunk Ports, and Router-on-a-Stick

## The problem: routing between VLANs

A VLAN is a broadcast domain — hosts inside it can ARP for each other and
communicate directly at L2. Hosts in *different* VLANs cannot communicate without
a router, because ARP broadcasts don't cross VLAN boundaries.

To route between VLANs, a router needs an IP address (a gateway) reachable from
each VLAN. There are two common ways to wire this up.

## Trunk ports (802.1Q)

A **trunk port** is a switch port that carries multiple VLANs on a single physical
link using **802.1Q** VLAN tagging. Each Ethernet frame gets a 4-byte tag inserted
after the source MAC address identifying which VLAN it belongs to. The receiving
device reads the tag, processes the frame in the correct VLAN context, and strips the
tag before delivering it to the host.

```
Normal (access) port: untagged frames → one VLAN
Trunk port:           tagged frames   → many VLANs on one cable
```

Trunk ports are used between switches, and between a switch and a router that needs
to participate in multiple VLANs without a separate cable for each.

## Router-on-a-stick

**Router-on-a-stick** is a pattern where a single physical link (trunk) connects a
switch to a router. The router creates one logical **subinterface** per VLAN:

```
Switch                           Router
  │  VLAN 10 (tagged)            eth0         ← physical interface (trunk)
  │  VLAN 20 (tagged)            ├─ eth0.10   192.168.10.254/24  ← subinterface for VLAN 10
  └──────────────────────────────┤
                                  └─ eth0.20   192.168.20.254/24  ← subinterface for VLAN 20
```

Each subinterface strips the VLAN tag, processes the frame as if it arrived on a
dedicated interface, and routes accordingly. The router's routing table sees each
subinterface as a directly connected network — just like a physical interface.

On Linux, subinterfaces are created with `ip link add link eth0 name eth0.10 type vlan id 10`.
On Cisco IOS: `interface GigabitEthernet0/0.10` + `encapsulation dot1Q 10`.

## SVIs (Switched Virtual Interfaces)

An **SVI** is the L3 interface associated with a VLAN on a Layer 3 switch or a router.
It provides the gateway IP that hosts in that VLAN send their default-route traffic to.

On a **Layer 3 switch**, SVIs are virtual interfaces (not physical ports) created for
each VLAN:

```
interface Vlan10
 ip address 192.168.10.254 255.255.255.0

interface Vlan20
 ip address 192.168.20.254 255.255.255.0
```

The switch itself does both L2 switching (within each VLAN) and L3 routing (between
VLANs), with no external router needed. This is the most common enterprise pattern for
inter-VLAN routing today.

**Router subinterfaces vs. SVIs — what's the difference?**

| | Router-on-a-stick subinterface | L3 switch SVI |
|---|---|---|
| Where it lives | External router, one physical trunk | Inside the switch |
| Physical cabling | One trunk cable between switch and router | None (internal) |
| Performance | Router CPU handles inter-VLAN traffic | Switch ASIC handles it (much faster) |
| Common use | Small networks, labs, VMs | Enterprise access/distribution layer |

Both achieve the same thing: a gateway IP per VLAN that hosts can route through.

## How lab02 maps to these concepts

Lab02 uses Podman networks, which don't support 802.1Q tagging. Instead of a single
trunk with subinterfaces, `lab02-router-a` gets two separate network attachments:
`eth0` on `lab02-vlan10` and `eth1` on `lab02-vlan20`. Each interface plays the SVI
role for its segment — it holds the gateway IP hosts send their traffic to.

```
Podman approach (lab02):         Real trunk approach:
  eth0 → lab02-vlan10              eth0.10 → VLAN 10  ┐ both on
  eth1 → lab02-vlan20              eth0.20 → VLAN 20  ┘ one physical eth0
```

The routing behavior is identical. The difference is only in how the L2 segments reach
the router — separate cables/interfaces vs. a single tagged trunk.

## Why this matters for VXLAN

The split-subnet problem in Lab 02 Part 3 arises because two physically separate
segments can't share a subnet — ARP doesn't cross the boundary. Trunk ports don't
solve this either (a trunk carries multiple VLANs; it doesn't merge separate physical
segments into one VLAN). The real solution is to extend the L2 domain across an L3
network using a tunnel — which is exactly what VXLAN does in [Lab 09](../../lab09-underlay-vs-overlay/README.md).
