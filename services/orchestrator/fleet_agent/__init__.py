"""ADK Web demo entrypoint for the Enterprise Fleet.

Run from `services/orchestrator/`:
    .venv/bin/adk web --port 8083

The ADK CLI discovers this package and expects a `root_agent` variable.
`Runner.agent` accepts `BaseNode`, so the Workflow itself is exposed here —
the CEO gates (RequestInput interrupts) render natively in the ADK Web UI.
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from app.fleet_workflow import FLEET_WORKFLOW  # noqa: E402

root_agent = FLEET_WORKFLOW
