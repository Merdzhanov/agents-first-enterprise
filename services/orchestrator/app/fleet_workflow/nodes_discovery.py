"""Discovery & planning nodes: Devpost scout + CEO Proposal Gate."""
from __future__ import annotations

from typing import Any

from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.workflow import node

from ..agents import PlannerAgent, ScoutAgent
from .core import (
    CEO_DECISION_GATE,
    LLM_CLIENT,
    MEMORY_DB,
    SESSION_DB,
    _noop,
    _sync_state,
    _tool_ctx,
)


@node(name="scout_node")
async def scout_node(ctx: Any):
    """Deterministic Devpost discovery through the Dart Functional Node.

    If ``active_opportunity`` is already seeded in the ADK session state
    (e.g. via /fleet/generate-proposals), skip discovery and use the
    pre-selected hackathon so the planner generates aligned proposals.
    """
    tc = _tool_ctx(ctx)
    # Pre-seeded opportunity: skip discovery, flow straight to planner.
    if tc.state.get("active_opportunity"):
        SESSION_DB.append_trace(
            tc.session_id, "ScoutAgent", "system",
            "ADK node: active_opportunity pre-seeded — skipping Devpost discovery.",
        )
        yield {"status": "success"}
        return
    SESSION_DB.append_trace(tc.session_id, "ScoutAgent", "dart", "ADK node: invoking Dart Functional Node.")
    scout_result = ScoutAgent().run(tc.state.get("raw_feed", {}), tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(
        tc.session_id, "ScoutAgent",
        "success" if scout_result.status == "success" else "error",
        f"ADK node: discovery {scout_result.status}.",
    )
    # Long-term memory: record every discovered opportunity (never breaks discovery).
    if scout_result.status == "success":
        opp = tc.state.get("active_opportunity") or {}
        try:
            MEMORY_DB.store_memory(
                topic="hackathon_discovery",
                content=(
                    f"Discovered hackathon '{opp.get('title', 'unknown')}' "
                    f"(prize pool {opp.get('prize_pool', 'n/a')}, deadline "
                    f"{opp.get('submission_deadline', 'n/a')}) — {opp.get('url', '')}"
                ),
                metadata={"session_id": tc.session_id, "opportunity_id": opp.get("id")},
            )
        except Exception as mem_err:
            SESSION_DB.append_trace(tc.session_id, "ScoutAgent", "error", f"Memory store failed: {mem_err}")
    yield {"status": scout_result.status}


@node(name="planner_gate_node", rerun_on_resume=True)
async def planner_gate_node(ctx: Any):
    """CEO Proposal Gate — pauses the workflow for the Human-in-the-Loop decision."""
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_DECISION_GATE in resume:
        payload = resume[CEO_DECISION_GATE] or {}
        decision = payload.get("decision", "approve_idea_a")
        SESSION_DB.append_trace(tc.session_id, "CEO", "ceo", f"ADK resume: CEO decision '{decision}'.")
        result = PlannerAgent(llm=LLM_CLIENT).process_ceo_decision(
            decision_choice=decision,
            custom_prompt=payload.get("custom_prompt"),
            git_provider=payload.get("git_provider", "github"),
            custom_repo_name=payload.get("custom_repo_name"),
            context=tc,
        )
        _sync_state(ctx, tc)
        if result.status == "skipped":
            try:
                MEMORY_DB.store_memory(
                    topic="ceo_decision",
                    content="CEO chose skip_implementation — pipeline halted with zero spend.",
                    metadata={"session_id": tc.session_id, "decision": decision},
                )
            except Exception:
                pass
            yield _noop(ctx, "CEO chose skip_implementation")
            return
        SESSION_DB.append_trace(
            tc.session_id, "PlannerAgent", "agent",
            f"ADK node: decision processed, repo '{tc.state.get('git_repo', {}).get('repo_name')}'.",
        )
        try:
            idea = tc.state.get("selected_idea") or {}
            MEMORY_DB.store_memory(
                topic="ceo_decision",
                content=(
                    f"CEO decision '{decision}' selected '{idea.get('title', 'n/a')}' "
                    f"→ provisioning repo '{tc.state.get('git_repo', {}).get('repo_name', 'n/a')}'."
                ),
                metadata={"session_id": tc.session_id, "decision": decision},
            )
        except Exception as mem_err:
            SESSION_DB.append_trace(tc.session_id, "CEO", "error", f"Memory store failed: {mem_err}")
        yield {"decision": decision, "repo_name": tc.state.get("git_repo", {}).get("repo_name")}
        return

    # First execution: synthesize the dual proposal, then pause.
    planner_result = PlannerAgent(llm=LLM_CLIENT).formulate_proposals(
        tc.state.get("active_opportunity", {}), tc
    )
    _sync_state(ctx, tc)
    gate_input = planner_result.request_input
    pending = {
        "interrupt_id": CEO_DECISION_GATE,
        "state_key": CEO_DECISION_GATE,
        "prompt": gate_input.prompt if gate_input else "Approve a prototype proposal?",
        "options": (gate_input.options if gate_input else []) or [],
        "metadata": (gate_input.metadata if gate_input else {}) or {},
    }
    ctx.state["pending_request_input"] = pending
    SESSION_DB.append_trace(tc.session_id, "PlannerAgent", "agent", "ADK node: pausing at CEO Proposal Gate.")
    yield AdkRequestInput(
        interrupt_id=CEO_DECISION_GATE,
        message=pending["prompt"],
        payload={"options": pending["options"]},
        response_schema=None,
    )
