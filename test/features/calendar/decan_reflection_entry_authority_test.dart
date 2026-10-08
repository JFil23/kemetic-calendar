import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/decan_reflection_badge.dart';
import 'package:mobile/features/reflections/decan_review_controller.dart';
import 'package:mobile/features/reflections/decan_review_widgets.dart';

void main() {
  test('Calendar and detail have one review owner and no legacy renderer', () {
    final calendar = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/reflections/decan_reflection_detail_page.dart',
    ).readAsStringSync();
    final badge = File(
      'lib/features/calendar/decan_reflection_badge.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/features/reflections/decan_review_controller.dart',
    ).readAsStringSync();
    expect(calendar, isNot(contains('Archive to profile')));
    expect(calendar, isNot(contains('_archiveReflectionPrompt')));
    expect(calendar, isNot(contains('decan_reflection_composer.dart')));
    expect(detail, contains('return DecanReviewScreen('));
    expect(detail, isNot(contains('DecanFolioMasthead')));
    expect(detail, isNot(contains('data?.reviewContext != null')));
    expect(badge, isNot(contains('reflectionText')));
    expect(badge, isNot(contains('renderMetadata')));
    expect(controller, isNot(contains('preserved earlier reflection')));
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(contains('test/support/legacy_decan')),
        reason: file.path,
      );
    }
  });
  for (final id in <String?>[null, 'legacy-period', 'review-period']) {
    testWidgets('approved badge is universal for $id', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DecanReflectionLowerThirdBadge(
                prompt: CalendarDecanReflectionPrompt(
                  id: id,
                  reviewWindow: DecanReviewWindow(
                    start: DateTime(2026, 9, 26),
                    end: DateTime(2026, 10, 5),
                    name: 'Current period',
                  ),
                ),
                maxWidth: 280,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('These ten days'), findsOneWidget);
      expect(find.text('Your decan reflection'), findsOneWidget);
      expect(find.byType(DecanReviewSeal), findsOneWidget);
      expect(find.text('Decan reflection'), findsNothing);
      await tester.tap(find.byKey(decanReflectionLowerThirdBadgeKey));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
