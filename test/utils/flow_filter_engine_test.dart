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

    test('treats inactive repeating-note rows as inactive, not helpers', () {
      expect(
        classifyFlowRecord(
          active: false,
          isHidden: false,
          isReminder: false,
          notes: '{"kind":"repeating_note","detail":"Bring journal"}',
        ),
        FlowRecordKind.inactive,
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

    test('hydrates only live schedule rows for schedule hydration', () {
      expect(
        shouldHydrateFlowEvents(
          const FlowRecordSnapshot(
            id: 1,
            active: true,
            isHidden: false,
            isReminder: false,
          ),
        ),
        isTrue,
      );
      expect(
        shouldHydrateFlowEvents(
          const FlowRecordSnapshot(
            id: 2,
            active: false,
            isHidden: false,
            isReminder: false,
          ),
        ),
        isFalse,
      );
      expect(
        shouldHydrateFlowEvents(
          const FlowRecordSnapshot(
            id: 3,
            active: false,
            isHidden: true,
            isReminder: false,
          ),
        ),
        isFalse,
      );
      expect(
        shouldHydrateFlowEvents(
          const FlowRecordSnapshot(
            id: 4,
            active: false,
            isHidden: false,
            isReminder: false,
            notes: '{"kind":"repeating_note","detail":"Water plants"}',
          ),
        ),
        isFalse,
      );
      expect(
        shouldHydrateFlowEvents(
          const FlowRecordSnapshot(
            id: 5,
            active: false,
            isHidden: false,
            isReminder: true,
          ),
        ),
        isTrue,
      );
    });

    test('hydrates materialized history for ended non-saved flows only', () {
      expect(
        shouldHydrateMaterializedUserEvents(
          const FlowRecordSnapshot(
            id: 1,
            active: true,
            isHidden: false,
            isReminder: false,
          ),
        ),
        isTrue,
      );
      expect(
        shouldHydrateMaterializedUserEvents(
          const FlowRecordSnapshot(
            id: 2,
            active: false,
            isHidden: false,
            isReminder: false,
          ),
        ),
        isTrue,
      );
      expect(
        shouldHydrateMaterializedUserEvents(
          const FlowRecordSnapshot(
            id: 3,
            active: false,
            isHidden: false,
            isReminder: false,
            isSaved: true,
          ),
        ),
        isFalse,
      );
      expect(
        shouldHydrateMaterializedUserEvents(
          const FlowRecordSnapshot(
            id: 4,
            active: false,
            isHidden: true,
            isReminder: false,
          ),
        ),
        isFalse,
      );
      expect(
        shouldHydrateMaterializedUserEvents(
          const FlowRecordSnapshot(
            id: 5,
            active: true,
            isHidden: false,
            isReminder: false,
            notes: '{"kind":"repeating_note","detail":"Water plants"}',
          ),
        ),
        isTrue,
      );
      expect(
        shouldHydrateMaterializedUserEvents(
          const FlowRecordSnapshot(
            id: 6,
            active: false,
            isHidden: false,
            isReminder: true,
          ),
        ),
        isTrue,
      );
    });

    test('exposes calendar chrome for referenced ended flows', () {
      expect(
        shouldExposeFlowChromeForCalendar(
          const FlowRecordSnapshot(
            id: 7,
            active: false,
            isHidden: false,
            isReminder: false,
          ),
          isReferencedByCalendar: true,
          isActiveLedgerFlow: false,
        ),
        isTrue,
      );
    });

    test(
      'exposes calendar chrome for referenced active flows even when not in active ledger',
      () {
        expect(
          shouldExposeFlowChromeForCalendar(
            const FlowRecordSnapshot(
              id: 8,
              active: true,
              isHidden: false,
              isReminder: false,
            ),
            isReferencedByCalendar: true,
            isActiveLedgerFlow: false,
          ),
          isTrue,
        );
      },
    );

    test('hides calendar chrome for reminders and deleted rows', () {
      expect(
        shouldExposeFlowChromeForCalendar(
          const FlowRecordSnapshot(
            id: 9,
            active: true,
            isHidden: false,
            isReminder: true,
          ),
          isReferencedByCalendar: true,
          isActiveLedgerFlow: false,
        ),
        isFalse,
      );
      expect(
        shouldExposeFlowChromeForCalendar(
          const FlowRecordSnapshot(
            id: 10,
            active: false,
            isHidden: true,
            isReminder: false,
          ),
          isReferencedByCalendar: true,
          isActiveLedgerFlow: false,
        ),
        isFalse,
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

  group('materialized flow event dedupe', () {
    test('keeps distinct all-day flow events when client ids differ', () {
      final first = buildMaterializedFlowEventDedupeKey(
        flowId: 12,
        allDay: true,
        clientEventId: 'flow:12:all-day:a',
        title: 'Morning ritual',
      );
      final second = buildMaterializedFlowEventDedupeKey(
        flowId: 12,
        allDay: true,
        clientEventId: 'flow:12:all-day:b',
        title: 'Morning ritual',
      );

      expect(first, isNot(second));
    });

    test('keeps distinct all-day flow events when titles differ', () {
      final first = buildMaterializedFlowEventDedupeKey(
        flowId: 12,
        allDay: true,
        title: 'Morning ritual',
      );
      final second = buildMaterializedFlowEventDedupeKey(
        flowId: 12,
        allDay: true,
        title: 'Evening offering',
      );

      expect(first, isNot(second));
    });
  });
}
