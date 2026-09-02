import 'package:flutter/material.dart';

/// Custom directive input + Skip Implementation button row.
/// Features an expandable text field with full-screen editor for long prompts.
class CustomAndSkipRow extends StatefulWidget {
  const CustomAndSkipRow({
    super.key,
    required this.customDirectiveController,
    required this.onSubmitCustomDirective,
    required this.onSkipImplementation,
  });

  final TextEditingController customDirectiveController;
  final VoidCallback onSubmitCustomDirective;
  final VoidCallback onSkipImplementation;

  @override
  State<CustomAndSkipRow> createState() => _CustomAndSkipRowState();
}

class _CustomAndSkipRowState extends State<CustomAndSkipRow> {
  bool _isExpanded = false;

  void _openFullScreenEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenEditor(
          controller: widget.customDirectiveController,
          onSubmit: widget.onSubmitCustomDirective,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF3E484F)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.customDirectiveController,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFD4E4FA)),
                    maxLines: _isExpanded ? 8 : 1,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Enter custom prototype directive...',
                      hintStyle:
                          const TextStyle(fontSize: 13, color: Color(0xFF87929A)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: InputBorder.none,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() => _isExpanded = !_isExpanded);
                            },
                            icon: Icon(
                              _isExpanded ? Icons.unfold_less : Icons.unfold_more,
                              color: const Color(0xFF87929A),
                              size: 18,
                            ),
                            tooltip: _isExpanded ? 'Collapse' : 'Expand',
                          ),
                          IconButton(
                            onPressed: _openFullScreenEditor,
                            icon: const Icon(Icons.fullscreen,
                                color: Color(0xFF87929A), size: 18),
                            tooltip: 'Open full-screen editor',
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => widget.onSubmitCustomDirective(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: IconButton(
                    onPressed: widget.onSubmitCustomDirective,
                    icon: const Icon(Icons.arrow_forward,
                        color: Color(0xFF38BDF8), size: 20),
                    tooltip: 'Submit directive',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: widget.onSkipImplementation,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF93000A).withAlpha(50),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFFFFB4AB).withAlpha(75)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Color(0xFFFFB4AB), size: 16),
                SizedBox(width: 8),
                Text(
                  'SKIP IMPLEMENTATION',
                  style: TextStyle(
                    color: Color(0xFFFFB4AB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen editor for long custom directives.
class _FullScreenEditor extends StatefulWidget {
  const _FullScreenEditor({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  State<_FullScreenEditor> createState() => _FullScreenEditorState();
}

class _FullScreenEditorState extends State<_FullScreenEditor> {
  late TextEditingController _localController;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _localController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    widget.controller.text = _localController.text;
    Navigator.of(context).pop();
  }

  void _submit() {
    widget.controller.text = _localController.text;
    widget.onSubmit();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF122131),
        leading: IconButton(
          onPressed: _saveAndClose,
          icon: const Icon(Icons.close, color: Color(0xFFBDC8D1)),
        ),
        title: const Text(
          'Custom Prototype Directive',
          style: TextStyle(color: Color(0xFF8ED5FF), fontSize: 16),
        ),
        actions: [
          TextButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send, color: Color(0xFF38BDF8), size: 18),
            label: const Text(
              'SUBMIT',
              style: TextStyle(
                color: Color(0xFF38BDF8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF020617),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enter your detailed prototype directive. Include architecture, requirements, and constraints.',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFBDC8D1).withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _localController,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFD4E4FA),
                height: 1.5,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Enter your directive here...\n\n'
                    '## PROJECT OVERVIEW\n'
                    'Build a standalone engine...\n\n'
                    '## ARCHITECTURE\n'
                    '- lib/src/controllers/\n'
                    '- lib/src/models/\n\n'
                    '## CONSTRAINTS\n'
                    '1. Zero external dependencies\n'
                    '2. WASM compatible',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3E484F),
                  height: 1.5,
                ),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
