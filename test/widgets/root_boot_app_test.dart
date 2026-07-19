import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/root_boot.dart';
import 'package:mobile/shared/glossy_text.dart';

void main() {
  testWidgets('boot shell owns the animated glossy launch word', (
    tester,
  ) async {
    await tester.pumpWidget(const RootBootShell());

    final glossyWord = find.descendant(
      of: find.byType(RootBootShell),
      matching: find.byType(GlossyText),
    );
    expect(glossyWord, findsOneWidget);

    final before = tester.widget<GlossyText>(glossyWord).gradient;
    await tester.pump(const Duration(milliseconds: 1300));
    final after = tester.widget<GlossyText>(glossyWord).gradient;

    expect(after, isNot(equals(before)));
  });

  testWidgets('blocked bootstrap keeps RootBootShell visible', (tester) async {
    final coordinator = BootCoordinator();
    final bootstrap = Completer<Widget>();

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(() => bootstrap.future);
    await tester.pump();

    expect(find.byType(RootBootShell), findsOneWidget);
    expect(find.text('Authenticated app'), findsNothing);

    coordinator.dispose();
  });

  testWidgets('bootstrap does not run synchronously before shell can paint', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    var starts = 0;

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(() async {
      starts += 1;
      return const MaterialApp(home: Text('Started'));
    });

    expect(starts, 0);
    expect(find.byType(RootBootShell), findsOneWidget);

    await tester.pump();

    expect(starts, 1);
    coordinator.dispose();
  });

  testWidgets('ready authenticated destination replaces boot shell', (
    tester,
  ) async {
    final coordinator = BootCoordinator();

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(
      () async => const MaterialApp(home: Text('Authenticated app')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(RootBootShell), findsNothing);
    expect(find.text('Authenticated app'), findsOneWidget);

    coordinator.dispose();
  });

  testWidgets('ready login destination does not expose cached app content', (
    tester,
  ) async {
    final coordinator = BootCoordinator();

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(() async => const MaterialApp(home: Text('Login')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Cached calendar'), findsNothing);

    coordinator.dispose();
  });

  testWidgets('ready onboarding destination remains authoritative', (
    tester,
  ) async {
    final coordinator = BootCoordinator();

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(() async => const MaterialApp(home: Text('Onboarding')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('Cached calendar'), findsNothing);

    coordinator.dispose();
  });

  testWidgets('post-ready warmups do not block visible destination', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    final warmup = Completer<void>();

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(() async {
      unawaited(warmup.future);
      return const MaterialApp(home: Text('Cached calendar'));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Cached calendar'), findsOneWidget);
    expect(find.byType(RootBootShell), findsNothing);

    warmup.complete();
    coordinator.dispose();
  });

  testWidgets(
    'boot errors show retry shell and retry runs bootstrap once more',
    (tester) async {
      final coordinator = BootCoordinator();
      var attempts = 0;

      Future<Widget> bootstrap() async {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('blocked boot');
        }
        return const MaterialApp(home: Text('Recovered app'));
      }

      await tester.pumpWidget(RootBootApp(coordinator: coordinator));
      coordinator.start(bootstrap);
      await tester.pump();
      await tester.pump();

      expect(find.byType(RootBootErrorShell), findsOneWidget);
      expect(find.text('Recovered app'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(find.text('Recovered app'), findsOneWidget);

      coordinator.dispose();
    },
  );

  testWidgets('start is idempotent and does not consume boot work twice', (
    tester,
  ) async {
    final coordinator = BootCoordinator();
    var starts = 0;

    Future<Widget> bootstrap() async {
      starts += 1;
      return const MaterialApp(home: Text('Booted once'));
    }

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator
      ..start(bootstrap)
      ..start(bootstrap);
    await tester.pump();
    await tester.pump();

    expect(starts, 1);
    expect(find.text('Booted once'), findsOneWidget);

    coordinator.dispose();
  });

  testWidgets('completion after disposal is ignored', (tester) async {
    final coordinator = BootCoordinator();
    final bootstrap = Completer<Widget>();

    await tester.pumpWidget(RootBootApp(coordinator: coordinator));
    coordinator.start(() => bootstrap.future);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    bootstrap.complete(const MaterialApp(home: Text('Too late')));
    await tester.pump();

    expect(find.text('Too late'), findsNothing);
    coordinator.dispose();
  });
}
