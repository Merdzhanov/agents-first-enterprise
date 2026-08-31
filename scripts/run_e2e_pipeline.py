#!/usr/bin/env python3
"""
End-to-End Execution and Verification Pipeline for Agent-First Enterprise.
Demonstrates:
  1. Discovery Phase (Dart JSON parser + Scout Agent)
  2. 2-Idea Synthesis (Planner Agent)
  3. CEO Decision Gate (Approve Idea 1 / Approve Idea 2 / Custom Idea / Skip)
  4. Repository Provisioning (GitLab / Dart Node)
  5. Architecture & Code Generation (Architect & Dev Agents)
  6. Final Deliverable Packaging (Marketing Agent)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# Add orchestrator to Python path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR / "services" / "orchestrator"))

from app.agents import (
    ArchitectAgent,
    LeadDevAgent,
    MarketingAgent,
    PlannerAgent,
    ScoutAgent,
)
from app.tools import RequestInput, ToolContext


def run_pipeline(
    decision_choice: str = "approve_idea_a",
    custom_prompt: str = "",
    git_provider: str = "github",
    project_name: str = "",
) -> dict:
    print("\n" + "=" * 80)
    print("🚀 AGENT-FIRST ENTERPRISE — AUTONOMOUS FLEET PIPELINE")
    print("=" * 80)

    context = ToolContext(session_id="e2e_demo_session_001")

    # 1. SCOUT / DISCOVERY PHASE
    print("\n[PHASE 1: SCOUT AGENT & DART NODE DISCOVERY]")
    raw_feed = {
        "min_prize_pool": 5000,
        "require_online": True,
        "hackathons": [
            {
                "id": "hack_gemini_2026",
                "title": "Google Cloud Global Multi-Agent AI Hackathon",
                "is_online": True,
                "prize_pool": 100000,
                "submission_deadline": "2026-09-30",
                "tracks": ["Fortified Enterprise Fleet", "Agentic Systems"],
            }
        ],
    }
    scout = ScoutAgent()
    scout_result = scout.run(raw_feed, context)
    print(f"✓ Scout Output: {scout_result.message}")
    print(f"✓ Active Track: {context.state.get('active_opportunity', {}).get('tracks')}")

    # 2. PLANNER 2-IDEA SYNTHESIS & CEO DECISION GATE
    print("\n[PHASE 2: PLANNER AGENT 2-IDEA SYNTHESIS]")
    planner = PlannerAgent()
    proposal_result = planner.formulate_proposals(scout_result.data, context)

    print(f"✓ Proposal Status: {proposal_result.status}")
    print("\n--- 📋 PROPOSALS SUBMITTED TO HUMAN-IN-THE-LOOP CEO ---")
    if proposal_result.request_input:
        for idx, opt in enumerate(proposal_result.request_input.options, 1):
            print(f"  [{idx}] {opt.get('title')}")
            print(f"      Description: {opt.get('description')}")
            if opt.get("tech_stack"):
                print(f"      Tech Stack: {', '.join(opt.get('tech_stack') or [])}")
            print()

    # 3. PROCESS CEO DECISION
    print(f"\n[PHASE 3: CEO DECISION GATE (Selected: '{decision_choice}', Provider: '{git_provider.upper()}')]")
    decision_result = planner.process_ceo_decision(
        decision_choice=decision_choice,
        custom_prompt=custom_prompt,
        context=context,
        git_provider=git_provider,
        custom_repo_name=project_name,
    )
    print(f"✓ Decision Status: {decision_result.status}")
    print(f"✓ Result Message: {decision_result.message}")

    if decision_result.status == "skipped":
        print("\n🛑 Pipeline gracefully halted as requested by CEO. Zero cloud waste incurred.")
        return {"status": "skipped", "session_state": context.state}

    # 4. ARCHITECT AGENT
    print("\n[PHASE 4: ARCHITECT AGENT TOPOLOGY GENERATION]")
    architect = ArchitectAgent()
    arch_result = architect.run(context)
    print(f"✓ Architecture: {arch_result.data.get('title')}")
    print(f"✓ Compute Policy: {arch_result.data.get('compute_target')}")
    print(f"✓ Session Storage: {arch_result.data.get('session_store')}")
    print(f"✓ Vector Memory: {arch_result.data.get('vector_memory_store')}")

    # 5. LEAD DEV AGENT (Iterative File Plan Option B)
    print("\n[PHASE 5: LEAD DEV AGENT & ITERATIVE CODE GENERATION (Option B)]")
    dev = LeadDevAgent()
    dev_result = dev.run(context)
    print(f"✓ Scaffolding Status: {dev_result.data.get('commit_status')}")
    print(f"✓ Files Generated & Committed:")
    for f in context.state.get("committed_files", []):
        print(f"   • {f}")
    print(f"✓ Verification Status: {dev_result.data.get('verification_status')}")

    # 6. MARKETING AGENT
    print("\n[PHASE 6: MARKETING AGENT & DELIVERABLES ASSEMBLY]")
    mkt = MarketingAgent()
    mkt_result = mkt.run(context)
    print(f"✓ Target Provider: {mkt_result.data.get('git_provider')}")
    print(f"✓ Repository URL: {mkt_result.data.get('repo_url')}")
    print(f"✓ Submission Ready: {mkt_result.data.get('submission_ready')}")
    print("\n✓ Demo Script Preview:")
    for line in mkt_result.data.get("demo_script", "").split("\n")[:7]:
        print(f"   {line}")

    print("\n" + "=" * 80)
    print("✅ END-TO-END PIPELINE COMPLETED SUCCESSFULLY")
    print("=" * 80 + "\n")

    return {
        "status": "completed",
        "selected_idea": context.state.get("selected_idea"),
        "gitlab_repo": context.state.get("gitlab_repo"),
        "architecture": context.state.get("architecture_spec"),
        "submission_package": mkt_result.data,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run E2E Agent-First Enterprise pipeline")
    parser.add_argument(
        "--decision",
        choices=["approve_idea_a", "approve_idea_b", "custom_idea", "skip_implementation"],
        default="approve_idea_a",
        help="Simulated CEO choice",
    )
    parser.add_argument("--custom-prompt", default="", help="Custom prompt if choosing custom_idea")
    parser.add_argument(
        "--provider",
        choices=["github", "gitlab"],
        default="github",
        help="Target Git hosting provider (github | gitlab)",
    )
    parser.add_argument(
        "--project-name",
        default="",
        help="Custom/confirmed repository project name",
    )
    args = parser.parse_args()

    run_pipeline(
        decision_choice=args.decision,
        custom_prompt=args.custom_prompt,
        git_provider=args.provider,
        project_name=args.project_name,
    )
