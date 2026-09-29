import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only complete paginated flow details are durable; failed refresh retains them',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      var fail = false;
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests++;
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          if (fail && offset > 0) {
            return http.Response(
              '{"message":"offline","code":"503"}',
              503,
              request: request,
            );
          }
          final count = offset == 0 ? 500 : 2;
          return http.Response(
            jsonEncode(
              List.generate(
                count,
                (i) => {
                  'id': 'event-${offset + i}',
                  'user_id': uid,
                  'filed_flow_id': 987,
                  'title': 'Occurrence ${offset + i}',
                  'starts_at': '2026-09-29T12:00:00Z',
                  'all_day': false,
                  'item_kind': 'flow',
                  'lifecycle': 'active',
                },
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final repo = UserEventsRepo(client);
      expect(await repo.getFlowDetailEvents(987), hasLength(502));
      expect(requests, 2);
      await WarmSnapshotStore.instance.flushed;
      expect(
        await WarmSnapshotStore().cached(uid, 'flow.events.987'),
        hasLength(502),
      );
      fail = true;
      await expectLater(
        repo.getFlowDetailEvents(987),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        await repo.getFlowDetailEvents(987, cachedOnly: true),
        hasLength(502),
      );
      expect(requests, 4);
      await client.dispose();
    },
  );
}
