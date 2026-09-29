import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/warm_state/warm_json_reads.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'explicit permission denial evicts a private snapshot; offline failure does not',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      var status = 200;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            status == 200
                ? '[{"id":"post"}]'
                : status == 403
                ? '{"message":"denied","code":"42501"}'
                : '{"message":"offline","code":"503"}',
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await client.auth.recoverSession(session());
      final reads = WarmJsonReads(client);
      Future<Object?> fetch() async => client.from('flow_posts').select();
      await reads.rows('social.post.private', fetch);
      status = 503;
      await expectLater(
        reads.rows('social.post.private', fetch),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        WarmSnapshotStore.instance.peek(uid, 'social.post.private'),
        isNotNull,
      );
      status = 403;
      await expectLater(
        reads.rows('social.post.private', fetch),
        throwsA(isA<WarmAccessDenied>()),
      );
      expect(
        WarmSnapshotStore.instance.peek(uid, 'social.post.private'),
        isNull,
      );
      await WarmSnapshotStore.instance.flushed;
      await expectLater(
        WarmSnapshotStore().cached(uid, 'social.post.private'),
        throwsA(isA<WarmCacheMiss>()),
      );
      await client.dispose();
    },
  );
}
