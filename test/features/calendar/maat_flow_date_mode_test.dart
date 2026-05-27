import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ma_at flow hub and list use the readable Ma_at Flows label', () {
    final modelsSource = File(
      'lib/features/calendar/calendar_flow_studio_models.dart',
    ).readAsStringSync();
    final hubSource = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
    final calendarSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(modelsSource, contains('const String _kMaatFlowsDisplayTitle'));
    expect(modelsSource, contains('"Ma\'at Flows"'));
    expect(hubSource, contains('title: _kMaatFlowsDisplayTitle'));
    expect(calendarSource, contains('title: _kMaatFlowsDisplayTitle'));
  });

  test('Ma_at flow added state refreshes from flow filing data', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final listSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('_flowMatchesActiveMaatTemplate'));
    expect(source, contains("source: 'open_maat_flows'"));
    expect(source, contains('flowsRepo.refreshMyFiledFlows()'));
    expect(source, contains('isFlowScheduleOpenLocally'));
    expect(listSource, contains('class _MaatFlowsListPageWithSnapshot'));
  });

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
