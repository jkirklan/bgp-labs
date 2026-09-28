import os
import sys
from flask import Flask, jsonify, render_template
from labs.lib.lab_config import LabConfig, LabConfigError
from labs.tools.topology_watch.poller import Poller

app = Flask(__name__)
_poller: Poller | None = None
_config: LabConfig | None = None


def create_app(lab_json_path: str) -> Flask:
    global _poller, _config
    _config = LabConfig(lab_json_path)
    _poller = Poller(_config)
    _poller.start()
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
    lab_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    try:
        create_app(os.path.join(lab_dir, "lab.json"))
    except LabConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    app.run(host="127.0.0.1", port=8080)
