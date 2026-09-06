import 'package:flutter/material.dart';

/// Top navigation bar with title, status pill, and action buttons.
class TopNavBar extends StatelessWidget {
  const TopNavBar({
    super.key,
    required this.statusText,
    required this.isLoading,
    required this.onTriggerDiscovery,
    required this.isSubmittingIdea,
    required this.onShowNewIdeaDialog,
    required this.onShowSystemPromptDialog,
  });

  final String statusText;
  final bool isLoading;
  final bool isSubmittingIdea;
  final VoidCallback onTriggerDiscovery;
  final VoidCallback onShowNewIdeaDialog;
  final VoidCallback onShowSystemPromptDialog;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF122131).withAlpha(150),
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const SelectableText(
                'Agent-First Enterprise',
                style: TextStyle(
                  color: Color(0xFF8ED5FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 24),
              const _NavPill(label: 'Fleet Ready'),
              const SizedBox(width: 16),
              const _NavPill(label: 'Python ADK 2.6.2'),
              const SizedBox(width: 16),
              const _NavPill(label: 'Scale-to-Zero'),
              const SizedBox(width: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFF38BDF8).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    SelectableText(
                      statusText,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF8ED5FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : onTriggerDiscovery,
                icon:
                    const Icon(Icons.bolt, size: 18, color: Color(0xFF00354A)),
                label: const SelectableText(
                  'TRIGGER DISCOVERY CYCLE',
                  style: TextStyle(
                    color: Color(0xFF00354A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: (isLoading || isSubmittingIdea)
                    ? null
                    : onShowNewIdeaDialog,
                icon: isSubmittingIdea
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFFBBF24)),
                      )
                    : const Icon(Icons.lightbulb_outline,
                        size: 16, color: Color(0xFFFBBF24)),
                label: const Text(
                  'NEW CEO IDEA',
                  style: TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: const Color(0xFFFBBF24).withAlpha(80)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onShowSystemPromptDialog,
                icon: const Icon(Icons.terminal,
                    size: 16, color: Color(0xFF8ED5FF)),
                label: const Text(
                  'EXECUTE SYSTEM PROMPT',
                  style: TextStyle(
                    color: Color(0xFF8ED5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: const Color(0xFF38BDF8).withAlpha(80)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings,
                    color: Color(0xFFBDC8D1), size: 20),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.account_circle,
                    color: Color(0xFFBDC8D1), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3E484F)),
      ),
      child: SelectableText(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFBDC8D1),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
