import 'package:flutter/material.dart';
import 'journal_controller.dart';

/// Wraps the AppBar in landscape mode to enable down-swipe gesture
class LandscapeJournalHeader extends StatefulWidget {
  final JournalController controller;
  final Widget child; // AppBar widget
  final VoidCallback? onJournalOpened;

  const LandscapeJournalHeader({
    Key? key,
    required this.controller,
    required this.child,
    this.onJournalOpened,
  }) : super(key: key);

  @override
  State<LandscapeJournalHeader> createState() => _LandscapeJournalHeaderState();
}

class _LandscapeJournalHeaderState extends State<LandscapeJournalHeader> {
  double _dragDistance = 0;
  static const double _openThreshold = 80.0; // pixels to drag down to open

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) {
      // Dragging down
      setState(() {
        _dragDistance += details.delta.dy;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragDistance > _openThreshold) {
      // Open journal
      widget.onJournalOpened?.call();
    }

    // Reset drag state
    setState(() {
      _dragDistance = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        decoration: _dragDistance > 0
            ? BoxDecoration(
                color: Colors.black,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFD4AF37).withOpacity(_dragDistance / _openThreshold),
                    width: 2,
                  ),
                ),
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

/// Wraps the journal overlay in landscape mode to enable up-swipe gesture to close
class LandscapeJournalOverlay extends StatefulWidget {
  final Widget child; // Journal overlay content
  final VoidCallback onClose;

  const LandscapeJournalOverlay({
    Key? key,
    required this.child,
    required this.onClose,
  }) : super(key: key);

  @override
  State<LandscapeJournalOverlay> createState() => _LandscapeJournalOverlayState();
}

class _LandscapeJournalOverlayState extends State<LandscapeJournalOverlay> {
  double _dragDistance = 0;
  static const double _closeThreshold = 100.0; // pixels to drag up to close

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy < 0) {
      // Dragging up
      setState(() {
        _dragDistance += details.delta.dy.abs();
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragDistance > _closeThreshold) {
      // Close journal
      widget.onClose();
    }

    // Reset drag state
    setState(() {
      _dragDistance = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: widget.child,
    );
  }
}
