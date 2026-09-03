"""Fleet workflow core — shared singletons, gate contracts, and ADK bridges.

Imported by every node module; also re-exported by the package ``__init__``.
"""
from __future__ import annotations

from typing import Any, Dict

from google.adk.events.request_input import RequestInput as AdkRequestInput  # noqa: F401

from ..db import CloudSessionManager, VectorMemoryManager
from ..llm import VertexGeminiClient
from ..tools import ToolContext

# Interrupt IDs (stable contract with the FastAPI layer and the CEO UI).
CEO_DECISION_GATE = "ceo_decision_gate"
CEO_ARCH_REVIEW_GATE = "ceo_arch_review_gate"
CEO_CODE_REVIEW_GATE = "ceo_code_review_gate"
CEO_DEPLOYMENT_GATE = "ceo_deployment_gate"

# Bounded iteration caps — real work requires rounds, but the pipeline must
# never loop forever. When a cap is reached the gate warns and force-continues.
MAX_ARCH_ROUNDS = 3
MAX_DEV_ROUNDS = 4
MAX_COMPLIANCE_ROUNDS = 2
MAX_BUILD_ROUNDS = 3

# Shared singletons (imported by main.py — one instance per process).
SESSION_DB = CloudSessionManager()
LLM_CLIENT = VertexGeminiClient()
MEMORY_DB = VectorMemoryManager()


# ---------------------------------------------------------------------
# ToolContext bridging between ADK node state and the fleet agents
# ---------------------------------------------------------------------
def _tool_ctx(ctx: Any) -> ToolContext:
    """Builds a fleet ToolContext seeded from the ADK node state."""
    tc = ToolContext(session_id=str(ctx.state.get("session_id", "adk_fleet_session")))
    # NOTE: adk.sessions.state.State has no __iter__/keys() — dict(ctx.state)
    # falls back to the legacy obj[0], obj[1]... protocol and raises KeyError.
    # to_dict() is the supported way to snapshot the merged state.
    tc.state = {k: v for k, v in ctx.state.to_dict().items() if not k.startswith("_")}
    return tc


def _sync_state(ctx: Any, tc: ToolContext) -> None:
    """Writes the fleet state back into the ADK session state."""
    for key, value in tc.state.items():
        if not key.startswith("_"):
            ctx.state[key] = value


def _noop(ctx: Any, reason: str) -> Dict[str, Any]:
    ctx.state["fleet_skipped"] = True
    return {"skipped": True, "reason": reason}
