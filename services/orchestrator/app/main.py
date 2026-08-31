"""FastAPI Cloud Run Service and Enterprise Multi-Agent Fleet Engine."""
from __future__ import annotations

import asyncio
import os
from typing import Any, Dict, List, Literal, Optional

# Strict CEO decision contract — invalid values are rejected by pydantic (HTTP 422).
DecisionChoice = Literal["approve_idea_a", "approve_idea_b", "custom_idea", "skip_implementation"]
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# -------------------------------------------------------------------
# ADK ORCHESTRATION IMPORTS (real google-adk 2.6.2 workflow engine)
# The Workflow/Runner/gate nodes live in fleet_workflow.py; main.py
# shares its singletons so traces and session state stay consistent.
# -------------------------------------------------------------------
from .agents import (
    ArchitectAgent,
    LeadDevAgent,
    MarketingAgent,
    PlannerAgent,
    ScoutAgent,
)
from .db import VectorMemoryManager
from .deployer import DeploymentAgent
from .fleet_workflow import (
    CEO_DECISION_GATE,
    FLEET_RUNNER,
    LLM_CLIENT,
    SESSION_DB,
    resume_fleet_run,
    start_fleet_run,
)
from .scheduler import DiscoveryScheduler
from .tools import ToolContext

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
MEMORY_DB = VectorMemoryManager()
SCHEDULER = DiscoveryScheduler(session_db=SESSION_DB, llm=LLM_CLIENT)

# -------------------------------------------------------------------
# FASTAPI REQUEST MODELS (ADK Runner as default)
# -------------------------------------------------------------------
class TriggerDiscoveryRequest(BaseModel):
    session_id: str = Field(default="session_dev_001")
    raw_feed: Dict[str, Any] = Field(default_factory=dict)
    use_adk_runner: bool = Field(default=True, description="Toggle between ADK Runner (default) and manual orchestration")

class CeoDecisionRequest(BaseModel):
    session_id: str
    decision_choice: DecisionChoice = Field(description="approve_idea_a | approve_idea_b | custom_idea | skip_implementation")
    custom_prompt: Optional[str] = None
    git_provider: str = Field(default="github", description="github | gitlab")
    custom_repo_name: Optional[str] = Field(default=None, description="Custom or confirmed repository name")
    use_adk_runner: bool = Field(default=True, description="Toggle between ADK Runner (default) and manual execution")

class DeployConfirmRequest(BaseModel):
    session_id: str
    decision: str = Field(default="confirm_deploy_cloud_run", description="confirm_deploy_cloud_run | cancel_deployment")


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
def trigger_discovery(req: TriggerDiscoveryRequest) -> Dict[str, Any]:
    # --- DEFAULT: ADK RUNNER MODE (real google-adk Workflow + Runner) ---
    if req.use_adk_runner:
        # Sync endpoints run in FastAPI's threadpool, so asyncio.run() here is
        # safe (no running event loop in this worker thread).
        state, pending = asyncio.run(
            start_fleet_run(session_id=req.session_id, raw_feed=req.raw_feed)
        )
        if pending is not None:
            # Mirror the ADK session state into the Cloud SQL-shaped session
            # store so dashboard telemetry (/fleet/session/{id}) stays live.
            SESSION_DB.save_session(
                req.session_id, "awaiting_ceo_decision", "PlannerAgent", state
            )
            return {
                "session_id": req.session_id,
                "status": "awaiting_ceo_decision",
                "request_input": pending,
                "hackathons": state.get("discovered_hackathons", []),
                "opportunity": state.get("active_opportunity", {}),
                "data": {
                    "idea_a": state.get("idea_a"),
                    "idea_b": state.get("idea_b"),
                },
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


def execute_ceo_pipeline_background_manual(req: CeoDecisionRequest, context: ToolContext):
    """Background task for Manual mode."""
    ArchitectAgent(llm=LLM_CLIENT).run(context)
    SESSION_DB.append_trace(req.session_id, "ArchitectAgent", "agent", "Synthesized Cloud Native architecture.")

    dev = LeadDevAgent(llm=LLM_CLIENT)
    dev_result = dev.run(context)
    SESSION_DB.append_trace(req.session_id, "LeadDevAgent", "agent", "Committed files to Git.")

    MarketingAgent(llm=LLM_CLIENT).run(context)
    SESSION_DB.append_trace(req.session_id, "MarketingAgent", "success", "Assembled Devpost package.")

    SESSION_DB.save_session(req.session_id, "completed", "MarketingAgent", context.state)

def background_runner_resume(
    session_id: str,
    decision: str,
    custom_prompt: Optional[str],
    git_provider: str = "github",
    custom_repo_name: Optional[str] = None,
):
    """Background task for ADK Runner mode (real Runner resume phase 2).

    Failures are captured into the session store (status='failed') so the
    CEO dashboard surfaces them instead of leaving the pipeline stuck in
    'processing_in_background' after an unhandled exception.
    """
    try:
        asyncio.run(
            resume_fleet_run(
                session_id=session_id,
                decision_payload={
                    "decision": decision,
                    "custom_prompt": custom_prompt,
                    "git_provider": git_provider,
                    "custom_repo_name": custom_repo_name,
                },
            )
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


@app.post("/fleet/ceo-decision")
def submit_ceo_decision(req: CeoDecisionRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    # --- DEFAULT: ADK RUNNER MODE ---
    if req.use_adk_runner:
        if req.decision_choice == "skip_implementation":
            SESSION_DB.save_session(req.session_id, "skipped", "CEO", {})
            SESSION_DB.append_trace(req.session_id, "CEO", "ceo", "CEO decision: skip_implementation.")
            return {"session_id": req.session_id, "status": "skipped", "message": "Workflow archived."}

        background_tasks.add_task(
            background_runner_resume,
            session_id=req.session_id,
            decision=req.decision_choice,
            custom_prompt=req.custom_prompt,
            git_provider=req.git_provider,
            custom_repo_name=req.custom_repo_name,
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


@app.get("/fleet/session/{session_id}")
def get_session_state(session_id: str) -> Dict[str, Any]:
    """Returns the current session record (status + state) for live telemetry."""
    record = SESSION_DB.load_session(session_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    return record


@app.get("/fleet/session/{session_id}/traces")
def get_session_traces(session_id: str) -> List[Dict[str, Any]]:
    """Returns the chronological execution trace log for the session."""
    return SESSION_DB.get_traces(session_id)


@app.get("/fleet/session/{session_id}/artifacts")
def get_session_artifacts(session_id: str) -> Dict[str, Any]:
    """Returns the generated deliverables (architecture, git repo, code, submission)."""
    record = SESSION_DB.load_session(session_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    state = record.get("state", {})
    return {
        "session_id": session_id,
        "status": record.get("status"),
        "selected_idea": state.get("selected_idea"),
        "architecture_spec": state.get("architecture_spec"),
        "git_repo": state.get("git_repo"),
        "committed_files": state.get("committed_files"),
        "submission_package": state.get("submission_package"),
        "deployment_record": state.get("deployment_record"),
    }


@app.post("/fleet/scheduled-discovery")
async def run_scheduled_discovery() -> Dict[str, Any]:
    """Invoked periodically by Google Cloud Scheduler via Cloud Pub/Sub."""
    proposals = await SCHEDULER.run_discovery_cycle()
    return {
        "status": "success",
        "proposals_count": len(proposals),
        "proposals": proposals,
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)