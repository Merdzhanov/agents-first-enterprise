"""Background pipeline tasks shared by the FastAPI endpoints.

Kept in a dedicated module so ``main.py`` stays under the 400-line budget;
both tasks are ``async`` and awaited natively on the ASGI event loop (no
``asyncio.run``) to avoid event-loop collisions with shared async resources.
"""
from __future__ import annotations

import asyncio
from typing import Optional

from .agents import ArchitectAgent, LeadDevAgent, MarketingAgent
from .api_models import CeoDecisionRequest
from .fleet_workflow import (
    CEO_DECISION_GATE,
    CEO_DEPLOYMENT_GATE,
    LLM_CLIENT,
    SESSION_DB,
    resume_fleet_run,
)
from .tools import ToolContext


async def execute_ceo_pipeline_background_manual(
    req: CeoDecisionRequest, context: ToolContext
) -> None:
    """Background task for Manual mode (blocking agents via executor threads)."""
    await asyncio.to_thread(ArchitectAgent(llm=LLM_CLIENT).run, context)
    SESSION_DB.append_trace(
        req.session_id, "ArchitectAgent", "agent", "Synthesized Cloud Native architecture."
    )

    dev = LeadDevAgent(llm=LLM_CLIENT)
    await asyncio.to_thread(dev.run, context)
    SESSION_DB.append_trace(req.session_id, "LeadDevAgent", "agent", "Committed files to Git.")

    await asyncio.to_thread(MarketingAgent(llm=LLM_CLIENT).run, context)
    SESSION_DB.append_trace(
        req.session_id, "MarketingAgent", "success", "Assembled Devpost package."
    )

    SESSION_DB.save_session(req.session_id, "completed", "MarketingAgent", context.state)


async def background_runner_resume(
    session_id: str,
    decision: str,
    custom_prompt: Optional[str],
    git_provider: str = "github",
    custom_repo_name: Optional[str] = None,
    feedback: Optional[str] = None,
) -> None:
    """Background task for ADK Runner mode (real Runner resume phase 2)."""
    try:
        state, pending = await resume_fleet_run(
            session_id=session_id,
            decision_payload={
                "decision": decision,
                "custom_prompt": custom_prompt,
                "git_provider": git_provider,
                "custom_repo_name": custom_repo_name,
                "feedback": feedback,
            },
        )
        # Multi-gate HITL: the resume may have paused at the NEXT gate
        # (architecture review / code review / deployment). Persist it so the
        # dashboard can poll /fleet/session/{id} and show the next CEO question.
        if pending is not None:
            gate = pending.get("interrupt_id")
            if gate == CEO_DECISION_GATE:
                status = "awaiting_ceo_decision"
            elif gate == CEO_DEPLOYMENT_GATE:
                status = "awaiting_deployment_decision"
            else:
                status = "awaiting_gate_decision"
            agent = "DeploymentAgent" if gate == CEO_DEPLOYMENT_GATE else "ADKRunner"
            SESSION_DB.save_session(
                session_id, status, agent, {**state, "pending_request_input": pending}
            )
            SESSION_DB.append_trace(
                session_id, "CEO", "hitl",
                f"Paused at gate '{pending.get('interrupt_id')}': {pending.get('prompt', '')[:160]}",
            )
    except Exception as exc:  # noqa: BLE001 — background tasks must never raise
        print(f"❌ [ADKRunner] Resume failed for '{session_id}': {exc}")
        SESSION_DB.save_session(
            session_id,
            "failed",
            "ADKRunner",
            {"failure_reason": str(exc), "failed_stage": "ceo_decision_resume"},
        )
        SESSION_DB.append_trace(
            session_id, "ADKRunner", "error",
            f"Background resume failed: {exc}",
        )
