import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/flow_appearance.dart';
import '../../../data/flow_appearance_store.dart';

class UserFlowAppearanceHero extends StatelessWidget {
  const UserFlowAppearanceHero({
    super.key,
    required this.appearance,
    required this.accent,
    this.localImageBytes,
    this.height = 140,
    this.compact = false,
    this.completedOccurrences = 0,
    this.totalOccurrences = 0,
    this.showProgressFooter = false,
    this.borderRadius,
  });

  final FlowAppearance appearance;
  final Color accent;
  final Uint8List? localImageBytes;
  final double height;
  final bool compact;
  final int completedOccurrences;
  final int totalOccurrences;
  final bool showProgressFooter;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasImage = localImageBytes != null || appearance.hasImage;
    final hasSign = appearance.hasSign;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(compact ? 10 : 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              _FlowImageLayer(
                key: const ValueKey('user-flow-appearance-image-layer'),
                objectPath: appearance.imageObjectPath,
                localImageBytes: localImageBytes,
                accent: accent,
              )
            else
              DecoratedBox(
                key: const ValueKey('user-flow-appearance-fallback-layer'),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.1, -0.2),
                    radius: 1.15,
                    colors: [
                      accent.withValues(alpha: 0.18),
                      const Color(0xFF080705),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            if (hasImage)
              const DecoratedBox(
                key: ValueKey('user-flow-appearance-treatment-layer'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x42000000),
                      Color(0x66000000),
                      Color(0xF0000000),
                    ],
                    stops: [0, 0.56, 1],
                  ),
                ),
              ),
            if (hasImage)
              const DecoratedBox(
                key: ValueKey('user-flow-appearance-vignette-layer'),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.12),
                    radius: 1.04,
                    colors: [Color(0x00000000), Color(0xB8000000)],
                    stops: [0.42, 1],
                  ),
                ),
              ),
            if (hasImage)
              const Positioned.fill(
                key: ValueKey('user-flow-appearance-grain-layer'),
                child: IgnorePointer(
                  child: CustomPaint(painter: _FlowImageGrainPainter()),
                ),
              ),
            if (hasSign)
              Align(
                key: const ValueKey('user-flow-appearance-sign-layer'),
                alignment: showProgressFooter
                    ? const Alignment(0, -0.24)
                    : Alignment.center,
                child: FlowSignVisual(
                  kind: appearance.signKind!,
                  label: showProgressFooter ? null : appearance.signLabel,
                  color: accent,
                  compact: compact,
                  completedOccurrences: completedOccurrences,
                  totalOccurrences: totalOccurrences,
                ),
              ),
            if (!compact && showProgressFooter)
              Positioned(
                key: const ValueKey('user-flow-appearance-progress-footer'),
                left: 18,
                right: 18,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        appearance.signLabel?.trim().isNotEmpty == true
                            ? appearance.signLabel!.trim()
                            : _flowSignProgressNoun(appearance.signKind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(
                            0xFFE8D9C3,
                          ).withValues(alpha: 0.82),
                          fontFamily: 'GentiumPlus',
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    if (totalOccurrences > 0)
                      Text(
                        '${completedOccurrences.clamp(0, totalOccurrences)} OF $totalOccurrences',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.92),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UserFlowAppearanceBadge extends StatelessWidget {
  const UserFlowAppearanceBadge({
    super.key,
    required this.appearance,
    required this.accent,
    this.localImageBytes,
    this.size = 40,
    this.completedOccurrences = 0,
    this.totalOccurrences = 0,
  });

  final FlowAppearance appearance;
  final Color accent;
  final Uint8List? localImageBytes;
  final double size;
  final int completedOccurrences;
  final int totalOccurrences;

  @override
  Widget build(BuildContext context) {
    if (appearance.isEmpty && localImageBytes == null) {
      return const SizedBox.shrink();
    }
    return SizedBox.square(
      dimension: size,
      child: UserFlowAppearanceHero(
        appearance: appearance,
        accent: accent,
        localImageBytes: localImageBytes,
        height: size,
        compact: true,
        completedOccurrences: completedOccurrences,
        totalOccurrences: totalOccurrences,
      ),
    );
  }
}

class FlowSignVisual extends StatelessWidget {
  const FlowSignVisual({
    super.key,
    required this.kind,
    required this.color,
    this.label,
    this.compact = false,
    this.completedOccurrences = 0,
    this.totalOccurrences = 0,
  });

  final FlowSignKind kind;
  final Color color;
  final String? label;
  final bool compact;
  final int completedOccurrences;
  final int totalOccurrences;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 31.0 : 78.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _FlowSignPainter(
              kind,
              color,
              completedOccurrences: completedOccurrences,
              totalOccurrences: totalOccurrences,
            ),
          ),
        ),
        if (!compact && label?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            label!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.92),
              fontFamily: 'GentiumPlus',
              fontSize: 15,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ],
    );
  }
}

class _FlowImageLayer extends StatelessWidget {
  const _FlowImageLayer({
    super.key,
    required this.objectPath,
    required this.localImageBytes,
    required this.accent,
  });

  final String? objectPath;
  final Uint8List? localImageBytes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bytes = localImageBytes;
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
    final path = objectPath?.trim();
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future: FlowAppearanceStore(Supabase.instance.client).signedUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) {
          return ColoredBox(color: accent.withValues(alpha: 0.12));
        }
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              ColoredBox(color: accent.withValues(alpha: 0.12)),
        );
      },
    );
  }
}

class _FlowImageGrainPainter extends CustomPainter {
  const _FlowImageGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0x10FFFFFF);
    final dark = Paint()..color = const Color(0x14000000);
    // A deterministic, low-opacity grain keeps every render and shared copy
    // visually identical without persisting a second processed bitmap.
    var seed = 0x6D2B79F5;
    for (var i = 0; i < 190; i++) {
      seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
      final x = (seed % 10000) / 10000 * size.width;
      seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
      final y = (seed % 10000) / 10000 * size.height;
      canvas.drawCircle(Offset(x, y), 0.45, i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowImageGrainPainter oldDelegate) => false;
}

class _FlowSignPainter extends CustomPainter {
  const _FlowSignPainter(
    this.kind,
    this.color, {
    required this.completedOccurrences,
    required this.totalOccurrences,
  });

  final FlowSignKind kind;
  final Color color;
  final int completedOccurrences;
  final int totalOccurrences;

  double get _progress {
    if (totalOccurrences <= 0) return 0;
    return (completedOccurrences / totalOccurrences).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.3, size.width * 0.035)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case FlowSignKind.palmCount:
        final count = totalOccurrences > 0 ? totalOccurrences.clamp(1, 30) : 4;
        final completed = totalOccurrences > 0
            ? ((completedOccurrences.clamp(0, totalOccurrences) /
                          totalOccurrences) *
                      count)
                  .round()
            : count;
        final columns = count <= 7 ? count : 7;
        final rows = (count / columns).ceil();
        final xGap = w * 0.62 / math.max(1, columns - 1);
        final yGap = h * 0.55 / math.max(1, rows - 1);
        for (var i = 0; i < count; i++) {
          final column = i % columns;
          final row = i ~/ columns;
          final mark = Paint()
            ..color = color.withValues(alpha: i < completed ? 0.96 : 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.15, size.width * 0.028)
            ..strokeCap = StrokeCap.round;
          final x = w * 0.19 + column * xGap;
          final y = rows == 1 ? h * 0.5 : h * 0.23 + row * yGap;
          canvas.drawLine(
            Offset(x, y - h * 0.055),
            Offset(x, y + h * 0.055),
            mark,
          );
        }
      case FlowSignKind.shen:
        final ring = Rect.fromLTWH(w * 0.2, h * 0.16, w * 0.6, h * 0.58);
        final dim = Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawOval(ring, dim);
        final sweep = totalOccurrences > 0
            ? math.pi * 2 * _progress
            : math.pi * 2;
        canvas.drawArc(ring, -math.pi / 2, sweep, false, p);
        canvas.drawLine(
          Offset(w * 0.35, h * 0.78),
          Offset(w * 0.65, h * 0.78),
          p,
        );
      case FlowSignKind.gatheringVessel:
        final path = Path()
          ..moveTo(w * 0.22, h * 0.28)
          ..quadraticBezierTo(w * 0.28, h * 0.8, w * 0.5, h * 0.82)
          ..quadraticBezierTo(w * 0.72, h * 0.8, w * 0.78, h * 0.28)
          ..close();
        canvas.drawPath(path, p);
        if (totalOccurrences > 0 && _progress > 0) {
          canvas.save();
          canvas.clipPath(path);
          canvas.drawRect(
            Rect.fromLTRB(
              w * 0.2,
              h * (0.8 - 0.48 * _progress),
              w * 0.8,
              h * 0.82,
            ),
            Paint()..color = color.withValues(alpha: 0.28),
          );
          canvas.restore();
        }
        canvas.drawLine(
          Offset(w * 0.18, h * 0.28),
          Offset(w * 0.82, h * 0.28),
          p,
        );
      case FlowSignKind.riverPath:
        final path = Path()
          ..moveTo(w * 0.18, h * 0.25)
          ..cubicTo(w * 0.8, h * 0.13, w * 0.22, h * 0.55, w * 0.8, h * 0.44)
          ..cubicTo(w * 0.22, h * 0.34, w * 0.8, h * 0.8, w * 0.2, h * 0.76);
        final dim = Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, totalOccurrences > 0 ? dim : p);
        if (totalOccurrences > 0) {
          for (final metric in path.computeMetrics()) {
            canvas.drawPath(
              metric.extractPath(0, metric.length * _progress),
              p,
            );
          }
        }
      case FlowSignKind.papyrus:
        final stalks = const [-0.25, -0.12, 0.0, 0.12, 0.25];
        final grown = totalOccurrences > 0
            ? (_progress * stalks.length).ceil()
            : stalks.length;
        for (var i = 0; i < stalks.length; i++) {
          final dx = stalks[i];
          final stalkPaint = Paint()
            ..color = color.withValues(alpha: i < grown ? 0.96 : 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.strokeWidth
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(w * (0.5 + dx * 0.22), h * 0.78),
            Offset(w * (0.5 + dx), h * 0.15),
            stalkPaint,
          );
        }
        canvas.drawLine(
          Offset(w * 0.3, h * 0.78),
          Offset(w * 0.7, h * 0.78),
          p,
        );
      case FlowSignKind.kheper:
        final stage = totalOccurrences <= 0
            ? 4
            : (_progress * 4).ceil().clamp(0, 4);
        final guide = Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round;
        final body = Rect.fromLTWH(w * 0.32, h * 0.3, w * 0.36, h * 0.38);
        canvas.drawOval(body, stage >= 1 ? p : guide);
        canvas.drawLine(
          Offset(w * 0.2, h * 0.22),
          Offset(w * 0.38, h * 0.38),
          stage >= 2 ? p : guide,
        );
        canvas.drawLine(
          Offset(w * 0.8, h * 0.22),
          Offset(w * 0.62, h * 0.38),
          stage >= 2 ? p : guide,
        );
        canvas.drawLine(
          Offset(w * 0.18, h * 0.7),
          Offset(w * 0.38, h * 0.58),
          stage >= 3 ? p : guide,
        );
        canvas.drawLine(
          Offset(w * 0.82, h * 0.7),
          Offset(w * 0.62, h * 0.58),
          stage >= 3 ? p : guide,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * 0.37, h * 0.08, w * 0.26, h * 0.2),
          math.pi,
          math.pi,
          false,
          stage >= 4 ? p : guide,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _FlowSignPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.completedOccurrences != completedOccurrences ||
      oldDelegate.totalOccurrences != totalOccurrences;
}

String _flowSignProgressNoun(FlowSignKind? kind) => switch (kind) {
  FlowSignKind.palmCount => 'completed occurrences',
  FlowSignKind.shen => 'whole cycle',
  FlowSignKind.gatheringVessel => 'accumulated progress',
  FlowSignKind.riverPath => 'distance traveled',
  FlowSignKind.papyrus => 'growth reached',
  FlowSignKind.kheper => 'transformation stage',
  null => 'flow progress',
};
