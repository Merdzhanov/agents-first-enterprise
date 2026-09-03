"""FastAPI request models + shared constants for the Fleet API."""
from __future__ import annotations

from typing import Any, Dict, Literal, Optional

from pydantic import BaseModel, Field

APP_VERSION = "3.1.0"

# Strict CEO decision contract — invalid values are rejected by pydantic (HTTP 422).
DecisionChoice = Literal[
    "approve_idea_a",
    "approve_idea_b",
    "custom_idea",
    "skip_implementation",
    # Multi-gate HITL decisions:
    "approve_architecture",
    "revise_architecture",
    "approve_code",
    "request_changes",
]


class TriggerDiscoveryRequest(BaseModel):
    session_id: str = Field(default="session_dev_001")
    raw_feed: Dict[str, Any] = Field(default_factory=dict)
    use_adk_runner: bool = Field(
        default=True,
        description="Toggle between ADK Runner (default) and manual orchestration",
    )


class CeoDecisionRequest(BaseModel):
    session_id: str
    decision_choice: DecisionChoice = Field(description="CEO decision at the current HITL gate")
    custom_prompt: Optional[str] = None
    git_provider: str = Field(default="github", description="github | gitlab")
    custom_repo_name: Optional[str] = Field(
        default=None, description="Custom or confirmed repository name"
    )
    feedback: Optional[str] = Field(
        default=None,
        description="Free-text feedback for revise_architecture / request_changes / custom_idea",
    )
    use_adk_runner: bool = Field(
        default=True, description="Toggle between ADK Runner (default) and manual execution"
    )


class DeployConfirmRequest(BaseModel):
    session_id: str
    decision: str = Field(
        default="confirm_deploy_cloud_run",
        description="confirm_deploy_cloud_run | cancel_deployment",
    )


class GenerateProposalsRequest(BaseModel):
    """Generate proposals for a specific hackathon (already discovered, no Devpost API call)."""

    session_id: str = Field(default="session_dev_001")
    hackathon: Dict[str, Any] = Field(
        ...,
        description="Selected hackathon data (title, url, prize_pool, tracks, etc.)",
    )


class CeoIdeaRequest(BaseModel):
    """CEO submits a fully independent idea at any time — no prior discovery required."""

    custom_prompt: str = Field(
        ..., min_length=1, description="The CEO's custom prototype directive / idea description"
    )
    git_provider: str = Field(default="github", description="github | gitlab")
    custom_repo_name: Optional[str] = Field(
        default=None, description="Optional repository name slug"
    )
    session_id: Optional[str] = Field(
        default=None, description="Optional explicit session id; generated if omitted"
    )


class MemoryStoreRequest(BaseModel):
    """CEO / operator knowledge ingestion into the enterprise semantic memory bank."""

    topic: str = Field(description="Short topic label (e.g. 'architecture-decision')")
    content: str = Field(description="The memory fact content to be embedded and stored")
    tenant_id: str = Field(default="default_enterprise", description="RLS tenant isolation key")
    metadata: Dict[str, Any] = Field(default_factory=dict)
