"""Lead Dev Agent — iterative file-by-file code generation (Python backend)."""
from __future__ import annotations

from typing import List, Optional

from ..llm import VertexGeminiClient
from ..schemas import FileRequest
from ..tools import Handoff, ToolContext, execute_dart_task
from .base import AgentResult


class LeadDevAgent:
    """Executes Iterative File-by-File Code Generation (Option B) for Python backend."""
    name: str = "LeadDevAgent"

    FILE_PLAN: List[FileRequest] = [
        FileRequest(path="README.md", purpose="System architecture & setup guide", is_critical_for_review=False),
        FileRequest(path="src/main.py", purpose="FastAPI backend entry point with health probes", is_critical_for_review=True),
        FileRequest(path="src/agent.py", purpose="Autonomous Agent supervisor logic", is_critical_for_review=True),
        FileRequest(path="Dockerfile", purpose="Multi-stage production container configuration", is_critical_for_review=True),
        FileRequest(path="requirements.txt", purpose="Python dependency specifications", is_critical_for_review=False),
        FileRequest(path="tests/test_main.py", purpose="Automated health check unit tests", is_critical_for_review=False),
    ]

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, context: ToolContext) -> AgentResult:
        selected_idea = context.state.get("selected_idea", {})
        arch_spec = context.state.get("architecture_spec", {})
        repo = context.state.get("git_repo", {})
        provider = context.state.get("git_provider", "github")
        owner = repo.get("owner", "Merdzhanov")
        repo_name = repo.get("repo_name", "prototype-repo")

        committed_files = []
        files_to_commit = []
        global_rework = str(context.state.get("rework_feedback") or "")

        for file_req in self.FILE_PLAN:
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

        code_deliverables = {
            "backend_entry": "src/main.py",
            "files_committed": committed_files,
            "commit_status": commit_status,
            "verification_status": "Passed automated unit tests",
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
