# Lab 00 — Build Your Router

## Objectives

- Build the FRR container image used by all subsequent labs
- Understand distroless multi-stage container builds
- Learn two debug container usage patterns: namespace join and network observer

## Prerequisites

These labs require Podman 4.x or later with rootless container support.

### macOS

Install [Podman Desktop](https://podman-desktop.io) — it bundles everything you need including the Podman CLI and a Linux VM (Podman Machine) that runs the actual containers.

1. Download and install Podman Desktop from **https://podman-desktop.io**
2. Open Podman Desktop and follow the setup wizard — it initializes a Podman Machine automatically
3. Verify from your terminal:

```bash
podman machine list        # should show a running machine
podman run --rm hello-world
```

> **Apple Silicon (M1/M2/M3/M4):** All labs are tested on arm64. The FRR build in Lab 00 auto-detects your architecture.

> **Minimum resources:** Podman Machine defaults (2 CPU, 2 GB RAM, 100 GB disk) are sufficient for all labs.

### Linux

Podman is available in most distribution package managers. Install it and verify rootless mode works:

**RHEL / Fedora / CentOS Stream:**
```bash
sudo dnf install -y podman
```

**Ubuntu / Debian:**
```bash
sudo apt-get install -y podman
```

**After installing:**
```bash
podman run --rm hello-world    # should succeed without sudo
```

If rootless mode fails (common on fresh installs), follow the [rootless setup guide](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md) — typically requires `/etc/subuid` and `/etc/subgid` entries for your user.

Alternatively, install [Podman Desktop for Linux](https://podman-desktop.io) for a GUI that handles rootless configuration automatically.

### Common check (all platforms)

```bash
podman version              # Podman version 4.x or later
podman info | grep -i root  # should show "rootless: true"
```

If these pass, you're ready. Run `./setup.sh` to build the FRR image.

## Concepts

FRR (Free Range Routing) is an open-source routing daemon suite that implements BGP,
OSPF, IS-IS, and other protocols. In these labs, each "router" is an FRR container
connected to Podman networks that act as point-to-point or broadcast links.

The FRR image is built on an AlmaLinux 9 base — FRR's EPEL packages require the
CodeReady Builder (CRB) repository, which is only available on full AlmaLinux/RHEL,
not on stripped-down UBI images.

### What is Hummingbird?

[Hummingbird](https://hummingbird-project.io/) is a project that publishes minimal,
distroless OCI container images for production use. A distroless image contains only
the application runtime (e.g., Python, Node.js, Go) and its library dependencies —
no shell, no package manager, no cron, no debugging tools. The attack surface is
dramatically reduced: there is nothing for an attacker to execute if they gain code
execution inside the container.

The multi-stage build pattern you see in `containerfiles/frr/Containerfile` is the
standard way to work with distroless bases:

1. **Builder stage** — a full OS image (AlmaLinux, UBI) with `dnf`, `gcc`, etc.
   Install packages, compile, run `npm install`, whatever the build needs.
2. **Runtime stage** — a minimal base (distroless or stripped). `COPY --from=build`
   pulls only the compiled output and runtime libraries. The build tools never make it
   into the shipped image.

Hummingbird provides both flavors: `default` (distroless runtime) and `builder`
(builder-stage base with bash and dnf). You can browse the full catalog and inspect
SBOMs and CVE scans at **https://hummingbird-project.io/**.

Because the runtime image has no shell, you interact with running routers through
`vtysh` (FRR's CLI) via `podman exec`.

## Linux Network Namespaces

[Namespaces](https://en.wikipedia.org/wiki/Linux_namespaces) are a Linux kernel feature
(alongside **cgroups**) that make containers possible. Namespaces partition kernel
resources so that one group of processes sees one set of resources while another group
sees a different set — each group believing it has its own isolated view of the system.
cgroups complement this by controlling *how much* of a resource (CPU, memory, I/O) a
group can use. Together they are the two foundational building blocks of every container
runtime, including Podman and Docker.

There are several namespace types in the Linux kernel (mount, PID, UTS, IPC, user, time)
but the most visible in these labs is the **network namespace**.

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
