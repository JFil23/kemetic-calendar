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

  void _onPanUpdate(DragUpdateDetails details) {
    // Debug: Log every pan update
    if (details.delta.dx.abs() > 2 || details.delta.dy.abs() > 2) {
      debugPrint('👆 PAN UPDATE: dx=${details.delta.dx.toStringAsFixed(1)}, dy=${details.delta.dy.toStringAsFixed(1)}');
    }
    
    if (!UiGuards.canOpenJournalSwipe) {
      debugPrint('⛔ PAN BLOCKED: UiGuards.canOpenJournalSwipe = false');
      return;
    }
    
    if (_isJournalOpen) {
      debugPrint('⛔ PAN BLOCKED: Journal already open');
      return;
    }

    // Check directional dominance
    final dx = details.delta.dx.abs();
    final dy = details.delta.dy.abs();

    bool shouldOpen = false;

    if (widget.isPortrait) {
      // Portrait: L→R swipe anywhere
      final isRightward = details.delta.dx > 0;
      final isDominantHorizontal = dx > dy * kJournalSwipeDominance;
      
      debugPrint('📱 PORTRAIT CHECK:');
      debugPrint('   Rightward? $isRightward (dx=${details.delta.dx.toStringAsFixed(1)})');
      debugPrint('   Dominant H? $isDominantHorizontal (dx=$dx > dy=$dy * 1.6)');
      
      shouldOpen = isRightward && isDominantHorizontal;
    } else {
      // Landscape: Down swipe on header only (handled by parent)
      debugPrint('📱 LANDSCAPE: Ignoring (header-only swipe)');
      return;
    }

    if (shouldOpen) {
      debugPrint('✅ OPENING JOURNAL (threshold met)');
      _openJournal();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    debugPrint('👆 PAN END: velocity=${details.velocity.pixelsPerSecond.dx.toStringAsFixed(1)} px/s');
    
    if (!UiGuards.canOpenJournalSwipe) {
      debugPrint('⛔ PAN END BLOCKED: Guards disabled');
      return;
    }
    
    if (_isJournalOpen) {
      debugPrint('⛔ PAN END BLOCKED: Already open');
      return;
    }

    final velocity = widget.isPortrait
        ? details.velocity.pixelsPerSecond.dx
        : details.velocity.pixelsPerSecond.dy;

    debugPrint('🏃 Velocity check: ${velocity.abs().toStringAsFixed(1)} vs threshold $kJournalSwipeMinVelocity');

    if (velocity.abs() >= kJournalSwipeMinVelocity) {
      if (widget.isPortrait && velocity > 0) {
        debugPrint('✅ OPENING JOURNAL (flick detected)');
        _openJournal();
      } else if (!widget.isPortrait && velocity > 0) {
        debugPrint('✅ OPENING JOURNAL (flick detected)');
        _openJournal();
      }
    }
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
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
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