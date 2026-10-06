# Administrative Distance and Metric

Every route in FRR's table carries a `[AD/metric]` field shown in `show ip route` output.

## The Two Numbers

```
B>* 10.10.10.2/32 [20/0] via 10.0.12.2, eth0
                   ^^  ^
                   AD  metric
```

**Administrative Distance (AD)** — a trust ranking assigned to the *source* of the route. When two different protocols both know a route to the same prefix, the one with the lower AD wins and gets installed.

**Metric** — a cost measure *within* a single protocol. BGP calls this MED (Multi-Exit Discriminator). Lower is preferred, but metric only matters between routes from the same source.

## Default Administrative Distances in FRR

| Source | AD | Notes |
|--------|-----|-------|
| Directly connected (`C`) | 0 | Always wins — you can't beat a connected route |
| Static (`S`) | 1 | Wins over any dynamic protocol |
| eBGP (`B`) | 20 | External BGP — the default in all these labs |
| OSPF (`O`) | 110 | Interior gateway protocol |
| iBGP (`B`) | 200 | Internal BGP — lower trust than eBGP |
| Unknown/kernel (`K`) | 254 | Last resort |

## Practical Consequence in the Labs

In Lab 01, host-a has:

```
K>* 0.0.0.0/0 [0/100] via 10.1.0.1, eth0
```

This `K` (kernel) route with AD 0 means the kernel installed a default route pointing at the Podman bridge gateway (`10.1.0.1`), not at `lab01-router-a`. Kernel routes with AD 0 beat everything — even if FRR learned a better route, it would need AD < 0 to override it (impossible). The fix is to delete the kernel default and let the router provide reachability instead.

## When AD Matters

AD determines which protocol wins for a given prefix when two protocols both advertise it. Within a single protocol, metric determines which *path* within that protocol wins. For BGP, path selection uses many attributes (AS path length, MED, local preference, etc.) before metric even applies — see the BGP path selection exercises in Lab 05.
