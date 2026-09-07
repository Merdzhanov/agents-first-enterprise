"""Planner Agent — central PM & Lifecycle Steward."""
from __future__ import annotations

import os
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
        system_prompt = context.state.get("system_prompt")
        if system_prompt and hasattr(self.llm, "generate_proposals_from_prompt"):
            memories = context.search_memory(system_prompt[:100])
            proposals = self.llm.generate_proposals_from_prompt(system_prompt, memory_context=memories)
        else:
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
        context.state["git_provider"] = normalized_provider
        context.state["ceo_decision_choice"] = decision_choice

        # Handle Skip
        if decision_choice == "skip_implementation":
            context.state["workflow_status"] = "skipped"
            context.state["pipeline_status"] = "skipped_by_ceo"
            context.state["spend_usd"] = 0.0
            return AgentResult(
                agent_name=self.name,
                status="skipped",
                message="CEO elected to skip implementation. Session archived with zero cloud spend.",
                data={"decision": "skip_implementation", "spend_usd": 0.0},
            )

        # Determine selected idea
        selected_idea: Dict[str, Any]
        if decision_choice == "approve_idea_a":
            selected_idea = context.state.get("idea_a", {})
        elif decision_choice == "approve_idea_b":
            selected_idea = context.state.get("idea_b", {})
        elif decision_choice == "custom_idea" or custom_prompt:
            # Enrich the directive with the full hackathon/opportunity context
            # (title, rules, deadline, prize, tracks) so the Architect and every
            # downstream agent design against the REAL target, not just the
            # raw CEO text.
            opp = context.state.get("active_opportunity", {}) or {}
            opp_title = str(opp.get("title") or "").strip()
            directive = custom_prompt or "Custom CEO directive"

            context_lines: list[str] = []
            if opp_title:
                context_lines.append(f"Target hackathon: {opp_title}")
                if opp.get("url"):
                    context_lines.append(f"URL: {opp['url']}")
                if opp.get("submission_deadline"):
                    context_lines.append(f"Submission deadline: {opp['submission_deadline']}")
                if opp.get("prize_pool"):
                    context_lines.append(f"Prize pool: ${opp['prize_pool']}")
                tracks = opp.get("tracks") or []
                if tracks:
                    context_lines.append(f"Tracks: {', '.join(str(t) for t in tracks)}")
                reqs = opp.get("requirements") or opp.get("rules") or []
                if isinstance(reqs, str):
                    reqs = [reqs]
                if reqs:
                    context_lines.append("Requirements / rules:")
                    context_lines.extend(f"- {r}" for r in reqs)

            if context_lines:
                full_summary = (
                    f"{directive}\n\n"
                    "--- HACKATHON CONTEXT (MUST be honored by every agent) ---\n"
                    + "\n".join(context_lines)
                )
                display_title = f"Custom Build — {opp_title}"
            else:
                full_summary = directive
                display_title = "Custom Executive Prototype"

            selected_idea = {
                "id": "idea_custom",
                "title": display_title,
                "summary": full_summary,
                "tech_stack": ["Google Cloud", "ADK 2.0", "Dart", "Cloud SQL"],
                "impact": "Direct Executive Alignment",
                "repo_name": "custom-enterprise-prototype",
                "hackathon_title": opp_title or None,
                "hackathon_url": opp.get("url"),
                "hackathon_deadline": opp.get("submission_deadline"),
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

        owner = os.getenv("GIT_OWNER") or os.getenv("GITHUB_ACTOR") or "agent-enterprise"

        # Provision repository via Dart Node
        repo_payload = {
            "repo_name": final_repo_name,
            "provider": normalized_provider,
            "owner": owner,
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
                    "owner": owner,
                    "web_url": (
                        f"https://github.com/{owner}/{final_repo_name}"
                        if normalized_provider == "github"
                        else f"https://gitlab.com/{owner}/{final_repo_name}"
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
