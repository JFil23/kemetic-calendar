import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_refresh_state.dart';

void main() {
  test('refresh outcome remains independent from presented data authority', () {
    final refreshedAt = DateTime.utc(2026, 8, 14, 6);
    final state = CalendarRefreshState(
      visibleViewportComplete: true,
      lastSuccessfulRefreshAtUtc: refreshedAt,
      latestRefreshStatus: CalendarRefreshStatus.failed,
      hasUsableSnapshot: true,
    );

    expect(state.visibleViewportComplete, isTrue);
    expect(state.hasUsableSnapshot, isTrue);
    expect(state.lastSuccessfulRefreshAtUtc, refreshedAt);
    expect(state.latestRefreshStatus, CalendarRefreshStatus.failed);
  });

  test('calendar refresh state cannot mount presentation chrome', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final state = File(
      'lib/features/calendar/calendar_refresh_state.dart',
    ).readAsStringSync();

    for (final source in <String>[page, dayView, state]) {
      expect(source, isNot(contains('CalendarHydrationStatusBanner')));
      expect(source, isNot(contains('CalendarHydrationAvailability')));
      expect(source, isNot(contains('Calendar may be out of date')));
      expect(source, isNot(contains('Calendar is temporarily unavailable')));
    }
  });
}
