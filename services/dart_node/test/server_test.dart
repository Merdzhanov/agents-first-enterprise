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
    test('mock provisions repository and formats response', () async {
      final gitLab = GitLabService(privateToken: null);
      final result = await gitLab.provisionRepository(
        repoName: 'Autonomous Agent Fleet',
        description: 'Test repo',
        readmeContent: '# Test',
      );

      expect(result['status'], equals('provisioned_mock'));
      expect(result['repo_name'], equals('autonomous-agent-fleet'));
      expect(result['web_url'], contains('gitlab.com/agents-first-enterprise/autonomous-agent-fleet'));
      expect(result['files_committed'], contains('README.md'));
    });

    test('mock commits multiple files to GitLab', () async {
      final gitLab = GitLabService(privateToken: null);
      final result = await gitLab.commitFiles(
        projectId: 12345,
        repoName: 'test-repo',
        files: [
          {'path': 'src/main.py', 'content': 'print("hello")', 'commit_message': 'Add main.py'},
          {'path': 'Dockerfile', 'content': 'FROM python', 'commit_message': 'Add Dockerfile'},
        ],
      );

      expect(result['status'], equals('committed_mock'));
      expect(result['committed_files'], contains('src/main.py'));
      expect(result['committed_files'], contains('Dockerfile'));
    });
  });

  group('GitHubService', () {
    test('mock provisions GitHub repository and formats response', () async {
      final gitHub = GitHubService(privateToken: null);
      final result = await gitHub.provisionRepository(
        repoName: 'EphemeraFlow Fleet',
        description: 'Test GitHub repo',
        readmeContent: '# EphemeraFlow',
      );

      expect(result['status'], equals('provisioned_mock'));
      expect(result['provider'], equals('github'));
      expect(result['repo_name'], equals('ephemeraflow-fleet'));
      expect(result['web_url'], contains('github.com/agents-first-enterprise/ephemeraflow-fleet'));
      expect(result['files_committed'], contains('README.md'));
    });

    test('mock commits multiple files to GitHub', () async {
      final gitHub = GitHubService(privateToken: null);
      final result = await gitHub.commitFiles(
        owner: 'agents-first-enterprise',
        repoName: 'ephemeraflow-fleet',
        files: [
          {'path': 'src/main.py', 'content': 'print("hello")', 'commit_message': 'Add main.py'},
          {'path': 'Dockerfile', 'content': 'FROM python', 'commit_message': 'Add Dockerfile'},
        ],
      );

      expect(result['status'], equals('committed_mock'));
      expect(result['committed_files'], contains('src/main.py'));
      expect(result['committed_files'], contains('Dockerfile'));
    });
  });

  group('DevpostService (Direct Function)', () {
    test('fetches and filters hackathons deterministically without MCP', () async {
      final devpost = DevpostService();
      final result = await devpost.fetchAndFilterHackathons(minPrizePool: 5000);

      expect(result['status'], equals('success'));
      expect(result['matches'], isNotEmpty);
      expect(result['matches'][0]['title'], contains('Google Cloud'));
    });
  });
}
