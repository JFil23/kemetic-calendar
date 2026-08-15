part of '../calendar_page.dart';

@immutable
final class _CalendarHydrationProjection {
  _CalendarHydrationProjection({
    required this.flows,
    required Map<String, List<_Note>> notesByDay,
    required this.reminderRules,
    required this.replaceReminderRules,
    required this.nextFlowId,
    required this.authorityScope,
    required this.authorityReason,
    required this.commitIsServerCurrent,
    required this.coverage,
    required this.lastSuccessfulRefreshAtUtc,
    required this.fullServerHydration,
    required this.clearWarmSnapshot,
    required this.affectedMonths,
    required this.extentAffecting,
  }) : notesByDay = Map<String, List<_Note>>.unmodifiable(<String, List<_Note>>{
         for (final entry in notesByDay.entries)
           entry.key: List<_Note>.unmodifiable(entry.value),
       });

  final List<_Flow> flows;
  final Map<String, List<_Note>> notesByDay;
  final List<ReminderRule> reminderRules;
  final bool replaceReminderRules;
  final int nextFlowId;
  final CalendarHydrationAuthorityScope authorityScope;
  final String authorityReason;
  final bool commitIsServerCurrent;
  final CalendarCoverageLedger coverage;
  final DateTime lastSuccessfulRefreshAtUtc;
  final bool fullServerHydration;
  final bool clearWarmSnapshot;
  final Set<MonthRef> affectedMonths;
  final bool extentAffecting;
}

extension _CalendarPresentationPageAdapter on CalendarPageState {
  void _beginCalendarGesturePresentationTransaction() {
    if (_calendarGesturePresentationTransaction != null) return;
    final userId = _activeWarmStartUserId();
    if (userId == null || userId.isEmpty) return;
    _calendarGesturePresentationTransaction = _calendarPresentationCoordinator
        .begin(
          kind: CalendarPresentationTransactionKind.gesture,
          userScope: userId,
        );
  }

  void _settleCalendarGesturePresentationTransaction() {
    final transaction = _calendarGesturePresentationTransaction;
    _calendarGesturePresentationTransaction = null;
    if (transaction != null) {
      _calendarPresentationCoordinator.settle(transaction);
    }
  }

  CalendarPresentationTransaction?
  _beginCalendarTodayPresentationTransaction() {
    final existing = _calendarTodayPresentationTransaction;
    if (existing != null) return existing;
    final userId = _activeWarmStartUserId();
    if (userId == null || userId.isEmpty) return null;
    return _calendarTodayPresentationTransaction =
        _calendarPresentationCoordinator.begin(
          kind: CalendarPresentationTransactionKind.today,
          userScope: userId,
        );
  }

  void _settleCalendarTodayPresentationTransaction(
    CalendarPresentationTransaction? transaction,
  ) {
    if (transaction == null ||
        _calendarTodayPresentationTransaction?.serial != transaction.serial) {
      return;
    }
    _calendarTodayPresentationTransaction = null;
    _calendarPresentationCoordinator.settle(transaction);
  }

  Set<MonthRef> _calendarAffectedMonths(
    Map<String, List<_Note>> nextNotes,
    Iterable<_Flow> nextFlows,
  ) {
    final affected = <MonthRef>{};
    final dayKeys = <String>{..._notes.keys, ...nextNotes.keys};
    for (final dayKey in dayKeys) {
      final before = _notes[dayKey] ?? const <_Note>[];
      final after = nextNotes[dayKey] ?? const <_Note>[];
      if (_calendarNoteBucketDigest(before) ==
          _calendarNoteBucketDigest(after)) {
        continue;
      }
      final month = _calendarMonthFromDayKey(dayKey);
      if (month != null) affected.add(month);
    }

    final beforeFlows = calendarCanonicalJson(
      _flows.map(_serializeWarmStartFlow).toList(growable: false),
    );
    final afterFlows = calendarCanonicalJson(
      nextFlows.map(_serializeWarmStartFlow).toList(growable: false),
    );
    if (beforeFlows != afterFlows) {
      for (final dayKey in dayKeys) {
        final month = _calendarMonthFromDayKey(dayKey);
        if (month != null) affected.add(month);
      }
    }
    return affected;
  }

  bool _calendarProjectionChangesExtent(
    Map<String, List<_Note>> nextNotes,
    Set<MonthRef> affectedMonths,
  ) {
    if (_monthExpansion != MonthExpansionLevel.details ||
        affectedMonths.isEmpty) {
      return false;
    }
    for (final month in affectedMonths) {
      final dayCount = const CalendarSectionIndex().dayCount(month);
      for (var day = 1; day <= dayCount; day++) {
        final key = _kKey(month.year, month.month, day);
        if ((_notes[key]?.length ?? 0) != (nextNotes[key]?.length ?? 0)) {
          return true;
        }
      }
    }
    return false;
  }

  String _calendarGeometryRevision(
    Map<String, List<_Note>> notesByDay,
    Set<MonthRef> affectedMonths,
  ) => calendarSnapshotDigest(
    calendarCanonicalJson(<String, Object?>{
      'expansion': _expansionToString(_monthExpansion),
      'months': <String, Object?>{
        for (final month in affectedMonths.toList()..sort())
          '${month.year}-${month.month}': <int>[
            for (
              var day = 1;
              day <= const CalendarSectionIndex().dayCount(month);
              day++
            )
              notesByDay[_kKey(month.year, month.month, day)]?.length ?? 0,
          ],
      },
    }),
  );

  String _calendarNoteBucketDigest(Iterable<_Note> notes) =>
      calendarSnapshotDigest(
        calendarCanonicalJson(
          notes.map(_serializeWarmStartNote).toList(growable: false),
        ),
      );

  MonthRef? _calendarMonthFromDayKey(String dayKey) {
    final match = RegExp(r'^(-?\d+)-(\d+)-(\d+)$').firstMatch(dayKey);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (year == null || month == null || month < 1 || month > 13) return null;
    return MonthRef(year: year, month: month);
  }

  void _activateCalendarHydrationEpoch(
    CalendarPresentationEpoch<_CalendarHydrationProjection> epoch,
  ) {
    if (!mounted || _activeWarmStartUserId() != epoch.userScope) return;
    final projection = epoch.projection;
    if (epoch.extentAffecting) {
      _calendarLayoutCorrection.request(
        geometryRevision: epoch.geometryRevision,
        resolveAnchor: _resolveCalendarLayoutCorrectionAnchor,
      );
      _calendarGeometryCollector.beginPresentationEpoch(epoch.geometryRevision);
    }

    _flows
      ..clear()
      ..addAll(projection.flows);
    // Every projection crosses the same publication seam. It copies the
    // prepared state and applies occurrence, delete, and ended-series intent
    // through one shared reducer before anything can paint.
    _replaceLiveNoteBuckets(projection.notesByDay);
    if (projection.replaceReminderRules) {
      _reminderRules
        ..clear()
        ..addAll(
          projection.reminderRules.where(
            (rule) => !_endedReminderIds.contains(rule.id),
          ),
        );
      _reminderRulesLoaded = true;
    }
    _nextFlowId = math.max(_nextFlowId, projection.nextFlowId);
    CalendarPage._reconcileRememberedMaatJoinsFromLiveFlows(_flows);
    _rebuildReminderRulesFromFlowsIfMissing();
    _setHydrationAuthorityScope(
      projection.authorityScope,
      reason: projection.authorityReason,
    );
    if (projection.commitIsServerCurrent) {
      _lastAuthoritativeHydrationAt = projection.lastSuccessfulRefreshAtUtc
          .toLocal();
      _latestCalendarRefreshStatus = CalendarRefreshStatus.succeeded;
    }
    _activeCalendarCoverage = projection.coverage;
    if (projection.fullServerHydration) {
      _serverHydrationCommittedForUserId = _activeWarmStartUserId();
    }
    if (projection.clearWarmSnapshot) _warmStartSnapshotVisible = false;
    _warmStartCacheRestoredForUserId = _activeWarmStartUserId();
    _dataVersion++;
    _publishCalendarRefreshState();
    _publishCalendarMonthProjections(projection.affectedMonths);
    _notifyDayViewDataChanged(scheduleCacheSave: false);
  }

  void _clearCalendarPresentationScope(String previousUserScope) {
    _calendarGesturePresentationTransaction = null;
    _calendarTodayPresentationTransaction = null;
    final affected = <MonthRef>{
      for (final key in _notes.keys)
        if (_calendarMonthFromDayKey(key) case final month?) month,
    };
    _flows.clear();
    _notes.clear();
    _calendarAuthoritativeFlows = null;
    _calendarAuthoritativeNotesByDay = null;
    _activeCalendarCoverage = null;
    _latestCalendarRefreshStatus = CalendarRefreshStatus.idle;
    _flowTotalEventCounts.clear();
    _flowRemainingEventCounts.clear();
    _calendarSummariesById.clear();
    _hiddenCalendarIds.clear();
    _personalCalendarId = null;
    _calendarStateLoaded = false;
    _unconfirmed.clear();
    _pendingDeletes.clear();
    _manualDeleteTombstones.clear();
    _occurrenceExclusions.clear();
    _occurrenceExclusionsLoadedForUserId = null;
    _occurrenceExclusionsLoad = null;
    _occurrenceExclusionsServerLoadedAt = null;
    _publishCalendarMonthProjections(affected);
    _notifyDayViewDataChanged(scheduleCacheSave: false);
  }
}
