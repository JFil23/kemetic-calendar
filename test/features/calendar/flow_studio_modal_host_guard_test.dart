import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Flow Studio modal sheets share one outer host without collapsing routes',
    () {
      final calendar = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final host = File(
        'lib/features/calendar/presentation/flow_studio_modal_sheet_host.dart',
      ).readAsStringSync();

      expect(host, contains('class FlowStudioModalSheetHost'));
      expect(host, contains('DraggableScrollableSheet('));
      expect(host, contains('heightFactor: 0.9'));

      final detached = calendar.substring(
        calendar.indexOf('static Future<void> _openDetachedFlowStudioSheet'),
        calendar.indexOf('static bool _sameRouteLocation'),
      );
      final mounted = calendar.substring(
        calendar.indexOf('Future<void> _openFlowStudioSheet({'),
        calendar.indexOf('// Directly open My Flows list'),
      );

      expect(detached, contains('FlowStudioModalSheetHost('));
      expect(mounted, contains('FlowStudioModalSheetHost('));
      expect(detached, isNot(contains('DraggableScrollableSheet(')));
      expect(mounted, isNot(contains('DraggableScrollableSheet(')));
      expect(detached, isNot(contains('heightFactor: 0.9')));
      expect(mounted, isNot(contains('heightFactor: 0.9')));

      expect(calendar, contains('class _FlowStudioRoutePage extends'));
      expect(calendar, contains('class _FlowEditorRoutePage extends'));
      expect(calendar, contains('embeddedInDaySheet: true'));
      expect(calendar, contains("GoRouter.of(context)"));
    },
  );
}
