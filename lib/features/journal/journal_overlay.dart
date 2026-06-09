// lib/features/journal/journal_overlay.dart
// FIXES: 1) Toolbar overflow, 2) Layered coexistence, 3) Drawing undo

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/features/calendar/calendar_reflection_context.dart';
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
import '../../widgets/kemetic_keyboard.dart';
import '../../widgets/keyboard_aware.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/node_link_picker_sheet.dart';

enum JournalPresentationMode { overlay, page }

class JournalOverlay extends StatefulWidget {
  final JournalController controller;
  final bool isPortrait;
  final VoidCallback onClose;
  final JournalPresentationMode presentationMode;
  final GlobalKey? badgeAreaKey;
  final CalendarReflectionContext? reflectionContext;

  const JournalOverlay({
    super.key,
    required this.controller,
    required this.isPortrait,
    required this.onClose,
    this.presentationMode = JournalPresentationMode.overlay,
    this.badgeAreaKey,
    this.reflectionContext,
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
  Timer? _placeholderRefreshTimer;

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
  bool _isClosing = false;

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
    _schedulePlaceholderRefresh();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted &&
          widget.presentationMode == JournalPresentationMode.overlay) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _placeholderRefreshTimer?.cancel();
    _animationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _badgeScrollController.dispose();
    _focusNode.dispose();
    widget.controller.onDraftChanged = null;
    super.dispose();
  }

  void _schedulePlaceholderRefresh() {
    _placeholderRefreshTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now) + const Duration(seconds: 1);
    _placeholderRefreshTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {});
      _schedulePlaceholderRefresh();
    });
  }

  String get _journalPlaceholderText =>
      widget.reflectionContext?.buildJournalPlaceholderText() ??
      dailyReflectionQuestionForDate(DateTime.now())?.question ??
      'Write your day…';

  void _onDraftChanged() {
    if (mounted && !FeatureFlags.hasRichText) {
      setState(() {
        _textController.text = widget.controller.currentDraft;
        _prevText = widget.controller.currentDraft;
      });
    }
  }

  Future<void> _loadLinks() async {
    final userId = _currentUserId();
    final links = await _insightRepo.fetchLinks(userId);
    final sourceId = _currentSourceId();
    if (!mounted) return;
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

  String _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'local';
    } on AssertionError {
      return 'local';
    } catch (_) {
      return 'local';
    }
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
      userId: _currentUserId(),
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
    unawaited(
      openDetailRoute<void>(context, '/nodes/${Uri.encodeComponent(node.id)}'),
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
    final userId = _currentUserId();
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

  void _dismissKeyboard() {
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    _dismissKeyboard();
    unawaited(_saveAndClose());
  }

  Future<void> _saveAndClose() async {
    final saved = await widget.controller.forceSave();
    if (!saved && mounted) {
      _showSyncWarningSnackBar();
    }
    if (!mounted) return;
    if (widget.presentationMode == JournalPresentationMode.page) {
      widget.onClose();
      return;
    }
    await _animationController.reverse();
    if (mounted) {
      widget.onClose();
    }
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
        final showJournalToolbar =
            _showToolbar && _activePane == _JournalPane.journal;
        if (size.width == 0 || size.height == 0) {
          return const SizedBox.shrink();
        }

        if (isFullPage) {
          return Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              minimum: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissKeyboard,
                child: Container(
                  color: Colors.black,
                  child: Column(
                    children: [
                      _buildHeader(),
                      if (showJournalToolbar)
                        _buildToolbar(compact: _keyboardVisible),
                      Expanded(child: _buildContent()),
                    ],
                  ),
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
                  onTap: _dismissKeyboard,
                  onPanUpdate: isTablet ? null : _onPanUpdate,
                  onPanEnd: isTablet ? null : _onPanEnd,
                  child: AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      final slideValue = _slideAnimation.value;
                      final currentOffset = _dragOffset * (1 - slideValue);

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
                            if (showJournalToolbar)
                              _buildToolbar(compact: _keyboardVisible),
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
              if (_keyboardVisible)
                IconButton(
                  icon: KemeticGold.icon(Icons.keyboard_hide),
                  onPressed: _dismissKeyboard,
                  tooltip: 'Dismiss keyboard',
                  padding: expandedIconButtonPadding(context),
                  constraints: expandedIconButtonConstraints(context),
                  visualDensity: expandedVisualDensity(context),
                ),
              IconButton(
                icon: KemeticGold.icon(Icons.history),
                onPressed: _openArchive,
                tooltip: 'View archive',
                padding: expandedIconButtonPadding(context),
                constraints: expandedIconButtonConstraints(context),
                visualDensity: expandedVisualDensity(context),
              ),
              IconButton(
                icon: KemeticGold.icon(Icons.link),
                onPressed: _startLinkFlow,
                tooltip: 'Link Insight',
                padding: expandedIconButtonPadding(context),
                constraints: expandedIconButtonConstraints(context),
                visualDensity: expandedVisualDensity(context),
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
                padding: expandedIconButtonPadding(context),
                constraints: expandedIconButtonConstraints(context),
                visualDensity: expandedVisualDensity(context),
              ),
              IconButton(
                icon: KemeticGold.icon(Icons.close),
                onPressed: _close,
                padding: expandedIconButtonPadding(context),
                constraints: expandedIconButtonConstraints(context),
                visualDensity: expandedVisualDensity(context),
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
      style: withExpandedTouchTargets(
        context,
        TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
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

  Widget _buildContent() {
    return _buildEditor();
  }

  Widget _buildToolbar({bool compact = false}) {
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
          compact: compact,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        final editorPadding = keyboardVisible
            ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
            : const EdgeInsets.all(16);
        final badgeHeight = _badgeAreaHeight(
          keyboardVisible: keyboardVisible,
          maxEditorHeight: constraints.maxHeight,
        );

        return Container(
          padding: editorPadding,
          child: Column(
            children: [
              Expanded(child: _buildTextLayer()),
              if (badgeHeight > 0) ...[
                SizedBox(height: keyboardVisible ? 8 : 12),
                // Badge area (replaces drawing canvas)
                _buildBadgeArea(height: badgeHeight, compact: keyboardVisible),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSyncWarningSnackBar() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_syncStatusMessage()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String _syncStatusMessage() {
    final signedIn = widget.controller.canSyncToCloud;
    switch (widget.controller.syncStatus) {
      case JournalSyncStatus.synced:
        return 'Journal synced';
      case JournalSyncStatus.saving:
        return 'Syncing journal...';
      case JournalSyncStatus.unsavedLocal:
        return signedIn
            ? 'Journal saved locally.'
            : 'Journal saved locally. Sign in to sync across devices.';
      case JournalSyncStatus.saveFailed:
        return signedIn
            ? 'Saved on this device. Cloud sync failed.'
            : 'Saved on this device. Sign in to sync across devices.';
    }
  }

  double _badgeAreaHeight({
    required bool keyboardVisible,
    required double maxEditorHeight,
  }) {
    final targetHeight = keyboardVisible
        ? (widget.presentationMode == JournalPresentationMode.page
              ? 88.0
              : 76.0)
        : (widget.presentationMode == JournalPresentationMode.page
              ? 252.0
              : 220.0);

    if (!maxEditorHeight.isFinite) {
      return targetHeight;
    }

    final paddingHeight = keyboardVisible ? 16.0 : 32.0;
    final gapHeight = keyboardVisible ? 8.0 : 12.0;
    final minTextHeight = keyboardVisible ? 120.0 : 180.0;
    final maxBadgeHeight =
        maxEditorHeight - paddingHeight - gapHeight - minTextHeight;

    if (maxBadgeHeight < 52) {
      return 0;
    }

    return targetHeight.clamp(52.0, maxBadgeHeight).toDouble();
  }

  Widget _buildTextLayer() {
    final placeholderText = _journalPlaceholderText;

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
        focusNode: _focusNode,
        highlightedRanges: _linkedTextRanges(),
        insightLinks: _insightLinks,
        onInsightLinkTap: _handleLinkTap,
        placeholderText: placeholderText,
      );
    }

    // Plain text fallback
    return KemeticKeyboardRevealScope(
      enabled: false,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        scrollController: _scrollController,
        scrollPadding: keyboardManagedTextFieldScrollPadding,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
        decoration: InputDecoration(
          hintText: placeholderText,
          hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 16),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        scrollPhysics: const BouncingScrollPhysics(),
        enableInteractiveSelection: true,
        onChanged: _handleTextChanged,
      ),
    );
  }

  List<EventBadgeToken> _extractBadges() {
    final doc = widget.controller.currentDocument;
    if (doc == null) return [];

    return JournalBadgeUtils.tokensFromDocument(doc);
  }

  Future<void> _removeBadge(EventBadgeToken token) async {
    await widget.controller.removeBadge(token.id);
    if (!mounted) return;
    setState(() {
      _badgeExpansion.remove(token.id);
    });
  }

  Widget _buildBadgeArea({required double height, bool compact = false}) {
    final badges = _extractBadges();
    final badgeCountLabel = badges.isEmpty
        ? 'No badges yet'
        : '${badges.length} badge${badges.length == 1 ? '' : 's'}';

    return AnimatedContainer(
      key: widget.badgeAreaKey,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, compact ? 6 : 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Badges',
                  style: TextStyle(
                    color: KemeticGold.base,
                    fontSize: compact
                        ? 13
                        : widget.presentationMode ==
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
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: compact
                    ? _buildCompactBadgeList(badges)
                    : _buildExpandedBadgeList(badges),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadgeList(List<EventBadgeToken> badges) {
    if (badges.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'No badges yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: badges.map((token) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: EventBadgeWidget(
              token: token,
              initialExpanded: false,
              expandable: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedBadgeList(List<EventBadgeToken> badges) {
    if (badges.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Event badges you add from day view will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666)),
          ),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      controller: _badgeScrollController,
      child: SingleChildScrollView(
        controller: _badgeScrollController,
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
                onDelete: () => unawaited(_removeBadge(token)),
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
    );
  }
}
