import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import 'calendar_snapshot_backend.dart';
import 'calendar_snapshot_context.dart';

/// Hive-backed object storage for native platforms.
///
/// Native callers share an in-process mutex. Web uses the direct IndexedDB
/// backend so compare-and-swap reads cannot be hidden behind Hive's per-tab
/// memory cache.
final class HiveCalendarSnapshotBackend implements CalendarSnapshotBackend {
  HiveCalendarSnapshotBackend({
    String boxName = 'calendar_snapshot_store_v1',
    CalendarSnapshotContextCoordinator? contextCoordinator,
  }) : _boxName = boxName,
       _contextCoordinator =
           contextCoordinator ?? createCalendarSnapshotContextCoordinator();

  static final Map<String, Future<Box<String>>> _boxFlights = {};

  final String _boxName;
  final CalendarSnapshotContextCoordinator _contextCoordinator;
  Box<String>? _box;

  @override
  Future<void> initialize() async {
    if (_box?.isOpen ?? false) return;
    final existing = _boxFlights[_boxName];
    if (existing != null) {
      _box = await existing;
      return;
    }
    final flight = _open();
    _boxFlights[_boxName] = flight;
    try {
      _box = await flight;
    } finally {
      _boxFlights.remove(_boxName);
    }
  }

  Future<Box<String>> _open() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Another app subsystem may have initialized Hive first. Opening the
      // named box below is the authoritative readiness check.
    }
    return Hive.openBox<String>(_boxName);
  }

  Box<String> get _readyBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Calendar snapshot backend is not initialized');
    }
    return box;
  }

  @override
  Future<String?> read(String key) async => _readyBox.get(key);

  @override
  Future<void> write(String key, String value) async {
    await _readyBox.put(key, value);
    _contextCoordinator.publish(key);
  }

  @override
  Future<void> delete(String key) async {
    await _readyBox.delete(key);
    _contextCoordinator.publish(key);
  }

  @override
  Future<Set<String>> keys({String? prefix}) async => _readyBox.keys
      .whereType<String>()
      .where((key) => prefix == null || key.startsWith(prefix))
      .toSet();

  @override
  Future<T> withExclusiveLock<T>(String name, Future<T> Function() action) =>
      _contextCoordinator.withExclusiveLock(name, action);

  @override
  Stream<String> get externalChanges => _contextCoordinator.changes;
}
