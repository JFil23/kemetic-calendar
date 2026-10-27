import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/pages/pages_resource_test.dart' show session, uid;

class _HeldFallbackRepo extends FlowsRepo {
  _HeldFallbackRepo(super.client);
  final started = Completer<void>();
  final held = Completer<List<FlowRow>?>();

  @override
  Future<List<FlowRow>?> restoreCachedFiledFlows() {
    started.complete();
    return held.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account departure fences an offline fallback already being restored',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('/logout')
                ? '{}'
                : '{"message":"offline"}',
            request.url.path.endsWith('/logout') ? 200 : 503,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      await client.auth.recoverSession(session());
      final repo = _HeldFallbackRepo(client);
      addTearDown(() async {
        if (!repo.held.isCompleted) repo.held.complete(const []);
        await client.dispose();
      });
      await repo.clearMyFiledFlowsCache();
      final read = repo.refreshMyFiledFlows();
      final cancelled = expectLater(read, throwsA(isA<WarmReadCancelled>()));
      await repo.started.future;
      await client.auth.signOut();
      await client.auth.recoverSession(session());
      repo.held.complete(const []);
      await cancelled;
    },
  );
  for (final boundary in [
    'concurrent callers',
    'mutation',
    'account departure',
  ]) {
    test('filed flow reads share work and respect $boundary', () async {
      SharedPreferences.setMockInitialValues({});
      var reads = 0, supplements = 0;
      final started = Completer<void>(), held = Completer<void>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final path = request.url.path.split('/').last;
          Object data = [];
          if (path == 'get_my_filed_flows_v1') {
            final call = ++reads;
            if (call == 1) {
              started.complete();
              await held.future;
            }
            data = [
              {
                'id': call,
                'user_id': uid,
                'name': 'Flow $call',
                'active': true,
                'rules': [],
              },
            ];
          }
          if (path == 'get_my_held_reading_houses_v1') supplements++;
          if (path == 'logout') data = {};
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      addTearDown(() async {
        if (!held.isCompleted) held.complete();
        await client.dispose();
      });
      final repo = FlowsRepo(client);
      await repo.clearMyFiledFlowsCache();
      final first = repo.refreshMyFiledFlows();
      await started.future;
      if (boundary == 'concurrent callers') {
        final others = [
          for (var i = 0; i < 12; i++) FlowsRepo(client).refreshMyFiledFlows(),
        ];
        expect(reads, 1);
        held.complete();
        final results = await Future.wait([first, ...others]);
        expect(results.every((rows) => rows.single.id == 1), isTrue);
        expect(reads, 1);
        expect(supplements, 1);
        await repo.refreshMyFiledFlows();
        expect(reads, 2, reason: 'Completed requests are not a new cache');
      } else if (boundary == 'mutation') {
        await repo.clearMyFiledFlowsCache();
        expect((await repo.refreshMyFiledFlows()).single.id, 2);
        held.complete();
        await first;
        expect(reads, 2);
        expect(
          repo.cachedMyFiledFlowsSync()!.single.id,
          2,
          reason:
              'The old response cannot overwrite the acknowledged generation',
        );
      } else {
        final departed = expectLater(first, throwsA(isA<WarmReadCancelled>()));
        await client.auth.signOut();
        await client.auth.recoverSession(session());
        expect((await repo.refreshMyFiledFlows()).single.id, 2);
        held.complete();
        await departed;
        expect(reads, 2);
        expect(repo.cachedMyFiledFlowsSync()!.single.id, 2);
      }
    });
  }
}
