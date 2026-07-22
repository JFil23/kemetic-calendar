import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const bool supportsAcknowledgedDurableSnapshotStore = true;

const String _databaseName = 'kemetic.restoration.authority.v1';
const String _storeName = 'snapshots';
const String _lastActiveUserKey = 'last_user';
const Duration _operationTimeout = Duration(seconds: 5);

String _windowKey(String userId, String windowId) =>
    'window:${userId.trim()}:${windowId.trim()}';

String _latestKey(String userId) => 'latest:${userId.trim()}';

Future<web.IDBDatabase> _openDatabase() {
  final completer = Completer<web.IDBDatabase>();
  late web.IDBOpenDBRequest request;
  try {
    request = web.window.indexedDB.open(_databaseName, 1);
  } catch (error, stackTrace) {
    return Future<web.IDBDatabase>.error(error, stackTrace);
  }
  request.onupgradeneeded = ((web.Event event) {
    final database = request.result as web.IDBDatabase;
    if (!database.objectStoreNames.contains(_storeName)) {
      database.createObjectStore(_storeName);
    }
  }).toJS;
  request.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('IndexedDB open failed: ${request.error?.message}'),
      );
    }
  }).toJS;
  request.onblocked = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('IndexedDB open blocked'));
    }
  }).toJS;
  request.onsuccess = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.complete(request.result as web.IDBDatabase);
    }
  }).toJS;
  return completer.future.timeout(_operationTimeout);
}

Future<String?> _read(String key) async {
  final database = await _openDatabase();
  try {
    final transaction = database.transaction(_storeName.toJS, 'readonly');
    final request = transaction.objectStore(_storeName).get(key.toJS);
    final completer = Completer<String?>();
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB read failed: ${request.error?.message}'),
        );
      }
    }).toJS;
    request.onsuccess = ((web.Event event) {
      if (completer.isCompleted) return;
      final result = request.result;
      completer.complete(result == null ? null : (result as JSString).toDart);
    }).toJS;
    return await completer.future.timeout(_operationTimeout);
  } finally {
    database.close();
  }
}

Future<String?> readWindowEnvelope(String userId, String windowId) =>
    _read(_windowKey(userId, windowId));

Future<String?> readLatestEnvelope(String userId) => _read(_latestKey(userId));

Future<String?> readLastActiveUserId() => _read(_lastActiveUserKey);

String _integrityForExistingEnvelope(Map<dynamic, dynamic> raw) {
  final payload = jsonEncode(<String, Object>{
    'authoritySchemaVersion': raw['authoritySchemaVersion'] as int,
    'snapshotSchemaVersion': raw['snapshotSchemaVersion'] as int,
    'userId': raw['userId'] as String,
    'windowId': raw['windowId'] as String,
    'generation': raw['generation'] as int,
    'snapshotJson': raw['snapshotJson'] as String,
  });
  var hash = 0x811c9dc5;
  for (final codeUnit in payload.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'fnv1a32:${hash.toRadixString(16).padLeft(8, '0')}';
}

int? _generationOf(String? encoded, {required String expectedUserId}) {
  if (encoded == null || encoded.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    final authoritySchemaVersion = decoded['authoritySchemaVersion'];
    final snapshotSchemaVersion = decoded['snapshotSchemaVersion'];
    final userId = decoded['userId'];
    final windowId = decoded['windowId'];
    final generation = decoded['generation'];
    final snapshotJson = decoded['snapshotJson'];
    final integrity = decoded['integrity'];
    if (authoritySchemaVersion is! int ||
        authoritySchemaVersion != 1 ||
        snapshotSchemaVersion is! int ||
        snapshotSchemaVersion < 1 ||
        userId is! String ||
        userId != expectedUserId ||
        windowId is! String ||
        windowId.trim().isEmpty ||
        generation is! int ||
        generation < 0 ||
        snapshotJson is! String ||
        snapshotJson.trim().isEmpty ||
        integrity is! String ||
        integrity != _integrityForExistingEnvelope(decoded)) {
      return null;
    }
    return generation;
  } catch (_) {
    return null;
  }
}

Future<String> writeEnvelope({
  required String userId,
  required String windowId,
  required int generation,
  required String encodedEnvelope,
}) async {
  final database = await _openDatabase();
  try {
    final transaction = database.transaction(
      _storeName.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final store = transaction.objectStore(_storeName);
    final latestRequest = store.get(_latestKey(userId).toJS);
    final completer = Completer<String>();
    var superseded = false;

    latestRequest.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'IndexedDB authority read failed: ${latestRequest.error?.message}',
          ),
        );
      }
      try {
        transaction.abort();
      } catch (_) {}
    }).toJS;
    latestRequest.onsuccess = ((web.Event event) {
      final result = latestRequest.result;
      final existing = result == null ? null : (result as JSString).toDart;
      final existingGeneration = _generationOf(
        existing,
        expectedUserId: userId,
      );
      if (existingGeneration != null && existingGeneration >= generation) {
        superseded = true;
        return;
      }
      store.put(encodedEnvelope.toJS, _windowKey(userId, windowId).toJS);
      store.put(encodedEnvelope.toJS, _latestKey(userId).toJS);
      store.put(userId.toJS, _lastActiveUserKey.toJS);
    }).toJS;
    transaction.onabort = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'IndexedDB transaction aborted: ${transaction.error?.message}',
          ),
        );
      }
    }).toJS;
    transaction.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'IndexedDB transaction failed: ${transaction.error?.message}',
          ),
        );
      }
    }).toJS;
    transaction.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete(superseded ? 'superseded' : 'committed');
      }
    }).toJS;
    return await completer.future.timeout(_operationTimeout);
  } finally {
    database.close();
  }
}

Future<void> _deleteKeys(List<String> keys) async {
  final database = await _openDatabase();
  try {
    final transaction = database.transaction(
      _storeName.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final store = transaction.objectStore(_storeName);
    for (final key in keys) {
      store.delete(key.toJS);
    }
    final completer = Completer<void>();
    transaction.onabort = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB delete aborted: ${transaction.error?.message}'),
        );
      }
    }).toJS;
    transaction.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB delete failed: ${transaction.error?.message}'),
        );
      }
    }).toJS;
    transaction.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    await completer.future.timeout(_operationTimeout);
  } finally {
    database.close();
  }
}

Future<void> clearWindow(String userId, String windowId) =>
    _deleteKeys(<String>[_windowKey(userId, windowId)]);

Future<void> clearLastActiveUser() =>
    _deleteKeys(const <String>[_lastActiveUserKey]);
