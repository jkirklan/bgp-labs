import logging
import re
import threading
from typing import Any

from labs.lib.lab_config import LabConfig
from labs.lib.podman_helper import PodmanError, run_ip_command, run_vtysh

BGP_STATES = {"Idle", "Connect", "Active", "OpenSent", "OpenConfirm"}
NEIGHBOR_RE = re.compile(
    r"^(\d+\.\d+\.\d+\.\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\S+\s+(\S+)"
)

logger = logging.getLogger(__name__)

_NeighborStatus = dict[str, str | int]  # {"state": str, "prefixes_received": int}


class Poller:
    def __init__(self, config: LabConfig, interval: float = 3.0) -> None:
        self._config: LabConfig = config
        self._interval: float = interval
        self._status: dict[str, dict[str, Any]] = {
            r["name"]: {"bgp": {}, "vxlan": {}} for r in config.routers
        }
        self._lock: threading.Lock = threading.Lock()
        self._stop: threading.Event = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        logger.info("Poller starting (interval=%.1fs, routers=%d)",
                    self._interval, len(self._config.routers))
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        logger.info("Poller stopping")
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=5)

    def get_status(self) -> dict[str, dict[str, Any]]:
        with self._lock:
            return {
                k: {"bgp": dict(v["bgp"]), "vxlan": dict(v["vxlan"])}
                for k, v in self._status.items()
            }

    def _run(self) -> None:
        while not self._stop.wait(self._interval):
            self._poll_once()

    def _poll_once(self) -> None:
        for router in self._config.routers:
            name: str = router["name"]
            try:
                output = run_vtysh(name, "show bgp summary")
                bgp: dict[str, _NeighborStatus] = _parse_bgp_summary(output)
            except Exception as e:
                logger.warning("BGP poll failed for %s: %s", name, e)
                bgp = {}
            vxlan: dict[str, str] = {}
            if self._config.has_overlay:
                try:
                    output = run_ip_command(name, "-br link show type vxlan")
                    vxlan = _parse_vxlan_links(output)
                except Exception as e:
                    logger.warning("VXLAN poll failed for %s: %s", name, e)
            with self._lock:
                self._status[name] = {"bgp": bgp, "vxlan": vxlan}


def _parse_bgp_summary(output: str) -> dict[str, _NeighborStatus]:
    neighbors: dict[str, _NeighborStatus] = {}
    for line in output.splitlines():
        m = NEIGHBOR_RE.match(line.strip())
        if not m:
            continue
        ip, state_or_pfx = m.group(1), m.group(2)
        if state_or_pfx in BGP_STATES:
            neighbors[ip] = {"state": state_or_pfx, "prefixes_received": 0}
        else:
            try:
                neighbors[ip] = {"state": "Established", "prefixes_received": int(state_or_pfx)}
            except ValueError:
                neighbors[ip] = {"state": "Unknown", "prefixes_received": 0}
    return neighbors


def _parse_vxlan_links(output: str) -> dict[str, str]:
    """Parse `ip -br link show type vxlan` output.
    Example line: vxlan0    UP    ba:ac:... <BROADCAST,...>
    Returns: {"vxlan0": "UP", "vxlan1": "DOWN"}
    """
    links: dict[str, str] = {}
    for line in output.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            links[parts[0]] = parts[1]
    return links
