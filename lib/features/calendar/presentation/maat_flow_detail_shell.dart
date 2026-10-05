import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/navigation_fallback.dart';
import '../../../widgets/keyboard_aware.dart';
import '../maat_flow_visual_tokens.dart';

const String kMaatFlowsListRoute = '/flows?mode=maatFlows';

void popMaatFlowDetailOrGo(
  BuildContext context, {
  String fallbackLocation = kMaatFlowsListRoute,
}) {
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
    return;
  }
  popOrGo(context, fallbackLocation);
}

/// The authored 34 px circular back control shared by Ma'at detail pages.
///
/// Keeping this chrome in one authority prevents each flow from drifting while
/// still allowing the flow palette to own its color.
class MaatFlowDetailBackButton extends StatelessWidget {
  const MaatFlowDetailBackButton({
    super.key,
    required this.color,
    required this.onPressed,
    this.backgroundColor = const Color(0x73000000),
    this.borderColor,
    this.size = 34,
    this.iconSize = 20,
    this.tooltip = 'Back',
    this.icon = Icons.arrow_back,
  });

  final Color color;
  final Color backgroundColor;
  final Color? borderColor;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: backgroundColor,
          shape: CircleBorder(
            side: BorderSide(
              color: borderColor ?? color.withValues(alpha: 0.28),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: color, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// An authored hero supplies its content minimum without duplicating its text
/// or typography in the scroll shell.
abstract interface class MaatFlowHeroGeometry {
  double minimumHeightFor(BuildContext context, double width);
}

/// Hero wrappers retain one descriptor for both layout measurement and paint.
mixin MaatFlowHeroGeometryDelegate on StatelessWidget
    implements MaatFlowHeroGeometry {
  MaatFlowDetailHero buildHero(BuildContext context);

  @override
  Widget build(BuildContext context) => buildHero(context);

  @override
  double minimumHeightFor(BuildContext context, double width) =>
      buildHero(context).minimumHeightFor(context, width);
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
    this.referenceHeroHeight = MaatFlowDetailGeometry.heroHeight,
    this.referenceSheetOverlap = MaatFlowDetailGeometry.sheetOverlap,
    this.scaleHeroWithText = false,
  });

  final MaatFlowDetailTheme theme;
  final Widget hero;
  final Widget sheet;
  final Widget? bottomDock;
  final ScrollController? scrollController;
  final Key scrollKey;
  final Key? heroLayerKey;
  final Key? sheetKey;
  final double referenceHeroHeight;
  final double referenceSheetOverlap;

  /// Authored Ma’at heroes retain their reference geometry on tablets and can
  /// grow and scroll with accessibility type. Custom flow heroes retain their
  /// independently owned geometry.
  final bool scaleHeroWithText;

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
            widget.referenceHeroHeight *
            (width / MaatFlowDetailGeometry.referenceWidth);
        final heightScaledHero =
            constraints.maxHeight *
            (widget.referenceHeroHeight /
                MaatFlowDetailGeometry.referenceHeight);
        final textScale = MediaQuery.textScalerOf(context).scale(20) / 20;
        final enlargedHero = widget.scaleHeroWithText && textScale > 1;
        final fittedHero = math.min(widthScaledHero, heightScaledHero);
        final hero = widget.hero;
        final minimumHeroHeight =
            widget.scaleHeroWithText && hero is MaatFlowHeroGeometry
            ? (hero as MaatFlowHeroGeometry).minimumHeightFor(context, width) +
                  // The authored width fit already owns its safe-area
                  // placement. When height compresses that fit, reserve the
                  // inherited inset too so fixed Back cannot enter the glyph.
                  (heightScaledHero < widthScaledHero
                      ? MediaQuery.paddingOf(context).top
                      : 0.0)
            : 0.0;
        // Keep the authored fit when its content has room. Smaller phone and
        // tablet windows must not compress unchanged typography into Back or
        // glyphs; the content supplies its own minimum without a size cutoff.
        final normalHeroHeight = math.max(minimumHeroHeight, fittedHero);
        // The parallax hero moves more slowly than its foreground sheet. In a
        // short viewport that sheet would overtake identity text before it
        // could clear the fixed dock. Reuse the existing accessible scrolling
        // hero so its content and sheet retain their relative positions.
        final shortHeroViewport =
            widget.scaleHeroWithText &&
            showBottomDock &&
            normalHeroHeight + MaatFlowDetailGeometry.bottomContentClearance >
                constraints.maxHeight;
        final scrollHero = enlargedHero || shortHeroViewport;
        final heroHeight = enlargedHero
            ? widthScaledHero * math.max(1, textScale)
            : normalHeroHeight;
        final widthScale = width / MaatFlowDetailGeometry.referenceWidth;
        // The foreground must not grow over the fixed-size hero typography
        // merely because a tablet (including narrow Split View) has more
        // horizontal room. Custom heroes keep their own overlap calculation.
        final overlap =
            widget.referenceSheetOverlap *
            (widget.scaleHeroWithText ? math.min(1.0, widthScale) : widthScale);
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
              if (!scrollHero)
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
                    child: scrollHero
                        ? SizedBox(
                            key: widget.heroLayerKey,
                            height: heroHeight,
                            child: widget.hero,
                          )
                        : SizedBox(height: heroHeight - overlap),
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
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          MaatFlowDetailGeometry.bottomContentClearance *
                          (widget.scaleHeroWithText
                              ? math.max(1, textScale)
                              : 1),
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
class MaatFlowDetailHero extends StatelessWidget
    implements MaatFlowHeroGeometry {
  const MaatFlowDetailHero({
    super.key,
    required this.theme,
    required this.background,
    required this.glyph,
    required this.title,
    required this.subtitle,
    this.glyphKey,
    this.glyphContent,
    this.glyphOffset = Offset.zero,
    this.glyphGradient,
    this.glyphBorder,
    this.glyphGlow,
    this.contentBottom = 72,
    this.contentLeft = 24,
    this.contentRight = 24,
    this.glyphToTitleSpacing = 16,
    this.titleFontSize = 48,
    this.titleHeight = 1,
    this.titleLetterSpacing = -0.48,
    this.subtitleSpacing = 10,
    this.subtitleWidth = 250,
    this.subtitleFontSize = 19,
    this.subtitleColor,
    this.subtitleHeight = 1.2,
    this.minimumTopClearance = 40,
  });

  final MaatFlowDetailTheme theme;
  final Widget background;
  final String glyph;
  final String title;
  final String subtitle;
  final Key? glyphKey;
  final Widget? glyphContent;
  final Offset glyphOffset;
  final Gradient? glyphGradient;
  final Color? glyphBorder;
  final Color? glyphGlow;
  final double contentBottom;
  final double contentLeft;
  final double contentRight;
  final double glyphToTitleSpacing;
  final double titleFontSize;
  final double titleHeight;
  final double titleLetterSpacing;
  final double subtitleSpacing;
  final double subtitleWidth;
  final double subtitleFontSize;
  final Color? subtitleColor;
  final double subtitleHeight;

  /// Space occupied by this flow's fixed Back control, excluding safe padding.
  final double minimumTopClearance;

  TextStyle _titleStyle(double titleScale) => TextStyle(
    color: theme.accent,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: titleFontSize * titleScale,
    fontWeight: FontWeight.w500,
    height: titleHeight,
    letterSpacing: titleLetterSpacing * titleScale,
    shadows: const [
      Shadow(color: Color(0xB8000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  TextStyle get _subtitleStyle => TextStyle(
    color: subtitleColor ?? theme.primaryText,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: subtitleFontSize,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    height: subtitleHeight,
    shadows: const [
      Shadow(color: Color(0xC7000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  /// Measure exactly the style, scaler and available width used by Text.
  static double measureTextHeight(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required double width,
  }) {
    final defaults = DefaultTextStyle.of(context);
    var effectiveStyle = defaults.style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior:
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
    )..layout(maxWidth: math.max(0, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  double minimumHeightFor(BuildContext context, double width) {
    final titleScale = math.min(
      1.0,
      width / MaatFlowDetailGeometry.referenceWidth,
    );
    final contentWidth = math.max(0.0, width - contentLeft - contentRight);
    final titleExtent = measureTextHeight(
      context,
      text: title,
      style: _titleStyle(titleScale),
      width: contentWidth,
    );
    final subtitleExtent = subtitle.isEmpty
        ? 0.0
        : subtitleSpacing +
              measureTextHeight(
                context,
                text: subtitle,
                style: _subtitleStyle,
                width: math.min(subtitleWidth, contentWidth),
              );
    // This local minimum measures the bottom-anchored identity. The shell
    // reserves inherited safe padding when height compresses the authored fit.
    return minimumTopClearance +
        math.max(0.0, -glyphOffset.dy) +
        52 +
        glyphToTitleSpacing +
        titleExtent +
        subtitleExtent +
        contentBottom;
  }

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
                left: contentLeft,
                right: contentRight,
                bottom: contentBottom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: glyphOffset,
                      child: MediaQuery.withNoTextScaling(
                        child: Container(
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
                                    theme.sheetBackground.withValues(
                                      alpha: 0.96,
                                    ),
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
                          child: glyphContent == null
                              ? Text(
                                  glyph,
                                  key: glyphKey,
                                  style: TextStyle(
                                    color: theme.glow,
                                    fontFamily:
                                        'Noto Sans Egyptian Hieroglyphs',
                                    fontSize: 29,
                                    height: 1,
                                  ),
                                )
                              : KeyedSubtree(
                                  key: glyphKey,
                                  child: glyphContent!,
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: glyphToTitleSpacing),
                    Text(title, style: _titleStyle(titleScale)),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: subtitleSpacing),
                      SizedBox(
                        width: subtitleWidth,
                        child: Text(subtitle, style: _subtitleStyle),
                      ),
                    ],
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
/// A host can continue from an already owned flow without replacing its page.
/// The flow still owns all of its detail content, editing and enrollment logic.
@immutable
class MaatFlowDetailPrimaryAction {
  const MaatFlowDetailPrimaryAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.note,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? note;
}

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
    this.onJoinedPressed,
    this.primaryAction,
    this.showNote = true,
    this.actionNoteWidget,
    this.joinedNoteWidget,
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
  final VoidCallback? onJoinedPressed;
  final MaatFlowDetailPrimaryAction? primaryAction;
  final bool showNote;
  final Widget? actionNoteWidget;
  final Widget? joinedNoteWidget;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(20) > 20;
    final action = primaryAction;
    final actionBusy = busy || (action?.busy ?? false);
    final passiveJoined = joined && action == null;
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
                height: enlargedText ? null : 54,
                width: double.infinity,
                child: ElevatedButton(
                  key: action != null
                      ? const ValueKey<String>('maat-flow-primary-action')
                      : joined
                      ? joinedKey
                      : actionKey,
                  style: ElevatedButton.styleFrom(
                    minimumSize: enlargedText
                        ? const Size(double.infinity, 54)
                        : null,
                    padding: enlargedText
                        ? const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          )
                        : null,
                    backgroundColor: theme.pageBackground,
                    foregroundColor: passiveJoined
                        ? theme.secondaryText
                        : theme.glow,
                    disabledBackgroundColor: theme.pageBackground,
                    disabledForegroundColor: theme.secondaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: passiveJoined
                            ? theme.accent.withValues(alpha: 0.22)
                            : theme.accent,
                        width: 1.5,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: actionBusy
                      ? null
                      : action != null
                      ? action.onPressed
                      : joined
                      ? onJoinedPressed
                      : onPressed,
                  child: actionBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.accent,
                          ),
                        )
                      : Text(
                          action?.label ?? (joined ? joinedLabel : actionLabel),
                          textAlign: enlargedText ? TextAlign.center : null,
                          style: TextStyle(
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: passiveJoined ? 17 : 20,
                            fontWeight: passiveJoined
                                ? FontWeight.w400
                                : FontWeight.w500,
                            height: 1,
                          ),
                        ),
                ),
              ),
              if (showNote) ...<Widget>[
                const SizedBox(height: 9),
                action?.note != null
                    ? _MaatFlowDetailDockNote(theme: theme, text: action!.note!)
                    : joined
                    ? (joinedNoteWidget ??
                          _MaatFlowDetailDockNote(
                            theme: theme,
                            text: joinedNote,
                          ))
                    : (actionNoteWidget ??
                          _MaatFlowDetailDockNote(
                            theme: theme,
                            text: actionNote,
                          )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MaatFlowDetailDockNote extends StatelessWidget {
  const _MaatFlowDetailDockNote({required this.theme, required this.text});

  final MaatFlowDetailTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: theme.secondaryText,
        fontFamily: MaatFlowListTokens.fontFamily,
        fontFamilyFallback: MaatFlowListTokens.fontFallback,
        fontSize: 10.5,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}
