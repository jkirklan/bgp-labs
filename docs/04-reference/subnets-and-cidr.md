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

## Calculating subnet mask from prefix length

A subnet mask is always a block of consecutive `1` bits followed by consecutive `0` bits.
The prefix length tells you how many `1` bits to use. Each octet is 8 bits.

Example: `/26`

```
26 one-bits:  11111111.11111111.11111111.11000000
              └── 8 ──┘└── 8 ──┘└── 8 ──┘└─ 6 ──┘
dotted-decimal:  255    .  255    .  255    .  192
```

The last octet has 6 one-bits: `11000000` = 128 + 64 = **192**.

Each dotted-decimal octet is just 8 bits converted to decimal:

| Binary | Decimal |
|--------|---------|
| 10000000 | 128 |
| 11000000 | 192 |
| 11100000 | 224 |
| 11110000 | 240 |
| 11111000 | 248 |
| 11111100 | 252 |
| 11111110 | 254 |
| 11111111 | 255 |

## Calculating network address, broadcast, and host range

Given an IP address and a subnet mask, three bitwise operations yield everything you need.

**Step 1 — Network address: bitwise AND of IP and mask**

The AND operation keeps only the bits that are `1` in *both* the IP and the mask. This zeros
out all host bits, leaving the network address.

```
IP:       192.168.10.25  →  11000000.10101000.00001010.00011001
Mask /24: 255.255.255.0  →  11111111.11111111.11111111.00000000
AND:                        ────────────────────────────────────
Network:  192.168.10.0   →  11000000.10101000.00001010.00000000
```

**Step 2 — Broadcast address: bitwise OR of network address and inverted mask**

Inverting the mask flips all `1`s to `0`s and `0`s to `1`s — this is the *host mask*.
OR-ing it with the network address sets all host bits to `1`, giving the broadcast address.

```
Network:      192.168.10.0   →  11000000.10101000.00001010.00000000
Inverted mask (host mask):   →  00000000.00000000.00000000.11111111
OR:                             ────────────────────────────────────
Broadcast:    192.168.10.255 →  11000000.10101000.00001010.11111111
```

**Step 3 — Usable host range and count**

```
First host = network address + 1  →  192.168.10.1
Last host  = broadcast - 1        →  192.168.10.254
Count      = 2^(host bits) - 2    →  2^8 - 2 = 254
```

The `-2` subtracts the network address and the broadcast address, which cannot be
assigned to hosts.

### Worked example: 10.0.12.1/30

```
Prefix length:  /30  →  30 one-bits  →  255.255.255.252

IP:        10.0.12.1    →  00001010.00000000.00001100.00000001
Mask /30:  255.255.255.252 → 11111111.11111111.11111111.11111100
AND →
Network:   10.0.12.0    →  00001010.00000000.00001100.00000000

Inverted mask:           →  00000000.00000000.00000000.00000011
OR with network →
Broadcast: 10.0.12.3    →  00001010.00000000.00001100.00000011

Host bits: 32 - 30 = 2
Usable hosts: 2^2 - 2 = 2  (10.0.12.1 and 10.0.12.2)
```

This is why `/30` is used for point-to-point links — exactly two usable addresses, one
per router end.

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
