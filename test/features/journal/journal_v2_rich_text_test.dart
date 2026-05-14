import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:mobile/features/journal/journal_v2_rich_text.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';

void main() {
  testWidgets('shows placeholder when empty document stores only a newline', (
    tester,
  ) async {
    const placeholder = '"What needs your attention today?"';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: RichTextEditor(
              initialBlock: const ParagraphBlock(
                id: 'p-empty',
                ops: [TextOp(insert: '\n')],
              ),
              onChanged: (_) {},
              placeholderText: placeholder,
            ),
          ),
        ),
      ),
    );

    expect(find.text(placeholder), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Answered.');
    await tester.pump();

    expect(find.text(placeholder), findsNothing);
  });

  testWidgets('keeps the journal editor caret above the keyboard inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 280, 24, 0),
              child: SizedBox(
                height: 240,
                child: RichTextEditor(
                  initialBlock: const ParagraphBlock(
                    id: 'p-keyboard',
                    ops: [TextOp(insert: '\n')],
                  ),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.scrollPadding.bottom, 356);

    final text = List<String>.generate(
      40,
      (index) => 'Journal line ${index + 1}',
    ).join('\n');
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    final caretRect = editable.renderEditable.getLocalRectForCaret(
      editable.widget.controller.selection.extent,
    );
    final caretBottom = editable.renderEditable
        .localToGlobal(caretRect.bottomLeft)
        .dy;

    expect(caretBottom + 20, lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
  });
}
