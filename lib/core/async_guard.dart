import 'dart:async';

typedef AsyncGuardReporter =
    void Function(String scope, Object error, StackTrace stackTrace);

Future<void> runGuardedAsync(
  String scope,
  Future<void> Function() action, {
  required AsyncGuardReporter onError,
}) async {
  try {
    await action();
  } catch (error, stackTrace) {
    onError(scope, error, stackTrace);
  }
}

void fireAndForgetGuarded<T>(
  String scope,
  Future<T>? future, {
  required AsyncGuardReporter onError,
}) {
  if (future == null) return;
  unawaited(() async {
    try {
      await future;
    } catch (error, stackTrace) {
      onError(scope, error, stackTrace);
    }
  }());
}

void runGuardedSync(
  String scope,
  void Function() action, {
  required AsyncGuardReporter onError,
}) {
  try {
    action();
  } catch (error, stackTrace) {
    onError(scope, error, stackTrace);
  }
}
