import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/event_filing_engine.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/utils/flow_filter_engine.dart';

void main() {
  const engine = EventFilingEngine();
  final now = DateTime.utc(2026, 5, 4, 19);

  group('event filing', () {
    test('files future standalone rows as active notes on their calendar', () {
      final event = _event(
        id: 'event-1',
        title: 'Dentist',
        calendarId: 'personal',
        startsAt: DateTime.utc(2026, 5, 5, 17),
      );

      final cabinet = engine.fileEvents([event], now: now);

      expect(cabinet.notes, hasLength(1));
      expect(cabinet.activeEventsForCalendar('personal'), [event]);
      expect(cabinet.inactive, isEmpty);
      expect(cabinet.deleted, isEmpty);
    });

    test(
      'files elapsed rows as inactive and excludes them from calendar active list',
      () {
        final event = _event(
          id: 'event-2',
          title: 'Past lunch',
          calendarId: 'personal',
          startsAt: DateTime.utc(2026, 5, 3, 19),
          endsAt: DateTime.utc(2026, 5, 3, 20),
        );

        final cabinet = engine.fileEvents([event], now: now);

        expect(cabinet.inactive, hasLength(1));
        expect(cabinet.activeEventsForCalendar('personal'), isEmpty);
      },
    );

    test('files tombstones and legacy maat rows as deleted ghosts', () {
      final tombstone = _event(
        id: 'event-3',
        title: 'deleted',
        clientEventId: 'cid-deleted',
        calendarId: 'personal',
        category: 'tombstone',
        startsAt: DateTime.utc(2026, 5, 5),
      );
      final maat = _event(
        id: 'event-4',
        title: 'legacy',
        clientEventId: 'maat:legacy',
        calendarId: 'personal',
        startsAt: DateTime.utc(2026, 5, 5),
      );

      final cabinet = engine.fileEvents([tombstone, maat], now: now);

      expect(cabinet.deleted, hasLength(2));
      expect(cabinet.activeEventsForCalendar('personal'), isEmpty);
    });

    test('files shared saved posted flow rows with flow ownership', () {
      final event = _event(
        id: 'event-5',
        title: 'Shared flow occurrence',
        clientEventId: 'ky=1-km=2-kd=3|f=42|cal=shared',
        calendarId: 'shared',
        calendarIsPersonal: false,
        flowLocalId: 42,
        startsAt: DateTime.utc(2026, 5, 6, 15),
      );

      final cabinet = engine.fileEvents(
        [event],
        flowOwnersById: const {
          42: FlowRecordSnapshot(
            id: 42,
            active: true,
            isHidden: false,
            isReminder: false,
            isSaved: true,
          ),
        },
        postedFlowIds: const {42},
        now: now,
      );
      final filed = cabinet.flows.single;

      expect(filed.lifecycle, FiledItemLifecycle.active);
      expect(filed.shared, isTrue);
      expect(filed.saved, isTrue);
      expect(filed.posted, isTrue);
      expect(cabinet.activeEventsForCalendar('shared'), [event]);
    });

    test('files orphaned flow rows as deleted so they cannot resurface', () {
      final event = _event(
        id: 'event-6',
        title: 'Orphaned flow occurrence',
        clientEventId: 'ky=1-km=2-kd=3|f=404',
        calendarId: 'personal',
        flowLocalId: 404,
        startsAt: DateTime.utc(2026, 5, 6, 15),
      );

      final cabinet = engine.fileEvents([event], now: now);

      expect(cabinet.deleted, hasLength(1));
      expect(cabinet.activeEventsForCalendar('personal'), isEmpty);
    });

    test('files reminder client ids in the reminder category', () {
      final event = _event(
        id: 'event-7',
        title: 'Drink water',
        clientEventId: 'reminder:water:2026-05-05T12:00:00Z',
        calendarId: 'personal',
        startsAt: DateTime.utc(2026, 5, 5, 12),
      );

      final cabinet = engine.fileEvents([event], now: now);

      expect(cabinet.reminders, hasLength(1));
      expect(cabinet.reminders.single.kind, FiledItemKind.reminder);
    });

    test('reads backend filing rows as the authoritative event cabinet', () {
      final active = _backendRow(
        id: 'event-8',
        title: 'Live shared flow',
        calendarId: 'shared',
        lifecycle: 'active',
        itemKind: 'flow',
        startsAt: DateTime.utc(2026, 5, 5, 16),
        flowId: 42,
        saved: true,
        shared: true,
        posted: true,
      );
      final inactive = _backendRow(
        id: 'event-9',
        title: 'Past note',
        calendarId: 'shared',
        lifecycle: 'inactive',
        itemKind: 'note',
        startsAt: DateTime.utc(2026, 5, 1, 16),
      );
      final deleted = _backendRow(
        id: 'event-10',
        title: 'Deleted reminder',
        calendarId: 'shared',
        lifecycle: 'deleted',
        itemKind: 'reminder',
        startsAt: DateTime.utc(2026, 5, 6, 16),
      );

      final cabinet = FiledEventCabinet.fromBackendRows([
        deleted,
        inactive,
        active,
      ]);

      expect(cabinet.active.single.event.title, 'Live shared flow');
      expect(cabinet.inactive.single.event.title, 'Past note');
      expect(cabinet.deleted.single.event.title, 'Deleted reminder');
      expect(cabinet.flows.single.saved, isTrue);
      expect(cabinet.flows.single.shared, isTrue);
      expect(cabinet.flows.single.posted, isTrue);
      expect(
        cabinet.flows.single.justification.activeUntilReason,
        'timed_valid_ends_at',
      );
      expect(cabinet.flows.single.justification.flowShareSource, isTrue);
      expect(cabinet.flows.single.justification.flowSavedSource, isTrue);
      expect(
        cabinet.activeEventsForCalendar('shared').map((event) => event.title),
        ['Live shared flow'],
      );
    });
  });

  group('flow filing', () {
    test('files active, saved, shared, posted, and deleted flow records', () {
      final active = _FlowFixture(
        id: 1,
        active: true,
        isSaved: false,
        isHidden: false,
        isReminder: false,
        calendarId: 'personal',
      );
      final saved = _FlowFixture(
        id: 2,
        active: false,
        isSaved: true,
        isHidden: false,
        isReminder: false,
        calendarId: 'shared',
        calendarIsPersonal: false,
      );
      final deleted = _FlowFixture(
        id: 3,
        active: false,
        isSaved: false,
        isHidden: true,
        isReminder: false,
        calendarId: 'personal',
      );

      final cabinet = engine.fileFlowRecords<_FlowFixture>(
        flows: [active, saved, deleted],
        idOf: (flow) => flow.id,
        activeOf: (flow) => flow.active,
        isSavedOf: (flow) => flow.isSaved,
        isHiddenOf: (flow) => flow.isHidden,
        isReminderOf: (flow) => flow.isReminder,
        endDateOf: (flow) => flow.endDate,
        notesOf: (flow) => flow.notes,
        calendarIdOf: (flow) => flow.calendarId,
        calendarIsPersonalOf: (flow) => flow.calendarIsPersonal,
        remainingEventCounts: const {1: 2, 2: 0, 3: 0},
        postedFlowIds: const {1},
        now: now,
      );

      expect(cabinet.active.single.flow, active);
      expect(cabinet.saved.single.flow, saved);
      expect(cabinet.shared.single.flow, saved);
      expect(cabinet.posted.single.flow, active);
      expect(cabinet.deleted.single.flow, deleted);
    });
  });

  test('deleted retention helper purges after ten days', () {
    expect(
      engine.shouldPurgeDeletedItem(
        DateTime.utc(2026, 5, 1),
        now: DateTime.utc(2026, 5, 11),
      ),
      isTrue,
    );
    expect(
      engine.shouldPurgeDeletedItem(
        DateTime.utc(2026, 5, 1),
        now: DateTime.utc(2026, 5, 10, 23, 59),
      ),
      isFalse,
    );
  });
}

UserEvent _event({
  required String id,
  required String title,
  required String calendarId,
  required DateTime startsAt,
  String? clientEventId,
  bool calendarIsPersonal = true,
  DateTime? endsAt,
  int? flowLocalId,
  String? category,
}) {
  return UserEvent(
    id: id,
    clientEventId: clientEventId,
    calendarId: calendarId,
    calendarName: calendarId,
    calendarColor: 0x4DD0E1,
    calendarIsPersonal: calendarIsPersonal,
    title: title,
    allDay: false,
    startsAt: startsAt,
    endsAt: endsAt,
    flowLocalId: flowLocalId,
    category: category,
  );
}

Map<String, dynamic> _backendRow({
  required String id,
  required String title,
  required String calendarId,
  required String lifecycle,
  required String itemKind,
  required DateTime startsAt,
  int? flowId,
  bool saved = false,
  bool shared = false,
  bool posted = false,
}) {
  return {
    'id': id,
    'user_id': '00000000-0000-0000-0000-000000000001',
    'client_event_id': 'client:$id',
    'calendar_id': calendarId,
    'calendar_name': calendarId,
    'calendar_color': 0x4DD0E1,
    'calendar_is_personal': calendarId == 'personal',
    'title': title,
    'detail': null,
    'location': null,
    'all_day': false,
    'starts_at': startsAt.toIso8601String(),
    'ends_at': startsAt.add(const Duration(hours: 1)).toIso8601String(),
    'flow_local_id': flowId,
    'category': null,
    'action_id': null,
    'behavior_payload': null,
    'updated_at': null,
    'created_at': null,
    'filed_flow_id': flowId,
    'flow_active': flowId != null,
    'flow_is_hidden': false,
    'flow_is_reminder': false,
    'flow_is_saved': saved,
    'flow_notes': null,
    'item_kind': itemKind,
    'lifecycle': lifecycle,
    'live_on_calendar': lifecycle == 'active',
    'is_saved': saved,
    'is_shared': shared,
    'is_posted': posted,
    'active_until': startsAt.add(const Duration(hours: 1)).toIso8601String(),
    'date_lifecycle': lifecycle == 'deleted' ? 'active' : lifecycle,
    'reason_item_kind': itemKind == 'flow'
        ? 'flow_reference'
        : itemKind == 'reminder'
        ? 'client_event_id_reminder_prefix'
        : 'standalone_event',
    'reason_deleted': lifecycle == 'deleted' ? 'event_deletion_trash' : null,
    'reason_active_until': 'timed_valid_ends_at',
    'user_timezone': 'UTC',
    'is_shared_calendar_source': false,
    'is_event_share_source': false,
    'is_flow_share_source': shared,
    'is_flow_post_source': posted,
    'is_flow_saved_source': saved,
    'is_active_reminder_source': false,
    'is_scheduled_notification_source': false,
    'filing_reasons': {
      'item_kind': {'value': itemKind},
    },
  };
}

class _FlowFixture {
  const _FlowFixture({
    required this.id,
    required this.active,
    required this.isSaved,
    required this.isHidden,
    required this.isReminder,
    required this.calendarId,
    this.calendarIsPersonal = true,
    this.endDate,
    this.notes,
  });

  final int id;
  final bool active;
  final bool isSaved;
  final bool isHidden;
  final bool isReminder;
  final String calendarId;
  final bool calendarIsPersonal;
  final DateTime? endDate;
  final String? notes;
}
