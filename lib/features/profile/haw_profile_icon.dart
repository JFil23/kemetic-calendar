import 'package:flutter/material.dart';

/// Exact 20×20 profile-v2 icon geometry supplied by the visual contract.
///
/// The gear uses its authored 22×22 view box. All icons render at 18 logical
/// pixels by default, preserving the sprite's intended optical stroke weight.
enum HawProfileIconKind {
  heart,
  comment,
  share,
  save,
  together,
  edit,
  post,
  settings,
  chevronRight,
  caretUp,
  caretDown,
}

class HawProfileIcon extends StatelessWidget {
  const HawProfileIcon(
    this.kind, {
    super.key,
    required this.color,
    this.size = 18,
    this.filled = false,
  });

  final HawProfileIconKind kind;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _HawProfileIconPainter(
          kind: kind,
          color: color,
          filled: filled,
        ),
      ),
    );
  }
}

class _HawProfileIconPainter extends CustomPainter {
  const _HawProfileIconPainter({
    required this.kind,
    required this.color,
    required this.filled,
  });

  final HawProfileIconKind kind;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final viewBox = kind == HawProfileIconKind.settings ? 22.0 : 20.0;
    final scale = size.shortestSide / viewBox;
    canvas
      ..save()
      ..scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = kind == HawProfileIconKind.settings ? 1.5 : 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case HawProfileIconKind.heart:
        final path = Path()
          ..moveTo(10, 17)
          ..cubicTo(10, 17, 3.5, 13, 3.5, 8.4)
          ..arcToPoint(
            const Offset(10, 6.3),
            radius: const Radius.circular(3.6),
          )
          ..arcToPoint(
            const Offset(16.5, 8.4),
            radius: const Radius.circular(3.6),
          )
          ..cubicTo(16.5, 13, 10, 17, 10, 17)
          ..close();
        if (filled) {
          canvas.drawPath(path, paint..style = PaintingStyle.fill);
        } else {
          canvas.drawPath(path, paint);
        }
      case HawProfileIconKind.comment:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 4.5)
            ..lineTo(16.5, 4.5)
            ..lineTo(16.5, 13.5)
            ..lineTo(9.5, 13.5)
            ..lineTo(5.5, 16.5)
            ..lineTo(5.5, 13.5)
            ..lineTo(3.5, 13.5)
            ..close(),
          paint,
        );
      case HawProfileIconKind.share:
        canvas.drawPath(
          Path()
            ..moveTo(10, 3.5)
            ..lineTo(10, 12.5)
            ..moveTo(6.5, 6.8)
            ..lineTo(10, 3.4)
            ..lineTo(13.5, 6.8)
            ..moveTo(4.5, 11.5)
            ..lineTo(4.5, 16.5)
            ..lineTo(15.5, 16.5)
            ..lineTo(15.5, 11.5),
          paint,
        );
      case HawProfileIconKind.save:
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 3.5)
            ..lineTo(14.5, 3.5)
            ..lineTo(14.5, 16.5)
            ..lineTo(10, 13.3)
            ..lineTo(5.5, 16.5)
            ..close(),
          paint,
        );
      case HawProfileIconKind.together:
        canvas
          ..drawCircle(const Offset(7, 7.5), 2.6, paint)
          ..drawCircle(const Offset(13.5, 7.5), 2.6, paint)
          ..drawPath(
            Path()
              ..moveTo(2.5, 16)
              ..cubicTo(3.1, 13.2, 4.9, 12, 7, 12)
              ..cubicTo(9.1, 12, 10.9, 13.2, 11.5, 16)
              ..moveTo(9.5, 16)
              ..cubicTo(10, 13.6, 11.5, 12.4, 13.5, 12.4)
              ..cubicTo(15.5, 12.4, 17, 13.6, 17.5, 16),
            paint,
          );
      case HawProfileIconKind.edit:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 16.5)
            ..lineTo(6.7, 16.5)
            ..lineTo(14.7, 8.5)
            ..lineTo(11.5, 5.3)
            ..lineTo(3.5, 13.3)
            ..close()
            ..moveTo(12.6, 4.4)
            ..lineTo(14.2, 2.8)
            ..lineTo(17.4, 6)
            ..lineTo(15.8, 7.6),
          paint,
        );
      case HawProfileIconKind.post:
        canvas.drawPath(
          Path()
            ..moveTo(10, 3.2)
            ..lineTo(10, 12.6)
            ..moveTo(6.3, 6.7)
            ..lineTo(10, 3)
            ..lineTo(13.7, 6.7)
            ..moveTo(4.3, 12.8)
            ..lineTo(4.3, 16.8)
            ..lineTo(15.7, 16.8)
            ..lineTo(15.7, 12.8),
          paint,
        );
      case HawProfileIconKind.settings:
        canvas
          ..drawCircle(const Offset(11, 11), 3.2, paint)
          ..drawPath(
            Path()
              ..moveTo(11, 2.2)
              ..lineTo(11, 4.6)
              ..moveTo(11, 17.4)
              ..lineTo(11, 19.8)
              ..moveTo(2.2, 11)
              ..lineTo(4.6, 11)
              ..moveTo(17.4, 11)
              ..lineTo(19.8, 11)
              ..moveTo(4.8, 4.8)
              ..lineTo(6.5, 6.5)
              ..moveTo(15.5, 15.5)
              ..lineTo(17.2, 17.2)
              ..moveTo(17.2, 4.8)
              ..lineTo(15.5, 6.5)
              ..moveTo(6.5, 15.5)
              ..lineTo(4.8, 17.2),
            paint,
          );
      case HawProfileIconKind.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(7.8, 4.5)
            ..lineTo(13, 10)
            ..lineTo(7.8, 15.5),
          paint,
        );
      case HawProfileIconKind.caretUp:
        canvas.drawPath(
          Path()
            ..moveTo(4.8, 12.6)
            ..lineTo(10, 7.2)
            ..lineTo(15.2, 12.6),
          paint,
        );
      case HawProfileIconKind.caretDown:
        canvas.drawPath(
          Path()
            ..moveTo(4.8, 7.4)
            ..lineTo(10, 12.8)
            ..lineTo(15.2, 7.4),
          paint,
        );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HawProfileIconPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.color != color ||
        oldDelegate.filled != filled;
  }
}
