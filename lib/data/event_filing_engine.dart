import '../utils/flow_filter_engine.dart';
import '../utils/flow_visibility.dart';
import 'user_events_repo.dart';

const deletedEventRetention = Duration(days: 10);

enum FiledItemKind { note, flow, reminder }

enum FiledItemLifecycle { active, inactive, deleted }

class FilingJustification {
  const FilingJustification({
    this.activeUntil,
    this.dateLifecycle,
    this.itemKindReason,
    this.deletedReason,
    this.activeUntilReason,
    this.userTimezone,
    this.sharedCalendarSource = false,
    this.eventShareSource = false,
    this.flowShareSource = false,
    this.flowPostSource = false,
    this.flowSavedSource = false,
    this.activeReminderSource = false,
    this.scheduledNotificationSource = false,
    this.raw = const <String, dynamic>{},
  });

  final DateTime? activeUntil;
  final String? dateLifecycle;
  final String? itemKindReason;
  final String? deletedReason;
  final String? activeUntilReason;
  final String? userTimezone;
  final bool sharedCalendarSource;
  final bool eventShareSource;
  final bool flowShareSource;
  final bool flowPostSource;
  final bool flowSavedSource;
  final bool activeReminderSource;
  final bool scheduledNotificationSource;
  final Map<String, dynamic> raw;

  factory FilingJustification.fromBackendRow(Map<String, dynamic> row) {
    final rawReasons = row['filing_reasons'] is Map
        ? Map<String, dynamic>.from(row['filing_reasons'] as Map)
        : const <String, dynamic>{};
    return FilingJustification(
      activeUntil: _parseBackendDateTime(row['active_until']),
      dateLifecycle: row['date_lifecycle'] as String?,
      itemKindReason: row['reason_item_kind'] as String?,
      deletedReason: row['reason_deleted'] as String?,
      activeUntilReason: row['reason_active_until'] as String?,
      userTimezone: row['user_timezone'] as String?,
      sharedCalendarSource:
          (row['is_shared_calendar_source'] as bool?) ?? false,
      eventShareSource: (row['is_event_share_source'] as bool?) ?? false,
      flowShareSource: (row['is_flow_share_source'] as bool?) ?? false,
      flowPostSource: (row['is_flow_post_source'] as bool?) ?? false,
      flowSavedSource: (row['is_flow_saved_source'] as bool?) ?? false,
      activeReminderSource:
          (row['is_active_reminder_source'] as bool?) ?? false,
      scheduledNotificationSource:
          (row['is_scheduled_notification_source'] as bool?) ?? false,
      raw: rawReasons,
    );
  }
}

class FiledCalendarRef {
  const FiledCalendarRef({
    required this.id,
    this.name,
    this.color,
    this.isPersonal = true,
  });

  final String? id;
  final String? name;
  final int? color;
  final bool isPersonal;

  bool get isShared => !isPersonal;
}

class FiledEvent {
  const FiledEvent({
    required this.event,
    required this.kind,
    required this.lifecycle,
    required this.calendar,
    this.flowId,
    this.flowOwner,
    this.saved = false,
    this.shared = false,
    this.posted = false,
    this.backendLiveOnCalendar,
    this.justification = const FilingJustification(),
  });

  final UserEvent event;
  final FiledItemKind kind;
  final FiledItemLifecycle lifecycle;
  final FiledCalendarRef calendar;
  final int? flowId;
  final FlowRecordSnapshot? flowOwner;
  final bool saved;
  final bool shared;
  final bool posted;
  final bool? backendLiveOnCalendar;
  final FilingJustification justification;

  bool get isActive => lifecycle == FiledItemLifecycle.active;
  bool get isInactive => lifecycle == FiledItemLifecycle.inactive;
  bool get isDeleted => lifecycle == FiledItemLifecycle.deleted;
  bool get visibleOnCalendar =>
      backendLiveOnCalendar ?? (isActive && !isDeleted);

  factory FiledEvent.fromBackendRow(Map<String, dynamic> row) {
    final flowId = (row['filed_flow_id'] as num?)?.toInt();
    final flowOwner = flowId == null
        ? null
        : FlowRecordSnapshot(
            id: flowId,
            active: (row['flow_active'] as bool?) ?? false,
            isHidden: (row['flow_is_hidden'] as bool?) ?? false,
            isReminder: (row['flow_is_reminder'] as bool?) ?? false,
            isSaved: (row['flow_is_saved'] as bool?) ?? false,
            notes: row['flow_notes'] as String?,
          );

    return FiledEvent(
      event: UserEvent.fromRow(row),
      kind: _parseFiledItemKind(row['item_kind'] as String?),
      lifecycle: _parseFiledItemLifecycle(row['lifecycle'] as String?),
      calendar: FiledCalendarRef(
        id: row['calendar_id'] as String?,
        name: row['calendar_name'] as String?,
        color: (row['calendar_color'] as num?)?.toInt(),
        isPersonal: (row['calendar_is_personal'] as bool?) ?? true,
      ),
      flowId: flowId,
      flowOwner: flowOwner,
      saved: (row['is_saved'] as bool?) ?? false,
      shared: (row['is_shared'] as bool?) ?? false,
      posted: (row['is_posted'] as bool?) ?? false,
      backendLiveOnCalendar: row['live_on_calendar'] as bool?,
      justification: FilingJustification.fromBackendRow(row),
    );
  }
}

class FiledEventCabinet {
  const FiledEventCabinet(this.entries);

  factory FiledEventCabinet.fromBackendRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final entries = rows.map(FiledEvent.fromBackendRow).toList(growable: false)
      ..sort((a, b) {
        final byStart = a.event.startsAt.compareTo(b.event.startsAt);
        if (byStart != 0) return byStart;
        return a.event.id.compareTo(b.event.id);
      });
    return FiledEventCabinet(List<FiledEvent>.unmodifiable(entries));
  }

  final List<FiledEvent> entries;

  List<FiledEvent> get notes => _whereKind(FiledItemKind.note);
  List<FiledEvent> get flows => _whereKind(FiledItemKind.flow);
  List<FiledEvent> get reminders => _whereKind(FiledItemKind.reminder);
  List<FiledEvent> get active => _whereLifecycle(FiledItemLifecycle.active);
  List<FiledEvent> get inactive => _whereLifecycle(FiledItemLifecycle.inactive);
  List<FiledEvent> get deleted => _whereLifecycle(FiledItemLifecycle.deleted);
  List<FiledEvent> get saved => _whereFlag((entry) => entry.saved);
  List<FiledEvent> get shared => _whereFlag((entry) => entry.shared);
  List<FiledEvent> get posted => _whereFlag((entry) => entry.posted);

  List<FiledEvent> forCalendar(String calendarId) {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];
    return List<FiledEvent>.unmodifiable(
      entries.where((entry) => entry.calendar.id == trimmed),
    );
  }

  List<FiledEvent> activeForCalendar(String calendarId) {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];
    return List<FiledEvent>.unmodifiable(
      entries.where(
        (entry) => entry.calendar.id == trimmed && entry.visibleOnCalendar,
      ),
    );
  }

  List<UserEvent> activeEventsForCalendar(String calendarId) {
    return activeForCalendar(
      calendarId,
    ).map((entry) => entry.event).toList(growable: false);
  }

  Map<String, List<FiledEvent>> byCalendar() {
    final grouped = <String, List<FiledEvent>>{};
    for (final entry in entries) {
      final calendarId = entry.calendar.id;
      if (calendarId == null || calendarId.isEmpty) continue;
      grouped.putIfAbsent(calendarId, () => <FiledEvent>[]).add(entry);
    }
    return Map<String, List<FiledEvent>>.unmodifiable(
      grouped.map(
        (key, value) => MapEntry(key, List<FiledEvent>.unmodifiable(value)),
      ),
    );
  }

  List<FiledEvent> _whereKind(FiledItemKind kind) {
    return List<FiledEvent>.unmodifiable(
      entries.where((entry) => entry.kind == kind),
    );
  }

  List<FiledEvent> _whereLifecycle(FiledItemLifecycle lifecycle) {
    return List<FiledEvent>.unmodifiable(
      entries.where((entry) => entry.lifecycle == lifecycle),
    );
  }

  List<FiledEvent> _whereFlag(bool Function(FiledEvent entry) test) {
    return List<FiledEvent>.unmodifiable(entries.where(test));
  }
}

FiledItemKind _parseFiledItemKind(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'flow':
      return FiledItemKind.flow;
    case 'reminder':
      return FiledItemKind.reminder;
    case 'note':
    default:
      return FiledItemKind.note;
  }
}

FiledItemLifecycle _parseFiledItemLifecycle(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'inactive':
      return FiledItemLifecycle.inactive;
    case 'deleted':
      return FiledItemLifecycle.deleted;
    case 'active':
    default:
      return FiledItemLifecycle.active;
  }
}

DateTime? _parseBackendDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

class FiledFlowRecord<T> {
  const FiledFlowRecord({
    required this.flow,
    required this.kind,
    required this.lifecycle,
    required this.calendar,
    required this.totalEventCount,
    required this.remainingEventCount,
    this.saved = false,
    this.shared = false,
    this.posted = false,
  });

  final T flow;
  final FiledItemKind kind;
  final FiledItemLifecycle lifecycle;
  final FiledCalendarRef calendar;
  final int totalEventCount;
  final int remainingEventCount;
  final bool saved;
  final bool shared;
  final bool posted;

  bool get isActive => lifecycle == FiledItemLifecycle.active;
  bool get isInactive => lifecycle == FiledItemLifecycle.inactive;
  bool get isDeleted => lifecycle == FiledItemLifecycle.deleted;
}

class FiledFlowCabinet<T> {
  const FiledFlowCabinet(this.entries);

  final List<FiledFlowRecord<T>> entries;

  List<FiledFlowRecord<T>> get active =>
      _whereLifecycle(FiledItemLifecycle.active);
  List<FiledFlowRecord<T>> get inactive =>
      _whereLifecycle(FiledItemLifecycle.inactive);
  List<FiledFlowRecord<T>> get deleted =>
      _whereLifecycle(FiledItemLifecycle.deleted);
  List<FiledFlowRecord<T>> get saved => _whereFlag((entry) => entry.saved);
  List<FiledFlowRecord<T>> get shared => _whereFlag((entry) => entry.shared);
  List<FiledFlowRecord<T>> get posted => _whereFlag((entry) => entry.posted);
  List<FiledFlowRecord<T>> get reminders =>
      List<FiledFlowRecord<T>>.unmodifiable(
        entries.where((entry) => entry.kind == FiledItemKind.reminder),
      );

  List<FiledFlowRecord<T>> _whereLifecycle(FiledItemLifecycle lifecycle) {
    return List<FiledFlowRecord<T>>.unmodifiable(
      entries.where((entry) => entry.lifecycle == lifecycle),
    );
  }

  List<FiledFlowRecord<T>> _whereFlag(bool Function(FiledFlowRecord<T>) test) {
    return List<FiledFlowRecord<T>>.unmodifiable(entries.where(test));
  }
}

class EventFilingEngine {
  const EventFilingEngine();

  FiledEventCabinet fileEvents(
    Iterable<UserEvent> events, {
    Map<int, FlowRecordSnapshot> flowOwnersById = const {},
    Set<String> sharedEventIds = const {},
    Set<int> postedFlowIds = const {},
    Set<String> postedEventIds = const {},
    DateTime? now,
  }) {
    final filed =
        events
            .map(
              (event) => fileEvent(
                event,
                flowOwnersById: flowOwnersById,
                sharedEventIds: sharedEventIds,
                postedFlowIds: postedFlowIds,
                postedEventIds: postedEventIds,
                now: now,
              ),
            )
            .toList(growable: false)
          ..sort(_compareFiledEvents);
    return FiledEventCabinet(List<FiledEvent>.unmodifiable(filed));
  }

  FiledEvent fileEvent(
    UserEvent event, {
    Map<int, FlowRecordSnapshot> flowOwnersById = const {},
    Set<String> sharedEventIds = const {},
    Set<int> postedFlowIds = const {},
    Set<String> postedEventIds = const {},
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final decision = classifyFlowEvent(
      event: FlowEventSnapshot(
        flowLocalId: event.flowLocalId,
        clientEventId: event.clientEventId,
        detail: event.detail,
        category: event.category,
      ),
      flowOwnersById: flowOwnersById,
    );
    final flowId =
        decision.referencedFlowId ??
        extractReferencedFlowId(
          flowLocalId: event.flowLocalId,
          clientEventId: event.clientEventId,
          detail: event.detail,
        );
    final deleted = _isDeletedEvent(event, decision);
    final lifecycle = deleted
        ? FiledItemLifecycle.deleted
        : _isActiveOrUpcomingEvent(event, now: current)
        ? FiledItemLifecycle.active
        : FiledItemLifecycle.inactive;
    final owner =
        decision.owner ?? (flowId == null ? null : flowOwnersById[flowId]);
    final eventKeys = _eventKeys(event);

    return FiledEvent(
      event: event,
      kind: _kindForEvent(event, decision),
      lifecycle: lifecycle,
      calendar: FiledCalendarRef(
        id: event.calendarId,
        name: event.calendarName,
        color: event.calendarColor,
        isPersonal: event.calendarIsPersonal,
      ),
      flowId: flowId,
      flowOwner: owner,
      saved: owner?.isSaved ?? false,
      shared:
          !event.calendarIsPersonal || eventKeys.any(sharedEventIds.contains),
      posted:
          (flowId != null && postedFlowIds.contains(flowId)) ||
          eventKeys.any(postedEventIds.contains),
    );
  }

  FiledFlowCabinet<T> fileFlowRecords<T>({
    required Iterable<T> flows,
    required int Function(T flow) idOf,
    required bool Function(T flow) activeOf,
    required bool Function(T flow) isSavedOf,
    required bool Function(T flow) isHiddenOf,
    required bool Function(T flow) isReminderOf,
    required DateTime? Function(T flow) endDateOf,
    required String? Function(T flow) notesOf,
    required String? Function(T flow) calendarIdOf,
    String? Function(T flow)? calendarNameOf,
    int? Function(T flow)? calendarColorOf,
    bool Function(T flow)? calendarIsPersonalOf,
    Map<int, int> totalEventCounts = const {},
    Map<int, int> remainingEventCounts = const {},
    Set<int> postedFlowIds = const {},
    DateTime? now,
    bool useRemainingEventCount = true,
  }) {
    final ledger = buildFlowLedger<T>(
      flows: flows,
      idOf: idOf,
      activeOf: activeOf,
      isSavedOf: isSavedOf,
      isHiddenOf: isHiddenOf,
      isReminderOf: isReminderOf,
      endDateOf: endDateOf,
      notesOf: notesOf,
      totalEventCounts: totalEventCounts,
      remainingEventCounts: remainingEventCounts,
      useRemainingEventCount: useRemainingEventCount,
      now: now,
    );
    final records = ledger.entries
        .map((entry) {
          final flow = entry.flow;
          final flowId = idOf(flow);
          final calendarPersonal = calendarIsPersonalOf?.call(flow) ?? true;
          final lifecycle = switch (entry.bucket) {
            FlowLedgerBucket.active => FiledItemLifecycle.active,
            FlowLedgerBucket.softDeleted => FiledItemLifecycle.deleted,
            FlowLedgerBucket.savedTemplate ||
            FlowLedgerBucket.inactive ||
            FlowLedgerBucket.hiddenHelper ||
            FlowLedgerBucket.reminder => FiledItemLifecycle.inactive,
          };
          return FiledFlowRecord<T>(
            flow: flow,
            kind: entry.bucket == FlowLedgerBucket.reminder
                ? FiledItemKind.reminder
                : FiledItemKind.flow,
            lifecycle: lifecycle,
            calendar: FiledCalendarRef(
              id: calendarIdOf(flow),
              name: calendarNameOf?.call(flow),
              color: calendarColorOf?.call(flow),
              isPersonal: calendarPersonal,
            ),
            totalEventCount: entry.totalEventCount,
            remainingEventCount: entry.remainingEventCount,
            saved: entry.visibleInSavedList,
            shared: !calendarPersonal,
            posted: postedFlowIds.contains(flowId),
          );
        })
        .toList(growable: false);
    return FiledFlowCabinet<T>(List<FiledFlowRecord<T>>.unmodifiable(records));
  }

  bool shouldPurgeDeletedItem(DateTime deletedAtUtc, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    return !deletedAtUtc.toUtc().add(deletedEventRetention).isAfter(current);
  }

  static Set<int> referencedFlowIds(Iterable<UserEvent> events) {
    return events
        .map(
          (event) => extractReferencedFlowId(
            flowLocalId: event.flowLocalId,
            clientEventId: event.clientEventId,
            detail: event.detail,
          ),
        )
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
  }

  bool _isDeletedEvent(UserEvent event, FlowEventDecision decision) {
    final category = event.category?.trim().toLowerCase();
    if (category == 'tombstone') return true;

    final clientEventId = event.clientEventId?.trim().toLowerCase() ?? '';
    if (clientEventId.startsWith('reminder:tombstone:')) return true;

    return decision.shouldPurgeGhostRow;
  }

  FiledItemKind _kindForEvent(UserEvent event, FlowEventDecision decision) {
    final clientEventId = event.clientEventId?.trim().toLowerCase() ?? '';
    if (clientEventId.startsWith('reminder:') ||
        clientEventId.startsWith('nutrition:')) {
      return FiledItemKind.reminder;
    }

    switch (decision.kind) {
      case FlowEventKind.reminderFlow:
        return FiledItemKind.reminder;
      case FlowEventKind.hiddenHelperFlow:
      case FlowEventKind.standalone:
        return FiledItemKind.note;
      case FlowEventKind.activeFlow:
      case FlowEventKind.inactiveFlow:
      case FlowEventKind.deletedFlow:
      case FlowEventKind.orphanedFlow:
      case FlowEventKind.legacyMaat:
        return FiledItemKind.flow;
    }
  }

  bool _isActiveOrUpcomingEvent(UserEvent event, {required DateTime now}) {
    final nowUtc = now.toUtc();
    final localNow = now.toLocal();
    final todayLocal = DateTime(localNow.year, localNow.month, localNow.day);

    if (event.allDay) {
      final localStart = event.startsAt.toLocal();
      final startDay = DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
      );
      if (!startDay.isBefore(todayLocal)) return true;
      final endsAt = event.endsAt;
      return endsAt != null && !endsAt.toUtc().isBefore(nowUtc);
    }

    final activeUntil = event.endsAt ?? event.startsAt;
    return !activeUntil.toUtc().isBefore(nowUtc);
  }

  Set<String> _eventKeys(UserEvent event) {
    return <String>{
      event.id,
      if (event.clientEventId != null && event.clientEventId!.trim().isNotEmpty)
        event.clientEventId!.trim(),
    };
  }

  int _compareFiledEvents(FiledEvent a, FiledEvent b) {
    final byStart = a.event.startsAt.compareTo(b.event.startsAt);
    if (byStart != 0) return byStart;
    return a.event.id.compareTo(b.event.id);
  }
}
