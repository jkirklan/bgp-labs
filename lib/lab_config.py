import json
import os


class LabConfigError(Exception):
    pass


class LabConfig:
    def __init__(self, path: str):
        if not os.path.exists(path):
            raise LabConfigError(f"lab.json not found: {path}")
        try:
            with open(path) as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            raise LabConfigError(f"Invalid JSON in {path}: {e}")

        for key in ("lab", "routers", "networks"):
            if key not in data:
                raise LabConfigError(f"Missing required key '{key}' in {path}")

        self.lab_name: str = data["lab"]
        self.routers: list[dict] = data["routers"]
        self.networks: list[dict] = data["networks"]

    @property
    def has_overlay(self) -> bool:
        return any(n.get("vni") is not None for n in self.networks)
