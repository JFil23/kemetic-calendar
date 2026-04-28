import 'package:flutter/material.dart';

const String _kemeticHeartGlyph = '𓄣';
const List<String> _kemeticHeartFontFallback = <String>[
  'Noto Sans Egyptian Hieroglyphs',
  'NotoSansEgyptianHieroglyphs',
  'Apple Symbols',
  'Segoe UI Historic',
  'Segoe UI Symbol',
  'Arial Unicode MS',
  'NotoSans',
  'GentiumPlus',
];

class KemeticHeartIcon extends StatelessWidget {
  const KemeticHeartIcon({
    super.key,
    required this.size,
    required this.color,
    this.filled = true,
  });

  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (filled) _buildGlyph(color: color, strokeWidth: size * 0.15),
              _buildGlyph(
                color: color,
                strokeWidth: filled ? null : size * 0.07,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlyph({required Color color, double? strokeWidth}) {
    return Text(
      _kemeticHeartGlyph,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: strokeWidth == null ? color : null,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 0.9,
        fontFamilyFallback: _kemeticHeartFontFallback,
        foreground: strokeWidth == null
            ? null
            : (Paint()
                ..style = PaintingStyle.stroke
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..strokeWidth = strokeWidth
                ..color = color),
      ),
    );
  }
}
