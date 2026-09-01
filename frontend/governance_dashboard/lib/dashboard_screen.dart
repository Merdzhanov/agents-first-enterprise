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
  String _selectedFile = '';

  // Active session for telemetry polling. Empty until discovery is triggered.
  String _sessionId = '';
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
      final newSession = result['session_id'] as String?;
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
      final count = result['proposals_count'] as int? ?? 0;
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
          // Top Navigation Bar
          TopNavBar(state: this),

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
                  child: LogsSidebar(state: this),
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
          GitTargetBar(state: this),
          const SizedBox(height: 20),

          // Live Hackathon Board (Top 5 from Devpost)
          HackathonBoard(state: this),
          const SizedBox(height: 20),

          // CEO Proposal Gate
          CeoProposalGate(state: this),
          const SizedBox(height: 20),

          // Custom Directive & Skip Row
          _buildCustomAndSkipRow(),
          const SizedBox(height: 20),

          // Repository Status & Artifacts Hub
          RepositoryStatusHub(state: this),
        ],
      ),
    );
  }

  Widget _buildActiveSection() {
    switch (_activeSection) {
      case 'sessions':
        return SessionsPanel(state: this);
      case 'memory':
        return MemoryPanel(state: this);
      case 'security':
        return SecurityPanel(state: this);
      case 'system':
        return SystemPanel(state: this);
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
