import 'dart:async';

/// Minimal durable key/value capability required by [CalendarSnapshotStore].
///
/// The store deliberately owns generations, manifests, checksums, and
/// recovery. Backends must preserve individual writes and provide one
/// cooperative writer lock across contexts that use the same namespace.
abstract interface class CalendarSnapshotBackend {
  Future<void> initialize();

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<Set<String>> keys({String? prefix});

  Future<T> withExclusiveLock<T>(String name, Future<T> Function() action);

  /// Emits a key after another context publishes it when supported.
  Stream<String> get externalChanges;
}

/// Deterministic backend for unit tests and failure injection.
final class MemoryCalendarSnapshotBackend implements CalendarSnapshotBackend {
  MemoryCalendarSnapshotBackend({Map<String, String>? seed})
    : _values = <String, String>{...?seed};

  final Map<String, String> _values;
  final StreamController<String> _changes = StreamController.broadcast();
  Future<void> _tail = Future<void>.value();
  int? failWriteNumber;
  String? failDeleteKey;
  int _writeCount = 0;

  int get writeCount => _writeCount;

  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _writeCount++;
    if (failWriteNumber == _writeCount) {
      throw StateError('Injected calendar snapshot write failure');
    }
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (key == failDeleteKey) {
      throw StateError('Injected calendar snapshot delete failure');
    }
    _values.remove(key);
  }

  @override
  Future<Set<String>> keys({String? prefix}) async => _values.keys
      .where((key) => prefix == null || key.startsWith(prefix))
      .toSet();

  @override
  Future<T> withExclusiveLock<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await predecessor;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  void simulateExternalChange(String key) => _changes.add(key);

  @override
  Stream<String> get externalChanges => _changes.stream;
}
