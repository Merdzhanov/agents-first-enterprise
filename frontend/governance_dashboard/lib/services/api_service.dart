import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when the orchestrator backend cannot be reached or responds with
/// an error. The UI surfaces this directly — failures are NEVER masked with
/// fabricated success data.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? 'ApiException: $message' : 'ApiException $statusCode: $message';
}

/// Client for communicating with the Python ADK Cloud Run Orchestrator.
///
/// Contract: every method either returns the backend's real JSON response or
/// throws [ApiException]. There is no offline/mock fallback in this client.
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment(
              'ORCHESTRATOR_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
        _client = client ?? http.Client();

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } catch (e) {
      throw ApiException('Backend unreachable at $baseUrl — $e');
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        'Backend returned HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw ApiException('Backend returned invalid JSON: ${response.body}');
    }
  }

  /// Triggers the autonomous discovery cycle.
  Future<Map<String, dynamic>> triggerDiscovery({
    String sessionId = 'session_governance_001',
  }) async {
    final decoded = await _send(
      () => _client
          .post(
            Uri.parse('$baseUrl/fleet/discovery'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': sessionId, 'raw_feed': {}}),
          )
          .timeout(const Duration(seconds: 30)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/discovery');
    }
    return decoded;
  }

  /// Submits the CEO decision for idea selection, git provider, and repository name.
  Future<Map<String, dynamic>> submitCeoDecision({
    required String sessionId,
    required String decisionChoice,
    String? customPrompt,
    String gitProvider = 'github',
    String? customRepoName,
  }) async {
    final decoded = await _send(
      () => _client
          .post(
            Uri.parse('$baseUrl/fleet/ceo-decision'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_id': sessionId,
              'decision_choice': decisionChoice,
              'custom_prompt': customPrompt,
              'git_provider': gitProvider,
              'custom_repo_name': customRepoName,
            }),
          )
          .timeout(const Duration(seconds: 30)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/ceo-decision');
    }
    return decoded;
  }

  /// Fetches execution trace history for the live telemetry sidebar.
  Future<List<Map<String, dynamic>>> getSessionTraces(String sessionId) async {
    final decoded = await _send(
      () => _client
          .get(Uri.parse('$baseUrl/fleet/session/$sessionId/traces'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! List) {
      throw ApiException('Unexpected response shape from traces endpoint');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Fetches the current session record (status + pipeline state) so the UI can
  /// reflect in real time what the background fleet is doing right now.
  Future<Map<String, dynamic>> getSessionState(String sessionId) async {
    final decoded = await _send(
      () => _client
          .get(Uri.parse('$baseUrl/fleet/session/$sessionId'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from session endpoint');
    }
    return decoded;
  }
}


