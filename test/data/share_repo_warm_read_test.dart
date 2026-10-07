import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/pages/pages_resource_test.dart' show uid, session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late ShareRepo repo;
  late String account;
  var testIndex = 0;
  var reads = 0;
  var unavailable = false;
  var denied = false;
  var rows = <Map<String, dynamic>>[];
  Completer<void>? hold;

  Map<String, dynamic> item(int i) => {
    'share_id': 'share-$i',
    'kind': 'flow',
    'sender_id': account,
    'recipient_id': 'friend',
    'payload_id': '$i',
    'title': 'Flow $i',
    'created_at': '2026-10-07T10:00:00Z',
    'payload_json': {
      'name': 'Flow $i',
      'events': [],
      'appearance': {'version': 1, 'image_object_path': 'fixture/hero.jpg'},
    },
  };

  setUp(() async {
    account =
        '10000000-0000-4000-8000-${(++testIndex).toString().padLeft(12, '0')}';
    SharedPreferences.setMockInitialValues({});
    reads = 0;
    hold = null;
    unavailable = false;
    denied = false;
    rows = [item(1)];
    client = SupabaseClient(
      'https://example.supabase.test',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body = [];
        if (request.url.path.endsWith('/share_filing_items_client') ||
            request.url.path.endsWith('/inbox_share_items_filtered')) {
          reads++;
          if (denied) {
            return http.Response(
              jsonEncode({'code': '42501', 'message': 'permission denied'}),
              403,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          final response = List<Map<String, dynamic>>.of(rows);
          await hold?.future;
          if (unavailable) {
            return http.Response('unavailable', 503, request: request);
          }
          body = response;
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.recoverSession(session().replaceAll(uid, account));
    repo = ShareRepo(client);
  });
  tearDown(() async => client.dispose());

  test(
    'simultaneous account reads share one request and retain full preview payload',
    () async {
      hold = Completer<void>();
      final first = repo.getInboxItems(throwOnError: true);
      final second = ShareRepo(client).getInboxItems(throwOnError: true);
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      hold!.complete();
      hold = null;
      await Future.wait([first, second]);
      expect(repo.cachedInboxItemsSync()!.single.payloadJson!['appearance'], {
        'version': 1,
        'image_object_path': 'fixture/hero.jpg',
      });
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('inbox:shares:v1:$account')!),
        hasLength(1),
      );
    },
  );

  test(
    'bounded refresh does not erase older cached conversation previews',
    () async {
      rows = [for (var i = 0; i < 70; i++) item(i)];
      await repo.getInboxItems(limit: 100, throwOnError: true);
      rows = [item(69)];
      await repo.getInboxItems(limit: 1, throwOnError: true);
      expect(repo.cachedInboxItemsSync(), hasLength(70));
    },
  );

  for (final returnToOriginal in [false, true]) {
    test(
      'late inbox response cannot publish after account departure (return=$returnToOriginal)',
      () async {
        hold = Completer<void>();
        final pending = repo.getInboxItems(throwOnError: true);
        final rejected = expectLater(
          pending,
          throwsA(isA<ViewReadCancelled>()),
        );
        await Future<void>.delayed(Duration.zero);
        await client.auth.recoverSession(
          session().replaceAll(uid, '20000000-0000-4000-8000-000000000001'),
        );
        if (returnToOriginal) {
          await client.auth.recoverSession(session().replaceAll(uid, account));
        }
        await Future<void>.delayed(Duration.zero);
        hold!.complete();
        hold = null;
        await rejected;
        expect(repo.cachedInboxItemsSync(), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('inbox:shares:v1:$account'), isNull);
      },
    );
  }

  test(
    'failed refresh retains confirmed previews and never saves an empty inbox',
    () async {
      await repo.getInboxItems(throwOnError: true);
      unavailable = true;
      await expectLater(
        repo.getInboxItems(throwOnError: true),
        throwsA(anything),
      );
      expect(repo.cachedInboxItemsSync()!.single.title, 'Flow 1');
    },
  );

  test(
    'confirmed access denial evicts stale previews without a legacy bypass',
    () async {
      await repo.getInboxItems(throwOnError: true);
      denied = true;
      final before = reads;
      await expectLater(
        repo.getInboxItems(throwOnError: true),
        throwsA(isA<PostgrestException>()),
      );
      expect(reads - before, 1);
      expect(repo.cachedInboxItemsSync(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('inbox:shares:v1:$account'), isNull);
    },
  );

  test(
    'old deployed inbox snapshot restores without a network request',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('inbox:shares:v1:$account', jsonEncode([item(8)]));
      unavailable = true;
      final restored = await repo.restoreCachedInboxItems();
      expect(restored!.single.title, 'Flow 8');
      expect(restored.single.payloadJson!['appearance'], isNotNull);
      expect(reads, 0);
    },
  );
}
