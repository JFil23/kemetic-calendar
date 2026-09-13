import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';

void main() {
  test('owned Djed sitting identity matches flow id and v2 event number', () {
    final event = djedV2EventByNumber(3)!;
    expect(
      calendarEventMatchesOwnedDjedSitting(
        flowId: 42,
        sittingNumber: 3,
        eventFlowId: 42,
        actionId: djedV2ActionId(event),
        behaviorPayload: <String, dynamic>{
          'djed_schema_version': kDjedV2SchemaVersion,
          'semantic_step_id': event.semanticStepId,
          'event_number': 3,
        },
      ),
      isTrue,
    );
    expect(
      calendarEventMatchesOwnedDjedSitting(
        flowId: 99,
        sittingNumber: 3,
        eventFlowId: 42,
        actionId: djedV2ActionId(event),
        behaviorPayload: <String, dynamic>{
          'djed_schema_version': kDjedV2SchemaVersion,
          'event_number': 3,
        },
      ),
      isFalse,
    );
    expect(
      calendarEventMatchesOwnedDjedSitting(
        flowId: 42,
        sittingNumber: 2,
        eventFlowId: 42,
        title: 'Djed 3: Read the result',
        actionId: djedV2ActionId(event),
        behaviorPayload: <String, dynamic>{
          'djed_schema_version': kDjedV2SchemaVersion,
          'semantic_step_id': event.semanticStepId,
          'event_number': 3,
        },
      ),
      isFalse,
    );
  });
}
