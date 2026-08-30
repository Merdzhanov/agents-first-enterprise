/// High-speed deterministic filtering and normalization of raw hackathon JSON data.
class BriefParserService {
  /// Filters raw opportunities based on criteria without LLM token overhead.
  Map<String, dynamic> parseAndFilterOpportunities(Map<String, dynamic> payload) {
    final List<dynamic> rawHackathons = payload['hackathons'] ?? [];
    final int minPrize = payload['min_prize_pool'] ?? 1000;
    final bool requireOnline = payload['require_online'] ?? true;

    final filtered = <Map<String, dynamic>>[];

    for (final item in rawHackathons) {
      if (item is! Map<String, dynamic>) continue;

      final bool isOnline = item['is_online'] ?? false;
      final int prizePool = (item['prize_pool'] is num) ? (item['prize_pool'] as num).toInt() : 0;

      if (requireOnline && !isOnline) continue;
      if (prizePool < minPrize) continue;

      filtered.add({
        'id': item['id'] ?? 'unknown',
        'title': item['title'] ?? 'Untitled Hackathon',
        'deadline': item['submission_deadline'] ?? '',
        'prize_pool': prizePool,
        'rules_url': item['rules_url'] ?? '',
        'eligible_gcp_apis': item['eligible_apis'] ?? ['Vertex AI', 'Cloud Run', 'Firestore'],
        'tracks': item['tracks'] ?? ['Enterprise Multi-Agent', 'Agent-First Systems'],
      });
    }

    return {
      'status': 'success',
      'total_evaluated': rawHackathons.length,
      'filtered_count': filtered.length,
      'matches': filtered,
      'processed_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
