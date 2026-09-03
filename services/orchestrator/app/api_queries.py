"""Governance query endpoints — sessions, traces, artifacts, memory, security."""
from __future__ import annotations

import os
from typing import Any, Dict, List, Optional, TYPE_CHECKING

from fastapi import APIRouter, HTTPException

from .api_models import APP_VERSION, MemoryStoreRequest
from .fleet_workflow import MEMORY_DB, SESSION_DB

router = APIRouter()

if TYPE_CHECKING:
    from .scheduler import DiscoveryScheduler

# Set by main.py at startup — the shared discovery scheduler singleton.
SCHEDULER: Optional["DiscoveryScheduler"] = None


@router.get("/fleet/session/{session_id}")
def get_session_state(session_id: str) -> Dict[str, Any]:
    """Returns the current session record (status + state) for live telemetry."""
    record = SESSION_DB.load_session(session_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found")
    return record


@router.get("/fleet/session/{session_id}/traces")
def get_session_traces(session_id: str) -> List[Dict[str, Any]]:
    """Returns the chronological execution trace log for the session."""
    return SESSION_DB.get_traces(session_id)


@router.get("/fleet/session/{session_id}/artifacts")
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


@router.get("/fleet/sessions")
def list_sessions_endpoint(limit: int = 100, include_state: bool = False) -> Dict[str, Any]:
    """Governance registry of all fleet sessions (audit trail across the org).

    ``include_state=true`` adds the full pipeline state to each record.
    """
    sessions = SESSION_DB.list_sessions(limit=limit, include_state=include_state)
    return {"count": len(sessions), "sessions": sessions}


@router.get("/fleet/memory")
def list_memories_endpoint(tenant_id: Optional[str] = None) -> Dict[str, Any]:
    """Semantic memory bank (pgvector-backed facts with tenant isolation)."""
    memories = MEMORY_DB.list_memories(tenant_id=tenant_id)
    return {
        "count": len(memories),
        "tenant_id": tenant_id or "default_enterprise",
        "memories": memories,
    }


@router.post("/fleet/memory")
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


@router.get("/fleet/security")
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
            "CEO Deployment Gate (confirm_deploy_cloud_run | cancel_deployment)",
        ],
        "skip_safety": "Skip decisions halt the pipeline with zero LLM/Git spend",
        "cors_policy": "allow_origins=* (DEMO ONLY — restrict for production)",
        "git_providers": ["github", "gitlab"],
    }


@router.get("/fleet/system")
def system_introspection_endpoint() -> Dict[str, Any]:
    """System health & architecture introspection (ADK engine, agents, stores)."""
    return {
        "version": APP_VERSION,
        "execution_engine": "Google ADK 2.6.2 graph Workflow (FunctionNode + RequestInput HITL interrupts)",
        "default_execution_mode": "adk_runner",
        "agents": [
            "ScoutAgent", "PlannerAgent", "ArchitectAgent",
            "LeadDevAgent", "ShaderEngineerAgent", "FlutterFrontendAgent",
            "ReviewerAgent", "ComplianceAgent", "MarketingAgent", "DeploymentAgent",
        ],
        "hitl_gates": [
            "CEO Proposal Gate", "CEO Architecture Review Gate",
            "CEO Code Review Gate", "Compliance Gate", "CEO Deployment Gate",
        ],
        "session_store": "Cloud SQL PostgreSQL (RLS) with in-memory local fallback",
        "memory_store": "Cloud SQL pgvector (text-embedding-005) with in-memory local fallback",
        "scheduler_interval_minutes": SCHEDULER.interval_minutes if SCHEDULER else None,
        "dart_node_url": os.getenv("DART_NODE_URL", "http://127.0.0.1:8080"),
        "vertex_ai_mode": os.getenv("GOOGLE_GENAI_USE_VERTEXAI", "False"),
        "cloud_location": os.getenv("GOOGLE_CLOUD_LOCATION", "global"),
    }


@router.post("/fleet/scheduled-discovery")
async def run_scheduled_discovery() -> Dict[str, Any]:
    """Invoked periodically by Google Cloud Scheduler via Cloud Pub/Sub."""
    if SCHEDULER is None:
        raise HTTPException(status_code=503, detail="Scheduler not initialized")
    proposals = await SCHEDULER.run_discovery_cycle()
    return {
        "status": "success",
        "proposals_count": len(proposals),
        "proposals": proposals,
    }
