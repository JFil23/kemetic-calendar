import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_share_snapshot.dart';
import 'package:mobile/data/share_models.dart';

void main() {
  group('FlowSharePayload.fromJson', () {
    test('parses typed flow snapshots with event metadata', () {
      final payload = FlowSharePayload.fromJson({
        'name': 'Morning Flow',
        'color': 0xFF123456,
        'notes': 'Start with water',
        'rules': [
          {'kind': 'weekly', 'weekdays': [1, 3, 5]},
        ],
        'events': [
          {
            'offset_days': 0,
            'title': 'Wake',
            'detail': 'Drink water',
            'location': 'Home',
            'all_day': false,
            'start_time': '06:00',
            'end_time': '06:15',
          },
          {
            'title': 'Reflect',
            'all_day': true,
          },
        ],
      });

      expect(payload.name, 'Morning Flow');
      expect(payload.color, 0xFF123456);
      expect(payload.notes, 'Start with water');
      expect(payload.rules, hasLength(1));
      expect(payload.events, hasLength(2));

      expect(payload.events.first.offsetDays, 0);
      expect(payload.events.first.title, 'Wake');
      expect(payload.events.first.detail, 'Drink water');
      expect(payload.events.first.location, 'Home');
      expect(payload.events.first.allDay, isFalse);
      expect(payload.events.first.startTime, '06:00');
      expect(payload.events.first.endTime, '06:15');

      expect(payload.events.last.offsetDays, 0);
      expect(payload.events.last.title, 'Reflect');
      expect(payload.events.last.allDay, isTrue);
    });
  });

  group('InboxShareItem.flowPayload', () {
    test('returns typed payloads for valid flow snapshots', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-flow-1',
        'kind': 'flow',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-1',
        'sender_handle': 'priestess',
        'sender_name': 'Priestess',
        'payload_id': 'payload-1',
        'title': 'Morning Flow',
        'created_at': '2026-04-15T00:00:00Z',
        'payload_json': {
          'name': 'Morning Flow',
          'rules': [
            {'kind': 'weekly', 'weekdays': [1, 3]},
          ],
          'events': [
            {
              'offset_days': 1,
              'title': 'Prepare altar',
              'all_day': false,
              'start_time': '08:00',
            },
          ],
        },
      });

      final payload = item.flowPayload;

      expect(payload, isNotNull);
      expect(payload!.name, 'Morning Flow');
      expect(payload.rules, hasLength(1));
      expect(payload.events, hasLength(1));
      expect(payload.events.single.offsetDays, 1);
      expect(payload.events.single.title, 'Prepare altar');
      expect(payload.events.single.startTime, '08:00');
    });

    test('returns null for malformed flow payloads so callers can fallback', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-flow-2',
        'kind': 'flow',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-1',
        'sender_handle': 'priestess',
        'sender_name': 'Priestess',
        'payload_id': 'payload-2',
        'title': 'Fallback Flow',
        'created_at': '2026-04-15T00:00:00Z',
        'payload_json': {
          'name': 'Fallback Flow',
          'events': ['not-a-map'],
        },
      });

      expect(item.flowPayload, isNull);
      expect(item.isFlow, isTrue);
      expect(item.subtitle, 'Flow shared by @priestess');
    });
  });
}
