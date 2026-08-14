part of '../calendar_page.dart';

extension _CalendarHydrationEngine on CalendarPageState {
  Future<CalendarHydrationJobDisposition> _requestHydration(
    _CalendarHydrationRequest request,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !mounted) {
      return CalendarHydrationJobDisposition.cancelled;
    }
    _hydrationController.beginSession(user.id);
    final fallbackWindow = _computeStartupVisibleHydrationInterval();
    final interval = request.interval ?? fallbackWindow;
    if (request.isForeground ||
        request.mode == _CalendarHydrationMode.catalogReconcile) {
      _hydrationController.reportViewport(interval);
    }
    _latestCalendarRefreshStatus = CalendarRefreshStatus.pending;
    _publishCalendarRefreshState();
    final fingerprint =
        request.catalogFingerprint ??
        _hydrationController.state.catalogFingerprint ??
        _catalogFingerprintForCurrentFlows();
    final passEpoch = ++_hydrationPassEpoch;
    final diagnostics = CalendarHydrationDiagnostics.instance;
    diagnostics.recordCoordinatorRequest(
      source: request.diagnosticSource,
      passActive: _hydrationScheduler.hasActiveJob,
    );
    final job = CalendarHydrationJob(
      key: request.jobKey(
        resolvedInterval: interval,
        resolvedFingerprint: fingerprint,
      ),
      priority: request.priority,
      retryPolicy:
          request.isForeground ||
              request.mode == _CalendarHydrationMode.backgroundWindow
          ? const CalendarHydrationRetryPolicy(maxAttempts: 2)
          : CalendarHydrationRetryPolicy.none,
      run: (jobContext) async {
        diagnostics.recordCoordinatorPassStarted();
        CalendarHydrationCatalogSnapshot? stagedCatalog;
        if (request.mode == _CalendarHydrationMode.catalogReconcile) {
          final catalogStopwatch = Stopwatch()..start();
          stagedCatalog = await CalendarHydrationRepository.fromUserEventsRepo(
            UserEventsRepo(Supabase.instance.client),
          ).fetchCatalog();
          jobContext.throwIfCancelled('after_catalog_fetch');
          diagnostics.recordPostProcessing(
            null,
            'catalog_reconcile_fetch',
            durationMs: catalogStopwatch.elapsedMilliseconds,
            fields: <String, Object?>{
              'row_count': stagedCatalog.entries.length,
              'fingerprint': stagedCatalog.fingerprint,
            },
          );
          final currentState = _hydrationController.state;
          final alreadyCovered =
              currentState.catalogFingerprint == stagedCatalog.fingerprint &&
              currentState.coverage.covers(interval);
          if (alreadyCovered &&
              _hydrationController.promoteMatchingFreshCatalog(
                stagedCatalog.fingerprint,
              )) {
            _activeCalendarCoverage = _hydrationController.state.coverage;
            _lastAuthoritativeHydrationAt = DateTime.now();
            _latestCalendarRefreshStatus = CalendarRefreshStatus.succeeded;
            _publishCalendarRefreshState();
            diagnostics.recordPostProcessing(
              null,
              'catalog_reconcile_promoted_without_lane_refetch',
              fields: <String, Object?>{
                'fingerprint': stagedCatalog.fingerprint,
              },
            );
            unawaited(
              _persistWarmStartCacheBestEffort(
                userId: user.id,
                debugReason: 'hydration_viewport_server_current',
                allowServerCurrentViewport: true,
              ),
            );
            return;
          }
        }
        final viewportCommitToken =
            request.mode == _CalendarHydrationMode.backgroundWindow
            ? null
            : _hydrationController.beginViewportCommit(
                catalogFingerprint: stagedCatalog?.fingerprint ?? fingerprint,
                catalogIsFresh:
                    request.mode == _CalendarHydrationMode.catalogReconcile,
              );
        await _executeHydrationRequest(
          request: request,
          resolvedInterval: interval,
          resolvedCatalogFingerprint: fingerprint,
          stagedCatalog: stagedCatalog,
          viewportCommitToken: viewportCommitToken,
          sessionGeneration: _hydrationController.state.sessionGeneration,
          jobContext: jobContext,
          passEpoch: passEpoch,
        );
        jobContext.throwIfCancelled('before_controller_commit');
        if (request.mode == _CalendarHydrationMode.backgroundWindow) {
          if (request.isFinalChunk) {
            unawaited(() async {
              await _persistWarmStartCacheBestEffort(
                userId: user.id,
                debugReason: 'hydration_horizon_complete',
              );
              await CalendarHydrationDiagnostics.instance.finishBackfillSummary(
                userId: user.id,
                fullHorizonComplete:
                    _hydrationController.state.authority ==
                    CalendarViewportAuthority.fullHorizon,
                cacheSaveEnded: _lastWarmStartCacheSaveOutcome != null,
                cacheSaveOutcome: _lastWarmStartCacheSaveOutcome,
              );
            }());
          }
        } else if (request.mode == _CalendarHydrationMode.catalogReconcile &&
            _hydrationController.state.authority ==
                CalendarViewportAuthority.serverCurrent) {
          // Heal the launch cache as soon as the exact viewport and fresh
          // catalog are atomically authoritative. Full-horizon persistence
          // still replaces this checkpoint after all background chunks land.
          unawaited(
            _persistWarmStartCacheBestEffort(
              userId: user.id,
              debugReason: 'hydration_viewport_server_current',
              allowServerCurrentViewport: true,
            ),
          );
        }
      },
    );
    final disposition = await _hydrationScheduler.schedule(
      job,
      supersedeKind: request.intentKind == CalendarHydrationIntentKind.viewport,
      preemptLowerPriority:
          request.isForeground ||
          request.mode == _CalendarHydrationMode.catalogReconcile,
    );
    if (!_hydrationScheduler.hasActiveJob &&
        !_hydrationScheduler.hasQueuedJobs) {
      diagnostics.recordCoordinatorIdle();
      if (disposition == CalendarHydrationJobDisposition.failed) {
        _recordCalendarRefreshFailure();
      } else if (disposition == CalendarHydrationJobDisposition.cancelled &&
          _latestCalendarRefreshStatus == CalendarRefreshStatus.pending) {
        _latestCalendarRefreshStatus = CalendarRefreshStatus.idle;
        _publishCalendarRefreshState();
      }
    }
    return disposition;
  }

  Future<_CalendarHydrationPassResult> _executeHydrationRequest({
    required _CalendarHydrationRequest request,
    required CalendarHydrationInterval resolvedInterval,
    required String resolvedCatalogFingerprint,
    CalendarHydrationCatalogSnapshot? stagedCatalog,
    required CalendarHydrationCommitToken? viewportCommitToken,
    required int sessionGeneration,
    required CalendarHydrationJobContext jobContext,
    required int passEpoch,
  }) async {
    final source = request.diagnosticSource;
    final hydrationDiagnostics = CalendarHydrationDiagnostics.instance;
    final hydrationContext = hydrationDiagnostics.beginPass(
      epoch: passEpoch,
      requestedSource: source,
      executedSource: source,
    );
    var hydrationPassSucceeded = false;
    var hydrationPassSuperseded = false;
    final flowEndRevisionAtLoadStart = CalendarPage._flowEndStateRevision;
    final foregroundMode =
        request.mode == _CalendarHydrationMode.provisionalViewport ||
        request.mode == _CalendarHydrationMode.targetedWindow;
    final backgroundWindowMode =
        request.mode == _CalendarHydrationMode.backgroundWindow;
    final backgroundPass = backgroundWindowMode
        ? (
            window: (
              startUtc: resolvedInterval.startUtc,
              endUtc: resolvedInterval.endUtc,
            ),
            union: (
              startUtc: request.union!.startUtc,
              endUtc: request.union!.endUtc,
            ),
            chunkIndex: request.chunkIndex!,
            chunkCount: request.chunkCount!,
            isFinal: request.isFinalChunk,
          )
        : null;
    var flowHydrationStatus = HydrationFetchStatus.notRun;
    var standaloneHydrationStatus = HydrationFetchStatus.notRun;
    var flowLaneDurationMs = 0;
    var standaloneLaneDurationMs = 0;
    DateTime? flowLaneStartedAtUtc;
    DateTime? flowLaneEndedAtUtc;
    DateTime? standaloneLaneStartedAtUtc;
    DateTime? standaloneLaneEndedAtUtc;
    String? progressiveAbortReason;
    String? loadUserIdForPass;
    var effectiveCatalogFingerprint = resolvedCatalogFingerprint;
    try {
      if (kDebugMode) {
        _calendarDebugPrint('=== hydrationEngine START ($source) ===');
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          _calendarDebugPrint(
            '[hydrationEngine] Skipping request: no authenticated user',
          );
        }
        hydrationDiagnostics.endPass(hydrationContext, succeeded: false);
        throw const _CalendarHydrationLaneUnavailable('unauthenticated');
      }
      final loadUserId = currentUser.id;
      loadUserIdForPass = loadUserId;
      await _ensureManualDeleteTombstonesLoaded();
      if (backgroundWindowMode && backgroundPass == null) {
        throw StateError('Missing progressive backfill window for $source');
      }
      final hasPaintedEventSnapshotAtLoadStart = _hasPaintedEventSnapshot(
        _notes,
      );
      final focusWindow = (
        startUtc: resolvedInterval.startUtc,
        endUtc: resolvedInterval.endUtc,
      );
      final repo = UserEventsRepo(Supabase.instance.client);
      hydrationDiagnostics.recordPostProcessing(
        hydrationContext,
        'authority_scope_pass_started',
        fields: <String, Object?>{
          'authority_scope': _hydrationAuthorityScope.diagnosticName,
        },
      );

      // Flow-first: load flows, then events; join only to known active flows
      final List<_Flow> newFlows = [];
      final Map<String, List<_Note>> newNotes = {};
      int nextFlowId = _nextFlowId;

      // Phase A owns the catalog request. Phase B reuses that exact successful
      // catalog snapshot so each chunk contains only the two hydration lanes.
      final reuseCatalog = request.reusesCatalog;
      final serverFlows = reuseCatalog ? null : stagedCatalog?.entries;
      if (!reuseCatalog && serverFlows == null) {
        throw StateError('Catalog reconciliation requires a staged catalog');
      }
      if (serverFlows != null) {
        effectiveCatalogFingerprint = stagedCatalog!.fingerprint;
      }
      if (reuseCatalog) {
        newFlows.addAll(_calendarHydrationBaseFlows);
        hydrationDiagnostics.recordDerivedFetchStatus(
          context: hydrationContext,
          operation: 'flow_catalog',
          status: newFlows.isEmpty
              ? HydrationFetchStatus.successfulEmpty
              : HydrationFetchStatus.successNonempty,
          rowCount: newFlows.length,
        );
      } else {
        if (kDebugMode) {
          _calendarDebugPrint(
            '[hydrationEngine] catalog rows: ${serverFlows!.length}',
          );
        }
        for (final f in serverFlows!) {
          final suppressedEnd = CalendarPage._isFlowEndSuppressed(f.id);
          if (suppressedEnd && !f.isSaved) {
            continue;
          }
          final repMeta = _decodeRepeatingNoteMetadata(f.notes);
          final derivedHidden =
              f.isHidden ||
              repMeta.detail != null ||
              repMeta.location != null ||
              repMeta.category != null;
          if (kDebugMode && derivedHidden) {
            final fromDb = f.isHidden;
            final fromRepMeta =
                repMeta.detail != null ||
                repMeta.location != null ||
                repMeta.category != null;
            _calendarDebugPrint(
              '[hydrationEngine] hidden flow id=${f.id} '
              'name=<redacted chars=${f.name.length}> '
              'fromDb=$fromDb fromRepMeta=$fromRepMeta',
            );
          }
          final flow = _Flow(
            id: f.id,
            calendarId: f.calendarId,
            name: f.name,
            color: Color(rgbToArgb(f.color)),
            active: suppressedEnd ? false : f.active,
            isSaved: f.isSaved,
            savedAt: f.savedAt,
            rules: _parseRules(f.rules),
            start: f.startDate,
            end: f.endDate,
            notes: f.notes,
            shareId: f.shareId, // NEW: Load share_id
            isHidden: derivedHidden,
            isReminder: f.isReminder,
            reminderUuid: f.reminderUuid,
          );
          newFlows.add(flow);
          // 🔍 DEBUG: Log what color came from database for ALL custom flows
          // Log flows with ID greater than 156 to catch all user-created flows
          if (kDebugMode && f.id > 156) {
            _calendarDebugPrint(
              '[loadFlows] Flow ${f.id} loaded with '
              'name=<redacted chars=${f.name.length}> '
              'color=${f.color} (0x${f.color.toRadixString(16)})',
            );
          }
          if (flow.id >= nextFlowId) nextFlowId = flow.id + 1;
        }
      }

      // Ensure reminder rules are present from loaded reminder flows if they didn't load earlier.
      // (Run after commit to use new flow state.)
      if (kDebugMode) {
        final hiddenCount = newFlows.where((f) => f.isHidden).length;
        final activeCount = newFlows.where((f) => f.active).length;
        final expiredCount = newFlows
            .where(
              (f) =>
                  f.active &&
                  !isFlowScheduleOpenLocally(active: f.active, endDate: f.end),
            )
            .length;
        _calendarDebugPrint(
          '[hydrationEngine] flows: total=${newFlows.length} hidden=$hiddenCount active=$activeCount expired=$expiredCount',
        );
      }

      // Stage reminder rules without mutating live state. Phase A publishes
      // them only in the same synchronous commit as both successful lanes.
      final reminderPrimeStopwatch = Stopwatch()..start();
      final stagedReminderRules = reuseCatalog
          ? List<ReminderRule>.of(_reminderRules)
          : await _stageReminderRulesFromFlows(newFlows);
      hydrationDiagnostics.recordPostProcessing(
        hydrationContext,
        'reminder_rules_staged',
        durationMs: reminderPrimeStopwatch.elapsedMilliseconds,
        fields: <String, Object?>{'flow_count': newFlows.length},
      );

      // Build index/maps for later use
      final Map<int, _Flow> flowIndex = {for (final f in newFlows) f.id: f};
      final flowOwnersById = <int, FlowRecordSnapshot>{
        for (final f in newFlows)
          f.id: FlowRecordSnapshot(
            id: f.id,
            active: f.active,
            isHidden: f.isHidden,
            isReminder: f.isReminder,
            isSaved: f.isSaved,
            notes: f.notes,
          ),
      };

      // Materialized history is wider than live schedule hydration: ended
      // non-saved flows keep their past `user_events`, while saved inactive
      // templates and backend deleted rows stay out of the calendar.
      final hydrationFlowIds = newFlows
          .where((f) {
            return !CalendarPage._isFlowEndSuppressed(f.id) &&
                shouldHydrateMaterializedUserEvents(flowOwnersById[f.id]!);
          })
          .map((f) => f.id)
          .toSet(); // 👈 Set for O(1) contains() lookups
      if (kDebugMode) {
        _calendarDebugPrint(
          '[hydrationEngine] hydration flow ids: ${hydrationFlowIds.length}',
        );
        if (hydrationFlowIds.isNotEmpty) {
          for (final fid in hydrationFlowIds) {
            final flow = flowIndex[fid];
            if (flow == null) continue;
            final rn = _decodeRepeatingNoteMetadata(flow.notes);
            final looksLikeRepeatingNote =
                rn.detail != null || rn.location != null || rn.category != null;
            _calendarDebugPrint(
              '[hydrationEngine] flow id=$fid '
              'name=<redacted chars=${flow.name.length}> '
              'isReminder=${flow.isReminder} hidden=${flow.isHidden} '
              'notesLikeRepeatingNote=$looksLikeRepeatingNote',
            );
          }
        }
      }

      ({DateTime startUtc, DateTime endUtc})? flowWindow;
      if (hydrationFlowIds.isNotEmpty) {
        flowWindow = focusWindow;
        if (kDebugMode) {
          _calendarDebugPrint(
            '[hydrationEngine] flow hydration window '
            '${flowWindow.startUtc.toIso8601String()} → ${flowWindow.endUtc.toIso8601String()}',
          );
        }
      }

      const catalogHydrationComplete = true;
      var flowHydrationComplete = true;
      var standaloneHydrationComplete = false;
      var flowMappingStats = const HydrationBatchMappingStats(
        requestedFlowCount: 0,
        rawRowCount: 0,
        mappedRowCount: 0,
        mappedFlowCount: 0,
        nullFlowIdRowCount: 0,
        outsideRequestedSetRowCount: 0,
      );
      flowHydrationStatus = hydrationFlowIds.isEmpty
          ? HydrationFetchStatus.successfulEmpty
          : HydrationFetchStatus.notRun;

      final hydrationWindow =
          await CalendarHydrationRepository.fromUserEventsRepo(
            repo,
          ).fetchWindow(
            interval: resolvedInterval,
            catalogFingerprint: effectiveCatalogFingerprint,
            flowIds: hydrationFlowIds,
            flowOwnersById: flowOwnersById,
            diagnosticContext: hydrationContext,
            cancellationCheck: jobContext.throwIfCancelled,
          );
      flowLaneStartedAtUtc = hydrationWindow.flowStartedAtUtc;
      flowLaneEndedAtUtc = hydrationWindow.flowEndedAtUtc;
      flowLaneDurationMs = hydrationWindow.flowDurationMs;
      standaloneLaneStartedAtUtc = hydrationWindow.standaloneStartedAtUtc;
      standaloneLaneEndedAtUtc = hydrationWindow.standaloneEndedAtUtc;
      standaloneLaneDurationMs = hydrationWindow.standaloneDurationMs;
      for (final lane in <(String, int)>[
        ('flow', flowLaneDurationMs),
        ('standalone', standaloneLaneDurationMs),
      ]) {
        if (lane.$2 < 4000) continue;
        hydrationDiagnostics.recordPostProcessing(
          hydrationContext,
          'hydration_performance_violation',
          durationMs: lane.$2,
          fields: <String, Object?>{
            'lane': lane.$1,
            'budget_ms': 4000,
            'semantic_result_discarded': false,
          },
        );
      }
      flowHydrationStatus = hydrationWindow.flowEvents.status;
      standaloneHydrationStatus = hydrationWindow.standaloneEvents.status;
      flowHydrationComplete = hydrationWindow.flowEvents.succeeded;
      standaloneHydrationComplete = hydrationWindow.standaloneEvents.succeeded;

      final eventsByFlowId = <int, List<FlowEventRow>>{};
      var mappedRowCount = 0;
      var nullFlowIdRowCount = 0;
      var outsideRequestedSetRowCount = 0;
      for (final event in hydrationWindow.flowEvents.value) {
        final flowId = event.flowLocalId;
        if (flowId == null) {
          nullFlowIdRowCount++;
          continue;
        }
        if (!hydrationFlowIds.contains(flowId)) {
          outsideRequestedSetRowCount++;
          continue;
        }
        mappedRowCount++;
        eventsByFlowId.putIfAbsent(flowId, () => <FlowEventRow>[]).add(event);
      }
      flowMappingStats = HydrationBatchMappingStats(
        requestedFlowCount: hydrationFlowIds.length,
        rawRowCount: hydrationWindow.flowEvents.value.length,
        mappedRowCount: mappedRowCount,
        mappedFlowCount: eventsByFlowId.length,
        nullFlowIdRowCount: nullFlowIdRowCount,
        outsideRequestedSetRowCount: outsideRequestedSetRowCount,
      );
      hydrationDiagnostics.recordBatchMapping(
        context: hydrationContext,
        stats: flowMappingStats,
      );
      if (!hydrationWindow.succeeded) {
        progressiveAbortReason = hydrationWindow.flowEvents.succeeded
            ? 'standalone_lane_failed'
            : 'flow_lane_failed';
        throw _CalendarHydrationLaneUnavailable(progressiveAbortReason);
      }
      final standaloneWindow = focusWindow;
      final standaloneFuture = Future.value(hydrationWindow.standaloneEvents);

      int flowAddedCount = 0;
      int standaloneAddedCount = 0;
      bool committedVisibleCalendar = false;

      Future<void> commitVisibleCalendarState(
        CalendarHydrationPublicationPhase phase, {
        bool loadComplete = false,
        HydrationCompletenessResult? diagnosticCompleteness,
      }) async {
        if (!jobContext.isCurrent ||
            _activeWarmStartUserId() != loadUserId ||
            flowEndRevisionAtLoadStart != CalendarPage._flowEndStateRevision) {
          hydrationPassSuperseded = true;
          progressiveAbortReason = 'authority_changed_before_commit';
          return;
        }
        final commitPrepStopwatch = Stopwatch()..start();
        if (!mounted) return;
        final hasIncomingEventSnapshot = newNotes.values.any(
          (notes) => notes.isNotEmpty,
        );
        if (!shouldPublishVisibleCalendarHydration(
          phase: phase,
          loadComplete: loadComplete,
        )) {
          if (kDebugMode) {
            _calendarDebugPrint(
              '[hydrationEngine] skipped non-complete visible commit '
              'source=$source incomingEvents=$hasIncomingEventSnapshot '
              'paintedEvents=$hasPaintedEventSnapshotAtLoadStart '
              'flowComplete=$flowHydrationComplete '
              'standaloneComplete=$standaloneHydrationComplete',
            );
          }
          return;
        }
        Map<String, List<_Note>> authoritativeCandidateNotes =
            mergeHydrationWindowIntoNotes<_Note>(
              existing: _calendarHydrationBaseNotes,
              incoming: newNotes,
              windowStartInclusive: focusWindow.startUtc,
              windowEndExclusive: focusWindow.endUtc,
              parseKeyToDay: _warmStartDateFromKey,
            );
        if (backgroundWindowMode && backgroundPass!.isFinal) {
          authoritativeCandidateNotes = retainNotesWithinHydrationWindow<_Note>(
            notes: authoritativeCandidateNotes,
            windowStartInclusive: backgroundPass.union.startUtc,
            windowEndExclusive: backgroundPass.union.endUtc,
            parseKeyToDay: _warmStartDateFromKey,
          );
        }
        final candidateNotes = <String, List<_Note>>{
          for (final entry in authoritativeCandidateNotes.entries)
            entry.key: List<_Note>.of(entry.value),
        };
        final unconfirmedMerge = _unconfirmed.mergeInto(
          candidateNotes,
          retireConfirmed: false,
        );
        final hydratedTrackSkyFlowIds = newFlows
            .where((flow) => _isTrackSkyFlowName(flow.name))
            .map((flow) => flow.id)
            .where((flowId) => flowId > 0)
            .toSet();
        final dedupeStopwatch = Stopwatch()..start();
        final dedupedNotes = <String, List<_Note>>{};
        candidateNotes.forEach((key, notes) {
          final cleaned = _dedupeVisibleDayNotes(
            notes,
            trackSkyFlowIds: hydratedTrackSkyFlowIds,
          );
          if (cleaned.isNotEmpty) dedupedNotes[key] = cleaned;
        });
        final authoritativeNotes = <String, List<_Note>>{};
        authoritativeCandidateNotes.forEach((key, notes) {
          final cleaned = _dedupeVisibleDayNotes(
            notes,
            trackSkyFlowIds: hydratedTrackSkyFlowIds,
          );
          if (cleaned.isNotEmpty) authoritativeNotes[key] = cleaned;
        });
        hydrationDiagnostics.recordPostProcessing(
          hydrationContext,
          'visible_snapshot_deduped',
          durationMs: dedupeStopwatch.elapsedMilliseconds,
          fields: <String, Object?>{
            'input_day_bucket_count': candidateNotes.length,
            'output_day_bucket_count': dedupedNotes.length,
          },
        );

        final projectedCoverage = backgroundWindowMode
            ? _hydrationController.previewBackgroundCoverage(
                sessionGeneration: sessionGeneration,
                catalogFingerprint: effectiveCatalogFingerprint,
                interval: resolvedInterval,
              )
            : viewportCommitToken == null
            ? null
            : _hydrationController.previewViewportCoverage(viewportCommitToken);
        if (projectedCoverage == null) {
          hydrationPassSuperseded = true;
          progressiveAbortReason = 'controller_rejected_before_durable_commit';
          return;
        }

        final publishedScope = backgroundWindowMode && backgroundPass!.isFinal
            ? CalendarHydrationAuthorityScope.fullHorizon
            : CalendarHydrationAuthorityScope.visibleWindow;
        final authorityReason = foregroundMode
            ? 'phase_a_complete'
            : backgroundWindowMode
            ? 'phase_b_complete'
            : 'full_refresh_complete';
        final commitIsServerCurrent =
            request.mode == _CalendarHydrationMode.catalogReconcile ||
            effectiveCatalogFingerprint ==
                _hydrationController.state.freshCatalogFingerprint;
        final affectedMonths = _calendarAffectedMonths(dedupedNotes, newFlows);
        final extentAffecting = _calendarProjectionChangesExtent(
          dedupedNotes,
          affectedMonths,
        );
        final geometryRevision = _calendarGeometryRevision(
          dedupedNotes,
          affectedMonths,
        );
        final confirmedOverlayCids = Set<String>.unmodifiable(
          unconfirmedMerge.confirmedCids,
        );
        final successfulRefreshAtUtc = DateTime.now().toUtc();
        final preparedSnapshot = _buildCalendarSnapshotCommit(
          userId: loadUserId,
          reason: 'hydration_${request.diagnosticSource}',
          flows: List<_Flow>.unmodifiable(newFlows),
          notesByDay: authoritativeNotes,
          coverage: projectedCoverage.intervals,
          catalogFingerprint: effectiveCatalogFingerprint,
          lastSuccessfulRefreshAtUtc: successfulRefreshAtUtc,
          confirmedOverlayCids: confirmedOverlayCids,
        );
        if (!mounted ||
            !jobContext.isCurrent ||
            _activeWarmStartUserId() != loadUserId ||
            flowEndRevisionAtLoadStart != CalendarPage._flowEndStateRevision) {
          hydrationPassSuperseded = true;
          progressiveAbortReason = 'authority_changed_before_publication';
          return;
        }

        final projection = _CalendarHydrationProjection(
          flows: List<_Flow>.unmodifiable(newFlows),
          notesByDay: dedupedNotes,
          reminderRules: List<ReminderRule>.unmodifiable(stagedReminderRules),
          replaceReminderRules: !reuseCatalog,
          nextFlowId: nextFlowId,
          authorityScope: publishedScope,
          authorityReason: authorityReason,
          commitIsServerCurrent: commitIsServerCurrent,
          coverage: projectedCoverage,
          lastSuccessfulRefreshAtUtc: successfulRefreshAtUtc,
          fullServerHydration: shouldSetFullServerHydrationSentinel(
            publishedScope,
          ),
          clearWarmSnapshot: shouldClearWarmStartSnapshotVisible(
            publishedScope,
          ),
          affectedMonths: Set<MonthRef>.unmodifiable(affectedMonths),
          extentAffecting: extentAffecting,
        );
        final epoch = CalendarPresentationEpoch<_CalendarHydrationProjection>(
          userScope: loadUserId,
          sequence: ++_calendarPresentationSequence,
          viewRevision:
              '${preparedSnapshot.serverRevision}:${preparedSnapshot.overlayRevision}',
          geometryRevision: geometryRevision,
          extentAffecting: extentAffecting,
          affectedSections: affectedMonths.map(
            (month) => '${month.year}-${month.month}',
          ),
          projection: projection,
        );
        var publishedImmediately = false;
        void applyPreparedState() {
          publishedImmediately = _calendarPresentationCoordinator.publish(
            epoch,
          );
        }

        final accepted = backgroundWindowMode
            ? _hydrationController.commitBackgroundInterval(
                sessionGeneration: sessionGeneration,
                catalogFingerprint: effectiveCatalogFingerprint,
                interval: resolvedInterval,
                applyPreparedState: applyPreparedState,
              )
            : viewportCommitToken != null &&
                  _hydrationController.commitViewport(
                    token: viewportCommitToken,
                    applyPreparedState: applyPreparedState,
                  );
        if (!accepted) {
          progressiveAbortReason = 'controller_rejected_commit';
          hydrationPassSuperseded = true;
          return;
        }
        _calendarAuthoritativeFlows = List<_Flow>.unmodifiable(newFlows);
        _calendarAuthoritativeNotesByDay =
            Map<String, List<_Note>>.unmodifiable(<String, List<_Note>>{
              for (final entry in authoritativeNotes.entries)
                entry.key: List<_Note>.unmodifiable(entry.value),
            });
        committedVisibleCalendar = true;
        if (confirmedOverlayCids.isNotEmpty) {
          _unconfirmed.forgetCids(confirmedOverlayCids);
          unawaited(
            _removePersistedPendingCids(
              confirmedOverlayCids,
              userId: loadUserId,
            ),
          );
        }
        _enqueueCalendarSnapshotPersistence(
          userId: loadUserId,
          reason: 'hydration_${request.diagnosticSource}',
          preparedCommit: preparedSnapshot,
          confirmedOverlayCids: confirmedOverlayCids,
        );
        if (kDebugMode) {
          _calendarDebugPrint(
            '[hydrationEngine] committed epoch phase=${phase.name} '
            'flows=${newFlows.length} notes=${dedupedNotes.length} '
            'immediate=$publishedImmediately '
            'unconfirmedPreserved=${unconfirmedMerge.preserved} '
            'unconfirmedConfirmed=${unconfirmedMerge.confirmed}',
          );
        }
        hydrationDiagnostics.recordVisibleCommit(
          context: hydrationContext,
          phase: phase.name,
          originClass: publishedImmediately
              ? 'server_complete'
              : 'server_complete_staged',
          totalFlows: newFlows.length,
          totalEvents: flowAddedCount + standaloneAddedCount,
          totalDayBuckets: dedupedNotes.length,
          selectedDay: _hydrationSelectedDaySnapshot(dedupedNotes),
          claimedComplete: loadComplete,
          completeness: diagnosticCompleteness,
          authorityScope: publishedScope.diagnosticName,
        );
        hydrationDiagnostics.recordPostProcessing(
          hydrationContext,
          'epoch_publish_and_snapshot_enqueue',
          durationMs: commitPrepStopwatch.elapsedMilliseconds,
          fields: <String, Object?>{
            'phase': phase.name,
            'published_immediately': publishedImmediately,
            'extent_affecting': extentAffecting,
            'affected_month_count': affectedMonths.length,
          },
        );
      }

      final flowConversionStopwatch = Stopwatch()..start();
      for (final flowId in hydrationFlowIds) {
        try {
          final flowEvents = eventsByFlowId[flowId] ?? const <FlowEventRow>[];
          final owningFlow = flowIndex[flowId];
          final isTrackSkyFlow = _isTrackSkyFlowName(owningFlow?.name);

          for (final evt in flowEvents) {
            // Convert DB UTC timestamps -> device local -> Kemetic date
            var localStart = evt.startsAtUtc.toLocal();
            var localEnd = evt.endsAtUtc?.toLocal();
            var allDay = evt.allDay;

            if (isTrackSkyFlow) {
              final normalized = normalizeTrackSkyLocalWindow(
                title: evt.title,
                category: evt.category,
                startLocal: localStart,
                endLocal: localEnd,
                allDay: allDay,
              );
              localStart = normalized.startLocal;
              localEnd = normalized.endLocal;
              allDay = normalized.allDay;
            }

            final kDate = KemeticMath.fromGregorian(localStart);

            // Build _Note, same shape the rest of the app expects
            // 👈 SAFETY NET: Skip events for flows that don't exist or are inactive.
            final ownerSnapshot = flowOwnersById[flowId];
            final flowEligible =
                owningFlow != null &&
                ownerSnapshot != null &&
                shouldHydrateMaterializedUserEvents(ownerSnapshot);
            if (!flowEligible) {
              // Skip backend deleted rows and saved inactive templates.
              continue;
            }

            final startTime = allDay
                ? null
                : TimeOfDay.fromDateTime(localStart);
            final endTime = localEnd == null
                ? null
                : TimeOfDay.fromDateTime(localEnd);
            if ((evt.category ?? '') == 'tombstone') {
              continue;
            }

            final meta = _decodeDetailMetadata(evt.detail);
            final storedCleanDetail = _cleanDetail(meta.detail);
            final canonicalDawnDetail =
                _canonicalDawnHouseRiteDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalTheWeighingDetail =
                _canonicalTheWeighingDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalOfferingTableDetail =
                _canonicalOfferingTableDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalTheTendingDetail =
                _canonicalTheTendingDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalKeptWordDetail =
                _canonicalKeptWordDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalCourseDetail = _canonicalCourseDetailForLoadedEvent(
              flow: owningFlow,
              event: evt,
              localStart: localStart,
            );
            final canonicalWagDetail = _canonicalWagDetailForLoadedEvent(
              flow: owningFlow,
              event: evt,
            );
            final canonicalOpenHandDetail =
                _canonicalOpenHandDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalDjedDetail = _canonicalDjedDetailForLoadedEvent(
              flow: owningFlow,
              event: evt,
            );
            final canonicalReadingHouseDetail =
                _canonicalReadingHouseDetailForLoadedEvent(
                  flow: owningFlow,
                  event: evt,
                );
            final canonicalDetail =
                canonicalDawnDetail ??
                canonicalTheWeighingDetail ??
                canonicalOfferingTableDetail ??
                canonicalTheTendingDetail ??
                canonicalKeptWordDetail ??
                canonicalCourseDetail ??
                canonicalWagDetail ??
                canonicalOpenHandDetail ??
                canonicalDjedDetail ??
                canonicalReadingHouseDetail;
            final cleanedDetail = canonicalDetail ?? storedCleanDetail;
            if (_isTombstoned(evt.clientEventId)) {
              continue;
            }
            if (_isPendingDelete(
              id: evt.id,
              clientEventId: evt.clientEventId,
              kYear: kDate.kYear,
              kMonth: kDate.kMonth,
              kDay: kDate.kDay,
              title: evt.title,
              allDay: allDay,
              start: startTime,
              end: endTime,
              flowId: flowId,
            )) {
              continue;
            }

            final note = _Note(
              id: evt.id,
              clientEventId: evt.clientEventId,
              calendarId: evt.calendarId,
              calendarName: evt.calendarName,
              title: _cleanTitle(evt.title),
              detail: cleanedDetail, // Clean the flowLocalId prefix
              location: evt.location,
              allDay: allDay,
              start: startTime,
              end: endTime,
              flowId: flowId,
              category: evt.category,
              isReminder: owningFlow.isReminder,
              reminderId: owningFlow.isReminder
                  ? owningFlow.reminderUuid
                  : null,
              manualColor: meta.color,
              alertOffsetMinutes: meta.alertMinutes,
              actionId: evt.actionId,
              behaviorPayload: evt.behaviorPayload,
            );

            final key = _kKey(kDate.kYear, kDate.kMonth, kDate.kDay);
            final bucket = newNotes.putIfAbsent(key, () => <_Note>[]);

            final noteStartMinute = note.allDay
                ? null
                : note.start == null
                ? null
                : note.start!.hour * 60 + note.start!.minute;
            final noteEndMinute = note.allDay
                ? null
                : note.end == null
                ? null
                : note.end!.hour * 60 + note.end!.minute;
            final incomingDedupeKey = buildMaterializedFlowEventDedupeKey(
              flowId: flowId,
              allDay: note.allDay,
              eventId: evt.id,
              clientEventId: note.clientEventId,
              title: note.title,
              startMinute: noteStartMinute,
              endMinute: noteEndMinute,
            );
            final already = bucket.any((existing) {
              if ((existing.flowId ?? -1) != flowId) return false;
              final existingStartMinute = existing.allDay
                  ? null
                  : existing.start == null
                  ? null
                  : existing.start!.hour * 60 + existing.start!.minute;
              final existingEndMinute = existing.allDay
                  ? null
                  : existing.end == null
                  ? null
                  : existing.end!.hour * 60 + existing.end!.minute;
              final existingDedupeKey = buildMaterializedFlowEventDedupeKey(
                flowId: flowId,
                allDay: existing.allDay,
                eventId: existing.id,
                clientEventId: existing.clientEventId,
                title: existing.title,
                startMinute: existingStartMinute,
                endMinute: existingEndMinute,
              );
              return existingDedupeKey == incomingDedupeKey;
            });

            if (!already) {
              bucket.add(note);
              flowAddedCount++;
            }
          }
        } catch (err, st) {
          flowHydrationComplete = false;
          if (kDebugMode) {
            _calendarDebugPrint(
              '[hydrationEngine] failed to hydrate events for flow $flowId: $err',
            );
            _calendarDebugPrint('$st');
          }
        }
      }
      hydrationDiagnostics.recordPostProcessing(
        hydrationContext,
        'flow_rows_converted',
        durationMs: flowConversionStopwatch.elapsedMilliseconds,
        fields: <String, Object?>{'added_count': flowAddedCount},
      );

      if (kDebugMode) {
        _calendarDebugPrint(
          '[hydrationEngine] flow notes added: $flowAddedCount',
        );
      }
      if (kDebugMode && flowAddedCount > 0) {
        _calendarDebugPrint(
          '[hydrationEngine] flow events ready internally; '
          'visible publication waits for complete hydration source=$source',
        );
      }

      // Load filing-backed standalone calendar events: notes, reminders, and
      // nutrition rows. Flow rows stay in the flow hydration path above.
      try {
        final standaloneFetchResult = await standaloneFuture;
        standaloneHydrationStatus = standaloneFetchResult.status;
        if (!standaloneFetchResult.succeeded) {
          throw const _CalendarHydrationLaneUnavailable('standalone');
        }
        final standaloneResult = standaloneFetchResult.value;
        final standaloneEvents = standaloneResult.events;
        final ghostStandaloneIds = standaloneResult.ghostEventIds;
        final standaloneConversionStopwatch = Stopwatch()..start();

        // Hydration is read-only. Ghost cleanup belongs to an explicit
        // maintenance intent and must never be hidden inside a viewport read.
        if (ghostStandaloneIds.isNotEmpty && kDebugMode) {
          _calendarDebugPrint(
            '[_hydrate] deferred ${ghostStandaloneIds.length} ghost rows',
          );
        }

        for (final evt in standaloneEvents) {
          try {
            final cid = evt.clientEventId ?? '';
            final rawDetail = evt.detail ?? '';
            final flowDecision = classifyFlowEvent(
              event: FlowEventSnapshot(
                flowLocalId: evt.flowLocalId,
                clientEventId: evt.clientEventId,
                detail: evt.detail,
                category: evt.category,
              ),
              flowOwnersById: flowOwnersById,
            );

            final isReminderBackboneEvent =
                evt.isReminder ||
                cid.startsWith('reminder:') ||
                cid.startsWith('nutrition:');

            // Filing-backed reminder rows may carry their canonical reminder
            // flow id for color/identity. Keep them in the standalone calendar
            // lane while still rejecting non-reminder flow ghosts.
            if (!flowDecision.isStandaloneVisible && !isReminderBackboneEvent) {
              continue;
            }

            // 🚫 HARD GUARD 4b: Reminder instances whose rule no longer exists (or was ended/deleted).
            if (cid.startsWith('reminder:')) {
              final rid = _reminderRuleIdFromCid(cid);
              final exists =
                  rid != null && stagedReminderRules.any((r) => r.id == rid);
              final ended = rid != null && _endedReminderIds.contains(rid);
              if (!exists || ended) {
                continue;
              }
            }

            // ✅ Nutrition: treat as reminder if a matching rule exists
            bool isReminderEvent =
                evt.isReminder || cid.startsWith('reminder:');
            String? reminderRuleId = _reminderRuleIdFromCid(cid);
            if (cid.startsWith('nutrition:')) {
              final parts = cid.split(':');
              if (parts.length >= 3) {
                final itemId = parts.sublist(1, parts.length - 1).join(':');
                final rid = 'nutrition:$itemId';
                final exists =
                    stagedReminderRules.any((r) => r.id == rid) &&
                    !_endedReminderIds.contains(rid);
                if (exists) {
                  isReminderEvent = true;
                  reminderRuleId = rid;
                }
              }
            }

            final positiveFiledFlowId =
                evt.flowLocalId != null && evt.flowLocalId! > 0
                ? evt.flowLocalId
                : null;
            final noteFlowId = isReminderEvent ? positiveFiledFlowId ?? -1 : -1;
            final reminderFlow = isReminderEvent && positiveFiledFlowId != null
                ? flowIndex[positiveFiledFlowId]
                : null;
            final reminderFlowColor = reminderFlow == null
                ? null
                : _displayFlowColor(reminderFlow.name, reminderFlow.color);

            // ✅ If it passed all guards → this is a true standalone note
            final localStart = evt.startsAtUtc.toLocal();
            final kDate = KemeticMath.fromGregorian(localStart);
            final decoded = _decodeDetailMetadata(rawDetail);
            final cleanedDetail = _cleanDetail(decoded.detail);

            final startTime = evt.allDay
                ? null
                : TimeOfDay.fromDateTime(localStart);
            final endTime = evt.endsAtUtc == null
                ? null
                : TimeOfDay.fromDateTime(evt.endsAtUtc!.toLocal());
            if ((evt.category ?? '') == 'tombstone') {
              continue;
            }

            if (_isTombstoned(evt.clientEventId)) {
              continue;
            }
            if (_isPendingDelete(
              id: evt.id,
              clientEventId: evt.clientEventId,
              kYear: kDate.kYear,
              kMonth: kDate.kMonth,
              kDay: kDate.kDay,
              title: evt.title,
              allDay: evt.allDay,
              start: startTime,
              end: endTime,
              flowId: noteFlowId,
            )) {
              continue;
            }

            final note = _Note(
              id: evt.id,
              clientEventId: evt.clientEventId,
              calendarId: evt.calendarId,
              calendarName: evt.calendarName,
              title: _cleanTitle(evt.title),
              detail: cleanedDetail,
              location: evt.location,
              allDay: evt.allDay,
              start: startTime,
              end: endTime,
              flowId: noteFlowId,
              manualColor:
                  decoded.color ??
                  reminderFlowColor ??
                  (evt.calendarIsPersonal
                      ? null
                      : (evt.calendarColor != null
                            ? Color(evt.calendarColor!)
                            : null)),
              category: evt.category,
              isReminder: isReminderEvent,
              reminderId: reminderRuleId,
              alertOffsetMinutes: decoded.alertMinutes,
            );

            final key = _kKey(kDate.kYear, kDate.kMonth, kDate.kDay);
            final bucket = newNotes.putIfAbsent(key, () => <_Note>[]);

            bool skip = false;
            int? replaceIndex;
            final incomingKey = _standaloneDedupeKey(note);
            final incomingPriority = _standalonePriority(note.clientEventId);

            for (int i = 0; i < bucket.length; i++) {
              final existing = bucket[i];
              if ((existing.flowId ?? -1) != -1 &&
                  !existing.isReminder &&
                  !note.isReminder) {
                continue; // skip flow-driven non-reminder rows
              }

              if (existing.clientEventId != null &&
                  note.clientEventId != null &&
                  existing.clientEventId == note.clientEventId) {
                skip = true;
                break;
              }

              if (existing.isReminder || note.isReminder) {
                if (existing.isReminder &&
                    note.isReminder &&
                    existing.reminderId == note.reminderId &&
                    existing.start?.hour == note.start?.hour &&
                    existing.start?.minute == note.start?.minute) {
                  skip = true;
                  break;
                }
                continue;
              }

              final existingKey = _standaloneDedupeKey(existing);
              if (existingKey == incomingKey) {
                final existingPriority = _standalonePriority(
                  existing.clientEventId,
                );
                if (incomingPriority > existingPriority) {
                  replaceIndex = i;
                } else {
                  skip = true;
                }
                break;
              }
            }

            if (skip) {
              continue;
            }

            if (replaceIndex != null) {
              bucket[replaceIndex] = note;
            } else {
              bucket.add(note);
              standaloneAddedCount++; // ✅ important: track how many actually added
            }
          } catch (rowErr) {
            _calendarDebugPrint(
              '[hydrationEngine] ⚠️ standalone row skipped: $rowErr (id=${evt.id} cid=${evt.clientEventId})',
            );
            continue;
          }
        }
        hydrationDiagnostics.recordPostProcessing(
          hydrationContext,
          'standalone_rows_converted',
          durationMs: standaloneConversionStopwatch.elapsedMilliseconds,
          fields: <String, Object?>{'added_count': standaloneAddedCount},
        );

        if (kDebugMode) {
          _calendarDebugPrint(
            '[hydrationEngine] loaded $standaloneAddedCount standalone events after filtering '
            '(${standaloneWindow.startUtc.toIso8601String()} → ${standaloneWindow.endUtc.toIso8601String()})',
          );
        }
        standaloneHydrationComplete = true;
      } catch (err, st) {
        standaloneLaneEndedAtUtc ??= DateTime.now().toUtc();
        if (standaloneHydrationStatus == HydrationFetchStatus.notRun) {
          standaloneHydrationStatus = HydrationFetchStatus.failed;
        }
        standaloneHydrationComplete = false;
        if (kDebugMode) {
          _calendarDebugPrint(
            '[hydrationEngine] failed to load standalone events: $err',
          );
          _calendarDebugPrint('$st');
        }
      }

      final reminderProjectionStopwatch = Stopwatch()..start();
      final projectedReminderCount = _projectReminderMembershipForHydration(
        flows: newFlows,
        notesByDay: newNotes,
      );
      hydrationDiagnostics.recordPostProcessing(
        hydrationContext,
        'reminder_projection_applied',
        durationMs: reminderProjectionStopwatch.elapsedMilliseconds,
        changedNotes: projectedReminderCount > 0,
        fields: <String, Object?>{
          'added_count': projectedReminderCount,
          'source': 'complete_snapshot',
        },
      );

      final calendarFetchComplete =
          flowHydrationComplete &&
          standaloneHydrationComplete &&
          calendarHydrationIsSemanticallyComplete(
            catalogComplete: catalogHydrationComplete,
            flowEvents: flowHydrationStatus,
            standalone: standaloneHydrationStatus,
          );
      final evaluatedCompleteness = evaluateHydrationCompleteness(
        HydrationCompletenessInput(
          catalogStatus: newFlows.isEmpty
              ? HydrationFetchStatus.successfulEmpty
              : HydrationFetchStatus.successNonempty,
          hydrationFlowCount: hydrationFlowIds.length,
          batchStatus: flowHydrationStatus,
          fallbackRequestCount: 0,
          fallbackFailedCount: 0,
          fallbackNonemptyCount: 0,
          standaloneStatus: standaloneHydrationStatus,
          mapping: flowMappingStats,
        ),
      );
      final diagnosticCompleteness = hydrationDiagnostics.recordCompleteness(
        context: hydrationContext,
        hydrationFlowCount: hydrationFlowIds.length,
        claimedComplete: calendarFetchComplete,
        evaluatedResult: evaluatedCompleteness,
      );
      final calendarSemanticComplete =
          calendarFetchComplete && diagnosticCompleteness.semanticComplete;
      await commitVisibleCalendarState(
        CalendarHydrationPublicationPhase.complete,
        loadComplete: calendarSemanticComplete,
        diagnosticCompleteness: diagnosticCompleteness,
      );

      hydrationPassSucceeded =
          calendarSemanticComplete && committedVisibleCalendar;
    } on CalendarHydrationJobCancelled catch (e) {
      hydrationPassSuperseded = true;
      progressiveAbortReason = e.reason;
      if (kDebugMode) {
        _calendarDebugPrint('Hydration superseded: ${e.reason}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        _calendarDebugPrint('Supabase sync FAILED: $e');
        _calendarDebugPrint('Stack: $stackTrace');
      }
    }

    if (backgroundPass != null && loadUserIdForPass != null) {
      final failureReason = hydrationPassSucceeded
          ? null
          : progressiveAbortReason ??
                (flowHydrationStatus == HydrationFetchStatus.failed
                    ? 'flow_lane_failed'
                    : standaloneHydrationStatus == HydrationFetchStatus.failed
                    ? 'standalone_lane_failed'
                    : 'pass_failed');
      await hydrationDiagnostics.recordBackfillChunk(
        userId: loadUserIdForPass,
        index: backgroundPass.chunkIndex,
        flowStatus: flowHydrationStatus,
        flowDurationMs: flowLaneDurationMs,
        flowStartedAtUtc: flowLaneStartedAtUtc,
        flowEndedAtUtc: flowLaneEndedAtUtc,
        standaloneStatus: standaloneHydrationStatus,
        standaloneDurationMs: standaloneLaneDurationMs,
        standaloneStartedAtUtc: standaloneLaneStartedAtUtc,
        standaloneEndedAtUtc: standaloneLaneEndedAtUtc,
        merged: hydrationPassSucceeded,
        failureReason: failureReason,
      );
    }

    hydrationDiagnostics.recordPostProcessing(
      hydrationContext,
      'authority_scope_pass_ended',
      fields: <String, Object?>{
        'authority_scope': _hydrationAuthorityScope.diagnosticName,
        'succeeded': hydrationPassSucceeded,
      },
    );

    hydrationDiagnostics.endPass(
      hydrationContext,
      succeeded: hydrationPassSucceeded,
    );

    if (kDebugMode) {
      _calendarDebugPrint('=== hydrationEngine END ($source) ===');
      if (request.reason == 'shared_calendar_event_tap_background') {
        _calendarDebugPrint(
          '[SharedCalendarEventTap] hydration complete source=$source',
        );
      }
    }
    if (hydrationPassSuperseded) {
      throw CalendarHydrationJobCancelled(
        progressiveAbortReason ?? 'superseded',
      );
    }
    if (!hydrationPassSucceeded) {
      throw const _CalendarHydrationLaneUnavailable('calendar');
    }
    return _CalendarHydrationPassResult(
      catalogFingerprint: effectiveCatalogFingerprint,
    );
  }
}
