import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inbox/dm_conversation_models.dart';

void main() {
  group('DmConversationSummary', () {
    test('builds group titles and sender-prefixed previews', () {
      final summary = DmConversationSummary.fromJson({
        'conversation_id': 'conversation-1',
        'type': 'group',
        'created_by': 'me',
        'created_at': '2026-06-29T12:00:00Z',
        'updated_at': '2026-06-29T12:05:00Z',
        'unread_count': 2,
        'members': [
          {'user_id': 'me', 'display_name': 'Me', 'role': 'owner'},
          {'user_id': 'user-a', 'display_name': 'A', 'role': 'member'},
          {'user_id': 'user-b', 'display_name': 'B', 'role': 'member'},
          {'user_id': 'user-c', 'display_name': 'C', 'role': 'member'},
          {'user_id': 'user-d', 'display_name': 'D', 'role': 'member'},
        ],
        'last_sender_id': 'user-b',
        'last_sender_display_name': 'B',
        'last_body': 'Hello group',
        'last_created_at': '2026-06-29T12:05:00Z',
      });

      expect(summary.titleFor('me'), 'A, B, C +1');
      expect(summary.previewFor('me'), 'B: Hello group');
      expect(summary.hasUnread, isTrue);
    });

    test('keeps direct previews unprefixed for current-user messages', () {
      final summary = DmConversationSummary.fromJson({
        'conversation_id': 'conversation-2',
        'type': 'direct',
        'created_by': 'me',
        'created_at': '2026-06-29T12:00:00Z',
        'updated_at': '2026-06-29T12:05:00Z',
        'unread_count': 0,
        'members': [
          {'user_id': 'me', 'display_name': 'Me', 'role': 'owner'},
          {'user_id': 'friend', 'handle': 'friend', 'role': 'member'},
        ],
        'last_sender_id': 'me',
        'last_body': 'See you there',
        'last_created_at': '2026-06-29T12:05:00Z',
      });

      expect(summary.titleFor('me'), '@friend');
      expect(summary.previewFor('me'), 'See you there');
      expect(summary.hasUnread, isFalse);
    });
  });
}
