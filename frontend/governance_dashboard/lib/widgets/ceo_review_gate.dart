import 'package:flutter/material.dart';

class CeoReviewGate extends StatelessWidget {
  final Map<String, dynamic> pendingData;
  final bool isLoading;
  final Function(String decision, String feedback) onDecision;

  const CeoReviewGate({
    super.key,
    required this.pendingData,
    required this.isLoading,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final prompt = pendingData['prompt']?.toString() ?? 'Review required';
    final options = pendingData['options'] as List<dynamic>? ?? [];
    final metadata = pendingData['metadata'] as Map<String, dynamic>? ?? {};
    final gate = metadata['gate']?.toString() ?? 'unknown';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(gate),
          const SizedBox(height: 12),
          _buildPrompt(prompt),
          const SizedBox(height: 16),
          _buildGateContent(gate, metadata),
          const SizedBox(height: 16),
          _buildOptions(options),
        ],
      ),
    );
  }

  Widget _buildHeader(String gate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withAlpha(125),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.rate_review, size: 16, color: Color(0xFF8ED5FF)),
          const SizedBox(width: 8),
          SelectableText(
            gate.toUpperCase().replaceAll('_', ' '),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC4E7FF),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompt(String prompt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SelectableText(
        prompt,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFD4E4FA),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildGateContent(String gate, Map<String, dynamic> metadata) {
    if (gate == 'architecture_review') {
      final arch = metadata['architecture'] as Map<String, dynamic>? ?? {};
      return _buildInfoBox('PROPOSED ARCHITECTURE', [
        _buildInfoRow('Title', arch['title']?.toString() ?? 'Untitled'),
        _buildInfoRow('Compute', arch['compute_target']?.toString() ?? 'n/a'),
      ]);
    }
    if (gate == 'deployment_review') {
      final dep = metadata['deployment'] as Map<String, dynamic>? ?? {};
      return _buildInfoBox('DEPLOYMENT STATUS', [
        _buildInfoRow('Status', dep['status']?.toString() ?? 'pending'),
      ]);
    }
    return _buildInfoBox('DETAILS', [
      _buildInfoRow('Gate', gate),
      ...metadata.entries.map((e) => _buildInfoRow(e.key, e.value.toString())),
    ]);
  }

  Widget _buildInfoBox(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF020617).withAlpha(100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF38BDF8).withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8ED5FF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 11, color: Color(0xFF87929A)),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 11, color: Color(0xFFD4E4FA)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(List<dynamic> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: options.map((opt) {
          final value = opt['value']?.toString() ?? '';
          final label = opt['label']?.toString() ?? value;
          final isApprove = value.contains('approve');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => onDecision(value, ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF00354A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(label),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
