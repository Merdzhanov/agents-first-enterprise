"""Unit and Integration Tests for Agent-First Orchestrator Fleet.

All external boundaries are mocked deterministically:
  - Dart Functional Node HTTP calls (app.agents.execute_dart_task)
  - Vertex AI LLM methods (patched on VertexGeminiClient — every agent
    constructs its own client via `llm or VertexGeminiClient()`)

The dart-node contract mirrors services/dart_node: provision-repo MUST
return status='provisioned' + web_url (the PlannerAgent validation gate
fails loudly on anything else — faked provisioning is forbidden).
"""
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

# Ensure orchestrator directory is in sys.path
ORCHESTRATOR_DIR = Path(__file__).resolve().parent.parent
if str(ORCHESTRATOR_DIR) not in sys.path:
    sys.path.insert(0, str(ORCHESTRATOR_DIR))

import app.agents as agents_mod
from app.agents import (
    ArchitectAgent,
    LeadDevAgent,
    MarketingAgent,
    PlannerAgent,
    ScoutAgent,
)
from app.llm import VertexGeminiClient
from app.schemas import (
    ArchitectureComponent,
    ArchitectureSpec,
    CodeReview,
    DualProposalResponse,
    FilePlanEntry,
    FilePlanResponse,
    GeneratedFile,
    IdeaProposal,
    SubmissionPackage,
)
from app.tools import Handoff, RequestInput, ToolContext
from app.fleet_workflow.core import CEO_REPO_DECISION_GATE


def _fake_dart(endpoint_path: str, payload=None, *args, **kwargs) -> dict:
    """Deterministic stand-in for the Dart Functional Node microservice."""
    if endpoint_path == "tasks/parse-brief":
        matches = []
        for h in (payload or {}).get("hackathons", []):
            match = dict(h)
            match.setdefault("url", f"https://{h.get('id', 'hack')}.devpost.com/")
            matches.append(match)
        return {
            "status": "success",
            "source": "unit_mock",
            "total_evaluated": len(matches),
            "filtered_count": len(matches),
            "matches": matches,
        }
    if endpoint_path == "tasks/provision-repo":
        p = payload or {}
        r_name = p.get("repo_name", "prototype-repo")
        prov = p.get("provider", "github")
        return {
            "status": "provisioned",
            "repo_name": r_name,
            "provider": prov,
            "owner": "unit-test-org",
            "web_url": f"https://{prov}.com/unit-test-org/{r_name}",
            "clone_url": f"https://{prov}.com/unit-test-org/{r_name}.git",
            "message": "Repository created and initial README committed.",
        }
    if endpoint_path == "tasks/commit-files":
        files = (payload or {}).get("files", [])
        return {
            "status": "committed",
            "commit_sha": "abc123unitfake",
            "files_committed": len(files),
            "branch": "main",
        }
    return {"status": "success"}


def _fake_proposals(self, opportunity, memory_context=None) -> DualProposalResponse:
    return DualProposalResponse(
        idea_a=IdeaProposal(
            id="idea_a_event_fleet",
            title="EphemeraFlow: Governed Multi-Agent Fleet",
            summary="Hybrid polyglot architecture with Dart Shelf workers on Cloud Run.",
            tech_stack=["Google ADK 2.0", "Dart Shelf", "Cloud Run"],
            track_fit="Enterprise AI",
            impact="99.9% uptime",
            repo_name="ephemeraflow-governed-fleet",
        ),
        idea_b=IdeaProposal(
            id="idea_b_compliance_rag",
            title="ArmorGuard: Row-Level Secure Multi-Tenant Hub",
            summary="Privacy-first architecture with strict tenant isolation.",
            tech_stack=["Vertex AI Gemini", "Cloud SQL RLS"],
            track_fit="Security & Governance",
            impact="Zero cross-tenant leaks",
            repo_name="armorguard-secure-hub",
        ),
        reasoning="Both ideas map to the discovered hackathon tracks.",
    )


def _fake_proposals_from_prompt(self, system_prompt, memory_context=None) -> DualProposalResponse:
    return _fake_proposals(self, {"title": "System Prompt"}, memory_context)


def _fake_architecture(self, idea, git_provider: str = "GITHUB", revision_feedback: str = "") -> ArchitectureSpec:
    return ArchitectureSpec(
        title=f"Cloud Native Architecture: {idea.get('title', 'Enterprise Prototype')}",
        diagram_mermaid="graph TD; A[Cloud Run] --> B[Cloud SQL]",
        components=[
            ArchitectureComponent(
                name="API Gateway", service_type="Cloud Run", role="Serves the fleet API"
            ),
        ],
    )


def _fake_file_plan(self, idea, architecture) -> FilePlanResponse:
    return FilePlanResponse(
        project_type="Backend Service",
        primary_language="python",
        entry_point="src/main.py",
        files=[
            FilePlanEntry(path="README.md", purpose="Architecture guide", language="markdown", is_critical_for_review=False),
            FilePlanEntry(path="src/main.py", purpose="Entry point", language="python", is_critical_for_review=True),
            FilePlanEntry(path="src/agent.py", purpose="Agent supervisor", language="python", is_critical_for_review=True),
            FilePlanEntry(path="Dockerfile", purpose="Container config", language="dockerfile", is_critical_for_review=True),
            FilePlanEntry(path="requirements.txt", purpose="Dependencies", language="text", is_critical_for_review=False),
            FilePlanEntry(path="tests/test_main.py", purpose="Tests", language="python", is_critical_for_review=False),
        ],
        reasoning="Standard 6-file scaffold for unit testing",
    )


def _fake_source_file(
    self, idea, architecture, file_path, purpose, existing_files,
    ceo_feedback=None, is_critical=False, language=None, context_hints=None,
) -> GeneratedFile:
    return GeneratedFile(
        path=file_path,
        content=f"# mock implementation of {file_path}\n",
        language=language or "python",
        commit_message=f"feat: scaffold {file_path}",
    )


def _fake_submission(self, idea, repo_url, test_results) -> SubmissionPackage:
    return SubmissionPackage(
        title=idea.get("title", "Enterprise Prototype"),
        tagline="Autonomous governed fleet prototype",
        demo_script_markdown="## 0:00 Intro\nThe fleet wakes up...",
        devpost_description="# Prototype\nBuilt with the Google ADK workflow engine.",
        features_and_functionality=["HITL CEO gates", "Real ADK Runner"],
        technologies_used=["Vertex AI", "Cloud Run"],
        learnings="Workflow interrupts map cleanly onto HITL gates.",
    )


def _fake_code_review(
    self, idea, architecture, files, hackathon_rules, previous_feedback="",
) -> CodeReview:
    return CodeReview(
        verdict="approve",
        summary="Mock review: implementation matches the architecture contract.",
        findings=[],
        rework_feedback="",
    )


class TestOrchestratorFleet(unittest.TestCase):
    def setUp(self):
        # Dart node: never hit the network from unit tests.
        import app.tools as tools_mod
        import app.agents.scout as scout_mod
        import app.agents.planner as planner_mod
        import app.agents.leaddev as leaddev_mod
        for target in (agents_mod, tools_mod, scout_mod, planner_mod, leaddev_mod):
            p = patch.object(target, "execute_dart_task", _fake_dart)
            p.start()
            self.addCleanup(p.stop)

        # Vertex AI: patch at class level so every agent's own client
        # instance (`llm or VertexGeminiClient()`) uses deterministic fakes.
        for method_name, fake in (
            ("generate_proposals", _fake_proposals),
            ("generate_proposals_from_prompt", _fake_proposals_from_prompt),
            ("generate_architecture", _fake_architecture),
            ("generate_file_plan", _fake_file_plan),
            ("generate_source_file", _fake_source_file),
            ("generate_submission", _fake_submission),
            ("generate_code_review", _fake_code_review),
        ):
            llm_patcher = patch.object(VertexGeminiClient, method_name, fake)
            llm_patcher.start()
            self.addCleanup(llm_patcher.stop)

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
        assert isinstance(result.handoff, Handoff)
        self.assertEqual(result.handoff.target_agent, "PlannerAgent")
        self.assertIn("active_opportunity", context.state)

    def test_scout_stores_all_hackathons_with_links(self):
        """Dashboard hackathon-board contract: ScoutAgent keeps every ranked
        match (no top-5 truncation — the UI tabs them by source), and every
        entry carries title + URL so the UI can deep-link each row to its
        specific hackathon in a new browser tab."""
        context = ToolContext(session_id="test_session_hackathons")
        scout = ScoutAgent()
        result = scout.run(self.mock_feed, context)

        self.assertEqual(result.status, "success")
        discovered = context.state.get("discovered_hackathons")
        self.assertIsNotNone(discovered)
        assert isinstance(discovered, list)
        discovered_list: list = discovered
        self.assertGreaterEqual(len(discovered_list), 1)
        for entry in discovered_list:
            self.assertIn("title", entry)
            self.assertIn("url", entry)
            self.assertTrue(str(entry["url"]).startswith("http"))
        # Rank #1 is the active opportunity the proposals are derived from.
        self.assertEqual(context.state["active_opportunity"], discovered_list[0])

    def test_planner_proposes_two_ideas_and_request_input(self):
        context = ToolContext(session_id="test_session_002")
        scout = ScoutAgent()
        scout_result = scout.run(self.mock_feed, context)

        planner = PlannerAgent()
        result = planner.formulate_proposals(scout_result.data, context)

        self.assertEqual(result.status, "awaiting_ceo_decision")
        assert isinstance(result.request_input, RequestInput)
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

    def test_ceo_decision_custom_idea_repo_already_exists_raises_repo_gate(self):
        """When provisioning reports 'already exists', process_ceo_decision must
        raise RequestInput for the Repo Decision Gate (CEO chooses between using
        the existing repo or creating a fresh one under a different name) —
        and must not crash on the lazy SESSION_DB import."""
        context = ToolContext(session_id="test_session_005")
        scout = ScoutAgent()
        scout_result = scout.run(self.mock_feed, context)
        planner = PlannerAgent()
        planner.formulate_proposals(scout_result.data, context)

        def _dart_repo_already_exists(endpoint_path, payload=None, *args, **kwargs):
            if endpoint_path == "tasks/provision-repo":
                return {
                    "status": "error",
                    "message": "Repository 'dup-repo' already exists on GitHub",
                    "repo_name": "dup-repo",
                }
            return _fake_dart(endpoint_path, payload)

        import app.agents.planner as planner_module

        with patch.object(planner_module, "execute_dart_task", _dart_repo_already_exists):
            with self.assertRaises(RequestInput) as cm:
                planner.process_ceo_decision(
                    decision_choice="custom_idea",
                    custom_prompt="Build a procedural 3D web engine with Dart + Flutter.",
                    git_provider="github",
                    custom_repo_name="dup-repo",
                    context=context,
                )

        req = cm.exception
        self.assertEqual(req.state_key, CEO_REPO_DECISION_GATE)
        option_values = [o["value"] for o in req.options]
        self.assertIn("use_existing_repo", option_values)
        self.assertIn("create_new_repo", option_values)
        self.assertEqual(context.state["existing_repo"]["repo_name"], "dup-repo")
        self.assertIn("dup-repo", context.state["existing_repo"]["web_url"])
        self.assertEqual(req.metadata["existing_repo"]["web_url"], context.state["existing_repo"]["web_url"])


if __name__ == "__main__":
    unittest.main()
