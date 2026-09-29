import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/warm_state/app_warm_state.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'foreground warming issues passive reads only and stops while backgrounded',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final object = r.url.path.contains('get_commons_together_home_cards')
              ? {}
              : [];
          return http.Response(
            jsonEncode(object),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final warm = AppWarmState(client)..start();
      addTearDown(() async {
        warm.dispose();
        await client.dispose();
      });
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (WarmSnapshotStore.instance.peek(uid, 'pages.flows') == null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(requests, isNotEmpty);
      expect(
        WarmSnapshotStore.instance.peek(uid, 'pages.flows'),
        isNotNull,
        reason: requests.map((r) => r.url.path).join(', '),
      );
      for (final request in requests) {
        expect(
          request.method == 'GET' ||
              (request.method == 'POST' &&
                  request.url.path.contains('/rpc/get_')),
          isTrue,
          reason:
              '${request.method} ${request.url.path} must be a passive read',
        );
      }
      warm.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final count = requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requests.length, count);
    },
  );
}
