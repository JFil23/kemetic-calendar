import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/boot_diagnostics.dart';

class HiveLocalStorageWeb extends LocalStorage {
  HiveLocalStorageWeb({
    HiveInterface? hive,
    Future<void> Function()? initializeHive,
  }) : _hive = hive ?? Hive,
       _initializeHive = initializeHive ?? Hive.initFlutter;

  final HiveInterface _hive;
  final Future<void> Function() _initializeHive;

  Future<T> _observe<T>(
    BootStorageOperation operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stack) {
      Error.throwWithStackTrace(BootStorageFailure(operation, error), stack);
    }
  }

  static const _boxName = 'sb_session';
  static const _key = supabasePersistSessionKey;

  bool _ready = false;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    await _observe(BootStorageOperation.initializeHive, _initializeHive);
    await _observe(
      BootStorageOperation.openSessionBox,
      () => _hive.openBox<String>(_boxName),
    );
    _ready = true;
  }

  @override
  Future<String?> accessToken() async {
    return _observe(BootStorageOperation.readSession, () async {
      final box = _hive.box<String>(_boxName);
      return box.get(_key);
    });
  }

  @override
  Future<bool> hasAccessToken() async {
    return _observe(BootStorageOperation.checkSession, () async {
      final box = _hive.box<String>(_boxName);
      return box.containsKey(_key);
    });
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    final box = _hive.box<String>(_boxName);
    await box.put(_key, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    final box = _hive.box<String>(_boxName);
    await box.delete(_key);
  }
}
