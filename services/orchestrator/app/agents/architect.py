"""Architect Agent — designs Google Cloud native system topology."""
from __future__ import annotations

from typing import Dict, Optional

from ..llm import VertexGeminiClient
from ..tools import Handoff, ToolContext
from .base import AgentResult


class ArchitectAgent:
    """Designs Google Cloud native system topology and architecture schemas via Vertex AI."""
    name: str = "ArchitectAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, context: ToolContext) -> AgentResult:
        selected_idea = context.state.get("selected_idea", {})
        provider_name = context.state.get("git_provider", "github").upper()
        revision_feedback = str(context.state.get("arch_revise_feedback") or "")

        arch_spec = self.llm.generate_architecture(
            selected_idea,
            git_provider=provider_name,
            revision_feedback=revision_feedback,
        )
        arch_dict = arch_spec.model_dump()
        context.state["architecture_spec"] = arch_dict
        context.state["arch_revise_feedback"] = ""

        return AgentResult(
            agent_name=self.name,
            status="success",
            message="Cloud Native architecture specification and Mermaid diagram synthesized with Vertex AI.",
            data=arch_dict,
            handoff=Handoff(
                target_agent="LeadDevAgent",
                reason="Generate backend services, schemas, and endpoint code iteratively",
            ),
        )
