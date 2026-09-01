import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Securitypanel extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Securitypanel({super.key, required this.state});

    final tenants = (state._securityData['tenants_observed'] as List<dynamic>? ?? [])
        .map((t) => t.toString())
        .toList();
    final gates =
        (state._securityData['human_in_the_loop_gates'] as List<dynamic>? ?? [])
            .map((g) => g.toString())
            .toList();

    return state._govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          state._govCard(
            title: 'Security & IAM Posture',
            children: [
              const Text(
                'Live view of the controls protecting the fleet: identity, '
                'isolation, and human oversight gates.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              state._govKV('Service-to-Service Auth',
                  (state._securityData['service_to_service_auth'] ?? '—').toString()),
              state._govKV('Dart Node Auth Policy',
                  (state._securityData['dart_node_auth_policy'] ?? '—').toString()),
              state._govKV('Session Isolation',
                  (state._securityData['session_isolation'] ?? '—').toString()),
              state._govKV('Memory Isolation',
                  (state._securityData['memory_tenant_isolation'] ?? '—').toString()),
              state._govKV('Skip Safety',
                  (state._securityData['skip_safety'] ?? '—').toString()),
              state._govKV('Git Providers',
                  ((state._securityData['git_providers'] as List<dynamic>? ?? [])
                      .join(', '))),
              state._govKV('Session Records',
                  (state._securityData['session_records'] ?? 0).toString()),
              state._govKV('Memory Records',
                  (state._securityData['memory_records'] ?? 0).toString()),
              state._govKV('CORS Policy',
                  (state._securityData['cors_policy'] ?? '—').toString()),
              const SizedBox(height: 12),
              _govChipSection(
                label: 'TENANTS OBSERVED (RLS KEYS)',
                items: tenants,
                borderColor: const Color(0xFF14B8A6).withAlpha(70),
                textColor: const Color(0xFF14B8A6),
              ),
              const SizedBox(height: 12),
              const Text(
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
                        child: Text(
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
    ));
  }

    required String label,
    required List<String> items,
    required Color borderColor,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 0.8,
              color: Color(0xFF87929A)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map((item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10, color: textColor),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  
}
