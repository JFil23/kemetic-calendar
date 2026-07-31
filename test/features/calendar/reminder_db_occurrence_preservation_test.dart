import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/reminders/reminder_rule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _principalId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
const _eventId = 'c6c8d29c-e22c-4b1b-901a-161d0a36a8a6';
const _reminderId = '4a42c9c8-6249-4adc-8a73-65d3b63ea642';
const _calendarId = '42e0e5ca-55b9-4948-a17c-4ba41cc0213e';
const _flowId = 642;
final _eventDate = DateTime(2026, 7, 27);
final _eventStart = DateTime(2026, 7, 27, 17);
final _eventEnd = DateTime(2026, 7, 27, 17, 30);
final _clientEventId = 'reminder:$_reminderId:2026-07-27';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'startup reminder sync preserves the authoritative Family Salon occurrence',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app:has_seen_onboarding': true,
        'app:onboarding:completed': true,
      });
      final fixtureClient = _CalendarFixtureClient();

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
      for (var attempt = 0; attempt < 240; attempt++) {
        await tester.pump(const Duration(milliseconds: 25));

        final state = CalendarPage.globalKey.currentState;
        if (state == null || fixtureClient.reminderOccurrenceReads == 0) {
          continue;
        }
        final kDate = KemeticMath.fromGregorian(_eventDate);
        final signature = [
          fixtureClient.requests.length,
          fixtureClient.reminderOccurrenceReads,
          state.filteredNoteCountForDay(kDate.kYear, kDate.kMonth, kDate.kDay),
        ].join(':');
        if (signature == previousSignature) {
          stableSamples++;
        } else {
          previousSignature = signature;
          stableSamples = 1;
        }
        if (stableSamples >= 4) break;
      }

      expect(
        fixtureClient.reminderOccurrenceReads,
        greaterThan(0),
        reason: 'The real startup reminder synchronization must execute.',
      );
      expect(fixtureClient.unexpectedMutations, isEmpty);

      final kDate = KemeticMath.fromGregorian(_eventDate);
      final notes = CalendarPage.globalKey.currentState!.notesForDayForTesting(
        kDate.kYear,
        kDate.kMonth,
        kDate.kDay,
      );

      expect(notes, hasLength(1));
      expect(notes.single.id, _eventId);
      expect(notes.single.clientEventId, _clientEventId);
      expect(notes.single.flowId, _flowId);
      expect(notes.single.calendarId, _calendarId);
      expect(notes.single.title, 'Family Salon');
      expect(notes.single.isReminder, isTrue);
      expect(notes.single.reminderId, _reminderId);
      expect(notes.single.start, const TimeOfDay(hour: 17, minute: 0));
      expect(notes.single.end, const TimeOfDay(hour: 17, minute: 30));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
}

class _CalendarFixtureClient extends http.BaseClient {
  final List<Uri> requests = <Uri>[];
  final List<String> unexpectedMutations = <String>[];
  int reminderOccurrenceReads = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final path = request.url.path;
    final isReadRpc =
        request.method == 'POST' && path.startsWith('/rest/v1/rpc/');
    if (path.startsWith('/rest/v1/') &&
        request.method != 'GET' &&
        request.method != 'HEAD' &&
        request.method != 'OPTIONS' &&
        !isReadRpc) {
      unexpectedMutations.add('${request.method} ${request.url}');
    }

    if (path == '/auth/v1/user') {
      return _jsonResponse(request, _userJson());
    }
    if (path == '/rest/v1/flows_with_calendars') {
      return _jsonResponse(request, <Object?>[_flowRow()]);
    }
    if (path == '/rest/v1/flows') {
      final wantsObject =
          request.headers['accept']?.contains('application/vnd.pgrst.object') ??
          false;
      return _jsonResponse(
        request,
        wantsObject
            ? <String, Object?>{'id': _flowId}
            : <Object?>[
                <String, Object?>{'id': _flowId},
              ],
      );
    }
    if (path == '/rest/v1/user_event_filing_items_client') {
      final itemKind = request.url.queryParameters['item_kind'] ?? '';
      final select = request.url.queryParameters['select'] ?? '';
      if (itemKind.contains('flow')) {
        return _jsonResponse(request, const <Object?>[]);
      }
      if (itemKind.contains('note') || itemKind.contains('reminder')) {
        return _jsonResponse(request, <Object?>[_filingRow()]);
      }
      if (select.contains('filed_flow_id')) {
        return _jsonResponse(request, const <Object?>[]);
      }
      return _jsonResponse(request, const <Object?>[]);
    }
    if (path == '/rest/v1/user_events') {
      if ((request.url.queryParameters['client_event_id'] ?? '').contains(
        'like.',
      )) {
        reminderOccurrenceReads++;
      }
      return _jsonResponse(request, const <Object?>[]);
    }
    if (path.startsWith('/rest/v1/')) {
      return _jsonResponse(request, const <Object?>[]);
    }
    return _jsonResponse(request, const <String, Object?>{});
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

Map<String, Object?> _flowRow() {
  final rule = ReminderRule(
    id: _reminderId,
    calendarId: _calendarId,
    title: 'Family Salon',
    startLocal: _eventStart,
    color: const Color(0xFFB68B2E),
  );
  return <String, Object?>{
    'id': _flowId,
    'user_id': _principalId,
    'calendar_id': _calendarId,
    'name': 'Family Salon',
    'color': 0xB68B2E,
    'active': true,
    'is_saved': false,
    'start_date': '2026-07-27',
    'end_date': null,
    'notes': jsonEncode(rule.toJson()),
    'rules': const <Object?>[],
    'share_id': null,
    'is_hidden': false,
    'is_reminder': true,
    'reminder_uuid': _reminderId,
    'created_at': '2026-07-01T00:00:00.000Z',
    'updated_at': '2026-07-27T23:59:00.000Z',
  };
}

Map<String, Object?> _filingRow() {
  return <String, Object?>{
    'id': _eventId,
    'calendar_id': _calendarId,
    'calendar_name': 'Personal',
    'calendar_color': 0xB68B2E,
    'calendar_is_personal': true,
    'client_event_id': _clientEventId,
    'title': 'Family Salon',
    'detail': null,
    'location': null,
    'all_day': false,
    'starts_at': _eventStart.toUtc().toIso8601String(),
    'ends_at': _eventEnd.toUtc().toIso8601String(),
    'flow_local_id': _flowId,
    'filed_flow_id': _flowId,
    'item_kind': 'reminder',
    'category': null,
    'action_id': 'shared_practice',
    'behavior_payload': <String, Object?>{
      'room_id': '27e2495f-c439-40a1-8a81-54885a9d3596',
    },
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
    'email': 'family-salon-owner@example.com',
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
