import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Deterministic lablab.ai hackathon discovery service.
/// Scrapes the live /ai-hackathons page (no public JSON API exists) and
/// normalizes entries to the same shape as DevpostService matches.
class LablabService {
  final String baseUrl;
  final http.Client _client;

  LablabService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'https://lablab.ai',
        _client = client ?? http.Client();

  /// Scrapes active hackathons from lablab.ai/ai-hackathons.
  /// Returns a list of matches in the same shape as DevpostService.
  Future<List<Map<String, dynamic>>> fetchAndScrapeHackathons() async {
    final matches = <Map<String, dynamic>>[];
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/ai-hackathons'),
            headers: {
              'Accept': 'text/html',
              'User-Agent': 'Agents-First-Enterprise-Dart-Node/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        // Each hackathon card is a .card-animation div wrapping one <a> link.
        final cards = document.querySelectorAll('div.card-animation > a');

        for (final card in cards) {
          try {
            final title = card.querySelector('h2')?.text.trim() ?? '';
            final rawUrl = card.attributes['href'] ?? '';
            if (title.isEmpty || rawUrl.isEmpty) continue;

            final absoluteUrl =
                rawUrl.startsWith('http') ? rawUrl : '$baseUrl$rawUrl';

            // Prize lives inside the description paragraph
            // ("$10,000 Prize Pool ($5k cash + $5k in AAI credits)").
            var prizeText = '';
            for (final p in card.querySelectorAll('p')) {
              if (p.text.contains(r'$')) {
                prizeText = p.text;
                break;
              }
            }

            // Dates are rendered inside <time><span>SEP 1 - 30</span></time>.
            final dateText = card.querySelector('time')?.text.trim() ?? '';

            matches.add({
              'id': 'lablab_${Uri.parse(absoluteUrl).pathSegments.last}',
              'title': title,
              'url': absoluteUrl,
              'submission_deadline': dateText,
              'prize_pool': _extractPrize(prizeText),
              'source': 'lablab',
              'eligible_gcp_apis': [
                'Vertex AI',
                'Cloud Run',
                'Firestore',
                'Pub/Sub'
              ],
              'tracks': ['Generative AI', 'Emerging Tech'],
            });
          } catch (e) {
            print('LablabService: failed to parse card - $e');
          }
        }
      } else {
        print(
            'LablabService: HTTP ${response.statusCode} from $baseUrl/ai-hackathons');
      }
    } catch (e) {
      print('LablabService: scrape failed - $e');
    }

    return matches;
  }

  /// Extracts the first dollar amount from free text ("$10,000", "$5k").
  int _extractPrize(String prizeText) {
    final match =
        RegExp(r'\$\s?([\d][\d,\.]*)\s*([kKmM])?').firstMatch(prizeText);
    if (match == null) return 0;
    final digits = (match.group(1) ?? '0').replaceAll(',', '');
    var value = int.tryParse(digits) ?? 0;
    final suffix = match.group(2)?.toLowerCase();
    if (suffix == 'k') value *= 1000;
    if (suffix == 'm') value *= 1000000;
    return value;
  }
}
