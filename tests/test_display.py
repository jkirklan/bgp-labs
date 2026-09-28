from labs.tools.packet_watch.bgp_parser import BgpMessage
from labs.tools.packet_watch.display import format_bgp_row, StandardDisplay
from unittest.mock import MagicMock


def test_format_bgp_row_contains_required_fields():
    msg = BgpMessage(timestamp=1727285001.0, src_ip="10.0.12.1", dst_ip="10.0.12.2",
                     msg_type="UPDATE", detail="+10.1.0.0/24 PATH:65001")
    row = format_bgp_row("as1-as2-link", msg)
    assert "UPDATE" in row
    assert "10.0.12.1" in row
    assert "as1-as2-link" in row
    assert "10.1.0.0/24" in row


def test_standard_display_suppresses_keepalives():
    console = MagicMock()
    d = StandardDisplay(console, no_keepalives=True)
    msg = BgpMessage(timestamp=0.0, src_ip="a", dst_ip="b", msg_type="KEEPALIVE", detail="")
    d.add_bgp("link", msg)
    console.print.assert_not_called()


def test_standard_display_passes_updates_through():
    console = MagicMock()
    d = StandardDisplay(console, no_keepalives=True)
    msg = BgpMessage(timestamp=0.0, src_ip="a", dst_ip="b", msg_type="UPDATE",
                     detail="+1.2.3.0/24")
    d.add_bgp("link", msg)
    console.print.assert_called_once()
