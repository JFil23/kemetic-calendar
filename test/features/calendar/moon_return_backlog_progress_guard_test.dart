import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Moon Return headless join cannot write completion or skipped evidence',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final start = source.indexOf(
        'Future<FlowJoinResult> joinMoonReturnHeadless',
      );
      final end = source.indexOf(
        'Future<FlowJoinResult> joinWagHeadless',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final body = source.substring(start, end);
      expect(body, contains('_upsertEventRow('));
      expect(body, contains('_fileHeadlessJoinDelivery('));
      expect(body, contains('_completeHeadlessJoin('));
      expect(body, isNot(contains('recordEventCompletion')));
      expect(body, isNot(contains('user_event_completions')));
      expect(body, isNot(contains('flow_skipped')));
      expect(body, isNot(contains("'status': 'skipped'")));
    },
  );

  test('Moon Return events declare quiet expiry for missed backlog rows', () {
    final source = File(
      'lib/features/calendar/moon_return_flow.dart',
    ).readAsStringSync();

    expect(source, contains("'missed_event_rule': 'expire_quietly'"));
    expect(
      source,
      contains("'completion_options': const <String>['observed', 'skipped']"),
    );
  });
}
