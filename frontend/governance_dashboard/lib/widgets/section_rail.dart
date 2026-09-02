import 'package:flutter/material.dart';

/// Left governance rail: Fleet / Sessions / Memory / Security / System.
class SectionRail extends StatelessWidget {
  const SectionRail({
    super.key,
    required this.activeSection,
    required this.onSectionSelected,
  });

  final String activeSection;
  final ValueChanged<String> onSectionSelected;

  static const List<(String, IconData, String)> sections = [
    ('fleet', Icons.hub, 'FLEET'),
    ('sessions', Icons.history, 'SESSIONS'),
    ('memory', Icons.psychology, 'MEMORY'),
    ('security', Icons.shield_outlined, 'SECURITY'),
    ('system', Icons.dns, 'SYSTEM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: const Color(0xFF051424),
        border: Border(right: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          for (final s in sections)
            InkWell(
              onTap: () => onSectionSelected(s.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: activeSection == s.$1
                      ? const Color(0xFF38BDF8).withAlpha(30)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: activeSection == s.$1
                          ? const Color(0xFF38BDF8)
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      s.$2,
                      size: 20,
                      color: activeSection == s.$1
                          ? const Color(0xFF8ED5FF)
                          : const Color(0xFFBDC8D1),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      s.$3,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        fontWeight: activeSection == s.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: activeSection == s.$1
                            ? const Color(0xFFC4E7FF)
                            : const Color(0xFFBDC8D1),
                      ),
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
