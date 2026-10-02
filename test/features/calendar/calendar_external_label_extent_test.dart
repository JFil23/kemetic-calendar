import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);

  for (final viewport in [
    (name: 'portrait', size: const Size(390, 844), scale: 1.0),
    (name: 'landscape enlarged', size: const Size(844, 390), scale: 1.5),
  ]) {
    for (final month in [1, 13]) {
      for (final mode in [
        (level: MonthExpansionLevel.compact, progress: null),
        (level: MonthExpansionLevel.stacked, progress: null),
        (level: MonthExpansionLevel.labeled, progress: null),
        (level: MonthExpansionLevel.details, progress: null),
        (level: MonthExpansionLevel.labeled, progress: 2.5),
      ]) {
        testWidgets(
          'external labels keep month $month extent ${mode.level.name}/${mode.progress} ${viewport.name}',
          (tester) async {
            tester.view.physicalSize = viewport.size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final longTitle = List.filled(12, 'Long provider title').join(' ');
            final titles = ['10:30', 'Event', longTitle];

            Future<({Size month, List<Rect> days})> render(
              bool external,
            ) async {
              await tester.pumpWidget(
                MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: SizedBox(
                        key: const ValueKey('month-extent-subject'),
                        child: buildCalendarMonthCardLayoutForTesting(
                          kYear: 6267,
                          kMonth: month,
                          expansionLevel: mode.level,
                          expansionProgress: mode.progress,
                          notesForDay: (day) => day != 1
                              ? const []
                              : [
                                  for (var i = 0; i < titles.length; i++)
                                    NoteData(
                                      clientEventId: external
                                          ? 'external:provider-$i'
                                          : 'authored-$i',
                                      title: titles[i],
                                      allDay: false,
                                      start: const TimeOfDay(
                                        hour: 9,
                                        minute: 0,
                                      ),
                                      end: const TimeOfDay(hour: 10, minute: 0),
                                      canonicalEnd: DateTime(2026, 10, 4, 10),
                                      manualColor: Colors.blue,
                                    ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final days = find.byType(CalendarPinchDayAnchor);
              expect(
                days,
                findsNWidgets(
                  month == 13
                      ? (KemeticMath.isLeapKemeticYear(6267) ? 6 : 5)
                      : 30,
                ),
              );
              return (
                month: tester.getSize(
                  find.byKey(const ValueKey('month-extent-subject')),
                ),
                days: [
                  for (var i = 0; i < days.evaluate().length; i++)
                    tester.getRect(days.at(i)),
                ],
              );
            }

            final authored = await render(false);
            final imported = await render(true);
            expect(imported.month, authored.month);
            expect(imported.days, orderedEquals(authored.days));
            if (mode.level == MonthExpansionLevel.labeled ||
                mode.level == MonthExpansionLevel.details) {
              for (final title in ['10:30', 'Event']) {
                expect(find.text(title), findsWidgets);
                for (final text in tester.widgetList<Text>(find.text(title))) {
                  expect(text.maxLines, anyOf(1, 3));
                  expect(text.overflow, TextOverflow.ellipsis);
                }
              }
            }
            if (mode.level == MonthExpansionLevel.details ||
                mode.progress != null) {
              final boundedLabel = '${longTitle.substring(0, 59)}…';
              expect(boundedLabel.length, 60);
              expect(find.text(boundedLabel), findsWidgets);
              expect(find.text(longTitle), findsNothing);
            }
          },
        );
      }
    }
  }
}
