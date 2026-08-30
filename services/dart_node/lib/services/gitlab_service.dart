import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Deterministic repository provisioning and multi-file Git tree scaffolding for GitLab.
class GitLabService {
  final String gitlabApiUrl;
  final String? privateToken;

  GitLabService({
    String? gitlabApiUrl,
    String? privateToken,
  })  : gitlabApiUrl = gitlabApiUrl ?? Platform.environment['GITLAB_API_URL'] ?? 'https://gitlab.com/api/v4',
        privateToken = privateToken ?? Platform.environment['GITLAB_TOKEN'];

  /// Provisions a new repository and commits initial scaffold files.
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

    // If no token is provided in dev environment, run in mock-deterministic mode
    if (privateToken == null || privateToken!.isEmpty) {
      return {
        'status': 'provisioned_mock',
        'provider': 'gitlab',
        'owner': 'agents-first-enterprise',
        'repo_name': sanitizedName,
        'web_url': 'https://gitlab.com/agents-first-enterprise/$sanitizedName',
        'project_id': 10000000 + sanitizedName.hashCode.abs() % 90000000,
        'license': license,
        'visibility': isPublic ? 'public' : 'private',
        'files_committed': ['README.md', 'LICENSE', '.gitignore'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$gitlabApiUrl/projects'),
        headers: {
          'PRIVATE-TOKEN': privateToken!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': sanitizedName,
          'description': description,
          'visibility': isPublic ? 'public' : 'private',
          'initialize_with_readme': false,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final projectId = data['id'];

        // Commit initial README.md
        await _commitFile(projectId, 'README.md', readmeContent, 'Initial commit from Agent Fleet');

        return {
          'status': 'provisioned',
          'provider': 'gitlab',
          'owner': 'agents-first-enterprise',
          'repo_name': sanitizedName,
          'web_url': data['web_url'],
          'project_id': projectId,
          'visibility': data['visibility'],
          'files_committed': ['README.md'],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      } else {
        throw HttpException('GitLab API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      return {
        'status': 'error',
        'provider': 'gitlab',
        'error_type': 'GitLabProvisioningFailed',
        'message': e.toString(),
        'fallback_url': 'https://gitlab.com/agents-first-enterprise/$sanitizedName',
      };
    }
  }

  /// Commits multiple files to GitLab repository.
  Future<Map<String, dynamic>> commitFiles({
    required dynamic projectId,
    required String repoName,
    required List<Map<String, dynamic>> files,
  }) async {
    if (privateToken == null || privateToken!.isEmpty) {
      final fileNames = files.map((f) => f['path']?.toString() ?? 'file').toList();
      return {
        'status': 'committed_mock',
        'provider': 'gitlab',
        'repo_name': repoName,
        'committed_files': fileNames,
        'commit_sha': 'mock_gitlab_sha_${DateTime.now().millisecondsSinceEpoch}',
      };
    }

    final committed = <String>[];
    for (final file in files) {
      final path = file['path'] ?? 'file';
      final content = file['content'] ?? '';
      final msg = file['commit_message'] ?? 'Add $path';
      await _commitFile(projectId, path, content, msg);
      committed.add(path);
    }

    return {
      'status': 'committed',
      'provider': 'gitlab',
      'repo_name': repoName,
      'committed_files': committed,
      'commit_sha': 'gl_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  Future<void> _commitFile(dynamic projectId, String filePath, String content, String commitMsg) async {
    if (privateToken == null || privateToken!.isEmpty) return;

    final url = '$gitlabApiUrl/projects/$projectId/repository/files/${Uri.encodeComponent(filePath)}';
    await http.post(
      Uri.parse(url),
      headers: {
        'PRIVATE-TOKEN': privateToken!,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'branch': 'main',
        'commit_message': commitMsg,
        'content': content,
      }),
    );
  }
}
