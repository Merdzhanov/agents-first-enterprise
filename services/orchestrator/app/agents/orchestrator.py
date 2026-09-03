"""Standalone orchestrator functions for manual/testing mode."""
from __future__ import annotations

from typing import Any, Dict

from ..tools import ToolContext
from .scout import ScoutAgent
from .planner import PlannerAgent
from .architect import ArchitectAgent
from .leaddev import LeadDevAgent
from .marketing import MarketingAgent


def adk_scout_agent(raw_feed: Dict[str, Any]) -> Dict[str, Any]:
    context = ToolContext(session_id="adk_scout_session")
    scout = ScoutAgent()
    res = scout.run(raw_feed, context)
    return {"agent": res.agent_name, "status": res.status, "message": res.message, "data": res.data}


def adk_planner_agent(opportunity: Dict[str, Any]) -> Dict[str, Any]:
    context = ToolContext(session_id="adk_planner_session")
    planner = PlannerAgent()
    res = planner.formulate_proposals(opportunity, context)
    return {"agent": res.agent_name, "status": res.status, "message": res.message, "data": res.data}


def adk_architect_agent(selected_idea: Dict[str, Any]) -> Dict[str, Any]:
    context = ToolContext(session_id="adk_architect_session")
    context.state["selected_idea"] = selected_idea
    architect = ArchitectAgent()
    res = architect.run(context)
    return {"agent": res.agent_name, "status": res.status, "message": res.message, "data": res.data}


def adk_fleet_orchestrator(raw_feed: Dict[str, Any]) -> Dict[str, Any]:
    context = ToolContext(session_id="adk_fleet_session")

    # 1. Scout
    scout_res = ScoutAgent().run(raw_feed, context)
    if scout_res.status != "success":
        return {"status": "failed_at_scout", "result": scout_res.message}

    # 2. Planner Formulate
    opportunity = context.state.get("active_opportunity", {})
    planner = PlannerAgent()
    planner_res = planner.formulate_proposals(opportunity, context)

    # Auto-approve Idea A for full interactive UI simulation
    planner.process_ceo_decision("approve_idea_a", context=context)

    # 3. Architect
    architect_res = ArchitectAgent().run(context)

    # 4. LeadDev
    dev_res = LeadDevAgent().run(context)

    # 5. Marketing
    mkt_res = MarketingAgent().run(context)

    return {
        "status": "pipeline_completed",
        "opportunity": opportunity.get("title"),
        "repo_url": context.state.get("git_repo", {}).get("web_url"),
        "submission_ready": context.state.get("submission_package", {}).get("submission_ready", False),
    }
