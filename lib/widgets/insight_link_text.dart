import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../data/insight_link_model.dart';
import '../shared/glossy_text.dart';

typedef InsightLinkTap = void Function(InsightLink link);

enum InsightLinkSpanRenderMode { widgetSpan, textSpan }

class InsightLinkTextStyle {
  InsightLinkTextStyle._();

  static const List<Shadow> _nodeLinkShadows = [
    Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
    Shadow(color: Colors.white10, blurRadius: 5, offset: Offset(0, 2)),
  ];

  static TextStyle widgetStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      shadows: _nodeLinkShadows,
      decoration: TextDecoration.none,
    );
  }

  static TextStyle textSpanStyle(
    TextStyle baseStyle,
    String phrase, {
    Rect? shaderRect,
  }) {
    return widgetStyle(baseStyle).copyWith(
      color: null,
      foreground: _glossPaint(baseStyle, phrase, shaderRect: shaderRect),
    );
  }

  static Paint _glossPaint(
    TextStyle baseStyle,
    String phrase, {
    Rect? shaderRect,
  }) {
    final fontSize = baseStyle.fontSize ?? 16.0;
    final estimatedWidth = (phrase.length.clamp(1, 48) * fontSize * 0.72)
        .toDouble();
    final rect =
        shaderRect ?? Rect.fromLTWH(0, 0, estimatedWidth, fontSize * 1.8);
    return Paint()..shader = KemeticGold.gloss.createShader(rect);
  }
}

class InsightLinkSpanBuilder {
  InsightLinkSpanBuilder._();

  static List<InlineSpan> build({
    required String text,
    required List<InsightLink> links,
    required TextStyle baseStyle,
    required InsightLinkTap onTap,
    InsightLinkSpanRenderMode mode = InsightLinkSpanRenderMode.widgetSpan,
    List<GestureRecognizer>? gestureRecognizers,
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
        spans.add(
          TextSpan(text: text.substring(cursor, start), style: baseStyle),
        );
      }
      spans.add(
        _linkSpan(
          text.substring(start, end),
          link,
          baseStyle,
          onTap,
          mode: mode,
          gestureRecognizers: gestureRecognizers,
        ),
      );
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
    InsightLinkTap onTap, {
    required InsightLinkSpanRenderMode mode,
    List<GestureRecognizer>? gestureRecognizers,
  }) {
    final linkStyle = mode == InsightLinkSpanRenderMode.textSpan
        ? InsightLinkTextStyle.textSpanStyle(baseStyle, phrase)
        : InsightLinkTextStyle.widgetStyle(baseStyle);
    if (mode == InsightLinkSpanRenderMode.textSpan) {
      final recognizer = TapGestureRecognizer()..onTap = () => onTap(link);
      gestureRecognizers?.add(recognizer);
      return TextSpan(text: phrase, style: linkStyle, recognizer: recognizer);
    }
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
          child: Text(phrase, style: linkStyle),
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
    final oldChangeEnd = endPrev >= start ? endPrev + 1 : start;
    final newChangeEnd = endNext >= start ? endNext + 1 : start;
    final delta = next.length - previous.length;
    final updatedLinks = <InsightLink>[];

    for (final link in links) {
      final newStart = _transformPosition(
        position: link.start,
        changeStart: start,
        oldChangeEnd: oldChangeEnd,
        newChangeEnd: newChangeEnd,
        delta: delta,
        stickToEnd: false,
      );
      final newEnd = _transformPosition(
        position: link.end,
        changeStart: start,
        oldChangeEnd: oldChangeEnd,
        newChangeEnd: newChangeEnd,
        delta: delta,
        stickToEnd: true,
      ).clamp(newStart, next.length);
      if (newEnd <= newStart) {
        continue;
      }

      updatedLinks.add(
        link.copyWith(
          start: newStart,
          end: newEnd,
          selectedText: _safeSlice(next, newStart, newEnd),
          updatedAt: DateTime.now(),
        ),
      );
    }

    return updatedLinks;
  }

  static int _transformPosition({
    required int position,
    required int changeStart,
    required int oldChangeEnd,
    required int newChangeEnd,
    required int delta,
    required bool stickToEnd,
  }) {
    if (position <= changeStart) return position;
    if (position >= oldChangeEnd) return position + delta;
    return stickToEnd ? newChangeEnd : changeStart;
  }

  static String _safeSlice(String text, int start, int end) {
    if (start >= text.length) return '';
    return text.substring(start, end.clamp(start, text.length));
  }
}
