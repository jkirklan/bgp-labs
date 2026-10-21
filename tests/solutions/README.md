# Exercise Solutions (CI only)

Reference answers for labs where the student has to configure something before
the lab reaches the state its `smoke.sh` verifies.

- Layout: `tests/solutions/<lab-dir>/<router>.conf`. The file name is the router;
  the container is `<labNN>-<router>` (e.g. `lab03-hello-bgp/router-b.conf`
  → `lab03-router-b`).
- Content: FRR config lines applied to the running router with `vtysh -f`.
- Applied **only** by `tests/integration/smoke-all.sh` (CI), after `setup.sh` and
  before `smoke.sh`. Running a lab's `smoke.sh` yourself tests *your* config.

| Lab | Solution |
|-----|----------|
| lab03-hello-bgp | `router-b.conf`: Exercise 2 (router-b neighbor + `network 192.168.2.0/24`) |
