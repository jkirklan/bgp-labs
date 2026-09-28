import re
import threading
from labs.lib.lab_config import LabConfig
from labs.lib.podman_helper import run_vtysh, PodmanError

BGP_STATES = {"Idle", "Connect", "Active", "OpenSent", "OpenConfirm"}
NEIGHBOR_RE = re.compile(
    r"^(\d+\.\d+\.\d+\.\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\S+\s+(\S+)"
)


class Poller:
    def __init__(self, config: LabConfig, interval: float = 3.0):
        self._config = config
        self._interval = interval
        self._status: dict = {r["name"]: {} for r in config.routers}
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self):
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=5)

    def get_status(self) -> dict:
        with self._lock:
            return {k: dict(v) for k, v in self._status.items()}

    def _run(self):
        while not self._stop.wait(self._interval):
            self._poll_once()

    def _poll_once(self):
        for router in self._config.routers:
            name = router["name"]
            try:
                output = run_vtysh(name, "show bgp summary")
                neighbors = _parse_summary(output)
            except Exception:
                neighbors = {}
            with self._lock:
                self._status[name] = neighbors


def _parse_summary(output: str) -> dict:
    neighbors = {}
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
