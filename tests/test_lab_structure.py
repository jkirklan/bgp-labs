import subprocess
from pathlib import Path

import pytest

from labs.lib.lab_config import LabConfig

LABS_ROOT = Path(__file__).parent.parent.parent / "labs"
REQUIRED_README_SECTIONS = [
    "## Objectives",
    "## Concepts",
    "## Topology",
    "## Setup",
    "## Exercises",
    "## Verification",
    "## Troubleshooting",
]

ALL_LABS = [
    "lab00-build-your-router",
    "lab01-unreachable-network",
    "lab02-l2-vs-l3-vlans",
    "lab03-hello-bgp",
    "lab04-transit",
    "lab05-many-paths",
    "lab06-route-filtering",
    "lab07-communities",
    "lab08-failover",
    "lab09-underlay-vs-overlay",
    "lab10-microsegmentation",
    "lab11-ibgp-fullmesh",
    "lab12-route-reflector",
    "lab13-path-selection",
]


@pytest.mark.parametrize("lab_dir", ALL_LABS)
def test_lab_has_required_files(lab_dir):
    path = LABS_ROOT / lab_dir
    assert (path / "README.md").exists(), f"Missing README.md in {lab_dir}"
    assert (path / "setup.sh").exists(), f"Missing setup.sh in {lab_dir}"
    assert (path / "teardown.sh").exists(), f"Missing teardown.sh in {lab_dir}"
    assert (path / "lab.json").exists(), f"Missing lab.json in {lab_dir}"


@pytest.mark.parametrize("lab_dir", ALL_LABS)
def test_lab_json_is_valid(lab_dir):
    path = LABS_ROOT / lab_dir / "lab.json"
    cfg = LabConfig(str(path))
    assert cfg.lab_name == lab_dir, f"lab.json 'lab' should be '{lab_dir}', got '{cfg.lab_name}'"
    assert isinstance(cfg.routers, list)
    assert isinstance(cfg.networks, list)


@pytest.mark.parametrize("lab_dir", ALL_LABS)
def test_setup_sh_valid_bash(lab_dir):
    path = LABS_ROOT / lab_dir / "setup.sh"
    result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
    assert result.returncode == 0, f"bash -n failed for {lab_dir}/setup.sh:\n{result.stderr}"


@pytest.mark.parametrize("lab_dir", ALL_LABS)
def test_teardown_sh_valid_bash(lab_dir):
    path = LABS_ROOT / lab_dir / "teardown.sh"
    result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
    assert result.returncode == 0, f"bash -n failed for {lab_dir}/teardown.sh:\n{result.stderr}"


@pytest.mark.parametrize("lab_dir", ALL_LABS)
def test_readme_has_required_sections(lab_dir):
    path = LABS_ROOT / lab_dir / "README.md"
    content = path.read_text()
    for section in REQUIRED_README_SECTIONS:
        assert section in content, f"Missing '{section}' in {lab_dir}/README.md"


def test_container_names_globally_unique():
    all_names = []
    for lab_dir in ALL_LABS:
        path = LABS_ROOT / lab_dir / "lab.json"
        if not path.exists():
            continue
        cfg = LabConfig(str(path))
        all_names.extend(r["name"] for r in cfg.routers)
    assert len(all_names) == len(set(all_names)), (
        f"Duplicate container names across labs: "
        f"{[n for n in all_names if all_names.count(n) > 1]}"
    )
