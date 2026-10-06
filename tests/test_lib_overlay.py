import json
import os
import tempfile
from unittest.mock import patch

import pytest

from labs.lib.lab_config import LabConfig
from labs.lib.podman_helper import PodmanError, run_ip_command


class FakeResult:
    def __init__(self, returncode, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def test_run_ip_command_returns_stdout():
    output = "vxlan0    UP    ba:ac:dd:ee:ff:01 <BROADCAST,MULTICAST,UP,LOWER_UP>\n"
    with patch("subprocess.run", return_value=FakeResult(0, output)) as mock_run:
        result = run_ip_command("lab09-vtep-a", "-br link show type vxlan")
    assert "vxlan0" in result
    assert "UP" in result
    args = mock_run.call_args[0][0]
    assert args[:3] == ["podman", "exec", "-i"]
    assert "ip" in args


def test_run_ip_command_raises_on_failure():
    with patch("subprocess.run", return_value=FakeResult(1, "", "No such device")):
        with pytest.raises(PodmanError, match="No such device"):
            run_ip_command("lab09-vtep-a", "-br link show type vxlan")


def test_lab_config_vnis_overlay():
    data = {
        "lab": "lab09-underlay-vs-overlay",
        "routers": [{"name": "lab09-vtep-a", "asn": 65001, "interfaces": ["eth0"]}],
        "networks": [{"name": "lab09-underlay", "subnet": "10.0.12.0/30", "vni": 1001}],
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(data, f)
        path = f.name
    try:
        cfg = LabConfig(path)
        assert cfg.vnis == [1001]
        assert cfg.has_overlay is True
    finally:
        os.unlink(path)


def test_lab_config_vnis_empty_for_bgp_only():
    data = {
        "lab": "lab08-failover",
        "routers": [{"name": "lab08-customer", "asn": 65001, "interfaces": ["eth0"]}],
        "networks": [{"name": "lab08-link", "subnet": "10.0.12.0/30", "vni": None}],
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(data, f)
        path = f.name
    try:
        cfg = LabConfig(path)
        assert cfg.vnis == []
    finally:
        os.unlink(path)


def test_lab_config_vnis_multiple_deduplicated():
    data = {
        "lab": "lab10-microsegmentation",
        "routers": [{"name": "lab10-vtep-a", "asn": 65001, "interfaces": ["eth0"]}],
        "networks": [
            {"name": "lab10-underlay", "subnet": "10.0.12.0/30", "vni": 1001},
            {"name": "lab10-overlay-b", "subnet": "10.0.13.0/30", "vni": 1002},
        ],
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(data, f)
        path = f.name
    try:
        cfg = LabConfig(path)
        assert cfg.vnis == [1001, 1002]
    finally:
        os.unlink(path)
