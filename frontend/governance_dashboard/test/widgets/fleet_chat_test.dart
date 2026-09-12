// Widget tests for FleetChat (lib/widgets/fleet_chat.dart).
//
// Covers: chat bubble rendering, Repo Decision Gate banner (b9a6863),
// gate option dispatch + custom_idea/skip filtering, architecture doc link,
// send flow (SEND button, empty-input guard), and the PURE IDEA toggle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:governance_dashboard/widgets/fleet_chat.dart';

Widget _wrap({
  required Map<String, dynamic> pendingGate,
  List<Map<String, dynamic>> messages = const [],
  bool isLoading = false,
  void Function(String)? onSend,
  void Function(String)? onLaunchUrl,
  void Function(String, String)? onGateDecision,
  void Function(bool)? onPureIdeaModeChanged,
  bool pureIdeaMode = false,
  String architectureDocUrl = '',
}) {
  return MaterialApp(
    home: Scaffold(
      body: FleetChat(
        messages: messages,
        pendingGate: pendingGate,
        isLoading: isLoading,
        onGateDecision: onGateDecision ?? (_, __) {},
        onSend: onSend ?? (_) {},
        activeOpportunity: const {},
        ideaA: const {},
        ideaB: const {},
        onApproveConcept: (
          _,
          __, {
          String? decisionChoiceOverride,
          String? feedback,
        }) {},
        onLaunchUrl: onLaunchUrl ?? (_) {},
        pureIdeaMode: pureIdeaMode,
        onPureIdeaModeChanged: onPureIdeaModeChanged ?? (_) {},
        architectureDocUrl: architectureDocUrl,
      ),
    ),
  );
}

Map<String, dynamic> _repoGate({
  Map<String, dynamic>? existingRepo,
  String gate = 'repo_decision',
  List<Map<String, dynamic>>? options,
  Map<String, dynamic>? architecture,
}) {
  return {
    'gate': gate,
    'prompt': 'Repository already exists. Decide how to proceed.',
    'options': options ??
        const [
          {'value': 'reuse', 'label': 'Reuse existing repo'},
        ],
    'metadata': {
      'gate': gate,
      if (existingRepo != null) 'existing_repo': existingRepo,
      if (architecture != null) 'architecture': architecture,
    },
  };
}

void main() {
  testWidgets('renders header and chat messages', (tester) async {
    await tester.pumpWidget(_wrap(
      pendingGate: const {},
      messages: const [
        {'type': 'system', 'time': '12:00', 'msg': 'Fleet online'},
        {'type': 'ceo', 'time': '12:01', 'msg': 'Build the thing'},
      ],
    ));

    expect(find.text('CEO CONVERSATION & WORKFLOW STREAM'), findsOneWidget);
    expect(find.text('Fleet online'), findsOneWidget);
    expect(find.text('Build the thing'), findsOneWidget);
    expect(find.text('SEND'), findsOneWidget);
  });

  testWidgets('SEND dispatches trimmed text and clears the input',
      (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_wrap(pendingGate: const {}, onSend: sent.add));

    await tester.enterText(find.byType(TextField), '  spin up the fleet  ');
    await tester.tap(find.text('SEND'));

    expect(sent, ['spin up the fleet']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('empty or whitespace-only input is not sent', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_wrap(pendingGate: const {}, onSend: sent.add));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('SEND'));

    expect(sent, isEmpty);
  });

  testWidgets('repo_decision gate shows existing repo banner', (tester) async {
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(existingRepo: {
        'repo_name': 'acme/fleet-service',
        'web_url': 'https://gitlab.example.com/acme/fleet-service',
      }),
    ));

    expect(find.text('REPO DECISION'), findsOneWidget);
    expect(find.text('Existing repository found:'), findsOneWidget);
    expect(find.text('acme/fleet-service'), findsOneWidget);
    expect(
      find.text('https://gitlab.example.com/acme/fleet-service'),
      findsOneWidget,
    );
  });

  testWidgets('tapping repo web_url fires onLaunchUrl', (tester) async {
    String? launched;
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(existingRepo: {
        'repo_name': 'acme/fleet-service',
        'web_url': 'https://gitlab.example.com/acme/fleet-service',
      }),
      onLaunchUrl: (url) => launched = url,
    ));

    await tester.tap(
      find.text('https://gitlab.example.com/acme/fleet-service'),
    );
    expect(launched, 'https://gitlab.example.com/acme/fleet-service');
  });

  testWidgets('repo banner falls back to pendingGate.existing_repo',
      (tester) async {
    final gate = _repoGate();
    gate['existing_repo'] = {
      'repo_name': 'fallback/repo',
      'web_url': 'https://gitlab.example.com/fallback/repo',
    };
    await tester.pumpWidget(_wrap(pendingGate: gate));

    expect(find.text('Existing repository found:'), findsOneWidget);
    expect(find.text('fallback/repo'), findsOneWidget);
    expect(
      find.text('https://gitlab.example.com/fallback/repo'),
      findsOneWidget,
    );
  });

  testWidgets('no banner for non repo_decision gates', (tester) async {
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(
        gate: 'approval',
        existingRepo: {'repo_name': 'x/y', 'web_url': 'https://e.com/x/y'},
      ),
    ));

    expect(find.text('Existing repository found:'), findsNothing);
  });

  testWidgets('option button dispatches onGateDecision(value, "")',
      (tester) async {
    final decisions = <String>[];
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(options: const [
        {'value': 'approve_reuse', 'label': 'Reuse it'},
        {'value': 'new_repo', 'label': 'Create new repo'},
      ]),
      onGateDecision: (decision, feedback) {
        decisions.add('$decision|$feedback');
      },
    ));

    await tester.tap(find.text('Reuse it'));
    expect(decisions, ['approve_reuse|']);
  });

  testWidgets('custom_idea and skip_implementation options are filtered out',
      (tester) async {
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(options: const [
        {'value': 'approve_build', 'label': 'Approve build'},
        {'value': 'custom_idea', 'label': 'Custom idea'},
        {'value': 'skip_implementation', 'label': 'Skip'},
      ]),
    ));

    expect(find.text('Approve build'), findsOneWidget);
    expect(find.text('Custom idea'), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('gate option buttons are disabled while loading',
      (tester) async {
    await tester.pumpWidget(_wrap(pendingGate: _repoGate(), isLoading: true));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Reuse existing repo'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('SEND is disabled while loading', (tester) async {
    await tester.pumpWidget(_wrap(pendingGate: const {}, isLoading: true));

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('architecture doc link is hidden when URL is empty',
      (tester) async {
    await tester.pumpWidget(_wrap(pendingGate: _repoGate()));

    expect(find.text('View full architecture doc'), findsNothing);
  });

  testWidgets('architecture doc link launches architectureDocUrl',
      (tester) async {
    String? launched;
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(),
      architectureDocUrl: 'https://gitlab.example.com/acme/-/blob/ARCH.md',
      onLaunchUrl: (url) => launched = url,
    ));

    await tester.tap(find.text('View full architecture doc'));
    expect(launched, 'https://gitlab.example.com/acme/-/blob/ARCH.md');
  });

  testWidgets('architecture summary renders title/compute/components',
      (tester) async {
    await tester.pumpWidget(_wrap(
      pendingGate: _repoGate(architecture: {
        'title': 'Fleet Orchestrator',
        'compute_target': 'cloud-run',
        'components': ['api', 'worker', 'dashboard'],
      }),
    ));

    expect(find.textContaining('Title: Fleet Orchestrator'), findsOneWidget);
    expect(find.textContaining('Compute: cloud-run'), findsOneWidget);
    expect(
      find.textContaining('Components: api, worker, dashboard'),
      findsOneWidget,
    );
  });

  testWidgets('PURE IDEA tap fires onPureIdeaModeChanged(true)',
      (tester) async {
    bool? next;
    await tester.pumpWidget(_wrap(
      pendingGate: const {},
      onPureIdeaModeChanged: (v) => next = v,
    ));

    await tester.tap(find.text('PURE IDEA — no hackathon context'));
    expect(next, isTrue);
  });

  testWidgets('active PURE IDEA mode shows filled bulb and toggles off',
      (tester) async {
    bool? next;
    await tester.pumpWidget(_wrap(
      pendingGate: const {},
      pureIdeaMode: true,
      onPureIdeaModeChanged: (v) => next = v,
    ));

    expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing);

    await tester.tap(find.text('PURE IDEA — no hackathon context'));
    expect(next, isFalse);
  });
}
