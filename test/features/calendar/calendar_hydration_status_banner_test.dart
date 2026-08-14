import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_hydration_status_banner.dart';

void main() {
  test('failure availability distinguishes stale from unavailable', () {
    expect(
      calendarAvailabilityAfterFailure(hasFallbackSnapshot: true),
      CalendarHydrationAvailability.stale,
    );
    expect(
      calendarAvailabilityAfterFailure(hasFallbackSnapshot: false),
      CalendarHydrationAvailability.unavailable,
    );
  });

  test('completeness freshness and refresh outcome remain independent', () {
    final refreshedAt = DateTime.utc(2026, 8, 14, 6);
    final pendingCold = CalendarHydrationStatus(
      visibleViewportComplete: false,
      lastSuccessfulRefreshAtUtc: null,
      latestRefreshStatus: CalendarRefreshStatus.pending,
      hasUsableSnapshot: false,
      accountingStale: false,
    );
    expect(
      pendingCold.calendarAvailability,
      CalendarHydrationAvailability.current,
    );
    expect(pendingCold.visibleViewportComplete, isFalse);
    expect(pendingCold.latestRefreshStatus, CalendarRefreshStatus.pending);

    final failedWarm = CalendarHydrationStatus(
      visibleViewportComplete: true,
      lastSuccessfulRefreshAtUtc: refreshedAt,
      latestRefreshStatus: CalendarRefreshStatus.failed,
      hasUsableSnapshot: true,
      accountingStale: false,
    );
    expect(
      failedWarm.calendarAvailability,
      CalendarHydrationAvailability.stale,
    );
    expect(failedWarm.visibleViewportComplete, isTrue);
    expect(failedWarm.lastSuccessfulRefreshAtUtc, refreshedAt);

    final failedCold = CalendarHydrationStatus(
      visibleViewportComplete: false,
      lastSuccessfulRefreshAtUtc: null,
      latestRefreshStatus: CalendarRefreshStatus.failed,
      hasUsableSnapshot: false,
      accountingStale: false,
    );
    expect(
      failedCold.calendarAvailability,
      CalendarHydrationAvailability.unavailable,
    );
  });

  testWidgets('current calendar and accounting render no warning', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      calendar: CalendarHydrationAvailability.current,
      accountingStale: false,
    );

    expect(find.textContaining('Calendar'), findsNothing);
    expect(find.text('Flow totals may be out of date.'), findsNothing);
  });

  testWidgets('stale calendar is distinct from stale accounting', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      calendar: CalendarHydrationAvailability.stale,
      accountingStale: true,
    );

    expect(
      find.text('Calendar may be out of date. It will retry when you return.'),
      findsOneWidget,
    );
    expect(find.text('Flow totals may be out of date.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-hydration-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-accounting-status')),
      findsOneWidget,
    );
  });

  testWidgets('cold failure reports unavailable rather than empty complete', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      calendar: CalendarHydrationAvailability.unavailable,
      accountingStale: false,
    );

    expect(
      find.text(
        'Calendar is temporarily unavailable. It will retry when you return.',
      ),
      findsOneWidget,
    );
    expect(find.text('Flow totals may be out of date.'), findsNothing);
  });

  testWidgets('accounting failure alone does not label calendar stale', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      calendar: CalendarHydrationAvailability.current,
      accountingStale: true,
    );

    expect(find.textContaining('Calendar may'), findsNothing);
    expect(find.textContaining('Calendar is'), findsNothing);
    expect(find.text('Flow totals may be out of date.'), findsOneWidget);
  });
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  required CalendarHydrationAvailability calendar,
  required bool accountingStale,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CalendarHydrationStatusBanner(
          calendarAvailability: calendar,
          accountingStale: accountingStale,
        ),
      ),
    ),
  );
}
