"""FastAPI Cloud Run Service and Enterprise Multi-Agent Fleet Engine."""
from __future__ import annotations

import os
import urllib.error
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware

# -------------------------------------------------------------------
# ADK ORCHESTRATION IMPORTS (real google-adk 2.6.2 workflow engine)
# The Workflow/Runner/gate nodes live in the fleet_workflow package;
# main.py shares its singletons so traces and session state stay
# consistent across the pipeline.
# -------------------------------------------------------------------
from .agents import (
    PlannerAgent,
    ScoutAgent,
)
from .api_models import (
    CeoDecisionRequest,
    DeployConfirmRequest,
    TriggerDiscoveryRequest,
)
from .fleet_workflow import (
    LLM_CLIENT,
    SESSION_DB,
    start_fleet_run,
)
from .pipeline_tasks import (
    background_runner_resume,
    execute_ceo_pipeline_background_manual,
)
from .tools import ToolContext

# ADK workflow error for node failures — imported separately to avoid
# pulling the entire ADK workflow package at module load time.
from google.adk.workflow._errors import DynamicNodeFailError

app = FastAPI(
    title="Agent-First Enterprise Orchestration Fleet (Dual Mode)",
    version="3.1.0",
    description="Enterprise Google Cloud Multi-Agent Orchestrator supporting both Manual and ADK Runner pipelines.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Google Cloud state managers (shared singletons from fleet_workflow)
from .scheduler import DiscoveryScheduler  # noqa: E402

SCHEDULER = DiscoveryScheduler(session_db=SESSION_DB, llm=LLM_CLIENT)

# Governance query endpoints (sessions, traces, memory, security, system).
from . import api_queries as _queries  # noqa: E402

_queries.SCHEDULER = SCHEDULER
app.include_router(_queries.router)

# Secondary pipeline endpoints (generate-proposals, ceo-idea).
from .fleet_routes import router as _fleet_router  # noqa: E402

app.include_router(_fleet_router)


# -------------------------------------------------------------------
# FASTAPI ENDPOINTS
# -------------------------------------------------------------------
@app.get("/health")
def health_check() -> Dict[str, str]:
    return {
        "status": "healthy",
        "service": "adk-orchestrator",
        "version": "3.1.0",
        "default_execution_mode": "adk_runner",
        "cloud_location": os.getenv("GOOGLE_CLOUD_LOCATION", "global"),
    }

@app.post("/fleet/discovery")
async def trigger_discovery(req: TriggerDiscoveryRequest) -> Dict[str, Any]:
    # --- DEFAULT: ADK RUNNER MODE (real google-adk Workflow + Runner) ---
    if req.use_adk_runner:
        try:
            # FIXED: Native await instead of asyncio.run() to prevent loop collisions
            state, pending = await start_fleet_run(session_id=req.session_id, raw_feed=req.raw_feed)
        except DynamicNodeFailError as e:
            # ADK workflow node failed — extract the original error for the message
            original = e.error
            import traceback
            print(f"ERROR in /fleet/discovery - Workflow node '{e.error_node_path}' failed: {original}")
            traceback.print_exception(type(original), original, original.__traceback__)
            if isinstance(original, urllib.error.HTTPError):
                # HTTPError must be checked BEFORE URLError (it is a subclass)
                raise HTTPException(status_code=502, detail=f"Dart Node HTTP {original.code} at '{e.error_node_path}': {original}")
            elif isinstance(original, urllib.error.URLError):
                raise HTTPException(status_code=502, detail=f"Dart Node unreachable at '{e.error_node_path}': {original}")
            elif isinstance(original, RuntimeError):
                raise HTTPException(status_code=500, detail=f"OIDC/LLM error at '{e.error_node_path}': {original}")
            else:
                raise HTTPException(status_code=500, detail=f"Workflow node '{e.error_node_path}' failed: {original}")
        except urllib.error.HTTPError as e:
            # HTTPError must precede URLError — it is a subclass (non-ADK path)
            print(f"ERROR in /fleet/discovery - Dart Node HTTP {e.code}: {e.reason}")
            raise HTTPException(status_code=502, detail=f"Dart Node returned HTTP {e.code}: {e.reason}")
        except urllib.error.URLError as e:
            # Dart Node service unreachable (non-ADK path)
            print(f"ERROR in /fleet/discovery - Dart Node unreachable: {e}")
            raise HTTPException(status_code=502, detail=f"Dart Node service unreachable: {e}")
        except RuntimeError as e:
            # OIDC token fetch failure or LLM client failure (non-ADK path)
            print(f"ERROR in /fleet/discovery - Runtime error: {e}")
            raise HTTPException(status_code=500, detail=str(e))
        except Exception as e:
            # Unexpected error
            import traceback
            print(f"ERROR in /fleet/discovery - Unexpected error: {e}")
            traceback.print_exc()
            raise HTTPException(status_code=500, detail=f"Internal server error: {e}")
        if pending is not None:
            # Mirror the ADK session state into the Cloud SQL-shaped session
            # store so dashboard telemetry (/fleet/session/{id}) stays live.
            SESSION_DB.save_session(
                req.session_id, "awaiting_ceo_decision", "PlannerAgent", state
            )
            # Attach the source hackathon deep-link to each proposal so the
            # dashboard can open the specific competition in a new tab.
            opportunity = state.get("active_opportunity", {})
            data = {
                "idea_a": state.get("idea_a"),
                "idea_b": state.get("idea_b"),
            }
            for idea_key in ("idea_a", "idea_b"):
                idea = data.get(idea_key)
                if isinstance(idea, dict):
                    idea["hackathon_title"] = opportunity.get("title")
                    idea["hackathon_url"] = opportunity.get("url")
            return {
                "session_id": req.session_id,
                "status": "awaiting_ceo_decision",
                "request_input": pending,
                "hackathons": state.get("discovered_hackathons", []),
                "opportunity": opportunity,
                "data": data,
                "execution_mode": "adk_runner",
            }
        return {
            "session_id": req.session_id,
            "status": "error",
            "message": "Pipeline completed without proposing ideas.",
            "execution_mode": "adk_runner",
        }

    # --- FALLBACK: MANUAL ORCHESTRATION MODE ---
    context = ToolContext(session_id=req.session_id)
    SESSION_DB.append_trace(req.session_id, "ScoutAgent", "dart", "Invoked Dart Functional Node with raw feeds.")

    scout = ScoutAgent()
    scout_result = scout.run(req.raw_feed, context)

    if scout_result.status != "success":
        return {
            "session_id": req.session_id,
            "status": scout_result.status,
            "message": scout_result.message,
            "data": scout_result.data,
            "opportunity": scout_result.data,
            "execution_mode": "manual"
        }

    SESSION_DB.append_trace(req.session_id, "PlannerAgent", "agent", "Synthesizing Vertex AI proposals.")
    planner = PlannerAgent(llm=LLM_CLIENT)
    planner_result = planner.formulate_proposals(scout_result.data, context)

    SESSION_DB.save_session(req.session_id, "awaiting_ceo_decision", "PlannerAgent", context.state)

    opportunity = context.state.get("active_opportunity", {})
    data = dict(planner_result.data)

    return {
        "session_id": req.session_id,
        "status": planner_result.status,
        "request_input": planner_result.request_input.to_dict() if planner_result.request_input else None,
        "data": data,
        "opportunity": opportunity,
        "execution_mode": "manual"
    }


# NOTE: The shared background tasks (execute_ceo_pipeline_background_manual,
# background_runner_resume) are imported from .pipeline_tasks above — they are
# defined there once and reused by both main.py and fleet_routes.py.


@app.post("/fleet/ceo-decision")
async def submit_ceo_decision(req: CeoDecisionRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    # --- DEFAULT: ADK RUNNER MODE ---
    if req.use_adk_runner:
        if req.decision_choice == "skip_implementation":
            SESSION_DB.save_session(req.session_id, "skipped", "CEO", {})
            SESSION_DB.append_trace(req.session_id, "CEO", "ceo", "CEO decision: skip_implementation.")
            return {"session_id": req.session_id, "status": "skipped", "message": "Workflow archived."}

        # Mark the session as executing BEFORE dispatching the background task
        # so the dashboard telemetry poller shows the correct state immediately.
        SESSION_DB.save_session(req.session_id, "executing", "ADKRunner", {})
        SESSION_DB.append_trace(
            req.session_id, "ADKRunner", "system",
            f"CEO decision '{req.decision_choice}' accepted — ADK workflow resuming in background.",
        )
        background_tasks.add_task(
            background_runner_resume,
            session_id=req.session_id,
            decision=req.decision_choice,
            custom_prompt=req.custom_prompt,
            git_provider=req.git_provider,
            custom_repo_name=req.custom_repo_name,
            feedback=req.feedback,
        )
        return {
            "session_id": req.session_id,
            "status": "processing_in_background",
            "message": "ADK Runner resumed.",
            "execution_mode": "adk_runner"
        }

    # --- FALLBACK: MANUAL ORCHESTRATION MODE ---
    session_record = SESSION_DB.load_session(req.session_id)
    if not session_record:
        raise HTTPException(status_code=404, detail="Session not found")
    
    context = ToolContext(session_id=req.session_id)
    context.state = session_record.get("state", {})

    SESSION_DB.append_trace(req.session_id, "CEO", "ceo", f"CEO Decision: {req.decision_choice}")

    planner = PlannerAgent(llm=LLM_CLIENT)
    decision_result = planner.process_ceo_decision(
        decision_choice=req.decision_choice,
        custom_prompt=req.custom_prompt,
        git_provider=req.git_provider,
        custom_repo_name=req.custom_repo_name,
        context=context,
    )

    if decision_result.status == "skipped":
        SESSION_DB.save_session(req.session_id, "skipped", "PlannerAgent", context.state)
        return {"session_id": req.session_id, "status": "skipped"}

    background_tasks.add_task(execute_ceo_pipeline_background_manual, req, context)
    SESSION_DB.save_session(req.session_id, "processing_in_background", "ArchitectAgent", context.state)

    return {
        "session_id": req.session_id,
        "status": "processing_in_background",
        "message": "Manual fleet has started processing.",
        "execution_mode": "manual"
    }


@app.post("/fleet/deploy")
async def confirm_deployment(req: DeployConfirmRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    """CEO Deployment Gate — confirms or cancels Cloud Run deployment.

    Resumes the paused ADK workflow with the CEO's deployment decision.
    The deployment runs in the background so the API returns immediately.
    """
    session_record = SESSION_DB.load_session(req.session_id)
    if not session_record:
        raise HTTPException(status_code=404, detail="Session not found")

    # Verify the session is awaiting a deployment decision
    if session_record.get("status") != "awaiting_deployment_decision":
        raise HTTPException(
            status_code=409,
            detail=f"Session is not awaiting deployment decision (current status: {session_record.get('status')})",
        )

    SESSION_DB.save_session(req.session_id, "deploying", "DeploymentAgent", {})
    SESSION_DB.append_trace(
        req.session_id, "DeploymentAgent", "system",
        f"CEO deployment decision '{req.decision}' accepted — executing in background.",
    )
    background_tasks.add_task(
        background_runner_resume,
        session_id=req.session_id,
        decision=req.decision,
        custom_prompt=None,
        git_provider="github",
        custom_repo_name=None,
        feedback=None,
    )
    return {
        "session_id": req.session_id,
        "status": "deploying",
        "message": f"Deployment decision '{req.decision}' accepted — executing in background.",
    }




if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)