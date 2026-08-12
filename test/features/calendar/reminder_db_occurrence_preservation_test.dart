import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/reminders/reminder_rule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _principalId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';

const _familyEventId = 'c6c8d29c-e22c-4b1b-901a-161d0a36a8a6';
const _familyReminderId = '4a42c9c8-6249-4adc-8a73-65d3b63ea642';
const _familyCalendarId = '42e0e5ca-55b9-4948-a17c-4ba41cc0213e';
const _familyFlowId = 642;
final _familyDate = DateTime(2026, 7, 27);
final _familyStart = DateTime(2026, 7, 27, 17);
final _familyEnd = DateTime(2026, 7, 27, 17, 30);
final _familyClientEventId = 'reminder:$_familyReminderId:2026-07-27';

const _journalEventId = '63bd76e9-0139-47af-820c-b36823daf3ee';
const _journalReminderId = '43394413-edd7-457a-9818-b0810a3c1e2f';
const _journalCalendarId = 'cf4be669-17f7-4a41-a956-d9f716830f87';
const _journalFlowId = 677;
const _journalDetail =
    'color=7bb661;alert=0;repeat={"kind":"everyNDays","interval":1,'
    '"weekdays":[],"monthDay":null,"monthDays":[],"decanDays":[],'
    '"kemeticMonthDays":[]};';
final _journalDate = DateTime(2026, 7, 30);
final _journalStart = DateTime(2026, 7, 30, 21, 30);
final _journalEnd = DateTime(2026, 7, 30, 22);
final _journalClientEventId = 'reminder:$_journalReminderId:2026-07-30';

const _localReminderId = '11111111-1111-4111-8111-111111111111';
const _localEventId = '22222222-2222-4222-8222-222222222222';
const _localFlowId = 900001;
final _localDate = DateTime(2026, 7, 30);
final _localStart = DateTime(2026, 7, 30, 8, 15);
final _localClientEventId = 'reminder:$_localReminderId:2026-07-30';

final _syncToday = DateTime(2026, 7, 29, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'startup reminder sync preserves past and future DB occurrences and local fallback',
    (tester) async {
      CalendarPage.debugReminderSyncTodayForTesting = _syncToday;
      CalendarPage.debugReminderSyncWindowEndForTesting = _journalDate;
      addTearDown(() {
        CalendarPage.debugReminderSyncTodayForTesting = null;
        CalendarPage.debugReminderSyncWindowEndForTesting = null;
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app:has_seen_onboarding': true,
        'app:onboarding:completed': true,
      });
      final fixtureClient = _CalendarFixtureClient();
      CalendarPage.debugReminderSyncCompletedForTesting =
          fixtureClient.recordReminderSyncCompletion;
      addTearDown(() {
        CalendarPage.debugReminderSyncCompletedForTesting = null;
      });

      await Supabase.initialize(
        url: 'http://127.0.0.1:9',
        anonKey: 'test-anon-key',
        httpClient: fixtureClient,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: false,
        ),
      );
      await Supabase.instance.client.auth.recoverSession(_sessionJson());

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CalendarPage())),
      );

      var stableSamples = 0;
      String? previousSignature;
      for (var attempt = 0; attempt < 480; attempt++) {
        await tester.pump(const Duration(milliseconds: 25));

        final state = CalendarPage.globalKey.currentState;
        if (state == null ||
            fixtureClient.reminderSyncCompletions == 0 ||
            fixtureClient.localOnlyUpserts != 1) {
          continue;
        }
        final familyKDate = KemeticMath.fromGregorian(_familyDate);
        final journalKDate = KemeticMath.fromGregorian(_journalDate);
        final localKDate = KemeticMath.fromGregorian(_localDate);
        final signature = [
          fixtureClient.requests.length,
          fixtureClient.reminderOccurrenceReads,
          fixtureClient.reminderSyncCompletions,
          fixtureClient.localOnlyUpserts,
          state.filteredNoteCountForDay(
            familyKDate.kYear,
            familyKDate.kMonth,
            familyKDate.kDay,
          ),
          state.filteredNoteCountForDay(
            journalKDate.kYear,
            journalKDate.kMonth,
            journalKDate.kDay,
          ),
          state.filteredNoteCountForDay(
            localKDate.kYear,
            localKDate.kMonth,
            localKDate.kDay,
          ),
        ].join(':');
        if (signature == previousSignature) {
          stableSamples++;
        } else {
          previousSignature = signature;
          stableSamples = 1;
        }
        if (stableSamples >= 6) break;
      }

      expect(
        fixtureClient.reminderSyncCompletions,
        1,
        reason: 'The real current/future reminder synchronization must finish.',
      );
      expect(
        fixtureClient.journalEventIdAtSyncCompletion,
        _journalEventId,
        reason:
            'Journal must retain its database identity at the exact sync boundary.',
      );
      expect(
        fixtureClient.localOnlyUpserts,
        1,
        reason: 'The no-occurrence fallback must retain local materialization.',
      );
      expect(fixtureClient.unexpectedMutations, isEmpty);

      final state = CalendarPage.globalKey.currentState!;
      final familyKDate = KemeticMath.fromGregorian(_familyDate);
      final familyNotes = state.notesForDayForTesting(
        familyKDate.kYear,
        familyKDate.kMonth,
        familyKDate.kDay,
      );
      expect(familyNotes, hasLength(1));
      expect(familyNotes.single.id, _familyEventId);
      expect(familyNotes.single.clientEventId, _familyClientEventId);
      expect(familyNotes.single.flowId, _familyFlowId);
      expect(familyNotes.single.calendarId, _familyCalendarId);
      expect(familyNotes.single.title, 'Family Salon');
      expect(familyNotes.single.isReminder, isTrue);
      expect(familyNotes.single.reminderId, _familyReminderId);
      expect(familyNotes.single.start, const TimeOfDay(hour: 17, minute: 0));
      expect(familyNotes.single.end, const TimeOfDay(hour: 17, minute: 30));

      final journalKDate = KemeticMath.fromGregorian(_journalDate);
      final journalNotes = state
          .notesForDayForTesting(
            journalKDate.kYear,
            journalKDate.kMonth,
            journalKDate.kDay,
          )
          .where((note) => note.reminderId == _journalReminderId)
          .toList();
      expect(journalNotes, hasLength(1));
      expect(journalNotes.single.id, _journalEventId);
      expect(journalNotes.single.clientEventId, _journalClientEventId);
      expect(journalNotes.single.flowId, _journalFlowId);
      expect(journalNotes.single.calendarId, _journalCalendarId);
      expect(journalNotes.single.title, 'journal every night');
      expect(journalNotes.single.isReminder, isTrue);
      expect(journalNotes.single.start, const TimeOfDay(hour: 21, minute: 30));
      expect(journalNotes.single.end, const TimeOfDay(hour: 22, minute: 0));

      final localKDate = KemeticMath.fromGregorian(_localDate);
      final localNotes = state
          .notesForDayForTesting(
            localKDate.kYear,
            localKDate.kMonth,
            localKDate.kDay,
          )
          .where((note) => note.reminderId == _localReminderId)
          .toList();
      expect(localNotes, hasLength(1));
      expect(localNotes.single.id, isNull);
      expect(localNotes.single.clientEventId, _localClientEventId);
      expect(localNotes.single.flowId, _localFlowId);
      expect(localNotes.single.title, 'local fallback reminder');
      expect(localNotes.single.isReminder, isTrue);
      expect(localNotes.single.start, const TimeOfDay(hour: 8, minute: 15));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
}

class _CalendarFixtureClient extends http.BaseClient {
  final List<Uri> requests = <Uri>[];
  final List<String> unexpectedMutations = <String>[];
  int reminderOccurrenceReads = 0;
  int journalOccurrenceReads = 0;
  int localOnlyUpserts = 0;
  int reminderSyncCompletions = 0;
  String? journalEventIdAtSyncCompletion;

  void recordReminderSyncCompletion() {
    reminderSyncCompletions++;
    final state = CalendarPage.globalKey.currentState;
    if (state == null) return;
    final date = KemeticMath.fromGregorian(_journalDate);
    final matches = state
        .notesForDayForTesting(date.kYear, date.kMonth, date.kDay)
        .where((note) => note.reminderId == _journalReminderId)
        .toList();
    journalEventIdAtSyncCompletion = matches.length == 1
        ? matches.single.id
        : 'count:${matches.length}';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final path = request.url.path;
    final isReadRpc =
        request.method == 'POST' && path.startsWith('/rest/v1/rpc/');
    final isExpectedLocalOnlyUpsert = _isExpectedLocalOnlyUpsert(request);
    if (path.startsWith('/rest/v1/') &&
        request.method != 'GET' &&
        request.method != 'HEAD' &&
        request.method != 'OPTIONS' &&
        !isReadRpc &&
        !isExpectedLocalOnlyUpsert) {
      unexpectedMutations.add('${request.method} ${request.url}');
    }

    if (path == '/auth/v1/user') {
      return _jsonResponse(request, _userJson());
    }
    if (path == '/rest/v1/flows_with_calendars') {
      return _jsonResponse(request, <Object?>[
        _familyFlowRow(),
        _localFlowRow(),
        _journalFlowRow(),
      ]);
    }
    if (path == '/rest/v1/flows') {
      final reminderFilter = request.url.queryParameters['reminder_uuid'] ?? '';
      final int? flowId = switch (reminderFilter) {
        final String value when value.contains(_familyReminderId) =>
          _familyFlowId,
        final String value when value.contains(_journalReminderId) =>
          _journalFlowId,
        final String value when value.contains(_localReminderId) =>
          _localFlowId,
        _ => null,
      };
      final wantsObject =
          request.headers['accept']?.contains('application/vnd.pgrst.object') ??
          false;
      return _jsonResponse(
        request,
        wantsObject
            ? (flowId == null ? null : <String, Object?>{'id': flowId})
            : (flowId == null
                  ? const <Object?>[]
                  : <Object?>[
                      <String, Object?>{'id': flowId},
                    ]),
      );
    }
    if (path == '/rest/v1/rpc/get_calendar_standalone_events_v2' &&
        request is http.Request) {
      return _jsonResponse(request, <Object?>[
        _familyFilingRow(),
        _journalFilingRow(),
      ]);
    }
    if (path == '/rest/v1/user_event_filing_items_client') {
      final itemKind = request.url.queryParameters['item_kind'] ?? '';
      final select = request.url.queryParameters['select'] ?? '';
      if (itemKind.contains('flow')) {
        return _jsonResponse(request, const <Object?>[]);
      }
      if (itemKind.contains('note') || itemKind.contains('reminder')) {
        return _jsonResponse(request, <Object?>[
          _familyFilingRow(),
          _journalFilingRow(),
        ]);
      }
      if (select.contains('filed_flow_id')) {
        return _jsonResponse(request, const <Object?>[]);
      }
      return _jsonResponse(request, const <Object?>[]);
    }
    if (path == '/rest/v1/user_events') {
      if (isExpectedLocalOnlyUpsert) {
        localOnlyUpserts++;
        return _jsonResponse(request, _localSavedEventRow());
      }
      final clientEventFilter =
          request.url.queryParameters['client_event_id'] ?? '';
      if (request.method == 'GET' && clientEventFilter.contains('like.')) {
        reminderOccurrenceReads++;
        if (clientEventFilter.contains(_journalReminderId)) {
          journalOccurrenceReads++;
          return _jsonResponse(request, _journalOccurrenceRows());
        }
        return _jsonResponse(request, const <Object?>[]);
      }
      return _jsonResponse(request, const <Object?>[]);
    }
    if (path.startsWith('/rest/v1/')) {
      return _jsonResponse(request, const <Object?>[]);
    }
    return _jsonResponse(request, const <String, Object?>{});
  }

  bool _isExpectedLocalOnlyUpsert(http.BaseRequest request) {
    if (request.method != 'POST' ||
        request.url.path != '/rest/v1/user_events' ||
        request is! http.Request) {
      return false;
    }
    try {
      final decoded = jsonDecode(request.body);
      final Object? raw = decoded is List && decoded.isNotEmpty
          ? decoded.first
          : decoded;
      if (raw is! Map) return false;
      return raw['client_event_id'] == _localClientEventId;
    } catch (_) {
      return false;
    }
  }

  http.StreamedResponse _jsonResponse(http.BaseRequest request, Object? body) {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      200,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

Map<String, Object?> _familyFlowRow() {
  final rule = ReminderRule(
    id: _familyReminderId,
    calendarId: _familyCalendarId,
    title: 'Family Salon',
    startLocal: _familyStart,
    color: const Color(0xFFB68B2E),
  );
  return _flowRow(
    id: _familyFlowId,
    calendarId: _familyCalendarId,
    name: 'Family Salon',
    color: 0xB68B2E,
    startDate: '2026-07-27',
    reminderId: _familyReminderId,
    notes: jsonEncode(rule.toJson()),
    createdAt: '2026-07-01T00:00:00.000Z',
    updatedAt: '2026-07-27T23:59:00.000Z',
  );
}

Map<String, Object?> _journalFlowRow() {
  return _flowRow(
    id: _journalFlowId,
    calendarId: _journalCalendarId,
    name: 'journal every night',
    color: 8107617,
    startDate: '2026-04-29',
    reminderId: _journalReminderId,
    notes:
        '{"id":"$_journalReminderId","calendarId":"$_journalCalendarId",'
        '"title":"journal every night","startLocal":"2026-04-29T21:30:00.000",'
        '"allDay":false,"color":4286297697,"category":"Spirit",'
        '"active":true,"repeat":{"kind":"everyNDays","interval":1,'
        '"weekdays":[],"monthDay":null,"monthDays":[],"decanDays":[],'
        '"kemeticMonthDays":[]},"alertOffsetMinutes":0}',
    createdAt: '2026-04-29T15:28:48.178170Z',
    updatedAt: '2026-04-30T03:01:04.811317Z',
  );
}

Map<String, Object?> _localFlowRow() {
  final rule = ReminderRule(
    id: _localReminderId,
    calendarId: _journalCalendarId,
    title: 'local fallback reminder',
    startLocal: _localStart,
    color: const Color(0xFF5577AA),
  );
  return _flowRow(
    id: _localFlowId,
    calendarId: _journalCalendarId,
    name: 'local fallback reminder',
    color: 0x5577AA,
    startDate: '2026-07-30',
    reminderId: _localReminderId,
    notes: jsonEncode(rule.toJson()),
    createdAt: '2026-07-30T12:00:00.000Z',
    updatedAt: '2026-07-30T12:00:00.000Z',
  );
}

Map<String, Object?> _flowRow({
  required int id,
  required String calendarId,
  required String name,
  required int color,
  required String startDate,
  required String reminderId,
  required String notes,
  required String createdAt,
  required String updatedAt,
}) {
  return <String, Object?>{
    'id': id,
    'user_id': _principalId,
    'calendar_id': calendarId,
    'name': name,
    'color': color,
    'active': true,
    'is_saved': false,
    'start_date': startDate,
    'end_date': null,
    'notes': notes,
    'rules': const <Object?>[],
    'share_id': null,
    'is_hidden': false,
    'is_reminder': true,
    'reminder_uuid': reminderId,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Map<String, Object?> _familyFilingRow() {
  return <String, Object?>{
    'id': _familyEventId,
    'calendar_id': _familyCalendarId,
    'calendar_name': 'Personal',
    'calendar_color': 0xB68B2E,
    'calendar_is_personal': true,
    'client_event_id': _familyClientEventId,
    'title': 'Family Salon',
    'detail': null,
    'location': null,
    'all_day': false,
    'starts_at': _familyStart.toUtc().toIso8601String(),
    'ends_at': _familyEnd.toUtc().toIso8601String(),
    'flow_local_id': _familyFlowId,
    'filed_flow_id': _familyFlowId,
    'item_kind': 'reminder',
    'category': null,
    'action_id': 'shared_practice',
    'behavior_payload': <String, Object?>{
      'room_id': '27e2495f-c439-40a1-8a81-54885a9d3596',
    },
  };
}

Map<String, Object?> _journalFilingRow() {
  return <String, Object?>{
    'id': _journalEventId,
    'calendar_id': _journalCalendarId,
    'calendar_name': 'My Calendar',
    'calendar_color': 5099745,
    'calendar_is_personal': true,
    'client_event_id': _journalClientEventId,
    'title': 'journal every night',
    'detail': _journalDetail,
    'location': null,
    'all_day': false,
    'starts_at': '2026-07-31T04:30:00.000Z',
    'ends_at': '2026-07-31T05:00:00.000Z',
    'flow_local_id': _journalFlowId,
    'filed_flow_id': _journalFlowId,
    'item_kind': 'reminder',
    'category': 'Spirit',
    'action_id': null,
    'behavior_payload': null,
    'created_at': '2026-05-05T02:02:42.893501Z',
    'updated_at': '2026-06-21T00:54:38.072443Z',
  };
}

List<Map<String, Object?>> _journalOccurrenceRows() {
  return <Map<String, Object?>>[
    <String, Object?>{
      'id': '11111111-2222-4333-8444-555555555555',
      'client_event_id': 'reminder:$_journalReminderId:2026-07-29',
      'title': 'journal every night',
      'detail': _journalDetail,
      'location': null,
      'all_day': false,
      'starts_at': DateTime(2026, 7, 29, 21, 30).toUtc().toIso8601String(),
      'ends_at': DateTime(2026, 7, 29, 22).toUtc().toIso8601String(),
      'calendar_id': _journalCalendarId,
      'flow_local_id': _journalFlowId,
      'category': 'Spirit',
    },
    <String, Object?>{
      'id': _journalEventId,
      'client_event_id': _journalClientEventId,
      'title': 'journal every night',
      'detail': _journalDetail,
      'location': null,
      'all_day': false,
      'starts_at': _journalStart.toUtc().toIso8601String(),
      'ends_at': _journalEnd.toUtc().toIso8601String(),
      'calendar_id': _journalCalendarId,
      'flow_local_id': _journalFlowId,
      'category': 'Spirit',
    },
  ];
}

Map<String, Object?> _localSavedEventRow() {
  return <String, Object?>{
    'id': _localEventId,
    'client_event_id': _localClientEventId,
    'calendar_id': _journalCalendarId,
    'title': 'local fallback reminder',
    'detail':
        'color=5577aa;alert=-1;repeat={"kind":"none","interval":1,'
        '"weekdays":[],"monthDay":null,"monthDays":[],"decanDays":[],'
        '"kemeticMonthDays":[]};',
    'location': null,
    'all_day': false,
    'starts_at': _localStart.toUtc().toIso8601String(),
    'ends_at': _localStart
        .add(const Duration(minutes: 30))
        .toUtc()
        .toIso8601String(),
    'flow_local_id': _localFlowId,
    'category': null,
    'created_at': '2026-07-30T12:00:00.000Z',
    'updated_at': '2026-07-30T12:00:00.000Z',
  };
}

Map<String, Object?> _userJson() {
  return <String, Object?>{
    'id': _principalId,
    'app_metadata': <String, Object?>{
      'provider': 'email',
      'providers': <String>['email'],
    },
    'user_metadata': const <String, Object?>{},
    'aud': 'authenticated',
    'email': 'reminder-owner@example.com',
    'phone': '',
    'created_at': '2026-01-01T00:00:00.000000Z',
    'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
    'role': 'authenticated',
    'updated_at': '2026-01-01T00:00:00.000000Z',
  };
}

String _sessionJson() {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  return jsonEncode(<String, Object?>{
    'access_token': 'test-access-token-$expiresAt',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': _userJson(),
    'expiresAt': expiresAt,
  });
}
