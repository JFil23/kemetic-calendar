import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/core/boot_diagnostics.dart';
import 'package:mobile/root_boot.dart';
import 'package:mobile/utils/hive_local_storage_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeBrowserError {
  FakeBrowserError(this.name);
  final String name;
  @override
  String toString() => 'private-token-and-callback';
}

class BrokenError {
  String get name => throw StateError('private');
  @override
  String toString() => throw StateError('must not stringify');
}

class SessionBox extends Fake implements Box<String> {
  String? value;
  Object? readError;
  Object? checkError;
  final accessedKeys = <dynamic>[];
  int deletes = 0;
  @override
  String? get(dynamic key, {String? defaultValue}) {
    accessedKeys.add(key);
    if (readError != null) throw readError!;
    return value;
  }

  @override
  bool containsKey(dynamic key) {
    accessedKeys.add(key);
    if (checkError != null) throw checkError!;
    return value != null;
  }

  @override
  Future<void> put(dynamic key, String value) async {
    accessedKeys.add(key);
    this.value = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    deletes++;
    value = null;
  }
}

class SessionHive extends Fake implements HiveInterface {
  final session = SessionBox();
  Object? openError;
  int opens = 0;
  final names = <String>[];
  @override
  Future<Box<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    dynamic bytes,
    String? collection,
    List<int>? encryptionKey,
  }) async {
    opens++;
    names.add(name);
    if (openError != null) throw openError!;
    return session as Box<E>;
  }

  @override
  Box<E> box<E>(String name) {
    names.add(name);
    return session as Box<E>;
  }
}

void main() {
  test('categories never expose messages or unknown names', () {
    expect(bootErrorCategory(FakeBrowserError('VersionError')), 'VersionError');
    expect(bootErrorCategory(FakeBrowserError('private-token')), 'unknown');
    expect(bootErrorCategory(BrokenError()), 'unknown');
    expect(bootErrorCategory(FormatException('private')), 'format');
    expect(bootErrorCategory(HiveError('private')), 'hive');
    expect(bootErrorCategory(TimeoutException('private')), 'timeout');
    expect(bootStageLabel('private-route'), 'startup');
  });

  test(
    'successful storage preserves box, key, session and once-only initialization',
    () async {
      final hive = SessionHive();
      var initializations = 0;
      final storage = HiveLocalStorageWeb(
        hive: hive,
        initializeHive: () async {
          initializations++;
        },
      );
      await storage.initialize();
      await storage.initialize();
      expect(initializations, 1);
      expect(hive.opens, 1);
      expect(await storage.hasAccessToken(), false);
      await storage.persistSession('session-value');
      expect(await storage.hasAccessToken(), true);
      expect(await storage.accessToken(), 'session-value');
      expect(hive.names.toSet(), {'sb_session'});
      expect(hive.session.accessedKeys.toSet(), {supabasePersistSessionKey});
      await storage.removePersistedSession();
      expect(hive.session.deletes, 1);
      expect(await storage.hasAccessToken(), false);
    },
  );

  for (final operation in BootStorageOperation.values) {
    testWidgets(
      'real storage boundary reports ${operation.name} and preserves data',
      (tester) async {
        final hive = SessionHive();
        hive.session.value = 'private-existing-session';
        final failure = FakeBrowserError('InvalidStateError');
        if (operation == BootStorageOperation.openSessionBox) {
          hive.openError = failure;
        }
        if (operation == BootStorageOperation.checkSession) {
          hive.session.checkError = failure;
        }
        if (operation == BootStorageOperation.readSession) {
          hive.session.readError = failure;
        }
        final storage = HiveLocalStorageWeb(
          hive: hive,
          initializeHive: () async {
            if (operation == BootStorageOperation.initializeHive) throw failure;
          },
        );
        final coordinator = BootCoordinator();
        var retries = 0;
        await tester.pumpWidget(
          RootBootApp(
            coordinator: coordinator,
            onRetry: () {
              retries++;
            },
          ),
        );
        coordinator.start((attempt) async {
          await attempt.run('saved session', () async {
            await storage.initialize();
            if (await storage.hasAccessToken()) await storage.accessToken();
          });
          return const MaterialApp(home: Text('ready'));
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('Stage: saved session'), findsOneWidget);
        expect(
          find.textContaining('Operation: ${operation.name}'),
          findsOneWidget,
        );
        expect(find.textContaining('Error: InvalidStateError'), findsOneWidget);
        expect(find.byKey(const ValueKey('boot-release')), findsOneWidget);
        expect(find.textContaining('private'), findsNothing);
        expect(find.text('ready'), findsNothing);
        expect(hive.session.value, 'private-existing-session');
        expect(hive.session.deletes, 0);
        final wrapped = coordinator.error!.cause as BootStorageFailure;
        expect(identical(wrapped.cause, failure), true);
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(retries, 1);
        expect(
          hive.opens,
          operation == BootStorageOperation.initializeHive ? 0 : 1,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        coordinator.dispose();
      },
    );
  }

  testWidgets('synchronous post-read failure keeps its own stage', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start((attempt) async {
      await attempt.run('saved navigation', () async {});
      attempt.enterStage('router initialization');
      throw StateError('private-route');
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Stage: router initialization'), findsOneWidget);
    expect(find.textContaining('private-route'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });
}
