"""Enterprise Fleet Workflow package.

Public API surface (imported by main.py and agent.py):
- FLEET_WORKFLOW  — the ADK Workflow graph (root agent)
- FLEET_RUNNER    — the ADK Runner wired to a persistent session service
- start_fleet_run / resume_fleet_run — async phase 1 / phase 2 API
- SESSION_DB, LLM_CLIENT, MEMORY_DB — shared singletons
- Gate interrupt-id constants and iteration caps
"""
from .core import (
    CEO_ARCH_REVIEW_GATE,
    CEO_CODE_REVIEW_GATE,
    CEO_DECISION_GATE,
    CEO_DEPLOYMENT_GATE,
    LLM_CLIENT,
    MAX_ARCH_ROUNDS,
    MAX_COMPLIANCE_ROUNDS,
    MAX_DEV_ROUNDS,
    MEMORY_DB,
    SESSION_DB,
)
from .runner import (
    FLEET_RUNNER,
    FLEET_SESSION_SERVICE,
    resume_fleet_run,
    start_fleet_run,
)
from .workflow import FLEET_WORKFLOW, WORKFLOW_NODES

__all__ = [
    "CEO_DECISION_GATE",
    "CEO_ARCH_REVIEW_GATE",
    "CEO_CODE_REVIEW_GATE",
    "CEO_DEPLOYMENT_GATE",
    "FLEET_RUNNER",
    "FLEET_SESSION_SERVICE",
    "FLEET_WORKFLOW",
    "SESSION_DB",
    "LLM_CLIENT",
    "MEMORY_DB",
    "MAX_ARCH_ROUNDS",
    "MAX_DEV_ROUNDS",
    "MAX_COMPLIANCE_ROUNDS",
    "WORKFLOW_NODES",
    "start_fleet_run",
    "resume_fleet_run",
]
