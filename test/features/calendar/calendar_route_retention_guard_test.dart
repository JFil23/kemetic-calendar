import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _calendarBuildSource(String source) {
  final start = source.indexOf(
    '  @override\n  Widget build(BuildContext context) {',
  );
  expect(start, isNot(-1));
  final end = source.indexOf(
    '  Widget _buildInitialCalendarLoadingScaffold()',
    start,
  );
  expect(end, isNot(-1));
  return source.substring(start, end);
}

void main() {
  test('covered retained Calendar keeps its rendered subtree', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final build = _calendarBuildSource(source);

    expect(
      build,
      isNot(contains('routeShouldRemainRendered')),
      reason:
          'A Calendar retained beneath a drawer destination must stay built; '
          'substituting an empty Scaffold forces a cold repaint on reveal.',
    );
    expect(
      build,
      isNot(
        contains(
          'return const Scaffold(backgroundColor: _bg, body: SizedBox.shrink())',
        ),
      ),
    );
  });
}
