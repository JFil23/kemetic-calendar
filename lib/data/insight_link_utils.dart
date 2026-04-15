import 'package:flutter/services.dart';

import 'insight_link_model.dart';

String journalInsightSourceId(DateTime date) {
  return 'journal-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

TextSelection? normalizeInsightSelection({
  required String text,
  required TextSelection selection,
}) {
  if (!selection.isValid || selection.isCollapsed || text.isEmpty) return null;

  var start = selection.start.clamp(0, text.length);
  var end = selection.end.clamp(0, text.length);
  if (start > end) {
    final tmp = start;
    start = end;
    end = tmp;
  }

  while (start < end && _isLinkWhitespace(text.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _isLinkWhitespace(text.codeUnitAt(end - 1))) {
    end--;
  }

  if (start >= end) return null;
  return TextSelection(baseOffset: start, extentOffset: end);
}

String selectedInsightText({
  required String text,
  required TextSelection selection,
}) {
  return text.substring(selection.start, selection.end);
}

InsightLink? findInsightLinkForSelection({
  required Iterable<InsightLink> links,
  required TextSelection selection,
}) {
  InsightLink? overlapping;
  for (final link in links) {
    if (link.start == selection.start && link.end == selection.end) {
      return link;
    }
    if (insightLinkOverlapsSelection(link, selection)) {
      overlapping ??= link;
    }
  }
  return overlapping;
}

InsightLink? findInsightLinkAtOffset({
  required Iterable<InsightLink> links,
  required int offset,
}) {
  for (final link in links) {
    if (_offsetWithinLink(link, offset)) {
      return link;
    }
  }
  return null;
}

InsightLink? findInsightLinkEndingAtOffset({
  required Iterable<InsightLink> links,
  required int offset,
}) {
  for (final link in links) {
    if (link.end == offset) {
      return link;
    }
  }
  return null;
}

bool insightLinkOverlapsSelection(InsightLink link, TextSelection selection) {
  return link.start < selection.end && link.end > selection.start;
}

List<InsightLink> removeInsightLinksForSelection({
  required Iterable<InsightLink> links,
  required TextSelection selection,
}) {
  return links
      .where((link) => !insightLinkOverlapsSelection(link, selection))
      .toList();
}

bool _isLinkWhitespace(int charCode) {
  return charCode == 0x20 ||
      charCode == 0x09 ||
      charCode == 0x0A ||
      charCode == 0x0D;
}

bool _offsetWithinLink(InsightLink link, int offset) {
  return offset >= link.start && offset < link.end;
}
