import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ma_at flow detail pages default to Kemetic date mode', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('bool _useKemetic = true;'));
    expect(source, contains('void _toggleDateMode()'));
    expect(source, contains('Widget _buildDateModeTitle'));
    expect(source, contains("label: _useKemetic ? 'Show Gregorian dates'"));
    expect(source, contains('gradient: _useKemetic ? goldGloss : whiteGloss'));
  });

  test(
    'Ma_at flow date references route through the shared date formatter',
    () {
      final source = File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('String _dateLabel(BuildContext context, DateTime date)'),
      );
      expect(source, contains('_startDateButtonLabel(context, selectedStart)'));
      expect(
        source,
        contains(r'First dawn: ${_dateLabel(context, selectedStart)}'),
      );
      expect(
        source,
        contains(r'First evening: ${_dateLabel(context, selectedStart)}'),
      );
      expect(
        source,
        contains(r'First sitting: ${_dateLabel(context, selectedStart)}'),
      );
      expect(
        source,
        isNot(contains(r'Start: ${_fmtGregorian(selectedStart)}')),
      );
      expect(source, isNot(contains('CupertinoSegmentedControl<bool>')));
    },
  );
}
