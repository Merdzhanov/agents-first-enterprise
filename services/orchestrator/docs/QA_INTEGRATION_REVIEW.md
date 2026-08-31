# QA Integration Review — Enterprise Multi-Agent Fleet Engine

**Scope:** `services/orchestrator` (main.py, scheduler.py, agents.py, llm.py, schemas.py, tools.py, db.py, fleet_workflow.py, deployer.py) against **google-adk 2.6.2**.
**Method:** deep static analysis + empirical validation of every ADK API call against the installed 2.6.2 wheel (`site-packages/google/adk`), plus a full mocked pytest suite (`tests/test_integration.py`).

---

## 1. Critical findings (blockers) — and their resolution

### 1.1 `from google import Workflow as AdkWorkflow` — ImportError at boot (CRITICAL, fixed)
`main.py` and `scheduler.py` imported `Workflow` / `Runner` from the top-level `google` namespace. **These symbols do not exist** in `google-adk 2.6.2` — verified:
`python -c "from app.main import app"` → `ImportError: cannot import name 'Workflow' from 'google'`.
The service could not start at all (a Cloud Run container would crash-loop; `adk web` had no valid agent to load).

**Resolution:** `google.adk` 2.6.2 exposes the real graph workflow engine at `google.adk.workflow`:
```python
from google.adk.workflow import Workflow, FunctionNode, START   # real 2.6.2 paths
```
All orchestration now lives in `app/fleet_workflow.py`, built on the verified API surface:
- **`Workflow(name=..., description=...)`** with `nodes=[...]` + `edges=[(from, to), ...]`, entry via `START`;
- **`FunctionNode(func=..., name=..., rerun_on_resume=...)`** — async-generator nodes that `yield` values into the event stream;
- **HITL contract (empirically validated, see §2)**.

### 1.2 Fictional decorator `@AdkWorkflow(name=..., description=...)` (CRITICAL, fixed)
Both `main.py` (whole pipeline as one function) and `scheduler.py` used a decorator with no counterpart in ADK 2.6.2. Replaced with a real `Workflow` graph in `fleet_workflow.py` (`build_fleet_workflow()`) and a thin sync wrapper node for the scheduler (`ADK_ScheduledDiscovery`).

### 1.3 `AdkRunner(workflow=..., storage=...)` — no such constructor (CRITICAL, fixed)
ADK 2.6.2 runners are `Runner(agent=..., app_name=..., session_service=...)` (`google.adk.runners`). `storage=` never existed — session persistence goes through a `BaseSessionService`. Now:
```python
FLEET_SESSION_SERVICE = InMemorySessionService()   # swap for DatabaseSessionService in prod
FLEET_RUNNER = Runner(agent=build_fleet_workflow(), app_name="enterprise_fleet", session_service=FLEET_SESSION_SERVICE)
```

### 1.4 Custom `RequestInput` exception vs ADK's native mechanism (HIGH, reconciled)
`tools.RequestInput` (ours) collided conceptually with `google.adk.events.request_input.RequestInput` (the framework's). ADK 2.6.2 HITL works by **yielding an `adk_request_input` function-call event**, not by exceptions. Both coexist explicitly now:
- `tools.RequestInput` — our rich payload type (prompt, state_key, options, metadata) for **manual mode** and the deployment gate;
- `fleet_workflow.py` converts it → `AdkRequestInput(message=..., payload=..., response_schema=...)` and the gate node yields it, which is what the Runner and `adk web` natively render as an interrupt.

### 1.5 Duplicate-run guard in scheduler — validated correct
`scheduler.run_discovery_cycle()` checks `session_db.load_session(f"auto_session_{opp_id}")` **before** planning → Cloud Run container restarts cannot duplicate proposals for the same Devpost hackathon ID. Covered by an idempotency test (second cycle returns 0 new proposals). The guard is only as durable as the store: in-memory `CloudSessionManager` resets per container — use the Cloud SQL implementation in prod (§5).

## 2. The ADK 2.6.2 HITL contract — empirically validated

A standalone probe (`Runner.run_async` against the real 2.6.2 engine) confirmed the exact wire behavior the integration relies on:

| Aspect | Verified behavior |
|---|---|
| Pause | A node that yields `adk_request_input` (via `AdkRequestInput(...)`) **pauses the whole run**; downstream nodes (architect → dev → marketing) never execute |
| Event stream | Surfaces as an event with `get_function_calls() == [FunctionCall(name='adk_request_input', id=<interrupt_id>, args={...})]` |
| Payload | Our prompt/options/metadata ride in `args.payload` (UI-displayable) and `args.response_schema` (validated on resume) |
| State | `ctx.state["pending_request_input"]` holds the serialized gate; `idea_a` / `idea_b` / `discovered_hackathons` persist for phase 2 |
| Resume | Send `Content(role='user', parts=[Part(function_response=FunctionResponse(id=<interrupt_id>, name='adk_request_input', response=<decision>))])` through `run_async` |
| Gate rerun | `rerun_on_resume=True` on the gate node is **mandatory** — with the default `False`, resume treats the user input as the node's *output* and the rest of the DAG would run without ever reading the decision from state |

## 3. Static analysis — mismatches fixed beyond the imports

| # | Finding | Severity | Fix |
|---|---|---|---|
| 1 | `main.py` ADK branch read `run_result.state.get("proposed_ideas")` — key never existed; agents write `idea_a`/`idea_b` | HIGH (silent empty UI) | Response built from real state keys; `pending_request_input` mirrored |
| 2 | ADK-branch `submit_ceo_decision` dropped `git_provider`/`custom_repo_name` — resume lost the decision context | HIGH | `decision_payload` carries all fields; `planner_gate_node` writes `selected_idea`/`git_repo` from it |
| 3 | `CeoDecisionRequest.decision_choice: str` accepted any garbage | MED | `Literal["approve_idea_a","approve_idea_b","custom_idea","skip_implementation"]` → FastAPI 422 (tested) |
| 4 | Background resume exceptions vanished (session stuck `processing_in_background`) | HIGH | `background_runner_resume` catches, saves `status='failed'` + error trace (dashboard surfaces it) |
| 5 | `execute_dart_task` returned `None` on failure; callers did `["matches"]` → `TypeError` | MED | Returns `{"status":"error","matches":[]}`; workflow halts gracefully |
| 6 | Agents crash-looped when Vertex was unavailable | MED | Deterministic template fallbacks (architecture/codegen/submission) — demo runs offline; covered by tests |
| 7 | Status drift: `pending_ceo_review` (scheduler) vs `awaiting_ceo_decision` (API) | LOW | Normalized; traces keep `agent_name`/`type`/`msg` keys the dashboard expects |
| 8 | Circular-import risk from the new `fleet_workflow` layer | — | Verified: `fleet_workflow` → `agents/tools/db`; `main` → `fleet_workflow`; no reverse edges. `import app.main` clean |
| 9 | Legacy unittest suite (6 tests) broke against the new dual-mode responses | LOW | Updated; **7/7 pytest + 6/6 unittest green** |

## 4. Test suite — `tests/test_integration.py` (pytest, 7 tests)

Real components exercised: **FastAPI `TestClient` + the actual ADK 2.6.2 `Runner`/`Workflow` engine + `InMemorySessionService`**. Mocked: `VertexGeminiClient` (patched at `fleet_workflow.LLM_CLIENT`) and `execute_dart_task` (patched in the `fleet_workflow` namespace).

| Test | Validates |
|---|---|
| `test_health_and_mode_headers` | Boot, `default_execution_mode` surfaced |
| `test_discovery_pauses_at_ceo_gate` | E2E step 1: `awaiting_ceo_decision`, `state_key='ceo_decision'`, both ideas + top-5 hackathons attached |
| `test_full_pipeline_approve_to_completed` | E2E steps 1–3: resume via background task → `completed`; `git_repo` + `submission` artifacts populated by the resumed DAG |
| `test_skip_implementation_archives_session` | Zero-spend skip path |
| `test_invalid_decision_choice_rejected` | Literal enum → 422 |
| `test_scheduled_discovery_idempotent` | Duplicate-run guard (2nd call: 0 proposals) |
| `test_deployment_agent_gate_and_execute` | DeploymentAgent HITL pause + confirm/cancel execution |

Run: `.venv/bin/python -m pytest tests/ -v` · legacy: `.venv/bin/python -m unittest discover tests`

## 5. Cloud Run edge cases for `deploy.sh`

| Setting | Recommendation | Why (from this architecture) |
|---|---|---|
| `--memory` | **1Gi** (not 512Mi) | `google-genai` + google-adk + Pydantic graph engine + generated-file buffers; 512Mi risks OOM under concurrent LLM JSON payloads |
| `--cpu` | 2 | Background CEO pipeline shares the container with health/poll requests |
| `--concurrency` | 4–8 | Background tasks are CPU-heavy (LLM parsing, codegen); low concurrency protects the shared event loop |
| `--min-instances=1` (orchestrator only) | Cloud Scheduler hits `/fleet/scheduled-discovery`; cold starts + in-memory session service lose ADK sessions | Scale-to-zero stays correct for the *prototype* services `deployer.py` builds (`min-instances=0`) |
| `--timeout=900` | CEO resume runs as a BackgroundTask after the HTTP response; long LLM chains exceed defaults and BackgroundTasks die with the instance | |
| Session persistence | Swap `InMemorySessionService` → `DatabaseSessionService` (Cloud SQL) | Phase-2 resume must find the paused session **on a different container** than discovery; in-memory → `failed` status `No ADK session` (surfaced, not hung) |
| IAM | `--no-allow-unauthenticated` + OIDC invoker binding | tools.py fetches ID tokens with `audience=base_url`; deploy must grant `roles/run.invoker` to the orchestrator SA on the Dart node |
| Env | `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `DART_NODE_URL`, `DISCOVERY_INTERVAL_MINUTES` | `GOOGLE_GENAI_USE_VERTEXAI=True` flips tools.py into OIDC mode — never set locally |

## 6. Manual testing — `scripts/smoke_curl.sh`

Seven-step paste-ready script (health → discovery → CEO gate → poll → traces → artifacts → scheduler idempotency → 422 path) with inline assertions:
```bash
cd services/orchestrator && .venv/bin/python -m uvicorn app.main:app --port 8000
bash services/orchestrator/scripts/smoke_curl.sh
```
Endpoints covered: `GET /health`, `POST /fleet/discovery`, `POST /fleet/ceo-decision`, `GET /fleet/session/{id}` (+`/traces`, `/artifacts`), `POST /fleet/scheduled-discovery`.

## 7. `adk web` demo entry point

`fleet_agent/` at the orchestrator root exposes `root_agent` as a real `google.adk.workflow.Workflow` (`EnterpriseFleetWorkflow`): `SCOUT → PLANNER_GATE (HITL) → ARCHITECT → LEAD_DEV → MARKETING`. From `services/orchestrator`:
```bash
GOOGLE_CLOUD_PROJECT=<project> GOOGLE_CLOUD_LOCATION=<region> .venv/bin/adk web
```
Select **fleet_agent** in the UI and run — it pauses at the CEO Proposal Gate with rendered options; the typed decision resumes the graph through architect/dev/marketing (same engine the FastAPI endpoints drive).

