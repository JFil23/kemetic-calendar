import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import '../../shared/glossy_text.dart';

class NodeGlyphMark extends StatelessWidget {
  const NodeGlyphMark({
    super.key,
    required this.glyph,
    required this.width,
    required this.height,
    required this.fontSize,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
    this.framed = false,
    this.borderRadius = 12,
    this.shadows = false,
    this.frameColor,
    this.borderColor,
    this.gradient,
  });

  final String glyph;
  final double width;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;
  final bool framed;
  final double borderRadius;
  final bool shadows;
  final Color? frameColor;
  final Color? borderColor;
  final Gradient? gradient;

  static const List<String> _glyphFontFallback = [
    'NotoSansEgyptianHieroglyphs',
    'GentiumPlus',
    'NotoSans',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  String get _compactGlyph => glyph.replaceAll(RegExp(r'\s+'), '').trim();

  List<String> _glyphSigns(String displayGlyph) =>
      displayGlyph.runes.map(String.fromCharCode).toList();

  List<String> _compoundRows(List<String> signs) {
    if (signs.length == 3) {
      return [signs.first, signs.skip(1).join()];
    }
    if (signs.length == 4) {
      return [signs.take(2).join(), signs.skip(2).join()];
    }
    if (signs.length == 5) {
      return [signs.take(3).join(), signs.skip(3).join()];
    }
    return [signs.join()];
  }

  Widget _text(String text, TextStyle style, StrutStyle strutStyle) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      strutStyle: strutStyle,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayGlyph = _compactGlyph.isEmpty ? glyph.trim() : _compactGlyph;
    final signs = _glyphSigns(displayGlyph);
    final shouldStackCompound = framed && signs.length >= 3;
    final visualNudge = Offset(0, -height * 0.04);
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
      color: Colors.white,
      fontFamily: 'Noto Sans Egyptian Hieroglyphs',
      fontFamilyFallback: _glyphFontFallback,
      letterSpacing: 0,
      shadows: shadows
          ? const [
              Shadow(
                color: Colors.black54,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
              Shadow(
                color: Colors.white12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ]
          : null,
    );
    final strutStyle = StrutStyle(
      fontFamily: 'Noto Sans Egyptian Hieroglyphs',
      fontFamilyFallback: _glyphFontFallback,
      fontSize: fontSize,
      height: 1,
      forceStrutHeight: true,
    );
    final glyphContent = shouldStackCompound
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: _compoundRows(
              signs,
            ).map((row) => _text(row, textStyle, strutStyle)).toList(),
          )
        : _text(displayGlyph, textStyle, strutStyle);

    final mark = SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Padding(
          padding: padding,
          child: Align(
            alignment: alignment,
            child: Transform.translate(
              offset: visualNudge,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: alignment,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) =>
                      (gradient ?? KemeticGold.gloss).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: glyphContent,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!framed) return mark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? Colors.white12),
        color: frameColor ?? Colors.white.withValues(alpha: 0.04),
      ),
      child: mark,
    );
  }
}

class GlyphBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool showLabel;
  final bool showCloseIcon;

  const GlyphBackButton({
    super.key,
    required this.onTap,
    this.showLabel = true,
    this.showCloseIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final minTouchSize = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTouchSize,
          minHeight: minTouchSize,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showCloseIcon)
                KemeticGold.icon(Icons.close, size: 20)
              else
                SizedBox(
                  height: 20,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) =>
                          KemeticGold.gloss.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        '𓋴 𓄿 𓏏 𓂋',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontFamily: 'GentiumPlus',
                          fontFamilyFallback: [
                            'NotoSans',
                            'Roboto',
                            'Arial',
                            'sans-serif',
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (showLabel) ...[
                const SizedBox(height: 2),
                const Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'GentiumPlus',
                    fontFamilyFallback: [
                      'NotoSans',
                      'Roboto',
                      'Arial',
                      'sans-serif',
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
