import atexit
import logging
import os
import signal
import sys
from flask import Flask, jsonify, render_template
from labs.lib.lab_config import LabConfig, LabConfigError
from labs.tools.topology_watch.poller import Poller

logger = logging.getLogger(__name__)

app = Flask(__name__)
_poller: Poller | None = None
_config: LabConfig | None = None


def create_app(lab_json_path: str) -> Flask:
    global _poller, _config
    _config = LabConfig(lab_json_path)
    _poller = Poller(_config)
    _poller.start()
    atexit.register(_poller.stop)
    return app


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/topology")
def topology():
    return jsonify({
        "lab": _config.lab_name,
        "routers": _config.routers,
        "networks": _config.networks,
        "has_overlay": _config.has_overlay,
    })


@app.route("/api/status")
def status():
    return jsonify(_poller.get_status())


if __name__ == "__main__":
    def _sigterm_handler(signum, frame):
        logger.info("Received SIGTERM, shutting down")
        sys.exit(0)

    signal.signal(signal.SIGTERM, _sigterm_handler)

    lab_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    try:
        create_app(os.path.join(lab_dir, "lab.json"))
    except LabConfigError as e:
        logger.error("Lab config error: %s", e)
        sys.exit(1)
    app.run(host="127.0.0.1", port=8080)
