"""Primary entry point for Google ADK 2.6.2 auto-discovery.

Exposing 'root_agent' here allows `adk web` to automatically detect and load
the Enterprise Fleet Workflow without additional CLI flags.
"""
import os
import sys

# Ensure the local directory is in the path for module resolution
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from app.fleet_workflow import FLEET_WORKFLOW as root_agent

__all__ = ["root_agent"]