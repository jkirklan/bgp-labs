"""Flask-based topology visualization server for BGP labs."""

from labs.tools.topology_watch.app import create_app

__all__ = ["create_app"]
