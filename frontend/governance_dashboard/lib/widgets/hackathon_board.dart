import 'package:flutter/material.dart';

import 'gov_helpers.dart';

/// Live board of all discovered hackathons. Every row deep-links to
/// the competition page, opened in a new browser tab.
/// Supports single-selection — only one hackathon can be selected at a time.
class HackathonBoard extends StatelessWidget {
  const HackathonBoard({
    super.key,
    required this.hackathons,
    required this.onLaunchUrl,
    this.selectedHackathonId,
    this.onHackathonSelected,
  });

  final List<Map<String, dynamic>> hackathons;
  final ValueChanged<String> onLaunchUrl;
  final String? selectedHackathonId;
  final ValueChanged<String?>? onHackathonSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, size: 16, color: Color(0xFFFBBF24)),
                const SizedBox(width: 8),
                const SelectableText(
                  'LIVE HACKATHON BOARD',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC4E7FF),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                SelectableText(
                  '(${hackathons.length} found)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF87929A),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 6),
                SelectableText(
                  hackathons.isEmpty ? 'AWAITING DISCOVERY' : 'LIVE · DEVPOST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hackathons.isEmpty
                        ? const Color(0xFF87929A)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (hackathons.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                'Trigger a discovery cycle to scout active competitions from Devpost in real time.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
              ),
            )
          else
            ...hackathons.map((h) => _buildCard(h)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> hackathon) {
    final id = (hackathon['id'] ?? '').toString();
    final url = (hackathon['url'] ?? '').toString();
    final title = (hackathon['title'] ?? 'Untitled hackathon').toString();
    final prize = hackathon['prize_pool'];
    final deadline = (hackathon['submission_deadline'] ?? 'TBA').toString();
    final organization = (hackathon['organization_name'] ?? '').toString();
    final registrations = (hackathon['registrations_count'] ?? 0).toString();
    final themes = govThemeNames(hackathon['themes']);
    final isSelected = selectedHackathonId == id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF38BDF8).withAlpha(15)
            : const Color(0xFF1E293B).withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF38BDF8)
              : const Color(0xFF38BDF8).withAlpha(25),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: url.isEmpty ? null : () => onLaunchUrl(url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? const Color(0xFF8ED5FF) : const Color(0xFFD4E4FA),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSelectButton(id, isSelected),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildDetailChip(Icons.attach_money, prize is num ? '\$${prize.toInt()}' : '$prize'),
                  const SizedBox(width: 8),
                  _buildDetailChip(Icons.calendar_today, deadline),
                  const SizedBox(width: 8),
                  _buildDetailChip(Icons.people, '$registrations registered'),
                ],
              ),
              if (organization.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.business, size: 12, color: Color(0xFF87929A)),
                    const SizedBox(width: 4),
                    SelectableText(
                      organization,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF87929A)),
                    ),
                  ],
                ),
              ],
              if (themes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: themes.take(4).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withAlpha(15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      t,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF8ED5FF)),
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.open_in_new, size: 12, color: Color(0xFF38BDF8)),
                  SizedBox(width: 4),
                  SelectableText(
                    'View on Devpost',
                    style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectButton(String id, bool isSelected) {
    return ElevatedButton(
      onPressed: onHackathonSelected == null
          ? null
          : () => onHackathonSelected!(isSelected ? null : id),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
        foregroundColor: isSelected ? const Color(0xFF00354A) : const Color(0xFF8ED5FF),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF38BDF8).withAlpha(60),
          ),
        ),
      ),
      child: Text(isSelected ? '✓ SELECTED' : 'SELECT'),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF87929A)),
        const SizedBox(width: 3),
        SelectableText(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFFBDC8D1)),
        ),
      ],
    );
  }
}
