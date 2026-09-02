import 'package:flutter/material.dart';
import 'concept_card_helpers.dart';

/// A reusable concept / proposal card with approve button.
class ConceptCard extends StatelessWidget {
  const ConceptCard({
    super.key,
    required this.conceptTag,
    required this.title,
    required this.description,
    required this.chips,
    required this.targetImpact,
    required this.impactColor,
    required this.gradientColors,
    required this.btnText,
    required this.onApprove,
    this.hackathonTitle,
    this.hackathonUrl,
  });

  final String conceptTag;
  final String title;
  final String description;
  final List<String> chips;
  final String targetImpact;
  final Color impactColor;
  final List<Color> gradientColors;
  final String btnText;
  final VoidCallback? onApprove;
  final String? hackathonTitle;
  final String? hackathonUrl;

  @override
  Widget build(BuildContext context) {
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
                  ConceptHeader(title: title, gradientColors: gradientColors),
                  const SizedBox(height: 8),
                  SelectableText(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBDC8D1),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConceptChipsRow(chips: chips),
                  if (hackathonTitle != null && hackathonTitle!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ConceptHackathonLink(title: hackathonTitle!),
                  ],
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withAlpha(15)),
                  const SizedBox(height: 12),
                  ConceptImpactAndButton(
                    targetImpact: targetImpact,
                    impactColor: impactColor,
                    gradientColors: gradientColors,
                    btnText: btnText,
                    onApprove: onApprove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
