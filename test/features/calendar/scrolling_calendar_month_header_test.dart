import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/calendar_scroll_coordinator.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/scrolling_calendar_month_header.dart';
import 'package:mobile/widgets/month_name_text.dart';

void main() {
  testWidgets('shows the active leading Kemetic month and its year context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.topCenter,
            child: ScrollingCalendarMonthHeader(
              month: getMonthById(4),
              yearLabel: '2026',
              showGregorian: false,
              gregorianMonthName: 'June',
              gregorianYearLabel: '2026',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ka-ḥer-Ka'), findsOneWidget);
    expect(find.text('(Kȝ-ḥr-Kȝ)'), findsOneWidget);
    expect(find.text('Akhet 2026'), findsOneWidget);
    expect(find.byType(MonthNameText), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(ScrollingCalendarMonthHeader)).height,
      ScrollingCalendarMonthHeader.height,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes the active leading month without animation', (
    tester,
  ) async {
    Widget subject(int monthId) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.topCenter,
          child: ScrollingCalendarMonthHeader(
            month: getMonthById(monthId),
            yearLabel: '2026',
            showGregorian: false,
            gregorianMonthName: 'June',
            gregorianYearLabel: '2026',
          ),
        ),
      ),
    );

    await tester.pumpWidget(subject(4));
    expect(find.text('Ka-ḥer-Ka'), findsOneWidget);

    await tester.pumpWidget(subject(5));
    expect(find.text('Ka-ḥer-Ka'), findsNothing);
    expect(find.text('Šef-Bedet'), findsOneWidget);
    expect(find.text('Peret 2026'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the Gregorian month in Gregorian mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.topCenter,
            child: ScrollingCalendarMonthHeader(
              month: getMonthById(5),
              yearLabel: '2026',
              showGregorian: true,
              gregorianMonthName: 'July',
              gregorianYearLabel: '2026',
            ),
          ),
        ),
      ),
    );

    expect(find.text('July'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Šef-Bedet'), findsNothing);
    expect(find.text('(Šf-bdt)'), findsNothing);
    expect(find.text('Peret 2026'), findsNothing);
    expect(find.byType(MonthNameText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps parenthetical month names out of the main calendar scroll',
    (tester) async {
      Future<void> pumpMonth(int kMonth) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              child: buildCalendarMonthCardLayoutForTesting(
                kYear: 6267,
                kMonth: kMonth,
                notesForDay: (_) => const [],
              ),
            ),
          ),
        ),
      );

      await pumpMonth(5);
      expect(find.text('Šef-Bedet'), findsOneWidget);
      expect(find.text('(Šf-bdt)'), findsNothing);
      expect(tester.takeException(), isNull);

      await pumpMonth(13);
      expect(find.text('Heriu Renpet'), findsOneWidget);
      expect(
        find.text('(${getMonthById(13).displayTransliteration})'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Gregorian mode hides Kemetic month titles but keeps decan names',
    (tester) async {
      const month = 5;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              child: buildCalendarMonthCardLayoutForTesting(
                kYear: 6267,
                kMonth: month,
                showGregorian: true,
                notesForDay: (_) => const [],
              ),
            ),
          ),
        ),
      );

      final kemeticTitle = find.text(getMonthById(month).displayShort);
      final titleVisibility = find.ancestor(
        of: kemeticTitle,
        matching: find.byType(Visibility),
      );
      expect(kemeticTitle, findsOneWidget);
      expect(titleVisibility, findsOneWidget);
      expect(tester.widget<Visibility>(titleVisibility).visible, isFalse);
      for (final decanName in DecanMetadata.decanNames[month]!) {
        expect(find.text(decanName), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switches at the buffered final day block toward the future', (
    tester,
  ) async {
    final rig = _LeadingHeaderRig(initialMonth: _month12, offset: 60);
    addTearDown(rig.dispose);
    await tester.pumpWidget(rig.subject());
    await rig.publishGeometry(tester);

    await rig.scrollTo(tester, 77.999);
    expect(rig.coordinator.activeBannerMonth.value, _month12);
    expect(find.text('Mesut-Ra'), findsOneWidget);

    await rig.scrollTo(tester, 78);
    expect(rig.coordinator.activeBannerMonth.value, _heriu);
    expect(find.text('Heriu Renpet'), findsOneWidget);

    await rig.scrollTo(tester, 122.999);
    expect(rig.coordinator.activeBannerMonth.value, _heriu);

    await rig.scrollTo(tester, 123);
    expect(rig.coordinator.activeBannerMonth.value, _thoth);
    expect(find.text('Thoth'), findsOneWidget);
  });

  testWidgets('switches at the buffered final day block toward the past', (
    tester,
  ) async {
    final rig = _LeadingHeaderRig(initialMonth: _thoth, offset: 180);
    addTearDown(rig.dispose);
    await tester.pumpWidget(rig.subject());
    await rig.publishGeometry(tester);

    await rig.scrollTo(tester, 107.001);
    expect(rig.coordinator.activeBannerMonth.value, _thoth);
    expect(find.text('Thoth'), findsOneWidget);

    await rig.scrollTo(tester, 107);
    expect(rig.coordinator.activeBannerMonth.value, _heriu);
    expect(find.text('Heriu Renpet'), findsOneWidget);

    await rig.scrollTo(tester, 62.001);
    expect(rig.coordinator.activeBannerMonth.value, _heriu);

    await rig.scrollTo(tester, 62);
    expect(rig.coordinator.activeBannerMonth.value, _month12);
    expect(find.text('Mesut-Ra'), findsOneWidget);
  });

  test('production banner binds only to coordinator banner authority', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'valueListenable: _calendarScrollCoordinator.activeBannerMonth',
    );
    final end = source.indexOf('Expanded(child: body)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final binding = source.substring(start, end);

    expect(binding, contains('_calendarScrollCoordinator.activeBannerMonth'));
    expect(
      binding,
      contains('_calendarScrollCoordinator.activeGregorianBannerMonth'),
    );
    expect(binding, contains('activeBannerMonth.year'));
    expect(binding, contains('activeBannerMonth.month'));
    expect(binding, contains('showGregorian: _showGregorian'));
    expect(binding, contains('_gregMonthNames[activeGregorianMonth.month]'));
    expect(binding, contains(r"'${activeGregorianMonth.year}'"));
    expect(binding, isNot(contains('gregorianMonthStart')));
    expect(binding, isNot(contains('_lastView')));
    expect(binding, isNot(contains('setState(')));
    expect(binding, isNot(contains('Restoration')));
    expect(binding, isNot(contains('Hydration')));
  });

  testWidgets('fits long month names on a narrow calendar viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.topCenter,
            child: ScrollingCalendarMonthHeader(
              month: getMonthById(7),
              yearLabel: '2026/2027',
              showGregorian: false,
              gregorianMonthName: 'September',
              gregorianYearLabel: '2026',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Rekh-Nedjes'), findsOneWidget);
    expect(find.text('Peret 2026/2027'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _month12 = MonthRef(year: 4, month: 12);
final _heriu = MonthRef(year: 4, month: 13);
final _thoth = MonthRef(year: 5, month: 1);

final _headerSnapshot = CalendarGeometrySnapshot(
  generation: 1,
  sections: [
    _headerGeometry(_month12, 0, 100, finalDayBlockLeading: 70),
    _headerGeometry(_heriu, 100, 130, finalDayBlockLeading: 115),
    _headerGeometry(_thoth, 130, 230, finalDayBlockLeading: 200),
  ],
);

final class _LeadingHeaderRig {
  _LeadingHeaderRig({required MonthRef initialMonth, required this.offset})
    : authoritative = initialMonth {
    coordinator = CalendarScrollCoordinator(
      initialBannerMonth: initialMonth,
      initialGregorianBannerMonth: const GregorianMonthRef(
        year: 2026,
        month: 1,
      ),
      scheduleAfterFrame: _scheduled.addLast,
      readSnapshot: () => _headerSnapshot,
      readScrollOffset: () => offset,
      readAuthoritativeMonth: () => authoritative,
      readLegacyCandidate: (_) => authoritative,
    );
  }

  final ListQueue<VoidCallback> _scheduled = ListQueue<VoidCallback>();
  double offset;
  MonthRef authoritative;
  late final CalendarScrollCoordinator coordinator;

  Widget subject() {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<MonthRef>(
            valueListenable: coordinator.activeBannerMonth,
            builder: (context, activeMonth, child) {
              return ScrollingCalendarMonthHeader(
                month: getMonthById(activeMonth.month),
                yearLabel: activeMonth.year.toString(),
                showGregorian: false,
                gregorianMonthName: 'January',
                gregorianYearLabel: '2026',
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> publishGeometry(WidgetTester tester) async {
    coordinator.noteGeometryPublication();
    _scheduled.removeFirst()();
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, double nextOffset) async {
    offset = nextOffset;
    coordinator.noteScroll();
    _scheduled.removeFirst()();
    await tester.pumpAndSettle();
  }

  void dispose() {
    coordinator.dispose();
  }
}

CalendarSectionGeometry _headerGeometry(
  MonthRef month,
  num leading,
  num trailing, {
  num? finalDayBlockLeading,
}) {
  return CalendarSectionGeometry(
    month: month,
    extent: CalendarCanonicalExtent(
      leading: leading.toDouble(),
      trailing: trailing.toDouble(),
    ),
    finalDayBlockLeading: finalDayBlockLeading?.toDouble(),
  );
}
