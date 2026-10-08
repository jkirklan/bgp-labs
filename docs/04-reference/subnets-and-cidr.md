# Subnets and CIDR Notation

## What is a subnet?

A **subnet** (subnetwork) is a contiguous range of IP addresses that share a common
network prefix. Hosts on the same subnet can communicate directly via ARP and Layer 2
switching — no router needed. Hosts on *different* subnets must go through a router.

## Subnet masks

Historically, the boundary between the network portion and the host portion of an IP
address was expressed as a **subnet mask** — a 32-bit number written in dotted-decimal.
Every `1` bit in the mask marks a *network* bit; every `0` bit marks a *host* bit.

```
IP address:    192.168.10.25
Subnet mask:   255.255.255.0
               ─────────────────────────────────────
               11111111.11111111.11111111.00000000
               │←───── network (24 bits) ────────→│←hosts→│
```

The network address (all host bits set to 0) is `192.168.10.0`.
The broadcast address (all host bits set to 1) is `192.168.10.255`.
Usable host addresses run from `192.168.10.1` to `192.168.10.254` (254 hosts).

Common masks and the number of usable host addresses:

| Mask | Binary host bits | Usable hosts |
|------|-----------------|--------------|
| 255.0.0.0 | 24 bits | 16,777,214 |
| 255.255.0.0 | 16 bits | 65,534 |
| 255.255.255.0 | 8 bits | 254 |
| 255.255.255.128 | 7 bits | 126 |
| 255.255.255.192 | 6 bits | 62 |
| 255.255.255.224 | 5 bits | 30 |
| 255.255.255.240 | 4 bits | 14 |
| 255.255.255.252 | 2 bits | 2 |

## CIDR notation (prefix length)

**CIDR** (Classless Inter-Domain Routing) replaces the dotted-decimal mask with a
**prefix length** — a single number after a `/` that counts how many leading bits
are the network portion. It is compact, unambiguous, and universally used today.

```
192.168.10.25/24
              ↑
              24 network bits → subnet mask 255.255.255.0
```

The two notations are equivalent:

| CIDR | Subnet mask | Host bits | Usable hosts |
|------|-------------|-----------|--------------|
| /8 | 255.0.0.0 | 24 | 16,777,214 |
| /16 | 255.255.0.0 | 16 | 65,534 |
| /24 | 255.255.255.0 | 8 | 254 |
| /25 | 255.255.255.128 | 7 | 126 |
| /26 | 255.255.255.192 | 6 | 62 |
| /27 | 255.255.255.224 | 5 | 30 |
| /28 | 255.255.255.240 | 4 | 14 |
| /30 | 255.255.255.252 | 2 | 2 |
| /32 | 255.255.255.255 | 0 | 1 (host route) |

`/30` (4 addresses, 2 usable) is common for point-to-point router links — one address
per router end, network address, broadcast. `/32` is a host route — it matches exactly
one IP and has no broadcast or network address.

## Reading an IP address in context

```
ip addr output:    inet 10.0.12.1/30
```

This tells you:
- The interface IP is `10.0.12.1`
- The subnet is `10.0.12.0/30` (4 addresses: .0 network, .1 and .2 usable, .3 broadcast)
- `10.0.12.2` is the only other usable address — the far end of this point-to-point link

```
ip route output:   10.0.12.0/30 dev eth0 proto kernel scope link src 10.0.12.1
```

This connected route covers the entire `/30` block. Any packet destined for `10.0.12.0`–`10.0.12.3`
matches this entry and is sent directly out `eth0`.

## Why /30 for router-to-router links?

In these labs, every pair of connected routers uses a `/30` subnet. It's the tightest
prefix that still gives two usable addresses — one for each router end. Using a `/24`
would waste 252 addresses on a link that only ever has two devices.
