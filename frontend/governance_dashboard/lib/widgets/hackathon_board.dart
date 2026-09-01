import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Hackathonboard extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Hackathonboard({super.key, required this.state});

    final items = state._hackathons.take(5).toList();
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
                const Text(
                  'LIVE HACKATHON BOARD — TOP 5',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC4E7FF),
                    letterSpacing: 0.5,
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
                Text(
                  items.isEmpty ? 'AWAITING DISCOVERY' : 'LIVE · DEVPOST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: items.isEmpty
                        ? const Color(0xFF87929A)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Trigger a discovery cycle to scout active competitions from Devpost in real time.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final hackathon = entry.value;
              final url = (hackathon['url'] ?? '').toString();
              final title = (hackathon['title'] ?? 'Untitled hackathon').toString();
              final prize = hackathon['prize_pool'];
              final deadline = (hackathon['submission_deadline'] ?? 'TBA').toString();
              return InkWell(
                onTap: url.isEmpty ? null : () => _launchExternalUrl(url),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: Colors.white.withAlpha(10))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8ED5FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD4E4FA),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      state._boardStat(
                        'PRIZE',
                        prize is num ? '\$${prize.toInt()}' : '$prize',
                      ),
                      const SizedBox(width: 20),
                      state._boardStat('DEADLINE', deadline),
                      const SizedBox(width: 12),
                      const Icon(Icons.open_in_new,
                          size: 14, color: Color(0xFF38BDF8)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  
}
