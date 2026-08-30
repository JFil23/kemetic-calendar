import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/flows_repo.dart';
import '../../../data/profile_repo.dart';
import '../../../data/shared_calendar_models.dart';
import '../../../data/shared_calendars_repo.dart';
import '../../../data/shared_practice_models.dart';
import '../../../data/shared_practice_repo.dart';
import '../../../data/user_events_repo.dart';
import '../the_reading_house_flow.dart';
import '../track_sky_flow.dart';

@immutable
class ReadingHouseSnapshot {
  const ReadingHouseSnapshot({
    required this.flowId,
    required this.calendarId,
    required this.plan,
    required this.sittings,
    required this.openDoors,
    required this.members,
    required this.held,
    required this.canEdit,
    required this.canManageMembership,
    required this.isSharedHouse,
  });

  final int? flowId;
  final String? calendarId;
  final ReadingHousePlan plan;
  final List<ReadingHouseSitting> sittings;
  final bool openDoors;
  final List<SharedCalendarMember> members;
  final bool held;
  final bool canEdit;
  final bool canManageMembership;
  final bool isSharedHouse;

  int get pendingInviteCount => members
      .where((member) => member.status == SharedCalendarInviteStatus.pending)
      .length;

  bool get isScheduled =>
      sittings.any((sitting) => sitting.scheduledDate != null);
}

ReadingHouseSnapshot readingHouseSnapshotFromSharedPracticeRoom(
  SharedPracticeRoomSnapshot roomSnapshot,
) {
  final source = roomSnapshot.sourceFlow;
  if (source == null) {
    throw StateError('Reading House source flow is unavailable.');
  }
  final metadata = source['ai_metadata'] is Map
      ? Map<String, dynamic>.from(source['ai_metadata'] as Map)
      : null;
  final notes = source['notes']?.toString();
  final plan = readingHousePlanFromMetadata(
    metadata,
    fallback: readingHousePlanFromFlowNotes(notes),
  );
  final members = roomSnapshot.members
      .map(
        (member) => SharedCalendarMember(
          userId: member.userId,
          role: sharedCalendarRoleFromString(member.role ?? 'viewer'),
          status: SharedCalendarInviteStatus.accepted,
          handle: member.handle,
          displayName: member.displayName,
          avatarUrl: member.avatarUrl,
        ),
      )
      .toList(growable: false);
  return ReadingHouseSnapshot(
    flowId: (source['id'] as num?)?.toInt() ?? roomSnapshot.room.sourceFlowId,
    calendarId: source['calendar_id']?.toString() ?? roomSnapshot.calendar.id,
    plan: plan,
    sittings: List<ReadingHouseSitting>.unmodifiable(
      readingHouseSittingsFromMetadata(metadata),
    ),
    openDoors: readingHouseOpenDoorsFromMetadata(
      metadata,
      fallback:
          roomSnapshot.room.visibility == SharedPracticeRoomVisibility.public,
    ),
    members: List<SharedCalendarMember>.unmodifiable(members),
    held: true,
    canEdit: roomSnapshot.viewerCanEdit,
    canManageMembership:
        roomSnapshot.viewerCanEdit && roomSnapshot.viewerCanManage,
    isSharedHouse: true,
  );
}

abstract class ReadingHouseAuthority {
  String? get currentUserId;

  Future<ReadingHouseSnapshot> load({
    required int flowId,
    required ReadingHousePlan fallbackPlan,
    required List<ReadingHouseSitting> fallbackSittings,
  });

  Future<ReadingHouseSnapshot> ensureHouse({
    int? flowId,
    String? calendarId,
    required String personalCalendarId,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  });

  Future<ReadingHouseSnapshot> updateHeldHouse({
    required ReadingHouseSnapshot house,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  });

  Future<ReadingHouseSnapshot> saveSitting({
    required ReadingHouseSnapshot house,
    required ReadingHouseSitting sitting,
    required List<ReadingHouseSitting> sittings,
    required TrackSkyTimeZone timezone,
  });

  Future<List<UserSearchResult>> searchReaders(
    String query, {
    required Iterable<String> excludedUserIds,
  });

  Future<SharedCalendarMember> inviteReader({
    required ReadingHouseSnapshot house,
    required UserSearchResult reader,
  });

  Future<List<SharedCalendarMember>> refreshMembers({
    required ReadingHouseSnapshot house,
  });
}

class LiveReadingHouseAuthority implements ReadingHouseAuthority {
  LiveReadingHouseAuthority(SupabaseClient client)
    : _client = client,
      _flows = FlowsRepo(client),
      _events = UserEventsRepo(client),
      _calendars = SharedCalendarsRepo(client),
      _practice = SharedPracticeRepo(client),
      _profiles = ProfileRepo(client);

  final SupabaseClient _client;
  final FlowsRepo _flows;
  final UserEventsRepo _events;
  final SharedCalendarsRepo _calendars;
  final SharedPracticeRepo _practice;
  final ProfileRepo _profiles;

  Future<T> _measure<T>(String operation, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[ReadingHouseTiming] $operation=${stopwatch.elapsedMilliseconds}ms',
        );
      }
    }
  }

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<ReadingHouseSnapshot> load({
    required int flowId,
    required ReadingHousePlan fallbackPlan,
    required List<ReadingHouseSitting> fallbackSittings,
  }) => _measure('plan_reload', () async {
    final row = await _flows.getFlowById(flowId);
    if (row == null) throw StateError('Reading House $flowId was not found.');
    return _snapshotFromRow(
      row,
      fallbackPlan: fallbackPlan,
      fallbackSittings: fallbackSittings,
    );
  });

  @override
  Future<ReadingHouseSnapshot> ensureHouse({
    int? flowId,
    String? calendarId,
    required String personalCalendarId,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  }) => _measure('hold_or_update_house', () async {
    // Reaching this authority is the explicit "Hold this house" boundary for
    // a new house. Progressive edits only call it after the house is held.
    final heldPlan = plan.copyWith(state: kReadingHouseHeldState);
    final existing = flowId != null && flowId > 0
        ? await _flows.getFlowById(flowId)
        : null;
    var targetCalendarId = _firstNonempty(<String?>[
      existing?.calendarId,
      calendarId,
      personalCalendarId,
    ]);
    if (targetCalendarId == null) {
      throw StateError('A calendar is required to hold this Reading House.');
    }

    if (!heldPlan.isSolo) {
      targetCalendarId = await _ensureSharedHouseCalendar(
        flowId: existing?.id,
        currentCalendarId: targetCalendarId,
        personalCalendarId: personalCalendarId,
        bookTitle: heldPlan.displayBookTitle,
      );
    } else if (existing != null && targetCalendarId != personalCalendarId) {
      targetCalendarId = await _moveSoloHouseToPersonal(
        flowId: existing.id,
        currentCalendarId: targetCalendarId,
        personalCalendarId: personalCalendarId,
      );
    }

    final normalized = normalizeReadingHouseSittingOrder(sittings);
    final savedFlowId = await _persistFlowDefinition(
      existing: existing,
      calendarId: targetCalendarId,
      plan: heldPlan,
      sittings: normalized,
      openDoors: openDoors,
      timezone: timezone,
    );

    await _materializeScheduledSittings(
      flowId: savedFlowId,
      calendarId: targetCalendarId,
      plan: heldPlan,
      sittings: normalized,
      timezone: timezone,
    );

    if (!heldPlan.isSolo) {
      await _updateSharedPracticeVisibility(
        flowId: savedFlowId,
        calendarId: targetCalendarId,
        openDoors: openDoors,
      );
    }

    unawaited(_flows.clearMyFiledFlowsCache());
    final row = await _flows.getFlowById(savedFlowId);
    if (row == null) {
      throw StateError('Reading House $savedFlowId could not be reloaded.');
    }
    return _snapshotFromRow(
      row,
      fallbackPlan: heldPlan,
      fallbackSittings: normalized,
    );
  });

  @override
  Future<ReadingHouseSnapshot> updateHeldHouse({
    required ReadingHouseSnapshot house,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  }) => _measure('update_house_details', () async {
    final flowId = house.flowId;
    final calendarId = house.calendarId?.trim();
    if (flowId == null ||
        flowId <= 0 ||
        calendarId == null ||
        calendarId.isEmpty) {
      throw StateError('Hold the Reading House before updating it.');
    }
    if (!house.canEdit) {
      throw StateError('Only an editor can update this Reading House.');
    }
    if (plan.isSolo != house.plan.isSolo) {
      throw StateError(
        'Reading House mode changes must use the calendar transition path.',
      );
    }

    final existing = await _flows.getFlowById(flowId);
    if (existing == null) {
      throw StateError('Reading House $flowId was not found.');
    }
    final existingPlan = readingHousePlanFromMetadata(
      existing.aiMetadata,
      fallback: readingHousePlanFromFlowNotes(
        existing.notes,
        fallback: house.plan,
      ),
    );
    final heldPlan = plan.copyWith(state: kReadingHouseHeldState);
    final normalized = normalizeReadingHouseSittingOrder(sittings);
    final effectiveOpenDoors = !heldPlan.isSolo && openDoors;
    await _persistFlowDefinition(
      existing: existing,
      calendarId: calendarId,
      plan: heldPlan,
      sittings: normalized,
      openDoors: effectiveOpenDoors,
      timezone: timezone,
    );

    if (existingPlan.displayQuestion != heldPlan.displayQuestion) {
      await _materializeScheduledSittings(
        flowId: flowId,
        calendarId: calendarId,
        plan: heldPlan,
        sittings: normalized,
        timezone: timezone,
      );
    }

    if (!heldPlan.isSolo && effectiveOpenDoors != house.openDoors) {
      await _updateSharedPracticeVisibility(
        flowId: flowId,
        calendarId: calendarId,
        openDoors: effectiveOpenDoors,
      );
    }

    unawaited(_flows.clearMyFiledFlowsCache());
    return _snapshotWith(
      house,
      plan: heldPlan,
      sittings: normalized,
      openDoors: effectiveOpenDoors,
    );
  });

  @override
  Future<ReadingHouseSnapshot> saveSitting({
    required ReadingHouseSnapshot house,
    required ReadingHouseSitting sitting,
    required List<ReadingHouseSitting> sittings,
    required TrackSkyTimeZone timezone,
  }) => _measure('date_time_or_sitting_save', () async {
    final flowId = house.flowId;
    final calendarId = house.calendarId?.trim();
    if (flowId == null ||
        flowId <= 0 ||
        calendarId == null ||
        calendarId.isEmpty) {
      throw StateError('Hold the Reading House before saving a sitting.');
    }
    if (!house.canEdit) {
      throw StateError('Only an editor can update a sitting.');
    }

    final existing = await _flows.getFlowById(flowId);
    if (existing == null) {
      throw StateError('Reading House $flowId was not found.');
    }
    final heldPlan = house.plan.copyWith(state: kReadingHouseHeldState);
    final normalized = normalizeReadingHouseSittingOrder(sittings);
    final persistedSitting = normalized.firstWhere(
      (candidate) => candidate.eventNumber == sitting.eventNumber,
      orElse: () => throw StateError('The sitting is no longer in the house.'),
    );
    ReadingHouseSitting? previous;
    for (final candidate in house.sittings) {
      if (candidate.eventNumber == sitting.eventNumber) {
        previous = candidate;
        break;
      }
    }

    await _persistFlowDefinition(
      existing: existing,
      calendarId: calendarId,
      plan: heldPlan,
      sittings: normalized,
      openDoors: house.openDoors,
      timezone: timezone,
    );
    await _materializeAffectedSitting(
      flowId: flowId,
      calendarId: calendarId,
      plan: heldPlan,
      previous: previous,
      sitting: persistedSitting,
      timezone: timezone,
    );

    unawaited(_flows.clearMyFiledFlowsCache());
    return _snapshotWith(
      house,
      plan: heldPlan,
      sittings: normalized,
      openDoors: house.openDoors,
    );
  });

  @override
  Future<List<UserSearchResult>> searchReaders(
    String query, {
    required Iterable<String> excludedUserIds,
  }) => _measure('profile_search', () async {
    final excluded = <String>{
      ...excludedUserIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
      if (currentUserId?.trim().isNotEmpty == true) currentUserId!.trim(),
    };
    final results = await _profiles.searchUsers(query);
    final filtered = results
        .where((result) => !excluded.contains(result.userId.trim()))
        .toList(growable: false);
    filtered.sort((a, b) {
      final aName = (a.displayName ?? a.handle ?? '').toLowerCase();
      final bName = (b.displayName ?? b.handle ?? '').toLowerCase();
      return aName.compareTo(bName);
    });
    return List<UserSearchResult>.unmodifiable(filtered.take(10));
  });

  @override
  Future<SharedCalendarMember> inviteReader({
    required ReadingHouseSnapshot house,
    required UserSearchResult reader,
  }) => _measure('invite_reader', () async {
    final flowId = house.flowId;
    final calendarId = house.calendarId?.trim();
    if (flowId == null ||
        flowId <= 0 ||
        calendarId == null ||
        calendarId.isEmpty) {
      throw StateError('Hold the Reading House before inviting readers.');
    }
    if (!house.canManageMembership) {
      throw StateError('Only the host can invite readers.');
    }
    await _calendars.inviteUser(
      calendarId: calendarId,
      userId: reader.userId,
      role: SharedCalendarRole.viewer,
      calendarName: _sharedCalendarName(house.plan.displayBookTitle),
      calendarColorValue: 0x3FA98A,
    );
    return SharedCalendarMember(
      userId: reader.userId.trim(),
      role: SharedCalendarRole.viewer,
      status: SharedCalendarInviteStatus.pending,
      invitedBy: currentUserId,
      invitedAt: DateTime.now().toUtc(),
      displayName: reader.displayName?.trim(),
      handle: reader.handle?.trim(),
    );
  });

  @override
  Future<List<SharedCalendarMember>> refreshMembers({
    required ReadingHouseSnapshot house,
  }) => _measure('member_refresh', () async {
    final calendarId = house.calendarId?.trim();
    if (!house.isSharedHouse || calendarId == null || calendarId.isEmpty) {
      return const <SharedCalendarMember>[];
    }
    final members = await _calendars.listMembers(
      calendarId,
      includePending: house.canManageMembership,
    );
    return List<SharedCalendarMember>.unmodifiable(members);
  });

  Future<int> _persistFlowDefinition({
    required FlowRow? existing,
    required String calendarId,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
    required TrackSkyTimeZone timezone,
  }) => _measure('flow_definition_upsert', () async {
    final scheduled = sittings
        .where((sitting) => sitting.scheduledDate != null)
        .toList(growable: false);
    final dates =
        scheduled
            .map((sitting) => DateUtils.dateOnly(sitting.scheduledDate!))
            .toSet()
            .toList()
          ..sort();
    final metadata = <String, dynamic>{
      ...?existing?.aiMetadata,
      'flow_key': kReadingHouseFlowKey,
      kReadingHouseMetadataKey: readingHouseMetadata(
        plan: plan,
        sittings: sittings,
        openDoors: !plan.isSolo && openDoors,
      ),
    };
    final notes = <String>[
      'mode=gregorian',
      'split=1',
      'maat=$kReadingHouseFlowKey',
      'reading_house_tz=${timezone.key}',
      ...readingHouseFlowNoteTokens(plan),
    ].join(';');
    final rules = dates.isEmpty
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'dates',
              'dates': dates
                  .map((date) => date.millisecondsSinceEpoch)
                  .toList(growable: false),
              'allDay': true,
            },
          ];

    return _events.upsertFlow(
      id: existing?.id,
      name: kReadingHouseTitle,
      color: 0x3FA98A,
      active: true,
      calendarId: calendarId,
      startDate: dates.isEmpty ? null : dates.first,
      endDate: dates.isEmpty ? null : dates.last,
      clearStartDate: dates.isEmpty,
      clearEndDate: dates.isEmpty,
      notes: notes,
      rules: jsonEncode(rules),
      originType: 'template',
      aiMetadata: metadata,
    );
  });

  ReadingHouseSnapshot _snapshotWith(
    ReadingHouseSnapshot house, {
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required bool openDoors,
  }) {
    return ReadingHouseSnapshot(
      flowId: house.flowId,
      calendarId: house.calendarId,
      plan: plan,
      sittings: List<ReadingHouseSitting>.unmodifiable(sittings),
      openDoors: openDoors,
      members: house.members,
      held: true,
      canEdit: house.canEdit,
      canManageMembership: house.canManageMembership,
      isSharedHouse: house.isSharedHouse,
    );
  }

  Future<void> _updateSharedPracticeVisibility({
    required int flowId,
    required String calendarId,
    required bool openDoors,
  }) => _measure('commons_visibility_update', () async {
    final roomId = await _practice.ensureSharedExperienceForFlow(
      flowId: flowId,
      calendarId: calendarId,
    );
    if (roomId == null) return;
    await _practice.setSharedPracticeVisibility(
      roomId: roomId,
      visibility: openDoors
          ? SharedPracticeRoomVisibility.public
          : SharedPracticeRoomVisibility.unlisted,
      joinPolicy: openDoors
          ? SharedPracticeJoinPolicy.ownerApproval
          : SharedPracticeJoinPolicy.closed,
    );
  });

  Future<void> _materializeAffectedSitting({
    required int flowId,
    required String calendarId,
    required ReadingHousePlan plan,
    required ReadingHouseSitting? previous,
    required ReadingHouseSitting sitting,
    required TrackSkyTimeZone timezone,
  }) => _measure('sitting_event_materialization', () async {
    if (previous?.scheduledDate == null && sitting.scheduledDate == null) {
      return;
    }

    final actionId = readingHouseActionId(sitting);
    final canonicalId = readingHouseClientEventId(
      flowId: flowId,
      eventNumber: sitting.eventNumber,
    );
    final rows = await _client
        .from('user_events')
        .select('client_event_id')
        .eq('flow_local_id', flowId)
        .eq('action_id', actionId)
        .neq('category', 'tombstone');
    final existingIds = (rows as List)
        .whereType<Map>()
        .map((row) => row['client_event_id']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (sitting.scheduledDate == null) {
      for (final clientId in existingIds) {
        await _events.deleteByClientId(
          clientId,
          semantic: 'reading_house_sitting_unplaced',
          suppressesClient: false,
          sourceFeature: 'LiveReadingHouseAuthority',
        );
      }
      return;
    }

    final clientId = existingIds.contains(canonicalId)
        ? canonicalId
        : (existingIds.isEmpty ? canonicalId : existingIds.first);
    for (final duplicate in existingIds.where((id) => id != clientId)) {
      await _events.deleteByClientId(
        duplicate,
        semantic: 'reading_house_duplicate_materialization',
        suppressesClient: false,
        sourceFeature: 'LiveReadingHouseAuthority',
      );
    }
    final schedule = readingHouseScheduleForDate(
      sitting,
      sitting.scheduledDate!,
      timezone,
      hour: sitting.hour,
      minute: sitting.minute,
    );
    await _events.upsertByClientId(
      clientEventId: clientId,
      title: readingHouseSittingTitle(sitting),
      startsAtUtc: schedule.startUtc,
      endsAtUtc: schedule.endUtc,
      detail: readingHouseDetailText(sitting, plan: plan),
      flowLocalId: flowId,
      category: 'Study',
      actionId: actionId,
      behaviorPayload: readingHouseBehaviorPayload(
        sitting: sitting,
        schedule: schedule,
        plan: plan,
      ),
      calendarId: calendarId,
      caller: 'reading_house_authority_targeted',
    );
  });

  Future<ReadingHouseSnapshot> _snapshotFromRow(
    FlowRow row, {
    required ReadingHousePlan fallbackPlan,
    required List<ReadingHouseSitting> fallbackSittings,
  }) async {
    var eventFallbackPlan = fallbackPlan;
    var eventFallbackSittings = fallbackSittings;
    if (row.aiMetadata?[kReadingHouseMetadataKey] is! Map) {
      final eventRows = await _events.getEventsForFlow(
        row.id,
        flowEventsOnly: true,
      );
      final recovered = <ReadingHouseSitting>[];
      for (final event in eventRows) {
        if (!isReadingHouseFlowReference(
          flowName: row.name,
          flowNotes: row.notes,
          actionId: event.actionId,
          behaviorPayload: event.behaviorPayload,
        )) {
          continue;
        }
        final sitting = readingHouseSittingForEvent(
          title: event.title,
          actionId: event.actionId,
          behaviorPayload: event.behaviorPayload,
        );
        if (sitting != null) recovered.add(sitting);
        eventFallbackPlan = readingHousePlanFromPayload(
          event.behaviorPayload,
          fallback: eventFallbackPlan,
        );
      }
      recovered.sort((a, b) => a.eventNumber.compareTo(b.eventNumber));
      if (recovered.isNotEmpty) {
        eventFallbackSittings = normalizeReadingHouseSittingOrder(recovered);
      }
    }
    final plan = readingHousePlanFromMetadata(
      row.aiMetadata,
      fallback: readingHousePlanFromFlowNotes(
        row.notes,
        fallback: eventFallbackPlan,
      ),
    );
    final sittings = readingHouseSittingsFromMetadata(
      row.aiMetadata,
      fallback: eventFallbackSittings,
    );
    final hasReadingHouseMetadata =
        row.aiMetadata?[kReadingHouseMetadataKey] is Map;
    final calendars = await _calendars.getAcceptedCalendars();
    SharedCalendarSummary? calendar;
    for (final candidate in calendars) {
      if (candidate.id == row.calendarId) {
        calendar = candidate;
        break;
      }
    }
    final isShared = calendar != null && !calendar.isPersonal;
    final members = isShared && calendar.canSeeMemberRoster
        ? await _calendars.listMembers(
            calendar.id,
            includePending: calendar.canSeePendingInvites,
            expectedMemberCount: calendar.memberCount,
            expectedPendingCount: calendar.pendingInviteCount,
          )
        : const <SharedCalendarMember>[];
    return ReadingHouseSnapshot(
      flowId: row.id,
      calendarId: row.calendarId,
      plan: plan,
      sittings: List<ReadingHouseSitting>.unmodifiable(sittings),
      openDoors: readingHouseOpenDoorsFromMetadata(row.aiMetadata),
      members: List<SharedCalendarMember>.unmodifiable(members),
      // Pre-metadata Reading Houses were only persisted by the old explicit
      // Add Flow action. Preserve them as held while requiring the explicit
      // held_house lifecycle for every metadata-backed house.
      held: plan.isHeld || !hasReadingHouseMetadata,
      canEdit: calendar?.canEdit ?? row.userId == currentUserId,
      canManageMembership: calendar?.canManageMembership ?? false,
      isSharedHouse: isShared,
    );
  }

  Future<String> _ensureSharedHouseCalendar({
    required int? flowId,
    required String currentCalendarId,
    required String personalCalendarId,
    required String bookTitle,
  }) async {
    final calendars = await _calendars.getAcceptedCalendars();
    for (final calendar in calendars) {
      if (calendar.id == currentCalendarId && !calendar.isPersonal) {
        return currentCalendarId;
      }
    }
    if (currentCalendarId != personalCalendarId && flowId != null) {
      return currentCalendarId;
    }
    final created = await _calendars.createCalendar(
      name: _sharedCalendarName(bookTitle),
      colorValue: 0x3FA98A,
    );
    if (flowId != null && flowId > 0) {
      await _flows.updateCalendar(id: flowId, calendarId: created);
      await _events.updateCalendarForFlowEvents(
        flowId: flowId,
        calendarId: created,
      );
    }
    return created;
  }

  Future<String> _moveSoloHouseToPersonal({
    required int flowId,
    required String currentCalendarId,
    required String personalCalendarId,
  }) async {
    final members = await _calendars.listMembers(
      currentCalendarId,
      includePending: true,
    );
    if (members.any((member) => !member.isOwner)) {
      throw StateError(
        'Remove invited readers before changing this house to Solo study.',
      );
    }
    final room = await _client
        .from('shared_practice_rooms')
        .select('id')
        .eq('shared_flow_id', flowId)
        .eq('calendar_id', currentCalendarId)
        .eq('status', 'active')
        .maybeSingle();
    final roomId = room?['id']?.toString().trim();
    if (roomId != null && roomId.isNotEmpty) {
      await _practice.setSharedPracticeVisibility(
        roomId: roomId,
        visibility: SharedPracticeRoomVisibility.private,
        joinPolicy: SharedPracticeJoinPolicy.closed,
      );
    }
    await _flows.updateCalendar(id: flowId, calendarId: personalCalendarId);
    await _events.updateCalendarForFlowEvents(
      flowId: flowId,
      calendarId: personalCalendarId,
    );
    return personalCalendarId;
  }

  Future<void> _materializeScheduledSittings({
    required int flowId,
    required String calendarId,
    required ReadingHousePlan plan,
    required List<ReadingHouseSitting> sittings,
    required TrackSkyTimeZone timezone,
  }) async {
    final rows = await _client
        .from('user_events')
        .select('client_event_id, action_id')
        .eq('flow_local_id', flowId)
        .neq('category', 'tombstone');
    final existingByAction = <String, List<String>>{};
    for (final raw in (rows as List).whereType<Map>()) {
      final actionId = raw['action_id']?.toString().trim();
      final clientId = raw['client_event_id']?.toString().trim();
      if (actionId == null ||
          actionId.isEmpty ||
          clientId == null ||
          clientId.isEmpty) {
        continue;
      }
      existingByAction.putIfAbsent(actionId, () => <String>[]).add(clientId);
    }

    final scheduled = sittings
        .where((sitting) => sitting.scheduledDate != null)
        .toList(growable: false);
    final activeActions = scheduled.map(readingHouseActionId).toSet();
    for (final entry in existingByAction.entries) {
      if (!entry.key.startsWith('$kReadingHouseFlowKey-sitting-') ||
          activeActions.contains(entry.key)) {
        continue;
      }
      for (final clientId in entry.value) {
        await _events.deleteByClientId(
          clientId,
          semantic: 'reading_house_sitting_removed',
          suppressesClient: false,
          sourceFeature: 'LiveReadingHouseAuthority',
        );
      }
    }

    for (final sitting in scheduled) {
      final actionId = readingHouseActionId(sitting);
      final canonicalId = readingHouseClientEventId(
        flowId: flowId,
        eventNumber: sitting.eventNumber,
      );
      final existingIds = existingByAction[actionId] ?? const <String>[];
      final clientId = existingIds.contains(canonicalId)
          ? canonicalId
          : (existingIds.isEmpty ? canonicalId : existingIds.first);
      for (final duplicate in existingIds.where((id) => id != clientId)) {
        await _events.deleteByClientId(
          duplicate,
          semantic: 'reading_house_duplicate_materialization',
          suppressesClient: false,
          sourceFeature: 'LiveReadingHouseAuthority',
        );
      }
      final schedule = readingHouseScheduleForDate(
        sitting,
        sitting.scheduledDate!,
        timezone,
        hour: sitting.hour,
        minute: sitting.minute,
      );
      await _events.upsertByClientId(
        clientEventId: clientId,
        title: readingHouseSittingTitle(sitting),
        startsAtUtc: schedule.startUtc,
        endsAtUtc: schedule.endUtc,
        detail: readingHouseDetailText(sitting, plan: plan),
        flowLocalId: flowId,
        category: 'Study',
        actionId: actionId,
        behaviorPayload: readingHouseBehaviorPayload(
          sitting: sitting,
          schedule: schedule,
          plan: plan,
        ),
        calendarId: calendarId,
        caller: 'reading_house_authority',
      );
    }
  }
}

String readingHouseClientEventId({
  required int flowId,
  required int eventNumber,
}) => 'maat:reading-house:$flowId:sitting:$eventNumber';

String? _firstNonempty(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _sharedCalendarName(String bookTitle) {
  final clean = bookTitle.trim();
  if (clean.isEmpty || clean == kReadingHouseDefaultBookTitle) {
    return kReadingHouseTitle;
  }
  return 'Reading House · $clean';
}
