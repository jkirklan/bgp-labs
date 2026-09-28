# BGP Labs

A progressive series of hands-on labs teaching BGP and overlay networking using FRR containers.

## Prerequisites

Build the FRR container image before starting any lab:

```bash
cd labs/lab00-build-your-router && ./setup.sh
```

## Labs

| Lab | Title | Concepts |
|-----|-------|----------|
| [Lab 00](lab00-build-your-router/README.md) | Build Your Router | FRR container image, vtysh basics |
| [Lab 01](lab01-unreachable-network/README.md) | The Unreachable Network | Routing tables, static routes, subnets |
| [Lab 02](lab02-l2-vs-l3-vlans/README.md) | L2 vs L3 VLANs | Broadcast domains, inter-VLAN routing |
| [Lab 03](lab03-hello-bgp/README.md) | Hello BGP | eBGP session setup, OPEN/KEEPALIVE/UPDATE |
| [Lab 04](lab04-transit/README.md) | Transit | next-hop-self, transit AS, multi-hop BGP |
| [Lab 05](lab05-many-paths/README.md) | Many Paths | ECMP, AS path, multipath BGP |
| [Lab 06](lab06-route-filtering/README.md) | Route Filtering | prefix-lists, route-maps, inbound filtering |
| [Lab 07](lab07-communities/README.md) | Communities | BGP communities, policy tagging, CUST-ONLY-OUT |
| [Lab 08](lab08-failover/README.md) | Failover | LOCAL_PREF, primary/backup paths, convergence |

## Tools

Each lab starts topology-watch (topology diagram) and packet-watch (live BGP messages) automatically.

| Tool | Port | Description |
|------|------|-------------|
| topology-watch | 8300–8308 | Live topology diagram (Lab 00 = 8300, Lab 01 = 8301, …) |
| packet-watch | — | Terminal BGP/VXLAN packet viewer (requires tshark) |

## Reference Docs

- [Route Source Codes](../docs/04-reference/routing-source-codes.md) — K, C, S, B flags in `show ip route`
- [Administrative Distance and Metric](../docs/04-reference/routing-ad-metric.md) — what `[AD/metric]` means
