import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/insight_link_model.dart';
import 'package:mobile/data/insight_link_utils.dart';

void main() {
  group('insight link utils', () {
    final sampleLinks = [
      InsightLink(
        id: 'link-1',
        userId: 'user-1',
        sourceType: InsightSourceType.journalEntry,
        sourceId: 'journal-2026-04-15',
        start: 0,
        end: 2,
        selectedText: 'Ra',
        targetType: InsightTargetType.node,
        targetId: 'ra',
        createdAt: DateTime(2026, 4, 15),
        updatedAt: DateTime(2026, 4, 15),
      ),
      InsightLink(
        id: 'link-2',
        userId: 'user-1',
        sourceType: InsightSourceType.journalEntry,
        sourceId: 'journal-2026-04-15',
        start: 8,
        end: 12,
        selectedText: 'Khep',
        targetType: InsightTargetType.node,
        targetId: 'khepri',
        createdAt: DateTime(2026, 4, 15),
        updatedAt: DateTime(2026, 4, 15),
      ),
    ];

    test('normalizeInsightSelection trims surrounding whitespace', () {
      final selection = normalizeInsightSelection(
        text: '  link Ra  ',
        selection: const TextSelection(baseOffset: 0, extentOffset: 10),
      );

      expect(selection, const TextSelection(baseOffset: 2, extentOffset: 9));
    });

    test('journalInsightSourceId matches journal date storage format', () {
      expect(
        journalInsightSourceId(DateTime(2026, 4, 5)),
        'journal-2026-04-05',
      );
    });

    test(
      'normalizeInsightSelection returns null for whitespace-only selections',
      () {
        final selection = normalizeInsightSelection(
          text: '   ',
          selection: const TextSelection(baseOffset: 0, extentOffset: 3),
        );

        expect(selection, isNull);
      },
    );

    test('findInsightLinkForSelection prefers exact matches', () {
      final match = findInsightLinkForSelection(
        links: sampleLinks,
        selection: const TextSelection(baseOffset: 0, extentOffset: 2),
      );

      expect(match?.id, 'link-1');
    });

    test('findInsightLinkForSelection falls back to overlapping matches', () {
      final match = findInsightLinkForSelection(
        links: sampleLinks,
        selection: const TextSelection(baseOffset: 9, extentOffset: 11),
      );

      expect(match?.id, 'link-2');
    });

    test('findInsightLinkAtOffset resolves taps inside a link', () {
      final match = findInsightLinkAtOffset(links: sampleLinks, offset: 1);

      expect(match?.id, 'link-1');
    });

    test('findInsightLinkAtOffset does not treat end-of-link as inside', () {
      final match = findInsightLinkAtOffset(links: sampleLinks, offset: 2);

      expect(match, isNull);
    });

    test('findInsightLinkEndingAtOffset finds a link boundary hit', () {
      final match = findInsightLinkEndingAtOffset(
        links: sampleLinks,
        offset: 2,
      );

      expect(match?.id, 'link-1');
    });

    test('removeInsightLinksForSelection removes overlapping links only', () {
      final remaining = removeInsightLinksForSelection(
        links: sampleLinks,
        selection: const TextSelection(baseOffset: 1, extentOffset: 3),
      );

      expect(remaining.map((link) => link.id), ['link-2']);
    });
  });
}
