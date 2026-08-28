import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' hide KemeticMath;
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_sheet.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(resetMaatFlowJoinedStateForTesting);

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
    expect(find.text(kOfferingTableGlyph), findsOneWidget);
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

  testWidgets('default preview begins tomorrow with the approved intro copy', (
    tester,
  ) async {
    final expectedStart = defaultOfferingTableStartDate(
      TrackSkyTimeZone.pacific,
    );
    await _pumpPage(tester, size: const Size(390, 844));

    expect(
      find.text(
        'Provision begins with the most basic need. Tomorrow you practice noticing yours before the day takes over.',
      ),
      findsOneWidget,
    );
    expect(find.text('WHAT NEEDS FEEDING?'), findsOneWidget);
    expect(
      find.text('Name one need you have been putting off'),
      findsOneWidget,
    );
    expect(find.text('Name the need…'), findsOneWidget);
    expect(find.text('START DATE'), findsOneWidget);
    expect(
      find.byKey(
        ValueKey<String>(
          'offering-table-calendar-ring-${_dateKey(expectedStart)}',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('intro timing says Today for an explicit same-day start', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(
      offeringTableNowInZone(TrackSkyTimeZone.pacific),
    );
    await _pumpPage(tester, size: const Size(390, 844), start: today);

    expect(
      find.text(
        'Provision begins with the most basic need. Today you practice noticing yours before the day takes over.',
      ),
      findsOneWidget,
    );
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
    expect(
      find.text(
        'Provision begins with the most basic need. On ${_monthDay(selected)} you practice noticing yours before the day takes over.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('offering-table-preview-day-1')),
        matching: find.text(gregorianDateLabel(selected)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();
    expect(joinedDate, selected);
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

  testWidgets('Carry saves the trimmed private need only after join succeeds', (
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
      await const OfferingTableLocalStore().loadNeed(81),
      'Protect my sleep.',
    );
  });

  testWidgets(
    'calendar, initial entry, and date previews follow the approved order',
    (tester) async {
      const size = Size(390, 844);
      final start = DateTime(2026, 9, 3);
      await _pumpPage(
        tester,
        size: size,
        start: start,
        calendarPreview: _calendarPreview(start),
      );

      final calendar = find.byKey(
        const ValueKey<String>('offering-table-thirty-day-calendar'),
      );
      final initialEntry = find.byKey(
        const ValueKey<String>('offering-table-initial-entry'),
      );
      final firstPreview = find.byKey(
        const ValueKey<String>('offering-table-preview-day-1'),
      );

      expect(calendar, findsOneWidget);
      expect(find.text('Here is your table.'), findsOneWidget);
      expect(find.text('For the next thirty days.'), findsOneWidget);
      expect(initialEntry, findsOneWidget);
      expect(find.text('HOW THE TABLE WORKS'), findsOneWidget);
      expect(find.text('WHAT NEEDS FEEDING?'), findsOneWidget);
      expect(
        find.text('Name one need you have been putting off'),
        findsOneWidget,
      );
      expect(find.text('Name the need…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('offering-table-initial-input')),
        findsOneWidget,
      );
      expect(firstPreview, findsOneWidget);
      expect(find.text('START DATE'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      final startDateControl = find.byKey(
        ValueKey<String>(
          'offering-table-calendar-top-label-control-${_dateKey(start)}',
        ),
      );
      expect(tester.getSemantics(startDateControl).label, 'Change start date');
      semantics.dispose();

      expect(
        tester.getTopLeft(calendar).dy,
        lessThan(tester.getTopLeft(initialEntry).dy),
      );
      expect(
        tester.getTopLeft(initialEntry).dy,
        lessThan(tester.getTopLeft(firstPreview).dy),
      );

      for (final offset in const <int>[0, 14, 29]) {
        final date = start.add(Duration(days: offset));
        final dateKey = _dateKey(date);
        expect(
          find.byKey(ValueKey<String>('offering-table-calendar-day-$dateKey')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('offering-table-calendar-ring-$dateKey')),
          findsOneWidget,
        );
        expect(
          _ringBorderColor(tester, 'offering-table-calendar-ring-$dateKey'),
          OfferingTableDetailTokens.warmGold,
        );
      }

      expect(_previewDayCards(), findsNWidgets(5));
      expect(
        find.byKey(const ValueKey<String>('offering-table-preview-day-6')),
        findsNothing,
      );
      expect(find.text('Day 1: The First Water'), findsOneWidget);
      expect(find.text('7:30 AM'), findsNWidgets(5));
      expect(find.byType(OfferingTableEventBlockVisual), findsNWidgets(5));
      expect(find.byType(MaatFlowPreviewEventRow), findsNWidgets(3));
      expect(find.text('VIEW PRACTICE'), findsNWidgets(5));
      expect(
        find.text(
          'Start with your most basic need before the day starts asking.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Choose what reaches you before messages and tasks do.'),
        findsOneWidget,
      );
      expect(
        find.text('Turn one meal from fuel into actual provision.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Correct one small act of body-care you have been deferring.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Treat rest as something that must be provided, not hoped for.',
        ),
        findsOneWidget,
      );
      for (final day in kOfferingTableDays.take(5)) {
        final badge = find.byKey(
          ValueKey<String>('offering-table-preview-event-${day.dayNumber}'),
        );
        expect(tester.widget<GestureDetector>(badge).onTap, isNotNull);
        expect(
          find.byKey(
            ValueKey<String>('offering-table-preview-chevron-${day.dayNumber}'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey<String>(
              'offering-table-preview-affordance-${day.dayNumber}',
            ),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Morning workout'), findsOneWidget);
      expect(find.text('Evening journal'), findsOneWidget);
      expect(find.text('Lunch meeting'), findsOneWidget);

      final workout = find.descendant(
        of: firstPreview,
        matching: find.text('Morning workout'),
      );
      final offering = find.descendant(
        of: firstPreview,
        matching: find.text('Day 1: The First Water'),
      );
      final journal = find.descendant(
        of: firstPreview,
        matching: find.text('Evening journal'),
      );
      expect(
        tester.getTopLeft(workout).dy,
        lessThan(tester.getTopLeft(offering).dy),
      );
      expect(
        tester.getTopLeft(offering).dy,
        lessThan(tester.getTopLeft(journal).dy),
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('offering-table-preview-day-2'),
          ),
          matching: find.text('Day 2: The Cup Before the Noise'),
        ),
        findsOneWidget,
      );

      final firstDateKey = _dateKey(start);
      expect(
        _dotColor(tester, 'offering-table-calendar-dot-$firstDateKey-0'),
        const Color(0xFF4E7A46),
      );
      expect(
        _dotColor(tester, 'offering-table-calendar-dot-$firstDateKey-1'),
        const Color(0xFF3B5D82),
      );
      expect(
        find.byKey(
          ValueKey<String>('offering-table-calendar-dot-$firstDateKey-2'),
        ),
        findsNothing,
      );
      final thirdDateKey = _dateKey(start.add(const Duration(days: 2)));
      expect(
        find.byKey(
          ValueKey<String>('offering-table-calendar-dot-$thirdDateKey-0'),
        ),
        findsNothing,
      );

      final firstBadge = find.byKey(
        const ValueKey<String>('offering-table-preview-event-1'),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('offering-table-scroll')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      await tester.tap(firstBadge);
      await tester.pumpAndSettle();

      var daySheet = find.byType(OfferingTableDaySheet);
      expect(daySheet, findsOneWidget);
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text('DAY 01 OF 30 · PERSONAL TABLE'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('The First Water')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text('Provide for yourself'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('1/10')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('WHY THIS DAY')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text(
            'Provision begins with the most basic need. Today you practice noticing yours before the day takes over.',
          ),
        ),
        findsNothing,
      );
      final progress = find.descendant(
        of: daySheet,
        matching: find.byKey(
          const ValueKey<String>('offering-table-day-sheet-progress'),
        ),
      );
      final yourMove = find.descendant(
        of: daySheet,
        matching: find.text('YOUR MOVE'),
      );
      expect(yourMove, findsOneWidget);
      expect(
        tester.getTopLeft(progress).dy,
        lessThan(tester.getTopLeft(yourMove).dy),
      );
      for (final step in const <String>[
        'Fill a cup of water.',
        'Name one basic need that has been unmet for a few days.',
        'Do the smallest thing that begins to meet it.',
      ]) {
        expect(
          find.descendant(of: daySheet, matching: find.text(step)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: daySheet, matching: find.text('CLOSE THE RITUAL')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('Drink the water.')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('Back to the table')),
        findsOneWidget,
      );
      for (final oldLabel in const <String>[
        'PURPOSE',
        'WATER',
        'WORDS',
        'PROVISION',
        'OPTIONAL',
        'DRINK',
      ]) {
        expect(
          find.descendant(of: daySheet, matching: find.text(oldLabel)),
          findsNothing,
        );
      }
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text(kOfferingTableDays.first.sourceNote!),
        ),
        findsNothing,
      );
      tester
          .widget<InkWell>(
            find.byKey(
              const ValueKey<String>('offering-table-day-sheet-context-toggle'),
            ),
          )
          .onTap!();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: daySheet, matching: find.text('WHY THIS DAY')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text(
            'Provision begins with the most basic need. Today you practice noticing yours before the day takes over.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text(kOfferingTableDays.first.sourceNote!),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text(
            '“${offeringTableDecanLine(kOfferingTableDays.first.dayNumber)}”',
          ),
        ),
        findsOneWidget,
      );
      Navigator.of(tester.element(daySheet)).pop();
      await tester.pumpAndSettle();

      expect(find.text('THE FIRST PRACTICE'), findsNothing);
      expect(find.text('SET YOUR TABLE'), findsNothing);
      expect(find.text('THE FIRST FIVE DAYS'), findsNothing);
      expect(find.text('LENS'), findsNothing);
      expect(find.text('Use the cup you’re already holding'), findsNothing);
      expect(find.text('Begin reflection'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('offering-table-initial-input')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('offering-table-initial-input')),
        'Water and rest',
      );
      expect(find.text('Water and rest'), findsOneWidget);

      final showAll = find.byKey(
        const ValueKey<String>('offering-table-show-all'),
      );
      tester.widget<InkWell>(showAll).onTap!();
      await tester.pumpAndSettle();

      expect(_previewDayCards(), findsNWidgets(5));
      expect(
        find.byKey(const ValueKey<String>('offering-table-preview-day-30')),
        findsNothing,
      );
      expect(find.byType(OfferingTableEventBlockVisual), findsNWidgets(5));
      expect(_compactDayRows(), findsNWidgets(25));
      expect(
        find.byKey(const ValueKey<String>('offering-table-all-day-30')),
        findsOneWidget,
      );

      final sixthRow = find.byKey(
        const ValueKey<String>('offering-table-all-day-6'),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('offering-table-scroll')),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(sixthRow);
      await tester.pumpAndSettle();

      daySheet = find.byType(OfferingTableDaySheet);
      final sixthDay = kOfferingTableDays[5];
      expect(daySheet, findsOneWidget);
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text('DAY 06 OF 30 · PERSONAL TABLE'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('The Small Supply')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text(sixthDay.provisionAct),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text('Tue · Sep 8, 2026 · 7:30 AM'),
        ),
        findsOneWidget,
      );
      Navigator.of(tester.element(daySheet)).pop();
      await tester.pumpAndSettle();

      for (final day in kOfferingTableDays.take(5)) {
        final date = start.add(Duration(days: day.dayNumber - 1));
        final kemetic = KemeticMath.fromGregorian(date);
        final month = getMonthById(kemetic.kMonth);
        final card = find.byKey(
          ValueKey<String>('offering-table-preview-day-${day.dayNumber}'),
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('${month.displayShort} ${kemetic.kDay}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(gregorianDateLabel(date)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('7:30 AM')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(offeringTableEventTitle(day)),
          ),
          findsOneWidget,
        );
      }

      final day30 = kOfferingTableDays.last;
      final day30Date = start.add(const Duration(days: 29));
      final compact30 = find.byKey(
        const ValueKey<String>('offering-table-all-day-30'),
      );
      expect(
        find.descendant(of: compact30, matching: find.text(day30.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: compact30,
          matching: find.textContaining(
            '${day30Date.day}, ${day30Date.year} · 7:30 AM',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: compact30, matching: find.text(day30.section)),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey<String>('offering-table-join')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('day sheet shows the three ten-day journey stages', (
    tester,
  ) async {
    const size = Size(390, 844);

    await _pumpDaySheet(tester, size: size, dayNumber: 5);
    expect(find.text('DAY 05 OF 30 · PERSONAL TABLE'), findsOneWidget);
    expect(find.text('Provide for yourself'), findsOneWidget);
    expect(find.text('5/10'), findsOneWidget);

    await _pumpDaySheet(tester, size: size, dayNumber: 11);
    expect(find.text('DAY 11 OF 30 · HOUSEHOLD TABLE'), findsOneWidget);
    expect(find.text('Provide for what depends on you'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);

    await _pumpDaySheet(tester, size: size, dayNumber: 21);
    expect(find.text('DAY 21 OF 30 · FLOWING TABLE'), findsOneWidget);
    expect(find.text('Return provision to the larger flow'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'carry delegates the draft once and waits for persisted authority',
    (tester) async {
      final selectedDate = DateTime(2026, 9, 3);
      DateTime? joinedDate;
      TrackSkyTimeZone? joinedTimezone;
      OfferingTableLens? joinedLens;
      bool? joinedNoCupMode;
      int? completedFlowId;

      await _pumpPage(
        tester,
        size: const Size(390, 844),
        start: selectedDate,
        timezone: TrackSkyTimeZone.eastern,
        onJoined: (flowId) async => completedFlowId = flowId,
        onJoin:
            ({
              required startDate,
              required timezone,
              required lens,
              required noCupMode,
            }) async {
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
      expect(completedFlowId, 41);
      expect(
        find.byKey(const ValueKey<String>('offering-table-joined')),
        findsNothing,
      );
    },
  );

  for (final fixture in const <({String name, Size size})>[
    (name: 'normal iPhone', size: Size(390, 844)),
    (name: 'narrow', size: Size(320, 700)),
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

      tester
          .widget<GestureDetector>(
            find.byKey(
              const ValueKey<String>('offering-table-preview-event-1'),
            ),
          )
          .onTap!();
      await tester.pumpAndSettle();

      expect(find.byType(OfferingTableDaySheet), findsOneWidget);
      final sheetScroll = find.byKey(
        const ValueKey<String>('offering-table-day-sheet-scroll'),
      );
      final scrollable = find.descendant(
        of: sheetScroll,
        matching: find.byType(Scrollable),
      );
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      await tester.drag(sheetScroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      final after = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(after, greaterThan(before));
      expect(find.text('Back to the table'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
  OfferingTableJoinCallback? onJoin,
  Future<void> Function(int flowId)? onJoined,
  FollowSkyCalendarPreview calendarPreview = FollowSkyCalendarPreview.empty,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: OfferingTableDetailPage(
        timezone: timezone,
        calendarPreview: calendarPreview,
        initialStartDate: start,
        joinedFlowId: joinedFlowId,
        joinedStartDate: joinedStartDate,
        joinedScheduleDates: joinedScheduleDates,
        showBackButton: false,
        onJoined: onJoined ?? (_) async {},
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
  );
  await tester.pump();
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
          child: OfferingTableDaySheet(
            occurrence: OfferingTablePreviewOccurrence(
              day: day,
              date: date,
              startLocal: DateTime(
                date.year,
                date.month,
                date.day,
                kOfferingTableDefaultHour,
                kOfferingTableDefaultMinute,
              ),
            ),
            lens: OfferingTableLens.neutral,
            noCupMode: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _previewDayCards() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('offering-table-preview-day-');
});

Finder _compactDayRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('offering-table-all-day-');
});

Finder _calendarRings() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('offering-table-calendar-ring-');
});

Color? _dotColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
  return (container.decoration as BoxDecoration).color;
}

Color? _ringBorderColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
  final decoration = container.decoration as BoxDecoration;
  return (decoration.border as Border).top.color;
}

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

String _monthDay(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
