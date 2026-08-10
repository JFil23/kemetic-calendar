import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/user_events_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
const _eventId = 'c6c8d29c-e22c-4b1b-901a-161d0a36a8a6';
const _clientEventId = 'ky=2|km=4|kd=8|title=race|f=-1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'zero-row delete cancels and settles an in-flight staged upsert',
    () async {
      final fixture = _RaceClient();
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: fixture,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      try {
        await client.auth.recoverSession(_sessionJson());
        final repo = UserEventsRepo(client);
        final upsert = repo.upsertByClientId(
          clientEventId: _clientEventId,
          title: 'Race note',
          startsAtUtc: DateTime.utc(2026, 8, 9, 16),
          allDay: true,
          caller: 'delete_race_test',
        );
        final upsertExpectation = expectLater(
          upsert,
          throwsA(isA<UserEventUpsertCancelledException>()),
        );

        await fixture.upsertStarted.future;
        final deletion = repo.delete(_eventId, clientEventId: _clientEventId);
        var deletionCompleted = false;
        unawaited(deletion.then((_) => deletionCompleted = true));

        await fixture.tombstoneRecorded.future;
        await Future<void>.delayed(Duration.zero);
        expect(deletionCompleted, isFalse);

        fixture.releaseUpsert.complete();
        final result = await deletion;
        await upsertExpectation;

        expect(
          result.disposition,
          UserEventDeleteDisposition.alreadyAbsentSuppressed,
        );
        expect(result.isSuccess, isTrue);
        expect(result.suppressionRecorded, isTrue);
        expect(fixture.semanticDeleteCalls, 1);
        expect(fixture.tombstoneCalls, 1);
      } finally {
        if (!fixture.releaseUpsert.isCompleted) {
          fixture.releaseUpsert.complete();
        }
        client.dispose();
      }
    },
  );
}

class _RaceClient extends http.BaseClient {
  final Completer<void> upsertStarted = Completer<void>();
  final Completer<void> releaseUpsert = Completer<void>();
  final Completer<void> tombstoneRecorded = Completer<void>();
  int semanticDeleteCalls = 0;
  int tombstoneCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path == '/rest/v1/user_events' && request.method == 'GET') {
      return _jsonResponse(request, <Object?>[]);
    }
    if (path == '/rest/v1/user_events' && request.method == 'POST') {
      if (!upsertStarted.isCompleted) upsertStarted.complete();
      await releaseUpsert.future;
      return _jsonResponse(request, <String, Object?>{
        'id': _eventId,
        'user_id': _userId,
        'client_event_id': _clientEventId,
        'title': 'Race note',
        'all_day': true,
        'starts_at': '2026-08-09T16:00:00.000Z',
      });
    }
    if (path == '/rest/v1/rpc/delete_user_events_by_ids_semantic') {
      semanticDeleteCalls += 1;
      return _jsonResponse(request, 0);
    }
    if (path == '/rest/v1/rpc/record_user_event_tombstone') {
      tombstoneCalls += 1;
      if (!tombstoneRecorded.isCompleted) tombstoneRecorded.complete();
      return _jsonResponse(request, null);
    }
    return _jsonResponse(request, <String, Object?>{}, statusCode: 404);
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
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
    'user': <String, Object?>{
      'id': _userId,
      'app_metadata': <String, Object?>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'email': 'delete-race@example.com',
      'phone': '',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
      'role': 'authenticated',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
    'expiresAt': expiresAt,
  });
}
