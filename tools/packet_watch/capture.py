import json
import logging
import subprocess
import threading
from collections.abc import Callable

logger = logging.getLogger(__name__)


def start_capture(
    iface: str,
    filter_expr: str,
    extra_args: list[str],
    callback: Callable[[dict], None],
    stop_event: threading.Event,
):
    logger.debug("Starting capture on %s filter=%r extra=%s", iface, filter_expr, extra_args)
    cmd = ["tshark", "-i", iface, "-T", "json", "-l", "-f", filter_expr] + extra_args
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def _watcher():
        stop_event.wait()
        proc.terminate()

    def _stderr_reader():
        for line in proc.stderr:
            line = line.strip()
            if line:
                logger.warning("tshark [%s]: %s", iface, line)

    watcher = threading.Thread(target=_watcher, daemon=True)
    watcher.start()
    stderr_thread = threading.Thread(target=_stderr_reader, daemon=True)
    stderr_thread.start()

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
        if proc.returncode not in (0, -15):  # -15 = SIGTERM from terminate()
            logger.warning("tshark exited with code %d on %s", proc.returncode, iface)
        logger.debug("Capture ended on %s", iface)
