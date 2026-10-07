import time

from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel

from labs.tools.packet_watch.bgp_parser import BgpMessage
from labs.tools.packet_watch.vxlan_parser import OverlayEvent, UnderlayEvent

MSG_COLORS = {"OPEN": "bright_cyan", "UPDATE": "bright_green",
              "KEEPALIVE": "dim", "NOTIFICATION": "bright_red"}
MAX_ROWS = 60


def format_bgp_row(link: str, msg: BgpMessage) -> str:
    ts = time.strftime("%H:%M:%S", time.localtime(msg.timestamp))
    return f"{ts}  {link:<28}  {msg.src_ip} → {msg.dst_ip:<15}  {msg.msg_type:<14}  {msg.detail}"


class StandardDisplay:
    def __init__(self, console: Console, no_keepalives: bool = False):
        self._console = console
        self._no_keepalives = no_keepalives

    def add_bgp(self, link: str, msg: BgpMessage):
        if self._no_keepalives and msg.msg_type == "KEEPALIVE":
            return
        color = MSG_COLORS.get(msg.msg_type, "white")
        self._console.print(f"[{color}]{format_bgp_row(link, msg)}[/{color}]")


class DualPaneDisplay:
    def __init__(self, no_keepalives: bool = False):
        self._no_keepalives = no_keepalives
        self._underlay: list[str] = []
        self._overlay: list[str] = []
        self._layout = Layout()
        self._layout.split_column(Layout(name="underlay"), Layout(name="overlay"))

    def add_underlay(self, link: str, event: UnderlayEvent):
        ts = time.strftime("%H:%M:%S", time.localtime(event.timestamp))
        row = (f"{ts}  {link:<28}  {event.src_ip} → {event.dst_ip}  "
               f"VNI:{event.vni}  inner:[{event.inner_src_mac}→{event.inner_dst_mac}]")
        self._underlay = (self._underlay + [row])[-MAX_ROWS:]

    def add_overlay(self, link: str, event: OverlayEvent):
        ts = time.strftime("%H:%M:%S", time.localtime(event.timestamp))
        row = (f"{ts}  {link:<28}  {event.inner_src_ip} → {event.inner_dst_ip}  "
               f"{event.protocol}  VNI:{event.vni}")
        self._overlay = (self._overlay + [row])[-MAX_ROWS:]

    def render(self) -> Layout:
        self._layout["underlay"].update(
            Panel("\n".join(self._underlay) or "(no packets yet)",
                  title="[bold blue]UNDERLAY — outer IP/UDP/VXLAN[/bold blue]",
                  border_style="blue"))
        self._layout["overlay"].update(
            Panel("\n".join(self._overlay) or "(no packets yet)",
                  title="[bold green]OVERLAY — inner Ethernet/IP (VXLAN decoded)[/bold green]",
                  border_style="green"))
        return self._layout
