"""Architecture nodes: synthesis + CEO Architecture Review Gate."""
from __future__ import annotations

from typing import Any

from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.workflow import node

from ..agents import ArchitectAgent
from ..tools import execute_dart_task
from .core import (
    CEO_ARCH_REVIEW_GATE,
    LLM_CLIENT,
    MAX_ARCH_ROUNDS,
    SESSION_DB,
    _sync_state,
    _tool_ctx,
)


def _build_architecture_doc(arch: dict) -> str:
    """Renders the architecture spec as a Markdown document for the repo."""
    components = arch.get("components", []) or []
    lines = [
        f"# {arch.get('title', 'System Architecture')}",
        "",
        "## Overview",
        "",
        f"- **Compute Target:** {arch.get('compute_target', 'n/a')}",
        f"- **Session Store:** {arch.get('session_store', 'n/a')}",
        f"- **Vector Memory:** {arch.get('vector_memory_store', 'n/a')}",
        f"- **Git Provider:** {str(arch.get('git_provider', 'github')).upper()}",
        "",
        "## Components",
        "",
    ]
    for c in components:
        if isinstance(c, dict):
            name = c.get("name", "component")
            desc = c.get("description", "")
            lines.append(f"- **{name}**" + (f" — {desc}" if desc else ""))
        else:
            lines.append(f"- {c}")
    mermaid = (arch.get("diagram_mermaid") or "").strip()
    if mermaid:
        lines += [
            "",
            "## Topology Diagram",
            "",
            "```mermaid",
            mermaid,
            "```",
        ]
    lines += [
        "",
        "---",
        "*Generated autonomously by the Enterprise Fleet (ArchitectAgent).*",
        "",
    ]
    return "\n".join(lines)


def _commit_architecture_doc(tc, arch: dict) -> dict:
    """Commits docs/ARCHITECTURE.md to the provisioned repo (best-effort)."""
    git_repo = tc.state.get("git_repo") or {}
    repo_name = git_repo.get("repo_name") or (tc.state.get("selected_idea", {}) or {}).get("repo_name")
    provider = str(git_repo.get("provider") or tc.state.get("git_provider") or "github").lower()
    if not repo_name:
        return {"status": "skipped", "message": "no repo provisioned yet"}

    payload = {
        "provider": provider,
        "owner": "Merdzhanov",
        "repo_name": repo_name,
        "project_id": git_repo.get("project_id", repo_name),
        "files": [
            {
                "path": "docs/ARCHITECTURE.md",
                "content": _build_architecture_doc(arch),
                "commit_message": "docs: add system architecture (autonomous fleet)",
                "existing_files": [],
            }
        ],
    }
    try:
        result = execute_dart_task("tasks/commit-files", payload)
    except Exception as e:  # noqa: BLE001 — doc commit is best-effort
        return {"status": "error", "message": str(e)}
    return result



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

    # Best-effort: persist the architecture doc into the provisioned repo so
    # the CEO can open/edit it on GitHub and reference it from the chat.
    arch_spec = tc.state.get("architecture_spec", {}) or {}
    doc_result = _commit_architecture_doc(tc, arch_spec)
    doc_url = ""
    if doc_result.get("status") == "committed" or doc_result.get("commit_sha"):
        repo_name = (tc.state.get("git_repo") or {}).get("repo_name") or (
            tc.state.get("selected_idea", {}) or {}
        ).get("repo_name", "")
        provider = str((tc.state.get("git_repo") or {}).get("provider") or "github").lower()
        base = "https://github.com" if provider == "github" else "https://gitlab.com"
        doc_url = f"{base}/Merdzhanov/{repo_name}/blob/main/docs/ARCHITECTURE.md"
        tc.state["architecture_doc_url"] = doc_url
        _sync_state(ctx, tc)

    SESSION_DB.append_trace(
        tc.session_id, "ArchitectAgent", "agent",
        f"ADK node: architecture round {ctx.state.get('arch_rounds')} synthesized — '{arch_title}'.",
    )
    # Chat-style trace with the architecture summary (surfaced in the CEO chat).
    comp_names = [c.get("name") if isinstance(c, dict) else str(c) for c in (arch_spec.get("components") or [])]
    SESSION_DB.append_trace(
        tc.session_id, "ArchitectAgent", "architecture",
        (
            f"📐 **Architecture proposal (round {ctx.state.get('arch_rounds')}): {arch_spec.get('title', arch_title)}**\n"
            f"- Compute: {arch_spec.get('compute_target', 'n/a')}\n"
            f"- Components: {', '.join(comp_names) if comp_names else 'n/a'}"
            + (f"\n- 📄 Doc committed: docs/ARCHITECTURE.md → {doc_url}" if doc_url else "")
        ),
    )
    yield {
        "agent": result.agent_name,
        "status": result.status,
        "arch_round": ctx.state.get("arch_rounds"),
        "architecture_doc_url": doc_url,
    }


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
