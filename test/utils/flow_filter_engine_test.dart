import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/flow_filter_engine.dart';

void main() {
  group('flow record classification', () {
    test('marks soft-deleted rows explicitly', () {
      expect(
        classifyFlowRecord(active: false, isHidden: true, isReminder: false),
        FlowRecordKind.softDeleted,
      );
    });

    test('marks repeating-note helper rows explicitly', () {
      expect(
        classifyFlowRecord(
          active: true,
          isHidden: false,
          isReminder: false,
          notes: '{"kind":"repeating_note","detail":"Bring journal"}',
        ),
        FlowRecordKind.hiddenHelper,
      );
    });

    test('treats hidden non-helper rows as deleted, not helper flows', () {
      expect(
        classifyFlowRecord(
          active: true,
          isHidden: true,
          isReminder: false,
          notes: 'legacy placeholder',
        ),
        FlowRecordKind.softDeleted,
      );
    });
  });

  group('flow link parsing', () {
    test(
      'extracts flow id from canonical client event id with calendar scope',
      () {
        final flowId = extractFlowIdFromClientEventId(
          'ky=1-km=2-kd=3|s=540|t=Morning%20ritual|f=42|cal=abcd1234',
        );

        expect(flowId, 42);
      },
    );

    test('extracts flow id from prefixed detail metadata chain', () {
      final flowId = extractFlowIdFromDetailMetadata(
        'color=ffcc00;alert=-15;flowLocalId=12;Bring water',
      );

      expect(flowId, 12);
    });

    test('matches flow references from detail metadata lines', () {
      expect(
        eventReferencesFlow(
          flowId: 55,
          flowLocalId: null,
          clientEventId: null,
          detail: 'Bring journal\nflowLocalId=55',
        ),
        isTrue,
      );
    });
  });

  group('flow event classification', () {
    test('treats orphaned embedded flow notes as orphaned flow events', () {
      final decision = classifyFlowEvent(
        event: const FlowEventSnapshot(
          flowLocalId: null,
          clientEventId:
              'ky=1-km=2-kd=3|s=540|t=Morning%20ritual|f=42|cal=abcd1234',
          detail: 'Bring water',
        ),
      );

      expect(decision.kind, FlowEventKind.orphanedFlow);
      expect(decision.shouldPurgeGhostRow, isTrue);
    });

    test('keeps active flow ghosts hidden but not purgeable', () {
      final decision = classifyFlowEvent(
        event: const FlowEventSnapshot(
          flowLocalId: null,
          clientEventId: 'ky=1-km=2-kd=3|s=540|t=Ritual|f=7',
          detail: 'Bring water',
        ),
        flowOwnersById: const {
          7: FlowRecordSnapshot(
            id: 7,
            active: true,
            isHidden: false,
            isReminder: false,
          ),
        },
      );

      expect(decision.kind, FlowEventKind.activeFlow);
      expect(decision.isStandaloneVisible, isFalse);
      expect(decision.shouldPurgeGhostRow, isFalse);
    });

    test('marks deleted flow notes as purgeable ghosts', () {
      final decision = classifyFlowEvent(
        event: const FlowEventSnapshot(
          flowLocalId: null,
          clientEventId: 'ky=1-km=2-kd=3|s=540|t=Ritual|f=9',
          detail: 'Bring water',
        ),
        flowOwnersById: const {
          9: FlowRecordSnapshot(
            id: 9,
            active: false,
            isHidden: true,
            isReminder: false,
          ),
        },
      );

      expect(decision.kind, FlowEventKind.deletedFlow);
      expect(decision.shouldPurgeGhostRow, isTrue);
    });
  });
}
