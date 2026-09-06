import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:governance_dashboard/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiService System Prompt & Dynamic HITL Gates (MockClient)', () {
    test('submitSystemPrompt POSTs to /fleet/system-prompt with payload', () async {
      final mockResponse = jsonEncode({
        'session_id': 'session_system_prompt_999',
        'status': 'awaiting_ceo_decision',
        'message': 'System prompt parsed and dual technical proposals synthesized.',
        'data': {
          'idea_a': {'title': 'Pure SPIR-V Engine', 'repo_name': 'agents_procedural_3d'},
          'idea_b': {'title': 'Hybrid GLSL Engine', 'repo_name': 'agents_procedural_hybrid'},
        },
      });

      final api = ApiService(
        baseUrl: 'http://mock.local',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/fleet/system-prompt');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['system_prompt'], contains('agents_procedural_3d'));
          expect(body['git_provider'], 'github');
          expect(body['custom_repo_name'], 'agents_procedural_3d');
          return http.Response(mockResponse, 200);
        }),
      );

      final result = await api.submitSystemPrompt(
        systemPrompt: '# SYSTEM PROMPT: Building `agents_procedural_3d` Engine',
        gitProvider: 'github',
        customRepoName: 'agents_procedural_3d',
      );

      expect(result['session_id'], 'session_system_prompt_999');
      expect(result['status'], 'awaiting_ceo_decision');
    });

    test('submitDeploymentDecision POSTs to /fleet/deploy with approval', () async {
      final mockResponse = jsonEncode({
        'session_id': 'session_deploy_123',
        'status': 'deploying',
        'message': 'Deployment approved for production Cloud Run.',
      });

      final api = ApiService(
        baseUrl: 'http://mock.local',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/fleet/deploy');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['session_id'], 'session_deploy_123');
          expect(body['decision'], 'approve_deploy');
          expect(body['target_environment'], 'production');
          return http.Response(mockResponse, 200);
        }),
      );

      final result = await api.submitDeploymentDecision(
        sessionId: 'session_deploy_123',
        decision: 'approve_deploy',
        targetEnvironment: 'production',
      );

      expect(result['status'], 'deploying');
    });

    test('submitGateDecision routes to submitCeoDecision with feedback', () async {
      final mockResponse = jsonEncode({
        'session_id': 'session_gate_456',
        'status': 'executing',
        'message': 'Gate decision acknowledged. Advancing to next pipeline stage.',
      });

      final api = ApiService(
        baseUrl: 'http://mock.local',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/fleet/ceo-decision');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['session_id'], 'session_gate_456');
          expect(body['decision_choice'], 'approve_architecture');
          expect(body['custom_prompt'], 'Architecture looks solid.');
          return http.Response(mockResponse, 200);
        }),
      );

      final result = await api.submitGateDecision(
        sessionId: 'session_gate_456',
        decision: 'approve_architecture',
        feedback: 'Architecture looks solid.',
      );

      expect(result['status'], 'executing');
    });
  });
}
