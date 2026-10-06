import json
import shutil
import subprocess


class PodmanError(Exception):
    pass


def run_vtysh(container: str, command: str) -> str:
    result = subprocess.run(
        ["podman", "exec", "-i", container, "vtysh", "-c", command],
        capture_output=True, text=True,
    )
    if result.returncode == 125 or "no container with name" in result.stderr:
        raise PodmanError(f"Container not found: {container}")
    if result.returncode != 0:
        raise PodmanError(f"vtysh failed in {container}: {result.stderr.strip()}")
    return result.stdout


def get_bridge_iface(network_name: str) -> str:
    result = subprocess.run(
        ["podman", "network", "inspect", network_name],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise PodmanError(f"Podman network not found: {network_name}")
    try:
        data = json.loads(result.stdout)
        net = data[0]
        # netavark format (Podman 4.0+)
        if "network_interface" in net:
            return net["network_interface"]
        # legacy CNI format
        return net["plugins"][0]["bridge"]
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        raise PodmanError(f"Could not parse bridge interface for {network_name}: {e}")


def run_ip_command(container: str, args: str) -> str:
    result = subprocess.run(
        ["podman", "exec", "-i", container, "ip"] + args.split(),
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise PodmanError(f"ip command failed in {container}: {result.stderr.strip()}")
    return result.stdout


def check_tshark() -> None:
    if shutil.which("tshark") is None:
        raise RuntimeError(
            "tshark not found. Install it with:\n"
            "  macOS:  brew install wireshark\n"
            "  RHEL:   sudo dnf install wireshark-cli\n"
            "  Ubuntu: sudo apt install tshark"
        )
