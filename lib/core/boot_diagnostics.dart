import 'dart:async';

import 'package:hive/hive.dart';

import 'boot_browser_error_stub.dart'
    if (dart.library.html) 'boot_browser_error_web.dart';

/// Fixed operation labels only; never retain account data in diagnostic text.
enum BootStorageOperation {
  initializeHive,
  openSessionBox,
  checkSession,
  readSession,
}

class BootStorageFailure implements Exception {
  const BootStorageFailure(this.operation, this.cause);
  final BootStorageOperation operation;
  final Object cause;

  @override
  String toString() => '${operation.name}: ${bootErrorCategory(cause)}';
}

/// Categories remain stable in dart2js release builds. Never stringify errors.
String bootErrorCategory(Object error) {
  if (error is BootStorageFailure) return bootErrorCategory(error.cause);
  if (error is TimeoutException) return 'timeout';
  if (error is FormatException) return 'format';
  if (error is TypeError) return 'type';
  if (error is HiveError) return 'hive';
  if (error is StateError) return 'state';
  // Browser IndexedDB errors expose a name. Accept only fixed standard names;
  // both absent properties and throwing getters are diagnostic-safe.
  try {
    final Object? name = browserBootErrorName(error) ?? (error as dynamic).name;
    const names = <String>{
      'AbortError',
      'ConstraintError',
      'DataError',
      'DataCloneError',
      'InvalidAccessError',
      'InvalidStateError',
      'NotFoundError',
      'QuotaExceededError',
      'ReadOnlyError',
      'SecurityError',
      'TransactionInactiveError',
      'UnknownError',
      'VersionError',
    };
    if (name is String && names.contains(name)) return name;
  } catch (_) {
    // A diagnostic must never replace the original failure.
  }
  return 'unknown';
}

String bootStageLabel(String stage) {
  const stages = <String>{
    'first frame',
    'device time zone',
    'runtime configuration',
    'saved session',
    'session refresh',
    'profile cache',
    'window identity',
    'restoration storage',
    'navigation trace',
    'initial app link',
    'initial push',
    'saved navigation',
    'router initialization',
    'launch restoration',
    'background setup',
  };
  return stages.contains(stage) ? stage : 'startup';
}

const bootDiagnosticRelease = String.fromEnvironment(
  'HYDRATION_DIAGNOSTIC_BUILD',
  defaultValue: 'unversioned',
);
