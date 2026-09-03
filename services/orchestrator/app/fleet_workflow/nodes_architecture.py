"""Architecture nodes: synthesis + CEO Architecture Review Gate."""
from __future__ import annotations

from typing import Any

from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.workflow import node

from ..agents import ArchitectAgent
from .core import (
    CEO_ARCH_REVIEW_GATE,
    LLM_CLIENT,
    MAX_ARCH_ROUNDS,
    SESSION_DB,
    _sync_state,
    _tool_ctx,
)


@node(name="architect_node")
async def architect_node(ctx: Any):
    """Synthesizes the Cloud Native architecture for the approved idea."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    ctx.state["arch_rounds"] = int(ctx.state.get("arch_rounds") or 0) + 1
    result = ArchitectAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    arch_title = (result.data or {}).get("title", "architecture")
    SESSION_DB.append_trace(
        tc.session_id, "ArchitectAgent", "agent",
        f"ADK node: architecture round {ctx.state.get('arch_rounds')} synthesized — '{arch_title}'.",
    )
    yield {"agent": result.agent_name, "status": result.status, "arch_round": ctx.state.get("arch_rounds")}


@node(name="arch_review_gate_node", rerun_on_resume=True)
async def arch_review_gate_node(ctx: Any):
    """CEO Architecture Review Gate — human checks the design before any code
    is written. 'revise' routes back to the architect (bounded rework loop)."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_ARCH_REVIEW_GATE in resume:
        payload = resume[CEO_ARCH_REVIEW_GATE] or {}
        decision = payload.get("decision", "approve_architecture")
        if decision == "revise_architecture":
            round_no = int(ctx.state.get("arch_rounds") or 0)
            if round_no < MAX_ARCH_ROUNDS:
                ctx.state["arch_revise_feedback"] = str(payload.get("feedback") or "")
                SESSION_DB.append_trace(
                    tc.session_id, "CEO", "ceo",
                    f"CEO requested architecture revision round {round_no}/{MAX_ARCH_ROUNDS}.",
                )
                ctx.route = "revise_arch"
                yield {"decision": "revise_architecture", "route": "architect", "arch_round": round_no}
                return
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "warning",
                f"Architecture revision cap reached ({MAX_ARCH_ROUNDS}) — forcing through current design.",
            )
        else:
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "ceo",
                "CEO approved the architecture — proceeding to implementation.",
            )
        ctx.state["pending_request_input"] = {}
        yield {"decision": decision, "route": "leaddev"}
        return

    # First pass: present the architecture and pause for human approval.
    arch = tc.state.get("architecture_spec", {})
    arch_summary = {
        "title": arch.get("title", "n/a"),
        "compute_target": arch.get("compute_target", "n/a"),
        "components": [c.get("name") for c in arch.get("components", [])],
        "diagram_mermaid": (arch.get("diagram_mermaid") or "")[:800],
    }
    round_no = int(ctx.state.get("arch_rounds") or 0)
    prompt = (
        f"Review the proposed architecture (round {round_no}). "
        f"Approve it to start implementation, or request a revision with feedback."
    )
    options = [
        {"label": "✅ Approve architecture", "value": "approve_architecture"},
        {"label": "🔄 Revise architecture (add feedback)", "value": "revise_architecture"},
    ]
    pending = {
        "interrupt_id": CEO_ARCH_REVIEW_GATE,
        "state_key": CEO_ARCH_REVIEW_GATE,
        "prompt": prompt,
        "options": options,
        "metadata": {"gate": "architecture_review", "arch_round": round_no, "architecture": arch_summary},
    }
    ctx.state["pending_request_input"] = pending
    SESSION_DB.append_trace(
        tc.session_id, "ArchitectAgent", "hitl",
        f"ADK node: pausing at CEO Architecture Review Gate (round {round_no}).",
    )
    yield AdkRequestInput(
        interrupt_id=CEO_ARCH_REVIEW_GATE,
        message=prompt,
        payload={"options": options},
        response_schema=None,
    )
