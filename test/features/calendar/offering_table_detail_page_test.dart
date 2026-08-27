import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' hide KemeticMath;
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/track_sky_event_block_visual.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
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

    expect(find.byType(OfferingTableDetailPage), findsOneWidget);
    expect(find.byType(MaatFlowDetailShell), findsOneWidget);
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
      await _pumpPage(tester, size: size, start: start);

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

      for (var offset = 0; offset < 30; offset++) {
        final date = start.add(Duration(days: offset));
        final dateKey = _dateKey(date);
        expect(
          find.byKey(ValueKey<String>('offering-table-calendar-day-$dateKey')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey<String>('offering-table-calendar-dot-$dateKey-0'),
          ),
          findsOneWidget,
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

      expect(_previewDayCards(), findsNWidgets(30));
      expect(
        find.byKey(const ValueKey<String>('offering-table-preview-day-30')),
        findsOneWidget,
      );
      expect(find.byType(TrackSkyEventBlockVisual), findsNWidgets(30));

      for (final day in kOfferingTableDays) {
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
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: OfferingTableDetailPage(
        timezone: timezone,
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

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
