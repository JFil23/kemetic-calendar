import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class JournalSkinTokens {
  const JournalSkinTokens._();

  static const String fontFamily = 'CormorantGaramond';

  static const Color black = Color(0xFF000000);
  static const Color pageGlow = Color(0xFF14110A);
  static const Color base0 = Color(0xFF0D0B07);
  static const Color base1 = Color(0xFF120F08);
  static const Color gold = Color(0xFFD4AE43);
  static const Color goldSoft = Color(0xFFE8CF7F);
  static const Color goldDeep = Color(0xFFA98731);
  static const Color silverHi = Color(0xFFC8C4BC);
  static const Color silverMid = Color(0xFF9E9A94);
  static const Color silverLo = Color(0xFF6A6660);
  static const Color leafTop = Color(0xFF241D12);
  static const Color leafMid = Color(0xFF1A140C);
  static const Color leafBottom = Color(0xFF0F0B06);
  static const Color leafCandleMid = Color(0xFF181006);
  static const Color leafCandleLow = Color(0xFF0D0904);
  static const Color hairline = Color.fromRGBO(212, 174, 67, 0.20);
  static const Color greenCheck = Color(0xFF3FA463);
  static const Color checkStroke = Color(0xFF0D0B07);

  static const Color mastheadDivider = Color.fromRGBO(212, 174, 67, 0.18);
  static const Color leafBorder = Color.fromRGBO(212, 174, 67, 0.12);
  static const Color leafInsetHighlight = Color.fromRGBO(255, 255, 255, 0.03);
  static const Color columnEdgeRule = Color.fromRGBO(212, 174, 67, 0.12);
  static const Color floatingGlyphBorder = Color.fromRGBO(212, 174, 67, 0.18);
  static const Color floatingGlyphShadow = Color.fromRGBO(0, 0, 0, 0.80);
  static const Color leafDropShadow = Color.fromRGBO(0, 0, 0, 0.90);

  static const Gradient mastheadDividerGradient = LinearGradient(
    colors: [
      Colors.transparent,
      mastheadDivider,
      mastheadDivider,
      Colors.transparent,
    ],
    stops: [0, 0.30, 0.70, 1],
  );

  static const Gradient leafGradient = LinearGradient(
    begin: Alignment(0.07, -1),
    end: Alignment(-0.07, 1),
    colors: [
      Color(0xFF171107),
      leafCandleMid,
      Color(0xFF130D06),
      leafCandleLow,
    ],
    stops: [0, 0.34, 0.70, 1],
  );

  static const Gradient floatingGlyphBackground = RadialGradient(
    center: Alignment(0, -0.30),
    radius: 0.70,
    colors: [Color(0xFF161208), Color(0xFF0A0805)],
  );

  static const Gradient floatingGlyphIconGradient = LinearGradient(
    colors: [gold, gold],
  );

  static const TextStyle mastheadLabelStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 5,
    color: silverMid,
  );

  static const TextStyle dateEyebrowStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 3,
    color: silverLo,
  );

  static const TextStyle dateTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.0,
    color: gold,
  );

  static const TextStyle dateGlossStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    color: silverMid,
  );

  static const TextStyle formatButtonStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    color: silverMid,
  );

  static const TextStyle savedLineStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: silverLo,
  );

  static const TextStyle entryBodyStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.55,
    color: silverHi,
  );

  static const TextStyle entryPlaceholderStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.55,
    color: silverLo,
  );
}

class JournalBackgroundPainter extends CustomPainter {
  const JournalBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = JournalSkinTokens.black,
    );
    if (size.isEmpty) return;

    final rx = size.width * 0.625;
    final ry = size.height * 0.45;
    final center = Offset(size.width * 0.5, size.height * -0.08);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        rx,
        const [
          JournalSkinTokens.pageGlow,
          JournalSkinTokens.base0,
          JournalSkinTokens.black,
        ],
        const [0, 0.48, 1],
        TileMode.clamp,
      );

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1, ry / rx);

    final transformedRect = Rect.fromLTRB(
      -center.dx,
      -center.dy * rx / ry,
      size.width - center.dx,
      (size.height - center.dy) * rx / ry,
    );
    canvas.drawRect(transformedRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant JournalBackgroundPainter oldDelegate) => false;
}

class JournalLeafDecorationPainter extends CustomPainter {
  const JournalLeafDecorationPainter();

  static const _grainLayers = <_JournalGrainLayer>[
    _JournalGrainLayer(
      tileSize: Size(140, 140),
      position: Offset(0.18, 0.30),
      color: Color.fromRGBO(212, 174, 67, 0.025),
    ),
    _JournalGrainLayer(
      tileSize: Size(180, 180),
      position: Offset(0.62, 0.22),
      color: Color.fromRGBO(255, 255, 255, 0.015),
    ),
    _JournalGrainLayer(
      tileSize: Size(120, 120),
      position: Offset(0.40, 0.60),
      color: Color.fromRGBO(212, 174, 67, 0.020),
    ),
    _JournalGrainLayer(
      tileSize: Size(160, 160),
      position: Offset(0.80, 0.70),
      color: Color.fromRGBO(255, 255, 255, 0.0125),
    ),
    _JournalGrainLayer(
      tileSize: Size(150, 150),
      position: Offset(0.28, 0.82),
      color: Color.fromRGBO(212, 174, 67, 0.020),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintInteriorWash(canvas, size);
    _paintCrown(canvas, size);
    _paintGrain(canvas, size);
    _paintTopHighlight(canvas, size);
  }

  void _paintInteriorWash(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final warmFieldPaint = Paint()
      ..color = const Color.fromRGBO(212, 174, 67, 0.006);
    canvas.drawRect(rect, warmFieldPaint);

    final topGlow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(232, 207, 127, 0.036),
          Color.fromRGBO(212, 174, 67, 0.012),
          Colors.transparent,
        ],
        stops: [0, 0.34, 0.78],
      ).createShader(rect);
    canvas.drawRect(rect, topGlow);

    final centerGlow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.52, size.height * 0.36),
        size.width * 0.68,
        const [
          Color.fromRGBO(232, 207, 127, 0.070),
          Color.fromRGBO(212, 174, 67, 0.026),
          Colors.transparent,
        ],
        const [0, 0.46, 1],
        TileMode.clamp,
      );
    canvas.drawRect(rect, centerGlow);

    final edgeShade = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.52, size.height * 0.42),
        size.width * 0.82,
        const [
          Colors.transparent,
          Color.fromRGBO(0, 0, 0, 0.16),
          Color.fromRGBO(0, 0, 0, 0.32),
        ],
        const [0, 0.68, 1],
        TileMode.clamp,
      );
    canvas.drawRect(rect, edgeShade);
  }

  void _paintCrown(Canvas canvas, Size size) {
    final rx = size.width * 0.39;
    final ry = size.height * 0.23;
    final center = Offset(size.width * 0.5, size.height * -0.14);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        rx,
        const [
          Color.fromRGBO(212, 174, 67, 0.13),
          Color.fromRGBO(212, 174, 67, 0.035),
          Colors.transparent,
        ],
        const [0, 0.42, 0.68],
        TileMode.clamp,
      );

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1, ry / rx);
    final transformedRect = Rect.fromLTRB(
      -center.dx,
      -center.dy * rx / ry,
      size.width - center.dx,
      (size.height - center.dy) * rx / ry,
    );
    canvas.drawRect(transformedRect, paint);
    canvas.restore();
  }

  void _paintGrain(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final layer in _grainLayers) {
      final paint = Paint()
        ..color = layer.color
        ..blendMode = BlendMode.overlay;
      for (
        double y = -layer.tileSize.height;
        y < size.height + layer.tileSize.height;
        y += layer.tileSize.height
      ) {
        for (
          double x = -layer.tileSize.width;
          x < size.width + layer.tileSize.width;
          x += layer.tileSize.width
        ) {
          final center = Offset(
            x + layer.tileSize.width * layer.position.dx,
            y + layer.tileSize.height * layer.position.dy,
          );
          if (center.dx < -2 ||
              center.dy < -2 ||
              center.dx > size.width + 2 ||
              center.dy > size.height + 2) {
            continue;
          }
          canvas.drawCircle(center, 1, paint);
        }
      }
    }
    canvas.restore();
  }

  void _paintTopHighlight(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = JournalSkinTokens.leafInsetHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant JournalLeafDecorationPainter oldDelegate) =>
      false;
}

class _JournalGrainLayer {
  const _JournalGrainLayer({
    required this.tileSize,
    required this.position,
    required this.color,
  });

  final Size tileSize;
  final Offset position;
  final Color color;
}
