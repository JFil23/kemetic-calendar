import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/follow_sky_track_definition.dart';
import '../../domain/sky_event_kind.dart';
import '../../domain/sky_graphic_astronomy.dart';
import '../../domain/sky_instrument_data.dart';
import '../follow_sky_observation_presentation_model.dart';
import '../follow_sky_view_time_policy.dart';

const _velvet = Color(0xFF080706);
const _bone = Color(0xFFE8E2D6);
const _gold = Color(0xFFD4AE43);
const _glow = Color(0xFFA4B1FF);
const _rose = Color(0xFFE5C3C6);
const _ui = 'GentiumPlus';

@immutable
class FollowSkyInstrumentReading {
  const FollowSkyInstrumentReading({
    required this.primary,
    required this.secondary,
    required this.semanticsValue,
  });

  final String primary;
  final String secondary;
  final String semanticsValue;
}

/// The one swappable celestial region inside the shared Follow Sky shell.
///
/// Family selection is exhaustive and typed. Event IDs never enter this
/// widget; event-specific differences arrive only through instrument data.
class FollowSkyInstrumentSurface extends StatelessWidget {
  const FollowSkyInstrumentSurface({
    super.key,
    required this.data,
    required this.peakMarker,
    required this.controller,
  });

  final SkyInstrumentData data;
  final FollowSkyPeakMarkerSpec peakMarker;
  final FollowSkyViewTimeController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller,
      builder: (context, selectedAt, _) => Semantics(
        key: ValueKey<String>('follow-sky-peak-marker-${data.family.name}'),
        label: 'Event peak',
        value: peakMarker.displayLabel,
        child: RepaintBoundary(
          key: ValueKey<String>('follow-sky-renderer-${data.family.name}'),
          child: CustomPaint(
            isComplex: true,
            willChange: true,
            painter: _rendererFor(data, peakMarker, controller, selectedAt),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  static FollowSkyInstrumentReading readingFor(
    SkyInstrumentData data,
    FollowSkyTrackDefinition track,
    DateTime selectedAt,
  ) => switch (data) {
    LunarPathData value => _lunarReading(value, selectedAt),
    MeteorWindowData value => FollowSkyInstrumentReading(
      primary: value.radiantName,
      secondary: value.estimatedZenithalHourlyRate == null
          ? ''
          : 'up to ${value.estimatedZenithalHourlyRate} meteors/hr',
      semanticsValue: '${value.radiantName}, ${_formatTime(selectedAt)}',
    ),
    OppositionData value => FollowSkyInstrumentReading(
      primary: value.bodyName,
      secondary: value.altitudeSamples.isEmpty
          ? ''
          : '${_positionAt(value.altitudeSamples, selectedAt).altitudeDegrees.round()}° up',
      semanticsValue:
          '${value.bodyName} opposition, ${_formatTime(selectedAt)}',
    ),
    ElongationData value => FollowSkyInstrumentReading(
      primary: value.bodyName,
      secondary: value.maximumElongationDegrees == null
          ? ''
          : '${value.maximumElongationDegrees!.toStringAsFixed(1)}° from the Sun',
      semanticsValue:
          '${value.bodyName} ${value.direction} elongation, ${_formatTime(selectedAt)}',
    ),
    ConjunctionData value => FollowSkyInstrumentReading(
      primary: '${value.bodyA} + ${value.bodyB}',
      secondary: '',
      semanticsValue:
          '${value.bodyA} and ${value.bodyB} conjunction, ${_formatTime(selectedAt)}',
    ),
    SolarThresholdData value => FollowSkyInstrumentReading(
      primary: 'Sun',
      secondary: value.solarSamples.isEmpty
          ? ''
          : '${_positionAt(value.solarSamples, selectedAt).altitudeDegrees.round()}° up',
      semanticsValue: 'Solar threshold, ${_formatTime(selectedAt)}',
    ),
    SolarEclipseData _ => FollowSkyInstrumentReading(
      primary: 'Sun + Moon',
      secondary: '',
      semanticsValue: 'Solar eclipse, ${_formatTime(selectedAt)}',
    ),
  };
}

CustomPainter _rendererFor(
  SkyInstrumentData data,
  FollowSkyPeakMarkerSpec peakMarker,
  FollowSkyViewTimeController controller,
  DateTime selectedAt,
) => switch (data) {
  LunarPathData value => _LunarPathRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
  MeteorWindowData value => _MeteorWindowRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
  OppositionData value => _OppositionRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
  ElongationData value => _ElongationRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
  ConjunctionData value => _ConjunctionRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
  SolarThresholdData value => _SolarThresholdRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
  SolarEclipseData value => _SolarEclipseRenderer(
    value,
    peakMarker,
    controller,
    selectedAt,
  ),
};

FollowSkyInstrumentReading _lunarReading(
  LunarPathData data,
  DateTime selectedAt,
) {
  if (data.moonSamples.isEmpty) {
    return FollowSkyInstrumentReading(
      primary: 'Moon path',
      secondary: data.visibility.summary,
      semanticsValue: 'Moon viewing window, ${_formatTime(selectedAt)}',
    );
  }
  final position = _positionAt(data.moonSamples, selectedAt);
  final altitude = position.altitudeDegrees.round();
  final note = altitude > 34
      ? 'high over the roofline'
      : altitude > 20
      ? 'clear of the roofline'
      : 'low · clear horizon';
  return FollowSkyInstrumentReading(
    primary: _longCompassDirection(position.azimuthDegrees),
    secondary: '$altitude° up · $note',
    semanticsValue:
        '${_formatTime(selectedAt)}, ${position.altitudeDegrees.toStringAsFixed(1)} degrees up, ${position.azimuthDegrees.toStringAsFixed(0)} degrees azimuth',
  );
}

abstract class _FollowSkyRenderer extends CustomPainter {
  _FollowSkyRenderer(
    this.data,
    this.peakMarker,
    this.controller,
    this.selectedAt,
  );

  final SkyInstrumentData data;
  final FollowSkyPeakMarkerSpec peakMarker;
  final FollowSkyViewTimeController controller;
  final DateTime selectedAt;

  double get fraction => controller.fractionFor(selectedAt).clamp(0.0, 1.0);
  FollowSkyVisualState get state => controller.stateAt(selectedAt);
  double get peakFraction =>
      controller.fractionFor(peakMarker.instant).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    _paintField(canvas, size, state);
    paintInstrument(canvas, size);
    FollowSkyPeakMarker.paint(
      canvas,
      size,
      spec: peakMarker,
      anchor: peakAnchor(size),
      labelAbove: peakLabelAbove,
      labelAtLeft: peakLabelAtLeft,
    );
    _paintSkyline(canvas, size);
  }

  void paintInstrument(Canvas canvas, Size size);
  Offset peakAnchor(Size size);
  bool get peakLabelAbove => true;
  bool get peakLabelAtLeft => false;

  void _paintField(Canvas canvas, Size size, FollowSkyVisualState state) {
    final bounds = Offset.zero & size;
    final sky = data is MeteorWindowData
        ? data.astronomy?.meteorAt(selectedAt)
        : null;
    final eclipse = data.astronomy?.facts.solarEclipse;
    final eclipseDarkness = eclipse == null
        ? 0.0
        : state.eventStrength * (eclipse.hasTotality ? 0.92 : 0.32);
    final daylight = sky == null
        ? (state.daylight * (1 - eclipseDarkness)).clamp(0.0, 1.0)
        : (1 - sky.darkness).clamp(0.0, 1.0);
    final moonWash = sky?.moonInterference ?? 0;
    final upper = Color.lerp(
      const Color(0xFF2C2338),
      const Color(0xFF6A8EB8),
      daylight,
    )!;
    final middle = Color.lerp(
      const Color(0xFF1A1526),
      const Color(0xFFC79B6F),
      daylight,
    )!;
    final lower = Color.lerp(
      const Color(0xFF0C0912),
      const Color(0xFFE8C98D),
      daylight,
    )!;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, -1),
          radius: 1.35,
          colors: <Color>[
            Color.lerp(upper, const Color(0xFF66687D), moonWash * 0.28)!,
            Color.lerp(middle, const Color(0xFF66687D), moonWash * 0.22)!,
            lower,
          ],
          stops: const <double>[0, 0.46, 1],
        ).createShader(bounds),
    );
    final starVisibility =
        math.pow(1 - daylight, 2).toDouble() * (1 - moonWash * 0.86);
    for (var index = 0; index < 118; index++) {
      final x = ((index * 83 + 29) % 521) / 521 * size.width;
      final rawY = ((index * index * 37 + index * 17 + 11) % 389) / 389;
      final y = math.pow(rawY, 1.3) * size.height * 0.9;
      final alpha =
          (0.1 + (index % 9) * 0.055) * (1 - y / size.height) * starVisibility;
      canvas.drawCircle(
        Offset(x, y),
        index % 13 == 0 ? 1.25 : 0.55 + (index % 3) * 0.18,
        Paint()..color = const Color(0xFFEFE7DE).withValues(alpha: alpha),
      );
    }
  }

  void _paintSkyline(Canvas canvas, Size size) {
    final roof = Path()
      ..moveTo(0, size.height - 32)
      ..lineTo(size.width * 0.13, size.height - 32)
      ..lineTo(size.width * 0.13, size.height - 58)
      ..lineTo(size.width * 0.27, size.height - 58)
      ..lineTo(size.width * 0.27, size.height - 40)
      ..lineTo(size.width * 0.43, size.height - 40)
      ..lineTo(size.width * 0.47, size.height - 66)
      ..lineTo(size.width * 0.51, size.height - 40)
      ..lineTo(size.width * 0.69, size.height - 40)
      ..lineTo(size.width * 0.69, size.height - 52)
      ..lineTo(size.width * 0.82, size.height - 52)
      ..lineTo(size.width * 0.82, size.height - 36)
      ..lineTo(size.width, size.height - 36)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF08060B));
    canvas.drawPath(
      roof,
      Paint()
        ..color = _glow.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 92, size.width, 92),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            const Color(0xFF0A0808).withValues(alpha: 0.5),
            _velvet,
          ],
        ).createShader(Rect.fromLTWH(0, size.height - 92, size.width, 92)),
    );
  }

  void label(
    Canvas canvas,
    Size size,
    String text,
    Offset position, {
    Color color = _rose,
    bool centered = true,
    double fontSize = 8.7,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: _ui,
          fontSize: fontSize,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelTop = _instrumentTextTop(size);
    painter.paint(
      canvas,
      centered
          ? Offset(
              (position.dx - painter.width / 2).clamp(
                12.0,
                math.max(12.0, size.width - painter.width - 12),
              ),
              math.max(position.dy, labelTop),
            )
          : Offset(position.dx, math.max(position.dy, labelTop)),
    );
  }

  @override
  bool shouldRepaint(covariant _FollowSkyRenderer oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.peakMarker != peakMarker ||
      oldDelegate.selectedAt != selectedAt;
}

/// Shared visual contract for the fixed, meaningful instant in every family.
///
/// The selected-time body is painted by each renderer. This marker is always
/// derived from [FollowSkyPeakMarkerSpec] and never follows the scrubber.
abstract final class FollowSkyPeakMarker {
  static void paint(
    Canvas canvas,
    Size size, {
    required FollowSkyPeakMarkerSpec spec,
    required Offset anchor,
    required bool labelAbove,
    bool labelAtLeft = false,
  }) {
    final color = spec.emphasized ? const Color(0xFFD88C82) : _gold;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(anchor, 6, glow);
    canvas.drawCircle(anchor, 2.1, Paint()..color = color);

    final text =
        '${spec.glyph == null ? '' : '${spec.glyph} '}${spec.displayLabel}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _rose.withValues(alpha: spec.emphasized ? 0.9 : 0.72),
          fontFamily: _ui,
          fontSize: 8.3,
          letterSpacing: 1.05,
          shadows: const <Shadow>[
            Shadow(color: Color(0xE6000000), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(92, size.width - 24).toDouble());

    final minimumTop = _instrumentTextTop(size);
    final maximumTop = math.max(minimumTop, size.height - 72);
    final desiredTop = labelAbove
        ? anchor.dy - painter.height - 34
        : anchor.dy + 18;
    final useSide = labelAbove && desiredTop < minimumTop;
    final top = (useSide ? anchor.dy - painter.height / 2 : desiredTop)
        .clamp(minimumTop, maximumTop)
        .toDouble();
    final desiredLeft = labelAtLeft
        ? 12.0
        : useSide
        ? anchor.dx + 32 + painter.width <= size.width - 12
              ? anchor.dx + 32
              : anchor.dx - painter.width - 32
        : anchor.dx - painter.width / 2;
    final left = desiredLeft
        .clamp(12.0, math.max(12.0, size.width - painter.width - 12))
        .toDouble();
    final lineEnd = useSide
        ? Offset(
            left > anchor.dx ? left - 4 : left + painter.width + 4,
            top + painter.height / 2,
          )
        : Offset(
            labelAtLeft ? left + painter.width / 2 : anchor.dx,
            labelAbove ? top + painter.height + 3 : top - 3,
          );
    canvas.drawLine(
      anchor,
      lineEnd,
      Paint()
        ..color = color.withValues(alpha: 0.42)
        ..strokeWidth = 0.8,
    );
    painter.paint(canvas, Offset(left, top));
  }
}

double _instrumentTextTop(Size size) =>
    math.min(size.width < 350 ? 160.0 : 138.0, size.height - 74);

class _LunarPathRenderer extends _FollowSkyRenderer {
  _LunarPathRenderer(
    this.lunar,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(lunar, peakMarker, controller, selectedAt);

  final LunarPathData lunar;

  double _baseY(Size size) => size.height - 39;

  double _apexY(Size size) =>
      math.min(size.height - 82, math.max(144, size.height * 0.54));

  double _altitudeAt(double atFraction) {
    return controller
        .stateAt(controller.timeAtFraction(atFraction))
        .altitudeNormalized
        .clamp(0.0, 1.0);
  }

  Offset _pathPoint(Size size, double atFraction) => Offset(
    42 + atFraction * (size.width - 84),
    _baseY(size) - _altitudeAt(atFraction) * (_baseY(size) - _apexY(size)),
  );

  @override
  Offset peakAnchor(Size size) => _pathPoint(size, peakFraction);

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final dim = Paint()..color = _rose.withValues(alpha: 0.28);
    final lit = Paint()..color = _glow.withValues(alpha: 0.58);
    final glow = Paint()
      ..color = _glow.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var index = 0; index <= 58; index++) {
      final atFraction = index / 58;
      final pathPoint = _pathPoint(size, atFraction);
      canvas.drawCircle(pathPoint, 1, dim);
      if (atFraction <= fraction) {
        canvas.drawCircle(pathPoint, 2.6, glow);
        canvas.drawCircle(pathPoint, 1.1, lit);
      }
    }

    final moon = _pathPoint(size, fraction);
    final brightness = state.altitudeNormalized.clamp(0.0, 1.0);
    canvas.drawCircle(
      moon,
      52 + 34 * brightness,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFF0E1DC).withValues(alpha: 0.34),
            const Color(0xFFBEA5C8).withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.52, 1],
        ).createShader(Rect.fromCircle(center: moon, radius: 86)),
    );
    canvas.drawCircle(moon, 24, Paint()..color = const Color(0xFFF6EEE3));
    if (controller.track.mode == FollowSkyTrackMode.lunarEclipse) {
      final strength = state.eventStrength.clamp(0.0, 1.0);
      final physics = lunar.astronomy?.facts.lunarEclipse;
      if (strength > 0 && physics != null) {
        canvas.save();
        final disk = Rect.fromCircle(center: moon, radius: 24);
        canvas.clipPath(Path()..addOval(disk));
        if (physics.type == LunarEclipseType.penumbral) {
          // Diffuse penumbra never acquires the sharp umbral edge.
          final depth = physics.penumbralMagnitude.clamp(0.0, 1.0) * strength;
          canvas.drawRect(
            disk,
            Paint()
              ..shader = LinearGradient(
                colors: [
                  const Color(0xFF43364B).withValues(alpha: depth * 0.48),
                  const Color(0xFF43364B).withValues(alpha: depth * 0.02),
                ],
              ).createShader(disk),
          );
        } else {
          // Umbral magnitude measures penetration in lunar diameters. A larger
          // Earth-shadow circle makes the curved bite physically distinct.
          final penetration =
              physics.umbralMagnitude.clamp(0.0, 1.9) * strength;
          canvas.drawCircle(
            moon.translate(24 + 58 - 48 * penetration, 0),
            58,
            Paint()..color = const Color(0xFF572D3A),
          );
        }
        canvas.restore();
      }
    }
    canvas.drawCircle(
      moon,
      24,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }
}

class _MeteorWindowRenderer extends _FollowSkyRenderer {
  _MeteorWindowRenderer(
    this.meteor,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(meteor, peakMarker, controller, selectedAt);
  final MeteorWindowData meteor;

  @override
  Offset peakAnchor(Size size) =>
      Offset(42 + peakFraction * (size.width - 84), size.height - 65);

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final astronomy = meteor.astronomy;
    final physics = astronomy?.facts.meteor;
    final sky = astronomy?.meteorAt(selectedAt);
    final horizon = size.height - 100;
    final skyTop = math.min(112.0, horizon - 30);
    final radiant = sky == null
        ? null
        : Offset(
            24 + sky.radiantAzimuth / 360 * (size.width - 48),
            horizon -
                math.sin(sky.radiantAltitude * math.pi / 180) *
                    (horizon - skyTop),
          );
    if (radiant != null && sky!.radiantAltitude >= 0) {
      canvas.drawCircle(
        radiant,
        22,
        Paint()
          ..color = _glow.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(radiant, 2.5, Paint()..color = _glow);
      label(
        canvas,
        size,
        'RADIANT · ${physics!.constellation.toUpperCase()}',
        radiant.translate(0, 12),
        fontSize: 7.5,
      );
    }
    if (physics != null && sky != null && radiant != null) {
      final activity = astronomy!.activityAt(selectedAt);
      final count =
          (physics.zenithalHourlyRate *
                  0.22 *
                  activity *
                  sky.radiantQuality *
                  sky.faintVisibility)
              .round()
              .clamp(0, 30);
      // Stable low-discrepancy positions cover the field, rather than forming
      // a firework burst at the radiant. Back-projected streaks converge there.
      final seed =
          (physics.rightAscensionDegrees * 37 + physics.declinationDegrees * 13)
              .round();
      double random(int i) => ((i * 7919 + seed * 104729) % 65521) / 65521;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(12, skyTop - 12, size.width - 12, horizon + 1),
      );
      for (var index = 0; index < count; index++) {
        final end = Offset(
          16 + random(index * 7) * (size.width - 32),
          skyTop + random(index * 11 + 4) * (horizon - skyTop),
        );
        final delta = end - radiant;
        if (delta.distance < 25) continue;
        final direction = delta / delta.distance;
        final timeBin = selectedAt.difference(astronomy.anchor).inMinutes ~/ 40;
        final fireballRoll = random(index * 13 + 19 + timeBin * 23);
        final fireball = physics.fireballs == MeteorCharacter.notable
            ? fireballRoll > 0.86
            : physics.fireballs == MeteorCharacter.ordinary &&
                  fireballRoll > 0.98;
        final grazer = sky.radiantAltitude > 0 && sky.radiantAltitude < 15
            ? 1.45
            : 1.0;
        final length = math.min(
          delta.distance * 0.72,
          physics.streakLength * (0.6 + random(index + 5) * 0.8) * grazer,
        );
        final start = end - direction * length;
        final brightness =
            (0.38 + random(index + 27) * 0.5) * sky.faintVisibility;
        final color = fireball ? const Color(0xFFFFEDD1) : _rose;
        final train =
            physics.trains == MeteorCharacter.notable && index % 3 != 1;
        if (train) {
          canvas.drawLine(
            start - direction * length * 0.4,
            end,
            Paint()
              ..color = _glow.withValues(alpha: brightness * 0.14)
              ..strokeWidth = 3
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        canvas.drawLine(
          start,
          end,
          Paint()
            ..shader = LinearGradient(
              colors: [
                color.withValues(alpha: 0.02),
                color.withValues(alpha: fireball ? 0.96 : brightness),
              ],
              begin: Alignment(-direction.dx, -direction.dy),
              end: Alignment(direction.dx, direction.dy),
            ).createShader(Rect.fromPoints(start, end).inflate(0.5))
            ..strokeWidth = fireball
                ? 2.5
                : (physics.velocityKmPerSecond > 55 ? 0.8 : 1.1)
            ..strokeCap = StrokeCap.round,
        );
        if (fireball) {
          canvas.drawCircle(
            end,
            2.4,
            Paint()
              ..color = color.withValues(alpha: 0.8)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
      canvas.restore();
      final curve = Path();
      for (var i = 0; i <= 80; i++) {
        final f = i / 80;
        final level = astronomy.activityAt(controller.timeAtFraction(f));
        final x = 42 + f * (size.width - 84);
        final y =
            size.height -
            72 -
            level * (5 + 23 * (physics.zenithalHourlyRate / 120).clamp(0, 1));
        if (i == 0) {
          curve.moveTo(x, y);
        } else {
          curve.lineTo(x, y);
        }
      }
      canvas.drawPath(
        curve,
        Paint()
          ..color = _glow.withValues(alpha: 0.36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }

    final trackY = size.height - 65;
    canvas.drawLine(
      Offset(42, trackY),
      Offset(size.width - 42, trackY),
      Paint()
        ..color = _rose.withValues(alpha: 0.2)
        ..strokeWidth = 0.8,
    );
    final selected = Offset(42 + fraction * (size.width - 84), trackY);
    canvas.drawCircle(
      selected,
      7,
      Paint()
        ..color = _glow.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(selected, 1.8, Paint()..color = _glow);
  }
}

class _OppositionRenderer extends _FollowSkyRenderer {
  _OppositionRenderer(
    this.opposition,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(opposition, peakMarker, controller, selectedAt);
  final OppositionData opposition;

  Offset _planetAt(Size size, double atFraction) {
    final altitude = controller
        .stateAt(controller.timeAtFraction(atFraction))
        .altitudeNormalized
        .clamp(0.0, 1.0);
    final horizon = size.height * 0.7;
    return Offset(
      44 + atFraction * (size.width - 88),
      horizon - altitude * size.height * 0.27,
    );
  }

  Offset _sunAt(Size size, double atFraction) {
    final horizon = size.height * 0.7;
    return Offset(
      size.width - 44 - atFraction * (size.width - 88),
      horizon + math.sin(math.pi * atFraction) * size.height * 0.13,
    );
  }

  @override
  Offset peakAnchor(Size size) => _planetAt(size, peakFraction);

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final planetPath = Path();
    final sunPath = Path();
    for (var index = 0; index <= 40; index++) {
      final atFraction = index / 40;
      final planetPoint = _planetAt(size, atFraction);
      final sunPoint = _sunAt(size, atFraction);
      if (index == 0) {
        planetPath.moveTo(planetPoint.dx, planetPoint.dy);
        sunPath.moveTo(sunPoint.dx, sunPoint.dy);
      } else {
        planetPath.lineTo(planetPoint.dx, planetPoint.dy);
        sunPath.lineTo(sunPoint.dx, sunPoint.dy);
      }
    }
    canvas.drawPath(
      planetPath,
      Paint()
        ..color = _glow.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawPath(
      sunPath,
      Paint()
        ..color = _gold.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    final planet = _planetAt(size, fraction);
    final sun = _sunAt(size, fraction);
    canvas.drawLine(
      sun,
      planet,
      Paint()
        ..color = _rose.withValues(alpha: 0.2)
        ..strokeWidth = 0.7,
    );
    _paintBody(canvas, sun, 13, _gold);
    _paintPlanet(
      canvas,
      planet,
      opposition.bodyName,
      appearance: opposition.astronomy?.facts.planets.firstOrNull,
    );
  }
}

class _ElongationRenderer extends _FollowSkyRenderer {
  _ElongationRenderer(
    this.elongation,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(elongation, peakMarker, controller, selectedAt);
  final ElongationData elongation;

  bool get _western =>
      (elongation.astronomy?.facts.elongationDirection ??
          elongation.direction) ==
      'western';

  Offset _sun(Size size) => Offset(
    _western ? size.width * 0.74 : size.width * 0.26,
    size.height * 0.74,
  );

  Offset _planetAt(Size size, double atFraction) {
    final separationState = controller
        .stateAt(controller.timeAtFraction(atFraction))
        .separationNormalized
        .clamp(0.0, 1.0);
    final angle = elongation.astronomy?.facts.elongationDegrees;
    final separation =
        22 +
        size.width *
            0.38 *
            separationState *
            (angle == null ? 1 : (angle / 47).clamp(0.2, 1.0));
    return _sun(size).translate(
      _western ? -separation : separation,
      -12 - 34 * separationState,
    );
  }

  @override
  Offset peakAnchor(Size size) => _planetAt(size, peakFraction);

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final horizon = size.height * 0.73;
    canvas.drawLine(
      Offset(30, horizon),
      Offset(size.width - 30, horizon),
      Paint()..color = _rose.withValues(alpha: 0.32),
    );
    final sun = _sun(size);
    final planet = _planetAt(size, fraction);
    for (var index = 0; index <= 16; index++) {
      final point = _planetAt(size, index / 16);
      canvas.drawCircle(
        point,
        1.1,
        Paint()..color = _glow.withValues(alpha: 0.1 + index * 0.008),
      );
    }
    _paintBody(canvas, sun, 24, _gold);
    _paintPlanet(
      canvas,
      planet,
      elongation.bodyName,
      radius: 9,
      appearance: elongation.astronomy?.facts.planets.firstOrNull,
    );
    canvas.drawLine(
      sun,
      planet,
      Paint()
        ..color = _glow.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final separationArc = Rect.fromCircle(center: sun, radius: 28);
    canvas.drawArc(
      separationArc,
      _western ? -math.pi : math.pi,
      _western ? -0.7 : 0.7,
      false,
      Paint()
        ..color = _glow.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }
}

class _ConjunctionRenderer extends _FollowSkyRenderer {
  _ConjunctionRenderer(
    this.conjunction,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(conjunction, peakMarker, controller, selectedAt);
  final ConjunctionData conjunction;

  Offset _center(Size size) => Offset(size.width / 2, size.height * 0.65);

  double _distanceAt(Size size, double atFraction) {
    final astronomy = conjunction.astronomy;
    final bodies = astronomy?.facts.planets ?? const <PlanetAppearance>[];
    final separation = astronomy?.separationAt(
      controller.timeAtFraction(atFraction),
    );
    if (separation != null && bodies.length == 2) {
      return (bodies[0].visualRadius + bodies[1].visualRadius + separation * 24)
          .clamp(0, size.width - 64);
    }
    final minimum = 26 + (conjunction.minimumSeparationDegrees ?? 1) * 24;
    return minimum +
        controller
                .stateAt(controller.timeAtFraction(atFraction))
                .separationNormalized
                .clamp(0.0, 1.0) *
            size.width *
            0.46;
  }

  @override
  Offset peakAnchor(Size size) => _center(size);

  @override
  bool get peakLabelAbove => false;

  @override
  bool get peakLabelAtLeft => true;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final center = _center(size);
    final distance = _distanceAt(size, fraction);
    final direction = fraction <= peakFraction ? -1.0 : 1.0;
    final left = center.translate(-distance / 2, -direction * distance * 0.12);
    final right = center.translate(distance / 2, direction * distance * 0.12);
    final bodies =
        conjunction.astronomy?.facts.planets ?? const <PlanetAppearance>[];
    _paintPlanet(
      canvas,
      left,
      conjunction.bodyA,
      radius: 12,
      appearance: bodies.firstOrNull,
    );
    _paintPlanet(
      canvas,
      right,
      conjunction.bodyB,
      radius: 14,
      appearance: bodies.length > 1 ? bodies[1] : null,
    );
    canvas.drawLine(
      left,
      right,
      Paint()
        ..color = _glow.withValues(alpha: 0.32)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = _gold.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }
}

class _SolarThresholdRenderer extends _FollowSkyRenderer {
  _SolarThresholdRenderer(
    this.threshold,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(threshold, peakMarker, controller, selectedAt);
  final SolarThresholdData threshold;

  double _arcHeight(Size size) {
    if (threshold.thresholdKind == SkyEventKind.equinox) {
      return size.height * 0.19;
    }
    final northernSummer =
        threshold.thresholdInstant.month >= 4 &&
        threshold.thresholdInstant.month <= 9;
    return size.height * (northernSummer ? 0.25 : 0.12);
  }

  Offset _sunAt(Size size, double atFraction, {double? arcHeight}) {
    final baseY = size.height - 43;
    if (threshold.thresholdKind == SkyEventKind.equinox) {
      final selected = controller.timeAtFraction(atFraction);
      final visual = controller.stateAt(selected);
      final rise = controller.track.sunrise;
      final set = controller.track.sunset;
      final riseFraction = rise == null ? 0.25 : controller.fractionFor(rise);
      final setFraction = set == null ? 0.75 : controller.fractionFor(set);
      final daylightProgress = atFraction <= riseFraction
          ? 0.0
          : atFraction >= setFraction
          ? 1.0
          : (atFraction - riseFraction) / (setFraction - riseFraction);
      final x = 42 + daylightProgress * (size.width - 84);
      final altitude = visual.altitudeNormalized;
      return Offset(
        x,
        altitude >= 0
            ? baseY - altitude * size.height * 0.28
            : baseY + (-altitude).clamp(0.0, 1.0) * 34,
      );
    }
    final height = arcHeight ?? _arcHeight(size);
    return Offset(
      42 + atFraction * (size.width - 84),
      baseY - math.sin(math.pi * atFraction) * height,
    );
  }

  Path _arcPath(Size size, double height) {
    final path = Path();
    for (var index = 0; index <= 48; index++) {
      final point = _sunAt(size, index / 48, arcHeight: height);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  @override
  Offset peakAnchor(Size size) => _sunAt(size, peakFraction);

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final height = _arcHeight(size);
    if (threshold.thresholdKind == SkyEventKind.solstice) {
      final arc = _arcPath(size, height);
      canvas.drawPath(
        arc,
        Paint()
          ..color = _gold.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final referenceHeight =
          threshold.thresholdInstant.month >= 4 &&
              threshold.thresholdInstant.month <= 9
          ? size.height * 0.12
          : size.height * 0.25;
      canvas.drawPath(
        _arcPath(size, referenceHeight),
        Paint()
          ..color = _rose.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    } else {
      final riseFraction = controller.track.sunrise == null
          ? 0.25
          : controller.fractionFor(controller.track.sunrise!);
      final setFraction = controller.track.sunset == null
          ? 0.75
          : controller.fractionFor(controller.track.sunset!);
      final left = 42.0;
      final width = size.width - 84;
      final bandY = size.height - 78;
      canvas.drawLine(
        Offset(left, bandY),
        Offset(left + width, bandY),
        Paint()
          ..color = _glow.withValues(alpha: 0.25)
          ..strokeWidth = 6,
      );
      canvas.drawLine(
        Offset(left + width * riseFraction, bandY),
        Offset(left + width * setFraction, bandY),
        Paint()
          ..color = _gold.withValues(alpha: 0.72)
          ..strokeWidth = 6,
      );
      final selectedX = left + width * fraction;
      canvas.drawLine(
        Offset(selectedX, bandY - 7),
        Offset(selectedX, bandY + 7),
        Paint()
          ..color = _bone.withValues(alpha: 0.75)
          ..strokeWidth = 1.2,
      );
    }
    final sun = _sunAt(size, fraction);
    if (threshold.thresholdKind != SkyEventKind.equinox ||
        state.daylight > 0.02 ||
        state.altitudeNormalized >= 0) {
      _paintBody(canvas, sun, 23, _gold);
    }
  }
}

class _SolarEclipseRenderer extends _FollowSkyRenderer {
  _SolarEclipseRenderer(
    this.eclipse,
    FollowSkyPeakMarkerSpec peakMarker,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(eclipse, peakMarker, controller, selectedAt);
  final SolarEclipseData eclipse;

  Offset _center(Size size) => Offset(size.width / 2, size.height * 0.66);

  @override
  Offset peakAnchor(Size size) => _center(size);

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final center = _center(size);
    final physics = eclipse.astronomy?.facts.solarEclipse;
    final ratio = physics?.lunarSolarRadiusRatio ?? 0.91;
    final direction = fraction <= peakFraction ? -1.0 : 1.0;
    final separation = state.separationNormalized.clamp(0.0, 1.0);
    final moon = center.translate(
      direction * separation * 34 * (1 + ratio),
      34 * (physics?.minimumCenterDistance ?? 0),
    );
    final totality =
        physics?.hasTotality == true &&
        (moon - center).distance <= 34 * (ratio - 1);
    if (totality) {
      canvas.drawCircle(
        center,
        34 * ratio + 5,
        Paint()
          ..color = _bone.withValues(alpha: 0.66)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    } else {
      canvas.drawCircle(
        center,
        58,
        Paint()
          ..color = _gold.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.drawCircle(center, 34, Paint()..color = const Color(0xFFF5D77C));
    canvas.drawCircle(
      moon,
      34 * ratio,
      Paint()..color = const Color(0xFF141019),
    );
    canvas.drawCircle(
      moon,
      34 * ratio,
      Paint()
        ..color = _glow.withValues(alpha: totality ? 0.06 : 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );
    if (eclipse.contactInstants.isNotEmpty) {
      final contactY = size.height - 58;
      canvas.drawLine(
        Offset(42, contactY),
        Offset(size.width - 42, contactY),
        Paint()
          ..color = _rose.withValues(alpha: 0.2)
          ..strokeWidth = 0.8,
      );
      for (final contact in eclipse.contactInstants) {
        final x =
            42 +
            controller.fractionFor(contact).clamp(0.0, 1.0) * (size.width - 84);
        canvas.drawLine(
          Offset(x, contactY - 4),
          Offset(x, contactY + 4),
          Paint()
            ..color = _rose.withValues(alpha: 0.5)
            ..strokeWidth = 0.8,
        );
      }
    }
  }
}

void _paintBody(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius * 2.6,
    Paint()
      ..color = color.withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
  );
  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = _bone.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );
}

void _paintPlanet(
  Canvas canvas,
  Offset center,
  String bodyName, {
  double radius = 10,
  PlanetAppearance? appearance,
}) {
  final body =
      appearance?.body ??
      switch (bodyName) {
        'Mars' => SkyBody.mars,
        'Jupiter' => SkyBody.jupiter,
        'Venus' => SkyBody.venus,
        'Mercury' => SkyBody.mercury,
        'Saturn' => SkyBody.saturn,
        _ => null,
      };
  radius = appearance?.visualRadius ?? radius;
  final color = switch (body) {
    SkyBody.mars => const Color(0xFFD58C7A),
    SkyBody.jupiter => const Color(0xFFE0C49A),
    SkyBody.venus => const Color(0xFFF1DDAF),
    SkyBody.mercury => const Color(0xFFC7C1B8),
    SkyBody.saturn => const Color(0xFFD7C8A5),
    null => _glow,
  };
  if (appearance != null) {
    canvas.drawCircle(
      center,
      radius * 2.8,
      Paint()
        ..color = color.withValues(alpha: appearance.glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
  _paintBody(canvas, center, radius, color);
  if (body == SkyBody.jupiter) {
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    for (final dy in [-0.5, 0.0, 0.5]) {
      canvas.drawLine(
        center.translate(-radius, radius * dy),
        center.translate(radius, radius * dy),
        Paint()
          ..color = const Color(0xFF785A3C).withValues(alpha: 0.4)
          ..strokeWidth = radius * 0.16,
      );
    }
    canvas.restore();
  }
  if (body == SkyBody.saturn) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.2,
        height: radius * 0.9,
      ),
      Paint()
        ..color = _bone.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.restore();
  }
}

SkyPositionSample _positionAt(List<SkyPositionSample> samples, DateTime at) {
  final sorted = samples.toList(growable: false)
    ..sort((a, b) => a.at.compareTo(b.at));
  if (!at.isAfter(sorted.first.at)) return sorted.first;
  if (!at.isBefore(sorted.last.at)) return sorted.last;
  for (var index = 0; index < sorted.length - 1; index++) {
    final left = sorted[index];
    final right = sorted[index + 1];
    if (at.isAfter(right.at)) continue;
    final span = right.at.difference(left.at).inMilliseconds;
    final elapsed = at.difference(left.at).inMilliseconds;
    final f = span == 0 ? 0.0 : elapsed / span;
    return SkyPositionSample(
      at: at,
      azimuthDegrees:
          left.azimuthDegrees +
          (right.azimuthDegrees - left.azimuthDegrees) * f,
      altitudeDegrees:
          left.altitudeDegrees +
          (right.altitudeDegrees - left.altitudeDegrees) * f,
    );
  }
  return sorted.last;
}

String _formatTime(DateTime value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
}

String _longCompassDirection(double azimuth) {
  const directions = <String>[
    'Due north',
    'North-northeast',
    'Northeast',
    'East-northeast',
    'Due east',
    'East-southeast',
    'Southeast',
    'South-southeast',
    'Due south',
    'South-southwest',
    'Southwest',
    'West-southwest',
    'Due west',
    'West-northwest',
    'Northwest',
    'North-northwest',
  ];
  final index = ((azimuth % 360) / 22.5).round() % directions.length;
  return directions[index];
}
