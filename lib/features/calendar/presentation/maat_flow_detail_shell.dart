import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/keyboard_aware.dart';
import '../maat_flow_visual_tokens.dart';

/// Flow-owned colors applied to the shared Ma'at detail geometry.
class MaatFlowDetailTheme {
  const MaatFlowDetailTheme({
    required this.pageBackground,
    required this.sheetBackground,
    required this.sheetBorder,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.separator,
    required this.glow,
  });

  final Color pageBackground;
  final Color sheetBackground;
  final Color sheetBorder;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color separator;
  final Color glow;
}

/// Reference geometry shared by the full-bleed Ma'at detail pages.
abstract final class MaatFlowDetailGeometry {
  static const double referenceWidth = 390;
  static const double referenceHeight = 844;
  static const double heroHeight = 452;
  static const double sheetOverlap = 46;
  static const double heroParallaxFactor = 0.58;
  static const double heroFadeScrollDistance = 430;
  static const double bottomContentClearance = 168;
  static const double sheetRadius = 26;
}

/// One continuous scroll surface with a receding hero and fixed action dock.
class MaatFlowDetailShell extends StatefulWidget {
  const MaatFlowDetailShell({
    super.key,
    required this.theme,
    required this.hero,
    required this.sheet,
    this.bottomDock,
    this.scrollController,
    this.scrollKey = const ValueKey<String>('maat-flow-detail-scroll'),
    this.heroLayerKey,
    this.sheetKey,
  });

  final MaatFlowDetailTheme theme;
  final Widget hero;
  final Widget sheet;
  final Widget? bottomDock;
  final ScrollController? scrollController;
  final Key scrollKey;
  final Key? heroLayerKey;
  final Key? sheetKey;

  @override
  State<MaatFlowDetailShell> createState() => _MaatFlowDetailShellState();
}

class _MaatFlowDetailShellState extends State<MaatFlowDetailShell> {
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
    final showBottomDock =
        widget.bottomDock != null && !keyboardIsVisible(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final widthScaledHero =
            MaatFlowDetailGeometry.heroHeight *
            (width / MaatFlowDetailGeometry.referenceWidth);
        final heightScaledHero =
            constraints.maxHeight *
            (MaatFlowDetailGeometry.heroHeight /
                MaatFlowDetailGeometry.referenceHeight);
        final heroHeight = math.min(widthScaledHero, heightScaledHero);
        final overlap =
            MaatFlowDetailGeometry.sheetOverlap *
            (width / MaatFlowDetailGeometry.referenceWidth);
        final parallax =
            _scrollOffset * MaatFlowDetailGeometry.heroParallaxFactor;
        final fadeT =
            (_scrollOffset / MaatFlowDetailGeometry.heroFadeScrollDistance)
                .clamp(0.0, 1.0);

        return ColoredBox(
          color: widget.theme.pageBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                key: widget.heroLayerKey,
                top: -parallax,
                left: 0,
                right: 0,
                height: heroHeight,
                child: Opacity(opacity: 1 - fadeT, child: widget.hero),
              ),
              CustomScrollView(
                key: widget.scrollKey,
                controller: _controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: heroHeight - overlap),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      key: widget.sheetKey,
                      decoration: BoxDecoration(
                        color: widget.theme.sheetBackground,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(
                            MaatFlowDetailGeometry.sheetRadius,
                          ),
                        ),
                        border: Border(
                          top: BorderSide(color: widget.theme.sheetBorder),
                        ),
                      ),
                      child: widget.sheet,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: MaatFlowDetailGeometry.bottomContentClearance,
                    ),
                  ),
                ],
              ),
              if (showBottomDock)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.bottomDock!,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared hero typography and placement. Each flow supplies its own backdrop
/// and glyph treatment while retaining the same hierarchy and proportions.
class MaatFlowDetailHero extends StatelessWidget {
  const MaatFlowDetailHero({
    super.key,
    required this.theme,
    required this.background,
    required this.glyph,
    required this.title,
    required this.subtitle,
    this.glyphKey,
    this.glyphGradient,
    this.glyphBorder,
    this.glyphGlow,
  });

  final MaatFlowDetailTheme theme;
  final Widget background;
  final String glyph;
  final String title;
  final String subtitle;
  final Key? glyphKey;
  final Gradient? glyphGradient;
  final Color? glyphBorder;
  final Color? glyphGlow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleScale = math.min(
          1.0,
          constraints.maxWidth / MaatFlowDetailGeometry.referenceWidth,
        );

        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              background,
              Positioned(
                left: 24,
                right: 24,
                bottom: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            glyphGradient ??
                            RadialGradient(
                              center: const Alignment(-0.24, -0.44),
                              radius: 0.9,
                              colors: [
                                theme.accent.withValues(alpha: 0.82),
                                theme.sheetBackground.withValues(alpha: 0.96),
                                theme.pageBackground,
                              ],
                            ),
                        border: Border.all(
                          color:
                              glyphBorder ??
                              theme.accent.withValues(alpha: 0.30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (glyphGlow ?? theme.glow).withValues(
                              alpha: 0.13,
                            ),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        glyph,
                        key: glyphKey,
                        style: TextStyle(
                          color: theme.glow,
                          fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                          fontSize: 29,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.accent,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 48 * titleScale,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        letterSpacing: -0.48 * titleScale,
                        shadows: const [
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
                        style: TextStyle(
                          color: theme.primaryText,
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 19,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          height: 1.2,
                          shadows: const [
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
      },
    );
  }
}

/// Shared fixed-dock geometry with flow-specific copy and colors.
class MaatFlowDetailDock extends StatelessWidget {
  const MaatFlowDetailDock({
    super.key,
    required this.theme,
    required this.joined,
    required this.busy,
    required this.onPressed,
    required this.actionLabel,
    required this.actionNote,
    required this.joinedLabel,
    required this.joinedNote,
    required this.actionKey,
    required this.joinedKey,
  });

  final MaatFlowDetailTheme theme;
  final bool joined;
  final bool busy;
  final VoidCallback? onPressed;
  final String actionLabel;
  final String actionNote;
  final String joinedLabel;
  final String joinedNote;
  final Key actionKey;
  final Key joinedKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, theme.pageBackground],
          stops: const [0.0, 0.34],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  key: joined ? joinedKey : actionKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.pageBackground,
                    foregroundColor: joined
                        ? theme.secondaryText
                        : theme.accent,
                    disabledBackgroundColor: theme.pageBackground,
                    disabledForegroundColor: theme.secondaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: joined
                            ? theme.accent.withValues(alpha: 0.22)
                            : theme.accent,
                        width: 1.5,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: joined || busy ? null : onPressed,
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.accent,
                          ),
                        )
                      : Text(
                          joined ? joinedLabel : actionLabel,
                          style: TextStyle(
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: joined ? 17 : 20,
                            fontWeight: joined
                                ? FontWeight.w400
                                : FontWeight.w500,
                            height: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 11),
              Text(
                joined ? joinedNote : actionNote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.secondaryText,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
