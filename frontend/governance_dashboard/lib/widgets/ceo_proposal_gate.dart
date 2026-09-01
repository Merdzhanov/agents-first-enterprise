import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Ceoproposalgate extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Ceoproposalgate({super.key, required this.state});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'CEO Proposal Gate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD4E4FA),
              ),
            ),
            const Spacer(),
            if (state._activeOpportunity['url'] != null)
              InkWell(
                onTap: () =>
                    _launchExternalUrl(state._activeOpportunity['url'].toString()),
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
                      Text(
                        'Source: ${(state._activeOpportunity['title'] ?? 'Hackathon').toString()}',
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
        Row(
          children: [
            // Concept A
            Expanded(
              child: _buildProposalCard(
                tag: 'Concept A',
                idea: state._ideaA,
                impactColor: const Color(0xFF34D399),
                gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
                decisionChoice: 'approve_idea_a',
              ),
            ),
            const SizedBox(width: 16),

            // Concept B
            Expanded(
              child: _buildProposalCard(
                tag: 'Concept B',
                idea: state._ideaB,
                impactColor: const Color(0xFFC084FC),
                gradientColors: [const Color(0xFF9333EA), const Color(0xFFD946EF)],
                decisionChoice: 'approve_idea_b',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds one CEO proposal card from a real Planner proposal when available,
  /// falling back to the baseline concepts before the first discovery run.
    required String tag,
    required Map<String, dynamic> idea,
    required Color impactColor,
    required List<Color> gradientColors,
    required String decisionChoice,
  }) {
    final dynamicTitle = (idea['title'] ?? '').toString();
    final dynamicDescription = (idea['summary'] ?? '').toString();
    final dynamicImpact = (idea['impact'] ?? '').toString();
    final dynamicRepo = (idea['repo_name'] ?? '').toString();
    final dynamicChips = _stringList(idea['tech_stack']);
    final hackathonTitle = (idea['hackathon_title'] ?? '').toString();
    final hackathonUrl = (idea['hackathon_url'] ?? '').toString();

    return _buildConceptCard(
      conceptTag: tag,
      title: dynamicTitle,
      description: dynamicDescription,
      chips: dynamicChips,
      targetImpact: dynamicImpact,
      impactColor: impactColor,
      gradientColors: gradientColors,
      btnText: 'Approve $tag',
      onApprove: () => _approveConcept(
        dynamicTitle,
        dynamicRepo,
        decisionChoiceOverride: decisionChoice,
      ),
      hackathonTitle: hackathonTitle.isNotEmpty ? hackathonTitle : null,
      hackathonUrl: hackathonUrl.isNotEmpty ? hackathonUrl : null,
    );
  }

  List<String> _stringList(dynamic value) =>
      (value as List? ?? const []).map((e) => e.toString()).toList();

    required String conceptTag,
    required String title,
    required String description,
    required List<String> chips,
    required String targetImpact,
    required Color impactColor,
    required List<Color> gradientColors,
    required String btnText,
    required VoidCallback onApprove,
    String? hackathonTitle,
    String? hackathonUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(30)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Gradient Stripe
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC4E7FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gradientColors[0].withAlpha(50),
                        ),
                        child: Icon(Icons.bolt, size: 14, color: gradientColors[0]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBDC8D1),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF020617),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF3E484F)),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: Color(0xFFBDC8D1),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  if (hackathonUrl != null && hackathonUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _launchExternalUrl(hackathonUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFF38BDF8).withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events,
                                size: 13, color: Color(0xFF8ED5FF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                (hackathonTitle != null &&
                                        hackathonTitle.isNotEmpty)
                                    ? hackathonTitle
                                    : 'Open hackathon page',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF8ED5FF)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new,
                                size: 12, color: Color(0xFF8ED5FF)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withAlpha(15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TARGET IMPACT',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: Color(0xFF87929A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            targetImpact,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: impactColor,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: state._isLoading ? null : onApprove,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          backgroundColor: gradientColors[0],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(
                          btnText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  
}
