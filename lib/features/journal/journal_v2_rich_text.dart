// lib/features/journal/journal_v2_rich_text.dart
// Rich text editor using custom TextEditingController for formatting

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_utils.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../widgets/insight_link_text.dart';
import 'journal_v2_document_model.dart';
import 'journal_event_badge.dart';

typedef BadgeToggleCallback = void Function(String badgeId, bool expanded);

/// Shared badge-aware span builder for both editor and archive rendering.
class JournalBadgeSpanBuilder {
  static List<InlineSpan> build({
    required String text,
    required TextStyle style,
    Map<String, bool>? expansionState,
    BadgeToggleCallback? onToggle,
    bool compact = false,
    bool renderBadgesInline = true,
  }) {
    final spans = <InlineSpan>[];
    const startTag = '⟦EVENT_BADGE';
    const endTag = '⟧';
    int cursor = 0;

    while (true) {
      final start = text.indexOf(startTag, cursor);
      if (start == -1) break;
      final end = text.indexOf(endTag, start + startTag.length);

      // If we can't find a closing tag, treat remainder as plain text
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(cursor), style: style));
        return spans;
      }

      // Add any plain text before the token
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start), style: style));
      }

      final rawContent = text.substring(start + startTag.length, end).trim();
      final token = EventBadgeToken.parse(rawContent);

      if (token != null) {
        if (renderBadgesInline) {
          final expanded = expansionState != null
              ? (expansionState[token.id] ?? false)
              : false;

          // Force badge to a new block with breathing room
          // In edit mode (compact), ensure badges are on their own line
          if (spans.isNotEmpty) {
            spans.add(const TextSpan(text: '\n'));
          }

          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: double.infinity),
                  child: KeyedSubtree(
                    key: ValueKey('badge-${token.id}'),
                    child: EventBadgeWidget(
                      token: token,
                      initialExpanded: compact ? false : expanded,
                      onToggle: onToggle != null
                          ? (next) => onToggle(token.id, next)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );

          // Extra spacing after badge so following text/badges do not collide
          spans.add(const TextSpan(text: '\n'));
        }
      } else if (renderBadgesInline) {
        // Fallback: render nothing (preserve text length via zero width) to avoid raw token spill
        spans.add(const WidgetSpan(child: SizedBox.shrink()));
      }

      cursor = end + endTag.length;
    }

    // Trailing text after the last token
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return spans;
  }
}

/// Custom controller that renders formatted text
class _FormattedTextEditingController extends TextEditingController {
  ParagraphBlock block;
  List<TextRange> highlightedRanges;
  double? layoutWidth;
  // Persist badge expansion state across rebuilds so toggle doesn't vanish
  final Map<String, bool> _badgeExpansion = {};
  bool get anyBadgeExpanded => _badgeExpansion.values.any((v) => v);
  Map<String, bool> get badgeExpansion => Map.unmodifiable(_badgeExpansion);
  final BadgeToggleCallback? onExternalBadgeToggle;

  _FormattedTextEditingController({
    required this.block,
    this.highlightedRanges = const [],
    this.onExternalBadgeToggle,
  }) : super(text: _opsToPlainText(block.ops));

  @override
  set value(TextEditingValue newValue) {
    final protected = _protectEventBadgeTokens(super.value, newValue);
    assert(() {
      _debugLogValueChange('value.set', super.value, newValue, protected);
      return true;
    }());
    super.value = protected;

    // If external code (e.g., custom keyboards) updates the controller text,
    // keep the rendered block in sync so buildTextSpan shows the new content.
    final currentPlain = _opsToPlainText(block.ops);
    if (protected.text != currentPlain) {
      block = ParagraphBlock(
        id: block.id.isEmpty
            ? 'p-${DateTime.now().millisecondsSinceEpoch}'
            : block.id,
        ops: [TextOp(insert: protected.text)],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  // helper to find badge ranges in text
  List<TextRange> _findBadgeRanges(String text) {
    final regex = RegExp(r'⟦EVENT_BADGE([\s\S]*?)⟧');
    return regex
        .allMatches(text)
        .map((m) => TextRange(start: m.start, end: m.end))
        .toList();
  }

  TextEditingValue _protectEventBadgeTokens(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (oldText.isEmpty || oldText == newText) {
      return newValue;
    }

    final oldRanges = _findBadgeRanges(oldText);
    if (oldRanges.isEmpty) {
      return newValue;
    }

    // Let formatter handle reroute; just clamp selection away from badges here.
    final protectedRanges = _findBadgeRanges(newText);
    final selection = _clampSelectionOutsideBadges(
      protectedRanges,
      newValue.selection,
    );
    return newValue.copyWith(selection: selection, composing: TextRange.empty);
  }

  TextSelection _clampSelectionOutsideBadges(
    List<TextRange> ranges,
    TextSelection selection,
  ) {
    var sel = selection;
    for (final r in ranges) {
      if (sel.start > r.start && sel.start < r.end) {
        sel = sel.copyWith(baseOffset: r.end, extentOffset: r.end);
      }
      if (sel.end > r.start && sel.end < r.end) {
        sel = sel.copyWith(baseOffset: sel.baseOffset, extentOffset: r.end);
      }
    }
    return sel;
  }

  static String _opsToPlainText(List<TextOp> ops) {
    return ops.map((op) => op.insert).join();
  }

  /// Add/remove real newline padding around a badge token to force spacing.
  void onBadgeToggled(String badgeId, bool expanded) {
    _badgeExpansion[badgeId] = expanded;

    final textStr = value.text;
    final badgeRegex = RegExp(
      r'⟦EVENT_BADGE[\s\S]*?id=' + RegExp.escape(badgeId) + r'[\s\S]*?⟧',
    );
    final match = badgeRegex.firstMatch(textStr);
    if (match == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      onExternalBadgeToggle?.call(badgeId, expanded);
      return;
    }

    final token = match.group(0)!;
    final beforeIdx = match.start;
    final afterIdx = match.end;

    String prefix = textStr.substring(0, beforeIdx);
    String suffix = textStr.substring(afterIdx);

    prefix = prefix.replaceFirst(RegExp(r'\n*$'), '');
    suffix = suffix.replaceFirst(RegExp(r'^\n*'), '');

    final beforeLines = expanded ? 8 : 1;
    final afterLines = expanded ? 8 : 1;
    final padBefore = '\n' * beforeLines;
    final padAfter = '\n' * afterLines;

    final newText = '$prefix$padBefore$token$padAfter$suffix';
    final newSelOffset = (prefix.length + padBefore.length + token.length)
        .clamp(0, newText.length);

    value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelOffset),
      composing: TextRange.empty,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    onExternalBadgeToggle?.call(badgeId, expanded);
  }

  void updateBlock(ParagraphBlock newBlock) {
    block = newBlock;
    final newText = _opsToPlainText(block.ops);
    if (text != newText) {
      value = value.copyWith(text: newText);
    }
  }

  void updateHighlightedRanges(List<TextRange> ranges) {
    highlightedRanges = List<TextRange>.unmodifiable(ranges);
    notifyListeners();
  }

  void setLayoutWidth(double width) {
    layoutWidth = width;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (block.ops.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final spans = <InlineSpan>[];
    final baseStyle = style ?? const TextStyle();
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final linkBoxes = _computeLinkBoxes(baseStyle, direction);
    int offset = 0;

    for (final op in block.ops) {
      final opStyle = _buildTextStyle(op.attrs, baseStyle);
      final opText = op.insert;
      final opStart = offset;
      final opEnd = opStart + opText.length;
      final opRanges =
          highlightedRanges
              .where((range) => range.start < opEnd && range.end > opStart)
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));

      if (opRanges.isEmpty) {
        spans.addAll(_buildTextSpans(text: opText, style: opStyle));
      } else {
        int cursor = 0;
        for (final range in opRanges) {
          final localStart = (range.start - opStart).clamp(0, opText.length);
          final localEnd = (range.end - opStart).clamp(0, opText.length);
          if (localStart > cursor) {
            spans.addAll(
              _buildTextSpans(
                text: opText.substring(cursor, localStart),
                style: opStyle,
              ),
            );
          }
          if (localEnd > localStart) {
            final linkedText = opText.substring(localStart, localEnd);
            final box = linkBoxes[_rangeKey(range)];
            spans.addAll(
              _buildTextSpans(
                text: linkedText,
                style: _buildLinkedTextStyle(opStyle, linkedText, box: box),
              ),
            );
          }
          cursor = localEnd;
        }
        if (cursor < opText.length) {
          spans.addAll(
            _buildTextSpans(text: opText.substring(cursor), style: opStyle),
          );
        }
      }
      offset = opEnd;
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  Map<String, Rect> _computeLinkBoxes(
    TextStyle baseStyle,
    TextDirection textDirection,
  ) {
    final width = layoutWidth;
    if (width == null ||
        width <= 0 ||
        highlightedRanges.isEmpty ||
        text.isEmpty) {
      return const {};
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textDirection: textDirection,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    )..layout(maxWidth: width);

    final boxes = <String, Rect>{};
    for (final range in highlightedRanges) {
      final start = range.start.clamp(0, text.length);
      final end = range.end.clamp(start, text.length);
      if (start >= end) continue;

      final textBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      if (textBoxes.isEmpty) continue;

      double left = textBoxes.first.left;
      double top = textBoxes.first.top;
      double right = textBoxes.first.right;
      double bottom = textBoxes.first.bottom;

      for (final textBox in textBoxes.skip(1)) {
        left = math.min(left, textBox.left);
        top = math.min(top, textBox.top);
        right = math.max(right, textBox.right);
        bottom = math.max(bottom, textBox.bottom);
      }

      boxes[_rangeKey(range)] = Rect.fromLTRB(left, top, right, bottom);
    }

    return boxes;
  }

  String _rangeKey(TextRange range) => '${range.start}:${range.end}';

  List<InlineSpan> _buildTextSpans({
    required String text,
    required TextStyle style,
  }) {
    return JournalBadgeSpanBuilder.build(
      text: text,
      style: style,
      expansionState: _badgeExpansion,
      onToggle: (id, expanded) {
        onBadgeToggled(id, expanded);
        onExternalBadgeToggle?.call(id, expanded);
      },
      compact: true,
      renderBadgesInline: false,
    );
  }

  void _debugLogValueChange(
    String where,
    TextEditingValue oldValue,
    TextEditingValue incoming,
    TextEditingValue protected,
  ) {
    final hasOld = oldValue.text.contains('⟦EVENT_BADGE');
    final hasIncoming = incoming.text.contains('⟦EVENT_BADGE');
    final hasProtected = protected.text.contains('⟦EVENT_BADGE');
    debugPrint(
      '[badge-debug][$where] old=${oldValue.text.length} incoming=${incoming.text.length} protected=${protected.text.length} | tokens old=$hasOld incoming=$hasIncoming protected=$hasProtected',
    );
  }

  TextStyle _buildTextStyle(TextAttrs? attrs, TextStyle? baseStyle) {
    if (attrs == null) return baseStyle ?? const TextStyle();

    final decorations = <TextDecoration>[];
    if (attrs.underline) decorations.add(TextDecoration.underline);
    if (attrs.strikethrough) decorations.add(TextDecoration.lineThrough);

    return (baseStyle ?? const TextStyle()).copyWith(
      fontWeight: attrs.bold ? FontWeight.bold : null,
      fontStyle: attrs.italic ? FontStyle.italic : null,
      backgroundColor: attrs.backgroundColor != null
          ? _parseColor(attrs.backgroundColor!)
          : null,
      color: attrs.color != null ? _parseColor(attrs.color!) : null,
      decoration: decorations.isEmpty
          ? TextDecoration.none
          : decorations.length == 1
          ? decorations.first
          : TextDecoration.combine(decorations),
      decorationColor: Colors.white,
      decorationThickness: 2.0,
    );
  }

  TextStyle _buildLinkedTextStyle(
    TextStyle baseStyle,
    String text, {
    Rect? box,
  }) {
    final fontSize = baseStyle.fontSize ?? 16.0;
    final shaderRect = box == null
        ? null
        : Rect.fromLTWH(
            box.left,
            box.top,
            math.max(box.width, fontSize),
            math.max(box.height, fontSize * 1.4),
          );
    return InsightLinkTextStyle.textSpanStyle(
      baseStyle,
      text,
      shaderRect: shaderRect,
    );
  }

  Color _parseColor(String value) {
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final intColor = int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
    return Color(intColor);
  }
}

class _BadgeProtectingFormatter extends TextInputFormatter {
  List<TextRange> _findBadgeRanges(String text) {
    final regex = RegExp(r'⟦EVENT_BADGE([^⟧]+)⟧');
    return regex
        .allMatches(text)
        .map((m) => TextRange(start: m.start, end: m.end))
        .toList();
  }

  TextSelection _clampSelectionOutsideBadges(
    List<TextRange> ranges,
    TextSelection selection,
  ) {
    var sel = selection;
    for (final r in ranges) {
      if (sel.start > r.start && sel.start < r.end) {
        sel = sel.copyWith(baseOffset: r.end, extentOffset: r.end);
      }
      if (sel.end > r.start && sel.end < r.end) {
        sel = sel.copyWith(baseOffset: sel.baseOffset, extentOffset: r.end);
      }
    }
    return sel;
  }

  TextRange _clampRangeOutsideBadges(List<TextRange> ranges, TextRange range) {
    var res = range;
    for (final r in ranges) {
      if (res.start > r.start && res.start < r.end) {
        res = TextRange(start: r.end, end: r.end);
      }
      if (res.end > r.start && res.end < r.end) {
        res = TextRange(start: res.start, end: r.end);
      }
    }
    return res;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (oldText.isEmpty || oldText == newText) {
      return newValue;
    }

    final oldRanges = _findBadgeRanges(oldText);
    if (oldRanges.isEmpty) return newValue;

    final newRanges = _findBadgeRanges(newText);

    // Reject if badge count changes (corruption protection)
    if (oldRanges.length != newRanges.length) {
      return oldValue;
    }

    // Just clamp selection/composing outside badge ranges - NO REROUTE
    final clampedSel = _clampSelectionOutsideBadges(
      newRanges,
      newValue.selection,
    );
    final clampedComp = _clampRangeOutsideBadges(newRanges, newValue.composing);

    return newValue.copyWith(
      selection: clampedSel,
      composing: clampedComp.isValid ? clampedComp : TextRange.empty,
    );
  }
}

/// Rich text editor with visual formatting
class RichTextEditor extends StatefulWidget {
  final ParagraphBlock initialBlock;
  final Function(ParagraphBlock) onChanged;
  final TextAttrs currentAttrs;
  final ValueChanged<bool>? onBadgeExpansionChanged;
  final bool readOnly;
  final List<TextRange> highlightedRanges;
  final List<InsightLink> insightLinks;
  final ValueChanged<InsightLink>? onInsightLinkTap;

  const RichTextEditor({
    super.key,
    required this.initialBlock,
    required this.onChanged,
    this.currentAttrs = const TextAttrs(),
    this.onBadgeExpansionChanged,
    this.readOnly = false,
    this.highlightedRanges = const [],
    this.insightLinks = const [],
    this.onInsightLinkTap,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  static const Duration _boundaryLinkTapWindow = Duration(milliseconds: 700);

  late _FormattedTextEditingController _controller;
  late FocusNode _focusNode;
  ParagraphBlock _currentBlock = ParagraphBlock(id: '', ops: []);
  bool _isUpdating = false;
  late final List<TextInputFormatter> _formatters;
  bool _badgeExpanded = false;
  final ScrollController _textScrollController = ScrollController();
  final ScrollController _readScrollController = ScrollController();
  TextSelection? _savedSelection;
  TextSelection? _lastNonCollapsedSelection;
  double? _savedTextScrollOffset;
  String? _armedBoundaryLinkId;
  DateTime? _armedBoundaryLinkAt;

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.initialBlock;
    _controller = _FormattedTextEditingController(
      block: _currentBlock,
      highlightedRanges: widget.highlightedRanges,
      onExternalBadgeToggle: _handleBadgeToggle,
    );
    _focusNode = FocusNode();
    _formatters = [_BadgeProtectingFormatter()];
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBlock != widget.initialBlock) {
      setState(() {
        _currentBlock = widget.initialBlock;
        _controller.updateBlock(_currentBlock);
      });
    }
    if (!_rangesEqual(oldWidget.highlightedRanges, widget.highlightedRanges)) {
      _controller.updateHighlightedRanges(widget.highlightedRanges);
    }
    if (_armedBoundaryLinkId != null &&
        !widget.insightLinks.any((link) => link.id == _armedBoundaryLinkId)) {
      _clearArmedBoundaryLink();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _textScrollController.dispose();
    _readScrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TextSelection get currentSelection {
    final selection = _controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      return selection;
    }
    return _lastNonCollapsedSelection ?? selection;
  }

  String get currentText => _controller.text;

  void _handleControllerChanged() {
    final selection = _controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      _lastNonCollapsedSelection = selection;
      _clearArmedBoundaryLink();
    }
  }

  bool _rangesEqual(List<TextRange> a, List<TextRange> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) {
        return false;
      }
    }
    return true;
  }

  /// Apply formatting to current selection
  void applyFormat(TextAttrs attrs) {
    final selection = _controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      return;
    }

    final start = selection.start;
    final end = selection.end;

    // Build new ops with formatting
    final newOps = <TextOp>[];
    int currentPos = 0;

    for (final op in _currentBlock.ops) {
      final opEnd = currentPos + op.insert.length;

      if (opEnd <= start || currentPos >= end) {
        // Outside selection
        newOps.add(op);
      } else if (currentPos >= start && opEnd <= end) {
        // Fully inside selection
        newOps.add(TextOp(insert: op.insert, attrs: attrs));
      } else {
        // Partially overlaps
        if (currentPos < start) {
          final beforeText = op.insert.substring(0, start - currentPos);
          newOps.add(TextOp(insert: beforeText, attrs: op.attrs));
        }

        final insideStart = start > currentPos ? start - currentPos : 0;
        final insideEnd = end < opEnd ? end - currentPos : op.insert.length;
        final insideText = op.insert.substring(insideStart, insideEnd);
        newOps.add(TextOp(insert: insideText, attrs: attrs));

        if (opEnd > end) {
          final afterText = op.insert.substring(end - currentPos);
          newOps.add(TextOp(insert: afterText, attrs: op.attrs));
        }
      }

      currentPos = opEnd;
    }

    final optimizedOps = _optimizeOps(newOps);
    if (_opsEqual(_currentBlock.ops, optimizedOps)) {
      return; // No change; avoid stacking duplicate formatting operations
    }
    final newBlock = ParagraphBlock(id: _currentBlock.id, ops: optimizedOps);

    setState(() {
      _currentBlock = newBlock;
      _controller.updateBlock(newBlock);
    });

    widget.onChanged(newBlock);
  }

  List<TextOp> _optimizeOps(List<TextOp> ops) {
    if (ops.length <= 1) return ops;

    final optimized = <TextOp>[];
    TextOp? current;

    for (final op in ops) {
      if (current == null) {
        current = op;
      } else if (_attrsEqual(current.attrs, op.attrs)) {
        current = TextOp(
          insert: current.insert + op.insert,
          attrs: current.attrs,
        );
      } else {
        optimized.add(current);
        current = op;
      }
    }

    if (current != null) optimized.add(current);
    return optimized;
  }

  bool _attrsEqual(TextAttrs? a, TextAttrs? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.bold == b.bold &&
        a.italic == b.italic &&
        a.underline == b.underline &&
        a.strikethrough == b.strikethrough &&
        a.color == b.color &&
        a.backgroundColor == b.backgroundColor;
  }

  bool _opsEqual(List<TextOp> a, List<TextOp> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].insert != b[i].insert) return false;
      if (!_attrsEqual(a[i].attrs, b[i].attrs)) return false;
    }
    return true;
  }

  void _handleTextChanged(String text) {
    if (_isUpdating) return;
    _clearArmedBoundaryLink();

    // Convert to single op (formatting happens via toolbar)
    final newBlock = ParagraphBlock(
      id: _currentBlock.id,
      ops: [TextOp(insert: text.isEmpty ? '\n' : text)],
    );

    _isUpdating = true;
    setState(() {
      _currentBlock = newBlock;
      _controller.updateBlock(newBlock);
    });
    _isUpdating = false;

    widget.onChanged(newBlock);
  }

  void _handleBadgeToggle(String badgeId, bool expanded) {
    _controller.onBadgeToggled(badgeId, expanded);
    final anyExpanded = _controller.anyBadgeExpanded;
    if (_badgeExpanded != anyExpanded) {
      if (anyExpanded) {
        // Preserve caret and scroll before switching to read-only view
        _savedSelection = _controller.selection;
        if (_textScrollController.hasClients) {
          _savedTextScrollOffset = _textScrollController.offset;
        }
      }
      setState(() => _badgeExpanded = anyExpanded);
      widget.onBadgeExpansionChanged?.call(anyExpanded);
      if (anyExpanded) {
        _focusNode.unfocus();
      }
    }
  }

  void _clearArmedBoundaryLink() {
    _armedBoundaryLinkId = null;
    _armedBoundaryLinkAt = null;
  }

  bool _shouldActivateBoundaryLink(InsightLink link, DateTime now) {
    final armedAt = _armedBoundaryLinkAt;
    return _armedBoundaryLinkId == link.id &&
        armedAt != null &&
        now.difference(armedAt) <= _boundaryLinkTapWindow;
  }

  void _handleEditableTap() {
    if (widget.onInsightLinkTap == null || widget.insightLinks.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selection = _controller.selection;
      if (!selection.isValid || !selection.isCollapsed) {
        _clearArmedBoundaryLink();
        return;
      }

      final exactLink = findInsightLinkAtOffset(
        links: widget.insightLinks,
        offset: selection.extentOffset,
      );
      if (exactLink != null) {
        _clearArmedBoundaryLink();
        FocusManager.instance.primaryFocus?.unfocus();
        widget.onInsightLinkTap?.call(exactLink);
        return;
      }

      final boundaryLink = findInsightLinkEndingAtOffset(
        links: widget.insightLinks,
        offset: selection.extentOffset,
      );
      if (boundaryLink == null) {
        _clearArmedBoundaryLink();
        return;
      }

      final now = DateTime.now();
      if (_shouldActivateBoundaryLink(boundaryLink, now)) {
        _clearArmedBoundaryLink();
        FocusManager.instance.primaryFocus?.unfocus();
        widget.onInsightLinkTap?.call(boundaryLink);
        return;
      }

      _armedBoundaryLinkId = boundaryLink.id;
      _armedBoundaryLinkAt = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final showReadOnly = widget.readOnly || _badgeExpanded;

    if (!showReadOnly) {
      final savedSelection = _savedSelection;
      final savedTextScrollOffset = _savedTextScrollOffset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (savedSelection != null) {
          final textLength = _controller.text.length;
          final restoredSelection = TextSelection(
            baseOffset: savedSelection.baseOffset.clamp(0, textLength).toInt(),
            extentOffset: savedSelection.extentOffset
                .clamp(0, textLength)
                .toInt(),
            affinity: savedSelection.affinity,
            isDirectional: savedSelection.isDirectional,
          );
          if (_controller.selection != restoredSelection) {
            _controller.selection = restoredSelection;
          }
          _savedSelection = null;
        }
        if (savedTextScrollOffset != null && _textScrollController.hasClients) {
          final max = _textScrollController.position.maxScrollExtent;
          final target = savedTextScrollOffset.clamp(0, max).toDouble();
          _textScrollController.jumpTo(target);
          _savedTextScrollOffset = null;
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _controller.setLayoutWidth(constraints.maxWidth);
        if (showReadOnly) {
          return _buildReadOnlyView(constraints);
        }
        return _buildEditableView(bottomInset);
      },
    );
  }

  Widget _buildEditableView(double bottomInset) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      scrollController: _textScrollController,
      readOnly: widget.readOnly,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      scrollPhysics: const BouncingScrollPhysics(),
      scrollPadding: EdgeInsets.only(bottom: bottomInset + 32),
      enableInteractiveSelection: !widget.readOnly,
      onTapAlwaysCalled: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      inputFormatters: _formatters,
      cursorColor: KemeticGold.base,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Write your day…',
        hintStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
      ),
      onTap: _handleEditableTap,
      onChanged: _handleTextChanged,
    );
  }

  Widget _buildReadOnlyView(BoxConstraints constraints) {
    final baseStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.5,
    );

    final spans = <InlineSpan>[];
    for (final op in _currentBlock.ops) {
      spans.addAll(
        JournalBadgeSpanBuilder.build(
          text: op.insert,
          style: baseStyle,
          expansionState: _controller.badgeExpansion,
          onToggle: _handleBadgeToggle,
          compact: false,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_savedTextScrollOffset != null && _readScrollController.hasClients) {
        final max = _readScrollController.position.maxScrollExtent;
        final target = _savedTextScrollOffset!.clamp(0, max).toDouble();
        _readScrollController.jumpTo(target);
      }
    });

    return SingleChildScrollView(
      controller: _readScrollController,
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        ),
        child: IntrinsicHeight(
          child: RichText(
            text: TextSpan(style: baseStyle, children: spans),
          ),
        ),
      ),
    );
  }
}
