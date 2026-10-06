import json
import os
import tempfile

import pytest

from labs.tools.topology_watch.poller import _parse_vxlan_links


def test_parse_vxlan_links_up_and_down():
    output = (
        "vxlan0    UP       ba:ac:dd:ee:ff:01 <BROADCAST,MULTICAST,UP,LOWER_UP>\n"
        "vxlan1    DOWN     ba:ac:dd:ee:ff:02 <BROADCAST,MULTICAST>\n"
    )
    result = _parse_vxlan_links(output)
    assert result == {"vxlan0": "UP", "vxlan1": "DOWN"}


def test_parse_vxlan_links_empty():
    assert _parse_vxlan_links("") == {}


def test_parse_vxlan_links_unknown_state():
    output = "vxlan0    UNKNOWN  ba:ac:dd:ee:ff:01 <BROADCAST,MULTICAST>\n"
    result = _parse_vxlan_links(output)
    assert result == {"vxlan0": "UNKNOWN"}


def test_get_status_always_has_bgp_and_vxlan_keys():
    """get_status returns both 'bgp' and 'vxlan' keys for every router."""
    from labs.lib.lab_config import LabConfig
    from labs.tools.topology_watch.poller import Poller

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
        poller = Poller(cfg, interval=9999)
        status = poller.get_status()
        assert "lab08-customer" in status
        assert "bgp" in status["lab08-customer"]
        assert "vxlan" in status["lab08-customer"]
    finally:
        os.unlink(path)


def test_api_status_format_has_bgp_vxlan_for_overlay_lab():
    """get_status structure matches what the frontend expects for overlay labs."""
    from labs.lib.lab_config import LabConfig
    from labs.tools.topology_watch.poller import Poller

    data = {
        "lab": "lab09-underlay-vs-overlay",
        "routers": [
            {"name": "lab09-vtep-a", "asn": 65001, "interfaces": ["eth0"]},
            {"name": "lab09-vtep-b", "asn": 65002, "interfaces": ["eth0"]},
        ],
        "networks": [{"name": "lab09-underlay", "subnet": "10.0.12.0/30", "vni": 1001}],
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(data, f)
        path = f.name
    try:
        cfg = LabConfig(path)
        poller = Poller(cfg, interval=9999)
        status = poller.get_status()
        for router_name in ["lab09-vtep-a", "lab09-vtep-b"]:
            assert router_name in status
            rs = status[router_name]
            assert "bgp" in rs and isinstance(rs["bgp"], dict)
            assert "vxlan" in rs and isinstance(rs["vxlan"], dict)
    finally:
        os.unlink(path)
