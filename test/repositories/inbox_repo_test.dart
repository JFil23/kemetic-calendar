import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/repositories/inbox_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  group('DM hardening helpers', () {
    test('detects missing send_dm_message function errors', () {
      expect(
        isMissingDmFunctionError(
          const FunctionException(status: 404, details: 'send_dm_message'),
        ),
        isTrue,
      );
      expect(isMissingDmFunctionError(Exception('boom')), isFalse);
    });

    test('retries push client-side when backend reports missing push auth', () {
      expect(
        shouldRetryDmPushFromResponse({
          'share': {'id': 'share-1'},
          'push': {
            'delivered': false,
            'reason': 'missing_internal_function_key',
          },
        }),
        isTrue,
      );

      expect(
        shouldRetryDmPushFromResponse({
          'push': {'delivered': true},
        }),
        isFalse,
      );
    });

    test('maps DM send errors to user-facing copy', () {
      expect(
        userFacingDmSendError(
          Exception('Recipient is not accepting messages right now'),
        ),
        'That user is not accepting messages right now.',
      );
      expect(
        userFacingDmSendError(
          const FunctionException(status: 404, details: 'send_dm_message'),
        ),
        'Messaging is updating right now. Please try again in a moment.',
      );
    });
  });
}
