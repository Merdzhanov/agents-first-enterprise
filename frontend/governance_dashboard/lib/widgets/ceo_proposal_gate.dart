import 'package:flutter/material.dart';

import 'concept_card.dart';
import 'gov_helpers.dart';

/// CEO Proposal Gate — presents Concept A / Concept B for approval.
/// Shows the selected hackathon context for aligned proposal generation.
class CeoProposalGate extends StatelessWidget {
  const CeoProposalGate({
    super.key,
    required this.activeOpportunity,
    required this.ideaA,
    required this.ideaB,
    required this.isLoading,
    required this.onApproveConcept,
    required this.isSessionReady,
    required this.onLaunchUrl,
    this.selectedHackathon,
  });

  final Map<String, dynamic> activeOpportunity;
  final Map<String, dynamic> ideaA;
  final Map<String, dynamic> ideaB;
  final bool isLoading;
  final void Function(String conceptName, String defaultRepo,
  final bool isSessionReady;
      {String? decisionChoiceOverride}) onApproveConcept;
  final ValueChanged<String> onLaunchUrl;
  final Map<String, dynamic>? selectedHackathon;

  List<String> _stringList(dynamic value) => govSafeStringList(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SelectableText(
              'CEO Proposal Gate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD4E4FA),
              ),
            ),
            const Spacer(),
            if (activeOpportunity['url'] != null)
              InkWell(
                onTap: () =>
                    onLaunchUrl(activeOpportunity['url'].toString()),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xFF38BDF8).withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events,
                          size: 13, color: Color(0xFF8ED5FF)),
                      const SizedBox(width: 6),
                      SelectableText(
                        'Source: ${(_activeOpportunityTitle)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8ED5FF)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new,
                          size: 12, color: Color(0xFF8ED5FF)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedHackathon != null) _buildSelectedHackathonBanner(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildProposalCard(
                tag: 'Concept A',
                idea: ideaA,
                impactColor: const Color(0xFF34D399),
                gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
                decisionChoice: 'approve_idea_a',
                isReady: isSessionReady, // <-- Pass down
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildProposalCard(
                tag: 'Concept B',
                idea: ideaB,
                impactColor: const Color(0xFFC084FC),
                gradientColors: [const Color(0xFF9333EA), const Color(0xFFD946EF)],
                decisionChoice: 'approve_idea_b',
                isReady: isSessionReady, // <-- Pass down
              ),
            ),
          ],
        ),
      ],
    );
  }

  String get _activeOpportunityTitle =>
      (activeOpportunity['title'] ?? 'Hackathon').toString();

  Widget _buildSelectedHackathonBanner() {
    final title = (selectedHackathon!['title'] ?? '').toString();
    final url = (selectedHackathon!['url'] ?? '').toString();
    final prize = selectedHackathon!['prize_pool'];
    final deadline = (selectedHackathon!['submission_deadline'] ?? '').toString();
    final themes = govThemeNames(selectedHackathon!['themes']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.adjust, size: 14, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              SelectableText(
                'PROPOSALS ALIGNED TO SELECTED HACKATHON',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8ED5FF),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD4E4FA),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.attach_money, size: 11, color: Color(0xFF87929A)),
              const SizedBox(width: 4),
              SelectableText(
                prize is num ? '\$${prize.toInt()}' : '$prize',
                style: const TextStyle(fontSize: 11, color: Color(0xFFBDC8D1)),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today, size: 11, color: Color(0xFF87929A)),
              const SizedBox(width: 4),
              SelectableText(
                deadline,
                style: const TextStyle(fontSize: 11, color: Color(0xFFBDC8D1)),
              ),
            ],
          ),
          if (themes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: themes.take(3).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  t,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF8ED5FF)),
                ),
              )).toList(),
            ),
          ],
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => onLaunchUrl(url),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new, size: 12, color: Color(0xFF38BDF8)),
                  SizedBox(width: 4),
                  SelectableText(
                    'View Hackathon Rules & Requirements',
                    style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProposalCard({
    required String tag,
    required Map<String, dynamic> idea,
    required Color impactColor,
    required List<Color> gradientColors,
    required String decisionChoice,
    required bool isReady,
  }) {
    final dynamicTitle = (idea['title'] ?? '').toString();
    final dynamicDescription = (idea['summary'] ?? '').toString();
    final dynamicImpact = (idea['impact'] ?? '').toString();
    final dynamicRepo = (idea['repo_name'] ?? '').toString();
    final dynamicChips = _stringList(idea['tech_stack']);
    final hackathonTitle = (idea['hackathon_title'] ?? '').toString();
    final hackathonUrl = (idea['hackathon_url'] ?? '').toString();

    return ConceptCard(
      conceptTag: tag,
      title: dynamicTitle,
      description: dynamicDescription,
      chips: dynamicChips,
      targetImpact: dynamicImpact,
      impactColor: impactColor,
      gradientColors: gradientColors,
      btnText: 'Approve $tag',
      onApprove: isLoading || !isReady // <-- Disable if loading OR session not ready
          ? null
          : () => onApproveConcept(
                dynamicTitle,
                dynamicRepo,
                decisionChoiceOverride: decisionChoice,
              ),
      hackathonTitle: hackathonTitle.isNotEmpty ? hackathonTitle : null,
      hackathonUrl: hackathonUrl.isNotEmpty ? hackathonUrl : null,
    );
  }
}
