"""Secondary fleet pipeline endpoints (proposals + CEO independent idea).

Split out of ``main.py`` to keep every module under 400 lines. Registered on
the main app via ``app.include_router(router)``.
"""
from __future__ import annotations

import time
from typing import Any, Dict

from fastapi import APIRouter, BackgroundTasks, HTTPException

from .api_models import CeoDecisionRequest, CeoIdeaRequest, GenerateProposalsRequest
from .fleet_workflow import LLM_CLIENT, SESSION_DB, start_fleet_run
from .pipeline_tasks import execute_ceo_pipeline_background_manual
from .agents import PlannerAgent
from .tools import ToolContext

router = APIRouter()


@router.post("/fleet/generate-proposals")
async def generate_proposals(req: GenerateProposalsRequest) -> Dict[str, Any]:
    """Generate proposals for a selected hackathon via the ADK Runner workflow.

    The hackathon is pre-seeded as ``active_opportunity`` in the ADK session
    state so the scout node skips Devpost discovery and the planner generates
    proposals aligned to the selected hackathon.
    """
    try:
        state, pending = await start_fleet_run(
            session_id=req.session_id,
            raw_feed={},
            state_overrides={"active_opportunity": req.hackathon},
        )

        # Primary: read from top-level keys set by PlannerAgent.formulate_proposals.
        # Fallback: propose_ideas_to_ceo also nests them under "proposed_ideas".
        idea_a = state.get("idea_a")
        idea_b = state.get("idea_b")
        if idea_a is None or idea_b is None:
            nested = state.get("proposed_ideas", {})
            idea_a = idea_a or nested.get("idea_a")
            idea_b = idea_b or nested.get("idea_b")

        # Persist the session so it appears in /fleet/sessions and the
        # governance dashboard history. Without this the ADK run is
        # ephemeral and the session disappears on refresh.
        SESSION_DB.save_session(
            session_id=req.session_id,
            status="awaiting_ceo_decision",
            current_agent="PlannerAgent",
            state=state,
        )
        SESSION_DB.append_trace(
            req.session_id,
            "PlannerAgent",
            "proposals",
            f"Generated 2 proposals for '{req.hackathon.get('title', 'selected hackathon')}' via ADK Runner.",
        )

        return {
            "session_id": req.session_id,
            "status": "awaiting_ceo_decision",
            "request_input": pending,
            "idea_a": idea_a,
            "idea_b": idea_b,
            "hackathon_title": req.hackathon.get("title"),
            "hackathon_url": req.hackathon.get("url"),
        }
    except HTTPException:
        raise
    except Exception as e:  # noqa: BLE001 — surfaced as HTTP 500 to the caller
        import traceback
        print(f"ERROR in /fleet/generate-proposals: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Proposal generation failed: {e}")


@router.post("/fleet/ceo-idea")
async def submit_ceo_idea(req: CeoIdeaRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    """CEO submits a fully independent idea at any time — no prior discovery required.

    Reuses the same custom_idea pipeline as the CEO decision gate, but seeds a
    fresh session from scratch so the CEO can propose ideas on demand, without
    waiting for a scheduled or triggered discovery cycle.
    """
    session_id = req.session_id or f"session_ceo_custom_{int(time.time())}"

    if SESSION_DB.session_exists(session_id):
        raise HTTPException(status_code=409, detail=f"Session '{session_id}' already exists")

    context = ToolContext(session_id=session_id)
    # Seed a minimal opportunity so downstream agents have a title context.
    context.state["active_opportunity"] = {
        "title": "CEO Independent Idea",
        "url": None,
        "source": "ceo_direct_input",
    }

    SESSION_DB.append_trace(
        session_id, "CEO", "ceo", f"CEO independent idea submitted: {req.custom_prompt[:80]}"
    )

    planner = PlannerAgent(llm=LLM_CLIENT)
    decision_result = planner.process_ceo_decision(
        decision_choice="custom_idea",
        custom_prompt=req.custom_prompt,
        git_provider=req.git_provider,
        custom_repo_name=req.custom_repo_name,
        context=context,
    )

    if decision_result.status == "skipped":
        SESSION_DB.save_session(session_id, "skipped", "PlannerAgent", context.state)
        return {"session_id": session_id, "status": "skipped", "message": "Idea skipped."}

    # execute_ceo_pipeline_background_manual expects a CeoDecisionRequest —
    # build one from the CeoIdeaRequest fields (only session_id is consumed).
    pipeline_req = CeoDecisionRequest(
        session_id=session_id,
        decision_choice="custom_idea",
        custom_prompt=req.custom_prompt,
        git_provider=req.git_provider,
        custom_repo_name=req.custom_repo_name,
    )
    background_tasks.add_task(execute_ceo_pipeline_background_manual, pipeline_req, context)
    SESSION_DB.save_session(session_id, "processing_in_background", "ArchitectAgent", context.state)

    return {
        "session_id": session_id,
        "status": "processing_in_background",
        "message": "CEO idea accepted — fleet pipeline started in background.",
        "execution_mode": "manual",
    }
