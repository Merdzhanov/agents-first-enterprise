"""Release nodes: Devpost marketing + CEO Deployment Gate."""
from __future__ import annotations

from typing import Any

from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.workflow import node

from ..agents import MarketingAgent
from ..deployer import DeploymentAgent
from ..tools import RequestInput
from .core import (
    CEO_DEPLOYMENT_GATE,
    LLM_CLIENT,
    MEMORY_DB,
    SESSION_DB,
    _sync_state,
    _tool_ctx,
)


@node(name="marketing_node")
async def marketing_node(ctx: Any):
    """Assembles the final Devpost submission package."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    result = MarketingAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(
        tc.session_id, "MarketingAgent", "success",
        "ADK node: Devpost submission package assembled.",
    )
    try:
        repo_name = (tc.state.get("git_repo") or {}).get("repo_name", "prototype")
        idea_title = (tc.state.get("selected_idea") or {}).get("title", "prototype")
        MEMORY_DB.store_memory(
            topic="pipeline_completion",
            content=(
                f"Pipeline completed: '{idea_title}' → repo '{repo_name}' with architecture, "
                f"generated code and Devpost submission package."
            ),
            metadata={"session_id": tc.session_id, "repo_name": repo_name},
        )
    except Exception:
        pass
    yield {"agent": result.agent_name, "status": result.status}


@node(name="deployment_gate_node", rerun_on_resume=True)
async def deployment_gate_node(ctx: Any):
    """CEO Deployment Gate — final HITL approval before rolling the prototype
    out to Cloud Run. 'confirm_deploy_cloud_run' executes the deployment;
    'cancel_deployment' keeps the repo only."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_DEPLOYMENT_GATE in resume:
        payload = resume[CEO_DEPLOYMENT_GATE] or {}
        decision = payload.get("decision", "confirm_deploy_cloud_run")
        SESSION_DB.append_trace(
            tc.session_id, "CEO", "ceo",
            f"ADK resume: CEO deployment decision '{decision}'.",
        )
        deployer = DeploymentAgent()
        result = deployer.execute_deployment(decision, tc)
        _sync_state(ctx, tc)
        SESSION_DB.append_trace(
            tc.session_id, "DeploymentAgent",
            "success" if result.get("status") == "deployed_live" else "info",
            f"Deployment result: {result.get('status')} — {result.get('message', result.get('url', ''))}",
        )
        yield {"deployment": result, "status": result.get("status")}
        return

    # First pass: prepare the deployment plan and pause for CEO approval.
    deployer = DeploymentAgent()
    try:
        deployer.prepare_deployment_plan(tc)
    except RequestInput as req:
        pending = {
            "interrupt_id": CEO_DEPLOYMENT_GATE,
            "state_key": CEO_DEPLOYMENT_GATE,
            "prompt": req.prompt,
            "options": req.options,
            "metadata": req.metadata,
        }
        ctx.state["pending_request_input"] = pending
        SESSION_DB.append_trace(
            tc.session_id, "DeploymentAgent", "hitl",
            "ADK node: pausing at CEO Deployment Gate.",
        )
        yield AdkRequestInput(
            interrupt_id=CEO_DEPLOYMENT_GATE,
            message=req.prompt,
            payload={"options": req.options},
            response_schema=None,
        )
        return

    # Fallback: if prepare_deployment_plan didn't raise (shouldn't happen),
    # execute directly.
    result = deployer.execute_deployment("confirm_deploy_cloud_run", tc)
    _sync_state(ctx, tc)
    yield {"deployment": result, "status": result.get("status")}
