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

from typing import Any, Dict, Optional, Tuple

from google.adk import Runner
from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.errors.already_exists_error import AlreadyExistsError
# Canonical HITL detection helpers in ADK 2.6.2 (not re-exported publicly).
from google.adk.workflow.utils._workflow_hitl_utils import (
    get_request_input_interrupt_ids,
    has_request_input_function_call,
)
from google.adk.sessions import InMemorySessionService
from google.adk.workflow import START, Workflow, node
from google.genai import types as genai_types

from .agents import (
    ArchitectAgent,
    ComplianceAgent,
    LeadDevAgent,
    MarketingAgent,
    PlannerAgent,
    ReviewerAgent,
    ScoutAgent,
)
from .db import CloudSessionManager, VectorMemoryManager
from .deployer import DeploymentAgent
from .llm import VertexGeminiClient
from .tools import ToolContext

# Interrupt IDs (stable contract with the FastAPI layer and the CEO UI).
CEO_DECISION_GATE = "ceo_decision_gate"
CEO_ARCH_REVIEW_GATE = "ceo_arch_review_gate"
CEO_CODE_REVIEW_GATE = "ceo_code_review_gate"
CEO_DEPLOYMENT_GATE = "ceo_deployment_gate"

# Bounded iteration caps — real work requires rounds, but the pipeline must
# never loop forever. When a cap is reached the gate warns and force-continues.
MAX_ARCH_ROUNDS = 3
MAX_DEV_ROUNDS = 4
MAX_COMPLIANCE_ROUNDS = 2

# Shared singletons (imported by main.py — one instance per process).
SESSION_DB = CloudSessionManager()
LLM_CLIENT = VertexGeminiClient()
MEMORY_DB = VectorMemoryManager()


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
    """Deterministic Devpost discovery through the Dart Functional Node.

    If ``active_opportunity`` is already seeded in the ADK session state
    (e.g. via /fleet/generate-proposals), skip discovery and use the
    pre-selected hackathon so the planner generates aligned proposals.
    """
    tc = _tool_ctx(ctx)
    # Pre-seeded opportunity: skip discovery, flow straight to planner.
    if tc.state.get("active_opportunity"):
        SESSION_DB.append_trace(
            tc.session_id, "ScoutAgent", "system",
            "ADK node: active_opportunity pre-seeded — skipping Devpost discovery.",
        )
        yield {"status": "success"}
        return
    SESSION_DB.append_trace(tc.session_id, "ScoutAgent", "dart", "ADK node: invoking Dart Functional Node.")
    scout_result = ScoutAgent().run(tc.state.get("raw_feed", {}), tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(
        tc.session_id, "ScoutAgent",
        "success" if scout_result.status == "success" else "error",
        f"ADK node: discovery {scout_result.status}.",
    )
    # Long-term memory: record every discovered opportunity (never breaks discovery).
    if scout_result.status == "success":
        opp = tc.state.get("active_opportunity") or {}
        try:
            MEMORY_DB.store_memory(
                topic="hackathon_discovery",
                content=(
                    f"Discovered hackathon '{opp.get('title', 'unknown')}' "
                    f"(prize pool {opp.get('prize_pool', 'n/a')}, deadline "
                    f"{opp.get('submission_deadline', 'n/a')}) — {opp.get('url', '')}"
                ),
                metadata={"session_id": tc.session_id, "opportunity_id": opp.get("id")},
            )
        except Exception as mem_err:
            SESSION_DB.append_trace(tc.session_id, "ScoutAgent", "error", f"Memory store failed: {mem_err}")
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
            try:
                MEMORY_DB.store_memory(
                    topic="ceo_decision",
                    content="CEO chose skip_implementation — pipeline halted with zero spend.",
                    metadata={"session_id": tc.session_id, "decision": decision},
                )
            except Exception:
                pass
            yield _noop(ctx, "CEO chose skip_implementation")
            return
        SESSION_DB.append_trace(
            tc.session_id, "PlannerAgent", "agent",
            f"ADK node: decision processed, repo '{tc.state.get('git_repo', {}).get('repo_name')}'.",
        )
        try:
            idea = tc.state.get("selected_idea") or {}
            MEMORY_DB.store_memory(
                topic="ceo_decision",
                content=(
                    f"CEO decision '{decision}' selected '{idea.get('title', 'n/a')}' "
                    f"→ provisioning repo '{tc.state.get('git_repo', {}).get('repo_name', 'n/a')}'."
                ),
                metadata={"session_id": tc.session_id, "decision": decision},
            )
        except Exception as mem_err:
            SESSION_DB.append_trace(tc.session_id, "CEO", "error", f"Memory store failed: {mem_err}")
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
        response_schema=None,
    )


@node(name="architect_node")
async def architect_node(ctx: Any):
    """Synthesizes the Cloud Native architecture for the approved idea."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    ctx.state["arch_rounds"] = int(ctx.state.get("arch_rounds") or 0) + 1
    result = ArchitectAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    arch_title = (result.data or {}).get("title", "architecture")
    SESSION_DB.append_trace(
        tc.session_id, "ArchitectAgent", "agent",
        f"ADK node: architecture round {ctx.state.get('arch_rounds')} synthesized — '{arch_title}'.",
    )
    yield {"agent": result.agent_name, "status": result.status, "arch_round": ctx.state.get("arch_rounds")}


@node(name="arch_review_gate_node", rerun_on_resume=True)
async def arch_review_gate_node(ctx: Any):
    """CEO Architecture Review Gate — human checks the design before any code
    is written. 'revise' routes back to the architect (bounded rework loop)."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_ARCH_REVIEW_GATE in resume:
        payload = resume[CEO_ARCH_REVIEW_GATE] or {}
        decision = payload.get("decision", "approve_architecture")
        if decision == "revise_architecture":
            round_no = int(ctx.state.get("arch_rounds") or 0)
            if round_no < MAX_ARCH_ROUNDS:
                ctx.state["arch_revise_feedback"] = str(payload.get("feedback") or "")
                SESSION_DB.append_trace(
                    tc.session_id, "CEO", "ceo",
                    f"CEO requested architecture revision round {round_no}/{MAX_ARCH_ROUNDS}.",
                )
                ctx.route = "revise_arch"
                yield {"decision": "revise_architecture", "route": "architect", "arch_round": round_no}
                return
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "warning",
                f"Architecture revision cap reached ({MAX_ARCH_ROUNDS}) — forcing through current design.",
            )
        else:
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "ceo",
                "CEO approved the architecture — proceeding to implementation.",
            )
        ctx.state["pending_request_input"] = {}
        yield {"decision": decision, "route": "leaddev"}
        return

    # First pass: present the architecture and pause for human approval.
    arch = tc.state.get("architecture_spec", {})
    arch_summary = {
        "title": arch.get("title", "n/a"),
        "compute_target": arch.get("compute_target", "n/a"),
        "components": [c.get("name") for c in arch.get("components", [])],
        "diagram_mermaid": (arch.get("diagram_mermaid") or "")[:800],
    }
    round_no = int(ctx.state.get("arch_rounds") or 0)
    prompt = (
        f"Review the proposed architecture (round {round_no}). "
        f"Approve it to start implementation, or request a revision with feedback."
    )
    options = [
        {"label": "✅ Approve architecture", "value": "approve_architecture"},
        {"label": "🔄 Revise architecture (add feedback)", "value": "revise_architecture"},
    ]
    pending = {
        "interrupt_id": CEO_ARCH_REVIEW_GATE,
        "state_key": CEO_ARCH_REVIEW_GATE,
        "prompt": prompt,
        "options": options,
        "metadata": {"gate": "architecture_review", "arch_round": round_no, "architecture": arch_summary},
    }
    ctx.state["pending_request_input"] = pending
    SESSION_DB.append_trace(
        tc.session_id, "ArchitectAgent", "hitl",
        f"ADK node: pausing at CEO Architecture Review Gate (round {round_no}).",
    )
    yield AdkRequestInput(
        interrupt_id=CEO_ARCH_REVIEW_GATE,
        message=prompt,
        payload={"options": options},
        response_schema=None,
    )


@node(name="leaddev_node")
async def leaddev_node(ctx: Any):
    """Iteratively scaffolds and commits the generated repository files."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    ctx.state["dev_rounds"] = int(ctx.state.get("dev_rounds") or 0) + 1
    result = LeadDevAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    files = (result.data or {}).get("files_committed", [])
    SESSION_DB.append_trace(
        tc.session_id, "LeadDevAgent", "agent",
        f"ADK node: round {ctx.state.get('dev_rounds')} committed {len(files)} files to Git.",
    )
    yield {
        "agent": result.agent_name,
        "status": result.status,
        "files_committed": len(files),
        "dev_round": ctx.state.get("dev_rounds"),
    }


@node(name="code_review_node")
async def code_review_node(ctx: Any):
    """Independent Reviewer Agent critiques the committed code. Findings route
    back to the Lead Dev for rework (bounded); a clean or capped review routes
    to the CEO Code Review Gate."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    result = ReviewerAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    dev_round = int(ctx.state.get("dev_rounds") or 0)
    findings = (result.data or {}).get("findings", [])
    SESSION_DB.append_trace(
        tc.session_id, "ReviewerAgent", "agent",
        f"ADK node: review iteration {ctx.state.get('review_iteration')} — "
        f"{len(findings)} finding(s), verdict '{result.status}'.",
    )
    if result.status == "review_needs_work" and dev_round < MAX_DEV_ROUNDS:
        ctx.route = "rework_code"
        yield {
            "agent": result.agent_name,
            "verdict": "needs_work",
            "findings_count": len(findings),
            "dev_round": dev_round,
            "max_rounds": MAX_DEV_ROUNDS,
        }
        return
    if result.status == "review_needs_work":
        SESSION_DB.append_trace(
            tc.session_id, "ReviewerAgent", "warning",
            f"Dev rework cap reached ({MAX_DEV_ROUNDS}) — forcing remaining findings to CEO for review.",
        )
    # Clean review (or cap reached) → default route → CEO Code Review Gate.
    yield {
        "agent": result.agent_name,
        "verdict": "clean" if result.status == "review_clean" else "needs_work_forced",
        "findings_count": len(findings),
        "dev_round": dev_round,
    }


@node(name="code_review_gate_node", rerun_on_resume=True)
async def code_review_gate_node(ctx: Any):
    """CEO Code Review Gate — human reviews the reviewer's verdict + the
    committed files, then approves or requests further changes (bounded)."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    resume = dict(ctx.resume_inputs or {})

    if CEO_CODE_REVIEW_GATE in resume:
        payload = resume[CEO_CODE_REVIEW_GATE] or {}
        decision = payload.get("decision", "approve_code")
        if decision == "request_changes":
            dev_round = int(ctx.state.get("dev_rounds") or 0)
            if dev_round < MAX_DEV_ROUNDS:
                ctx.state["rework_feedback"] = str(
                    payload.get("feedback") or "CEO requested changes before proceeding."
                )
                SESSION_DB.append_trace(
                    tc.session_id, "CEO", "ceo",
                    f"CEO requested code changes (round {dev_round}/{MAX_DEV_ROUNDS}).",
                )
                ctx.state["pending_request_input"] = {}
                ctx.route = "rework_code"
                yield {"decision": "request_changes", "route": "leaddev", "dev_round": dev_round}
                return
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "warning",
                f"Code change cap reached ({MAX_DEV_ROUNDS}) — proceeding with current version.",
            )
        else:
            SESSION_DB.append_trace(
                tc.session_id, "CEO", "ceo",
                "CEO approved the reviewed code — proceeding to compliance.",
            )
        ctx.state["pending_request_input"] = {}
        yield {"decision": decision, "route": "compliance"}
        return

    # First pass: present review verdict + findings to CEO.
    review = tc.state.get("code_review", {})
    findings = review.get("findings", [])
    dev_round = int(ctx.state.get("dev_rounds") or 0)
    findings_summary = "\n".join(
        f"- [{f.get('severity', 'info')}] {f.get('file', 'general')}: {f.get('issue', '')}"
        for f in findings[:10]
    )
    prompt = (
        f"Code review is complete (dev round {dev_round}). Verdict: "
        f"{review.get('verdict', 'n/a')}. Findings:\n{findings_summary or '(none)'}\n\n"
        f"Approve the code to proceed, or request specific changes."
    )
    options = [
        {"label": "✅ Approve code", "value": "approve_code"},
        {"label": "🔄 Request changes (add feedback)", "value": "request_changes"},
    ]
    pending = {
        "interrupt_id": CEO_CODE_REVIEW_GATE,
        "state_key": CEO_CODE_REVIEW_GATE,
        "prompt": prompt,
        "options": options,
        "metadata": {"gate": "code_review", "dev_round": dev_round, "verdict": review.get("verdict")},
    }
    ctx.state["pending_request_input"] = pending
    SESSION_DB.append_trace(
        tc.session_id, "ReviewerAgent", "hitl",
        f"ADK node: pausing at CEO Code Review Gate (round {dev_round}).",
    )
    yield AdkRequestInput(
        interrupt_id=CEO_CODE_REVIEW_GATE,
        message=prompt,
        payload={"options": options},
        response_schema=None,
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


@node(name="compliance_node")
async def compliance_node(ctx: Any):
    """Post-build regulatory compliance check — EU, Bulgaria, and global."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    result = ComplianceAgent(llm=LLM_CLIENT).run(tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(tc.session_id, "ComplianceAgent", "agent", "Regulatory scan completed.")
    yield {"agent": result.agent_name, "status": result.status}


@node(name="compliance_gate_node")
async def compliance_gate_node(ctx: Any):
    """Compliance gate — blocking findings route the pipeline back to the Lead
    Dev for remediation (bounded); a clean or capped scan proceeds to marketing."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)
    report = tc.state.get("compliance_report") or {}
    critical = int(report.get("critical_issues_count") or 0)
    round_no = int(ctx.state.get("compliance_rounds") or 0)

    if critical > 0 and round_no < MAX_COMPLIANCE_ROUNDS:
        ctx.state["compliance_rounds"] = round_no + 1
        recs = "; ".join(report.get("recommendations", []) or [])[:2000]
        ctx.state["rework_feedback"] = (
            f"[COMPLIANCE GATE] Resolve these blocking compliance issues before "
            f"submission: {recs or 'see compliance_report recommendations'}"
        )
        SESSION_DB.append_trace(
            tc.session_id, "ComplianceAgent", "blocked",
            f"Compliance gate BLOCKED by {critical} critical issue(s) — "
            f"routing to Lead Dev remediation round {round_no + 1}/{MAX_COMPLIANCE_ROUNDS}.",
        )
        ctx.route = "rework_compliance"
        yield {
            "gate": "compliance",
            "decision": "rework",
            "critical_issues": critical,
            "compliance_round": round_no + 1,
        }
        return

    if critical > 0:
        SESSION_DB.append_trace(
            tc.session_id, "ComplianceAgent", "warning",
            f"Compliance remediation cap reached ({MAX_COMPLIANCE_ROUNDS}) — proceeding with {critical} critical finding(s).",
        )
    else:
        SESSION_DB.append_trace(
            tc.session_id, "ComplianceAgent", "pass",
            "Compliance gate passed — proceeding to submission package.",
        )
    yield {
        "gate": "compliance",
        "decision": "pass",
        "critical_issues": critical,
        "compliance_round": round_no,
    }


# Node identifiers exposed via /fleet/system for the governance dashboard.
WORKFLOW_NODES = [
    "scout_node",
    "planner_gate_node",
    "architect_node",
    "arch_review_gate_node",
    "leaddev_node",
    "code_review_node",
    "code_review_gate_node",
    "compliance_node",
    "compliance_gate_node",
    "marketing_node",
]

# Adaptive Enterprise Fleet Workflow — collaboration + bounded rework loops.
#   START → scout → planner gate → architect → arch review gate
#     arch review: "revise_arch" ↺ architect (max MAX_ARCH_ROUNDS)
#                  default → leaddev → code review
#     code review: "rework_code" ↺ leaddev (max MAX_DEV_ROUNDS)
#                  default → code review gate (CEO)
#     code review gate: "rework_code" ↺ leaddev (max MAX_DEV_ROUNDS)
#                       default → compliance
#     compliance gate:  "rework_compliance" ↺ leaddev (max MAX_COMPLIANCE_ROUNDS)
#                       default → marketing
FLEET_WORKFLOW = Workflow(
    name="enterprise_fleet_workflow",
    description=(
        "Adaptive prototyping pipeline with multi-agent collaboration, "
        "bounded rework loops, and Human-in-the-Loop CEO gates."
    ),
    edges=[
        ("START", scout_node, planner_gate_node, architect_node, arch_review_gate_node),
        # Arch review gate: revise ↺ architect (bounded) | default → leaddev
        (
            arch_review_gate_node,
            {
                "revise_arch": architect_node,
                "__DEFAULT__": leaddev_node,
            },
        ),
        # Lead dev always hands off to the independent reviewer.
        (leaddev_node, code_review_node),
        # Reviewer: rework ↺ leaddev (bounded) | default → CEO code review gate
        (
            code_review_node,
            {
                "rework_code": leaddev_node,
                "__DEFAULT__": code_review_gate_node,
            },
        ),
        # CEO code review gate: request changes ↺ leaddev (bounded) | default → compliance
        (
            code_review_gate_node,
            {
                "rework_code": leaddev_node,
                "__DEFAULT__": compliance_node,
            },
        ),
        (compliance_node, compliance_gate_node),
        # Compliance gate: blocked ↺ leaddev (bounded) | default → marketing
        (
            compliance_gate_node,
            {
                "rework_compliance": leaddev_node,
                "__DEFAULT__": marketing_node,
            },
        ),
    ],
)

# Long-lived runner + session service (session state survives between the
# /fleet/discovery pause and the /fleet/ceo-decision resume in one process).
FLEET_SESSION_SERVICE = InMemorySessionService()
FLEET_RUNNER = Runner(node=FLEET_WORKFLOW, session_service=FLEET_SESSION_SERVICE)
_FLEET_USER = "ceo"


async def start_fleet_run(
    session_id: str,
    raw_feed: Dict[str, Any],
    state_overrides: Optional[Dict[str, Any]] = None,
) -> Tuple[Dict[str, Any], Optional[Dict[str, Any]]]:
    """Runs phase 1 of the workflow. Returns (state, pending_request_input|None).

    Optional ``state_overrides`` are merged into the initial ADK session state
    (e.g. ``active_opportunity`` to skip discovery for a pre-selected hackathon).
    """
    try:
        await FLEET_SESSION_SERVICE.create_session(
            app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
        )
    except AlreadyExistsError:
        # Idempotent: a session for this id already exists (e.g. retry or
        # repeated live test) — delete it and start fresh.
        await FLEET_SESSION_SERVICE.delete_session(
            app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
        )
        await FLEET_SESSION_SERVICE.create_session(
            app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
        )
    pending_event = None
    interrupt_ids: list = []
    # Merge optional state_overrides (e.g. pre-seeded active_opportunity)
    # into the initial session state_delta.
    state_delta: Dict[str, Any] = {
        "session_id": session_id,
        "raw_feed": raw_feed or {},
    }
    if state_overrides:
        state_delta.update(state_overrides)
    async for event in FLEET_RUNNER.run_async(
        user_id=_FLEET_USER,
        session_id=session_id,
        new_message=genai_types.Content(
            role="user", parts=[genai_types.Part(text="start fleet pipeline")],
        ),
        state_delta=state_delta,
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
        content = pending_event.content if pending_event.content is not None else None
        if content is not None and content.parts is not None:
            for part in content.parts:
                call = getattr(part, "function_call", None)
                if call is not None and call.name == "adk_request_input":
                    fc_args = dict(call.args or {})
                    break
        raw_payload = fc_args.get("payload")
        payload: Dict[str, Any] = raw_payload if isinstance(raw_payload, dict) else {}
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


async def resume_fleet_run(session_id: str, decision_payload: Dict[str, Any]) -> Tuple[Dict[str, Any], Optional[Dict[str, Any]]]:
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
    # Multi-gate support: the resume may have paused again at the NEXT
    # human-in-the-loop gate (architecture review / code review). Surface the
    # pending question so the dashboard can ask the CEO without restarting.
    pending = None
    stored_pending = state.get("pending_request_input") or {}
    if stored_pending and stored_pending.get("interrupt_id"):
        pending = {
            "type": "REQUEST_INPUT",
            "interrupt_id": stored_pending.get("interrupt_id"),
            "state_key": stored_pending.get("state_key"),
            "prompt": stored_pending.get("prompt"),
            "options": stored_pending.get("options", []),
            "metadata": stored_pending.get("metadata", {}),
        }
        gate = stored_pending.get("interrupt_id")
        status = (
            "awaiting_ceo_decision"
            if gate == CEO_DECISION_GATE
            else "awaiting_gate_decision"
        )
    else:
        status = "skipped" if state.get("fleet_skipped") else "completed"
    SESSION_DB.save_session(session_id, status, "MarketingAgent", state)
    SESSION_DB.append_trace(
        session_id, "ADKRunner",
        "skip" if status == "skipped" else "success",
        f"ADK workflow finished with status '{status}'.",
    )
    return state, pending


__all__ = [
    "CEO_DECISION_GATE",
    "CEO_ARCH_REVIEW_GATE",
    "CEO_CODE_REVIEW_GATE",
    "CEO_DEPLOYMENT_GATE",
    "FLEET_RUNNER",
    "FLEET_WORKFLOW",
    "SESSION_DB",
    "LLM_CLIENT",
    "MEMORY_DB",
    "MAX_ARCH_ROUNDS",
    "MAX_DEV_ROUNDS",
    "MAX_COMPLIANCE_ROUNDS",
    "start_fleet_run",
    "resume_fleet_run",
]

