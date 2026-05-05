import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flows_repo.dart';

void main() {
  group('FlowRow.fromRow', () {
    test('parses filing view fields for My Flows hydration', () {
      final row = FlowRow.fromRow({
        'id': 42,
        'user_id': 'user-1',
        'calendar_id': 'calendar-1',
        'name': 'Follow the sky',
        'color': 0x12F0A1,
        'active': true,
        'is_saved': true,
        'start_date': '2026-05-01T00:00:00Z',
        'end_date': '2027-03-20T00:00:00Z',
        'notes': 'source=filing',
        'rules': [
          {
            'type': 'gregorian',
            'months': [5],
            'days': [1],
            'allDay': true,
          },
        ],
        'is_hidden': false,
        'is_reminder': false,
        'reminder_uuid': null,
        'share_id': '2bfaf9f3-c605-4a3e-8d47-fb6ce7b1703f',
        'saved_at': '2026-05-04T12:00:00Z',
        'lifecycle': 'active',
        'visible_in_active_list': true,
        'visible_in_saved_list': true,
        'total_event_count': 12,
        'remaining_event_count': 8,
        'remaining_live_event_count': 7,
        'ai_metadata': {'source': 'test'},
      });

      expect(row.id, 42);
      expect(row.shareId, '2bfaf9f3-c605-4a3e-8d47-fb6ce7b1703f');
      expect(row.filingLifecycle, 'active');
      expect(row.visibleInActiveList, isTrue);
      expect(row.visibleInSavedList, isTrue);
      expect(row.totalEventCount, 12);
      expect(row.remainingEventCount, 8);
      expect(row.remainingLiveEventCount, 7);
      expect(row.rules, hasLength(1));
      expect(row.aiMetadata, {'source': 'test'});
    });

    test(
      'uses lifecycle fallback for older rows without filing visibility',
      () {
        final row = FlowRow.fromRow({
          'id': 9,
          'user_id': 'user-1',
          'name': 'Legacy flow',
          'color': null,
          'active': true,
          'is_saved': false,
          'start_date': null,
          'end_date': null,
          'notes': null,
          'rules': null,
          'lifecycle': 'active',
        });

        expect(row.visibleInActiveList, isTrue);
        expect(row.visibleInSavedList, isFalse);
        expect(row.totalEventCount, 0);
        expect(row.remainingLiveEventCount, 0);
      },
    );
  });

  group('FlowFilingCounts', () {
    test('counts visible active flows and their live remaining events', () {
      FlowRow row({
        required int id,
        required bool active,
        required int remaining,
      }) {
        return FlowRow.fromRow({
          'id': id,
          'user_id': 'user-1',
          'name': 'Flow $id',
          'active': true,
          'is_saved': false,
          'start_date': null,
          'end_date': null,
          'notes': null,
          'rules': const [],
          'visible_in_active_list': active,
          'remaining_live_event_count': remaining,
        });
      }

      final counts = FlowFilingCounts.fromRows([
        row(id: 1, active: true, remaining: 7),
        row(id: 2, active: false, remaining: 20),
        row(id: 3, active: true, remaining: 4),
      ]);

      expect(counts.activeFlows, 2);
      expect(counts.flowEvents, 11);
    });
  });
}
