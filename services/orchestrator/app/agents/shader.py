"""Shader Engineer Agent — generates GLSL fragment shaders for Flutter WASM."""
from __future__ import annotations

from typing import Any, Dict, Optional

from ..llm import VertexGeminiClient
from ..schemas import GeneratedFile
from ..tools import ToolContext
from .base import AgentResult


class ShaderEngineerAgent:
    """Specialized Graphics Engineer Agent for SDF Raymarching GLSL shaders."""
    name: str = "ShaderEngineerAgent"

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def run(self, idea: Dict[str, Any], context: ToolContext) -> AgentResult:
        title = idea.get("title", "3D Procedural Prototype")
        summary = idea.get("summary", "A 3D procedural rendering experience.")
        repo_slug = idea.get("repo_name", "procedural_scene").replace("-", "_")
        shader_path = idea.get("shader_path") or f"shaders/{repo_slug}.frag"
        rework_feedback = str(context.state.get("rework_feedback") or "")

        # Search memory for SDF formulas
        memories = context.search_memory("SDF 3D shapes raymarching lighting formulas")
        memory_str = "\n".join(f"- {m.get('content', '')}" for m in memories)

        prompt = (
            f"Write a mathematically sound GLSL fragment shader for: '{title}'.\n"
            f"Concept: {summary}\n"
            f"Target file: {shader_path}\n\n"
            f"MANDATORY SPECS:\n"
            f"1. All 3D via SDF (Signed Distance Fields) — procedural, no external mesh files\n"
            f"2. Raymarching loop: MAX 64-80 steps with early exit (< 0.001)\n"
            f"3. Uniforms: uTime (float), uSize (vec2)\n"
            f"4. Blinn-Phong or PBR lighting, camera with ray origin/direction\n"
            f"5. Output ONLY raw GLSL code, no markdown wrapping\n\n"
            f"GROUNDED MATH:\n{memory_str or 'Use standard SDF formulas'}\n\n"
            f"REWORK:\n{rework_feedback or 'None'}"
        )

        try:
            generated = self.llm.generate_source_file(
                idea=idea,
                architecture=context.state.get("architecture_spec", {}),
                file_path=shader_path,
                purpose=f"Optimized 3D SDF Raymarching Fragment Shader ({title})",
                existing_files=context.state.get("committed_files", []),
                ceo_feedback=rework_feedback,
                is_critical=True,
                language="glsl",
            )
        except Exception as e:
            raise RuntimeError(
                f"Shader generation failed transparently for '{shader_path}': {e}"
            ) from e

        # Store in state
        if "flutter_project_files" not in context.state:
            context.state["flutter_project_files"] = {}
        context.state["flutter_project_files"][shader_path] = generated.content
        context.state["shader_path"] = shader_path

        return AgentResult(
            agent_name=self.name,
            status="success",
            message=f"3D SDF Raymarching shader '{shader_path}' generated.",
            data={"shader_path": shader_path, "shader_content": generated.content},
        )

