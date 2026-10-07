from dataclasses import dataclass

IP_PROTOCOLS = {"1": "ICMP", "6": "TCP", "17": "UDP", "89": "OSPF"}


@dataclass
class UnderlayEvent:
    timestamp: float
    src_ip: str
    dst_ip: str
    vni: int
    inner_src_mac: str
    inner_dst_mac: str


@dataclass
class OverlayEvent:
    timestamp: float
    inner_src_ip: str
    inner_dst_ip: str
    vni: int
    protocol: str
    detail: str = ""


def parse_vxlan_packet(packet: dict) -> "tuple[UnderlayEvent, OverlayEvent] | None":
    try:
        layers = packet["_source"]["layers"]
        if "vxlan" not in layers:
            return None
        ts = float(layers.get("frame", {}).get("frame.time_epoch", 0))
        ip = layers.get("ip", {})
        vni = int(layers["vxlan"]["vxlan.vni"])
        inner_eth = layers.get("eth_1", layers.get("eth", {}))
        inner_ip = layers.get("ip_1", {})
        protocol = IP_PROTOCOLS.get(inner_ip.get("ip.proto", ""), "unknown")
        return (
            UnderlayEvent(
                timestamp=ts,
                src_ip=ip.get("ip.src", "?"),
                dst_ip=ip.get("ip.dst", "?"),
                vni=vni,
                inner_src_mac=inner_eth.get("eth.src", "?"),
                inner_dst_mac=inner_eth.get("eth.dst", "?"),
            ),
            OverlayEvent(
                timestamp=ts,
                inner_src_ip=inner_ip.get("ip.src", "?"),
                inner_dst_ip=inner_ip.get("ip.dst", "?"),
                vni=vni,
                protocol=protocol,
            ),
        )
    except (KeyError, TypeError, ValueError):
        return None
