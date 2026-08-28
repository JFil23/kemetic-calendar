import 'package:flutter/material.dart';

import '../../calendar_event_visual_style.dart';
import '../../presentation/graphic_event_block_shell.dart';

class OfferingTableEventBlockVisual extends StatelessWidget {
  const OfferingTableEventBlockVisual({
    super.key,
    required this.graphic,
    required this.height,
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
  final Widget? child;
  final Widget? overlay;
  final double opacity;
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    return GraphicEventBlockShell(
      graphic: graphic,
      height: height,
      width: width,
      isPreview: isPreview,
      opacity: opacity,
      dashedBorder: dashedBorder,
      overlay: overlay,
      visual: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xD9040201),
                  Color(0x8F140A05),
                  Color(0x182B160C),
                  Colors.transparent,
                ],
                stops: [0, 0.38, 0.7, 1],
              ),
            ),
          ),
          Positioned(
            right: 9,
            top: (height - 30) / 2,
            child: Opacity(
              opacity: isPreview ? 0.82 : 1,
              child: const OfferingTableCupAccent(size: 31),
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

class OfferingTableCupAccent extends StatelessWidget {
  const OfferingTableCupAccent({super.key, this.size = 31});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.82),
      painter: const _OfferingTableCupAccentPainter(),
    );
  }
}

class _OfferingTableCupAccentPainter extends CustomPainter {
  const _OfferingTableCupAccentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rim = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.12,
      size.width * 0.84,
      size.height * 0.28,
    );
    final body = Path()
      ..moveTo(size.width * 0.12, size.height * 0.26)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.44,
        size.width * 0.88,
        size.height * 0.26,
      )
      ..lineTo(size.width * 0.79, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width * 0.21,
        size.height * 0.82,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A603D), Color(0xFF4A2817), Color(0xFF241109)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFE1B07D),
    );
    canvas.drawOval(rim, Paint()..color = const Color(0xFF24120B));
    canvas.drawOval(
      Rect.fromCenter(
        center: rim.center.translate(0, 0.4),
        width: rim.width * 0.78,
        height: rim.height * 0.55,
      ),
      Paint()..color = const Color(0xFF8FC7C4),
    );
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFE1B07D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
