import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Sessionspanel extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Sessionspanel({super.key, required this.state});

    final sessions = (state._sessionsData['sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final count = (state._sessionsData['count'] ?? sessions.length).toString();

    return state._govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          state._govCard(
            title: 'Session Registry — $count record(s)',
            children: [
              const Text(
                'Audit trail of every fleet execution. State is persisted per '
                'session_id with tenant isolation (Cloud SQL RLS in production).',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                const Text(
                  'No sessions recorded yet — trigger a Discovery cycle in the FLEET section.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
                ),
              for (final s in sessions) ..._sessionRow(s),
            ],
          ),
        ],
      ),
    ));
  }

  List<Widget> _sessionRow(Map<String, dynamic> s) {
    final status = (s['status'] ?? 'unknown').toString();
    final color = state._govStatusColor(status);
    final state = s['state'];
    final stateKeys = state is Map ? state.keys.take(6).toList() : const [];
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
            child: Text(
              (s['session_id'] ?? '?').toString(),
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: Color(0xFFC4E7FF)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
              color: color),
          ),
        ],
      ),
      const SizedBox(height: 6),
      state._govKV('current_agent', (s['current_agent'] ?? '—').toString()),
      state._govKV('tenant_id', (s['tenant_id'] ?? '—').toString()),
      state._govKV('updated_at', (s['updated_at'] ?? '—').toString()),
      if (stateKeys.isNotEmpty)
        state._govKV('state_keys', stateKeys.join(', ')),
      const SizedBox(height: 6),
    ];
  }

  // =========================================================
  // MEMORY PANEL — semantic memory bank with CEO ingestion
  // =========================================================
}
