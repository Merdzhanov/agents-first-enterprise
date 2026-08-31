"""FastAPI Cloud Run Service and Enterprise Multi-Agent Fleet Engine."""
from __future__ import annotations

import os
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# -------------------------------------------------------------------
# ADK ORCHESTRATION IMPORTS
# -------------------------------------------------------------------
from google import Workflow as AdkWorkflow
from google import Runner as AdkRunner

from .agents import (
    ArchitectAgent,
    LeadDevAgent,
    MarketingAgent,
    PlannerAgent,
    ScoutAgent,
)
from .db import CloudSessionManager, VectorMemoryManager
from .deployer import DeploymentAgent
from .llm import VertexGeminiClient
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

# Global Google Cloud state managers
SESSION_DB = CloudSessionManager()
MEMORY_DB = VectorMemoryManager()
LLM_CLIENT = VertexGeminiClient()
SCHEDULER = DiscoveryScheduler(session_db=SESSION_DB, llm=LLM_CLIENT)

# -------------------------------------------------------------------
# ADK WORKFLOW DEFINITION
# -------------------------------------------------------------------
@AdkWorkflow(name="EnterpriseFleetWorkflow", description="Full Autonomous Prototyping Pipeline")
def enterprise_fleet_workflow(raw_feed: Dict[str, Any]) -> Dict[str, Any]:
    """ADK native workflow representing the full DAG execution."""
    context = ToolContext(session_id="adk_interactive_session")
    
    scout = ScoutAgent()
    scout_res = scout.run(raw_feed, context)
    if scout_res.status != "success":
        return {"status": "halted", "reason": scout_res.message}
        
    planner = PlannerAgent(llm=LLM_CLIENT)
    planner.formulate_proposals(scout_res.data, context)
    # The runner pauses here on RequestInput automatically
    
    ArchitectAgent(llm=LLM_CLIENT).run(context)
    LeadDevAgent(llm=LLM_CLIENT).run(context)
    mkt_res = MarketingAgent(llm=LLM_CLIENT).run(context)
    
    return {"status": "completed", "final_data": mkt_res.data}

# Initialize the global ADK Runner connected to our Cloud SQL session DB
FLEET_RUNNER = AdkRunner(
    workflow=enterprise_fleet_workflow,
    storage=SESSION_DB
)

# -------------------------------------------------------------------
# FASTAPI REQUEST MODELS (ADK Runner as default)
# -------------------------------------------------------------------
class TriggerDiscoveryRequest(BaseModel):
    session_id: str = Field(default="session_dev_001")
    raw_feed: Dict[str, Any] = Field(default_factory=dict)
    use_adk_runner: bool = Field(default=True, description="Toggle between ADK Runner (default) and manual orchestration")

class CeoDecisionRequest(BaseModel):
    session_id: str
    decision_choice: str = Field(description="approve_idea_a | approve_idea_b | custom_idea | skip_implementation")
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
    # --- DEFAULT: ADK RUNNER MODE ---
    if req.use_adk_runner:
        run_result = FLEET_RUNNER.start(
            session_id=req.session_id,
            inputs={"raw_feed": req.raw_feed}
        )
        if run_result.is_paused and run_result.pending_input:
            return {
                "session_id": req.session_id,
                "status": "awaiting_ceo_decision",
                "request_input": run_result.pending_input.to_dict(),
                "opportunity": run_result.state.get("active_opportunity", {}),
                "data": run_result.state.get("proposed_ideas", {}),
                "execution_mode": "adk_runner"
            }
        return {"status": "error", "message": "Pipeline completed without proposing ideas."}

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

def background_runner_resume(session_id: str, decision: str, custom_prompt: Optional[str]):
    """Background task for ADK Runner mode."""
    FLEET_RUNNER.resume(
        session_id=session_id,
        human_input={
            "decision": decision,
            "custom_prompt": custom_prompt
        }
    )


@app.post("/fleet/ceo-decision")
def submit_ceo_decision(req: CeoDecisionRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    # --- DEFAULT: ADK RUNNER MODE ---
    if req.use_adk_runner:
        if req.decision_choice == "skip_implementation":
            SESSION_DB.save_session(req.session_id, "skipped", "CEO", {})
            return {"status": "skipped", "message": "Workflow archived."}

        background_tasks.add_task(
            background_runner_resume,
            session_id=req.session_id,
            decision=req.decision_choice,
            custom_prompt=req.custom_prompt
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

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)