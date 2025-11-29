// lib/features/journal/journal_v2_toolbar.dart
// Journal V2 Toolbar - Fixed for ScrollView

import 'package:flutter/material.dart';
import 'journal_controller.dart';
import 'journal_v2_document_model.dart';

enum JournalV2Mode { type, draw }

class JournalV2Toolbar extends StatefulWidget {
  final JournalController controller;
  final Function(JournalV2Mode) onModeChanged;
  final Function(TextAttrs) onFormatChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onInsertChart;
  final VoidCallback onClearDrawing;
  final bool canUndo;
  final bool canRedo;

  const JournalV2Toolbar({
    Key? key,
    required this.controller,
    required this.onModeChanged,
    required this.onFormatChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onInsertChart,
    required this.onClearDrawing,
    this.canUndo = false,
    this.canRedo = false,
  }) : super(key: key);

  @override
  State<JournalV2Toolbar> createState() => _JournalV2ToolbarState();
}

class _JournalV2ToolbarState extends State<JournalV2Toolbar> {
  JournalV2Mode _currentMode = JournalV2Mode.type;
  TextAttrs _currentAttrs = const TextAttrs();

  void _handleModeChange(JournalV2Mode mode) {
    setState(() => _currentMode = mode);
    widget.onModeChanged(mode);
  }

  void _toggleFormat(String format) {
    TextAttrs newAttrs;
    switch (format) {
      case 'bold':
        final currentValue = _currentAttrs.bold;
        newAttrs = _currentAttrs.copyWith(bold: !currentValue);
        break;
      case 'italic':
        final currentValue = _currentAttrs.italic;
        newAttrs = _currentAttrs.copyWith(italic: !currentValue);
        break;
      case 'underline':
        final currentValue = _currentAttrs.underline;
        newAttrs = _currentAttrs.copyWith(underline: !currentValue);
        break;
      case 'strikethrough':
        final currentValue = _currentAttrs.strikethrough;
        newAttrs = _currentAttrs.copyWith(strikethrough: !currentValue);
        break;
      case 'highlight':
        final isOn = _currentAttrs.backgroundColor != null;
        newAttrs = _currentAttrs.copyWith(
          backgroundColor: isOn ? null : '#FFF6A3', // soft yellow highlight
        );
        break;
      default:
        return;
    }
    
    setState(() => _currentAttrs = newAttrs);
    widget.onFormatChanged(newAttrs);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode selector row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(JournalV2Mode.type, Icons.text_fields, 'Type'),
              const SizedBox(width: 8),
              _buildModeButton(JournalV2Mode.draw, Icons.brush, 'Draw'),
            ],
          ),
          
          // Format buttons row (only in Type mode)
          if (_currentMode == JournalV2Mode.type) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormatButton('B', 'bold', _currentAttrs.bold, bold: true),
                const SizedBox(width: 4),
                _buildFormatButton('I', 'italic', _currentAttrs.italic, italic: true),
                const SizedBox(width: 4),
                _buildFormatButton('U', 'underline', _currentAttrs.underline, underline: true),
                const SizedBox(width: 4),
                _buildFormatButton('S', 'strikethrough', _currentAttrs.strikethrough, strikethrough: true),
                const SizedBox(width: 4),
                _buildFormatButton('H', 'highlight', _currentAttrs.backgroundColor != null),
              ],
            ),
          ],
          
          // Clear buttons row (only in Draw mode)
          if (_currentMode == JournalV2Mode.draw) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildClearButton('Clear Drawing', Icons.brush, widget.onClearDrawing),
              ],
            ),
          ],
          
          // Status bar with undo/redo
          const SizedBox(height: 8),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildModeButton(JournalV2Mode mode, IconData icon, String label) {
    final isActive = _currentMode == mode;
    
    return GestureDetector(
      onTap: () => _handleModeChange(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF333333) : Colors.transparent,
          border: Border.all(
            color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF666666),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF999999),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF999999),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(
    String label,
    String format,
    bool isActive, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
  }) {
    final isHighlight = format == 'highlight';
    final Color activeBg = isHighlight ? const Color(0xFFFFF6A3) : const Color(0xFF333333);
    final Color inactiveBg = isHighlight ? Colors.transparent : Colors.transparent;
    final Color borderColor = isHighlight
        ? const Color(0xFFD4AF37)
        : (isActive ? const Color(0xFFD4AF37) : const Color(0xFF666666));
    final Color textColor = isHighlight
        ? (isActive ? const Color(0xFF3A3211) : const Color(0xFFD4AF37))
        : (isActive ? const Color(0xFFD4AF37) : const Color(0xFF999999));

    return GestureDetector(
      onTap: () => _toggleFormat(format),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline
                  ? TextDecoration.underline
                  : strikethrough
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
              decorationColor: isActive ? const Color(0xFFD4AF37) : const Color(0xFF999999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: const Color(0xFF666666),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF999999),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Saved indicator
          const Icon(
            Icons.check_circle,
            color: Color(0xFF4CAF50),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Saved • $hour:$minute $period',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 24),
          // Undo/Redo buttons - now more prominent
          _buildUndoRedoButtons(),
        ],
      ),
    );
  }

  Widget _buildUndoRedoButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.canUndo ? const Color(0xFFD4AF37) : const Color(0xFF444444),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.canUndo ? widget.onUndo : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.undo,
                  color: widget.canUndo ? const Color(0xFFD4AF37) : const Color(0xFF666666),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.canRedo ? const Color(0xFFD4AF37) : const Color(0xFF444444),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.canRedo ? widget.onRedo : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.redo,
                  color: widget.canRedo ? const Color(0xFFD4AF37) : const Color(0xFF666666),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
