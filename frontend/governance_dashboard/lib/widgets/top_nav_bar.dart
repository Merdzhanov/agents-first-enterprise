import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Topnavbar extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Topnavbar({super.key, required this.state});

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF122131).withAlpha(150),
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Agent-First Enterprise',
                style: TextStyle(
                  color: Color(0xFF8ED5FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 24),
              state._buildNavPill('Fleet Ready'),
              const SizedBox(width: 16),
              state._buildNavPill('Python ADK 2.0'),
              const SizedBox(width: 16),
              state._buildNavPill('Scale-to-Zero'),
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF38BDF8).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      state._statusText,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8ED5FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: state._isLoading ? null : state._triggerDiscovery,
                icon: const Icon(Icons.bolt, size: 18, color: Color(0xFF00354A)),
                label: const Text(
                  'TRIGGER DISCOVERY CYCLE',
                  style: TextStyle(
                    color: Color(0xFF00354A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: state._isSubmittingIdea ? null : _showNewIdeaDialog,
                icon: Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: state._isSubmittingIdea
                      ? const Color(0xFF3E484F)
                      : const Color(0xFFFBBF24),
                ),
                label: Text(
                  state._isSubmittingIdea ? 'SUBMITTING...' : '＋ NEW IDEA',
                  style: TextStyle(
                    color: state._isSubmittingIdea
                        ? const Color(0xFF3E484F)
                        : const Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(
                    color: state._isSubmittingIdea
                        ? const Color(0xFF3E484F)
                        : const Color(0xFFFBBF24).withAlpha(180),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings, color: Color(0xFFBDC8D1), size: 20),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.account_circle,
                    color: Color(0xFFBDC8D1), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  
}
