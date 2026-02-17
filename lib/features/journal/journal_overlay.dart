// lib/features/journal/journal_overlay.dart
// FIXES: 1) Toolbar overflow, 2) Layered coexistence, 3) Drawing undo

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../../services/ai_reflection_service.dart';
import '../../widgets/kemetic_day_info.dart';
import '../../core/day_key.dart';
import '../../widgets/kemetic_date_picker.dart' show KemeticMath;
import '../../services/ai_reflection_service.dart';

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

enum _JournalPane { journal, reflection }

class _JournalOverlayState extends State<JournalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late TextEditingController _textController;
  late ScrollController _scrollController;
  late ScrollController _badgeScrollController;
  late FocusNode _focusNode;
  late final AIReflectionService _reflectionService;

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

  // Reflection tab state
  _JournalPane _activePane = _JournalPane.journal;
  String? _reflectionText;
  bool _isGeneratingReflection = false;
  bool _isSavingReflection = false;

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
    _badgeScrollController = ScrollController();
    _focusNode = FocusNode();
    widget.controller.onDraftChanged = _onDraftChanged;
    _reflectionService = AIReflectionService(Supabase.instance.client);

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
    _badgeScrollController.dispose();
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

  String _buildReflectionFromBadges(List<EventBadgeToken> badges) {
    if (badges.isEmpty) {
      return 'Time moved quietly this decan. Silence is still a shape—space held open for whatever wants to speak next.';
    }

    final titleCounts = <String, int>{};
    int morningCount = 0;
    int eveningCount = 0;

    for (final b in badges) {
      final t = b.title.trim().toLowerCase();
      if (t.isNotEmpty) {
        titleCounts[t] = (titleCounts[t] ?? 0) + 1;
      }
      final start = b.start;
      if (start != null) {
        final h = start.toLocal().hour;
        if (h < 12) morningCount++;
        if (h >= 18) eveningCount++;
      }
    }

    final sorted = titleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominant = sorted.isNotEmpty ? sorted.first.value : 0;
    final total = badges.length;
    final dominantRatio = total == 0 ? 0.0 : dominant / total;

    final focused = dominantRatio >= 0.5;
    final exploratory = sorted.length >= 3 && dominantRatio < 0.5;
    final morningLean = morningCount > total / 2;
    final eveningLean = eveningCount > total / 2;

    final opening = focused
        ? 'This decan moved in close circles—choosing depth over breadth.'
        : exploratory
            ? 'Your days touched many currents, yet an inner note stayed steady.'
            : 'You moved with measured steps, neither rushing nor drifting.';

    final pattern = focused
        ? 'Returning to similar moments suggests you were seeking alignment more than variety—choosing what felt true over what was simply available.'
        : exploratory
            ? 'You let yourself explore without fixing on one shape. That kind of wandering is listening for what rings honest.'
            : 'Your marks carried a quiet negotiation between stability and change, steadying yourself while testing new edges.';

    final rhythm = morningLean
        ? 'Mornings held more of your presence—as if first light gave the clearest signal.'
        : eveningLean
            ? 'Evenings gathered your energy—closing light became a place to settle what mattered.'
            : 'Your hours spread across the day, a gentle pulse rather than a single surge.';

    const silence =
        'Some spaces stayed quiet—not as neglect, but as rest points waiting to receive you when you are ready.';

    const invitation =
        'As the next decan opens, carry forward the feeling that felt most like you, and let one quiet space be touched—only if it calls.';

    const closing =
        'Balance is already leaning toward you; meet it with the smallest honest gesture.';

    return [
      opening,
      pattern,
      rhythm,
      silence,
      invitation,
      closing,
    ].join(' ');
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
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
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
          print('[JournalOverlay] layout size=${size.width}x${size.height} portrait=${widget.isPortrait}');
        }
        if (size.width == 0 || size.height == 0) {
          return const SizedBox.shrink();
        }

        return SizedBox.expand(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                color: Colors.black.withOpacity(0.5),
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
                        print('[JournalOverlay] slide=$slideValue drag=$_dragOffset');
                      }

                      if (isTablet) return child!;
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
                            if (_showToolbar && _activePane == _JournalPane.journal) _buildToolbar(),
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
                Flexible(child: _buildTabButton(label: 'Journal', pane: _JournalPane.journal)),
                const SizedBox(width: 8),
                Flexible(child: _buildTabButton(label: 'Reflection', pane: _JournalPane.reflection)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
          color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF888888),
          fontSize: 18,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          decoration: isActive ? TextDecoration.underline : TextDecoration.none,
          decorationColor: const Color(0xFFD4AF37),
          decorationThickness: 2,
        ),
      ),
    );
  }

  /// Returns either the Journal editor (default) or the Nutrition grid.
  Widget _buildContent() {
    if (_activePane == _JournalPane.reflection) {
      return _buildReflectionPane();
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
          canUndo: _undoSystem.canUndo,
          canRedo: _undoSystem.canRedo,
        ),
      ),
    );
  }

  ({String dayLabel, String decanLabel, String monthLabel, int kDay}) _currentKemeticContext() {
    final date = widget.controller.currentDate ?? DateTime.now();
    final kem = KemeticMath.fromGregorian(date);
    final dayKey = kemeticDayKey(kem.kMonth, kem.kDay);
    final info = KemeticDayData.getInfoForDay(dayKey);
    final monthLabel = info?.month ?? 'Month ${kem.kMonth}';
    final decanLabel =
        KemeticDayData.resolveDecanNameFromKey(dayKey, expanded: true) ??
            info?.decanName ??
            'Decan ${decanForDay(kem.kDay)}';
    final dayLabel = '$monthLabel ${kem.kDay}';
    return (
      dayLabel: dayLabel,
      decanLabel: decanLabel,
      monthLabel: monthLabel,
      kDay: kem.kDay,
    );
  }

  String _buildReflectionText(List<EventBadgeToken> badges) {
    // Fallback reflection grounded in badge patterns (no journal text, no badge/task recap).
    return _buildReflectionFromBadges(badges);
  }

  Future<void> _handleGenerateReflection() async {
    if (_isGeneratingReflection) return;
    setState(() {
      _isGeneratingReflection = true;
    });
    final badges = _extractBadges();
    final ctx = _currentKemeticContext();
    final badgeTitles = badges
        .map((b) => b.title.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    String generated = '';
    try {
      final response = await _reflectionService.generateReflection(
        decanName: '${ctx.monthLabel} — ${ctx.decanLabel}',
        badgeTitles: badgeTitles,
        badgeCount: badges.length,
        kemeticDayLabel: 'Day ${ctx.kDay}',
      );
      if (response.success && (response.reflection?.trim().isNotEmpty ?? false)) {
        generated = response.reflection!.trim();
      }
    } catch (_) {
      // fall through to fallback
    }

    final text = generated.isNotEmpty ? generated : _buildReflectionText(badges);
    setState(() {
      _reflectionText = text;
      _isGeneratingReflection = false;
    });
  }

  Future<void> _handleSaveReflection() async {
    if (_isSavingReflection) return;
    setState(() {
      _isSavingReflection = true;
    });

    final badges = _extractBadges();
    final text = _reflectionText ?? _buildReflectionText(badges);
    try {
      await widget.controller.appendToToday('\n\n$text');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reflection saved to journal'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _activePane = _JournalPane.journal;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reflectionText = text;
          _isSavingReflection = false;
        });
      }
    }
  }

  Widget _buildReflectionPane() {
    final badges = _extractBadges();
    final ctx = _currentKemeticContext();
    final reflection = _reflectionText;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decan Reflection',
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${ctx.monthLabel} — ${ctx.decanLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildBadgeSummary(badges),
          const SizedBox(height: 16),
          Text(
            reflection ?? 'Generate a reflection that reads your time-shape from badges alone (journal text stays private).',
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isGeneratingReflection ? null : _handleGenerateReflection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: _isGeneratingReflection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isSavingReflection ? null : _handleSaveReflection,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                  foregroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: _isSavingReflection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Save to Journal'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() => _activePane = _JournalPane.journal);
              Future.microtask(() => _focusNode.requestFocus());
            },
            child: const Text(
              'Back to Journal',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSummary(List<EventBadgeToken> badges) {
    if (badges.isEmpty) {
      return const Text(
        'No badges yet for this entry.',
        style: TextStyle(color: Color(0xFFAAAAAA)),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges • ${badges.length}',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...badges.map((token) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EventBadgeWidget(
                  token: token,
                  initialExpanded: _badgeExpansion[token.id] ?? false,
                  onToggle: (next) {
                    setState(() {
                      _badgeExpansion[token.id] = next;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Text area (take remaining space)
            Expanded(
              child: _buildTextLayer(),
            ),
            const SizedBox(height: 12),
            // Badge area (replaces drawing canvas)
            _buildBadgeArea(keyboardVisible),
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
