import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
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

  testWidgets('appearance detail adds a hero to the existing dashboard', (
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
        home: CalendarPage.buildCanonicalCustomFlowDetail(
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
      const PageStorageKey<String>('flow-dashboard-77-active'),
    );
    expect(existingDashboard, findsOneWidget);
    expect(find.text('THE FLOW CALENDAR'), findsNothing);
    expect(
      find.byKey(const ValueKey('user-flow-remaining-occurrences')),
      findsNothing,
    );
    final progressFooter = find.byKey(
      const ValueKey<String>('user-flow-appearance-progress-footer'),
    );
    expect(progressFooter, findsOneWidget);
    expect(
      find.descendant(
        of: progressFooter,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.endsWith('OF 7') == true,
        ),
      ),
      findsOneWidget,
    );
    if (_captureUserFlowDetail) {
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('/tmp/user-flow-detail.png'),
      );
    }
    final detailScroll = find
        .descendant(of: existingDashboard, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Practice 6'),
      260,
      scrollable: detailScroll,
    );
    expect(find.text('Practice 6'), findsOneWidget);
  });
}
