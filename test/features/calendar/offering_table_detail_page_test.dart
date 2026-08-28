import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' hide KemeticMath;
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/track_sky_event_block_visual.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_sheet.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
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
      expect(find.text('WHAT WAS FED?'), findsOneWidget);
      expect(find.text('What did you provide today?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('offering-table-initial-input')),
        findsOneWidget,
      );
      expect(firstPreview, findsOneWidget);

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
      expect(find.byType(TrackSkyEventBlockVisual), findsNWidgets(5));
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
          matching: find.text('DAY 01 · PERSONAL TABLE'),
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
          matching: find.text(kOfferingTableDays.first.provisionAct),
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
      expect(find.byType(TrackSkyEventBlockVisual), findsNWidgets(5));
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
          matching: find.text('DAY 06 · PERSONAL TABLE'),
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

  testWidgets('carry retains the existing default join arguments', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 9, 3);
    DateTime? joinedDate;
    TrackSkyTimeZone? joinedTimezone;
    OfferingTableLens? joinedLens;
    bool? joinedNoCupMode;

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
            joinedDate = startDate;
            joinedTimezone = timezone;
            joinedLens = lens;
            joinedNoCupMode = noCupMode;
            return 41;
          },
    );

    await tester.tap(find.byKey(const ValueKey<String>('offering-table-join')));
    await tester.pumpAndSettle();

    expect(joinedDate, selectedDate);
    expect(joinedTimezone, TrackSkyTimeZone.eastern);
    expect(joinedLens, OfferingTableLens.neutral);
    expect(joinedNoCupMode, isFalse);
    final firstDateKey = _dateKey(selectedDate);
    expect(
      _ringFillColor(tester, 'offering-table-calendar-ring-$firstDateKey'),
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey<String>('offering-table-joined')),
      findsOneWidget,
    );
  });

  for (final fixture in const <({String name, Size size})>[
    (name: 'normal iPhone', size: Size(390, 844)),
    (name: 'narrow', size: Size(320, 700)),
  ]) {
    testWidgets('${fixture.name} layout remains overflow-free', (tester) async {
      await _pumpPage(tester, size: fixture.size, start: DateTime(2026, 9, 3));
      await tester.drag(
        find.byKey(const ValueKey<String>('offering-table-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
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
  required DateTime start,
  TrackSkyTimeZone timezone = TrackSkyTimeZone.pacific,
  OfferingTableJoinCallback? onJoin,
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
        showBackButton: false,
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

Color? _dotColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
  return (container.decoration as BoxDecoration).color;
}

Color? _ringBorderColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
  final decoration = container.decoration as BoxDecoration;
  return (decoration.border as Border).top.color;
}

Color? _ringFillColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey<String>(key)));
  return (container.decoration as BoxDecoration).color;
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
