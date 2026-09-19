import 'dart:async';

import 'maat_flow_identity.dart';
import 'maat_flow_temporal_policy.dart';

enum MaatFlowCatalogStatus { core, archived, absorbed, retired, legacy }

class MaatFlowCatalogEntry {
  const MaatFlowCatalogEntry({
    required this.kind,
    required this.status,
    required this.temporalPolicy,
    this.verb,
    this.compatibilityTitle,
    this.compatibilityGlyph,
  });

  final MaatFlowKind kind;
  final MaatFlowCatalogStatus status;
  final MaatFlowTemporalPolicy temporalPolicy;
  final String? verb;
  final String? compatibilityTitle;
  final String? compatibilityGlyph;

  bool get isDiscoverable => isMaatFlowDiscoverableKind(kind);
  bool get isJoinable => isMaatFlowNewJoinAllowedKind(kind);
  bool get isCompatibilitySupported =>
      isMaatFlowCompatibilitySupportedKind(kind);
}

const Set<MaatFlowKind> kDiscoverableMaatFlowKinds = <MaatFlowKind>{
  MaatFlowKind.trackSky,
  MaatFlowKind.offeringTable,
  MaatFlowKind.readingHouse,
  MaatFlowKind.theDjed,
  MaatFlowKind.theKar,
};

const Set<MaatFlowKind> kNewJoinAllowedMaatFlowKinds = <MaatFlowKind>{
  MaatFlowKind.trackSky,
  MaatFlowKind.offeringTable,
  MaatFlowKind.readingHouse,
  MaatFlowKind.theDjed,
  MaatFlowKind.theKar,
};

const Set<MaatFlowKind> kArchivedCompatibilityMaatFlowKinds = <MaatFlowKind>{
  MaatFlowKind.dawnHouseRite,
  MaatFlowKind.eveningThresholdRite,
  MaatFlowKind.theWeighing,
  MaatFlowKind.keptWord,
  MaatFlowKind.theTending,
  MaatFlowKind.firstArrangement,
  MaatFlowKind.clearing,
  MaatFlowKind.theWag,
  MaatFlowKind.daysOutsideTheYear,
};

const Set<MaatFlowKind> kCompatibilitySupportedMaatFlowKinds = <MaatFlowKind>{
  ...kDiscoverableMaatFlowKinds,
  ...kArchivedCompatibilityMaatFlowKinds,
};

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
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'Dawn House Rite',
        compatibilityGlyph: '𓉐',
      ),
      MaatFlowKind.eveningThreshold: MaatFlowCatalogEntry(
        kind: MaatFlowKind.eveningThreshold,
        status: MaatFlowCatalogStatus.legacy,
        temporalPolicy: MaatFlowTemporalPolicy.eveningThreshold,
      ),
      MaatFlowKind.eveningThresholdRite: MaatFlowCatalogEntry(
        kind: MaatFlowKind.eveningThresholdRite,
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Closing',
        compatibilityGlyph: '𓊌',
      ),
      MaatFlowKind.theWeighing: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theWeighing,
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Weighing',
        compatibilityGlyph: '𓍝',
      ),
      MaatFlowKind.offeringTable: MaatFlowCatalogEntry(
        kind: MaatFlowKind.offeringTable,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.relativeCalendarDays(1),
        verb: 'NOURISH',
      ),
      MaatFlowKind.theTending: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theTending,
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Tending',
        compatibilityGlyph: '𓇐',
      ),
      MaatFlowKind.keptWord: MaatFlowCatalogEntry(
        kind: MaatFlowKind.keptWord,
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Kept Word',
        compatibilityGlyph: '𓂋',
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
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Wag',
        compatibilityGlyph: '𓊝',
      ),
      MaatFlowKind.decanWatch: MaatFlowCatalogEntry(
        kind: MaatFlowKind.decanWatch,
        status: MaatFlowCatalogStatus.absorbed,
        temporalPolicy: MaatFlowTemporalPolicy.nextDecanWindow,
      ),
      MaatFlowKind.daysOutsideTheYear: MaatFlowCatalogEntry(
        kind: MaatFlowKind.daysOutsideTheYear,
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Days Outside the Year',
        compatibilityGlyph: '𓆱',
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
      MaatFlowKind.theKar: MaatFlowCatalogEntry(
        kind: MaatFlowKind.theKar,
        status: MaatFlowCatalogStatus.core,
        temporalPolicy: MaatFlowTemporalPolicy.relativeCalendarDays(1),
        verb: 'IMAGINE',
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
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The First Arrangement',
        compatibilityGlyph: '𓇾',
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
        status: MaatFlowCatalogStatus.archived,
        temporalPolicy: MaatFlowTemporalPolicy.archivedReadOnly,
        compatibilityTitle: 'The Clearing',
        compatibilityGlyph: '𓈖',
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

bool isMaatFlowDiscoverableKind(MaatFlowKind kind) =>
    kDiscoverableMaatFlowKinds.contains(kind);

bool isMaatFlowNewJoinAllowedKind(MaatFlowKind kind) =>
    kNewJoinAllowedMaatFlowKinds.contains(kind);

bool isMaatFlowCompatibilitySupportedKind(MaatFlowKind kind) =>
    kCompatibilitySupportedMaatFlowKinds.contains(kind);

String archivedMaatFlowTitle(MaatFlowKind kind) {
  final entry = maatFlowCatalogEntry(kind);
  if (entry.status != MaatFlowCatalogStatus.archived ||
      entry.compatibilityTitle == null) {
    throw StateError('${kind.name} has no archived compatibility title.');
  }
  return entry.compatibilityTitle!;
}

String archivedMaatFlowGlyph(MaatFlowKind kind) {
  final entry = maatFlowCatalogEntry(kind);
  if (entry.status != MaatFlowCatalogStatus.archived ||
      entry.compatibilityGlyph == null) {
    throw StateError('${kind.name} has no archived compatibility glyph.');
  }
  return entry.compatibilityGlyph!;
}

bool isCoreMaatFlowKind(MaatFlowKind kind) => isMaatFlowDiscoverableKind(kind);

bool isCoreMaatFlowKey(String flowKey) {
  final kind = resolveMaatFlowKind(
    behaviorPayload: <String, dynamic>{'flow_key': flowKey},
  );
  return kind != null && isCoreMaatFlowKind(kind);
}

bool isMaatFlowDiscoverable(String flowKey) {
  final kind = resolveMaatFlowKind(
    behaviorPayload: <String, dynamic>{'flow_key': flowKey},
  );
  return kind != null && isMaatFlowDiscoverableKind(kind);
}

bool isMaatFlowNewJoinAllowed(String flowKey) {
  final kind = resolveMaatFlowKind(
    behaviorPayload: <String, dynamic>{'flow_key': flowKey},
  );
  return kind != null && isMaatFlowNewJoinAllowedKind(kind);
}

bool isMaatFlowCompatibilitySupported(String flowKey) {
  final kind = resolveMaatFlowKind(
    behaviorPayload: <String, dynamic>{'flow_key': flowKey},
  );
  return kind != null && isMaatFlowCompatibilitySupportedKind(kind);
}

List<MaatFlowKind> get discoverableMaatFlowKinds =>
    List<MaatFlowKind>.unmodifiable(
      MaatFlowKind.values.where(isMaatFlowDiscoverableKind),
    );

Set<String> get discoverableMaatFlowKeys => Set<String>.unmodifiable(
  discoverableMaatFlowKinds.map((kind) => kind.flowKey),
);

List<MaatFlowKind> get coreMaatFlowKinds =>
    List<MaatFlowKind>.unmodifiable(discoverableMaatFlowKinds);

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
  return kind == null || isMaatFlowNewJoinAllowedKind(kind);
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
  if (kind != null && !isMaatFlowNewJoinAllowedKind(kind)) {
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
