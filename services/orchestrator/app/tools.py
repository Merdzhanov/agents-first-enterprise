"""Tools and Execution Bridges for Python ADK Orchestration Fleet."""
from __future__ import annotations

import json
import os
import urllib.request
import urllib.error
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


def get_oidc_token(audience: str) -> Optional[str]:
    """
    Generates a secure OIDC token for Cloud Run service-to-service communication.
    Tries google-auth library first (ADC compatible), falls back to metadata server.
    """
    try:
        import google.auth.transport.requests
        import google.oauth2.id_token
        auth_req = google.auth.transport.requests.Request()
        return google.oauth2.id_token.fetch_id_token(auth_req, audience=audience)
    except ImportError:
        # Fallback to the Google Cloud internal metadata server
        try:
            req = urllib.request.Request(
                f"http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience={audience}",
                headers={"Metadata-Flavor": "Google"}
            )
            with urllib.request.urlopen(req, timeout=3) as response:
                return response.read().decode('utf-8')
        except Exception as e:
            print(f"Warning: Failed to fetch OIDC token from metadata server (running locally?): {e}")
            return None
    except Exception as e:
        print(f"OIDC token acquisition note: {e}")
        return None


class RequestInput(Exception):
    """Signals that the agent loop must pause for Human-in-the-Loop CEO approval."""
    def __init__(
        self,
        prompt: str,
        state_key: str,
        options: Optional[List[Dict[str, Any]]] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ):
        self.prompt = prompt
        self.state_key = state_key
        self.options = options or []
        self.metadata = metadata or {}
        super().__init__(prompt)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "type": "REQUEST_INPUT",
            "prompt": self.prompt,
            "state_key": self.state_key,
            "options": self.options,
            "metadata": self.metadata,
        }


@dataclass
class Handoff:
    """Signals a routing transition to another specialized agent in the fleet."""
    target_agent: str
    reason: str = ""
    transferred_state: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ToolContext:
    """Execution context and shared scratchpad state across agent turns."""
    session_id: str
    state: Dict[str, Any] = field(default_factory=dict)
    memory_bank: List[Dict[str, Any]] = field(default_factory=list)

    def search_memory(self, query: str) -> List[Dict[str, Any]]:
        # OPTIMIZATION: Updated to match the "content" key used in VectorMemoryManager
        q = query.lower()
        return [
            m for m in self.memory_bank
            if q in m.get("content", "").lower() or q in m.get("topic", "").lower()
        ]


def execute_dart_task(
    endpoint_path: str,
    payload: Dict[str, Any],
    dart_node_base_url: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Executes a deterministic task by calling the Dart Shelf Functional Node.
    Uses Google Cloud OIDC Bearer token when running in GCP / Cloud Run,
    with local dev fallback.
    """
    base_url = (
        dart_node_base_url
        or os.getenv("DART_NODE_URL")
        or "http://127.0.0.1:8080"
    ).rstrip("/")
    url = f"{base_url}/{endpoint_path.lstrip('/')}"

    headers = {
        "Content-Type": "application/json",
    }

    # Acquire OIDC identity token for IAM protected Cloud Run instances
    if os.getenv("GOOGLE_GENAI_USE_VERTEXAI") == "True" and not base_url.startswith("http://127.0.0.1"):
        id_token = get_oidc_token(audience=base_url)
        if id_token:
            headers["Authorization"] = f"Bearer {id_token}"


    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as err:
        # Provide resilient mock response in local offline simulation
        print(f"Dart Node at {url} unreachable ({err}). Falling back to internal deterministic driver.")
        
        if "parse-brief" in endpoint_path:
            return {
                "status": "success_mock",
                "total_evaluated": len(payload.get("hackathons", [])),
                "filtered_count": 1,
                "matches": [
                    {
                        "id": "hack_gemini_enterprise",
                        "title": "Google Cloud & Gemini Multi-Agent Challenge",
                        "url": "https://googlecloudagents.devpost.com",
                        "submission_deadline": "2026-09-30",
                        "deadline": "2026-09-30",
                        "prize_pool": 75000,
                        "eligible_gcp_apis": ["Vertex AI", "Cloud Run", "Firestore", "Pub/Sub"],
                        "tracks": ["Fortified Enterprise Fleet", "Agentic Systems"],
                    }
                ],
            }
        elif "provision-repo" in endpoint_path:
            repo_name = payload.get("repo_name", "prototype-repo")
            provider = payload.get("provider", "github")
            base = "github.com" if provider == "github" else "gitlab.com"
            return {
                "status": "provisioned_mock",
                "provider": provider,
                "repo_name": repo_name,
                "web_url": f"https://{base}/agents-first-enterprise/{repo_name}",
                "project_id": 99887766,
                "files_committed": ["README.md", "LICENSE", ".gitignore"],
            }
        elif "commit-files" in endpoint_path:
            files = payload.get("files", [])
            return {
                "status": "committed_mock",
                "provider": payload.get("provider", "github"),
                "repo_name": payload.get("repo_name", "prototype-repo"),
                "committed_files": [f.get("path") for f in files],
                "commit_sha": "mock_sha_123456",
            }
            
        return {"status": "error", "message": str(err)}


def propose_ideas_to_ceo(
    idea_a: Dict[str, Any],
    idea_b: Dict[str, Any],
    tool_context: ToolContext,
) -> RequestInput:
    """
    Submits two distinct prototype ideas to the CEO via RequestInput,
    along with options for custom input and skipping implementation.
    """
    options = [
        {
            "id": "approve_idea_a",
            "title": f"Idea A: {idea_a.get('title', 'Concept A')}",
            "description": idea_a.get("summary", ""),
            "tech_stack": idea_a.get("tech_stack", []),
            "estimated_impact": idea_a.get("impact", "High"),
            "data": idea_a,
        },
        {
            "id": "approve_idea_b",
            "title": f"Idea B: {idea_b.get('title', 'Concept B')}",
            "description": idea_b.get("summary", ""),
            "tech_stack": idea_b.get("tech_stack", []),
            "estimated_impact": idea_b.get("impact", "High"),
            "data": idea_b,
        },
        {
            "id": "custom_idea",
            "title": "Propose Custom Direction",
            "description": "Provide a custom instruction or requirement for the technical fleet.",
            "requires_text_input": True,
        },
        {
            "id": "skip_implementation",
            "title": "Skip Implementation",
            "description": "Decline all current proposals and archive this discovery cycle.",
        },
    ]

    tool_context.state["proposed_ideas"] = {
        "idea_a": idea_a,
        "idea_b": idea_b,
    }

    raise RequestInput(
        prompt="Discovery phase complete. Please review the 2 proposed implementation concepts, provide a custom direction, or skip implementation.",
        state_key="ceo_decision",
        options=options,
        metadata={"stage": "CEO_PROPOSAL_GATE", "ideas_count": 2},
    )