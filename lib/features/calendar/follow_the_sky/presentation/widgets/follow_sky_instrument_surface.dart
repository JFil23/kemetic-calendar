import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/sky_event_kind.dart';
import '../../domain/sky_instrument_data.dart';
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
    required this.controller,
  });

  final SkyInstrumentData data;
  final FollowSkyViewTimeController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller,
      builder: (context, selectedAt, _) => RepaintBoundary(
        key: ValueKey<String>('follow-sky-renderer-${data.family.name}'),
        child: CustomPaint(
          isComplex: true,
          willChange: true,
          painter: _rendererFor(data, controller, selectedAt),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  static FollowSkyInstrumentReading readingFor(
    SkyInstrumentData data,
    DateTime selectedAt,
  ) => switch (data) {
    LunarPathData value => _lunarReading(value, selectedAt),
    MeteorWindowData value => FollowSkyInstrumentReading(
      primary: value.radiantName,
      secondary: value.estimatedZenithalHourlyRate == null
          ? 'peak activity window'
          : 'up to ${value.estimatedZenithalHourlyRate} meteors/hr',
      semanticsValue: '${value.radiantName}, ${_formatTime(selectedAt)}',
    ),
    OppositionData value => FollowSkyInstrumentReading(
      primary: value.bodyName,
      secondary: value.altitudeSamples.isEmpty
          ? 'opposition night window'
          : '${_positionAt(value.altitudeSamples, selectedAt).altitudeDegrees.round()}° up',
      semanticsValue:
          '${value.bodyName} opposition, ${_formatTime(selectedAt)}',
    ),
    ElongationData value => FollowSkyInstrumentReading(
      primary: '${value.bodyName} · ${value.direction}',
      secondary: value.maximumElongationDegrees == null
          ? 'maximum separation window'
          : '${value.maximumElongationDegrees!.toStringAsFixed(1)}° from the Sun',
      semanticsValue:
          '${value.bodyName} ${value.direction} elongation, ${_formatTime(selectedAt)}',
    ),
    ConjunctionData value => FollowSkyInstrumentReading(
      primary: '${value.bodyA} + ${value.bodyB}',
      secondary: value.minimumSeparationDegrees == null
          ? 'closest-approach window'
          : '${value.minimumSeparationDegrees!.toStringAsFixed(1)}° closest separation',
      semanticsValue:
          '${value.bodyA} and ${value.bodyB} conjunction, ${_formatTime(selectedAt)}',
    ),
    SolarThresholdData value => FollowSkyInstrumentReading(
      primary: value.thresholdKind == SkyEventKind.equinox
          ? 'Equal light'
          : 'Sun at the turning',
      secondary: value.solarSamples.isEmpty
          ? 'threshold timing'
          : '${_positionAt(value.solarSamples, selectedAt).altitudeDegrees.round()}° up',
      semanticsValue: 'Solar threshold, ${_formatTime(selectedAt)}',
    ),
    SolarEclipseData _ => FollowSkyInstrumentReading(
      primary: 'Sun + Moon',
      secondary: 'greatest-eclipse window',
      semanticsValue: 'Solar eclipse, ${_formatTime(selectedAt)}',
    ),
  };
}

CustomPainter _rendererFor(
  SkyInstrumentData data,
  FollowSkyViewTimeController controller,
  DateTime selectedAt,
) => switch (data) {
  LunarPathData value => _LunarPathRenderer(value, controller, selectedAt),
  MeteorWindowData value => _MeteorWindowRenderer(
    value,
    controller,
    selectedAt,
  ),
  OppositionData value => _OppositionRenderer(value, controller, selectedAt),
  ElongationData value => _ElongationRenderer(value, controller, selectedAt),
  ConjunctionData value => _ConjunctionRenderer(value, controller, selectedAt),
  SolarThresholdData value => _SolarThresholdRenderer(
    value,
    controller,
    selectedAt,
  ),
  SolarEclipseData value => _SolarEclipseRenderer(
    value,
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
  _FollowSkyRenderer(this.data, this.controller, this.selectedAt);

  final SkyInstrumentData data;
  final FollowSkyViewTimeController controller;
  final DateTime selectedAt;

  double get fraction => controller.fractionFor(selectedAt).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    _paintField(canvas, size);
    paintInstrument(canvas, size);
    _paintSkyline(canvas, size);
  }

  void paintInstrument(Canvas canvas, Size size);

  void _paintField(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -1),
          radius: 1.35,
          colors: <Color>[
            Color(0xFF2C2338),
            Color(0xFF1A1526),
            Color(0xFF0C0912),
          ],
          stops: <double>[0, 0.46, 1],
        ).createShader(bounds),
    );
    for (var index = 0; index < 118; index++) {
      final x = ((index * 83 + 29) % 521) / 521 * size.width;
      final rawY = ((index * index * 37 + index * 17 + 11) % 389) / 389;
      final y = math.pow(rawY, 1.3) * size.height * 0.9;
      final alpha = (0.1 + (index % 9) * 0.055) * (1 - y / size.height);
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
    painter.paint(
      canvas,
      centered ? position.translate(-painter.width / 2, 0) : position,
    );
  }

  @override
  bool shouldRepaint(covariant _FollowSkyRenderer oldDelegate) =>
      oldDelegate.data != data || oldDelegate.selectedAt != selectedAt;
}

class _LunarPathRenderer extends _FollowSkyRenderer {
  _LunarPathRenderer(
    this.lunar,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(lunar, controller, selectedAt);

  final LunarPathData lunar;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final baseY = size.height - 39;
    final apexY = math.max(92.0, size.height * 0.34);
    final hasGeometry = lunar.moonSamples.isNotEmpty;
    final maxAltitude = hasGeometry
        ? lunar.moonSamples
              .map((sample) => sample.altitudeDegrees)
              .reduce(math.max)
        : 1.0;
    Offset point(double atFraction, double normalizedAltitude) => Offset(
      42 + atFraction * (size.width - 84),
      baseY - normalizedAltitude.clamp(0.0, 1.0) * (baseY - apexY),
    );
    double altitudeAt(double atFraction) {
      if (!hasGeometry) return math.sin(math.pi * atFraction).clamp(0.0, 1.0);
      final at = controller.timeAtFraction(atFraction);
      return (_positionAt(lunar.moonSamples, at).altitudeDegrees / maxAltitude)
          .clamp(0.0, 1.0);
    }

    final dim = Paint()..color = _rose.withValues(alpha: 0.28);
    final lit = Paint()..color = _glow.withValues(alpha: 0.58);
    final glow = Paint()
      ..color = _glow.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var index = 0; index <= 58; index++) {
      final atFraction = index / 58;
      final pathPoint = point(atFraction, altitudeAt(atFraction));
      canvas.drawCircle(pathPoint, 1, dim);
      if (atFraction <= fraction) {
        canvas.drawCircle(pathPoint, 2.6, glow);
        canvas.drawCircle(pathPoint, 1.1, lit);
      }
    }

    if (hasGeometry && lunar.transit != null) {
      final apexFraction = controller.fractionFor(lunar.transit!);
      final apex = point(apexFraction, altitudeAt(apexFraction));
      label(
        canvas,
        'HIGHEST · ${_formatTime(lunar.transit!)}',
        apex.translate(0, -48),
        color: _rose.withValues(alpha: 0.58),
      );
    } else {
      label(
        canvas,
        'CATALOG VIEWING WINDOW',
        Offset(size.width / 2, apexY - 25),
        color: _rose.withValues(alpha: 0.58),
      );
    }

    LunarEclipseContact? maximum;
    for (final contact in lunar.eclipseContacts) {
      if (contact.kind == LunarEclipseContactKind.maximum &&
          contact.locallyVisible) {
        maximum = contact;
        break;
      }
    }
    if (maximum != null && hasGeometry) {
      final maxFraction = controller.fractionFor(maximum.at);
      final maxPoint = point(maxFraction, altitudeAt(maxFraction));
      canvas.drawCircle(
        maxPoint,
        3.2,
        Paint()..color = const Color(0xFFD88C82),
      );
      label(
        canvas,
        'ECLIPSE MAX',
        maxPoint.translate(2, -13),
        color: _rose.withValues(alpha: 0.72),
      );
    }

    final moon = point(fraction, altitudeAt(fraction));
    final brightness = math.sin(math.pi * fraction).clamp(0.0, 1.0);
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
    if (maximum != null) {
      final minutes = selectedAt.difference(maximum.at).inSeconds.abs() / 60;
      final strength = math.max(0.0, 1 - minutes / 105);
      if (strength > 0) {
        canvas.save();
        canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: moon, radius: 24)),
        );
        canvas.drawCircle(
          moon.translate(8 - 14 * strength, 0),
          24,
          Paint()
            ..color = const Color(
              0xFF7B3F4C,
            ).withValues(alpha: 0.78 * strength),
        );
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
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(meteor, controller, selectedAt);
  final MeteorWindowData meteor;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final radiant = Offset(size.width * 0.44, size.height * 0.48);
    canvas.drawCircle(
      radiant,
      25,
      Paint()
        ..color = _glow.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(radiant, 3, Paint()..color = _glow);
    label(canvas, 'RADIANT', radiant.translate(0, -24));
    final activity = (1 - (fraction - 0.5).abs() * 2).clamp(0.25, 1.0);
    final count = 4 + (activity * 9).round();
    for (var index = 0; index < count; index++) {
      final angle = -2.8 + index * 0.43;
      final length = 18.0 + (index % 4) * 9;
      final start =
          radiant + Offset(math.cos(angle), math.sin(angle)) * (20 + index * 7);
      final end = start + Offset(math.cos(angle), math.sin(angle)) * length;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = _rose.withValues(alpha: 0.24 + activity * 0.48)
          ..strokeWidth = index % 3 == 0 ? 1.4 : 0.8,
      );
    }
  }
}

class _OppositionRenderer extends _FollowSkyRenderer {
  _OppositionRenderer(
    this.opposition,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(opposition, controller, selectedAt);
  final OppositionData opposition;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final path = Rect.fromCenter(
      center: center,
      width: size.width * 0.7,
      height: size.height * 0.38,
    );
    canvas.drawArc(
      path,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _rose.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final angle = math.pi + math.pi * fraction;
    final planet = Offset(
      center.dx + path.width / 2 * math.cos(angle),
      center.dy + path.height / 2 * math.sin(angle),
    );
    _paintBody(canvas, planet, 11, _glow);
    label(canvas, 'OPPOSITION', Offset(size.width / 2, size.height * 0.23));
  }
}

class _ElongationRenderer extends _FollowSkyRenderer {
  _ElongationRenderer(
    this.elongation,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(elongation, controller, selectedAt);
  final ElongationData elongation;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final horizon = size.height * 0.73;
    canvas.drawLine(
      Offset(30, horizon),
      Offset(size.width - 30, horizon),
      Paint()..color = _rose.withValues(alpha: 0.32),
    );
    final western = elongation.direction == 'western';
    final sun = Offset(
      western ? size.width * 0.72 : size.width * 0.28,
      horizon,
    );
    final separation = 52 + 66 * math.sin(math.pi * fraction).abs();
    final planet = sun.translate(western ? -separation : separation, -70);
    _paintBody(canvas, sun, 24, _gold);
    _paintBody(canvas, planet, 9, _glow);
    canvas.drawLine(
      sun,
      planet,
      Paint()
        ..color = _glow.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    label(canvas, 'SEPARATION', (sun + planet) / 2 - const Offset(0, 18));
  }
}

class _ConjunctionRenderer extends _FollowSkyRenderer {
  _ConjunctionRenderer(
    this.conjunction,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(conjunction, controller, selectedAt);
  final ConjunctionData conjunction;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.5);
    final distance = 16 + (fraction - 0.5).abs() * size.width * 0.45;
    final left = center.translate(-distance / 2, 0);
    final right = center.translate(distance / 2, 0);
    _paintBody(canvas, left, 12, _rose);
    _paintBody(canvas, right, 16, _glow);
    canvas.drawLine(
      left,
      right,
      Paint()
        ..color = _glow.withValues(alpha: 0.32)
        ..strokeWidth = 1,
    );
    label(canvas, 'CLOSEST APPROACH', center.translate(0, -48));
  }
}

class _SolarThresholdRenderer extends _FollowSkyRenderer {
  _SolarThresholdRenderer(
    this.threshold,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(threshold, controller, selectedAt);
  final SolarThresholdData threshold;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final baseY = size.height * 0.75;
    final arc = Path();
    for (var index = 0; index <= 48; index++) {
      final f = index / 48;
      final point = Offset(
        42 + f * (size.width - 84),
        baseY - math.sin(math.pi * f) * size.height * 0.38,
      );
      if (index == 0) {
        arc.moveTo(point.dx, point.dy);
      } else {
        arc.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      arc,
      Paint()
        ..color = _gold.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final sun = Offset(
      42 + fraction * (size.width - 84),
      baseY - math.sin(math.pi * fraction) * size.height * 0.38,
    );
    _paintBody(canvas, sun, 23, _gold);
    label(
      canvas,
      threshold.thresholdKind == SkyEventKind.equinox
          ? 'BALANCE POINT'
          : 'SOLAR TURNING',
      Offset(size.width / 2, size.height * 0.23),
    );
  }
}

class _SolarEclipseRenderer extends _FollowSkyRenderer {
  _SolarEclipseRenderer(
    this.eclipse,
    FollowSkyViewTimeController controller,
    DateTime selectedAt,
  ) : super(eclipse, controller, selectedAt);
  final SolarEclipseData eclipse;

  @override
  void paintInstrument(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.49);
    final distance = (fraction - 0.5).abs() * 110;
    final moon = center.translate((fraction < 0.5 ? -1 : 1) * distance, 0);
    canvas.drawCircle(
      center,
      58,
      Paint()
        ..color = _gold.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(center, 34, Paint()..color = const Color(0xFFF5D77C));
    canvas.drawCircle(moon, 31, Paint()..color = const Color(0xFF17121D));
    canvas.drawCircle(
      moon,
      31,
      Paint()
        ..color = _glow.withValues(alpha: 0.26)
        ..style = PaintingStyle.stroke,
    );
    label(canvas, 'GREATEST ECLIPSE', center.translate(0, -70));
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
