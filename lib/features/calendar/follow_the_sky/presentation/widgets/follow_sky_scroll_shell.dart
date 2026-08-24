import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../maat_flow_visual_tokens.dart';
import 'follow_sky_v11_tokens.dart';

/// Single-scroll Follow Sky shell: hero recedes at [FollowSkyV11Tokens.heroParallaxFactor].
class FollowSkyScrollShell extends StatefulWidget {
  const FollowSkyScrollShell({
    super.key,
    required this.hero,
    required this.sheet,
    this.bottomBar,
    this.scrollController,
  });

  final Widget hero;
  final Widget sheet;
  final Widget? bottomBar;
  final ScrollController? scrollController;

  @override
  State<FollowSkyScrollShell> createState() => _FollowSkyScrollShellState();
}

class _FollowSkyScrollShellState extends State<FollowSkyScrollShell> {
  late final ScrollController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.scrollController == null;
    _controller = widget.scrollController ?? ScrollController();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onScroll() => setState(() {});

  double get _scrollOffset => _controller.hasClients ? _controller.offset : 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final widthScaledHero =
            FollowSkyV11Tokens.heroHeight *
            (width / FollowSkyV11Tokens.referenceWidth);
        final heightScaledHero =
            constraints.maxHeight *
            (FollowSkyV11Tokens.heroHeight /
                FollowSkyV11Tokens.referenceHeight);
        final heroHeight = math.min(widthScaledHero, heightScaledHero);
        final overlap =
            FollowSkyV11Tokens.sheetOverlap *
            (width / FollowSkyV11Tokens.referenceWidth);
        final parallax = _scrollOffset * FollowSkyV11Tokens.heroParallaxFactor;
        final fadeT =
            (_scrollOffset / FollowSkyV11Tokens.heroFadeScrollDistance).clamp(
              0.0,
              1.0,
            );
        final heroOpacity = 1 - fadeT;

        return ColoredBox(
          color: FollowSkyV11Tokens.pageBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -parallax,
                left: 0,
                right: 0,
                height: heroHeight,
                child: Opacity(opacity: heroOpacity, child: widget.hero),
              ),
              CustomScrollView(
                key: const ValueKey<String>('follow-sky-scroll'),
                controller: _controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: heroHeight - overlap),
                  ),
                  SliverToBoxAdapter(child: widget.sheet),
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: FollowSkyV11Tokens.bottomContentClearance,
                    ),
                  ),
                ],
              ),
              if (widget.bottomBar != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.bottomBar!,
                ),
            ],
          ),
        );
      },
    );
  }
}

class FollowSkyHero extends StatelessWidget {
  const FollowSkyHero({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            FollowSkyV11Tokens.heroAsset,
            fit: BoxFit.cover,
            alignment: Alignment(
              0,
              FollowSkyV11Tokens.heroImageAlignmentY * 2 - 1,
            ),
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: Color(0xFF050812)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x05050504),
                  Color(0x05050504),
                  Color(0x2E050504),
                  Color(0x94050504),
                ],
                stops: [0.0, 0.46, 0.70, 1.0],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x1A050504),
                    FollowSkyV11Tokens.pageBg,
                    FollowSkyV11Tokens.pageBg,
                  ],
                  stops: [0.0, 0.38, 0.92, 1.0],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _FollowSkyOrbitalArcsPainter(
                color: const Color(0xFFA4B1FF).withValues(alpha: 0.015),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FollowSkyHeroGlyph(),
                const SizedBox(height: 16),
                Text(
                  title == 'Follow the sky' ? 'Follow\nthe sky' : title,
                  style: const TextStyle(
                    color: FollowSkyV11Tokens.gold,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: -0.48,
                    shadows: [
                      Shadow(
                        color: Color(0xB8000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 250,
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.silverHi,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 19,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Color(0xC7000000),
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowSkyHeroGlyph extends StatelessWidget {
  const _FollowSkyHeroGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.24, -0.44),
          radius: 0.9,
          colors: [Color(0xE04B5EBB), Color(0xEB222A5B), Color(0xFA090D1E)],
          stops: [0.0, 0.48, 1.0],
        ),
        border: Border.all(
          color: FollowSkyV11Tokens.intentionPeriwinkle.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA4B1FF).withValues(alpha: 0.13),
            blurRadius: 26,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CustomPaint(painter: _FollowSkyHeroGlyphPainter()),
      ),
    );
  }
}

class _FollowSkyHeroGlyphPainter extends CustomPainter {
  const _FollowSkyHeroGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24;
    final scaleY = size.height / 24;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final paint = Paint()
      ..color = FollowSkyV11Tokens.intentionPeriwinkle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 6.5), 3, paint);
    canvas.drawLine(const Offset(12, 9.5), const Offset(12, 20.5), paint);
    final arms = Path()
      ..moveTo(6, 13)
      ..lineTo(12, 10.5)
      ..lineTo(18, 13);
    canvas.drawPath(arms, paint);
    final legs = Path()
      ..moveTo(8, 21)
      ..lineTo(12, 15)
      ..lineTo(16, 21);
    canvas.drawPath(legs, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FollowSkyOrbitalArcsPainter extends CustomPainter {
  _FollowSkyOrbitalArcsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final cx = size.width / 2;
    final radii = [
      size.width * (152 / 390),
      size.width * (245 / 390),
      size.width * (336 / 390),
      size.width * (436 / 390),
    ];
    for (final rx in radii) {
      final rect = Rect.fromCenter(
        center: Offset(cx, -size.height * 0.1),
        width: rx * 2,
        height: rx * 1.868,
      );
      canvas.drawArc(rect, math.pi * 0.08, math.pi * 0.84, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
