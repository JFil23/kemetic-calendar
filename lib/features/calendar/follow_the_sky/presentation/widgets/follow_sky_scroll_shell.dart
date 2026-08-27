import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../presentation/maat_flow_detail_shell.dart';
import 'follow_sky_v11_tokens.dart';

/// Follow the Sky's own art direction inside the shared Ma'at hero geometry.
class FollowSkyHero extends StatelessWidget {
  const FollowSkyHero({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      theme: FollowSkyV11Tokens.detailTheme,
      background: const _FollowSkyHeroBackdrop(),
      glyph: '𓇼', // sbꜣ — star — Egyptian hieroglyph N14.
      glyphKey: const ValueKey<String>('follow-sky-hero-star'),
      glyphGradient: const RadialGradient(
        center: Alignment(-0.24, -0.44),
        radius: 0.9,
        colors: [Color(0xE04B5EBB), Color(0xEB222A5B), Color(0xFA090D1E)],
        stops: [0.0, 0.48, 1.0],
      ),
      glyphBorder: FollowSkyV11Tokens.intentionPeriwinkle.withValues(
        alpha: 0.30,
      ),
      glyphGlow: FollowSkyV11Tokens.glow,
      title: title.toLowerCase() == 'follow the sky'
          ? 'Follow\nthe Sky'
          : title,
      subtitle: subtitle,
    );
  }
}

class _FollowSkyHeroBackdrop extends StatelessWidget {
  const _FollowSkyHeroBackdrop();

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
        ],
      ),
    );
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
