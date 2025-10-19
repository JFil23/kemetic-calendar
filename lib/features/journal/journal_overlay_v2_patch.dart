// ============================================================================
// JOURNAL OVERLAY V2 INTEGRATION PATCH
// ============================================================================
// FILE: lib/features/journal/journal_overlay_v2_patch.dart
// PURPOSE: Shows exact changes needed to upgrade JournalOverlay to V2
//
// INSTRUCTIONS:
// 1. Apply the changes marked with "// V2 ADD" and "// V2 REPLACE"
// 2. Keep all existing V1 functionality working
// 3. V2 features only activate when FeatureFlags.journalV2Enabled = true
// ============================================================================

// STEP 1: Add these imports to the top of journal_overlay.dart
// V2 ADD: Import V2 components
import '../../core/feature_flags.dart';
import 'journal_v2_toolbar.dart';
import 'journal_v2_document_model.dart';

// STEP 2: Add these fields to _JournalOverlayState class (after existing fields)
// V2 ADD: V2 toolbar support
JournalV2Toolbar? _toolbar;
bool _showToolbar = false;

// STEP 3: Replace the initState method with this enhanced version
// V2 REPLACE: Enhanced initState with toolbar support
@override
void initState() {
  super.initState();

  // Animation setup
  _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  _slideAnimation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeOut,
  );

  // Text editor setup
  _textController = TextEditingController(text: widget.controller.currentDraft);
  _scrollController = ScrollController();
  _focusNode = FocusNode();

  // Listen to controller changes
  widget.controller.onDraftChanged = _onDraftChanged;

  // V2 ADD: Initialize toolbar if V2 is enabled
  if (FeatureFlags.isJournalV2Active) {
    _toolbar = JournalV2Toolbar(
      controller: widget.controller,
      onModeChanged: _onToolbarModeChanged,
      onFormatChanged: _onFormatChanged,
      onUndo: _onUndo,
      onRedo: _onRedo,
      onInsertChart: _onInsertChart,
    );
    _showToolbar = FeatureFlags.hasRichText || FeatureFlags.hasDrawing || FeatureFlags.hasCharts;
  }

  // Animate in
  _animationController.forward();

  // Focus after animation
  Future.delayed(const Duration(milliseconds: 300), () {
    if (mounted) {
      _focusNode.requestFocus();
    }
  });
}

// STEP 4: Add these V2 toolbar callback methods
// V2 ADD: Toolbar mode changed
void _onToolbarModeChanged(JournalV2Mode mode) {
  setState(() {
    // Update UI based on mode
    // This will be implemented when we add the actual toolbar UI
  });
}

// V2 ADD: Format changed (B/I/U/S)
void _onFormatChanged(TextAttrs attrs) {
  if (!FeatureFlags.hasRichText) return;
  
  // This will be implemented when we add rich text editing
  // For now, just log the format change
  if (FeatureFlags.journalV2DebugMode) {
    debugPrint('[JournalV2] Format changed: $attrs');
  }
}

// V2 ADD: Undo action
void _onUndo() {
  if (!FeatureFlags.isJournalV2Active) return;
  
  // This will be implemented when we add undo/redo
  // For now, just log the undo action
  if (FeatureFlags.journalV2DebugMode) {
    debugPrint('[JournalV2] Undo requested');
  }
}

// V2 ADD: Redo action
void _onRedo() {
  if (!FeatureFlags.isJournalV2Active) return;
  
  // This will be implemented when we add undo/redo
  // For now, just log the redo action
  if (FeatureFlags.journalV2DebugMode) {
    debugPrint('[JournalV2] Redo requested');
  }
}

// V2 ADD: Insert chart
void _onInsertChart() {
  if (!FeatureFlags.hasCharts) return;
  
  // This will be implemented when we add chart insertion
  // For now, just log the chart insertion
  if (FeatureFlags.journalV2DebugMode) {
    debugPrint('[JournalV2] Chart insertion requested');
  }
}

// STEP 5: Replace the build method with this enhanced version
// V2 REPLACE: Enhanced build method with toolbar support
@override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  
  return GestureDetector(
    onTap: _close,
    child: Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black.withOpacity(0.5), // Scrim
        child: GestureDetector(
          onTap: () {}, // Prevent scrim tap from bubbling
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              final slideValue = _slideAnimation.value;
              final currentOffset = widget.isPortrait
                  ? _dragOffset * (1 - slideValue)
                  : _dragOffset * (1 - slideValue);

              return Transform.translate(
                offset: widget.isPortrait
                    ? Offset(-(1 - slideValue) * size.width + currentOffset, 0)
                    : Offset(0, -(1 - slideValue) * size.height * 0.3 + currentOffset),
                child: child,
              );
            },
            child: Align(
              alignment: widget.isPortrait
                  ? Alignment.centerLeft
                  : Alignment.topCenter,
              child: Container(
                width: widget.isPortrait
                    ? size.width * kJournalPortraitWidthFraction
                    : size.width,
                height: widget.isPortrait
                    ? size.height
                    : size.height * kJournalLandscapeHeightFraction,
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.0,
                  ),
                  borderRadius: widget.isPortrait
                      ? const BorderRadius.horizontal(right: Radius.circular(16))
                      : const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    // V2 ADD: Show toolbar if V2 is enabled
                    if (_showToolbar && _toolbar != null) _toolbar!,
                    Expanded(child: _buildEditor()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// STEP 6: Replace the _buildEditor method with this enhanced version
// V2 REPLACE: Enhanced editor with V2 support
Widget _buildEditor() {
  return Container(
    padding: const EdgeInsets.all(16),
    child: Stack(
      children: [
        // V2 ADD: Conditional rich text editor (when V2 is enabled)
        if (FeatureFlags.isJournalV2Active && FeatureFlags.hasRichText)
          _buildRichTextEditor()
        else
          _buildPlainTextEditor(),
        
        if (_highlightStart != null && _highlightEnd != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Color(kJournalHighlightColor),
              ),
            ),
          ),
      ],
    ),
  );
}

// V2 ADD: Plain text editor (V1 behavior)
Widget _buildPlainTextEditor() {
  return TextField(
    controller: _textController,
    focusNode: _focusNode,
    scrollController: _scrollController,
    maxLines: null,
    expands: true,
    textAlignVertical: TextAlignVertical.top,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.5,
    ),
    decoration: const InputDecoration(
      hintText: 'Write your day…',
      hintStyle: TextStyle(
        color: Color(0xFF666666),
        fontSize: 16,
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    onChanged: _handleTextChanged,
  );
}

// V2 ADD: Rich text editor (V2 behavior)
Widget _buildRichTextEditor() {
  // For now, use the same TextField but with enhanced styling
  // This will be replaced with a proper rich text editor in Phase 2
  return TextField(
    controller: _textController,
    focusNode: _focusNode,
    scrollController: _scrollController,
    maxLines: null,
    expands: true,
    textAlignVertical: TextAlignVertical.top,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.5,
    ),
    decoration: const InputDecoration(
      hintText: 'Write your day… (Rich Text Mode)',
      hintStyle: TextStyle(
        color: Color(0xFF666666),
        fontSize: 16,
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    onChanged: _handleTextChanged,
  );
}

// STEP 7: Update dispose method
// V2 REPLACE: Enhanced dispose with toolbar cleanup
@override
void dispose() {
  _animationController.dispose();
  _textController.dispose();
  _scrollController.dispose();
  _focusNode.dispose();
  widget.controller.onDraftChanged = null;
  // V2 ADD: Cleanup toolbar
  _toolbar = null;
  super.dispose();
}
