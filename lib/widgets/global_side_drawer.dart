import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/global_side_drawer_metrics.dart';
import '../features/calendar/kemetic_month_metadata.dart';
import '../shared/glossy_text.dart';
import 'kemetic_date_picker.dart' show KemeticMath;
import 'inbox_icon_with_badge.dart';
import 'month_name_text.dart';

const Key globalMenuBubbleKey = ValueKey<String>('global-menu-bubble');
const Key globalMenuBubbleSurfaceKey = ValueKey<String>(
  'global-menu-bubble-surface',
);
const Key globalSideDrawerKey = ValueKey<String>('global-side-drawer');
const Key globalSideDrawerDateHeaderKey = ValueKey<String>(
  'global-side-drawer-date-header',
);
const Key globalSideDrawerDateMonthKey = ValueKey<String>(
  'global-side-drawer-date-month',
);
const Key globalSideDrawerDateDayKey = ValueKey<String>(
  'global-side-drawer-date-day',
);
const Key globalSideDrawerDateDividerKey = ValueKey<String>(
  'global-side-drawer-date-divider',
);
const Key globalSideDrawerForegroundKey = ValueKey<String>(
  'global-side-drawer-foreground',
);
const Key globalSideDrawerScrimKey = ValueKey<String>(
  'global-side-drawer-scrim',
);
const Duration globalSideDrawerTransitionDuration = Duration(milliseconds: 220);
const Curve globalSideDrawerTransitionCurve = Curves.easeOutCubic;
const double kGlobalSideDrawerGlyphColumnWidth = 46;
const double kGlobalSideDrawerRowHeight = 50;
const double _kGlobalSideDrawerRowGap = 2;
const double _kGlobalSideDrawerHorizontalPadding = 10;
const double _kGlobalSideDrawerVerticalPadding = 18;
const double _kGlobalSideDrawerDesiredNavTopFraction = 0.30;
const double _kGlobalSideDrawerMinHeaderHeight = 96;
const double _kGlobalSideDrawerMinVisibleHeaderHeight = 52;
const double _kGlobalSideDrawerDateHeaderBottomGap = 12;
const double _kGlobalSideDrawerDateDividerBandHeight = 44;
const double _kGlobalSideDrawerDateOpacity = 0.86;
const Gradient _kGlobalSideDrawerDayGoldGloss = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFE6BE32), Color(0xFFC89710), Color(0xFF735109)],
  stops: [0, 0.52, 1],
);

const GlobalMenuBubbleStyle globalTransparentMenuBubbleStyle =
    GlobalMenuBubbleStyle(
      size: 52,
      left: 18,
      bottom: 22,
      background: RadialGradient(
        center: Alignment(0, -0.3),
        radius: 0.76,
        colors: <Color>[Color.fromRGBO(245, 232, 203, 0.14), Color(0xFF120F08)],
        stops: <double>[0, 0.6],
      ),
      borderColor: Color.fromRGBO(212, 174, 67, 0.18),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.55),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
      glyphGradient: LinearGradient(
        colors: <Color>[Color(0xFFD4AE43), Color(0xFFD4AE43)],
      ),
      glyphSize: 24,
    );

class GlobalSideDrawerItem {
  const GlobalSideDrawerItem({
    required this.label,
    required this.glyph,
    required this.onSelected,
    this.selected = false,
    this.showNotificationDot = false,
    this.glyphSize = 22,
  });

  final String label;
  final String glyph;
  final VoidCallback onSelected;
  final bool selected;
  final bool showNotificationDot;
  final double glyphSize;
}

class GlobalMenuBubble extends StatelessWidget {
  const GlobalMenuBubble({
    super.key = globalMenuBubbleKey,
    required this.visible,
    required this.open,
    required this.onPressed,
    this.style,
  });

  final bool visible;
  final bool open;
  final VoidCallback onPressed;
  final GlobalMenuBubbleStyle? style;

  @override
  Widget build(BuildContext context) {
    final bubbleStyle = style ?? globalTransparentMenuBubbleStyle;
    final double size = bubbleStyle.size;
    final safePadding = MediaQuery.paddingOf(context);
    final left =
        bubbleStyle.left + (bubbleStyle.respectSafeArea ? safePadding.left : 0);
    final bottom =
        bubbleStyle.bottom +
        (bubbleStyle.respectSafeArea ? safePadding.bottom : 0);

    return Positioned(
      left: left,
      bottom: bottom,
      width: size,
      height: size,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedScale(
            scale: visible ? 1 : 0.92,
            duration: globalSideDrawerTransitionDuration,
            curve: globalSideDrawerTransitionCurve,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: globalSideDrawerTransitionDuration,
              curve: globalSideDrawerTransitionCurve,
              child: Semantics(
                container: true,
                label: open ? 'Close navigation menu' : 'Open navigation menu',
                button: true,
                onTap: onPressed,
                child: ExcludeSemantics(
                  child: _GlobalMenuBubbleSurface(
                    style: bubbleStyle,
                    onPressed: onPressed,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalMenuBubbleStyle {
  const GlobalMenuBubbleStyle({
    required this.size,
    required this.left,
    required this.bottom,
    required this.background,
    required this.borderColor,
    required this.boxShadow,
    required this.glyphGradient,
    required this.glyphSize,
    this.respectSafeArea = true,
  });

  final double size;
  final double left;
  final double bottom;
  final Gradient background;
  final Color borderColor;
  final List<BoxShadow> boxShadow;
  final Gradient glyphGradient;
  final double glyphSize;
  final bool respectSafeArea;
}

class _GlobalMenuBubbleSurface extends StatelessWidget {
  const _GlobalMenuBubbleSurface({
    required this.style,
    required this.onPressed,
  });

  final GlobalMenuBubbleStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bubbleStyle = style;
    final glyph = GlossyGlyph(
      glyph: '𓉹',
      gradient: bubbleStyle.glyphGradient,
      size: bubbleStyle.glyphSize,
    );

    return DecoratedBox(
      key: globalMenuBubbleSurfaceKey,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: bubbleStyle.background,
        border: Border.all(color: bubbleStyle.borderColor),
        boxShadow: bubbleStyle.boxShadow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: _GlobalMenuBubbleInk(onPressed: onPressed, child: glyph),
      ),
    );
  }
}

class _GlobalMenuBubbleInk extends StatelessWidget {
  const _GlobalMenuBubbleInk({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox.expand(
        child: Center(
          child: SizedBox.square(
            dimension: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: InboxUnreadDotOverlay(
                top: -1,
                right: -1,
                size: 7,
                dotColor: const Color(0xFFFF3B30),
                borderColor: const Color(0xFF07080A),
                borderWidth: 1.1,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalSideDrawer extends StatelessWidget {
  const GlobalSideDrawer({super.key, required this.open, required this.items});

  final bool open;
  final List<GlobalSideDrawerItem> items;

  @override
  Widget build(BuildContext context) {
    final drawerWidth = globalSideDrawerWidth(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: drawerWidth,
        height: double.infinity,
        child: IgnorePointer(
          ignoring: !open,
          child: ExcludeSemantics(
            excluding: !open,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: globalSideDrawerTransitionDuration,
              curve: globalSideDrawerTransitionCurve,
              child: Material(
                key: globalSideDrawerKey,
                color: const Color(0xFF000000),
                elevation: 14,
                shadowColor: const Color(0xB3000000),
                child: SafeArea(
                  right: false,
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _GlobalSideDrawerBody(
                        items: items,
                        availableHeight: constraints.maxHeight,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalSideDrawerBody extends StatelessWidget {
  const _GlobalSideDrawerBody({
    required this.items,
    required this.availableHeight,
  });

  final List<GlobalSideDrawerItem> items;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final height = availableHeight.isFinite
        ? availableHeight
        : MediaQuery.sizeOf(context).height;
    final navHeight = _drawerRowsHeight(items.length);
    final usesScrollableFallback =
        height <
        navHeight +
            _kGlobalSideDrawerVerticalPadding +
            _kGlobalSideDrawerDateHeaderBottomGap +
            _kGlobalSideDrawerMinVisibleHeaderHeight;

    if (usesScrollableFallback) {
      final headerHeight = (height * 0.28)
          .clamp(_kGlobalSideDrawerMinHeaderHeight, 160.0)
          .toDouble();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _kGlobalSideDrawerHorizontalPadding,
          _kGlobalSideDrawerVerticalPadding,
          _kGlobalSideDrawerHorizontalPadding,
          _kGlobalSideDrawerVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: headerHeight,
              child: const _GlobalSideDrawerDateHeader(),
            ),
            const SizedBox(height: _kGlobalSideDrawerDateHeaderBottomGap),
            _GlobalSideDrawerRows(items: items),
          ],
        ),
      );
    }

    final maxNavTop = height - navHeight - _kGlobalSideDrawerVerticalPadding;
    final navTop = (height * _kGlobalSideDrawerDesiredNavTopFraction)
        .clamp(_kGlobalSideDrawerVerticalPadding, maxNavTop)
        .toDouble();
    final dateHeaderHeight = math
        .max(0, navTop - _kGlobalSideDrawerDateDividerBandHeight)
        .toDouble();
    final dividerTop = dateHeaderHeight + (navTop - dateHeaderHeight - 1) / 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: _kGlobalSideDrawerHorizontalPadding,
          right: _kGlobalSideDrawerHorizontalPadding,
          height: dateHeaderHeight,
          child: const _GlobalSideDrawerDateHeader(),
        ),
        Positioned(
          top: dividerTop,
          left: _kGlobalSideDrawerHorizontalPadding,
          right: _kGlobalSideDrawerHorizontalPadding,
          child: const _GlobalSideDrawerDateDivider(),
        ),
        Positioned(
          top: navTop,
          left: _kGlobalSideDrawerHorizontalPadding,
          right: _kGlobalSideDrawerHorizontalPadding,
          height: navHeight,
          child: _GlobalSideDrawerRows(items: items),
        ),
      ],
    );
  }
}

double _drawerRowsHeight(int itemCount) {
  if (itemCount <= 0) return 0;
  return itemCount * kGlobalSideDrawerRowHeight +
      (itemCount - 1) * _kGlobalSideDrawerRowGap;
}

class _GlobalSideDrawerDateHeader extends StatelessWidget {
  const _GlobalSideDrawerDateHeader();

  @override
  Widget build(BuildContext context) {
    final today = KemeticMath.fromGregorian(DateTime.now());
    final monthName = getMonthById(today.kMonth).displayShort.toUpperCase();
    final dayNumber = '${today.kDay}';

    return LayoutBuilder(
      key: globalSideDrawerDateHeaderKey,
      builder: (context, constraints) {
        if (constraints.maxHeight < 52 || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        final monthFontSize = constraints.maxHeight < 128 ? 23.0 : 27.5;
        final monthStyle = TextStyle(
          color: Colors.white,
          fontSize: monthFontSize,
          height: 1.02,
          fontWeight: FontWeight.w600,
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: const ['GentiumPlus', 'NotoSans', 'Roboto'],
          letterSpacing: 0.8,
        );
        final monthWidth = _textWidth(
          monthName,
          monthStyle,
        ).clamp(44.0, constraints.maxWidth).toDouble();
        const baseDayFontSize = 96.0;
        final baseDayStyle = monthStyle.copyWith(
          fontSize: baseDayFontSize,
          height: 0.72,
          fontWeight: FontWeight.w400,
        );
        final dayWidth = math.max(1, _textWidth(dayNumber, baseDayStyle));
        final computedDayFontSize = baseDayFontSize * monthWidth / dayWidth;
        final maxDayFontSize = math.max(
          48.0,
          math.min(152.0, constraints.maxHeight - monthFontSize - 6),
        );
        final minDayFontSize = math.min(62.0, maxDayFontSize);
        final dayFontSize = computedDayFontSize
            .clamp(minDayFontSize, maxDayFontSize)
            .toDouble();
        final dayStyle = baseDayStyle.copyWith(fontSize: dayFontSize);
        final dayVisualHeight = (dayFontSize * 0.56).clamp(42.0, 88.0);
        final dayTop = math.max(0.0, monthFontSize - 3);
        final dateBlockHeight = dayTop + dayVisualHeight;

        return Center(
          child: Opacity(
            opacity: _kGlobalSideDrawerDateOpacity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                height: dateBlockHeight,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      child: Transform.scale(
                        scaleY: 1.08,
                        alignment: Alignment.center,
                        child: _GlobalSideDrawerDateMonthText(
                          monthName,
                          style: monthStyle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: dayTop,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: dayVisualHeight,
                        child: OverflowBox(
                          minHeight: 0,
                          maxWidth: constraints.maxWidth,
                          maxHeight: dayFontSize,
                          alignment: Alignment.center,
                          child: Transform.scale(
                            scaleX: 0.94,
                            scaleY: 0.72,
                            alignment: Alignment.center,
                            child: _GlobalSideDrawerDateDayText(
                              key: globalSideDrawerDateDayKey,
                              text: dayNumber,
                              style: dayStyle,
                              gradient: _kGlobalSideDrawerDayGoldGloss,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalSideDrawerDateDayText extends StatelessWidget {
  const _GlobalSideDrawerDateDayText({
    super.key,
    required this.text,
    required this.style,
    required this.gradient,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = style.fontSize ?? 96;
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : _textWidth(text, style);
        final bounds = Rect.fromLTWH(0, 0, width, fontSize * 1.1);
        final paint = Paint()..shader = gradient.createShader(bounds);

        return RepaintBoundary(
          child: Text(
            text,
            style: style.copyWith(
              foreground: paint,
              shadows: null,
              letterSpacing: style.letterSpacing ?? 0,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        );
      },
    );
  }
}

class _GlobalSideDrawerDateDivider extends StatelessWidget {
  const _GlobalSideDrawerDateDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: SizedBox(
          key: globalSideDrawerDateDividerKey,
          height: 0.75,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KemeticGold.base.withValues(alpha: 0),
                  KemeticGold.light.withValues(alpha: 0.42),
                  KemeticGold.base.withValues(alpha: 0.50),
                  KemeticGold.deep.withValues(alpha: 0.30),
                  KemeticGold.base.withValues(alpha: 0),
                ],
                stops: const [0, 0.18, 0.50, 0.82, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

class _GlobalSideDrawerDateMonthText extends StatelessWidget {
  const _GlobalSideDrawerDateMonthText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final masked = style.copyWith(
      color: const Color(0xFFFFFFFF),
      fontSize: (style.fontSize ?? 20).roundToDouble(),
      letterSpacing: style.letterSpacing,
      height: style.height,
      shadows: null,
    );

    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (bounds) => goldGloss.createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: MonthNameText(
          text,
          key: globalSideDrawerDateMonthKey,
          style: masked,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _GlobalSideDrawerRows extends StatelessWidget {
  const _GlobalSideDrawerRows({required this.items});

  final List<GlobalSideDrawerItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _GlobalSideDrawerRow(item: items[index]),
          if (index != items.length - 1)
            const SizedBox(height: _kGlobalSideDrawerRowGap),
        ],
      ],
    );
  }
}

class GlobalSideDrawerForeground extends StatelessWidget {
  const GlobalSideDrawerForeground({
    super.key,
    required this.open,
    required this.child,
  });

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final drawerOffset = open ? globalSideDrawerWidth(context) : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: drawerOffset, end: drawerOffset),
      duration: globalSideDrawerTransitionDuration,
      curve: globalSideDrawerTransitionCurve,
      builder: (context, offset, child) {
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: SizedBox.expand(key: globalSideDrawerForegroundKey, child: child),
    );
  }
}

class _GlobalSideDrawerRow extends StatelessWidget {
  const _GlobalSideDrawerRow({required this.item});

  final GlobalSideDrawerItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected
        ? const Color(0xFFFFE8A3)
        : const Color(0xFFE8E0D6);
    final background = item.selected
        ? const Color(0x26D4AF37)
        : Colors.transparent;
    final borderColor = item.selected
        ? const Color(0x40D4AF37)
        : Colors.transparent;
    final glyph = GlossyGlyph(
      glyph: item.glyph,
      gradient: goldGloss,
      size: item.glyphSize,
    );

    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey<String>('global-side-drawer-item-${item.label}'),
          borderRadius: BorderRadius.circular(8),
          onTap: item.onSelected,
          child: Container(
            height: kGlobalSideDrawerRowHeight,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Row(
              children: [
                SizedBox(
                  key: ValueKey<String>(
                    'global-side-drawer-glyph-${item.label}',
                  ),
                  width: kGlobalSideDrawerGlyphColumnWidth,
                  height: 40,
                  child: _GlobalSideDrawerGlyph(
                    showNotificationDot: item.showNotificationDot,
                    child: glyph,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key: ValueKey<String>(
                      'global-side-drawer-label-${item.label}',
                    ),
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: item.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalSideDrawerGlyph extends StatelessWidget {
  const _GlobalSideDrawerGlyph({
    required this.child,
    required this.showNotificationDot,
  });

  final Widget child;
  final bool showNotificationDot;

  @override
  Widget build(BuildContext context) {
    final glyph = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: child,
    );

    return Center(
      child: showNotificationDot
          ? InboxUnreadDotOverlay(
              top: -2,
              right: -2,
              size: 7,
              dotColor: const Color(0xFFFF3B30),
              borderColor: const Color(0xFF07080A),
              borderWidth: 1.1,
              child: glyph,
            )
          : glyph,
    );
  }
}
