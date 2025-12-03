// lib/features/journal/journal_overlay.dart
// FIXES: 1) Toolbar overflow, 2) Layered coexistence, 3) Drawing undo

import 'package:flutter/material.dart';
import 'journal_controller.dart';
import 'journal_constants.dart';
import '../../core/feature_flags.dart';
import 'journal_v2_toolbar.dart';
import 'journal_v2_document_model.dart';
import 'journal_v2_rich_text.dart';
import 'journal_undo_system.dart';
import 'journal_archive_page.dart';
import '../../data/journal_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'journal_event_badge.dart';
import 'journal_badge_utils.dart';

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

  // V2 state
  bool _showToolbar = false;
  TextAttrs _currentAttrs = const TextAttrs();
  GlobalKey<RichTextEditorState>? _richTextEditorKey;
  final Map<String, bool> _badgeExpansion = {};
  
  // Archive state
  bool _showingArchive = false;
  bool _keyboardVisible = false;
  
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
      _showToolbar = FeatureFlags.hasRichText;
      
      if (FeatureFlags.hasRichText) {
        _richTextEditorKey = GlobalKey<RichTextEditorState>();
      }
    }

    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
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
    // Type is the only mode; keep focus on text when requested.
    if (mode == JournalV2Mode.type) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
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
      });
    }
  }

  void _onInsertChart() {
    // Not implemented yet
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

  void _onPanUpdate(DragUpdateDetails details) {
    if (_focusNode.hasFocus || _keyboardVisible) return;
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
    if (_focusNode.hasFocus || _keyboardVisible) return;
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
    _keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
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
                      if (_showToolbar) _buildToolbar(),
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
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Journal',
              style: TextStyle(
                color: const Color(0xFFD4AF37),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFFD4AF37)),
            onPressed: _openArchive,
            tooltip: 'View archive',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFD4AF37)),
            onPressed: () async {
              await widget.controller.clearToday();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cleared today\'s journal'),
                    backgroundColor: Color(0xFFD4AF37),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Clear today',
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
          canUndo: _undoSystem.canUndo,
          canRedo: _undoSystem.canRedo,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Text area (take remaining space)
          Expanded(
            child: AnimatedPadding(
              padding: EdgeInsets.only(
                bottom: bottomInset,
              ),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 160),
                child: _buildTextLayer(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Badge area (replaces drawing canvas)
          _buildBadgeArea(keyboardVisible),
        ],
      ),
    );
  }

  Widget _buildTextLayer() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
      scrollPadding: EdgeInsets.only(bottom: bottomInset + 32),
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      scrollPhysics: const BouncingScrollPhysics(),
      enableInteractiveSelection: true,
      onChanged: _handleTextChanged,
    );
  }

  List<EventBadgeToken> _extractBadges() {
    final doc = widget.controller.currentDocument;
    if (doc == null) return [];

    return JournalBadgeUtils.tokensFromDocument(doc);
  }

  Widget _buildBadgeArea(bool keyboardVisible) {
    final badges = _extractBadges();
    final height = keyboardVisible ? 0.0 : 220.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      child: height == 0
          ? const SizedBox.shrink()
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                ),
                child: badges.isEmpty
                    ? const Center(
                        child: Text(
                          'No badges yet',
                          style: TextStyle(color: Color(0xFF666666)),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: badges.map((token) {
                              final expanded = _badgeExpansion[token.id] ?? false;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: EventBadgeWidget(
                                  token: token,
                                  initialExpanded: expanded,
                                  onToggle: (next) {
                                    setState(() {
                                      _badgeExpansion[token.id] = next;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
    );
  }
}
