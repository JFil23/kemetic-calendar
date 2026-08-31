import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

void main() {
  testWidgets('editable modal owns one system inset at its content root', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 645);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey<String>('open-editable-modal'),
                onPressed: () => showEditableModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => KeyboardAwareEditableSurface(
                    child: Material(
                      key: const ValueKey<String>('editable-modal-content'),
                      child: SizedBox(
                        height: 300,
                        child: ListView(
                          children: const <Widget>[
                            SizedBox(height: 220),
                            TextField(
                              key: ValueKey<String>('editable-modal-field'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-editable-modal')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 311);
    await tester.pump();

    expect(find.byKey(editableModalSystemInsetOwnerKey), findsOneWidget);
    final owner = tester.widget<Padding>(
      find.byKey(editableModalSystemInsetOwnerKey),
    );
    expect(owner.padding, const EdgeInsets.only(bottom: 311));

    final content = find.byKey(
      const ValueKey<String>('editable-modal-content'),
    );
    expect(tester.getRect(content).bottom, lessThanOrEqualTo(334));
    expect(MediaQuery.viewInsetsOf(tester.element(content)).bottom, 0);

    final surface = tester.widget<KeyboardAwareEditableSurface>(
      find.byType(KeyboardAwareEditableSurface),
    );
    expect(surface.manageSystemKeyboardInset, isFalse);
    expect(tester.takeException(), isNull);
  });
}
