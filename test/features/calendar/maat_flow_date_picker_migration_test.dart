import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Ma_at generic date picker routes only through Stone Register wrapper',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsString();
      final picker = _sourceBetween(
        source,
        'Future<void> _pickDate() async',
        'Future<void> _pickMoonReturnWindowDate() async',
      );

      expect(picker, contains('MaatFlowDatePicker.show'));
      expect(picker, contains('initialDate: _picked'));
      expect(picker, contains('initialMode: _useKemetic'));
      expect(picker, contains('MaatFlowDatePickerMode.kemetic'));
      expect(picker, contains('MaatFlowDatePickerMode.gregorian'));
      expect(picker, contains('_picked = DateUtils.dateOnly(picked.date)'));
      expect(picker, contains('_markGenericMaatStartDateTouched()'));
      expect(picker, isNot(contains('CupertinoPicker')));
      expect(picker, isNot(contains('FixedExtentScrollController')));
      expect(picker, isNot(contains('showModalBottomSheet')));
      expect(picker, isNot(contains('Use this date')));
      expect(_occurrences(source, 'MaatFlowDatePicker.show'), 1);
    },
  );

  test(
    'Ma_at window-only pickers remain outside generic date migration',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsString();
      final picker = _sourceBetween(
        source,
        'Future<void> _pickDate() async',
        'Future<void> _pickMoonReturnWindowDate() async',
      );
      final wrapperIndex = picker.indexOf('MaatFlowDatePicker.show');

      for (final call in <String>[
        '_pickMoonReturnWindowDate',
        '_pickWagWindowDate',
        '_pickDecanWatchWindowDate',
        '_pickDaysOutsideYearWindowDate',
        '_pickOpenHandWindowDate',
        '_pickDjedWindowDate',
        '_pickMaatDecanWindowDate',
      ]) {
        final index = picker.indexOf(call);
        expect(index, isNonNegative, reason: '$call should remain routed');
        expect(
          index,
          lessThan(wrapperIndex),
          reason: '$call must stay special',
        );
      }

      for (final functionName in <String>[
        '_pickMoonReturnWindowDate',
        '_pickWagWindowDate',
        '_pickDecanWatchWindowDate',
        '_pickDaysOutsideYearWindowDate',
        '_pickOpenHandWindowDate',
        '_pickDjedWindowDate',
        '_pickMaatDecanWindowDate',
      ]) {
        final windowPicker = _sourceBetween(
          source,
          'Future<void> $functionName() async',
          functionName == '_pickMaatDecanWindowDate'
              ? 'Future<void> _pickDaysOutsideYearWindowDate() async'
              : _nextWindowPickerMarker(functionName),
        );
        expect(windowPicker, contains('window.opensAtLocal'));
        expect(windowPicker, contains('ListView.separated'));
        expect(windowPicker, isNot(contains('MaatFlowDatePicker.show')));
      }
    },
  );

  test('Ma_at touched flags and join state remain caller-owned', () async {
    final source = await File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsString();
    final touched = _sourceBetween(
      source,
      'void _markGenericMaatStartDateTouched()',
      'Future<void> _pickMoonReturnWindowDate() async',
    );
    final startRow = _sourceBetween(
      source,
      'Widget _buildStartDateRow',
      'Widget _buildDetailChoiceChips',
    );
    final sequenceJoin = _sourceBetween(
      source,
      'Widget _buildSequenceScaffold(BuildContext context)',
      '@override\n  Widget build(BuildContext context)',
    );

    for (final flag in <String>[
      '_dawnStartDateTouched',
      '_eveningThresholdStartDateTouched',
      '_eveningStartDateTouched',
      '_theWeighingStartDateTouched',
      '_offeringStartDateTouched',
      '_theTendingStartDateTouched',
      '_keptWordStartDateTouched',
      '_courseStartDateTouched',
    ]) {
      expect(touched, contains('$flag = true'));
    }
    expect(startRow, contains('onPressed: _pickDate'));
    expect(startRow, contains('minimumSize: const Size.fromHeight(60)'));
    expect(sequenceJoin, contains('startDate: _picked!'));
    expect(sequenceJoin, contains('useKemetic: _useKemetic'));
    expect(sequenceJoin, contains('_startDateButtonLabel(context, _picked!)'));
  });

  test(
    'Ma_at completion, journal badge, palette, sizing, and scroll contracts remain intact',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsString();
      final dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      final completion = await File(
        'lib/features/calendar/calendar_completion.dart',
      ).readAsString();

      final detailScaffold = _sourceBetween(
        source,
        'Widget _buildMaatFlowDetailScaffold',
        'List<Widget> _buildMaatFlowOverviewZones',
      );
      expect(source, contains('MaatFlowPalette get _palette'));
      expect(detailScaffold, contains('final scrollBottomPadding ='));
      expect(detailScaffold, contains('MaatFlowListTokens.pageBg'));
      expect(detailScaffold, contains('ListView('));
      expect(detailScaffold, contains('final bodyPadding = embedded'));
      expect(detailScaffold, contains('final ctaPadding = embedded'));
      expect(detailScaffold, contains('bottomNavigationBar: SafeArea'));
      expect(detailScaffold, contains('BoxConstraints(maxWidth: 720)'));

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

String _nextWindowPickerMarker(String functionName) {
  return switch (functionName) {
    '_pickMoonReturnWindowDate' => 'Future<void> _pickWagWindowDate() async',
    '_pickWagWindowDate' => 'Future<void> _pickDecanWatchWindowDate() async',
    '_pickDecanWatchWindowDate' =>
      'Future<void> _pickOpenHandWindowDate() async',
    '_pickDaysOutsideYearWindowDate' => 'void _setTrackSkyPreviewTimeZone',
    '_pickOpenHandWindowDate' => 'Future<void> _pickDjedWindowDate() async',
    '_pickDjedWindowDate' => 'Future<void> _pickMaatDecanWindowDate() async',
    _ => throw ArgumentError.value(functionName, 'functionName'),
  };
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start needle: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end needle: $endNeedle');
  return source.substring(start, end);
}

int _occurrences(String source, String needle) {
  var count = 0;
  var index = 0;
  while (true) {
    index = source.indexOf(needle, index);
    if (index < 0) return count;
    count += 1;
    index += needle.length;
  }
}
