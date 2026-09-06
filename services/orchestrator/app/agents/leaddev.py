"""Lead Dev Agent — dynamic iterative code generation for any project stack."""
from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from ..llm import VertexGeminiClient
from ..schemas import FilePlanEntry, FilePlanResponse, FileRequest
from ..tools import Handoff, ToolContext, execute_dart_task
from .base import AgentResult


class LeadDevAgent:
    """Executes dynamic file-by-file code scaffolding for any tech stack."""
    name: str = "LeadDevAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, context: ToolContext) -> AgentResult:
        selected_idea = context.state.get("selected_idea", {})
        arch_spec = context.state.get("architecture_spec", {})
        repo = context.state.get("git_repo", {})
        provider = context.state.get("git_provider", "github")
        owner = repo.get("owner") or os.getenv("GIT_OWNER") or os.getenv("GITHUB_ACTOR") or "agent-enterprise"
        repo_name = repo.get("repo_name", "prototype-repo")

        # 1. Determine dynamic file plan
        file_plan_entries: List[FilePlanEntry] = []
        entry_point = ""
        cached_plan = context.state.get("file_plan")

        if cached_plan:
            if isinstance(cached_plan, dict):
                file_plan_entries = [
                    FilePlanEntry(**f) if isinstance(f, dict) else f
                    for f in cached_plan.get("files", [])
                ]
                entry_point = cached_plan.get("entry_point", "")
            elif hasattr(cached_plan, "files"):
                file_plan_entries = cached_plan.files
                entry_point = getattr(cached_plan, "entry_point", "")

        if not file_plan_entries:
            try:
                plan_resp = self.llm.generate_file_plan(
                    idea=selected_idea,
                    architecture=arch_spec,
                )
                file_plan_entries = plan_resp.files
                entry_point = plan_resp.entry_point
                context.state["file_plan"] = plan_resp.model_dump()
            except Exception as e:
                raise RuntimeError(
                    f"Dynamic file plan generation failed for '{selected_idea.get('title', repo_name)}': {e}"
                ) from e

        if not file_plan_entries:
            raise RuntimeError(
                f"File plan generated zero files for '{selected_idea.get('title', repo_name)}'. Cannot proceed with empty project."
            )

        committed_files: List[str] = []
        files_to_commit: List[Dict[str, Any]] = []
        global_rework = str(context.state.get("rework_feedback") or "")

        # 2. Iterate through planned files dynamically
        for file_req in file_plan_entries:
            ceo_feedback = context.state.get(f"feedback_{file_req.path}")
            combined_feedback = global_rework if global_rework else ceo_feedback

            try:
                generated = self.llm.generate_source_file(
                    idea=selected_idea,
                    architecture=arch_spec,
                    file_path=file_req.path,
                    purpose=file_req.purpose,
                    existing_files=committed_files,
                    ceo_feedback=combined_feedback,
                    is_critical=file_req.is_critical_for_review,
                    language=getattr(file_req, "language", None),
                )
                files_to_commit.append({
                    "path": generated.path,
                    "content": generated.content,
                    "commit_message": generated.commit_message,
                })
                committed_files.append(generated.path)
            except Exception as e:
                if file_req.is_critical_for_review:
                    raise RuntimeError(
                        f"Critical file generation failed for '{file_req.path}': {e}"
                    ) from e
                print(f"⚠️ [LeadDevAgent] Failed to generate {file_req.path}: {e}. Skipping non-critical file.")
                continue

        if not files_to_commit:
            return AgentResult(
                agent_name=self.name,
                status="error",
                message="Failed to generate any files. Check Vertex AI connection or limits.",
                data={},
            )

        commit_payload = {
            "provider": provider,
            "owner": owner,
            "repo_name": repo_name,
            "project_id": repo.get("project_id", repo_name),
            "files": files_to_commit,
        }

        try:
            dart_commit_result = execute_dart_task("tasks/commit-files", commit_payload)
        except Exception as e:
            dart_commit_result = {"status": "error", "message": str(e)}

        context.state["committed_files"] = committed_files
        context.state["git_commit_status"] = dart_commit_result
        context.state["generated_files"] = files_to_commit

        commit_status = str(dart_commit_result.get("status", ""))
        if commit_status != "committed" or not dart_commit_result.get("commit_sha"):
            err_msg = (
                f"Git commit FAILED for '{repo_name}' on {provider.upper()}: "
                f"{dart_commit_result.get('message', commit_status)}. "
                f"No files were actually pushed."
            )
            raise RuntimeError(err_msg)

        resolved_entry = entry_point or (committed_files[0] if committed_files else "main")
        code_deliverables = {
            "entry_point": resolved_entry,
            "backend_entry": resolved_entry,  # backward compatibility
            "files_committed": committed_files,
            "commit_status": commit_status,
            "verification_status": f"Scaffolded {len(committed_files)} files with verifiable syntax",
        }
        context.state["code_deliverables"] = code_deliverables
        context.state["rework_feedback"] = ""

        return AgentResult(
            agent_name=self.name,
            status="success",
            message=f"Iterative scaffolding complete. {len(committed_files)} files committed to {provider.upper()} repo.",
            data=code_deliverables,
            handoff=Handoff(
                target_agent="MarketingAgent",
                reason="Assemble submission deliverables, README, and demo video script",
            ),
        )
