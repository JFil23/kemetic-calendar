import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup calendar first paint does not eagerly build current year', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    final scrollViewStart = source.indexOf('Widget _buildCalendarScrollView()');
    expect(scrollViewStart, isNot(-1));
    final flowIndexStart = source.indexOf(
      'Map<int, FlowData> _buildCalendarFlowChromeIndex()',
      scrollViewStart,
    );
    expect(flowIndexStart, isNot(-1));
    final scrollViewSource = source.substring(scrollViewStart, flowIndexStart);

    expect(
      scrollViewSource,
      isNot(contains('child: _YearSection(')),
      reason:
          'The current year must be split into month-level slivers so the '
          'first drawable frame does not construct every month/day card before '
          'showing cached calendar content.',
    );
    expect(scrollViewSource, contains('_buildCurrentYearMonthSliver('));
    expect(
      scrollViewSource,
      contains('_shouldUseStartupSingleMonthCalendar'),
      reason:
          'A valid warm cache must draw a single selected month before the '
          'full current-year scroll tree is allowed to build.',
    );
    expect(
      source,
      contains('void _scheduleFullCalendarScrollAfterStartupFrame()'),
    );
    expect(source, contains('int _currentYearCenterMonthForScroll()'));
  });
}
