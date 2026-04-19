import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/repositories/inbox_repo.dart';

void main() {
  group('aggregateDmMessageLikeStates', () {
    test('counts likes per message and marks current user state', () {
      final states = aggregateDmMessageLikeStates(
        ['msg-1', 'msg-2'],
        [
          {'message_share_id': 'msg-1', 'user_id': 'user-a'},
          {'message_share_id': 'msg-1', 'user_id': 'user-b'},
          {'message_share_id': 'msg-2', 'user_id': 'user-a'},
        ],
        'user-a',
      );

      expect(states['msg-1']?.count, 2);
      expect(states['msg-1']?.likedByMe, isTrue);
      expect(states['msg-2']?.count, 1);
      expect(states['msg-2']?.likedByMe, isTrue);
    });

    test('keeps empty messages in the result map', () {
      final states = aggregateDmMessageLikeStates(
        ['msg-1', 'msg-2'],
        const [],
        'user-a',
      );

      expect(states['msg-1']?.count, 0);
      expect(states['msg-1']?.likedByMe, isFalse);
      expect(states['msg-2']?.count, 0);
      expect(states['msg-2']?.likedByMe, isFalse);
    });
  });
}
