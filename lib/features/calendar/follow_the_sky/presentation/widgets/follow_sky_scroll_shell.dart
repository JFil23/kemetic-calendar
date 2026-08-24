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
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = FollowSkyV11Tokens.heroHeight * (width / FollowSkyV11Tokens.referenceWidth);
    final overlap = FollowSkyV11Tokens.sheetOverlap * (width / FollowSkyV11Tokens.referenceWidth);
    final parallax = _scrollOffset * FollowSkyV11Tokens.heroParallaxFactor;
    final fadeT = (_scrollOffset / FollowSkyV11Tokens.heroFadeScrollDistance).clamp(0.0, 1.0);
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
            controller: _controller,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: heroHeight - overlap)),
              SliverToBoxAdapter(child: widget.sheet),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          if (widget.bottomBar != null)
            Positioned(left: 0, right: 0, bottom: 0, child: widget.bottomBar!),
        ],
      ),
    );
  }
}

class FollowSkyHero extends StatelessWidget {
  const FollowSkyHero({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = FollowSkyV11Tokens.heroHeight * (width / FollowSkyV11Tokens.referenceWidth);

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            FollowSkyV11Tokens.heroAsset,
            fit: BoxFit.cover,
            alignment: Alignment(0, FollowSkyV11Tokens.heroImageAlignmentY * 2 - 1),
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF050812)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.18),
                  FollowSkyV11Tokens.pageBg.withValues(alpha: 0.92),
                  FollowSkyV11Tokens.pageBg,
                ],
                stops: const [0.0, 0.45, 0.82, 1.0],
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _FollowSkyOrbitalArcsPainter(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: overlapReserve(context) + 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FollowSkyV11Tokens.gold,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FollowSkyV11Tokens.silverHi,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double overlapReserve(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return FollowSkyV11Tokens.sheetOverlap * (width / FollowSkyV11Tokens.referenceWidth);
  }
}

class _FollowSkyOrbitalArcsPainter extends CustomPainter {
  _FollowSkyOrbitalArcsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = size.width / 2;
    final radii = [size.width * 0.39, size.width * 0.62, size.width * 0.86];
    for (final rx in radii) {
      final rect = Rect.fromCenter(
        center: Offset(cx, -size.height * 0.1),
        width: rx * 2,
        height: rx * 1.85,
      );
      canvas.drawArc(rect, math.pi * 0.08, math.pi * 0.84, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
