import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/node_user_insights_section.dart';

void main() {
  test('insight editor height stays within the keyboard-safe viewport', () {
    const media = MediaQueryData(
      size: Size(390, 844),
      padding: EdgeInsets.only(top: 47, bottom: 34),
    );

    final closedHeight = insightEntryEditorSheetHeight(
      media: media,
      keyboardInset: 0,
    );
    final keyboardOpenHeight = insightEntryEditorSheetHeight(
      media: media,
      keyboardInset: 320,
    );

    expect(closedHeight, closeTo(692.08, 0.01));
    expect(keyboardOpenHeight, closeTo(469, 0.01));
    expect(keyboardOpenHeight + 320, lessThanOrEqualTo(media.size.height));
  });
}
