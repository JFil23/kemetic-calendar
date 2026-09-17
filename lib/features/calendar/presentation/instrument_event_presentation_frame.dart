import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

const double instrumentEventSheetMinExtent = 0.58;

double instrumentEventSheetExtentForViewport({
  required BuildContext context,
  required double viewportFraction,
  double? maximumHeight,
}) {
  final media = MediaQuery.of(context);
  final availableSheetHeight = math.max(
    0.0,
    media.size.height - media.padding.top - media.padding.bottom - 12,
  );
  if (availableSheetHeight <= 0) return instrumentEventSheetMinExtent;
  final fractionHeight = media.size.height * viewportFraction;
  final targetHeight = maximumHeight == null
      ? fractionHeight
      : math.min(maximumHeight, fractionHeight);
  return (targetHeight / availableSheetHeight)
      .clamp(instrumentEventSheetMinExtent, 1.0)
      .toDouble();
}

Future<T?> showCalendarEventDetailSheetModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showEditableModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: false,
    builder: builder,
  );
}

class CalendarEventDetailSheetCoordinator {
  CalendarEventDetailSheetCoordinator._();

  static bool _openOrOpening = false;

  static bool get isOpenOrOpening => _openOrOpening;

  static bool tryMarkOpenOrOpening() {
    if (_openOrOpening) return false;
    _openOrOpening = true;
    return true;
  }

  static void markClosed() {
    _openOrOpening = false;
  }

  @visibleForTesting
  static void debugResetForTests() {
    _openOrOpening = false;
  }
}

@visibleForTesting
const ValueKey<String> dayViewBottomSheetBackplateKey = ValueKey<String>(
  'day-view-bottom-sheet-backplate',
);

class DayViewBottomSheetFrame extends StatelessWidget {
  const DayViewBottomSheetFrame({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.decoration,
  });

  final Widget child;
  final double borderRadius;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(borderRadius));

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: dayViewBottomSheetBackplateKey,
              decoration:
                  decoration ??
                  BoxDecoration(
                    borderRadius: radius,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xF7070605), Color(0xFA050403)],
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0xCC000000),
                        blurRadius: 28,
                        spreadRadius: 6,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// The single outer host for instrument-backed calendar event sheets.
///
/// This is the extracted Day View behavior: it owns the modal-height extent,
/// keyboard-aware available height, vertical resize equation, backplate,
/// resize region, and outer sheet geometry. Consumers provide only their
/// presentation body, trailing control, and optional fixed footer.
class InstrumentEventSheetHost extends StatefulWidget {
  const InstrumentEventSheetHost({
    super.key,
    required this.semanticLabel,
    required this.handleColor,
    required this.body,
    this.leading,
    this.trailing,
    this.footer,
    this.initialExtent = instrumentEventSheetMinExtent,
    this.geometry,
    this.frameDecoration,
  }) : assert(
         initialExtent >= instrumentEventSheetMinExtent && initialExtent <= 1,
       );

  final String semanticLabel;
  final Color handleColor;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;
  final double initialExtent;
  final InstrumentEventSheetGeometry? geometry;
  final BoxDecoration? frameDecoration;

  @override
  State<InstrumentEventSheetHost> createState() =>
      _InstrumentEventSheetHostState();
}

class _InstrumentEventSheetHostState extends State<InstrumentEventSheetHost> {
  late double _extent;

  @override
  void initState() {
    super.initState();
    _extent = widget.initialExtent;
  }

  void _updateExtent(DragUpdateDetails details, double availableSheetHeight) {
    final delta = details.primaryDelta;
    if (delta == null || availableSheetHeight <= 0) return;
    final nextExtent = (_extent - delta / availableSheetHeight)
        .clamp(instrumentEventSheetMinExtent, 1.0)
        .toDouble();
    if ((nextExtent - _extent).abs() < 0.0001) return;
    setState(() => _extent = nextExtent);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableSheetHeight = math.max(
      0.0,
      media.size.height - media.padding.top - media.padding.bottom - 12,
    );
    final keyboardVisible = keyboardIsVisible(context);
    final effectiveExtent = keyboardVisible ? 1.0 : _extent;
    final maxSheetHeight = availableSheetHeight * effectiveExtent;
    final hasFooter = widget.footer != null;
    final geometry = widget.geometry;

    // These values preserve the two production geometries that existed before
    // extraction: Day View reserves 120px for its fixed actions, while the
    // preview has no external footer and gives that space to the presentation.
    final outerHeight = geometry == null
        ? maxSheetHeight + (hasFooter ? 8.0 : 0.0)
        : maxSheetHeight;
    final configuredOuterPadding =
        geometry?.outerPadding ??
        (hasFooter
            ? const EdgeInsets.fromLTRB(10, 8, 10, 10)
            : const EdgeInsets.fromLTRB(10, 0, 10, 10));
    final outerPadding = geometry != null && media.size.width <= 430
        ? EdgeInsets.fromLTRB(
            0,
            configuredOuterPadding.top,
            0,
            configuredOuterPadding.bottom,
          )
        : configuredOuterPadding;
    final bodyTopGap = geometry?.bodyTopGap ?? 8.0;
    final footerGap = geometry?.footerGap ?? 8.0;
    final footerHeight = geometry?.footerHeight ?? 46.0;
    final topBarHeight = geometry?.topBarHeight ?? 48.0;
    final bodyHeight = geometry == null
        ? math.max(0.0, maxSheetHeight - (hasFooter ? 120.0 : 66.0))
        : math.max(
            0.0,
            outerHeight -
                outerPadding.vertical -
                topBarHeight -
                bodyTopGap -
                (hasFooter ? footerGap + footerHeight : 0),
          );

    return SafeArea(
      top: false,
      child: SizedBox(
        height: outerHeight,
        child: Padding(
          padding: outerPadding,
          child: DayViewBottomSheetFrame(
            borderRadius: geometry?.sheetBorderRadius ?? 20,
            decoration: widget.frameDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InstrumentEventSheetTopBar(
                  semanticLabel: widget.semanticLabel,
                  handleColor: widget.handleColor,
                  height: topBarHeight,
                  handleTop: geometry?.handleTop,
                  handleWidth: geometry?.handleWidth ?? 42,
                  onVerticalDragUpdate: !keyboardVisible
                      ? (details) =>
                            _updateExtent(details, availableSheetHeight)
                      : null,
                  leading: widget.leading,
                  trailing: widget.trailing,
                ),
                SizedBox(height: bodyTopGap),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: geometry?.bodyHorizontalInset ?? 0,
                  ),
                  child: SizedBox(
                    height: bodyHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(geometry?.bodyBorderRadius ?? 20),
                      ),
                      child: KeyboardAwareEditableSurface(child: widget.body),
                    ),
                  ),
                ),
                if (widget.footer != null) ...<Widget>[
                  SizedBox(height: footerGap),
                  SizedBox(height: footerHeight, child: widget.footer),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class InstrumentEventSheetGeometry {
  const InstrumentEventSheetGeometry({
    required this.outerPadding,
    required this.topBarHeight,
    required this.bodyTopGap,
    required this.footerGap,
    required this.footerHeight,
    this.sheetBorderRadius = 20,
    this.bodyHorizontalInset = 0,
    this.bodyBorderRadius = 20,
    this.handleTop,
    this.handleWidth = 42,
  });

  /// Geometry copied from the layered Djed/Offering HTML sheets: a 48px
  /// chrome row, a 72px fixed footer, and no gaps between the three layers.
  static const layered = InstrumentEventSheetGeometry(
    outerPadding: EdgeInsets.fromLTRB(9, 0, 9, 0),
    topBarHeight: 48,
    bodyTopGap: 0,
    footerGap: 0,
    footerHeight: 72,
    sheetBorderRadius: 24,
    bodyHorizontalInset: 10,
    bodyBorderRadius: 18,
    handleTop: 19,
    handleWidth: 41,
  );

  final EdgeInsets outerPadding;
  final double topBarHeight;
  final double bodyTopGap;
  final double footerGap;
  final double footerHeight;
  final double sheetBorderRadius;
  final double bodyHorizontalInset;
  final double bodyBorderRadius;
  final double? handleTop;
  final double handleWidth;
}

/// The five built-in Ma'at flows that use the canonical Day View housing.
///
/// Detail-entry sheets and user-created flows deliberately do not use this
/// identity. Keeping the identity here makes the housing configuration one
/// shared authority instead of a collection of route-local booleans.
enum MaatDayViewFlow { followSky, offeringTable, readingHouse, djed, kar }

@immutable
class MaatDayViewHousingSpec {
  const MaatDayViewHousingSpec({
    required this.hostKey,
    required this.semanticLabel,
    required this.handleColor,
    required this.initialExtent,
    this.footerActionColor,
  });

  factory MaatDayViewHousingSpec.forFlow(MaatDayViewFlow flow) {
    return switch (flow) {
      MaatDayViewFlow.followSky => const MaatDayViewHousingSpec(
        hostKey: 'follow-sky-resizable-sheet',
        semanticLabel: 'Resize Follow Sky sheet',
        handleColor: Color(0x7AD4AE43),
        initialExtent: instrumentEventSheetMinExtent,
      ),
      MaatDayViewFlow.offeringTable => const MaatDayViewHousingSpec(
        hostKey: 'offering-table-resizable-sheet',
        semanticLabel: 'Resize Offering Table sheet',
        handleColor: Color(0xFF72571E),
        initialExtent: .71,
      ),
      MaatDayViewFlow.readingHouse => const MaatDayViewHousingSpec(
        hostKey: 'reading-house-resizable-sheet',
        semanticLabel: 'Resize Reading House sheet',
        handleColor: Color(0xFF33463E),
        initialExtent: instrumentEventSheetMinExtent,
      ),
      MaatDayViewFlow.djed => const MaatDayViewHousingSpec(
        hostKey: 'djed-resizable-sheet',
        semanticLabel: 'Resize Djed sheet',
        handleColor: Color(0xFF72571E),
        initialExtent: instrumentEventSheetMinExtent,
      ),
      MaatDayViewFlow.kar => const MaatDayViewHousingSpec(
        hostKey: 'kar-resizable-sheet',
        semanticLabel: 'Resize Kꜣr sheet',
        handleColor: Color(0xFF33444A),
        initialExtent: .71,
        footerActionColor: Color(0xFFA9CFDA),
      ),
    };
  }

  final String hostKey;
  final String semanticLabel;
  final Color handleColor;
  final double initialExtent;
  final Color? footerActionColor;
}

/// The one outer Day View sheet for every built-in Ma'at flow.
///
/// Flow-specific presentations supply content only. This widget owns the
/// Follow-the-Sky-approved host geometry, resize policy, handle placement,
/// menu slot, and fixed-footer slot.
class MaatDayViewSheetHost extends StatelessWidget {
  const MaatDayViewSheetHost({
    super.key,
    required this.flow,
    required this.body,
    this.leading,
    required this.trailing,
    required this.footer,
  });

  final MaatDayViewFlow flow;
  final Widget body;
  final Widget? leading;
  final Widget trailing;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final spec = MaatDayViewHousingSpec.forFlow(flow);
    return InstrumentEventSheetHost(
      key: ValueKey<String>(spec.hostKey),
      semanticLabel: spec.semanticLabel,
      handleColor: spec.handleColor,
      initialExtent: spec.initialExtent,
      leading: leading,
      trailing: trailing,
      body: body,
      footer: footer,
    );
  }
}

/// The single fixed action footer for canonical Ma'at Day View sheets.
///
/// Event capabilities and callbacks remain owned by Day View. This widget owns
/// only the Follow-the-Sky-approved placement and visual treatment.
class MaatDayViewFooterActions extends StatelessWidget {
  const MaatDayViewFooterActions({
    super.key,
    required this.onMakeTodo,
    required this.calendarLabel,
    this.onCalendar,
    this.actionColor,
  });

  final VoidCallback onMakeTodo;
  final String calendarLabel;
  final VoidCallback? onCalendar;
  final Color? actionColor;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: <String>['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
  );

  @override
  Widget build(BuildContext context) {
    final color = actionColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: TextButton.icon(
            key: const ValueKey<String>('maat-day-view-make-todo'),
            onPressed: onMakeTodo,
            icon: color == null
                ? KemeticGold.icon(Icons.playlist_add_check)
                : Icon(Icons.playlist_add_check, color: color),
            label: color == null
                ? KemeticGold.text('Make to-do', style: _labelStyle)
                : Text('Make to-do', style: _labelStyle.copyWith(color: color)),
          ),
        ),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('maat-day-view-calendar'),
              onPressed: onCalendar,
              child: color == null
                  ? KemeticGold.text(calendarLabel, style: _labelStyle)
                  : Text(
                      calendarLabel,
                      style: _labelStyle.copyWith(color: color),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

typedef InstrumentEventInputBuilder =
    Widget Function(
      BuildContext context,
      double heroHeight,
      double instrumentHeight,
    );

enum _MaatDayViewGraphicSpaceMode { responsive, fixed, revealable }

/// Flow-authored graphic dimensions consumed by the one shared housing.
///
/// These values describe how much fixed graphic space a flow needs. They do
/// not provide alternate scrolling, sheet, or foreground implementations.
@immutable
class MaatDayViewGraphicSpace {
  const MaatDayViewGraphicSpace.responsive({
    required this.minimumHeroHeight,
    required this.maximumHeroHeight,
    required this.heroHeightFraction,
    this.footerHeight = 0,
  }) : _mode = _MaatDayViewGraphicSpaceMode.responsive,
       fixedHeight = null,
       minimumForegroundPeek = 0,
       _foregroundFillsViewport = false;

  const MaatDayViewGraphicSpace.fixed({
    required double height,
    bool foregroundFillsViewport = false,
  }) : _mode = _MaatDayViewGraphicSpaceMode.fixed,
       fixedHeight = height,
       minimumHeroHeight = 0,
       maximumHeroHeight = 0,
       heroHeightFraction = 0,
       footerHeight = 0,
       minimumForegroundPeek = 0,
       _foregroundFillsViewport = foregroundFillsViewport;

  /// Gives one authored day/state its own natural upper-composition height.
  ///
  /// When the current outer-sheet extent is shorter, the foreground keeps a
  /// small visible grab area and covers the rest. Resizing the outer sheet
  /// reveals more of the unchanged composition; it never rescales the art.
  const MaatDayViewGraphicSpace.revealable({
    required double preferredHeight,
    required this.minimumForegroundPeek,
  }) : _mode = _MaatDayViewGraphicSpaceMode.revealable,
       fixedHeight = preferredHeight,
       minimumHeroHeight = 0,
       maximumHeroHeight = 0,
       heroHeightFraction = 0,
       footerHeight = 0,
       _foregroundFillsViewport = true,
       assert(minimumForegroundPeek >= 0);

  final _MaatDayViewGraphicSpaceMode _mode;
  final double? fixedHeight;
  final double minimumHeroHeight;
  final double maximumHeroHeight;
  final double heroHeightFraction;
  final double footerHeight;
  final double minimumForegroundPeek;
  final bool _foregroundFillsViewport;

  double foregroundStartFor(double boundedHeight) {
    return switch (_mode) {
      _MaatDayViewGraphicSpaceMode.responsive =>
        (boundedHeight * heroHeightFraction).clamp(
              minimumHeroHeight,
              maximumHeroHeight,
            ) +
            footerHeight,
      _MaatDayViewGraphicSpaceMode.fixed => fixedHeight!,
      _MaatDayViewGraphicSpaceMode.revealable =>
        boundedHeight >= fixedHeight!
            ? fixedHeight!
            : math.max(0.0, boundedHeight - minimumForegroundPeek),
    };
  }

  double artworkHeightFor(double boundedHeight, double foregroundStart) {
    return _mode == _MaatDayViewGraphicSpaceMode.revealable
        ? fixedHeight!
        : foregroundStart;
  }

  bool get foregroundFillsViewport => _foregroundFillsViewport;
}

@immutable
class MaatDayViewForegroundStyle {
  const MaatDayViewForegroundStyle.color({
    required Color color,
    required this.borderColor,
  }) : backgroundColor = color,
       backgroundGradient = null;

  const MaatDayViewForegroundStyle.gradient({
    required Gradient gradient,
    required this.borderColor,
  }) : backgroundColor = null,
       backgroundGradient = gradient;

  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final Color borderColor;
}

/// Follow the Sky's approved rising foreground shell shared by all five
/// built-in Ma'at Day View presentations.
class MaatDayViewForegroundShell extends StatelessWidget {
  const MaatDayViewForegroundShell({
    super.key,
    required this.style,
    required this.child,
  });

  final MaatDayViewForegroundStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        gradient: style.backgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: style.borderColor)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The one completion position inside the canonical Ma'at Day View housing.
///
/// Flows own the picker state and callbacks. The housing owns where that
/// picker sits relative to the flow body and fixed footer.
class MaatDayViewForegroundContent extends StatelessWidget {
  const MaatDayViewForegroundContent({
    super.key,
    required this.body,
    this.completion,
  });

  final Widget body;
  final Widget? completion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        body,
        if (completion != null) ...<Widget>[
          KeyedSubtree(
            key: const ValueKey<String>('maat-day-view-completion-slot'),
            child: completion!,
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

/// Keeps upper-layer controls aligned with the stationary artwork while the
/// one shared scroll owner moves the foreground over both.
///
/// The controls remain inside the earlier sliver, so the later foreground
/// still paints and hit-tests above them when it covers the upper composition.
class _StationaryInstrumentInput extends StatelessWidget {
  const _StationaryInstrumentInput({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;
    return AnimatedBuilder(
      animation: position,
      child: child,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, position.pixels), child: child),
    );
  }
}

/// The production geometry shared by instrument-backed calendar details.
///
/// This owns only the frame that Follow the Sky already proved: the fixed
/// instrument, the transparent input layer, and a vertical body that rises
/// over the instrument. Flow-specific art and copy stay with each flow.
class InstrumentEventPresentationFrame extends StatelessWidget {
  const InstrumentEventPresentationFrame({
    super.key,
    required this.decoration,
    required this.instrument,
    required this.instrumentFooter,
    required this.inputBuilder,
    required this.body,
    this.completion,
    required this.bodyScrollKey,
    required this.lowerSheetKey,
    required this.graphicSpace,
    required this.foregroundStyle,
    this.instrumentInteractive = false,
  });

  static const double footerHeight = 76;

  final Decoration decoration;
  final Widget instrument;
  final Widget instrumentFooter;
  final InstrumentEventInputBuilder inputBuilder;
  final Widget body;
  final Widget? completion;
  final Key bodyScrollKey;
  final Key lowerSheetKey;
  final MaatDayViewGraphicSpace graphicSpace;
  final MaatDayViewForegroundStyle foregroundStyle;
  final bool instrumentInteractive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 620.0;
        final lowerSheetStart = graphicSpace.foregroundStartFor(boundedHeight);
        final instrumentHeight = graphicSpace.artworkHeightFor(
          boundedHeight,
          lowerSheetStart,
        );
        final heroHeight = math.max(
          0.0,
          instrumentHeight - graphicSpace.footerHeight,
        );
        return DecoratedBox(
          decoration: decoration,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: instrumentHeight,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: heroHeight,
                      child: instrumentInteractive
                          ? RepaintBoundary(child: instrument)
                          : ExcludeSemantics(
                              child: IgnorePointer(
                                child: RepaintBoundary(child: instrument),
                              ),
                            ),
                    ),
                    if (graphicSpace.footerHeight > 0)
                      SizedBox(
                        height: graphicSpace.footerHeight,
                        child: instrumentFooter,
                      ),
                  ],
                ),
              ),
              CustomScrollView(
                key: bodyScrollKey,
                physics: const ClampingScrollPhysics(),
                hitTestBehavior: instrumentInteractive
                    ? HitTestBehavior.deferToChild
                    : HitTestBehavior.opaque,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: lowerSheetStart,
                      child: _StationaryInstrumentInput(
                        child: inputBuilder(
                          context,
                          heroHeight,
                          instrumentHeight,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: graphicSpace.foregroundFillsViewport
                            ? boundedHeight
                            : 0,
                      ),
                      child: RepaintBoundary(
                        key: lowerSheetKey,
                        child: MaatDayViewForegroundShell(
                          style: foregroundStyle,
                          child: MaatDayViewForegroundContent(
                            body: body,
                            completion: completion,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

@immutable
class InstrumentEventReflectionStyle {
  const InstrumentEventReflectionStyle({
    required this.activeColor,
    required this.armedBackgroundColor,
    required this.inactiveBackgroundColor,
    required this.inactiveIconColor,
    required this.inactiveLabelColor,
    required this.inactiveBorderColor,
    required this.promptColor,
    required this.reflectionTextColor,
    required this.mutedColor,
    required this.fieldFillColor,
    required this.microphoneBackgroundColor,
    required this.displayFontFamily,
    required this.uiFontFamily,
  });

  final Color activeColor;
  final Color armedBackgroundColor;
  final Color inactiveBackgroundColor;
  final Color inactiveIconColor;
  final Color inactiveLabelColor;
  final Color inactiveBorderColor;
  final Color promptColor;
  final Color reflectionTextColor;
  final Color mutedColor;
  final Color fieldFillColor;
  final Color microphoneBackgroundColor;
  final String displayFontFamily;
  final String uiFontFamily;
}

/// The shared reflection tool used by instrument-backed Day View sheets.
///
/// Flow presentations own their reflection state and persistence authority;
/// this widget owns only the proven Follow the Sky visual and interaction
/// geometry.
class InstrumentEventReflectionSection extends StatelessWidget {
  const InstrumentEventReflectionSection({
    super.key,
    required this.open,
    required this.onToggle,
    required this.prompt,
    required this.controller,
    required this.fieldKey,
    required this.style,
    this.horizontalPadding = 20,
  });

  final bool open;
  final VoidCallback onToggle;
  final String prompt;
  final TextEditingController controller;
  final Key fieldKey;
  final InstrumentEventReflectionStyle style;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            0,
          ),
          child: InstrumentEventTool(
            icon: Icons.description_outlined,
            label: 'Reflect',
            armed: open,
            onTap: onToggle,
            style: style,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            13,
            horizontalPadding,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.activeColor,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: style.activeColor, blurRadius: 10),
                    ],
                  ),
                  child: const SizedBox(width: 6, height: 6),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Everything you add here is automatically kept in today’s Journal.',
                  style: TextStyle(
                    color: style.mutedColor,
                    fontFamily: style.uiFontFamily,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (open)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  prompt,
                  style: TextStyle(
                    color: style.promptColor,
                    fontFamily: style.displayFontFamily,
                    fontSize: 20,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    TextField(
                      key: fieldKey,
                      controller: controller,
                      minLines: 3,
                      maxLines: 5,
                      style: TextStyle(
                        color: style.reflectionTextColor,
                        fontFamily: style.displayFontFamily,
                        fontSize: 19,
                        fontStyle: FontStyle.italic,
                        height: 1.42,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type it, or say it out loud.',
                        hintStyle: TextStyle(color: style.mutedColor),
                        filled: true,
                        fillColor: style.fieldFillColor,
                        contentPadding: const EdgeInsets.fromLTRB(
                          13,
                          13,
                          52,
                          13,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: style.activeColor.withValues(alpha: 0.30),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: style.activeColor),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 9, bottom: 11),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: style.microphoneBackgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: style.activeColor.withValues(alpha: 0.34),
                          ),
                        ),
                        child: Icon(
                          Icons.mic_none,
                          color: style.activeColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class InstrumentEventTool extends StatelessWidget {
  const InstrumentEventTool({
    super.key,
    required this.icon,
    required this.label,
    required this.armed,
    required this.onTap,
    required this.style,
  });

  final IconData icon;
  final String label;
  final bool armed;
  final VoidCallback onTap;
  final InstrumentEventReflectionStyle style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 69,
        decoration: BoxDecoration(
          color: armed
              ? style.armedBackgroundColor
              : style.inactiveBackgroundColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: armed ? style.activeColor : style.inactiveBorderColor,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              color: armed ? style.activeColor : style.inactiveIconColor,
              size: 23,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: armed ? style.activeColor : style.inactiveLabelColor,
                fontFamily: style.uiFontFamily,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstrumentEventSheetTopBar extends StatelessWidget {
  const InstrumentEventSheetTopBar({
    super.key,
    required this.semanticLabel,
    required this.handleColor,
    this.height = 48,
    this.handleTop,
    this.handleWidth = 42,
    this.onVerticalDragUpdate,
    this.leading,
    this.trailing,
  });

  final String semanticLabel;
  final Color handleColor;
  final double height;
  final double? handleTop;
  final double handleWidth;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: 52,
            right: 52,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              key: const ValueKey<String>('follow-sky-sheet-resize-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: onVerticalDragUpdate,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    top: handleTop,
                    child: Semantics(
                      label: semanticLabel,
                      child: Container(
                        key: const ValueKey<String>(
                          'instrument-sheet-handle-mark',
                        ),
                        width: handleWidth,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (leading != null)
            Positioned(left: 0, top: 0, bottom: 0, child: leading!),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}
