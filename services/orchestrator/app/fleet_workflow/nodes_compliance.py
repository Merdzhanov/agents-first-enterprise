"""Compliance nodes: regulatory scan + blocking-issues gate."""
from __future__ import annotations

from typing import Any

from google.adk.workflow import node

from ..agents import ComplianceAgent
from .core import LLM_CLIENT, MAX_COMPLIANCE_ROUNDS, SESSION_DB, _sync_state, _tool_ctx


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
