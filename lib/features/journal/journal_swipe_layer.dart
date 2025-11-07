// lib/features/journal/journal_swipe_layer.dart
// TEMPORARY DEBUG VERSION - Replace your current file with this
import 'package:flutter/material.dart';
import 'journal_controller.dart';
import 'journal_overlay.dart';
import 'journal_constants.dart';
import '../../core/ui_guards.dart';
import '../../main.dart';

class JournalSwipeLayer extends StatefulWidget {
  final Widget child;
  final JournalController controller;
  final bool isPortrait;

  const JournalSwipeLayer({
    Key? key,
    required this.child,
    required this.controller,
    required this.isPortrait,
  }) : super(key: key);

  @override
  State<JournalSwipeLayer> createState() => _JournalSwipeLayerState();
}

class _JournalSwipeLayerState extends State<JournalSwipeLayer> {
  bool _isJournalOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    debugPrint('');
    debugPrint('🟢 JournalSwipeLayer INITIALIZED');
    debugPrint('   isPortrait: ${widget.isPortrait}');
    debugPrint('   canOpenJournalSwipe: ${UiGuards.canOpenJournalSwipe}');
    debugPrint('');
  }

  @override
  void dispose() {
    debugPrint('🔴 JournalSwipeLayer DISPOSED');
    _closeJournal();
    super.dispose();
  }

  // Track drag distance for portrait swipe detection
  double _dragAccum = 0.0;

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragAccum = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!UiGuards.canOpenJournalSwipe) {
      return;
    }
    
    if (_isJournalOpen) {
      return;
    }

    if (!widget.isPortrait) {
      return; // Landscape handled by header
    }

    // Portrait: L→R swipe anywhere
    _dragAccum += details.delta.dx;
    
    // Check if we've exceeded threshold for immediate open
    final dx = details.delta.dx.abs();
    final dy = details.delta.dy.abs();
    final isRightward = details.delta.dx > 0;
    final isDominantHorizontal = dx > dy * kJournalSwipeDominance;
    
    if (isRightward && isDominantHorizontal && _dragAccum > 40) {
      debugPrint('✅ OPENING JOURNAL (threshold met)');
      _openJournal();
      _dragAccum = 0.0;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!UiGuards.canOpenJournalSwipe) {
      _dragAccum = 0.0;
      return;
    }
    
    if (_isJournalOpen) {
      _dragAccum = 0.0;
      return;
    }

    if (!widget.isPortrait) {
      _dragAccum = 0.0;
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.dx;

    // Check velocity or accumulated distance
    if (velocity.abs() >= kJournalSwipeMinVelocity && velocity > 0) {
      debugPrint('✅ OPENING JOURNAL (flick detected)');
      _openJournal();
    } else if (_dragAccum > 40) {
      debugPrint('✅ OPENING JOURNAL (distance threshold)');
      _openJournal();
    }
    
    _dragAccum = 0.0;
  }

  void _openJournal() {
    debugPrint('');
    debugPrint('🚀 OPENING JOURNAL OVERLAY');
    debugPrint('');
    
    if (_isJournalOpen) return;

    setState(() => _isJournalOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => JournalOverlay(
        controller: widget.controller,
        onClose: _closeJournal,
        isPortrait: widget.isPortrait,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Track analytics
    _trackJournalOpened();
    
    debugPrint('✅ Journal overlay inserted');
  }

  void _closeJournal() {
    if (!_isJournalOpen) return;

    debugPrint('🔒 Closing journal overlay');
    
    _overlayEntry?.remove();
    _overlayEntry = null;

    setState(() => _isJournalOpen = false);
  }

  void _trackJournalOpened() {
    // Track journal opened event
    Events.trackIfAuthed('journal_opened', {
      'entry_point': 'swipe',
      'orientation': widget.isPortrait ? 'portrait' : 'landscape',
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️  JournalSwipeLayer BUILD (isPortrait: ${widget.isPortrait})');
    
    // Only add gesture detector in portrait mode
    // Landscape open is handled by header bar
    if (!widget.isPortrait) {
      debugPrint('   Skipping gesture detector (landscape mode)');
      return widget.child;
    }

    debugPrint('   Adding gesture detector (portrait mode)');
    // Use drag gestures instead of pan gestures to match landscape pattern
    // This ensures gesture binding is fully initialized in PWA standalone mode
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: widget.child,
    );
  }
}

/// Wrapper for landscape header-only swipe
class JournalHeaderSwipeDetector extends StatelessWidget {
  final Widget child;
  final JournalController controller;
  final VoidCallback onOpen;

  const JournalHeaderSwipeDetector({
    Key? key,
    required this.child,
    required this.controller,
    required this.onOpen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (!UiGuards.canOpenJournalSwipe) return;

        // Down swipe only
        if (details.delta.dy > 0 &&
            details.delta.dy.abs() > details.delta.dx.abs() * kJournalSwipeDominance) {
          onOpen();
        }
      },
      child: child,
    );
  }
}