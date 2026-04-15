import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/insight_link_model.dart';
import 'package:mobile/widgets/insight_link_text.dart';

void main() {
  group('InsightLinkSpanBuilder', () {
    final sampleLink = InsightLink(
      id: 'link-1',
      userId: 'user-1',
      sourceType: InsightSourceType.nodeUserText,
      sourceId: 'node-1',
      start: 8,
      end: 12,
      selectedText: 'Peel',
      targetType: InsightTargetType.node,
      targetId: 'node-target',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('uses WidgetSpan links by default', () {
      final spans = InsightLinkSpanBuilder.build(
        text: 'Atwater Peel',
        links: [sampleLink],
        baseStyle: const TextStyle(fontSize: 14),
        onTap: (_) {},
      );

      expect(spans.length, 2);
      expect(spans[0], isA<TextSpan>());
      expect(spans[1], isA<WidgetSpan>());
    });

    test('supports selectable-safe TextSpan links', () {
      final recognizers = <GestureRecognizer>[];
      addTearDown(() {
        for (final recognizer in recognizers) {
          recognizer.dispose();
        }
      });

      final spans = InsightLinkSpanBuilder.build(
        text: 'Atwater Peel',
        links: [sampleLink],
        baseStyle: const TextStyle(fontSize: 14),
        onTap: (_) {},
        mode: InsightLinkSpanRenderMode.textSpan,
        gestureRecognizers: recognizers,
      );

      expect(spans.length, 2);
      expect(spans[0], isA<TextSpan>());
      expect(spans[1], isA<TextSpan>());
      expect(recognizers, hasLength(1));
      expect((spans[1] as TextSpan).recognizer, same(recognizers.single));
      expect((spans[1] as TextSpan).style?.decoration, TextDecoration.none);
      expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.w700);
    });
  });

  group('InsightLinkRangeUpdater', () {
    final baseLink = InsightLink(
      id: 'link-2',
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
    );

    test('expands a link when text is inserted inside it', () {
      final updated = InsightLinkRangeUpdater.shiftRanges(
        previous: 'Ra light',
        next: 'Rha light',
        links: [baseLink],
      );

      expect(updated, hasLength(1));
      expect(updated.single.start, 0);
      expect(updated.single.end, 3);
      expect(updated.single.selectedText, 'Rha');
    });

    test('shrinks a link when text is deleted from inside it', () {
      final updated = InsightLinkRangeUpdater.shiftRanges(
        previous: 'Rha light',
        next: 'Ra light',
        links: [baseLink.copyWith(end: 3, selectedText: 'Rha')],
      );

      expect(updated, hasLength(1));
      expect(updated.single.start, 0);
      expect(updated.single.end, 2);
      expect(updated.single.selectedText, 'Ra');
    });
  });
}
