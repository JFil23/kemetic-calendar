part of '../calendar_page.dart';

extension _CalendarSnapshotPageAdapter on CalendarPageState {
  Future<void> _deleteCalendarSnapshotForAccountChange(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return;
    try {
      await calendarSnapshotStore.deleteUserScope(normalized);
      CalendarHydrationDiagnostics.instance.recordCacheEvent(
        'snapshot_account_scope_deleted',
        const <String, Object?>{},
      );
    } catch (error) {
      // The store writes a quarantine marker before deleting. A failed delete
      // therefore remains unreadable and can be retried without exposing data.
      CalendarHydrationDiagnostics.instance.recordCacheEvent(
        'snapshot_account_scope_quarantined',
        <String, Object?>{'safe_error_class': error.runtimeType.toString()},
      );
    }
  }

  Future<bool> _restoreCalendarSnapshotStoreIfAvailable({
    required String userId,
    required String reason,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;
    final started = Stopwatch()..start();
    final projectionRevisionAtStart = _calendarProjectionMutationRevision;
    try {
      final snapshot = await calendarSnapshotStore.readLatest(normalizedUserId);
      if (snapshot == null ||
          !mounted ||
          _activeWarmStartUserId() != normalizedUserId ||
          _serverHydrationCommittedForUserId == normalizedUserId) {
        return false;
      }

      // During migration the old durable overlay stores remain mirrors. Read
      // them before presentation and compose them into the same first paint;
      // never show the server snapshot and patch pending records afterward.
      final mirroredPending = await _pendingNoteStore.readForUser(
        normalizedUserId,
      );
      var mirroredTombstones = <String>{};
      try {
        final prefs = await SharedPreferences.getInstance();
        mirroredTombstones =
            (await CalendarUserScopedPrefs.readStringList(
                  prefs: prefs,
                  userId: normalizedUserId,
                  userKey: CalendarUserScopedPrefs.manualDeleteTombstonesKey,
                  legacyKey:
                      CalendarUserScopedPrefs.legacyManualDeleteTombstonesKey,
                ))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toSet();
      } catch (_) {
        // The snapshot overlay remains authoritative if a legacy mirror is
        // unavailable. Mirror failure cannot suppress a complete generation.
      }
      if (!mounted || _activeWarmStartUserId() != normalizedUserId) {
        return false;
      }

      final flows = snapshot.flows
          .map(_deserializeWarmStartFlow)
          .whereType<_Flow>()
          .toList(growable: false);
      final trackSkyFlowIds = flows
          .where((flow) => _isTrackSkyFlowName(flow.name))
          .map((flow) => flow.id)
          .where((flowId) => flowId > 0)
          .toSet();
      final notesByDay = <String, List<_Note>>{};
      for (final entry in snapshot.eventsByDay.entries) {
        final notes = _dedupeVisibleDayNotes(
          entry.value
              .map(_deserializeWarmStartNote)
              .whereType<_Note>()
              .toList(growable: true),
          trackSkyFlowIds: trackSkyFlowIds,
        );
        if (notes.isNotEmpty) notesByDay[entry.key] = notes;
      }
      final authoritativeNotesByDay =
          Map<String, List<_Note>>.unmodifiable(<String, List<_Note>>{
            for (final entry in notesByDay.entries)
              entry.key: List<_Note>.unmodifiable(entry.value),
          });

      final restoredTombstones = <String>{};
      final restoredPending = <_UnconfirmedNote>[];
      for (final record in snapshot.overlayRecords) {
        final kind = record['kind']?.toString();
        if (kind == 'delete_tombstone') {
          final identity = record['identity']?.toString().trim();
          if (identity != null && identity.isNotEmpty) {
            restoredTombstones.add(identity);
          }
          continue;
        }
        if (kind != 'create_or_edit' || record['note'] is! Map) continue;
        final dayKey = record['dayKey']?.toString().trim();
        final cid = record['clientEventId']?.toString().trim();
        final note = _deserializeWarmStartNote(record['note']);
        if (dayKey == null ||
            dayKey.isEmpty ||
            cid == null ||
            cid.isEmpty ||
            note == null ||
            note.clientEventId?.trim() != cid) {
          continue;
        }
        notesByDay.removeWhere((_, notes) {
          notes.removeWhere(
            (candidate) => candidate.clientEventId?.trim() == cid,
          );
          return notes.isEmpty;
        });
        notesByDay.putIfAbsent(dayKey, () => <_Note>[]).add(note);
        restoredPending.add(
          _UnconfirmedNote(
            dayKey: dayKey,
            note: note,
            createdAt:
                DateTime.tryParse(
                  record['createdAtUtc']?.toString() ?? '',
                )?.toUtc() ??
                snapshot.committedAtUtc,
          ),
        );
      }
      for (final record in mirroredPending) {
        final note = _deserializeWarmStartNote(record.notePayload);
        if (note == null ||
            note.clientEventId?.trim() != record.clientEventId.trim()) {
          continue;
        }
        final cid = record.clientEventId.trim();
        notesByDay.removeWhere((_, notes) {
          notes.removeWhere(
            (candidate) => candidate.clientEventId?.trim() == cid,
          );
          return notes.isEmpty;
        });
        notesByDay.putIfAbsent(record.dayKey, () => <_Note>[]).add(note);
        restoredPending.removeWhere(
          (entry) => entry.note.clientEventId?.trim() == cid,
        );
        restoredPending.add(
          _UnconfirmedNote(
            dayKey: record.dayKey,
            note: note,
            createdAt: record.createdAt,
          ),
        );
      }
      restoredTombstones.addAll(mirroredTombstones);
      if (restoredTombstones.isNotEmpty) {
        notesByDay.removeWhere((_, notes) {
          notes.removeWhere(
            (note) =>
                restoredTombstones.contains(note.clientEventId?.trim() ?? ''),
          );
          return notes.isEmpty;
        });
        restoredPending.removeWhere(
          (entry) => restoredTombstones.contains(
            entry.note.clientEventId?.trim() ?? '',
          ),
        );
      }

      final calendarsById = <String, SharedCalendarSummary>{};
      final calendarsRaw = snapshot.calendarMetadata['calendars'];
      if (calendarsRaw is List) {
        for (final raw in calendarsRaw.whereType<Map>()) {
          final calendar = SharedCalendarSummary.fromRow(
            Map<String, dynamic>.from(raw),
          );
          if (calendar.id.trim().isNotEmpty) {
            calendarsById[calendar.id] = calendar;
          }
        }
      }
      final hiddenCalendarIds = <String>{
        for (final value
            in (snapshot.calendarMetadata['hiddenCalendarIds'] as List? ??
                const <Object?>[]))
          if (value.toString().trim().isNotEmpty) value.toString().trim(),
      };
      final personalCalendarId = snapshot.calendarMetadata['personalCalendarId']
          ?.toString()
          .trim();

      if (_calendarProjectionMutationRevision != projectionRevisionAtStart) {
        CalendarHydrationDiagnostics.instance.recordCacheEvent(
          'snapshot_restore_superseded',
          <String, Object?>{
            'request_reason': reason,
            'duration_ms': started.elapsedMilliseconds,
          },
        );
        // A newer local/server projection already owns the page. Treat the
        // restore request as handled so the lossy legacy fallback cannot
        // overwrite that newer projection.
        return true;
      }

      _projectReminderMembershipForHydration(
        flows: flows,
        notesByDay: notesByDay,
      );
      final affectedMonths = _calendarAffectedMonths(notesByDay, flows);
      _hydrationController.beginSession(normalizedUserId);
      _hydrationController.restoreCache(
        catalogFingerprint: snapshot.catalogFingerprint,
        coverageIntervals: snapshot.coverage
            .map(
              (interval) => CalendarHydrationInterval(
                startUtc: interval.startUtc,
                endUtc: interval.endUtc,
              ),
            )
            .toList(growable: false),
        applyPreparedState: () {
          _flows
            ..clear()
            ..addAll(flows);
          _notes
            ..clear()
            ..addAll(notesByDay);
          _calendarAuthoritativeFlows = List<_Flow>.unmodifiable(flows);
          _calendarAuthoritativeNotesByDay = authoritativeNotesByDay;
          _flowTotalEventCounts.clear();
          _flowRemainingEventCounts.clear();
          _calendarSummariesById = calendarsById;
          _hiddenCalendarIds = hiddenCalendarIds;
          _personalCalendarId =
              personalCalendarId == null || personalCalendarId.isEmpty
              ? null
              : personalCalendarId;
          _calendarStateLoaded = calendarsRaw is List;
          if (flows.isNotEmpty) {
            _nextFlowId = math.max(
              _nextFlowId,
              flows.map((flow) => flow.id).reduce(math.max) + 1,
            );
          }
          _unconfirmed
            ..clear()
            ..restore(restoredPending);
          _manualDeleteTombstones
            ..clear()
            ..addAll(restoredTombstones);
          _manualTombstonesLoaded = true;
          _rebuildReminderRulesFromFlowsIfMissing();
          _publishCalendarMonthProjections(affectedMonths);
        },
      );
      _activeCalendarCoverage = _hydrationController.state.coverage;
      _latestCalendarRefreshStatus = CalendarRefreshStatus.idle;
      _pendingNotesRestoredForUserId = normalizedUserId;
      _warmStartCacheRestoredForUserId = normalizedUserId;
      _warmStartSnapshotVisible = true;
      _lastAuthoritativeHydrationAt = snapshot.lastSuccessfulRefreshAtUtc
          .toLocal();
      _accountingStale = true;
      _publishHydrationStatus();
      _notifyDayViewDataChanged(scheduleCacheSave: false);

      final restoredEventCount = notesByDay.values.fold<int>(
        0,
        (sum, notes) => sum + notes.length,
      );
      CalendarHydrationDiagnostics.instance.recordCacheEvent(
        'snapshot_restore_hit',
        <String, Object?>{
          'request_reason': reason,
          'generation': snapshot.generation,
          'recovered_previous_generation': snapshot.recoveredPreviousGeneration,
          'cached_flow_count': flows.length,
          'cached_event_count': restoredEventCount,
          'cached_day_bucket_count': notesByDay.length,
          'coverage_interval_count': snapshot.coverage.length,
          'overlay_record_count': snapshot.overlayRecords.length,
          'duration_ms': started.elapsedMilliseconds,
        },
      );
      CalendarHydrationDiagnostics.instance.recordWarmCacheCommit(
        totalFlows: flows.length,
        totalEvents: restoredEventCount,
        totalDayBuckets: notesByDay.length,
        selectedDay: _hydrationSelectedDaySnapshot(notesByDay),
      );
      return true;
    } catch (error) {
      CalendarHydrationDiagnostics.instance
          .recordCacheEvent('snapshot_restore_failed', <String, Object?>{
            'request_reason': reason,
            'safe_error_class': error.runtimeType.toString(),
            'duration_ms': started.elapsedMilliseconds,
          });
      if (kDebugMode) {
        _calendarDebugPrint(
          '[calendarSnapshot] restore failed class=${error.runtimeType}',
        );
      }
      return false;
    }
  }

  Future<
    ({CalendarSnapshotCommit commit, CalendarSnapshotCommitResult result})?
  >
  _commitCalendarSnapshotCandidate({
    required String userId,
    required String reason,
    required List<_Flow> flows,
    required Map<String, List<_Note>> notesByDay,
    required Iterable<CalendarHydrationInterval> coverage,
    required String catalogFingerprint,
    required DateTime lastSuccessfulRefreshAtUtc,
    Iterable<String> confirmedOverlayCids = const <String>[],
  }) {
    final baseCommit = _buildCalendarSnapshotCommit(
      userId: userId,
      reason: reason,
      flows: flows,
      notesByDay: notesByDay,
      coverage: coverage,
      catalogFingerprint: catalogFingerprint,
      lastSuccessfulRefreshAtUtc: lastSuccessfulRefreshAtUtc,
      confirmedOverlayCids: confirmedOverlayCids,
    );
    final operation = _calendarSnapshotWriteTail.then((_) async {
      final normalizedUserId = userId.trim();
      if (!mounted || _activeWarmStartUserId() != normalizedUserId) {
        return null;
      }
      try {
        final existing = await calendarSnapshotStore.readLatest(
          normalizedUserId,
        );
        if (!mounted || _activeWarmStartUserId() != normalizedUserId) {
          return null;
        }
        final overlayRows = _mergeCalendarOverlayRows(
          durableRows: existing?.overlayRecords ?? const [],
          localRows: baseCommit.overlayRecords,
          removeCreateCids: confirmedOverlayCids.toSet(),
        );
        final commit = _calendarSnapshotCommitWithOverlay(
          baseCommit,
          overlayRows,
        );
        final result = await calendarSnapshotStore.commit(
          commit,
          expectedGeneration: existing?.generation,
          requireGenerationMatch: true,
        );
        if (!mounted || _activeWarmStartUserId() != normalizedUserId) {
          return null;
        }
        final durable = await calendarSnapshotStore.readLatest(
          normalizedUserId,
        );
        if (durable == null ||
            durable.generation != result.generation ||
            durable.canonicalDigest != commit.canonicalDigest) {
          _lastCalendarSnapshotShadowOutcome = 'candidate_parity_failed';
          return null;
        }
        _lastCalendarSnapshotShadowOutcome = 'candidate_committed';
        return (commit: commit, result: result);
      } on CalendarSnapshotConflict {
        _lastCalendarSnapshotShadowOutcome = 'candidate_conflict';
        return null;
      } catch (error) {
        _lastCalendarSnapshotShadowOutcome = 'candidate_failed';
        CalendarHydrationDiagnostics.instance
            .recordCacheEvent('snapshot_candidate_failed', <String, Object?>{
              'request_reason': reason,
              'safe_error_class': error.runtimeType.toString(),
            });
        return null;
      }
    });
    _calendarSnapshotWriteTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<bool> _commitCalendarOverlayState({
    required String userId,
    required String reason,
    Iterable<Map<String, Object?>> additionalRecords = const [],
    Set<String> removeCreateCids = const <String>{},
    Set<String> removeTombstoneIdentities = const <String>{},
  }) {
    final operation = _calendarSnapshotWriteTail.then((_) async {
      final normalizedUserId = userId.trim();
      if (!mounted ||
          normalizedUserId.isEmpty ||
          _activeWarmStartUserId() != normalizedUserId) {
        return false;
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final existing = await calendarSnapshotStore.readLatest(
            normalizedUserId,
          );
          if (!mounted || _activeWarmStartUserId() != normalizedUserId) {
            return false;
          }
          final localRows = _calendarOverlayRows(
            additionalRecords: additionalRecords,
          );
          final overlayRows = _mergeCalendarOverlayRows(
            durableRows: existing?.overlayRecords ?? const [],
            localRows: localRows,
            removeCreateCids: removeCreateCids,
            removeTombstoneIdentities: removeTombstoneIdentities,
          );
          final base = existing == null
              ? _emptyCalendarSnapshotCommit(
                  userId: normalizedUserId,
                  reason: reason,
                )
              : CalendarSnapshotCommit(
                  userScope: normalizedUserId,
                  serverRevision: existing.serverRevision,
                  overlayRevision: existing.overlayRevision,
                  catalogFingerprint: existing.catalogFingerprint,
                  origin: reason,
                  committedAtUtc: DateTime.now().toUtc(),
                  lastSuccessfulRefreshAtUtc:
                      existing.lastSuccessfulRefreshAtUtc,
                  coverage: existing.coverage,
                  eventsByDay: existing.eventsByDay,
                  flows: existing.flows,
                  calendarMetadata: existing.calendarMetadata,
                  overlayRecords: existing.overlayRecords,
                );
          final commit = _calendarSnapshotCommitWithOverlay(base, overlayRows);
          final result = await calendarSnapshotStore.commit(
            commit,
            expectedGeneration: existing?.generation,
            requireGenerationMatch: true,
          );
          final durable = await calendarSnapshotStore.readLatest(
            normalizedUserId,
          );
          if (durable == null ||
              durable.generation != result.generation ||
              durable.canonicalDigest != commit.canonicalDigest) {
            return false;
          }
          return true;
        } on CalendarSnapshotConflict {
          if (attempt == 1) return false;
        } catch (error) {
          CalendarHydrationDiagnostics.instance.recordCacheEvent(
            'snapshot_overlay_commit_failed',
            <String, Object?>{
              'request_reason': reason,
              'safe_error_class': error.runtimeType.toString(),
            },
          );
          return false;
        }
      }
      return false;
    });
    _calendarSnapshotWriteTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  CalendarSnapshotCommit _emptyCalendarSnapshotCommit({
    required String userId,
    required String reason,
  }) => CalendarSnapshotCommit(
    userScope: userId,
    serverRevision: calendarSnapshotDigest(
      calendarCanonicalJson(const <String, Object?>{}),
    ),
    overlayRevision: calendarSnapshotDigest('[]'),
    catalogFingerprint: _catalogFingerprintForCurrentFlows(),
    origin: reason,
    committedAtUtc: DateTime.now().toUtc(),
    lastSuccessfulRefreshAtUtc: DateTime.fromMillisecondsSinceEpoch(
      0,
      isUtc: true,
    ),
    coverage: const <CalendarSnapshotCoverageInterval>[],
    eventsByDay: const <String, List<Map<String, Object?>>>{},
    flows: const <Map<String, Object?>>[],
    calendarMetadata: const <String, Object?>{
      'personalCalendarId': null,
      'hiddenCalendarIds': <String>[],
      'calendars': <Object?>[],
    },
  );

  CalendarSnapshotCommit _calendarSnapshotCommitWithOverlay(
    CalendarSnapshotCommit base,
    List<Map<String, Object?>> overlayRows,
  ) => CalendarSnapshotCommit(
    userScope: base.userScope,
    serverRevision: base.serverRevision,
    overlayRevision: calendarSnapshotDigest(calendarCanonicalJson(overlayRows)),
    catalogFingerprint: base.catalogFingerprint,
    origin: base.origin,
    committedAtUtc: base.committedAtUtc,
    lastSuccessfulRefreshAtUtc: base.lastSuccessfulRefreshAtUtc,
    coverage: base.coverage,
    eventsByDay: base.eventsByDay,
    flows: base.flows,
    calendarMetadata: base.calendarMetadata,
    overlayRecords: overlayRows,
  );

  List<Map<String, Object?>> _mergeCalendarOverlayRows({
    required Iterable<Map<String, Object?>> durableRows,
    required Iterable<Map<String, Object?>> localRows,
    Set<String> removeCreateCids = const <String>{},
    Set<String> removeTombstoneIdentities = const <String>{},
  }) {
    final rows = <String, Map<String, Object?>>{};
    String? keyFor(Map<String, Object?> row) {
      final kind = row['kind']?.toString();
      final identity = kind == 'delete_tombstone'
          ? row['identity']?.toString().trim()
          : row['clientEventId']?.toString().trim();
      if (kind == null || identity == null || identity.isEmpty) return null;
      return '$kind:$identity';
    }

    for (final row in <Map<String, Object?>>[...durableRows, ...localRows]) {
      final key = keyFor(row);
      if (key != null) rows[key] = Map<String, Object?>.from(row);
    }
    for (final cid in removeCreateCids) {
      rows.remove('create_or_edit:${cid.trim()}');
    }
    for (final identity in removeTombstoneIdentities) {
      rows.remove('delete_tombstone:${identity.trim()}');
    }
    for (final entry in rows.entries.toList(growable: false)) {
      if (!entry.key.startsWith('delete_tombstone:')) continue;
      rows.remove(
        'create_or_edit:${entry.key.substring('delete_tombstone:'.length)}',
      );
    }
    final merged = rows.values.toList(growable: false)
      ..sort(
        (a, b) => calendarCanonicalJson(a).compareTo(calendarCanonicalJson(b)),
      );
    return merged;
  }

  CalendarSnapshotCommit _buildCalendarSnapshotCommit({
    required String userId,
    required String reason,
    required Iterable<_Flow> flows,
    required Map<String, List<_Note>> notesByDay,
    required Iterable<CalendarHydrationInterval> coverage,
    required String catalogFingerprint,
    required DateTime lastSuccessfulRefreshAtUtc,
    Iterable<String> confirmedOverlayCids = const <String>[],
  }) {
    final confirmedCids = confirmedOverlayCids
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final unconfirmedCids = <String>{
      for (final entry in _unconfirmed.entries)
        if ((entry.note.clientEventId ?? '').trim().isNotEmpty &&
            !confirmedCids.contains(entry.note.clientEventId!.trim()))
          entry.note.clientEventId!.trim(),
    };
    final serverEvents = <String, List<Map<String, Object?>>>{};
    for (final entry in notesByDay.entries) {
      final rows = entry.value
          .where(
            (note) =>
                !unconfirmedCids.contains(note.clientEventId?.trim() ?? ''),
          )
          .map(
            (note) => Map<String, Object?>.from(_serializeWarmStartNote(note)),
          )
          .toList(growable: false);
      if (rows.isNotEmpty) serverEvents[entry.key] = rows;
    }
    final flowRows = flows
        .map((flow) => Map<String, Object?>.from(_serializeWarmStartFlow(flow)))
        .toList(growable: false);
    final overlayRows = _calendarOverlayRows(confirmedCids: confirmedCids);
    final snapshotCoverage = <CalendarSnapshotCoverageInterval>[
      for (final interval in coverage)
        CalendarSnapshotCoverageInterval(
          startUtc: interval.startUtc,
          endUtc: interval.endUtc,
        ),
    ];
    final calendarMetadata = <String, Object?>{
      'personalCalendarId': _personalCalendarId,
      'hiddenCalendarIds': _hiddenCalendarIds.toList(growable: false)..sort(),
      'calendars': _calendarSummariesById.values
          .map((calendar) => calendar.toCacheJson())
          .toList(growable: false),
    };
    final serverRevision = calendarSnapshotDigest(
      calendarCanonicalJson(<String, Object?>{
        'catalogFingerprint': catalogFingerprint,
        'coverage': snapshotCoverage.map((value) => value.toJson()).toList(),
        'eventsByDay': serverEvents,
        'flows': flowRows,
        'calendarMetadata': calendarMetadata,
      }),
    );
    final overlayRevision = calendarSnapshotDigest(
      calendarCanonicalJson(overlayRows),
    );
    return CalendarSnapshotCommit(
      userScope: userId,
      serverRevision: serverRevision,
      overlayRevision: overlayRevision,
      catalogFingerprint: catalogFingerprint,
      origin: reason,
      committedAtUtc: DateTime.now().toUtc(),
      lastSuccessfulRefreshAtUtc: lastSuccessfulRefreshAtUtc,
      coverage: snapshotCoverage,
      eventsByDay: serverEvents,
      flows: flowRows,
      calendarMetadata: calendarMetadata,
      overlayRecords: overlayRows,
    );
  }

  List<Map<String, Object?>> _calendarOverlayRows({
    Set<String> confirmedCids = const <String>{},
    Iterable<Map<String, Object?>> additionalRecords = const [],
  }) {
    final rowsByIdentity = <String, Map<String, Object?>>{};
    void add(Map<String, Object?> row) {
      final kind = row['kind']?.toString();
      final identity = kind == 'delete_tombstone'
          ? row['identity']?.toString().trim()
          : row['clientEventId']?.toString().trim();
      if (kind == null || identity == null || identity.isEmpty) return;
      rowsByIdentity['$kind:$identity'] = Map<String, Object?>.from(row);
    }

    for (final entry in _unconfirmed.entries) {
      final cid = entry.note.clientEventId?.trim() ?? '';
      if (cid.isEmpty || confirmedCids.contains(cid)) continue;
      add(<String, Object?>{
        'kind': 'create_or_edit',
        'dayKey': entry.dayKey,
        'clientEventId': cid,
        'createdAtUtc': entry.createdAt.toUtc().toIso8601String(),
        'note': _serializeWarmStartNote(entry.note),
      });
    }
    for (final tombstone in _manualDeleteTombstones) {
      add(<String, Object?>{'kind': 'delete_tombstone', 'identity': tombstone});
    }
    for (final row in additionalRecords) {
      add(row);
    }
    final rows = rowsByIdentity.values.toList(growable: false)
      ..sort(
        (a, b) => calendarCanonicalJson(a).compareTo(calendarCanonicalJson(b)),
      );
    return rows;
  }
}
