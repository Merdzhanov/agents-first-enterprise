"""Unit and Integration Tests for Agent-First Orchestrator Fleet."""
import os
import sys
import unittest
from pathlib import Path

# Ensure orchestrator directory is in sys.path
ORCHESTRATOR_DIR = Path(__file__).resolve().parent.parent
if str(ORCHESTRATOR_DIR) not in sys.path:
    sys.path.insert(0, str(ORCHESTRATOR_DIR))

from app.agents import (
    ArchitectAgent,
    LeadDevAgent,
    MarketingAgent,
    PlannerAgent,
    ScoutAgent,
)
from app.tools import RequestInput, ToolContext


class TestOrchestratorFleet(unittest.TestCase):
    def setUp(self):
        self.mock_feed = {
            "min_prize_pool": 1000,
            "require_online": True,
            "hackathons": [
                {
                    "id": "hack_gcp_2026",
                    "title": "Google Cloud & Vertex AI Agent Challenge",
                    "is_online": True,
                    "prize_pool": 50000,
                    "submission_deadline": "2026-09-30",
                    "tracks": ["Fortified Enterprise Fleet", "Multi-Agent Systems"],
                }
            ],
        }

    def test_scout_agent_filters_and_handoff(self):
        context = ToolContext(session_id="test_session_001")
        scout = ScoutAgent()
        result = scout.run(self.mock_feed, context)

        self.assertEqual(result.status, "success")
        self.assertIn("Google Cloud", result.message)
        self.assertIsNotNone(result.handoff)
        self.assertEqual(result.handoff.target_agent, "PlannerAgent")
        self.assertIn("active_opportunity", context.state)

    def test_planner_proposes_two_ideas_and_request_input(self):
        context = ToolContext(session_id="test_session_002")
        scout = ScoutAgent()
        scout_result = scout.run(self.mock_feed, context)

        planner = PlannerAgent()
        result = planner.formulate_proposals(scout_result.data, context)

        self.assertEqual(result.status, "awaiting_ceo_decision")
        self.assertIsNotNone(result.request_input)
        self.assertEqual(len(result.request_input.options), 4)

        option_ids = [opt["id"] for opt in result.request_input.options]
        self.assertIn("approve_idea_a", option_ids)
        self.assertIn("approve_idea_b", option_ids)
        self.assertIn("custom_idea", option_ids)
        self.assertIn("skip_implementation", option_ids)

        self.assertIn("idea_a", context.state)
        self.assertIn("idea_b", context.state)

    def test_ceo_decision_approval_path_github(self):
        context = ToolContext(session_id="test_session_003")
        scout = ScoutAgent()
        scout_result = scout.run(self.mock_feed, context)

        planner = PlannerAgent()
        planner.formulate_proposals(scout_result.data, context)

        # Simulate CEO Approving Idea A on GitHub with custom repo name
        decision_result = planner.process_ceo_decision(
            decision_choice="approve_idea_a",
            custom_prompt=None,
            git_provider="github",
            custom_repo_name="my-custom-ephemeraflow",
            context=context,
        )
        self.assertEqual(decision_result.status, "approved_and_provisioned")
        self.assertIn("git_repo", context.state)
        self.assertEqual(context.state["git_provider"], "github")
        self.assertEqual(context.state["selected_idea"]["repo_name"], "my-custom-ephemeraflow")

        # Verify downstream agents
        arch = ArchitectAgent()
        arch_result = arch.run(context)
        self.assertEqual(arch_result.status, "success")
        self.assertEqual(arch_result.data["git_provider"], "github")

        dev = LeadDevAgent()
        dev_result = dev.run(context)
        self.assertEqual(dev_result.status, "success")

        mkt = MarketingAgent()
        mkt_result = mkt.run(context)
        self.assertEqual(mkt_result.status, "completed")
        self.assertIn("demo_script", mkt_result.data)
        self.assertTrue(mkt_result.data["submission_ready"])

    def test_ceo_decision_approval_path_gitlab(self):
        context = ToolContext(session_id="test_session_003_gl")
        scout = ScoutAgent()
        scout_result = scout.run(self.mock_feed, context)

        planner = PlannerAgent()
        planner.formulate_proposals(scout_result.data, context)

        # Simulate CEO Approving Idea B on GitLab
        decision_result = planner.process_ceo_decision(
            decision_choice="approve_idea_b",
            custom_prompt=None,
            git_provider="gitlab",
            custom_repo_name="armorguard-enterprise",
            context=context,
        )
        self.assertEqual(decision_result.status, "approved_and_provisioned")
        self.assertEqual(context.state["git_provider"], "gitlab")
        self.assertEqual(context.state["selected_idea"]["repo_name"], "armorguard-enterprise")

    def test_ceo_decision_skip_path(self):
        context = ToolContext(session_id="test_session_004")
        scout = ScoutAgent()
        scout_result = scout.run(self.mock_feed, context)

        planner = PlannerAgent()
        planner.formulate_proposals(scout_result.data, context)

        # Simulate CEO choosing Skip
        decision_result = planner.process_ceo_decision("skip_implementation", None, context)
        self.assertEqual(decision_result.status, "skipped")
        self.assertIn("CEO elected to skip implementation", decision_result.message)
        self.assertNotIn("gitlab_repo", context.state)
        self.assertEqual(context.state.get("pipeline_status"), "skipped_by_ceo")


if __name__ == "__main__":
    unittest.main()
