# BGP Labs — Claude Instructions

## Key Files

- `docs/superpowers/specs/2026-09-25-bgp-labs-design.md` — authoritative spec
- `docs/superpowers/plans/2026-09-25-bgp-labs-tooling.md` — Plan 1 (tooling, DONE)
- `docs/superpowers/plans/2026-09-25-bgp-labs-00-08.md` — Plan 2 (Labs 00-08)
- `labs/lib/lab_config.py` — `LabConfig(path)` loads/validates `lab.json`
- `labs/tests/test_lab_structure.py` — parametrized validator for all labs

## FRR Container Pattern

```bash
podman run -d --name lab03-router-a \
  --cap-add NET_ADMIN --cap-add NET_RAW --cap-add SYS_ADMIN \
  --network lab03-as1-as2-link:ip=10.0.12.1 \
  -v "${LAB_DIR}/configs/router-a.conf:/etc/frr/frr.conf:Z" \
  frr:latest
```

Always: `no bgp ebgp-requires-policy` in FRR BGP configs.

- **Every container that pings needs `--cap-add NET_RAW`.** Podman 6 (macOS machine) doesn't allow unprivileged ICMP by default; without it `ping` fails with `socket: Operation not permitted`.
- **IPv6 neighbors:** add `neighbor <ip> timers connect 5`. The first connect can fail during DAD, and FRR's default retry is 120s.
- **Don't use `192.168.1.0/24` for Podman networks.** It's the default home LAN and collides with the host route (lab03/04/11/12 still do; tracked in Todoist).
- **VXLAN/VRF labs need the host's `vxlan`/`vrf` modules loaded.** Rootless containers can't load them; `setup.sh` warns, CI loads them.

## Smoke Tests (`tests/integration/`)

- `smoke-all.sh` runs every lab: setup → (CI-only solutions) → `smoke.sh` → teardown. It fails if zero labs run.
- **BGP session counts:** use `bgp_established_count` / `bgp6_established_count` (JSON). `show bgp summary` text never prints "Established" for up peers; it shows the prefix count.
- **Route presence:** use `wait_bgp_route` / `wait_bgp6_route` (retry up to 30s). Routes lag session establishment, so one-shot checks flake.
- **Exercise labs:** reference answers live in `tests/solutions/<lab>/<router>.conf`, applied by `smoke-all.sh` only (never by `setup.sh`/`smoke.sh`). See `tests/solutions/README.md`.
- Smoke assertions must match the lab README's Verification section; check the README before trusting a failing smoke test.
- Test a branch on all runners: `gh workflow run smoke-test.yml --ref <branch>` and `gh workflow run smoke-macos.yml --ref <branch>` (pushes to non-main branches don't trigger CI).

## Naming and Port Conventions

- Container names: `labXX-<role>` (e.g., `lab03-router-a`) — required for simultaneous lab operation
- Podman networks: `labXX-<name>` (e.g., `lab03-as1-as2-link`)
- topology-watch ports: 8300–8310 (Lab 00=8300, Lab 01=8301, ...) — reserved in homelab port-mapping.md
- Test runner: `python -m pytest labs/tests/ -v` from repo root
- Python env: `.venv/` (uv, Python 3.12)

## Diagrams

Always use Mermaid (`\`\`\`mermaid graph LR`). Never ASCII art for topology diagrams.
