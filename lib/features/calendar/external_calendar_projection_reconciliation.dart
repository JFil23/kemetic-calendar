part of 'calendar_page.dart';

extension _ExternalCalendarProjectionReconciliation on CalendarPageState {
  Future<void> _reconcileExternalCalendarSourceRemoval(
    ExternalCalendarInvalidation invalidation,
  ) async {
    final repository = externalCalendarRepository(Supabase.instance.client);
    bool current() =>
        mounted &&
        _activeWarmStartUserId() == invalidation.accountId &&
        repository.lane == invalidation.lane;
    if (!current() || invalidation.removedSourceIds.isEmpty) return;
    final removed = invalidation.removedSourceIds
        .where(
          (id) => repository.isSourceRemoved(
            'external:$id',
            owner: invalidation.accountId,
          ),
        )
        .toSet();
    if (removed.isEmpty) return;
    bool discard(_Note note) =>
        note.clientEventId?.startsWith('external:') == true &&
        note.calendarId?.startsWith('external:') == true &&
        removed.contains(note.calendarId!.substring('external:'.length));
    Map<String, List<_Note>> filtered(Map<String, List<_Note>> notes) => {
      for (final entry in notes.entries)
        if (entry.value.any((note) => !discard(note)))
          entry.key: entry.value.where((note) => !discard(note)).toList(),
    };

    // An older viewport has higher priority than an event invalidation. Retire
    // its token before it can restore a source removed by acknowledged consent.
    _hydrationScheduler.invalidateAll(reason: 'external_source_removed');
    _warmStartCacheDebounceTimer?.cancel();
    _warmStartCacheDebounceTimer = null;
    final authoritative = filtered(_calendarHydrationBaseNotes);
    _calendarAuthoritativeNotesByDay = Map.unmodifiable(authoritative);
    final pending = _calendarPresentationCoordinator.pending?.projection;
    final visible = filtered(pending?.notesByDay ?? _notes);
    final flows = pending?.flows ?? _calendarHydrationBaseFlows;
    final affected = _calendarAffectedMonths(visible, flows);
    final extentAffecting = _calendarProjectionChangesExtent(visible, affected);
    final geometry = _calendarGeometryRevision(visible, affected);
    final sequence = ++_calendarPresentationSequence;
    _calendarPresentationCoordinator.publish(
      CalendarPresentationEpoch(
        userScope: invalidation.accountId,
        sequence: sequence,
        viewRevision: 'external_source_removal:$sequence',
        geometryRevision: geometry,
        extentAffecting: extentAffecting,
        affectedSections: affected.map(
          (month) => '${month.year}-${month.month}',
        ),
        projection: _CalendarHydrationProjection(
          flows: flows,
          notesByDay: visible,
          reminderRules: const [],
          replaceReminderRules: false,
          nextFlowId: _nextFlowId,
          authorityScope: _hydrationAuthorityScope,
          authorityReason: 'external_source_removed',
          commitIsServerCurrent: false,
          coverage: _hydrationController.state.coverage,
          lastSuccessfulRefreshAtUtc:
              _lastAuthoritativeHydrationAt?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          fullServerHydration: false,
          clearWarmSnapshot: false,
          affectedMonths: affected,
          extentAffecting: extentAffecting,
        ),
      ),
    );
    // Already prepared writes may still finish. Queue the final prune after
    // BOTH tails so neither mirror can resurrect removed rows. Disposable
    // storage must not hold up the live refresh or a later source reselect.
    unawaited(
      Future.wait<void>([
        _calendarSnapshotWriteTail,
        _warmStartCacheWriteTail,
      ]).then((_) async {
        if (repository.accountId != invalidation.accountId ||
            repository.lane != invalidation.lane) {
          return;
        }
        await repository.pruneRemovedSources(invalidation.accountId, removed);
      }),
    );
  }
}
