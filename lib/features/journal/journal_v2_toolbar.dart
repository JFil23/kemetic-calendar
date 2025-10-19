import 'package:flutter/material.dart';
import '../../core/feature_flags.dart';
import 'journal_controller.dart';
import 'journal_v2_document_model.dart';

/// Editor modes for Journal V2
enum JournalV2Mode {
  type,      // Rich text editing
  draw,      // Pen drawing
  highlight, // Highlighter
}

/// Journal V2 Toolbar Widget
class JournalV2Toolbar extends StatefulWidget {
  final JournalController controller;
  final Function(JournalV2Mode) onModeChanged;
  final Function(TextAttrs) onFormatChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onInsertChart;
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
    this.canUndo = false,
    this.canRedo = false,
  }) : super(key: key);

  @override
  State<JournalV2Toolbar> createState() => _JournalV2ToolbarState();
}

class _JournalV2ToolbarState extends State<JournalV2Toolbar> {
  JournalV2Mode _currentMode = JournalV2Mode.type;
  TextAttrs _currentAttrs = const TextAttrs();
  DateTime? _lastSaved;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Listen to controller changes for save status
    widget.controller.onDraftChanged = _onDraftChanged;
  }

  void _onDraftChanged() {
    if (mounted) {
      setState(() {
        _lastSaved = DateTime.now();
        _isSaving = false;
      });
    }
  }

  void _changeMode(JournalV2Mode mode) {
    if (_currentMode == mode) return;
    setState(() => _currentMode = mode);
    widget.onModeChanged(mode);
  }

  void _toggleFormat(String format) {
    final bool currentValue;
    switch (format) {
      case 'bold':
        currentValue = _currentAttrs.bold;
        break;
      case 'italic':
        currentValue = _currentAttrs.italic;
        break;
      case 'underline':
        currentValue = _currentAttrs.underline;
        break;
      case 'strikethrough':
        currentValue = _currentAttrs.strikethrough;
        break;
      default:
        return;
    }
    
    // Now toggle the value
    final TextAttrs newAttrs;
    switch (format) {
      case 'bold':
        newAttrs = _currentAttrs.copyWith(bold: !currentValue);
        break;
      case 'italic':
        newAttrs = _currentAttrs.copyWith(italic: !currentValue);
        break;
      case 'underline':
        newAttrs = _currentAttrs.copyWith(underline: !currentValue);
        break;
      case 'strikethrough':
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
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode selector row
          if (FeatureFlags.hasDrawing || FeatureFlags.hasRichText)
            _buildModeSelector(),
          
          // Format buttons row (only in Type mode with rich text enabled)
          if (_currentMode == JournalV2Mode.type && FeatureFlags.hasRichText)
            _buildFormatBar(),
          
          // Status bar
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Type mode
          _buildModeButton(
            mode: JournalV2Mode.type,
            icon: Icons.text_fields,
            label: 'Type',
          ),
          const SizedBox(width: 8),
          
          // Draw mode
          if (FeatureFlags.hasDrawing)
            _buildModeButton(
              mode: JournalV2Mode.draw,
              icon: Icons.brush,
              label: 'Draw',
            ),
          const SizedBox(width: 8),
          
          // Highlight mode
          if (FeatureFlags.hasDrawing)
            _buildModeButton(
              mode: JournalV2Mode.highlight,
              icon: Icons.highlight,
              label: 'Highlight',
            ),
          
          const Spacer(),
          
          // Undo/Redo (only show if feature enabled)
          if (FeatureFlags.hasRichText) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              color: widget.canUndo ? const Color(0xFFD4AF37) : const Color(0xFF666666),
              onPressed: widget.canUndo ? widget.onUndo : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              color: widget.canRedo ? const Color(0xFFD4AF37) : const Color(0xFF666666),
              onPressed: widget.canRedo ? widget.onRedo : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required JournalV2Mode mode,
    required IconData icon,
    required String label,
  }) {
    final isActive = _currentMode == mode;
    
    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFFD4AF37).withOpacity(0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: const Color(0xFFD4AF37), width: 2)
              : Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF999999),
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

  Widget _buildFormatBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFormatButton('B', 'bold', _currentAttrs.bold),
          const SizedBox(width: 8),
          _buildFormatButton('I', 'italic', _currentAttrs.italic, italic: true),
          const SizedBox(width: 8),
          _buildFormatButton('U', 'underline', _currentAttrs.underline, underline: true),
          const SizedBox(width: 8),
          _buildFormatButton('S', 'strikethrough', _currentAttrs.strikethrough, strikethrough: true),
          
          const Spacer(),
          
          // Insert chart button
          if (FeatureFlags.hasCharts)
            TextButton.icon(
              onPressed: widget.onInsertChart,
              icon: const Icon(Icons.insert_chart, size: 18, color: Color(0xFFD4AF37)),
              label: const Text(
                'Chart',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(
    String label,
    String format,
    bool isActive, {
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
  }) {
    return GestureDetector(
      onTap: () => _toggleFormat(format),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFFD4AF37).withOpacity(0.2) 
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: const Color(0xFFD4AF37), width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF999999),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline 
                  ? TextDecoration.underline 
                  : (strikethrough ? TextDecoration.lineThrough : TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (_isSaving)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF666666)),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Saving…',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else if (_lastSaved != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF666666)),
                const SizedBox(width: 6),
                Text(
                  'Saved • ${_formatTime(_lastSaved!)}',
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
