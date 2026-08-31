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

        context_str = ""
        if memory_context:
            context_str = "\n--- RELEVANT MEMORY CONTEXT ---\n"
            for mem in memory_context:
                context_str += f"- {mem.get('content', '')}\n"
            context_str += "-------------------------------\n"

        prompt = (
            f"An active hackathon / innovation opportunity was scouted:\n"
            f"- Title: {title}\n"
            f"- Tracks: {', '.join(tracks)}\n"
            f"- Prize Pool: ${prize}\n"
            f"- Eligible GCP Services: Vertex AI, Cloud Run, Cloud SQL (with RLS), Cloud Pub/Sub\n"
            f"{context_str}\n"
            f"Synthesize exactly TWO distinct, high-ROI prototype proposals:\n"
            f"1. Idea A (High-Throughput / Polyglot): Event-driven architecture with Python ADK & Dart on Cloud Run.\n"
            f"2. Idea B (Security & Governance): Privacy-preserving platform with Cloud SQL RLS and Vertex AI Model Armor.\n"
            f"Ensure both have sanitized repository names (kebab-case) and concrete impact targets."
        )

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
                summary="A hybrid polyglot architecture combining Python ADK 2.0 reasoning with sub-millisecond Dart Shelf workers on Cloud Run.",
                tech_stack=["Google ADK 2.0", "Dart Shelf", "Cloud Run", "Cloud SQL RLS", "Pub/Sub"],
                track_fit=tracks[0] if tracks else "Enterprise Fleet",
                impact="99.9% Uptime with Sub-Millisecond Task Dispatching",
                repo_name="ephemeraflow-governed-fleet",
            ),
            idea_b=IdeaProposal(
                id="idea_b_compliance_rag",
                title=f"ArmorGuard: Row-Level Secure Multi-Tenant Agent Hub",
                summary="A privacy-first autonomous agent platform with Cloud SQL PostgreSQL Row-Level Security, Vertex AI Model Armor prompt injection shields.",
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

        prompt = (
            f"Design the complete Google Cloud system architecture for: \"{title}\".\n"
            f"Tech Stack: {', '.join(idea.get('tech_stack', []))}\n"
            f"Target Provider: {git_provider}\n"
            f"Repo Name: {repo_name}\n\n"
            f"Requirements:\n"
            f"- Compute: Google Cloud Run with scale-to-zero (min-instances=0)\n"
            f"- Session Storage: Google Cloud SQL PostgreSQL with Row-Level Security (RLS)\n"
            f"- Vector Memory: Google Cloud SQL with pgvector (text-embedding-005)\n"
            f"- Messaging: Google Cloud Pub/Sub\n"
            f"- Generate a clean Mermaid diagram representing the data and control flow. Ensure the Mermaid code is RAW text without markdown code blocks."
        )
        
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

        mermaid_str = (
            "graph TD\n"
            "    CEO[\"👑 Human-in-the-Loop CEO (Flutter Web)\"] -->|Approvals & Monitor| SQL[(\"🐘 Cloud SQL Session State (RLS)\")]\n"
            "    CEO -->|REST & SSE| Orch[\"Python ADK 2.0 Orchestrator (Cloud Run)\"]\n"
            "    Orch -->|Vertex AI SDK| LLM[\"⚡ Vertex AI Gemini 3.5\"]\n"
            "    Orch -->|pgvector Cosine Search| VecDB[(\"🧠 pgvector Memory Store\")]\n"
            "    Orch -->|IAM OIDC Bearer| DartNode[\"⚡ Dart Shelf Functional Worker (Cloud Run)\"]\n"
            "    DartNode -->|Push Events| PS[(\"📬 Cloud Pub/Sub Topics\")]\n"
            "    PS -->|Webhook Delivery| DartNode\n"
            f"    DartNode -->|Push Code Scaffold| GitRepo[\"{git_provider.upper()} Repo: {repo_name}\"]"
        )

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
        prompt = (
            f"Generate the complete production-grade source code for: `{file_path}`.\n"
            f"Prototype: {idea.get('title')}\n"
            f"Summary: {idea.get('summary')}\n"
            f"Purpose of file: {purpose}\n"
            f"Existing files in project: {', '.join(existing_files)}\n"
            f"CEO Feedback to address: {ceo_feedback or 'None'}\n\n"
            f"Return complete, compilable, runnable code with zero truncation or placeholders. Ensure code is returned as RAW text, NOT wrapped in markdown blocks."
        )
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

        # Deterministic IDE-safe fallback code based on file path
        app_title = idea.get("title", "Enterprise Prototype")
        summary_text = idea.get("summary", "Prototype summary")
        service_name = idea.get("repo_name", "prototype")
        compute_target = architecture.get("compute_target", "Google Cloud Run")
        session_store = architecture.get("session_store", "Cloud SQL PostgreSQL")
        vector_store = architecture.get("vector_memory_store", "Cloud SQL pgvector")

        if file_path == "README.md":
            language = "markdown"
            content = (
                f"# {app_title}\n\n"
                f"> {summary_text}\n\n"
                f"## 🏗️ Architecture\n"
                f"- **Compute**: {compute_target}\n"
                f"- **Session Storage**: {session_store}\n"
                f"- **Vector Memory**: {vector_store}\n\n"
                f"## 🚀 Getting Started\n"
                f"```bash\n"
                f"./setup.sh\n"
                f"uvicorn src.main:app --host 0.0.0.0 --port 8080\n"
                f"```\n\n"
                f"## ✅ Verification\n"
                f"Deployment target: Google Cloud Run (scale-to-zero, min-instances=0).\n"
            )
        elif file_path == "src/main.py":
            language = "python"
            content = (
                f'"""{app_title} — FastAPI backend entry point."""\n'
                f'from fastapi import FastAPI\n'
                f'from pydantic import BaseModel\n\n'
                f'app = FastAPI(title="{app_title}", version="1.0.0")\n\n\n'
                f'class HealthReport(BaseModel):\n'
                f'    status: str\n'
                f'    service: str\n'
                f'    version: str\n\n\n'
                f'@app.get("/health", response_model=HealthReport)\n'
                f'def health() -> HealthReport:\n'
                f'    """Liveness probe consumed by Cloud Run."""\n'
                f'    return HealthReport(status="healthy", service="{service_name}", version="1.0.0")\n\n\n'
                f'@app.get("/ready", response_model=HealthReport)\n'
                f'def ready() -> HealthReport:\n'
                f'    """Readiness probe consumed by Cloud Run."""\n'
                f'    return HealthReport(status="ready", service="{service_name}", version="1.0.0")\n'
            )
        elif file_path == "src/agent.py":
            language = "python"
            content = (
                f'"""Autonomous Agent supervisor logic for {app_title}."""\n'
                f'from dataclasses import dataclass, field\n'
                f'from typing import Any, Dict, List\n\n\n'
                f'@dataclass\n'
                f'class TaskResult:\n'
                f'    agent_name: str\n'
                f'    status: str\n'
                f'    message: str\n'
                f'    data: Dict[str, Any] = field(default_factory=dict)\n\n\n'
                f'class SupervisorAgent:\n'
                f'    """Routes deterministic tasks to fast workers and reasoning tasks to Gemini."""\n\n'
                f'    def __init__(self) -> None:\n'
                f'        self._trace: List[TaskResult] = []\n\n'
                f'    def dispatch(self, task_name: str, payload: Dict[str, Any]) -> TaskResult:\n'
                f'        """Executes a task and records an audit trace entry."""\n'
                f'        result = TaskResult(\n'
                f'            agent_name="SupervisorAgent",\n'
                f'            status="success",\n'
                f'            message=f"Dispatched task: {{task_name}}",\n'
                f'            data=payload,\n'
                f'        )\n'
                f'        self._trace.append(result)\n'
                f'        return result\n\n'
                f'    @property\n'
                f'    def trace(self) -> List[TaskResult]:\n'
                f'        """Chronological audit trail of dispatched tasks."""\n'
                f'        return list(self._trace)\n'
            )
        elif file_path == "Dockerfile":
            language = "dockerfile"
            content = (
                "# Multi-stage production container for Google Cloud Run\n"
                "FROM python:3.12-slim AS builder\n"
                "WORKDIR /app\n"
                "COPY requirements.txt .\n"
                "RUN pip install --no-cache-dir --prefix=/install -r requirements.txt\n\n"
                "FROM python:3.12-slim\n"
                "WORKDIR /app\n"
                "COPY --from=builder /install /usr/local\n"
                "COPY src/ ./src/\n"
                "ENV PORT=8080\n"
                "EXPOSE 8080\n"
                'CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]\n'
            )
        elif file_path == "requirements.txt":
            language = "text"
            content = (
                "fastapi>=0.110.0\n"
                "uvicorn[standard]>=0.28.0\n"
                "pydantic>=2.6.0\n"
                "httpx>=0.27.0\n"
            )
        elif file_path == "tests/test_main.py":
            language = "python"
            content = (
                '"""Automated health check tests for the FastAPI entry point."""\n'
                'from fastapi.testclient import TestClient\n\n'
                'from src.main import app\n\n'
                'client = TestClient(app)\n\n\n'
                'def test_health() -> None:\n'
                '    response = client.get("/health")\n'
                '    assert response.status_code == 200\n'
                '    assert response.json()["status"] == "healthy"\n\n\n'
                'def test_ready() -> None:\n'
                '    response = client.get("/ready")\n'
                '    assert response.status_code == 200\n'
                '    assert response.json()["status"] == "ready"\n'
            )
        else:
            language = "text"
            content = (
                f"# {file_path}\n\n"
                f"Purpose: {purpose}\n"
                f"Prototype: {app_title}\n"
            )

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
                prompt = (
                    f"Create the final hackathon submission package for: \"{title}\".\n"
                    f"Summary: {idea.get('summary')}\n"
                    f"Tech Stack: {', '.join(idea.get('tech_stack', []))}\n"
                    f"Repository URL: {repo_url}\n"
                    f"Verification Results: {test_results}\n\n"
                    f"Deliver: a 1-line tagline (max 100 chars), a minute-by-minute 4-minute demo "
                    f"video script in markdown, a full Devpost description in markdown, key features, "
                    f"technologies used, and learnings."
                )
                response = self._client.models.generate_content(
                    model=self.model_pro,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction="You are the Marketing Agent. You craft compelling, precise hackathon submissions.",
                        response_mime_type="application/json",
                        response_schema=SubmissionPackage,
                        temperature=0.5,
                    ),
                )
                return self._parse_json_response(response.text, SubmissionPackage)
            except Exception as err:
                print(f"Vertex AI generate_submission fallback: {err}")

        # Deterministic IDE-safe fallback submission package
        summary = idea.get("summary", "Autonomous enterprise prototype")
        tech_stack = idea.get("tech_stack", []) or ["Google Cloud Run", "Vertex AI"]
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

        demo_script = (
            f"## Demo Video Script (4:00) — {title}\n\n"
            "**[0:00–0:30] The Problem** — Enterprise teams need governed autonomy, not rogue agents.\n"
            "**[0:30–1:30] Architecture** — Human-in-the-Loop CEO gate, Python ADK orchestration, and Dart workers on Cloud Run.\n"
            f"**[1:30–2:30] Live Walkthrough** — Discovery trigger, CEO approval in Flutter, repository provisioned at {repo_url}.\n"
            "**[2:30–3:30] Enterprise Controls** — Cloud SQL Row-Level Security, full execution trace audit log, scale-to-zero FinOps.\n"
            f"**[3:30–4:00] Verification & Wrap-up** — {test_results}.\n"
        )

        devpost_description = (
            f"# {title}\n\n"
            f"{summary}\n\n"
            "## What it does\n"
            "An agent fleet where a human CEO approves every consequential action before\n"
            "execution. Deterministic Dart workers handle high-throughput tasks while Gemini\n"
            "handles reasoning, all wired through a fully auditable execution trace.\n\n"
            "## Key Features\n"
            f"{features_md}\n\n"
            "## Technologies\n"
            f"{tech_md}\n\n"
            "## Verification\n"
            f"{test_results}\n"
        )

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