import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'compose_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeComposeTests);
  test('obsolete generator is absent from canonical application source', () {
    expect(
      File(
        'lib/features/ai_generation/ai_flow_generation_modal.dart',
      ).existsSync(),
      isFalse,
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(contains('AIFlowGenerationModal')),
        reason: file.path,
      );
    }
  });
  testWidgets(
    'Compose owns generation with the current spectrum and no header shortcut',
    (tester) async {
      await openCompose(tester);
      expect(find.text('Compose'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('flow-studio-spectrum')),
        findsOneWidget,
      );
      expect(find.text('Generate with AI'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.auto_awesome),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('manual Build retains its color picker', (tester) async {
    await openCompose(tester, build: true);
    expect(find.text('COLOR'), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-studio-spectrum')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Compose typing remains visible with keyboard and rotation', (
    tester,
  ) async {
    await openCompose(tester);
    final field = find.byType(TextField).first;
    await revealCompose(tester, field);
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    final before = tester.getRect(field);
    await tester.enterText(field, 'Build a calm seven day practice.');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(field).top, closeTo(before.top, .01));
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(844 - 320));
    tester.view.physicalSize = const Size(844, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Compose calendar toggle keeps both dates and duration', (
    tester,
  ) async {
    await openCompose(tester);
    await revealCompose(tester, find.text('Gregorian'));
    await tester.tap(find.text('Kemetic'));
    await tester.pumpAndSettle();
    expect(find.text('2026-06-02'), findsNothing);
    expect(find.text('2026-06-11'), findsNothing);
    await tester.tap(find.text('Gregorian'));
    await tester.pumpAndSettle();
    expect(find.text('2026-06-02'), findsOneWidget);
    expect(find.text('2026-06-11'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final kemetic in [false, true]) {
    testWidgets(
      'Compose ${kemetic ? 'Kemetic' : 'Gregorian'} date picker cancel done reopen',
      (tester) async {
        await openCompose(tester);
        if (kemetic) {
          await revealCompose(tester, find.text('Kemetic'));
          await tester.tap(find.text('Kemetic'));
          await tester.pumpAndSettle();
        }
        final date = find.byType(OutlinedButton).first;
        await revealCompose(tester, date);
        final original = tester
            .widget<OutlinedButton>(date)
            .child!
            .toStringDeep();
        for (final action in ['Cancel', 'Done', 'Cancel']) {
          await tester.tap(date);
          await tester.pumpAndSettle();
          expect(
            find.text(kemetic ? 'Kemetic Calendar' : 'Gregorian Calendar'),
            findsWidgets,
          );
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(
            tester.widget<OutlinedButton>(date).child!.toStringDeep(),
            original,
          );
        }
        expect(find.text('Use prompt duration'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
