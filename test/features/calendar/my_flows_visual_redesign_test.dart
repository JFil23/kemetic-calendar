import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(find.text('COMPLETED · 2 EVENTS'), findsOneWidget);
    expect(find.text('Day 3 · 6'), findsOneWidget);
    expect(find.text('Manage Flow'), findsOneWidget);

    await _scrollToText(tester, 'TODAY · DAY 3');
    expect(find.text('TODAY · DAY 3'), findsWidgets);
    await _scrollToText(tester, 'UPCOMING');
    expect(find.text('UPCOMING'), findsOneWidget);

    await tester.tap(find.text('Manage Flow'));
    await tester.pump();
    expect(manageCount, 1);
  });

  testWidgets('Saved detail starts at Day 1 and keeps import CTA', (
    tester,
  ) async {
    await _pumpMyFlowDetail(tester, saved: true);

    expect(find.text('Overview'), findsNothing);
    expect(find.text('COMPLETED · 2 EVENTS'), findsNothing);
    expect(find.textContaining('TODAY'), findsNothing);
    expect(find.text('Day 1 · 6'), findsOneWidget);
    await _scrollToText(tester, 'DAY 1');
    expect(find.text('DAY 1'), findsWidgets);
    expect(find.text('Area of Square'), findsWidgets);
    await _scrollToText(tester, 'How to Simplify Fractions');
    expect(find.text('How to Simplify Fractions'), findsOneWidget);
    expect(find.text('Import Flow'), findsOneWidget);
  });

  testWidgets(
    'Saved flow start picker opens with normalized date and Cancel preserves footer',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final expectedStart = DateUtils.dateOnly(DateTime.now());
      final expectedLabel = _startLabel(expectedStart);

      await _pumpMyFlowDetail(tester, saved: true);

      expect(find.text(expectedLabel), findsOneWidget);
      expect(find.text('Import Flow'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, expectedLabel));
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsOneWidget);
      expect(
        find.text(_gregorianMonthAbbreviation(expectedStart.month)),
        findsWidgets,
      );
      expect(find.text('${expectedStart.day}'), findsWidgets);
      expect(find.text('${expectedStart.year}'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsOneWidget);
      expect(find.text('Import Flow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved flow start picker Done preserves visible date and reopens',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final expectedStart = DateUtils.dateOnly(DateTime.now());
      final expectedLabel = _startLabel(expectedStart);

      await _pumpMyFlowDetail(tester, saved: true);

      await tester.tap(find.widgetWithText(OutlinedButton, expectedLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsOneWidget);
      expect(find.text('Import Flow'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, expectedLabel));
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(
        find.text(_gregorianMonthAbbreviation(expectedStart.month)),
        findsWidgets,
      );
      expect(find.text('${expectedStart.day}'), findsWidgets);
      expect(find.text('${expectedStart.year}'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(expectedLabel), findsOneWidget);
      expect(find.text('Import Flow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Detail rows expand, collapse, and switch inline content', (
    tester,
  ) async {
    await _pumpMyFlowDetail(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('my_flow_day_tap_72:preview-72-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED · DAY 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('my_flow_day_tap_72:preview-72-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED · DAY 1'), findsNothing);

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
    expect(find.text('DAY 4'), findsNothing);
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

Future<void> _pumpMyFlows(
  WidgetTester tester, {
  bool activeEmpty = false,
  bool savedEmpty = false,
  bool includeUnresolvedMaatFlow = false,
  bool includeMissingProgressFlow = false,
  bool includeNoScheduleSavedFlow = false,
  ValueChanged<int>? onPreviewFlow,
  VoidCallback? onCreateNew,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMyFlowsListPreviewForTesting(
        activeEmpty: activeEmpty,
        savedEmpty: savedEmpty,
        includeUnresolvedMaatFlow: includeUnresolvedMaatFlow,
        includeMissingProgressFlow: includeMissingProgressFlow,
        includeNoScheduleSavedFlow: includeNoScheduleSavedFlow,
        onPreviewFlow: onPreviewFlow,
        onCreateNew: onCreateNew,
      ),
    ),
  );
  await tester.pump();
}

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
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets);
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final rect = tester.getRect(target.first);
  if (rect.bottom > viewportHeight - 150) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
}

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

String _startLabel(DateTime date) {
  final normalized = DateUtils.dateOnly(date);
  return 'Start: ${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

String _gregorianMonthAbbreviation(int month) {
  const labels = <int, String>{
    1: 'Jan',
    2: 'Feb',
    3: 'Mar',
    4: 'Apr',
    5: 'May',
    6: 'Jun',
    7: 'Jul',
    8: 'Aug',
    9: 'Sep',
    10: 'Oct',
    11: 'Nov',
    12: 'Dec',
  };
  return labels[month]!;
}
