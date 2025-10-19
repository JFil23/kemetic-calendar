// lib/features/journal/journal_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'journal_controller.dart';
import 'journal_constants.dart';

class JournalOverlay extends StatefulWidget {
  final JournalController controller;
  final VoidCallback onClose;
  final bool isPortrait;

  const JournalOverlay({
    Key? key,
    required this.controller,
    required this.onClose,
    required this.isPortrait,
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

  double _dragOffset = 0.0;
  bool _isDragging = false;
  int? _highlightStart;
  int? _highlightEnd;

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

    // Animate in
    _animationController.forward();

    // Focus after animation
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
    if (!mounted) return;
    
    final newText = widget.controller.currentDraft;
    if (_textController.text != newText) {
      final selection = _textController.selection;
      _textController.text = newText;
      
      // Restore cursor position if valid
      if (selection.baseOffset <= newText.length) {
        _textController.selection = selection;
      }
    }
  }

  void _handleTextChanged(String text) {
    widget.controller.updateDraft(text);
  }

  Future<void> _close() async {
    await widget.controller.forceSave();
    
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      // Check if gesture is directionally dominant
      final dx = details.delta.dx.abs();
      final dy = details.delta.dy.abs();
      
      if (widget.isPortrait) {
        // Portrait: R→L close
        if (details.delta.dx < 0 && dx > dy * kJournalSwipeDominance) {
          setState(() => _isDragging = true);
        }
      } else {
        // Landscape: Up close
        if (details.delta.dy < 0 && dy > dx * kJournalSwipeDominance) {
          setState(() => _isDragging = true);
        }
      }
    }

    if (_isDragging) {
      setState(() {
        if (widget.isPortrait) {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(
            double.negativeInfinity,
            0.0,
          );
        } else {
          _dragOffset = (_dragOffset + details.delta.dy).clamp(
            double.negativeInfinity,
            0.0,
          );
        }
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final size = MediaQuery.of(context).size;
    final threshold = widget.isPortrait
        ? size.width * kJournalPortraitWidthFraction * kJournalCloseTravelFraction
        : size.height * kJournalLandscapeHeightFraction * kJournalCloseTravelFraction;

    final velocity = widget.isPortrait
        ? details.velocity.pixelsPerSecond.dx
        : details.velocity.pixelsPerSecond.dy;

    final shouldClose = _dragOffset.abs() >= threshold ||
        velocity.abs() >= kJournalSwipeMinVelocity;

    setState(() => _isDragging = false);

    if (shouldClose) {
      _close();
    } else {
      // Spring back
      setState(() => _dragOffset = 0.0);
    }
  }

  /// Scroll to end and highlight appended content
  Future<void> scrollToEndAndHighlight(int startPosition, int endPosition) async {
    setState(() {
      _highlightStart = startPosition;
      _highlightEnd = endPosition;
    });

    // Scroll to bottom
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Clear highlight after delay
    Future.delayed(const Duration(milliseconds: kJournalHighlightDurationMs), () {
      if (mounted) {
        setState(() {
          _highlightStart = null;
          _highlightEnd = null;
        });
      }
    });
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
      child: Stack(
        children: [
          TextField(
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
          ),
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
}