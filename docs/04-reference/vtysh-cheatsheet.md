# vtysh Command Reference

`vtysh` is FRR's unified shell. It combines all FRR daemons (bgpd, zebra, staticd, …) into one CLI, similar to Cisco IOS or Junos.

## Entering vtysh

```bash
# From inside a running lab container
podman exec -it lab03-router-a vtysh

# Run a single command without entering the shell
podman exec lab03-router-a vtysh -c "show bgp summary"
```

Once inside, the prompt shows the router hostname:

```
router-a#
```

## Configuration Mode

| Command | What it does |
|---------|-------------|
| `configure terminal` | Enter global configuration mode (prompt: `router-a(config)#`) |
| `end` | Exit back to privileged exec mode |
| `exit` | Exit current mode (one level up) |
| `write memory` | Save running config to `/etc/frr/frr.conf` |
| `do <cmd>` | Run an exec command while in config mode (e.g. `do show bgp summary`) |

## Show Commands

### Routing Table

```
show ip route
```

Shows all routes. First column is the source code (`B` = BGP, `C` = Connected, `K` = Kernel, `S` = Static). See [Route Source Codes](routing-source-codes.md).

```
show ip route vrf <name>
```

Shows the routing table for a specific VRF.

### BGP Summary

```
show bgp summary
```

One line per peer. Key columns:

| Column | Meaning |
|--------|---------|
| Neighbor | Peer IP |
| AS | Peer's AS number |
| MsgRcvd / MsgSent | BGP messages exchanged |
| Up/Down | Session uptime or time since last reset |
| State/PfxRcd | `Establ` = up; if a number, how many prefixes received |

### BGP Prefix Detail

```
show bgp ipv4 unicast <prefix>
show bgp ipv6 unicast <prefix>
show bgp ipv4 unicast          # all IPv4 prefixes
show bgp ipv6 unicast          # all IPv6 prefixes
```

Shows the BGP RIB entry for a prefix: all paths, attributes (AS-path, MED, local-pref, communities), and which path is best (`>`).

### BGP Neighbor Detail

```
show bgp neighbors <peer-ip>
```

Full session state, timers, capabilities, and counters. Useful filters:

```
show bgp neighbors <peer-ip> | grep -E "BGP state|prefixes"
show bgp neighbors <peer-ip> received-routes    # what peer sent
show bgp neighbors <peer-ip> advertised-routes  # what we sent
```

### Interfaces and Links

```
show interface <name>
show interface eth0
```

### Running Configuration

```
show running-config
show running-config | grep route-map
show running-config | grep prefix-list
```

## BGP Configuration

All BGP config lives under `router bgp <ASN>`:

```
configure terminal
router bgp 65001
  bgp router-id 10.0.0.1
  no bgp ebgp-requires-policy        ! required in all lab configs
  neighbor 10.0.12.2 remote-as 65002
  neighbor 10.0.12.2 description router-b
  !
  address-family ipv4 unicast
    network 10.10.10.1/32
    neighbor 10.0.12.2 activate
    neighbor 10.0.12.2 next-hop-self
  exit-address-family
end
write memory
```

### Common Neighbor Options

| Command | Effect |
|---------|--------|
| `neighbor <ip> remote-as <asn>` | Define a peer |
| `neighbor <ip> description <text>` | Label for `show bgp summary` |
| `neighbor <ip> next-hop-self` | Rewrite next-hop to self (iBGP transit) |
| `neighbor <ip> route-reflector-client` | Make this peer an RR client |
| `neighbor <ip> route-map <name> in\|out` | Apply policy on received or sent routes |
| `neighbor <ip> prefix-list <name> in\|out` | Filter prefixes by list |
| `neighbor <ip> maximum-prefix <n> <pct>` | Alert/shut when prefix count exceeds threshold |
| `no neighbor <ip> <option>` | Remove a specific option (leaves the session) |
| `no neighbor <ip>` | Remove the peer entirely |

### Route Maps and Prefix Lists

```
ip prefix-list BOGON-FILTER seq 10 deny 0.0.0.0/0 le 7
ip prefix-list BOGON-FILTER seq 20 permit 0.0.0.0/0 le 32

route-map PREPEND out
  set as-path prepend 65001 65001
route-map PREPEND out

show ip prefix-list BOGON-FILTER
show route-map
```

## Operational Commands

### Clear BGP Sessions

```
clear bgp *                    # reset all sessions (hard reset)
clear bgp * soft               # soft reset all (re-send/re-receive routes)
clear bgp * soft in            # re-receive inbound routes from all peers
clear bgp * soft out           # re-advertise outbound routes to all peers
clear bgp <peer-ip> soft in    # soft reset one peer inbound
clear bgp <peer-ip> soft out   # soft reset one peer outbound
```

Use `soft` whenever possible — it refreshes routes without tearing down the TCP session.

### Reload Config Without Restart

```
podman exec <container> vtysh -c "reload"
```

Reads `/etc/frr/frr.conf` and applies changes incrementally. Equivalent to `service frr reload` but from within vtysh.

### Connectivity Testing

```
ping <destination>             # ICMP ping from router's default table
ping -6 <ipv6-dest>
```

For VRF-aware ping from the host:

```bash
ip vrf exec <vrf-name> ping <destination>
```

## Tips

**Abbreviations** — vtysh accepts unambiguous abbreviations: `sh bgp su` = `show bgp summary`, `conf t` = `configure terminal`.

**Tab completion** — works for all commands.

**Pipe filtering** — `show running-config | grep neighbor` works like a Unix pipe.

**`do` in config mode** — run show commands without exiting: `do show bgp summary`.

**`write memory`** — always run after config changes. The config file (`/etc/frr/frr.conf`) is also bind-mounted from the host, so the file on disk is the source of truth when the container restarts.
