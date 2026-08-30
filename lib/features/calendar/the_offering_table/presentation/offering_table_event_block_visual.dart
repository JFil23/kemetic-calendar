import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const Duration kOfferingTableRippleCycle = Duration(milliseconds: 5400);
const Duration kOfferingTableRipplePhaseSeparation = Duration(
  milliseconds: 1800,
);
const double _offeringTableRipplePhaseOffset = 1 / 3;

enum OfferingTableBlockStage { personal, household, flowing }

enum OfferingTableBlockVisualState { empty, named, received }

OfferingTableBlockStage offeringTableBlockStageForDay(int dayNumber) {
  if (dayNumber <= 10) return OfferingTableBlockStage.personal;
  if (dayNumber <= 20) return OfferingTableBlockStage.household;
  return OfferingTableBlockStage.flowing;
}

/// Offering Table event-card face shared by its calendar surfaces.
///
/// Day View remains the interaction authority. This widget only presents the
/// canonical day title and authored prompt.
class OfferingTableEventBlockVisual extends StatelessWidget {
  const OfferingTableEventBlockVisual({
    super.key,
    required this.dayNumber,
    required this.title,
    required this.prompt,
    required this.height,
    this.width,
    this.isPreview = false,
    this.overlay,
    this.opacity = 1,
    this.dashedBorder = false,
    this.visualState,
    this.rippleAnimation,
  }) : assert(prompt != '');

  final int dayNumber;
  final String title;
  final String prompt;
  final double height;
  final double? width;
  final bool isPreview;
  final Widget? overlay;
  final double opacity;
  final bool dashedBorder;
  final Animation<double>? rippleAnimation;

  /// Presentation-only fixture seam. Day View intentionally leaves this null
  /// until completion-to-received behavior is approved separately.
  final OfferingTableBlockVisualState? visualState;

  OfferingTableBlockStage get stage => offeringTableBlockStageForDay(dayNumber);

  OfferingTableBlockVisualState get resolvedVisualState {
    final explicit = visualState;
    if (explicit != null) return explicit;
    return OfferingTableBlockVisualState.named;
  }

  @override
  Widget build(BuildContext context) {
    final state = resolvedVisualState;
    final isTall = height >= 70;
    final radius = BorderRadius.circular(8);
    final face = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isPreview
                  ? 0.34
                  : (state == OfferingTableBlockVisualState.received
                        ? 0.50
                        : 0.55),
            ),
            blurRadius: kIsWeb ? 12 : 18,
            offset: const Offset(0, 6),
          ),
          if (state != OfferingTableBlockVisualState.received)
            BoxShadow(
              color: const Color(
                0xFFD29660,
              ).withValues(alpha: isPreview ? 0.08 : 0.14),
              blurRadius: kIsWeb ? 12 : 16,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _OfferingTableCardSurface(dayNumber: dayNumber, state: state),
            Positioned(
              left: isTall ? 13 : 12,
              top: isTall ? 9 : 5,
              right: isTall ? 70 : 60,
              bottom: isTall ? 8 : 4,
              child: _OfferingTableCardText(
                dayNumber: dayNumber,
                title: title,
                prompt: prompt,
                state: state,
                tall: isTall,
              ),
            ),
            Positioned(
              right: isTall ? 10 : 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: isPreview ? 0.82 : 1,
                  child: OfferingTableCupVisual(
                    stage: stage,
                    state: state,
                    tall: isTall,
                    rippleAnimation: rippleAnimation,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _OfferingTableBorderPainter(
                    dashed: dashedBorder,
                    preview: isPreview,
                    received: state == OfferingTableBlockVisualState.received,
                  ),
                ),
              ),
            ),
            if (overlay != null) Positioned.fill(child: overlay!),
          ],
        ),
      ),
    );
    final previewFace = isPreview ? Opacity(opacity: 0.92, child: face) : face;
    if (opacity >= 0.999) return previewFace;
    return Opacity(opacity: opacity, child: previewFace);
  }
}

class _OfferingTableCardSurface extends StatelessWidget {
  const _OfferingTableCardSurface({
    required this.dayNumber,
    required this.state,
  });

  final int dayNumber;
  final OfferingTableBlockVisualState state;

  @override
  Widget build(BuildContext context) {
    final received = state == OfferingTableBlockVisualState.received;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-1, -0.45),
              end: const Alignment(1, 0.45),
              colors: received
                  ? const [
                      Color(0xFF160D07),
                      Color(0xFF3C2617),
                      Color(0xFF150D07),
                    ]
                  : const [
                      Color(0xFF20130A),
                      Color(0xFF6A4327),
                      Color(0xFF22150C),
                    ],
              stops: const [0, 0.52, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.92, -1.45),
              radius: 1.8,
              colors: [
                const Color(
                  0xFFFFD8A8,
                ).withValues(alpha: received ? 0.10 : 0.26),
                Colors.transparent,
              ],
              stops: const [0, 0.62],
            ),
          ),
        ),
        if (!received)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.76, 0.10),
                radius: 0.84,
                colors: [
                  const Color(0xFF96D6CE).withValues(
                    alpha: state == OfferingTableBlockVisualState.empty
                        ? 0.025
                        : 0.13,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _OfferingTableSpecklePainter(seed: dayNumber),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xC20A0603),
                Color(0x8A0A0603),
                Color(0x0F0A0603),
                Colors.transparent,
              ],
              stops: [0, 0.34, 0.64, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferingTableCardText extends StatelessWidget {
  const _OfferingTableCardText({
    required this.dayNumber,
    required this.title,
    required this.prompt,
    required this.state,
    required this.tall,
  });

  final int dayNumber;
  final String title;
  final String prompt;
  final OfferingTableBlockVisualState state;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final eyebrow =
        'THE OFFERING TABLE · DAY ${dayNumber.toString().padLeft(2, '0')}';
    final received = state == OfferingTableBlockVisualState.received;
    final promptText = '“${prompt.trim()}”';
    return ClipRect(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFFF1BF),
                Color(0xFFF8DA79),
                Color(0xFFFFF8D9),
                Color(0xFFF1CE67),
              ],
              stops: [0, 0.34, 0.66, 1],
            ).createShader(bounds),
            child: Text(
              eyebrow,
              key: const ValueKey<String>('offering-table-block-eyebrow'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'GentiumPlus',
                fontFamilyFallback: ['Georgia', 'serif'],
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: tall ? 2 : 1),
          Text(
            title,
            key: const ValueKey<String>('offering-table-block-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: received
                  ? const Color(0xFFD9CBBA)
                  : const Color(0xFFFFF6F1),
              fontFamily: 'CormorantGaramond',
              fontFamilyFallback: const ['GentiumPlus', 'Georgia', 'serif'],
              fontSize: tall ? 17 : 15.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.15,
              shadows: const [
                Shadow(color: Color(0x73FFFFFF), offset: Offset(-0.3, -0.3)),
                Shadow(color: Color(0x73040201), offset: Offset(0.5, 0.7)),
              ],
            ),
          ),
          if (tall) const SizedBox(height: 1),
          Text(
            promptText,
            key: const ValueKey<String>('offering-table-block-teaser'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: received
                  ? const Color(0xFFB08D63)
                  : const Color(0xFFF6D6B2),
              fontFamily: 'CormorantGaramond',
              fontFamilyFallback: const ['GentiumPlus', 'Georgia', 'serif'],
              fontSize: tall ? 15 : 14,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.25,
              height: 1.2,
              shadows: const [
                Shadow(color: Color(0x80040201), offset: Offset(0.5, 0.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OfferingTableCupVisual extends StatelessWidget {
  const OfferingTableCupVisual({
    super.key,
    required this.stage,
    required this.state,
    required this.tall,
    this.rippleAnimation,
  });

  final OfferingTableBlockStage stage;
  final OfferingTableBlockVisualState state;
  final bool tall;
  final Animation<double>? rippleAnimation;

  @override
  Widget build(BuildContext context) {
    final size = tall ? const Size(58, 60) : const Size(48, 50);
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _OfferingTableCupPainter(stage: stage, state: state),
              ),
              CustomPaint(
                painter: OfferingTableRipplePainter(
                  visible: state == OfferingTableBlockVisualState.named,
                  animation: state == OfferingTableBlockVisualState.named
                      ? rippleAnimation
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferingTableCupPainter extends CustomPainter {
  const _OfferingTableCupPainter({required this.stage, required this.state});

  final OfferingTableBlockStage stage;
  final OfferingTableBlockVisualState state;

  static const _designSize = Size(56, 52);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / _designSize.width,
      size.height / _designSize.height,
    );
    const bounds = Rect.fromLTWH(0, 0, 56, 52);
    final empty = state == OfferingTableBlockVisualState.empty;
    final received = state == OfferingTableBlockVisualState.received;

    canvas.drawOval(
      const Rect.fromLTWH(10, 35, 40, 12),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );

    const glowRect = Rect.fromLTWH(0, 3, 56, 44);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(
              0xFFCFF0E9,
            ).withValues(alpha: received ? 0 : (empty ? 0.02 : 0.40)),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );

    final clay = Path()
      ..moveTo(6, 25)
      ..arcToPoint(
        const Offset(50, 25),
        radius: const Radius.elliptical(22, 17),
        clockwise: false,
      )
      ..lineTo(42.6, 33.4)
      ..arcToPoint(
        const Offset(13.4, 33.4),
        radius: const Radius.elliptical(14.6, 11),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(
      clay,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.84, -0.88),
          end: const Alignment(0.84, 0.88),
          colors: _clayColors(stage),
          stops: const [0, 0.36, 0.78, 1],
        ).createShader(bounds),
    );

    _drawArcPath(
      canvas,
      start: const Offset(7.6, 29.6),
      end: const Offset(15.2, 36.6),
      radius: const Radius.elliptical(22, 17),
      clockwise: false,
      color: const Color(0x61FFDDB6),
      width: 1.5,
    );
    _drawArcPath(
      canvas,
      start: const Offset(48.4, 29.6),
      end: const Offset(40.8, 36.6),
      radius: const Radius.elliptical(22, 17),
      clockwise: true,
      color: const Color(0x73180D06),
      width: 2,
    );
    _drawArcPath(
      canvas,
      start: const Offset(13.4, 33.4),
      end: const Offset(42.6, 33.4),
      radius: const Radius.elliptical(14.6, 11),
      clockwise: false,
      color: const Color(0x80150C06),
      width: 1,
    );

    canvas.drawOval(
      const Rect.fromLTWH(9.4, 11.8, 37.2, 28.4),
      Paint()..color = const Color(0xFF150C07),
    );

    const waterRect = Rect.fromLTWH(11, 13.8, 34, 25.6);
    if (empty || received) {
      canvas.drawOval(
        waterRect,
        Paint()
          ..color = empty ? const Color(0xFF150C07) : const Color(0xFF1E1209),
      );
    } else {
      canvas.drawOval(
        waterRect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.32, -0.52),
            colors: [Color(0xFFE6F9F3), Color(0xFF7CBCB6), Color(0xFF174441)],
            stops: [0, 0.40, 1],
          ).createShader(waterRect),
      );
    }
    canvas.drawOval(
      waterRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = received
            ? const Color(0x809A7A4A)
            : const Color(0xFFE9FCF7).withValues(alpha: empty ? 0.08 : 0.40),
    );

    canvas.save();
    canvas.translate(20.8, 21);
    canvas.rotate(-20 * math.pi / 180);
    canvas.drawOval(
      const Rect.fromLTWH(-5.6, -2.6, 11.2, 5.2),
      Paint()
        ..color = const Color(
          0xFFF8FEFC,
        ).withValues(alpha: received ? 0.07 : (empty ? 0.04 : 0.44)),
    );
    canvas.restore();

    const rim = Rect.fromLTWH(6, 8, 44, 34);
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = const Color(0xFFF6D4A9),
    );
    _drawArcPath(
      canvas,
      start: const Offset(28, 8),
      end: const Offset(6, 25),
      radius: const Radius.elliptical(22, 17),
      clockwise: false,
      color: const Color(0xBFFFEBD0),
      width: 1.6,
    );
    _drawArcPath(
      canvas,
      start: const Offset(28, 42),
      end: const Offset(50, 25),
      radius: const Radius.elliptical(22, 17),
      clockwise: false,
      color: const Color(0x732A1710),
      width: 1.1,
    );
    canvas.restore();
  }

  static List<Color> _clayColors(OfferingTableBlockStage stage) {
    switch (stage) {
      case OfferingTableBlockStage.personal:
        return const [
          Color(0xFFF0BE8E),
          Color(0xFFA2673C),
          Color(0xFF4A2A18),
          Color(0xFF1B0F08),
        ];
      case OfferingTableBlockStage.household:
        return const [
          Color(0xFFDCA467),
          Color(0xFF8B5531),
          Color(0xFF3B2113),
          Color(0xFF1B0F08),
        ];
      case OfferingTableBlockStage.flowing:
        return const [
          Color(0xFFBC8B54),
          Color(0xFF6E4127),
          Color(0xFF2E1A0F),
          Color(0xFF1B0F08),
        ];
    }
  }

  static void _drawArcPath(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required Radius radius,
    required bool clockwise,
    required Color color,
    required double width,
  }) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..arcToPoint(end, radius: radius, clockwise: clockwise);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _OfferingTableCupPainter oldDelegate) {
    return oldDelegate.stage != stage || oldDelegate.state != state;
  }
}

@visibleForTesting
class OfferingTableRipplePainter extends CustomPainter {
  const OfferingTableRipplePainter({required this.visible, this.animation})
    : super(repaint: animation);

  final bool visible;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    canvas.save();
    canvas.scale(size.width / 56, size.height / 52);
    final driver = animation;
    final rings = driver == null
        ? const <({double scale, double opacity})>[
            (scale: 0.42, opacity: 0.18),
            (scale: 0.68, opacity: 0.13),
            (scale: 0.92, opacity: 0.08),
          ]
        : List<({double scale, double opacity})>.generate(3, (index) {
            final phase =
                (driver.value - (index * _offeringTableRipplePhaseOffset)) % 1;
            final easedScale = Curves.easeOutCubic.transform(phase);
            return (
              scale: 0.28 + (0.72 * easedScale),
              opacity: (0.20 * math.pow(1 - phase, 1.45)).toDouble(),
            );
          }, growable: false);
    for (final ring in rings) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(28, 26.6),
          width: 32.8 * ring.scale,
          height: 24.6 * ring.scale,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.85
          ..color = const Color(0xFFEBFDF8).withValues(alpha: ring.opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OfferingTableRipplePainter oldDelegate) {
    return oldDelegate.visible != visible ||
        !identical(oldDelegate.animation, animation);
  }
}

class _OfferingTableSpecklePainter extends CustomPainter {
  const _OfferingTableSpecklePainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed * 7919);
    for (var index = 0; index < 18; index++) {
      final warm = index % 3 != 1;
      final color = warm ? const Color(0xFFFFE2BE) : const Color(0xFFFFFFFF);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.25 + random.nextDouble() * 0.45,
        Paint()
          ..color = color.withValues(alpha: 0.03 + random.nextDouble() * 0.07),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OfferingTableSpecklePainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _OfferingTableBorderPainter extends CustomPainter {
  const _OfferingTableBorderPainter({
    required this.dashed,
    required this.preview,
    required this.received,
  });

  final bool dashed;
  final bool preview;
  final bool received;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(0.55),
          const Radius.circular(7.45),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1.2 : 0.9
      ..color = const Color(
        0xFFF6E4C9,
      ).withValues(alpha: received ? 0.36 : (preview ? 0.58 : 0.78));
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 4, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OfferingTableBorderPainter oldDelegate) {
    return oldDelegate.dashed != dashed ||
        oldDelegate.preview != preview ||
        oldDelegate.received != received;
  }
}
