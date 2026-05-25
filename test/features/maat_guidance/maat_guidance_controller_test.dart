import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/maat_guidance_model.dart';
import 'package:mobile/data/maat_guidance_repo.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_controller.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test(
    'shown delivery remains visible after restart until terminal ack',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{
        'maat_guidance.lastShownDeliveryId': 'opening',
        'maat_guidance.lastShownPeriodKey': _periodKey,
      });
      final repo = _FakeMaatGuidanceRepo([
        _delivery(id: 'opening', status: MaatGuidanceStatus.shown),
      ]);
      final controller = MaatGuidanceController(repo);

      await controller.refresh(force: true);
      controller.updateSuppression(false);
      await pumpEventQueue();

      expect(controller.current?.id, 'opening');
      expect(repo.acks, isEmpty);
    },
  );

  test('dismiss advances immediately to next queued delivery', () async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(id: 'opening'),
      _delivery(id: 'drift', kind: MaatGuidanceKind.driftNudge, priority: 20),
    ]);
    final controller = MaatGuidanceController(repo);

    await controller.refresh(force: true);
    controller.updateSuppression(false);
    await pumpEventQueue();
    expect(controller.current?.id, 'opening');

    await controller.dismissCurrent();

    expect(controller.current?.id, 'drift');
    expect(repo.acks, <String>[
      'opening:shown',
      'opening:dismissed',
      'drift:shown',
    ]);
  });

  test('refresh updates same delivery when server enriches payload', () async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(id: 'opening', bodyText: 'Generic opening.'),
    ]);
    final controller = MaatGuidanceController(repo);

    await controller.refresh(force: true);
    expect(controller.current?.bodyText, 'Generic opening.');

    repo.replaceDelivery(
      _delivery(
        id: 'opening',
        bodyText: 'Opening with today card.',
        payload: const <String, dynamic>{'day_card_date': '2026-05-16'},
      ),
    );

    await controller.refresh(force: true);

    expect(controller.current?.id, 'opening');
    expect(controller.current?.bodyText, 'Opening with today card.');
    expect(controller.current?.payload['day_card_date'], '2026-05-16');
  });

  test('markActed clears current delivery and advances queue', () async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(id: 'drift', kind: MaatGuidanceKind.driftNudge, priority: 20),
      _delivery(
        id: 'strength',
        kind: MaatGuidanceKind.strengthNudge,
        priority: 30,
      ),
    ]);
    final controller = MaatGuidanceController(repo);

    await controller.refresh(force: true);
    controller.updateSuppression(false);
    await pumpEventQueue();
    final drift = controller.current;
    expect(drift?.id, 'drift');

    await controller.markActed(drift!);

    expect(controller.current?.id, 'strength');
    expect(repo.acks, <String>['drift:shown', 'drift:acted', 'strength:shown']);
  });

  testWidgets('detail CTA uses scoped controller and advances queue', (
    tester,
  ) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'drift',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.node,
        ctaRef: 'maat',
      ),
      _delivery(
        id: 'strength',
        kind: MaatGuidanceKind.strengthNudge,
        priority: 30,
      ),
    ]);
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/drift',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            final deliveryId = state.pathParameters['deliveryId']!;
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(deliveryId: deliveryId, repo: repo),
            );
          },
        ),
        GoRoute(
          path: '/nodes/:slug',
          builder: (context, state) => const Scaffold(body: Text('node')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(repo.acks, <String>['drift:opened']);
    expect(controller.current?.id, 'strength');

    await tester.tap(find.text('Open Node'));
    await tester.pumpAndSettle();

    expect(repo.acks, <String>['drift:opened', 'drift:acted']);
    expect(controller.current?.id, 'strength');
    expect(find.text('node'), findsOneWidget);
  });

  testWidgets('flow template CTA opens suggested template immediately', (
    tester,
  ) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'drift-template',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-offering-table',
        bodyText:
            'Tend to provision by restoring one check. Keep it small enough to finish today.',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/drift-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Ma’at Grounding'), findsWidgets);
    expect(find.text('Open suggested flow'), findsOneWidget);

    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates, hasLength(1));
    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-offering-table');
    expect(repo.acks, <String>[
      'drift-template:opened',
      'drift-template:acted',
    ]);
  });

  testWidgets('flow template CTA can open The Weighing', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'measure-template',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-weighing',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/measure-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-weighing');
  });

  testWidgets('flow template CTA can open The Tending', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'care-template',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-tending',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/care-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-tending');
  });

  testWidgets('flow template CTA can open The Kept Word', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'cohesion-template',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-kept-word',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/cohesion-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-kept-word');
  });

  testWidgets('flow template CTA can open The Course', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'rhythm-template',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-course',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/rhythm-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-course');
  });

  testWidgets('flow template CTA can open The Moon Return', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'moon-template',
        kind: MaatGuidanceKind.strengthNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-moon-return',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/moon-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-moon-return');
  });

  testWidgets('flow template CTA can open The Wag', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'wag-template',
        kind: MaatGuidanceKind.strengthNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-wag',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/wag-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-wag');
  });

  testWidgets('flow template CTA can open The Decan Watch', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'decan-watch-template',
        kind: MaatGuidanceKind.decanOpening,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-decan-watch',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/decan-watch-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-decan-watch');
  });

  testWidgets('flow template CTA can open The Days Outside the Year', (
    tester,
  ) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'days-outside-template',
        kind: MaatGuidanceKind.strengthNudge,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-days-outside-the-year',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/days-outside-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-days-outside-the-year');
  });

  testWidgets('flow template CTA can open The Open Hand', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'open-hand-template',
        kind: MaatGuidanceKind.decanOpening,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-open-hand',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/open-hand-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-open-hand');
  });

  testWidgets('flow template CTA can open The Djed', (tester) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'djed-template',
        kind: MaatGuidanceKind.decanOpening,
        ctaType: MaatGuidanceCtaType.flowTemplate,
        ctaRef: 'the-djed',
      ),
    ]);
    final openedStates = <Map<String, dynamic>>[];
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/djed-template',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
                flowStudioOpener: (_, restorationState) async {
                  openedStates.add(Map<String, dynamic>.from(restorationState));
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open suggested flow'));
    await tester.pumpAndSettle();

    expect(openedStates.single['mode'], 'maatTemplate');
    expect(openedStates.single['templateKey'], 'the-djed');
  });

  testWidgets('opening detail shows server-owned journey context', (
    tester,
  ) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'opening',
        ctaType: MaatGuidanceCtaType.node,
        ctaRef: 'maat',
        bodyText:
            'This decan opens through Hathor.\n\n'
            'This decan marks stability regained.\n\n'
            'Today centers Step Back Onto the Earth. Your move: Name what you just carried.\n\n'
            'The useful move now is simple: write one truthful mark.',
        payload: const <String, dynamic>{
          'lead_axis': 'T',
          'reflection_move': 'inquire',
          'node_ref': 'maat',
          'day_card_date': '2026-05-19',
          'surface_variants': {
            'context_card': {
              'rows': [
                {
                  'label': 'Today',
                  'value':
                      'Today centers Step Back Onto the Earth. Your move: Name what you just carried.',
                },
                {
                  'label': 'Journey signal',
                  'value':
                      'This opening is tracking truth in the current pattern. Move forward through one step that can be seen, recorded, and repeated.',
                },
                {'label': 'Next act', 'value': 'Write one truthful mark.'},
              ],
            },
          },
        },
      ),
    ]);
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/opening',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
              ),
            );
          },
        ),
        GoRoute(
          path: '/nodes/:slug',
          builder: (context, state) => const Scaffold(body: Text('node')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(
      find.text(
        'Today centers Step Back Onto the Earth. Your move: Name what you just carried.',
      ),
      findsOneWidget,
    );
    expect(find.text('Journey signal'), findsOneWidget);
    expect(find.textContaining('truth in your current pattern'), findsNothing);
    expect(find.textContaining('truth in the current pattern'), findsOneWidget);
    expect(find.text('Next act'), findsOneWidget);
    expect(find.text('Write one truthful mark.'), findsOneWidget);
    expect(find.text('Read the guiding node'), findsOneWidget);

    await tester.ensureVisible(find.text('Read the guiding node'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read the guiding node'));
    await tester.pumpAndSettle();

    expect(find.text('node'), findsOneWidget);
  });

  testWidgets('detail page shows personalized flow preview before accept', (
    tester,
  ) async {
    final repo = _FakeMaatGuidanceRepo([
      _delivery(
        id: 'drift-flow',
        kind: MaatGuidanceKind.driftNudge,
        ctaType: MaatGuidanceCtaType.flowPersonalized,
        ctaRef: 'mfb_v1_drift_restore_provision_M',
        payload: const <String, dynamic>{
          'preview_summary': 'A short provision flow with visible actions.',
          'sample_days': ['Record water.', 'Prepare one meal.'],
          'flow_brief': {
            'description': 'Create a provision flow.',
            'sourceText': 'MAAT_FLOW_BRIEF v1',
            'durationDays': 10,
            'fallbackTemplateKey': 'the-offering-table',
          },
        },
      ),
    ]);
    final controller = MaatGuidanceController(repo);
    final router = GoRouter(
      initialLocation: '/maat-guidance/drift-flow',
      routes: [
        GoRoute(
          path: '/maat-guidance/:deliveryId',
          builder: (context, state) {
            return MaatGuidanceScope(
              controller: controller,
              child: MaatGuidanceDetailPage(
                deliveryId: state.pathParameters['deliveryId']!,
                repo: repo,
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Flow preview'), findsOneWidget);
    expect(
      find.text('A short provision flow with visible actions.'),
      findsOneWidget,
    );
    expect(find.text('Create this flow'), findsOneWidget);
    expect(find.text('Choose another path'), findsOneWidget);
    expect(repo.acks, <String>['drift-flow:opened']);
  });
}

const _periodKey = '2026-05-16:2026-05-25:1-1';

MaatGuidanceDelivery _delivery({
  required String id,
  MaatGuidanceKind kind = MaatGuidanceKind.decanOpening,
  MaatGuidanceStatus status = MaatGuidanceStatus.pending,
  int priority = 10,
  String bodyText = 'Keep the action small, visible, and restorable.',
  MaatGuidanceCtaType ctaType = MaatGuidanceCtaType.none,
  String? ctaRef,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return MaatGuidanceDelivery(
    id: id,
    kind: kind,
    decanPeriodKey: _periodKey,
    status: status,
    priority: priority,
    teaserText: 'Begin with one measured act.',
    bodyText: bodyText,
    payload: payload,
    ctaType: ctaType,
    ctaRef: ctaRef,
    triggerReason: 'test',
    createdAt: DateTime.utc(2026, 5, 16),
  );
}

class _FakeMaatGuidanceRepo implements MaatGuidanceDataSource {
  _FakeMaatGuidanceRepo(this._deliveries);

  final List<MaatGuidanceDelivery?> _deliveries;
  final List<String> acks = <String>[];
  final Set<String> _terminalIds = <String>{};

  void replaceDelivery(MaatGuidanceDelivery delivery) {
    final index = _deliveries.indexWhere((row) => row?.id == delivery.id);
    if (index >= 0) {
      _deliveries[index] = delivery;
    } else {
      _deliveries.add(delivery);
    }
  }

  @override
  Future<void> ack({
    required String deliveryId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    acks.add('$deliveryId:$action');
    if (action == 'dismissed' || action == 'opened' || action == 'acted') {
      _terminalIds.add(deliveryId);
    }
  }

  @override
  Future<MaatGuidanceEvaluateResult?> evaluate({String? timezone}) async {
    return null;
  }

  @override
  Future<MaatGuidanceDelivery?> fetchPending() async {
    for (final delivery in _deliveries.whereType<MaatGuidanceDelivery>()) {
      if (!_terminalIds.contains(delivery.id)) return delivery;
    }
    return null;
  }

  @override
  Future<MaatGuidanceDelivery?> getById(String id) async {
    for (final delivery in _deliveries.whereType<MaatGuidanceDelivery>()) {
      if (delivery.id == id) return delivery;
    }
    return null;
  }
}
