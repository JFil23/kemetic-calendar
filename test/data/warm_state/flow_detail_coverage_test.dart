import 'dart:convert';
import 'package:mobile/data/flows_repo.dart';
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
    'owned flow detail restores offline, retains good data after failed refresh and fences logout',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      var status = 200;
      var reads = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/v1/logout') {
            return http.Response('{}', 200, request: request);
          }
          reads++;
          return http.Response(
            status == 200
                ? jsonEncode({
                    'id': 42,
                    'user_id': uid,
                    'name': 'Follow the Sky',
                    'active': true,
                    'is_saved': false,
                    'rules': [],
                    'notes': 'maat=track-the-sky',
                  })
                : '{"message":"offline","code":"503"}',
            status,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final repo = FlowsRepo(client);
      await expectLater(
        repo.getFlowById(42, cachedOnly: true),
        throwsA(isA<WarmCacheMiss>()),
      );
      expect(reads, 0);
      final cold = await repo.getFlowById(42);
      expect(cold!.id, 42);
      expect(cold.notes, 'maat=track-the-sky');
      expect(reads, 1);
      await WarmSnapshotStore.instance.flushed;
      expect(
        (await WarmSnapshotStore().cached(uid, 'flow.detail.42')) as Map,
        containsPair('id', 42),
      );
      status = 503;
      final warm = await repo.getFlowById(42, cachedOnly: true);
      expect(warm!.notes, cold.notes);
      expect(reads, 1);
      await expectLater(
        repo.getFlowById(42),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await repo.getFlowById(42, cachedOnly: true))!.name,
        'Follow the Sky',
      );
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(
        repo.getFlowById(42, cachedOnly: true),
        throwsA(isA<WarmReadCancelled>()),
      );
      await client.dispose();
    },
  );

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
