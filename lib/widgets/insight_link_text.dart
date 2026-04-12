import 'package:flutter/material.dart';
import '../data/insight_link_model.dart';
import '../shared/glossy_text.dart';

typedef InsightLinkTap = void Function(InsightLink link);

class InsightLinkSpanBuilder {
  InsightLinkSpanBuilder._();

  static List<InlineSpan> build({
    required String text,
    required List<InsightLink> links,
    required TextStyle baseStyle,
    required InsightLinkTap onTap,
  }) {
    if (links.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    final sorted = [...links]..sort((a, b) => a.start.compareTo(b.start));
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final link in sorted) {
      final start = link.start.clamp(0, text.length);
      final end = link.end.clamp(0, text.length);
      if (start < cursor) continue;
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start), style: baseStyle));
      }
      spans.add(_linkSpan(text.substring(start, end), link, baseStyle, onTap));
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  static InlineSpan _linkSpan(
    String phrase,
    InsightLink link,
    TextStyle baseStyle,
    InsightLinkTap onTap,
  ) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => onTap(link),
        child: ShaderMask(
          shaderCallback: (Rect bounds) =>
              KemeticGold.gloss.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            phrase,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal helper to adjust link ranges when text changes.
class InsightLinkRangeUpdater {
  static List<InsightLink> shiftRanges({
    required String previous,
    required String next,
    required List<InsightLink> links,
  }) {
    if (previous == next) return links;

    // Find first and last differing indices
    int start = 0;
    while (start < previous.length &&
        start < next.length &&
        previous[start] == next[start]) {
      start++;
    }
    int endPrev = previous.length - 1;
    int endNext = next.length - 1;
    while (endPrev >= start &&
        endNext >= start &&
        previous[endPrev] == next[endNext]) {
      endPrev--;
      endNext--;
    }
    final delta = next.length - previous.length;

    return links.map((link) {
      if (link.start >= start) {
        final newStart = (link.start + delta).clamp(0, next.length);
        final newEnd = (link.end + delta).clamp(newStart, next.length);
        return link.copyWith(start: newStart, end: newEnd, selectedText: _safeSlice(next, newStart, newEnd), updatedAt: DateTime.now());
      }
      return link.copyWith(selectedText: _safeSlice(next, link.start, link.end));
    }).toList();
  }

  static String _safeSlice(String text, int start, int end) {
    if (start >= text.length) return '';
    return text.substring(start, end.clamp(start, text.length));
  }
}
