import 'package:flutter/material.dart';

import '../shared/glossy_text.dart';

const Key utilitySheetRouteBackdropKey = Key(
  'utilitySheetRouteScaffold.backdrop',
);
const Key utilitySheetRouteDragHandleKey = Key(
  'utilitySheetRouteScaffold.dragHandle',
);
const Key utilitySheetRouteCloseButtonKey = Key(
  'utilitySheetRouteScaffold.closeButton',
);

class UtilitySheetRouteScaffold extends StatefulWidget {
  const UtilitySheetRouteScaffold({
    super.key,
    required this.child,
    required this.onClose,
    required this.semanticLabel,
    this.dismissDistance = 120,
    this.dismissVelocity = 700,
  });

  final Widget child;
  final VoidCallback onClose;
  final String semanticLabel;
  final double dismissDistance;
  final double dismissVelocity;

  @override
  State<UtilitySheetRouteScaffold> createState() =>
      _UtilitySheetRouteScaffoldState();
}

class _UtilitySheetRouteScaffoldState extends State<UtilitySheetRouteScaffold> {
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _closeRequested = false;

  double get _dragProgress =>
      (_dragOffset / widget.dismissDistance).clamp(0.0, 1.0);

  void _requestClose() {
    if (_closeRequested) return;
    _closeRequested = true;
    widget.onClose();
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final nextOffset = (_dragOffset + details.delta.dy).clamp(
      0.0,
      widget.dismissDistance * 1.6,
    );
    if (nextOffset == _dragOffset) return;
    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final downwardVelocity = details.primaryVelocity ?? 0;
    if (_dragOffset >= widget.dismissDistance ||
        downwardVelocity >= widget.dismissVelocity) {
      _requestClose();
      return;
    }
    _snapBack();
  }

  void _handleDragCancel() {
    _snapBack();
  }

  void _snapBack() {
    if (!_isDragging && _dragOffset == 0) return;
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.shortestSide >= 600;
    final sideInset = isWide ? 24.0 : 0.0;
    final bottomInset = isWide ? 24.0 : 0.0;
    final heightFactor = isWide ? 0.9 : 0.92;
    final scrimOpacity = 0.58 - (_dragProgress * 0.18);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: utilitySheetRouteBackdropKey,
              behavior: HitTestBehavior.opaque,
              onTap: _requestClose,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: scrimOpacity),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sideInset,
                  0,
                  sideInset,
                  bottomInset,
                ),
                child: FractionallySizedBox(
                  heightFactor: heightFactor,
                  widthFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: AnimatedContainer(
                      duration: _isDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      transform: Matrix4.translationValues(0, _dragOffset, 0),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Material(
                          color: Colors.black,
                          child: Column(
                            children: [
                              GestureDetector(
                                key: utilitySheetRouteDragHandleKey,
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragStart: _handleDragStart,
                                onVerticalDragUpdate: _handleDragUpdate,
                                onVerticalDragEnd: _handleDragEnd,
                                onVerticalDragCancel: _handleDragCancel,
                                child: SizedBox(
                                  height: 44,
                                  child: Stack(
                                    children: [
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Container(
                                            width: 42,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          key: utilitySheetRouteCloseButtonKey,
                                          tooltip:
                                              'Close ${widget.semanticLabel}',
                                          onPressed: _requestClose,
                                          icon: KemeticGold.icon(Icons.close),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(child: widget.child),
                            ],
                          ),
                        ),
                      ),
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
