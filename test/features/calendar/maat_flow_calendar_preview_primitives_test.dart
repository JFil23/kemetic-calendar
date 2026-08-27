import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';

void main() {
  const calendarTheme = MaatFlowThirtyDayCalendarTheme(
    introText: Color(0xFFE0D8C8),
    introEmphasis: Color(0xFFB8AD9B),
    border: Color(0x443F2B15),
    month: Color(0xFFC99A3D),
    monthTransliteration: Color(0xFF9A7635),
    decan: Color(0xFFA9853D),
    day: Color(0xFFB59150),
    today: Color(0xFFF0C96A),
    highlight: Color(0xFFC99A3D),
  );
  const previewTheme = MaatFlowPreviewTheme(
    surface: Color(0xFF160F07),
    border: Color(0x3DC99A3D),
    shadow: Color(0x0AC99A3D),
    kemeticDate: Color(0xFFC99A3D),
    gregorianDate: Color(0xFFD3B06A),
    divider: Color(0x2BC99A3D),
    primaryText: Color(0xFFD7CDBA),
    secondaryText: Color(0xFFA59D91),
  );

  testWidgets('shared calendar renders thirty marked dates by Kemetic decan', (
    tester,
  ) async {
    final start = DateTime(2026, 9, 3);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MaatFlowThirtyDayCalendar(
              windowStart: start,
              markers: [
                for (var offset = 0; offset < 30; offset++)
                  MaatFlowThirtyDayMarker(
                    date: start.add(Duration(days: offset)),
                    secondaryColors: const [Color(0xFFC99A3D)],
                  ),
              ],
              theme: calendarTheme,
              introFirstLine: 'Here is your table.',
              introSecondLine: 'For the next thirty days.',
              keyPrefix: 'test-calendar',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var offset = 0; offset < 30; offset++) {
      final date = start.add(Duration(days: offset));
      final key = _dateKey(date);
      expect(
        find.byKey(ValueKey<String>('test-calendar-day-$key')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('test-calendar-dot-$key-0')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared preview card keeps date and event hierarchy at 320', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 3);
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: MaatFlowPreviewDayCard(
              date: date,
              theme: previewTheme,
              children: const [
                MaatFlowPreviewEventRow(
                  timeLabel: '7:30 AM',
                  title: 'Day 1: The First Water',
                  subtitle: 'Personal Table · Place the first water.',
                  accent: Color(0xFFC99A3D),
                  theme: previewTheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(gregorianDateLabel(date)), findsOneWidget);
    expect(find.text('7:30 AM'), findsOneWidget);
    expect(find.text('Day 1: The First Water'), findsOneWidget);
    expect(find.textContaining('Personal Table'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
