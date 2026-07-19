import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing start marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing end marker: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('mounted Calendar Today is one in-place animated viewport command', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final openToday = _sourceBetween(
      source,
      'static void openMainCalendarAtToday(',
      '  // Static method for parsing rules from JSON',
    );
    final applyToday = _sourceBetween(
      source,
      'void _applyTodayNavigationCommand(',
      '  bool _consumePendingTodayNavigationCommand',
    );

    expect(openToday, contains('bool animate = true'));
    expect(
      openToday,
      contains(
        'if (mountedState != null && '
        'mountedState._isPrimaryCalendarRouteCurrent)',
      ),
      reason: 'A mounted current Calendar must not be routed through go(/).',
    );
    final mountedBranchStart = openToday.indexOf(
      'if (mountedState != null && '
      'mountedState._isPrimaryCalendarRouteCurrent)',
    );
    final routeStart = openToday.indexOf(
      'final router = GoRouter.of(context);',
    );
    expect(mountedBranchStart, isNonNegative);
    expect(routeStart, greaterThan(mountedBranchStart));
    final mountedBranch = openToday.substring(mountedBranchStart, routeStart);
    expect(mountedBranch, contains('_applyTodayNavigationCommand('));
    expect(mountedBranch, contains('animate: true'));
    expect(mountedBranch, contains('return;'));
    expect(mountedBranch, isNot(contains("router.go('/')")));
    expect(mountedBranch, isNot(contains('_scheduleTodayJumpAfterNavigation')));

    expect(
      applyToday,
      isNot(contains('_applyTodayFallbackAfterRestore')),
      reason: 'User Today must not start the restoration fallback writer.',
    );
    expect(applyToday, isNot(contains('_scheduleInitialViewportRestore')));
    expect(applyToday, contains('_setView(_today.kYear, _today.kMonth'));
    expect(applyToday, contains('_scrollToToday(animate: animate)'));
    expect(
      RegExp(r'_scrollToToday\(').allMatches(applyToday),
      hasLength(1),
      reason: 'Mounted Today owns exactly one viewport command.',
    );
  });
}
