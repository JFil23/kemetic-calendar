import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'journal_controller.dart';
import 'journal_overlay.dart';
import 'journal_constants.dart';
import '../../core/ui_guards.dart';
import '../../main.dart';

/// Allows triggering the journal overlay programmatically (e.g., from an AppBar button).
class JournalSwipeHandle {
  void Function({String entryPoint})? _open;
  VoidCallback? _close;

  void open({String entryPoint = 'external'}) => _open?.call(entryPoint: entryPoint);
  void close() => _close?.call();

  void _bind({
    required void Function({String entryPoint}) open,
    required VoidCallback close,
  }) {
    _open = open;
    _close = close;
  }

  void _clear() {
    _open = null;
    _close = null;
  }
}

class JournalSwipeLayer extends StatefulWidget {
  const JournalSwipeLayer({
    Key? key,
    required this.child,
    required this.controller,
    required this.isPortrait,
    this.handle,
  }) : super(key: key);

  final Widget child;
  final JournalController controller; // your existing data/controller
  final bool isPortrait;
  final JournalSwipeHandle? handle;

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
    _bindHandle();
  }

  @override
  void dispose() {
    widget.handle?._clear();
    _closeJournal();
    super.dispose();
  }

  @override
  void didUpdateWidget(JournalSwipeLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?._clear();
      _bindHandle();
    }
  }

  void _bindHandle() {
    widget.handle?._bind(
      open: ({String entryPoint = 'external'}) => _openJournal(entryPoint: entryPoint),
      close: _closeJournal,
    );
  }

  void _openJournal({String entryPoint = 'swipe'}) {
    if (!_active) return;
    if (_isJournalOpen) return;
    if (!UiGuards.canOpenJournalSwipe) return;
    if (kDebugMode) {
      print('[JournalSwipeLayer] open entryPoint=$entryPoint portrait=${widget.isPortrait}');
    }

    setState(() => _isJournalOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: JournalOverlay(
          controller: widget.controller,
          onClose: _closeJournal,
          isPortrait: widget.isPortrait,
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);

    // analytics
    _trackJournalOpened(entryPoint);
    
  }

  void _closeJournal() {
    if (!_isJournalOpen) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isJournalOpen = false);
  }

  void _trackJournalOpened(String entryPoint) {
    Events.trackIfAuthed('journal_opened', {
      'entry_point': entryPoint,
      'orientation': widget.isPortrait ? 'portrait' : 'landscape',
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return widget.child;
    }

    final double safeTop = kToolbarHeight + MediaQuery.of(context).padding.top;
    final double edge = _edgeWidth(context);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    // For RTL, flip edges
    final leftSide = isRtl ? null : 0.0;
    final rightSide = isRtl ? 0.0 : null;

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
