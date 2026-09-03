"""Reviewer Agent — independent code critique."""
from __future__ import annotations

from typing import Optional

from ..llm import VertexGeminiClient
from ..tools import Handoff, ToolContext
from .base import AgentResult


class ReviewerAgent:
    """Independent senior-engineer agent that critiques Lead Dev output."""
    name: str = "ReviewerAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, context: ToolContext) -> AgentResult:
        idea = context.state.get("selected_idea", {})
        arch = context.state.get("architecture_spec", {})
        files = context.state.get("generated_files", [])
        opportunity = context.state.get("active_opportunity", {})
        hackathon_rules = str(
            opportunity.get("rules")
            or opportunity.get("requirements")
            or opportunity.get("description")
            or ""
        )
        previous_feedback = str(context.state.get("rework_feedback") or "")

        review = self.llm.generate_code_review(
            idea=idea,
            architecture=arch,
            files=files,
            hackathon_rules=hackathon_rules,
            previous_feedback=previous_feedback,
        )
        review_dict = review.model_dump()
        context.state["code_review"] = review_dict
        context.state["review_iteration"] = int(context.state.get("review_iteration") or 0) + 1

        if review.verdict == "approve":
            context.state["rework_feedback"] = ""
            return AgentResult(
                agent_name=self.name,
                status="review_clean",
                message=f"Code review passed: {review.summary}",
                data=review_dict,
                handoff=Handoff(
                    target_agent="MarketingAgent",
                    reason="Code quality gate passed — proceeding.",
                ),
            )

        context.state["rework_feedback"] = review.rework_feedback
        return AgentResult(
            agent_name=self.name,
            status="review_needs_work",
            message=f"Code review found {len(review.findings)} issue(s): {review.summary}",
            data=review_dict,
            handoff=Handoff(
                target_agent="LeadDevAgent",
                reason="Rework the code based on the reviewer findings.",
            ),
        )
