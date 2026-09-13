import 'dart:convert';

import 'the_djed_flow.dart';
import 'track_sky_flow.dart';

const int kDjedV2SchemaVersion = 2;
const String kDjedV2BehaviorKind = 'maat_djed_v2_event';
const String kDjedV2MaterializationVersion = 'nine-sittings-v1';

enum DjedV2SupportCondition { holding, underPressure, wobbling }

extension DjedV2SupportConditionX on DjedV2SupportCondition {
  String get key => switch (this) {
    DjedV2SupportCondition.holding => 'holding',
    DjedV2SupportCondition.underPressure => 'under_pressure',
    DjedV2SupportCondition.wobbling => 'wobbling',
  };

  static DjedV2SupportCondition? fromKey(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'holding' || 'solid' => DjedV2SupportCondition.holding,
        'under_pressure' || 'pressure' => DjedV2SupportCondition.underPressure,
        'wobbling' || 'wobble' => DjedV2SupportCondition.wobbling,
        _ => null,
      };
}

class DjedV2SupportDefinition {
  const DjedV2SupportDefinition({
    required this.slot,
    required this.name,
    required this.initialCondition,
  }) : assert(slot >= 1 && slot <= 4);

  final int slot;
  final String name;
  final DjedV2SupportCondition initialCondition;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'slot': slot,
    'name': name.trim(),
    'initial_condition': initialCondition.key,
  };

  static DjedV2SupportDefinition? fromJson(Map<String, dynamic> json) {
    final rawSlot = json['slot'];
    final slot = rawSlot is num
        ? rawSlot.toInt()
        : int.tryParse(rawSlot?.toString() ?? '');
    final name = json['name']?.toString().trim() ?? '';
    final condition = DjedV2SupportConditionX.fromKey(
      json['initial_condition']?.toString(),
    );
    if (slot == null || slot < 1 || slot > 4 || condition == null) return null;
    return DjedV2SupportDefinition(
      slot: slot,
      name: name,
      initialCondition: condition,
    );
  }
}

enum DjedV2StepKind { orientation, makeMove, readResult }

extension DjedV2StepKindX on DjedV2StepKind {
  String get key => switch (this) {
    DjedV2StepKind.orientation => 'orientation',
    DjedV2StepKind.makeMove => 'make_move',
    DjedV2StepKind.readResult => 'read_result',
  };
}

class DjedV2Event {
  const DjedV2Event({
    required this.eventNumber,
    required this.flowDay,
    required this.semanticStepId,
    required this.stepKind,
    required this.title,
    required this.phase,
    required this.slot,
    required this.durationMinutes,
    required this.context,
    required this.source,
    this.supportSlot,
    this.finalRaising = false,
  });

  final int eventNumber;
  final int flowDay;
  final String semanticStepId;
  final DjedV2StepKind stepKind;
  final String title;
  final String phase;
  final DjedTimingSlot slot;
  final int durationMinutes;
  final String context;
  final String source;
  final int? supportSlot;
  final bool finalRaising;
}

const List<DjedV2Event> kDjedV2Events = <DjedV2Event>[
  DjedV2Event(
    eventNumber: 1,
    flowDay: 1,
    semanticStepId: 'orientation',
    stepKind: DjedV2StepKind.orientation,
    title: 'Set your footing',
    phase: 'ORIENTATION',
    slot: DjedTimingSlot.openMorning,
    durationMinutes: 5,
    context:
        'You do not have to fix everything at once. For each support: make one small move, then return and see what happened.',
    source:
        'The first sitting establishes the method before any single beam becomes the work.',
  ),
  DjedV2Event(
    eventNumber: 2,
    flowDay: 5,
    semanticStepId: 'support-01-make-move',
    stepKind: DjedV2StepKind.makeMove,
    title: 'Make one move',
    phase: 'SUPPORT 01',
    slot: DjedTimingSlot.checkMidday,
    durationMinutes: 5,
    context:
        'You do not have to solve this. Find one useful part that is fully in your hands.',
    source:
        'A small controllable action is the unit of work. The goal is a real attempt, not a perfect solution.',
    supportSlot: 1,
  ),
  DjedV2Event(
    eventNumber: 3,
    flowDay: 9,
    semanticStepId: 'support-01-read-result',
    stepKind: DjedV2StepKind.readResult,
    title: 'Read the result',
    phase: 'SUPPORT 01',
    slot: DjedTimingSlot.openMorning,
    durationMinutes: 5,
    context:
        'Come back to the move you chose. Read what actually happened before deciding anything else.',
    source:
        'The second sitting is verification: use reality as information, not as a verdict.',
    supportSlot: 1,
  ),
  DjedV2Event(
    eventNumber: 4,
    flowDay: 11,
    semanticStepId: 'support-02-make-move',
    stepKind: DjedV2StepKind.makeMove,
    title: 'Make one move',
    phase: 'SUPPORT 02',
    slot: DjedTimingSlot.openMorning,
    durationMinutes: 5,
    context:
        'Same method, new beam. One useful move. Small enough to complete before you return.',
    source:
        'Repeating the same method lowers the cognitive cost while the life problem changes.',
    supportSlot: 2,
  ),
  DjedV2Event(
    eventNumber: 5,
    flowDay: 15,
    semanticStepId: 'support-02-read-result',
    stepKind: DjedV2StepKind.readResult,
    title: 'Read the result',
    phase: 'SUPPORT 02',
    slot: DjedTimingSlot.checkMidday,
    durationMinutes: 5,
    context:
        'The work already happened outside the app. This sitting only asks what the move taught you.',
    source:
        'A useful result can be improvement, information, or a smaller retry.',
    supportSlot: 2,
  ),
  DjedV2Event(
    eventNumber: 6,
    flowDay: 19,
    semanticStepId: 'support-03-make-move',
    stepKind: DjedV2StepKind.makeMove,
    title: 'Make one move',
    phase: 'SUPPORT 03',
    slot: DjedTimingSlot.sealEvening,
    durationMinutes: 5,
    context:
        'You know the pattern now: find the part you can move, keep it small, put it in time.',
    source:
        'The repeated structure is intentional: capability grows through doing the method again.',
    supportSlot: 3,
  ),
  DjedV2Event(
    eventNumber: 7,
    flowDay: 21,
    semanticStepId: 'support-03-read-result',
    stepKind: DjedV2StepKind.readResult,
    title: 'Read the result',
    phase: 'SUPPORT 03',
    slot: DjedTimingSlot.openMorning,
    durationMinutes: 5,
    context:
        'Look at the result, not the intention. What happened is enough to tell you what comes next.',
    source:
        'Verification keeps the flow grounded in lived evidence instead of aspiration.',
    supportSlot: 3,
  ),
  DjedV2Event(
    eventNumber: 8,
    flowDay: 25,
    semanticStepId: 'support-04-make-move',
    stepKind: DjedV2StepKind.makeMove,
    title: 'Make one move',
    phase: 'SUPPORT 04',
    slot: DjedTimingSlot.checkMidday,
    durationMinutes: 5,
    context:
        'Last beam. Do not make the move bigger because it is last. Small and doable still wins.',
    source:
        'The fourth beam uses the exact same process: controllable action first, interpretation later.',
    supportSlot: 4,
  ),
  DjedV2Event(
    eventNumber: 9,
    flowDay: 29,
    semanticStepId: 'support-04-read-result-and-raise',
    stepKind: DjedV2StepKind.readResult,
    title: 'Read the result',
    phase: 'SUPPORT 04',
    slot: DjedTimingSlot.openMorning,
    durationMinutes: 15,
    context: 'Read the last result. Then stand and raise the whole structure.',
    source:
        'The final raising closes four cycles of deliberate action and return to reality.',
    supportSlot: 4,
    finalRaising: true,
  ),
];

class DjedV2Configuration {
  const DjedV2Configuration({
    required this.supports,
    this.materializationVersion = kDjedV2MaterializationVersion,
  });

  final List<DjedV2SupportDefinition> supports;
  final String materializationVersion;

  bool get isComplete =>
      supports.length == 4 &&
      supports.map((support) => support.slot).toSet().length == 4 &&
      supports.every((support) => support.name.trim().isNotEmpty);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema_version': kDjedV2SchemaVersion,
    'supports': supports.map((support) => support.toJson()).toList(),
    'materialization': <String, dynamic>{
      'version': materializationVersion,
      'event_count': kDjedV2Events.length,
      'flow_days': kDjedV2Events.map((event) => event.flowDay).toList(),
    },
  };

  static DjedV2Configuration? fromJson(Map<String, dynamic> json) {
    if (_intValue(json['schema_version']) != kDjedV2SchemaVersion) return null;
    final rawSupports = json['supports'];
    if (rawSupports is! List) return null;
    final supports =
        rawSupports
            .whereType<Map>()
            .map(
              (value) => DjedV2SupportDefinition.fromJson(
                Map<String, dynamic>.from(value),
              ),
            )
            .whereType<DjedV2SupportDefinition>()
            .toList(growable: false)
          ..sort((a, b) => a.slot.compareTo(b.slot));
    final rawMaterialization = json['materialization'];
    final materialization = rawMaterialization is Map
        ? Map<String, dynamic>.from(rawMaterialization)
        : const <String, dynamic>{};
    final result = DjedV2Configuration(
      supports: supports,
      materializationVersion:
          materialization['version']?.toString().trim().isNotEmpty == true
          ? materialization['version'].toString().trim()
          : kDjedV2MaterializationVersion,
    );
    return result.isComplete ? result : null;
  }
}

String djedV2ConfigurationNotesToken(DjedV2Configuration configuration) =>
    Uri.encodeComponent(jsonEncode(configuration.toJson()));

DjedV2Configuration? djedV2ConfigurationFromNotes(String? notes) {
  if (notes == null || notes.trim().isEmpty) return null;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('djed_v2_config=')) continue;
    try {
      final decoded = jsonDecode(
        Uri.decodeComponent(trimmed.substring('djed_v2_config='.length)),
      );
      if (decoded is! Map) return null;
      return DjedV2Configuration.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
  return null;
}

int djedSchemaVersion({
  String? flowNotes,
  Map<String, dynamic>? behaviorPayload,
}) {
  final payloadVersion = _intValue(behaviorPayload?['djed_schema_version']);
  if (payloadVersion != null) return payloadVersion;
  if (flowNotes != null) {
    for (final token in flowNotes.split(';')) {
      final trimmed = token.trim();
      if (trimmed.startsWith('djed_schema_version=')) {
        return _intValue(trimmed.substring('djed_schema_version='.length)) ?? 1;
      }
    }
  }
  return 1;
}

DjedV2Event? djedV2EventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kDjedV2Events) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

DjedV2Event? djedV2EventForEvent({
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (djedSchemaVersion(behaviorPayload: behaviorPayload) !=
      kDjedV2SchemaVersion) {
    return null;
  }
  final semanticId = behaviorPayload?['semantic_step_id']?.toString().trim();
  if (semanticId != null && semanticId.isNotEmpty) {
    for (final event in kDjedV2Events) {
      if (event.semanticStepId == semanticId) return event;
    }
  }
  final normalizedAction = actionId?.trim();
  if (normalizedAction != null && normalizedAction.isNotEmpty) {
    for (final event in kDjedV2Events) {
      if (djedV2ActionId(event) == normalizedAction) return event;
    }
  }
  return djedV2EventByNumber(_intValue(behaviorPayload?['event_number']));
}

DjedOccurrenceSchedule djedV2ScheduleForEvent(
  DjedV2Event event,
  DateTime flowStart,
  TrackSkyTimeZone timezone,
) => djedScheduleForOccurrence(
  flowDay: event.flowDay,
  slot: event.slot,
  durationMinutes: event.durationMinutes,
  flowStart: flowStart,
  timezone: timezone,
);

String djedV2ActionId(DjedV2Event event) =>
    'the-djed-v2-${event.semanticStepId}';

String djedV2ClientEventId({required int flowId, required DjedV2Event event}) =>
    'djed-v2:$flowId:${event.semanticStepId}';

String djedV2EventTitle(DjedV2Event event) =>
    'Djed ${event.eventNumber}: ${event.title}';

String djedV2DetailText(
  DjedV2Event event, {
  required DjedLens lens,
}) => <String>[
  event.context,
  'Why this belongs at the Djed\n${event.source}',
  if (event.finalRaising)
    'The raising\nStand. Raise the whole structure. Hold with the pillar for $kDjedRaisingSeconds seconds.',
  if (lens.detailLine.trim().isNotEmpty) 'Lens\n${lens.detailLine.trim()}',
].join('\n\n');

String? canonicalDjedV2DetailTextForEvent({
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  final event = djedV2EventForEvent(
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      djedLensFromKey(behaviorPayload?['lens']?.toString()) ?? DjedLens.neutral;
  return djedV2DetailText(event, lens: lens);
}

Map<String, dynamic> djedV2BehaviorPayload({
  required DjedV2Event event,
  required DjedOccurrenceSchedule schedule,
  required DjedLens lens,
  required DjedV2Configuration configuration,
}) {
  final support = event.supportSlot == null
      ? null
      : configuration.supports[event.supportSlot! - 1];
  return <String, dynamic>{
    'kind': kDjedV2BehaviorKind,
    'flow_key': kTheDjedFlowKey,
    'djed_schema_version': kDjedV2SchemaVersion,
    'semantic_step_id': event.semanticStepId,
    'event_number': event.eventNumber,
    'support_slot': event.supportSlot,
    if (support != null) 'support_name': support.name,
    if (support != null)
      'support_initial_condition': support.initialCondition.key,
    'immutable_occurrence': <String, dynamic>{
      'flow_day': event.flowDay,
      'timing_slot': event.slot.key,
      'duration_minutes': event.durationMinutes,
      'final_raising': event.finalRaising,
    },
    'hydration': <String, dynamic>{
      'schema_version': kDjedV2SchemaVersion,
      'materialization_version': configuration.materializationVersion,
      'semantic_step_id': event.semanticStepId,
    },
    'missed_event_rule': 'expire_quietly',
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'schedule': <String, dynamic>{
      'type': schedule.scheduleType,
      'fallback': schedule.fallback,
      'used_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocationName,
      if (schedule.middayHour != null) 'midday_hour': schedule.middayHour,
      if (schedule.middayMinute != null) 'midday_minute': schedule.middayMinute,
    },
    'lens': lens.key,
  };
}

int? _intValue(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
