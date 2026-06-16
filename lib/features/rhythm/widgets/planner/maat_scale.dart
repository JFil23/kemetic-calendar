import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class MaatScale extends StatelessWidget {
  const MaatScale({
    super.key,
    required this.tiltDegrees,
    required this.progress,
  });

  final double tiltDegrees;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final clampedTilt = tiltDegrees.clamp(0.0, 20.0).toDouble();
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      height: 104,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: clampedTilt),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, animatedTilt, child) {
          return CustomPaint(
            painter: _MaatScalePainter(
              tiltDegrees: animatedTilt,
              progress: clampedProgress,
            ),
          );
        },
      ),
    );
  }
}

class _MaatScalePainter extends CustomPainter {
  const _MaatScalePainter({required this.tiltDegrees, required this.progress});

  final double tiltDegrees;
  final double progress;

  static const _gold = Color(0xFFC8A84A);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 390, size.height / 92);
    final dx = (size.width - 390 * scale) / 2;
    final dy = (size.height - 92 * scale) / 2;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final glowPaint = Paint()
      ..color = _gold.withValues(
        alpha: PlannerVisualTokens.liftedAlpha(0.04 + progress * 0.08),
      )
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(195, 46), width: 220, height: 68),
      glowPaint,
    );

    final postPaint = Paint()
      ..color = _gold.withValues(
        alpha: PlannerVisualTokens.liftedAlpha(0.42 + progress * 0.14),
      )
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(const Offset(195, 20), const Offset(195, 78), postPaint)
      ..drawLine(const Offset(178, 78), const Offset(212, 78), postPaint);

    final fulcrumPaint = Paint()
      ..color = _gold.withValues(
        alpha: PlannerVisualTokens.liftedAlpha(0.58 + progress * 0.22),
      );
    canvas.drawCircle(const Offset(195, 20), 3.2, fulcrumPaint);

    final pivot = const Offset(195, 38);
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(tiltDegrees * math.pi / 180)
      ..translate(-pivot.dx, -pivot.dy);

    final beamPaint = Paint()
      ..color = _gold.withValues(
        alpha: PlannerVisualTokens.liftedAlpha(0.38 + progress * 0.22),
      )
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(115, 38), const Offset(275, 38), beamPaint);
    _drawPan(canvas, const Offset(115, 38), hasFeather: true);
    _drawPan(
      canvas,
      const Offset(275, 38),
      fillAlpha: PlannerVisualTokens.liftedAlpha(0.05 + progress * 0.09),
    );

    canvas
      ..restore()
      ..restore();
  }

  void _drawPan(
    Canvas canvas,
    Offset anchor, {
    bool hasFeather = false,
    double fillAlpha = 0,
  }) {
    final linePaint = Paint()
      ..color = _gold.withValues(alpha: PlannerVisualTokens.liftedAlpha(0.36))
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(anchor, Offset(anchor.dx, anchor.dy + 16), linePaint);

    final bowlPath = Path()
      ..moveTo(anchor.dx - 15, anchor.dy + 16)
      ..quadraticBezierTo(
        anchor.dx,
        anchor.dy + 28,
        anchor.dx + 15,
        anchor.dy + 16,
      );
    final bowlStroke = Paint()
      ..color = _gold.withValues(alpha: PlannerVisualTokens.liftedAlpha(0.48))
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bowlPath, bowlStroke);
    if (fillAlpha > 0) {
      final fillPath = Path.from(bowlPath)
        ..lineTo(anchor.dx - 15, anchor.dy + 16)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = _gold.withValues(alpha: fillAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    if (!hasFeather) return;

    final featherPath = Path()
      ..moveTo(anchor.dx, anchor.dy + 4)
      ..quadraticBezierTo(
        anchor.dx - 3,
        anchor.dy + 10,
        anchor.dx,
        anchor.dy + 16,
      )
      ..quadraticBezierTo(
        anchor.dx + 3,
        anchor.dy + 10,
        anchor.dx,
        anchor.dy + 4,
      )
      ..close();
    canvas.drawPath(
      featherPath,
      Paint()
        ..color = _gold.withValues(alpha: PlannerVisualTokens.liftedAlpha(0.58))
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      Offset(anchor.dx, anchor.dy + 6),
      Offset(anchor.dx, anchor.dy + 16),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MaatScalePainter oldDelegate) {
    return oldDelegate.tiltDegrees != tiltDegrees ||
        oldDelegate.progress != progress;
  }
}
