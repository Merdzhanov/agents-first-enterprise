"""Fleet runner — persistent ADK session service, Runner, start/resume API.

Phase 1 (``start_fleet_run``) runs the workflow until it pauses at a
Human-in-the-Loop gate; phase 2 (``resume_fleet_run``) feeds the CEO decision
back into the paused node.
"""
from __future__ import annotations

import os
from typing import Any, Dict, Optional, Tuple

from google.adk import Runner
from google.adk.errors.already_exists_error import AlreadyExistsError
from google.adk.sessions import DatabaseSessionService, InMemorySessionService
# Canonical HITL detection helpers in ADK 2.6.2 (not re-exported publicly).
from google.adk.workflow.utils._workflow_hitl_utils import (
    get_request_input_interrupt_ids,
    has_request_input_function_call,
)
from google.genai import types as genai_types

from .core import CEO_DECISION_GATE, CEO_DEPLOYMENT_GATE, SESSION_DB
from .workflow import FLEET_WORKFLOW

_DATABASE_URL = os.getenv("DATABASE_URL", "")


def _normalize_async_db_url(url: str) -> str:
    """Rewrites a database URL to its async driver form.

    ADK's DatabaseSessionService builds a SQLAlchemy *async* engine, which
    requires an async driver. Sync-driver URLs (the common defaults) crash at
    startup with 'The asyncio extension requires an async driver'. We map:
      postgresql://            -> postgresql+asyncpg://
      postgres:// (legacy)     -> postgresql+asyncpg://
      postgresql+psycopg2://   -> postgresql+asyncpg:// (sync driver)
      sqlite:///               -> sqlite+aiosqlite:/// (sync driver)
    URLs that already use an async driver are returned untouched.
    """
    if url.startswith("postgresql+psycopg2://"):
        return url.replace("postgresql+psycopg2://", "postgresql+asyncpg://", 1)
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+asyncpg://", 1)
    if url.startswith("sqlite:///") and not url.startswith("sqlite+aiosqlite:///"):
        return url.replace("sqlite:///", "sqlite+aiosqlite:///", 1)
    return url


def _build_session_service():
    """Returns the best available session service for the current environment."""
    if _DATABASE_URL:
        # Production path: Cloud SQL PostgreSQL via asyncpg (or any DATABASE_URL,
        # normalized to its async driver — ADK builds an async engine).
        url = _normalize_async_db_url(_DATABASE_URL)
        print(f"[FLEET] Using DatabaseSessionService (PostgreSQL): "
              f"{url.split('@')[-1] if '@' in url else url}")
        return DatabaseSessionService(db_url=url)
    # Development fallback: SQLite file so sessions survive process restarts.
    try:
        sqlite_url = "sqlite+aiosqlite:///./adk_sessions.db"
        print(f"[FLEET] Using DatabaseSessionService (SQLite dev): {sqlite_url}")
        return DatabaseSessionService(db_url=sqlite_url)
    except Exception as exc:
        print(f"[FLEET] WARNING: DatabaseSessionService unavailable ({exc}). "
              f"Falling back to InMemorySessionService (sessions lost on restart).")
        return InMemorySessionService()


FLEET_SESSION_SERVICE = _build_session_service()
FLEET_RUNNER = Runner(node=FLEET_WORKFLOW, session_service=FLEET_SESSION_SERVICE)
_FLEET_USER = "ceo"


async def start_fleet_run(
    session_id: str,
    raw_feed: Dict[str, Any],
    state_overrides: Optional[Dict[str, Any]] = None,
) -> Tuple[Dict[str, Any], Optional[Dict[str, Any]]]:
    """Runs phase 1 of the workflow. Returns (state, pending_request_input|None).

    Optional ``state_overrides`` are merged into the initial ADK session state
    (e.g. ``active_opportunity`` to skip discovery for a pre-selected hackathon).
    """
    try:
        await FLEET_SESSION_SERVICE.create_session(
            app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
        )
    except AlreadyExistsError:
        # Idempotent: a session for this id already exists — start fresh.
        await FLEET_SESSION_SERVICE.delete_session(
            app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
        )
        await FLEET_SESSION_SERVICE.create_session(
            app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
        )
    pending_event = None
    interrupt_ids: list = []
    state_delta: Dict[str, Any] = {
        "session_id": session_id,
        "raw_feed": raw_feed or {},
    }
    if state_overrides:
        state_delta.update(state_overrides)
    async for event in FLEET_RUNNER.run_async(
        user_id=_FLEET_USER,
        session_id=session_id,
        new_message=genai_types.Content(
            role="user", parts=[genai_types.Part(text="start fleet pipeline")],
        ),
        state_delta=state_delta,
    ):
        # HITL contract (ADK 2.6.2): a paused node emits a function_call named
        # 'adk_request_input' — there is NO `event.request_input` attribute.
        if has_request_input_function_call(event):
            pending_event = event
            interrupt_ids = get_request_input_interrupt_ids(event)

    sess = await FLEET_SESSION_SERVICE.get_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    state = dict(sess.state) if sess else {}

    pending = None
    if pending_event is not None:
        stored = state.get("pending_request_input") or {}
        # Pull the canonical interrupt args straight from the emitted call
        # (RequestInput is serialized with camelCase aliases).
        fc_args: Dict[str, Any] = {}
        content = pending_event.content if pending_event.content is not None else None
        if content is not None and content.parts is not None:
            for part in content.parts:
                call = getattr(part, "function_call", None)
                if call is not None and call.name == "adk_request_input":
                    fc_args = dict(call.args or {})
                    break
        raw_payload = fc_args.get("payload")
        payload: Dict[str, Any] = raw_payload if isinstance(raw_payload, dict) else {}
        pending = {
            "type": "REQUEST_INPUT",
            "interrupt_id": (
                interrupt_ids[0]
                if interrupt_ids
                else fc_args.get("interruptId") or stored.get("interrupt_id", CEO_DECISION_GATE)
            ),
            "state_key": stored.get("state_key", CEO_DECISION_GATE),
            "prompt": fc_args.get("message") or stored.get("prompt"),
            "options": payload.get("options") or stored.get("options", []),
            "metadata": stored.get("metadata", {}),
        }
    return state, pending


async def resume_fleet_run(
    session_id: str, decision_payload: Dict[str, Any]
) -> Tuple[Dict[str, Any], Optional[Dict[str, Any]]]:
    """Resumes the paused workflow with the CEO decision (phase 2)."""
    sess = await FLEET_SESSION_SERVICE.get_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    if sess is None:
        raise ValueError(f"No ADK session for '{session_id}' — trigger /fleet/discovery first.")

    function_call = None
    for event in reversed(sess.events):
        for call in (event.get_function_calls() if hasattr(event, "get_function_calls") else []):
            if call.name == "adk_request_input":
                function_call = call
                break
        if function_call is not None:
            break
    if function_call is None:
        raise RuntimeError("Workflow is not paused — no pending 'adk_request_input' call found.")

    resume_message = genai_types.Content(
        role="user",
        parts=[genai_types.Part(function_response=genai_types.FunctionResponse(
            id=function_call.id,
            name=function_call.name,
            response=decision_payload,
        ))],
    )
    async for _ in FLEET_RUNNER.run_async(
        user_id=_FLEET_USER, session_id=session_id, new_message=resume_message,
    ):
        pass

    final_session = await FLEET_SESSION_SERVICE.get_session(
        app_name=FLEET_RUNNER.app_name, user_id=_FLEET_USER, session_id=session_id,
    )
    state = dict(final_session.state) if final_session else {}
    # Multi-gate support: the resume may have paused again at the NEXT
    # human-in-the-loop gate — surface the pending question so the dashboard
    # can ask the CEO without restarting.
    pending = None
    stored_pending = state.get("pending_request_input") or {}
    if stored_pending and stored_pending.get("interrupt_id"):
        pending = {
            "type": "REQUEST_INPUT",
            "interrupt_id": stored_pending.get("interrupt_id"),
            "state_key": stored_pending.get("state_key"),
            "prompt": stored_pending.get("prompt"),
            "options": stored_pending.get("options", []),
            "metadata": stored_pending.get("metadata", {}),
        }
        gate = stored_pending.get("interrupt_id")
        if gate == CEO_DECISION_GATE:
            status = "awaiting_ceo_decision"
        elif gate == CEO_DEPLOYMENT_GATE:
            status = "awaiting_deployment_decision"
        else:
            status = "awaiting_gate_decision"
        agent = "DeploymentAgent" if gate == CEO_DEPLOYMENT_GATE else "ADKRunner"
    else:
        status = "skipped" if state.get("fleet_skipped") else "completed"
        agent = "ADKRunner"
    SESSION_DB.save_session(session_id, status, agent, state)
    SESSION_DB.append_trace(
        session_id, "ADKRunner",
        "skip" if status == "skipped" else "success",
        f"ADK workflow finished with status '{status}'.",
    )
    return state, pending
