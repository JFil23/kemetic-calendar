import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'journal_controller.dart';
import 'journal_overlay.dart';
import 'journal_constants.dart';
import '../../core/ui_guards.dart';
import '../../main.dart';
import '../calendar/calendar_page.dart' show CreateFlowFromNutrition;

class JournalSwipeLayer extends StatefulWidget {
  const JournalSwipeLayer({
    Key? key,
    required this.child,
    required this.controller,
    required this.isPortrait,
    this.onCreateFlow,
  }) : super(key: key);

  final Widget child;
  final JournalController controller; // your existing data/controller
  final bool isPortrait;
  final CreateFlowFromNutrition? onCreateFlow;

  @override
  State<JournalSwipeLayer> createState() => _JournalSwipeLayerState();
}

class _JournalSwipeLayerState extends State<JournalSwipeLayer> {
  bool _isJournalOpen = false;
  OverlayEntry? _overlayEntry;

  // Gesture accumulators
  double _dragAccumOpen = 0.0;   // left-edge -> right drag to open
  double _dragAccumClose = 0.0;  // right-edge -> left drag to close

  // Tunables
  static const double _edgeMin = 28;   // min px edge width
  static const double _edgeMax = 56;   // max px edge width
  static const double _openDistance = 42;     // px to open via slow drag
  static const double _closeDistance = 42;    // px to close via slow drag
  static const double _openVelocity = 750;    // fling right to open
  static const double _closeVelocity = -750;  // fling left to close

  double _edgeWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return math.max(_edgeMin, math.min(_edgeMax, w * 0.06));
  }

  bool get _active => widget.isPortrait && mounted;

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

  void _openJournal() {
    if (_isJournalOpen) return;
    if (!UiGuards.canOpenJournalSwipe) return;

    debugPrint('');
    debugPrint('🚀 OPENING JOURNAL OVERLAY');
    debugPrint('');

    setState(() => _isJournalOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => JournalOverlay(
        controller: widget.controller,
        onClose: _closeJournal,
        isPortrait: widget.isPortrait,
        onCreateFlow: widget.onCreateFlow,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);

    // analytics
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
    Events.trackIfAuthed('journal_opened', {
      'entry_point': 'swipe',
      'orientation': widget.isPortrait ? 'portrait' : 'landscape',
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️  JournalSwipeLayer BUILD (isPortrait: ${widget.isPortrait})');
    
    if (!_active) {
      debugPrint('   Skipping gesture detector (landscape mode or not mounted)');
      return widget.child;
    }

    final double safeTop = kToolbarHeight + MediaQuery.of(context).padding.top;
    final double edge = _edgeWidth(context);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    // For RTL, flip edges
    final leftSide = isRtl ? null : 0.0;
    final rightSide = isRtl ? 0.0 : null;

    debugPrint('   Adding edge-only swipe pads (edge width: $edge px)');

    return Stack(
      children: [
        // Content below
        widget.child,

        // ===== Left-edge OPEN (drag right) — only when closed =====
        if (!_isJournalOpen)
          Positioned(
            left: leftSide,
            right: rightSide,
            top: safeTop,
            bottom: 0,
            width: edge,
            child: _EdgeSwipePad(
              onHorizontalDragStart: (_) {
                if (!UiGuards.canOpenJournalSwipe) return;
                _dragAccumOpen = 0.0;
              },
              onHorizontalDragUpdate: (d) {
                if (!UiGuards.canOpenJournalSwipe) return;
                _dragAccumOpen += d.delta.dx; // right = positive
              },
              onHorizontalDragEnd: (d) {
                if (!UiGuards.canOpenJournalSwipe) {
                  _dragAccumOpen = 0.0;
                  return;
                }
                final vx = d.velocity.pixelsPerSecond.dx;
                final traveled = _dragAccumOpen;
                final flingOpen = vx > _openVelocity;
                final dragOpen = traveled > _openDistance;
                if ((flingOpen || dragOpen) && !_isJournalOpen) {
                  _openJournal();
                }
                _dragAccumOpen = 0.0;
              },
            ),
          ),

        // ===== Right-edge CLOSE (drag left) — only when open =====
        if (_isJournalOpen)
          Positioned(
            right: rightSide == null ? 0 : null, // LTR -> right:0 ; RTL -> left:0
            left: rightSide,
            top: safeTop,
            bottom: 0,
            width: edge,
            child: _EdgeSwipePad(
              onHorizontalDragStart: (_) => _dragAccumClose = 0.0,
              onHorizontalDragUpdate: (d) {
                _dragAccumClose += d.delta.dx; // left = negative
              },
              onHorizontalDragEnd: (d) {
                final vx = d.velocity.pixelsPerSecond.dx;
                final traveled = _dragAccumClose;
                final flingClose = vx < _closeVelocity;        // strong left fling
                final dragClose = traveled < -_closeDistance;  // enough left drag
                if ((flingClose || dragClose) && _isJournalOpen) {
                  _closeJournal();
                }
                _dragAccumClose = 0.0;
              },
            ),
          ),
      ],
    );
  }
}

/// Transparent, edge-only strip that recognizes drags but lets taps pass.
class _EdgeSwipePad extends StatelessWidget {
  const _EdgeSwipePad({
    required this.onHorizontalDragStart,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
  });

  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent, // do not swallow taps
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: null, // never claim taps
        onHorizontalDragStart: onHorizontalDragStart,
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: const SizedBox.expand(),
      ),
    );
  }
}
