import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/staged_flow_lifecycle.dart';

void main() {
  test('armed completion retains terminal persistence until consumed', () {
    final lifecycle = StagedFlowLifecycle(completionRequired: true);
    final registry = StagedFlowLifecycleRegistry<StagedFlowLifecycle>()
      ..register(41, lifecycle);

    expect(lifecycle.completionRequired, isTrue);
    expect(lifecycle.beginPersistence(), isTrue);
    expect(lifecycle.persistenceStarted, isTrue);
    expect(lifecycle.persistenceCompleted, isFalse);
    expect(lifecycle.completionConsumed, isFalse);
    expect(lifecycle.shouldCleanup, isFalse);

    lifecycle.completePersistence();
    registry.cleanupIfTerminal(41);

    expect(lifecycle.persistenceCompleted, isTrue);
    expect(lifecycle.completionConsumed, isFalse);
    expect(lifecycle.shouldCleanup, isFalse);
    expect(registry.contains(41), isTrue);

    lifecycle.consumeCompletion();
    registry.cleanupIfTerminal(41);

    expect(lifecycle.completionConsumed, isTrue);
    expect(lifecycle.shouldCleanup, isTrue);
    expect(registry.contains(41), isFalse);
  });

  test(
    'never-armed completion cleans up as soon as persistence is terminal',
    () {
      final lifecycle = StagedFlowLifecycle(completionRequired: false);
      final registry = StagedFlowLifecycleRegistry<StagedFlowLifecycle>()
        ..register(42, lifecycle);

      expect(lifecycle.beginPersistence(), isTrue);
      lifecycle.completePersistence();
      registry.cleanupIfTerminal(42);

      expect(lifecycle.completionRequired, isFalse);
      expect(lifecycle.persistenceCompleted, isTrue);
      expect(lifecycle.completionConsumed, isFalse);
      expect(lifecycle.shouldCleanup, isTrue);
      expect(registry.contains(42), isFalse);
    },
  );

  test('failure records its cause and resolves an abandoned completion', () {
    final lifecycle = StagedFlowLifecycle(completionRequired: true);
    final registry = StagedFlowLifecycleRegistry<StagedFlowLifecycle>()
      ..register(43, lifecycle);
    final failure = StateError('persist failed');

    lifecycle.beginPersistence();
    lifecycle.completePersistence(failure: failure);
    registry.cleanupIfTerminal(43);

    expect(lifecycle.persistenceFailure, same(failure));
    expect(lifecycle.persistenceCompleted, isTrue);
    expect(lifecycle.shouldCleanup, isFalse);
    expect(registry.contains(43), isTrue);

    lifecycle.consumeCompletion();
    registry.cleanupIfTerminal(43);

    expect(lifecycle.completionConsumed, isTrue);
    expect(lifecycle.shouldCleanup, isTrue);
    expect(registry.contains(43), isFalse);
  });

  test('persistence start is single-flight', () {
    final lifecycle = StagedFlowLifecycle(completionRequired: false);

    expect(lifecycle.beginPersistence(), isTrue);
    expect(lifecycle.beginPersistence(), isFalse);
    expect(lifecycle.persistenceStarted, isTrue);
  });
}
