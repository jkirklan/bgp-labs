import json
import os
import pytest
from labs.tools.packet_watch.vxlan_parser import parse_vxlan_packet, UnderlayEvent, OverlayEvent

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def load(name):
    with open(os.path.join(FIXTURES, name)) as f:
        return json.load(f)


def test_returns_both_events():
    result = parse_vxlan_packet(load("tshark_vxlan.json"))
    assert result is not None
    underlay, overlay = result
    assert isinstance(underlay, UnderlayEvent)
    assert isinstance(overlay, OverlayEvent)


def test_underlay_outer_ips():
    underlay, _ = parse_vxlan_packet(load("tshark_vxlan.json"))
    assert underlay.src_ip == "10.0.12.1"
    assert underlay.dst_ip == "10.0.12.2"
    assert underlay.vni == 1001


def test_underlay_inner_macs():
    underlay, _ = parse_vxlan_packet(load("tshark_vxlan.json"))
    assert underlay.inner_src_mac == "aa:bb:cc:dd:ee:01"
    assert underlay.inner_dst_mac == "aa:bb:cc:dd:ee:02"


def test_overlay_inner_ips():
    _, overlay = parse_vxlan_packet(load("tshark_vxlan.json"))
    assert overlay.inner_src_ip == "192.168.10.1"
    assert overlay.inner_dst_ip == "192.168.10.2"
    assert overlay.vni == 1001
    assert overlay.protocol == "ICMP"


def test_non_vxlan_returns_none():
    pkt = {"_source": {"layers": {"ip": {"ip.src": "1.2.3.4"}, "tcp": {}}}}
    assert parse_vxlan_packet(pkt) is None


def test_timestamps_match():
    underlay, overlay = parse_vxlan_packet(load("tshark_vxlan.json"))
    assert underlay.timestamp == overlay.timestamp == 1727290001.0


def test_malformed_returns_none():
    assert parse_vxlan_packet({}) is None
