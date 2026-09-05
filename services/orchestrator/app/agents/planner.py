"""Planner Agent — central PM & Lifecycle Steward."""
from __future__ import annotations

import re
from typing import Any, Dict, Optional

from ..llm import VertexGeminiClient
from ..tools import Handoff, RequestInput, ToolContext, execute_dart_task, propose_ideas_to_ceo
from .base import AgentResult

def _clean_github_description(description: str) -> str:
    """Strips control chars and truncates for GitHub API compatibility."""
    if not description:
        return ""
    # 1. Replace control characters (newlines, tabs, etc.) with a space.
    cleaned = re.sub(r'[\x00-\x1F\x7F-\x9F]', ' ', description)
    # 2. Collapse multiple spaces into one and strip leading/trailing space.
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    # 3. Truncate to a maximum of 350 characters to be safe.
    if len(cleaned) > 350:
        return cleaned[:347] + "..."
    return cleaned



class PlannerAgent:
    """Synthesizes 2 competitive prototype ideas via Vertex AI, triggers CEO Decision Gate."""
    name: str = "PlannerAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def formulate_proposals(self, opportunity: Dict[str, Any], context: ToolContext) -> AgentResult:
        search_query = f"enterprise prototype {opportunity.get('title', '')} {opportunity.get('theme', '')}"
        memories = context.search_memory(search_query.strip())
        proposals = self.llm.generate_proposals(opportunity, memory_context=memories)

        idea_a = proposals.idea_a.model_dump()
        idea_b = proposals.idea_b.model_dump()

        context.state["idea_a"] = idea_a
        context.state["idea_b"] = idea_b
        context.state["planner_reasoning"] = proposals.reasoning

        try:
            propose_ideas_to_ceo(idea_a, idea_b, context)
        except RequestInput as req:
            return AgentResult(
                agent_name=self.name,
                status="awaiting_ceo_decision",
                message="Submitted 2 Vertex AI-synthesized proposals to the Human CEO for review.",
                data={"idea_a": idea_a, "idea_b": idea_b, "reasoning": proposals.reasoning},
                request_input=req,
            )

        return AgentResult(agent_name=self.name, status="error", message="Failed to trigger decision gate", data={})

    def process_ceo_decision(
        self,
        decision_choice: str,
        custom_prompt: Optional[str] = None,
        context: Optional[ToolContext] = None,
        git_provider: str = "github",
        custom_repo_name: Optional[str] = None,
    ) -> AgentResult:
        if context is None:
            raise ValueError("ToolContext is required for process_ceo_decision")

        normalized_provider = "gitlab" if git_provider == "gitlab" else "github"

        # Determine selected idea
        selected_idea: Dict[str, Any]
        if decision_choice == "approve_idea_a":
            selected_idea = context.state.get("idea_a", {})
        elif decision_choice == "approve_idea_b":
            selected_idea = context.state.get("idea_b", {})
        elif decision_choice == "custom_idea" or custom_prompt:
            selected_idea = {
                "id": "idea_custom",
                "title": "Custom Executive Prototype",
                "summary": custom_prompt or "Custom CEO directive",
                "tech_stack": ["Google Cloud", "ADK 2.0", "Dart", "Cloud SQL"],
                "impact": "Direct Executive Alignment",
                "repo_name": "custom-enterprise-prototype",
            }
        else:
            selected_idea = context.state.get("idea_a", {})

        fallback_slug = re.sub(r'[^a-z0-9\-]', '-', selected_idea.get("title", "prototype").lower())
        final_repo_name = (
            custom_repo_name.strip()
            if custom_repo_name and custom_repo_name.strip()
            else selected_idea.get("repo_name", fallback_slug)
        )
        selected_idea["repo_name"] = final_repo_name
        selected_idea["git_provider"] = normalized_provider
        context.state["selected_idea"] = selected_idea

        # Clean the description for GitHub API compatibility before provisioning
        cleaned_description = _clean_github_description(selected_idea.get("summary", "Autonomous prototype"))

        # Provision repository via Dart Node
        repo_payload = {
            "repo_name": final_repo_name,
            "provider": normalized_provider,
            "description": cleaned_description,
            "readme_content": (
                f"# {selected_idea.get('title')}\n\n"
                f"{selected_idea.get('summary')}\n\n"
                f"**Provider:** {normalized_provider.upper()}\n"
                f"**Repository:** `{final_repo_name}`\n\n"
                f"### Tech Stack\n"
                + "\n".join(f"- {t}" for t in (selected_idea.get("tech_stack") or []))
            ),
        }
        dart_repo_result = execute_dart_task("tasks/provision-repo", repo_payload)
        repo_status = str(dart_repo_result.get("status", ""))
        if repo_status != "provisioned" or not dart_repo_result.get("web_url"):
            raw_message = str(dart_repo_result.get("message", repo_status))
            # Idempotency: if the repository already exists (e.g. from a previous
            # run), adopt it instead of failing — the workflow can push to an
            # existing repo just fine.
            if "already exists" in raw_message.lower():
                SESSION_DB.append_trace(
                    context.session_id,
                    self.name,
                    "warning",
                    f"Repository '{final_repo_name}' already exists — adopting existing repo.",
                )
                dart_repo_result = {
                    "status": "provisioned",
                    "repo_name": final_repo_name,
                    "provider": normalized_provider,
                    "web_url": (
                        f"https://github.com/Merdzhanov/{final_repo_name}"
                        if normalized_provider == "github"
                        else f"https://gitlab.com/Merdzhanov/{final_repo_name}"
                    ),
                    "message": "Adopted pre-existing repository.",
                }
            else:
                err_msg = (
                    f"Repository provisioning FAILED for '{final_repo_name}' on "
                    f"{normalized_provider.upper()}: {raw_message}"
                )
                raise RuntimeError(err_msg)
        context.state["git_repo"] = dart_repo_result
        context.state["gitlab_repo"] = dart_repo_result

        return AgentResult(
            agent_name=self.name,
            status="approved_and_provisioned",
            message=f"CEO approved: '{selected_idea.get('title')}' on {normalized_provider.upper()}. Repo provisioned.",
            data={"selected_idea": selected_idea, "git_repo": dart_repo_result},
            handoff=Handoff(
                target_agent="ArchitectAgent",
                reason="Generate Cloud Native Architecture Topology and Diagrams",
            ),
        )
