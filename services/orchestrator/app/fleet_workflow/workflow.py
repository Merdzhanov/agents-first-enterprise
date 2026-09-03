"""Enterprise Fleet Workflow graph — node registry and edge routing."""
from __future__ import annotations

from google.adk.workflow import Workflow

from .core import (
    CEO_ARCH_REVIEW_GATE,
    CEO_CODE_REVIEW_GATE,
    CEO_DECISION_GATE,
    CEO_DEPLOYMENT_GATE,
    LLM_CLIENT,
    MEMORY_DB,
    SESSION_DB,
)
from .nodes_discovery import (
    planner_gate_node,
    scout_node,
)
from .nodes_architecture import (
    architect_node,
    arch_review_gate_node,
)
from .nodes_dev import (
    code_review_gate_node,
    leaddev_node,
    code_review_node,
)
from .nodes_flutter import flutter_dev_node, wasm_verify_node
from .nodes_compliance import compliance_gate_node, compliance_node
from .nodes_release import marketing_node, deployment_gate_node

# Adaptive Enterprise Fleet Workflow — collaboration + bounded rework loops.
#   START → scout → planner gate → architect → arch review gate
#     arch review: "revise_arch" ↺ architect (max MAX_ARCH_ROUNDS)
#                  "deploy_frontend" → flutter_dev (WASM/Flutter path)
#                  default → leaddev (backend path)
#     flutter path: flutter_dev → wasm_verify ("rework_build" ↺ flutter_dev)
#     code review: shared by both paths → CEO gate
FLEET_WORKFLOW = Workflow(
    name="enterprise_fleet_workflow",
    description=(
        "Adaptive prototyping pipeline with multi-agent collaboration, "
        "bounded rework loops, Human-in-the-Loop CEO gates, and "
        "dynamic backend/frontend branching with WASM verification."
    ),
    edges=[
        ("START", scout_node, planner_gate_node, architect_node, arch_review_gate_node),
        # Arch review gate: revise ↺ architect | frontend → flutter | default → leaddev
        (
            arch_review_gate_node,
            {
                "revise_arch": architect_node,
                "deploy_frontend": flutter_dev_node,
                "__DEFAULT__": leaddev_node,
            },
        ),
        # Backend path: leaddev → code_review → ...
        (leaddev_node, code_review_node),
        # Flutter path: flutter_dev → wasm_verify → code_review
        (flutter_dev_node, wasm_verify_node),
        (
            wasm_verify_node,
            {
                "rework_build": flutter_dev_node,
                "__DEFAULT__": code_review_node,
            },
        ),
        # Code review (shared by both paths)
        (code_review_node, code_review_gate_node),
        (
            code_review_gate_node,
            {
                "rework_code": leaddev_node,
                "__DEFAULT__": compliance_node,
            },
        ),
        (compliance_node, compliance_gate_node),
        (
            compliance_gate_node,
            {
                "rework_compliance": leaddev_node,
                "__DEFAULT__": marketing_node,
            },
        ),
        (marketing_node, deployment_gate_node),
    ],
)

WORKFLOW_NODES = [
    "scout_node",
    "planner_gate_node",
    "architect_node",
    "arch_review_gate_node",
    "leaddev_node",
    "code_review_node",
    "code_review_gate_node",
    "flutter_dev_node",
    "wasm_verify_node",
    "compliance_node",
    "compliance_gate_node",
    "marketing_node",
    "deployment_gate_node",
]
