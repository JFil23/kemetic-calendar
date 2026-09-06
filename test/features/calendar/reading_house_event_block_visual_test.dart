import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_event_block_visual.dart';

void main() {
  Future<void> pumpBlocks(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF050504),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  ReadingHouseEventBlockVisual(),
                  SizedBox(height: 24),
                  ReadingHouseEventBlockVisual(
                    size: ReadingHouseEventBlockSize.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in <Size>[
    const Size(320, 700),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('featured and compact Reading House blocks fit $size', (
      tester,
    ) async {
      await pumpBlocks(tester, size);
      expect(
        find.byKey(
          const ValueKey<String>('reading-house-event-block-featured'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('reading-house-event-block-compact')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
