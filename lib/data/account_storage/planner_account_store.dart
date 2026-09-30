import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../warm_state/warm_mutation.dart';

/// Durable writes are deliberately separate from the evictable warm cache.
/// The disk format and mutation IDs survive releases, logout and lost replies.
class PlannerAccountStore extends ChangeNotifier with WidgetsBindingObserver {
  PlannerAccountStore(
    this.client, {
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;
  static final _instances = Expando<PlannerAccountStore>();
  static PlannerAccountStore of(SupabaseClient client) {
    final existing = _instances[client];
    if (existing != null && !existing._disposed) return existing;
    return _instances[client] = PlannerAccountStore(client);
  }

  final SupabaseClient client;
  final Future<SharedPreferences> Function() _preferences;
  static const kinds = ['notes', 'nutrition'];
  static const _tables = {
    'notes': 'alignment_notes',
    'nutrition': 'nutrition_items',
  };
  static const fields = {
    'notes': ['body', 'position'],
    'nutrition': [
      'nutrient',
      'source',
      'purpose',
      'mode',
      'days_of_week',
      'decan_days',
      'repeat',
      'time_h',
      'time_m',
      'alert_offset_minutes',
      'enabled',
    ],
  };
  final _documents = <String, Map<String, dynamic>>{};
  final _versions = <String, int>{};
  final _errors = <String, String>{};
  final _flights = <String, Future<void>>{};
  Future<void> _writes = Future.value();
  StreamSubscription<AuthState>? _auth;
  Timer? _timer;
  bool _started = false, _foreground = true, _disposed = false;
  Future<void>? _resumeFlight;
  String? get userId => client.auth.currentUser?.id;
  static String storageKey(String uid) => 'planner_account:v1:$uid';
  bool _current(String uid) => !_disposed && userId == uid;
  List<Map<String, dynamic>> _list(dynamic raw) => (raw as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  Future<T> _locked<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, dynamic>> _document(String uid) async {
    if (_documents[uid] case final existing?) return existing;
    final prefs = await _preferences();
    final raw = prefs.getString(storageKey(uid));
    final doc = raw == null
        ? <String, dynamic>{
            'schema': 1,
            'userId': uid,
            'rows': <String, dynamic>{},
            'legacyIds': <String, dynamic>{},
            'pending': [],
            'conflicts': [],
            'migrated': [],
          }
        : jsonDecode(raw) as Map<String, dynamic>;
    if (doc['schema'] != 1 || doc['userId'] != uid) {
      // Never replace an unknown durable-write format with an empty document.
      throw StateError(
        'Planner recovery data requires a compatible app version.',
      );
    }
    if (raw == null) {
      for (final kind in kinds) {
        final key = kind == 'notes'
            ? 'today_alignment_notes_$uid'
            : 'today_alignment_nutrition_items_$uid';
        final stored = prefs.getStringList(key) ?? [];
        final seeds = <Map<String, dynamic>>[];
        for (var i = 0; i < stored.length; i++) {
          Map<String, dynamic> value;
          try {
            value = Map<String, dynamic>.from(jsonDecode(stored[i]) as Map);
          } catch (_) {
            if (kind != 'notes') continue;
            value = {'id': 'local_$i', 'text': stored[i], 'position': i};
          }
          final oldId = value['id'] as String? ?? 'local_$i';
          final id = oldId.startsWith('local_') || oldId.isEmpty
              ? const Uuid().v5(
                  Namespace.url.value,
                  'planner:$uid:$kind:$oldId',
                )
              : oldId;
          (doc['legacyIds'] as Map)[oldId] = id;
          seeds.add({
            ...value,
            'id': id,
            if (kind == 'notes') 'body': value['text'] ?? '',
            'created_at': value['createdAt'] ?? '1970-01-01T00:00:00Z',
          });
        }
        (doc['rows'] as Map)[kind] = seeds;
      }
    }
    _documents[uid] = doc;
    return doc;
  }

  Future<void> _commit(String uid, Map<String, dynamic> next) async {
    final prefs = await _preferences();
    if (!await prefs.setString(storageKey(uid), jsonEncode(next))) {
      throw StateError(
        'Could not preserve this edit. Please keep it open and retry.',
      );
    }
    _documents[uid] = next;
    _versions[uid] = (_versions[uid] ?? 0) + 1;
    if (_current(uid)) notifyListeners();
  }

  Future<void> restore() async {
    final uid = userId;
    if (uid == null) return;
    await _locked(() async {
      await _document(uid);
    });
    if (_current(uid)) notifyListeners();
  }

  List<Map<String, dynamic>> rows(String kind) {
    final doc = _documents[userId];
    if (doc == null) return [];
    final result = <String, Map<String, dynamic>>{
      for (final r in _list((doc['rows'] as Map)[kind])) r['id'] as String: r,
    };
    for (final op in _list(doc['pending']).where((o) => o['kind'] == kind)) {
      final id = op['record_id'] as String;
      if (op['delete'] == true) {
        result.remove(id);
        continue;
      }
      result[id] = {
        ...?result[id],
        'id': id,
        'created_at': op['created_at'],
        ...Map<String, dynamic>.from(op['change'] as Map),
      };
    }
    return result.values.toList();
  }

  List<Map<String, dynamic>> conflicts([String? kind]) => _list(
    _documents[userId]?['conflicts'],
  ).where((r) => kind == null || r['kind'] == kind).toList();
  Map<String, String> get legacyIds =>
      Map<String, String>.from(_documents[userId]?['legacyIds'] as Map? ?? {});

  bool pending(String kind) =>
      _list(_documents[userId]?['pending']).any((r) => r['kind'] == kind);
  String? message(String kind) {
    if (conflicts(kind).isNotEmpty) {
      return 'Another device changed this item. Both versions are preserved in your account.';
    }
    if (pending(kind)) {
      return 'Changes pending account sync. They will retry automatically.';
    }
    return _errors['$userId:$kind'];
  }

  /// Persist intent before returning an optimistic row or attempting the network.
  Future<String> save(
    String kind,
    Map<String, dynamic> change, {
    String? id,
    bool delete = false,
    String? resolves,
    int? expectedRevision,
    bool useExpectedRevision = false,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('Sign in to save to your account.');
    if (!kinds.contains(kind) ||
        change.keys.any((k) => !fields[kind]!.contains(k))) {
      throw ArgumentError('Unknown Planner storage contract');
    }
    final recordId = id ?? const Uuid().v4();
    await _locked(() async {
      final doc = _clone(await _document(uid));
      if (!_current(uid)) throw StateError('Account changed before saving.');
      if (conflicts(kind).any(
        (r) => r['record_id'] == recordId && r['mutation_id'] != resolves,
      )) {
        throw StateError('Review the saved versions before editing this item.');
      }
      final existing = _list(
        (doc['rows'] as Map)[kind],
      ).where((r) => r['id'] == recordId);
      final op = <String, dynamic>{
        'mutation_id': const Uuid().v4(),
        'kind': kind,
        'record_id': recordId,
        'change': change,
        'expected_revision': useExpectedRevision
            ? expectedRevision
            : existing.firstOrNull?['planner_revision'],
        'delete': delete,
        'resolves': resolves,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      doc['pending'] = [..._list(doc['pending']), op];
      await _commit(uid, doc);
    });
    unawaited(flush());
    return recordId;
  }

  Future<void> flush() {
    final uid = userId;
    if (uid == null || !_foreground || _disposed) return Future.value();
    return _flights[uid] ??= _drain(uid).whenComplete(() {
      _flights.remove(uid);
    });
  }

  Future<void> _drain(String uid) async {
    try {
      while (_current(uid) && _foreground) {
        final op = await _locked(
          () async => _list((await _document(uid))['pending']).firstOrNull,
        );
        if (op == null || !_current(uid)) return;
        final raw = await client
            .rpc(
              'apply_planner_mutation_v1',
              params: {
                'p_account_id': uid,
                'p_mutation_id': op['mutation_id'],
                'p_kind': op['kind'],
                'p_record_id': op['record_id'],
                'p_change': op['change'],
                'p_expected_revision': op['expected_revision'],
                'p_delete': op['delete'],
                'p_resolves': op['resolves'],
              },
            )
            .timeout(const Duration(seconds: 20));
        if (!_current(uid)) {
          return; // A departed account's durable intent stays intact.
        }
        final response = Map<String, dynamic>.from(raw as Map);
        if (response['mutation_id'] != op['mutation_id'] ||
            !['applied', 'conflict'].contains(response['status']) ||
            (response['status'] == 'applied' &&
                op['delete'] != true &&
                (response['row'] is! Map ||
                    (response['row'] as Map)['id'] != op['record_id'] ||
                    (response['row'] as Map)['user_id'] != uid))) {
          throw StateError('Unrecognized Planner save response');
        }
        await _locked(() async {
          final doc = _clone(await _document(uid));
          final pending = _list(doc['pending']);
          pending.removeWhere((o) => o['mutation_id'] == op['mutation_id']);
          if (response['status'] == 'applied') {
            final records = _list((doc['rows'] as Map)[op['kind']]);
            records.removeWhere((r) => r['id'] == op['record_id']);
            if (response['row'] != null) {
              records.add(Map<String, dynamic>.from(response['row'] as Map));
            }
            (doc['rows'] as Map)[op['kind']] = records;
            for (final later in pending.where(
              (o) =>
                  o['kind'] == op['kind'] && o['record_id'] == op['record_id'],
            )) {
              later['expected_revision'] =
                  (response['row'] as Map?)?['planner_revision'];
            }
            doc['conflicts'] = _list(doc['conflicts'])
              ..removeWhere((r) => r['mutation_id'] == op['resolves']);
          } else {
            final records = _list((doc['rows'] as Map)[op['kind']])
              ..removeWhere((r) => r['id'] == op['record_id']);
            if (response['row'] != null) {
              records.add(Map<String, dynamic>.from(response['row'] as Map));
            }
            (doc['rows'] as Map)[op['kind']] = records;
            doc['conflicts'] = [
              ..._list(doc['conflicts']),
              {
                'mutation_id': op['mutation_id'],
                'kind': op['kind'],
                'record_id': op['record_id'],
                'request': op,
                'result': response,
              },
            ];
          }
          doc['pending'] = pending;
          await _commit(uid, doc);
        });
        invalidateWarmDomains(uid, [
          'rhythm.',
          'pages.planner.',
          'planner.',
          'pages.journal.',
        ]);
      }
    } catch (_) {
      // The durable intent remains queued, with its original idempotency key.
      if (_current(uid)) notifyListeners();
    }
  }

  Future<void> refresh(String kind) async {
    final uid = userId;
    if (uid == null) return;
    await restore();
    await flush();
    try {
      final readVersion = _versions[uid] ?? 0;
      final fetched = await client
          .from(_tables[kind]!)
          .select()
          .eq('user_id', uid)
          .order('created_at')
          .timeout(const Duration(seconds: 20));
      if (!_current(uid)) return;
      await _locked(() async {
        final doc = _clone(await _document(uid));
        if ((_versions[uid] ?? 0) != readVersion) return;
        (doc['rows'] as Map)[kind] = fetched;
        await _migrateLegacy(uid, kind, doc);
        _errors.remove('$uid:$kind');
        await _commit(uid, doc);
      });
      final conflictVersion = _versions[uid] ?? 0;
      final recovered = await client
          .from('planner_mutation_receipts')
          .select('mutation_id,kind,record_id,request,result,created_at')
          .eq('user_id', uid)
          .isFilter('resolved_at', null)
          .eq('result->>status', 'conflict')
          .order('created_at')
          .timeout(const Duration(seconds: 20));
      if (!_current(uid)) return;
      await _locked(() async {
        final doc = _clone(await _document(uid));
        if ((_versions[uid] ?? 0) != conflictVersion) return;
        doc['conflicts'] = recovered;
        await _commit(uid, doc);
      });
      await flush();
    } catch (_) {
      if (_current(uid)) {
        _errors['$uid:$kind'] =
            'Account sync unavailable. Your saved copy is preserved; retrying.';
        notifyListeners();
      }
    }
  }

  /// Legacy backups are retained. Differences are uploaded with no base revision,
  /// so an existing account row becomes a recoverable conflict, never overwritten.
  Future<void> _migrateLegacy(
    String uid,
    String kind,
    Map<String, dynamic> doc,
  ) async {
    final migrated = List<String>.from(doc['migrated'] as List);
    if (migrated.contains(kind)) return;
    final prefs = await _preferences();
    final key = kind == 'notes'
        ? 'today_alignment_notes_$uid'
        : 'today_alignment_nutrition_items_$uid';
    final legacy = prefs.getStringList(key) ?? [];
    final records = _list((doc['rows'] as Map)[kind]);
    final pending = _list(doc['pending']);
    for (var index = 0; index < legacy.length; index++) {
      Map<String, dynamic> value;
      try {
        value = Map<String, dynamic>.from(jsonDecode(legacy[index]) as Map);
      } catch (_) {
        if (kind != 'notes') {
          throw StateError(
            'Unrecognized legacy nutrition record; original retained.',
          );
        }
        value = {
          'id': 'local_$index',
          'text': legacy[index],
          'position': index,
        };
      }
      final oldId = value['id'] as String? ?? 'local_$index';
      final local = oldId.startsWith('local_') || oldId.isEmpty;
      final id = local
          ? const Uuid().v5(Namespace.url.value, 'planner:$uid:$kind:$oldId')
          : oldId;
      final change = kind == 'notes'
          ? <String, dynamic>{
              'body': value['text'] ?? '',
              'position': value['position'] ?? index,
            }
          : <String, dynamic>{
              for (final field in fields[kind]!)
                if (value.containsKey(field)) field: value[field],
            };
      final remote = records.where((r) => r['id'] == id).firstOrNull;
      if (remote != null &&
          change.entries.every(
            (e) => jsonEncode(remote[e.key]) == jsonEncode(e.value),
          )) {
        continue;
      }
      if (pending.any((p) => p['kind'] == kind && p['record_id'] == id)) {
        continue;
      }
      // A missing formerly-account row may represent a deletion from another
      // device. Force recovery review instead of resurrecting it automatically.
      pending.add({
        'mutation_id': const Uuid().v5(
          Namespace.url.value,
          'planner-migration:$uid:$kind:$oldId',
        ),
        'kind': kind,
        'record_id': id,
        'change': change,
        'expected_revision': local ? null : -1,
        'delete': false,
        'resolves': null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    doc['pending'] = pending;
    doc['migrated'] = [...migrated, kind];
  }

  Future<void> resolve(
    Map<String, dynamic> conflict, {
    required bool keepMine,
  }) async {
    final uid = userId;
    if (uid == null) return;
    final kind = conflict['kind'] as String;
    if (keepMine) {
      if (!_current(uid)) return;
      final request = Map<String, dynamic>.from(conflict['request'] as Map);
      await save(
        kind,
        Map<String, dynamic>.from(request['change'] as Map),
        id: conflict['record_id'] as String,
        delete: request['delete'] == true,
        resolves: conflict['mutation_id'] as String,
        useExpectedRevision: true,
        expectedRevision:
            ((conflict['result'] as Map)['row'] as Map?)?['planner_revision']
                as int?,
      );
      await flush();
    } else {
      await client
          .from('planner_mutation_receipts')
          .update({'resolved_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .eq('mutation_id', conflict['mutation_id'] as String)
          .select('mutation_id')
          .single();
      if (!_current(uid)) return;
      await _locked(() async {
        final doc = _clone(await _document(uid));
        doc['conflicts'] = _list(doc['conflicts'])
          ..removeWhere((r) => r['mutation_id'] == conflict['mutation_id']);
        await _commit(uid, doc);
      });
    }
  }

  /// Preserve the old device backup in the account without replaying stale
  /// checkmarks over newer changes from another device.
  Future<void> preserveLegacyCheckmarks() async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await _preferences();
    final key = 'today_alignment_nutrition_checks_$uid';
    final values = prefs.getStringList(key);
    if (values == null ||
        values.isEmpty ||
        prefs.getBool('$key:archived') == true) {
      return;
    }
    final backupId = const Uuid().v5(
      Namespace.url.value,
      '$uid:$key:${jsonEncode(values)}',
    );
    await client
        .from('planner_legacy_recovery')
        .upsert(
          {
            'user_id': uid,
            'backup_id': backupId,
            'kind': 'nutrition_checkmarks',
            'payload': {'values': values, 'item_ids': legacyIds},
          },
          onConflict: 'user_id,backup_id',
          ignoreDuplicates: true,
        )
        .timeout(const Duration(seconds: 20));
    if (_current(uid)) await prefs.setBool('$key:archived', true);
  }

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _auth = client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
      unawaited(_resume());
    });
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_resume()),
    );
    unawaited(_resume());
  }

  Future<void> _resume() => _resumeFlight ??= _resumeAccount().whenComplete(() {
    _resumeFlight = null;
  });

  Future<void> _resumeAccount() async {
    if (!_foreground || _disposed || userId == null) return;
    final uid = userId;
    try {
      await restore();
      for (final kind in kinds) {
        if (userId != uid || !_foreground) return;
        await refresh(kind);
      }
      await preserveLegacyCheckmarks();
    } catch (_) {
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_resume());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _auth?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
