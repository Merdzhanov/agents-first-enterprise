import 'package:flutter/material.dart';

class PipelineStepInfo {
  final String title;
  final String role;
  final IconData icon;
  final bool isHitl;

  const PipelineStepInfo({
    required this.title,
    required this.role,
    required this.icon,
    this.isHitl = false,
  });
}

const List<PipelineStepInfo> kPipelineSteps = [
  PipelineStepInfo(title: 'Market Scout', role: 'Scout Agent', icon: Icons.radar),
  PipelineStepInfo(title: 'Architecture Options', role: 'Planner Agent', icon: Icons.lightbulb_outline),
  PipelineStepInfo(title: 'Proposal Gate', role: 'CEO Approval', icon: Icons.how_to_reg, isHitl: true),
  PipelineStepInfo(title: 'System Spec', role: 'Architect Agent', icon: Icons.architecture),
  PipelineStepInfo(title: 'Arch Review', role: 'CEO Gate', icon: Icons.rate_review, isHitl: true),
  PipelineStepInfo(title: 'Code Scaffolding', role: 'Lead Dev Agent', icon: Icons.code),
  PipelineStepInfo(title: 'Code Review', role: 'CEO Gate', icon: Icons.verified, isHitl: true),
  PipelineStepInfo(title: 'Compliance Audit', role: 'Security Agent', icon: Icons.shield_outlined),
  PipelineStepInfo(title: 'Market Launch', role: 'Marketing Agent', icon: Icons.campaign_outlined),
  PipelineStepInfo(title: 'Deploy Gate', role: 'CEO Gate', icon: Icons.cloud_upload_outlined, isHitl: true),
];

/// Displays the 10-stage ADK 2.6.2 workflow pipeline with live stage progression,
/// highlighting automated agent execution vs human-in-the-loop governance gates.
class PipelineStepper extends StatelessWidget {
  final String currentStatus;
  final String? activeGate;

  const PipelineStepper({
    super.key,
    required this.currentStatus,
    this.activeGate,
  });

  int _getActiveIndex() {
    final s = currentStatus.toLowerCase();
    final g = (activeGate ?? '').toLowerCase();

    if (s.contains('discover') || s.contains('scout')) return 0;
    if (s.contains('plan') || s.contains('propos')) return 1;
    if (g.contains('proposal') || s.contains('awaiting_ceo_decision')) return 2;
    if (s.contains('architect') && !s.contains('review')) return 3;
    if (g.contains('arch') || s.contains('awaiting_architecture_review')) return 4;
    if (s.contains('code') || s.contains('dev') || s.contains('scaffold')) return 5;
    if (g.contains('code') || s.contains('awaiting_code_review')) return 6;
    if (s.contains('compliance') || s.contains('secur') || s.contains('audit')) return 7;
    if (s.contains('market') || s.contains('launch')) return 8;
    if (g.contains('deploy') || s.contains('awaiting_deployment')) return 9;
    if (s.contains('complete') || s.contains('deployed') || s.contains('provisioned')) return 10;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final activeIdx = _getActiveIndex();
    final isError = currentStatus.toLowerCase().contains('error') || currentStatus.toLowerCase().contains('failed');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF091421),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(12)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(kPipelineSteps.length, (idx) {
            final step = kPipelineSteps[idx];
            final isCompleted = activeIdx > idx;
            final isCurrent = activeIdx == idx;

            final Color stepColor = isError && isCurrent
                ? const Color(0xFFF43F5E)
                : isCompleted
                    ? const Color(0xFF10B981)
                    : isCurrent
                        ? (step.isHitl ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8))
                        : const Color(0xFF475569);

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? stepColor.withAlpha(30)
                        : const Color(0xFF020617).withAlpha(120),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCurrent ? stepColor : Colors.white.withAlpha(12),
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : step.icon,
                        size: 14,
                        color: stepColor,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                  color: isCurrent ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8),
                                ),
                              ),
                              if (step.isHitl) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24).withAlpha(40),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    'HITL',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFBBF24),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            step.role,
                            style: TextStyle(
                              fontSize: 9,
                              color: isCurrent ? stepColor : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (idx < kPipelineSteps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: isCompleted ? const Color(0xFF10B981).withAlpha(180) : const Color(0xFF334155),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
