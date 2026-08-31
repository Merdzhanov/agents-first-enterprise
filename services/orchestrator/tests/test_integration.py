"""End-to-end integration suite for the Enterprise Multi-Agent Fleet Engine.

Runs the REAL google-adk 2.6.2 engine (fleet_workflow.FLEET_WORKFLOW driven by
a real Runner) through the FastAPI app, with all external boundaries mocked:

  - VertexGeminiClient LLM methods -> deterministic Pydantic responses
  - Dart node HTTP calls           -> deterministic dict responses

Validated contract:
  1. /fleet/discovery  -> HITL pause (REQUEST_INPUT + ideas + hackathons)
  2. /fleet/session/*  -> live telemetry mirrors the ADK session state
  3. /fleet/ceo-decision -> background resume drives the pipeline to 'completed'
  4. skip decision archives the workflow with zero spend
  5. Manual orchestration fallback mode remains functional
  6. Scheduler refuses duplicate discovery for the same hackathon id
"""
from __future__ import annotations

import asyncio
import uuid
from typing import Any, Dict, List

import pytest
from fastapi.testclient import TestClient

import app.agents as agents_mod
import app.scheduler as scheduler_mod
import app.fleet_workflow as fw
from app.main import SCHEDULER, app
from app.schemas import (
    ArchitectureComponent,
    ArchitectureSpec,
    DualProposalResponse,
    GeneratedFile,
    IdeaProposal,
    SubmissionPackage,
)

MOCK_OPPORTUNITY: Dict[str, Any] = {
    "id": "hack_google_cloud_agent_challenge",
    "title": "Google Cloud & Vertex AI Agent Challenge",
    "url": "https://googlecloudagents.devpost.com",
    "submission_deadline": "2026-09-30",
    "prize_pool": 100000,
    "tracks": ["Enterprise AI", "Agentic Systems"],
}


def _fake_dart(endpoint_path: str, payload: Any = None, *args: Any, **kwargs: Any) -> Dict[str, Any]:
    """Deterministic stand-in for the Dart Functional Node microservice."""
    if endpoint_path == "tasks/parse-brief":
        return {
            "status": "success",
            "source": "pytest_mock",
            "total_evaluated": 1,
            "filtered_count": 1,
            "matches": [dict(MOCK_OPPORTUNITY)],
        }
    if endpoint_path == "tasks/provision-repo":
        p = payload or {}
        repo_name = p.get("repo_name", "prototype-repo")
        return {
            "status": "created",
            "repo_name": repo_name,
            "repo_url": f"https://github.com/mock-org/{repo_name}",
            "provider": p.get("provider", "github"),
        }
    if endpoint_path == "tasks/commit-files":
        files = (payload or {}).get("files") or []
        paths = [f.get("path") if isinstance(f, dict) else str(f) for f in files]
        return {"status": "committed", "commit_sha": "deadbeef", "files_committed": paths}
    return {"status": "ok", "echo": payload}


@pytest.fixture
def mock_dart(monkeypatch: pytest.MonkeyPatch) -> None:
    """Patches every import site of execute_dart_task."""
    monkeypatch.setattr(agents_mod, "execute_dart_task", _fake_dart)
    monkeypatch.setattr(scheduler_mod, "execute_dart_task", _fake_dart)


# ---------------------------------------------------------------------
# LLM mocks — deterministic Pydantic responses on the shared singleton
# ---------------------------------------------------------------------
def _mock_proposals() -> DualProposalResponse:
    return DualProposalResponse(
        idea_a=IdeaProposal(
            id="idea_a_event_fleet",
            title="EphemeraFlow: Governed Multi-Agent Fleet",
            summary="Hybrid polyglot architecture with Dart Shelf workers on Cloud Run.",
            tech_stack=["Google ADK 2.0", "Dart Shelf", "Cloud Run"],
            track_fit="Enterprise AI",
            impact="99.9% uptime",
            repo_name="ephemeraflow-governed-fleet",
        ),
        idea_b=IdeaProposal(
            id="idea_b_compliance_rag",
            title="ArmorGuard: Row-Level Secure Multi-Tenant Hub",
            summary="Privacy-first architecture with strict tenant isolation.",
            tech_stack=["Vertex AI Gemini", "Cloud SQL RLS"],
            track_fit="Security & Governance",
            impact="Zero cross-tenant leaks",
            repo_name="armorguard-secure-hub",
        ),
        reasoning="Both ideas map to the discovered hackathon tracks.",
    )


@pytest.fixture
def llm_calls(monkeypatch: pytest.MonkeyPatch) -> Dict[str, int]:
    """Patches the shared VertexGeminiClient singleton (used by main.py,
    fleet_workflow.py and every agent) with deterministic Pydantic responses
    and counts every LLM invocation so tests can assert zero-spend paths."""
    calls = {"proposals": 0, "architecture": 0, "source_file": 0, "submission": 0}
    llm = fw.LLM_CLIENT

    def fake_proposals(opportunity: Dict[str, Any], memory_context: Any = None) -> DualProposalResponse:
        calls["proposals"] += 1
        return _mock_proposals()

    def fake_architecture(idea: Dict[str, Any], git_provider: str = "GITHUB") -> ArchitectureSpec:
        calls["architecture"] += 1
        return ArchitectureSpec(
            # Mirrors the real VertexGeminiClient.generate_architecture contract
            # (llm.py fallback): "Cloud Native Architecture: <idea title>".
            title=f"Cloud Native Architecture: {idea.get('title', 'Enterprise Prototype')}",
            diagram_mermaid="graph TD; A[Cloud Run] --> B[Cloud SQL]",
            components=[
                ArchitectureComponent(name="API Gateway", service_type="Cloud Run", role="Serves the fleet API"),
            ],
        )

    def fake_source_file(
        idea: Dict[str, Any],
        architecture: Any,
        file_path: str,
        purpose: str,
        existing_files: List[str],
        ceo_feedback: Any = None,
        is_critical: bool = False,
    ) -> GeneratedFile:
        calls["source_file"] += 1
        return GeneratedFile(
            path=file_path,
            content=f"# mock implementation of {file_path}\n",
            language="python",
            commit_message=f"feat: scaffold {file_path}",
        )

    def fake_submission(idea: Dict[str, Any], repo_url: str, test_results: str) -> SubmissionPackage:
        calls["submission"] += 1
        return SubmissionPackage(
            title=idea.get("title", "Enterprise Prototype"),
            tagline="Autonomous governed fleet prototype",
            demo_script_markdown="## 0:00 Intro\nThe fleet wakes up...",
            devpost_description="# Prototype\nBuilt with the Google ADK workflow engine.",
            features_and_functionality=["HITL CEO gates", "Real ADK Runner"],
            technologies_used=["Vertex AI", "Cloud Run"],
            learnings="Workflow interrupts map cleanly onto HITL gates.",
        )

    monkeypatch.setattr(llm, "generate_proposals", fake_proposals)
    monkeypatch.setattr(llm, "generate_architecture", fake_architecture)
    monkeypatch.setattr(llm, "generate_source_file", fake_source_file)
    monkeypatch.setattr(llm, "generate_submission", fake_submission)
    return calls


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)

# ---------------------------------------------------------------------
# 1. Health & static wiring
# ---------------------------------------------------------------------
def test_health(client: TestClient) -> None:
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "healthy"
    assert body["default_execution_mode"] == "adk_runner"


# ---------------------------------------------------------------------
# 2. Full HITL flow: discovery -> pause -> CEO decision -> completed
# ---------------------------------------------------------------------
def test_full_hitl_flow_approve_idea_a(
    client: TestClient, mock_dart: None, llm_calls: Dict[str, int]
) -> None:
    sid = f"it_{uuid.uuid4().hex[:8]}"

    # --- Phase 1: discovery must pause at the CEO gate ---
    res = client.post("/fleet/discovery", json={"session_id": sid, "raw_feed": {}})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["status"] == "awaiting_ceo_decision"
    assert body["execution_mode"] == "adk_runner"

    # HITL pause contract (ADK request_input + fleet payload)
    ri = body["request_input"]
    assert ri["type"] == "REQUEST_INPUT"
    assert ri["interrupt_id"]
    assert ri["state_key"] == fw.CEO_DECISION_GATE
    assert ri["prompt"]
    option_ids = [o["id"] for o in ri["options"]]
    assert {"approve_idea_a", "approve_idea_b", "skip_implementation"} <= set(option_ids)

    # Proposals + source hackathon exposed for the dashboard
    assert body["data"]["idea_a"]["title"] == "EphemeraFlow: Governed Multi-Agent Fleet"
    assert body["data"]["idea_b"]["repo_name"] == "armorguard-secure-hub"
    assert body["hackathons"] and body["hackathons"][0]["id"] == MOCK_OPPORTUNITY["id"]
    assert body["opportunity"]["url"] == MOCK_OPPORTUNITY["url"]

    # Live telemetry mirrors the pause
    sess = client.get(f"/fleet/session/{sid}").json()
    assert sess["status"] == "awaiting_ceo_decision"
    assert sess["state"]["idea_a"]["title"].startswith("EphemeraFlow")
    assert llm_calls["proposals"] == 1

    # --- Phase 2: CEO decision resumes the REAL ADK Runner to completion ---
    res = client.post(
        "/fleet/ceo-decision",
        json={"session_id": sid, "decision_choice": "approve_idea_a"},
    )
    assert res.status_code == 200, res.text
    assert res.json()["status"] == "processing_in_background"

    # TestClient executes background tasks synchronously -> pipeline finished
    sess = client.get(f"/fleet/session/{sid}").json()
    assert sess["status"] == "completed", sess
    state = sess["state"]
    assert state["ceo_decision_choice"] == "approve_idea_a"
    assert state["selected_idea"]["repo_name"] == "ephemeraflow-governed-fleet"
    assert "mock-org" in state["git_repo"]["repo_url"]
    assert state["architecture_spec"]["title"].startswith("Cloud Native Architecture")
    assert state["committed_files"], "LeadDev must commit the scaffolded files"
    assert state["submission_package"]["tagline"]

    # Exactly one deterministic call per LLM stage -> zero wasted spend
    assert llm_calls["proposals"] == 1
    assert llm_calls["architecture"] == 1
    assert llm_calls["submission"] == 1
    assert llm_calls["source_file"] >= 1

    # Execution traces were recorded for the dashboard
    traces = client.get(f"/fleet/session/{sid}/traces").json()
    assert isinstance(traces, list)

    # The artifacts endpoint aggregates every deliverable from state
    arts = client.get(f"/fleet/session/{sid}/artifacts")
    assert arts.status_code == 200, arts.text
    arts = arts.json()
    assert arts["status"] == "completed"
    assert "mock-org" in arts["git_repo"]["repo_url"]
    assert arts["architecture_spec"]["title"].startswith("Cloud Native Architecture")
    assert arts["committed_files"]
    assert arts["submission_package"]["tagline"]


# ---------------------------------------------------------------------
# 3. Skip decision archives the workflow with zero LLM spend after gate
# ---------------------------------------------------------------------
def test_skip_archives_with_zero_spend(
    client: TestClient, mock_dart: None, llm_calls: Dict[str, int]
) -> None:
    sid = f"it_{uuid.uuid4().hex[:8]}"

    res = client.post("/fleet/discovery", json={"session_id": sid, "raw_feed": {}})
    assert res.status_code == 200
    assert res.json()["status"] == "awaiting_ceo_decision"
    assert llm_calls["proposals"] == 1

    res = client.post(
        "/fleet/ceo-decision",
        json={"session_id": sid, "decision_choice": "skip_implementation"},
    )
    assert res.status_code == 200
    assert res.json()["status"] == "skipped"

    sess = client.get(f"/fleet/session/{sid}").json()
    assert sess["status"] == "skipped"
    # Zero-spend guarantee: no heavy agents ran after the skip decision
    assert llm_calls["architecture"] == 0
    assert llm_calls["source_file"] == 0
    assert llm_calls["submission"] == 0


# ---------------------------------------------------------------------
# 4. Manual orchestration fallback remains functional end-to-end
# ---------------------------------------------------------------------
def test_manual_mode_end_to_end(
    client: TestClient, mock_dart: None, llm_calls: Dict[str, int]
) -> None:
    sid = f"it_{uuid.uuid4().hex[:8]}"

    res = client.post(
        "/fleet/discovery",
        json={"session_id": sid, "raw_feed": {}, "use_adk_runner": False},
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["execution_mode"] == "manual"
    assert body["request_input"]["type"] == "REQUEST_INPUT"
    assert body["data"]["idea_a"]["repo_name"] == "ephemeraflow-governed-fleet"

    res = client.post(
        "/fleet/ceo-decision",
        json={
            "session_id": sid,
            "decision_choice": "approve_idea_b",
            "use_adk_runner": False,
        },
    )
    assert res.status_code == 200, res.text
    assert res.json()["status"] == "processing_in_background"

    sess = client.get(f"/fleet/session/{sid}").json()
    assert sess["status"] == "completed", sess
    state = sess["state"]
    assert state["selected_idea"]["repo_name"] == "armorguard-secure-hub"
    assert state["committed_files"]
    assert state["submission_package"]["title"]


# ---------------------------------------------------------------------
# 5. Scheduler dedup: same Devpost hackathon id never plans twice
# ---------------------------------------------------------------------
def test_scheduler_no_duplicate_for_same_hackathon(
    mock_dart: None, llm_calls: Dict[str, int]
) -> None:
    first = asyncio.run(SCHEDULER.run_discovery_cycle())
    assert len(first) == 1
    assert first[0]["hackathon_id"] == MOCK_OPPORTUNITY["id"]
    assert first[0]["idea_a"]["title"].startswith("EphemeraFlow")
    assert first[0]["request_input"]["type"] == "REQUEST_INPUT"

    # Container restart simulation: identical cycle must be a no-op
    second = asyncio.run(SCHEDULER.run_discovery_cycle())
    assert second == []
    # No duplicated LLM planning spend either
    assert llm_calls["proposals"] == 1


# ---------------------------------------------------------------------
# 6. Validation guards: unknown sessions and invalid decisions
# ---------------------------------------------------------------------
def test_unknown_session_returns_404(client: TestClient) -> None:
    assert client.get("/fleet/session/does_not_exist").status_code == 404


def test_invalid_decision_choice_rejected(client: TestClient) -> None:
    res = client.post(
        "/fleet/ceo-decision",
        json={"session_id": "it_invalid", "decision_choice": "yolo_everything"},
    )
    assert res.status_code == 422


# ---------------------------------------------------------------------
# 7. Governance surfaces: sessions registry, memory bank, security, system
# ---------------------------------------------------------------------
def test_sessions_registry_lists_created_sessions(client: TestClient) -> None:
    client.post("/fleet/discovery", json={"session_id": "gov_sess_1", "raw_feed": {}})
    res = client.get("/fleet/sessions?limit=50&include_state=true")
    assert res.status_code == 200
    body = res.json()
    assert body["count"] >= 1
    ids = [s["session_id"] for s in body["sessions"]]
    assert "gov_sess_1" in ids
    record = next(s for s in body["sessions"] if s["session_id"] == "gov_sess_1")
    assert {"status", "current_agent", "state", "tenant_id", "updated_at"} <= set(record)


def test_memory_store_and_list_with_tenant_isolation(client: TestClient) -> None:
    res = client.post(
        "/fleet/memory",
        json={
            "topic": "deployment_policy",
            "content": "Always require CEO approval before Cloud Run deploy.",
            "tenant_id": "tenant_alpha",
        },
    )
    assert res.status_code == 200
    assert res.json()["status"] == "stored"

    listed = client.get("/fleet/memory").json()
    assert listed["count"] >= 1
    topics = [m["topic"] for m in listed["memories"]]
    assert "deployment_policy" in topics

    # Semantic search on the bank returns the stored fact for its tenant
    searched = client.get(
        "/fleet/memory", params={"tenant_id": "tenant_alpha"}
    ).json()
    assert all(m["tenant_id"] == "tenant_alpha" for m in searched["memories"])


def test_security_posture_reports_controls(client: TestClient) -> None:
    res = client.get("/fleet/security")
    assert res.status_code == 200
    body = res.json()
    assert "OIDC" in body["service_to_service_auth"]
    assert "RLS" in body["session_isolation"]
    assert len(body["human_in_the_loop_gates"]) == 2
    assert isinstance(body["tenants_observed"], list)
    assert body["cors_policy"].startswith("allow_origins")


def test_system_introspection_exposes_engine(client: TestClient) -> None:
    res = client.get("/fleet/system")
    assert res.status_code == 200
    body = res.json()
    assert body["execution_engine"].startswith("Google ADK")
    assert body["default_execution_mode"] == "adk_runner"
    assert set(body["agents"]) == {
        "ScoutAgent", "PlannerAgent", "ArchitectAgent",
        "LeadDevAgent", "MarketingAgent", "DeploymentAgent",
    }
    assert "pgvector" in body["memory_store"]
    assert "scheduler_interval_minutes" in body
