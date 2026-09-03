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
            "pubspec.yaml": f"Multi-platform config. Targets: {", ".join(platforms)}.",
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
            prompt = self._build_prompt(title, path, purpose, platforms, uses_shaders, shader_path)
            try:
                g = self.llm.generate_source_file(
                    idea=idea, architecture=arch, file_path=path, purpose=purpose,
                    existing_files=committed, ceo_feedback=rework, is_critical=True,
                )
                generated[path] = g.content
                committed.append(path)
            except Exception as e:
                print(f"\u26a0\ufe0f [FlutterFrontendAgent] {path}: {e}. Boilerplate.")
                generated[path] = self._get_boilerplate(path, shader_path, repo_name, platforms)
                committed.append(path)

        context.state.setdefault("flutter_project_files", {})
        context.state["flutter_project_files"].update(generated)
        context.state["committed_files"] = committed
        context.state["flutter_project_type"] = "multi_platform"
        context.state["flutter_platforms"] = platforms

        return AgentResult(
            agent_name=self.name, status="success",
            message=f"Flutter app for {repo_name} targeting {", ".join(platforms)} ({len(generated)} files).",
            data={"files_generated": list(generated.keys()), "platforms": platforms, "uses_shaders": uses_shaders},
        )

    def _build_prompt(self, title, path, purpose, platforms, uses_shaders, shader_path) -> str:
        p = f"Generate Flutter file: {path}\nPurpose: {purpose}\nPlatforms: {", ".join(platforms)}\n"
        p += "Rules: conditional imports (dart.library.io/html), responsive layout, no markdown.\n"
        if uses_shaders and "shader" in path.lower():
            p += f"SHADER: {shader_path}, max 64-80 raymarching steps, uniforms: uTime, uSize\n"
        if "pubspec.yaml" in path:
            p += f"PUBSPEC: Targets: {", ".join(platforms)}. Cross-platform deps only.\n"
        return p


    def _get_boilerplate(self, path: str, shader_path: str, repo_name: str, platforms: list) -> str:
        """Fallback compile-ready boilerplate for multi-platform Flutter."""
        if path == "pubspec.yaml":
            return f"""name: {repo_name}
description: Multi-platform Flutter application.
version: 1.0.0+1
publish_to: 'none'
environment:
  sdk: '>=3.2.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  vector_math: ^2.1.4
flutter:
  uses-material-design: true
  shaders:
    - {shader_path}
"""
        elif path == "lib/main.dart":
            return """import 'package:flutter/material.dart';
import 'app.dart';

void main() => runApp(const MyApp());
"""
        elif path == "lib/app.dart":
            return """import 'package:flutter/material.dart';
import 'shader_canvas.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Multi-Platform',
      theme: ThemeData.dark(),
      home: const Scaffold(body: ShaderCanvas()),
    );
  }
}
"""
        elif path == "lib/shader_controller.dart":
            return """import 'package:flutter/material.dart';

class ShaderUniformController extends ChangeNotifier {
  double _time = 0.0;
  Size _resolution = Size.zero;
  Offset _pointer = Offset.zero;
  double get time => _time;
  Size get resolution => _resolution;
  Offset get pointer => _pointer;
  void updateTime(double t) { _time = t; notifyListeners(); }
  void updateResolution(Size s) { _resolution = s; notifyListeners(); }
  void updatePointer(Offset p) { _pointer = p; notifyListeners(); }
  List<double> getUniforms() => [_time, _resolution.width, _resolution.height, _pointer.dx, _pointer.dy];
}
"""
        elif path == "lib/shader_canvas.dart":
            return """import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'shader_controller.dart';

class ShaderCanvas extends StatefulWidget {
  const ShaderCanvas({super.key});
  @override
  State<ShaderCanvas> createState() => _ShaderCanvasState();
}

class _ShaderCanvasState extends State<ShaderCanvas> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ShaderUniformController _uniforms;
  ui.FragmentShader? _shader;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(days: 365))..repeat();
    _uniforms = ShaderUniformController();
    _loadShader();
  }
  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('assets/shaders/app_shader.frag');
      _shader = program.fragmentShader();
      if (mounted) setState(() {});
    } catch (e) { debugPrint('Shader load error: $e'); }
  }
  @override
  void dispose() { _controller.dispose(); _shader?.dispose(); _uniforms.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _uniforms.updateResolution(Size(constraints.maxWidth, constraints.maxHeight));
      return AnimatedBuilder(animation: _controller, builder: (context, _) {
        _uniforms.updateTime(_controller.lastElapsedDuration!.inMilliseconds / 1000.0);
        if (_shader == null) return const Center(child: CircularProgressIndicator());
        _setUniforms();
        return CustomPaint(size: Size(constraints.maxWidth, constraints.maxHeight), painter: _ShaderPainter(_shader!));
      });
    });
  }
  void _setUniforms() { if (_shader == null) return; final u = _uniforms.getUniforms(); for (int i = 0; i < u.length; i++) { _shader!.setFloat(i, u[i]); } }
}
class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  _ShaderPainter(this.shader);
  @override
  void paint(Canvas canvas, Size size) { canvas.drawRect(Offset.zero & size, Paint()..shader = shader); }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
"""
        elif path == "web/index.html":
            return """<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter App</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
"""
        elif path == "web/manifest.json":
            return """{
  "name": "Flutter App",
  "short_name": "FlutterApp",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2"
}
"""
        return "// Boilerplate fallback"
