"""Specialized Agent Fleet for Agent-First Enterprise.

Public exports — import these from app.agents:
    from app.agents import (
        AgentResult, GeneratedFile,
        ScoutAgent, PlannerAgent, ArchitectAgent,
        LeadDevAgent, ReviewerAgent, MarketingAgent, ComplianceAgent,
        ShaderEngineerAgent, FlutterFrontendAgent,
    )
"""
from __future__ import annotations

from .base import AgentResult, GDPR_REQUIREMENTS, BULGARIA_REQUIREMENTS, GLOBAL_REQUIREMENTS
from .scout import ScoutAgent
from .planner import PlannerAgent
from .architect import ArchitectAgent
from .leaddev import LeadDevAgent
from .reviewer import ReviewerAgent
from .marketing import MarketingAgent
from .compliance import ComplianceAgent
from .shader import ShaderEngineerAgent
from .flutter import FlutterFrontendAgent
from .orchestrator import adk_scout_agent, adk_planner_agent, adk_architect_agent, adk_fleet_orchestrator

__all__ = [
    "AgentResult",
    "GDPR_REQUIREMENTS",
    "BULGARIA_REQUIREMENTS",
    "GLOBAL_REQUIREMENTS",
    "ScoutAgent",
    "PlannerAgent",
    "ArchitectAgent",
    "LeadDevAgent",
    "ReviewerAgent",
    "MarketingAgent",
    "ComplianceAgent",
    "ShaderEngineerAgent",
    "FlutterFrontendAgent",
    "adk_scout_agent",
    "adk_planner_agent",
    "adk_architect_agent",
    "adk_fleet_orchestrator",
]

