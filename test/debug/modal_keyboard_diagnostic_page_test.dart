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
}
