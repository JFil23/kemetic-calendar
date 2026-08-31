import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/node_link_picker_sheet.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

void main() {
  testWidgets('node link picker uses the shared editable modal inset owner', (
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
                key: const ValueKey<String>('open-node-link-picker'),
                onPressed: () => showNodeLinkPickerSheet(
                  context: context,
                  selectedText: 'chosen passage',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-node-link-picker')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 311);
    await tester.pump();

    expect(find.byKey(editableModalSystemInsetOwnerKey), findsOneWidget);
    final searchField = find.byType(TextField).first;
    expect(MediaQuery.viewInsetsOf(tester.element(searchField)).bottom, 0);
    expect(tester.getRect(searchField).bottom, lessThanOrEqualTo(334));
    expect(tester.takeException(), isNull);
  });
}
