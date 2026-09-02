import 'package:flutter/material.dart';

import 'gov_helpers.dart';

/// Full governance registry of fleet sessions.
class SessionsPanel extends StatelessWidget {
  const SessionsPanel({
    super.key,
    required this.sessionsData,
    required this.sectionLoading,
  });

  final Map<String, dynamic> sessionsData;
  final bool sectionLoading;

  @override
  Widget build(BuildContext context) {
    final sessions = govSafeList(sessionsData['sessions'])
        .whereType<Map>()
        .map((s) => govSafeMap(s))
        .toList();
    final count = (sessionsData['count'] ?? sessions.length).toString();

    return govLoadingOr(
      sectionLoading,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            govCard(
              title: 'Session Registry — $count record(s)',
              children: [
                const SelectableText(
                  'Audit trail of every fleet execution. State is persisted per '
                  'session_id with tenant isolation (Cloud SQL RLS in production).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
                ),
                const SizedBox(height: 12),
                if (sessions.isEmpty)
                  const SelectableText(
                    'No sessions recorded yet — trigger a Discovery cycle in the FLEET section.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
                  ),
                for (final s in sessions) ..._sessionRow(s),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sessionRow(Map<String, dynamic> s) {
    final status = (s['status'] ?? 'unknown').toString();
    final color = govStatusColor(status);
    final state = s['state'];
    final stateKeys = state is Map ? state.keys.take(6).toList() : const <dynamic>[];
    return [
      Container(height: 1, color: Colors.white.withAlpha(15)),
      const SizedBox(height: 10),
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              (s['session_id'] ?? '?').toString(),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: Color(0xFFC4E7FF)),
            ),
          ),
          SelectableText(
            status,
            style: TextStyle(
                fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
      const SizedBox(height: 6),
      govKV('current_agent', (s['current_agent'] ?? '—').toString()),
      govKV('tenant_id', (s['tenant_id'] ?? '—').toString()),
      govKV('updated_at', (s['updated_at'] ?? '—').toString()),
      if (stateKeys.isNotEmpty)
        govKV('state_keys', stateKeys.join(', ')),
      const SizedBox(height: 6),
    ];
  }
}
