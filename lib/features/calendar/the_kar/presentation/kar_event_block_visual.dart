import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../the_kar_models.dart';

class KarShrineMark extends StatelessWidget {
  const KarShrineMark({
    super.key,
    this.color = const Color(0xFF91B7C7),
    this.placed = 0,
  });
  final Color color;
  final int placed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _KarShrinePainter(color: color, placed: placed),
    size: const Size(70, 74),
  );
}

/// The authored full-size kꜣr used by the detail and Day View sheets.
/// Event blocks continue to use [KarShrineMark], the compact version of the
/// same geometry.
class KarShrineVisual extends StatelessWidget {
  const KarShrineVisual({
    super.key,
    this.color = const Color(0xFF91B7C7),
    this.placed = 0,
  });

  final Color color;
  final int placed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _KarShrineVisualPainter(color: color, placed: placed),
    size: const Size(246, 218),
  );
}

class _KarShrineVisualPainter extends CustomPainter {
  const _KarShrineVisualPainter({required this.color, required this.placed});

  final Color color;
  final int placed;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 246;
    final sy = size.height / 218;
    canvas.save();
    canvas.scale(sx, sy);

    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF11100C), Color(0xFF090806)],
      ).createShader(const Rect.fromLTWH(0, 0, 246, 218));
    final line = Paint()
      ..color = const Color(0xFF44391F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 0, 218, 28),
        const Radius.circular(14),
      ),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 0, 218, 28),
        const Radius.circular(14),
      ),
      line,
    );

    final body = const Rect.fromLTWH(23, 26, 200, 168);
    canvas.drawRect(body, Paint()..color = const Color(0xFF0A0907));
    canvas.drawRect(body, line);
    for (final x in const <double>[34, 191]) {
      final jamb = Rect.fromLTWH(x, 37, 21, 146);
      canvas.drawRect(jamb, Paint()..color = const Color(0xFF0A0907));
      canvas.drawRect(jamb, line..color = const Color(0xFF3E341D));
    }

    final door = const Rect.fromLTWH(73.5, 50, 99, 127);
    canvas.drawRect(door, Paint()..color = const Color(0xFF090806));
    canvas.drawRect(door, line..color = const Color(0xFF44391F));
    canvas.drawRect(
      const Rect.fromLTWH(83.5, 60, 79, 107),
      line..color = const Color(0xFF352C1A),
    );
    canvas.drawLine(
      const Offset(123, 50),
      const Offset(123, 177),
      line..color = const Color(0x99302819),
    );

    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6, 193, 234, 25),
      const Radius.circular(1),
    );
    canvas.drawRRect(base, stone);
    canvas.drawRRect(base, line..color = const Color(0xFF44391F));

    const points = <Offset>[
      Offset(123, 189),
      Offset(16, 84),
      Offset(230, 84),
      Offset(123, 12),
      Offset(214, 211),
    ];
    final count = placed.clamp(0, 5);
    for (var index = 0; index < points.length; index++) {
      if (index > count) continue;
      final isTarget = index == count && count < 5;
      final dot = Paint()
        ..color = isTarget
            ? color
            : color.withValues(alpha: index < count ? .72 : .12)
        ..style = PaintingStyle.fill;
      if (isTarget) {
        canvas.drawCircle(
          points[index],
          15,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[color.withValues(alpha: .36), Colors.transparent],
            ).createShader(Rect.fromCircle(center: points[index], radius: 15)),
        );
      }
      canvas.drawCircle(points[index], isTarget ? 6 : 5, dot);
      canvas.drawCircle(
        points[index],
        isTarget ? 6 : 5,
        Paint()
          ..color = color.withValues(alpha: isTarget ? .9 : .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KarShrineVisualPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.placed != placed;
}

class _KarShrinePainter extends CustomPainter {
  const _KarShrinePainter({required this.color, required this.placed});
  final Color color;
  final int placed;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 70;
    final sy = size.height / 74;
    canvas.save();
    canvas.scale(sx, sy);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[color.withValues(alpha: .27), Colors.transparent],
      ).createShader(const Rect.fromLTWH(1, 3, 68, 68));
    canvas.drawOval(const Rect.fromLTWH(1, 3, 68, 68), glow);
    final line = Paint()
      ..color = const Color(0xFF725D2B).withValues(alpha: .84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF17150D),
          Color(0xFF0C0B08),
          Color(0xFF070706),
        ],
      ).createShader(const Rect.fromLTWH(11, 8, 48, 57));
    final cornice = Path()
      ..moveTo(14, 15)
      ..quadraticBezierTo(35, 6, 56, 15)
      ..lineTo(53, 22)
      ..lineTo(17, 22)
      ..close();
    canvas.drawPath(cornice, stone);
    canvas.drawPath(cornice, line);
    canvas.drawRect(const Rect.fromLTWH(17, 21, 36, 40), stone);
    canvas.drawRect(const Rect.fromLTWH(17, 21, 36, 40), line);
    canvas.drawRect(
      const Rect.fromLTWH(25, 30, 20, 25),
      Paint()..color = const Color(0xFF050504),
    );
    canvas.drawRect(
      const Rect.fromLTWH(25, 30, 20, 25),
      line..color = const Color(0xFF725D2B).withValues(alpha: .62),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 59, 48, 6),
        const Radius.circular(1.5),
      ),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 59, 48, 6),
        const Radius.circular(1.5),
      ),
      line..color = const Color(0xFF725D2B).withValues(alpha: .74),
    );
    final dot = Paint()..color = color;
    for (var index = 0; index < placed.clamp(0, 5); index++) {
      canvas.drawCircle(
        Offset(29 + (index % 3) * 6, 38 + (index ~/ 3) * 7),
        1.6,
        dot,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KarShrinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.placed != placed;
}

class KarEventBlockVisual extends StatelessWidget {
  const KarEventBlockVisual({
    super.key,
    required this.netjer,
    required this.stageIndex,
    required this.title,
    this.height = 106,
    this.width,
    this.placedCount = 0,
    this.returning = false,
    this.onTap,
  });

  final KarNetjer netjer;
  final int stageIndex;
  final String title;
  final double height;
  final double? width;
  final int placedCount;
  final bool returning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isWalk = stageIndex == 5;
    final stage = kKarStages[stageIndex];
    final compact = height < 82;
    final accent = Color(netjer.accentValue);
    final radius = BorderRadius.circular(MaatEventBlockBorderTokens.radius);
    final card = Container(
      key: ValueKey<String>('kar-event-block-$stageIndex'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: MaatEventBlockBorderTokens.color,
          width: MaatEventBlockBorderTokens.width,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF17150D),
            Color(0xFF0C0B08),
            Color(0xFF070706),
          ],
        ),
        boxShadow: <BoxShadow>[
          const BoxShadow(
            color: Color(0x85000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
          BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 14),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 15,
              compact ? 7 : 12,
              compact ? 74 : 92,
              compact ? 6 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'THE KꜣR · ${netjer.name.toUpperCase()}${isWalk
                      ? ''
                      : returning
                      ? ' · RETURN'
                      : ' · SITTING ${(stageIndex + 1).toString().padLeft(2, '0')}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(
                    const Color(0xFF8A7030),
                    compact ? 8.5 : 9.5,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),
                Text(
                  isWalk
                      ? 'Walk the kꜣr'
                      : returning
                      ? 'Return to the ${stage.place.toLowerCase()}'
                      : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(
                    const Color(0xFFF2EEE5),
                    compact ? 17 : 24,
                    weight: FontWeight.w600,
                  ),
                ),
                if (!compact) ...[
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      for (var index = 0; index < 5; index++)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: index < placedCount
                                ? accent
                                : index == stageIndex
                                ? const Color(0xFFD4AE43)
                                : const Color(0xFF3A372E),
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isWalk
                              ? 'DAY 30 · INNER CHAMBER'
                              : '${(stageIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(
                            const Color(0xFF8D877D),
                            8,
                            letterSpacing: .9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: compact ? 5 : 12,
            top: compact ? -2 : 14,
            width: compact ? 64 : 76,
            height: compact ? 64 : 78,
            child: KarShrineMark(
              color: accent,
              placed: isWalk ? 5 : placedCount,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: '$title, Day ${stage.day}, ${stage.place}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: radius, child: card),
      ),
    );
  }
}

TextStyle _style(
  Color color,
  double size, {
  double? letterSpacing,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  color: color,
  fontFamily: MaatFlowListTokens.fontFamily,
  fontFamilyFallback: MaatFlowListTokens.fontFallback,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  height: 1,
);
