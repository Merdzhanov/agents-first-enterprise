"""Flutter WASM nodes: development + compilation verification gate."""
from __future__ import annotations

from typing import Any

from google.adk.events.request_input import RequestInput as AdkRequestInput
from google.adk.workflow import node

from ..agents import FlutterFrontendAgent, ShaderEngineerAgent
from ..tools import validate_flutter_wasm_build
from .core import (
    LLM_CLIENT,
    MAX_BUILD_ROUNDS,
    SESSION_DB,
    _sync_state,
    _tool_ctx,
)


@node(name="flutter_dev_node")
async def flutter_dev_node(ctx: Any):
    """Flutter development node — generates shader + Flutter project structure."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)

    # Step 1: Generate the shader
    shader_agent = ShaderEngineerAgent(llm=LLM_CLIENT)
    shader_result = shader_agent.run(tc.state.get("selected_idea", {}), tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(
        tc.session_id, "ShaderEngineerAgent", "agent",
        f"ADK node: shader generated — '{shader_result.data.get('shader_path')}'.",
    )

    # Step 2: Generate Flutter project structure
    flutter_agent = FlutterFrontendAgent(llm=LLM_CLIENT)
    flutter_result = flutter_agent.run(tc.state.get("selected_idea", {}), tc)
    _sync_state(ctx, tc)
    SESSION_DB.append_trace(
        tc.session_id, "FlutterFrontendAgent", "agent",
        f"ADK node: Flutter project generated with {len(flutter_result.data.get('files_generated', []))} files.",
    )

    yield {
        "agent": flutter_result.agent_name,
        "status": flutter_result.status,
        "files": flutter_result.data.get("files_generated", []),
        "shader": shader_result.data.get("shader_path"),
        "project_type": "flutter_wasm",
    }


@node(name="wasm_verify_node", rerun_on_resume=True)
async def wasm_verify_node(ctx: Any):
    """Compilation verification gate — runs a real ``flutter build web --wasm``
    on the Dart Node before the code reaches the CEO review."""
    if ctx.state.get("fleet_skipped"):
        yield {"skipped": True}
        return
    tc = _tool_ctx(ctx)

    project_files = tc.state.get("flutter_project_files") or {}
    if not project_files:
        SESSION_DB.append_trace(
            tc.session_id, "WasmVerify", "warning",
            "No Flutter project files found — skipping WASM verification.",
        )
        yield {"build_status": "skipped", "reason": "no_files"}
        return

    SESSION_DB.append_trace(
        tc.session_id, "WasmVerify", "system",
        f"Submitting {len(project_files)} files for WASM compilation verification...",
    )

    result = validate_flutter_wasm_build(project_files, tc)
    _sync_state(ctx, tc)
    status = result.get("status")

    if status == "success":
        SESSION_DB.append_trace(
            tc.session_id, "WasmVerify", "success",
            "WASM build successful — proceeding to code review.",
        )
        yield {"build_status": "success", "route": "code_review"}
        return

    # Build failed — bounded rework loop back to the Flutter dev node.
    errors = result.get("errors") or [result.get("logs", "unknown error")]
    build_round = int(ctx.state.get("wasm_build_rounds") or 0)
    if build_round < MAX_BUILD_ROUNDS:
        ctx.state["wasm_build_rounds"] = build_round + 1
        ctx.state["rework_feedback"] = (
            "[WASM BUILD GATE] The Flutter build failed. Fix these compiler "
            "errors:\n" + "\n".join(f"- {e}" for e in errors[:10])
        )
        SESSION_DB.append_trace(
            tc.session_id, "WasmVerify", "error",
            f"WASM build failed with {len(errors)} error(s) — rework round "
            f"{build_round + 1}/{MAX_BUILD_ROUNDS}.",
        )
        ctx.route = "rework_build"
        yield {
            "build_status": "failed",
            "route": "rework_build",
            "errors": errors[:10],
            "build_round": build_round + 1,
        }
        return

    # Cap reached — force through with a warning so the pipeline never hangs.
    SESSION_DB.append_trace(
        tc.session_id, "WasmVerify", "warning",
        f"WASM rework cap reached ({MAX_BUILD_ROUNDS}) — forcing proceed with failing build.",
    )
    yield {"build_status": "failed_forced", "route": "code_review", "errors": errors[:10]}

