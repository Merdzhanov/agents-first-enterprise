import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Repositorystatushub extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Repositorystatushub({super.key, required this.state});

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(25)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF020617).withAlpha(125),
              border: Border(
                  bottom: BorderSide(color: Colors.white.withAlpha(15))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'REPOSITORY STATUS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC4E7FF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF10B981).withAlpha(50)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle,
                              size: 6, color: Color(0xFF34D399)),
                          SizedBox(width: 6),
                          Text(
                            'POPULATING FILES...',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withAlpha(75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF273647),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Step 2 of 3',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFBDC8D1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Explorer & Preview
          SizedBox(
            height: 240,
            child: Row(
              children: [
                // File Tree (1/3)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617).withAlpha(75),
                      border: Border(
                          right: BorderSide(
                              color: Colors.white.withAlpha(15))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: state._artifacts.keys.map((filename) {
                        final isSelected = state._selectedFile == filename;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              state._selectedFile = filename;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withAlpha(15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  filename.endsWith('.md')
                                      ? Icons.description
                                      : filename.endsWith('.py')
                                          ? Icons.code
                                          : filename.endsWith('.sh')
                                              ? Icons.terminal
                                              : Icons.account_tree,
                                  size: 14,
                                  color: filename.endsWith('.py')
                                      ? Colors.blueAccent
                                      : filename.endsWith('.sh')
                                          ? Colors.greenAccent
                                          : const Color(0xFFBDC8D1),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    filename,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: isSelected
                                          ? const Color(0xFFC4E7FF)
                                          : const Color(0xFFBDC8D1),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // File Preview (2/3)
                Expanded(
                  flex: 2,
                  child: Container(
                    color: const Color(0xFF020617).withAlpha(125),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.white.withAlpha(15))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                state._selectedFile,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFBDC8D1),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: state._artifacts[state._selectedFile] ?? ''));
                                  state._addLog(
                                      'Copied "$state._selectedFile" to clipboard.',
                                      'system');
                                },
                                child: const Icon(Icons.content_copy,
                                    size: 14, color: Color(0xFFBDC8D1)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              state._artifacts[state._selectedFile] ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFFBDC8D1),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Governance section loaders (honest errors, no mock data)
  // =========================================================
  Future<void> _loadSessions({bool silent = false}) async {
    if (!silent) setState(() => state._sectionLoading = true);
    try {
      final data = await state._api.getSessions(limit: 200);
      if (!mounted) return;
      setState(() => state._sessionsData = data);
    } catch (e) {
      if (!silent) state._addLog('Sessions load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => state._sectionLoading = false);
    }
  }

  Future<void> _loadMemory({bool silent = false}) async {
    if (!silent) setState(() => state._sectionLoading = true);
    try {
      final data = await state._api.getMemories();
      if (!mounted) return;
      setState(() => state._memoryData = data);
    } catch (e) {
      if (!silent) state._addLog('Memory load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => state._sectionLoading = false);
    }
  }

  Future<void> _submitMemory() async {
    final topic = state._memoryTopicController.text.trim();
    final content = state._memoryContentController.text.trim();
    if (topic.isEmpty || content.isEmpty) {
      state._addLog('Memory store skipped: topic and content are required.', 'error');
      return;
    }
    setState(() => state._sectionLoading = true);
    try {
      final res = await state._api.storeMemory(topic: topic, content: content);
      state._memoryTopicController.clear();
      state._memoryContentController.clear();
      state._addLog("Memory stored: ${res['topic']}", 'ceo');
      await _loadMemory(silent: true);
    } catch (e) {
      state._addLog('Memory store failed: $e', 'error');
    } finally {
      if (mounted) setState(() => state._sectionLoading = false);
    }
  }

  Future<void> _loadSecurity() async {
    setState(() => state._sectionLoading = true);
    try {
      final data = await state._api.getSecurityPosture();
      if (!mounted) return;
      setState(() => state._securityData = data);
    } catch (e) {
      state._addLog('Security load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => state._sectionLoading = false);
    }
  }

  Future<void> _loadSystem() async {
    setState(() => state._sectionLoading = true);
    try {
      final data = await state._api.getSystemInfo();
      if (!mounted) return;
      setState(() => state._systemData = data);
    } catch (e) {
      state._addLog('System load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => state._sectionLoading = false);
    }
  }

  // =========================================================
  // Shared governance UI helpers
  // =========================================================
}
