import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:mobile/features/journal/journal_v2_rich_text.dart';

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
}
