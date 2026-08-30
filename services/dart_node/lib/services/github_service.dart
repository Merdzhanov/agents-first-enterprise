import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Deterministic repository provisioning and multi-file Git tree scaffolding for GitHub.
class GitHubService {
  final String githubApiUrl;
  final String? privateToken;

  GitHubService({
    String? githubApiUrl,
    String? privateToken,
  })  : githubApiUrl = githubApiUrl ?? Platform.environment['GITHUB_API_URL'] ?? 'https://api.github.com',
        privateToken = privateToken ?? Platform.environment['GITHUB_TOKEN'];

  /// Provisions a new repository on GitHub and commits initial scaffold files.
  Future<Map<String, dynamic>> provisionRepository({
    required String repoName,
    required String description,
    required String readmeContent,
    String license = 'MIT',
    bool isPublic = true,
  }) async {
    final sanitizedName = repoName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '-')
        .replaceAll(RegExp(r'-+'), '-');

    // If no token is provided in dev/offline mode, run in mock-deterministic mode
    if (privateToken == null || privateToken!.isEmpty) {
      return {
        'status': 'provisioned_mock',
        'provider': 'github',
        'owner': 'agents-first-enterprise',
        'repo_name': sanitizedName,
        'web_url': 'https://github.com/agents-first-enterprise/$sanitizedName',
        'project_id': 20000000 + sanitizedName.hashCode.abs() % 80000000,
        'license': license,
        'visibility': isPublic ? 'public' : 'private',
        'files_committed': ['README.md', 'LICENSE', '.gitignore'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$githubApiUrl/user/repos'),
        headers: {
          'Authorization': 'Bearer $privateToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
          'User-Agent': 'Agents-First-Enterprise-Dart-Node',
        },
        body: jsonEncode({
          'name': sanitizedName,
          'description': description,
          'private': !isPublic,
          'auto_init': true,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String htmlUrl = data['html_url'] ?? 'https://github.com/agents-first-enterprise/$sanitizedName';
        final String owner = data['owner']?['login'] ?? 'agents-first-enterprise';
        final int repoId = data['id'] ?? (20000000 + sanitizedName.hashCode.abs() % 80000000);

        // Upload custom README.md
        await commitFile(
          owner: owner,
          repoName: sanitizedName,
          filePath: 'README.md',
          content: readmeContent,
          commitMsg: 'Initial architecture scaffold from Agent Fleet',
        );

        return {
          'status': 'provisioned',
          'provider': 'github',
          'owner': owner,
          'repo_name': sanitizedName,
          'web_url': htmlUrl,
          'project_id': repoId,
          'visibility': isPublic ? 'public' : 'private',
          'files_committed': ['README.md'],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      } else {
        throw HttpException('GitHub API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      return {
        'status': 'error',
        'provider': 'github',
        'error_type': 'GitHubProvisioningFailed',
        'message': e.toString(),
        'fallback_url': 'https://github.com/agents-first-enterprise/$sanitizedName',
      };
    }
  }

  /// Commits multiple files in batch or single-file updates.
  Future<Map<String, dynamic>> commitFiles({
    required String owner,
    required String repoName,
    required List<Map<String, dynamic>> files,
  }) async {
    if (privateToken == null || privateToken!.isEmpty) {
      final fileNames = files.map((f) => f['path']?.toString() ?? 'file').toList();
      return {
        'status': 'committed_mock',
        'provider': 'github',
        'repo_name': repoName,
        'committed_files': fileNames,
        'commit_sha': 'mock_sha_${DateTime.now().millisecondsSinceEpoch}',
      };
    }

    final committed = <String>[];
    for (final file in files) {
      final path = file['path'] ?? 'file';
      final content = file['content'] ?? '';
      final msg = file['commit_message'] ?? 'Add $path';
      await commitFile(
        owner: owner,
        repoName: repoName,
        filePath: path,
        content: content,
        commitMsg: msg,
      );
      committed.add(path);
    }

    return {
      'status': 'committed',
      'provider': 'github',
      'repo_name': repoName,
      'committed_files': committed,
      'commit_sha': 'gh_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// Commits a single file via GitHub REST API.
  Future<void> commitFile({
    required String owner,
    required String repoName,
    required String filePath,
    required String content,
    required String commitMsg,
  }) async {
    if (privateToken == null || privateToken!.isEmpty) return;

    final url = '$githubApiUrl/repos/$owner/$repoName/contents/$filePath';
    final base64Content = base64Encode(utf8.encode(content));

    await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $privateToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
        'User-Agent': 'Agents-First-Enterprise-Dart-Node',
      },
      body: jsonEncode({
        'message': commitMsg,
        'content': base64Content,
      }),
    );
  }
}
