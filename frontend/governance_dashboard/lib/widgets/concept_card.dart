import 'package:flutter/material.dart';
import 'concept_card_helpers.dart';

class ConceptCard extends StatefulWidget {
  const ConceptCard({
    super.key,
    required this.conceptTag,
    required this.title,
    required this.description,
    this.detailedText,
    required this.chips,
    required this.targetImpact,
    required this.impactColor,
    required this.gradientColors,
    required this.btnText,
    this.onApprove,
    this.hackathonTitle,
    this.hackathonUrl,
  });

  final String conceptTag;
  final String title;
  final String description;
  final String? detailedText;
  final List<String> chips;
  final String targetImpact;
  final Color impactColor;
  final List<Color> gradientColors;
  final String btnText;
  final VoidCallback? onApprove;
  final String? hackathonTitle;
  final String? hackathonUrl;

  @override
  State<ConceptCard> createState() => _ConceptCardState();
}

class _ConceptCardState extends State<ConceptCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
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
                  gradient: LinearGradient(colors: widget.gradientColors),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConceptHeader(title: widget.title, gradientColors: widget.gradientColors),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFBDC8D1),
                        height: 1.4,
                      ),
                    ),
                    if (_isExpanded && widget.detailedText != null && widget.detailedText!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(height: 1, color: Colors.white.withAlpha(15)),
                      const SizedBox(height: 12),
                      SelectableText(
                        widget.detailedText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFFBDC8D1).withAlpha(200),
                          height: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (widget.detailedText != null && widget.detailedText!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: InkWell(
                          onTap: () => setState(() => _isExpanded = !_isExpanded),
                          child: Text(
                            _isExpanded ? 'Show Less' : 'Show More...',
                            style: const TextStyle(
                              color: Color(0xFF8ED5FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    ConceptChipsRow(chips: widget.chips),
                    if (widget.hackathonTitle != null && widget.hackathonTitle!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ConceptHackathonLink(title: widget.hackathonTitle!),
                    ],
                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.white.withAlpha(15)),
                    const SizedBox(height: 12),
                    ConceptImpactAndButton(
                      targetImpact: widget.targetImpact,
                      impactColor: widget.impactColor,
                      gradientColors: widget.gradientColors,
                      btnText: widget.btnText,
                      onApprove: widget.onApprove,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
