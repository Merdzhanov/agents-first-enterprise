"""Development & review nodes: LeadDev, Reviewer, CEO Code Review Gate."""
from __future__ import annotations

from typing import Any

from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.workflow import node

from ..agents import LeadDevAgent, ReviewerAgent
from .core import (
    CEO_CODE_REVIEW_GATE,
    LLM_CLIENT,
    MAX_DEV_ROUNDS,
    SESSION_DB,
    _sync_state,
    _tool_ctx,
)


@node(name="leaddev_node")
async def leaddev_node(ctx: Any):
    """Iteratively scaffolds and commits the generated repository files."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    ctx.state["dev_rounds"] = int(ctx.state.get("dev_rounds") or 0) + 1
    result = LeadDevAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    files = (result.data or {}).get("files_committed", [])
    SESSION_DB.append_trace(
        tc.session_id, "LeadDevAgent", "agent",
        f"ADK node: round {ctx.state.get('dev_rounds')} committed {len(files)} files to Git.",
    )
    yield {
        "agent": result.agent_name,
        "status": result.status,
        "files_committed": len(files),
        "dev_round": ctx.state.get("dev_rounds"),
    }


@node(name="code_review_node")
async def code_review_node(ctx: Any):
    """Independent Reviewer Agent critiques the committed code. Findings route
    back to the Lead Dev for rework (bounded); a clean or capped review routes
    to the CEO Code Review Gate."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    result = ReviewerAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    dev_round = int(ctx.state.get("dev_rounds") or 0)
    findings = (result.data or {}).get("findings", [])
    SESSION_DB.append_trace(
        tc.session_id, "ReviewerAgent", "agent",
        f"ADK node: review iteration {ctx.state.get('review_iteration')} — "
        f"{len(findings)} finding(s), verdict '{result.status}'.",
    )
    if result.status == "review_needs_work" and dev_round < MAX_DEV_ROUNDS:
        ctx.route = "rework_code"
        yield {
            "agent": result.agent_name,
            "verdict": "needs_work",
            "findings_count": len(findings),
            "dev_round": dev_round,
            "max_rounds": MAX_DEV_ROUNDS,
        }
        return
    if result.status == "review_needs_work":
        SESSION_DB.append_trace(
            tc.session_id, "ReviewerAgent", "warning",
            f"Dev rework cap reached ({MAX_DEV_ROUNDS}) — forcing remaining findings to CEO for review.",
        )
    # Clean review (or cap reached) → default route → CEO Code Review Gate.
    yield {
        "agent": result.agent_name,
        "verdict": "clean" if result.status == "review_clean" else "needs_work_forced",
        "findings_count": len(findings),
        "dev_round": dev_round,
    }


@node(name="code_review_gate_node", rerun_on_resume=True)
async def code_review_gate_node(ctx: Any):
    """CEO Code Review Gate — human reviews the reviewer's verdict + the
    committed files, then approves or requests further changes (bounded)."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_CODE_REVIEW_GATE in resume:
        payload = resume[CEO_CODE_REVIEW_GATE] or {}
        decision = payload.get("decision", "approve_code")
        if decision == "request_changes":
            dev_round = int(ctx.state.get("dev_rounds") or 0)
            if dev_round < MAX_DEV_ROUNDS:
                ctx.state["rework_feedback"] = str(
                    payload.get("feedback") or "CEO requested changes before proceeding."
                )
                SESSION_DB.append_trace(
                    tc.session_id, "CEO", "ceo",
                    f"CEO requested code changes (round {dev_round}/{MAX_DEV_ROUNDS}).",
                )
                ctx.state["pending_request_input"] = {}
                ctx.route = "rework_code"
                yield {"decision": "request_changes", "route": "leaddev", "dev_round": dev_round}
                return
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "warning",
                f"Code change cap reached ({MAX_DEV_ROUNDS}) — proceeding with current version.",
            )
        else:
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "ceo",
                "CEO approved the reviewed code — proceeding to compliance.",
            )
        ctx.state["pending_request_input"] = {}
        yield {"decision": decision, "route": "compliance"}
        return

    # First pass: present review verdict + findings to CEO.
    review = tc.state.get("code_review", {})
    findings = review.get("findings", [])
    dev_round = int(ctx.state.get("dev_rounds") or 0)
    findings_summary = "\n".join(
        f"- [{f.get('severity', 'info')}] {f.get('file', 'general')}: {f.get('issue', '')}"
        for f in findings[:10]
    )
    prompt = (
        f"Code review is complete (dev round {dev_round}). Verdict: "
        f"{review.get('verdict', 'n/a')}. Findings:\n{findings_summary or '(none)'}\n\n"
        f"Approve the code to proceed, or request specific changes."
    )
    options = [
        {"label": "✅ Approve code", "value": "approve_code"},
        {"label": "🔄 Request changes (add feedback)", "value": "request_changes"},
    ]
    pending = {
        "interrupt_id": CEO_CODE_REVIEW_GATE,
        "state_key": CEO_CODE_REVIEW_GATE,
        "prompt": prompt,
        "options": options,
        "metadata": {"gate": "code_review", "dev_round": dev_round, "verdict": review.get("verdict")},
    }
    ctx.state["pending_request_input"] = pending
    SESSION_DB.append_trace(
        tc.session_id, "ReviewerAgent", "hitl",
        f"ADK node: pausing at CEO Code Review Gate (round {dev_round}).",
    )
    yield AdkRequestInput(
        interrupt_id=CEO_CODE_REVIEW_GATE,
        message=prompt,
        payload={"options": options},
        response_schema=None,
    )
