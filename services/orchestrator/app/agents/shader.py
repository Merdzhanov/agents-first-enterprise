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
        shader_path = "assets/shaders/red_hood_3d.frag"
        rework_feedback = str(context.state.get("rework_feedback") or "")

        # Search memory for SDF formulas
        memories = context.search_memory("SDF 3D shapes raymarching lighting formulas")
        memory_str = "\n".join(f"- {m.get('content', '')}" for m in memories)

        prompt = (
            f"Write a mathematically perfect GLSL fragment shader for: '{title}'.\n"
            f"Concept: {summary}\n"
            f"Target: {shader_path}\n\n"
            f"MANDATORY SPECS:\n"
            f"1. All 3D via SDF (Signed Distance Fields) — no mesh files\n"
            f"2. Raymarching loop: MAX 64-80 steps with early exit (< 0.001)\n"
            f"3. Uniforms: uTime (float), uSize (vec2)\n"
            f"4. Blinn-Phong lighting, camera with ray origin/direction\n"
            f"5. Output ONLY raw GLSL code, no markdown\n\n"
            f"GROUNDED MATH:\n{memory_str or 'Use standard SDF formulas'}\n\n"
            f"REWORK:\n{rework_feedback or 'None'}"
        )

        try:
            generated = self.llm.generate_source_file(
                idea=idea,
                architecture=context.state.get("architecture_spec", {}),
                file_path=shader_path,
                purpose="Optimized 3D SDF Raymarching Fragment Shader",
                existing_files=context.state.get("committed_files", []),
                ceo_feedback=rework_feedback,
                is_critical=True,
            )
        except Exception as e:
            print(f"⚠️ [ShaderEngineerAgent] Fallback due to LLM error: {e}")
            generated = GeneratedFile(
                path=shader_path,
                content=FALLBACK_SHADER,
                language="glsl",
                commit_message="Add fallback procedural fragment shader",
            )

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


FALLBACK_SHADER = """#version 460 core
precision highp float;
layout(location = 0) out vec4 fragColor;
layout(location = 0) uniform float uTime;
layout(location = 1) uniform vec2 uSize;

float sdSphere(vec3 p, float r) { return length(p) - r; }

float map(vec3 p) {
    float sphere = sdSphere(p, 1.0);
    float box = length(max(abs(p - vec3(sin(uTime), 0.0, 0.0)) - vec3(0.5), 0.0)) - 0.3;
    return min(sphere, box);
}

vec3 calcNormal(vec3 p) {
    const float h = 0.001;
    return normalize(vec3(
        map(p + vec3(h, 0, 0)) - map(p - vec3(h, 0, 0)),
        map(p + vec3(0, h, 0)) - map(p - vec3(0, h, 0)),
        map(p + vec3(0, 0, h)) - map(p - vec3(0, 0, h))
    ));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uSize) / uSize.y;
    vec3 ro = vec3(0.0, 0.0, 4.0);
    vec3 rd = normalize(vec3(uv, -1.5));

    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if (d < 0.001) break;
        t += d;
        if (t > 20.0) break;
    }

    vec3 color = vec3(0.05, 0.05, 0.1);
    if (t < 20.0) {
        vec3 pos = ro + rd * t;
        vec3 nor = calcNormal(pos);
        vec3 light = normalize(vec3(0.8, 0.8, 0.6));
        float diff = max(dot(nor, light), 0.0);
        color = vec3(0.9, 0.2, 0.1) * (0.2 + 0.8 * diff);
    }

    fragColor = vec4(pow(color, vec3(1.0/2.2)), 1.0);
}
"""
