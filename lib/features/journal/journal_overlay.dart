import 'package:flutter/material.dart';
import 'journal_controller.dart';
import 'journal_constants.dart';
import '../../core/feature_flags.dart';
import 'journal_v2_toolbar.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_rich_text.dart';
import 'journal_v2_drawing.dart';

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

  double _dragOffset = 0;
  int? _highlightStart;
  int? _highlightEnd;

  // V2 ADDITIONS
  JournalV2Toolbar? _toolbar;
  bool _showToolbar = false;
  JournalV2Mode _currentMode = JournalV2Mode.type;
  TextAttrs _currentAttrs = const TextAttrs();
  GlobalKey<RichTextEditorState>? _richTextEditorKey;
  DrawingBlock? _currentDrawingBlock;
  DrawingTool _currentDrawingTool = DrawingTool.pen;
  Color _currentDrawingColor = Colors.white;
  double _currentDrawingWidth = 2.0;

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

    // V2: Initialize toolbar if enabled
    if (FeatureFlags.isJournalV2Active) {
      _showToolbar = FeatureFlags.hasRichText || FeatureFlags.hasDrawing || FeatureFlags.hasCharts;
      
      if (_showToolbar) {
        _toolbar = JournalV2Toolbar(
          controller: widget.controller,
          onModeChanged: _onToolbarModeChanged,
          onFormatChanged: _onFormatChanged,
          onUndo: _onUndo,
          onRedo: _onRedo,
          onInsertChart: _onInsertChart,
          canUndo: false,
          canRedo: false,
        );
      }
      
      // Initialize rich text editor key if needed
      if (FeatureFlags.hasRichText) {
        _richTextEditorKey = GlobalKey<RichTextEditorState>();
      }
      
      // Initialize drawing block if needed
      if (FeatureFlags.hasDrawing && widget.controller.currentDocument != null) {
        // Find or create drawing block
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

    // Animate in
    _animationController.forward();

    // Focus after animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
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

  // V2 TOOLBAR CALLBACKS

  void _onToolbarModeChanged(JournalV2Mode mode) {
    setState(() {
      _currentMode = mode;
      
      // Update drawing tool based on mode
      if (mode == JournalV2Mode.draw) {
        _currentDrawingTool = DrawingTool.pen;
      } else if (mode == JournalV2Mode.highlight) {
        _currentDrawingTool = DrawingTool.highlighter;
      }
    });
    
    if (FeatureFlags.journalV2DebugMode) {
      debugPrint('[JournalOverlay] Mode changed to: $mode');
    }
  }

  void _onFormatChanged(TextAttrs attrs) {
    if (!FeatureFlags.hasRichText) return;
    
    setState(() => _currentAttrs = attrs);
    
    // Apply formatting to rich text editor
    _richTextEditorKey?.currentState?.applyFormat(attrs);
    
    if (FeatureFlags.journalV2DebugMode) {
      debugPrint('[JournalOverlay] Format changed: $attrs');
    }
  }

  void _onUndo() {
    if (FeatureFlags.journalV2DebugMode) {
      debugPrint('[JournalOverlay] Undo requested (not implemented yet)');
    }
    // TODO: Implement undo in Phase 4
  }

  void _onRedo() {
    if (FeatureFlags.journalV2DebugMode) {
      debugPrint('[JournalOverlay] Redo requested (not implemented yet)');
    }
    // TODO: Implement redo in Phase 4
  }

  void _onInsertChart() {
    if (!FeatureFlags.hasCharts) return;
    
    if (FeatureFlags.journalV2DebugMode) {
      debugPrint('[JournalOverlay] Chart insertion requested (not implemented yet)');
    }
    // TODO: Implement chart wizard in Phase 3
  }

  void _onRichTextChanged(ParagraphBlock block) {
    if (!FeatureFlags.hasRichText || widget.controller.currentDocument == null) return;
    
    // Update document with new paragraph block
    final doc = widget.controller.currentDocument!;
    final blocks = List<JournalBlock>.from(doc.blocks);
    
    // Find and update the paragraph block
    final index = blocks.indexWhere((b) => b is ParagraphBlock);
    if (index >= 0) {
      blocks[index] = block;
    } else {
      blocks.insert(0, block);
    }
    
    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );
    
    widget.controller.updateDocument(newDoc);
  }

  void _onDrawingChanged(DrawingBlock block) {
    if (!FeatureFlags.hasDrawing || widget.controller.currentDocument == null) return;
    
    setState(() => _currentDrawingBlock = block);
    
    // Update document with new drawing block
    final doc = widget.controller.currentDocument!;
    final blocks = List<JournalBlock>.from(doc.blocks);
    
    // Find and update the drawing block
    final index = blocks.indexWhere((b) => b is DrawingBlock && b.id == block.id);
    if (index >= 0) {
      blocks[index] = block;
    } else {
      blocks.add(block);
    }
    
    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );
    
    widget.controller.updateDocument(newDoc);
  }

  void _close() async {
    // Save before closing
    await widget.controller.forceSave();
    
    // Animate out
    await _animationController.reverse();
    
    // Close overlay
    if (mounted) {
      widget.onClose();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (widget.isPortrait) {
        // Portrait: R→L to close
        _dragOffset += details.delta.dx;
        if (_dragOffset > 0) _dragOffset = 0;
      } else {
        // Landscape: up to close
        _dragOffset += details.delta.dy;
        if (_dragOffset > 0) _dragOffset = 0;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final threshold = widget.isPortrait
        ? kJournalPortraitCloseThreshold
        : kJournalLandscapeCloseThreshold;

    if (_dragOffset.abs() > threshold) {
      _close();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    widget.controller.onDraftChanged = null;
    _toolbar = null;
    super.dispose();
  }

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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF333333),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Journal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
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

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: _buildEditorContent(),
    );
  }

  Widget _buildEditorContent() {
    // Phase 3: Drawing mode
    if (FeatureFlags.hasDrawing && 
        (_currentMode == JournalV2Mode.draw || _currentMode == JournalV2Mode.highlight)) {
      return Stack(
        children: [
          // Show text as background
          Opacity(
            opacity: 0.3,
            child: _buildPlainTextEditor(),
          ),
          // Drawing layer on top
          if (_currentDrawingBlock != null)
            DrawingCanvas(
              initialBlock: _currentDrawingBlock!,
              onChanged: _onDrawingChanged,
              currentTool: _currentDrawingTool,
              currentColor: _currentDrawingColor,
              currentWidth: _currentDrawingWidth,
            ),
        ],
      );
    }
    
    // Phase 2: Rich text mode
    if (FeatureFlags.hasRichText && _currentMode == JournalV2Mode.type) {
      return _buildRichTextEditor();
    }
    
    // Phase 1 / V1: Plain text mode
    return _buildPlainTextEditor();
  }

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

  Widget _buildRichTextEditor() {
    if (widget.controller.currentDocument == null) {
      return _buildPlainTextEditor();
    }
    
    // Get first paragraph block from document
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
}