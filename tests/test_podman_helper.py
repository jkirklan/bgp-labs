import os
from unittest.mock import MagicMock, patch

import pytest

from labs.lib.podman_helper import PodmanError, check_tshark, get_bridge_iface, run_vtysh

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")
VTYSH_SUMMARY = open(os.path.join(FIXTURES, "vtysh_bgp_summary.txt")).read()


def test_run_vtysh_returns_stdout():
    result = MagicMock(returncode=0, stdout=VTYSH_SUMMARY, stderr="")
    with patch("subprocess.run", return_value=result):
        output = run_vtysh("router-a", "show bgp summary")
    assert "65001" in output
    assert "10.0.12.2" in output


def test_run_vtysh_container_not_found_raises():
    result = MagicMock(returncode=125, stdout="", stderr="Error: no container with name or id")
    with patch("subprocess.run", return_value=result):
        with pytest.raises(PodmanError, match="not found"):
            run_vtysh("missing", "show bgp summary")


def test_run_vtysh_vtysh_error_raises():
    result = MagicMock(returncode=1, stdout="", stderr="vtysh: cannot connect to zebra")
    with patch("subprocess.run", return_value=result):
        with pytest.raises(PodmanError, match="vtysh"):
            run_vtysh("router-a", "show bgp summary")


def test_get_bridge_iface_returns_name():
    inspect = '[{"plugins":[{"bridge":"podman1"}]}]'
    result = MagicMock(returncode=0, stdout=inspect, stderr="")
    with patch("subprocess.run", return_value=result):
        assert get_bridge_iface("lab03-as1-as2-link") == "podman1"


def test_get_bridge_iface_unknown_network_raises():
    result = MagicMock(returncode=1, stdout="", stderr="network not found")
    with patch("subprocess.run", return_value=result):
        with pytest.raises(PodmanError, match="network"):
            get_bridge_iface("nonexistent")


def test_check_tshark_raises_when_missing():
    with patch("shutil.which", return_value=None):
        with pytest.raises(RuntimeError, match="tshark"):
            check_tshark()


def test_check_tshark_passes_when_present():
    with patch("shutil.which", return_value="/usr/bin/tshark"):
        check_tshark()  # must not raise
