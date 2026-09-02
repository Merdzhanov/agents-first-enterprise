"""Primary entry point for Google ADK 2.6.2 auto-discovery.

Exposing 'root_agent' here allows `adk web` to automatically detect and load
the Enterprise Fleet Workflow without additional CLI flags.

The ``app`` object (with ``is_resumable=True``) is exported alongside
``root_agent`` so the ADK workflow engine checkpoints progress into
``event.actions.agent_state`` and resumes at the interrupted node instead
of replaying the full graph. This is essential for multi-step HITL flows
like the CEO Proposal Gate.
"""
import os
import sys

# Ensure the local directory is in the path for module resolution
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from app.fleet_workflow import FLEET_WORKFLOW as root_agent

# ADK 2.6.2: App with resumable=True enables state checkpointing across
# Human-in-the-Loop interrupts (CEO Proposal Gate, Architecture Review, etc.)
try:
    from google.adk.apps import App, ResumabilityConfig

    app = App(
        name="enterprise_fleet_orchestrator",
        root_agent=root_agent,
        resumability_config=ResumabilityConfig(is_resumable=True),
    )
except ImportError:
    # ADK version does not expose App/ResumabilityConfig — fall back to
    # root_agent-only mode (replay-based resume, works for single interrupts).
    app = None

__all__ = ["root_agent", "app"]