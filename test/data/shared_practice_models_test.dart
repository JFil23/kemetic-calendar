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
          'visibility': 'public',
          'join_policy': 'owner_approval',
          'member_count': 2,
          'pending_request_count': 1,
          'viewer_can_manage': true,
        },
        'calendar': {'id': 'cal-1', 'name': 'Family', 'color': 0xD4AE43},
        'source_flow': {
          'id': 42,
          'user_id': 'user-1',
          'calendar_id': 'cal-1',
          'name': 'The Reading House',
          'notes': 'maat=the-reading-house',
        },
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
        'join_requests': [
          {
            'id': 'request-1',
            'room_id': 'room-1',
            'requester_id': 'user-3',
            'requester_display_name': 'Aset',
            'message': 'I can keep this with care.',
            'status': 'pending',
          },
        ],
        'viewer_can_manage': true,
        'viewer_can_edit': true,
        'viewer_is_member': true,
      });

      expect(snapshot.room.id, 'room-1');
      expect(snapshot.room.visibility, SharedPracticeRoomVisibility.public);
      expect(snapshot.room.joinPolicy, SharedPracticeJoinPolicy.ownerApproval);
      expect(snapshot.room.pendingJoinRequestCount, 1);
      expect(snapshot.viewerCanManage, isTrue);
      expect(snapshot.viewerCanEdit, isTrue);
      expect(snapshot.sourceFlow?['id'], 42);
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
      expect(snapshot.joinRequests.single.requesterLabel, 'Aset');
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

    test('parses persisted group messages and published quote activity', () {
      final snapshot = SharedPracticeRoomSnapshot.fromJson({
        'room': {
          'id': 'room-1',
          'created_by': 'host-1',
          'title': 'Morning Practice',
          'visibility': 'public',
          'request_audience': 'anyone',
        },
        'calendar': {'id': '', 'name': 'Morning Practice'},
        'local_date': '2026-09-26',
        'messages': [
          {
            'id': 'message-1',
            'room_id': 'room-1',
            'user_id': 'member-1',
            'flow_day': '2026-09-26',
            'body_text': 'Breathe before beginning.',
            'host_client_event_id': 'event-3',
            'flow_id': 42,
            'author_display_name': 'Amina',
          },
        ],
      });
      final quote = SharedPracticeQuotePost.fromJson({
        'id': 'quote-1',
        'room_id': 'room-1',
        'source_message_id': 'message-1',
        'quoted_user_id': 'member-1',
        'submitted_by': 'member-1',
        'body_text': 'Breathe before beginning.',
        'status': 'published',
        'author_is_public': true,
        'author_display_name': 'Amina',
        'likes_count': 3,
        'liked_by_me': true,
        'comments': [
          {
            'id': 'comment-1',
            'quote_post_id': 'quote-1',
            'user_id': 'reader-1',
            'body_text': 'Keeping this.',
            'author_handle': 'reader',
          },
        ],
      });

      expect(snapshot.messages.single.bodyText, 'Breathe before beginning.');
      expect(snapshot.messages.single.authorLabel, 'Amina');
      expect(snapshot.messages.single.flowId, 42);
      expect(quote.authorLabel, 'Amina');
      expect(quote.likesCount, 3);
      expect(quote.likedByMe, isTrue);
      expect(quote.comments.single.authorLabel, '@reader');
    });
  });

  group('TogetherInboxSnapshot', () {
    test('parses active rooms, quote approvals, and requester decisions', () {
      final snapshot = TogetherInboxSnapshot.fromJson({
        'active_rooms': [
          {
            'room_id': 'room-active',
            'title': 'Morning Practice',
            'member_count': 3,
            'visibility': 'private',
            'request_audience': 'nobody',
            'created_by': 'host-1',
            'host_display_name': 'Sekhet',
          },
        ],
        'quote_approvals': [
          {
            'id': 'quote-1',
            'room_id': 'room-1',
            'source_message_id': 'message-1',
            'submitted_by': 'member-2',
            'body_text': 'A selected line.',
            'flow_title': 'Morning Practice',
            'submitter_display_name': 'Amina',
          },
        ],
        'request_decisions': [
          {
            'id': 'request-1',
            'room_id': 'room-1',
            'status': 'approved',
            'title': 'Morning Practice',
            'host_id': 'host-1',
            'source_flow_id': 42,
            'host_handle': 'host',
          },
        ],
      });

      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.activeRooms.single.memberCount, 3);
      expect(snapshot.activeRooms.single.hostLabel, 'Sekhet');
      expect(snapshot.quoteApprovals.single.submitterLabel, 'Amina');
      expect(snapshot.requestDecisions.single.approved, isTrue);
      expect(snapshot.requestDecisions.single.hostLabel, '@host');
      expect(snapshot.requestDecisions.single.sourceFlowId, 42);
    });
  });
}
