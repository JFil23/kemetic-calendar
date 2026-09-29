import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../calendar_event_visual_style.dart';
import '../../domain/sky_graphic_astronomy.dart';
import '../../domain/sky_catalog.dart';
import '../../services/sky_catalog_repository.dart';
import '../../../presentation/graphic_event_block_shell.dart';

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
    this.skyEventId,
    this.astronomy,
  });

  final String title;
  final String? skyEventId;
  final SkyGraphicAstronomy? astronomy;
  static Future<SkyCatalog>? _catalog;
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
    if (astronomy != null || skyEventId == null) return _build(astronomy);
    return FutureBuilder<SkyCatalog>(
      future: _catalog ??= SkyCatalogRepository().load(),
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        final event = catalog?.byId(skyEventId!);
        final facts = event == null
            ? null
            : event.mergedIntoId != null
            ? event.graphicAstronomy
            : catalog!.observingNight(event).windowSource.graphicAstronomy;
        return _build(facts);
      },
    );
  }

  Widget _build(SkyGraphicAstronomy? facts) {
    return GraphicEventBlockShell(
      graphic: graphic,
      width: width,
      height: height,
      isPreview: isPreview,
      opacity: opacity,
      dashedBorder: dashedBorder,
      overlay: overlay,
      visual: Stack(
        fit: StackFit.expand,
        children: [
          ...buildTrackSkyCardStars(
            seed: title,
            tint: graphic.accentColor,
            compact: compact,
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xA804060C),
                    Color(0x7A04060C),
                    Color(0x1804060C),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.34, 0.62, 1.0],
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
                astronomy: facts,
              ),
            ),
          ),
        ],
      ),
      child: child == null
          ? null
          : Padding(
              padding: EdgeInsets.only(right: (width ?? 300) < 220 ? 29 : 0),
              child: child,
            ),
    );
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
  SkyGraphicAstronomy? astronomy,
}) {
  if (astronomy != null) {
    return SizedBox(
      width: size + 8,
      height: size,
      child: CustomPaint(painter: _SkyCardAstronomyPainter(astronomy)),
    );
  }
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

/// Compact projection of the same typed facts used by the detailed instruments.
class _SkyCardAstronomyPainter extends CustomPainter {
  const _SkyCardAstronomyPainter(this.facts);
  final SkyGraphicAstronomy facts;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height * 0.4;
    final meteor = facts.meteor;
    final solar = facts.solarEclipse;
    final lunar = facts.lunarEclipse;
    if (meteor != null) {
      final count = (meteor.zenithalHourlyRate / 30).ceil().clamp(1, 5);
      final angle = -0.3 - meteor.declinationDegrees / 180;
      final direction = Offset(math.cos(angle), math.sin(angle));
      for (var i = 0; i < count; i++) {
        final end = Offset(
          size.width * (0.6 + i % 2 * 0.2),
          size.height * (i + 1) / (count + 1),
        );
        final fireball = meteor.fireballs == MeteorCharacter.notable && i == 0;
        canvas.drawLine(
          end - direction * (meteor.streakLength / 5),
          end,
          Paint()
            ..color = const Color(
              0xFFE5C3C6,
            ).withValues(alpha: fireball ? 1 : 0.65)
            ..strokeWidth = fireball ? 2 : 0.7
            ..strokeCap = StrokeCap.round,
        );
      }
    } else if (solar != null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = solar.hasTotality
              ? const Color(0xFFE8E2D6)
              : const Color(0xFFD4AE43)
          ..style = PaintingStyle.stroke
          ..strokeWidth = solar.hasTotality ? 2.5 : 1.5
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            solar.hasTotality ? 2 : 0,
          ),
      );
      canvas.drawCircle(
        center,
        radius * 0.82,
        Paint()..color = const Color(0xFF080706),
      );
    } else if (lunar != null) {
      final disk = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFF6EEE3),
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(disk));
      if (lunar.type == LunarEclipseType.penumbral) {
        canvas.drawRect(
          disk,
          Paint()
            ..shader = LinearGradient(
              colors: [
                const Color(0xFF43364B).withValues(
                  alpha: lunar.penumbralMagnitude.clamp(0, 1) * 0.48,
                ),
                Colors.transparent,
              ],
            ).createShader(disk),
        );
      } else {
        canvas.drawCircle(
          center.translate(radius * (3.4 - 2 * lunar.umbralMagnitude), 0),
          radius * 2.4,
          Paint()..color = const Color(0xFF572D3A),
        );
      }
      canvas.restore();
    } else {
      final planets = facts.planets;
      for (var i = 0; i < planets.length; i++) {
        final p = planets[i];
        final r = p.visualRadius * (planets.length > 1 ? 0.28 : 0.4);
        final c = planets.length == 1
            ? center
            : Offset(
                size.width * (i == 0 ? 0.3 : 0.75),
                size.height * (i == 0 ? 0.65 : 0.35),
              );
        final color = switch (p.body) {
          SkyBody.mars => const Color(0xFFD58C7A),
          SkyBody.jupiter => const Color(0xFFE0C49A),
          SkyBody.venus => const Color(0xFFF1DDAF),
          SkyBody.mercury => const Color(0xFFC7C1B8),
          SkyBody.saturn => const Color(0xFFD7C8A5),
        };
        canvas.drawCircle(c, r, Paint()..color = color);
        if (p.body == SkyBody.saturn) {
          canvas.drawOval(
            Rect.fromCenter(center: c, width: r * 3.2, height: r * 0.9),
            Paint()
              ..color = const Color(0xFFE8E2D6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.7,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyCardAstronomyPainter oldDelegate) =>
      oldDelegate.facts != facts;
}
