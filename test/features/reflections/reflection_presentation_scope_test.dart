import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reflection presentation stays inside the review and its badge', () {
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.startsWith('lib/features/reflections/') ||
          file.path == 'lib/features/calendar/decan_reflection_badge.dart') {
        continue;
      }
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('decan_review_widgets.dart')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('decan_review_views.dart')),
        reason: file.path,
      );
      expect(source, isNot(contains('DecanReviewCanvas')), reason: file.path);
    }
    expect(
      File('lib/features/journal/journal_document_view.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/profile/decan_insight_post.dart').existsSync(),
      isFalse,
    );
  });
}
