import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_repo.dart';

void main() {
  group('isExternalInboxActivityActor', () {
    test('rejects self activity rows', () {
      expect(isExternalInboxActivityActor('user-1', 'user-1'), isFalse);
    });

    test('rejects missing actor ids', () {
      expect(isExternalInboxActivityActor(null, 'user-1'), isFalse);
      expect(isExternalInboxActivityActor('', 'user-1'), isFalse);
    });

    test('accepts activity from other users', () {
      expect(isExternalInboxActivityActor('user-2', 'user-1'), isTrue);
    });
  });

  group('invite import metadata builders', () {
    test('standalone invite imports preserve action metadata', () {
      final spec = buildStandaloneInviteImportSpec(
        shareId: 'share-123',
        payload: {
          'title': 'Budget review',
          'starts_at': '2026-05-03T15:00:00Z',
          'ends_at': '2026-05-03T15:20:00Z',
          'all_day': false,
          'action_id': 'action-budget-review',
          'behavior_payload': {
            'definition_of_done':
                'Review the account balances and tag one unexpected transaction',
          },
        },
      );

      expect(spec, isNotNull);
      expect(spec!['client_event_id'], 'event_share:share-123');
      expect(spec['action_id'], 'action-budget-review');
      expect(spec['behavior_payload'], {
        'definition_of_done':
            'Review the account balances and tag one unexpected transaction',
      });
    });

    test('accepted shared flow imports preserve action metadata', () {
      final spec = buildImportedFlowInviteEventSpec(
        flowId: 42,
        sourceEvent: {
          'source_client_event_id': 'sender-cid-1',
          'title': 'Budget review',
          'starts_at': '2026-05-03T15:00:00Z',
          'ends_at': '2026-05-03T15:20:00Z',
          'all_day': false,
          'action_id': 'action-budget-review',
          'behavior_payload': {
            'minimum_version': 'Open the sheet and verify one balance',
          },
        },
      );

      expect(spec, isNotNull);
      expect(
        spec!['client_event_id'],
        'flow_import:42:${Uri.encodeComponent('sender-cid-1')}',
      );
      expect(spec['action_id'], 'action-budget-review');
      expect(spec['behavior_payload'], {
        'minimum_version': 'Open the sheet and verify one balance',
      });
    });
  });
}
