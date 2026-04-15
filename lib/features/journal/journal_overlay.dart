// lib/features/journal/journal_overlay.dart
// FIXES: 1) Toolbar overflow, 2) Layered coexistence, 3) Drawing undo

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/shared/glossy_text.dart';
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
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../data/insight_link_utils.dart';
import '../../widgets/insight_link_text.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/kemetic_node_reader_page.dart';
import '../nodes/node_link_picker_sheet.dart';

enum JournalPresentationMode { overlay, page }

class JournalOverlay extends StatefulWidget {
  final JournalController controller;
  final bool isPortrait;
  final VoidCallback onClose;
  final JournalPresentationMode presentationMode;

  const JournalOverlay({
    super.key,
    required this.controller,
    required this.isPortrait,
    required this.onClose,
    this.presentationMode = JournalPresentationMode.overlay,
  });

  @override
  State<JournalOverlay> createState() => _JournalOverlayState();
}

enum _JournalPane { journal }

class _JournalOverlayState extends State<JournalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late TextEditingController _textController;
  late ScrollController _scrollController;
  late ScrollController _badgeScrollController;
  late FocusNode _focusNode;

  double _dragOffset = 0;

  // V2 state
  bool _showToolbar = false;
  TextAttrs _currentAttrs = const TextAttrs();
  GlobalKey<RichTextEditorState>? _richTextEditorKey;
  final Map<String, bool> _badgeExpansion = {};
  final InsightLinkRepo _insightRepo = InsightLinkRepo();
  List<InsightLink> _insightLinks = [];
  String _prevText = '';

  // Archive state
  bool _showingArchive = false;
  bool _keyboardVisible = false;

  // Universal undo/redo system
  late JournalUndoSystem _undoSystem;

  _JournalPane _activePane = _JournalPane.journal;
  // Reflection tab removed — keep state lean

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

    final initialText =
        widget.controller.currentDocument?.blocks
            .whereType<ParagraphBlock>()
            .expand((block) => block.ops)
            .map((op) => op.insert)
            .join() ??
        widget.controller.currentDraft;
    _textController = TextEditingController(text: initialText);
    _prevText = initialText;
    _scrollController = ScrollController();
    _badgeScrollController = ScrollController();
    _focusNode = FocusNode();
    widget.controller.onDraftChanged = _onDraftChanged;

    // V2 initialization
    _undoSystem = JournalUndoSystem();

    if (FeatureFlags.isJournalV2Active) {
      _showToolbar = FeatureFlags.hasRichText;

      if (FeatureFlags.hasRichText) {
        _richTextEditorKey = GlobalKey<RichTextEditorState>();
      }
    }

    _animationController.forward();

    _loadLinks();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted &&
          widget.presentationMode == JournalPresentationMode.overlay) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _badgeScrollController.dispose();
    _focusNode.dispose();
    widget.controller.onDraftChanged = null;
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted && !FeatureFlags.hasRichText) {
      setState(() {
        _textController.text = widget.controller.currentDraft;
        _prevText = widget.controller.currentDraft;
      });
    }
  }

  Future<void> _loadLinks() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final links = await _insightRepo.fetchLinks(userId);
    final sourceId = _currentSourceId();
    setState(() {
      _insightLinks = links
          .where(
            (l) =>
                l.sourceType == InsightSourceType.journalEntry &&
                l.sourceId == sourceId,
          )
          .toList();
    });
  }

  String _currentSourceId() {
    final d = widget.controller.currentDate ?? DateTime.now();
    return journalInsightSourceId(d);
  }

  String _currentEditorText() {
    if (FeatureFlags.hasRichText) {
      final editor = _richTextEditorKey?.currentState;
      if (editor != null) return editor.currentText;
      final doc = widget.controller.currentDocument;
      if (doc != null) {
        return doc.blocks
            .whereType<ParagraphBlock>()
            .expand((block) => block.ops)
            .map((op) => op.insert)
            .join();
      }
    }
    return _textController.text;
  }

  TextSelection _currentEditorSelection() {
    if (FeatureFlags.hasRichText) {
      final editor = _richTextEditorKey?.currentState;
      if (editor != null) return editor.currentSelection;
    }
    return _textController.selection;
  }

  List<TextRange> _linkedTextRanges() {
    return _insightLinks
        .map((link) => TextRange(start: link.start, end: link.end))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void _showSelectionRequiredMessage() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Select text first, then tap Link Insight.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(context).viewInsets.bottom + 120,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _saveLinkSelection({
    required TextSelection selection,
    required String text,
    InsightLink? existingLink,
  }) async {
    final selectedText = selectedInsightText(text: text, selection: selection);
    final currentNode = existingLink == null
        ? null
        : KemeticNodeLibrary.resolve(existingLink.targetId);

    FocusManager.instance.primaryFocus?.unfocus();

    final result = await showNodeLinkPickerSheet(
      context: context,
      selectedText: selectedText,
      currentNode: currentNode,
    );
    if (!mounted || result == null) return;

    final remaining = removeInsightLinksForSelection(
      links: _insightLinks,
      selection: selection,
    );
    if (result.action == NodeLinkPickerAction.unlink) {
      setState(() {
        _insightLinks = remaining;
      });
      await _saveLinks();
      return;
    }

    final targetNode = result.node;
    if (targetNode == null) return;

    final now = DateTime.now();
    final nextLink = InsightLink(
      id: existingLink?.id ?? 'link-${now.microsecondsSinceEpoch}',
      userId: Supabase.instance.client.auth.currentUser?.id ?? 'local',
      sourceType: InsightSourceType.journalEntry,
      sourceId: _currentSourceId(),
      start: selection.start,
      end: selection.end,
      selectedText: selectedText,
      targetType: InsightTargetType.node,
      targetId: targetNode.id,
      createdAt: existingLink?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _insightLinks = [...remaining, nextLink]
        ..sort((a, b) => a.start.compareTo(b.start));
    });
    await _saveLinks();
  }

  void _handleLinkTap(InsightLink link) {
    if (link.targetType != InsightTargetType.node) return;
    final node = KemeticNodeLibrary.resolve(link.targetId);
    if (node == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KemeticNodeReaderPage(node: node)),
    );
  }

  void _handleTextChanged(String text) {
    if (_prevText != text) {
      setState(() {
        _insightLinks = InsightLinkRangeUpdater.shiftRanges(
          previous: _prevText,
          next: text,
          links: _insightLinks,
        );
        _prevText = text;
      });
      _saveLinks();
    }
    widget.controller.updateDraft(text);
  }

  Future<void> _saveLinks() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final all = await _insightRepo.fetchLinks(userId);
    final sourceId = _currentSourceId();
    final filtered = all
        .where(
          (l) =>
              !(l.sourceType == InsightSourceType.journalEntry &&
                  l.sourceId == sourceId),
        )
        .toList();
    filtered.addAll(_insightLinks);
    await _insightRepo.saveLinks(userId, filtered);
  }

  void _close() {
    _focusNode.unfocus();
    if (widget.presentationMode == JournalPresentationMode.page) {
      widget.onClose();
      return;
    }
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
          final plainText = paragraphBlocks.first.ops
              .map((op) => op.insert)
              .join();
          _textController.text = plainText;
          _insightLinks = InsightLinkRangeUpdater.shiftRanges(
            previous: _prevText,
            next: plainText,
            links: _insightLinks,
          );
          _prevText = plainText;
        }
      });
      _saveLinks();
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
          final plainText = paragraphBlocks.first.ops
              .map((op) => op.insert)
              .join();
          _textController.text = plainText;
          _insightLinks = InsightLinkRangeUpdater.shiftRanges(
            previous: _prevText,
            next: plainText,
            links: _insightLinks,
          );
          _prevText = plainText;
        }
      });
      _saveLinks();
    }
  }

  Future<void> _startLinkFlow() async {
    final text = _currentEditorText();
    final selection = normalizeInsightSelection(
      text: text,
      selection: _currentEditorSelection(),
    );
    if (selection == null) {
      _showSelectionRequiredMessage();
      return;
    }

    final existingLink = findInsightLinkForSelection(
      links: _insightLinks,
      selection: selection,
    );
    await _saveLinkSelection(
      selection: selection,
      text: text,
      existingLink: existingLink,
    );
  }

  void _onInsertChart() {
    // Not implemented yet
  }

  void _onRichTextChanged(ParagraphBlock block) {
    if (!FeatureFlags.hasRichText ||
        widget.controller.currentDocument == null) {
      return;
    }

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

    final nextText = block.ops.map((op) => op.insert).join();
    if (_prevText != nextText) {
      setState(() {
        _insightLinks = InsightLinkRangeUpdater.shiftRanges(
          previous: _prevText,
          next: nextText,
          links: _insightLinks,
        );
        _prevText = nextText;
      });
      _saveLinks();
    }

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
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final isFullPage = widget.presentationMode == JournalPresentationMode.page;

    // Show archive if requested
    if (_showingArchive) {
      return JournalArchivePage(
        repo: JournalRepo(Supabase.instance.client),
        controller: widget.controller,
        isPortrait: widget.isPortrait,
        onClose: _closeArchive, // FIXED: Add callback to close archive
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (kDebugMode) {
          print(
            '[JournalOverlay] layout size=${size.width}x${size.height} portrait=${widget.isPortrait}',
          );
        }
        if (size.width == 0 || size.height == 0) {
          return const SizedBox.shrink();
        }

        if (isFullPage) {
          return Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Container(
                color: Colors.black,
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_showToolbar && _activePane == _JournalPane.journal)
                      _buildToolbar(),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          );
        }

        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: GestureDetector(
                  onTap: () {},
                  onPanUpdate: isTablet ? null : _onPanUpdate,
                  onPanEnd: isTablet ? null : _onPanEnd,
                  child: AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      final slideValue = _slideAnimation.value;
                      final currentOffset = _dragOffset * (1 - slideValue);
                      if (kDebugMode) {
                        print(
                          '[JournalOverlay] slide=$slideValue drag=$_dragOffset',
                        );
                      }

                      if (isTablet) return child!;
                      return Transform.translate(
                        offset: widget.isPortrait
                            ? Offset(
                                -(1 - slideValue) * size.width + currentOffset,
                                0,
                              )
                            : Offset(
                                0,
                                -(1 - slideValue) * size.height * 0.3 +
                                    currentOffset,
                              ),
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
                            color: KemeticGold.base,
                            width: 1.0,
                          ),
                          borderRadius: widget.isPortrait
                              ? const BorderRadius.horizontal(
                                  right: Radius.circular(16),
                                )
                              : const BorderRadius.vertical(
                                  bottom: Radius.circular(16),
                                ),
                        ),
                        child: Column(
                          children: [
                            _buildHeader(),
                            // Show the journal toolbar only in Journal mode
                            if (_showToolbar &&
                                _activePane == _JournalPane.journal)
                              _buildToolbar(),
                            Expanded(child: _buildContent()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _buildTabButton(
                    label: 'Journal',
                    pane: _JournalPane.journal,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: KemeticGold.icon(Icons.history),
                onPressed: _openArchive,
                tooltip: 'View archive',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: KemeticGold.icon(Icons.link),
                onPressed: _startLinkFlow,
                tooltip: 'Link Insight',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: KemeticGold.icon(Icons.delete_outline),
                onPressed: () async {
                  await widget.controller.clearToday();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cleared today\'s journal'),
                        backgroundColor: KemeticGold.base,
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
                icon: KemeticGold.icon(Icons.close),
                onPressed: _close,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required _JournalPane pane}) {
    final isActive = _activePane == pane;
    return TextButton(
      onPressed: () {
        setState(() {
          _activePane = pane;
        });
        if (pane == _JournalPane.journal) {
          // Return focus to the editor when coming back to journal.
          Future.microtask(() => _focusNode.requestFocus());
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? KemeticGold.base : const Color(0xFF888888),
          fontSize: 18,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          decoration: isActive ? TextDecoration.underline : TextDecoration.none,
          decorationColor: KemeticGold.base,
          decorationThickness: 2,
        ),
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
        border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 1)),
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

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Text area (take remaining space)
            Expanded(child: _buildTextLayer()),
            const SizedBox(height: 12),
            // Badge area (replaces drawing canvas)
            _buildBadgeArea(),
          ],
        ),
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
        highlightedRanges: _linkedTextRanges(),
        insightLinks: _insightLinks,
        onInsightLinkTap: _handleLinkTap,
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
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
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

  Widget _buildBadgeArea() {
    final badges = _extractBadges();
    final height = widget.presentationMode == JournalPresentationMode.page
        ? 252.0
        : 220.0;
    final badgeCountLabel = badges.isEmpty
        ? 'No badges yet'
        : '${badges.length} badge${badges.length == 1 ? '' : 's'}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      child: height == 0
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Badges',
                        style: TextStyle(
                          color: KemeticGold.base,
                          fontSize:
                              widget.presentationMode ==
                                  JournalPresentationMode.page
                              ? 16
                              : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        badgeCountLabel,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        border: Border.all(
                          color: const Color(0xFF333333),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: badges.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18),
                                child: Text(
                                  'Event badges you add from day view will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF666666)),
                                ),
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              controller: _badgeScrollController,
                              child: SingleChildScrollView(
                                controller: _badgeScrollController,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: badges.map((token) {
                                    final expanded =
                                        _badgeExpansion[token.id] ?? false;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
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
                ),
              ],
            ),
    );
  }
}
