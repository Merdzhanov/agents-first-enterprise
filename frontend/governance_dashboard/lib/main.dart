import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final List<Map<String, dynamic>> _logs = [
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
      final result = await _api.triggerDiscovery();
      final message = result['message'] ?? 'Vertex AI synthesized 2 proposals.';
      setState(() {
        _isLoading = false;
        _statusText = 'CEO Proposal Gate: Review Concepts & Confirm Provider/Project Name';
      });
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

  void _approveConcept(String conceptName, String defaultRepo) async {
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

    final decisionChoice = conceptName.contains('EphemeraFlow')
        ? 'approve_idea_a'
        : conceptName.contains('ArmorGuard')
            ? 'approve_idea_b'
            : 'custom_idea';

    final Map<String, dynamic> result;
    try {
      result = await _api.submitCeoDecision(
        sessionId: 'session_governance_001',
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

          // Main Layout Area (68% Main + 32% Logs)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Content (68%)
                Expanded(
                  flex: 68,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Git Target Bar
                        _buildGitTargetBar(),
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
                  ),
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
        const Text(
          'CEO Proposal Gate',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD4E4FA),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Concept A
            Expanded(
              child: _buildConceptCard(
                conceptTag: 'Concept A',
                title: 'EphemeraFlow: Governed Multi-Agent Fleet',
                description:
                    'Hybrid polyglot architecture emphasizing rapid scale-out and tear-down capabilities with Dart Shelf workers on Cloud Run.',
                chips: ['Google ADK 2.0', 'Dart Shelf', 'Cloud Run'],
                targetImpact: '99.9% Uptime',
                impactColor: const Color(0xFF34D399),
                gradientColors: [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
                btnText: 'Approve Concept A',
                onApprove: () => _approveConcept(
                    'EphemeraFlow: Governed Multi-Agent Fleet',
                    'ephemeraflow-governed-fleet'),
              ),
            ),
            const SizedBox(width: 16),

            // Concept B
            Expanded(
              child: _buildConceptCard(
                conceptTag: 'Concept B',
                title: 'ArmorGuard: Row-Level Secure Multi-Tenant Hub',
                description:
                    'Privacy-first architecture ensuring strict data isolation across tenant boundaries with Vertex AI Model Armor.',
                chips: ['Vertex AI Gemini', 'Cloud SQL RLS', 'Model Armor'],
                targetImpact: 'Zero Cross-Tenant Leaks',
                impactColor: const Color(0xFFC084FC),
                gradientColors: [const Color(0xFF9333EA), const Color(0xFFD946EF)],
                btnText: 'Approve Concept B',
                onApprove: () => _approveConcept(
                    'ArmorGuard: Row-Level Secure Multi-Tenant Hub',
                    'armorguard-secure-agent-hub'),
              ),
            ),
          ],
        ),
      ],
    );
  }

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
}
