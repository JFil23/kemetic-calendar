import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_presentation_copy.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _viewport = Size(390, 844);
const _flowId = 91;

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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('rejected OfferingTableDayPresentation is absent', () {
    expect(
      File(
        'lib/features/calendar/the_offering_table/presentation/'
        'offering_table_day_presentation.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('all thirty days own one non-empty authored event-block prompt', () {
    expect(kOfferingTableDays, hasLength(30));
    for (final day in kOfferingTableDays) {
      expect(
        day.eventBlockPrompt.trim(),
        isNotEmpty,
        reason: 'Day ${day.dayNumber}',
      );
      expect(
        day.eventBlockPrompt,
        isNot(contains('\n')),
        reason: 'Day ${day.dayNumber} must remain one-line safe',
      );
    }
    expect(
      kOfferingTableDays[2].eventBlockPrompt,
      'put real food within reach',
    );
  });

  test(
    'all thirty days preserve their authored mockup steps without additions',
    () {
      for (final day in kOfferingTableDays) {
        final presentation = offeringTablePracticePresentation(day);
        expect(presentation.steps, isNotEmpty, reason: 'Day ${day.dayNumber}');
      }

      expect(
        offeringTablePracticePresentation(kOfferingTableDays.first).steps,
        const <String>[
          'Name one supply running low.',
          'Refill it, or write down the next step.',
          'Put it in sight or set one reminder.',
        ],
      );
      expect(
        offeringTablePracticePresentation(kOfferingTableDays[1]).steps,
        const <String>[
          'Name the first thing you want to give your attention to today.',
          'Drink a glass of water before you open feeds, messages, or tasks.',
          'Give that first thing one quiet minute.',
        ],
      );
    },
  );

  testWidgets('Offering uses the shared resizable instrument host', (
    tester,
  ) async {
    await _pumpOfferingSheet(tester);

    final sheet = find.byKey(
      const ValueKey<String>('offering-table-resizable-sheet'),
    );
    final handle = find.byKey(
      const ValueKey<String>('follow-sky-sheet-resize-handle'),
    );
    final page = find.descendant(of: sheet, matching: find.byType(PageView));
    final presentation = find.byKey(
      const ValueKey<String>('offering-table-day-presentation-v8'),
    );
    final lowerSheet = find.byKey(
      const ValueKey<String>('offering-table-layered-practice-sheet'),
    );
    expect(sheet, findsOneWidget);
    expect(handle, findsOneWidget);
    expect(presentation, findsOneWidget);
    expect(
      tester.getRect(presentation).bottom - tester.getRect(lowerSheet).top,
      closeTo(28, .5),
      reason: 'Day 1 keeps the authored lower ritual card peeking by 28 px.',
    );

    final availableHeight = _viewport.height - 12;
    final maxSheetHeight = availableHeight * 0.71;
    final layeredPageHeight = maxSheetHeight - 48 - 72;
    expect(tester.getSize(page).height, closeTo(layeredPageHeight, 20));

    await tester.drag(handle, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getSize(page).height, closeTo(layeredPageHeight + 120, 20));
    expect(
      tester.getRect(presentation).bottom - tester.getRect(lowerSheet).top,
      closeTo(28, .5),
      reason: 'Resizing the outer sheet preserves the authored card peek.',
    );

    final body = find.byKey(
      const ValueKey<String>('offering-table-presentation-body'),
    );
    final xBefore = tester.getTopLeft(body).dx;
    final lowerBefore = tester.getRect(lowerSheet);
    await tester.dragFrom(
      Offset(tester.getRect(sheet).center.dx, lowerBefore.top + 12),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(body).dx, closeTo(xBefore, 0.1));
  });
}

Future<void> _pumpOfferingSheet(WidgetTester tester) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);

  const store = OfferingTableLocalStore();
  await store.saveIntention(_flowId, 1, 'Protect my sleep.');
  final day = kOfferingTableDays.first;
  final localDate = DateTime(2026, 8, 29);
  final schedule = offeringTableScheduleForDate(
    day,
    localDate,
    TrackSkyTimeZone.pacific,
  );
  final target = DayViewSheetEventTarget(
    ky: 1,
    km: 1,
    kd: 1,
    event: EventItem(
      clientEventId: 'offering-table-sheet-fixture',
      title: offeringTableEventTitle(day),
      startMin: 7 * 60 + 30,
      endMin: 7 * 60 + 35,
      flowId: _flowId,
      color: const Color(0xFFC99A3D),
      allDay: false,
      behaviorPayload: offeringTableBehaviorPayload(
        day: day,
        schedule: schedule,
        lens: OfferingTableLens.neutral,
        noCupMode: false,
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: CalendarEventDetailSheet(
            hostContext: context,
            initialTarget: target,
            flowResolver: (flowId) => flowId == _flowId
                ? const FlowData(
                    id: _flowId,
                    name: kOfferingTableTitle,
                    color: Color(0xFFC99A3D),
                    active: true,
                    notes:
                        'mode=gregorian;maat=the-offering-table;offering_lens=neutral',
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
