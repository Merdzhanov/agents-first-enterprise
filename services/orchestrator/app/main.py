"""FastAPI Cloud Run Service and Enterprise Multi-Agent Fleet Engine."""
from __future__ import annotations

import asyncio
import os
import time
import urllib.error
from typing import Any, Dict, List, Literal, Optional

# Strict CEO decision contract — invalid values are rejected by pydantic (HTTP 422).
DecisionChoice = Literal[
    "approve_idea_a",
    "approve_idea_b",
    "custom_idea",
    "skip_implementation",
    # Multi-gate HITL decisions:
    "approve_architecture",
    "revise_architecture",
    "approve_code",
    "request_changes",
]
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
from .deployer import DeploymentAgent
from .fleet_workflow import (
    CEO_ARCH_REVIEW_GATE,
    CEO_CODE_REVIEW_GATE,
    CEO_DECISION_GATE,
    FLEET_RUNNER,
    LLM_CLIENT,
    MEMORY_DB,
    SESSION_DB,
    WORKFLOW_NODES,
    resume_fleet_run,
    start_fleet_run,
)
from .scheduler import DiscoveryScheduler
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
    decision_choice: DecisionChoice = Field(description="CEO decision at the current HITL gate")
    custom_prompt: Optional[str] = None
    git_provider: str = Field(default="github", description="github | gitlab")
    custom_repo_name: Optional[str] = Field(default=None, description="Custom or confirmed repository name")
    feedback: Optional[str] = Field(default=None, description="Free-text feedback for revise_architecture / request_changes / custom_idea")
    use_adk_runner: bool = Field(default=True, description="Toggle between ADK Runner (default) and manual execution")

class DeployConfirmRequest(BaseModel):
    session_id: str
    decision: str = Field(default="confirm_deploy_cloud_run", description="confirm_deploy_cloud_run | cancel_deployment")


class GenerateProposalsRequest(BaseModel):
    """Generate proposals for a specific hackathon (already discovered, no Devpost API call)."""
    session_id: str = Field(default="session_dev_001")
    hackathon: Dict[str, Any] = Field(..., description="Selected hackathon data (title, url, prize_pool, tracks, etc.)")


class CeoIdeaRequest(BaseModel):
    """CEO submits a fully independent idea at any time — no prior discovery required."""
    custom_prompt: str = Field(..., min_length=1, description="The CEO's custom prototype directive / idea description")
    git_provider: str = Field(default="github", description="github | gitlab")
    custom_repo_name: Optional[str] = Field(default=None, description="Optional repository name slug")
    session_id: Optional[str] = Field(default=None, description="Optional explicit session id; generated if omitted")


class MemoryStoreRequest(BaseModel):
    """CEO / operator knowledge ingestion into the enterprise semantic memory bank."""
    topic: str = Field(description="Short topic label (e.g. 'architecture-decision')")
    content: str = Field(description="The memory fact content to be embedded and stored")
    tenant_id: str = Field(default="default_enterprise", description="RLS tenant isolation key")
    metadata: Dict[str, Any] = Field(default_factory=dict)


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
        try:
            state, pending = asyncio.run(
                start_fleet_run(session_id=req.session_id, raw_feed=req.raw_feed)
            )
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
    feedback: Optional[str] = None,
):
    """Background task for ADK Runner mode (real Runner resume phase 2).

    Failures are captured into the session store (status='failed') so the
    CEO dashboard surfaces them instead of leaving the pipeline stuck in
    'processing_in_background' after an unhandled exception.
    """
    try:
        state, pending = asyncio.run(
            resume_fleet_run(
                session_id=session_id,
                decision_payload={
                    "decision": decision,
                    "custom_prompt": custom_prompt,
                    "git_provider": git_provider,
                    "custom_repo_name": custom_repo_name,
                    "feedback": feedback,
                },
            )
        )
        # Multi-gate HITL: the resume may have paused at the NEXT gate
        # (architecture review / code review). Persist it so the dashboard
        # can poll /fleet/session/{id} and show the next CEO question.
        if pending is not None:
            status = "awaiting_ceo_decision" if pending.get("interrupt_id") == CEO_DECISION_GATE else "awaiting_gate_decision"
            SESSION_DB.save_session(session_id, status, "ADKRunner", {**state, "pending_request_input": pending})
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


@app.post("/fleet/generate-proposals")
def generate_proposals(req: GenerateProposalsRequest) -> Dict[str, Any]:
    """Generate proposals for a selected hackathon via the ADK Runner workflow.

    The hackathon is pre-seeded as ``active_opportunity`` in the ADK session
    state so the scout node skips Devpost discovery and the planner generates
    proposals aligned to the selected hackathon.
    """
    try:
        state, pending = asyncio.run(
            start_fleet_run(
                session_id=req.session_id,
                raw_feed={},
                state_overrides={"active_opportunity": req.hackathon},
            )
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
    except Exception as e:
        import traceback
        print(f"ERROR in /fleet/generate-proposals: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Proposal generation failed: {e}")


@app.post("/fleet/ceo-idea")
def submit_ceo_idea(req: CeoIdeaRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    """
    CEO submits a fully independent idea at any time — no prior discovery required.

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

    SESSION_DB.append_trace(session_id, "CEO", "ceo", f"CEO independent idea submitted: {req.custom_prompt[:80]}")

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


@app.get("/fleet/sessions")
def list_sessions_endpoint(limit: int = 100, include_state: bool = False) -> Dict[str, Any]:
    """Governance registry of all fleet sessions (audit trail across the org).

    ``include_state=true`` adds the full pipeline state to each record.
    """
    sessions = SESSION_DB.list_sessions(limit=limit, include_state=include_state)
    return {"count": len(sessions), "sessions": sessions}


@app.get("/fleet/memory")
def list_memories_endpoint(tenant_id: Optional[str] = None) -> Dict[str, Any]:
    """Semantic memory bank (pgvector-backed facts with tenant isolation)."""
    memories = MEMORY_DB.list_memories(tenant_id=tenant_id)
    return {
        "count": len(memories),
        "tenant_id": tenant_id or "default_enterprise",
        "memories": memories,
    }


@app.post("/fleet/memory")
def store_memory_endpoint(req: MemoryStoreRequest) -> Dict[str, Any]:
    """Stores a semantic memory fact (CEO knowledge ingestion)."""
    MEMORY_DB.store_memory(
        topic=req.topic,
        content=req.content,
        metadata=req.metadata,
        tenant_id=req.tenant_id,
    )
    SESSION_DB.append_trace(
        f"memory_{req.tenant_id}", "CEO", "memory",
        f"Stored memory '{req.topic}' ({len(req.content)} chars).",
    )
    return {"status": "stored", "topic": req.topic, "tenant_id": req.tenant_id}


@app.get("/fleet/security")
def security_posture_endpoint() -> Dict[str, Any]:
    """Live security & IAM posture of the fleet (OIDC, RLS isolation, HITL gates)."""
    all_sessions = SESSION_DB.list_sessions(limit=10000)
    tenants = sorted({s.get("tenant_id", "default_enterprise") for s in all_sessions})
    return {
        "service_to_service_auth": "Google OIDC Bearer tokens (google.oauth2.id_token) for Cloud Run-to-Cloud Run calls",
        "dart_node_auth_policy": "OIDC attached when Vertex AI mode is on; plaintext localhost in dev",
        "session_isolation": "Row-Level Security (RLS) keyed by tenant_id",
        "tenants_observed": tenants,
        "session_records": len(all_sessions),
        "memory_records": len(MEMORY_DB.list_memories()),
        "memory_tenant_isolation": "Memories are filtered per tenant_id on read",
        "human_in_the_loop_gates": [
            "CEO Proposal Gate (approve_idea_a | approve_idea_b | custom_idea | skip_implementation)",
            "CEO Architecture Review Gate (approve_architecture | revise_architecture)",
            "CEO Code Review Gate (approve_code | request_changes)",
        ],
        "skip_safety": "Skip decisions halt the pipeline with zero LLM/Git spend",
        "cors_policy": "allow_origins=* (DEMO ONLY — restrict for production)",
        "git_providers": ["github", "gitlab"],
    }


@app.get("/fleet/system")
def system_introspection_endpoint() -> Dict[str, Any]:
    """System health & architecture introspection (ADK engine, agents, stores)."""
    return {
        "version": app.version,
        "execution_engine": "Google ADK 2.6.2 graph Workflow (FunctionNode + RequestInput HITL interrupts)",
        "default_execution_mode": "adk_runner",
        "agents": [
            "ScoutAgent", "PlannerAgent", "ArchitectAgent",
            "LeadDevAgent", "MarketingAgent", "DeploymentAgent",
        ],
        "hitl_gates": ["CEO Proposal Gate", "CEO Architecture Review Gate", "CEO Code Review Gate", "Compliance Gate"],
        "session_store": "Cloud SQL PostgreSQL (RLS) with in-memory local fallback",
        "memory_store": "Cloud SQL pgvector (text-embedding-005) with in-memory local fallback",
        "scheduler_interval_minutes": SCHEDULER.interval_minutes,
        "dart_node_url": os.getenv("DART_NODE_URL", "http://127.0.0.1:8080"),
        "vertex_ai_mode": os.getenv("GOOGLE_GENAI_USE_VERTEXAI", "False"),
        "cloud_location": os.getenv("GOOGLE_CLOUD_LOCATION", "global"),
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