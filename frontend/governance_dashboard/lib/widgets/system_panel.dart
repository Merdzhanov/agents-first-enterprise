import 'package:flutter/material.dart';

import 'gov_helpers.dart';

/// System introspection panel with agent fleet and scheduled discovery.
class SystemPanel extends StatelessWidget {
  const SystemPanel({
    super.key,
    required this.systemData,
    required this.sectionLoading,
    required this.isRunningScheduledDiscovery,
    required this.onRunScheduledDiscovery,
  });

  final Map<String, dynamic> systemData;
  final bool sectionLoading;
  final bool isRunningScheduledDiscovery;
  final VoidCallback onRunScheduledDiscovery;

  @override
  Widget build(BuildContext context) {
    final agents = (systemData['agents'] as List<dynamic>? ?? [])
        .map((a) => a.toString())
        .toList();

    return govLoadingOr(
      sectionLoading,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            govCard(
              title: 'System Introspection — v${(systemData['version'] ?? '?')}',
              children: [
                const SelectableText(
                  'Architecture of the running orchestrator: engine, agents, '
                  'stores and environment configuration.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
                ),
                const SizedBox(height: 12),
                govKV('Execution Engine',
                    (systemData['execution_engine'] ?? '—').toString()),
                govKV('Default Mode',
                    (systemData['default_execution_mode'] ?? '—').toString()),
                govKV('Session Store',
                    (systemData['session_store'] ?? '—').toString()),
                govKV('Memory Store',
                    (systemData['memory_store'] ?? '—').toString()),
                govKV('Scheduler Interval', () {
                  final mins = systemData['scheduler_interval_minutes'];
                  if (mins == 1440) return '24h (daily)';
                  if (mins is num) return '$mins min';
                  return '—';
                }()),
                govKV('Dart Node URL',
                    (systemData['dart_node_url'] ?? '—').toString()),
                govKV('Vertex AI Mode',
                    (systemData['vertex_ai_mode'] ?? '—').toString()),
                govKV('Cloud Location',
                    (systemData['cloud_location'] ?? '—').toString()),
                const SizedBox(height: 12),
                govChipSection(
                  label: 'AGENT FLEET (${agents.length})',
                  items: agents,
                  borderColor: const Color(0xFF38BDF8).withAlpha(70),
                  textColor: const Color(0xFF7BD0FF),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isRunningScheduledDiscovery
                        ? null
                        : onRunScheduledDiscovery,
                    icon: Icon(
                      Icons.update,
                      size: 16,
                      color: isRunningScheduledDiscovery
                          ? const Color(0xFF3E484F)
                          : const Color(0xFF00354A),
                    ),
                    label: SelectableText(
                      isRunningScheduledDiscovery
                          ? 'SCANNING...'
                          : 'RUN DISCOVERY CYCLE NOW',
                      style: TextStyle(
                        color: isRunningScheduledDiscovery
                            ? const Color(0xFF3E484F)
                            : const Color(0xFF00354A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunningScheduledDiscovery
                          ? const Color(0xFF3E484F)
                          : const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                govKV('HITL Gates',
                    ((systemData['hitl_gates'] as List<dynamic>? ?? [])
                        .join('  •  '))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
