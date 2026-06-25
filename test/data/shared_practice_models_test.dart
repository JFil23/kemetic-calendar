import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/data/shared_practice_models.dart';

void main() {
  group('SharedPracticeRoomSnapshot', () {
    test('parses snapshot and separated member statuses', () {
      final snapshot = SharedPracticeRoomSnapshot.fromJson({
        'room': {
          'id': 'room-1',
          'calendar_id': 'cal-1',
          'source_flow_id': 42,
          'shared_flow_id': 84,
          'created_by': 'user-1',
          'title': 'The Closing',
          'status': 'active',
        },
        'calendar': {'id': 'cal-1', 'name': 'Family', 'color': 0xD4AE43},
        'local_date': '2026-06-24',
        'today_step': {
          'id': 'event-1',
          'client_event_id': 'shared:1',
          'flow_id': 84,
          'title': 'Close the day',
          'step_index': 2,
          'total_steps': 10,
        },
        'members': [
          {
            'user_id': 'user-1',
            'display_name': 'Jarale',
            'completion_status': 'observed',
            'presence_status': null,
            'completed_count': 2,
            'total_count': 10,
            'entry_visibility': 'private',
            'entry_has_body': true,
            'entry_available_to_viewer': true,
          },
          {
            'user_id': 'user-2',
            'display_name': 'Monroe',
            'completion_status': null,
            'presence_status': 'carrying',
            'completed_count': 1,
            'total_count': 10,
          },
        ],
        'entries': [
          {
            'id': 'entry-1',
            'room_id': 'room-1',
            'user_id': 'user-1',
            'completed_on': '2026-06-24',
            'completion_status': 'observed',
            'body_text': 'Done quietly.',
            'visibility': 'private',
            'moderation_status': 'visible',
          },
        ],
      });

      expect(snapshot.room.id, 'room-1');
      expect(snapshot.todayStep?.flowId, 84);
      expect(
        snapshot.members.first.completionStatus,
        CompletionStatus.observed,
      );
      expect(
        snapshot.members.last.presenceStatus,
        SharedPracticePresenceStatus.carrying,
      );
      expect(
        snapshot.entries.single.visibility,
        SharedPracticeVisibility.private,
      );
    });

    test('builds factual summary without interpretive language', () {
      expect(
        buildSharedPracticeSummary(
          observed: 0,
          partial: 0,
          skipped: 0,
          carrying: 0,
          notYet: 4,
        ),
        'Nobody has recorded today\'s step yet.',
      );
      expect(
        buildSharedPracticeSummary(
          observed: 2,
          partial: 1,
          skipped: 0,
          carrying: 1,
          notYet: 1,
        ),
        '2 observed today. 1 partly completed. 1 is carrying the step.',
      );
    });

    test('member entry labels preserve private bodies', () {
      final privateOtherMember = SharedPracticeMemberStatus.fromJson({
        'user_id': 'user-2',
        'completion_status': 'observed',
        'entry_visibility': 'private',
        'entry_has_body': true,
        'entry_available_to_viewer': false,
      });
      final statusOnlyShared = SharedPracticeMemberStatus.fromJson({
        'user_id': 'user-3',
        'completion_status': 'observed',
        'entry_visibility': 'shared_with_calendar',
        'entry_has_body': false,
        'entry_available_to_viewer': false,
      });

      expect(privateOtherMember.entryActionLabel, 'Entry private');
      expect(statusOnlyShared.entryActionLabel, 'No note shared');
    });
  });
}
