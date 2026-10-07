import json
import os

import pytest

from labs.lib.lab_config import LabConfig, LabConfigError

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def test_load_valid_config():
    cfg = LabConfig(os.path.join(FIXTURES, "lab_hello_bgp.json"))
    assert cfg.lab_name == "lab03-hello-bgp"
    assert len(cfg.routers) == 2
    assert cfg.routers[0]["name"] == "router-a"
    assert cfg.routers[0]["asn"] == 65001
    assert len(cfg.networks) == 2


def test_has_overlay_false_when_no_vni():
    cfg = LabConfig(os.path.join(FIXTURES, "lab_hello_bgp.json"))
    assert cfg.has_overlay is False


def test_has_overlay_true_when_vni_present():
    cfg = LabConfig(os.path.join(FIXTURES, "lab_overlay.json"))
    assert cfg.has_overlay is True


def test_missing_file_raises():
    with pytest.raises(LabConfigError, match="not found"):
        LabConfig("/nonexistent/lab.json")


def test_invalid_json_raises():
    path = "/tmp/bad_json.json"
    with open(path, "w") as f:
        f.write("{not valid json")
    with pytest.raises(LabConfigError, match="Invalid JSON"):
        LabConfig(path)


def test_missing_routers_key_raises():
    path = "/tmp/no_routers.json"
    with open(path, "w") as f:
        json.dump({"lab": "x", "networks": []}, f)
    with pytest.raises(LabConfigError, match="routers"):
        LabConfig(path)


def test_missing_networks_key_raises():
    path = "/tmp/no_networks.json"
    with open(path, "w") as f:
        json.dump({"lab": "x", "routers": []}, f)
    with pytest.raises(LabConfigError, match="networks"):
        LabConfig(path)
