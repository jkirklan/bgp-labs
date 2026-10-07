import json
import os

from labs.tools.packet_watch.bgp_parser import parse_bgp_packet

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def load(name):
    with open(os.path.join(FIXTURES, name)) as f:
        return json.load(f)


def test_parse_open():
    msg = parse_bgp_packet(load("tshark_bgp_open.json"))
    assert msg is not None
    assert msg.msg_type == "OPEN"
    assert msg.src_ip == "10.0.12.1"
    assert msg.dst_ip == "10.0.12.2"
    assert "65001" in msg.detail
    assert "hold:90s" in msg.detail


def test_parse_update_with_prefix_and_path():
    msg = parse_bgp_packet(load("tshark_bgp_update.json"))
    assert msg is not None
    assert msg.msg_type == "UPDATE"
    assert "10.1.0.0/24" in msg.detail
    assert "PATH:65001" in msg.detail


def test_parse_keepalive():
    msg = parse_bgp_packet(load("tshark_bgp_keepalive.json"))
    assert msg is not None
    assert msg.msg_type == "KEEPALIVE"
    assert msg.src_ip == "10.0.12.2"
    assert msg.detail == ""


def test_parse_notification_decode_cease():
    msg = parse_bgp_packet(load("tshark_bgp_notification.json"))
    assert msg is not None
    assert msg.msg_type == "NOTIFICATION"
    assert "Cease" in msg.detail


def test_non_bgp_packet_returns_none():
    pkt = {"_source": {"layers": {"ip": {"ip.src": "1.2.3.4"}, "tcp": {"tcp.dstport": "80"}}}}
    assert parse_bgp_packet(pkt) is None


def test_timestamp_parsed():
    msg = parse_bgp_packet(load("tshark_bgp_open.json"))
    assert abs(msg.timestamp - 1727285001.123) < 0.001


def test_malformed_packet_returns_none():
    assert parse_bgp_packet({}) is None
    assert parse_bgp_packet({"_source": {}}) is None
