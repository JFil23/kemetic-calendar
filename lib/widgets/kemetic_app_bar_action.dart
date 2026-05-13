import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';

class KemeticAppBarAction extends StatelessWidget {
  const KemeticAppBarAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.width = 44,
    this.iconBoxSize = 28,
    this.iconOffset = Offset.zero,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final double width;
  final double iconBoxSize;
  final Offset iconOffset;

  @override
  Widget build(BuildContext context) {
    final alignedIcon = iconOffset == Offset.zero
        ? icon
        : Transform.translate(offset: iconOffset, child: icon);

    return IconButton(
      tooltip: tooltip,
      constraints: BoxConstraints.tightFor(
        width: width,
        height: kToolbarHeight,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 22,
      visualDensity: VisualDensity.compact,
      icon: SizedBox.square(
        dimension: iconBoxSize,
        child: Center(child: alignedIcon),
      ),
      onPressed: onPressed,
    );
  }
}

class KemeticAppBarProfileIcon extends StatelessWidget {
  const KemeticAppBarProfileIcon({super.key});

  static const double _boxSize = 28;
  static const double _glyphSize = 31;
  static const Offset _glyphOffset = Offset(-3.5, -2.5);
  static const double _strokeWidth = 0.60;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _boxSize,
      child: Center(
        child: Transform.translate(
          offset: _glyphOffset,
          child: SizedBox.square(
            dimension: _glyphSize,
            child: CustomPaint(painter: const _ProfileGlyphPainter()),
          ),
        ),
      ),
    );
  }
}

class _ProfileGlyphPainter extends CustomPainter {
  const _ProfileGlyphPainter();

  static const _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );
  static const _strutStyle = StrutStyle(
    fontSize: KemeticAppBarProfileIcon._glyphSize,
    height: 1,
    forceStrutHeight: true,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final glyphPainter = _createTextPainter(
      Paint()
        ..shader = KemeticGold.gloss.createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = KemeticAppBarProfileIcon._strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    _paintCentered(canvas, size, glyphPainter);
  }

  static TextPainter _createTextPainter(Paint paint) {
    return TextPainter(
      text: TextSpan(
        text: MeduNeterGlyphs.profileAppBar,
        style: TextStyle(
          foreground: paint,
          fontSize: KemeticAppBarProfileIcon._glyphSize,
          height: 1,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          fontFamily: 'Noto Sans Egyptian Hieroglyphs',
          fontFamilyFallback: meduNeterFontFallback,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      strutStyle: _strutStyle,
      textHeightBehavior: _textHeightBehavior,
    )..layout();
  }

  static void _paintCentered(Canvas canvas, Size size, TextPainter painter) {
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileGlyphPainter oldDelegate) => false;
}

class KemeticAppBarTodayIcon extends StatelessWidget {
  const KemeticAppBarTodayIcon({
    super.key,
    this.gradient = KemeticGold.gloss,
    this.boxSize = 28,
    this.glyphSize = 23,
    this.glyphOffset = Offset.zero,
  });

  final Gradient gradient;
  final double boxSize;
  final double glyphSize;
  final Offset glyphOffset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: boxSize,
      child: CustomPaint(
        painter: _TodayGlyphPainter(
          gradient: gradient,
          diameter: glyphSize,
          offset: glyphOffset,
        ),
      ),
    );
  }
}

class _TodayGlyphPainter extends CustomPainter {
  const _TodayGlyphPainter({
    required this.gradient,
    required this.diameter,
    required this.offset,
  });

  final Gradient gradient;
  final double diameter;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final strokeWidth = (diameter * 0.105).clamp(1.6, 2.5).toDouble();
    final center = bounds.center + offset;
    final radius = (diameter - strokeWidth) / 2;
    final shader = gradient.createShader(bounds);

    final ringPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, ringPaint);

    final dotPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(
      center,
      (diameter * 0.135).clamp(2.0, 3.2).toDouble(),
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TodayGlyphPainter oldDelegate) =>
      oldDelegate.gradient != gradient ||
      oldDelegate.diameter != diameter ||
      oldDelegate.offset != offset;
}

class KemeticAppBarSearchIcon extends StatelessWidget {
  const KemeticAppBarSearchIcon({
    super.key,
    this.gradient = KemeticGold.gloss,
    this.boxSize = 28,
    this.glyphSize = 30,
    this.glyphOffset = const Offset(-0.5, -1.0),
    this.strokeWidth = 0.82,
  });

  final Gradient gradient;
  final double boxSize;
  final double glyphSize;
  final Offset glyphOffset;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: boxSize,
      child: CustomPaint(
        painter: _SearchGlyphPainter(
          gradient: gradient,
          glyphSize: glyphSize,
          glyphOffset: glyphOffset,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SearchGlyphPainter extends CustomPainter {
  const _SearchGlyphPainter({
    required this.gradient,
    required this.glyphSize,
    required this.glyphOffset,
    required this.strokeWidth,
  });

  final Gradient gradient;
  final double glyphSize;
  final Offset glyphOffset;
  final double strokeWidth;

  static const _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final textPainter = TextPainter(
      text: TextSpan(
        text: MeduNeterGlyphs.search,
        style: TextStyle(
          foreground: Paint()
            ..shader = gradient.createShader(bounds)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
          fontSize: glyphSize,
          height: 1,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          fontFamily: 'Noto Sans Egyptian Hieroglyphs',
          fontFamilyFallback: meduNeterFontFallback,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle(
        fontSize: glyphSize,
        height: 1,
        forceStrutHeight: true,
      ),
      textHeightBehavior: _textHeightBehavior,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          ) +
          glyphOffset,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchGlyphPainter oldDelegate) =>
      oldDelegate.gradient != gradient ||
      oldDelegate.glyphSize != glyphSize ||
      oldDelegate.glyphOffset != glyphOffset ||
      oldDelegate.strokeWidth != strokeWidth;
}
