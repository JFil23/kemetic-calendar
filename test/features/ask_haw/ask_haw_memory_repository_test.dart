import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/pages_resource_test.dart' show session, uid;

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> _memory({
  int revision = 0,
  int epoch = 0,
  Map<String, dynamic> payload = const {},
}) => {'revision': revision, 'epoch': epoch, 'payload': payload};

Map<String, dynamic> _document(SharedPreferences prefs) =>
    Map<String, dynamic>.from(
      jsonDecode(prefs.getString(AskHawMemoryRepository.storageKey(uid))!)
          as Map,
    );

/// Controlled acknowledgements exercise the real repository, account fence and
/// durable document. Merge/SQL semantics are covered by the backend smoke.
class _Gateway {
  Map<String, dynamic> row = _memory();
  final reads = <Map<String, dynamic>>[];
  final writes = <Map<String, dynamic>>[];
  FutureOr<Map<String, dynamic>> Function(Map<String, dynamic>)? onWrite;

  Future<dynamic> invoke(String name, Map<String, dynamic> params) async {
    if (name == 'read_ask_haw_memory_v1') {
      reads.add(_copy(params));
      return {'status': 'ready', 'row': _copy(row)};
    }
    expect(name, 'apply_ask_haw_memory_v1');
    writes.add(_copy(params));
    if (onWrite == null) throw StateError('Unexpected memory mutation');
    return onWrite!(_copy(params));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late SupabaseClient client;
  late _Gateway gateway;
  late List<AskHawMemoryRepository> repositories;

  AskHawMemoryRepository repository({
    Future<SharedPreferences> Function()? preferences,
  }) {
    final value = AskHawMemoryRepository(
      client,
      preferences: preferences ?? () async => prefs,
      invoke: gateway.invoke,
    );
    repositories.add(value);
    return value;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway = _Gateway();
    repositories = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) => throw StateError('Unexpected raw request')),
    );
    await client.auth.recoverSession(session());
  });

  tearDown(() async {
    for (final repo in repositories) {
      repo.dispose();
    }
    await client.dispose();
  });

  test(
    'request is durable before RPC and only acknowledgement changes memory',
    () async {
      gateway.row = _memory(revision: 7, epoch: 2);
      final repo = repository();
      await repo.read();
      gateway.onWrite = (request) {
        final doc = _document(prefs);
        expect(doc['pending'], [request]);
        expect((doc['confirmed'] as Map)['revision'], 7);
        expect(repo.confirmed.revision, 7);
        expect(request['p_expected_revision'], 7);
        expect(request['p_expected_epoch'], 2);
        expect(request['p_account'], uid);
        gateway.row = _memory(
          revision: 8,
          epoch: 2,
          payload: {
            'preferences': {'preferredDurationMinutes': 10},
          },
        );
        return {'status': 'applied', 'row': gateway.row};
      };
      final result = await repo.update({
        'preferences': {'preferredDurationMinutes': 10},
      });
      expect(result.preferredDurationMinutes, 10);
      expect(result.revision, 8);
      expect(_document(prefs)['pending'], isEmpty);
      expect(prefs.getKeys(), {AskHawMemoryRepository.storageKey(uid)});
      expect(
        _document(prefs).keys,
        unorderedEquals([
          'schema',
          'account',
          'confirmed',
          'pending',
          'conflicts',
        ]),
      );
    },
  );

  test(
    'lost acknowledgement reopens and retries the exact durable identity',
    () async {
      final repo = repository();
      await repo.read();
      var committed = 0;
      gateway.onWrite = (request) {
        if (committed == 0) {
          committed++;
          gateway.row = _memory(
            revision: 1,
            payload: {
              'bindings': {
                'evening reset': {'intent': 'find', 'query': 'stability'},
              },
            },
          );
          throw StateError('Reply lost after commit');
        }
        expect(request, gateway.writes.first);
        return {'status': 'applied', 'row': gateway.row};
      };
      await expectLater(
        repo.update({
          'bindings': {
            'evening reset': {'intent': 'find', 'query': 'stability'},
          },
        }),
        throwsStateError,
      );
      final pending = (_document(prefs)['pending'] as List).single;
      expect(pending, gateway.writes.single);
      expect(repo.confirmed.revision, 0);
      repo.dispose();
      final reopened = repository();
      final restored = await reopened.read();
      expect(gateway.writes, [pending, pending]);
      expect(committed, 1);
      expect(restored.revision, 1);
      expect(restored.bindingFor('evening reset')!['query'], 'stability');
      expect(await reopened.preservedChanges(), isEmpty);
    },
  );

  test(
    'clear precedes queued learning and fences its old epoch after acknowledgement',
    () async {
      gateway.row = _memory(revision: 4, epoch: 2);
      final repo = repository();
      await repo.read();
      gateway.onWrite = (_) {
        // The server committed this learning, but the response was lost.
        gateway.row = _memory(
          revision: 5,
          epoch: 2,
          payload: {
            'hidden': ['flow:7'],
          },
        );
        throw StateError('Reply lost');
      };
      await expectLater(
        repo.update({
          'hidden': ['flow:7'],
        }),
        throwsStateError,
      );
      final oldRequest = _copy(gateway.writes.single);
      gateway.onWrite = (request) {
        expect(request['p_operation'], 'clear');
        expect(request['p_expected_revision'], 5);
        expect(request['p_expected_epoch'], 2);
        final pending = _document(prefs)['pending'] as List;
        expect(pending.length, 2);
        expect(pending.first, request);
        expect(pending.last, oldRequest);
        gateway.row = _memory(revision: 6, epoch: 3);
        return {'status': 'applied', 'row': gateway.row};
      };
      final cleared = await repo.clear();
      expect(cleared.epoch, 3);
      expect(cleared.payload, isEmpty);
      expect(gateway.writes.map((r) => r['p_operation']), ['patch', 'clear']);
      expect(await repo.preservedChanges(), isEmpty);
      final reopened = repository();
      expect((await reopened.read()).payload, isEmpty);
      expect(gateway.writes.length, 2);
    },
  );

  test(
    'stale rendered revision conflicts without rebasing or dropping the intent',
    () async {
      gateway.row = _memory(revision: 3, epoch: 1);
      final repo = repository();
      await repo.read();
      gateway.row = _memory(
        revision: 4,
        epoch: 1,
        payload: {
          'preferences': {'preferredTimeOfDay': 'morning'},
        },
      );
      gateway.onWrite = (request) {
        expect(request['p_expected_revision'], 3);
        return {'status': 'conflict', 'row': gateway.row};
      };
      await expectLater(
        repo.update({
          'preferences': {'preferredTimeOfDay': 'evening'},
        }),
        throwsA(isA<AskHawMemoryConflict>()),
      );
      expect(repo.confirmed.revision, 4);
      expect(repo.confirmed.preferredTimeOfDay, 'morning');
      final preserved = await repo.preservedChanges();
      expect(preserved.single, gateway.writes.single);
      expect(preserved.single['p_payload'], {
        'preferences': {'preferredTimeOfDay': 'evening'},
      });
      expect(_document(prefs)['pending'], isEmpty);
      expect((_document(prefs)['conflicts'] as List).length, 1);
    },
  );

  test(
    'A to B to A rejects a late acknowledgement and retains A request',
    () async {
      final repo = repository();
      await repo.read();
      final entered = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      gateway.onWrite = (_) {
        entered.complete();
        return response.future;
      };
      final pending = repo.update({
        'hidden': ['flow:private-A'],
      });
      final rejected = expectLater(pending, throwsStateError);
      await entered.future;
      const other = '27d63169-a28a-4550-a0a0-8fee0e8e7b96';
      await client.auth.recoverSession(session().replaceAll(uid, other));
      await Future<void>.delayed(Duration.zero);
      await client.auth.recoverSession(session());
      await Future<void>.delayed(Duration.zero);
      response.complete({
        'status': 'applied',
        'row': _memory(
          revision: 1,
          payload: {
            'hidden': ['flow:private-A'],
          },
        ),
      });
      await rejected;
      expect(repo.confirmed.revision, 0);
      expect(
        (_document(prefs)['pending'] as List).single,
        gateway.writes.single,
      );
      expect((_document(prefs)['confirmed'] as Map)['revision'], 0);
      expect(prefs.getString(AskHawMemoryRepository.storageKey(other)), isNull);
      await expectLater(repo.read(), throwsStateError);
    },
  );

  test(
    'disposed in-flight memory retains its departure fence across A to B to A',
    () async {
      final repo = repository();
      await repo.read();
      final entered = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      gateway.onWrite = (_) {
        entered.complete();
        return response.future;
      };
      final pending = repo.update({
        'hidden': ['flow:private-A'],
      });
      final rejected = expectLater(pending, throwsStateError);
      await entered.future;
      repo.dispose();
      const other = '27d63169-a28a-4550-a0a0-8fee0e8e7b96';
      await client.auth.recoverSession(session().replaceAll(uid, other));
      await Future<void>.delayed(Duration.zero);
      await client.auth.recoverSession(session());
      await Future<void>.delayed(Duration.zero);
      response.complete({
        'status': 'applied',
        'row': _memory(
          revision: 1,
          payload: {
            'hidden': ['flow:private-A'],
          },
        ),
      });
      await rejected;
      expect(repo.confirmed.revision, 0);
      expect(
        (_document(prefs)['pending'] as List).single,
        gateway.writes.single,
      );
      expect((_document(prefs)['confirmed'] as Map)['revision'], 0);
      expect(prefs.getString(AskHawMemoryRepository.storageKey(other)), isNull);
      expect(gateway.writes.length, 1);
      await expectLater(repo.read(), throwsStateError);
    },
  );

  test(
    'disposal refuses new operations but settles an authorized durable acknowledgement',
    () async {
      final repo = repository();
      await repo.read();
      final entered = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      gateway.onWrite = (_) {
        entered.complete();
        return response.future;
      };
      final pending = repo.update({
        'preferences': {'preferredDurationMinutes': 10},
      });
      await entered.future;
      repo.dispose();
      repo.dispose();
      await expectLater(repo.read(), throwsStateError);
      await expectLater(repo.restore(), throwsStateError);
      await expectLater(repo.clear(), throwsStateError);
      await expectLater(repo.update({'hidden': []}), throwsStateError);
      await expectLater(repo.preservedChanges(), throwsStateError);
      expect(gateway.reads.length, 1);
      expect(gateway.writes.length, 1);
      expect(
        (_document(prefs)['pending'] as List).single,
        gateway.writes.single,
      );
      response.complete({
        'status': 'applied',
        'row': _memory(
          revision: 1,
          payload: {
            'preferences': {'preferredDurationMinutes': 10},
          },
        ),
      });
      final acknowledged = await pending;
      expect(acknowledged.revision, 1);
      expect(acknowledged.preferredDurationMinutes, 10);
      expect(repo.confirmed.revision, 1);
      expect((_document(prefs)['confirmed'] as Map)['revision'], 1);
      expect(_document(prefs)['pending'], isEmpty);
      expect(prefs.getKeys(), {AskHawMemoryRepository.storageKey(uid)});
    },
  );

  test(
    'operations queued before disposal can both settle for the account',
    () async {
      final repo = repository();
      await repo.read();
      final entered = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      gateway.onWrite = (request) {
        if (gateway.writes.length == 1) {
          entered.complete();
          return response.future;
        }
        expect(request['p_expected_revision'], 1);
        gateway.row = _memory(
          revision: 2,
          payload: {
            'preferences': {'preferredDurationMinutes': 10},
            'hidden': ['flow:7'],
          },
        );
        return {'status': 'applied', 'row': gateway.row};
      };
      final first = repo.update({
        'preferences': {'preferredDurationMinutes': 10},
      });
      final second = repo.update({
        'hidden': ['flow:7'],
      });
      await entered.future;
      repo.dispose();
      response.complete({
        'status': 'applied',
        'row': _memory(
          revision: 1,
          payload: {
            'preferences': {'preferredDurationMinutes': 10},
          },
        ),
      });
      expect((await first).revision, 1);
      expect((await second).revision, 2);
      expect(repo.confirmed.revision, 2);
      expect(gateway.writes.length, 2);
      expect((_document(prefs)['confirmed'] as Map)['revision'], 2);
      expect(_document(prefs)['pending'], isEmpty);
      await expectLater(repo.read(), throwsStateError);
    },
  );

  test('durability failure prevents sending an account mutation', () async {
    var reads = 0;
    final repo = repository(
      preferences: () async {
        reads++;
        if (reads == 4) throw StateError('Storage unavailable');
        return prefs;
      },
    );
    await repo.read(); // Read document, then preserve confirmed server state.
    await expectLater(
      repo.update({
        'hidden': ['flow:7'],
      }),
      throwsStateError,
    );
    expect(gateway.writes, isEmpty);
    expect((_document(prefs)['confirmed'] as Map)['revision'], 0);
    expect(_document(prefs)['pending'], isEmpty);
  });

  test(
    'old confirmed payload restores without reads and preserves opaque keys',
    () async {
      final raw = {
        'schema': 1,
        'account': uid,
        'confirmed': _memory(
          revision: 2,
          payload: {
            'bindings': {
              'reset': {'intent': 'find', 'query': 'water'},
            },
            'future_resource': {'opaque': true},
          },
        ),
        'pending': [],
        'conflicts': [],
      };
      await prefs.setString(
        AskHawMemoryRepository.storageKey(uid),
        jsonEncode(raw),
      );
      final repo = repository();
      final restored = await repo.restore();
      expect(restored, isA<AskHawMemory>());
      expect(restored.bindingFor('reset')!['query'], 'water');
      expect(restored.payload['future_resource'], {'opaque': true});
      expect(gateway.reads, isEmpty);
      expect(gateway.writes, isEmpty);
      expect(_document(prefs), raw);
    },
  );
}
