import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/debug/modal_keyboard_diagnostic_page.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_sitting_editor.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

void main() {
  Future<void> pumpHarness(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: ModalKeyboardDiagnosticPage(buildLabel: 'test-build'),
      ),
    );
  }

  Future<void> closeModal(WidgetTester tester) async {
    Navigator.of(
      tester.element(find.byType(BottomSheet)),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
  }

  Future<void> openFieldMatrix(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey<String>(key));
    await tester.scrollUntilVisible(
      button,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  test('diagnostic route is available only in debug or staging builds', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(
      mainSource,
      contains(
        "kDebugMode || appEnvironmentEnv.trim().toLowerCase() == 'staging'",
      ),
    );
    expect(mainSource, contains('if (_modalKeyboardDiagnosticsEnabled)'));
    expect(mainSource, contains('path: modalKeyboardDiagnosticRoute'));
  });

  testWidgets('case A is a pure Flutter modal with no shared surface', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.byKey(const ValueKey('modal-keyboard-case-a')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(KeyboardAwareEditableSurface), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('case B can isolate native and explicit shared inset ownership', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.byKey(const ValueKey('modal-keyboard-case-b')));
    await tester.pumpAndSettle();
    var surface = tester.widget<KeyboardAwareEditableSurface>(
      find.byType(KeyboardAwareEditableSurface),
    );
    expect(surface.manageSystemKeyboardInset, isFalse);

    await closeModal(tester);
    await tester.tap(find.byKey(const ValueKey('modal-keyboard-case-b-owned')));
    await tester.pumpAndSettle();
    surface = tester.widget<KeyboardAwareEditableSurface>(
      find.byType(KeyboardAwareEditableSurface),
    );
    expect(surface.manageSystemKeyboardInset, isTrue);
  });

  testWidgets('case E has one modal-root system inset owner', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 645);
    addTearDown(tester.view.reset);
    await pumpHarness(tester);

    await tester.tap(find.byKey(const ValueKey('modal-keyboard-case-e')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(KeyboardAwareEditableSurface), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));

    tester.view.viewInsets = const FakeViewPadding(bottom: 311);
    await tester.pump();

    final keyboardTop = 645 - 311;
    final contentRect = tester.getRect(
      find.byKey(modalKeyboardCaseEContentKey),
    );
    expect(contentRect.bottom, lessThanOrEqualTo(keyboardTop));

    final contentContext = tester.element(
      find.byKey(modalKeyboardCaseEContentKey),
    );
    expect(MediaQuery.viewInsetsOf(contentContext).bottom, 0);
    final owner = tester.widget<Padding>(
      find.byKey(modalKeyboardCaseESystemInsetOwnerKey),
    );
    expect(owner.padding, const EdgeInsets.only(bottom: 311));
    expect(tester.takeException(), isNull);
  });

  testWidgets('case C runs the actual Reading House sitting editor', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.byKey(const ValueKey('modal-keyboard-case-c')));
    await tester.pumpAndSettle();

    expect(find.byType(ReadingHouseSittingEditorSheet), findsOneWidget);
    final surface = tester.widget<KeyboardAwareEditableSurface>(
      find.byType(KeyboardAwareEditableSurface),
    );
    expect(surface.manageSystemKeyboardInset, isTrue);
    expect(
      find.byKey(const ValueKey('reading_house_sitting_host_note_field')),
      findsOneWidget,
    );
  });

  testWidgets('text-field matrix A uses unmodified stock Flutter fields', (
    tester,
  ) async {
    await pumpHarness(tester);

    await openFieldMatrix(tester, 'text-field-matrix-a');

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('text-field-matrix-1')),
    );
    expect(field.decoration?.labelText, 'Baseline');
    expect(field.decoration?.hintText, isNull);
    expect(field.focusNode, isNull);
    expect(field.style, isNull);
    expect(field.scrollPadding, const EdgeInsets.all(20));
    expect(field.autofillHints, isEmpty);
  });

  testWidgets('text-field matrix C uses the current Reading House field', (
    tester,
  ) async {
    await pumpHarness(tester);

    await openFieldMatrix(tester, 'text-field-matrix-c');

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('text-field-matrix-1')),
    );
    expect(field.decoration?.labelText, isNull);
    expect(field.decoration?.hintText, 'Current Reading House field');
    expect(field.focusNode, isNull);
    expect(field.scrollPadding, const EdgeInsets.all(20));
    expect(field.autofillHints, isEmpty);
    expect(find.text('CURRENT HꜣW FIELD 1'), findsOneWidget);
  });

  testWidgets('text-field matrix B and D use the actual Reading House tree', (
    tester,
  ) async {
    await pumpHarness(tester);

    await openFieldMatrix(tester, 'text-field-matrix-bd');

    final book = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('reading-house-book')),
    );
    expect(book.decoration?.labelText, 'Book');
    expect(book.decoration?.hintText, isNull);
    expect(book.focusNode, isNull);
    expect(book.style, isNull);
    expect(book.scrollPadding, const EdgeInsets.all(20));
    expect(book.autofillHints, isEmpty);

    final edition = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('reading-house-edition')),
    );
    expect(edition.decoration?.labelText, isNull);
    expect(edition.decoration?.hintText, 'Translator, edition, or link');
    expect(edition.focusNode, isNull);
    expect(edition.scrollPadding, const EdgeInsets.all(20));
    expect(edition.autofillHints, isEmpty);
  });
}
