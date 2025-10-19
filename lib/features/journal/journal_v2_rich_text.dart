// lib/features/journal/journal_v2_rich_text.dart
// Rich text editor using custom TextEditingController for formatting

import 'package:flutter/material.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_toolbar.dart';

/// Custom controller that renders formatted text
class _FormattedTextEditingController extends TextEditingController {
  ParagraphBlock block;
  
  _FormattedTextEditingController({required this.block}) 
      : super(text: _opsToPlainText(block.ops));
  
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
    
    for (final op in block.ops) {
      spans.add(
        TextSpan(
          text: op.insert,
          style: _buildTextStyle(op.attrs, style),
        ),
      );
    }

    return TextSpan(children: spans, style: style);
  }
  
  TextStyle _buildTextStyle(TextAttrs? attrs, TextStyle? baseStyle) {
    if (attrs == null) return baseStyle ?? const TextStyle();
    
    final decorations = <TextDecoration>[];
    if (attrs.underline) decorations.add(TextDecoration.underline);
    if (attrs.strikethrough) decorations.add(TextDecoration.lineThrough);
    
    return (baseStyle ?? const TextStyle()).copyWith(
      fontWeight: attrs.bold ? FontWeight.bold : null,
      fontStyle: attrs.italic ? FontStyle.italic : null,
      decoration: decorations.isEmpty 
          ? TextDecoration.none 
          : decorations.length == 1 
              ? decorations.first 
              : TextDecoration.combine(decorations),
      decorationColor: Colors.white,
      decorationThickness: 2.0,
    );
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

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.initialBlock;
    _controller = _FormattedTextEditingController(block: _currentBlock);
    _focusNode = FocusNode();
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
        a.strikethrough == b.strikethrough;
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
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.5,
      ),
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