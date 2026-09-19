import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../the_offering_table_flow.dart';

@immutable
class OfferingTablePreviewOccurrence {
  const OfferingTablePreviewOccurrence({
    required this.day,
    required this.date,
    required this.startLocal,
  });

  final OfferingTableDay day;
  final DateTime date;
  final DateTime startLocal;
}

class OfferingTableContextDisclosure extends StatefulWidget {
  const OfferingTableContextDisclosure({
    super.key,
    required this.context,
    required this.instruction,
  });

  final String context;
  final String instruction;

  @override
  State<OfferingTableContextDisclosure> createState() =>
      _OfferingTableContextDisclosureState();
}

class _OfferingTableContextDisclosureState
    extends State<OfferingTableContextDisclosure> {
  static const _separator = Color(0xFF2A2415);
  static const _muted = Color(0xFF8E867C);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _separator),
          bottom: BorderSide(color: _separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>(
              'offering-table-day-sheet-context-toggle',
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Why this belongs at the Offering Table',
                      style: TextStyle(
                        color: Color(0xFFA99D8E),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _expanded ? '−' : '+',
                    key: const ValueKey<String>(
                      'offering-table-day-sheet-context-sign',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF7A4E2E),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(widget.context, style: _contextStyle),
                          const SizedBox(height: 12),
                          Text(widget.instruction, style: _contextStyle),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  static const _contextStyle = TextStyle(
    color: _muted,
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: <String>['Georgia', 'serif'],
    fontSize: 13,
    height: 1.42,
  );
}

class OfferingTableStage {
  const OfferingTableStage({
    required this.name,
    required this.progressLanguage,
  });

  final String name;
  final String progressLanguage;
}

OfferingTableStage offeringTableStage(int dayNumber) {
  if (dayNumber <= 10) {
    return const OfferingTableStage(
      name: 'Personal Table',
      progressLanguage: 'Provide for yourself',
    );
  }
  if (dayNumber <= 20) {
    return const OfferingTableStage(
      name: 'Household Table',
      progressLanguage: 'Provide for what depends on you',
    );
  }
  return const OfferingTableStage(
    name: 'Flowing Table',
    progressLanguage: 'Return provision to the larger flow',
  );
}

class OfferingTableSmallSupplyJarVisual extends StatelessWidget {
  const OfferingTableSmallSupplyJarVisual({
    super.key,
    this.label = 'supply…',
    this.refilled = false,
    this.visible = false,
    this.complete = false,
  });

  final String label;
  final bool refilled;
  final bool visible;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: key ?? const ValueKey<String>('offering-table-small-supply-jar'),
      painter: _SmallSupplyJarPainter(
        label: label,
        refilled: refilled,
        visible: visible,
        complete: complete,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SmallSupplyJarPainter extends CustomPainter {
  const _SmallSupplyJarPainter({
    required this.label,
    required this.refilled,
    required this.visible,
    required this.complete,
  });

  final String label;
  final bool refilled;
  final bool visible;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 142, size.height / 204);
    canvas.save();
    canvas.translate(
      (size.width - 142 * scale) / 2,
      (size.height - 204 * scale) / 2,
    );
    canvas.scale(scale);

    final halo = Rect.fromCenter(
      center: const Offset(71, 110),
      width: 130,
      height: 124,
    );
    if (complete) {
      canvas.drawOval(
        halo,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[Color(0x57F0C96A), Color(0x00F0C96A)],
          ).createShader(halo),
      );
    }

    final jar = Path()
      ..moveTo(42, 43)
      ..lineTo(100, 43)
      ..lineTo(108, 60)
      ..lineTo(108, 157)
      ..quadraticBezierTo(71, 172, 34, 157)
      ..lineTo(34, 60)
      ..close();
    canvas.drawPath(
      jar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFC99A3D),
    );
    if (refilled) {
      canvas
        ..save()
        ..clipPath(jar)
        ..drawRect(
          const Rect.fromLTRB(34, 110, 108, 165),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFCBEAE6), Color(0xFF5A928D)],
            ).createShader(const Rect.fromLTRB(34, 110, 108, 165)),
        )
        ..restore();
      canvas.drawLine(
        const Offset(35, 111),
        const Offset(107, 111),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFFBFE4DF),
      );
    }
    final cap = Path()
      ..moveTo(42, 43)
      ..lineTo(48, 31)
      ..lineTo(94, 31)
      ..lineTo(100, 43);
    canvas.drawPath(
      cap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFC99A3D),
    );
    if (visible) {
      final provisionMark = Path()
        ..moveTo(112, 72)
        ..lineTo(131, 72)
        ..lineTo(131, 136)
        ..lineTo(112, 136)
        ..moveTo(117, 80)
        ..lineTo(126, 80);
      canvas.drawPath(
        provisionMark,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFF0C96A),
      );
    }
    canvas.drawLine(
      const Offset(45, 94),
      const Offset(97, 94),
      Paint()
        ..strokeWidth = .8
        ..color = const Color(0x57C99A3D),
    );
    final labelSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: refilled ? const Color(0xFFE8B27C) : const Color(0x61E8B27C),
        fontFamily: 'CormorantGaramond',
        fontSize: 9,
        fontStyle: FontStyle.italic,
      ),
    );
    final painter = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, Offset(71 - painter.width / 2, 79));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SmallSupplyJarPainter oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.refilled != refilled ||
      oldDelegate.visible != visible ||
      oldDelegate.complete != complete;
}

class OfferingTableCourseTrack extends StatelessWidget {
  const OfferingTableCourseTrack({
    super.key,
    this.dayNumber = 1,
    this.stageLabel = 'PERSONAL',
  });

  final int dayNumber;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              for (var index = 1; index <= 30; index++)
                Expanded(
                  child: Align(
                    child: Transform.rotate(
                      angle: index % 10 == 0 ? .7853981633974483 : 0,
                      child: Container(
                        width: index % 10 == 0
                            ? 7
                            : index == dayNumber
                            ? 5
                            : 4,
                        height: index % 10 == 0
                            ? 7
                            : index == dayNumber
                            ? 5
                            : 4,
                        decoration: BoxDecoration(
                          color: index < dayNumber
                              ? const Color(0xFF8A7030)
                              : index == dayNumber
                              ? const Color(0xFFF0C96A)
                              : const Color(0xFF2C2318),
                          shape: index % 10 == 0
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          border: index % 10 == 0
                              ? Border.all(color: const Color(0xFF4B3B1F))
                              : null,
                          boxShadow: index == dayNumber
                              ? const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x75F0C96A),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          stageLabel,
          style: const TextStyle(
            color: Color(0xFF8F6D2C),
            fontFamily: 'GentiumPlus',
            fontSize: 8,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
