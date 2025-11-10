// lib/features/journal/journal_overlay.dart
// FIXES: 1) Toolbar overflow, 2) Layered coexistence, 3) Drawing undo

import 'package:flutter/material.dart';
import 'journal_controller.dart';
import 'journal_constants.dart';
import '../../core/feature_flags.dart';
import 'journal_v2_toolbar.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_rich_text.dart';
import 'journal_v2_drawing.dart';
import 'journal_undo_system.dart';
import 'journal_archive_page.dart';
import '../../data/journal_repo.dart';
import '../../data/nutrition_repo.dart';
import '../../data/user_events_repo.dart';
import '../nutrition/nutrition_grid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalOverlay extends StatefulWidget {
  final JournalController controller;
  final bool isPortrait;
  final VoidCallback onClose;

  const JournalOverlay({
    Key? key,
    required this.controller,
    required this.isPortrait,
    required this.onClose,
  }) : super(key: key);

  @override
  State<JournalOverlay> createState() => _JournalOverlayState();
}

class _JournalOverlayState extends State<JournalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late TextEditingController _textController;
  late ScrollController _scrollController;
  late FocusNode _focusNode;

  // Toggle between Journal (false) and Nutrition (true)
  bool _showNutrition = false;

  double _dragOffset = 0;

  // V2 state
  bool _showToolbar = false;
  JournalV2Mode _currentMode = JournalV2Mode.type;
  TextAttrs _currentAttrs = const TextAttrs();
  GlobalKey<RichTextEditorState>? _richTextEditorKey;
  
  // Archive state
  bool _showingArchive = false;
  DrawingBlock? _currentDrawingBlock;
  DrawingTool _currentDrawingTool = DrawingTool.pen;
  
  // Universal undo/redo system
  late JournalUndoSystem _undoSystem;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _textController = TextEditingController(text: widget.controller.currentDraft);
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    widget.controller.onDraftChanged = _onDraftChanged;

    // Journal remains default view; Nutrition toggle is user-driven

    // V2 initialization
    _undoSystem = JournalUndoSystem();
    
    if (FeatureFlags.isJournalV2Active) {
      _showToolbar = FeatureFlags.hasRichText || FeatureFlags.hasDrawing;
      
      if (FeatureFlags.hasRichText) {
        _richTextEditorKey = GlobalKey<RichTextEditorState>();
      }
      
      if (FeatureFlags.hasDrawing && widget.controller.currentDocument != null) {
        final doc = widget.controller.currentDocument!;
        final drawingBlocks = doc.blocks.whereType<DrawingBlock>();
        if (drawingBlocks.isNotEmpty) {
          _currentDrawingBlock = drawingBlocks.first;
        } else {
          _currentDrawingBlock = DrawingBlock(
            id: 'draw-${DateTime.now().millisecondsSinceEpoch}',
            strokes: [],
          );
        }
      }
    }

    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _currentMode == JournalV2Mode.type) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    widget.controller.onDraftChanged = null;
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted && !FeatureFlags.hasRichText) {
      setState(() {
        _textController.text = widget.controller.currentDraft;
      });
    }
  }

  void _handleTextChanged(String text) {
    widget.controller.updateDraft(text);
  }

  void _close() {
    _focusNode.unfocus();
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  // ARCHIVE METHODS
  void _openArchive() {
    setState(() {
      _showingArchive = true;
    });
  }

  void _closeArchive() {
    setState(() {
      _showingArchive = false;
    });
  }

  // TOOLBAR CALLBACKS

  void _onToolbarModeChanged(JournalV2Mode mode) {
    setState(() {
      _currentMode = mode;
      
      if (mode == JournalV2Mode.type) {
        // Switch to typing - request focus
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _focusNode.requestFocus();
        });
      } else {
        // Switch to drawing - unfocus keyboard
        _focusNode.unfocus();
      }
      
      if (mode == JournalV2Mode.draw) {
        _currentDrawingTool = DrawingTool.pen;
      } else if (mode == JournalV2Mode.highlight) {
        _currentDrawingTool = DrawingTool.highlighter;
      }
    });
  }

  void _onFormatChanged(TextAttrs attrs) {
    if (!FeatureFlags.hasRichText) return;
    
    setState(() => _currentAttrs = attrs);
    _richTextEditorKey?.currentState?.applyFormat(attrs);
  }

  void _onUndo() {
    if (!_undoSystem.canUndo) return;
    
    final doc = widget.controller.currentDocument;
    if (doc == null) return;
    
    final previousDoc = _undoSystem.undo(doc);
    if (previousDoc != null) {
      // Update document
      widget.controller.updateDocument(previousDoc);
      
      // Update local state
      setState(() {
        // Update text
        final paragraphBlocks = previousDoc.blocks.whereType<ParagraphBlock>();
        if (paragraphBlocks.isNotEmpty) {
          final plainText = paragraphBlocks.first.ops.map((op) => op.insert).join();
          _textController.text = plainText;
        }
        
        // Update drawing
        final drawingBlocks = previousDoc.blocks.whereType<DrawingBlock>();
        if (drawingBlocks.isNotEmpty) {
          _currentDrawingBlock = drawingBlocks.first;
        }
      });
    }
  }

  void _onRedo() {
    if (!_undoSystem.canRedo) return;
    
    final doc = widget.controller.currentDocument;
    if (doc == null) return;
    
    final nextDoc = _undoSystem.redo(doc);
    if (nextDoc != null) {
      // Update document
      widget.controller.updateDocument(nextDoc);
      
      // Update local state
      setState(() {
        // Update text
        final paragraphBlocks = nextDoc.blocks.whereType<ParagraphBlock>();
        if (paragraphBlocks.isNotEmpty) {
          final plainText = paragraphBlocks.first.ops.map((op) => op.insert).join();
          _textController.text = plainText;
        }
        
        // Update drawing
        final drawingBlocks = nextDoc.blocks.whereType<DrawingBlock>();
        if (drawingBlocks.isNotEmpty) {
          _currentDrawingBlock = drawingBlocks.first;
        }
      });
    }
  }

  void _onInsertChart() {
    // Not implemented yet
  }

  void _onClearDrawing() {
    final doc = widget.controller.currentDocument;
    if (doc == null || _currentDrawingBlock == null) return;
    
    // Record undo action
    _undoSystem.recordAction(
      type: JournalActionType.drawStroke,
      before: doc,
      after: null,
    );
    
    // Remove all pen strokes
    final remainingStrokes = _currentDrawingBlock!.strokes
        .where((stroke) => stroke.tool != 'pen')
        .toList();
    
    final newDrawingBlock = DrawingBlock(
      id: _currentDrawingBlock!.id,
      strokes: remainingStrokes,
    );
    
    setState(() {
      _currentDrawingBlock = newDrawingBlock;
    });
    
    final blocks = List<JournalBlock>.from(doc.blocks);
    final drawingIndex = blocks.indexWhere((b) => b is DrawingBlock);
    
    if (drawingIndex >= 0) {
      if (remainingStrokes.isEmpty) {
        blocks.removeAt(drawingIndex);
      } else {
        blocks[drawingIndex] = newDrawingBlock;
      }
    }
    
    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );
    
    _undoSystem.updateLastAction(newDoc);
    widget.controller.updateDocument(newDoc);
  }

  void _onClearHighlights() {
    final doc = widget.controller.currentDocument;
    if (doc == null || _currentDrawingBlock == null) return;
    
    // Record undo action
    _undoSystem.recordAction(
      type: JournalActionType.highlightStroke,
      before: doc,
      after: null,
    );
    
    // Remove all highlighter strokes
    final remainingStrokes = _currentDrawingBlock!.strokes
        .where((stroke) => stroke.tool != 'highlighter')
        .toList();
    
    final newDrawingBlock = DrawingBlock(
      id: _currentDrawingBlock!.id,
      strokes: remainingStrokes,
    );
    
    setState(() {
      _currentDrawingBlock = newDrawingBlock;
    });
    
    final blocks = List<JournalBlock>.from(doc.blocks);
    final drawingIndex = blocks.indexWhere((b) => b is DrawingBlock);
    
    if (drawingIndex >= 0) {
      if (remainingStrokes.isEmpty) {
        blocks.removeAt(drawingIndex);
      } else {
        blocks[drawingIndex] = newDrawingBlock;
      }
    }
    
    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );
    
    _undoSystem.updateLastAction(newDoc);
    widget.controller.updateDocument(newDoc);
  }

  void _onRichTextChanged(ParagraphBlock block) {
    if (!FeatureFlags.hasRichText || widget.controller.currentDocument == null) return;
    
    final doc = widget.controller.currentDocument!;
    
    // Record undo action
    _undoSystem.recordAction(
      type: JournalActionType.textEdit,
      before: doc,
      after: null, // Will be set below
    );
    
    final blocks = List<JournalBlock>.from(doc.blocks);
    
    final paragraphIndex = blocks.indexWhere((b) => b is ParagraphBlock);
    if (paragraphIndex >= 0) {
      blocks[paragraphIndex] = block;
    } else {
      blocks.insert(0, block);
    }
    
    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );
    
    // Update the undo action with the new document
    _undoSystem.updateLastAction(newDoc);
    
    widget.controller.updateDocument(newDoc);
  }

  void _onDrawingChanged(DrawingBlock block) {
    if (!FeatureFlags.hasDrawing || widget.controller.currentDocument == null) return;
    
    final doc = widget.controller.currentDocument!;
    
    // Determine action type
    final actionType = _currentMode == JournalV2Mode.highlight
        ? JournalActionType.highlightStroke
        : JournalActionType.drawStroke;
    
    // Record undo action
    _undoSystem.recordAction(
      type: actionType,
      before: doc,
      after: null, // Will be set below
    );
    
    setState(() {
      _currentDrawingBlock = block;
    });
    
    final blocks = List<JournalBlock>.from(doc.blocks);
    
    final drawingIndex = blocks.indexWhere((b) => b is DrawingBlock);
    if (drawingIndex >= 0) {
      blocks[drawingIndex] = block;
    } else {
      blocks.add(block);
    }
    
    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );
    
    // Update the undo action with the new document
    _undoSystem.updateLastAction(newDoc);
    
    widget.controller.updateDocument(newDoc);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animationController.isAnimating) return;
    
    final dx = details.delta.dx;
    
    setState(() {
      if (widget.isPortrait) {
        _dragOffset += dx;
        if (_dragOffset > 0) _dragOffset = 0;
      } else {
        _dragOffset += details.delta.dy;
        if (_dragOffset > 0) _dragOffset = 0;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.isPortrait) {
      if (_dragOffset < -50) {
        _close();
      } else {
        setState(() => _dragOffset = 0);
      }
    } else {
      if (_dragOffset < -30) {
        _close();
      } else {
        setState(() => _dragOffset = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Show archive if requested
    if (_showingArchive) {
      return JournalArchivePage(
        repo: JournalRepo(Supabase.instance.client),
        controller: widget.controller,
        isPortrait: widget.isPortrait,
        onClose: _closeArchive, // FIXED: Add callback to close archive
      );
    }
    
    return GestureDetector(
      onTap: _close,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: GestureDetector(
            onTap: () {},
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                final slideValue = _slideAnimation.value;
                final currentOffset = _dragOffset * (1 - slideValue);

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
                      // Show the journal toolbar only in Journal mode
                      if (_showToolbar && !_showNutrition) _buildToolbar(),
                      Expanded(child: _buildContent()),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Journal button
          TextButton(
            onPressed: () => setState(() => _showNutrition = false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Journal',
              style: TextStyle(
                color: !_showNutrition ? const Color(0xFFD4AF37) : Colors.white70,
                fontSize: 18,
                fontWeight: !_showNutrition ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          // Nutrition button (only if feature is enabled)
          if (FeatureFlags.hasNutrition) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _showNutrition = true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Nutrition',
                style: TextStyle(
                  color: _showNutrition ? const Color(0xFFD4AF37) : Colors.white70,
                  fontSize: 18,
                  fontWeight: _showNutrition ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFFD4AF37)),
            onPressed: _openArchive,
            tooltip: 'View archive',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
            onPressed: _close,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Returns either the Journal editor (default) or the Nutrition grid.
  Widget _buildContent() {
    if (FeatureFlags.hasNutrition && _showNutrition) {
      return NutritionGridWidget(
        repo: NutritionRepo(Supabase.instance.client),
        eventsRepo: UserEventsRepo(Supabase.instance.client),
      );
    }
    return _buildEditor(); // existing editor builder
  }

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: JournalV2Toolbar(
          controller: widget.controller,
          onModeChanged: _onToolbarModeChanged,
          onFormatChanged: _onFormatChanged,
          onUndo: _onUndo,
          onRedo: _onRedo,
          onInsertChart: _onInsertChart,
          onClearDrawing: _onClearDrawing,
          onClearHighlights: _onClearHighlights,
          canUndo: _undoSystem.canUndo,
          canRedo: _undoSystem.canRedo,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      // FIX #2: ALL content layers coexist in one Stack
      child: Stack(
        children: [
          // Layer 1: Text (bottom layer)
          if (_currentMode == JournalV2Mode.type)
            _buildTextLayer()
          else
            Opacity(
              opacity: 0.3,
              child: IgnorePointer(child: _buildTextLayer()),
            ),
          
          // Layer 2: ONE unified drawing canvas (handles ALL strokes)
          if (FeatureFlags.hasDrawing && _currentDrawingBlock != null)
            IgnorePointer(
              ignoring: _currentMode == JournalV2Mode.type,
              child: DrawingCanvas(
                key: ValueKey(_currentDrawingBlock!.id),
                initialBlock: _currentDrawingBlock!,
                onChanged: _onDrawingChanged,
                currentTool: _currentDrawingTool,
                currentColor: _currentMode == JournalV2Mode.highlight
                    ? const Color(0x88FFEB3B) // Yellow highlighter
                    : Colors.white, // White pen
                currentWidth: _currentMode == JournalV2Mode.highlight
                    ? 12.0
                    : 2.0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextLayer() {
    if (FeatureFlags.hasRichText && widget.controller.currentDocument != null) {
      final doc = widget.controller.currentDocument!;
      final paragraphBlocks = doc.blocks.whereType<ParagraphBlock>();
      final initialBlock = paragraphBlocks.isNotEmpty
          ? paragraphBlocks.first
          : ParagraphBlock(
              id: 'p-${DateTime.now().millisecondsSinceEpoch}',
              ops: [TextOp(insert: '\n')],
            );
      
      return RichTextEditor(
        key: _richTextEditorKey,
        initialBlock: initialBlock,
        onChanged: _onRichTextChanged,
        currentAttrs: _currentAttrs,
      );
    }
    
    // Plain text fallback
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
        hintStyle: TextStyle(color: Color(0xFF666666), fontSize: 16),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: _handleTextChanged,
    );
  }
}


