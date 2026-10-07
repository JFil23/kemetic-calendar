import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _captureUserFlowDetail = bool.fromEnvironment('CAPTURE_USER_FLOW_DETAIL');

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  testWidgets('appearance detail uses the one My Flows hero and schedule', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final events = <Map<String, Object?>>[
      for (var index = 0; index < 7; index++)
        <String, Object?>{
          'offset_days': index,
          'title': 'Practice ${index + 1}',
          'start_time': '08:00',
          'end_time': '09:00',
        },
    ];
    final today = DateUtils.dateOnly(DateTime.now());

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage.buildCanonicalFlowDetail(
          name: 'Study the Duat',
          color: 0xFF6F93A8,
          flowId: 77,
          notes: '{"overview":"Read with attention."}',
          eventsJson: events,
          startDate: today,
          appearance: const FlowAppearance(
            signKind: FlowSignKind.papyrus,
            signLabel: 'Study',
            accentArgb: 0xFF6F93A8,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('user-flow-detail-appearance')),
      findsOneWidget,
    );
    final existingDashboard = find.byKey(
      const ValueKey<String>('user-flow-detail-scroll-77'),
    );
    expect(existingDashboard, findsOneWidget);
    expect(find.text('THE FLOW CALENDAR'), findsNothing);
    expect(
      find.byKey(const ValueKey('user-flow-remaining-occurrences')),
      findsNothing,
    );
    final caption = find.byKey(const ValueKey('user-flow-detail-caption'));
    expect(caption, findsOneWidget);
    expect(tester.widget<Text>(caption).data, endsWith('OF 7'));
    if (_captureUserFlowDetail) {
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('/tmp/user-flow-detail.png'),
      );
    }
    Future<void> reveal(Finder target) async {
      for (var attempt = 0; attempt < 40; attempt++) {
        if (target.evaluate().isNotEmpty &&
            tester.getRect(target).top >= 40 &&
            tester.getRect(target).bottom <=
                tester.getRect(find.byType(MaatFlowDetailDock)).top) {
          return;
        }
        await tester.drag(existingDashboard, const Offset(0, -260));
        await tester.pumpAndSettle();
      }
      final controller = tester
          .widget<CustomScrollView>(existingDashboard)
          .controller!;
      fail(
        'Schedule content must be reachable above the fixed dock: '
        '${target.evaluate().isEmpty ? "missing" : tester.getRect(target)} '
        'scroll=${controller.offset}/${controller.position.maxScrollExtent}',
      );
    }

    final later = find.byKey(const ValueKey('user-flow-show-later'));
    await reveal(later);
    await tester.tap(later);
    await tester.pumpAndSettle();
    await reveal(find.text('Practice 6'));
    expect(find.text('Practice 6'), findsOneWidget);
  });

  testWidgets('historical source data still uses the one My Flows fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage.buildCanonicalFlowDetail(
          name: 'The Moon Return',
          notes: 'maat=the-moon-return',
          color: 0xFF6F93A8,
          flowId: 78,
          initialFlowEvents: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('user-flow-detail-surface-78')),
      findsOneWidget,
    );
    expect(find.byType(MaatFlowDetailShell), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved appearance replaces the open detail snapshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: buildMyFlowDetailPreviewForTesting(
          appearance: FlowAppearance.empty,
          onRefreshAppearance: () async {
            refreshCount += 1;
            return const FlowAppearance(
              signKind: FlowSignKind.palmCount,
              signLabel: 'completed occurrences',
              accentArgb: 0xFF6F93A8,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailHero = find.byKey(
      const ValueKey<String>('user-flow-detail-appearance'),
    );
    Finder heroSign() => find.descendant(
      of: detailHero,
      matching: find.byKey(
        const ValueKey<String>('user-flow-appearance-sign-layer'),
      ),
    );
    expect(heroSign(), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('user-flow-manage')));
    await tester.pumpAndSettle();

    expect(refreshCount, 1);
    expect(heroSign(), findsOneWidget);
  });
}
