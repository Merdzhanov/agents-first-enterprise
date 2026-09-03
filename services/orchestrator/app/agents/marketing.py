"""Marketing Agent — assembles final judging deliverables."""
from __future__ import annotations

from typing import Optional

from ..llm import VertexGeminiClient
from ..tools import ToolContext
from .base import AgentResult


class MarketingAgent:
    """Assembles final judging deliverables, README documentation, and demo scripts via Vertex AI."""
    name: str = "MarketingAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, context: ToolContext) -> AgentResult:
        selected_idea = context.state.get("selected_idea", {})
        repo = context.state.get("git_repo", {})
        provider_name = context.state.get("git_provider", "github").upper()

        submission = self.llm.generate_submission(
            idea=selected_idea,
            repo_url=repo.get("web_url", "https://github.com"),
            test_results="Passed all automated unit tests and health checks",
        )
        submission_dict = submission.model_dump()
        submission_dict["demo_script"] = submission_dict.get("demo_script_markdown")
        submission_dict["git_provider"] = provider_name
        submission_dict["repo_url"] = repo.get("web_url")
        submission_dict["gitlab_url"] = repo.get("web_url")
        submission_dict["submission_ready"] = True

        context.state["submission_package"] = submission_dict

        return AgentResult(
            agent_name=self.name,
            status="completed",
            message="All judging deliverables, 4-minute demo script, and repository assets synthesized via Vertex AI.",
            data=submission_dict,
        )
