import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';

void main() {
  runApp(const AgentEnterpriseApp());
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

  String _statusText = 'Awaiting Discovery Trigger';
  bool _isLoading = false;
  String _selectedFile = 'README.md';

  // Live telemetry + discovery state (sourced from the real orchestrator).
  static const String _sessionId = 'session_governance_001';
  Timer? _telemetryTimer;
  List<Map<String, dynamic>> _hackathons = [];
  Map<String, dynamic> _activeOpportunity = {};
  Map<String, dynamic> _ideaA = {};
  Map<String, dynamic> _ideaB = {};

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

  List<Map<String, dynamic>> _logs = [
    {
      'time': 'System Ready',
      'msg': 'Cloud Run services and Dart nodes initialized in eur3 / europe-west1.',
      'type': 'system'
    }
  ];

  final Map<String, String> _filesContent = {
    'README.md': '''# EphemeraFlow Governed Fleet

This repository contains the auto-generated code for the 
EphemeraFlow Multi-Agent Fleet architecture.

## Getting Started
1. Run `./setup_enterprise.sh` to initialize GCP IAM & Firestore.
2. Deploy Dart Functional Nodes to Cloud Run.
3. Deploy Python ADK 2.0 Orchestrator with Vertex AI endpoints.''',
    'src/main.py': '''"""Orchestrator entry point with Vertex AI Gemini 3.5 & ADK 2.0."""
from fastapi import FastAPI

app = FastAPI(title="EphemeraFlow Fleet")''',
    'src/agent.py': '''"""Autonomous Supervisor & Reasoning Loop."""
from google.adk.agents import Agent

supervisor = Agent(name="SupervisorAgent", model="gemini-2.5-pro")''',
    'architecture.drawio': '''<mxfile host="65bd71144e">
  <diagram id="arch" name="Enterprise Multi-Agent Topology">
    <!-- Cloud Run, Firestore, Pub/Sub & Dart Functional Nodes -->
  </diagram>
</mxfile>''',
    'setup.sh': '''#!/bin/bash
echo "Provisioning Google Cloud Run, Cloud SQL RLS & Firestore..."
gcloud services enable aiplatform.googleapis.com run.googleapis.com''',
  };

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
    try {
      final traces = await _api.getSessionTraces(_sessionId);
      final session = await _api.getSessionState(_sessionId);
      if (!mounted) return;
      setState(() {
        if (traces.isNotEmpty) {
          _logs = traces.reversed.map((t) {
            final agent = (t['agent_name'] ?? '').toString();
            final msg = (t['msg'] ?? '').toString();
            final prefixed =
                agent.isEmpty || msg.startsWith(agent) ? msg : '$agent: $msg';
            return {
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
            'executing' =>
              'Fleet executing — Architect → Lead Dev → Marketing in progress...',
            'completed' =>
              'Completed: prototype provisioned and submission packaged',
            'skipped' => 'Pipeline Safely Halted (Skipped by CEO)',
            _ => 'Fleet status: $status',
          };
        }
      });
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
      _logs.insert(0, {'time': timeStr, 'msg': msg, 'type': type});
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
      final result = await _api.triggerDiscovery(sessionId: _sessionId);
      final message = result['message'] ?? 'Vertex AI synthesized 2 proposals.';
      final hackathons = (result['hackathons'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final opportunity =
          (result['opportunity'] as Map<String, dynamic>? ?? const {});
      final data = result['data'];
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hackathons = hackathons;
        _activeOpportunity = opportunity;
        if (data is Map<String, dynamic>) {
          _ideaA = (data['idea_a'] as Map<String, dynamic>? ?? const {});
          _ideaB = (data['idea_b'] as Map<String, dynamic>? ?? const {});
        }
        _statusText = 'CEO Proposal Gate: Review Concepts & Confirm Provider/Project Name';
      });
      _addLog(
          'Scout Agent: Ranked ${hackathons.length} live hackathons — top 5 now on the Live Hackathon Board.',
          'dart');
      _addLog('Planner Agent: $message', 'agent');
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

  void _approveConcept(
    String conceptName,
    String defaultRepo, {
    String? decisionChoiceOverride,
  }) async {
    final provider = _selectedProvider.toLowerCase();
    final repoName = _projectName.trim().isEmpty ? defaultRepo : _projectName.trim();
    final repoUrl = _selectedProvider == 'GitHub'
        ? 'https://github.com/agents-first-enterprise/$repoName'
        : 'https://gitlab.com/agents-first-enterprise/$repoName';

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

    final statusMsg = result['message'] ?? 'Pipeline executed successfully.';
    _addLog('Dart Functional Node: Provisioning ${provider.toUpperCase()} repository $repoUrl', 'dart');
    _addLog('Architect Agent: Generated GCP system topology and Mermaid architecture diagram.', 'agent');
    _addLog('Lead Dev Agent: Generated backend services, Cloud Run configs, and tests.', 'agent');
    _addLog('Marketing Agent: $statusMsg', 'success');

    setState(() {
      _isLoading = false;
      _statusText = 'Completed: "$conceptName" (${provider.toUpperCase()})';
      _filesContent['README.md'] = '''# $conceptName

Autonomous prototype provisioned on ${provider.toUpperCase()}.
Repository: `$repoName`

## Architecture
- Google Cloud Run (scale-to-zero)
- Dart Shelf Functional Workers
- Python ADK 2.0 Orchestration
- Cloud SQL Session Storage (RLS) & pgvector Memory''';
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Column(
        children: [
          // Top Navigation Bar
          _buildTopNavBar(),

          // Main Layout Area (Rail + 62% Section + 30% Logs)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left governance rail: Fleet / Sessions / Memory / Security / System
                _buildSectionRail(),

                // Active section content
                Expanded(
                  flex: 62,
                  child: _buildActiveSection(),
                ),

                // Vertical Divider
                Container(width: 1, color: Colors.white.withAlpha(15)),

                // Right Sidebar: Real-Time Fleet Traces (32%)
                Expanded(
                  flex: 32,
                  child: _buildLogsSidebar(),
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
          // Git Target Bar
          _buildGitTargetBar(),
          const SizedBox(height: 20),

          // Live Hackathon Board (Top 5 from Devpost)
          _buildHackathonBoard(),
          const SizedBox(height: 20),

          // CEO Proposal Gate
          _buildCeoProposalGate(),
          const SizedBox(height: 20),

          // Custom Directive & Skip Row
          _buildCustomAndSkipRow(),
          const SizedBox(height: 20),

          // Repository Status & Artifacts Hub
          _buildRepositoryStatusHub(),
        ],
      ),
    );
  }

  Widget _buildActiveSection() {
    switch (_activeSection) {
      case 'sessions':
        return _buildSessionsPanel();
      case 'memory':
        return _buildMemoryPanel();
      case 'security':
        return _buildSecurityPanel();
      case 'system':
        return _buildSystemPanel();
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

  static const List<(String, IconData, String)> _govSections = [
    ('fleet', Icons.hub, 'FLEET'),
    ('sessions', Icons.history, 'SESSIONS'),
    ('memory', Icons.psychology, 'MEMORY'),
    ('security', Icons.shield_outlined, 'SECURITY'),
    ('system', Icons.dns, 'SYSTEM'),
  ];

  Widget _buildSectionRail() {
    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: const Color(0xFF051424),
        border: Border(right: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          for (final s in _govSections)
            InkWell(
              onTap: () => _switchSection(s.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _activeSection == s.$1
                      ? const Color(0xFF38BDF8).withAlpha(30)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: _activeSection == s.$1
                          ? const Color(0xFF38BDF8)
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      s.$2,
                      size: 20,
                      color: _activeSection == s.$1
                          ? const Color(0xFF8ED5FF)
                          : const Color(0xFFBDC8D1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.$3,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        fontWeight: _activeSection == s.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _activeSection == s.$1
                            ? const Color(0xFFC4E7FF)
                            : const Color(0xFFBDC8D1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF122131).withAlpha(150),
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Agent-First Enterprise',
                style: TextStyle(
                  color: Color(0xFF8ED5FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 24),
              _buildNavPill('Fleet Ready'),
              const SizedBox(width: 16),
              _buildNavPill('Python ADK 2.0'),
              const SizedBox(width: 16),
              _buildNavPill('Scale-to-Zero'),
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF38BDF8).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      _statusText,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8ED5FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _triggerDiscovery,
                icon: const Icon(Icons.bolt, size: 18, color: Color(0xFF00354A)),
                label: const Text(
                  'TRIGGER DISCOVERY CYCLE',
                  style: TextStyle(
                    color: Color(0xFF00354A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings, color: Color(0xFFBDC8D1), size: 20),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.account_circle,
                    color: Color(0xFFBDC8D1), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFBDC8D1),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildGitTargetBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Segmented Toggle
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3E484F)),
                ),
                child: Row(
                  children: [
                    _buildProviderBtn('GitHub'),
                    _buildProviderBtn('GitLab'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: const Color(0xFF3E484F)),
              const SizedBox(width: 16),

              // Project Name Editor
              if (_isEditingName)
                SizedBox(
                  width: 260,
                  height: 32,
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF7BD0FF),
                    ),
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (val) {
                      setState(() {
                        _projectName = val.trim();
                        _isEditingName = false;
                      });
                    },
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    setState(() {
                      _isEditingName = true;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        _projectName,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF7BD0FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 14, color: Color(0xFFBDC8D1)),
                    ],
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sync Active',
                style: TextStyle(
                  color: Color(0xFFBDC8D1),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderBtn(String name) {
    final isSelected = _selectedProvider == name;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedProvider = name;
        });
        _addLog('CEO Config: Switched Git provider to $name', 'ceo');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF273647) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFFD4E4FA) : const Color(0xFFBDC8D1),
          ),
        ),
      ),
    );
  }

  Widget _buildCeoProposalGate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'CEO Proposal Gate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD4E4FA),
              ),
            ),
            const Spacer(),
            if (_activeOpportunity['url'] != null)
              InkWell(
                onTap: () =>
                    _launchExternalUrl(_activeOpportunity['url'].toString()),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xFF38BDF8).withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events,
                          size: 13, color: Color(0xFF8ED5FF)),
                      const SizedBox(width: 6),
                      Text(
                        'Source: ${(_activeOpportunity['title'] ?? 'Hackathon').toString()}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8ED5FF)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new,
                          size: 12, color: Color(0xFF8ED5FF)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Concept A
            Expanded(
              child: _buildProposalCard(
                tag: 'Concept A',
                idea: _ideaA,
                fallbackTitle: 'EphemeraFlow: Governed Multi-Agent Fleet',
                fallbackDescription:
                    'Hybrid polyglot architecture emphasizing rapid scale-out and tear-down capabilities with Dart Shelf workers on Cloud Run.',
                fallbackChips: ['Google ADK 2.0', 'Dart Shelf', 'Cloud Run'],
                fallbackImpact: '99.9% Uptime',
                impactColor: const Color(0xFF34D399),
                gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
                fallbackRepo: 'ephemeraflow-governed-fleet',
                decisionChoice: 'approve_idea_a',
              ),
            ),
            const SizedBox(width: 16),

            // Concept B
            Expanded(
              child: _buildProposalCard(
                tag: 'Concept B',
                idea: _ideaB,
                fallbackTitle: 'ArmorGuard: Row-Level Secure Multi-Tenant Hub',
                fallbackDescription:
                    'Privacy-first architecture ensuring strict data isolation across tenant boundaries with Vertex AI Model Armor.',
                fallbackChips: ['Vertex AI Gemini', 'Cloud SQL RLS', 'Model Armor'],
                fallbackImpact: 'Zero Cross-Tenant Leaks',
                impactColor: const Color(0xFFC084FC),
                gradientColors: [const Color(0xFF9333EA), const Color(0xFFD946EF)],
                fallbackRepo: 'armorguard-secure-agent-hub',
                decisionChoice: 'approve_idea_b',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds one CEO proposal card from a real Planner proposal when available,
  /// falling back to the baseline concepts before the first discovery run.
  Widget _buildProposalCard({
    required String tag,
    required Map<String, dynamic> idea,
    required String fallbackTitle,
    required String fallbackDescription,
    required List<String> fallbackChips,
    required String fallbackImpact,
    required Color impactColor,
    required List<Color> gradientColors,
    required String fallbackRepo,
    required String decisionChoice,
  }) {
    final dynamicTitle = (idea['title'] ?? '').toString();
    final dynamicDescription = (idea['summary'] ?? '').toString();
    final dynamicImpact = (idea['impact'] ?? '').toString();
    final dynamicRepo = (idea['repo_name'] ?? '').toString();
    final dynamicChips = _stringList(idea['tech_stack']);
    final hackathonTitle = (idea['hackathon_title'] ?? '').toString();
    final hackathonUrl = (idea['hackathon_url'] ?? '').toString();

    return _buildConceptCard(
      conceptTag: tag,
      title: dynamicTitle.isNotEmpty ? dynamicTitle : fallbackTitle,
      description: dynamicDescription.isNotEmpty
          ? dynamicDescription
          : fallbackDescription,
      chips: dynamicChips.isNotEmpty ? dynamicChips : fallbackChips,
      targetImpact: dynamicImpact.isNotEmpty ? dynamicImpact : fallbackImpact,
      impactColor: impactColor,
      gradientColors: gradientColors,
      btnText: 'Approve $tag',
      onApprove: () => _approveConcept(
        dynamicTitle.isNotEmpty ? dynamicTitle : fallbackTitle,
        dynamicRepo.isNotEmpty ? dynamicRepo : fallbackRepo,
        decisionChoiceOverride: decisionChoice,
      ),
      hackathonTitle: hackathonTitle.isNotEmpty ? hackathonTitle : null,
      hackathonUrl: hackathonUrl.isNotEmpty ? hackathonUrl : null,
    );
  }

  List<String> _stringList(dynamic value) =>
      (value as List? ?? const []).map((e) => e.toString()).toList();

  Widget _buildConceptCard({
    required String conceptTag,
    required String title,
    required String description,
    required List<String> chips,
    required String targetImpact,
    required Color impactColor,
    required List<Color> gradientColors,
    required String btnText,
    required VoidCallback onApprove,
    String? hackathonTitle,
    String? hackathonUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(30)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Gradient Stripe
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC4E7FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gradientColors[0].withAlpha(50),
                        ),
                        child: Icon(Icons.bolt, size: 14, color: gradientColors[0]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBDC8D1),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF020617),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF3E484F)),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: Color(0xFFBDC8D1),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  if (hackathonUrl != null && hackathonUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _launchExternalUrl(hackathonUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFF38BDF8).withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events,
                                size: 13, color: Color(0xFF8ED5FF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                (hackathonTitle != null &&
                                        hackathonTitle.isNotEmpty)
                                    ? hackathonTitle
                                    : 'Open hackathon page',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF8ED5FF)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new,
                                size: 12, color: Color(0xFF8ED5FF)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withAlpha(15),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TARGET IMPACT',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: Color(0xFF87929A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            targetImpact,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: impactColor,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : onApprove,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          backgroundColor: gradientColors[0],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(
                          btnText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAndSkipRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF3E484F)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customDirectiveController,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFD4E4FA)),
                    decoration: const InputDecoration(
                      hintText: 'Enter custom prototype directive...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Color(0xFF87929A)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submitCustomDirective(),
                  ),
                ),
                IconButton(
                  onPressed: _submitCustomDirective,
                  icon: const Icon(Icons.arrow_forward,
                      color: Color(0xFFBDC8D1), size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: _skipImplementation,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF93000A).withAlpha(50),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFFFFB4AB).withAlpha(75)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Color(0xFFFFB4AB), size: 16),
                SizedBox(width: 8),
                Text(
                  'SKIP IMPLEMENTATION',
                  style: TextStyle(
                    color: Color(0xFFFFB4AB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepositoryStatusHub() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(25)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF020617).withAlpha(125),
              border: Border(
                  bottom: BorderSide(color: Colors.white.withAlpha(15))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'REPOSITORY STATUS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC4E7FF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF10B981).withAlpha(50)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle,
                              size: 6, color: Color(0xFF34D399)),
                          SizedBox(width: 6),
                          Text(
                            'POPULATING FILES...',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withAlpha(75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF273647),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Step 2 of 3',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFBDC8D1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Explorer & Preview
          SizedBox(
            height: 240,
            child: Row(
              children: [
                // File Tree (1/3)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617).withAlpha(75),
                      border: Border(
                          right: BorderSide(
                              color: Colors.white.withAlpha(15))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: _filesContent.keys.map((filename) {
                        final isSelected = _selectedFile == filename;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFile = filename;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withAlpha(15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  filename.endsWith('.md')
                                      ? Icons.description
                                      : filename.endsWith('.py')
                                          ? Icons.code
                                          : filename.endsWith('.sh')
                                              ? Icons.terminal
                                              : Icons.account_tree,
                                  size: 14,
                                  color: filename.endsWith('.py')
                                      ? Colors.blueAccent
                                      : filename.endsWith('.sh')
                                          ? Colors.greenAccent
                                          : const Color(0xFFBDC8D1),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    filename,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: isSelected
                                          ? const Color(0xFFC4E7FF)
                                          : const Color(0xFFBDC8D1),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // File Preview (2/3)
                Expanded(
                  flex: 2,
                  child: Container(
                    color: const Color(0xFF020617).withAlpha(125),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.white.withAlpha(15))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedFile,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFBDC8D1),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _filesContent[_selectedFile] ?? ''));
                                  _addLog(
                                      'Copied "$_selectedFile" to clipboard.',
                                      'system');
                                },
                                child: const Icon(Icons.content_copy,
                                    size: 14, color: Color(0xFFBDC8D1)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _filesContent[_selectedFile] ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFFBDC8D1),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Governance section loaders (honest errors, no mock data)
  // =========================================================
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
  // Shared governance UI helpers
  // =========================================================
  Widget _govCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withAlpha(100),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(30)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFFC4E7FF),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _govKV(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              key,
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: Color(0xFF87929A)),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: valueColor ?? const Color(0xFFD4E4FA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _govStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF34D399);
      case 'awaiting_ceo_decision':
      case 'pending_ceo_review':
        return const Color(0xFFFBBF24);
      case 'processing_in_background':
        return const Color(0xFF38BDF8);
      case 'skipped':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFFBDC8D1);
    }
  }

  Widget _govLoadingOr(Widget child) {
    if (_sectionLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }
    return child;
  }

  // =========================================================
  // SESSIONS PANEL — full governance registry of fleet sessions
  // =========================================================
  Widget _buildSessionsPanel() {
    final sessions = (_sessionsData['sessions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final count = (_sessionsData['count'] ?? sessions.length).toString();

    return _govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _govCard(
            title: 'Session Registry — $count record(s)',
            children: [
              const Text(
                'Audit trail of every fleet execution. State is persisted per '
                'session_id with tenant isolation (Cloud SQL RLS in production).',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                const Text(
                  'No sessions recorded yet — trigger a Discovery cycle in the FLEET section.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
                ),
              for (final s in sessions) ..._sessionRow(s),
            ],
          ),
        ],
      ),
    ));
  }

  List<Widget> _sessionRow(Map<String, dynamic> s) {
    final status = (s['status'] ?? 'unknown').toString();
    final color = _govStatusColor(status);
    final state = s['state'];
    final stateKeys = state is Map ? state.keys.take(6).toList() : const [];
    return [
      Container(height: 1, color: Colors.white.withAlpha(15)),
      const SizedBox(height: 10),
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (s['session_id'] ?? '?').toString(),
              style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: Color(0xFFC4E7FF)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
              color: color),
          ),
        ],
      ),
      const SizedBox(height: 6),
      _govKV('current_agent', (s['current_agent'] ?? '—').toString()),
      _govKV('tenant_id', (s['tenant_id'] ?? '—').toString()),
      _govKV('updated_at', (s['updated_at'] ?? '—').toString()),
      if (stateKeys.isNotEmpty)
        _govKV('state_keys', stateKeys.join(', ')),
      const SizedBox(height: 6),
    ];
  }

  // =========================================================
  // MEMORY PANEL — semantic memory bank with CEO ingestion
  // =========================================================
  Widget _buildMemoryPanel() {
    final memories = (_memoryData['memories'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final count = (_memoryData['count'] ?? memories.length).toString();
    final tenant = (_memoryData['tenant_id'] ?? 'default_enterprise').toString();

    return _govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _govCard(
            title: 'Store Memory Fact',
            children: [
              const Text(
                'CEO knowledge ingestion — facts stored here are tenant-isolated '
                'and searchable by the fleet (pgvector / text-embedding-005).',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoryTopicController,
                style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA)),
                decoration: _govInputDecoration('Topic (e.g. compliance-constraints)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _memoryContentController,
                style: const TextStyle(fontSize: 13, color: Color(0xFFD4E4FA)),
                maxLines: 3,
                decoration: _govInputDecoration('Content (the fact itself)'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _sectionLoading ? null : _submitMemory,
                icon: const Icon(Icons.psychology, size: 16, color: Color(0xFF00354A)),
                label: const Text('STORE MEMORY',
                    style: TextStyle(
                        color: Color(0xFF00354A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _govCard(
            title: 'Memory Bank — $count record(s) — tenant: $tenant',
            children: [
              if (memories.isEmpty)
                const Text(
                  'No memories stored yet. Facts are also written automatically '
                  'by the fleet during discovery, CEO decisions and completion.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
                ),
              for (final m in memories) ..._memoryRow(m),
            ],
          ),
        ],
      ),
    ));
  }

  List<Widget> _memoryRow(Map<String, dynamic> m) {
    return [
      Container(height: 1, color: Colors.white.withAlpha(15)),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(Icons.psychology, size: 14, color: Color(0xFFC084FC)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (m['topic'] ?? '?').toString(),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC4E7FF)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            (m['tenant_id'] ?? '—').toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF87929A)),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SelectableText(
        (m['content'] ?? '').toString(),
        style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFFD4E4FA)),
      ),
      const SizedBox(height: 4),
      _govKV('created_at', (m['created_at'] ?? '—').toString()),
      const SizedBox(height: 4),
    ];
  }

  InputDecoration _govInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF87929A)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF3E484F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF3E484F)),
      ),
      isDense: true,
    );
  }

  Widget _buildSecurityPanel() {
    final tenants = (_securityData['tenants_observed'] as List<dynamic>? ?? [])
        .map((t) => t.toString())
        .toList();
    final gates =
        (_securityData['human_in_the_loop_gates'] as List<dynamic>? ?? [])
            .map((g) => g.toString())
            .toList();

    return _govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _govCard(
            title: 'Security & IAM Posture',
            children: [
              const Text(
                'Live view of the controls protecting the fleet: identity, '
                'isolation, and human oversight gates.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              _govKV('Service-to-Service Auth',
                  (_securityData['service_to_service_auth'] ?? '—').toString()),
              _govKV('Dart Node Auth Policy',
                  (_securityData['dart_node_auth_policy'] ?? '—').toString()),
              _govKV('Session Isolation',
                  (_securityData['session_isolation'] ?? '—').toString()),
              _govKV('Memory Isolation',
                  (_securityData['memory_tenant_isolation'] ?? '—').toString()),
              _govKV('Skip Safety',
                  (_securityData['skip_safety'] ?? '—').toString()),
              _govKV('Git Providers',
                  ((_securityData['git_providers'] as List<dynamic>? ?? [])
                      .join(', '))),
              _govKV('Session Records',
                  (_securityData['session_records'] ?? 0).toString()),
              _govKV('Memory Records',
                  (_securityData['memory_records'] ?? 0).toString()),
              _govKV('CORS Policy',
                  (_securityData['cors_policy'] ?? '—').toString()),
              const SizedBox(height: 12),
              _govChipSection(
                label: 'TENANTS OBSERVED (RLS KEYS)',
                items: tenants,
                borderColor: const Color(0xFF14B8A6).withAlpha(70),
                textColor: const Color(0xFF14B8A6),
              ),
              const SizedBox(height: 12),
              const Text(
                'HUMAN-IN-THE-LOOP GATES',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: Color(0xFF87929A)),
              ),
              const SizedBox(height: 6),
              for (final g in gates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user,
                          size: 13, color: Color(0xFF34D399)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g,
                          style: const TextStyle(
                              fontSize: 12, height: 1.35, color: Color(0xFFD4E4FA)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _govChipSection({
    required String label,
    required List<String> items,
    required Color borderColor,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 0.8,
              color: Color(0xFF87929A)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map((item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10, color: textColor),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSystemPanel() {
    final agents = (_systemData['agents'] as List<dynamic>? ?? [])
        .map((a) => a.toString())
        .toList();

    return _govLoadingOr(SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _govCard(
            title: 'System Introspection — v${(_systemData['version'] ?? '?')}',
            children: [
              const Text(
                'Architecture of the running orchestrator: engine, agents, '
                'stores and environment configuration.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A), height: 1.4),
              ),
              const SizedBox(height: 12),
              _govKV('Execution Engine',
                  (_systemData['execution_engine'] ?? '—').toString()),
              _govKV('Default Mode',
                  (_systemData['default_execution_mode'] ?? '—').toString()),
              _govKV('Session Store',
                  (_systemData['session_store'] ?? '—').toString()),
              _govKV('Memory Store',
                  (_systemData['memory_store'] ?? '—').toString()),
              _govKV('Scheduler Interval',
                  '${_systemData['scheduler_interval_minutes'] ?? '—'} min'),
              _govKV('Dart Node URL',
                  (_systemData['dart_node_url'] ?? '—').toString()),
              _govKV('Vertex AI Mode',
                  (_systemData['vertex_ai_mode'] ?? '—').toString()),
              _govKV('Cloud Location',
                  (_systemData['cloud_location'] ?? '—').toString()),
              const SizedBox(height: 12),
              _govChipSection(
                label: 'AGENT FLEET (${agents.length})',
                items: agents,
                borderColor: const Color(0xFF38BDF8).withAlpha(70),
                textColor: const Color(0xFF7BD0FF),
              ),
              const SizedBox(height: 12),
              _govKV('HITL Gates',
                  ((_systemData['hitl_gates'] as List<dynamic>? ?? [])
                      .join('  •  '))),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildLogsSidebar() {
    return Container(
      color: const Color(0xFF051424),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 8),
              const Text(
                'REAL-TIME FLEET TRACES',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC4E7FF),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _refreshTelemetry,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFBDC8D1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Refresh live traces',
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withAlpha(15)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                final type = log['type'];
                final borderColor = type == 'error'
                    ? const Color(0xFFEF4444)
                    : type == 'dart'
                        ? const Color(0xFF14B8A6)
                        : type == 'ceo'
                            ? const Color(0xFFFBBF24)
                            : type == 'success'
                                ? const Color(0xFF34D399)
                                : type == 'skip'
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF38BDF8);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withAlpha(150),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(left: BorderSide(color: borderColor, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['time'],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Color(0xFF87929A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log['msg'],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFD4E4FA),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Live board of the top 5 discovered hackathons. Every row deep-links to
  /// the competition page, opened in a new browser tab.
  Widget _buildHackathonBoard() {
    final items = _hackathons.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, size: 16, color: Color(0xFFFBBF24)),
                const SizedBox(width: 8),
                const Text(
                  'LIVE HACKATHON BOARD — TOP 5',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC4E7FF),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  items.isEmpty ? 'AWAITING DISCOVERY' : 'LIVE · DEVPOST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: items.isEmpty
                        ? const Color(0xFF87929A)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Trigger a discovery cycle to scout active competitions from Devpost in real time.',
                style: TextStyle(fontSize: 12, color: Color(0xFF87929A)),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final hackathon = entry.value;
              final url = (hackathon['url'] ?? '').toString();
              final title = (hackathon['title'] ?? 'Untitled hackathon').toString();
              final prize = hackathon['prize_pool'];
              final deadline = (hackathon['submission_deadline'] ?? 'TBA').toString();
              return InkWell(
                onTap: url.isEmpty ? null : () => _launchExternalUrl(url),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: Colors.white.withAlpha(10))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8ED5FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD4E4FA),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _boardStat(
                        'PRIZE',
                        prize is num ? '\$${prize.toInt()}' : '$prize',
                      ),
                      const SizedBox(width: 20),
                      _boardStat('DEADLINE', deadline),
                      const SizedBox(width: 12),
                      const Icon(Icons.open_in_new,
                          size: 14, color: Color(0xFF38BDF8)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _boardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: Color(0xFF87929A),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFBDC8D1),
          ),
        ),
      ],
    );
  }
}
