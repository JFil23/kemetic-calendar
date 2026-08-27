import 'dart:async';

import 'maat_flow_identity.dart';

enum MaatFlowCatalogStatus { core, absorbed, retired, legacy }

class MaatFlowCatalogEntry {
  const MaatFlowCatalogEntry({
    required this.kind,
    required this.status,
    this.verb,
  });

  final MaatFlowKind kind;
  final MaatFlowCatalogStatus status;
  final String? verb;

  bool get isJoinable => status == MaatFlowCatalogStatus.core;
}

const Map<MaatFlowKind, MaatFlowCatalogEntry> kMaatFlowCatalog =
    <MaatFlowKind, MaatFlowCatalogEntry>{
      MaatFlowKind.trackSky: MaatFlowCatalogEntry(
        kind: MaatFlowKind.trackSky,
        status: MaatFlowCatalogStatus.core,
        verb: 'ORIENT',
      ),
      MaatFlowKind.dawnHouseRite: MaatFlowCatalogEntry(
        kind: MaatFlowKind.dawnHouseRite,
        status: MaatFlowCatalogStatus.core,
        verb: 'BEGIN',
      ),
      MaatFlowKind.eveningThreshold: MaatFlowCatalogEntry(
        kind: MaatFlowKind.eveningThreshold,
        status: MaatFlowCatalogStatus.legacy,
      ),
      MaatFlowKind.eveningThresholdRite: MaatFlowCatalogEntry(
        kind: MaatFlowKind.eveningThresholdRite,
        status: MaatFlowCatalogStatus.core,
        verb: 'CLOSE',
      ),
      MaatFlowKind.theWeighing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theWeighing,
        status: MaatFlowCatalogStatus.core,
        verb: 'CORRECT',
      ),
      MaatFlowKind.offeringTable: MaatFlowCatalogEntry(
        kind: MaatFlowKind.offeringTable,
        status: MaatFlowCatalogStatus.core,
        verb: 'NOURISH',
      ),
      MaatFlowKind.theTending: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theTending,
        status: MaatFlowCatalogStatus.core,
        verb: 'CARE',
      ),
      MaatFlowKind.keptWord: MaatFlowCatalogEntry(
        kind: MaatFlowKind.keptWord,
        status: MaatFlowCatalogStatus.core,
        verb: 'KEEP',
      ),
      MaatFlowKind.theCourse: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theCourse,
        status: MaatFlowCatalogStatus.retired,
      ),
      MaatFlowKind.moonReturn: MaatFlowCatalogEntry(
        kind: MaatFlowKind.moonReturn,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.theWag: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theWag,
        status: MaatFlowCatalogStatus.core,
        verb: 'REMEMBER',
      ),
      MaatFlowKind.decanWatch: MaatFlowCatalogEntry(
        kind: MaatFlowKind.decanWatch,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.daysOutsideTheYear: MaatFlowCatalogEntry(
        kind: MaatFlowKind.daysOutsideTheYear,
        status: MaatFlowCatalogStatus.core,
        verb: 'RENEW',
      ),
      MaatFlowKind.theOpenHand: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theOpenHand,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.theDjed: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theDjed,
        status: MaatFlowCatalogStatus.core,
        verb: 'STABILIZE',
      ),
      MaatFlowKind.readingHouse: MaatFlowCatalogEntry(
        kind: MaatFlowKind.readingHouse,
        status: MaatFlowCatalogStatus.core,
        verb: 'STUDY',
      ),
      MaatFlowKind.fairHearing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.fairHearing,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.houseOfLife: MaatFlowCatalogEntry(
        kind: MaatFlowKind.houseOfLife,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.boundaryStone: MaatFlowCatalogEntry(
        kind: MaatFlowKind.boundaryStone,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.hotep: MaatFlowCatalogEntry(
        kind: MaatFlowKind.hotep,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.openMouth: MaatFlowCatalogEntry(
        kind: MaatFlowKind.openMouth,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.livingRecord: MaatFlowCatalogEntry(
        kind: MaatFlowKind.livingRecord,
        status: MaatFlowCatalogStatus.retired,
      ),
      MaatFlowKind.hetHeru: MaatFlowCatalogEntry(
        kind: MaatFlowKind.hetHeru,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.theShore: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theShore,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.theAutobiography: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theAutobiography,
        status: MaatFlowCatalogStatus.retired,
      ),
      MaatFlowKind.firstArrangement: MaatFlowCatalogEntry(
        kind: MaatFlowKind.firstArrangement,
        status: MaatFlowCatalogStatus.core,
        verb: 'ORDER',
      ),
      MaatFlowKind.livingPattern: MaatFlowCatalogEntry(
        kind: MaatFlowKind.livingPattern,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.trueName: MaatFlowCatalogEntry(
        kind: MaatFlowKind.trueName,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.livingText: MaatFlowCatalogEntry(
        kind: MaatFlowKind.livingText,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.clearing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.clearing,
        status: MaatFlowCatalogStatus.core,
        verb: 'CLEAR',
      ),
      MaatFlowKind.wandering: MaatFlowCatalogEntry(
        kind: MaatFlowKind.wandering,
        status: MaatFlowCatalogStatus.retired,
      ),
      MaatFlowKind.khat: MaatFlowCatalogEntry(
        kind: MaatFlowKind.khat,
        status: MaatFlowCatalogStatus.absorbed,
      ),
      MaatFlowKind.oracle: MaatFlowCatalogEntry(
        kind: MaatFlowKind.oracle,
        status: MaatFlowCatalogStatus.retired,
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
