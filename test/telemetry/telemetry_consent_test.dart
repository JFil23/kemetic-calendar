import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/choice_event_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const a = '00000000-0000-4000-8000-000000000001';
const b = '00000000-0000-4000-8000-000000000002';

String session(String id) {
  String encode(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256'})}.${encode({'sub': id, 'exp': expiry})}.sig',
    'refresh_token': 'fixture',
    'token_type': 'bearer',
    'expires_at': expiry,
    'user': {
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<String> writes;
  late List<String> requests;
  bool? enabled;
  Completer<void>? pending;
  setUp(() {
    enabled = true;
    pending = null;
    writes = [];
    requests = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('get_my_telemetry_and_personalization')) {
          final captured = enabled;
          await pending?.future;
          return http.Response(
            jsonEncode(
              captured == null
                  ? []
                  : [
                      {'telemetry_enabled': captured},
                    ],
            ),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method.toUpperCase() == 'POST')
          writes.add(request.url.path);
        return http.Response(
          '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDown(() => client.dispose());

  Future<void> exercise() async {
    await UserEventsRepo(client).track(event: 'screen_view');
    await SupabaseChoiceEventTracker(
      client,
    ).trackChoiceEvent(eventType: 'node_opened');
    await RhythmTelemetry.recordCycleFieldSaved(
      client: client,
      fieldId: 'fixture',
      category: 'cycle',
      isTimed: false,
      remindersEnabled: false,
      patternCount: 1,
    );
  }

  test('no session, opt-out and missing preference all fail closed', () async {
    await exercise();
    expect(writes, isEmpty);
    await client.auth.recoverSession(session(a));
    enabled = false;
    await exercise();
    enabled = null;
    await exercise();
    expect(writes, isEmpty);
  });

  test(
    'both event pipelines use current acknowledged preference each time',
    () async {
      await client.auth.recoverSession(session(a));
      expect(client.auth.currentUser?.id, a);
      expect(await client.rpc('get_my_telemetry_and_personalization'), [
        {'telemetry_enabled': true},
      ]);
      await exercise();
      expect(
        writes.where((p) => p.endsWith('app_events')),
        hasLength(2),
        reason: requests.toString(),
      );
      expect(
        writes.where((p) => p.endsWith('track_choice_event')),
        hasLength(2),
      );
      writes.clear();
      enabled = false;
      await exercise();
      expect(writes, isEmpty);
    },
  );

  for (final returnToA in [false, true]) {
    test(
      'pending consent cannot publish after account departure, return=$returnToA',
      () async {
        await client.auth.recoverSession(session(a));
        pending = Completer<void>();
        final work = UserEventsRepo(client).track(event: 'screen_view');
        await Future<void>.delayed(Duration.zero);
        await client.auth.recoverSession(session(b));
        if (returnToA) await client.auth.recoverSession(session(a));
        await Future<void>.delayed(Duration.zero);
        pending!.complete();
        await work;
        expect(writes, isEmpty);
      },
    );
  }
}
