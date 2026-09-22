import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/flow_appearance.dart';
import '../../../data/flow_appearance_store.dart';

enum UserFlowAppearanceSurface { standard, fullDetail, daySheet, timelineBadge }

@visibleForTesting
double resolveUserFlowMerkhetProgress({
  required double completedOccurrences,
  required int totalOccurrences,
}) {
  if (totalOccurrences <= 0 || completedOccurrences <= 0) return 0;
  return (completedOccurrences / totalOccurrences).clamp(0.0, 1.0);
}

@visibleForTesting
double resolvePalmCountLitMarks({
  required double completedOccurrences,
  required int displayedMarkCount,
}) {
  if (completedOccurrences <= 0 || displayedMarkCount <= 0) return 0;
  final position = completedOccurrences % displayedMarkCount;
  if (position == 0) return displayedMarkCount.toDouble();
  return position;
}

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
    this.surface = UserFlowAppearanceSurface.standard,
    this.animationRevision = 0,
    this.animationFromCompletedOccurrences,
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
  final UserFlowAppearanceSurface surface;
  final int animationRevision;
  final int? animationFromCompletedOccurrences;

  @override
  Widget build(BuildContext context) {
    final hasImage = localImageBytes != null || appearance.hasImage;
    final hasSign = appearance.hasSign;
    final showImage =
        hasImage && surface != UserFlowAppearanceSurface.timelineBadge;
    final imageOpacity = switch (surface) {
      UserFlowAppearanceSurface.daySheet => hasSign ? 0.24 : 1.0,
      _ => 1.0,
    };
    final signSize = switch (surface) {
      UserFlowAppearanceSurface.fullDetail => math.min(152.0, height * 0.54),
      UserFlowAppearanceSurface.daySheet => math.min(136.0, height * 0.72),
      UserFlowAppearanceSurface.timelineBadge => math.min(31.0, height * 0.78),
      UserFlowAppearanceSurface.standard => compact ? 31.0 : 78.0,
    };
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(compact ? 10 : 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showImage) ...[
              const ColoredBox(color: Color(0xFF050403)),
              Opacity(
                key: const ValueKey('user-flow-appearance-image-opacity'),
                opacity: imageOpacity,
                child: _FlowImageLayer(
                  key: const ValueKey('user-flow-appearance-image-layer'),
                  objectPath: appearance.imageObjectPath,
                  localImageBytes: localImageBytes,
                  accent: accent,
                ),
              ),
            ] else
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
            if (showImage)
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
            if (showImage)
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
            if (showImage)
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
                  compact: surface == UserFlowAppearanceSurface.timelineBadge,
                  size: signSize,
                  completedOccurrences: completedOccurrences,
                  totalOccurrences: totalOccurrences,
                  animationRevision: animationRevision,
                  animationFromCompletedOccurrences:
                      animationFromCompletedOccurrences,
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
    if (!appearance.hasSign) {
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
        surface: UserFlowAppearanceSurface.timelineBadge,
        completedOccurrences: completedOccurrences,
        totalOccurrences: totalOccurrences,
      ),
    );
  }
}

class FlowSignVisual extends StatefulWidget {
  const FlowSignVisual({
    super.key,
    required this.kind,
    required this.color,
    this.label,
    this.compact = false,
    this.size,
    this.completedOccurrences = 0,
    this.totalOccurrences = 0,
    this.animationRevision = 0,
    this.animationFromCompletedOccurrences,
  });

  final FlowSignKind kind;
  final Color color;
  final String? label;
  final bool compact;
  final double? size;
  final int completedOccurrences;
  final int totalOccurrences;
  final int animationRevision;
  final int? animationFromCompletedOccurrences;

  @override
  State<FlowSignVisual> createState() => _FlowSignVisualState();
}

class _FlowSignVisualState extends State<FlowSignVisual>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1000);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didUpdateWidget(covariant FlowSignVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationRevision != oldWidget.animationRevision &&
        widget.animationRevision > 0) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? (widget.compact ? 31.0 : 78.0);
    return AnimatedBuilder(
      key: ValueKey<String>(
        'user-flow-merkhet-animation-${widget.kind.name}-${widget.animationRevision}',
      ),
      animation: _controller,
      builder: (context, _) {
        final animationValue = Curves.easeInOutCubic.transform(
          _controller.value,
        );
        final from =
            (widget.animationFromCompletedOccurrences ??
                    widget.completedOccurrences)
                .toDouble();
        final completed = _controller.isAnimating || _controller.value > 0
            ? from + (widget.completedOccurrences - from) * animationValue
            : widget.completedOccurrences.toDouble();
        final pulse = _controller.isAnimating
            ? math.sin(math.pi * _controller.value).clamp(0.0, 1.0)
            : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: _FlowSignPainter(
                  widget.kind,
                  widget.color,
                  completedOccurrences: completed,
                  totalOccurrences: widget.totalOccurrences,
                  pulse: pulse,
                ),
              ),
            ),
            if (!widget.compact && widget.label?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                widget.label!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.color.withValues(alpha: 0.92),
                  fontFamily: 'GentiumPlus',
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ],
        );
      },
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
    final store = FlowAppearanceStore(Supabase.instance.client);
    final cachedBytes = store.cachedImageBytes(path);
    if (cachedBytes != null) {
      return Image.memory(cachedBytes, fit: BoxFit.cover);
    }
    return FutureBuilder<Uint8List>(
      future: store.imageBytes(path),
      builder: (context, snapshot) {
        final hydratedBytes = snapshot.data;
        if (hydratedBytes == null) {
          return ColoredBox(color: accent.withValues(alpha: 0.12));
        }
        return Image.memory(hydratedBytes, fit: BoxFit.cover);
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
    required this.pulse,
  });

  final FlowSignKind kind;
  final Color color;
  final double completedOccurrences;
  final int totalOccurrences;
  final double pulse;

  double get _progress {
    return resolveUserFlowMerkhetProgress(
      completedOccurrences: completedOccurrences,
      totalOccurrences: totalOccurrences,
    );
  }

  Paint _glowPaint(double width) => Paint()
    ..color = color.withValues(alpha: 0.58 * pulse)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

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
        final completed = resolvePalmCountLitMarks(
          completedOccurrences: completedOccurrences,
          displayedMarkCount: count,
        );
        final columns = count <= 7 ? count : 7;
        final rows = (count / columns).ceil();
        final xGap = w * 0.62 / math.max(1, columns - 1);
        final yGap = h * 0.55 / math.max(1, rows - 1);
        for (var i = 0; i < count; i++) {
          final column = i % columns;
          final row = i ~/ columns;
          final completion = (completed - i).clamp(0.0, 1.0);
          final mark = Paint()
            ..color = color.withValues(alpha: 0.22 + 0.74 * completion)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.15, size.width * 0.028)
            ..strokeCap = StrokeCap.round;
          final x = w * 0.19 + column * xGap;
          final y = rows == 1 ? h * 0.5 : h * 0.23 + row * yGap;
          if (pulse > 0 && i == math.max(0, completed.ceil() - 1)) {
            canvas.drawLine(
              Offset(x, y - h * 0.055),
              Offset(x, y + h * 0.055),
              _glowPaint(math.max(4, size.width * 0.09)),
            );
          }
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
        final sweep = math.pi * 2 * _progress;
        if (pulse > 0 && sweep > 0) {
          canvas.drawArc(
            ring,
            -math.pi / 2,
            sweep,
            false,
            _glowPaint(math.max(4, p.strokeWidth * 2.8)),
          );
        }
        canvas.drawArc(ring, -math.pi / 2, sweep, false, p);
        if (sweep > 0) {
          final angle = -math.pi / 2 + sweep;
          final tip = Offset(
            ring.center.dx + ring.width / 2 * math.cos(angle),
            ring.center.dy + ring.height / 2 * math.sin(angle),
          );
          canvas.drawCircle(
            tip,
            math.max(1.8, size.width * (0.022 + pulse * 0.018)),
            Paint()
              ..color = color.withValues(alpha: 0.86)
              ..style = PaintingStyle.fill,
          );
        }
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
          if (pulse > 0) {
            final surfaceY = h * (0.8 - 0.48 * _progress);
            canvas.drawLine(
              Offset(w * 0.29, surfaceY),
              Offset(w * 0.71, surfaceY),
              _glowPaint(math.max(3, p.strokeWidth * 2.4)),
            );
          }
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
        canvas.drawPath(path, dim);
        if (_progress > 0) {
          for (final metric in path.computeMetrics()) {
            final traveled = metric.length * _progress;
            final revealed = metric.extractPath(0, traveled);
            if (pulse > 0 && traveled > 0) {
              canvas.drawPath(
                metric.extractPath(math.max(0, traveled - w * 0.16), traveled),
                _glowPaint(math.max(4, p.strokeWidth * 2.6)),
              );
            }
            canvas.drawPath(revealed, p);
          }
        }
      case FlowSignKind.papyrus:
        final stalks = const [-0.25, -0.12, 0.0, 0.12, 0.25];
        final growth = _progress * stalks.length;
        final guide = Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < stalks.length; i++) {
          final dx = stalks[i];
          final stalkGrowth = (growth - i).clamp(0.0, 1.0);
          final stalkPaint = Paint()
            ..color = color.withValues(alpha: 0.2 + 0.76 * stalkGrowth)
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.strokeWidth
            ..strokeCap = StrokeCap.round;
          final base = Offset(w * (0.5 + dx * 0.22), h * 0.78);
          final tip = Offset(w * (0.5 + dx), h * 0.15);
          final grownTip = Offset.lerp(base, tip, stalkGrowth)!;
          canvas.drawLine(base, tip, guide);
          if (pulse > 0 && i == math.max(0, growth.ceil() - 1)) {
            canvas.drawLine(
              base,
              grownTip,
              _glowPaint(math.max(4, p.strokeWidth * 2.7)),
            );
          }
          canvas.drawLine(base, grownTip, stalkPaint);
        }
        canvas.drawLine(
          Offset(w * 0.3, h * 0.78),
          Offset(w * 0.7, h * 0.78),
          p,
        );
      case FlowSignKind.kheper:
        final stage = (_progress * 4).ceil().clamp(0, 4);
        final activeStage = math.max(1, stage);
        final guide = Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round;
        final body = Rect.fromLTWH(w * 0.32, h * 0.3, w * 0.36, h * 0.38);
        if (pulse > 0 && activeStage == 1) {
          canvas.drawOval(body, _glowPaint(math.max(4, p.strokeWidth * 2.8)));
        }
        canvas.drawOval(body, stage >= 1 ? p : guide);
        if (pulse > 0 && activeStage == 2) {
          final glow = _glowPaint(math.max(4, p.strokeWidth * 2.8));
          canvas.drawLine(
            Offset(w * 0.2, h * 0.22),
            Offset(w * 0.38, h * 0.38),
            glow,
          );
          canvas.drawLine(
            Offset(w * 0.8, h * 0.22),
            Offset(w * 0.62, h * 0.38),
            glow,
          );
        }
        canvas.drawLine(
          Offset(w * 0.2, h * 0.22),
          Offset(w * 0.38, h * 0.38),
          stage >= 2 ? p : guide,
        );
        if (pulse > 0 && activeStage == 3) {
          final glow = _glowPaint(math.max(4, p.strokeWidth * 2.8));
          canvas.drawLine(
            Offset(w * 0.18, h * 0.7),
            Offset(w * 0.38, h * 0.58),
            glow,
          );
          canvas.drawLine(
            Offset(w * 0.82, h * 0.7),
            Offset(w * 0.62, h * 0.58),
            glow,
          );
        }
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
        if (pulse > 0 && activeStage == 4) {
          canvas.drawArc(
            Rect.fromLTWH(w * 0.37, h * 0.08, w * 0.26, h * 0.2),
            math.pi,
            math.pi,
            false,
            _glowPaint(math.max(4, p.strokeWidth * 2.8)),
          );
        }
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
      oldDelegate.totalOccurrences != totalOccurrences ||
      oldDelegate.pulse != pulse;
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
