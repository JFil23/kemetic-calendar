// lib/features/journal/journal_v2_rich_text.dart
// Rich text editor using custom TextEditingController for formatting

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'journal_v2_document_model.dart';
import 'journal_event_badge.dart';
import 'journal_v2_toolbar.dart';

/// Custom controller that renders formatted text
class _FormattedTextEditingController extends TextEditingController {
  ParagraphBlock block;
  // Persist badge expansion state across rebuilds so toggle doesn't vanish
  final Map<String, bool> _badgeExpansion = {};

  _FormattedTextEditingController({required this.block})
      : super(text: _opsToPlainText(block.ops));

  @override
  set value(TextEditingValue newValue) {
    final protected = _protectEventBadgeTokens(super.value, newValue);
    assert(() {
      _debugLogValueChange('value.set', super.value, newValue, protected);
      return true;
    }());
    super.value = protected;
  }
  
  // helper to find badge ranges in text
  List<TextRange> _findBadgeRanges(String text) {
    final regex = RegExp(r'⟦EVENT_BADGE([\s\S]*?)⟧');
    return regex.allMatches(text).map((m) => TextRange(start: m.start, end: m.end)).toList();
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
    final selection = _clampSelectionOutsideBadges(protectedRanges, newValue.selection);
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

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _opsToPlainText(List<TextOp> ops) {
    return ops.map((op) => op.insert).join();
  }
  
  void updateBlock(ParagraphBlock newBlock) {
    block = newBlock;
    final newText = _opsToPlainText(block.ops);
    if (text != newText) {
      value = value.copyWith(text: newText);
    }
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

    for (final op in block.ops) {
      spans.addAll(_buildSpansForText(op.insert, _buildTextStyle(op.attrs, baseStyle)));
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  List<InlineSpan> _buildSpansForText(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    const startTag = '⟦EVENT_BADGE';
    const endTag = '⟧';
    int cursor = 0;

    assert(() {
      if (text.contains(startTag)) {
        debugPrint('[badge-span] building spans for text len=${text.length}');
      }
      return true;
    }());

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
        // Guard token with zero-width spaces so caret/composing never land inside,
        // and key the widget so its state (expanded/collapsed) survives rebuilds.
        final expanded = _badgeExpansion[token.id] ?? false;
        spans.add(const TextSpan(text: '\u200b', style: TextStyle(letterSpacing: 0)));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: KeyedSubtree(
            key: ValueKey('badge-${token.id}'),
            child: EventBadgeWidget(
              token: token,
              initialExpanded: expanded,
              onToggle: (next) => _badgeExpansion[token.id] = next,
            ),
          ),
        ));
        spans.add(const TextSpan(text: '\u200b', style: TextStyle(letterSpacing: 0)));
        assert(() {
          debugPrint('[badge-span] token matched id=${token.id}');
          return true;
        }());
      } else {
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
  
  void _debugLogValueChange(
    String where,
    TextEditingValue oldValue,
    TextEditingValue incoming,
    TextEditingValue protected,
  ) {
    final hasOld = oldValue.text.contains('⟦EVENT_BADGE');
    final hasIncoming = incoming.text.contains('⟦EVENT_BADGE');
    final hasProtected = protected.text.contains('⟦EVENT_BADGE');
    debugPrint('[badge-debug][$where] old=${oldValue.text.length} incoming=${incoming.text.length} protected=${protected.text.length} | tokens old=$hasOld incoming=$hasIncoming protected=$hasProtected');
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
    return regex.allMatches(text).map((m) => TextRange(start: m.start, end: m.end)).toList();
  }

  List<String> _badgeSubstrings(String text, List<TextRange> ranges) {
    return ranges.map((r) => text.substring(r.start, r.end)).toList();
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

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (oldText.isEmpty || oldText == newText) {
      return newValue;
    }

    final oldRanges = _findBadgeRanges(oldText);
    if (oldRanges.isEmpty) return newValue;

    final newRanges = _findBadgeRanges(newText);

    // If badge count or content changed, reroute the edit (don't revert, don't edit the badge).
    final oldSubs = _badgeSubstrings(oldText, oldRanges);
    final newSubs = _badgeSubstrings(newText, newRanges);
    bool badgesChanged = oldSubs.length != newSubs.length;
    if (!badgesChanged) {
      for (int i = 0; i < oldSubs.length; i++) {
        if (oldSubs[i] != newSubs[i]) {
          badgesChanged = true;
          break;
        }
      }
    }

    // Detect if caret/composing is inside a badge; if so, reroute insertion to after that badge.
    bool insideBadge = false;
    TextRange? targetBadge;
    for (final r in newRanges) {
      if ((newValue.selection.start > r.start && newValue.selection.start < r.end) ||
          (newValue.selection.end > r.start && newValue.selection.end < r.end) ||
          (newValue.composing.start > r.start && newValue.composing.start < r.end)) {
        insideBadge = true;
        targetBadge = r;
        break;
      }
    }

    if (badgesChanged || insideBadge) {
      // Compute insertion delta: text added compared to oldText.
      final delta = newText.length - oldText.length;
      String insert = '';
      if (delta > 0) {
        // naive diff: take the tail that wasn't in oldText
        final startIdx = newValue.selection.start - delta;
        if (startIdx >= 0 && startIdx + delta <= newText.length) {
          insert = newText.substring(startIdx, startIdx + delta);
        }
      }

      // Reroute: keep oldText, append insert after the badge (or at end if none).
      final badgeEnd = targetBadge?.end ?? oldText.length;
      final reroutedText = oldText.substring(0, badgeEnd) + insert + oldText.substring(badgeEnd);
      final newCaret = badgeEnd + insert.length;
      final sel = TextSelection.collapsed(offset: newCaret);
      return TextEditingValue(
        text: reroutedText,
        selection: sel,
        composing: TextRange.empty,
      );
    }

    // Clamp selection to avoid landing inside badges
    final clampedSel = _clampSelectionOutsideBadges(newRanges, newValue.selection);
    return newValue.copyWith(selection: clampedSel, composing: TextRange.empty);
  }
}

/// Rich text editor with visual formatting
class RichTextEditor extends StatefulWidget {
  final ParagraphBlock initialBlock;
  final Function(ParagraphBlock) onChanged;
  final TextAttrs currentAttrs;

  const RichTextEditor({
    Key? key,
    required this.initialBlock,
    required this.onChanged,
    this.currentAttrs = const TextAttrs(),
  }) : super(key: key);

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  late _FormattedTextEditingController _controller;
  late FocusNode _focusNode;
  ParagraphBlock _currentBlock = ParagraphBlock(id: '', ops: []);
  bool _isUpdating = false;
  late final List<TextInputFormatter> _formatters;

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.initialBlock;
    _controller = _FormattedTextEditingController(block: _currentBlock);
    _focusNode = FocusNode();
    _formatters = [_BadgeProtectingFormatter()];
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
        current = TextOp(insert: current.insert + op.insert, attrs: current.attrs);
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      scrollPhysics: const BouncingScrollPhysics(),
      scrollPadding: EdgeInsets.only(bottom: bottomInset + 32),
      enableInteractiveSelection: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.5,
      ),
      inputFormatters: _formatters,
      cursorColor: const Color(0xFFD4AF37),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Write your day…',
        hintStyle: TextStyle(
          color: Color(0xFF666666),
          fontSize: 16,
        ),
      ),
      onChanged: _handleTextChanged,
    );
  }
}
