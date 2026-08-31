"""Real Google ADK 2.6.2 Workflow integration for the Enterprise Fleet.

Validated against google-adk 2.6.2 (adk.dev/2.0 workflow engine):
- `google.adk.workflow.Workflow` / `node` / `START` define a graph of nodes.
- A node pauses for Human-in-the-Loop by yielding
  `google.adk.events.request_input.RequestInput` — the runner emits a
  `function_call` named `adk_request_input` with `id=interrupt_id`.
- On resume the framework delivers the caller's FunctionResponse payload via
  `ctx.resume_inputs["<interrupt_id>"]`; gate nodes MUST use
  `rerun_on_resume=True` so they re-execute and consume the decision.
- `Runner(node=<workflow>, session_service=...)` drives execution;
  `Runner.agent` accepts a `BaseNode`, so the Workflow itself can be exposed
  as `root_agent` for `adk web`.
"""
from __future__ import annotations

from typing import Any, Dict, Optional

from google.adk import Runner
from google.adk.events.request_input import RequestInput as AdkRequestInput
# Canonical HITL detection helpers in ADK 2.6.2 (not re-exported publicly).
from google.adk.workflow.utils._workflow_hitl_utils import (
    get_request_input_interrupt_ids,
    has_request_input_function_call,
)
from google.adk.sessions import InMemorySessionService
from google.adk.workflow import START, Workflow, node
from google.genai import types as genai_types

from .agents import ArchitectAgent, LeadDevAgent, MarketingAgent, PlannerAgent, ScoutAgent
from .db import CloudSessionManager
from .deployer import DeploymentAgent
from .llm import VertexGeminiClient
from .tools import ToolContext

# Interrupt IDs (stable contract with the FastAPI layer and the CEO UI).
CEO_DECISION_GATE = "ceo_decision_gate"
CEO_DEPLOYMENT_GATE = "ceo_deployment_gate"

# Shared singletons (imported by main.py — one instance per process).
SESSION_DB = CloudSessionManager()
LLM_CLIENT = VertexGeminiClient()


# ---------------------------------------------------------------------
# ToolContext bridging between ADK node state and the fleet agents
# ---------------------------------------------------------------------
def _tool_ctx(ctx: Any) -> ToolContext:
    """Builds a fleet ToolContext seeded from the ADK node state."""
    tc = ToolContext(session_id=str(ctx.state.get("session_id", "adk_fleet_session")))
    # NOTE: adk.sessions.state.State has no __iter__/keys() — dict(ctx.state)
    # falls back to the legacy obj[0], obj[1]... protocol and raises KeyError.
    # to_dict() is the supported way to snapshot the merged state.
    tc.state = {k: v for k, v in ctx.state.to_dict().items() if not k.startswith("_")}
    return tc


def _sync_state(ctx: Any, tc: ToolContext) -> None:
    """Writes the fleet state back into the ADK session state."""
    for key, value in tc.state.items():
        if not key.startswith("_"):
            ctx.state[key] = value


def _noop(ctx: Any, reason: str) -> Dict[str, Any]:
    ctx.state["fleet_skipped"] = True
    return {"skipped": True, "reason": reason}


# ---------------------------------------------------------------------
# Workflow nodes (async generators; gates use rerun_on_resume=True)
# ---------------------------------------------------------------------
@node(name="scout_node")
async def scout_node(ctx: Any):
    """Deterministic Devpost discovery through the Dart Functional Node."""
    tc = _tool_ctx(ctx)
    SESSION_DB.append_trace(tc.session_id, "ScoutAgent", "dart", "ADK node: invoking Dart Functional Node.")
    scout_result = ScoutAgent().run(tc.state.get("raw_feed", {}), tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(
        tc.session_id, "ScoutAgent",
        "success" if scout_result.status == "success" else "error",
        f"ADK node: discovery {scout_result.status}.",
    )
    yield {"status": scout_result.status}


@node(name="planner_gate_node", rerun_on_resume=True)
async def planner_gate_node(ctx: Any):
    """CEO Proposal Gate — pauses the workflow for the Human-in-the-Loop decision."""
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_DECISION_GATE in resume:
        payload = resume[CEO_DECISION_GATE] or {}
        decision = payload.get("decision", "approve_idea_a")
        SESSION_DB.append_trace(tc.session_id, "CEO", "ceo", f"ADK resume: CEO decision '{decision}'.")
        result = PlannerAgent(llm=LLM_CLIENT).process_ceo_decision(
            decision_choice=decision,
            custom_prompt=payload.get("custom_prompt"),
            git_provider=payload.get("git_provider", "github"),
            custom_repo_name=payload.get("custom_repo_name"),
            context=tc,
        )
        _sync_state(ctx, tc)
        if result.status == "skipped":
            yield _noop(ctx, "CEO chose skip_implementation")
            return
        SESSION_DB.append_trace(
            tc.session_id, "PlannerAgent", "agent",
            f"ADK node: decision processed, repo '{tc.state.get('git_repo', {}).get('repo_name')}'.",
        )
        yield {"decision": decision, "repo_name": tc.state.get("git_repo", {}).get("repo_name")}
        return

    # First execution: synthesize the dual proposal, then pause.
    planner_result = PlannerAgent(llm=LLM_CLIENT).formulate_proposals(
        tc.state.get("active_opportunity", {}), tc
    )
    _sync_state(ctx, tc)
    gate_input = planner_result.request_input
    pending = {
        "interrupt_id": CEO_DECISION_GATE,
        "state_key": CEO_DECISION_GATE,
        "prompt": gate_input.prompt if gate_input else "Approve a prototype proposal?",
        "options": (gate_input.options if gate_input else []) or [],
        "metadata": (gate_input.metadata if gate_input else {}) or {},
    }
    ctx.state["pending_request_input"] = pending
    SESSION_DB.append_trace(tc.session_id, "PlannerAgent", "agent", "ADK node: pausing at CEO Proposal Gate.")
    yield AdkRequestInput(
        interrupt_id=CEO_DECISION_GATE,
        message=pending["prompt"],
        payload={"options": pending["options"]},
    )


@node(name="architect_node")
async def architect_node(ctx: Any):
    """Synthesizes the Cloud Native architecture for the approved idea."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    result = ArchitectAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(tc.session_id, "ArchitectAgent", "agent", "ADK node: architecture synthesized.")
    yield {"agent": result.agent_name, "status": result.status}


@node(name="leaddev_node")
async def leaddev_node(ctx: Any):
    """Iteratively scaffolds and commits the generated repository files."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    result = LeadDevAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    files = (result.data or {}).get("files_committed", [])
    SESSION_DB.append_trace(
        tc.session_id, "LeadDevAgent", "agent",
        f"ADK node: committed {len(files)} files to Git.",
    )
    yield {"agent": result.agent_name, "status": result.status, "files_committed": len(files)}


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
    yield {"agent": result.agent_name, "status": result.status}


FLEET_WORKFLOW = Workflow(
    name="enterprise_fleet_workflow",
    description="Full autonomous prototyping pipeline with Human-in-the-Loop CEO gates.",
    edges=[
        ("START", scout_node, planner_gate_node, architect_node, leaddev_node, marketing_node),
    ],
)

# Long-lived runner + session service (session state survives between the
# /fleet/discovery pause and the /fleet/ceo-decision resume in one process).
FLEET_SESSION_SERVICE = InMemorySessionService()
FLEET_RUNNER = Runner(node=FLEET_WORKFLOW, session_service=FLEET_SESSION_SERVICE)
_FLEET_USER = "ceo"


async def start_fleet_run(session_id: str, raw_feed: Dict[str, Any]) -> tuple:
    """Runs phase 1 of the workflow. Returns (state, pending_request_input|None)."""
    await FLEET_SESSION_SERVICE.create_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    pending_event = None
    interrupt_ids: list = []
    async for event in FLEET_RUNNER.run_async(
        user_id=_FLEET_USER,
        session_id=session_id,
        new_message=genai_types.Content(
            role="user", parts=[genai_types.Part(text="start fleet pipeline")],
        ),
        state_delta={"session_id": session_id, "raw_feed": raw_feed or {}},
    ):
        # HITL contract (ADK 2.6.2): a paused node emits a function_call named
        # 'adk_request_input' — there is NO `event.request_input` attribute.
        if has_request_input_function_call(event):
            pending_event = event
            interrupt_ids = get_request_input_interrupt_ids(event)

    sess = await FLEET_SESSION_SERVICE.get_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    state = dict(sess.state) if sess else {}

    pending = None
    if pending_event is not None:
        stored = state.get("pending_request_input") or {}
        # Pull the canonical interrupt args straight from the emitted call
        # (RequestInput is serialized with camelCase aliases).
        fc_args: Dict[str, Any] = {}
        for part in (pending_event.content.parts if pending_event.content else []):
            call = getattr(part, "function_call", None)
            if call is not None and call.name == "adk_request_input":
                fc_args = dict(call.args or {})
                break
        payload = fc_args.get("payload") if isinstance(fc_args.get("payload"), dict) else {}
        pending = {
            "type": "REQUEST_INPUT",
            "interrupt_id": (
                interrupt_ids[0]
                if interrupt_ids
                else fc_args.get("interruptId") or stored.get("interrupt_id", CEO_DECISION_GATE)
            ),
            "state_key": stored.get("state_key", CEO_DECISION_GATE),
            "prompt": fc_args.get("message") or stored.get("prompt"),
            "options": payload.get("options") or stored.get("options", []),
            "metadata": stored.get("metadata", {}),
        }
    return state, pending


async def resume_fleet_run(session_id: str, decision_payload: Dict[str, Any]) -> Dict[str, Any]:
    """Resumes the paused workflow with the CEO decision (phase 2)."""
    sess = await FLEET_SESSION_SERVICE.get_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    if sess is None:
        raise ValueError(f"No ADK session for '{session_id}' — trigger /fleet/discovery first.")

    function_call = None
    for event in reversed(sess.events):
        for call in (event.get_function_calls() if hasattr(event, "get_function_calls") else []):
            if call.name == "adk_request_input":
                function_call = call
                break
        if function_call is not None:
            break
    if function_call is None:
        raise RuntimeError("Workflow is not paused — no pending 'adk_request_input' call found.")

    resume_message = genai_types.Content(
        role="user",
        parts=[genai_types.Part(function_response=genai_types.FunctionResponse(
            id=function_call.id,
            name=function_call.name,
            response=decision_payload,
        ))],
    )
    async for _ in FLEET_RUNNER.run_async(
        user_id=_FLEET_USER, session_id=session_id, new_message=resume_message,
    ):
        pass

    final_session = await FLEET_SESSION_SERVICE.get_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    state = dict(final_session.state) if final_session else {}
    status = "skipped" if state.get("fleet_skipped") else "completed"
    SESSION_DB.save_session(session_id, status, "MarketingAgent", state)
    SESSION_DB.append_trace(
        session_id, "ADKRunner",
        "skip" if status == "skipped" else "success",
        f"ADK workflow finished with status '{status}'.",
    )
    return state


__all__ = [
    "CEO_DECISION_GATE",
    "CEO_DEPLOYMENT_GATE",
    "FLEET_RUNNER",
    "FLEET_WORKFLOW",
    "SESSION_DB",
    "LLM_CLIENT",
    "start_fleet_run",
    "resume_fleet_run",
]

