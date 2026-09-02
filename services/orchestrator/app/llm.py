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
    CodeReview,
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

    def _parse_json_response(self, text: Optional[str], schema_class: Any) -> Any:
        """Strips markdown code blocks if the LLM hallucinated them, then validates."""
        if text is None:
            raise ValueError("LLM returned no text content to parse")
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
        """Calls Gemini to synthesize 2 competing prototype proposals.
        
        The proposals are based ENTIRELY on the opportunity data (title, tracks, prize, rules).
        If no opportunity data is available, raises RuntimeError instead of generating fake proposals.
        """
        title = opportunity.get("title")
        if not title:
            raise RuntimeError(
                "Cannot generate proposals: no hackathon opportunity data available. "
                "The Scout Agent must discover at least one real hackathon first."
            )

        tracks = opportunity.get("tracks", [])
        prize = opportunity.get("prize_pool", 0)
        rules = opportunity.get("rules", opportunity.get("requirements", []))
        eligible_apis = opportunity.get("eligible_gcp_apis", ["Vertex AI", "Cloud Run", "Cloud SQL", "Pub/Sub"])

        context_str = ""
        if memory_context:
            context_str = "\n--- RELEVANT MEMORY CONTEXT ---\n"
            for mem in memory_context:
                context_str += f"- {mem.get('content', '')}\n"
            context_str += "-------------------------------\n"

        rules_str = ""
        if rules:
            rules_str = "\n--- HACKATHON RULES & REQUIREMENTS ---\n"
            for r in rules:
                rules_str += f"- {r}\n"
            rules_str += "----------------------------------------\n"

        prompt = (
            f"An active hackathon / innovation opportunity was scouted:\n"
            f"- Title: {title}\n"
            f"- Tracks: {', '.join(tracks) if tracks else 'General'}\n"
            f"- Prize Pool: ${prize}\n"
            f"- Eligible GCP Services: {', '.join(eligible_apis)}\n"
            f"{rules_str}"
            f"{context_str}\n"
            f"Synthesize exactly TWO distinct, high-ROI prototype proposals that:\n"
            f"1. Directly address the hackathon's specific themes and requirements\n"
            f"2. Leverage the eligible GCP services listed above\n"
            f"3. Are technically feasible within the submission deadline\n"
            f"4. Have sanitized repository names (kebab-case) and concrete impact targets\n"
            f"\n"
            f"Each proposal MUST be unique and tailored to this specific hackathon. "
            f"Do NOT use generic templates — base proposals on the actual opportunity data."
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
                raise RuntimeError(f"Vertex AI generate_proposals failed: {err}") from err

        raise RuntimeError("Vertex AI client not configured (GOOGLE_GENAI_USE_VERTEXAI != True)")

    def generate_architecture(
        self,
        idea: Dict[str, Any],
        git_provider: str = "GITHUB",
        revision_feedback: str = "",
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
            f"- Generate a clean Mermaid diagram representing the data and control flow. Ensure the Mermaid code is RAW text without markdown code blocks.\n\n"
            f"## CEO revision request (MUST be incorporated)\n{revision_feedback or 'No revisions requested — keep the first-pass design.'}"
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
                raise RuntimeError(f"Vertex AI generate_architecture failed: {err}") from err

        raise RuntimeError("Vertex AI client not configured (GOOGLE_GENAI_USE_VERTEXAI != True)")

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
                raise RuntimeError(f"Vertex AI generate_source_file failed: {err}") from err

        raise RuntimeError("Vertex AI client not configured (GOOGLE_GENAI_USE_VERTEXAI != True)")

    def generate_code_review(
        self,
        idea: Dict[str, Any],
        architecture: Dict[str, Any],
        files: List[Dict[str, Any]],
        hackathon_rules: str,
        previous_feedback: str = "",
    ) -> CodeReview:
        """Independent code review: critiques generated files against the
        architecture, the hackathon rules, and basic correctness.

        The Reviewer is deliberately NOT the author of the code. It sends
        concrete, actionable findings back to the Lead Dev for rework.
        """
        file_dump = "\n\n".join(
            f"### {f.get('path', 'unknown')}\n```\n{str(f.get('content', ''))[:4000]}\n```"
            for f in files[:8]
        )
        prompt = (
            f"Perform an INDEPENDENT code review of the generated prototype.\n\n"
            f"Prototype: {idea.get('title')}\n"
            f"Summary: {idea.get('summary')}\n\n"
            f"## Architecture contract\n{architecture.get('diagram_mermaid', 'n/a')}\n"
            f"Components: {', '.join(c.get('name', '') for c in architecture.get('components', []))}\n\n"
            f"## Hackathon rules & requirements\n{hackathon_rules or 'n/a'}\n\n"
            f"## Previously requested changes (already applied — verify)\n{previous_feedback or 'none'}\n\n"
            f"## Files under review\n{file_dump or '(no files)'}\n\n"
            f"Check for: (1) deviations from the architecture contract, "
            f"(2) violations of the hackathon rules/requirements, "
            f"(3) correctness bugs, missing error handling, deadlocks, insecure "
            f"config (secrets in code, permissive CORS, missing auth), "
            f"(4) incomplete stubs or truncated code. "
            f"Verdict MUST be 'needs_work' if any critical or warning finding exists; "
            f"'approve' ONLY when the code is ready to ship."
        )
        if self._client:
            try:
                from google.genai import types
                response = self._client.models.generate_content(
                    model=self.model_pro,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=(
                            "You are the Reviewer Agent: a strict, independent senior "
                            "engineer. You are not the author of this code. You protect "
                            "quality by finding concrete problems and demanding fixes."
                        ),
                        response_mime_type="application/json",
                        response_schema=CodeReview,
                        temperature=0.1,
                    ),
                )
                return self._parse_json_response(response.text, CodeReview)
            except Exception as err:
                raise RuntimeError(f"Vertex AI generate_code_review failed: {err}") from err

        raise RuntimeError("Vertex AI client not configured (GOOGLE_GENAI_USE_VERTEXAI != True)")

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
                raise RuntimeError(f"Vertex AI generate_submission failed: {err}") from err

        raise RuntimeError("Vertex AI client not configured (GOOGLE_GENAI_USE_VERTEXAI != True)")