#!/usr/bin/env bash
set -euo pipefail
# Lab 00 has no running containers or networks to remove.
echo "Lab 00 has no running containers. Nothing to tear down."
echo "To remove the built image: podman rmi frr:latest"
