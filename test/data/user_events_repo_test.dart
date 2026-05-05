import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/user_events_repo.dart';

void main() {
  group('filing-backed user event row helpers', () {
    test('uses filed_flow_id as the canonical flow owner', () {
      final row = <String, dynamic>{
        'flow_local_id': 12,
        'filed_flow_id': 34,
        'item_kind': 'flow',
      };

      expect(canonicalFiledFlowIdForEventRow(row), 34);
      expect(filingRowIsFlowCalendarEvent(row), isTrue);
      expect(filingRowIsStandaloneCalendarEvent(row), isFalse);
    });

    test('recognizes filed flow rows when raw flow_local_id is missing', () {
      final row = <String, dynamic>{
        'flow_local_id': null,
        'filed_flow_id': 99,
        'item_kind': 'flow',
      };

      expect(canonicalFiledFlowIdForEventRow(row), 99);
      expect(filingRowIsFlowCalendarEvent(row), isTrue);
    });

    test('keeps reminder rows in standalone calendar hydration', () {
      final row = <String, dynamic>{
        'flow_local_id': 7,
        'filed_flow_id': 7,
        'item_kind': 'reminder',
      };

      expect(canonicalFiledFlowIdForEventRow(row), 7);
      expect(filingRowIsStandaloneCalendarEvent(row), isTrue);
      expect(filingRowIsFlowCalendarEvent(row), isFalse);
    });

    test('keeps normal note rows standalone', () {
      final row = <String, dynamic>{
        'flow_local_id': null,
        'filed_flow_id': null,
        'item_kind': 'note',
      };

      expect(canonicalFiledFlowIdForEventRow(row), isNull);
      expect(filingRowIsStandaloneCalendarEvent(row), isTrue);
      expect(filingRowIsFlowCalendarEvent(row), isFalse);
    });
  });
}
