import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

import 'widgets/top_nav_bar.dart';
import 'widgets/section_rail.dart';
import 'widgets/git_target_bar.dart';
import 'widgets/hackathon_board.dart';
import 'widgets/logs_sidebar.dart';
import 'widgets/ceo_proposal_gate.dart';
import 'widgets/custom_and_skip_row.dart';
import 'widgets/repository_status_hub.dart';
import 'widgets/sessions_panel.dart';
import 'widgets/memory_panel.dart';
import 'widgets/security_panel.dart';
import 'widgets/system_panel.dart';
import 'widgets/gov_helpers.dart';

void main() {
  debugPrint('[ENV] kIsWasm=$kIsWasm');
  FlutterError.onError = (details) {
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    debugPrint('[FLUTTER_ERROR] stack: ${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PLATFORM_ERROR] ${error.runtimeType}: $error');
    debugPrint('[PLATFORM_ERROR] stack:\n$stack');
    return true;
  };
  runZonedGuarded(() {
    runApp(const AgentEnterpriseApp());
  }, (error, stack) {
    debugPrint('[ZONE_ERROR] ${error.runtimeType}: $error');
    debugPrint('[ZONE_ERROR] stack:\n$stack');
  });
}

class AgentEnterpriseApp extends StatelessWidget {
  const AgentEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agent-First Enterprise - CEO Governance Command Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8ED5FF),
          primaryContainer: Color(0xFF38BDF8),
          surface: Color(0xFF051424),
          surfaceContainerHighest: Color(0xFF273647),
          onSurface: Color(0xFFD4E4FA),
          onSurfaceVariant: Color(0xFFBDC8D1),
          error: Color(0xFFFFB4AB),
          errorContainer: Color(0xFF93000A),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedProvider = 'GitHub';
  String _projectName = 'ephemeraflow-governed-fleet';
  bool _isEditingName = false;
  final TextEditingController _nameController =
      TextEditingController(text: 'ephemeraflow-governed-fleet');
  final TextEditingController _customDirectiveController =
      TextEditingController();

  String _statusText = 'No active session — trigger discovery to begin.';
  bool _isLoading = false;
  bool _isSessionReady = false; // Controls whether CEO can approve/reject
  String _selectedFile = '';

  // Active session for telemetry polling. Empty until discovery is triggered.
  String _sessionId = '';
  Timer? _telemetryTimer;
  List<Map<String, dynamic>> _hackathons = [];
  String? _selectedHackathonId;
  Map<String, dynamic> _activeOpportunity = {};
  Map<String, dynamic> _ideaA = {};
  Map<String, dynamic> _ideaB = {};

  /// Safely converts a dynamic value (from JSON) to Map<String, dynamic>.
  /// Returns an empty map for null or non-Map values, preventing runtime
  /// type-check failures in release builds.
  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  // Enterprise governance sections (sessions / memory / security / system).
  String _activeSection = 'fleet';
  bool _sectionLoading = false;
  Map<String, dynamic> _sessionsData = {};
  Map<String, dynamic> _memoryData = {};
  Map<String, dynamic> _securityData = {};
  Map<String, dynamic> _systemData = {};
  final TextEditingController _memoryTopicController =
      TextEditingController();
  final TextEditingController _memoryContentController =
      TextEditingController();
  final TextEditingController _newIdeaController =
      TextEditingController();
  bool _isSubmittingIdea = false;
  bool _isRunningScheduledDiscovery = false;

  List<Map<String, dynamic>> _logs = [
    {
      'time': 'System Ready',
      'msg': 'Cloud Run services and Dart nodes initialized in eur3 / europe-west1.',
      'type': 'system'
    }
  ];

  // Real artifacts from the backend — populated after CEO approval.
  Map<String, String> _artifacts = {};

  @override
  void initState() {
    super.initState();
    _startTelemetryPolling();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _nameController.dispose();
    _customDirectiveController.dispose();
    _memoryTopicController.dispose();
    _memoryContentController.dispose();
    _newIdeaController.dispose();
    super.dispose();
  }

  /// Polls the orchestrator so the dashboard shows what the fleet is doing
  /// right now — live session status plus real execution traces.
  void _startTelemetryPolling() {
    _refreshTelemetry();
    _telemetryTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _onTelemetryTick());
  }

  /// One polling tick: fleet traces/status always refresh; the session
  /// registry stays live while its section is on screen.
  void _onTelemetryTick() {
    _refreshTelemetry();
    if (_activeSection == 'sessions') {
      _loadSessions(silent: true);
    }
  }

  Future<void> _refreshTelemetry() async {
    // Guard: don't hit the backend with an empty session ID — produces
    // /fleet/session//traces → 404 noise in Cloud Run logs.
    if (_sessionId.isEmpty) return;
    try {
        _isSessionReady = true; // <-- Enable approval buttons
      final traces = await _api.getSessionTraces(_sessionId);
      final session = await _api.getSessionState(_sessionId);
      if (!mounted) return;
      setState(() {
        if (traces.isNotEmpty) {
          // NOTE: the map closure MUST be pinned to Map<String, dynamic>.
          // If it infers Map<String, String>, `_logs` becomes a
          // List<Map<String, String>> at runtime while statically typed
          // List<Map<String, dynamic>> — the next _addLog insert then throws
          // a covariance TypeError (fatal under dart2wasm's sound checks).
          _logs = traces.reversed.map<Map<String, dynamic>>((t) {
            final agent = (t['agent_name'] ?? '').toString();
            final msg = (t['msg'] ?? '').toString();
            final prefixed =
                agent.isEmpty || msg.startsWith(agent) ? msg : '$agent: $msg';
            return <String, dynamic>{
              'time': (t['time'] ?? '--:--:--').toString(),
              'msg': prefixed,
              'type': (t['type'] ?? 'system').toString(),
            };
          }).toList();
        }
        final status = (session['status'] ?? '').toString();
        if (status.isNotEmpty) {
          _statusText = switch (status) {
            'awaiting_ceo_decision' =>
              'CEO Proposal Gate: Review Concepts & Confirm Provider/Project Name',
            'awaiting_gate_decision' =>
              'CEO Review Gate: Architecture or Code review awaiting your decision',
            'awaiting_deployment_decision' =>
              'CEO Deployment Gate: Confirm Cloud Run deployment or keep repo only',
            'executing' =>
              'Fleet executing — Architect → Lead Dev → Marketing in progress...',
            'deploying' =>
              'Deploying to Cloud Run — building container and rolling out...',
            'completed' =>
              'Completed: prototype provisioned and submission packaged',
            'skipped' => 'Pipeline Safely Halted (Skipped by CEO)',
            'failed' => 'Pipeline failed — see execution log for details',
            _ => 'Fleet status: $status',
          };
          // Terminal states: stop polling so the UI freezes on the final status.
          if (status == 'completed' ||
              status == 'skipped' ||
              status == 'failed') {
            _telemetryTimer?.cancel();
            _telemetryTimer = null;
          }
        }
      });
      // Fetch real artifacts when pipeline completes (outside setState).
      if ((session['status'] ?? '').toString() == 'completed') {
        try {
          final artifacts = await _api.getSessionArtifacts(_sessionId);
          if (artifacts.isNotEmpty && mounted) {
            setState(() {
              _artifacts = artifacts;
              if (_selectedFile.isEmpty || !_artifacts.containsKey(_selectedFile)) {
                _selectedFile = artifacts.keys.first;
              }
            });
          }
        } catch (_) {}
      }
    } catch (_) {
      // Backend unreachable — keep last known state and local action logs.
    }
  }

  /// Opens a hackathon page in a new browser tab (new tab on Flutter Web).
  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      _addLog('ERROR: Invalid hackathon link — "$url".', 'error');
      return;
    }
    _addLog('Opening hackathon page in a new browser tab: $url', 'system');
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!ok) {
        _addLog('ERROR: System refused to open $url.', 'error');
      }
    } catch (e) {
      _addLog('ERROR: Could not open $url — $e', 'error');
    }
  }

  void _addLog(String msg, String type) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      _logs.insert(
          0, <String, dynamic>{'time': timeStr, 'msg': msg, 'type': type});
    });
  }

  final ApiService _api = ApiService();

  void _triggerDiscovery() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Scouting Active Tracks & Synthesizing Proposals...';
    });
    _addLog(
        'Scout Agent: Invoked Dart Functional Node (/tasks/parse-brief) with raw opportunity feeds.',
        'dart');

    try {
      final result = await _api.triggerDiscovery(
        sessionId: _sessionId.isEmpty ? 'session_governance_001' : _sessionId,
      );
      final message = result['message'] ?? 'Vertex AI synthesized 2 proposals.';
      final hackathons = govSafeList(result['hackathons'])
          .whereType<Map>()
          .map((h) => _safeMap(h))
          .toList();
      final opportunity = _safeMap(result['opportunity']);
      final data = result['data'];
      // Store session_id from backend response for subsequent calls
      final newSessionId = result['session_id']?.toString();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hackathons = hackathons;
        _activeOpportunity = opportunity;
        if (data is Map<String, dynamic>) {
          _ideaA = _safeMap(data['idea_a']);
          _ideaB = _safeMap(data['idea_b']);
        }
        // Store session_id from backend to use in CEO decision calls
        if (newSessionId != null && newSessionId.isNotEmpty) {
          _sessionId = newSessionId;
        }
        // Auto-select the first hackathon so proposals align with the selected hackathon
        if (hackathons.isNotEmpty) {
          _selectedHackathonId = hackathons.first['id']?.toString();
        }
        _statusText = 'CEO Proposal Gate: Review Concepts & Confirm Provider/Project Name';
      });
      _addLog(
          'Scout Agent: Ranked ${hackathons.length} live hackathons — top 5 now on the Live Hackathon Board.',
          'dart');
      _addLog('Planner Agent: $message', 'agent');
      _isSessionReady = false; // <-- Disable approval buttons
      _addLog(
          'RequestInput: Yielded execution loop to Human CEO for decision.',
          'ceo');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = 'Backend unreachable — start the orchestrator and retry';
      });
      _addLog('ERROR: Discovery failed — $e', 'error');
    }
  }

  /// Generates proposals aligned to a specific hackathon by re-running discovery
  /// with the selected hackathon as the seed.
  void _generateProposalsForHackathon(String hackathonId) async {
    final hackathon = _hackathons.firstWhere(
      (h) => (h['id']?.toString() ?? '') == hackathonId,
      orElse: () => {},
    );
    if (hackathon.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusText = 'Generating proposals for ${hackathon['title']}...';
      _ideaA = {};
      _ideaB = {};
    });
    _addLog(
        'Planner Agent: Synthesizing proposals aligned to "${hackathon['title']}"...',
        'agent');

    try {
      // Generate a fresh session per hackathon so each selection produces
      // distinct proposals and appears as its own entry in the history.
      final newSessionId =
          'session_governance_${hackathonId}_${DateTime.now().millisecondsSinceEpoch}';
      final result = await _api.generateProposals(
        sessionId: newSessionId,
        hackathon: hackathon,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _sessionId = newSessionId;
        _ideaA = _safeMap(result['idea_a']);
        _ideaB = _safeMap(result['idea_b']);
        _activeOpportunity = hackathon;
        _statusText = 'Proposals ready for "${hackathon['title']}"';
      });
      _addLog(
          'Planner Agent: Generated 2 proposals aligned to "${hackathon['title']}".',
          'agent');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = 'Failed to generate proposals — $e';
      });
      _addLog('ERROR: Proposal generation failed — $e', 'error');
    }
  }

  void _approveConcept(
    String conceptName,
    String defaultRepo, {
    String? decisionChoiceOverride,
  }) async {
    final provider = _selectedProvider.toLowerCase();
    final repoName = _projectName.trim().isEmpty ? defaultRepo : _projectName.trim();
    final repoUrl = _selectedProvider == 'GitHub'
        ? 'https://github.com/Merdzhanov/$repoName'
        : 'https://gitlab.com/Merdzhanov/$repoName';

    setState(() {
      _isLoading = true;
      _statusText = 'Executing Pipeline on ${provider.toUpperCase()} for: "$conceptName"...';
    });

    _addLog(
        'CEO Action: Approved $conceptName on ${provider.toUpperCase()} with repository name "$repoName".',
        'ceo');

    final decisionChoice = decisionChoiceOverride ??
        (conceptName.toLowerCase().contains('ephemeraflow')
            ? 'approve_idea_a'
            : conceptName.toLowerCase().contains('armorguard')
                ? 'approve_idea_b'
                : 'custom_idea');

    final Map<String, dynamic> result;
    try {
      result = await _api.submitCeoDecision(
        sessionId: _sessionId,
        decisionChoice: decisionChoice,
        gitProvider: provider,
        customRepoName: repoName,
        customPrompt: conceptName.startsWith('Custom Directive:') ? conceptName : null,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = 'Pipeline failed — backend error (see execution log)';
      });
      _addLog('ERROR: CEO pipeline failed — $e', 'error');
      return;
    }

    final statusMsg = result['message'] ?? 'Pipeline dispatched.';
    _addLog('ADK Runner: $statusMsg — provisioning $repoUrl in background.', 'system');
    _addLog('Telemetry: polling for real execution traces every 3s...', 'system');

    setState(() {
      _isLoading = false;
      _statusText = 'Fleet executing — Architect → Lead Dev → Marketing in progress...';
    });
    // Ensure the telemetry timer is active so real backend traces surface.
    if (_telemetryTimer == null || !_telemetryTimer!.isActive) {
      _startTelemetryPolling();
    }
  }

  void _skipImplementation() {
    setState(() {
      _statusText = 'Pipeline Safely Halted (Skipped by CEO)';
    });
    _addLog('CEO Action: Elected to Skip Implementation.', 'skip');
    _addLog(
        'Supervisor: Acknowledged Skip command. Updating Firestore state. Zero cloud resources consumed.',
        'skip');
  }

  void _submitCustomDirective() {
    final directive = _customDirectiveController.text.trim();
    if (directive.isEmpty) return;
    _approveConcept('Custom Directive: $directive', 'custom-enterprise-prototype');
  }

  void _showNewIdeaDialog() {
    _newIdeaController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: Color(0xFFFBBF24), size: 20),
              SizedBox(width: 8),
              Text(
                'New CEO Idea',
                style: TextStyle(
                  color: Color(0xFFD4E4FA),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: _newIdeaController,
            maxLines: 4,
            autofocus: true,
            style: const TextStyle(color: Color(0xFFD4E4FA), fontSize: 13),
            decoration: const InputDecoration(
              hintText:
                  'Describe your prototype idea — problem, target users, key GCP services...',
              hintStyle:
                  TextStyle(fontSize: 13, color: Color(0xFF87929A)),
              filled: true,
              fillColor: Color(0xFF020617),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3E484F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFBBF24)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFBDC8D1))),
            ),
            ElevatedButton(
              onPressed: () {
                final text = _newIdeaController.text.trim();
                if (text.isEmpty) return;
                Navigator.of(ctx).pop();
                _submitNewIdea(text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24),
              ),
              child: const Text('Submit Idea',
                  style: TextStyle(
                      color: Color(0xFF00354A),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _submitNewIdea(String ideaText) async {
    setState(() => _isSubmittingIdea = true);
    _addLog('CEO: Submitting independent idea — "${ideaText.substring(0, ideaText.length.clamp(0, 60))}..."',
        'ceo');
    try {
      final result = await _api.submitCeoIdea(
        customPrompt: ideaText,
        gitProvider: _selectedProvider.toLowerCase(),
      );
      if (!mounted) return;
      final newSession = result['session_id']?.toString();
      setState(() {
        _isSubmittingIdea = false;
        if (newSession != null && newSession.isNotEmpty) {
          _sessionId = newSession;
        }
        _statusText = 'CEO idea accepted — fleet pipeline running in background.';
      });
      _addLog(
          'Planner: Custom directive accepted. Session ${newSession ?? "?"} provisioning in background.',
          'agent');
      _startTelemetryPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingIdea = false;
        _statusText = 'Failed to submit idea — $e';
      });
      _addLog('Error submitting idea: $e', 'error');
    }
  }

  void _runScheduledDiscovery() async {
    setState(() => _isRunningScheduledDiscovery = true);
    _addLog('Scheduler: On-demand discovery cycle triggered.', 'system');
    try {
      final result = await _api.triggerScheduledDiscovery();
      if (!mounted) return;
      final count = govSafeInt(result['proposals_count']);
      setState(() => _isRunningScheduledDiscovery = false);
      _addLog(
          'Scheduler: Cycle complete — $count new proposal(s) synthesized for CEO review.',
          'success');
      // Refresh sessions list so any new auto-sessions appear.
      _onTelemetryTick();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRunningScheduledDiscovery = false);
      _addLog('Scheduler error: $e', 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Column(
        children: [
          TopNavBar(
            statusText: _statusText,
            isLoading: _isLoading,
            isSubmittingIdea: _isSubmittingIdea,
            onTriggerDiscovery: _triggerDiscovery,
            onShowNewIdeaDialog: _showNewIdeaDialog,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionRail(
                  activeSection: _activeSection,
                  onSectionSelected: _switchSection,
                ),
                Expanded(
                  flex: 62,
                  child: _buildActiveSection(),
                ),
                Container(width: 1, color: Colors.white.withAlpha(15)),
                Expanded(
            isSessionReady: _isSessionReady,
                  flex: 32,
                  child: LogsSidebar(
                    logs: _logs,
                    onRefresh: _refreshTelemetry,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fleet section — the original main content column.
  Widget _buildFleetSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GitTargetBar(
            selectedProvider: _selectedProvider,
            projectName: _projectName,
            isEditingName: _isEditingName,
            nameController: _nameController,
            onProviderChanged: (provider) {
              setState(() => _selectedProvider = provider);
            },
            onEditingNameStart: () {
              setState(() => _isEditingName = true);
            },
            onProjectNameSubmitted: (val) {
              setState(() {
                _projectName = val.trim();
                _isEditingName = false;
              });
            },
            onLog: _addLog,
          ),
          const SizedBox(height: 20),
          HackathonBoard(
            hackathons: _hackathons,
            onLaunchUrl: _launchExternalUrl,
            selectedHackathonId: _selectedHackathonId,
            onHackathonSelected: (id) {
              if (id == null) return;
              setState(() => _selectedHackathonId = id);
              _generateProposalsForHackathon(id);
            },
          ),
          const SizedBox(height: 20),
          CeoProposalGate(
            activeOpportunity: _activeOpportunity,
            ideaA: _ideaA,
            ideaB: _ideaB,
            isLoading: _isLoading,
            onApproveConcept: _approveConcept,
            onLaunchUrl: _launchExternalUrl,
            selectedHackathon: _selectedHackathonId == null
                ? null
                : _hackathons.firstWhere(
                    (h) => (h['id']?.toString() ?? '') == _selectedHackathonId,
                    orElse: () => {},
                  ),
          ),
          const SizedBox(height: 20),
          CustomAndSkipRow(
            customDirectiveController: _customDirectiveController,
            onSubmitCustomDirective: _submitCustomDirective,
            onSkipImplementation: _skipImplementation,
          ),
          const SizedBox(height: 20),
          RepositoryStatusHub(
            artifacts: _artifacts,
            selectedFile: _selectedFile,
            isLoading: _isLoading,
            onFileSelected: (file) {
              setState(() => _selectedFile = file);
            },
            onLog: _addLog,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSection() {
    switch (_activeSection) {
      case 'sessions':
        return SessionsPanel(
          sessionsData: _sessionsData,
          sectionLoading: _sectionLoading,
        );
      case 'memory':
        return MemoryPanel(
          memoryData: _memoryData,
          sectionLoading: _sectionLoading,
          topicController: _memoryTopicController,
          contentController: _memoryContentController,
          onSubmitMemory: _submitMemory,
        );
      case 'security':
        return SecurityPanel(
          securityData: _securityData,
          sectionLoading: _sectionLoading,
        );
      case 'system':
        return SystemPanel(
          systemData: _systemData,
          sectionLoading: _sectionLoading,
          isRunningScheduledDiscovery: _isRunningScheduledDiscovery,
          onRunScheduledDiscovery: _runScheduledDiscovery,
        );
      default:
        return _buildFleetSection();
    }
  }

  void _switchSection(String section) {
    setState(() => _activeSection = section);
    switch (section) {
      case 'sessions':
        _loadSessions();
      case 'memory':
        _loadMemory();
      case 'security':
        _loadSecurity();
      case 'system':
        _loadSystem();
    }
  }


  Future<void> _loadSessions({bool silent = false}) async {
    if (!silent) setState(() => _sectionLoading = true);
    try {
      final data = await _api.getSessions(limit: 200);
      if (!mounted) return;
      setState(() => _sessionsData = data);
    } catch (e) {
      if (!silent) _addLog('Sessions load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => _sectionLoading = false);
    }
  }

  Future<void> _loadMemory({bool silent = false}) async {
    if (!silent) setState(() => _sectionLoading = true);
    try {
      final data = await _api.getMemories();
      if (!mounted) return;
      setState(() => _memoryData = data);
    } catch (e) {
      if (!silent) _addLog('Memory load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => _sectionLoading = false);
    }
  }

  Future<void> _submitMemory() async {
    final topic = _memoryTopicController.text.trim();
    final content = _memoryContentController.text.trim();
    if (topic.isEmpty || content.isEmpty) {
      _addLog('Memory store skipped: topic and content are required.', 'error');
      return;
    }
    setState(() => _sectionLoading = true);
    try {
      final res = await _api.storeMemory(topic: topic, content: content);
      _memoryTopicController.clear();
      _memoryContentController.clear();
      _addLog("Memory stored: ${res['topic']}", 'ceo');
      await _loadMemory(silent: true);
    } catch (e) {
      _addLog('Memory store failed: $e', 'error');
    } finally {
      if (mounted) setState(() => _sectionLoading = false);
    }
  }

  Future<void> _loadSecurity() async {
    setState(() => _sectionLoading = true);
    try {
      final data = await _api.getSecurityPosture();
      if (!mounted) return;
      setState(() => _securityData = data);
    } catch (e) {
      _addLog('Security load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => _sectionLoading = false);
    }
  }

  Future<void> _loadSystem() async {
    setState(() => _sectionLoading = true);
    try {
      final data = await _api.getSystemInfo();
      if (!mounted) return;
      setState(() => _systemData = data);
    } catch (e) {
      _addLog('System load failed: $e', 'error');
    } finally {
      if (mounted) setState(() => _sectionLoading = false);
    }
  }


  // =========================================================
  // SESSIONS PANEL — full governance registry of fleet sessions
  // =========================================================
}
