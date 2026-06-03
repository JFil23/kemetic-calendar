import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared calendar item-added fanout is server backed', () async {
    final repoSource = await File(
      'lib/data/shared_calendars_repo.dart',
    ).readAsString();
    final edgeSource = await File(
      '../supabase/functions/notify_shared_calendar_item_added/index.ts',
    ).readAsString();
    final migrationSource = await File(
      '../supabase/migrations/20260602110000_shared_calendar_item_added_fanout.sql',
    ).readAsString();

    expect(repoSource, contains('notifySharedCalendarItemAdded'));
    expect(repoSource, contains("'notify_shared_calendar_item_added'"));
    expect(
      edgeSource,
      contains('notification_type: "shared_calendar_item_added"'),
    );
    expect(edgeSource, contains('notification_kind: "calendar_event"'));
    expect(edgeSource, contains('shared_calendar_item_added_fanout'));
    expect(edgeSource, contains('getRecipientUserIds'));
    expect(edgeSource, contains('userId !== actorUserId'));
    expect(migrationSource, contains('dedupe_key text primary key'));
    expect(
      migrationSource,
      contains("shared_calendar_item_added:{calendarId}:{itemType}:{itemId}"),
    );
  });

  test('calendar add paths use shared calendar item-added fanout', () async {
    final calendarSource = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final flowPagesSource = await File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsString();

    final singleSave = _sourceBetween(
      calendarSource,
      'Future<({String clientEventId, String eventId})> _saveSingleNoteOnly',
      'Future<({String clientEventId, String eventId})> _updateSingleNoteOnly',
    );
    expect(singleSave, contains('_notifySharedCalendarItemAdded'));
    expect(singleSave, contains("itemType: 'event'"));
    expect(singleSave, contains('eventId: updated.id'));

    final flowStudioPersist = _sourceBetween(
      calendarSource,
      'Future<int?> _persistFlowStudioResult(_FlowStudioResult r) async',
      'Future<({String clientEventId, String eventId})> _saveSingleNoteOnly',
    );
    expect(flowStudioPersist, contains('isNewFlowSave'));
    expect(flowStudioPersist, contains('notifyFlowAdditionIfNeeded'));
    expect(flowStudioPersist, contains("itemType: 'flow'"));
    expect(flowStudioPersist, contains('flowId: saved.id'));

    final reminderSave = _sourceBetween(
      calendarSource,
      'Future<void> _upsertReminderRule(ReminderRule rule) async',
      'Future<void> _deleteReminderRule(String id) async',
    );
    expect(reminderSave, contains('isNewReminderFlow'));
    expect(reminderSave, contains("itemType: 'reminder'"));
    expect(reminderSave, contains('flowId: saved.id'));

    final repeatingNoteSave = _sourceBetween(
      calendarSource,
      'Future<void> _saveRepeatingNoteAsHiddenFlow',
      'Future<DateTime?> pickDateUniversal',
    );
    expect(repeatingNoteSave, contains("itemType: 'note'"));
    expect(repeatingNoteSave, contains('noteId: firstEventId'));

    expect(flowPagesSource, contains('_notifySharedCalendarItemAdded'));
    expect(flowPagesSource, contains("itemType: 'flow'"));

    final standaloneMove = _sourceBetween(
      calendarSource,
      'Future<DayViewSheetEventTarget?> _moveStandaloneEventToCalendar',
      'Future<DayViewSheetEventTarget?> _moveFlowEventToCalendar',
    );
    expect(standaloneMove, contains('_notifySharedCalendarItemAdded'));
    expect(standaloneMove, contains("itemType: 'event'"));

    final flowMove = _sourceBetween(
      calendarSource,
      'Future<DayViewSheetEventTarget?> _moveFlowEventToCalendar',
      'Future<DayViewSheetEventTarget?> _moveReminderEventToCalendar',
    );
    expect(flowMove, contains('_notifySharedCalendarItemAdded'));
    expect(flowMove, contains("itemType: 'flow'"));

    final reminderMove = _sourceBetween(
      calendarSource,
      'Future<DayViewSheetEventTarget?> _moveReminderEventToCalendar',
      'Future<DayViewSheetEventTarget?> _reassignDetailTargetCalendar',
    );
    expect(reminderMove, contains('_notifySharedCalendarItemAdded'));
    expect(reminderMove, contains("itemType: 'reminder'"));
  });

  test(
    'shared calendar item-added pushes route to focused inbox calendar context',
    () async {
      final mainSource = await File('lib/main.dart').readAsString();
      final sendPushSource = await File(
        '../supabase/functions/send_push/index.ts',
      ).readAsString();

      expect(sendPushSource, contains('kind === "shared_calendar_item_added"'));
      expect(
        sendPushSource,
        contains('push_kind: "shared_calendar_item_added"'),
      );
      expect(sendPushSource, contains('const passthroughValue'));
      expect(mainSource, contains("kind == 'shared_calendar_item_added'"));
      expect(mainSource, contains("'item_id': params['item_id']"));
      expect(mainSource, contains("'note_id': params['note_id']"));
      expect(mainSource, contains("'task_id': params['task_id']"));
      expect(
        mainSource,
        contains('sharedCalendarInboxRouteLocationFromPushData(data)'),
      );
      expect(mainSource, contains('initialSharedCalendarId'));
    },
  );
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start marker: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end marker: $endNeedle');
  return source.substring(start, end);
}
