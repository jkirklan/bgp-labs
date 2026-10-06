# Route Source Codes

The first column of `show ip route` output shows how FRR learned about each route.

## Codes

| Code | Meaning | Example |
|------|---------|---------|
| `K` | **Kernel** — installed by the OS kernel, not a routing protocol | Interface routes, static routes added via `ip route` outside FRR |
| `C` | **Connected** — a network directly attached to a router interface | `10.0.12.0/30` when eth0 has IP `10.0.12.1/30` |
| `S` | **Static** — manually configured with `ip route` inside FRR | `ip route 10.99.0.0/24 10.0.12.2` |
| `B` | **BGP** — learned from a BGP peer | A prefix advertised by a neighbor with `network` or redistributed |
| `O` | **OSPF** — learned from OSPF (not used in these labs) | — |
| `R` | **RIP** — learned from RIP (not used in these labs) | — |
| `>` | **Selected** — best route for this prefix (used for forwarding decisions) | Appears alongside the source code |
| `*` | **FIB-installed** — route is in the forwarding table (packets actually use it) | Appears alongside `>` |

## Example Output

```
B>* 10.10.10.2/32 [20/0] via 10.0.12.2, eth0, weight 1, 00:01:04
C>* 10.0.12.0/30 is directly connected, eth0, 00:05:22
K>* 0.0.0.0/0 [0/100] via 10.0.12.1, eth0, 00:05:22
```

Reading row 1: `B` = BGP, `>` = selected, `*` = in FIB, prefix `10.10.10.2/32` learned via BGP from `10.0.12.2` out `eth0`, AD/metric `[20/0]`, 1 minute 4 seconds old.

## Where Multiple Sources Compete

When two protocols know the same prefix, the route with the **lowest administrative distance** wins. See [Administrative Distance and Metric](routing-ad-metric.md) for how that tiebreaker works.
