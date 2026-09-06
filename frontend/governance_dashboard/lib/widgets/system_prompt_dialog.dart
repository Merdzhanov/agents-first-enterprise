import 'package:flutter/material.dart';

/// Preset complex prompt for fast evaluation of dynamic engine generation.
const String kProcedural3dEnginePreset = '''# SYSTEM PROMPT: Building `agents_procedural_3d` Engine

## 1. PROJECT OVERVIEW & GOAL
You are an expert Flutter, Graphics (GLSL/WASM), and AI Systems Engineer. Your task is to build a standalone, ultra-lightweight procedural 3D graphics and animation engine package named `agents_procedural_3d`.

The engine must eliminate traditional heavy 3D asset pipelines (.gltf, .obj, .mp4, .riv) by rendering dynamic 3D scenes entirely using GLSL Signed Distance Field (SDF) Raymarching fragment shaders compiled to SPIR-V for WebAssembly (WASM), Web, iOS, Android, and Desktop via Flutter's modern Impeller and Skia graphics backends.

## 2. KEY CAPABILITIES REQUIRED
1. Procedural 3D SDF primitives (Sphere, Torus, Box, Gyroid, Mandelbulb fractal).
2. Smooth Boolean Operations (Union, Subtraction, Intersection with polynomial smin).
3. Dynamic Lighting Model (Blinn-Phong, Raymarched Soft Shadows, Screen-space Ambient Occlusion).
4. Camera & Projection System (Interactive Orbit Camera, Perspective Ray Origins/Directions).
5. Flutter Impeller FragmentShader bridge with high-frequency uniform pumping.
6. Zero asset dependencies — pure procedural mathematical generation.''';

/// Modal dialog for submitting arbitrary, complex system prompts directly to the
/// autonomous multi-agent fleet orchestrator.
class SystemPromptDialog extends StatefulWidget {
  final Future<void> Function({
    required String systemPrompt,
    required String gitProvider,
    String? customRepoName,
  }) onSubmit;

  const SystemPromptDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<SystemPromptDialog> createState() => _SystemPromptDialogState();
}

class _SystemPromptDialogState extends State<SystemPromptDialog> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _repoController = TextEditingController();
  String _selectedProvider = 'github';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _promptController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  void _loadPreset(String preset) {
    setState(() {
      _promptController.text = preset;
      if (_repoController.text.trim().isEmpty) {
        _repoController.text = 'agents_procedural_3d';
      }
    });
  }

  Future<void> _handleSubmit() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = 'System prompt cannot be empty.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        systemPrompt: prompt,
        gitProvider: _selectedProvider,
        customRepoName: _repoController.text.trim().isEmpty
            ? null
            : _repoController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1520),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF38BDF8).withAlpha(60)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 860,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.terminal,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          'Execute Custom System Prompt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        SizedBox(height: 2),
                        SelectableText(
                          'Bypasses hackathon scraping and routes directly into multi-agent planning & dynamic code scaffolding.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Controls row: Presets, Provider, Repo Name
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(10)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Preset:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _loadPreset(kProcedural3dEnginePreset),
                    icon: const Icon(Icons.view_in_ar, size: 14, color: Color(0xFFFBBF24)),
                    label: const Text(
                      'Procedural 3D Engine',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFBBF24), fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFFFBBF24).withAlpha(120)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _promptController.clear();
                              _repoController.clear();
                            });
                          },
                    child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ),
                  const Spacer(),
                  const Text('Git:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _selectedProvider,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'github', child: Text('GitHub')),
                      DropdownMenuItem(value: 'gitlab', child: Text('GitLab')),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedProvider = val);
                          },
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _repoController,
                      enabled: !_isSubmitting,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                      decoration: const InputDecoration(
                        labelText: 'Repo Name (optional)',
                        labelStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Prompt text editor
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _promptController,
                  enabled: !_isSubmitting,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFFD4E4FA),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Paste complete system specification prompt here...\n\nExample:\n# SYSTEM PROMPT: Building custom procedural engine\n- Architecture\n- Modules\n- Deliverables',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF43F5E).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFF43F5E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFF43F5E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Footer actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00354A)),
                        )
                      : const Icon(Icons.rocket_launch, size: 16, color: Color(0xFF00354A)),
                  label: Text(
                    _isSubmitting ? 'DISPATCHING FLEET...' : 'EXECUTE SYSTEM PROMPT',
                    style: const TextStyle(
                      color: Color(0xFF00354A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
