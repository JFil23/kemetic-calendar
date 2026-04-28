import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/kemetic_converter.dart';
import '../features/calendar/decan_metadata.dart';
import '../features/journal/journal_badge_utils.dart';
import '../features/journal/journal_event_badge.dart';
import '../features/journal/journal_v2_document_model.dart';
import 'flow_activation_utils.dart';
import 'flows_repo.dart';
import 'user_events_repo.dart';

class FlowTrackerEventPreview {
  const FlowTrackerEventPreview({
    required this.title,
    this.detail,
    required this.startsAtLocal,
    required this.allDay,
    required this.isReflection,
  });

  final String title;
  final String? detail;
  final DateTime startsAtLocal;
  final bool allDay;
  final bool isReflection;
}

class FlowTrackerDayProgress {
  const FlowTrackerDayProgress({
    required this.localDate,
    required this.flowDayIndex,
    required this.primaryEventCompleted,
    required this.journalActivityLogged,
    required this.reflectionLogged,
    required this.badgeCount,
    required this.scheduledEventCount,
    this.lastBadgeCode,
  });

  final DateTime localDate;
  final int flowDayIndex;
  final bool primaryEventCompleted;
  final bool journalActivityLogged;
  final bool reflectionLogged;
  final int badgeCount;
  final int scheduledEventCount;
  final String? lastBadgeCode;

  bool get isFull => primaryEventCompleted && journalActivityLogged;
  bool get isPartial => primaryEventCompleted || journalActivityLogged;

  double get eventCoverageFraction {
    if (scheduledEventCount <= 0) {
      return journalActivityLogged ? 1.0 : 0.0;
    }
    final ratio = badgeCount / scheduledEventCount;
    if (ratio <= 0) return 0.0;
    if (ratio >= 1.0) return 1.0;
    return ratio;
  }

  double get score {
    if (isFull) return 1.0;
    if (isPartial) return 0.5;
    return 0.0;
  }
}

class FlowTrackerSummary {
  const FlowTrackerSummary({
    required this.flow,
    required this.vowText,
    required this.effectiveStartDate,
    required this.effectiveEndDate,
    required this.flowLengthDays,
    required this.days,
    required this.currentFlowDayIndex,
    required this.progressScore,
    required this.daysWithProgress,
    required this.fullDays,
    required this.badgeCount,
    required this.reflectionCount,
    required this.currentDecanName,
    required this.currentDecanDay,
    required this.startDecanName,
    required this.startDecanDay,
    required this.daysUntilDecanReflection,
    required this.hasRolledIntoNewDecan,
    this.nextEvent,
    this.nextReflection,
  });

  final FlowRow flow;
  final String vowText;
  final DateTime effectiveStartDate;
  final DateTime effectiveEndDate;
  final int flowLengthDays;
  final List<FlowTrackerDayProgress> days;
  final int currentFlowDayIndex;
  final double progressScore;
  final int daysWithProgress;
  final int fullDays;
  final int badgeCount;
  final int reflectionCount;
  final String currentDecanName;
  final int currentDecanDay;
  final String startDecanName;
  final int startDecanDay;
  final int daysUntilDecanReflection;
  final bool hasRolledIntoNewDecan;
  final FlowTrackerEventPreview? nextEvent;
  final FlowTrackerEventPreview? nextReflection;

  bool get startedMidDecan => startDecanDay > 1;
  bool get reachedMeaningfulProgress => progressScore >= 7.0;
}

class FlowReflectionEvidence {
  const FlowReflectionEvidence({
    required this.flowId,
    required this.title,
    required this.domain,
    required this.vowText,
    required this.flowLengthDays,
    required this.overlapDays,
    required this.progressScore,
    required this.daysWithProgress,
    required this.fullDays,
    required this.primaryEventCount,
    required this.journalActivityDays,
    required this.reflectionCount,
    required this.badgeCount,
    required this.missedDays,
    required this.overlapStart,
    required this.overlapEnd,
    this.strongestBadgeCode,
  });

  final int flowId;
  final String title;
  final String? domain;
  final String vowText;
  final int flowLengthDays;
  final int overlapDays;
  final double progressScore;
  final int daysWithProgress;
  final int fullDays;
  final int primaryEventCount;
  final int journalActivityDays;
  final int reflectionCount;
  final int badgeCount;
  final int missedDays;
  final DateTime overlapStart;
  final DateTime overlapEnd;
  final String? strongestBadgeCode;

  Map<String, dynamic> toJson() {
    String dateKey(DateTime value) {
      final yyyy = value.year.toString().padLeft(4, '0');
      final mm = value.month.toString().padLeft(2, '0');
      final dd = value.day.toString().padLeft(2, '0');
      return '$yyyy-$mm-$dd';
    }

    return {
      'flow_id': flowId,
      'title': title,
      if (domain != null && domain!.trim().isNotEmpty) 'domain': domain,
      'vow_text': vowText,
      'flow_length_days': flowLengthDays,
      'overlap_days': overlapDays,
      'progress_score': progressScore,
      'days_with_progress': daysWithProgress,
      'full_days': fullDays,
      'primary_event_count': primaryEventCount,
      'journal_activity_days': journalActivityDays,
      'reflection_count': reflectionCount,
      'badge_count': badgeCount,
      'missed_days': missedDays,
      'overlap_start': dateKey(overlapStart),
      'overlap_end': dateKey(overlapEnd),
      if (strongestBadgeCode != null && strongestBadgeCode!.trim().isNotEmpty)
        'strongest_badge_code': strongestBadgeCode,
    };
  }
}

class _FlowProgressAggregate {
  const _FlowProgressAggregate({
    required this.score,
    required this.daysWithProgress,
    required this.fullDays,
    required this.days,
  });

  final double score;
  final int daysWithProgress;
  final int fullDays;
  final Map<int, FlowTrackerDayProgress> days;
}

class _ResolvedFlowTrackerRange {
  const _ResolvedFlowTrackerRange({
    required this.startDate,
    required this.endDate,
    required this.flowLengthDays,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int flowLengthDays;
}

typedef _JournalTrackedEventRow = ({
  String? id,
  String? clientEventId,
  String title,
  String? detail,
  DateTime startsAtLocal,
  DateTime? endsAtLocal,
  int flowId,
  String? category,
});

typedef _DerivedJournalProgressRow = ({
  bool journalActivityLogged,
  bool reflectionLogged,
  int badgeCount,
  String? lastBadgeCode,
});

class _JournalBadgeMatch {
  const _JournalBadgeMatch({
    required this.event,
    required this.badge,
    required this.isReflection,
    required this.badgeCode,
  });

  final _JournalTrackedEventRow event;
  final EventBadgeToken badge;
  final bool isReflection;
  final String badgeCode;
}

class FlowProgressRepo {
  FlowProgressRepo(this._client);

  final SupabaseClient _client;
  final KemeticConverter _kemeticConverter = KemeticConverter();
  String? _journalBackfillCompletedForUserId;
  static final Map<String, List<FlowTrackerSummary>>
  _cachedActiveTrackersByUserId = <String, List<FlowTrackerSummary>>{};

  FlowsRepo get _flowsRepo => FlowsRepo(_client);
  UserEventsRepo get _eventsRepo => UserEventsRepo(_client);

  List<FlowTrackerSummary> get cachedActiveTrackers {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    return List<FlowTrackerSummary>.from(
      _cachedActiveTrackersByUserId[uid] ?? const <FlowTrackerSummary>[],
    );
  }

  Stream<FlowTrackerSummary?> watchPrimaryTracker() {
    return _watchTrackers(loadPrimaryTracker);
  }

  Stream<List<FlowTrackerSummary>> watchActiveTrackers() {
    return _watchTrackers(loadActiveTrackers);
  }

  Stream<T> _watchTrackers<T>(Future<T> Function() loader) {
    final controller = StreamController<T>.broadcast();
    RealtimeChannel? channel;
    StreamSubscription<AuthState>? authSub;
    String? boundUid;

    T emptyValue() {
      if (null is T) {
        return null as T;
      }
      if (<FlowTrackerSummary>[] is T) {
        return <FlowTrackerSummary>[] as T;
      }
      throw StateError('Unsupported tracker stream type: $T');
    }

    Future<void> emitValue(T value) async {
      if (!controller.isClosed) {
        controller.add(value);
      }
    }

    Future<void> disposeChannel() async {
      final current = channel;
      channel = null;
      if (current != null) {
        await current.unsubscribe();
      }
    }

    Future<void> bindForUser(String? uid) async {
      if (controller.isClosed) return;
      if (boundUid == uid && (uid == null || channel != null)) {
        return;
      }

      boundUid = uid;
      await disposeChannel();

      if (uid == null) {
        await emitValue(emptyValue());
        return;
      }

      Future<void> refresh() async {
        if (controller.isClosed) return;
        if (_client.auth.currentUser?.id != uid) return;
        T summary;
        try {
          summary = await loader();
        } catch (_) {
          summary = emptyValue();
        }
        if (controller.isClosed) return;
        if (_client.auth.currentUser?.id != uid) return;
        controller.add(summary);
      }

      final channelName =
          'flow_tracker_${uid}_${DateTime.now().microsecondsSinceEpoch}';
      channel = _client.channel(channelName)
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'flows',
          callback: (_) => unawaited(refresh()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'flow_day_progress',
          callback: (_) => unawaited(refresh()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_event_completions',
          callback: (_) => unawaited(refresh()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_events',
          callback: (_) => unawaited(refresh()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journal_entries',
          callback: (_) => unawaited(refresh()),
        )
        ..subscribe();

      await refresh();
    }

    Future<void> startWatching() async {
      if (authSub != null) return;
      authSub = _client.auth.onAuthStateChange.listen((data) {
        final nextUid = data.session?.user.id ?? _client.auth.currentUser?.id;
        unawaited(bindForUser(nextUid));
      });
      await bindForUser(_client.auth.currentUser?.id);
    }

    Future<void> stopWatching() async {
      final currentAuthSub = authSub;
      authSub = null;
      boundUid = null;
      await currentAuthSub?.cancel();
      await disposeChannel();
    }

    controller.onListen = () {
      unawaited(startWatching());
    };

    controller.onCancel = () {
      if (controller.hasListener) return;
      unawaited(stopWatching());
    };

    return controller.stream;
  }

  Future<void> ensureInitializedForFlow(FlowRow flow) async {
    final user = _client.auth.currentUser;
    final range = await _resolveTrackerRange(flow);
    if (user == null || range == null) return;
    final scheduledDates = await _resolveScheduledFlowDates(flow, range: range);
    if (scheduledDates.isEmpty) return;

    final rows = List.generate(scheduledDates.length, (index) {
      final localDate = scheduledDates[index];
      return <String, dynamic>{
        'user_id': user.id,
        'flow_id': flow.id,
        'local_date': _dateKey(localDate),
        'flow_day_index': index + 1,
      };
    });

    try {
      await _client
          .from('flow_day_progress')
          .upsert(rows, onConflict: 'user_id,flow_id,local_date');
    } catch (_) {
      // Non-fatal: tracker can still derive from existing completion state.
    }
  }

  Future<void> markPrimaryEventCompleted({
    required int flowId,
    required DateTime completedOnDate,
    String source = 'day_view',
  }) async {
    final flow = await _flowsRepo.getFlowById(flowId);
    if (flow == null) return;
    final range = await _resolveTrackerRange(flow);
    if (range == null) return;
    final scheduledDates = await _resolveScheduledFlowDates(flow, range: range);
    if (scheduledDates.isEmpty) return;
    await ensureInitializedForFlow(flow);
    final previousAggregate = await _loadAggregateForFlow(flow, range: range);
    final localDate = normalizeDateOnly(completedOnDate);
    if (localDate == null) return;

    final flowDayIndex = _flowDayIndexForScheduledDates(
      scheduledDates,
      localDate,
    );
    if (flowDayIndex == null) return;

    await _client.from('flow_day_progress').upsert({
      'user_id': _client.auth.currentUser!.id,
      'flow_id': flowId,
      'local_date': _dateKey(localDate),
      'flow_day_index': flowDayIndex,
      'primary_event_completed': true,
    }, onConflict: 'user_id,flow_id,local_date');

    await _eventsRepo.track(
      event: 'flow_event_completed',
      source: source,
      properties: {
        'flow_id': flowId,
        'flow_day_index': flowDayIndex,
        'completed_on': _dateKey(localDate),
      },
    );
    await _eventsRepo.track(
      event: 'flow_progress_square_updated',
      source: source,
      properties: {
        'flow_id': flowId,
        'flow_day_index': flowDayIndex,
        'signal': 'primary_event_completed',
      },
    );
    final nextAggregate = await _loadAggregateForFlow(flow, range: range);
    await _trackProgressMilestones(
      flow: flow,
      flowDayIndex: flowDayIndex,
      previous: previousAggregate,
      current: nextAggregate,
      source: source,
    );
  }

  Future<void> markJournalActivityLogged({
    required int flowId,
    required DateTime localDate,
    String? badgeCode,
    bool reflectionLogged = false,
    String source = 'journal',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final flow = await _flowsRepo.getFlowById(flowId);
    if (flow == null) return;
    final range = await _resolveTrackerRange(flow);
    if (range == null) return;
    final scheduledDates = await _resolveScheduledFlowDates(flow, range: range);
    if (scheduledDates.isEmpty) return;
    await ensureInitializedForFlow(flow);
    final previousAggregate = await _loadAggregateForFlow(flow, range: range);

    final normalizedDate = normalizeDateOnly(localDate);
    final flowDayIndex = _flowDayIndexForScheduledDates(
      scheduledDates,
      normalizedDate,
    );
    if (normalizedDate == null || flowDayIndex == null) return;

    final existing = await _client
        .from('flow_day_progress')
        .select('badge_count, reflection_logged')
        .eq('user_id', user.id)
        .eq('flow_id', flowId)
        .eq('local_date', _dateKey(normalizedDate))
        .maybeSingle();

    final existingBadgeCount = (existing?['badge_count'] as num?)?.toInt() ?? 0;
    final existingReflection =
        (existing?['reflection_logged'] as bool?) ?? false;

    await _client.from('flow_day_progress').upsert({
      'user_id': user.id,
      'flow_id': flowId,
      'local_date': _dateKey(normalizedDate),
      'flow_day_index': flowDayIndex,
      'journal_activity_logged': true,
      'reflection_logged': reflectionLogged || existingReflection,
      'badge_count': existingBadgeCount + 1,
      if (badgeCode != null && badgeCode.trim().isNotEmpty)
        'last_badge_code': badgeCode.trim(),
    }, onConflict: 'user_id,flow_id,local_date');

    await _eventsRepo.track(
      event: reflectionLogged
          ? 'flow_reflection_logged'
          : 'flow_event_added_to_journal',
      source: source,
      properties: {
        'flow_id': flowId,
        'flow_day_index': flowDayIndex,
        'local_date': _dateKey(normalizedDate),
      },
    );
    await _eventsRepo.track(
      event: 'journal_badge_added_from_flow',
      source: source,
      properties: {
        'flow_id': flowId,
        'flow_day_index': flowDayIndex,
        if (badgeCode != null && badgeCode.trim().isNotEmpty)
          'badge_code': badgeCode.trim(),
      },
    );
    await _eventsRepo.track(
      event: 'flow_progress_square_updated',
      source: source,
      properties: {
        'flow_id': flowId,
        'flow_day_index': flowDayIndex,
        'signal': reflectionLogged
            ? 'reflection_logged'
            : 'journal_activity_logged',
      },
    );
    final nextAggregate = await _loadAggregateForFlow(flow, range: range);
    await _trackProgressMilestones(
      flow: flow,
      flowDayIndex: flowDayIndex,
      previous: previousAggregate,
      current: nextAggregate,
      source: source,
    );
  }

  Future<void> syncJournalBadgesForDate({
    required DateTime localDate,
    required Iterable<EventBadgeToken> badges,
    String source = 'journal_autosave',
  }) async {
    final user = _client.auth.currentUser;
    final normalizedDate = normalizeDateOnly(localDate);
    if (user == null || normalizedDate == null) return;

    final trackedEvents = await _loadFlowEventsForLocalDate(normalizedDate);
    if (trackedEvents.isEmpty) return;

    final badgesForDate = badges.where((badge) {
      final badgeDate = normalizeDateOnly(badge.start?.toLocal());
      return badgeDate == null || _sameDate(badgeDate, normalizedDate);
    }).toList();

    final matchesByFlow = _matchJournalBadgesToFlowEvents(
      badges: badgesForDate,
      events: trackedEvents,
      localDate: normalizedDate,
    );
    final flowIds = trackedEvents.map((event) => event.flowId).toSet().toList()
      ..sort();

    final existingRows = await _client
        .from('flow_day_progress')
        .select(
          'flow_id, flow_day_index, journal_activity_logged, reflection_logged, badge_count, last_badge_code',
        )
        .eq('user_id', user.id)
        .eq('local_date', _dateKey(normalizedDate))
        .inFilter('flow_id', flowIds);

    final existingByFlowId = <int, Map<String, dynamic>>{};
    for (final row in (existingRows as List).cast<Map<String, dynamic>>()) {
      final flowId = (row['flow_id'] as num?)?.toInt();
      if (flowId == null) continue;
      existingByFlowId[flowId] = row;
    }

    final updates = <Map<String, dynamic>>[];
    for (final flowId in flowIds) {
      final flow = await _flowsRepo.getFlowById(flowId);
      if (flow == null) continue;

      final flowEvents = trackedEvents
          .where((event) => event.flowId == flowId)
          .map(_trackedEventToFlowEventRow)
          .toList();
      final range = await _resolveTrackerRange(
        flow,
        prefetchedEvents: flowEvents,
      );
      if (range == null) continue;
      final scheduledDates = await _resolveScheduledFlowDates(
        flow,
        prefetchedEvents: flowEvents,
        range: range,
      );
      final flowDayIndex = _flowDayIndexForScheduledDates(
        scheduledDates,
        normalizedDate,
      );
      if (flowDayIndex == null) continue;

      final matches = matchesByFlow[flowId] ?? const <_JournalBadgeMatch>[];
      final badgeCount = matches.length;
      final journalLogged = badgeCount > 0;
      final reflectionLogged = matches.any((match) => match.isReflection);
      final lastBadgeCode = matches.isEmpty ? null : matches.last.badgeCode;
      final existing = existingByFlowId[flowId];
      final existingJournal =
          (existing?['journal_activity_logged'] as bool?) ?? false;
      final existingReflection =
          (existing?['reflection_logged'] as bool?) ?? false;
      final existingBadgeCount =
          (existing?['badge_count'] as num?)?.toInt() ?? 0;
      final existingBadgeCode = normalizeFlowText(
        existing?['last_badge_code'] as String?,
      );

      final changed =
          existingJournal != journalLogged ||
          existingReflection != reflectionLogged ||
          existingBadgeCount != badgeCount ||
          existingBadgeCode != lastBadgeCode;
      if (!changed) continue;

      updates.add({
        'user_id': user.id,
        'flow_id': flowId,
        'local_date': _dateKey(normalizedDate),
        'flow_day_index': flowDayIndex,
        'journal_activity_logged': journalLogged,
        'reflection_logged': reflectionLogged,
        'badge_count': badgeCount,
        'last_badge_code': lastBadgeCode,
      });
    }

    if (updates.isEmpty) return;

    await _client
        .from('flow_day_progress')
        .upsert(updates, onConflict: 'user_id,flow_id,local_date');
    await _eventsRepo.track(
      event: 'flow_progress_square_updated',
      source: source,
      properties: {
        'local_date': _dateKey(normalizedDate),
        'flow_count': updates.length,
        'signal': 'journal_badge_sync',
      },
    );
  }

  Future<List<FlowReflectionEvidence>> loadReflectionEvidenceForWindow({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = _client.auth.currentUser;
    final normalizedStart = normalizeDateOnly(startDate);
    final normalizedEnd = normalizeDateOnly(endDate);
    if (user == null || normalizedStart == null || normalizedEnd == null) {
      return const [];
    }

    final flows = await _flowsRepo.listMyFlowsUnfiltered(limit: 500);
    final visibleFlows = flows.where((flow) => flow.isTrackableFlow).toList();
    if (visibleFlows.isEmpty) return const [];

    final eventsByFlowId = await _prefetchEventsByFlowId(visibleFlows);
    final candidateDatesByFlowId = <int, List<DateTime>>{};
    final candidates = <FlowRow>[];

    for (final flow in visibleFlows) {
      final flowEvents = eventsByFlowId[flow.id] ?? const <FlowEventRow>[];
      final range = await _resolveTrackerRange(
        flow,
        prefetchedEvents: flowEvents,
      );
      if (range == null) continue;
      final scheduledDates = await _resolveScheduledFlowDates(
        flow,
        prefetchedEvents: flowEvents,
        range: range,
      );
      final overlapDates = scheduledDates.where((date) {
        return !date.isBefore(normalizedStart) && !date.isAfter(normalizedEnd);
      }).toList();
      if (overlapDates.isEmpty) continue;
      candidates.add(flow);
      candidateDatesByFlowId[flow.id] = overlapDates;
    }
    if (candidates.isEmpty) return const [];

    final flowIds = candidates.map((flow) => flow.id).toList()..sort();
    final rows = await _client
        .from('flow_day_progress')
        .select(
          'flow_id, local_date, flow_day_index, primary_event_completed, journal_activity_logged, reflection_logged, badge_count, last_badge_code',
        )
        .eq('user_id', user.id)
        .inFilter('flow_id', flowIds)
        .gte('local_date', _dateKey(normalizedStart))
        .lte('local_date', _dateKey(normalizedEnd));

    final progressByFlow = <int, List<Map<String, dynamic>>>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final id = (row['flow_id'] as num?)?.toInt();
      if (id == null) continue;
      progressByFlow.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(row);
    }

    final completionRows = await _client
        .from('user_event_completions')
        .select('flow_id, completed_on')
        .eq('user_id', user.id)
        .inFilter('flow_id', flowIds)
        .gte('completed_on', _dateKey(normalizedStart))
        .lte('completed_on', _dateKey(normalizedEnd));
    final completionDatesByFlow = <int, Set<String>>{};
    for (final row in (completionRows as List).cast<Map<String, dynamic>>()) {
      final flowId = (row['flow_id'] as num?)?.toInt();
      final completedOn = row['completed_on']?.toString();
      if (flowId == null || completedOn == null || completedOn.isEmpty) {
        continue;
      }
      completionDatesByFlow
          .putIfAbsent(flowId, () => <String>{})
          .add(completedOn);
    }

    final derivedJournalByFlow = await _loadDerivedJournalProgressForFlows(
      candidates,
      prefetchedEventsByFlowId: eventsByFlowId,
      startDate: normalizedStart,
      endDate: normalizedEnd,
    );

    final evidence = <FlowReflectionEvidence>[];
    for (final flow in candidates) {
      final overlapDates = candidateDatesByFlowId[flow.id] ?? const [];
      if (overlapDates.isEmpty) continue;

      final overlapStart = overlapDates.first;
      final overlapEnd = overlapDates.last;
      final overlapDays = overlapDates.length;
      final rowsForFlow =
          progressByFlow[flow.id] ?? const <Map<String, dynamic>>[];
      final rowsByDate = <String, Map<String, dynamic>>{};
      for (final row in rowsForFlow) {
        final localDate = row['local_date']?.toString();
        if (localDate == null || localDate.isEmpty) continue;
        rowsByDate[localDate] = row;
      }
      final completionDates =
          completionDatesByFlow[flow.id] ?? const <String>{};
      final derivedByDate = derivedJournalByFlow[flow.id] ?? const {};
      int daysWithProgress = 0;
      int fullDays = 0;
      int primaryEventCount = 0;
      int journalActivityDays = 0;
      int reflectionCount = 0;
      int badgeCount = 0;
      final badgeFrequency = <String, int>{};

      for (final localDate in overlapDates) {
        final dateKey = _dateKey(localDate);
        final row = rowsByDate[dateKey];
        final derived = derivedByDate[dateKey];
        final primaryCompleted =
            (row?['primary_event_completed'] as bool?) ??
            completionDates.contains(dateKey);
        final journalLogged =
            ((row?['journal_activity_logged'] as bool?) ?? false) ||
            (derived?.journalActivityLogged ?? false);
        final reflectionLogged =
            ((row?['reflection_logged'] as bool?) ?? false) ||
            (derived?.reflectionLogged ?? false);
        final rowBadgeCount = (row?['badge_count'] as num?)?.toInt() ?? 0;
        final derivedBadgeCount = derived?.badgeCount ?? 0;
        final effectiveBadgeCount = rowBadgeCount >= derivedBadgeCount
            ? rowBadgeCount
            : derivedBadgeCount;
        final badgeCode = normalizeFlowText(
          derived?.lastBadgeCode ?? row?['last_badge_code'] as String?,
        );

        if (primaryCompleted) primaryEventCount++;
        if (journalLogged) journalActivityDays++;
        if (reflectionLogged) reflectionCount++;
        badgeCount += effectiveBadgeCount;
        if (badgeCode != null) {
          badgeFrequency[badgeCode] = (badgeFrequency[badgeCode] ?? 0) + 1;
        }

        if (primaryCompleted || journalLogged) {
          daysWithProgress++;
        }
        if (primaryCompleted && journalLogged) {
          fullDays++;
        }
      }

      final progressScore =
          fullDays +
          ((daysWithProgress - fullDays).clamp(0, overlapDays) * 0.5);
      final missedDays = (overlapDays - daysWithProgress).clamp(0, overlapDays);
      final strongestBadgeCode = badgeFrequency.entries.isEmpty
          ? null
          : (badgeFrequency.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key;
      final vowText =
          normalizeFlowText(flow.vowText) ??
          buildFallbackFlowVow(
            title: flow.name,
            domain: flow.intentionDomain,
            intention: flow.intentionText,
            obstacle: flow.obstacleText,
          );
      final flowLengthDays =
          candidateDatesByFlowId[flow.id]?.length ??
          flow.resolvedFlowLengthDays ??
          overlapDays;

      evidence.add(
        FlowReflectionEvidence(
          flowId: flow.id,
          title: flow.name,
          domain: normalizeFlowText(flow.intentionDomain),
          vowText: vowText,
          flowLengthDays: flowLengthDays,
          overlapDays: overlapDays,
          progressScore: progressScore,
          daysWithProgress: daysWithProgress,
          fullDays: fullDays,
          primaryEventCount: primaryEventCount,
          journalActivityDays: journalActivityDays,
          reflectionCount: reflectionCount,
          badgeCount: badgeCount,
          missedDays: missedDays,
          overlapStart: overlapStart,
          overlapEnd: overlapEnd,
          strongestBadgeCode: strongestBadgeCode,
        ),
      );
    }

    evidence.sort((a, b) {
      final scoreCompare = b.progressScore.compareTo(a.progressScore);
      if (scoreCompare != 0) return scoreCompare;
      final badgeCompare = b.badgeCount.compareTo(a.badgeCount);
      if (badgeCompare != 0) return badgeCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return evidence;
  }

  Future<FlowTrackerSummary?> loadPrimaryTracker() async {
    final summaries = await loadActiveTrackers();
    if (summaries.isEmpty) return null;
    return summaries.first;
  }

  Future<List<FlowTrackerSummary>> loadActiveTrackers() async {
    final uid = _client.auth.currentUser?.id;
    final flows = await _loadTrackableActiveFlows();
    if (flows.isEmpty) {
      if (uid != null) {
        _cachedActiveTrackersByUserId[uid] = const <FlowTrackerSummary>[];
      }
      return const [];
    }
    final eventsByFlowId = await _prefetchEventsByFlowId(flows);
    unawaited(
      _backfillJournalProgressForFlows(
        flows,
        prefetchedEventsByFlowId: eventsByFlowId,
      ),
    );
    final derivedJournalByFlow = await _loadDerivedJournalProgressForFlows(
      flows,
      prefetchedEventsByFlowId: eventsByFlowId,
    );
    final summaries = await Future.wait(
      flows.map(
        (flow) => _buildTrackerSummary(
          flow,
          prefetchedEvents: eventsByFlowId[flow.id],
          derivedJournalProgressByDate:
              derivedJournalByFlow[flow.id] ?? const {},
        ),
      ),
    );
    final resolved = summaries.whereType<FlowTrackerSummary>().toList();
    if (uid != null) {
      _cachedActiveTrackersByUserId[uid] =
          List<FlowTrackerSummary>.unmodifiable(resolved);
    }
    return resolved;
  }

  Future<FlowTrackerSummary?> _buildTrackerSummary(
    FlowRow flow, {
    List<FlowEventRow>? prefetchedEvents,
    Map<String, _DerivedJournalProgressRow> derivedJournalProgressByDate =
        const {},
  }) async {
    final events =
        prefetchedEvents ?? await _eventsRepo.getEventsForFlow(flow.id);
    final range = await _resolveTrackerRange(flow, prefetchedEvents: events);
    if (range == null) return null;
    final scheduledDates = await _resolveScheduledFlowDates(
      flow,
      prefetchedEvents: events,
      range: range,
    );
    if (scheduledDates.isEmpty) return null;
    await ensureInitializedForFlow(flow);

    final progressRows = await _loadProgressRows(flow.id);
    final completions = await _loadCompletionDates(flow.id);
    final nowLocal = DateUtils.dateOnly(DateTime.now());
    final flowDatesThroughToday = scheduledDates
        .where((date) => !date.isAfter(nowLocal))
        .toList();
    final eventCountByDate = _countTrackedEventsByDate(events);
    final currentFlowDayIndex = flowDatesThroughToday.length.clamp(
      0,
      scheduledDates.length,
    );
    final dayRows = <FlowTrackerDayProgress>[];

    for (var index = 0; index < flowDatesThroughToday.length; index++) {
      final localDate = flowDatesThroughToday[index];
      final completionKey = _dateKey(localDate);
      final row = progressRows[completionKey];
      final derived = derivedJournalProgressByDate[completionKey];
      final primaryCompleted =
          (row?['primary_event_completed'] as bool?) ??
          completions.contains(completionKey);
      final rowJournalLogged =
          (row?['journal_activity_logged'] as bool?) ?? false;
      final rowReflectionLogged = (row?['reflection_logged'] as bool?) ?? false;
      final rowBadgeCount = (row?['badge_count'] as num?)?.toInt() ?? 0;
      final derivedBadgeCount = derived?.badgeCount ?? 0;
      final journalLogged =
          rowJournalLogged || (derived?.journalActivityLogged ?? false);
      final reflectionLogged =
          rowReflectionLogged || (derived?.reflectionLogged ?? false);
      final badgeCount = rowBadgeCount >= derivedBadgeCount
          ? rowBadgeCount
          : derivedBadgeCount;
      dayRows.add(
        FlowTrackerDayProgress(
          localDate: localDate,
          flowDayIndex: index + 1,
          primaryEventCompleted: primaryCompleted,
          journalActivityLogged: journalLogged,
          reflectionLogged: reflectionLogged,
          badgeCount: badgeCount,
          scheduledEventCount: eventCountByDate[completionKey] ?? 0,
          lastBadgeCode:
              derived?.lastBadgeCode ?? row?['last_badge_code'] as String?,
        ),
      );
    }

    final score = dayRows.fold<double>(0.0, (sum, day) => sum + day.score);
    final daysWithProgress = dayRows.where((day) => day.isPartial).length;
    final fullDays = dayRows.where((day) => day.isFull).length;
    final badgeCount = dayRows.fold<int>(0, (sum, day) => sum + day.badgeCount);
    final reflectionCount = dayRows.where((day) => day.reflectionLogged).length;

    final currentKemetic = _kemeticConverter.fromGregorian(nowLocal);
    final currentDecanName = currentKemetic.epagomenal
        ? 'Epagomenal'
        : DecanMetadata.decanNameFor(
            kMonth: currentKemetic.month,
            kDay: currentKemetic.day,
          );
    final currentDecanDay = _decanDayFor(currentKemetic.day);

    final startKemetic = _kemeticConverter.fromGregorian(range.startDate);
    final startDecanName = flow.startKemeticDecanName?.trim().isNotEmpty == true
        ? flow.startKemeticDecanName!.trim()
        : (startKemetic.epagomenal
              ? 'Epagomenal'
              : DecanMetadata.decanNameFor(
                  kMonth: startKemetic.month,
                  kDay: startKemetic.day,
                ));
    final startDecanDay =
        flow.startKemeticDay ?? _decanDayFor(startKemetic.day);

    final nextEvent = _nextEvent(events, reflection: false);
    final nextReflection = _nextEvent(events, reflection: true);
    final vowText =
        normalizeFlowText(flow.vowText) ??
        buildFallbackFlowVow(
          title: flow.name,
          domain: flow.intentionDomain,
          intention: flow.intentionText,
          obstacle: flow.obstacleText,
        );

    return FlowTrackerSummary(
      flow: flow,
      vowText: vowText,
      effectiveStartDate: scheduledDates.first,
      effectiveEndDate: scheduledDates.last,
      flowLengthDays:
          flow.resolvedFlowLengthDays ??
          flow.flowLengthDays ??
          scheduledDates.length,
      days: dayRows,
      currentFlowDayIndex: currentFlowDayIndex,
      progressScore: score,
      daysWithProgress: daysWithProgress,
      fullDays: fullDays,
      badgeCount: badgeCount,
      reflectionCount: reflectionCount,
      currentDecanName: currentDecanName,
      currentDecanDay: currentDecanDay,
      startDecanName: startDecanName,
      startDecanDay: startDecanDay,
      daysUntilDecanReflection: (10 - currentDecanDay).clamp(0, 9),
      hasRolledIntoNewDecan:
          startDecanName != currentDecanName ||
          startKemetic.month != currentKemetic.month,
      nextEvent: nextEvent,
      nextReflection: nextReflection,
    );
  }

  Future<List<FlowRow>> _loadTrackableActiveFlows() async {
    final flows = await _flowsRepo.listMyFlowsUnfiltered(limit: 500);
    if (flows.isEmpty) return const [];
    final today = DateUtils.dateOnly(DateTime.now());
    final candidates = <MapEntry<FlowRow, List<DateTime>>>[];
    for (final flow in flows) {
      if (!flow.active || !flow.isTrackableFlow) {
        continue;
      }
      final range = await _resolveTrackerRange(flow);
      if (range == null) {
        continue;
      }
      final scheduledDates = await _resolveScheduledFlowDates(
        flow,
        range: range,
      );
      if (scheduledDates.isEmpty) {
        continue;
      }
      if (scheduledDates.last.isBefore(today)) {
        continue;
      }
      candidates.add(MapEntry(flow, scheduledDates));
    }
    if (candidates.isEmpty) return const [];

    int scoreFor(List<DateTime> scheduledDates) {
      final startDate = scheduledDates.first;
      final endDate = scheduledDates.last;
      if (!today.isBefore(startDate) && !today.isAfter(endDate)) {
        return 1000;
      }
      if (today.isBefore(startDate)) {
        return 500 - startDate.difference(today).inDays.abs();
      }
      return 100 - today.difference(endDate).inDays.abs();
    }

    candidates.sort((a, b) {
      final scoreCompare = scoreFor(b.value).compareTo(scoreFor(a.value));
      if (scoreCompare != 0) return scoreCompare;
      final updatedCompare = (b.key.updatedAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.key.updatedAt?.millisecondsSinceEpoch ?? 0);
      if (updatedCompare != 0) return updatedCompare;
      return b.value.first.millisecondsSinceEpoch.compareTo(
        a.value.first.millisecondsSinceEpoch,
      );
    });
    return candidates.map((entry) => entry.key).toList();
  }

  Future<Map<int, List<FlowEventRow>>> _prefetchEventsByFlowId(
    Iterable<FlowRow> flows,
  ) async {
    final flowIds = flows.map((flow) => flow.id).toSet();
    if (flowIds.isEmpty) return const {};
    final events = await _eventsRepo.getEventsForFlowIds(flowIds);
    final grouped = <int, List<FlowEventRow>>{};
    for (final event in events) {
      final flowId = event.flowLocalId;
      if (flowId == null) continue;
      grouped.putIfAbsent(flowId, () => <FlowEventRow>[]).add(event);
    }
    return grouped;
  }

  Future<Map<String, Map<String, dynamic>>> _loadProgressRows(
    int flowId,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await _client
          .from('flow_day_progress')
          .select(
            'local_date, flow_day_index, primary_event_completed, journal_activity_logged, reflection_logged, badge_count, last_badge_code',
          )
          .eq('user_id', uid)
          .eq('flow_id', flowId);
      return {
        for (final raw in (rows as List).cast<Map<String, dynamic>>())
          (raw['local_date'] as String?) ?? '': raw,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<Set<String>> _loadCompletionDates(int flowId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await _client
          .from('user_event_completions')
          .select('completed_on')
          .eq('user_id', uid)
          .eq('flow_id', flowId);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((row) => row['completed_on']?.toString())
          .whereType<String>()
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  FlowTrackerEventPreview? _nextEvent(
    List<FlowEventRow> events, {
    required bool reflection,
  }) {
    final nowUtc = DateTime.now().toUtc();
    for (final event in events) {
      final isReflection = _looksLikeReflectionEvent(event);
      if (isReflection != reflection) continue;
      if (event.startsAtUtc.isBefore(nowUtc)) continue;
      return FlowTrackerEventPreview(
        title: event.title.trim().isEmpty ? 'Flow event' : event.title.trim(),
        detail: normalizeFlowText(event.detail),
        startsAtLocal: event.startsAtUtc.toLocal(),
        allDay: event.allDay,
        isReflection: isReflection,
      );
    }
    return null;
  }

  int _decanDayFor(int kemeticDay) => ((kemeticDay - 1) % 10) + 1;

  int? _flowDayIndexForScheduledDates(
    List<DateTime> scheduledDates,
    DateTime? localDate,
  ) {
    final normalizedDate = normalizeDateOnly(localDate);
    if (normalizedDate == null) {
      return null;
    }
    for (var index = 0; index < scheduledDates.length; index++) {
      if (_sameDate(scheduledDates[index], normalizedDate)) {
        return index + 1;
      }
    }
    return null;
  }

  bool _looksLikeReflectionEvent(FlowEventRow event) {
    final category = event.category?.trim().toLowerCase() ?? '';
    if (category == 'reflection') return true;
    if (category == 'flow_action') return false;
    final haystack = '${event.title} ${event.detail ?? ''}'
        .toLowerCase()
        .trim();
    return haystack.contains('reflection') ||
        haystack.contains('reflect') ||
        haystack.contains('journal') ||
        haystack.contains('review') ||
        haystack.contains('seal the day');
  }

  bool _looksLikeReflectionTrackedEvent(_JournalTrackedEventRow event) {
    return _looksLikeReflectionEvent(_trackedEventToFlowEventRow(event));
  }

  String _dateKey(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<_FlowProgressAggregate> _loadAggregateForFlow(
    FlowRow flow, {
    _ResolvedFlowTrackerRange? range,
  }) async {
    final resolvedRange = range ?? await _resolveTrackerRange(flow);
    if (resolvedRange == null || resolvedRange.flowLengthDays <= 0) {
      return const _FlowProgressAggregate(
        score: 0,
        daysWithProgress: 0,
        fullDays: 0,
        days: {},
      );
    }
    final scheduledDates = await _resolveScheduledFlowDates(
      flow,
      range: resolvedRange,
    );
    final nowLocal = DateUtils.dateOnly(DateTime.now());
    final flowDatesThroughToday = scheduledDates
        .where((date) => !date.isAfter(nowLocal))
        .toList();
    if (flowDatesThroughToday.isEmpty) {
      return const _FlowProgressAggregate(
        score: 0,
        daysWithProgress: 0,
        fullDays: 0,
        days: {},
      );
    }

    final progressRows = await _loadProgressRows(flow.id);
    final completions = await _loadCompletionDates(flow.id);
    final dayRows = <int, FlowTrackerDayProgress>{};
    double score = 0;
    int daysWithProgress = 0;
    int fullDays = 0;

    for (var index = 0; index < flowDatesThroughToday.length; index++) {
      final localDate = flowDatesThroughToday[index];
      final row = progressRows[_dateKey(localDate)];
      final completionKey = _dateKey(localDate);
      final day = FlowTrackerDayProgress(
        localDate: localDate,
        flowDayIndex: index + 1,
        primaryEventCompleted:
            (row?['primary_event_completed'] as bool?) ??
            completions.contains(completionKey),
        journalActivityLogged:
            (row?['journal_activity_logged'] as bool?) ?? false,
        reflectionLogged: (row?['reflection_logged'] as bool?) ?? false,
        badgeCount: (row?['badge_count'] as num?)?.toInt() ?? 0,
        scheduledEventCount: 0,
        lastBadgeCode: row?['last_badge_code'] as String?,
      );
      dayRows[index + 1] = day;
      score += day.score;
      if (day.isPartial) daysWithProgress++;
      if (day.isFull) fullDays++;
    }

    return _FlowProgressAggregate(
      score: score,
      daysWithProgress: daysWithProgress,
      fullDays: fullDays,
      days: dayRows,
    );
  }

  Future<_ResolvedFlowTrackerRange?> _resolveTrackerRange(
    FlowRow flow, {
    List<FlowEventRow>? prefetchedEvents,
  }) async {
    final metadataStart = normalizeDateOnly(flow.startDate);
    final metadataEnd = normalizeDateOnly(flow.endDate);
    final explicitLength = flow.flowLengthDays?.clamp(1, 90);
    final ruleDates = _extractRuleLocalDates(flow.rules);
    final ruleStart = ruleDates.isEmpty ? null : ruleDates.first;
    final ruleEnd = ruleDates.isEmpty ? null : ruleDates.last;

    List<FlowEventRow> events = prefetchedEvents ?? const <FlowEventRow>[];
    if (events.isEmpty &&
        (metadataStart == null ||
            (metadataEnd == null && explicitLength == null) ||
            ruleStart == null)) {
      events = await _eventsRepo.getEventsForFlow(flow.id);
    }
    final eventDates = _extractEventLocalDates(events);
    final eventStart = eventDates.isEmpty ? null : eventDates.first;
    final eventEnd = eventDates.isEmpty ? null : eventDates.last;
    final createdDate = normalizeDateOnly(flow.createdAt);
    final updatedDate = normalizeDateOnly(flow.updatedAt);
    final fallbackStart =
        metadataStart ??
        ruleStart ??
        eventStart ??
        createdDate ??
        updatedDate ??
        DateUtils.dateOnly(DateTime.now());

    if (explicitLength != null && explicitLength > 0) {
      final endDate = fallbackStart.add(Duration(days: explicitLength - 1));
      return _ResolvedFlowTrackerRange(
        startDate: fallbackStart,
        endDate: endDate,
        flowLengthDays: explicitLength,
      );
    }

    final startCandidates = <DateTime>[
      if (metadataStart != null) metadataStart,
      if (ruleStart != null) ruleStart,
      if (eventStart != null) eventStart,
      if (createdDate != null) createdDate,
      if (updatedDate != null) updatedDate,
    ]..sort();
    final endCandidates = <DateTime>[
      if (metadataEnd != null) metadataEnd,
      if (ruleEnd != null) ruleEnd,
      if (eventEnd != null) eventEnd,
    ]..sort();

    final startDate = startCandidates.isEmpty
        ? fallbackStart
        : startCandidates.first;
    final rawEndDate = endCandidates.isEmpty ? startDate : endCandidates.last;
    final endDate = rawEndDate.isBefore(startDate) ? startDate : rawEndDate;
    final flowLengthDays = (endDate.difference(startDate).inDays + 1).clamp(
      1,
      90,
    );

    return _ResolvedFlowTrackerRange(
      startDate: startDate,
      endDate: startDate.add(Duration(days: flowLengthDays - 1)),
      flowLengthDays: flowLengthDays,
    );
  }

  List<DateTime> _extractRuleLocalDates(List<dynamic>? rules) {
    final dates = <DateTime>{};
    for (final rawRule in rules ?? const <dynamic>[]) {
      if (rawRule is! Map) continue;
      final type = rawRule['type']?.toString().trim().toLowerCase();
      if (type != 'dates') continue;
      final rawDates = rawRule['dates'];
      if (rawDates is! List) continue;
      for (final rawDate in rawDates) {
        final millis = switch (rawDate) {
          int value => value,
          num value => value.toInt(),
          _ => null,
        };
        if (millis == null) continue;
        final localDate = normalizeDateOnly(
          DateTime.fromMillisecondsSinceEpoch(millis),
        );
        if (localDate != null) {
          dates.add(localDate);
        }
      }
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }

  List<DateTime> _extractEventLocalDates(List<FlowEventRow> events) {
    final dates = <DateTime>{};
    for (final event in events) {
      final localDate = normalizeDateOnly(event.startsAtUtc.toLocal());
      if (localDate != null) {
        dates.add(localDate);
      }
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }

  Future<List<_JournalTrackedEventRow>> _loadFlowEventsForLocalDate(
    DateTime localDate,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final dayStartLocal = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    final dayEndLocal = dayStartLocal.add(const Duration(days: 1));
    try {
      final rows = await _client
          .from('user_events')
          .select(
            'id, client_event_id, title, detail, starts_at, ends_at, flow_local_id, category',
          )
          .eq('user_id', user.id)
          .not('flow_local_id', 'is', null)
          .gte('starts_at', dayStartLocal.toUtc().toIso8601String())
          .lt('starts_at', dayEndLocal.toUtc().toIso8601String())
          .order('starts_at', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map<_JournalTrackedEventRow>((row) {
            return (
              id: row['id'] as String?,
              clientEventId: row['client_event_id'] as String?,
              title: (row['title'] as String?) ?? '',
              detail: row['detail'] as String?,
              startsAtLocal: DateTime.parse(
                row['starts_at'] as String,
              ).toLocal(),
              endsAtLocal: row['ends_at'] == null
                  ? null
                  : DateTime.parse(row['ends_at'] as String).toLocal(),
              flowId: (row['flow_local_id'] as num).toInt(),
              category: row['category'] as String?,
            );
          })
          .where((event) => event.category?.trim().toLowerCase() != 'done')
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<int, Map<String, _DerivedJournalProgressRow>>>
  _loadDerivedJournalProgressForFlows(
    List<FlowRow> flows, {
    Map<int, List<FlowEventRow>>? prefetchedEventsByFlowId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || flows.isEmpty) return const {};

    final normalizedStart = normalizeDateOnly(startDate);
    final normalizedEnd = normalizeDateOnly(endDate);
    final eventsByFlowId =
        prefetchedEventsByFlowId ?? await _prefetchEventsByFlowId(flows);
    final relevantDates = <DateTime>{};
    final scheduledKeysByFlowId = <int, Set<String>>{};
    final trackedEventsByDate = <String, List<_JournalTrackedEventRow>>{};

    for (final flow in flows) {
      final flowEvents = eventsByFlowId[flow.id] ?? const <FlowEventRow>[];
      final range = await _resolveTrackerRange(
        flow,
        prefetchedEvents: flowEvents,
      );
      if (range == null) continue;
      final scheduledDates = await _resolveScheduledFlowDates(
        flow,
        prefetchedEvents: flowEvents,
        range: range,
      );
      if (scheduledDates.isEmpty) continue;

      final filteredDates = scheduledDates.where((date) {
        if (normalizedStart != null && date.isBefore(normalizedStart)) {
          return false;
        }
        if (normalizedEnd != null && date.isAfter(normalizedEnd)) {
          return false;
        }
        return true;
      }).toList();
      if (filteredDates.isEmpty) continue;

      final dateKeys = <String>{};
      for (final date in filteredDates) {
        relevantDates.add(date);
        dateKeys.add(_dateKey(date));
      }
      scheduledKeysByFlowId[flow.id] = dateKeys;

      for (final event in flowEvents) {
        final localDate = normalizeDateOnly(event.startsAtUtc.toLocal());
        if (localDate == null) continue;
        if (normalizedStart != null && localDate.isBefore(normalizedStart)) {
          continue;
        }
        if (normalizedEnd != null && localDate.isAfter(normalizedEnd)) {
          continue;
        }
        final dateKey = _dateKey(localDate);
        if (!dateKeys.contains(dateKey)) continue;
        trackedEventsByDate
            .putIfAbsent(dateKey, () => <_JournalTrackedEventRow>[])
            .add(_flowEventToTrackedEventRow(event));
      }
    }

    if (relevantDates.isEmpty || trackedEventsByDate.isEmpty) {
      return const {};
    }

    final sortedDates = relevantDates.toList()..sort();
    final startKey = _dateKey(sortedDates.first);
    final endKey = _dateKey(sortedDates.last);
    final badgesByDate = <String, List<EventBadgeToken>>{};

    try {
      final rows = await _client
          .from('journal_entries')
          .select('greg_date, body')
          .eq('user_id', user.id)
          .gte('greg_date', startKey)
          .lte('greg_date', endKey);

      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final dateKey = row['greg_date']?.toString();
        final body = row['body']?.toString();
        if (dateKey == null || body == null || body.trim().isEmpty) {
          continue;
        }
        final badges = _extractJournalBadgesFromBody(body);
        if (badges.isEmpty) continue;
        badgesByDate[dateKey] = badges;
      }
    } catch (_) {
      return const {};
    }

    final derived = <int, Map<String, _DerivedJournalProgressRow>>{};
    for (final date in sortedDates) {
      final dateKey = _dateKey(date);
      final badges = badgesByDate[dateKey];
      final trackedEvents = trackedEventsByDate[dateKey];
      if (badges == null ||
          badges.isEmpty ||
          trackedEvents == null ||
          trackedEvents.isEmpty) {
        continue;
      }

      final matchesByFlow = _matchJournalBadgesToFlowEvents(
        badges: badges,
        events: trackedEvents,
        localDate: date,
      );
      for (final entry in matchesByFlow.entries) {
        final flowId = entry.key;
        final matches = entry.value;
        if (matches.isEmpty) continue;
        final scheduledKeys = scheduledKeysByFlowId[flowId];
        if (scheduledKeys == null || !scheduledKeys.contains(dateKey)) {
          continue;
        }
        derived.putIfAbsent(
          flowId,
          () => <String, _DerivedJournalProgressRow>{},
        )[dateKey] = (
          journalActivityLogged: true,
          reflectionLogged: matches.any((match) => match.isReflection),
          badgeCount: matches.length,
          lastBadgeCode: matches.last.badgeCode,
        );
      }
    }

    return derived;
  }

  Future<void> _backfillJournalProgressForFlows(
    List<FlowRow> flows, {
    Map<int, List<FlowEventRow>>? prefetchedEventsByFlowId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (_journalBackfillCompletedForUserId == user.id) return;
    _journalBackfillCompletedForUserId = user.id;

    final today = DateUtils.dateOnly(DateTime.now());
    final relevantDates = <DateTime>{};
    for (final flow in flows) {
      final flowEvents = prefetchedEventsByFlowId?[flow.id];
      final range = await _resolveTrackerRange(
        flow,
        prefetchedEvents: flowEvents,
      );
      if (range == null) continue;
      final scheduledDates = await _resolveScheduledFlowDates(
        flow,
        prefetchedEvents: flowEvents,
        range: range,
      );
      for (final date in scheduledDates) {
        if (!date.isAfter(today)) {
          relevantDates.add(date);
        }
      }
    }
    if (relevantDates.isEmpty) return;

    final sortedDates = relevantDates.toList()..sort();
    final startDate = sortedDates.first;
    final endDate = sortedDates.last;

    try {
      final rows = await _client
          .from('journal_entries')
          .select('greg_date, body')
          .eq('user_id', user.id)
          .gte('greg_date', _dateKey(startDate))
          .lte('greg_date', _dateKey(endDate));

      final bodyByDate = <String, String>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final dateKey = row['greg_date']?.toString();
        final body = row['body']?.toString();
        if (dateKey == null || body == null || body.isEmpty) continue;
        bodyByDate[dateKey] = body;
      }

      for (final date in sortedDates) {
        final body = bodyByDate[_dateKey(date)];
        if (body == null || body.isEmpty) continue;
        final badges = _extractJournalBadgesFromBody(body);
        if (badges.isEmpty) continue;
        await syncJournalBadgesForDate(
          localDate: date,
          badges: badges,
          source: 'tracker_backfill',
        );
      }
    } catch (_) {
      // Best-effort hydration only.
    }
  }

  List<EventBadgeToken> _extractJournalBadgesFromBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];
    try {
      if (trimmed.startsWith('{') && trimmed.contains('"version"')) {
        final doc = JournalDocument.fromJson(
          jsonDecode(trimmed) as Map<String, dynamic>,
        );
        return JournalBadgeUtils.tokensFromDocument(doc);
      }
    } catch (_) {
      // Fall through to raw token extraction.
    }
    return JournalBadgeUtils.extractRawTokens(body)
        .map(JournalBadgeUtils.parseRawToken)
        .whereType<EventBadgeToken>()
        .toList();
  }

  Future<List<DateTime>> _resolveScheduledFlowDates(
    FlowRow flow, {
    List<FlowEventRow>? prefetchedEvents,
    _ResolvedFlowTrackerRange? range,
  }) async {
    List<FlowEventRow> events = prefetchedEvents ?? const <FlowEventRow>[];
    if (events.isEmpty) {
      events = await _eventsRepo.getEventsForFlow(flow.id);
    }
    final eventDates = _extractScheduledFlowDates(events);
    if (eventDates.isNotEmpty) {
      return eventDates;
    }

    final ruleDates = _extractRuleLocalDates(flow.rules);
    if (ruleDates.isNotEmpty) {
      return ruleDates;
    }

    final resolvedRange =
        range ?? await _resolveTrackerRange(flow, prefetchedEvents: events);
    if (resolvedRange == null || resolvedRange.flowLengthDays <= 0) {
      return const [];
    }
    return List<DateTime>.generate(
      resolvedRange.flowLengthDays,
      (index) => resolvedRange.startDate.add(Duration(days: index)),
    );
  }

  List<DateTime> _extractScheduledFlowDates(List<FlowEventRow> events) {
    final primaryDates = <DateTime>{};
    final fallbackDates = <DateTime>{};
    for (final event in events) {
      final localDate = normalizeDateOnly(event.startsAtUtc.toLocal());
      if (localDate == null) continue;
      fallbackDates.add(localDate);
      if (!_looksLikeReflectionEvent(event)) {
        primaryDates.add(localDate);
      }
    }
    final sortedPrimary = primaryDates.toList()..sort();
    if (sortedPrimary.isNotEmpty) {
      return sortedPrimary;
    }
    final sortedFallback = fallbackDates.toList()..sort();
    return sortedFallback;
  }

  Map<String, int> _countTrackedEventsByDate(List<FlowEventRow> events) {
    final counts = <String, int>{};
    for (final event in events) {
      final category = event.category?.trim().toLowerCase();
      if (category == 'done' || category == 'tombstone') {
        continue;
      }
      final localDate = normalizeDateOnly(event.startsAtUtc.toLocal());
      if (localDate == null) continue;
      final dateKey = _dateKey(localDate);
      counts[dateKey] = (counts[dateKey] ?? 0) + 1;
    }
    return counts;
  }

  _JournalTrackedEventRow _flowEventToTrackedEventRow(FlowEventRow event) {
    return (
      id: event.id,
      clientEventId: event.clientEventId,
      title: event.title,
      detail: event.detail,
      startsAtLocal: event.startsAtUtc.toLocal(),
      endsAtLocal: event.endsAtUtc?.toLocal(),
      flowId: event.flowLocalId ?? -1,
      category: event.category,
    );
  }

  Map<int, List<_JournalBadgeMatch>> _matchJournalBadgesToFlowEvents({
    required List<EventBadgeToken> badges,
    required List<_JournalTrackedEventRow> events,
    required DateTime localDate,
  }) {
    if (badges.isEmpty || events.isEmpty) {
      return const <int, List<_JournalBadgeMatch>>{};
    }

    final remaining = List<_JournalTrackedEventRow>.from(events);
    final matches = <int, List<_JournalBadgeMatch>>{};
    for (final badge in badges) {
      final matchedEvent = _findBestTrackedEventMatch(
        badge: badge,
        candidates: remaining,
        localDate: localDate,
      );
      if (matchedEvent == null) continue;
      remaining.remove(matchedEvent);
      final isReflection = _looksLikeReflectionTrackedEvent(matchedEvent);
      matches
          .putIfAbsent(matchedEvent.flowId, () => <_JournalBadgeMatch>[])
          .add(
            _JournalBadgeMatch(
              event: matchedEvent,
              badge: badge,
              isReflection: isReflection,
              badgeCode: isReflection ? 'reflection_logged' : 'event_logged',
            ),
          );
    }
    return matches;
  }

  _JournalTrackedEventRow? _findBestTrackedEventMatch({
    required EventBadgeToken badge,
    required List<_JournalTrackedEventRow> candidates,
    required DateTime localDate,
  }) {
    if (candidates.isEmpty) return null;

    final badgeEventId = normalizeFlowText(badge.eventId);
    if (badgeEventId != null) {
      for (final candidate in candidates) {
        if (candidate.id == badgeEventId ||
            candidate.clientEventId == badgeEventId) {
          return candidate;
        }
      }
    }

    final normalizedTitle = _normalizeMatchText(badge.title);
    final compactTitle = _compactMatchText(badge.title);
    final badgeDate = normalizeDateOnly(badge.start?.toLocal());
    if (badgeDate != null && !_sameDate(badgeDate, localDate)) {
      return null;
    }
    final badgeStartMinute = _minutesSinceMidnight(badge.start?.toLocal());
    final badgeEndMinute = _minutesSinceMidnight(badge.end?.toLocal());

    int scoreCandidate(_JournalTrackedEventRow candidate) {
      var score = 0;
      final title = _normalizeMatchText(candidate.title);
      final detail = _normalizeMatchText(candidate.detail);
      final compactCandidateTitle = _compactMatchText(candidate.title);
      final compactCandidateDetail = _compactMatchText(candidate.detail);
      if (normalizedTitle.isNotEmpty &&
          (title == normalizedTitle || detail == normalizedTitle)) {
        score += 60;
      } else if (normalizedTitle.isNotEmpty &&
          (title.contains(normalizedTitle) ||
              normalizedTitle.contains(title) ||
              detail.contains(normalizedTitle) ||
              normalizedTitle.contains(detail))) {
        score += 40;
      } else if (compactTitle.isNotEmpty &&
          (compactCandidateTitle == compactTitle ||
              compactCandidateDetail == compactTitle)) {
        score += 35;
      }
      final candidateStartMinute = _minutesSinceMidnight(
        candidate.startsAtLocal,
      );
      if (badgeStartMinute != null &&
          candidateStartMinute == badgeStartMinute) {
        score += 30;
      }
      final candidateEndMinute = _minutesSinceMidnight(candidate.endsAtLocal);
      if (badgeEndMinute != null &&
          candidateEndMinute != null &&
          badgeEndMinute == candidateEndMinute) {
        score += 10;
      }
      return score;
    }

    _JournalTrackedEventRow? best;
    var bestScore = 0;
    for (final candidate in candidates) {
      final score = scoreCandidate(candidate);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    if (bestScore > 0) return best;

    if (badgeStartMinute == null) {
      return null;
    }
    final sameMinute = candidates.where((candidate) {
      return _minutesSinceMidnight(candidate.startsAtLocal) == badgeStartMinute;
    }).toList();
    if (sameMinute.length == 1) {
      return sameMinute.first;
    }
    return null;
  }

  FlowEventRow _trackedEventToFlowEventRow(_JournalTrackedEventRow event) {
    return (
      id: event.id,
      clientEventId: event.clientEventId,
      title: event.title,
      detail: event.detail,
      location: null,
      allDay: false,
      startsAtUtc: event.startsAtLocal.toUtc(),
      endsAtUtc: event.endsAtLocal?.toUtc(),
      flowLocalId: event.flowId,
      category: event.category,
    );
  }

  String _normalizeMatchText(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _compactMatchText(String? value) {
    return _normalizeMatchText(value).replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  int? _minutesSinceMidnight(DateTime? value) {
    if (value == null) return null;
    return value.hour * 60 + value.minute;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _trackProgressMilestones({
    required FlowRow flow,
    required int flowDayIndex,
    required _FlowProgressAggregate previous,
    required _FlowProgressAggregate current,
    required String source,
  }) async {
    if (previous.score < 7.0 && current.score >= 7.0) {
      await _eventsRepo.track(
        event: 'flow_progress_score_7_reached',
        source: source,
        properties: {
          'flow_id': flow.id,
          'flow_day_index': flowDayIndex,
          'progress_score': current.score,
          'flow_length_days': flow.resolvedFlowLengthDays,
        },
      );
    }

    final flowLengthDays = flow.resolvedFlowLengthDays ?? 0;
    if (flowLengthDays >= 10 && flowDayIndex == 10) {
      final previousDayScore = previous.days[10]?.score ?? 0.0;
      final currentDayScore = current.days[10]?.score ?? 0.0;
      if (previousDayScore <= 0.0 && currentDayScore > 0.0) {
        await _eventsRepo.track(
          event: 'flow_day_10_reached',
          source: source,
          properties: {
            'flow_id': flow.id,
            'progress_score': current.score,
            'flow_length_days': flowLengthDays,
          },
        );
      }
    }
  }
}
