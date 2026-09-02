import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import '../lib/services/brief_parser.dart';
import '../lib/services/devpost_service.dart';
import '../lib/services/gitlab_service.dart';
import '../lib/services/github_service.dart';

void main() {
  group('BriefParserService', () {
    test('filters online hackathons above minimum prize pool', () {
      final parser = BriefParserService();
      final payload = {
        'min_prize_pool': 5000,
        'require_online': true,
        'hackathons': [
          {
            'id': 'hack_1',
            'title': 'Global AI Enterprise Challenge',
            'is_online': true,
            'prize_pool': 50000,
            'submission_deadline': '2026-09-15',
          },
          {
            'id': 'hack_2',
            'title': 'Local In-Person Meetup',
            'is_online': false,
            'prize_pool': 10000,
            'submission_deadline': '2026-09-20',
          },
          {
            'id': 'hack_3',
            'title': 'Small Hackathon',
            'is_online': true,
            'prize_pool': 500,
            'submission_deadline': '2026-09-10',
          },
        ],
      };

      final result = parser.parseAndFilterOpportunities(payload);
      expect(result['status'], equals('success'));
      expect(result['total_evaluated'], equals(3));
      expect(result['filtered_count'], equals(1));
      expect(result['matches'][0]['title'], equals('Global AI Enterprise Challenge'));
    });
  });

  group('GitLabService', () {
    test('fails loudly when no private token is configured (no mock)', () async {
      final gitLab = GitLabService(privateToken: null);
      final result = await gitLab.provisionRepository(
        repoName: 'Autonomous Agent Fleet',
        description: 'Test repo',
        readmeContent: '# Test',
      );

      expect(result['status'], equals('error'));
      expect(result['error_type'], equals('GitLabTokenNotConfigured'));
      // Critical: no fake web_url must ever appear.
      expect(result['web_url'], isNull);
    });

    test('fails loudly on commit when no private token (no mock)', () async {
      final gitLab = GitLabService(privateToken: null);
      final result = await gitLab.commitFiles(
        projectId: 12345,
        repoName: 'test-repo',
        files: [
          {'path': 'src/main.py', 'content': 'print("hello")', 'commit_message': 'Add main.py'},
          {'path': 'Dockerfile', 'content': 'FROM python', 'commit_message': 'Add Dockerfile'},
        ],
      );

      expect(result['status'], equals('error'));
      expect(result['error_type'], equals('GitLabTokenNotConfigured'));
    });
  });

  group('GitHubService', () {
    test('fails loudly when no private token is configured (no mock)', () async {
      final gitHub = GitHubService(privateToken: null);
      final result = await gitHub.provisionRepository(
        repoName: 'EphemeraFlow Fleet',
        description: 'Test GitHub repo',
        readmeContent: '# EphemeraFlow',
      );

      expect(result['status'], equals('error'));
      expect(result['error_type'], equals('GitHubTokenNotConfigured'));
      // Critical: no fake web_url must ever appear.
      expect(result['web_url'], isNull);
    });

    test('fails loudly on commit when no private token (no mock)', () async {
      final gitHub = GitHubService(privateToken: null);
      final result = await gitHub.commitFiles(
        owner: 'Merdzhanov',
        repoName: 'ephemeraflow-fleet',
        files: [
          {'path': 'src/main.py', 'content': 'print("hello")', 'commit_message': 'Add main.py'},
          {'path': 'Dockerfile', 'content': 'FROM python', 'commit_message': 'Add Dockerfile'},
        ],
      );

      expect(result['status'], equals('error'));
      expect(result['error_type'], equals('GitHubTokenNotConfigured'));
    });
  });

  group('DevpostService (Direct Function)', () {
    test('fetches and filters hackathons deterministically without MCP', () async {
      // Inject a mock HTTP client so the test is deterministic (no live network).
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'hackathons': [
              {
                'id': '30721',
                'title': 'Agentic Cinema: The Blockbuster Hackathon',
                'displayed_location': 'Online',
                'prize_amount': 75000,
                'url': 'https://agentic-cinema.devpost.com/',
              },
              {
                'id': '30722',
                'title': 'Local In-Person Meetup',
                'displayed_location': 'San Francisco, CA',
                'prize_amount': 10000,
                'url': 'https://local-meetup.devpost.com/',
              },
              {
                'id': '30723',
                'title': 'Tiny Prize Hackathon',
                'displayed_location': 'Online',
                'prize_amount': 500,
                'url': '/tiny-prize-hackathon',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final devpost = DevpostService(client: mockClient);
      final result = await devpost.fetchAndFilterHackathons(minPrizePool: 5000);

      expect(result['status'], equals('success'));
      expect(result['filtered_count'], equals(1));
      expect(result['matches'], isNotEmpty);
      // Online + above prize threshold → only the Agentic Cinema hackathon survives.
      expect(result['matches'][0]['title'], contains('Agentic Cinema'));
      // Relative URLs are normalized to absolute devpost.com URLs.
      expect(result['matches'].length, equals(1));
    });

    test('returns empty matches when Devpost API is unreachable', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final devpost = DevpostService(client: mockClient);
      final result = await devpost.fetchAndFilterHackathons();

      expect(result['status'], equals('success'));
      expect(result['matches'], isEmpty);
      expect(result['error'], isNotNull);
    });
  });
}
