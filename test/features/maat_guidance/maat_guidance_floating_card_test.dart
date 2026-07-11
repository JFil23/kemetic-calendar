import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/maat_guidance_model.dart';
import 'package:mobile/data/maat_guidance_repo.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_controller.dart';
import 'package:mobile/features/maat_guidance/maat_guidance_floating_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('global lower-third presenter uses shared decan onboarding gate', () {
    final source = File('lib/main.dart').readAsStringSync();
    final suppression = _sourceBetween(
      source,
      'bool _shouldSuppressMaatGuidance(BuildContext context) {',
      'String _traceRouteLabel()',
    );
    final gateEvaluation = _sourceBetween(
      source,
      'Future<void> _evaluateMaatGuidanceGate(int serial) async {',
      'void _resetFloatingMenuStateAfterFrame()',
    );
    final pushGate = _sourceBetween(
      source,
      'Future<bool> _canOpenMaatGuidancePush(',
      'void _openSharedFlow(String shareId) {',
    );

    expect(suppression, contains('_maatGuidanceProactiveUiAllowed'));
    expect(suppression, contains('_maatGuidancePromptDecanIdentity()'));
    expect(suppression, contains('DecanReflectionOnboardingGate.shouldBlock'));
    expect(
      gateEvaluation,
      contains('DecanReflectionOnboardingGate.shouldBlock'),
    );
    expect(
      gateEvaluation,
      contains('_maatGuidanceController.dismissCurrent()'),
    );
    expect(pushGate, contains('DecanReflectionOnboardingGate.shouldBlock'));
    expect(pushGate, contains('_maatGuidanceDecanIdentityFromPeriodKey'));
  });

  testWidgets('floating card dismiss button does not require an Overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.black,
            child: MaatGuidanceFloatingCard(
              delivery: _delivery(),
              onDismiss: () {},
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Read guidance'), findsOneWidget);
    expect(find.text('You are in ḥry-ib sꜣḥ'), findsOneWidget);
    expect(
      find.textContaining('ḥry-ib sꜣḥ asks for truth to become practical'),
      findsOneWidget,
    );
    expect(find.textContaining('This decan asks'), findsNothing);
  });

  testWidgets('floating card has an explicit open button', (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.black,
            child: MaatGuidanceFloatingCard(
              delivery: _deliveryWithNode(),
              onDismiss: () {},
              onOpen: () => openCount += 1,
            ),
          ),
        ),
      ),
    );

    final openButton = find.widgetWithText(TextButton, 'Open guidance');
    expect(openButton, findsOneWidget);

    await tester.tap(openButton);
    await tester.pump();

    expect(openCount, 1);
  });

  testWidgets('deterministic orientation renders as lower-third badge', (
    tester,
  ) async {
    var openCount = 0;
    final repo = _FakeMaatGuidanceRepo([_deterministicOrientationDelivery()]);
    final controller = MaatGuidanceController(repo);

    await controller.refresh(force: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MaatGuidanceOverlayHost(
                controller: controller,
                visible: true,
                onOpen: (_) => openCount += 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(maatGuidanceOrientationLowerThirdBadgeKey),
      findsOneWidget,
    );
    expect(find.byType(MaatGuidanceFloatingCard), findsNothing);
    expect(find.text('Orientation'), findsOneWidget);
    expect(
      find.text('Keep the record plain before drawing meaning from it.'),
      findsOneWidget,
    );
    expect(find.textContaining('The account was made plain'), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byKey(maatGuidanceOrientationLowerThirdBadgeKey));
    await tester.pump();

    expect(openCount, 1);

    await tester.tap(
      find.byKey(maatGuidanceOrientationLowerThirdDismissButtonKey),
    );
    await tester.pump();

    expect(openCount, 1);
    expect(repo.acks, contains('orientation:dismissed'));
    expect(controller.current, isNull);
  });

  testWidgets(
    'deterministic orientation lower-third dismiss works without Overlay',
    (tester) async {
      var openCount = 0;
      var dismissCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MaatGuidanceOrientationLowerThirdBadge(
            delivery: _deterministicOrientationDelivery(),
            maxWidth: 320,
            onDismiss: () => dismissCount += 1,
            onOpen: () => openCount += 1,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(
        find.byKey(maatGuidanceOrientationLowerThirdDismissButtonKey),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(maatGuidanceOrientationLowerThirdDismissButtonKey),
      );
      await tester.pump();

      expect(dismissCount, 1);
      expect(openCount, 0);

      await tester.tap(find.byKey(maatGuidanceOrientationLowerThirdBadgeKey));
      await tester.pump();

      expect(openCount, 1);
    },
  );

  testWidgets('non-spectrum guidance keeps existing floating card surface', (
    tester,
  ) async {
    final repo = _FakeMaatGuidanceRepo([_delivery()]);
    final controller = MaatGuidanceController(repo);

    await controller.refresh(force: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              MaatGuidanceOverlayHost(
                controller: controller,
                visible: true,
                onOpen: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(maatGuidanceOrientationLowerThirdBadgeKey), findsNothing);
    expect(find.byType(MaatGuidanceFloatingCard), findsOneWidget);
    expect(find.text('Read guidance'), findsOneWidget);
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}

MaatGuidanceDelivery _delivery() {
  return MaatGuidanceDelivery(
    id: 'opening',
    kind: MaatGuidanceKind.decanOpening,
    decanPeriodKey: '2026-05-29:2026-06-07:3-2',
    status: MaatGuidanceStatus.pending,
    priority: 10,
    teaserText:
        'This decan asks for truth to become practical. Begin with one measured act.',
    bodyText: 'This decan opens through Paopi.',
    payload: const <String, dynamic>{'decan_short_name': 'ḥry-ib sꜣḥ'},
    ctaType: MaatGuidanceCtaType.none,
    ctaRef: null,
    triggerReason: 'decan_boundary',
    createdAt: DateTime.utc(2026, 5, 19),
  );
}

MaatGuidanceDelivery _deliveryWithNode() {
  return MaatGuidanceDelivery(
    id: 'opening',
    kind: MaatGuidanceKind.decanOpening,
    decanPeriodKey: '2026-05-29:2026-06-07:3-2',
    status: MaatGuidanceStatus.pending,
    priority: 10,
    teaserText:
        'This decan asks for truth to become practical. Begin with one measured act.',
    bodyText: 'This decan opens through Paopi.',
    payload: const <String, dynamic>{
      'decan_short_name': 'ḥry-ib sꜣḥ',
      'node_ref': 'maat',
    },
    ctaType: MaatGuidanceCtaType.node,
    ctaRef: 'maat',
    triggerReason: 'decan_boundary',
    createdAt: DateTime.utc(2026, 5, 19),
  );
}

MaatGuidanceDelivery _deterministicOrientationDelivery() {
  return MaatGuidanceDelivery.fromJson({
    'id': 'orientation',
    'kind': 'decan_opening',
    'decan_period_key': '2026-05-29:2026-06-07:3-2',
    'status': 'pending',
    'priority': 10,
    'teaser_text': 'Legacy teaser should not render.',
    'body_text': 'Legacy body should not render.',
    'payload': {
      'maat_flow_response_renderer': {
        'renderer': 'deterministic_spectrum',
        'used_llm': false,
        'llm_cost': 0,
        'spectrum_flow_key': 'the-weighing',
        'response_kind': 'orientation',
        'badge_role': 'opening_orientation',
        'preferred_surface': 'lower_third_badge',
        'badge_title': 'Orientation',
      },
      'maat_flow_response': {
        'responseKind': 'orientation',
        'body': 'Keep the record plain before drawing meaning from it.',
        'badgeTitle': 'Orientation',
        'badgeBody': 'Keep the record plain before drawing meaning from it.',
        'selectedSeed': {
          'seed': 'Keep the record plain before drawing meaning from it.',
          'flowKey': 'the-weighing',
          'badgeRole': 'opening_orientation',
          'preferredSurface': 'lower_third_badge',
        },
      },
    },
  });
}

class _FakeMaatGuidanceRepo implements MaatGuidanceDataSource {
  _FakeMaatGuidanceRepo(this._deliveries);

  final List<MaatGuidanceDelivery> _deliveries;
  final List<String> acks = <String>[];
  final Set<String> _terminalIds = <String>{};

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
  Future<MaatGuidanceEvaluateResult?> evaluate({String? timezone}) async =>
      null;

  @override
  Future<MaatGuidanceDelivery?> fetchPending() async {
    for (final delivery in _deliveries) {
      if (!_terminalIds.contains(delivery.id)) return delivery;
    }
    return null;
  }

  @override
  Future<MaatGuidanceDelivery?> getById(String id) async {
    for (final delivery in _deliveries) {
      if (delivery.id == id) return delivery;
    }
    return null;
  }
}
