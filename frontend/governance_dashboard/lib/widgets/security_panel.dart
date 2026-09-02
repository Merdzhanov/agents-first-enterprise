import 'package:flutter/material.dart';

import 'gov_helpers.dart';

/// Security & IAM posture panel.
class SecurityPanel extends StatelessWidget {
  const SecurityPanel({
    super.key,
    required this.securityData,
    required this.sectionLoading,
  });

  final Map<String, dynamic> securityData;
  final bool sectionLoading;

  @override
  Widget build(BuildContext context) {
    final tenants = govSafeStringList(securityData['tenants_observed']);
    final gates = govSafeStringList(securityData['human_in_the_loop_gates']);

    return govLoadingOr(
      sectionLoading,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            govCard(
              title: 'Security & IAM Posture',
              children: [
                const SelectableText(
                  'Live view of the controls protecting the fleet: identity, '
                  'isolation, and human oversight gates.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
                ),
                const SizedBox(height: 12),
                govKV('Service-to-Service Auth',
                    (securityData['service_to_service_auth'] ?? '—').toString()),
                govKV('Dart Node Auth Policy',
                    (securityData['dart_node_auth_policy'] ?? '—').toString()),
                govKV('Session Isolation',
                    (securityData['session_isolation'] ?? '—').toString()),
                govKV('Memory Isolation',
                    (securityData['memory_tenant_isolation'] ?? '—').toString()),
                govKV('Skip Safety',
                    (securityData['skip_safety'] ?? '—').toString()),
                govKV('Git Providers',
                    govSafeStringList(securityData['git_providers']).join(', ')),
                govKV('Session Records',
                    (securityData['session_records'] ?? 0).toString()),
                govKV('Memory Records',
                    (securityData['memory_records'] ?? 0).toString()),
                govKV('CORS Policy',
                    (securityData['cors_policy'] ?? '—').toString()),
                const SizedBox(height: 12),
                govChipSection(
                  label: 'TENANTS OBSERVED (RLS KEYS)',
                  items: tenants,
                  borderColor: const Color(0xFF14B8A6).withAlpha(70),
                  textColor: const Color(0xFF14B8A6),
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  'HUMAN-IN-THE-LOOP GATES',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: Color(0xFF87929A)),
                ),
                const SizedBox(height: 6),
                for (final g in gates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user,
                            size: 13, color: Color(0xFF34D399)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            g,
                            style: const TextStyle(
                                fontSize: 12, height: 1.35, color: Color(0xFFD4E4FA)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
