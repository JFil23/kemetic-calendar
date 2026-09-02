import 'dart:async';

import 'maat_flow_identity.dart';
import 'maat_flow_temporal_policy.dart';

enum MaatFlowCatalogStatus { core, absorbed, retired, legacy }

class MaatFlowCatalogEntry {
  const MaatFlowCatalogEntry({
    required this.kind,
    required this.status,
    required this.temporalPolicy,
    this.verb,
  });

  final MaatFlowKind kind;
  final MaatFlowCatalogStatus status;
  final MaatFlowTemporalPolicy temporalPolicy;
  final String? verb;

  bool get isJoinable => status == MaatFlowCatalogStatus.core;
}

const Map<MaatFlowKind, MaatFlowCatalogEntry> kMaatFlowCatalog =
    <MaatFlowKind, MaatFlowCatalogEntry>{
      MaatFlowKind.trackSky: MaatFlowCatalogEntry(
        kind: MaatFlowKind.trackSky,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.nextEligibleSkyEvent,
        verb: 'ORIENT',
      ),
      MaatFlowKind.dawnHouseRite: MaatFlowCatalogEntry(
        kind: MaatFlowKind.dawnHouseRite,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.dawnHouseRite,
        verb: 'BEGIN',
      ),
      MaatFlowKind.eveningThreshold: MaatFlowCatalogEntry(
        kind: MaatFlowKind.eveningThreshold,
        status: MaatFlowCatalogStatus.legacy,
        temporalPolicy: MaatFlowTemporalPolicy.eveningThreshold,
      ),
      MaatFlowKind.eveningThresholdRite: MaatFlowCatalogEntry(
        kind: MaatFlowKind.eveningThresholdRite,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.eveningThresholdRite,
        verb: 'CLOSE',
      ),
      MaatFlowKind.theWeighing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theWeighing,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.theWeighing,
        verb: 'CORRECT',
      ),
      MaatFlowKind.offeringTable: MaatFlowCatalogEntry(
        kind: MaatFlowKind.offeringTable,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.relativeCalendarDays(1),
        verb: 'NOURISH',
      ),
      MaatFlowKind.theTending: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theTending,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.theTending,
        verb: 'CARE',
      ),
      MaatFlowKind.keptWord: MaatFlowCatalogEntry(
        kind: MaatFlowKind.keptWord,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.keptWord,
        verb: 'KEEP',
      ),
      MaatFlowKind.theCourse: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theCourse,
        status: MaatFlowCatalogStatus.retired,
        temporalPolicy: MaatFlowTemporalPolicy.theCourse,
      ),
      MaatFlowKind.moonReturn: MaatFlowCatalogEntry(
        kind: MaatFlowKind.moonReturn,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.moonReturn,
      ),
      MaatFlowKind.theWag: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theWag,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.nextWepRonpetWindow,
        verb: 'REMEMBER',
      ),
      MaatFlowKind.decanWatch: MaatFlowCatalogEntry(
        kind: MaatFlowKind.decanWatch,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.daysOutsideTheYear: MaatFlowCatalogEntry(
        kind: MaatFlowKind.daysOutsideTheYear,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.nextDaysOutsideYearWindow,
        verb: 'RENEW',
      ),
      MaatFlowKind.theOpenHand: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theOpenHand,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.theDjed: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theDjed,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
        verb: 'STABILIZE',
      ),
      MaatFlowKind.readingHouse: MaatFlowCatalogEntry(
        kind: MaatFlowKind.readingHouse,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.relativeCalendarDays(3),
        verb: 'STUDY',
      ),
      MaatFlowKind.fairHearing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.fairHearing,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.houseOfLife: MaatFlowCatalogEntry(
        kind: MaatFlowKind.houseOfLife,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.boundaryStone: MaatFlowCatalogEntry(
        kind: MaatFlowKind.boundaryStone,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.hotep: MaatFlowCatalogEntry(
        kind: MaatFlowKind.hotep,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.openMouth: MaatFlowCatalogEntry(
        kind: MaatFlowKind.openMouth,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.livingRecord: MaatFlowCatalogEntry(
        kind: MaatFlowKind.livingRecord,
        status: MaatFlowCatalogStatus.retired,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.hetHeru: MaatFlowCatalogEntry(
        kind: MaatFlowKind.hetHeru,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.theShore: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theShore,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.theAutobiography: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theAutobiography,
        status: MaatFlowCatalogStatus.retired,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.firstArrangement: MaatFlowCatalogEntry(
        kind: MaatFlowKind.firstArrangement,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
        verb: 'ORDER',
      ),
      MaatFlowKind.livingPattern: MaatFlowCatalogEntry(
        kind: MaatFlowKind.livingPattern,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.trueName: MaatFlowCatalogEntry(
        kind: MaatFlowKind.trueName,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.livingText: MaatFlowCatalogEntry(
        kind: MaatFlowKind.livingText,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.clearing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.clearing,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
        verb: 'CLEAR',
      ),
      MaatFlowKind.wandering: MaatFlowCatalogEntry(
        kind: MaatFlowKind.wandering,
        status: MaatFlowCatalogStatus.retired,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.khat: MaatFlowCatalogEntry(
        kind: MaatFlowKind.khat,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.oracle: MaatFlowCatalogEntry(
        kind: MaatFlowKind.oracle,
        status: MaatFlowCatalogStatus.retired,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
    };

MaatFlowCatalogEntry maatFlowCatalogEntry(MaatFlowKind kind) {
  final entry = kMaatFlowCatalog[kind];
  if (entry == null) {
    throw StateError('Missing Ma’at catalog disposition for ${kind.name}.');
  }
  return entry;
}

bool isCoreMaatFlowKind(MaatFlowKind kind) =>
    maatFlowCatalogEntry(kind).isJoinable;

bool isCoreMaatFlowKey(String flowKey) {
  final kind = resolveMaatFlowKind(
    behaviorPayload: <String, dynamic>{'flow_key': flowKey},
  );
  return kind != null && isCoreMaatFlowKind(kind);
}

bool isMaatFlowNewJoinAllowed(String flowKey) => isCoreMaatFlowKey(flowKey);

List<MaatFlowKind> get coreMaatFlowKinds => List<MaatFlowKind>.unmodifiable(
  MaatFlowKind.values.where(isCoreMaatFlowKind),
);

Set<String> get coreMaatFlowKeys =>
    Set<String>.unmodifiable(coreMaatFlowKinds.map((kind) => kind.flowKey));

MaatFlowKind? resolveMaatFlowKindFromFlowSnapshot({
  String? flowName,
  String? flowNotes,
  String? flowKey,
  Iterable<Object?> events = const <Object?>[],
}) {
  final direct = resolveMaatFlowKind(
    flowNotes: flowNotes,
    behaviorPayload: flowKey == null
        ? null
        : <String, dynamic>{'flow_key': flowKey},
  );
  if (direct != null) return direct;

  for (final raw in events) {
    if (raw is! Map) continue;
    final event = Map<String, dynamic>.from(raw);
    final rawBehaviorPayload =
        event['behavior_payload'] ?? event['behaviorPayload'];
    final behaviorPayload = rawBehaviorPayload is Map
        ? Map<String, dynamic>.from(rawBehaviorPayload)
        : null;
    final kind = resolveMaatFlowKind(
      actionId: (event['action_id'] ?? event['actionId'])?.toString(),
      behaviorPayload: behaviorPayload,
    );
    if (kind != null) return kind;
  }
  return resolveMaatFlowKind(flowName: flowName);
}

bool isNewFlowCreationAllowedByMaatCatalog({
  String? flowName,
  String? flowNotes,
  String? flowKey,
  Iterable<Object?> events = const <Object?>[],
}) {
  final kind = resolveMaatFlowKindFromFlowSnapshot(
    flowName: flowName,
    flowNotes: flowNotes,
    flowKey: flowKey,
    events: events,
  );
  return kind == null || isCoreMaatFlowKind(kind);
}

class NonJoinableMaatFlowException implements Exception {
  const NonJoinableMaatFlowException(this.kind);

  final MaatFlowKind kind;

  @override
  String toString() =>
      'This Ma’at Flow is preserved for existing history but is no longer '
      'available to add.';
}

void ensureNewFlowCreationAllowedByMaatCatalog({
  String? flowName,
  String? flowNotes,
  String? flowKey,
  Iterable<Object?> events = const <Object?>[],
}) {
  final kind = resolveMaatFlowKindFromFlowSnapshot(
    flowName: flowName,
    flowNotes: flowNotes,
    flowKey: flowKey,
    events: events,
  );
  if (kind != null && !isCoreMaatFlowKind(kind)) {
    throw NonJoinableMaatFlowException(kind);
  }
}

Future<T> applyMaatFlowNewJoinPolicy<T>({
  required String flowKey,
  required T rejectedValue,
  required FutureOr<T> Function() create,
}) async {
  if (!isMaatFlowNewJoinAllowed(flowKey)) return rejectedValue;
  return await create();
}
