from dataclasses import dataclass

BGP_TYPES = {"1": "OPEN", "2": "UPDATE", "3": "NOTIFICATION", "4": "KEEPALIVE"}

NOTIFICATION_ERRORS = {
    "1": "Message Header Error",
    "2": "OPEN Message Error",
    "3": "UPDATE Message Error",
    "4": "Hold Timer Expired",
    "5": "Finite State Machine Error",
    "6": "Cease",
}


@dataclass
class BgpMessage:
    timestamp: float
    src_ip: str
    dst_ip: str
    msg_type: str
    detail: str


def parse_bgp_packet(packet: dict) -> "BgpMessage | None":
    try:
        layers = packet["_source"]["layers"]
        if "bgp" not in layers:
            return None
        bgp = layers["bgp"]
        ip = layers.get("ip", {})
        frame = layers.get("frame", {})
        msg_type = BGP_TYPES.get(bgp.get("bgp.type", ""))
        if not msg_type:
            return None
        return BgpMessage(
            timestamp=float(frame.get("frame.time_epoch", 0)),
            src_ip=ip.get("ip.src", "?"),
            dst_ip=ip.get("ip.dst", "?"),
            msg_type=msg_type,
            detail=_build_detail(msg_type, bgp),
        )
    except (KeyError, TypeError, ValueError):
        return None


def _build_detail(msg_type: str, bgp: dict) -> str:
    if msg_type == "OPEN":
        return f"ASN:{bgp.get('bgp.open.as', '?')} hold:{bgp.get('bgp.open.holdtime', '?')}s"
    if msg_type == "UPDATE":
        parts = []
        if prefix := bgp.get("bgp.update.nlri_prefix"):
            parts.append(f"+{prefix}")
        if withdrawn := bgp.get("bgp.update.withdrawn_prefix"):
            parts.append(f"-{withdrawn}")
        if path := bgp.get("bgp.path_attribute.as_path"):
            parts.append(f"PATH:{path}")
        return " ".join(parts) if parts else "(empty)"
    if msg_type == "NOTIFICATION":
        code = bgp.get("bgp.notify.major_error", "?")
        return NOTIFICATION_ERRORS.get(code, f"error code {code}")
    return ""  # KEEPALIVE
