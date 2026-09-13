import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

enum DjedEventBlockSize { detail, compact }

/// The ember event block authored in the Djed HTML references.
///
/// This is shared by the flow detail and Day View so the sitting angle,
/// support label, progress marks, and palette cannot drift between surfaces.
class DjedEventBlockVisual extends StatelessWidget {
  const DjedEventBlockVisual({
    super.key,
    required this.sittingNumber,
    required this.title,
    required this.phase,
    required this.timeLabel,
    required this.durationLabel,
    this.supportName,
    this.progressCopy,
    this.ordinalLabel,
    this.supportPipIndex,
    this.size = DjedEventBlockSize.detail,
    this.width,
    this.height,
    this.onTap,
  });

  final int sittingNumber;
  final String title;
  final String phase;
  final String timeLabel;
  final String durationLabel;
  final String? supportName;
  final String? progressCopy;
  final String? ordinalLabel;

  /// `-1` paints empty pips (Day View orientation). Null uses sitting defaults.
  final int? supportPipIndex;
  final DjedEventBlockSize size;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  static const _bone = Color(0xFFF2EADD);
  static const _emberCopy = Color(0xFFE8B98A);

  @override
  Widget build(BuildContext context) {
    final compact = size == DjedEventBlockSize.compact;
    final blockHeight = height ?? (compact ? 86.0 : 106.0);
    final radius = BorderRadius.circular(MaatEventBlockBorderTokens.radius);
    final content = Container(
      key: ValueKey<String>(
        'djed-event-block-${compact ? 'compact' : 'detail'}-$sittingNumber',
      ),
      width: width,
      height: blockHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: MaatEventBlockBorderTokens.color,
          width: MaatEventBlockBorderTokens.width,
        ),
        gradient: const LinearGradient(
          begin: Alignment(-0.45, -1),
          end: Alignment(0.72, 1),
          colors: <Color>[
            Color(0xFF1E120A),
            Color(0xFF3A1F0E),
            Color(0xFF150B04),
          ],
          stops: <double>[0, .56, 1],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x94000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
          BoxShadow(color: Color(0x14E0873C), blurRadius: 16),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.66, 0),
                radius: .72,
                colors: <Color>[Color(0x42E0873C), Color(0x00E0873C)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xD1060402),
                  Color(0x75060402),
                  Color(0x05060402),
                ],
                stops: <double>[0, .46, 1],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFF5B963), Color(0xFFB4552A)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 12 : 14,
            top: compact ? 9 : 11,
            right: compact ? 70 : 82,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The Djed · ${_kickerPhase(sittingNumber, phase)}'
                      .toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ui(
                    color: const Color(0xFFEDB874),
                    size: compact ? 7.4 : 8.5,
                    spacing: compact ? 1.25 : 1.5,
                  ),
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(
                    color: _bone,
                    size: compact ? 18 : 21,
                    weight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  supportName ?? _supportFallback(sittingNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(
                    color: _emberCopy,
                    size: compact ? 11.5 : 14,
                    style: FontStyle.italic,
                    height: compact ? 1 : 1.2,
                  ),
                ),
                SizedBox(height: compact ? 5 : 9),
                Row(
                  children: <Widget>[
                    _SittingPips(
                      sittingNumber: sittingNumber,
                      supportPipIndex: supportPipIndex,
                    ),
                    SizedBox(width: compact ? 4 : 9),
                    Expanded(
                      child: Text(
                        progressCopy ??
                            _eventProgressCopy(sittingNumber, title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ui(
                          color: const Color(0xFFB0977B),
                          size: compact ? 8.5 : 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    SizedBox(
                      width: compact ? 48 : 60,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          ordinalLabel ?? _ordinal(sittingNumber),
                          maxLines: 1,
                          style: _ui(
                            color: const Color(0xFF9A8365),
                            size: compact ? 8 : 10,
                            spacing: .3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: compact ? 8 : 10,
            top: 0,
            bottom: 0,
            width: compact ? 64 : 70,
            child: Center(
              child: SizedBox(
                width: compact ? 64 : 70,
                height: compact ? 68 : 74,
                child: CustomPaint(
                  painter: _EmberDjedPainter(
                    angleDegrees: _sittingAngle(sittingNumber),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

class _SittingPips extends StatelessWidget {
  const _SittingPips({required this.sittingNumber, this.supportPipIndex});

  final int sittingNumber;
  final int? supportPipIndex;

  @override
  Widget build(BuildContext context) {
    final supportIndex =
        supportPipIndex ?? _supportIndexForSitting(sittingNumber);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 1; index <= 4; index++) ...<Widget>[
          Container(
            width: 15,
            height: 3,
            decoration: BoxDecoration(
              color: supportIndex < 0
                  ? const Color(0xFF493322)
                  : index - 1 < supportIndex
                  ? const Color(0xFFF5B963)
                  : index - 1 == supportIndex
                  ? const Color(0xFFE0873C)
                  : const Color(0xFF493322),
              borderRadius: BorderRadius.circular(2),
              boxShadow: supportIndex < 0
                  ? const <BoxShadow>[]
                  : index - 1 < supportIndex
                  ? const <BoxShadow>[
                      BoxShadow(color: Color(0x80F5B963), blurRadius: 7),
                    ]
                  : index - 1 == supportIndex
                  ? const <BoxShadow>[
                      BoxShadow(color: Color(0xB3E0873C), blurRadius: 9),
                    ]
                  : const <BoxShadow>[],
            ),
          ),
          if (index < 4) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _EmberDjedPainter extends CustomPainter {
  const _EmberDjedPainter({required this.angleDegrees});

  final double angleDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 70;
    final scaleY = size.height / 74;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    const glowRect = Rect.fromLTWH(-1, 2, 72, 72);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.12),
          radius: .56,
          colors: <Color>[Color(0x66F5B963), Color(0x00E0873C)],
        ).createShader(glowRect),
    );

    canvas.translate(35, 62);
    canvas.rotate(angleDegrees * math.pi / 180);
    canvas.scale(.42);

    void shaftRect(Rect rect, double radius) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[
              Color(0xFF7A4418),
              Color(0xFFE9A253),
              Color(0xFFB4682C),
              Color(0xFF4E2A10),
            ],
            stops: <double>[0, .38, .68, 1],
          ).createShader(rect),
      );
    }

    void litBar(double y) {
      final rect = Rect.fromLTWH(-40, y, 80, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFFBDCA4),
              Color(0xFFE0873C),
              Color(0xFF8A4418),
            ],
            stops: <double>[0, .5, 1],
          ).createShader(rect),
      );
    }

    shaftRect(const Rect.fromLTWH(-30, 86, 60, 12), 5);
    shaftRect(const Rect.fromLTWH(-8, -6, 16, 94), 7);
    litBar(-64);
    litBar(-48);
    litBar(-32);
    litBar(-16);
    shaftRect(const Rect.fromLTWH(-24, -78, 48, 10), 5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmberDjedPainter oldDelegate) =>
      oldDelegate.angleDegrees != angleDegrees;
}

int _supportIndexForSitting(int sitting) => switch (sitting) {
  1 || 2 || 3 => 0,
  4 || 5 => 1,
  6 || 7 => 2,
  8 || 9 => 3,
  _ => 0,
};

String _kickerPhase(int sittingNumber, String phase) {
  if (sittingNumber == 1 ||
      phase.toUpperCase() == 'ORIENTATION' ||
      phase.toUpperCase() == 'FIND YOUR FOOTING') {
    return 'Orientation';
  }
  return phase;
}

String _eventProgressCopy(int sittingNumber, String title) {
  if (sittingNumber == 1) return 'Start here';
  if (title == 'Make one move') return 'One small thing today';
  return 'Return and read what happened';
}

double _sittingAngle(int sitting) => switch (sitting.clamp(1, 9)) {
  1 => -74,
  2 => -66,
  3 => -56,
  4 => -42,
  5 => -32,
  6 => -24,
  7 => -16,
  8 => -8,
  _ => 0,
};

String _supportFallback(int sitting) => switch (sitting) {
  1 => 'four supports · one at a time',
  2 || 3 => 'support 01',
  4 || 5 => 'the weekly call with my sister',
  6 || 7 => 'support 03',
  _ => 'support 04',
};

String _ordinal(int sitting) {
  if (sitting == 1) return 'Start here';
  const labels = <String>[
    'First of four',
    'First of four',
    'Second of four',
    'Second of four',
    'Third of four',
    'Third of four',
    'Fourth of four',
    'Fourth of four',
  ];
  return labels[(sitting.clamp(2, 9) - 2)];
}

TextStyle _display({
  required Color color,
  required double size,
  FontWeight weight = FontWeight.w400,
  FontStyle? style,
  double? height,
}) => TextStyle(
  color: color,
  fontFamily: MaatFlowListTokens.fontFamily,
  fontFamilyFallback: MaatFlowListTokens.fontFallback,
  fontSize: size,
  fontWeight: weight,
  fontStyle: style,
  height: height,
);

TextStyle _ui({required Color color, required double size, double? spacing}) =>
    TextStyle(
      color: color,
      fontFamily: 'GentiumPlus',
      fontSize: size,
      letterSpacing: spacing,
      height: 1,
    );
