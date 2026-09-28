import argparse
import os
import sys
import threading
from rich.console import Console
from rich.live import Live
from labs.lib.lab_config import LabConfig, LabConfigError
from labs.lib.podman_helper import get_bridge_iface, check_tshark, PodmanError
from labs.tools.packet_watch.bgp_parser import parse_bgp_packet
from labs.tools.packet_watch.vxlan_parser import parse_vxlan_packet
from labs.tools.packet_watch.capture import start_capture
from labs.tools.packet_watch.display import StandardDisplay, DualPaneDisplay


def main():
    parser = argparse.ArgumentParser(description="Live BGP/VXLAN packet viewer")
    parser.add_argument("--lab-dir", default=".", help="Directory containing lab.json")
    parser.add_argument("--no-keepalives", action="store_true",
                        help="Suppress KEEPALIVE messages from display")
    args = parser.parse_args()

    try:
        check_tshark()
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    lab_json = os.path.join(args.lab_dir, "lab.json")
    try:
        cfg = LabConfig(lab_json)
    except LabConfigError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    stop = threading.Event()
    if cfg.has_overlay:
        _run_dual_pane(cfg, stop, args.no_keepalives)
    else:
        _run_standard(cfg, stop, args.no_keepalives)


def _run_standard(cfg, stop, no_keepalives):
    console = Console()
    display = StandardDisplay(console, no_keepalives)
    threads = []
    for net in cfg.networks:
        try:
            iface = get_bridge_iface(net["name"])
        except PodmanError as e:
            console.print(f"[yellow]Warning: skipping {net['name']}: {e}[/yellow]")
            continue

        def on_packet(pkt, link=net["name"]):
            msg = parse_bgp_packet(pkt)
            if msg:
                display.add_bgp(link, msg)

        t = threading.Thread(target=start_capture,
                             args=(iface, "tcp port 179", [], on_packet, stop), daemon=True)
        t.start()
        threads.append(t)

    console.print(f"[dim]Watching {len(threads)} network(s). Ctrl-C to stop.[/dim]")
    try:
        stop.wait()
    except KeyboardInterrupt:
        stop.set()


def _run_dual_pane(cfg, stop, no_keepalives):
    display = DualPaneDisplay(no_keepalives)
    threads = []
    for net in cfg.networks:
        try:
            iface = get_bridge_iface(net["name"])
        except PodmanError:
            continue
        if net.get("vni"):
            def on_vxlan(pkt, link=net["name"]):
                result = parse_vxlan_packet(pkt)
                if result:
                    display.add_underlay(link, result[0])
                    display.add_overlay(link, result[1])
            t = threading.Thread(target=start_capture,
                                 args=(iface, "udp port 4789",
                                       ["-d", "udp.port==4789,vxlan"],
                                       on_vxlan, stop), daemon=True)
        else:
            def on_bgp(pkt, link=net["name"]):
                msg = parse_bgp_packet(pkt)
                if msg:
                    display.add_underlay(link,
                        type("U", (), {"timestamp": msg.timestamp, "src_ip": msg.src_ip,
                                       "dst_ip": msg.dst_ip, "vni": 0,
                                       "inner_src_mac": "", "inner_dst_mac": ""})())
            t = threading.Thread(target=start_capture,
                                 args=(iface, "tcp port 179", [], on_bgp, stop), daemon=True)
        t.start()
        threads.append(t)

    with Live(display.render(), refresh_per_second=2) as live:
        try:
            while not stop.is_set():
                live.update(display.render())
                stop.wait(0.5)
        except KeyboardInterrupt:
            stop.set()


if __name__ == "__main__":
    main()
