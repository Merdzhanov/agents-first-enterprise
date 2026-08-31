"""Autonomous Periodic Discovery Scheduler using Cloud Pub/Sub & Cloud Scheduler.

Continuously monitors Devpost hackathons, performs diffs against seen registries
in Cloud SQL, and triggers the Planner Agent to synthesize 2 ideas for newly identified opportunities.
"""
from __future__ import annotations

import asyncio
import os
from typing import Any, Dict, List, Optional

# -------------------------------------------------------------------
# ADK ORCHESTRATION IMPORTS
# -------------------------------------------------------------------
from google import Workflow as AdkWorkflow

from .agents import PlannerAgent, ScoutAgent
from .db import CloudSessionManager
from .llm import VertexGeminiClient
from .tools import ToolContext, execute_dart_task


class DiscoveryScheduler:
    """Manages periodic autonomous discovery cycles with safe HITL pausing."""

    def __init__(
        self,
        interval_minutes: int = 30,
        session_db: Optional[CloudSessionManager] = None,
        llm: Optional[VertexGeminiClient] = None,
    ):
        self.interval_minutes = int(os.getenv("DISCOVERY_INTERVAL_MINUTES", str(interval_minutes)))
        self.session_db = session_db or CloudSessionManager()
        self.llm = llm or VertexGeminiClient()
        self._is_running = False

    async def run_discovery_cycle(self) -> List[Dict[str, Any]]:
        """Executes a single periodic scan, diffs seen hackathons, and generates proposals."""
        print("⏰ [Scheduler] Triggering periodic Devpost discovery cycle...")

        # Non-blocking execution of the synchronous Dart HTTP call
        dart_result = await asyncio.to_thread(
            execute_dart_task, "tasks/parse-brief", {"min_prize_pool": 1000, "require_online": True}
        )
        matches = dart_result.get("matches", [])
        proposals_generated = []

        for opp in matches:
            opp_id = opp.get("id", "hack_unknown")
            session_id = f"auto_session_{opp_id}"

            # OPTIMIZATION: Stateless check directly against Cloud SQL to prevent duplicates on Cloud Run restarts
            existing_session = self.session_db.load_session(session_id)
            if existing_session:
                continue
            
            context = ToolContext(session_id=session_id)
            context.state["active_opportunity"] = opp

            planner = PlannerAgent(llm=self.llm)

            try:
                # OPTIMIZATION: Aligning with main.py pattern - capturing return object instead of exception
                planner_result = planner.formulate_proposals(opp, context)

                if planner_result.request_input:
                    context.state["request_input_signal"] = planner_result.request_input.to_dict()

                    self.session_db.save_session(
                        session_id=session_id,
                        status="pending_ceo_review",
                        current_agent="PlannerAgent",
                        state=context.state,
                    )

                    proposals_generated.append({
                        "hackathon_id": opp_id,
                        "title": opp.get("title"),
                        "session_id": session_id,
                        "request_input": planner_result.request_input.to_dict(),
                        "idea_a": context.state.get("idea_a"), # OPTIMIZATION: Fixed key to match context state from agents.py
                        "idea_b": context.state.get("idea_b"),
                    })

                    print(f"✨ [Scheduler] Synthesized 2 proposals and paused for CEO review: '{opp.get('title')}'")
                else:
                    print(f"ℹ️ [Scheduler] Planner completed but did not yield RequestInput for {opp_id}.")

            except Exception as e:
                print(f"⚠️ [Scheduler] Unexpected error during planning for {opp_id}: {e}")

        return proposals_generated

    async def start_loop(self) -> None:
        """Starts the periodic background loop (useful for local development)."""
        self._is_running = True
        while self._is_running:
            try:
                await self.run_discovery_cycle()
            except Exception as e:
                print(f"⚠️ [Scheduler] Error during discovery cycle: {e}")
            await asyncio.sleep(self.interval_minutes * 60)

    def stop_loop(self) -> None:
        """Stops the local scheduler loop."""
        self._is_running = False


# =====================================================================
# ADK WEB INTERACTIVE WRAPPERS & EXPORTS
# Allows manual trigger and visualization of the scheduler cycle in `adk w`
# =====================================================================

@AdkWorkflow(
    name="ADK_ScheduledDiscovery",
    description="Interactive ADK Workflow: Manually triggers the background discovery cycle to find Devpost hackathons and synthesize CEO proposals."
)
def adk_scheduled_discovery_workflow() -> Dict[str, Any]:
    """
    Sync wrapper around the async run_discovery_cycle so it can be 
    triggered seamlessly from the ADK Web UI Run button.
    """
    scheduler = DiscoveryScheduler()
    
    # Run the async core logic synchronously for the ADK UI session
    proposals = asyncio.run(scheduler.run_discovery_cycle())
    
    return {
        "status": "discovery_cycle_completed",
        "new_opportunities_found": len(proposals),
        "data": proposals
    }