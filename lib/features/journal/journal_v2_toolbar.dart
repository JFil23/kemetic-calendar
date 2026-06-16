// lib/features/journal/journal_v2_toolbar.dart
// Journal V2 Toolbar - Fixed for ScrollView

import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../calendar/calendar_page.dart' show KemeticMath;
import '../calendar/kemetic_month_metadata.dart' show getMonthById;
import 'journal_controller.dart';
import 'journal_skin_tokens.dart';
import 'journal_v2_document_model.dart';

enum JournalV2Mode { type, draw }

class JournalV2Toolbar extends StatefulWidget {
  final JournalController controller;
  final Function(JournalV2Mode) onModeChanged;
  final Function(TextAttrs) onFormatChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onInsertChart;
  final bool canUndo;
  final bool canRedo;
  final bool compact;
  final bool journalPageSkin;

  const JournalV2Toolbar({
    super.key,
    required this.controller,
    required this.onModeChanged,
    required this.onFormatChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onInsertChart,
    this.canUndo = false,
    this.canRedo = false,
    this.compact = false,
    this.journalPageSkin = false,
  });

  @override
  State<JournalV2Toolbar> createState() => _JournalV2ToolbarState();
}

class _JournalV2ToolbarState extends State<JournalV2Toolbar> {
  TextAttrs _currentAttrs = const TextAttrs();
  bool _showKemetic = true; // default to Kemetic view for date tracker

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
      default:
        return;
    }

    setState(() => _currentAttrs = newAttrs);
    widget.onFormatChanged(newAttrs);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.journalPageSkin) {
      return _buildJournalPageSkinToolbar();
    }

    final now = DateTime.now();
    final dateLabel = _showKemetic
        ? _formatKemetic(now)
        : _formatGregorian(now);
    final dateToggleMinHeight = expandedTouchTargetMinDimension(
      context,
      fallback: 0,
    );

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: _buildFormatButtonsRow(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current day tracker (toggle Kemetic/Gregorian on tap)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _showKemetic = !_showKemetic);
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: dateToggleMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dateLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFC8CCD2), // silver like decan labels
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Format buttons row
          const SizedBox(height: 8),
          _buildFormatButtonsRow(),

          // Status bar with undo/redo
          const SizedBox(height: 8),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildJournalPageSkinToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildJournalSkinFormatButton(
              'B',
              'bold',
              _currentAttrs.bold,
              bold: true,
            ),
            const SizedBox(width: 18),
            _buildJournalSkinFormatButton(
              'I',
              'italic',
              _currentAttrs.italic,
              italic: true,
            ),
            const SizedBox(width: 18),
            _buildJournalSkinFormatButton(
              'U',
              'underline',
              _currentAttrs.underline,
              underline: true,
            ),
            const SizedBox(width: 18),
            _buildJournalSkinFormatButton(
              'S',
              'strikethrough',
              _currentAttrs.strikethrough,
              strikethrough: true,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildJournalSkinUndoRedoButton(
              icon: Icons.undo,
              tooltip: 'Undo',
              enabled: widget.canUndo,
              onPressed: widget.onUndo,
            ),
            const SizedBox(width: 16),
            _buildJournalSkinUndoRedoButton(
              icon: Icons.redo,
              tooltip: 'Redo',
              enabled: widget.canRedo,
              onPressed: widget.onRedo,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJournalSkinFormatButton(
    String label,
    String format,
    bool isActive, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
  }) {
    final color = isActive
        ? JournalSkinTokens.goldSoft
        : JournalSkinTokens.silverMid;
    return TextButton(
      onPressed: () => _toggleFormat(format),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(Size(24, 30)),
        fixedSize: const WidgetStatePropertyAll(Size(24, 30)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return JournalSkinTokens.goldSoft;
          }
          return color;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return JournalSkinTokens.goldSoft.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return JournalSkinTokens.goldSoft.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      child: Text(
        label,
        style: JournalSkinTokens.formatButtonStyle.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          decoration: underline
              ? TextDecoration.underline
              : strikethrough
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          decorationColor: color,
          decorationThickness: 1.2,
        ),
      ),
    );
  }

  Widget _buildJournalSkinUndoRedoButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final color = enabled
        ? JournalSkinTokens.silverMid
        : JournalSkinTokens.silverLo;
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      iconSize: 19,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 30),
      visualDensity: VisualDensity.compact,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return JournalSkinTokens.silverLo;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return JournalSkinTokens.goldSoft;
          }
          return JournalSkinTokens.silverMid;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return Colors.transparent;
          if (states.contains(WidgetState.focused)) {
            return JournalSkinTokens.goldSoft.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return JournalSkinTokens.goldSoft.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      icon: Icon(icon, color: color),
    );
  }

  Widget _buildFormatButtonsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFormatButton('B', 'bold', _currentAttrs.bold, bold: true),
        const SizedBox(width: 4),
        _buildFormatButton('I', 'italic', _currentAttrs.italic, italic: true),
        const SizedBox(width: 4),
        _buildFormatButton(
          'U',
          'underline',
          _currentAttrs.underline,
          underline: true,
        ),
        const SizedBox(width: 4),
        _buildFormatButton(
          'S',
          'strikethrough',
          _currentAttrs.strikethrough,
          strikethrough: true,
        ),
      ],
    );
  }

  String _formatKemetic(DateTime g) {
    final k = KemeticMath.fromGregorian(g);
    final month = getMonthById(k.kMonth).displayFull;
    return '$month ${k.kDay}';
  }

  String _formatGregorian(DateTime g) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[g.month - 1];
    return '$month ${g.day}';
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
    final buttonSize = expandedTouchTargetMinDimension(context, fallback: 40);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleFormat(format),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF333333) : Colors.transparent,
          border: Border.all(
            color: isActive ? KemeticGold.base : const Color(0xFF666666),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? KemeticGold.base : const Color(0xFF999999),
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline
                  ? TextDecoration.underline
                  : strikethrough
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationColor: isActive
                  ? KemeticGold.base
                  : const Color(0xFF999999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
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
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 6),
          Text(
            'Saved • $hour:$minute $period',
            style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
          ),
          const SizedBox(width: 24),
          // Undo/Redo buttons - now more prominent
          _buildUndoRedoButtons(),
        ],
      ),
    );
  }

  Widget _buildUndoRedoButtons() {
    final buttonPadding = useExpandedTouchTargets(context)
        ? const EdgeInsets.all(12)
        : const EdgeInsets.all(6);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.canUndo
                  ? KemeticGold.base
                  : const Color(0xFF444444),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.canUndo ? widget.onUndo : null,
              borderRadius: BorderRadius.circular(6),
              child: withMinimumTouchTarget(
                context,
                Padding(
                  padding: buttonPadding,
                  child: Icon(
                    Icons.undo,
                    color: widget.canUndo
                        ? KemeticGold.base
                        : const Color(0xFF666666),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.canRedo
                  ? KemeticGold.base
                  : const Color(0xFF444444),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.canRedo ? widget.onRedo : null,
              borderRadius: BorderRadius.circular(6),
              child: withMinimumTouchTarget(
                context,
                Padding(
                  padding: buttonPadding,
                  child: Icon(
                    Icons.redo,
                    color: widget.canRedo
                        ? KemeticGold.base
                        : const Color(0xFF666666),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
