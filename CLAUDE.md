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

## Naming and Port Conventions

- Container names: `labXX-<role>` (e.g., `lab03-router-a`) — required for simultaneous lab operation
- Podman networks: `labXX-<name>` (e.g., `lab03-as1-as2-link`)
- topology-watch ports: 8300–8310 (Lab 00=8300, Lab 01=8301, ...) — reserved in homelab port-mapping.md
- Test runner: `python -m pytest labs/tests/ -v` from repo root
- Python env: `.venv/` (uv, Python 3.12)

## Diagrams

Always use Mermaid (`\`\`\`mermaid graph LR`). Never ASCII art for topology diagrams.
