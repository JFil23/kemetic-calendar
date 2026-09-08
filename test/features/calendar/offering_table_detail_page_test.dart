import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/calendar_page.dart' hide KemeticMath;
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/calendar_event_visual_style.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_presentation.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_presentation_copy.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_preview_day_sheet.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _captureVisualCheckpoint = bool.fromEnvironment(
  'CAPTURE_OFFERING_TABLE_VISUAL_CHECKPOINT',
);
const _visualCaptureSurfaceKey = ValueKey<String>(
  'offering-table-visual-capture-surface',
);

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
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(() {
    CalendarEventDetailSheetCoordinator.debugResetForTests();
    resetMaatFlowJoinedStateForTesting();
  });

  testWidgets('catalog route opens the dedicated warm shared-shell detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: kOfferingTableFlowKey,
        ),
      ),
    );
    await tester.pump();

    final heroAsset = await rootBundle.load(
      OfferingTableDetailTokens.heroAsset,
    );

    expect(find.byType(OfferingTableDetailPage), findsOneWidget);
    expect(find.byType(MaatFlowDetailShell), findsOneWidget);
    expect(find.byType(MaatFlowDetailHero), findsOneWidget);
    expect(heroAsset.lengthInBytes, greaterThan(0));
    final hero = find.byKey(const ValueKey<String>('offering-table-hero'));
    final heroImage = find.descendant(
      of: hero,
      matching: find.byKey(const ValueKey<String>('offering-table-hero-image')),
    );
    expect(heroImage, findsOneWidget);
    expect(
      (tester.widget<Image>(heroImage).image as AssetImage).assetName,
      OfferingTableDetailTokens.heroAsset,
    );
    expect(find.text('The Offering\nTable'), findsOneWidget);
    expect(find.text(kOfferingTableTagline), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('offering-table-hero-glyph')),
      findsOneWidget,
    );
    expect(find.text('Carry this table'), findsOneWidget);
  });

  testWidgets('catalog route preserves the persisted joined flow schedule', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final start = DateTime(2026, 9, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: kOfferingTableFlowKey,
          joinedStartDate: start,
          joinedFlowId: 957,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detail = tester.widget<OfferingTableDetailPage>(
      find.byType(OfferingTableDetailPage),
    );
    expect(detail.joinedFlowId, 957);
    expect(detail.joinedStartDate, start);
    expect(detail.joinedScheduleDates, hasLength(30));
    expect(detail.joinedScheduleDates.first, start);
    expect(detail.joinedScheduleDates.last, DateTime(2026, 9, 30));
    expect(
      find.byKey(const ValueKey<String>('offering-table-joined')),
      findsOneWidget,
    );
  });

  testWidgets(
    'default preview begins tomorrow with the approved first morning',
    (tester) async {
      final expectedStart = defaultOfferingTableStartDate(
        TrackSkyTimeZone.pacific,
      );
      await _pumpPage(tester, size: const Size(390, 844));

      expect(find.text('YOUR FIRST MORNING'), findsOneWidget);
      expect(find.text('WHAT ARE YOU RUNNING LOW ON?'), findsOneWidget);
      expect(find.text('Medication, groceries, soap…'), findsOneWidget);
      expect(find.text('The Small Supply'), findsOneWidget);
      expect(find.text('START DATE'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>(
            'offering-table-calendar-ring-${_dateKey(expectedStart)}',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('intro timing says Today for an explicit same-day start', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(
      offeringTableNowInZone(TrackSkyTimeZone.pacific),
    );
    await _pumpPage(tester, size: const Size(390, 844), start: today);

    expect(find.text('YOUR FIRST MORNING'), findsOneWidget);
  });

  testWidgets('start-date label moves the entire preview and Carry date', (
    tester,
  ) async {
    final start = DateTime(DateTime.now().year + 1, 6, 10);
    final selected = start.add(const Duration(days: 1));
    DateTime? joinedDate;

    await _pumpPage(
      tester,
      size: const Size(390, 844),
      start: start,
      onJoin:
          ({
            required startDate,
            required timezone,
            required lens,
            required noCupMode,
          }) async {
            joinedDate = startDate;
            return 52;
          },
    );

    final startControl = find.byKey(
      ValueKey<String>(
        'offering-table-calendar-top-label-control-${_dateKey(start)}',
      ),
    );
    await tester.ensureVisible(startControl);
    await tester.pumpAndSettle();
    await tester.tap(startControl);
    await tester.pumpAndSettle();

    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('Gregorian Calendar'), findsWidgets);
    await tester.drag(
      find.byKey(const ValueKey<String>('stone-register-wheel-day')),
      const Offset(0, -StoneRegisterDatePickerTheme.rowHeight),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        ValueKey<String>('offering-table-calendar-ring-${_dateKey(start)}'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey<String>('offering-table-calendar-ring-${_dateKey(selected)}'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>(
          'offering-table-calendar-ring-'
          '${_dateKey(selected.add(const Duration(days: 29)))}',
        ),
      ),
      findsOneWidget,
    );
    expect(_calendarRings(), findsNWidgets(30));
    expect(find.text('START DATE'), findsOneWidget);
    expect(find.text('YOUR FIRST MORNING'), findsOneWidget);
    expect(find.textContaining(gregorianDateLabel(selected)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();
    expect(joinedDate, selected);
  });

  testWidgets('local-midnight resume rebases an uncarried preview and Carry', (
    tester,
  ) async {
    var nowUtc = DateTime.utc(2026, 9, 3, 6, 59);
    DateTime? carriedStart;
    await _pumpPage(
      tester,
      size: const Size(390, 844),
      clock: () => nowUtc,
      onJoin:
          ({
            required startDate,
            required timezone,
            required lens,
            required noCupMode,
          }) async {
            carriedStart = startDate;
            return 9026;
          },
    );

    expect(
      find.byKey(
        const ValueKey<String>(
          'offering-table-calendar-top-label-control-2026-09-03',
        ),
      ),
      findsOneWidget,
    );

    nowUtc = DateTime.utc(2026, 9, 3, 7, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'offering-table-calendar-top-label-control-2026-09-04',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();
    expect(carriedStart, DateTime(2026, 9, 4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pump();
  });

  testWidgets('a carried Offering Table remains fixed after local midnight', (
    tester,
  ) async {
    var nowUtc = DateTime.utc(2026, 9, 3, 6, 59);
    await _pumpPage(
      tester,
      size: const Size(390, 844),
      joinedFlowId: 9027,
      joinedStartDate: DateTime(2026, 9, 3),
      clock: () => nowUtc,
    );

    nowUtc = DateTime.utc(2026, 9, 3, 7, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'offering-table-calendar-top-label-control-2026-09-03',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>(
          'offering-table-calendar-top-label-control-2026-09-04',
        ),
      ),
      findsNothing,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pump();
  });

  testWidgets('a manually selected start survives midnight and Carry', (
    tester,
  ) async {
    var nowUtc = DateTime.utc(2026, 9, 2, 18);
    DateTime? carriedStart;
    await _pumpPage(
      tester,
      size: const Size(390, 844),
      clock: () => nowUtc,
      onJoin:
          ({
            required startDate,
            required timezone,
            required lens,
            required noCupMode,
          }) async {
            carriedStart = startDate;
            return 9030;
          },
    );

    final startControl = find.byKey(
      const ValueKey<String>(
        'offering-table-calendar-top-label-control-2026-09-03',
      ),
    );
    await tester.ensureVisible(startControl);
    await tester.pumpAndSettle();
    await tester.tap(startControl);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('stone-register-wheel-day')),
      const Offset(0, -StoneRegisterDatePickerTheme.rowHeight),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'offering-table-calendar-top-label-control-2026-09-04',
        ),
      ),
      findsOneWidget,
    );

    nowUtc = DateTime.utc(2026, 9, 4, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>(
          'offering-table-calendar-top-label-control-2026-09-04',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();
    expect(carriedStart, DateTime(2026, 9, 4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pump();
  });

  testWidgets(
    'joined detail reads the persisted schedule and cannot draft another start',
    (tester) async {
      final start = DateTime(2026, 9, 1);
      final dates = <DateTime>[
        for (var offset = 0; offset < 30; offset++)
          start.add(Duration(days: offset)),
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offering_table_957_initial_need': 'Protect my sleep.',
      });

      await _pumpPage(
        tester,
        size: const Size(390, 844),
        start: DateTime(2026, 8, 29),
        joinedFlowId: 957,
        joinedStartDate: start,
        joinedScheduleDates: dates,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('offering-table-calendar-ring-${_dateKey(start)}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'offering-table-calendar-ring-${_dateKey(DateTime(2026, 9, 30))}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('offering-table-calendar-ring-2026-08-29'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('offering-table-joined')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey<String>('offering-table-initial-input'),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey<String>('offering-table-initial-input'),
              ),
            )
            .controller
            ?.text,
        'Protect my sleep.',
      );

      final startControl = find.byKey(
        ValueKey<String>(
          'offering-table-calendar-top-label-control-${_dateKey(start)}',
        ),
      );
      await tester.tap(startControl);
      await tester.pumpAndSettle();
      expect(find.text('Start date'), findsNothing);
    },
  );

  testWidgets('Carry seeds only the trimmed Day 1 intention after join', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      size: const Size(390, 844),
      onJoin:
          ({
            required startDate,
            required timezone,
            required lens,
            required noCupMode,
          }) async => 81,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('offering-table-initial-input')),
      '  Protect my sleep.  ',
    );
    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();

    expect(
      await const OfferingTableLocalStore().loadIntention(81, 1),
      'Protect my sleep.',
    );
    expect(await const OfferingTableLocalStore().loadIntention(81, 2), isEmpty);
    expect(
      await const OfferingTableLocalStore().loadIntention(81, 30),
      isEmpty,
    );
  });

  testWidgets(
    'production carry stages one canonical flow before local need persistence',
    (tester) async {
      var joinCalls = 0;
      var flowCalls = 0;
      var cacheClears = 0;
      int? returnedFlowId;
      final eventCalls = <Map<String, Object?>>[];
      final persistenceComplete = Completer<void>();
      final service = FlowJoinService(
        offeringTableScheduleForDate: (day, date, timezone) {
          final startLocal = DateTime(
            date.year,
            date.month,
            date.day,
            kOfferingTableDefaultHour,
            kOfferingTableDefaultMinute,
          );
          final endLocal = startLocal.add(
            Duration(minutes: day.durationMinutes),
          );
          return OfferingTableOccurrenceSchedule(
            startLocal: startLocal,
            endLocal: endLocal,
            startUtc: startLocal.toUtc(),
            endUtc: endLocal.toUtc(),
            usedFallback: false,
            clampedToDawn: false,
            timezone: timezone,
            referenceLocationName: 'Production seam fixture',
            configuredHour: kOfferingTableDefaultHour,
            configuredMinute: kOfferingTableDefaultMinute,
          );
        },
        upsertFlow:
            ({
              id,
              required name,
              required color,
              required active,
              calendarId,
              startDate,
              endDate,
              notes,
              required rules,
              originType,
            }) async {
              flowCalls += 1;
              return 82;
            },
        upsertEvent:
            ({
              required clientEventId,
              required title,
              required startsAtUtc,
              detail,
              allDay = false,
              endsAtUtc,
              flowLocalId,
              category,
              actionId,
              behaviorPayload,
              calendarId,
              caller,
            }) async {
              eventCalls.add(<String, Object?>{
                'clientEventId': clientEventId,
                'title': title,
                'flowLocalId': flowLocalId,
                'behaviorPayload': behaviorPayload,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {},
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              if (!persistenceComplete.isCompleted) {
                persistenceComplete.complete();
              }
            },
      );
      await _pumpPage(
        tester,
        size: const Size(390, 844),
        localStore: const _FailingOfferingTableLocalStore(),
        onJoin:
            ({
              required startDate,
              required timezone,
              required lens,
              required noCupMode,
            }) async {
              joinCalls += 1;
              returnedFlowId =
                  await joinOfferingTableThroughProductionForTesting(
                    joinService: service,
                    startDate: startDate,
                    timezone: timezone,
                    lens: lens,
                    noCupMode: noCupMode,
                    clearFiledFlowsCache: () async {
                      cacheClears += 1;
                    },
                  );
              return returnedFlowId!;
            },
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('offering-table-initial-input')),
        'Protect my sleep.',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('offering-table-join')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => persistenceComplete.future.timeout(const Duration(seconds: 2)),
      );
      await tester.pump();

      expect(joinCalls, 1);
      expect(returnedFlowId, 82);
      expect(flowCalls, 1);
      expect(cacheClears, 1);
      expect(eventCalls, hasLength(30));
      expect(
        eventCalls.map((call) => call['clientEventId']).toSet(),
        hasLength(30),
      );
      expect(eventCalls.map((call) => call['flowLocalId']).toSet(), <Object?>{
        82,
      });
      expect(
        eventCalls.map(
          (call) => (call['behaviorPayload']! as Map<String, dynamic>)['day'],
        ),
        orderedEquals(List<int>.generate(30, (index) => index + 1)),
      );
      for (final call in eventCalls) {
        final payload = call['behaviorPayload']! as Map<String, dynamic>;
        expect(payload['kind'], 'maat_offering_table_day');
        expect(payload['flow_key'], kOfferingTableFlowKey);
        expect(
          resolveCalendarEventVisualStyle(
            eventColor: const Color(0xFFC99A3D),
            eventTitle: call['title']! as String,
            behaviorPayload: payload,
          ).graphic?.kind,
          CalendarEventGraphicKind.offeringTable,
        );
      }
      expect(
        find.byKey(const ValueKey<String>('offering-table-joined')),
        findsOneWidget,
      );
      expect(find.text('In your calendar'), findsOneWidget);
      expect(
        find.text('Could not join The Offering Table. Please retry.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'ritual-first preview supersedes the legacy calendar-first contract',
    (tester) async {
      const size = Size(390, 844);
      final start = DateTime(2026, 9, 3);
      await _pumpPage(
        tester,
        size: size,
        start: start,
        calendarPreview: _calendarPreview(start),
      );

      final firstMorning = find.text('YOUR FIRST MORNING');
      final featured = find.byKey(
        const ValueKey<String>('offering-table-preview-event-1'),
      );
      final runningLow = find.text('WHAT ARE YOU RUNNING LOW ON?');
      final ritualCalendar = find.byKey(
        const ValueKey<String>('offering-table-thirty-day-calendar'),
      );
      expect(firstMorning, findsOneWidget);
      expect(featured, findsOneWidget);
      expect(runningLow, findsOneWidget);
      expect(ritualCalendar, findsOneWidget);
      expect(
        tester.getTopLeft(firstMorning).dy,
        lessThan(tester.getTopLeft(featured).dy),
      );
      expect(
        tester.getTopLeft(featured).dy,
        lessThan(tester.getTopLeft(runningLow).dy),
      );
      expect(
        tester.getTopLeft(runningLow).dy,
        lessThan(tester.getTopLeft(ritualCalendar).dy),
      );
      expect(
        find.byKey(const ValueKey<String>('offering-table-initial-input')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ritual-first detail follows the supplied v7 order', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      size: const Size(390, 844),
      start: DateTime(2026, 9, 4),
    );

    final firstMorning = find.text('YOUR FIRST MORNING');
    final featured = find.byKey(
      const ValueKey<String>('offering-table-preview-event-1'),
    );
    final runningLow = find.text('WHAT ARE YOU RUNNING LOW ON?');
    final calendar = find.byKey(
      const ValueKey<String>('offering-table-thirty-day-calendar'),
    );
    expect(firstMorning, findsOneWidget);
    expect(featured, findsOneWidget);
    expect(find.text('The Small Supply'), findsOneWidget);
    expect(runningLow, findsOneWidget);
    expect(calendar, findsOneWidget);
    expect(
      tester.getTopLeft(firstMorning).dy,
      lessThan(tester.getTopLeft(featured).dy),
    );
    expect(
      tester.getTopLeft(featured).dy,
      lessThan(tester.getTopLeft(runningLow).dy),
    );
    expect(
      tester.getTopLeft(runningLow).dy,
      lessThan(tester.getTopLeft(calendar).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('canonical presentation uses the unique daily prompt authority', (
    tester,
  ) async {
    const size = Size(390, 844);
    final day5Prompt = offeringTablePracticePresentation(
      kOfferingTableDays[4],
    ).previewSummary;
    final day11Prompt = offeringTablePracticePresentation(
      kOfferingTableDays[10],
    ).previewSummary;
    final day21Prompt = offeringTablePracticePresentation(
      kOfferingTableDays[20],
    ).previewSummary;
    expect(day5Prompt, isNot(day11Prompt));
    expect(day11Prompt, isNot(day21Prompt));

    await _pumpDaySheet(tester, size: size, dayNumber: 5);
    await _revealOfferingPresentationBody(tester);
    expect(find.text('PERSONAL TABLE · DAY 5'), findsWidgets);
    expect(find.text(day5Prompt), findsWidgets);
    expect(
      find.text(
        '${offeringTablePracticePresentation(kOfferingTableDays[4]).steps.length} steps',
      ),
      findsNothing,
    );

    await _pumpDaySheet(tester, size: size, dayNumber: 11);
    await _revealOfferingPresentationBody(tester);
    expect(find.text('HOUSEHOLD TABLE · DAY 1'), findsWidgets);
    expect(find.text(day11Prompt), findsWidgets);
    expect(
      find.text(
        '${offeringTablePracticePresentation(kOfferingTableDays[10]).steps.length} steps',
      ),
      findsNothing,
    );

    await _pumpDaySheet(tester, size: size, dayNumber: 21);
    await _revealOfferingPresentationBody(tester);
    expect(find.text('FLOWING TABLE · DAY 1'), findsWidgets);
    expect(find.text(day21Prompt), findsWidgets);
    expect(
      find.text(
        '${offeringTablePracticePresentation(kOfferingTableDays[20]).steps.length} steps',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail preview uses its own host and dismisses without Day View lifecycle',
    (tester) async {
      await _pumpPage(
        tester,
        size: const Size(390, 844),
        start: DateTime(2026, 9, 3),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('offering-table-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      final firstBadge = find.byKey(
        const ValueKey<String>('offering-table-preview-event-1'),
      );
      await Scrollable.ensureVisible(
        tester.element(firstBadge),
        alignment: 0.45,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstBadge);
      await tester.pumpAndSettle();

      expect(find.byType(OfferingTablePreviewDaySheet), findsOneWidget);
      expect(find.byType(OfferingTableDayPresentation), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('offering-table-preview-sheet-host')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('offering-table-resizable-sheet')),
        findsNothing,
      );
      expect(find.byTooltip('Event options'), findsNothing);
      expect(find.text('Make to-do'), findsNothing);
      expect(find.text('Calendar'), findsNothing);
      expect(find.text('Speak your intention into the water'), findsNothing);
      expect(find.text('THE NEED YOU NAMED'), findsNothing);
      expect(find.text('Reflect'), findsNothing);
      expect(find.text('COMPLETION'), findsNothing);
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();

      expect(find.byType(OfferingTablePreviewDaySheet), findsNothing);
      expect(find.byType(OfferingTableDetailPage), findsOneWidget);
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

      await tester.tap(firstBadge);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('offering-table-preview-sheet-back')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('offering-table-preview-sheet-back')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OfferingTablePreviewDaySheet), findsNothing);
      expect(find.byType(OfferingTableDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'Day View Offering blocks reopen after shared barrier dismissal',
    (tester) async {
      await _pumpOfferingDayViewInteraction(tester);

      final eventLayer = find.byKey(dayViewTimelineEventLayerKey);
      final previewLayer = find.byKey(dayViewTimelinePreviewLayerKey);
      Finder offeringBlocksIn(Finder layer) => find.descendant(
        of: layer,
        matching: find.byType(OfferingTableEventBlockVisual),
      );

      expect(offeringBlocksIn(eventLayer), findsNWidgets(2));
      expect(offeringBlocksIn(previewLayer), findsNothing);

      await tester.tap(offeringBlocksIn(eventLayer).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('offering-table-resizable-sheet')),
        findsOneWidget,
      );
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isTrue);
      expect(
        find.byKey(const ValueKey<String>('offering-table-small-supply-jar')),
        findsOneWidget,
      );
      expect(find.text('Reflect'), findsNothing);

      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();
      expect(find.byType(OfferingTableDayPresentation), findsNothing);
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

      await tester.tap(offeringBlocksIn(eventLayer).first);
      await tester.pumpAndSettle();
      expect(find.byType(OfferingTableDayPresentation), findsOneWidget);

      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

      await tester.tap(offeringBlocksIn(eventLayer).last);
      await tester.pumpAndSettle();
      expect(find.byType(OfferingTableDayPresentation), findsOneWidget);
      expect(
        find.text(
          offeringTablePracticePresentation(
            kOfferingTableDays[1],
          ).previewSummary,
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'carry delegates once and keeps the successful staged join authoritative',
    (tester) async {
      final selectedDate = DateTime(2026, 9, 3);
      DateTime? joinedDate;
      TrackSkyTimeZone? joinedTimezone;
      OfferingTableLens? joinedLens;
      bool? joinedNoCupMode;
      var joinCalls = 0;

      await _pumpPage(
        tester,
        size: const Size(390, 844),
        start: selectedDate,
        timezone: TrackSkyTimeZone.eastern,
        onJoin:
            ({
              required startDate,
              required timezone,
              required lens,
              required noCupMode,
            }) async {
              joinCalls += 1;
              joinedDate = startDate;
              joinedTimezone = timezone;
              joinedLens = lens;
              joinedNoCupMode = noCupMode;
              return 41;
            },
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('offering-table-join')),
      );
      await tester.pumpAndSettle();

      expect(joinedDate, selectedDate);
      expect(joinedTimezone, TrackSkyTimeZone.eastern);
      expect(joinedLens, OfferingTableLens.neutral);
      expect(joinedNoCupMode, isFalse);
      expect(joinCalls, 1);
      expect(
        find.byKey(const ValueKey<String>('offering-table-joined')),
        findsOneWidget,
      );
      expect(find.text('In your calendar'), findsOneWidget);
    },
  );

  for (final fixture in const <({String name, Size size})>[
    (name: 'normal iPhone', size: Size(390, 844)),
    (name: 'narrow', size: Size(320, 700)),
    (name: 'large', size: Size(430, 932)),
  ]) {
    testWidgets('${fixture.name} page and day sheet remain scroll-safe', (
      tester,
    ) async {
      await _pumpPage(tester, size: fixture.size, start: DateTime(2026, 9, 3));
      await tester.drag(
        find.byKey(const ValueKey<String>('offering-table-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The detail preview must fit before its event sheet opens.',
      );

      tester
          .widget<GestureDetector>(
            find.byKey(
              const ValueKey<String>('offering-table-preview-event-1'),
            ),
          )
          .onTap!();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The event sheet must fit at its initial extent.',
      );

      expect(find.byType(OfferingTablePreviewDaySheet), findsOneWidget);
      expect(find.byType(OfferingTableDayPresentation), findsNothing);
      final sheetRect = tester.getRect(
        find.byKey(const ValueKey<String>('offering-table-preview-sheet-host')),
      );
      expect(sheetRect.height, closeTo(fixture.size.height * 0.82, 0.5));
      expect(sheetRect.top, closeTo(fixture.size.height * 0.18, 0.5));
      final sheetScroll = find.byKey(
        const ValueKey<String>('offering-table-preview-sheet-scroll'),
      );
      final scrollable = find.descendant(
        of: sheetScroll,
        matching: find.byType(Scrollable),
      );
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      await tester.drag(sheetScroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      final scrollError = tester.takeException();
      expect(
        scrollError,
        isNull,
        reason: scrollError is FlutterError
            ? scrollError.toStringDeep()
            : 'The event sheet must remain bounded while scrolling.',
      );
      final after = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(after, greaterThan(before));
      expect(find.text('Back to the table'), findsOneWidget);
      expect(find.text('COMPLETION'), findsNothing);
      expect(find.text('Observed'), findsNothing);
      expect(find.text('Partly'), findsNothing);
      expect(find.text('Skipped'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('captures the flow-detail preview sheet visual checkpoint', (
    tester,
  ) async {
    if (!_captureVisualCheckpoint) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _loadOfferingVisualFonts();

    for (final fixture in const <({String name, Size size})>[
      (name: '390', size: Size(390, 844)),
      (name: '320', size: Size(320, 700)),
      (name: '430', size: Size(430, 932)),
    ]) {
      await _pumpPage(tester, size: fixture.size, start: DateTime(2026, 9, 3));
      await expectLater(
        find.byKey(_visualCaptureSurfaceKey),
        matchesGoldenFile(
          '/tmp/offering-table-flutter-detail-${fixture.name}.png',
        ),
      );
      final previewEvent = find.byKey(
        const ValueKey<String>('offering-table-preview-event-1'),
      );
      await tester.ensureVisible(previewEvent);
      await tester.tap(previewEvent);
      await tester.pumpAndSettle();
      expect(find.byType(OfferingTablePreviewDaySheet), findsOneWidget);
      debugPrint(
        'OFFERING_PREVIEW_SHEET_${fixture.name} '
        '${tester.getRect(find.byKey(const ValueKey<String>('offering-table-preview-sheet-host')))}',
      );
      debugPrint(
        'OFFERING_PREVIEW_MEDIA_${fixture.name} '
        '${MediaQuery.sizeOf(tester.element(find.byType(OfferingTablePreviewDaySheet)))}',
      );

      await expectLater(
        find.byKey(_visualCaptureSurfaceKey),
        matchesGoldenFile(
          '/tmp/offering-table-flutter-preview-sheet-${fixture.name}.png',
        ),
      );

      if (fixture.name == '390') {
        await tester.drag(
          find.byKey(
            const ValueKey<String>('offering-table-preview-sheet-scroll'),
          ),
          const Offset(0, -620),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(_visualCaptureSurfaceKey),
          matchesGoldenFile(
            '/tmp/offering-table-flutter-preview-sheet-390-body.png',
          ),
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('captures the static Offering Table visual checkpoint', (
    tester,
  ) async {
    if (!_captureVisualCheckpoint) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _loadOfferingVisualFonts();

    for (final fixture in const <({String name, Size size})>[
      (name: '390', size: Size(390, 844)),
      (name: '320', size: Size(320, 700)),
      (name: '430', size: Size(430, 932)),
    ]) {
      await _pumpStaticOfferingDayView(tester, size: fixture.size);
      final eventBlock = find.byType(OfferingTableEventBlockVisual).first;
      expect(eventBlock, findsOneWidget);
      final rect = tester.getRect(eventBlock);
      debugPrint(
        'OFFERING_EVENT_RECT_${fixture.name} '
        '${rect.left},${rect.top},${rect.width},${rect.height}',
      );
      await expectLater(
        find.byKey(_visualCaptureSurfaceKey),
        matchesGoldenFile(
          '/tmp/offering-table-flutter-day-view-${fixture.name}.png',
        ),
      );

      await tester.tap(eventBlock);
      await tester.pumpAndSettle();
      expect(find.byType(OfferingTableDayPresentation), findsOneWidget);
      final media = MediaQuery.of(
        tester.element(find.byType(OfferingTableDayPresentation)),
      );
      debugPrint(
        'OFFERING_MEDIA_${fixture.name} '
        'size=${media.size} padding=${media.padding} '
        'insets=${media.viewInsets}',
      );
      debugPrint(
        'OFFERING_SHEET_${fixture.name} '
        '${tester.getRect(find.byKey(const ValueKey<String>('offering-table-resizable-sheet')))}',
      );
      debugPrint(
        'OFFERING_PRESENTATION_${fixture.name} '
        '${tester.getRect(find.byType(OfferingTableDayPresentation))}',
      );

      await expectLater(
        find.byKey(_visualCaptureSurfaceKey),
        matchesGoldenFile(
          '/tmp/offering-table-flutter-day-sheet-${fixture.name}-initial.png',
        ),
      );

      if (fixture.name == '390') {
        await tester.drag(
          find.byKey(const ValueKey<String>('follow-sky-sheet-resize-handle')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(_visualCaptureSurfaceKey),
          matchesGoldenFile(
            '/tmp/offering-table-flutter-day-sheet-390-expanded.png',
          ),
        );
        await tester.drag(
          find.byKey(
            const ValueKey<String>('offering-table-presentation-body'),
          ),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(_visualCaptureSurfaceKey),
          matchesGoldenFile(
            '/tmp/offering-table-flutter-day-sheet-390-body.png',
          ),
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      CalendarEventDetailSheetCoordinator.debugResetForTests();
    }
    expect(tester.takeException(), isNull);
  });

  test('Offering Table retains a distinct theme from Follow the Sky', () {
    expect(
      OfferingTableDetailTokens.theme.pageBackground,
      isNot(FollowSkyV11Tokens.detailTheme.pageBackground),
    );
    expect(
      OfferingTableDetailTokens.theme.glow,
      isNot(FollowSkyV11Tokens.detailTheme.glow),
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Size size,
  DateTime? start,
  int? joinedFlowId,
  DateTime? joinedStartDate,
  List<DateTime> joinedScheduleDates = const <DateTime>[],
  TrackSkyTimeZone timezone = TrackSkyTimeZone.pacific,
  MaatFlowClock? clock,
  OfferingTableJoinCallback? onJoin,
  OfferingTableLocalStore localStore = const OfferingTableLocalStore(),
  FollowSkyCalendarPreview calendarPreview = FollowSkyCalendarPreview.empty,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: _visualCaptureSurfaceKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: OfferingTableDetailPage(
          timezone: timezone,
          clock: clock,
          presentDayIanaTimeZone: timezone.ianaName,
          calendarPreview: calendarPreview,
          initialStartDate: start,
          joinedFlowId: joinedFlowId,
          joinedStartDate: joinedStartDate,
          joinedScheduleDates: joinedScheduleDates,
          showBackButton: false,
          localStore: localStore,
          onJoin:
              onJoin ??
              ({
                required startDate,
                required timezone,
                required lens,
                required noCupMode,
              }) async => 1,
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FailingOfferingTableLocalStore extends OfferingTableLocalStore {
  const _FailingOfferingTableLocalStore();

  @override
  Future<void> saveIntention(int flowId, int dayNumber, String value) async {
    throw StateError('test-only private store failure');
  }
}

Future<void> _pumpDaySheet(
  WidgetTester tester, {
  required Size size,
  required int dayNumber,
}) async {
  final start = DateTime(2026, 9, 3);
  final day = kOfferingTableDays[dayNumber - 1];
  final date = start.add(Duration(days: dayNumber - 1));
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: OfferingTableDetailTokens.pageBackground,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: OfferingTableDayPresentation(
            day: day,
            localDate: date,
            startMinute:
                kOfferingTableDefaultHour * 60 + kOfferingTableDefaultMinute,
            initialIntention: 'Protect my sleep.',
            lens: OfferingTableLens.neutral,
            persistResponses: false,
            completionPanel: const Text('Completion fixture'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _revealOfferingPresentationBody(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey<String>('offering-table-presentation-body')),
    const Offset(0, -360),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadOfferingVisualFonts() async {
  final gentium = FontLoader('GentiumPlus')
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Bold.ttf'));
  final cormorant = FontLoader('CormorantGaramond')
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Regular.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Italic.ttf'))
    ..addFont(rootBundle.load('ios/Runner/Fonts/CormorantGaramond-Medium.ttf'))
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf'),
    )
    ..addFont(
      rootBundle.load('ios/Runner/Fonts/CormorantGaramond-SemiBold.ttf'),
    );
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait(<Future<void>>[
    gentium.load(),
    cormorant.load(),
    materialIcons.load(),
  ]);
}

Future<void> _pumpStaticOfferingDayView(
  WidgetTester tester, {
  required Size size,
}) async {
  const flowId = 701;
  tester.view.physicalSize = size;
  await const OfferingTableLocalStore().saveIntention(
    flowId,
    1,
    'Protect my sleep.',
  );
  final day = kOfferingTableDays.first;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _visualCaptureSurfaceKey,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: DayViewGrid(
            ky: 1,
            km: 1,
            kd: 1,
            notes: <NoteData>[
              NoteData(
                clientEventId: 'offering-table-static-visual',
                title: offeringTableEventTitle(day),
                allDay: false,
                start: const TimeOfDay(hour: 7, minute: 30),
                end: const TimeOfDay(hour: 8, minute: 30),
                flowId: flowId,
                behaviorPayload: <String, dynamic>{
                  'kind': 'maat_offering_table_day',
                  'flow_key': kOfferingTableFlowKey,
                  'day': 1,
                },
              ),
            ],
            showGregorian: false,
            flowIndex: const <int, FlowData>{
              flowId: FlowData(
                id: flowId,
                name: kOfferingTableTitle,
                color: Color(0xFFC99A3D),
                active: true,
                notes: 'mode=gregorian;maat=$kOfferingTableFlowKey',
              ),
            },
            activeLedgerFlowIds: const <int>{flowId},
            initialScrollOffset: 6 * 60,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpOfferingDayViewInteraction(WidgetTester tester) async {
  const flowId = 702;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: <NoteData>[
            for (final entry in <({int dayNumber, int hour})>[
              (dayNumber: 1, hour: 7),
              (dayNumber: 2, hour: 9),
            ])
              NoteData(
                clientEventId: 'offering-table-day-view-${entry.dayNumber}',
                title: offeringTableEventTitle(
                  kOfferingTableDays[entry.dayNumber - 1],
                ),
                allDay: false,
                start: TimeOfDay(hour: entry.hour, minute: 30),
                end: TimeOfDay(hour: entry.hour + 1, minute: 0),
                flowId: flowId,
                behaviorPayload: <String, dynamic>{
                  'kind': 'maat_offering_table_day',
                  'flow_key': kOfferingTableFlowKey,
                  'day': entry.dayNumber,
                },
              ),
          ],
          showGregorian: false,
          flowIndex: const <int, FlowData>{
            flowId: FlowData(
              id: flowId,
              name: kOfferingTableTitle,
              color: Color(0xFFC99A3D),
              active: true,
              notes: 'mode=gregorian;maat=$kOfferingTableFlowKey',
            ),
          },
          activeLedgerFlowIds: const <int>{flowId},
          initialScrollOffset: 6 * 60,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _calendarRings() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('offering-table-calendar-ring-');
});

FollowSkyCalendarPreview _calendarPreview(DateTime start) {
  final secondDay = start.add(const Duration(days: 1));
  return FollowSkyCalendarPreview(
    rows: [
      FollowSkyCalendarPreviewRow(
        localDay: start,
        start: DateTime(start.year, start.month, start.day, 6, 30),
        end: DateTime(start.year, start.month, start.day, 7, 15),
        title: 'Morning workout',
        eventColor: const Color(0xFF4E7A46),
      ),
      FollowSkyCalendarPreviewRow(
        localDay: start,
        start: DateTime(start.year, start.month, start.day, 21, 30),
        end: DateTime(start.year, start.month, start.day, 22),
        title: 'Evening journal',
        eventColor: const Color(0xFF3B5D82),
      ),
      FollowSkyCalendarPreviewRow(
        localDay: secondDay,
        start: DateTime(secondDay.year, secondDay.month, secondDay.day, 7, 30),
        end: DateTime(secondDay.year, secondDay.month, secondDay.day, 7, 33),
        title: 'Day 2: The Cup Before the Noise',
        eventColor: const Color(0xFFB85B87),
        flowName: kOfferingTableTitle,
      ),
      FollowSkyCalendarPreviewRow(
        localDay: secondDay,
        start: DateTime(secondDay.year, secondDay.month, secondDay.day, 13),
        end: DateTime(secondDay.year, secondDay.month, secondDay.day, 14),
        title: 'Lunch meeting',
        eventColor: const Color(0xFF8E4B2E),
      ),
    ],
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
