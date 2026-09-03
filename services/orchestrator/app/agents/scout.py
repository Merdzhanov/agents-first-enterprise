"""Scout Agent — discovers active developer competitions."""
from __future__ import annotations

from typing import Any, Dict

from ..tools import Handoff, ToolContext, execute_dart_task
from .base import AgentResult


class ScoutAgent:
    """Discovers active developer competitions and extracts structured constraints."""
    name: str = "ScoutAgent"

    def run(self, raw_feed: Dict[str, Any], context: ToolContext) -> AgentResult:
        dart_response = execute_dart_task("tasks/parse-brief", raw_feed)
        matches = dart_response.get("matches", [])

        if not matches:
            return AgentResult(
                agent_name=self.name,
                status="no_matches",
                message="No matching high-yield opportunities found in feed.",
                data={"total_evaluated": dart_response.get("total_evaluated", 0)},
            )

        top_opportunity = matches[0]
        context.state["active_opportunity"] = top_opportunity
        context.state["discovered_hackathons"] = matches[:5]

        return AgentResult(
            agent_name=self.name,
            status="success",
            message=f"Discovered opportunity: {top_opportunity.get('title')}",
            data=top_opportunity,
            handoff=Handoff(
                target_agent="PlannerAgent",
                reason="Synthesize prototype proposals for discovered opportunity",
            ),
        )
