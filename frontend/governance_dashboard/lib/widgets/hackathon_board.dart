import 'package:flutter/material.dart';

import 'gov_helpers.dart';

/// Live board of all discovered hackathons, grouped by source tabs.
///
/// Tab layout:
///  * "TOP 10" (default) — best cross-source matches, prize-ranked by the
///    Dart discovery node.
///  * One tab per source (Devpost, Lablab.ai, ...) — every active hackathon
///    from that source, so new discovery platforms plug in automatically.
///
/// Every row deep-links to the competition page, opened in a new browser tab.
/// Supports single-selection — only one hackathon can be selected at a time.
class HackathonBoard extends StatefulWidget {
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
  State<HackathonBoard> createState() => _HackathonBoardState();
}

class _HackathonBoardState extends State<HackathonBoard> {
  static const String _topTab = '__top';
  static const int _topTabLimit = 10;

  String _activeTab = _topTab;

  /// Source keys in first-seen order. Legacy entries without a `source`
  /// field are attributed to Devpost.
  List<String> get _sources {
    final seen = <String>[];
    for (final h in widget.hackathons) {
      final s = (h['source'] ?? 'devpost').toString();
      if (!seen.contains(s)) seen.add(s);
    }
    return seen;
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'devpost':
        return 'Devpost';
      case 'lablab':
        return 'Lablab.ai';
      default:
        if (source.isEmpty) return 'Other';
        return source[0].toUpperCase() + source.substring(1);
    }
  }

  int _countForSource(String source) => widget.hackathons
      .where((h) => (h['source'] ?? 'devpost').toString() == source)
      .length;

  List<Map<String, dynamic>> get _visibleHackathons {
    if (_activeTab == _topTab) {
      // The Dart node already prize-ranks the merged cross-source list.
      return widget.hackathons.take(_topTabLimit).toList();
    }
    return widget.hackathons
        .where((h) => (h['source'] ?? 'devpost').toString() == _activeTab)
        .toList();
  }

  @override
  void didUpdateWidget(covariant HackathonBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new discovery cycle can drop the currently selected source tab.
    if (_activeTab != _topTab && !_sources.contains(_activeTab)) {
      _activeTab = _topTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;
    final visible = _visibleHackathons;
    final badge = widget.hackathons.isEmpty
        ? 'AWAITING DISCOVERY'
        : 'LIVE · ${sources.map(_sourceLabel).join(' + ').toUpperCase()}';

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
                const Icon(Icons.emoji_events,
                    size: 16, color: Color(0xFFFBBF24)),
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
                  '(${widget.hackathons.length} found)',
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
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.hackathons.isEmpty
                        ? const Color(0xFF87929A)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (widget.hackathons.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                'Trigger a discovery cycle to scout active competitions from Devpost & Lablab.ai in real time.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
              ),
            )
          else ...[
            _buildTabBar(sources),
            const SizedBox(height: 4),
            ...visible.map((h) => _buildCard(h)),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(List<String> sources) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton(_topTab),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _buildTabButton(source),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tab) {
    final isActive = _activeTab == tab;
    final label = tab == _topTab
        ? '★ TOP $_topTabLimit'
        : '${_sourceLabel(tab)} (${_countForSource(tab)})';
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? const Color(0xFF38BDF8)
                : const Color(0xFF38BDF8).withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color:
                isActive ? const Color(0xFF00354A) : const Color(0xFF8ED5FF),
          ),
        ),
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
    final isSelected = widget.selectedHackathonId == id;
    final source = (hackathon['source'] ?? 'devpost').toString();
    final rank = _activeTab == _topTab
        ? widget.hackathons.indexOf(hackathon) + 1
        : null;

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
        onTap: url.isEmpty ? null : () => widget.onLaunchUrl(url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (rank != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: SelectableText(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF8ED5FF)
                            : const Color(0xFFD4E4FA),
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
                  _buildDetailChip(
                      Icons.source, _sourceLabel(source)),
                  const SizedBox(width: 8),
                  _buildDetailChip(Icons.attach_money,
                      prize is num ? '\$${prize.toInt()}' : '$prize'),
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
                    const Icon(Icons.business,
                        size: 12, color: Color(0xFF87929A)),
                    const SizedBox(width: 4),
                    SelectableText(
                      organization,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF87929A)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          t,
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF8ED5FF)),
                        ),
                      )).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.open_in_new,
                      size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  SelectableText(
                    source == 'lablab'
                        ? 'View on Lablab.ai'
                        : 'View on Devpost',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF38BDF8)),
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
      onPressed: widget.onHackathonSelected == null
          ? null
          : () =>
              widget.onHackathonSelected!(isSelected ? null : id),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF38BDF8)
            : const Color(0xFF1E293B),
        foregroundColor:
            isSelected ? const Color(0xFF00354A) : const Color(0xFF8ED5FF),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        textStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : const Color(0xFF38BDF8).withAlpha(60),
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
          style:
              const TextStyle(fontSize: 10, color: Color(0xFFBDC8D1)),
        ),
      ],
    );
  }
}
