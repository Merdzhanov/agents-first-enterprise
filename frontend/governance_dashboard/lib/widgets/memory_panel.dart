import 'package:flutter/material.dart';

import 'gov_helpers.dart';

/// Semantic memory bank with CEO ingestion.
class MemoryPanel extends StatelessWidget {
  const MemoryPanel({
    super.key,
    required this.memoryData,
    required this.sectionLoading,
    required this.topicController,
    required this.contentController,
    required this.onSubmitMemory,
  });

  final Map<String, dynamic> memoryData;
  final bool sectionLoading;
  final TextEditingController topicController;
  final TextEditingController contentController;
  final VoidCallback onSubmitMemory;

  @override
  Widget build(BuildContext context) {
    final memories = (memoryData['memories'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final count = (memoryData['count'] ?? memories.length).toString();
    final tenant = (memoryData['tenant_id'] ?? 'default_enterprise').toString();

    return govLoadingOr(
      sectionLoading,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            govCard(
              title: 'Store Memory Fact',
              children: [
                const SelectableText(
                  'CEO knowledge ingestion — facts stored here are tenant-isolated '
                  'and searchable by the fleet (pgvector / text-embedding-005).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicController,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA)),
                  decoration: govInputDecoration('Topic (e.g. compliance-constraints)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA)),
                  maxLines: 3,
                  decoration: govInputDecoration('Content (the fact itself)'),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: sectionLoading ? null : onSubmitMemory,
                  icon: const Icon(Icons.psychology, size: 16, color: Color(0xFF00354A)),
                  label: const SelectableText('STORE MEMORY',
                      style: TextStyle(
                          color: Color(0xFF00354A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            govCard(
              title: 'Memory Bank — $count record(s) — tenant: $tenant',
              children: [
                if (memories.isEmpty)
                  const SelectableText(
                    'No memories stored yet. Facts are also written automatically '
                    'by the fleet during discovery, CEO decisions and completion.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
                  ),
                for (final m in memories) ..._memoryRow(m),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _memoryRow(Map<String, dynamic> m) {
    return [
      Container(height: 1, color: Colors.white.withAlpha(15)),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(Icons.psychology, size: 14, color: Color(0xFFC084FC)),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              (m['topic'] ?? '?').toString(),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC4E7FF)),
            ),
          ),
          SelectableText(
            (m['tenant_id'] ?? '—').toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF87929A)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SelectableText(
        (m['content'] ?? '').toString(),
        style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFD4E4FA)),
      ),
      const SizedBox(height: 4),
      govKV('created_at', (m['created_at'] ?? '—').toString()),
      const SizedBox(height: 4),
    ];
  }
}
