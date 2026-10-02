import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/root_boot.dart';

const _requiredStartupStages = <String>[
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
];

const _readyApp = MaterialApp(home: Text('Authenticated calendar'));

Future<void> _showBoot(
  WidgetTester tester,
  BootCoordinator coordinator,
  BootAppFactory bootstrap, {
  VoidCallback? onRetry,
  VoidCallback? onReadyFrame,
}) async {
  await tester.pumpWidget(
    RootBootApp(
      coordinator: coordinator,
      onRetry: onRetry,
      onReadyFrame: onReadyFrame,
    ),
  );
  coordinator.start(bootstrap);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'boot and recovery preserve the incoming auth and deep-link URL',
    (tester) async {
      const incomingRoute = '/login-callback?code=test-oauth-code&next=/pages';
      final navigationMessages = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          incomingRoute;
      messenger.setMockMethodCallHandler(SystemChannels.navigation, (
        call,
      ) async {
        navigationMessages.add(call);
        return null;
      });
      addTearDown(() {
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
        messenger.setMockMethodCallHandler(SystemChannels.navigation, null);
      });

      final blocked = Completer<void>();
      final coordinator = BootCoordinator();
      await _showBoot(tester, coordinator, (attempt) async {
        await attempt.run<void>('saved session', () => blocked.future);
        return _readyApp;
      });
      expect(find.byType(RootBootShell), findsOneWidget);
      expect(find.byType(Navigator), findsNothing);
      expect(
        navigationMessages,
        isEmpty,
        reason:
            'A pre-auth shell must not replace a callback or deep-link URL.',
      );

      blocked.completeError(StateError('Saved session unavailable'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(RootBootErrorShell), findsOneWidget);
      expect(find.byType(Navigator), findsNothing);
      expect(
        navigationMessages,
        isEmpty,
        reason:
            'Recovery must preserve the original URL for a full-page retry.',
      );
      expect(tester.binding.platformDispatcher.defaultRouteName, incomingRoute);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    },
  );

  testWidgets('safe shell paints before any bootstrap operation runs', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    var starts = 0;
    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start((attempt) async {
      starts += 1;
      return _readyApp;
    });

    expect(starts, 0);
    expect(find.byType(RootBootShell), findsOneWidget);
    expect(find.text('Authenticated calendar'), findsNothing);

    await tester.pump();
    await tester.pump();
    expect(starts, 1);
    expect(find.text('Authenticated calendar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  for (final blockedStage in _requiredStartupStages) {
    testWidgets('$blockedStage cannot leave boot pending indefinitely', (
      tester,
    ) async {
      final blocked = Completer<void>();
      final entered = <String>[];
      var failureNotifications = 0;
      final coordinator = BootCoordinator(
        onFailure: (_) => failureNotifications += 1,
      );

      await _showBoot(tester, coordinator, (attempt) async {
        for (final stage in _requiredStartupStages) {
          await attempt.run<void>(stage, () async {
            entered.add(stage);
            if (stage == blockedStage) await blocked.future;
          }, timeout: const Duration(milliseconds: 20));
        }
        attempt.ensureActive();
        entered.add('create router');
        entered.add('start warmups');
        return _readyApp;
      });

      expect(find.byType(RootBootShell), findsOneWidget);
      expect(find.text('Authenticated calendar'), findsNothing);
      await tester.pump(const Duration(milliseconds: 21));
      await tester.pump();

      expect(coordinator.phase, RootBootPhase.error);
      expect(coordinator.error, isA<BootFailure>());
      expect((coordinator.error as BootFailure).stage, blockedStage);
      expect(failureNotifications, 1);
      expect(find.byType(RootBootErrorShell), findsOneWidget);
      expect(
        entered,
        _requiredStartupStages
            .take(_requiredStartupStages.indexOf(blockedStage) + 1)
            .toList(),
      );

      // A browser storage/network promise can resolve after our deadline. It
      // must not resume startup, install a router, or start account warmups.
      blocked.complete();
      await tester.pump();
      await tester.pump();
      expect(coordinator.phase, RootBootPhase.error);
      expect(failureNotifications, 1);
      expect(entered.last, blockedStage);
      expect(find.text('Authenticated calendar'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    });

    testWidgets('$blockedStage failure stays behind the identity boundary', (
      tester,
    ) async {
      final entered = <String>[];
      final coordinator = BootCoordinator();
      await _showBoot(tester, coordinator, (attempt) async {
        for (final stage in _requiredStartupStages) {
          await attempt.run<void>(stage, () async {
            entered.add(stage);
            if (stage == blockedStage) {
              throw StateError('Simulated startup failure');
            }
          });
        }
        entered.add('create router');
        return _readyApp;
      });

      expect(coordinator.phase, RootBootPhase.error);
      expect((coordinator.error as BootFailure).stage, blockedStage);
      expect(find.byType(RootBootErrorShell), findsOneWidget);
      expect(find.text('Authenticated calendar'), findsNothing);
      expect(entered.last, blockedStage);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    });
  }

  testWidgets('whole-startup deadline also fences late continuations', (
    tester,
  ) async {
    final blocked = Completer<void>();
    var routerCreations = 0;
    var failures = 0;
    final coordinator = BootCoordinator(
      timeout: const Duration(milliseconds: 40),
      onFailure: (_) => failures += 1,
    );
    await _showBoot(tester, coordinator, (attempt) async {
      await attempt.run<void>(
        'saved session',
        () => blocked.future,
        timeout: const Duration(seconds: 1),
      );
      routerCreations += 1;
      return _readyApp;
    });

    await tester.pump(const Duration(milliseconds: 41));
    await tester.pump();
    expect(find.byType(RootBootErrorShell), findsOneWidget);
    expect(coordinator.phase, RootBootPhase.error);
    expect(failures, 1);

    blocked.complete();
    await tester.pump();
    await tester.pump();
    expect(routerCreations, 0);
    expect(failures, 1);
    expect(coordinator.phase, RootBootPhase.error);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  testWidgets('a late rejected operation cannot escape recovery', (
    tester,
  ) async {
    final blocked = Completer<void>();
    var failures = 0;
    final coordinator = BootCoordinator(onFailure: (_) => failures += 1);
    await _showBoot(tester, coordinator, (attempt) async {
      await attempt.run<void>(
        'saved session',
        () => blocked.future,
        timeout: const Duration(milliseconds: 20),
      );
      return _readyApp;
    });
    await tester.pump(const Duration(milliseconds: 21));
    await tester.pump();
    blocked.completeError(StateError('Storage rejected after deadline'));
    await tester.pump();
    await tester.pump();

    expect(coordinator.phase, RootBootPhase.error);
    expect(failures, 1);
    expect(find.byType(RootBootErrorShell), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  testWidgets('retry requests a reload and never reinitializes this session', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    var attempts = 0;
    var reloadRequests = 0;
    await _showBoot(tester, coordinator, (attempt) async {
      attempts += 1;
      await attempt.run<void>('saved session', () {
        throw StateError('Unavailable storage');
      });
      return _readyApp;
    }, onRetry: () => reloadRequests += 1);

    expect(find.byType(RootBootErrorShell), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(reloadRequests, 1);
    expect(attempts, 1);
    expect(coordinator.phase, RootBootPhase.error);
    expect(find.text('Authenticated calendar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  testWidgets('diagnostic failure cannot prevent the recovery frame', (
    tester,
  ) async {
    final coordinator = BootCoordinator(
      onFailure: (_) => throw StateError('Diagnostics unavailable'),
    );
    await _showBoot(tester, coordinator, (attempt) async {
      await attempt.run<void>('saved session', () {
        throw StateError('Unavailable storage');
      });
      return _readyApp;
    });

    expect(coordinator.phase, RootBootPhase.error);
    expect(find.byType(RootBootErrorShell), findsOneWidget);
    expect(find.text('Authenticated calendar'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  testWidgets('successful boot publishes one ready frame and starts once', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    var attempts = 0;
    var readyFrames = 0;
    Future<Widget> bootstrap(BootAttempt attempt) async {
      attempts += 1;
      await attempt.run<void>('saved session', () async {});
      return _readyApp;
    }

    await _showBoot(
      tester,
      coordinator,
      bootstrap,
      onReadyFrame: () => readyFrames += 1,
    );
    coordinator.start(bootstrap);
    await tester.pump();
    await tester.pump();
    expect(attempts, 1);
    expect(readyFrames, 1);
    expect(coordinator.phase, RootBootPhase.ready);
    expect(find.byType(RootBootShell), findsNothing);
    expect(find.text('Authenticated calendar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  for (final destination in ['Login', 'Onboarding']) {
    testWidgets('$destination remains authoritative after bootstrap', (
      tester,
    ) async {
      final coordinator = BootCoordinator();
      await _showBoot(tester, coordinator, (attempt) async {
        await attempt.run<void>('saved session', () async {});
        return MaterialApp(home: Text(destination));
      });
      expect(find.text(destination), findsOneWidget);
      expect(find.text('Authenticated calendar'), findsNothing);
      expect(find.byType(RootBootShell), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    });
  }

  testWidgets('disposal fences work without publishing an error or app', (
    tester,
  ) async {
    final blocked = Completer<void>();
    var continued = false;
    var failures = 0;
    final coordinator = BootCoordinator(onFailure: (_) => failures += 1);
    await _showBoot(tester, coordinator, (attempt) async {
      await attempt.run<void>('saved session', () => blocked.future);
      continued = true;
      return _readyApp;
    });
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
    blocked.complete();
    await tester.pump();

    expect(continued, isFalse);
    expect(failures, 0);
    expect(find.text('Authenticated calendar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
