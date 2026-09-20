import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/shared_calendars_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _recipientId = 'f8eca20c-df58-47c9-a013-c808a26eb120';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'pending invite watcher reconnects when auth restores after subscription',
    () async {
      final httpClient = _PendingInviteHttpClient();
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final repo = SharedCalendarsRepo(client);
      final signedOutEmission = Completer<void>();
      final inviteEmission = Completer<void>();
      final emissions = <int>[];
      final subscription = repo.watchPendingInvites().listen((invites) {
        emissions.add(invites.length);
        if (invites.isEmpty && !signedOutEmission.isCompleted) {
          signedOutEmission.complete();
        }
        if (invites.length == 1 && !inviteEmission.isCompleted) {
          expect(invites.single.sourceFlowKey, 'the-reading-house');
          expect(invites.single.sourceBookTitle, 'catcher in the rye');
          inviteEmission.complete();
        }
      });

      try {
        await signedOutEmission.future.timeout(const Duration(seconds: 2));

        await client.auth.recoverSession(_sessionJson(_recipientId));

        await inviteEmission.future.timeout(const Duration(seconds: 2));
        expect(emissions, containsAllInOrder(<int>[0, 1]));
        expect(httpClient.pendingInviteRequests, greaterThanOrEqualTo(1));
      } finally {
        await subscription.cancel();
        client.dispose();
      }
    },
  );
}

class _PendingInviteHttpClient extends http.BaseClient {
  int pendingInviteRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isPendingInviteView = request.url.path.endsWith(
      '/rest/v1/shared_calendar_invite_filing_items_client',
    );
    if (isPendingInviteView) {
      pendingInviteRequests += 1;
    }
    final body = isPendingInviteView
        ? <Object?>[
            <String, Object?>{
              'calendar_id': '549fc157-819e-46b4-85dc-2be61dc2c66c',
              'calendar_name': 'Reading House · catcher in the rye',
              'calendar_color': 0x0C3B2E,
              'role': 'editor',
              'invited_at': '2026-09-18T12:00:00.000Z',
              'invited_by': '27d63169-a28a-4550-a0a0-8fee0e8e7b95',
              'inviter_handle': 'bigjfil',
              'invite_direction': 'incoming',
              'lifecycle': 'pending',
              'source_flow_id': 966,
              'source_flow_key': 'the-reading-house',
              'source_book_title': 'catcher in the rye',
            },
          ]
        : const <Object?>[];
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      200,
      request: request,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }
}

String _sessionJson(String userId) {
  final expiresAt =
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 3600;
  return jsonEncode(<String, Object?>{
    'access_token': _jwtForUser(userId, expiresAt),
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expiresAt,
    'refresh_token': 'fixture-refresh-token',
    'user': <String, Object?>{
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'recipient@example.com',
      'app_metadata': const <String, Object?>{},
      'user_metadata': const <String, Object?>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  });
}

String _jwtForUser(String userId, int expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode(<String, Object?>{'sub': userId, 'exp': expiresAt})}.signature';
}
