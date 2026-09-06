import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'concept_card.dart';
import 'gov_helpers.dart';

class FleetChat extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> pendingGate;
  final bool isLoading;
  final void Function(String decision, String feedback) onGateDecision;
  final void Function(String text) onSend;
  final Map<String, dynamic> activeOpportunity;
  final Map<String, dynamic> ideaA;
  final Map<String, dynamic> ideaB;
  final Map<String, dynamic>? selectedHackathon;
  final void Function(String conceptName, String defaultRepo, {String? decisionChoiceOverride, String? feedback}) onApproveConcept;
  final ValueChanged<String> onLaunchUrl;

  const FleetChat({
    super.key,
    required this.messages,
    required this.pendingGate,
    required this.isLoading,
    required this.onGateDecision,
    required this.onSend,
    required this.activeOpportunity,
    required this.ideaA,
    required this.ideaB,
    this.selectedHackathon,
    required this.onApproveConcept,
    required this.onLaunchUrl,
  });

  @override
  State<FleetChat> createState() => _FleetChatState();
}

class _FleetChatState extends State<FleetChat> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _input.clear();
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
            Text('CEO CONVERSATION & WORKFLOW STREAM',
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
    final stage = (meta['stage'] ?? '').toString();
    final isProposalGate = widget.ideaA.isNotEmpty;

    if (isProposalGate) {
      return _buildInlineProposalGate(gate, meta);
    }

    return _buildStandardGateCard(gate, meta);
  }

  Widget _buildInlineProposalGate(Map<String, dynamic> gate, Map<String, dynamic> meta) {
    final opp = widget.selectedHackathon ?? widget.activeOpportunity;
    final oppTitle = (opp['title'] ?? '').toString();
    final oppUrl = (opp['url'] ?? '').toString();
    final prize = opp['prize_pool'];
    final deadline = (opp['submission_deadline'] ?? '').toString();
    final themes = govThemeNames(opp['themes']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.how_to_reg, size: 16, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 8),
              const SelectableText(
                'CEO PROPOSAL GATE — SELECT ARCHITECTURAL DIRECTION',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC4E7FF),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            gate['prompt']?.toString() ??
                'Discovery phase complete. Please review the proposed implementation concepts below.',
            style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA)),
          ),
          if (oppTitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617).withAlpha(150),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8).withAlpha(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, size: 14, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(
                          oppTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD4E4FA),
                          ),
                        ),
                      ),
                      if (oppUrl.isNotEmpty)
                        InkWell(
                          onTap: () => widget.onLaunchUrl(oppUrl),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Rules', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                              SizedBox(width: 3),
                              Icon(Icons.open_in_new, size: 11, color: Color(0xFF38BDF8)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (prize != null || deadline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (prize != null) ...[
                          const Icon(Icons.attach_money, size: 11, color: Color(0xFF87929A)),
                          const SizedBox(width: 2),
                          SelectableText(
                            prize is num ? '\$${prize.toInt()}' : '$prize',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFBDC8D1)),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (deadline.isNotEmpty) ...[
                          const Icon(Icons.calendar_today, size: 11, color: Color(0xFF87929A)),
                          const SizedBox(width: 4),
                          SelectableText(
                            deadline,
                            style: const TextStyle(fontSize: 11, color: Color(0xFFBDC8D1)),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (themes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: themes.take(4).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 9, color: Color(0xFF8ED5FF))),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Proposal Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final cardA = _buildCard(
                tag: 'Concept A',
                idea: widget.ideaA,
                impactColor: const Color(0xFF34D399),
                gradientColors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                decisionChoice: 'approve_idea_a',
              );
              final cardB = _buildCard(
                tag: 'Concept B',
                idea: widget.ideaB,
                impactColor: const Color(0xFFC084FC),
                gradientColors: const [Color(0xFF9333EA), Color(0xFFD946EF)],
                decisionChoice: 'approve_idea_b',
              );

              if (isNarrow) {
                return Column(
                  children: [
                    cardA,
                    const SizedBox(height: 12),
                    cardB,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cardA),
                  const SizedBox(width: 14),
                  Expanded(child: cardB),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String tag,
    required Map<String, dynamic> idea,
    required Color impactColor,
    required List<Color> gradientColors,
    required String decisionChoice,
  }) {
    final title = (idea['title'] ?? '').toString();
    final description = (idea['summary'] ?? '').toString();
    final impact = (idea['impact'] ?? '').toString();
    final repo = (idea['repo_name'] ?? '').toString();
    final chips = govSafeStringList(idea['tech_stack']);
    final hackathonTitle = (idea['hackathon_title'] ?? '').toString();
    final hackathonUrl = (idea['hackathon_url'] ?? '').toString();

    final detailedText = (idea['detailed_prompt'] ?? '').toString();

    return ConceptCard(
      conceptTag: tag,
      title: title,
      description: description,
      detailedText: detailedText,
      chips: chips,
      targetImpact: impact,
      impactColor: impactColor,
      gradientColors: gradientColors,
      btnText: 'Approve $tag',
      onApprove: widget.isLoading
          ? null
          : () {
              widget.onApproveConcept(
                title,
                repo,
                decisionChoiceOverride: decisionChoice,
                feedback: _input.text.trim(),
              );
              _input.clear();
            },
      hackathonTitle: hackathonTitle.isNotEmpty ? hackathonTitle : null,
      hackathonUrl: hackathonUrl.isNotEmpty ? hackathonUrl : null,
    );
  }

  Widget _buildStandardGateCard(Map<String, dynamic> gate, Map<String, dynamic> meta) {
    final arch = meta['architecture'] as Map<String, dynamic>? ?? {};
    final rawOptions = gate['options'] as List<dynamic>? ?? [];
    // Custom idea and skip buttons are not needed per user specification
    final options = rawOptions.where((opt) {
      final val = (opt['value'] ?? opt['id'] ?? '').toString();
      return val != 'custom_idea' && val != 'skip_implementation';
    }).toList();
    final comps = (arch['components'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            (meta['gate'] ?? 'gate').toString().toUpperCase().replaceAll('_', ' '),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC4E7FF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            gate['prompt']?.toString() ?? 'Review required',
            style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA)),
          ),
          if (arch.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Title: ${arch['title'] ?? 'n/a'}\nCompute: ${arch['compute_target'] ?? 'n/a'}\nComponents: $comps',
              style: const TextStyle(fontSize: 11, color: Color(0xFFA7F3D0)),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: options.map((opt) {
              final value = opt['value']?.toString() ?? opt['id']?.toString() ?? '';
              final label = opt['label']?.toString() ?? opt['title']?.toString() ?? value;
              final isApprove = value.contains('approve') || value.contains('confirm');
              return ElevatedButton(
                onPressed: widget.isLoading ? null : () => widget.onGateDecision(value, ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF00354A),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1520),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 52,
                maxHeight: 180,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8).withAlpha(50)),
              ),
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter, control: true): _send,
                  const SingleActivator(LogicalKeyboardKey.enter, meta: true): _send,
                },
                child: Scrollbar(
                  child: TextField(
                    controller: _input,
                    minLines: 2,
                    maxLines: 7,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFFD4E4FA),
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Enter directive, complex prompt, or feedback for the fleet (multiline supported)...\nPress Send or ⌘+Enter to submit.',
                      hintStyle: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF00354A),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00354A)),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_upward, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'SEND',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}