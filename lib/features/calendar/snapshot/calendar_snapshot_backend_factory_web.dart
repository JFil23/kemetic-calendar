import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'calendar_snapshot_backend.dart';
import 'calendar_snapshot_context.dart';

CalendarSnapshotBackend createPlatformCalendarSnapshotBackend() =>
    IndexedDbCalendarSnapshotBackend();

/// Web storage that reads IndexedDB on every operation.
///
/// Hive's web box keeps an in-memory view of IndexedDB. That is useful for a
/// single tab, but a BroadcastChannel notification does not refresh the box's
/// cached head in another tab. Direct requests keep the compare-and-swap read
/// inside the Web Lock honest across tabs and service-worker-era clients.
final class IndexedDbCalendarSnapshotBackend
    implements CalendarSnapshotBackend {
  IndexedDbCalendarSnapshotBackend({
    String databaseName = 'kemet_calendar_snapshot_v1',
    String objectStoreName = 'objects',
    CalendarSnapshotContextCoordinator? contextCoordinator,
  }) : _databaseName = databaseName,
       _objectStoreName = objectStoreName,
       _contextCoordinator =
           contextCoordinator ?? createCalendarSnapshotContextCoordinator();

  final String _databaseName;
  final String _objectStoreName;
  final CalendarSnapshotContextCoordinator _contextCoordinator;
  Future<web.IDBDatabase>? _databaseFlight;

  @override
  Future<void> initialize() async {
    await (_databaseFlight ??= _openDatabase());
  }

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_objectStoreName)) {
        database.createObjectStore(_objectStoreName);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Unable to open calendar snapshot IndexedDB: '
            '${request.error?.name ?? 'unknown'}',
          ),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Calendar snapshot IndexedDB upgrade was blocked'),
        );
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      database.onversionchange = ((web.Event _) => database.close()).toJS;
      if (!completer.isCompleted) completer.complete(database);
    }).toJS;
    return completer.future;
  }

  Future<web.IDBDatabase> get _database async {
    await initialize();
    return _databaseFlight!;
  }

  @override
  Future<String?> read(String key) async {
    final database = await _database;
    final transaction = database.transaction(_objectStoreName.toJS, 'readonly');
    final request = transaction.objectStore(_objectStoreName).get(key.toJS);
    final result = await _requestResult(request);
    await _transactionComplete(transaction);
    final value = result?.dartify();
    return value is String ? value : null;
  }

  @override
  Future<void> write(String key, String value) async {
    final database = await _database;
    final transaction = database.transaction(
      _objectStoreName.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    transaction.objectStore(_objectStoreName).put(value.toJS, key.toJS);
    await _transactionComplete(transaction);
    _contextCoordinator.publish(key);
  }

  @override
  Future<void> delete(String key) async {
    final database = await _database;
    final transaction = database.transaction(
      _objectStoreName.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    transaction.objectStore(_objectStoreName).delete(key.toJS);
    await _transactionComplete(transaction);
    _contextCoordinator.publish(key);
  }

  @override
  Future<Set<String>> keys({String? prefix}) async {
    final database = await _database;
    final transaction = database.transaction(_objectStoreName.toJS, 'readonly');
    final request = transaction.objectStore(_objectStoreName).getAllKeys();
    final result = await _requestResult(request);
    await _transactionComplete(transaction);
    final values = result?.dartify();
    if (values is! List) return <String>{};
    return values
        .whereType<String>()
        .where((key) => prefix == null || key.startsWith(prefix))
        .toSet();
  }

  @override
  Future<T> withExclusiveLock<T>(String name, Future<T> Function() action) =>
      _contextCoordinator.withExclusiveLock(name, action);

  @override
  Stream<String> get externalChanges => _contextCoordinator.changes;

  Future<JSAny?> _requestResult(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Calendar snapshot IndexedDB request failed: '
            '${request.error?.name ?? 'unknown'}',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<void> _transactionComplete(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    void fail(web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Calendar snapshot IndexedDB transaction failed: '
            '${transaction.error?.name ?? 'unknown'}',
          ),
        );
      }
    }

    transaction.onerror = fail.toJS;
    transaction.onabort = fail.toJS;
    return completer.future;
  }
}
