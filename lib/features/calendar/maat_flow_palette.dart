import 'package:flutter/material.dart';

class MaatFlowPalette {
  const MaatFlowPalette({
    required this.accent,
    required this.glowColor,
    this.isGraphic = false,
    this.iconGradientStops,
  });

  final Color accent;
  final Color glowColor;
  final bool isGraphic;
  final List<Color>? iconGradientStops;

  static const Color joinedBase = Color(0xFF120F08);
  static const Color unjoinedBase = Color(0xFF0D0B07);

  static const Color silverHi = Color(0xFFC8C4BC);
  static const Color silverMid = Color(0xFF9E9A94);
  static const Color silverLo = Color(0xFF6A6660);

  static const Color gold = Color(0xFFD4AE43);
  static const Color goldDim = Color(0xFF8A7030);
  static const Color goldMute = Color(0xFF5A4A20);
  static const Color interiorLabel = Color(0xFFD8B64E);

  static const Color separator = Color(0xFF1E1A0C);
  static const Color warmDark = Color(0xFF1A1508);

  static MaatFlowPalette resolve({
    required String flowId,
    required Color accent,
  }) {
    final override = _graphicOverrides[flowId.trim()];
    if (override != null) return override;
    return MaatFlowPalette(accent: accent, glowColor: accent);
  }

  static const Map<String, MaatFlowPalette> _graphicOverrides = {
    'track-the-sky': MaatFlowPalette(
      accent: Color(0xFF6876D8),
      glowColor: Color(0xFFA4B1FF),
      isGraphic: true,
      iconGradientStops: [
        Color(0xFF090D1E),
        Color(0xFF222A5B),
        Color(0xFF4B5EBB),
      ],
    ),
    'dawn-house-rite': MaatFlowPalette(
      accent: Color(0xFFEFA25C),
      glowColor: Color(0xFFFFD08A),
      isGraphic: true,
      iconGradientStops: [
        Color(0xFF12152C),
        Color(0xFF3A315D),
        Color(0xFFB56A6E),
      ],
    ),
    'evening-threshold-rite': MaatFlowPalette(
      accent: Color(0xFF6F58D9),
      glowColor: Color(0xFF7FE0D4),
      isGraphic: true,
      iconGradientStops: [
        Color(0xFF030611),
        Color(0xFF111634),
        Color(0xFF193248),
      ],
    ),
    'the-weighing': MaatFlowPalette(
      accent: Color(0xFFB8A88A),
      glowColor: Color(0xFFF5E8CB),
      isGraphic: true,
      iconGradientStops: [
        Color(0xFF111213),
        Color(0xFF2C2A25),
        Color(0xFF5D5241),
      ],
    ),
    'the-reading-house': MaatFlowPalette(
      accent: Color(0xFF4FA58D),
      glowColor: Color(0xFFA8E6D1),
      iconGradientStops: [
        Color(0xFF07130F),
        Color(0xFF12362D),
        Color(0xFF4FA58D),
      ],
    ),
  };
}

class MaatFlowSurface extends StatelessWidget {
  const MaatFlowSurface({
    super.key,
    required this.palette,
    required this.child,
    required this.borderRadius,
    this.showCrown = false,
    this.showTopGlow = true,
    this.washOpacity = 0.07,
    this.border,
    this.padding,
    this.baseColor = MaatFlowPalette.joinedBase,
  });

  final MaatFlowPalette palette;
  final Widget child;
  final BorderRadius borderRadius;
  final bool showCrown;
  final bool showTopGlow;
  final double washOpacity;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius, border: border),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: baseColor)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      palette.accent.withValues(alpha: washOpacity * 2),
                      palette.accent.withValues(alpha: washOpacity),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.38, 0.70],
                  ),
                ),
              ),
            ),
            if (showCrown)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -1.4),
                      radius: 0.85,
                      colors: [
                        const Color(0xFFFFF8E6).withValues(alpha: 0.14),
                        const Color(0xFFFFF8E6).withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 0.75],
                    ),
                  ),
                ),
              ),
            if (showTopGlow)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    widthFactor: 0.84,
                    child: SizedBox(
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              palette.glowColor.withValues(alpha: 0.16),
                              palette.glowColor.withValues(alpha: 0.36),
                              palette.glowColor.withValues(alpha: 0.16),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.28, 0.50, 0.72, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ],
        ),
      ),
    );
  }
}
