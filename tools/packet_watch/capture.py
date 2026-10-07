import json
import logging
import subprocess
import threading
from typing import Callable

logger = logging.getLogger(__name__)


def start_capture(
    iface: str,
    filter_expr: str,
    extra_args: list[str],
    callback: Callable[[dict], None],
    stop_event: threading.Event,
):
    logger.debug("Starting capture on %s with filter %r (extra: %s)", iface, filter_expr, extra_args)
    cmd = ["tshark", "-i", iface, "-T", "json", "-l", "-f", filter_expr] + extra_args
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

    def _watcher():
        stop_event.wait()
        proc.terminate()

    watcher = threading.Thread(target=_watcher, daemon=True)
    watcher.start()

    buf = ""
    depth = 0
    try:
        for line in proc.stdout:
            stripped = line.strip()
            if stripped in ("[", "]", ""):
                continue
            buf += line
            depth += stripped.count("{") - stripped.count("}")
            if depth == 0 and buf.strip():
                candidate = buf.strip().rstrip(",")
                try:
                    callback(json.loads(candidate))
                except json.JSONDecodeError as e:
                    logger.debug("JSON decode error on %s: %s", iface, e)
                buf = ""
    finally:
        proc.terminate()
        proc.wait()
        logger.debug("Capture ended on %s", iface)
