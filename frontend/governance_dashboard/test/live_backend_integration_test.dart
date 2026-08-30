// Live integration test: proves whether ApiService talks to the REAL backend
// or throws honest errors. After the no-silent-fallback fix, ANY backend
// outage must surface as an ApiException — never as fabricated success data.
//
// Prerequisites:
//   - Real orchestrator running:  uvicorn app.main:app --port 8000
//   - Dead port 59999 to prove failures throw instead of masking.
//
// Run:  flutter test test/live_backend_integration_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:governance_dashboard/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('ApiService hackathon board contract (offline, MockClient)', () {
    test('triggerDiscovery surfaces top-5 hackathons + per-idea deep links',
        () async {
      final hackathons = List.generate(5, (i) => {
            'id': 'hack_$i',
            'title': 'Hackathon $i',
            'url': 'https://devpost.com/hack-$i',
            'prize_pool': 100000 - i * 10000,
            'submission_deadline': '2026-09-30',
          });
      final mockBody = jsonEncode({
        'session_id': 'board_contract_test',
        'status': 'awaiting_ceo_decision',
        'message': 'ok',
        'request_input': null,
        'data': {
          'idea_a': {
            'title': 'EphemeraFlow',
            'hackathon_title': hackathons[0]['title'],
            'hackathon_url': hackathons[0]['url'],
          },
          'idea_b': {
            'title': 'ArmorGuard',
            'hackathon_title': hackathons[0]['title'],
            'hackathon_url': hackathons[0]['url'],
          },
        },
        'hackathons': hackathons,
        'opportunity': hackathons[0],
      });

      final api = ApiService(
        baseUrl: 'http://mock.local',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/fleet/discovery');
          return http.Response(mockBody, 200);
        }),
      );

      final result =
          await api.triggerDiscovery(sessionId: 'board_contract_test');

      // Top-5 board: every row must carry a clickable link to the hackathon.
      final board = result['hackathons'] as List;
      expect(board.length, 5);
      for (final row in board) {
        expect((row as Map)['title'], isNotEmpty);
        expect(row['url'], startsWith('https://'));
      }

      // Each proposed project deep-links to the specific hackathon it came from.
      final ideas = result['data'] as Map;
      for (final key in ['idea_a', 'idea_b']) {
        final idea = ideas[key] as Map;
        expect(idea['hackathon_title'], isNotEmpty);
        expect(idea['hackathon_url'], startsWith('https://'));
      }
      expect(
        (result['opportunity'] as Map)['url'],
        (board.first as Map)['url'],
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

    test('getSessionState throws ApiException instead of fabricated status',
        () async {
      final api = ApiService(baseUrl: 'http://127.0.0.1:59999');

      await expectLater(
        api.getSessionState('dead_port_test'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
