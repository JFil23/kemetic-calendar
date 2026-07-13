import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup calendar keeps one lazy authoritative portrait tree', () {
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
      contains('_buildCenterYearMonthSliver('),
      reason:
          'The restored center year must remain split into lazy month slivers.',
    );
    expect(scrollViewSource, isNot(contains('child: _YearSection(')));
    expect(
      scrollViewSource,
      isNot(contains('_shouldUseStartupSingleMonthCalendar')),
    );
    expect(source, isNot(contains('calendar_portrait_scroll_startup_month')));
    expect(
      source,
      isNot(contains('void _scheduleFullCalendarScrollAfterStartupFrame()')),
      reason:
          'Startup must not replace a temporary tree with a second calendar.',
    );
    expect(source, contains('int _centerYearMonthForScroll(int baseYear)'));
  });
}
