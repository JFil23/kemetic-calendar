import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flow Studio close handler cannot delete persisted AI flows', () {
    final source = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();
    final closeStart = source.indexOf('Future<void> _handleClose() async');
    final closeEnd = source.indexOf('// ---------- build ----------');

    expect(closeStart, isNonNegative);
    expect(closeEnd, greaterThan(closeStart));

    final closeHandler = source.substring(closeStart, closeEnd);
    expect(closeHandler, isNot(contains('deleteByFlowId')));
    expect(closeHandler, isNot(contains('FlowsRepo')));
    expect(closeHandler, isNot(contains('Delete AI Flow?')));
  });

  test('replacement deletes do not create client-suppressing tombstones', () {
    final calendarSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final inboxSource = File(
      'lib/repositories/inbox_repo.dart',
    ).readAsStringSync();
    final shareSource = File('lib/data/share_repo.dart').readAsStringSync();

    expect(
      _deleteCallFor(
        calendarSource,
        "sourceFeature: 'CalendarPage._persistFlowStudioResult'",
      ),
      contains('suppressesClient: false'),
    );
    expect(
      _deleteCallFor(
        calendarSource,
        "sourceFeature: 'CalendarPage.scheduleFlowNotes'",
      ),
      contains('suppressesClient: false'),
    );
    expect(
      _deleteCallFor(
        inboxSource,
        "sourceFeature: 'InboxRepo._scheduleImportedFlow'",
      ),
      contains('suppressesClient: false'),
    );
    expect(
      _deleteCallFor(
        shareSource,
        "sourceFeature: 'ShareRepo._importSharedFlow'",
      ),
      contains('suppressesClient: false'),
    );
  });
}

String _deleteCallFor(String source, String sourceFeatureNeedle) {
  final featureIndex = source.indexOf(sourceFeatureNeedle);
  expect(featureIndex, isNonNegative);

  final callStart = source.lastIndexOf('deleteByFlowId(', featureIndex);
  expect(callStart, isNonNegative);

  final callEnd = source.indexOf(');', featureIndex);
  expect(callEnd, isNonNegative);

  return source.substring(callStart, callEnd);
}
