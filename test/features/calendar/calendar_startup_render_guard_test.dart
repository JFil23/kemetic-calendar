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

  test('portrait year dividers do not retain compositor-only layers', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final dividerStart = source.indexOf('class _GoldDivider');
    expect(dividerStart, isNot(-1));
    final dividerEnd = source.indexOf(
      'String _reminderRepeatLabelForPicker',
      dividerStart,
    );
    expect(dividerEnd, isNot(-1));
    final dividerSource = source.substring(dividerStart, dividerEnd);

    expect(dividerSource, isNot(contains('RepaintBoundary(')));
    expect(dividerSource, isNot(contains('Opacity(')));
    expect(dividerSource, isNot(contains('ShaderMask(')));
    expect(
      dividerSource,
      contains('gradient: LinearGradient('),
      reason: 'The divider should keep its gold treatment without save layers.',
    );
  });
}
