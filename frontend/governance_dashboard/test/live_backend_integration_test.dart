// Live integration test: proves whether ApiService talks to the REAL backend
// or throws honest errors. After the no-silent-fallback fix, ANY backend
// outage must surface as an ApiException — never as fabricated success data.
//
// Prerequisites:
//   - Real orchestrator running:  uvicorn app.main:app --port 8000
//   - Dead port 59999 to prove failures throw instead of masking.
//
// Run:  flutter test test/live_backend_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:governance_dashboard/services/api_service.dart';

void main() {
  group('ApiService against LIVE backend (http://127.0.0.1:8000)', () {
    final api = ApiService(baseUrl: 'http://127.0.0.1:8000');

    test('triggerDiscovery returns REAL pipeline data from the orchestrator',
        () async {
      final result = await api
          .triggerDiscovery(sessionId: 'flutter_live_test')
          .timeout(const Duration(seconds: 20));

      // The backend always echoes the session id it received — impossible
      // to produce from any client-side hardcoded data.
      expect(result['session_id'], 'flutter_live_test');

      // Real pipeline status from main.py trigger_discovery.
      expect(result['status'], anyOf('awaiting_ceo_decision', 'error'));
    });

    test('getSessionTraces returns REAL trace rows for a fresh session',
        () async {
      // Create our own session so the test is self-contained (the in-memory
      // store resets on orchestrator restarts).
      final sessionId =
          'flutter_trace_test_${DateTime.now().millisecondsSinceEpoch}';
      await api
          .triggerDiscovery(sessionId: sessionId)
          .timeout(const Duration(seconds: 30));

      final traces = await api.getSessionTraces(sessionId).timeout(
            const Duration(seconds: 20),
          );

      expect(traces, isNotEmpty,
          reason: 'Expected real execution traces from the orchestrator');
      expect(
        traces.any((t) => t['agent_name'] == 'ScoutAgent'),
        isTrue,
        reason: 'ScoutAgent trace row missing: $traces',
      );
    });
  });

  group('ApiService against DEAD backend (errors must surface, not mask)', () {
    test('triggerDiscovery throws ApiException instead of returning mocks',
        () async {
      // Nothing listens on 59999 -> connection refused -> must THROW.
      final api = ApiService(baseUrl: 'http://127.0.0.1:59999');

      await expectLater(
        api.triggerDiscovery(sessionId: 'dead_port_test'),
        throwsA(isA<ApiException>()),
      );
    });

    test('submitCeoDecision throws ApiException instead of fabricated success',
        () async {
      final api = ApiService(baseUrl: 'http://127.0.0.1:59999');

      await expectLater(
        api.submitCeoDecision(
          sessionId: 'dead_port_test',
          decisionChoice: 'approve_idea_a',
          gitProvider: 'github',
          customRepoName: 'never-created-repo',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('getSessionTraces throws ApiException instead of returning []',
        () async {
      final api = ApiService(baseUrl: 'http://127.0.0.1:59999');

      await expectLater(
        api.getSessionTraces('dead_port_test'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
