import os
import pytest
from unittest.mock import patch
from labs.lib.lab_config import LabConfig
from labs.tools.topology_watch.poller import Poller

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")
ESTABLISHED = open(os.path.join(FIXTURES, "vtysh_bgp_summary.txt")).read()
ACTIVE = open(os.path.join(FIXTURES, "vtysh_bgp_active.txt")).read()


@pytest.fixture
def cfg():
    return LabConfig(os.path.join(FIXTURES, "lab_hello_bgp.json"))


def test_established_session(cfg):
    with patch("labs.tools.topology_watch.poller.run_vtysh", return_value=ESTABLISHED):
        p = Poller(cfg, interval=999)
        p._poll_once()
    neighbor = p.get_status()["router-a"]["bgp"]["10.0.12.2"]
    assert neighbor["state"] == "Established"
    assert neighbor["prefixes_received"] == 1


def test_active_session(cfg):
    with patch("labs.tools.topology_watch.poller.run_vtysh", return_value=ACTIVE):
        p = Poller(cfg, interval=999)
        p._poll_once()
    neighbor = p.get_status()["router-a"]["bgp"]["10.0.12.2"]
    assert neighbor["state"] == "Active"
    assert neighbor["prefixes_received"] == 0


def test_vtysh_failure_yields_empty_dict(cfg):
    with patch("labs.tools.topology_watch.poller.run_vtysh", side_effect=Exception("boom")):
        p = Poller(cfg, interval=999)
        p._poll_once()
    rs = p.get_status()["router-a"]
    assert rs["bgp"] == {}
    assert rs["vxlan"] == {}


def test_initial_status_has_all_routers(cfg):
    p = Poller(cfg, interval=999)
    status = p.get_status()
    assert "router-a" in status
    assert "router-b" in status
