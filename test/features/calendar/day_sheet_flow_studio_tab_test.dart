import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'day sheet embeds the full Flow Studio navigator as its Flows tab',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final daySheetStart = source.indexOf('void _openDaySheet(');
      final daySheetEnd = source.indexOf(
        '/* ───── Natural language quick add ───── */',
        daySheetStart,
      );
      final daySheet = source.substring(daySheetStart, daySheetEnd);

      expect(daySheet, contains('activeTab: activeDaySheetTab'));
      expect(daySheet, contains('DaySheetTab.flows'));
      expect(
        daySheet,
        contains("debugLabel: 'day_sheet_flow_studio_navigator'"),
      );
      expect(daySheet, contains('_buildEmbeddedFlowStudioHubPage('));
      expect(daySheet, contains('scrollable: false'));
    },
  );

  test(
    'the Flow Studio hub shortcut opens the unified sheet on Flows',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final callbackStart = source.indexOf(
        'void Function(int? flowId) _getFlowStudioCallback()',
      );
      final callbackEnd = source.indexOf(
        'void _openFlowEditorDirectly(',
        callbackStart,
      );
      final callback = source.substring(callbackStart, callbackEnd);

      expect(callback, contains('_openDaySheet('));
      expect(callback, contains('initialTab: DaySheetTab.flows'));
      expect(callback, isNot(contains('_openFlowStudioSheet(rootBuilder:')));
    },
  );
}
