import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/async_guard.dart';

void main() {
  test('runGuardedAsync reports async failures once', () async {
    final reports = <(String, Object, StackTrace)>[];

    await runGuardedAsync(
      'async_scope',
      () async {
        throw StateError('boom');
      },
      onError: (scope, error, stackTrace) {
        reports.add((scope, error, stackTrace));
      },
    );

    expect(reports, hasLength(1));
    expect(reports.single.$1, 'async_scope');
    expect(reports.single.$2, isA<StateError>());
  });

  test('fireAndForgetGuarded reports background failures', () async {
    final reports = <(String, Object, StackTrace)>[];

    fireAndForgetGuarded(
      'background_scope',
      Future<void>.error(StateError('background boom')),
      onError: (scope, error, stackTrace) {
        reports.add((scope, error, stackTrace));
      },
    );

    await Future<void>.delayed(Duration.zero);

    expect(reports, hasLength(1));
    expect(reports.single.$1, 'background_scope');
    expect(reports.single.$2, isA<StateError>());
  });

  test('runGuardedSync reports sync failures', () {
    final reports = <(String, Object, StackTrace)>[];

    runGuardedSync(
      'sync_scope',
      () {
        throw ArgumentError('bad input');
      },
      onError: (scope, error, stackTrace) {
        reports.add((scope, error, stackTrace));
      },
    );

    expect(reports, hasLength(1));
    expect(reports.single.$1, 'sync_scope');
    expect(reports.single.$2, isA<ArgumentError>());
  });
}
