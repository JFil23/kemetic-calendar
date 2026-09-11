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
    size: const Size(248, 225),
  );
}

/// The narrow shrine geometry used by the authored Kꜣr Day View hero.
class KarDayShrineVisual extends StatelessWidget {
  const KarDayShrineVisual({
    super.key,
    this.color = const Color(0xFF91B7C7),
    this.placedStages = const <int>{},
    this.currentStage,
  });

  final Color color;
  final Set<int> placedStages;
  final int? currentStage;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _KarDayShrinePainter(
      color: color,
      placedStages: placedStages,
      currentStage: currentStage,
    ),
    size: const Size(120, 190),
  );
}

class _KarDayShrinePainter extends CustomPainter {
  const _KarDayShrinePainter({
    required this.color,
    required this.placedStages,
    required this.currentStage,
  });

  final Color color;
  final Set<int> placedStages;
  final int? currentStage;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 190);
    final walking = color == const Color(0xFFD4AE43);
    final accent = walking ? const Color(0xFFDCC879) : const Color(0xFF6A5727);
    final line = Paint()
      ..color = accent.withValues(alpha: .68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF17150D),
          Color(0xFF0D0C08),
          Color(0xFF070706),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 120, 190));

    canvas.drawOval(
      const Rect.fromLTWH(3, 13, 114, 156),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: walking ? .12 : .05),
            Colors.transparent,
          ],
        ).createShader(const Rect.fromLTWH(3, 13, 114, 156)),
    );
    final cornice = Path()
      ..moveTo(19, 33)
      ..quadraticBezierTo(60, 15, 101, 33)
      ..lineTo(96, 48)
      ..lineTo(24, 48)
      ..close();
    canvas.drawPath(cornice, stone);
    canvas.drawPath(cornice, line);
    canvas.drawRect(const Rect.fromLTWH(24, 47, 72, 104), stone);
    canvas.drawRect(const Rect.fromLTWH(24, 47, 72, 104), line);
    canvas.drawLine(const Offset(30, 56), const Offset(30, 143), line);
    canvas.drawLine(const Offset(90, 56), const Offset(90, 143), line);
    canvas.drawRect(
      const Rect.fromLTWH(39, 72, 42, 62),
      Paint()..color = const Color(0xFF050504),
    );
    canvas.drawRect(
      const Rect.fromLTWH(39, 72, 42, 62),
      Paint()
        ..color = accent.withValues(alpha: .50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(13, 149, 94, 12),
      const Radius.circular(3),
    );
    canvas.drawRRect(base, stone);
    canvas.drawRRect(base, line);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KarDayShrinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.currentStage != currentStage ||
      oldDelegate.placedStages.length != placedStages.length ||
      !oldDelegate.placedStages.containsAll(placedStages);
}

class _KarShrineVisualPainter extends CustomPainter {
  const _KarShrineVisualPainter({required this.color, required this.placed});

  final Color color;
  final int placed;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 248;
    final sy = size.height / 225;
    canvas.save();
    canvas.scale(sx, sy);

    final stone = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF11100C), Color(0xFF090806)],
      ).createShader(const Rect.fromLTWH(0, 0, 248, 225));
    final line = Paint()
      ..color = const Color(0xFF44391F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cornice = Path()
      ..moveTo(18, 20)
      ..quadraticBezierTo(124, -2, 230, 20)
      ..quadraticBezierTo(232, 23, 230, 27)
      ..lineTo(226, 31)
      ..lineTo(22, 31)
      ..lineTo(18, 27)
      ..quadraticBezierTo(16, 23, 18, 20)
      ..close();
    canvas.drawPath(cornice, stone);
    canvas.drawPath(cornice, line);

    final body = const Rect.fromLTWH(28, 29, 192, 169);
    canvas.drawRect(body, Paint()..color = const Color(0xFF0A0907));
    canvas.drawRect(body, line);
    for (final x in const <double>[44, 175]) {
      final jamb = Rect.fromLTWH(x, 46, 29, 135);
      canvas.drawRect(jamb, Paint()..color = const Color(0xFF0A0907));
      canvas.drawRect(jamb, line..color = const Color(0xFF3E341D));
    }

    final door = const Rect.fromLTWH(73, 57, 102, 130);
    canvas.drawRect(door, Paint()..color = const Color(0xFF090806));
    canvas.drawRect(door, line..color = const Color(0xFF44391F));
    canvas.drawRect(
      const Rect.fromLTWH(83, 67, 82, 110),
      line..color = const Color(0xFF352C1A),
    );
    canvas.drawLine(
      const Offset(124, 57),
      const Offset(124, 187),
      line..color = const Color(0x99302819),
    );

    final base = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 196, 228, 29),
      const Radius.circular(1),
    );
    canvas.drawRRect(base, stone);
    canvas.drawRRect(base, line..color = const Color(0xFF44391F));

    const points = <Offset>[
      Offset(124, 198),
      Offset(57, 110),
      Offset(191, 110),
      Offset(124, 27),
      Offset(206, 202.5),
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
    this.placedStages = const <int>{},
    this.cycleSequence = 1,
    this.returning = false,
    this.supportText,
    this.onTap,
  });

  final KarNetjer netjer;
  final int stageIndex;
  final String title;
  final double height;
  final double? width;
  final int placedCount;
  final Set<int> placedStages;
  final int cycleSequence;
  final bool returning;
  final String? supportText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isWalk = stageIndex == 5;
    final stage = kKarStages[stageIndex];
    final compact = height < 82;
    final accent = Color(netjer.accentValue);
    final accent2 = Color(netjer.accent2Value);
    final deep = Color(netjer.deepValue);
    final radius = BorderRadius.circular(MaatEventBlockBorderTokens.radius);
    final sitting = (stageIndex + 1).clamp(1, 5);
    final ordinal = sitting.toString().padLeft(2, '0');
    final blockTitle = isWalk
        ? 'Walk the kꜣr'
        : returning
        ? 'Return to the ${stage.place.toLowerCase()}'
        : title;
    final support =
        supportText ??
        (isWalk
            ? 'five places · current cycle only'
            : returning
            ? 'Is it here?'
            : '$ordinal · ${stage.place}');
    final footerLabel = isWalk ? '$placedCount/5' : 'SITTING $sitting OF 5';
    final kicker = compact
        ? 'THE KꜣR · ${netjer.name.toUpperCase()} · CYCLE ${cycleSequence.toString().padLeft(2, '0')}'
        : 'THE KꜣR · ${stage.place.toUpperCase()}';
    bool isPlaced(int index) => placedStages.isNotEmpty
        ? placedStages.contains(index)
        : index < placedCount;

    Widget progressPips({required bool compact}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < 5; index++)
          Container(
            width: compact ? 9 : 15,
            height: compact ? 2 : 3,
            margin: EdgeInsets.only(right: compact ? 3 : 4),
            decoration: BoxDecoration(
              color: isWalk || isPlaced(index)
                  ? accent2
                  : index == stageIndex
                  ? accent
                  : Color.alphaBlend(
                      deep.withValues(alpha: .55),
                      const Color(0xFF2D2921),
                    ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isWalk || isPlaced(index) || index == stageIndex
                  ? <BoxShadow>[
                      BoxShadow(
                        color: (index == stageIndex ? accent : accent2)
                            .withValues(alpha: .42),
                        blurRadius: 7,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );

    final fullContent = Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 82, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kicker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(
              Color.alphaBlend(
                accent2.withValues(alpha: .82),
                const Color(0xFFA98B54),
              ),
              8.5,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            blockTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(const Color(0xFFE8E2D6), 21, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Day ${stage.day.toString().padLeft(2, '0')} · ${stage.place}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(
              Color.alphaBlend(
                accent2.withValues(alpha: .78),
                const Color(0xFFA88F6A),
              ),
              14,
              style: FontStyle.italic,
              lineHeight: 1.2,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              progressPips(compact: false),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$ordinal · ${stage.place.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(
                    Color.alphaBlend(
                      accent2.withValues(alpha: .45),
                      const Color(0xFF7C7467),
                    ),
                    10.5,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                footerLabel,
                style: _style(const Color(0xFF857A64), 10, letterSpacing: .3),
              ),
            ],
          ),
        ],
      ),
    );

    final compactContent = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: 12,
          right: 62,
          top: 8,
          child: Text(
            kicker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(
              Color.alphaBlend(
                accent2.withValues(alpha: .82),
                const Color(0xFFA98B54),
              ),
              7,
              letterSpacing: 1.18,
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 62,
          top: 20,
          child: Text(
            blockTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(
              const Color(0xFFF2EEE7),
              17,
              weight: FontWeight.w600,
              lineHeight: .96,
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 7,
          width: 77,
          child: Text(
            support,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(
              returning
                  ? const Color(0xFF99ADB3)
                  : Color.alphaBlend(
                      accent2.withValues(alpha: .78),
                      const Color(0xFFA88F6A),
                    ),
              9.5,
              style: FontStyle.italic,
            ),
          ),
        ),
        Positioned(
          left: 91,
          right: 62,
          bottom: 7,
          height: 9,
          child: Row(
            children: <Widget>[
              progressPips(compact: true),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  footerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.right,
                  style: _style(const Color(0xFF71878F), 7.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final card = Container(
      key: ValueKey<String>('kar-event-block-$stageIndex'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent.withValues(alpha: .42), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              deep.withValues(alpha: .66),
              const Color(0xFF090806),
            ),
            Color.alphaBlend(
              deep.withValues(alpha: .88),
              const Color(0xFF15130E),
            ),
            Color.alphaBlend(
              deep.withValues(alpha: .48),
              const Color(0xFF070706),
            ),
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
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(.72, 0),
                radius: .72,
                colors: <Color>[
                  accent.withValues(alpha: returning ? .13 : .24),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0xD6040504),
                  Color(0x7A040504),
                  Color(0x05040504),
                ],
                stops: <double>[0, .46, 1],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[accent2, accent],
                ),
              ),
            ),
          ),
          compact ? compactContent : fullContent,
          Positioned(
            right: compact ? 5 : 10,
            top: compact ? 3.5 : 16,
            width: compact ? 52 : 70,
            height: compact ? 54 : 74,
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
  FontStyle? style,
  double? lineHeight,
}) => TextStyle(
  color: color,
  fontFamily: KarFlowVisualTokens.fontFamily,
  fontFamilyFallback: KarFlowVisualTokens.fontFallback,
  fontSize: size,
  fontWeight: weight,
  fontStyle: style,
  letterSpacing: letterSpacing,
  height: lineHeight ?? 1,
);
