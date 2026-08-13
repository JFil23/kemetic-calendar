import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/scrolling_calendar_month_header.dart';
import 'package:mobile/widgets/month_name_text.dart';

void main() {
  testWidgets('shows the centered Kemetic month and its year context', (
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

  testWidgets('cross-fades when the centered month changes', (tester) async {
    Widget subject(int monthId) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.topCenter,
          child: ScrollingCalendarMonthHeader(
            month: getMonthById(monthId),
            yearLabel: '2026',
          ),
        ),
      ),
    );

    await tester.pumpWidget(subject(4));
    expect(find.text('Ka-ḥer-Ka'), findsOneWidget);

    await tester.pumpWidget(subject(5));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Ka-ḥer-Ka'), findsOneWidget);
    expect(find.text('Šef-Bedet'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Ka-ḥer-Ka'), findsNothing);
    expect(find.text('Šef-Bedet'), findsOneWidget);
    expect(find.text('Peret 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
