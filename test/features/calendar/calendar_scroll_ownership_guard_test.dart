import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('scroll frames have one semantic owner and no persistence writer', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final onScroll = _between(
      source,
      '  void _onVerticalScroll() {',
      '  void _handleCoordinatorCenteredMonth() {',
    );
    final centered = _between(
      source,
      '  void _handleCoordinatorCenteredMonth() {',
      '  MonthRef? _shadowAuthoritativeMonth() {',
    );
    final scrollView = _between(
      source,
      '  Widget _buildCalendarScrollView() {',
      '  Map<int, FlowData> _buildCalendarFlowChromeIndex()',
    );

    expect(onScroll, contains('_calendarScrollCoordinator.noteScroll()'));
    expect(onScroll, isNot(contains('_saveCalendarRestorationNow')));
    expect(onScroll, isNot(contains('_persistCalendarRestorationState')));
    expect(centered, isNot(contains('_setView(')));
    expect(centered, isNot(contains('setState(')));
    expect(centered, isNot(contains('_scheduleCalendarRestorationSave')));
    expect(centered, isNot(contains('_scheduleMonthHydrationFrame')));
    expect(scrollView, contains('notification is ScrollStartNotification'));
    expect(scrollView, isNot(contains('notification.dragDetails != null')));
  });

  test('Today owns mounting, animation, and epoch settlement', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final travel = _between(
      source,
      '  Future<bool> _travelToTodayInActiveEpoch',
      '  double? _centeredScrollOffsetForContext',
    );
    final command = _between(
      source,
      '  Future<void> _scrollToTodayWithResolvedTarget',
      '  void _centerMonth(',
    );

    expect(travel, contains('final currentYearOrigin = 0.0.clamp('));
    expect(travel, contains('await WidgetsBinding.instance.endOfFrame'));
    expect(travel, contains('final exactTarget = resolveTarget()'));
    expect(command, contains('_beginCalendarTodayPresentationTransaction()'));
    expect(command, contains('_settleCalendarTodayPresentationTransaction('));
    expect(command, isNot(contains('destination can move underneath it')));
  });

  test('repeated month paint has one boundary and no save-layer stack', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final grid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    final divider = _between(
      page,
      'class _GoldDivider',
      'String _reminderRepeatLabelForPicker',
    );
    final title = _between(
      grid,
      'class _SoftMonthNameTitle',
      'class _MonthCard',
    );
    final dayChip = _between(grid, 'class _DayChip', 'class _ColorDot');

    for (final repeatedPath in <String>[divider, title, dayChip]) {
      expect(repeatedPath, isNot(contains('ShaderMask(')));
      expect(repeatedPath, isNot(contains('Opacity(')));
    }
    expect(divider, isNot(contains('RepaintBoundary(')));
    expect(dayChip, isNot(contains('RepaintBoundary(')));
    expect(divider, contains('gradient: LinearGradient('));
    expect(
      RegExp(r'RepaintBoundary\(').allMatches(grid),
      hasLength(1),
      reason: 'The month body is the sole repeated-paint layer owner.',
    );
  });

  test('geometry publishes on structural layout changes, not every layout', () {
    final source = File(
      'lib/features/calendar/calendar_geometry_collector.dart',
    ).readAsStringSync();

    expect(
      RegExp(r'if \(_lastReportedSize != size\)').allMatches(source),
      hasLength(3),
    );
    expect(
      RegExp(r'_lastReportedSize = null;').allMatches(source),
      hasLength(3),
    );
  });
}
