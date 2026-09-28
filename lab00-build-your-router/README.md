# Lab 00 — Build Your Router

## Objectives

- Build the FRR container image used by all subsequent labs
- Understand distroless multi-stage container builds
- Learn two debug container usage patterns: namespace join and network observer

## Concepts

FRR (Free Range Routing) is an open-source routing daemon suite that implements BGP,
OSPF, IS-IS, and other protocols. In these labs, each "router" is an FRR container
connected to Podman networks that act as point-to-point or broadcast links.

The FRR image is built from a Hummingbird `core-runtime` base — a distroless image
with no shell, no package manager, and no unnecessary binaries. The multi-stage build
installs FRR in a builder stage, then copies only the required binaries and libraries
into the final image. This keeps the attack surface minimal and the image small.

Because the runtime image has no shell, you interact with running routers through
`vtysh` (FRR's CLI) via `podman exec`.

## Linux Network Namespaces

Every Podman container runs in its own **network namespace** — an isolated copy of the
Linux network stack with its own interfaces, routing table, ARP cache, and firewall rules.
This is what makes containers feel like separate machines on a network.

When you run:
```bash
podman run -d --name lab03-router-a --network lab03-as1-as2-link:ip=10.0.12.1 frr:latest
```

Linux creates a new network namespace for `lab03-router-a`. Inside it: one `eth0`
interface with IP 10.0.12.1, a routing table with only that connected route, and an ARP
cache. Nothing else on your host can see inside it without explicitly entering the namespace.

**Entering a namespace two ways:**

```bash
# 1. Via podman exec — runs a process inside the container's namespace
podman exec -it lab03-router-a vtysh

# 2. Via --network container: — a NEW container shares the existing namespace
podman run --rm -it \
  --network container:lab03-router-a \
  docker.io/nicolaka/netshoot bash
# Inside: you see the same eth0, same IPs, same routing table as lab03-router-a
#         but you have a shell (vtysh doesn't give you one)
```

The second pattern is how the debug container works throughout these labs.
The `--network container:X` flag does not create a new namespace — it joins X's.

**See namespaces on your host:**
```bash
# List all network namespaces (requires root or sudo)
sudo ip netns list

# Each running container shows up here — name is the container's short ID
# You can enter one directly (bypassing Podman):
sudo ip netns exec <ns-id> ip route show
```

**Why this matters for routing labs:**
When two containers share a Podman network (`lab03-as1-as2-link`), Linux creates a
veth pair — a virtual Ethernet cable with one end in each namespace. The Podman bridge
(`br-xxxx` visible on your host via `ip link show type bridge`) connects all the veth
ends on the host side. Run this on your host after any `./setup.sh` to see it:

```bash
ip link show type bridge
ip link show type veth
```

You'll see one bridge per Podman network and one veth pair per container-network attachment.

## Topology

No running topology in this lab — you build the image and explore the debug container.

```
[your host] ──── podman build ──── frr:latest
                                    (FRR daemons: zebra, bgpd, staticd, bfdd)
```

## Setup

```bash
./setup.sh
```

This builds `frr:latest` from `containerfiles/frr/` and pulls the debug container image.
Expected output: a series of build steps ending with "frr:latest built successfully."

## Exercises

**Exercise 1: Inspect the Containerfile**

```bash
cat containerfiles/frr/Containerfile
```

Identify: Which packages does the builder stage install? What does the final stage
copy from the builder? Why is there no `RUN dnf install` in the final stage?

**Exercise 2: Build the image**

```bash
./setup.sh
```

**Exercise 3: Verify FRR works**

```bash
podman run --rm --entrypoint /usr/libexec/frr/watchfrr frr:latest --version
```

Expected output: `vtysh version X.X (FRRRouting)...`

**Exercise 4: Explore the debug container — network namespace join**

```bash
# Start a throwaway FRR container
podman run -d --name test-router \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  frr:latest

# Join its network namespace with the debug container
podman run --rm -it \
  --network container:test-router \
  docker.io/nicolaka/netshoot bash

# Inside the debug container:
ip addr
ip route show
# Exit when done
exit

# Clean up
podman rm -f test-router
```

**Exercise 5: Observer pattern — attach debug container to a network**

```bash
podman network create --subnet 10.99.0.0/24 test-net
podman run --rm -it \
  --network test-net \
  docker.io/nicolaka/netshoot bash
# Inside: ip addr, ping 10.99.0.1, exit
podman network rm test-net
```

## Verification

```bash
podman image exists frr:latest && echo "OK: frr:latest present"
podman run --rm --entrypoint /usr/libexec/frr/watchfrr frr:latest --version
podman image exists docker.io/nicolaka/netshoot && echo "OK: debug image present"
```

Expected: both images present, vtysh version printed.

## Troubleshooting

**Build fails with a platform or architecture error:**
`setup.sh` auto-detects your architecture (`uname -m`) and passes
`--platform linux/amd64` on x86-64 hosts and `--platform linux/arm64`
on Apple Silicon (M1/M2/M3). If you need to override:
```bash
podman build --platform linux/amd64 -t frr:latest containerfiles/frr/
```

**vtysh not found in image:**
The image is distroless — `vtysh` is at `/usr/bin/vtysh`. Run:
```bash
podman run --rm --entrypoint /usr/libexec/frr/watchfrr frr:latest --version
```

**Debug container can't reach test-router:**
Confirm test-router is running: `podman ps`. Confirm you used `--network container:test-router`.
