import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Systempanel extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Systempanel({super.key, required this.state});

    final agents = (state._systemData['agents'] as List<dynamic>? ?? [])
        .map((a) => a.toString())
        .toList();

    return state._govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          state._govCard(
            title: 'System Introspection — v${(state._systemData['version'] ?? '?')}',
            children: [
              const Text(
                'Architecture of the running orchestrator: engine, agents, '
                'stores and environment configuration.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              state._govKV('Execution Engine',
                  (state._systemData['execution_engine'] ?? '—').toString()),
              state._govKV('Default Mode',
                  (state._systemData['default_execution_mode'] ?? '—').toString()),
              state._govKV('Session Store',
                  (state._systemData['session_store'] ?? '—').toString()),
              state._govKV('Memory Store',
                  (state._systemData['memory_store'] ?? '—').toString()),
              state._govKV('Scheduler Interval', () {
                final mins = state._systemData['scheduler_interval_minutes'];
                if (mins == 1440) return '24h (daily)';
                if (mins is num) return '$mins min';
                return '—';
              }()),
              state._govKV('Dart Node URL',
                  (state._systemData['dart_node_url'] ?? '—').toString()),
              state._govKV('Vertex AI Mode',
                  (state._systemData['vertex_ai_mode'] ?? '—').toString()),
              state._govKV('Cloud Location',
                  (state._systemData['cloud_location'] ?? '—').toString()),
              const SizedBox(height: 12),
              _govChipSection(
                label: 'AGENT FLEET (${agents.length})',
                items: agents,
                borderColor: const Color(0xFF38BDF8).withAlpha(70),
                textColor: const Color(0xFF7BD0FF),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state._isRunningScheduledDiscovery
                      ? null
                      : _runScheduledDiscovery,
                  icon: Icon(
                    Icons.update,
                    size: 16,
                    color: state._isRunningScheduledDiscovery
                        ? const Color(0xFF3E484F)
                        : const Color(0xFF00354A),
                  ),
                  label: Text(
                    state._isRunningScheduledDiscovery
                        ? 'SCANNING...'
                        : 'RUN DISCOVERY CYCLE NOW',
                    style: TextStyle(
                      color: state._isRunningScheduledDiscovery
                          ? const Color(0xFF3E484F)
                          : const Color(0xFF00354A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state._isRunningScheduledDiscovery
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
              state._govKV('HITL Gates',
                  ((state._systemData['hitl_gates'] as List<dynamic>? ?? [])
                      .join('  •  '))),
            ],
          ),
        ],
      ),
    ));
  
}
