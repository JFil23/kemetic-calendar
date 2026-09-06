import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';

const DjedV2Configuration _configuration = DjedV2Configuration(
  supports: <DjedV2SupportDefinition>[
    DjedV2SupportDefinition(
      slot: 1,
      name: 'daily energy',
      initialCondition: DjedV2SupportCondition.underPressure,
    ),
    DjedV2SupportDefinition(
      slot: 2,
      name: 'the work',
      initialCondition: DjedV2SupportCondition.holding,
    ),
    DjedV2SupportDefinition(
      slot: 3,
      name: 'home',
      initialCondition: DjedV2SupportCondition.wobbling,
    ),
    DjedV2SupportDefinition(
      slot: 4,
      name: 'close relationships',
      initialCondition: DjedV2SupportCondition.holding,
    ),
  ],
);

void main() {
  test('v2 defines the approved immutable nine-sitting sequence', () {
    expect(kDjedV2Events.map((event) => event.flowDay), <int>[
      1,
      5,
      9,
      11,
      15,
      19,
      21,
      25,
      29,
    ]);
    expect(
      kDjedV2Events.map((event) => event.semanticStepId).toSet(),
      hasLength(9),
    );
    expect(
      kDjedV2Events
          .map(djedV2ActionId)
          .every((actionId) => actionId.startsWith('the-djed-v2-')),
      isTrue,
    );
    expect(
      kDjedV2Events
          .map(djedV2ActionId)
          .any((actionId) => actionId.startsWith('the-djed-event-')),
      isFalse,
    );
  });

  test('configuration round trips through flow metadata', () {
    final notes =
        'maat=$kTheDjedFlowKey;djed_schema_version=2;djed_v2_config=${djedV2ConfigurationNotesToken(_configuration)}';
    final decoded = djedV2ConfigurationFromNotes(notes);

    expect(decoded, isNotNull);
    expect(decoded!.isComplete, isTrue);
    expect(decoded.supports.map((support) => support.name), <String>[
      'daily energy',
      'the work',
      'home',
      'close relationships',
    ]);
  });

  test('hydration dispatches by schema before event number', () {
    final v1Payload = <String, dynamic>{
      'kind': 'maat_djed_event',
      'event_number': 4,
    };
    final v2Payload = <String, dynamic>{
      'kind': kDjedV2BehaviorKind,
      'djed_schema_version': 2,
      'event_number': 4,
      'semantic_step_id': 'support-02-make-move',
    };

    expect(djedV2EventForEvent(behaviorPayload: v1Payload), isNull);
    expect(
      canonicalDjedDetailTextForEvent(
        flowName: kTheDjedTitle,
        behaviorPayload: v2Payload,
      ),
      isNull,
    );
    expect(
      djedV2EventForEvent(behaviorPayload: v2Payload)?.title,
      'Make one move',
    );
    expect(
      djedEventForEvent(behaviorPayload: v1Payload)?.title,
      'The Mock Battle Begins',
    );
  });

  test('incomplete support definitions cannot be materialized', () {
    const incomplete = DjedV2Configuration(
      supports: <DjedV2SupportDefinition>[],
    );
    expect(incomplete.isComplete, isFalse);
  });
}
