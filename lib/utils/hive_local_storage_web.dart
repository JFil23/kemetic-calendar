import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HiveLocalStorageWeb extends LocalStorage {
  static const _boxName = 'sb_session';
  static const _key = supabasePersistSessionKey;

  bool _ready = false;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Hive.openBox<String>(_boxName);
    _ready = true;
  }

  @override
  Future<String?> accessToken() async {
    final box = Hive.box<String>(_boxName);
    return box.get(_key);
  }

  @override
  Future<bool> hasAccessToken() async {
    final box = Hive.box<String>(_boxName);
    return box.containsKey(_key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    final box = Hive.box<String>(_boxName);
    await box.put(_key, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    final box = Hive.box<String>(_boxName);
    await box.delete(_key);
  }
}
