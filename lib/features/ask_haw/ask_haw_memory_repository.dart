import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/account_operation_fence.dart';
import 'ask_haw_memory.dart';

class AskHawMemoryConflict implements Exception {
  const AskHawMemoryConflict(this.current);
  final AskHawMemory current;
  @override
  String toString() =>
      'Your preferences changed elsewhere. Your requested change is kept. Review the saved version before trying again.';
}

/// The account owns confirmed memory and durable requests. This store is never
/// registered with warm-cache eviction, startup warming, or logout cleanup.
class AskHawMemoryRepository {
  AskHawMemoryRepository(
    this.client, {
    Future<SharedPreferences> Function()? preferences,
    Future<dynamic> Function(String, Map<String, dynamic>)? invoke,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _invoke = invoke ?? ((name, params) => client.rpc(name, params: params)),
       _account = AccountOperationFence(client);
  final SupabaseClient client;
  final Future<SharedPreferences> Function() _preferences;
  final Future<dynamic> Function(String, Map<String, dynamic>) _invoke;
  final AccountOperationFence _account;
  static final _queues = <String, Future<void>>{};
  AskHawMemory _confirmed = AskHawMemory();
  bool _hasRead = false;
  bool _disposeRequested = false;
  bool _fenceDisposed = false;
  int _operations = 0;
  AskHawMemory get confirmed => _confirmed;
  String get _uid => _account.userId ?? '';
  static String storageKey(String account) => 'ask_haw_account:v1:$account';
  void _check() {
    if (_uid.isEmpty || !_account.isCurrent) {
      throw StateError('Account changed. Reopen Ask ḥꜣw to continue.');
    }
  }

  Future<T> _locked<T>(Future<T> Function() action) {
    if (_disposeRequested) {
      return Future<T>.error(StateError('Ask ḥꜣw memory is closed.'));
    }
    // Accepted operations, including those waiting in the account queue, retain
    // the departure fence until their durable acknowledgement has settled.
    _operations++;
    final task = (_queues[_uid] ?? Future<void>.value())
        .then((_) {
          _check();
          return action();
        })
        .whenComplete(() {
          _operations--;
          _disposeFenceIfIdle();
        });
    final tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _queues[_uid] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_queues[_uid], tail)) _queues.remove(_uid);
      }),
    );
    return task;
  }

  Future<Map<String, dynamic>> _document() async {
    _check();
    final prefs = await _preferences();
    _check();
    final raw = prefs.getString(storageKey(_uid));
    if (raw == null) {
      return {
        'schema': 1,
        'account': _uid,
        'confirmed': _confirmed.toJson(),
        'pending': [],
        'conflicts': [],
      };
    }
    final doc = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (doc['schema'] != 1 || doc['account'] != _uid) {
      throw StateError('Saved Ask ḥꜣw requests need a compatible app version.');
    }
    return doc;
  }

  Future<void> _persist(Map<String, dynamic> doc) async {
    _check();
    final prefs = await _preferences();
    _check();
    if (!await prefs.setString(storageKey(_uid), jsonEncode(doc))) {
      await prefs.reload();
      throw StateError(
        'Could not preserve this change. Keep this open and try again.',
      );
    }
    _check();
  }

  Future<AskHawMemory> restore() => _locked(() async {
    final doc = await _document();
    _confirmed = AskHawMemory.fromJson(
      Map<String, dynamic>.from(doc['confirmed'] as Map),
    );
    _hasRead = true;
    return _confirmed;
  });
  Future<AskHawMemory> _fetch(Map<String, dynamic> doc) async {
    final raw = Map<String, dynamic>.from(
      await _invoke('read_ask_haw_memory_v1', {
            'p_account': _uid,
          }).timeout(const Duration(seconds: 30))
          as Map,
    );
    _check();
    if (raw['status'] != 'ready' || raw['row'] is! Map) {
      throw StateError('Ask ḥꜣw memory is unavailable.');
    }
    final current = AskHawMemory.fromJson(
      Map<String, dynamic>.from(raw['row'] as Map),
    );
    doc['confirmed'] = current.toJson();
    await _persist(doc);
    _confirmed = current;
    _hasRead = true;
    return current;
  }

  Future<AskHawMemory> read() => _locked(() async {
    final doc = await _document();
    await _drain(doc);
    return _fetch(doc);
  });
  Future<AskHawMemory> update(Map<String, dynamic> patch) => _locked(() async {
    final doc = await _document();
    await _drain(doc);
    final current = _hasRead ? _confirmed : await _fetch(doc);
    return _enqueue(doc, current, 'patch', patch);
  });
  Future<AskHawMemory> clear() => _locked(() async {
    final doc = await _document();
    // Clearing reads the server directly; it never applies queued old learning.
    final current = await _fetch(doc);
    return _enqueue(doc, current, 'clear', {});
  });
  Future<AskHawMemory> _enqueue(
    Map<String, dynamic> doc,
    AskHawMemory current,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final request = {
      'p_account': _uid,
      'p_mutation': const Uuid().v4(),
      'p_expected_revision': current.revision,
      'p_expected_epoch': current.epoch,
      'p_operation': operation,
      'p_payload': payload,
    };
    final pending = List<dynamic>.from(doc['pending'] as List);
    if (operation == 'clear') {
      // Preserve pending intents until the clear acknowledgement fences them.
      pending.insert(0, request);
    } else {
      pending.add(request);
    }
    doc['pending'] = pending;
    await _persist(doc);
    await _drain(doc);
    return _confirmed;
  }

  Future<void> _drain(Map<String, dynamic> doc) async {
    final pending = List<dynamic>.from(doc['pending'] as List);
    while (pending.isNotEmpty) {
      _check();
      final request = Map<String, dynamic>.from(pending.first as Map);
      final raw = Map<String, dynamic>.from(
        await _invoke(
              'apply_ask_haw_memory_v1',
              request,
            ).timeout(const Duration(seconds: 30))
            as Map,
      );
      _check();
      final current = AskHawMemory.fromJson(
        Map<String, dynamic>.from(raw['row'] as Map),
      );
      final status = raw['status'];
      if (status != 'applied' &&
          status != 'superseded' &&
          status != 'conflict') {
        throw StateError(
          'This preference was not acknowledged. It is kept for retry.',
        );
      }
      pending.removeAt(0);
      doc['confirmed'] = current.toJson();
      if (status == 'conflict') {
        (doc['conflicts'] as List).add(request);
      }
      if (status == 'applied' && request['p_operation'] == 'clear') {
        pending.removeWhere(
          (value) => (value as Map)['p_expected_epoch'] != current.epoch,
        );
        doc['conflicts'] = [];
      }
      doc['pending'] = pending;
      await _persist(doc);
      _confirmed = current;
      if (status == 'conflict') throw AskHawMemoryConflict(current);
    }
  }

  Future<List<Map<String, dynamic>>> preservedChanges() => _locked(() async {
    final doc = await _document();
    return [
      for (final value in [
        ...doc['pending'] as List,
        ...doc['conflicts'] as List,
      ])
        Map<String, dynamic>.from(value as Map),
    ];
  });
  void _disposeFenceIfIdle() {
    if (_disposeRequested && _operations == 0 && !_fenceDisposed) {
      _fenceDisposed = true;
      _account.dispose();
    }
  }

  void dispose() {
    _disposeRequested = true;
    _disposeFenceIfIdle();
  }
}
