import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('center year keeps the July 10 single YearSection topology', () {
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
      contains(
        'SliverToBoxAdapter(\n            key: _centerKey,\n            child: _YearSection(',
      ),
      reason:
          'The controlled paint A/B keeps the center year in one persistent '
          'YearSection instead of thirteen independently mounted slivers.',
    );
    expect(scrollViewSource, isNot(contains('_buildCenterYearMonthSliver(')));
    expect(
      scrollViewSource,
      isNot(contains('for (var month = 1; month <= 13; month++)')),
    );
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
    expect(
      scrollViewSource,
      contains(
        'final baseYear = _calendarScrollBaseYear ?? _lastViewKy ?? '
        'kToday.kYear;',
      ),
      reason: 'The topology A/B must preserve the restored center-year base.',
    );
  });
}
