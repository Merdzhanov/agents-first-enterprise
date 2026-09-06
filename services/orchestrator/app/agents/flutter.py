"""Flutter Frontend Agent — generates multi-platform Flutter applications."""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from ..llm import VertexGeminiClient
from ..tools import ToolContext
from .base import AgentResult


class FlutterFrontendAgent:
    """Multi-platform Flutter Developer (iOS, Android, Web/WASM, Desktop)."""
    name: str = "FlutterFrontendAgent"

    ALL_PLATFORMS = ["ios", "android", "web", "windows", "macos", "linux"]

    def __init__(self, llm: Optional[VertexGeminiClient] = None):
        self.llm = llm or VertexGeminiClient()

    def _detect_platforms(self, idea: Dict[str, Any], arch: Dict[str, Any]) -> List[str]:
        """Detect target platforms from idea and architecture spec."""
        platforms: List[str] = []
        tech = [t.lower() for t in (idea.get("tech_stack") or [])]
        desc = (idea.get("description") or "").lower()
        combined = " ".join(tech) + " " + desc
        if "ios" in combined or "iphone" in combined:
            platforms.append("ios")
        if "android" in combined or "mobile" in combined:
            platforms.append("android")
        if "web" in combined or "wasm" in combined or "browser" in combined:
            platforms.append("web")
        if "windows" in combined or "win32" in combined:
            platforms.append("windows")
        if "macos" in combined or "darwin" in combined:
            platforms.append("macos")
        if "linux" in combined or "gtk" in combined:
            platforms.append("linux")
        return platforms or ["ios", "android", "web"]

    def _is_shader_project(self, idea: Dict[str, Any]) -> bool:
        """Check if this project uses GPU shaders."""
        tech = [t.lower() for t in (idea.get("tech_stack") or [])]
        desc = (idea.get("description") or "").lower()
        kws = ["shader", "glsl", "raymarching", "sdf", "3d", "gpu", "fragment", "opengl", "vulkan"]
        return any(k in " ".join(tech) + " " + desc for k in kws)

    def run(self, idea: Dict[str, Any], context: ToolContext) -> AgentResult:
        title = idea.get("title", "Flutter App")
        repo_name = idea.get("repo_name", "flutter-app")
        arch = context.state.get("architecture_spec", {})
        rework = str(context.state.get("rework_feedback") or "")
        platforms = self._detect_platforms(idea, arch)
        uses_shaders = self._is_shader_project(idea)
        shader_path = context.state.get("shader_path", "assets/shaders/app_shader.frag")

        # Build file generation plan
        files: Dict[str, str] = {
            "pubspec.yaml": f"Multi-platform config. Targets: {', '.join(platforms)}.",
            "lib/main.dart": "Platform-aware entry point.",
            "lib/app.dart": "Root MaterialApp with responsive layout.",
        }
        if uses_shaders:
            files["lib/shader_controller.dart"] = "Shader uniform controller."
            files["lib/shader_canvas.dart"] = "FragmentShader canvas widget."
        if "web" in platforms:
            files["web/index.html"] = "Web entry point."
            files["web/manifest.json"] = "PWA manifest."

        generated: Dict[str, str] = {}
        committed = list(context.state.get("committed_files", []))
        for path, purpose in files.items():
            try:
                g = self.llm.generate_source_file(
                    idea=idea,
                    architecture=arch,
                    file_path=path,
                    purpose=purpose,
                    existing_files=committed,
                    ceo_feedback=rework,
                    is_critical=True,
                    language="dart" if path.endswith(".dart") else ("yaml" if path.endswith(".yaml") else "generic"),
                    context_hints=f"Project: {title}, Platforms: {', '.join(platforms)}, Shader: {shader_path if uses_shaders else 'none'}",
                )
                generated[path] = g.content
                committed.append(path)
            except Exception as e:
                raise RuntimeError(
                    f"Flutter source generation failed transparently for '{path}': {e}"
                ) from e

        context.state.setdefault("flutter_project_files", {})
        context.state["flutter_project_files"].update(generated)
        context.state["committed_files"] = committed
        context.state["flutter_project_type"] = "multi_platform"
        context.state["flutter_platforms"] = platforms

        return AgentResult(
            agent_name=self.name,
            status="success",
            message=f"Flutter multi-platform implementation for {repo_name} generated ({len(generated)} files).",
            data={"files_generated": list(generated.keys()), "platforms": platforms, "uses_shaders": uses_shaders},
        )
