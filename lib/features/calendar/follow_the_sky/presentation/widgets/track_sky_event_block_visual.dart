import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../calendar_event_visual_style.dart';

/// Shared production Track Sky event-card visual body for Day View and Follow Sky.
class TrackSkyEventBlockVisual extends StatelessWidget {
  const TrackSkyEventBlockVisual({
    super.key,
    required this.title,
    required this.graphic,
    required this.height,
    this.width,
    this.compact = false,
    this.isPreview = false,
    this.child,
    this.overlay,
    this.opacity = 1,
    this.dashedBorder = false,
  });

  final String title;
  final CalendarEventGraphicStyle graphic;
  final double height;
  final double? width;
  final bool compact;
  final bool isPreview;
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
            color: graphic.glowColor.withValues(
              alpha: isPreview ? 0.08 : 0.14,
            ),
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
                    alpha: dashedBorder
                        ? 0.55
                        : (isPreview ? 0.7 : 0.92),
                  ),
                  width: dashedBorder ? 1.2 : 0.9,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ...buildTrackSkyCardStars(
                  seed: title,
                  tint: graphic.accentColor,
                  compact: compact,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xA804060C),
                          const Color(0x7A04060C),
                          const Color(0x1804060C),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.34, 0.62, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 7,
                  child: Opacity(
                    opacity: isPreview ? 0.82 : 1.0,
                    child: buildTrackSkyCardAccent(
                      graphic,
                      title,
                      size: math.min(height - 18, 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

List<Widget> buildTrackSkyCardStars({
  required String seed,
  required Color tint,
  required bool compact,
}) {
  final random = math.Random(seed.hashCode & 0x7fffffff);
  final count = compact ? 7 : 11;
  return List<Widget>.generate(count, (index) {
    final x = (-0.88 + random.nextDouble() * 1.76).clamp(-1.0, 1.0);
    final y = (-0.86 + random.nextDouble() * 1.72).clamp(-1.0, 1.0);
    final size = compact
        ? 0.9 + random.nextDouble() * 1.2
        : 1.0 + random.nextDouble() * 1.9;
    final starOpacity = 0.2 + random.nextDouble() * 0.42;
    final color = (index % 3 == 0 ? tint : Colors.white).withValues(
      alpha: starOpacity,
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(x.toDouble(), y.toDouble()),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color, blurRadius: compact ? 1.2 : 2.8),
              ],
            ),
          ),
        ),
      ),
    );
  });
}

Widget buildTrackSkyCardAccent(
  CalendarEventGraphicStyle spec,
  String title, {
  double size = 24,
}) {
  final lower = title.toLowerCase();

  Widget planet({
    required Color color,
    double? diameter,
    BoxBorder? border,
    List<BoxShadow>? shadow,
  }) {
    final d = diameter ?? size;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border,
        boxShadow: shadow,
      ),
    );
  }

  switch (spec.trackSkyKind) {
    case null:
      return const SizedBox.shrink();
    case CalendarTrackSkyCardKind.moon:
      return planet(
        color: spec.accentColor,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: 10,
          ),
        ],
      );
    case CalendarTrackSkyCardKind.lunarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            planet(
              color: spec.accentColor,
              shadow: [
                BoxShadow(
                  color: spec.glowColor.withValues(alpha: 0.38),
                  blurRadius: 9,
                ),
              ],
            ),
            Positioned(
              left: size * (lower.contains('penumbral') ? 0.16 : 0.28),
              top: size * 0.05,
              child: planet(
                color: const Color(0xCC03050B),
                diameter: size * 0.82,
              ),
            ),
          ],
        ),
      );
    case CalendarTrackSkyCardKind.solarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            planet(
              color: Colors.transparent,
              border: Border.all(color: spec.accentColor, width: 2),
              shadow: [
                BoxShadow(
                  color: spec.glowColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            planet(color: const Color(0xFF04060D), diameter: size * 0.64),
          ],
        ),
      );
    case CalendarTrackSkyCardKind.meteor:
      return SizedBox(
        width: size + 10,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: 5,
              child: planet(
                color: Colors.white,
                diameter: size * 0.28,
                shadow: [
                  BoxShadow(
                    color: spec.glowColor.withValues(alpha: 0.58),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 8,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: size * 0.85,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        spec.accentColor.withValues(alpha: 0.2),
                        spec.accentColor.withValues(alpha: 0.72),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.34, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    case CalendarTrackSkyCardKind.planet:
      if (lower.contains('saturn')) {
        return SizedBox(
          width: size + 6,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: size + 6,
                  height: 8,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: spec.accentSecondaryColor.withValues(alpha: 0.84),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              planet(color: spec.accentColor, diameter: size * 0.62),
            ],
          ),
        );
      }
      if (lower.contains('conjunction')) {
        return SizedBox(
          width: size + 8,
          height: size,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 2,
                child: planet(
                  color: spec.accentSecondaryColor,
                  diameter: size * 0.46,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 2,
                child: planet(color: spec.accentColor, diameter: size * 0.62),
              ),
            ],
          ),
        );
      }
      if (lower.contains('parade')) {
        final colors = [
          spec.accentColor,
          spec.accentSecondaryColor,
          const Color(0xFFE7C8FF),
        ];
        return SizedBox(
          width: size + 10,
          height: size,
          child: Stack(
            children: [
              for (int i = 0; i < colors.length; i++)
                Positioned(
                  left: i * 7.0,
                  top: i.isEven ? 1.5 : 5,
                  child: planet(color: colors[i], diameter: 5.2),
                ),
            ],
          ),
        );
      }
      return planet(
        color: spec.accentColor,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: 8,
          ),
        ],
      );
    case CalendarTrackSkyCardKind.solarSeason:
      return SizedBox(
        width: size + 8,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Container(
                height: 1.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      spec.accentSecondaryColor.withValues(alpha: 0.48),
                      spec.accentSecondaryColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 3,
              bottom: 2,
              child: planet(
                color: spec.accentColor,
                diameter: 8,
                shadow: [
                  BoxShadow(
                    color: spec.glowColor.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    case CalendarTrackSkyCardKind.genericSky:
      return planet(
        color: spec.accentSecondaryColor,
        diameter: 8,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: 8,
          ),
        ],
      );
  }
}
