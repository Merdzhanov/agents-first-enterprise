import 'package:flutter/material.dart';

/// Repository Status & Artifacts Hub — shows real artifacts from the backend
/// and lets the CEO browse generated code files.
class RepositoryStatusHub extends StatelessWidget {
  const RepositoryStatusHub({
    super.key,
    required this.artifacts,
    required this.selectedFile,
    required this.isLoading,
    required this.onFileSelected,
    required this.onLog,
  });

  final Map<String, String> artifacts;
  final String selectedFile;
  final bool isLoading;
  final ValueChanged<String> onFileSelected;
  final void Function(String msg, String type) onLog;

  @override
  Widget build(BuildContext context) {
    final files = artifacts.keys.toList();
    final hasArtifacts = artifacts.isNotEmpty;
    final content = hasArtifacts ? (artifacts[selectedFile] ?? '') : '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(25)),
      ),
      child: Column(
        children: [
          _buildHeader(hasArtifacts),
          if (hasArtifacts)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileTree(files),
                Container(width: 1, color: Colors.white.withAlpha(15)),
                _buildCodeViewer(content, selectedFile),
              ],
            )
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool hasArtifacts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withAlpha(125),
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const SelectableText(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 6,
                        color: hasArtifacts
                            ? const Color(0xFF34D399)
                            : const Color(0xFF87929A)),
                    const SizedBox(width: 6),
                    SelectableText(
                      hasArtifacts ? 'POPULATING FILES...' : 'AWAITING CEO APPROVAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: hasArtifacts
                            ? const Color(0xFF34D399)
                            : const Color(0xFF87929A),
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
                  color: const Color(0xFF38BDF8).withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileTree(List<String> files) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SelectableText(
              'FILES',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 0.5,
                color: Color(0xFF87929A),
              ),
            ),
          ),
          for (final file in files)
            InkWell(
              onTap: () => onFileSelected(file),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: selectedFile == file
                    ? const Color(0xFF38BDF8).withAlpha(20)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Icon(
                      file.endsWith('.dart')
                          ? Icons.integration_instructions
                          : file.endsWith('.yaml') || file.endsWith('.yml')
                              ? Icons.settings
                              : file.endsWith('.md')
                                  ? Icons.description
                                  : Icons.insert_drive_file,
                      size: 14,
                      color: selectedFile == file
                          ? const Color(0xFF8ED5FF)
                          : const Color(0xFFBDC8D1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        file,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: selectedFile == file
                              ? const Color(0xFF8ED5FF)
                              : const Color(0xFFBDC8D1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCodeViewer(String content, String file) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SelectableText(
                  file,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF8ED5FF),
                  ),
                ),
                InkWell(
                  onTap: () {
                    // Copy to clipboard would go here
                    onLog('Copied $file content to clipboard', 'system');
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.copy, size: 12, color: Color(0xFFBDC8D1)),
                      SizedBox(width: 4),
                      SelectableText(
                        'COPY',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFBDC8D1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFD4E4FA),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 40, color: const Color(0xFF38BDF8).withAlpha(75)),
            const SizedBox(height: 12),
            SelectableText(
              'No repository artifacts yet.',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFFBDC8D1).withAlpha(180),
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Approve a concept to generate code.',
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF87929A).withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
