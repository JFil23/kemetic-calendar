import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../calendar_event_visual_style.dart';

class GraphicEventBlockShell extends StatelessWidget {
  const GraphicEventBlockShell({
    super.key,
    required this.graphic,
    required this.height,
    required this.visual,
    this.width,
    this.isPreview = false,
    this.child,
    this.overlay,
    this.opacity = 1,
    this.dashedBorder = false,
  });

  final CalendarEventGraphicStyle graphic;
  final double height;
  final double? width;
  final bool isPreview;
  final Widget visual;
  final Widget? child;
  final Widget? overlay;
  final double opacity;
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(7);
    final block = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPreview ? 0.16 : 0.28),
            blurRadius: kIsWeb ? 8 : 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: graphic.glowColor.withValues(alpha: isPreview ? 0.08 : 0.14),
            blurRadius: kIsWeb ? 10 : 14,
            spreadRadius: -3,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: graphic.background,
                borderRadius: borderRadius,
                border: Border.all(
                  color: graphic.borderColor.withValues(
                    alpha: dashedBorder ? 0.55 : (isPreview ? 0.7 : 0.92),
                  ),
                  width: dashedBorder ? 1.2 : 0.9,
                ),
              ),
            ),
          ),
          Positioned.fill(child: IgnorePointer(child: visual)),
          if (child != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              child: child,
            ),
          if (overlay != null) Positioned.fill(child: overlay!),
        ],
      ),
    );
    if (opacity >= 0.999) return block;
    return Opacity(opacity: opacity, child: block);
  }
}
