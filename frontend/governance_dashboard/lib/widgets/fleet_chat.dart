import 'package:flutter/material.dart';

class FleetChat extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> pendingGate;
  final bool isLoading;
  final void Function(String decision, String feedback) onGateDecision;
  final void Function(String text) onSend;

  const FleetChat({
    super.key,
    required this.messages,
    required this.pendingGate,
    required this.isLoading,
    required this.onGateDecision,
    required this.onSend,
  });

  @override
  State<FleetChat> createState() => _FleetChatState();
}

class _FleetChatState extends State<FleetChat> {
  final _input = TextEditingController();
  final _feedback = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF051424),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.forum, color: Color(0xFF38BDF8), size: 18),
            SizedBox(width: 8),
            Text('CEO CONVERSATION',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC4E7FF),
                    letterSpacing: 0.5)),
          ]),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...widget.messages.reversed.map(_bubble),
              if (widget.pendingGate.isNotEmpty) ...[
                const SizedBox(height: 8),
                _gateCard(widget.pendingGate),
              ],
            ],
          ),
        ),
        _inputBar(),
      ]),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final type = (m['type'] ?? 'system').toString();
    final isCeo = type == 'ceo';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isCeo ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          SelectableText((m['time'] ?? '').toString(),
              style: const TextStyle(fontSize: 9, color: Color(0xFF87929A))),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCeo
                  ? const Color(0xFF1E3A5F)
                  : type == 'architecture'
                      ? const Color(0xFF172E2A)
                      : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withAlpha(12)),
            ),
            child: SelectableText((m['msg'] ?? '').toString(),
                style: const TextStyle(
                    fontSize: 12, height: 1.45, color: Color(0xFFD4E4FA))),
          ),
        ],
      ),
    );
  }

  Widget _gateCard(Map<String, dynamic> gate) {
    final meta = gate['metadata'] as Map<String, dynamic>? ?? {};
    final arch = meta['architecture'] as Map<String, dynamic>? ?? {};
    final options = gate['options'] as List<dynamic>? ?? [];
    final comps = (arch['components'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(70)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(
          (meta['gate'] ?? 'gate').toString().toUpperCase().replaceAll('_', ' '),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC4E7FF),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        SelectableText(gate['prompt']?.toString() ?? 'Review required',
            style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA))),
        if (arch.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            'Title: ${arch['title'] ?? 'n/a'}\nCompute: ${arch['compute_target'] ?? 'n/a'}\nComponents: $comps',
            style: const TextStyle(fontSize: 11, color: Color(0xFFA7F3D0)),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _feedback,
          style: const TextStyle(fontSize: 12, color: Color(0xFFD4E4FA)),
          decoration: const InputDecoration(
            hintText: 'Add feedback / instructions (optional)…',
            hintStyle: TextStyle(color: Color(0xFF87929A), fontSize: 12),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final value = opt['value']?.toString() ?? '';
            return ElevatedButton(
              onPressed: widget.isLoading
                  ? null
                  : () {
                      widget.onGateDecision(value, _feedback.text.trim());
                      _feedback.clear();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: value.contains('approve')
                    ? const Color(0xFF10B981)
                    : const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF00354A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(opt['label']?.toString() ?? value,
                  style: const TextStyle(fontSize: 11)),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1520),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(12))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            style: const TextStyle(fontSize: 12, color: Color(0xFFD4E4FA)),
            decoration: const InputDecoration(
              hintText: 'Message the fleet / ask a question…',
              hintStyle: TextStyle(color: Color(0xFF87929A), fontSize: 12),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _send,
          icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
          tooltip: 'Send',
        ),
      ]),
    );
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _input.clear();
  }
}