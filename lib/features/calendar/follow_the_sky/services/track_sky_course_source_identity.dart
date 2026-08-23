import '../domain/track_sky_course.dart';

/// Stable course-source identity for Follow the Sky V2.
///
/// Gate 16: linkage must survive sync/rehydration and must not alias another flow.
///
/// Durable identity evidence (same-user):
/// - `FlowsRepo.insert` / upsert returns the Postgres `flows.id` from
///   `.insert(payload).select().single()` — not an app-only counter.
/// - `calendar_hydration_engine` rebuilds `_Flow(id: f.id, …)` from that same
///   server id on every device for the signed-in user.
/// - Cross-user share/import creates a **new** row/id, so linkage is owning-user
///   scoped (matches Follow the Sky enrollment).
///
/// Wire format:
/// - flow: `flow:<serverId>`  (server PK only — never a local optimistic id)
/// - recurring standalone title: `event_title:<normalizedLabel>`
/// - free text (unlinked): no sourceId
///
/// Resolution after hydrate/restore is owned by [TrackSkyCourseSourceResolver].
class TrackSkyCourseSourceIdentity {
  static const String flowPrefix = 'flow:';
  static const String eventTitlePrefix = 'event_title:';

  static String forFlow(int serverFlowId) {
    if (serverFlowId <= 0) {
      throw ArgumentError.value(serverFlowId, 'serverFlowId', 'must be > 0');
    }
    return '$flowPrefix$serverFlowId';
  }

  static String forEventTitle(String label) {
    final normalized = normalizeLabel(label);
    if (normalized.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must be non-empty');
    }
    return '$eventTitlePrefix$normalized';
  }

  static String normalizeLabel(String label) {
    return label.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static int? tryParseFlowId(String? sourceId) {
    if (sourceId == null || !sourceId.startsWith(flowPrefix)) return null;
    return int.tryParse(sourceId.substring(flowPrefix.length));
  }

  static String? tryParseEventTitle(String? sourceId) {
    if (sourceId == null || !sourceId.startsWith(eventTitlePrefix)) return null;
    return sourceId.substring(eventTitlePrefix.length);
  }

  static TrackSkyCourseSourceType? sourceTypeFor(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) {
      return TrackSkyCourseSourceType.freeText;
    }
    if (sourceId.startsWith(flowPrefix)) return TrackSkyCourseSourceType.flow;
    if (sourceId.startsWith(eventTitlePrefix)) {
      return TrackSkyCourseSourceType.eventTitle;
    }
    return null;
  }

  /// True only when [sourceId] is exactly `flow:<flowId>`.
  /// Label/name is intentionally ignored — rename must not break linkage,
  /// and name equality must never create linkage (see resolver).
  static bool matchesFlow({
    required String? sourceId,
    required int flowId,
    String? courseLabel,
    String? flowName,
  }) {
    final parsed = tryParseFlowId(sourceId);
    return parsed != null && parsed == flowId;
  }
}
