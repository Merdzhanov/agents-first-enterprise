import 'package:flutter/material.dart';

/// Right sidebar: real-time fleet traces with colored left-border by type.
class LogsSidebar extends StatelessWidget {
  const LogsSidebar({
    super.key,
    required this.logs,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> logs;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF051424),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              const SelectableText(
                'REAL-TIME FLEET TRACES',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC4E7FF),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFBDC8D1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Refresh live traces',
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              const SelectableText(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withAlpha(15)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final log = logs[i];
                final type = log['type'];
                final borderColor = type == 'error'
                    ? const Color(0xFFEF4444)
                    : type == 'dart'
                        ? const Color(0xFF14B8A6)
                        : type == 'ceo'
                            ? const Color(0xFFFBBF24)
                            : type == 'success'
                                ? const Color(0xFF34D399)
                                : type == 'skip'
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF38BDF8);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withAlpha(150),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(left: BorderSide(color: borderColor, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        log['time'],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Color(0xFF87929A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        log['msg'],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFD4E4FA),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
