"""Cognitive LLM Engine using Google Vertex AI (Gemini 3.5 & 2.5 Pro / Flash).

Provides structured Pydantic output generation for:
- 2-Idea Proposal Synthesis (Planner)
- Cloud Native Architecture & Mermaid Synthesis (Architect)
- Iterative Source Code Generation (Lead Dev)
- Submission & Video Script Synthesis (Marketing)
"""
from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional, Tuple

from .schemas import (
    ArchitectureSpec,
    DualProposalResponse,
    GeneratedFile,
    IdeaProposal,
    SubmissionPackage,
)


class VertexGeminiClient:
    """Client for Vertex AI Gemini models with structured JSON schema output."""

    def __init__(
        self,
        model_fast: str = "gemini-2.5-flash",
        model_pro: str = "gemini-2.5-pro",
        project_id: Optional[str] = None,
        location: Optional[str] = None,
    ):
        self.model_fast = model_fast
        self.model_pro = model_pro
        self.project_id = project_id or os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("GCP_PROJECT")
        self.location = location or os.getenv("GOOGLE_CLOUD_LOCATION") or "global"
        self._client = None
        self._init_client()

    def _init_client(self) -> None:
        """Initializes the google-genai client if credentials/SDK are present."""
        try:
            from google import genai

            if os.getenv("GOOGLE_GENAI_USE_VERTEXAI") == "True" or self.project_id:
                self._client = genai.Client(
                    vertexai=True,
                    project=self.project_id,
                    location=self.location,
                )
            elif os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY"):
                self._client = genai.Client(
                    api_key=os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY"),
                )
        except Exception as e:
            # Fallback will activate gracefully in offline / unit testing environments
            print(f"GenAI Client Init Note: {e}")
            self._client = None

    def _parse_json_response(self, text: str, schema_class: Any) -> Any:
        """Strips markdown code blocks if the LLM hallucinated them, then validates."""
        clean_text = text.strip()
        if clean_text.startswith("```json"):
            clean_text = clean_text[7:]
        elif clean_text.startswith("```"):
            clean_text = clean_text[3:]
        
        if clean_text.endswith("```"):
            clean_text = clean_text[:-3]
            
        return schema_class.model_validate_json(clean_text.strip())

    def generate_proposals(
        self,
        opportunity: Dict[str, Any],
        memory_context: Optional[List[Dict[str, Any]]] = None,
    ) -> DualProposalResponse:
        """Calls Gemini to synthesize 2 competing prototype proposals."""
        title = opportunity.get("title", "Developer Challenge")
        tracks = opportunity.get("tracks", ["Enterprise AI"])
        prize = opportunity.get("prize_pool", 50000)

        # Инжектиране на векторната памет в промпта, ако има такава
        context_str = ""
        if memory_context:
            context_str = "\n--- RELEVANT MEMORY CONTEXT ---\n"
            for mem in memory_context:
                context_str += f"- {mem.get('content', '')}\n"
            context_str += "-------------------------------\n"

        prompt = f"""
An active hackathon / innovation opportunity was scouted:
- Title: {title}
- Tracks: {', '.join(tracks)}
- Prize Pool: ${prize}
- Eligible GCP Services: Vertex AI, Cloud Run, Cloud SQL (with RLS), Cloud Pub/Sub, Cloud Secret Manager
{context_str}
Synthesize exactly TWO distinct, high-ROI prototype proposals:
1. Idea A (High-Throughput / Polyglot): An event-driven architecture combining Python ADK 2.0 reasoning with compiled Dart Shelf functional workers on Cloud Run.
2. Idea B (Security & Governance): A privacy-preserving, enterprise-governed platform featuring Cloud SQL PostgreSQL Row-Level Security (RLS) and Vertex AI Model Armor.

Ensure both have sanitized repository names (kebab-case) and concrete impact targets.
"""

        if self._client:
            try:
                from google.genai import types
                response = self._client.models.generate_content(
                    model=self.model_fast,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction="You are the Executive Planner Agent in an Agent-First Enterprise prototype factory. Your role is to formulate high-impact, actionable business proposals.",
                        response_mime_type="application/json",
                        response_schema=DualProposalResponse,
                        temperature=0.7,
                    ),
                )
                return self._parse_json_response(response.text, DualProposalResponse)
            except Exception as err:
                print(f"Vertex AI generate_proposals fallback: {err}")

        # Deterministic structured fallback
        return DualProposalResponse(
            idea_a=IdeaProposal(
                id="idea_a_event_fleet",
                title=f"EphemeraFlow: Governed Multi-Agent Fleet for {title}",
                summary=(
                    "A hybrid polyglot architecture combining Python ADK 2.0 reasoning "
                    "with sub-millisecond Dart Shelf workers on Cloud Run, backed by "
                    "Cloud SQL transactional session storage and Pub/Sub event streams."
                ),
                tech_stack=["Google ADK 2.0", "Dart Shelf", "Cloud Run", "Cloud SQL RLS", "Pub/Sub"],
                track_fit=tracks[0] if tracks else "Enterprise Fleet",
                impact="99.9% Uptime with Sub-Millisecond Task Dispatching",
                repo_name="ephemeraflow-governed-fleet",
            ),
            idea_b=IdeaProposal(
                id="idea_b_compliance_rag",
                title=f"ArmorGuard: Row-Level Secure Multi-Tenant Agent Hub",
                summary=(
                    "A privacy-first autonomous agent platform with Cloud SQL PostgreSQL Row-Level "
                    "Security, Vertex AI Model Armor prompt injection shields, and OpenTelemetry auditing."
                ),
                tech_stack=["Vertex AI Gemini", "Cloud SQL PostgreSQL RLS", "Model Armor", "OpenTelemetry"],
                track_fit=tracks[-1] if tracks else "Security & Governance",
                impact="Zero Cross-Tenant Leaks with Provable Cryptographic Traces",
                repo_name="armorguard-secure-agent-hub",
            ),
            reasoning=f"Both proposals optimize for the '{tracks[0]}' track while leveraging scale-to-zero Google Cloud Run compute.",
        )

    def generate_architecture(
        self,
        idea: Dict[str, Any],
        git_provider: str = "GITHUB",
    ) -> ArchitectureSpec:
        """Synthesizes Google Cloud system architecture and Mermaid topology."""
        title = idea.get("title", "Enterprise Prototype")
        repo_name = idea.get("repo_name", "prototype-repo")

        prompt = f"""
Design the complete Google Cloud system architecture for: "{title}".
Tech Stack: {', '.join(idea.get('tech_stack', []))}
Target Provider: {git_provider}
Repo Name: {repo_name}

Requirements:
- Compute: Google Cloud Run with scale-to-zero (min-instances=0)
- Session Storage: Google Cloud SQL PostgreSQL with Row-Level Security (RLS)
- Vector Memory: Google Cloud SQL with pgvector (text-embedding-005)
- Messaging: Google Cloud Pub/Sub
- Generate a clean Mermaid diagram representing the data and control flow. Ensure the Mermaid code is RAW text without markdown code blocks.
"""
        if self._client:
            try:
                from google.genai import types
                response = self._client.models.generate_content(
                    model=self.model_pro,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction="You are the Architect Agent. You design robust, scalable, and secure Google Cloud Native architectures.",
                        response_mime_type="application/json",
                        response_schema=ArchitectureSpec,
                        temperature=0.3,
                    ),
                )
                return self._parse_json_response(response.text, ArchitectureSpec)
            except Exception as err:
                print(f"Vertex AI generate_architecture fallback: {err}")

        mermaid_str = f"""graph TD
    CEO["👑 Human-in-the-Loop CEO (Flutter Web)"] -->|Approvals & Monitor| SQL[("🐘 Cloud SQL Session State (RLS)")]
    CEO -->|REST & SSE| Orch["Python ADK 2.0 Orchestrator (Cloud Run)"]
    Orch -->|Vertex AI SDK| LLM["⚡ Vertex AI Gemini 3.5"]
    Orch -->|pgvector Cosine Search| VecDB[("🧠 pgvector Memory Store")]
    Orch -->|IAM OIDC Bearer| DartNode["⚡ Dart Shelf Functional Worker (Cloud Run)"]
    DartNode -->|Push Events| PS[("📬 Cloud Pub/Sub Topics")]
    PS -->|Webhook Delivery| DartNode
    DartNode -->|Push Code Scaffold| GitRepo["{git_provider.upper()} Repo: {repo_name}"]"""

        return ArchitectureSpec(
            title=f"Cloud Native Architecture: {title}",
            compute_target="Google Cloud Run (min-instances=0 for FinOps Scale-to-Zero)",
            session_store="Cloud SQL PostgreSQL (with Row-Level Security)",
            vector_memory_store="Cloud SQL pgvector (text-embedding-005, 768-dim)",
            diagram_mermaid=mermaid_str,
        )

    def generate_source_file(
        self,
        idea: Dict[str, Any],
        architecture: Dict[str, Any],
        file_path: str,
        purpose: str,
        existing_files: List[str],
        ceo_feedback: Optional[str] = None,
        is_critical: bool = False,
    ) -> GeneratedFile:
        """Generates a complete source file for the downstream repository."""
        prompt = f"""
Generate the complete production-grade source code for: `{file_path}`.
Prototype: {idea.get('title')}
Summary: {idea.get('summary')}
Purpose of file: {purpose}
Existing files in project: {', '.join(existing_files)}
CEO Feedback to address: {ceo_feedback or 'None'}

Return complete, compilable, runnable code with zero truncation or placeholders. Ensure code is returned as RAW text, NOT wrapped in markdown blocks.
"""
        if self._client:
            try:
                from google.genai import types
                response = self._client.models.generate_content(
                    model=self.model_pro,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction="You are the Lead Developer Agent. You write production-grade, bug-free, and well-documented source code.",
                        response_mime_type="application/json",
                        response_schema=GeneratedFile,
                        temperature=0.2,
                    ),
                )
                return self._parse_json_response(response.text, GeneratedFile)
            except Exception as err:
                print(f"Vertex AI generate_source_file fallback: {err}")

        # Deterministic fallback code based on file path
        if file_path == "README.md":
            language = "markdown"
            content = f"""# {idea.get('title')}

> {idea.get('summary')}

## 🏗️ Architecture
- **Compute**: {architecture.get('compute_target', 'Google Cloud Run')}
- **Session Storage**: {architecture.get('session_store', 'Cloud SQL PostgreSQL with RLS')}
- **Vector Memory**: {architecture.get('vector_memory_store', 'Cloud SQL pgvector')}

## 🚀 Getting Started
```bash
./setup.sh
uvicorn src.main:app --host 0.0.0.0 --port 8080
```

## ✅ Verification
Deployment target: Google Cloud Run (scale-to-zero, min-instances=0).
"""
        elif file_path == "src/main.py":
            language = "python"
            service_name = idea.get("repo_name", "prototype")
            content = f'''"""{idea.get('title', 'Enterprise Prototype')} — FastAPI backend entry point with health probes."""
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="{idea.get('title', 'Enterprise Prototype')}", version="1.0.0")


class HealthReport(BaseModel):
    status: str
    service: str
    version: str


@app.get("/health", response_model=HealthReport)
def health() -> HealthReport:
    """Liveness probe consumed by Cloud Run."""
    return HealthReport(status="healthy", service="{service_name}", version="1.0.0")


@app.get("/ready", response_model=HealthReport)
def ready() -> HealthReport:
    """Readiness probe consumed by Cloud Run."""
    return HealthReport(status="ready", service="{service_name}", version="1.0.0")
'''
        elif file_path == "src/agent.py":
            language = "python"
            content = f'''"""Autonomous Agent supervisor logic for {idea.get('title', 'the prototype')}."""
from dataclasses import dataclass, field
from typing import Any, Dict, List


@dataclass
class TaskResult:
    agent_name: str
    status: str
    message: str
    data: Dict[str, Any] = field(default_factory=dict)


class SupervisorAgent:
    """Routes deterministic tasks to fast workers and reasoning tasks to Gemini."""

    def __init__(self) -> None:
        self._trace: List[TaskResult] = []

    def dispatch(self, task_name: str, payload: Dict[str, Any]) -> TaskResult:
        """Executes a task and records an audit trace entry."""
        result = TaskResult(
            agent_name="SupervisorAgent",
            status="success",
            message=f"Dispatched task: {{task_name}}",
            data=payload,
        )
        self._trace.append(result)
        return result

    @property
    def trace(self) -> List[TaskResult]:
        """Chronological audit trail of dispatched tasks."""
        return list(self._trace)
'''
        elif file_path == "Dockerfile":
            language = "dockerfile"
            content = """# Multi-stage production container for Google Cloud Run
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /install /usr/local
COPY src/ ./src/
ENV PORT=8080
EXPOSE 8080
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
"""
        elif file_path == "requirements.txt":
            language = "text"
            content = """fastapi>=0.110.0
uvicorn[standard]>=0.28.0
pydantic>=2.6.0
httpx>=0.27.0
"""
        elif file_path == "tests/test_main.py":
            language = "python"
            content = '''"""Automated health check tests for the FastAPI entry point."""
from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_ready() -> None:
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"
'''
        else:
            language = "text"
            content = f"""# {file_path}

Purpose: {purpose}
Prototype: {idea.get('title', 'Enterprise Prototype')}
"""

        return GeneratedFile(
            path=file_path,
            content=content,
            language=language,
            commit_message=f"Add {file_path}: {purpose}",
            is_critical_for_review=is_critical,
        )

    def generate_submission(
        self,
        idea: Dict[str, Any],
        repo_url: str,
        test_results: str,
    ) -> SubmissionPackage:
        """Synthesizes final judging deliverables and the 4-minute demo script."""
        title = idea.get("title", "Enterprise Prototype")

        if self._client:
            try:
                from google.genai import types
                prompt = f"""
Create the final hackathon submission package for: "{title}".
Summary: {idea.get('summary')}
Tech Stack: {', '.join(idea.get('tech_stack', []))}
Repository URL: {repo_url}
Verification Results: {test_results}

Deliver: a 1-line tagline (max 100 chars), a minute-by-minute 4-minute demo
video script in markdown, a full Devpost description in markdown, key features,
technologies used, and learnings.
"""
                response = self._client.models.generate_content(
                    model=self.model_pro,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=(
                            "You are the Marketing Agent. You craft compelling, "
                            "precise hackathon submissions."
                        ),
                        response_mime_type="application/json",
                        response_schema=SubmissionPackage,
                        temperature=0.5,
                    ),
                )
                return self._parse_json_response(response.text, SubmissionPackage)
            except Exception as err:
                print(f"Vertex AI generate_submission fallback: {err}")

        # Deterministic fallback submission package for offline / unit test runs
        summary = idea.get("summary", "Autonomous enterprise prototype")
        tech_stack = idea.get("tech_stack", []) or [
            "Google Cloud Run",
            "Vertex AI",
        ]
        tagline = summary if len(summary) <= 100 else summary[:97] + "..."

        features = [
            "Human-in-the-Loop CEO approval gate before any cloud spend",
            "Deterministic Dart Shelf workers for sub-millisecond task dispatch",
            "Cloud SQL session state with Row-Level Security (RLS)",
            "pgvector long-term memory with semantic recall",
            "Full execution trace audit log for every agent action",
        ]
        features_md = "\n".join(f"- {f}" for f in features)
        tech_md = "\n".join(f"- {t}" for t in tech_stack)

        demo_script = f"""## Demo Video Script (4:00) — {title}

**[0:00–0:30] The Problem** — Enterprise teams need governed autonomy, not rogue agents.
**[0:30–1:30] Architecture** — Human-in-the-Loop CEO gate, Python ADK 2.0 orchestration, and Dart Shelf functional workers on Cloud Run.
**[1:30–2:30] Live Walkthrough** — Discovery trigger, CEO approval in Flutter, repository provisioned at {repo_url}.
**[2:30–3:30] Enterprise Controls** — Cloud SQL Row-Level Security, full execution trace audit log, scale-to-zero FinOps.
**[3:30–4:00] Verification & Wrap-up** — {test_results}.
"""

        devpost_description = f"""# {title}

{summary}

## What it does
An agent fleet where a human CEO approves every consequential action before
execution. Deterministic Dart workers handle high-throughput tasks while Gemini
handles reasoning, all wired through a fully auditable execution trace.

## Key Features
{features_md}

## Technologies
{tech_md}

## Verification
{test_results}
"""

        learnings = (
            "Separating deterministic execution (Dart) from probabilistic reasoning "
            "(Gemini) makes agent fleets auditable: every action maps to an approval "
            "gate or a trace row. Human-in-the-loop gates keep cloud spend at exactly "
            "zero until a human says go."
        )

        return SubmissionPackage(
            title=title,
            tagline=tagline,
            demo_script_markdown=demo_script,
            devpost_description=devpost_description,
            features_and_functionality=features,
            technologies_used=tech_stack,
            learnings=learnings,
        )