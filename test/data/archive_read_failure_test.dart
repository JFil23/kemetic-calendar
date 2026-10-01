import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/decan_reflection_repo.dart';
import 'package:mobile/data/maat_guidance_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final denied in [false, true]) {
    test(
      'archive failure discards cache only for access denial: $denied',
      () async {
        SharedPreferences.setMockInitialValues({});
        await WarmSnapshotStore.instance.forgetAccount(uid);
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            if (!denied) throw http.ClientException('offline');
            return http.Response(
              jsonEncode({'code': '42501', 'message': 'Denied'}),
              403,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        await client.auth.recoverSession(session());
        final reflections = await DecanReflectionRepo(client).listMineResult();
        final openings = await MaatGuidanceRepo(
          client,
        ).listDecanOpeningsForArchive();
        expect(reflections.hasError, isTrue);
        expect(openings.hasError, isTrue);
        expect(reflections.discardCached, denied);
        expect(openings.discardCached, denied);
        await client.dispose();
      },
    );
  }
  test(
    'same-account invalidation cancels refresh without discarding the visible snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          WarmSnapshotStore.instance.invalidate(uid);
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final result = await DecanReflectionRepo(client).listMineResult();
      expect(result.hasError, isTrue);
      expect(result.discardCached, isFalse);
      await client.dispose();
    },
  );
}
