import 'package:flutter/material.dart';

class ConceptHeader extends StatelessWidget {
  const ConceptHeader({super.key, required this.title, required this.gradientColors});
  final String title;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SelectableText(
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
    );
  }
}

class ConceptChipsRow extends StatelessWidget {
  const ConceptChipsRow({super.key, required this.chips});
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3E484F)),
                ),
                child: SelectableText(
                  c,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFBDC8D1)),
                ),
              ))
          .toList(),
    );
  }
}

class ConceptHackathonLink extends StatelessWidget {
  const ConceptHackathonLink({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          const Icon(Icons.emoji_events, size: 13, color: Color(0xFF8ED5FF)),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8ED5FF)),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.open_in_new, size: 12, color: Color(0xFF8ED5FF)),
        ],
      ),
    );
  }
}

class ConceptImpactAndButton extends StatelessWidget {
  const ConceptImpactAndButton({
    super.key,
    required this.targetImpact,
    required this.impactColor,
    required this.gradientColors,
    required this.btnText,
    required this.onApprove,
  });

  final String targetImpact;
  final Color impactColor;
  final List<Color> gradientColors;
  final String btnText;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SelectableText(
              'TARGET IMPACT',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: Color(0xFF87929A),
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(
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
          onPressed: onApprove,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            backgroundColor: gradientColors[0],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: SelectableText(
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
    );
  }
}
