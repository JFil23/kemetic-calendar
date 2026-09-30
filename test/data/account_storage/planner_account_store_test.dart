import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/account_storage/planner_account_store.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

class AccountServer {
  final rows = <String, Map<String, dynamic>>{};
  final receipts = <String, Map<String, dynamic>>{};
  final backups = <Map<String, dynamic>>[];
  final sent = <Map<String, dynamic>>[];
  bool offline = false, loseReply = false;
  Completer<void>? hold;
  Future<http.Response> handle(http.Request request) async {
    if (offline) throw http.ClientException('offline');
    Object data = [];
    if (request.url.path.endsWith('apply_planner_mutation_v1')) {
      final p = jsonDecode(request.body) as Map<String, dynamic>;
      sent.add(p);
      await hold?.future;
      final mid = p['p_mutation_id'] as String;
      final id = p['p_record_id'] as String;
      if (!receipts.containsKey(mid)) {
        final before = rows[id];
        final expected = p['p_expected_revision'];
        final conflict = before != null
            ? expected != before['planner_revision']
            : expected != null && p['p_delete'] != true;
        Map<String, dynamic>? after;
        if (!conflict && p['p_delete'] != true) {
          after = {
            ...?before,
            ...Map<String, dynamic>.from(p['p_change'] as Map),
            'id': id,
            'user_id': p['p_account_id'],
            'planner_revision': (before?['planner_revision'] as int? ?? 0) + 1,
            'created_at': '2026-09-29T00:00:00Z',
          };
          rows[id] = after;
        } else if (!conflict) {
          rows.remove(id);
        }
        receipts[mid] = {
          'mutation_id': mid,
          'kind': p['p_kind'],
          'record_id': id,
          'request': {'change': p['p_change'], 'delete': p['p_delete']},
          'result': {
            'mutation_id': mid,
            'status': conflict ? 'conflict' : 'applied',
            'row': conflict ? before : after,
          },
        };
      }
      data = receipts[mid]!['result'];
      if (loseReply) {
        loseReply = false;
        throw http.ClientException('reply lost after commit');
      }
    } else if (request.url.path.endsWith('planner_legacy_recovery')) {
      backups.add(jsonDecode(request.body) as Map<String, dynamic>);
    } else if (request.url.path.endsWith('planner_mutation_receipts')) {
      data = receipts.values
          .where((r) => (r['result'] as Map)['status'] == 'conflict')
          .toList();
    } else if (request.url.path.endsWith('alignment_notes') ||
        request.url.path.endsWith('nutrition_items')) {
      data = rows.values.toList();
    }
    return http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountServer server;
  late SupabaseClient client;
  late PlannerAccountStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = AccountServer();
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(server.handle),
    );
    await client.auth.recoverSession(session());
    store = PlannerAccountStore(client);
  });
  tearDown(() async {
    store.dispose();
    await client.dispose();
  });

  test(
    'offline note is durable before acknowledgement and recovers after restart',
    () async {
      server.offline = true;
      final id = await store.save('notes', {
        'body': 'keep this',
        'position': 0,
      });
      await store.flush();
      expect(store.pending('notes'), isTrue);
      final raw = (await SharedPreferences.getInstance()).getString(
        PlannerAccountStore.storageKey(uid),
      )!;
      expect(raw, contains('keep this'));
      store.dispose();
      store = PlannerAccountStore(client);
      await store.restore();
      expect(store.rows('notes').single['id'], id);
      server.offline = false;
      await store.flush();
      expect(store.pending('notes'), isFalse);
      expect(server.rows[id]!['body'], 'keep this');
    },
  );
  test(
    'lost acknowledgement retries the same mutation without duplicates',
    () async {
      server.loseReply = true;
      await store.save('notes', {'body': 'once', 'position': 0});
      await store.flush();
      expect(store.pending('notes'), isTrue);
      store.dispose();
      store = PlannerAccountStore(client);
      await store.flush();
      expect(server.rows.length, 1);
      expect(server.sent.length, 2);
      expect(server.sent[0]['p_mutation_id'], server.sent[1]['p_mutation_id']);
      expect(store.pending('notes'), isFalse);
    },
  );
  test(
    'edits queued during an in-flight create follow its acknowledged revision',
    () async {
      server.hold = Completer<void>();
      final id = await store.save('notes', {'body': 'first', 'position': 0});
      await store.save('notes', {'body': 'second'}, id: id);
      server.hold!.complete();
      await store.flush();
      expect(server.rows[id]!['body'], 'second');
      expect(server.sent.last['p_expected_revision'], 1);
      expect(store.conflicts(), isEmpty);
    },
  );
  test(
    'delete remains hidden while offline and reaches the account after restart',
    () async {
      final id = await store.save('notes', {
        'body': 'delete me',
        'position': 0,
      });
      await store.flush();
      server.offline = true;
      await store.save('notes', {}, id: id, delete: true);
      await store.flush();
      expect(store.rows('notes'), isEmpty);
      store.dispose();
      store = PlannerAccountStore(client);
      await store.restore();
      expect(store.rows('notes'), isEmpty);
      server.offline = false;
      await store.flush();
      expect(server.rows, isEmpty);
    },
  );
  test(
    'conflicting edits are preserved remotely and recovered by a fresh device',
    () async {
      final id = await store.save('notes', {'body': 'original', 'position': 0});
      await store.flush();
      server.rows[id] = {
        ...server.rows[id]!,
        'body': 'other device',
        'planner_revision': 2,
      };
      await store.save('notes', {'body': 'offline version'}, id: id);
      await store.flush();
      expect(server.rows[id]!['body'], 'other device');
      expect(
        store.conflicts('notes').single['request']['change']['body'],
        'offline version',
      );
      store.dispose();
      SharedPreferences.setMockInitialValues({});
      store = PlannerAccountStore(client);
      await store.refresh('notes');
      expect(store.rows('notes').single['body'], 'other device');
      expect(
        store.conflicts('notes').single['request']['change']['body'],
        'offline version',
      );
    },
  );
  test(
    'legacy local notes upload once with stable identity and leave original backup',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('today_alignment_notes_$uid', [
        jsonEncode({'id': 'local_12', 'text': 'legacy', 'position': 0}),
      ]);
      await store.restore();
      expect(store.rows('notes').single['body'], 'legacy');
      await store.refresh('notes');
      expect(server.rows.length, 1);
      await store.refresh('notes');
      expect(server.rows.length, 1);
      expect(prefs.getStringList('today_alignment_notes_$uid'), isNotEmpty);
    },
  );
  test(
    'legacy changed account copy becomes a recovery conflict instead of overwriting',
    () async {
      const id = '10000000-0000-4000-8000-000000000001';
      server.rows[id] = {
        'id': id,
        'body': 'cloud',
        'position': 0,
        'planner_revision': 2,
        'created_at': '2026-01-01T00:00:00Z',
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('today_alignment_notes_$uid', [
        jsonEncode({'id': id, 'text': 'legacy edit', 'position': 0}),
      ]);
      await store.refresh('notes');
      expect(server.rows[id]!['body'], 'cloud');
      expect(
        store.conflicts().single['request']['change']['body'],
        'legacy edit',
      );
    },
  );
  test('unknown durable schema is never overwritten or discarded', () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({
      'schema': 999,
      'userId': uid,
      'pending': [
        {'body': 'future edit'},
      ],
    });
    await prefs.setString(PlannerAccountStore.storageKey(uid), raw);
    await expectLater(store.save('notes', {'body': 'new'}), throwsStateError);
    expect(prefs.getString(PlannerAccountStore.storageKey(uid)), raw);
    expect(server.sent, isEmpty);
  });
  test(
    'signout during a save retains the intent and fences UI publication',
    () async {
      server.hold = Completer<void>();
      await store.save('notes', {'body': 'account A', 'position': 0});
      await client.auth.signOut(scope: SignOutScope.local);
      server.hold!.complete();
      await store.flush();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(store.rows('notes'), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          PlannerAccountStore.storageKey(uid),
        ),
        contains('account A'),
      );
      await client.auth.recoverSession(session());
      await store.flush();
      expect(server.sent.every((p) => p['p_account_id'] == uid), isTrue);
      expect(store.rows('notes').single['body'], 'account A');
    },
  );
  test(
    'legacy checkmark backup retries into the account without erasing the source',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final key = 'today_alignment_nutrition_checks_$uid';
      await prefs.setStringList(key, ['2026-09-29::local-fixture::done']);
      server.offline = true;
      await expectLater(
        store.preserveLegacyCheckmarks(),
        throwsA(isA<http.ClientException>()),
      );
      expect(prefs.getBool('$key:archived'), isNull);
      server.offline = false;
      await store.preserveLegacyCheckmarks();
      await store.preserveLegacyCheckmarks();
      expect(server.backups, hasLength(1));
      expect(server.backups.single['user_id'], uid);
      expect(
        server.backups.single['payload']['values'],
        prefs.getStringList(key),
      );
      expect(prefs.getStringList(key), ['2026-09-29::local-fixture::done']);
    },
  );
}
