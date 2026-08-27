import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/sky_instrument_data.dart';

class LunarPathInstrument extends StatelessWidget {
  const LunarPathInstrument({
    super.key,
    required this.data,
    required this.selectedAt,
    required this.onPreview,
    required this.onCommit,
    this.enabled = true,
  });

  final LunarPathData data;
  final DateTime selectedAt;
  final ValueChanged<DateTime> onPreview;
  final ValueChanged<DateTime> onCommit;
  final bool enabled;

  bool get _hasGeometry =>
      data.rise != null &&
      data.transit != null &&
      data.set != null &&
      data.moonSamples.length >= 3;

  @override
  Widget build(BuildContext context) {
    if (!_hasGeometry) {
      return _LocationLockedInstrument(
        viewingWindowStart: data.viewingWindowStart,
        viewingWindowEnd: data.viewingWindowEnd,
      );
    }
    final rise = data.rise!;
    final transit = data.transit!;
    final set = data.set!;
    final selected = _clampDate(selectedAt, rise, set);
    final position = _interpolatePosition(data.moonSamples, selected);

    DateTime timeForFraction(double fraction) {
      final normalized = fraction.clamp(0.0, 1.0);
      final raw = normalized <= 0.5
          ? rise.add(
              Duration(
                milliseconds:
                    (transit.difference(rise).inMilliseconds *
                            (normalized / 0.5))
                        .round(),
              ),
            )
          : transit.add(
              Duration(
                milliseconds:
                    (set.difference(transit).inMilliseconds *
                            ((normalized - 0.5) / 0.5))
                        .round(),
              ),
            );
      return _snapFiveMinutes(raw, rise, set);
    }

    DateTime step(int minutes) =>
        _snapFiveMinutes(selected.add(Duration(minutes: minutes)), rise, set);

    return Semantics(
      label: 'Local lunar path instrument',
      value:
          '${_formatTime(selected)}, altitude ${position.altitudeDegrees.toStringAsFixed(1)} degrees, azimuth ${position.azimuthDegrees.toStringAsFixed(0)} degrees ${_compassDirection(position.azimuthDegrees)}',
      increasedValue: _formatTime(step(5)),
      decreasedValue: _formatTime(step(-5)),
      onIncrease: enabled ? () => onCommit(step(5)) : null,
      onDecrease: enabled ? () => onCommit(step(-5)) : null,
      slider: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'SKY INSTRUMENT',
                  style: TextStyle(
                    color: Color(0xFFFFD486),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text(
                'LOCAL ALTITUDE · INSTRUMENT PROJECTION',
                style: TextStyle(
                  color: Color(0xFF8098C2),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.65,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1.38,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double fractionFor(Offset localPosition) =>
                    ((localPosition.dx - 18) / (constraints.maxWidth - 36))
                        .clamp(0.0, 1.0);
                return _LunarArcGesture(
                  enabled: enabled,
                  selectedAt: selected,
                  timeForPosition: (position) =>
                      timeForFraction(fractionFor(position)),
                  onPreview: onPreview,
                  onCommit: onCommit,
                  child: CustomPaint(
                    key: const ValueKey<String>('lunar-path-canvas'),
                    painter: _LunarPathPainter(
                      samples: data.moonSamples,
                      contacts: data.eclipseContacts,
                      rise: rise,
                      transit: transit,
                      set: set,
                      selectedAt: selected,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PathTimeLabel(label: 'RISE', value: _formatTime(rise)),
              _PathTimeLabel(
                label: 'HIGHEST',
                value: _formatTime(transit),
                centered: true,
              ),
              _PathTimeLabel(label: 'SET', value: _formatTime(set), end: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Readout(
                  label: 'SELECTED',
                  value: _formatTime(selected),
                ),
              ),
              Expanded(
                child: _Readout(
                  label: 'ALTITUDE',
                  value: '${position.altitudeDegrees.toStringAsFixed(1)}°',
                  centered: true,
                ),
              ),
              Expanded(
                child: _Readout(
                  label: 'FINDER',
                  value:
                      '${position.azimuthDegrees.toStringAsFixed(0)}° ${_compassDirection(position.azimuthDegrees)}',
                  end: true,
                ),
              ),
            ],
          ),
          if (data.eclipseContacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final contact in data.eclipseContacts)
                  _ContactChip(contact: contact),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Drag the Moon along the path to move this observation. The curve shows altitude over time; the finder uses true local azimuth.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LunarArcGesture extends StatefulWidget {
  const _LunarArcGesture({
    required this.enabled,
    required this.selectedAt,
    required this.timeForPosition,
    required this.onPreview,
    required this.onCommit,
    required this.child,
  });

  final bool enabled;
  final DateTime selectedAt;
  final DateTime Function(Offset position) timeForPosition;
  final ValueChanged<DateTime> onPreview;
  final ValueChanged<DateTime> onCommit;
  final Widget child;

  @override
  State<_LunarArcGesture> createState() => _LunarArcGestureState();
}

class _LunarArcGestureState extends State<_LunarArcGesture> {
  DateTime? _dragSelection;

  void _preview(Offset position) {
    final next = widget.timeForPosition(position);
    _dragSelection = next;
    widget.onPreview(next);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragDown: widget.enabled
        ? (details) => _preview(details.localPosition)
        : null,
    onHorizontalDragUpdate: widget.enabled
        ? (details) => _preview(details.localPosition)
        : null,
    onHorizontalDragEnd: widget.enabled
        ? (_) {
            widget.onCommit(_dragSelection ?? widget.selectedAt);
            _dragSelection = null;
          }
        : null,
    onTapUp: widget.enabled
        ? (details) {
            final next = widget.timeForPosition(details.localPosition);
            widget.onPreview(next);
            widget.onCommit(next);
          }
        : null,
    child: widget.child,
  );
}

class _LunarPathPainter extends CustomPainter {
  const _LunarPathPainter({
    required this.samples,
    required this.contacts,
    required this.rise,
    required this.transit,
    required this.set,
    required this.selectedAt,
  });

  final List<SkyPositionSample> samples;
  final List<LunarEclipseContact> contacts;
  final DateTime rise;
  final DateTime transit;
  final DateTime set;
  final DateTime selectedAt;

  static const _gold = Color(0xFFFFD486);
  static const _night = Color(0xFF05070D);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF111B31), _night],
      ).createShader(bounds);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(22)),
      background,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(22)),
    );

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.34);
    for (var index = 0; index < 34; index++) {
      final x = ((index * 73) % 997) / 997 * size.width;
      final y = ((index * index * 31 + 17) % 419) / 419 * size.height * 0.72;
      canvas.drawCircle(Offset(x, y), index % 7 == 0 ? 1.25 : 0.7, starPaint);
    }

    final horizonY = size.height - 25;
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.13)
        ..strokeWidth = 1,
    );

    final usable =
        samples
            .where(
              (sample) => !sample.at.isBefore(rise) && !sample.at.isAfter(set),
            )
            .toList(growable: false)
          ..sort((a, b) => a.at.compareTo(b.at));
    final maximumAltitude = math.max(
      1.0,
      usable.map((sample) => sample.altitudeDegrees).reduce(math.max),
    );
    Offset point(SkyPositionSample sample) =>
        _pointFor(sample.at, sample.altitudeDegrees, size, maximumAltitude);

    final path = Path();
    for (var index = 0; index < usable.length; index++) {
      final offset = point(usable[index]);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.21)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final selectedFraction = _timeFraction(selectedAt, rise, transit, set);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * selectedFraction),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF8BA5CF), _gold],
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final contact in contacts) {
      if (contact.at.isBefore(rise) || contact.at.isAfter(set)) continue;
      final marker = _pointFor(
        contact.at,
        contact.altitudeDegrees,
        size,
        maximumAltitude,
      );
      final color = contact.locallyVisible
          ? const Color(0xFFC7A6FF)
          : Colors.white24;
      canvas.drawCircle(marker, 4, Paint()..color = color);
      final label = TextPainter(
        text: TextSpan(
          text: contact.kind.wireName,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, marker.translate(-label.width / 2, 7));
    }

    final selectedPosition = _interpolatePosition(usable, selectedAt);
    final moon = point(selectedPosition);
    canvas.drawCircle(
      moon,
      19,
      Paint()
        ..color = _gold.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      moon,
      12,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFFF8DB), _gold, Color(0xFFD59F4E)],
        ).createShader(Rect.fromCircle(center: moon, radius: 12)),
    );
    canvas.restore();
  }

  Offset _pointFor(
    DateTime at,
    double altitude,
    Size size,
    double maximumAltitude,
  ) {
    final fraction = _timeFraction(at, rise, transit, set).clamp(0.0, 1.0);
    final altitudeFraction = (altitude / maximumAltitude).clamp(0.0, 1.0);
    return Offset(
      18 + fraction * (size.width - 36),
      size.height - 25 - altitudeFraction * (size.height - 57),
    );
  }

  @override
  bool shouldRepaint(covariant _LunarPathPainter oldDelegate) =>
      oldDelegate.selectedAt != selectedAt ||
      oldDelegate.samples != samples ||
      oldDelegate.contacts != contacts;
}

class _PathTimeLabel extends StatelessWidget {
  const _PathTimeLabel({
    required this.label,
    required this.value,
    this.centered = false,
    this.end = false,
  });
  final String label;
  final String value;
  final bool centered;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end
        ? CrossAxisAlignment.end
        : centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      Text(value, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    this.centered = false,
    this.end = false,
  });
  final String label;
  final String value;
  final bool centered;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end
        ? CrossAxisAlignment.end
        : centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8098C2),
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.contact});
  final LunarEclipseContact contact;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: contact.locallyVisible
          ? const Color(0x22C7A6FF)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: contact.locallyVisible
            ? const Color(0x66C7A6FF)
            : Colors.white12,
      ),
    ),
    child: Text(
      '${contact.kind.wireName} ${_formatTime(contact.at)}${contact.locallyVisible ? '' : ' · below horizon'}',
      style: TextStyle(
        color: contact.locallyVisible
            ? const Color(0xFFD8C5FF)
            : Colors.white38,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _LocationLockedInstrument extends StatelessWidget {
  const _LocationLockedInstrument({
    required this.viewingWindowStart,
    required this.viewingWindowEnd,
  });
  final DateTime viewingWindowStart;
  final DateTime viewingWindowEnd;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    decoration: BoxDecoration(
      color: const Color(0xFF090C13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x33FFD486)),
    ),
    child: Column(
      children: [
        const Icon(Icons.nightlight_round, color: Color(0xFFFFD486), size: 38),
        const SizedBox(height: 12),
        const Text(
          'Unlock your local sky',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'CormorantGaramond',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose an observing place to reveal real moonrise, highest point, moonset, and eclipse visibility. No sky geometry is invented without it.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

SkyPositionSample _interpolatePosition(
  List<SkyPositionSample> samples,
  DateTime at,
) {
  if (!at.isAfter(samples.first.at)) return samples.first;
  if (!at.isBefore(samples.last.at)) return samples.last;
  for (var index = 1; index < samples.length; index++) {
    final right = samples[index];
    if (at.isAfter(right.at)) continue;
    final left = samples[index - 1];
    final span = right.at.difference(left.at).inMilliseconds;
    final fraction = span == 0
        ? 0.0
        : at.difference(left.at).inMilliseconds / span;
    var azimuthDelta = right.azimuthDegrees - left.azimuthDegrees;
    if (azimuthDelta > 180) azimuthDelta -= 360;
    if (azimuthDelta < -180) azimuthDelta += 360;
    final azimuth = (left.azimuthDegrees + azimuthDelta * fraction) % 360;
    return SkyPositionSample(
      at: at,
      altitudeDegrees:
          left.altitudeDegrees +
          (right.altitudeDegrees - left.altitudeDegrees) * fraction,
      azimuthDegrees: azimuth < 0 ? azimuth + 360 : azimuth,
    );
  }
  return samples.last;
}

double _timeFraction(
  DateTime value,
  DateTime rise,
  DateTime transit,
  DateTime set,
) {
  if (!value.isAfter(rise)) return 0;
  if (!value.isBefore(set)) return 1;
  if (!value.isAfter(transit)) {
    return 0.5 *
        value.difference(rise).inMilliseconds /
        transit.difference(rise).inMilliseconds;
  }
  return 0.5 +
      0.5 *
          value.difference(transit).inMilliseconds /
          set.difference(transit).inMilliseconds;
}

DateTime _clampDate(DateTime value, DateTime start, DateTime end) {
  if (value.isBefore(start)) return start;
  if (value.isAfter(end)) return end;
  return value;
}

DateTime _snapFiveMinutes(DateTime value, DateTime start, DateTime end) {
  final snapped = DateTime.fromMillisecondsSinceEpoch(
    (value.millisecondsSinceEpoch / const Duration(minutes: 5).inMilliseconds)
            .round() *
        const Duration(minutes: 5).inMilliseconds,
    isUtc: value.isUtc,
  );
  return _clampDate(snapped, start, end);
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

String _compassDirection(double azimuth) {
  const directions = <String>['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return directions[((azimuth + 22.5) ~/ 45) % directions.length];
}
