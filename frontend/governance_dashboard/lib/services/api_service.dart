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
///
/// Authentication: when [authAudience] is set, every request includes a
/// Google-signed OIDC ID token in the Authorization header. This is required
/// when the Cloud Run service is configured with "Require authentication".
class ApiService {
  final String baseUrl;
  final String? authAudience;
  final http.Client _client;

  ApiService({
    String? baseUrl,
    String? authAudience,
    http.Client? client,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment(
              'ORCHESTRATOR_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
        authAudience = authAudience ?? const String.fromEnvironment(
              'ORCHESTRATOR_AUDIENCE',
              defaultValue: '',
            ).nullIfEmpty,
        _client = client ?? http.Client();

  /// Fetches a Google-signed OIDC ID token targeting [audience].
  ///
  /// On GCP (Cloud Run, GCE, Cloud Functions) this hits the metadata server.
  /// Returns null when no audience is configured or when running outside GCP
  /// (local dev against http://127.0.0.1:8000).
  Future<String?> _fetchOidcToken(String audience) async {
    final uri = Uri.parse(
      'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=$audience',
    );
    try {
      final resp = await _client
          .get(uri, headers: {'Metadata-Flavor': 'Google'})
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        return resp.body;
      }
    } catch (_) {
      // Not running on GCP — fall through to null.
    }
    return null;
  }

  /// Returns headers for a request, attaching an OIDC token when configured.
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authAudience != null && authAudience!.isNotEmpty) {
      final token = await _fetchOidcToken(authAudience!);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

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
  /// Pass [rawFeed] to seed the scout with specific hackathon data.
  Future<Map<String, dynamic>> triggerDiscovery({
    String sessionId = 'session_governance_001',
    Map<String, dynamic>? rawFeed,
  }) async {
    final decoded = await _send(
      () async => _client
          .post(
            Uri.parse('$baseUrl/fleet/discovery'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'session_id': sessionId,
              'raw_feed': rawFeed ?? {},
            }),
          )
          .timeout(const Duration(seconds: 180)),
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
      () async => _client
          .post(
            Uri.parse('$baseUrl/fleet/ceo-decision'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'session_id': sessionId,
              'decision_choice': decisionChoice,
              'custom_prompt': customPrompt,
              'git_provider': gitProvider,
              'custom_repo_name': customRepoName,
            }),
          )
          .timeout(const Duration(seconds: 180)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/ceo-decision');
    }
    return decoded;
  }

  /// Fetches execution trace history for the live telemetry sidebar.
  Future<List<Map<String, dynamic>>> getSessionTraces(String sessionId) async {
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/session/$sessionId/traces'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! List) {
      throw ApiException('Unexpected response shape from traces endpoint');
    }
    // Eagerly materialize into List<Map<String, dynamic>> — a lazy
    // .cast<>() view defers the element check to iteration time and can
    // surface as an opaque WASM runtime type-check failure deep in widgets.
    return decoded.whereType<Map>().map((e) {
      if (e is Map<String, dynamic>) return e;
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  /// Fetches committed artifacts (code files, docs) for a completed session.
  /// Returns a map of filename → file content from the backend.
  Future<Map<String, String>> getSessionArtifacts(String sessionId) async {
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/session/$sessionId/artifacts'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map) {
      throw ApiException('Unexpected response shape from artifacts endpoint');
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  /// Fetches the current session record (status + pipeline state) so the UI can
  /// reflect in real time what the background fleet is doing right now.
  Future<Map<String, dynamic>> getSessionState(String sessionId) async {
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/session/$sessionId'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from session endpoint');
    }
    return decoded;
  }

  /// Governance registry of all fleet sessions (audit trail).
  Future<Map<String, dynamic>> getSessions({int limit = 100}) async {
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/sessions?limit=$limit'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/sessions');
    }
    return decoded;
  }

  /// Semantic memory bank listing (tenant-isolated).
  Future<Map<String, dynamic>> getMemories({String? tenantId}) async {
    final qp = tenantId == null
        ? ''
        : '?tenant_id=${Uri.encodeComponent(tenantId)}';
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/memory$qp'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/memory');
    }
    return decoded;
  }

  /// Stores a semantic memory fact (CEO knowledge ingestion).
  Future<Map<String, dynamic>> storeMemory({
    required String topic,
    required String content,
    String tenantId = 'default_enterprise',
  }) async {
    final decoded = await _send(
      () async => _client
          .post(
            Uri.parse('$baseUrl/fleet/memory'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'topic': topic,
              'content': content,
              'tenant_id': tenantId,
            }),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from POST /fleet/memory');
    }
    return decoded;
  }

  /// Live security & IAM posture of the fleet.
  Future<Map<String, dynamic>> getSecurityPosture() async {
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/security'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/security');
    }
    return decoded;
  }

  /// System health & architecture introspection.
  Future<Map<String, dynamic>> getSystemInfo() async {
    final decoded = await _send(
      () async => _client
          .get(Uri.parse('$baseUrl/fleet/system'))
          .timeout(const Duration(seconds: 15)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/system');
    }
    return decoded;
  }

  /// CEO submits a fully independent idea at any time — no prior discovery required.
  /// The backend seeds a fresh session and starts the fleet pipeline in the background.
  Future<Map<String, dynamic>> submitCeoIdea({
    required String customPrompt,
    String gitProvider = 'github',
    String? customRepoName,
    String? sessionId,
  }) async {
    final decoded = await _send(
      () async => _client
          .post(
            Uri.parse('$baseUrl/fleet/ceo-idea'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'custom_prompt': customPrompt,
              'git_provider': gitProvider,
              'custom_repo_name': customRepoName,
              'session_id': sessionId,
            }),
          )
          .timeout(const Duration(seconds: 180)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/ceo-idea');
    }
    return decoded;
  }

  /// Generate proposals for a specific hackathon (already discovered — no Devpost API call).
  /// Pass the full hackathon map from the existing hackathons list.
  Future<Map<String, dynamic>> generateProposals({
    required Map<String, dynamic> hackathon,
    String sessionId = 'session_dev_001',
  }) async {
    final decoded = await _send(
      () async => _client
          .post(
            Uri.parse('$baseUrl/fleet/generate-proposals'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'session_id': sessionId,
              'hackathon': hackathon,
            }),
          )
          .timeout(const Duration(seconds: 180)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/generate-proposals');
    }
    return decoded;
  }

  /// On-demand trigger of the daily discovery cycle (same logic as the Cloud Scheduler job).
  Future<Map<String, dynamic>> triggerScheduledDiscovery() async {
    final decoded = await _send(
      () async => _client
          .post(
            Uri.parse('$baseUrl/fleet/scheduled-discovery'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 180)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response shape from /fleet/scheduled-discovery');
    }
    return decoded;
  }
}

/// Convenience extension for converting empty strings to null.
extension _StringNullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}


