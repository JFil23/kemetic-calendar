import 'package:flutter/foundation.dart';

import '../../../data/user_events_repo.dart';
import '../../../utils/flow_filter_engine.dart';
import '../calendar_hydration_diagnostics.dart';
import 'calendar_hydration_models.dart';

@immutable
class CalendarHydrationCatalogEntry {
  const CalendarHydrationCatalogEntry({
    required this.id,
    required this.userId,
    required this.calendarId,
    required this.name,
    required this.color,
    required this.active,
    required this.isSaved,
    required this.savedAt,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.rules,
    required this.shareId,
    required this.isHidden,
    required this.isReminder,
    required this.reminderUuid,
  });

  final int id;
  final String? userId;
  final String? calendarId;
  final String name;
  final int color;
  final bool active;
  final bool isSaved;
  final DateTime? savedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final String rules;
  final String? shareId;
  final bool isHidden;
  final bool isReminder;
  final String? reminderUuid;

  CalendarCatalogFingerprintRow get fingerprintRow =>
      CalendarCatalogFingerprintRow(
        id: id,
        userId: userId,
        calendarId: calendarId,
        name: name,
        color: color,
        active: active,
        isSaved: isSaved,
        startDate: startDate,
        endDate: endDate,
        notes: notes,
        rules: rules,
        shareId: shareId,
        isHidden: isHidden,
        isReminder: isReminder,
        reminderUuid: reminderUuid,
      );
}

@immutable
class CalendarHydrationCatalogSnapshot {
  CalendarHydrationCatalogSnapshot(List<CalendarHydrationCatalogEntry> entries)
    : entries = List<CalendarHydrationCatalogEntry>.unmodifiable(entries),
      fingerprint = computeCalendarCatalogFingerprint(
        entries.map((entry) => entry.fingerprintRow),
      );

  final List<CalendarHydrationCatalogEntry> entries;
  final String fingerprint;
}

@immutable
class CalendarHydrationWindowResult {
  const CalendarHydrationWindowResult({
    required this.interval,
    required this.catalogFingerprint,
    required this.flowEvents,
    required this.standaloneEvents,
    required this.flowStartedAtUtc,
    required this.flowEndedAtUtc,
    required this.flowDurationMs,
    required this.standaloneStartedAtUtc,
    required this.standaloneEndedAtUtc,
    required this.standaloneDurationMs,
  });

  final CalendarHydrationInterval interval;
  final String catalogFingerprint;
  final HydrationFetchResult<List<FlowEventRow>> flowEvents;
  final HydrationFetchResult<StandaloneEventRangeResult> standaloneEvents;
  final DateTime flowStartedAtUtc;
  final DateTime flowEndedAtUtc;
  final int flowDurationMs;
  final DateTime? standaloneStartedAtUtc;
  final DateTime? standaloneEndedAtUtc;
  final int standaloneDurationMs;

  bool get succeeded => flowEvents.succeeded && standaloneEvents.succeeded;
}

typedef CalendarCatalogLoader =
    Future<CalendarHydrationCatalogSnapshot> Function(
      HydrationDiagnosticContext? diagnosticContext,
    );
typedef CalendarFlowLaneLoader =
    Future<HydrationFetchResult<List<FlowEventRow>>> Function(
      Set<int> flowIds,
      CalendarHydrationInterval interval,
      HydrationDiagnosticContext? diagnosticContext,
    );
typedef CalendarStandaloneLaneLoader =
    Future<HydrationFetchResult<StandaloneEventRangeResult>> Function(
      CalendarHydrationInterval interval,
      Map<int, FlowRecordSnapshot> owners,
      HydrationDiagnosticContext? diagnosticContext,
    );

/// Read-only calendar hydration facade. It returns immutable values and has no
/// reference to page state, authority, cache, or rendering.
class CalendarHydrationRepository {
  CalendarHydrationRepository({
    required CalendarCatalogLoader loadCatalog,
    required CalendarFlowLaneLoader loadFlowLane,
    required CalendarStandaloneLaneLoader loadStandaloneLane,
  }) : _loadCatalog = loadCatalog,
       _loadFlowLane = loadFlowLane,
       _loadStandaloneLane = loadStandaloneLane;

  factory CalendarHydrationRepository.fromUserEventsRepo(UserEventsRepo repo) {
    return CalendarHydrationRepository(
      loadCatalog: (diagnosticContext) async {
        final rows = await repo.getAllFlows(
          diagnosticContext: diagnosticContext,
          includeSavedTimestamps: false,
        );
        return CalendarHydrationCatalogSnapshot(
          rows
              .map(
                (row) => CalendarHydrationCatalogEntry(
                  id: row.id,
                  userId: row.userId,
                  calendarId: row.calendarId,
                  name: row.name,
                  color: row.color,
                  active: row.active,
                  isSaved: row.isSaved,
                  savedAt: row.savedAt,
                  startDate: row.startDate,
                  endDate: row.endDate,
                  notes: row.notes,
                  rules: row.rules,
                  shareId: row.shareId,
                  isHidden: row.isHidden,
                  isReminder: row.isReminder,
                  reminderUuid: row.reminderUuid,
                ),
              )
              .toList(growable: false),
        );
      },
      loadFlowLane: (flowIds, interval, diagnosticContext) =>
          repo.getEventsForFlowIds(
            flowIds,
            startUtc: interval.startUtc,
            endUtc: interval.endUtc,
            diagnosticContext: diagnosticContext,
          ),
      loadStandaloneLane: (interval, owners, diagnosticContext) =>
          repo.getStandaloneEventsForDateRangeAll(
            startUtc: interval.startUtc,
            endUtc: interval.endUtc,
            pageSize: 1000,
            flowOwnersById: owners,
            diagnosticContext: diagnosticContext,
          ),
    );
  }

  final CalendarCatalogLoader _loadCatalog;
  final CalendarFlowLaneLoader _loadFlowLane;
  final CalendarStandaloneLaneLoader _loadStandaloneLane;

  Future<CalendarHydrationCatalogSnapshot> fetchCatalog({
    HydrationDiagnosticContext? diagnosticContext,
  }) => _loadCatalog(diagnosticContext);

  /// Executes the two authority lanes sequentially. A failed flow lane stops
  /// the job before standalone so database-heavy work cannot overlap or waste
  /// capacity on a result that is forbidden to commit.
  Future<CalendarHydrationWindowResult> fetchWindow({
    required CalendarHydrationInterval interval,
    required String catalogFingerprint,
    required Set<int> flowIds,
    required Map<int, FlowRecordSnapshot> flowOwnersById,
    required void Function() cancellationCheck,
    HydrationDiagnosticContext? diagnosticContext,
  }) async {
    cancellationCheck();
    final flowStartedAtUtc = DateTime.now().toUtc();
    final flowStopwatch = Stopwatch()..start();
    final flow = flowIds.isEmpty
        ? const HydrationFetchResult<List<FlowEventRow>>.successfulEmpty(
            <FlowEventRow>[],
          )
        : await _loadFlowLane(flowIds, interval, diagnosticContext);
    final flowEndedAtUtc = DateTime.now().toUtc();
    cancellationCheck();
    if (!flow.succeeded) {
      return CalendarHydrationWindowResult(
        interval: interval,
        catalogFingerprint: catalogFingerprint,
        flowEvents: flow,
        standaloneEvents:
            const HydrationFetchResult<StandaloneEventRangeResult>.failed((
              events: <StandaloneEventRow>[],
              ghostEventIds: <String>[],
              pageCount: 0,
              rawCount: 0,
            )),
        flowStartedAtUtc: flowStartedAtUtc,
        flowEndedAtUtc: flowEndedAtUtc,
        flowDurationMs: flowStopwatch.elapsedMilliseconds,
        standaloneStartedAtUtc: null,
        standaloneEndedAtUtc: null,
        standaloneDurationMs: 0,
      );
    }
    final standaloneStartedAtUtc = DateTime.now().toUtc();
    final standaloneStopwatch = Stopwatch()..start();
    final standalone = await _loadStandaloneLane(
      interval,
      flowOwnersById,
      diagnosticContext,
    );
    final standaloneEndedAtUtc = DateTime.now().toUtc();
    cancellationCheck();
    return CalendarHydrationWindowResult(
      interval: interval,
      catalogFingerprint: catalogFingerprint,
      flowEvents: flow,
      standaloneEvents: standalone,
      flowStartedAtUtc: flowStartedAtUtc,
      flowEndedAtUtc: flowEndedAtUtc,
      flowDurationMs: flowStopwatch.elapsedMilliseconds,
      standaloneStartedAtUtc: standaloneStartedAtUtc,
      standaloneEndedAtUtc: standaloneEndedAtUtc,
      standaloneDurationMs: standaloneStopwatch.elapsedMilliseconds,
    );
  }
}
