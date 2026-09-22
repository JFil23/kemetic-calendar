import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.test',
        anonKey: 'test-anon-key',
        httpClient: _RejectingClient(),
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
    }
  });

  setUp(EndFlowVisibilityStore.instance.debugReset);
  tearDown(EndFlowVisibilityStore.instance.debugReset);

  testWidgets('My Flows active and saved tabs stay mutually exclusive', (
    tester,
  ) async {
    await _pumpMyFlows(tester);

    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('Personal Practice'), findsOneWidget);
    expect(find.text('Follow the sky'), findsOneWidget);
    expect(find.text('The Weighing'), findsNothing);

    await tester.tap(find.text('Saved Flows'));
    await tester.pumpAndSettle();

    expect(find.text('SAVED'), findsWidgets);
    expect(find.text('The Weighing'), findsOneWidget);
    expect(find.text('Saved Personal Template'), findsOneWidget);
    expect(find.text('Personal Practice'), findsNothing);
    expect(find.text('Follow the sky'), findsNothing);
  });

  testWidgets(
    'My Flows cards render personal initials and Ma’at glyph badges',
    (tester) async {
      await _pumpMyFlows(tester, includeUnresolvedMaatFlow: true);

      expect(
        find.byKey(
          const ValueKey<String>('my_flow_initial_badge_Personal Practice'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('my_flow_maat_badge_track-the-sky')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('my_flow_initial_badge_Mystery Maat'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('my_flow_maat_badge_not-a-real-flow'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'My Flows progress uses snapshot counts and saved cards show dash',
    (tester) async {
      await _pumpMyFlows(tester, includeMissingProgressFlow: true);

      expect(find.text('4 of 6'), findsOneWidget);
      expect(find.text('5 of 27'), findsOneWidget);
      expect(find.text('May 25 \u2192 Jun 23, 2026'), findsOneWidget);
      expect(find.text('May 2026 \u2192 Mar 2027'), findsOneWidget);
      expect(find.textContaining('2026-'), findsNothing);
      expect(find.text('No Count Practice'), findsOneWidget);
      expect(find.text('\u2014'), findsOneWidget);

      await tester.tap(find.text('Saved Flows'));
      await tester.pumpAndSettle();

      expect(find.text('The Weighing'), findsOneWidget);
      expect(find.text('Saved Personal Template'), findsOneWidget);
      expect(find.text('May 25 \u2192 Aug 22, 2026'), findsOneWidget);
      expect(find.text('\u2014'), findsWidgets);
      expect(find.text('7 of 9'), findsNothing);
    },
  );

  testWidgets('My Flows files no-schedule custom flows under Saved', (
    tester,
  ) async {
    await _pumpMyFlows(tester, includeNoScheduleSavedFlow: true);

    expect(find.text('CODEX_NO_SCHEDULE_FLOW_VISIBILITY'), findsNothing);

    await tester.tap(find.text('Saved Flows'));
    await tester.pumpAndSettle();

    expect(find.text('CODEX_NO_SCHEDULE_FLOW_VISIBILITY'), findsOneWidget);
    expect(find.text('Saved Personal Template'), findsOneWidget);
  });

  testWidgets('My Flows card taps delegate through the existing preview path', (
    tester,
  ) async {
    final opened = <int>[];
    await _pumpMyFlows(tester, onPreviewFlow: opened.add);

    await tester.tap(find.text('Personal Practice'));
    await tester.pump();
    expect(opened, <int>[1]);

    await tester.tap(find.text('Saved Flows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Weighing'));
    await tester.pump();

    expect(opened, <int>[1, 3]);
  });

  testWidgets(
    'active Ma’at cards reuse the canonical discovery detail surface',
    (tester) async {
      await _pumpMyFlows(tester);

      await tester.tap(find.text('Follow the sky'));
      await tester.pumpAndSettle();

      expect(find.byType(FollowSkyDetailSurface), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('user-flow-detail-surface-2')),
        findsNothing,
      );
    },
  );

  testWidgets('My Flows plus button remains delegated', (tester) async {
    var createCount = 0;
    await _pumpMyFlows(
      tester,
      onCreateNew: () {
        createCount += 1;
      },
    );

    await tester.tap(find.byTooltip('New flow'));
    await tester.pump();

    expect(createCount, 1);
  });

  testWidgets('My Flows back button pops the nested Flow Studio route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Center(child: Text('Flow Studio hub')),
          ),
        ),
      ),
    );
    await tester.pump();

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => buildMyFlowsListPreviewForTesting(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Flows'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Flow Studio hub'), findsOneWidget);
    expect(find.text('My Flows'), findsNothing);
  });

  testWidgets('My Flows empty states are preserved for active and saved tabs', (
    tester,
  ) async {
    await _pumpMyFlows(tester, activeEmpty: true, savedEmpty: true);

    expect(find.text('No flows yet'), findsOneWidget);

    await tester.tap(find.text('Saved Flows'));
    await tester.pumpAndSettle();

    expect(find.text('No flows yet'), findsOneWidget);
  });

  testWidgets('visibility overlay survives late mount and stale refresh', (
    tester,
  ) async {
    EndFlowVisibilityStore.instance.markPending(1);
    await _pumpMyFlows(tester);

    expect(find.text('Personal Practice'), findsNothing);
    expect(find.text('Follow the sky'), findsOneWidget);

    EndFlowVisibilityStore.instance.markCommitted(1);
    await tester.pump();
    expect(find.text('Personal Practice'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpMyFlows(tester);
    expect(find.text('Personal Practice'), findsNothing);

    EndFlowVisibilityStore.instance.remove(1);
    await tester.pump();
    expect(find.text('Personal Practice'), findsOneWidget);
  });

  testWidgets('Flow Studio counts render source snapshot plus overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildFlowHubPreviewForTesting(),
      ),
    );
    await tester.pump();
    expect(find.text('2 active · 2 saved'), findsOneWidget);

    EndFlowVisibilityStore.instance.markPending(1);
    await tester.pump();
    expect(find.text('1 active · 2 saved'), findsOneWidget);

    EndFlowVisibilityStore.instance.markCommitted(1);
    await tester.pump();
    expect(find.text('1 active · 2 saved'), findsOneWidget);

    EndFlowVisibilityStore.instance.remove(1);
    await tester.pump();
    expect(find.text('2 active · 2 saved'), findsOneWidget);
  });

  testWidgets('End Flow hides immediately and overlay-restores on failure', (
    tester,
  ) async {
    final endResult = Completer<EndFlowOutcome>();
    await _pumpMyFlows(
      tester,
      includeUnresolvedMaatFlow: true,
      onEndFlow: (flowId) {
        expect(flowId, 4);
        return endResult.future;
      },
    );

    await tester.tap(find.text('Mystery Maat'));
    await tester.pumpAndSettle();
    expect(find.text('End Flow'), findsOneWidget);

    await tester.tap(find.text('End Flow'));
    await tester.pumpAndSettle();
    expect(find.text('Mystery Maat'), findsNothing);

    endResult.complete(_failedEndFlowOutcome('failed-4'));
    await tester.pumpAndSettle();
    expect(find.text('Mystery Maat'), findsOneWidget);
    expect(
      find.textContaining('Could not end this flow right now.'),
      findsOneWidget,
    );
    expect(find.text('Copy diagnostics'), findsOneWidget);
  });

  testWidgets('session-not-ready End Flow uses the mapped message', (
    tester,
  ) async {
    await _pumpMyFlows(
      tester,
      includeUnresolvedMaatFlow: true,
      onEndFlow: (_) async => EndFlowOutcome.failure(
        operationId: 'session-not-ready',
        failureKind: EndFlowFailureKind.sessionNotReady,
        terminalStage: EndFlowTerminalStage.preRpcGuard,
        rpcAttempted: false,
      ),
    );

    await tester.tap(find.text('Mystery Maat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Flow'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your session isn’t ready. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Copy diagnostics'), findsOneWidget);
  });

  testWidgets('auth readiness restores End Flow without leaving the preview', (
    tester,
  ) async {
    addTearDown(
      () => EndFlowAuthReadiness.instance.debugSetReadyForTesting(true),
    );
    await _pumpMyFlows(tester, includeUnresolvedMaatFlow: true);
    await tester.tap(find.text('Mystery Maat'));
    await tester.pumpAndSettle();
    expect(find.text('End Flow'), findsOneWidget);

    EndFlowAuthReadiness.instance.debugSetReadyForTesting(false);
    await tester.pump();
    expect(find.text('End Flow'), findsNothing);

    EndFlowAuthReadiness.instance.debugSetReadyForTesting(true);
    await tester.pump();
    expect(find.text('End Flow'), findsOneWidget);
  });

  testWidgets(
    'failed End Flow restores only its target and preserves a concurrent commit',
    (tester) async {
      final completions = <int, Completer<EndFlowOutcome>>{
        4: Completer<EndFlowOutcome>(),
        8: Completer<EndFlowOutcome>(),
      };
      final committedFlowIds = <int>{};
      final filingInactiveFlowIds = <int>{};

      await _pumpMyFlows(
        tester,
        includeUnresolvedMaatFlow: true,
        includeSecondActiveMaatFlow: true,
        filingInactiveFlowIdsForTesting: filingInactiveFlowIds,
        onEndFlow: (flowId) async {
          final result = await completions[flowId]!.future;
          if (result.result == EndFlowActionResult.success) {
            committedFlowIds.add(flowId);
          }
          filingInactiveFlowIds
            ..clear()
            ..addAll(committedFlowIds);
          return result;
        },
      );

      await tester.tap(find.text('Mystery Maat'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('End Flow'));
      await tester.tap(find.text('End Flow'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dawn House Rite'));
      await tester.pumpAndSettle();
      final archivedEnd = find.byKey(
        const ValueKey<String>('archived-flow-end-leave'),
      );
      await _scrollArchivedControlIntoViewport(tester, archivedEnd);
      await tester.tap(archivedEnd);
      await tester.pumpAndSettle();

      expect(find.text('Mystery Maat'), findsNothing);
      expect(find.text('Dawn House Rite'), findsNothing);

      completions[8]!.complete(
        EndFlowOutcome.success(operationId: 'success-8'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mystery Maat'), findsNothing);
      expect(find.text('Dawn House Rite'), findsNothing);

      completions[4]!.complete(_failedEndFlowOutcome('failed-4-concurrent'));
      await tester.pumpAndSettle();

      expect(find.text('Mystery Maat'), findsOneWidget);
      expect(find.text('Dawn House Rite'), findsNothing);
      expect(
        find.textContaining('Could not end this flow right now.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('ended archived Ma’at flow remains in Saved read-only history', (
    tester,
  ) async {
    await _pumpMyFlows(
      tester,
      onEndFlow: (_) async =>
          EndFlowOutcome.success(operationId: 'saved-success'),
    );

    await tester.tap(find.text('Saved Flows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Weighing'));
    await tester.pumpAndSettle();
    expect(find.text('Ended · archived'), findsOneWidget);
    expect(find.text('Leave history'), findsOneWidget);
    expect(find.text('End Flow'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('archived-flow-back')));
    await tester.pumpAndSettle();

    expect(find.text('The Weighing'), findsOneWidget);
    await tester.tap(find.text('Active Flows'));
    await tester.pumpAndSettle();
    expect(find.text('The Weighing'), findsNothing);
  });

  testWidgets('My Flows layout has no overflow in required viewports', (
    tester,
  ) async {
    for (final size in const <Size>[
      Size(390, 844),
      Size(844, 390),
      Size(820, 1180),
    ]) {
      await _pumpMyFlowsAtSize(tester, size);
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }

    await _pumpMyFlowsAtSize(
      tester,
      const Size(390, 844),
      textScaleFactor: 1.3,
    );
    expect(tester.takeException(), isNull, reason: 'textScaleFactor 1.3');
  });

  testWidgets('Active detail renders dashboard and Manage Flow CTA', (
    tester,
  ) async {
    var manageCount = 0;
    await _pumpMyFlowDetail(
      tester,
      onManageFlow: () {
        manageCount += 1;
      },
    );

    expect(find.text('Overview'), findsNothing);
    expect(find.text('Schedule'), findsNothing);
    expect(find.text('Days & Notes'), findsNothing);
    expect(find.text('DAY 3 OF 6'), findsOneWidget);
    expect(find.text('Manage flow'), findsOneWidget);
    expect(find.byKey(const ValueKey('user-flow-calendar-72')), findsOneWidget);

    await _scrollToText(tester, 'NEXT 4 UPCOMING EVENTS');
    expect(find.text('NEXT 4 UPCOMING EVENTS'), findsOneWidget);
    for (var day = 3; day <= 6; day++) {
      expect(
        find.byKey(ValueKey<String>('user-flow-schedule-block-$day')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('user-flow-show-past')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('user-flow-show-later')),
      findsNothing,
    );

    await tester.tap(find.text('Manage flow'));
    await tester.pump();
    expect(manageCount, 1);
  });

  testWidgets('Dashboard YouTube location still uses Watch on YouTube', (
    tester,
  ) async {
    await _pumpMyFlowDetail(tester, saved: true);

    await _scrollToText(tester, 'Why Does Fermat’s Last Theorem Matter?');
    await tester.tap(
      find.byKey(const ValueKey<String>('my_flow_day_tap_71:preview-71-2')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Watch on YouTube'), findsOneWidget);
    expect(find.text('https://www.youtube.com/watch?v=example'), findsNothing);
  });

  testWidgets('Saved detail starts at Day 1 and keeps import CTA', (
    tester,
  ) async {
    await _pumpMyFlowDetail(tester, saved: true);

    expect(find.text('Overview'), findsNothing);
    expect(find.text('COMPLETED · 2'), findsNothing);
    expect(find.textContaining('TODAY'), findsNothing);
    expect(find.text('SAVED · 6 DAYS'), findsOneWidget);
    await _scrollToText(tester, 'NEXT 5 UPCOMING EVENTS');
    expect(find.text('NEXT 5 UPCOMING EVENTS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('user-flow-schedule-block-1')),
      findsOneWidget,
    );
    expect(find.text('Area of Square'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('user-flow-show-later')),
      findsOneWidget,
    );
    await _scrollToText(tester, 'How to Simplify Fractions');
    expect(find.text('How to Simplify Fractions'), findsOneWidget);
    expect(find.text('Carry this flow'), findsOneWidget);
  });

  testWidgets(
    'Saved flow start picker opens with normalized date and Cancel preserves footer',
    (tester) async {
      _useSmallPhoneSurface(tester);
      await _pumpMyFlowDetail(tester, saved: true);

      expect(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
        findsOneWidget,
      );
      expect(find.text('Carry this flow'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Kemetic Calendar'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
        findsOneWidget,
      );
      expect(find.text('Carry this flow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved flow start picker Done preserves visible date and reopens',
    (tester) async {
      _useSmallPhoneSurface(tester);
      await _pumpMyFlowDetail(tester, saved: true);

      await tester.tap(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
        findsOneWidget,
      );
      expect(find.text('Carry this flow'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Kemetic Calendar'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('user-flow-saved-start-control')),
        findsOneWidget,
      );
      expect(find.text('Carry this flow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Detail rows expand, collapse, and retain the two newest cards', (
    tester,
  ) async {
    await _pumpMyFlowDetail(tester);

    final showPast = find.byKey(const ValueKey<String>('user-flow-show-past'));
    await _revealUserFlowDetail(tester, showPast);
    await tester.tap(showPast);
    await tester.pumpAndSettle();

    final firstDay = find.byKey(
      const ValueKey<String>('my_flow_day_tap_72:preview-72-0'),
    );
    await _revealUserFlowDetail(tester, firstDay);
    await tester.tap(firstDay);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('my_flow_day_card_72:preview-72-0')),
      findsOneWidget,
    );

    await _revealUserFlowDetail(tester, firstDay);
    await tester.tap(firstDay);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('my_flow_day_card_72:preview-72-0')),
      findsNothing,
    );

    await _scrollToText(tester, 'The Birthday Problem and Probability');
    await tester.tap(
      find.byKey(const ValueKey<String>('my_flow_day_tap_72:preview-72-3')),
    );
    await tester.pumpAndSettle();
    expect(find.text('DAY 4'), findsOneWidget);

    await _scrollToText(tester, 'What Is the Golden Ratio?');
    await tester.tap(
      find.byKey(const ValueKey<String>('my_flow_day_tap_72:preview-72-4')),
    );
    await tester.pumpAndSettle();
    expect(find.text('DAY 4'), findsOneWidget);
    expect(find.text('DAY 5'), findsOneWidget);
  });

  testWidgets('Reminder-backed detail preserves legacy summary', (
    tester,
  ) async {
    await _pumpMyFlowDetail(tester, reminderBacked: true);

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Days & Notes'), findsOneWidget);
    expect(find.text('Repeats: One-time'), findsOneWidget);
    expect(find.text('Manage Flow'), findsNothing);
  });
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const <int>[]),
      500,
      request: request,
    );
  }
}

Future<void> _pumpMyFlows(
  WidgetTester tester, {
  bool activeEmpty = false,
  bool savedEmpty = false,
  bool includeUnresolvedMaatFlow = false,
  bool includeSecondActiveMaatFlow = false,
  bool includeMissingProgressFlow = false,
  bool includeNoScheduleSavedFlow = false,
  ValueChanged<int>? onPreviewFlow,
  VoidCallback? onCreateNew,
  Future<EndFlowOutcome> Function(int flowId)? onEndFlow,
  Set<int>? filingInactiveFlowIdsForTesting,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMyFlowsListPreviewForTesting(
        activeEmpty: activeEmpty,
        savedEmpty: savedEmpty,
        includeUnresolvedMaatFlow: includeUnresolvedMaatFlow,
        includeSecondActiveMaatFlow: includeSecondActiveMaatFlow,
        includeMissingProgressFlow: includeMissingProgressFlow,
        includeNoScheduleSavedFlow: includeNoScheduleSavedFlow,
        onPreviewFlow: onPreviewFlow,
        onCreateNew: onCreateNew,
        onEndFlow: onEndFlow,
        filingInactiveFlowIdsForTesting: filingInactiveFlowIdsForTesting,
      ),
    ),
  );
  await tester.pump();
}

EndFlowOutcome _failedEndFlowOutcome(String operationId) =>
    EndFlowOutcome.failure(
      operationId: operationId,
      failureKind: EndFlowFailureKind.unknown,
    );

Future<void> _pumpMyFlowsAtSize(
  WidgetTester tester,
  Size size, {
  double textScaleFactor = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: buildMyFlowsListPreviewForTesting(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await _revealUserFlowDetail(tester, target);
}

Future<void> _revealUserFlowDetail(WidgetTester tester, Finder target) async {
  final scroll = _userFlowDetailScroll();
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var i = 0; i < 24; i++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target.first);
      if (rect.top >= 8 && rect.bottom <= viewportHeight - 150) return;
      await tester.drag(scroll, Offset(0, rect.top < 8 ? 280 : -280));
    } else {
      await tester.drag(scroll, const Offset(0, -280));
    }
    await tester.pumpAndSettle();
  }
  fail(
    'Could not reveal ${target.describeMatch(Plurality.one)} '
    'in the user-flow detail scroll.',
  );
}

Finder _userFlowDetailScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is CustomScrollView &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'user-flow-detail-scroll-',
          ),
    )
    .hitTestable()
    .first;

Future<void> _pumpMyFlowDetail(
  WidgetTester tester, {
  bool saved = false,
  bool reminderBacked = false,
  VoidCallback? onManageFlow,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMyFlowDetailPreviewForTesting(
        saved: saved,
        reminderBacked: reminderBacked,
        onManageFlow: onManageFlow,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollArchivedControlIntoViewport(
  WidgetTester tester,
  Finder control,
) async {
  final scroll = find.byKey(const ValueKey<String>('archived-flow-scroll'));
  for (var attempt = 0; attempt < 12; attempt++) {
    final rect = tester.getRect(control);
    if (rect.top >= 0 && rect.bottom <= 580) return;
    await tester.drag(scroll, const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  expect(tester.getRect(control).bottom, lessThanOrEqualTo(580));
}
