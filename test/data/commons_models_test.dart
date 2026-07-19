import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/shared_practice_models.dart';

void main() {
  group('CommonsHomeSnapshot', () {
    test('keeps empty Commons state factual', () {
      final empty = CommonsHomeSnapshot.empty();

      expect(empty.rhythm.activeUsersTodayLabel, '0');
      expect(empty.rhythm.flowsKeptTodayLabel, '0');
      expect(empty.questions, isEmpty);
      expect(empty.mySharedPractices, isEmpty);
      expect(empty.publicSharedPractices, isEmpty);
      expect(empty.fragments, isEmpty);
      expect(empty.discover, isEmpty);
    });

    test('parses public rhythm and unanswered question state', () {
      final snapshot = CommonsHomeSnapshot.fromJson({
        'rhythm': {
          'active_users_today': 4,
          'active_users_today_label': '4',
          'flows_kept_today': 6,
          'flows_kept_today_label': '6',
          'public_fragments_today': 2,
          'public_fragments_today_label': 'a few',
          'public_rooms_open': 3,
          'public_rooms_open_label': '3',
          'top_flow': {'title': 'Public Smoke Flow', 'count_label': 'a few'},
        },
        'questions': [
          {
            'id': 'daily-reflection:2026-06-26',
            'question': 'What did practice make visible?',
            'answers': [],
            'my_answer': null,
          },
        ],
      });

      expect(snapshot.rhythm.activeUsersTodayLabel, '4');
      expect(snapshot.rhythm.flowsKeptTodayLabel, '6');
      expect(snapshot.rhythm.publicFragmentsTodayLabel, 'a few');
      expect(snapshot.rhythm.publicRoomsOpenLabel, '3');
      expect(snapshot.rhythm.topFlowTitle, 'Public Smoke Flow');
      expect(snapshot.questions.single.myAnswer, isNull);
      expect(snapshot.questions.single.answers, isEmpty);
    });

    test('parses saved answer and practice room states', () {
      final snapshot = CommonsHomeSnapshot.fromJson({
        'rhythm': {'active_users_today': 1, 'flows_kept_today': 1},
        'questions': [
          {
            'id': 'daily-reflection:2026-06-26',
            'question': 'What did practice make visible?',
            'answers': [
              {
                'id': 'answer-1',
                'question_id': 'daily-reflection:2026-06-26',
                'user_id': 'user-1',
                'body_text': 'It made one next action visible.',
                'author_handle': 'jarale',
                'is_mine': true,
              },
              {
                'id': 'answer-2',
                'question_id': 'daily-reflection:2026-06-26',
                'user_id': 'user-2',
                'body_text': 'Another public answer.',
                'author_display_name': 'Aset',
              },
            ],
            'my_answer': {
              'id': 'answer-1',
              'question_id': 'daily-reflection:2026-06-26',
              'user_id': 'user-1',
              'body_text': 'It made one next action visible.',
              'author_handle': 'jarale',
              'is_mine': true,
            },
          },
        ],
        'my_shared_practices': [
          {
            'id': 'room-mine',
            'calendar_id': 'calendar-1',
            'source_flow_id': 42,
            'created_by': 'user-1',
            'title': 'My private flow',
            'status': 'active',
            'visibility': 'private',
            'join_policy': 'closed',
            'member_count': 1,
            'pending_request_count': 2,
            'viewer_is_member': true,
            'viewer_can_manage': true,
          },
        ],
        'public_shared_practices': [
          {
            'id': 'room-public',
            'calendar_id': 'calendar-2',
            'source_flow_id': 84,
            'created_by': 'user-2',
            'title': 'Open to request',
            'status': 'active',
            'visibility': 'public',
            'join_policy': 'owner_approval',
            'member_count': 3,
            'viewer_is_member': false,
            'viewer_can_manage': false,
          },
          {
            'id': 'room-pending',
            'calendar_id': 'calendar-3',
            'source_flow_id': 96,
            'created_by': 'user-3',
            'title': 'Already requested',
            'status': 'active',
            'visibility': 'public',
            'join_policy': 'owner_approval',
            'viewer_request_status': 'pending',
            'viewer_is_member': false,
            'viewer_can_manage': false,
          },
        ],
      });

      final question = snapshot.questions.single;
      expect(question.myAnswer?.bodyText, 'It made one next action visible.');
      expect(question.myAnswer?.isMine, isTrue);
      expect(question.answers.last.authorLabel, 'Aset');

      final ownRoom = snapshot.mySharedPractices.single;
      expect(ownRoom.visibility, SharedPracticeRoomVisibility.private);
      expect(ownRoom.joinPolicy, SharedPracticeJoinPolicy.closed);
      expect(ownRoom.viewerCanManage, isTrue);
      expect(ownRoom.pendingJoinRequestCount, 2);

      final publicRoom = snapshot.publicSharedPractices.first;
      expect(publicRoom.visibility, SharedPracticeRoomVisibility.public);
      expect(publicRoom.joinPolicy, SharedPracticeJoinPolicy.ownerApproval);
      expect(publicRoom.requestLabel, 'Ask to join');

      final pendingRoom = snapshot.publicSharedPractices.last;
      expect(pendingRoom.requestLabel, 'Requested');
    });
  });
}
