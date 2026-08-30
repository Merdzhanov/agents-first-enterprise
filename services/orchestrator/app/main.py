"""FastAPI Cloud Run Service and Enterprise Multi-Agent Fleet Engine."""
from __future__ import annotations

import os
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

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
    title="Agent-First Enterprise Orchestration Fleet",
    version="3.0.0",
    description="Enterprise Google Cloud Multi-Agent Orchestrator with Vertex AI Gemini 3.5 and Cloud SQL pgvector",
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

class TriggerDiscoveryRequest(BaseModel):
    session_id: str = Field(default="session_dev_001")
    raw_feed: Dict[str, Any] = Field(default_factory=dict)

class CeoDecisionRequest(BaseModel):
    session_id: str
    decision_choice: str = Field(description="approve_idea_a | approve_idea_b | custom_idea | skip_implementation")
    custom_prompt: Optional[str] = None
    git_provider: str = Field(default="github", description="github | gitlab")
    custom_repo_name: Optional[str] = Field(default=None, description="Custom or confirmed repository name")

class DeployConfirmRequest(BaseModel):
    session_id: str
    decision: str = Field(default="confirm_deploy_cloud_run", description="confirm_deploy_cloud_run | cancel_deployment")

@app.get("/health")
def health_check() -> Dict[str, str]:
    return {
        "status": "healthy",
        "service": "adk-orchestrator",
        "version": "3.0.0",
        "cloud_location": os.getenv("GOOGLE_CLOUD_LOCATION", "global"),
        "session_store": "Cloud SQL PostgreSQL with RLS",
        "vector_memory": "Cloud SQL pgvector (text-embedding-005)",
    }

@app.post("/fleet/discovery")
def trigger_discovery(req: TriggerDiscoveryRequest) -> Dict[str, Any]:
    """
    Executes Discovery Phase:
    1. ScoutAgent discovers and extracts track requirements via Dart Node.
    2. PlannerAgent uses Vertex AI to formulate 2 prototype proposals.
    3. Yields RequestInput for CEO decision.
    """
    context = ToolContext(session_id=req.session_id)

    SESSION_DB.append_trace(
        req.session_id, "ScoutAgent", "dart",
        "Invoked Dart Functional Node (/tasks/parse-brief) with raw opportunity feeds."
    )

    # Scout Phase
    scout = ScoutAgent()
    scout_result = scout.run(req.raw_feed, context)

    if scout_result.status != "success":
        return {
            "session_id": req.session_id,
            "status": scout_result.status,
            "message": scout_result.message,
            "request_input": None,
            "data": scout_result.data,
            "hackathons": [],
            "opportunity": scout_result.data,
        }

    SESSION_DB.append_trace(
        req.session_id, "PlannerAgent", "agent",
        f"Synthesizing 2 Vertex AI proposals for '{scout_result.data.get('title')}'."
    )

    # Planner Formulates 2 Ideas via Vertex AI
    planner = PlannerAgent(llm=LLM_CLIENT)
    planner_result = planner.formulate_proposals(scout_result.data, context)

    # Save context state to Cloud SQL database (Stateless architecture)
    SESSION_DB.save_session(
        session_id=req.session_id,
        status="awaiting_ceo_decision",
        current_agent="PlannerAgent",
        state=context.state,
    )

    # Attach the source hackathon (title + URL) to each proposal so the
    # dashboard can deep-link every suggested project to its competition.
    opportunity = context.state.get("active_opportunity", {})
    data = dict(planner_result.data)
    for idea_key in ("idea_a", "idea_b"):
        idea = data.get(idea_key)
        if isinstance(idea, dict):
            idea["hackathon_title"] = opportunity.get("title")
            idea["hackathon_url"] = opportunity.get("url")

    # Top 5 discovered hackathons for the dashboard's live hackathon board.
    hackathons = context.state.get("discovered_hackathons", [])

    return {
        "session_id": req.session_id,
        "status": planner_result.status,
        "message": planner_result.message,
        "request_input": planner_result.request_input.to_dict() if planner_result.request_input else None,
        "data": data,
        "hackathons": hackathons,
        "opportunity": opportunity,
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

def execute_ceo_pipeline_background(req: CeoDecisionRequest, context: ToolContext):
    """Background task for executing heavy agent workflows without blocking HTTP response."""
    # Execute Architect Agent with Vertex AI
    architect = ArchitectAgent(llm=LLM_CLIENT)
    architect.run(context)
    SESSION_DB.append_trace(req.session_id, "ArchitectAgent", "agent", "Synthesized Cloud Native architecture and Mermaid topology.")

    # Execute Lead Dev Agent with Iterative Scaffolding (Option B)
    dev = LeadDevAgent(llm=LLM_CLIENT)
    dev_result = dev.run(context)
    SESSION_DB.append_trace(req.session_id, "LeadDevAgent", "agent", f"Committed {len(dev_result.data.get('files_committed', []))} files to Git.")

    # Execute Marketing Agent with Vertex AI
    marketing = MarketingAgent(llm=LLM_CLIENT)
    marketing_result = marketing.run(context)
    SESSION_DB.append_trace(req.session_id, "MarketingAgent", "success", "Assembled 4-minute demo script and Devpost submission package.")

    SESSION_DB.save_session(req.session_id, "completed", "MarketingAgent", context.state)

@app.post("/fleet/ceo-decision")
def submit_ceo_decision(req: CeoDecisionRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    """
    Processes CEO Decision Gate:
    - If Skip: Halts safely with zero spend.
    - If Approved: Triggers background tasks for Dart Git provisioning, Vertex AI Architect, 
      Iterative Dev Agent, and Marketing Agent to prevent Gateway Timeouts.
    """
    # Load state from database for Cloud Run container safety
    session_record = SESSION_DB.load_session(req.session_id)
    if not session_record:
        raise HTTPException(status_code=404, detail="Session not found or expired")
    
    context = ToolContext(session_id=req.session_id)
    context.state = session_record.get("state", {})

    SESSION_DB.append_trace(
        req.session_id, "CEO", "ceo",
        f"CEO Decision: {req.decision_choice} on {req.git_provider.upper()} (repo: '{req.custom_repo_name or 'default'}')."
    )

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
        return {
            "session_id": req.session_id,
            "status": "skipped",
            "message": decision_result.message,
            "pipeline_state": context.state,
        }

    # Add heavy pipeline to background tasks
    background_tasks.add_task(execute_ceo_pipeline_background, req, context)

    # Update DB to show processing status before returning response
    SESSION_DB.save_session(req.session_id, "processing_in_background", "ArchitectAgent", context.state)

    return {
        "session_id": req.session_id,
        "status": "processing_in_background",
        "message": "The agent fleet has started provisioning the repository and writing code on Google Cloud.",
        "git_provider": req.git_provider,
    }

@app.post("/fleet/deploy-confirm")
def confirm_deployment(req: DeployConfirmRequest) -> Dict[str, Any]:
    """Handles CEO confirmation for deploying the generated prototype to Google Cloud Run."""
    session_record = SESSION_DB.load_session(req.session_id)
    if not session_record:
        raise HTTPException(status_code=404, detail="Session not found")

    context = ToolContext(session_id=req.session_id)
    context.state = session_record.get("state", {})

    deployer = DeploymentAgent()
    deploy_result = deployer.execute_deployment(req.decision, context)

    SESSION_DB.append_trace(
        req.session_id, "DeploymentAgent", "success" if deploy_result.get("status") == "deployed_live" else "skip",
        f"Deployment action executed: {deploy_result.get('status')} ({deploy_result.get('url', 'N/A')})"
    )
    
    # Save state after deployer modifications
    SESSION_DB.save_session(req.session_id, "deployment_completed", "DeploymentAgent", context.state)

    return {
        "session_id": req.session_id,
        "deployment": deploy_result,
        "state": context.state,
    }

@app.get("/fleet/session/{session_id}")
def get_session_state(session_id: str) -> Dict[str, Any]:
    record = SESSION_DB.load_session(session_id)
    if not record:
        raise HTTPException(status_code=404, detail="Session not found")
    return record

@app.get("/fleet/session/{session_id}/traces")
def get_session_traces(session_id: str) -> List[Dict[str, Any]]:
    return SESSION_DB.get_traces(session_id)

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)