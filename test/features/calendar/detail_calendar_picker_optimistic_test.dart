import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail calendar picker updates selection before async save', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final picker = _sourceBetween(
      source,
      'Future<DayViewSheetEventTarget?> _showDetailSheetCalendarPicker',
      'void _showCalendarActionMessage',
    );

    expect(picker, contains('var selectedCalendarId = currentCalendarId;'));
    expect(picker, contains('String? savingCalendarId;'));
    expect(picker, contains('calendar.id == selectedCalendarId'));
    expect(picker, contains('CircularProgressIndicator'));
    expect(
      picker.indexOf('selectedCalendarId = calendarId;'),
      lessThan(picker.indexOf('_reassignDetailTargetCalendar(')),
    );
    expect(
      picker.indexOf('onOptimisticTargetChanged?.call(optimisticTarget);'),
      lessThan(picker.indexOf('_reassignDetailTargetCalendar(')),
    );
    expect(
      picker,
      contains(
        'onOptimisticTargetChanged?.call(\n'
        '                  _detailSheetTargetWithCalendar(target, previousCalendarId),',
      ),
    );
    expect(picker, contains("saveError = 'Unable to change calendar.';"));
    expect(picker, isNot(contains('_notifySharedCalendarItemAdded')));
  });

  test('detail sheet parents receive optimistic calendar target', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();

    expect(dayView, contains('onOptimisticTargetChanged: (optimisticTarget)'));
    expect(dayView, contains('_moveToTarget(optimisticTarget);'));
    expect(landscape, contains('CalendarEventDetailSheet('));
    expect(landscape, contains('onTargetChanged: moveToTarget'));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start marker: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end marker: $endNeedle');
  return source.substring(start, end);
}
