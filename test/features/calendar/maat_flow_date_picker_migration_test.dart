import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retained authoring date pickers route through the shared wrapper',
    () async {
      final readingHouse = await File(
        'lib/features/calendar/the_reading_house/presentation/'
        'reading_house_sitting_editor.dart',
      ).readAsString();
      final offeringTable = await File(
        'lib/features/calendar/the_offering_table/presentation/'
        'offering_table_detail_page.dart',
      ).readAsString();
      final readingPicker = _sourceBetween(
        readingHouse,
        'Future<void> _pickDate() async',
        'Future<void> _pickTime() async',
      );
      final offeringPicker = _sourceBetween(
        offeringTable,
        'Future<void> _pickStartDate() async',
        'List<OfferingTablePreviewOccurrence> _previewOccurrences()',
      );

      expect(readingPicker, contains('MaatFlowDatePicker.show'));
      expect(readingPicker, contains('initialDate: _scheduledDate'));
      expect(readingPicker, contains('MaatFlowDatePickerMode.kemetic'));
      expect(readingPicker, contains('DateUtils.dateOnly(picked.date)'));
      expect(offeringPicker, contains('MaatFlowDatePicker.show'));
      expect(offeringPicker, contains('initialDate: _startDate'));
      expect(offeringPicker, contains('MaatFlowDatePickerMode.gregorian'));
      expect(offeringPicker, contains('lockExplicitDate(result.date)'));
      for (final picker in <String>[readingPicker, offeringPicker]) {
        expect(picker, isNot(contains('CupertinoPicker')));
        expect(picker, isNot(contains('showDatePicker(')));
        expect(picker, isNot(contains('showModalBottomSheet')));
      }
    },
  );

  test(
    'retired window-only pickers are absent from active detail authority',
    () async {
      final active = await File(
        'lib/features/calendar/calendar_active_maat_flows.dart',
      ).readAsString();

      for (final retiredPicker in <String>[
        '_pickMoonReturnWindowDate',
        '_pickWagWindowDate',
        '_pickDecanWatchWindowDate',
        '_pickDaysOutsideYearWindowDate',
        '_pickOpenHandWindowDate',
        '_pickMaatDecanWindowDate',
      ]) {
        expect(active, isNot(contains(retiredPicker)), reason: retiredPicker);
      }
      expect(active, contains('Widget _buildDjed()'));
      expect(active, contains('djedNextEnrollmentWindow'));
    },
  );

  test('retained picker state remains owned by each flow surface', () async {
    final offeringTable = await File(
      'lib/features/calendar/the_offering_table/presentation/'
      'offering_table_detail_page.dart',
    ).readAsString();
    final readingHouse = await File(
      'lib/features/calendar/the_reading_house/presentation/'
      'reading_house_sitting_editor.dart',
    ).readAsString();

    expect(offeringTable, contains('_temporalController.lockExplicitDate'));
    expect(offeringTable, contains('_temporalController.startDateForCarry'));
    expect(offeringTable, contains('_temporalController.lockCarried('));
    expect(readingHouse, contains('_placementChosen = true'));
    expect(readingHouse, contains('_scheduledDate = DateUtils.dateOnly'));
  });

  test(
    'Ma_at completion, journal badge, palette, sizing, and scroll contracts remain intact',
    () async {
      final detailShell = await File(
        'lib/features/calendar/presentation/maat_flow_detail_shell.dart',
      ).readAsString();
      final dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      final completion = await File(
        'lib/features/calendar/calendar_completion.dart',
      ).readAsString();

      expect(detailShell, contains('class MaatFlowDetailShell'));
      expect(detailShell, contains('CustomScrollView('));
      expect(detailShell, contains('MaatFlowDetailGeometry.heroHeight'));
      expect(
        detailShell,
        contains('MaatFlowDetailGeometry.bottomContentClearance'),
      );
      expect(detailShell, contains('keyboardIsVisible(context)'));
      expect(detailShell, contains('child: SafeArea('));
      expect(detailShell, contains('top: false'));

      expect(dayView, contains('class _MaatFlowCompletionPanel'));
      expect(dayView, contains('CalendarCompletionPicker'));
      expect(dayView, contains('onCreateContinuity'));
      expect(dayView, contains('CompletionSourceType.maatFlow'));
      expect(completion, contains('CompletionStatus.observed'));
      expect(completion, contains('CompletionStatus.partial'));
      expect(completion, contains('CompletionStatus.skipped'));
      expect(completion, contains('buildCalendarCompletionBadgeToken'));
    },
  );

  test('audit records Ma_at flow date picker preservation contract', () async {
    final audit = await File(
      'docs/stone_register_date_picker_audit.md',
    ).readAsString();

    expect(audit, contains("### Ma'at Flow Date Picker Preservation Contract"));
    expect(audit, contains('MaatFlowDatePicker.show'));
    expect(audit, contains('Observed/Partly/Skipped'));
    expect(audit, contains('journal badge writing'));
    expect(audit, contains('Custom repeat interval'));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start needle: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end needle: $endNeedle');
  return source.substring(start, end);
}
