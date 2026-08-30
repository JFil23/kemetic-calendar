import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

@visibleForTesting
const double instrumentEventSheetMinExtent = 0.58;

Future<T?> showCalendarEventDetailSheetModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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

/// The shared horizontal, normalized input surface for instrument heroes.
///
/// Follow the Sky owns the established gesture contract: taps and horizontal
/// drags select one fraction across the instrument's inset track. Instrument
/// presentations decide only how that fraction is rendered.
class InstrumentEventHorizontalInput extends StatelessWidget {
  const InstrumentEventHorizontalInput({
    super.key,
    required this.gestureKey,
    required this.onSelectFraction,
  });

  final Key gestureKey;
  final ValueChanged<double> onSelectFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) {
          onSelectFraction(
            ((position.dx - 42) / (constraints.maxWidth - 84))
                .clamp(0.0, 1.0)
                .toDouble(),
          );
        }

        return GestureDetector(
          key: gestureKey,
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => update(details.localPosition),
          onHorizontalDragDown: (details) => update(details.localPosition),
          onHorizontalDragUpdate: (details) => update(details.localPosition),
          child: const SizedBox.expand(),
        );
      },
    );
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
  });

  final Widget child;
  final double borderRadius;

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
              decoration: BoxDecoration(
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
    this.trailing,
    this.footer,
  });

  final String semanticLabel;
  final Color handleColor;
  final Widget body;
  final Widget? trailing;
  final Widget? footer;

  @override
  State<InstrumentEventSheetHost> createState() =>
      _InstrumentEventSheetHostState();
}

class _InstrumentEventSheetHostState extends State<InstrumentEventSheetHost> {
  double _extent = instrumentEventSheetMinExtent;

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
    final keyboardInset = keyboardInsetOf(context);
    final availableSheetHeight = math.max(
      0.0,
      media.size.height -
          keyboardInset -
          media.padding.top -
          media.padding.bottom -
          12,
    );
    final effectiveExtent = keyboardInset > 0 ? 1.0 : _extent;
    final maxSheetHeight = availableSheetHeight * effectiveExtent;
    final hasFooter = widget.footer != null;

    // These values preserve the two production geometries that existed before
    // extraction: Day View reserves 120px for its fixed actions, while the
    // preview has no external footer and gives that space to the presentation.
    final bodyHeight = math.max(
      0.0,
      maxSheetHeight - (hasFooter ? 120.0 : 66.0),
    );
    final outerHeight = maxSheetHeight + (hasFooter ? 8.0 : 0.0);
    final outerPadding = hasFooter
        ? const EdgeInsets.fromLTRB(10, 8, 10, 10)
        : const EdgeInsets.fromLTRB(10, 0, 10, 10);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: outerHeight,
          child: Padding(
            padding: outerPadding,
            child: DayViewBottomSheetFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  InstrumentEventSheetTopBar(
                    semanticLabel: widget.semanticLabel,
                    handleColor: widget.handleColor,
                    onVerticalDragUpdate: keyboardInset == 0
                        ? (details) =>
                              _updateExtent(details, availableSheetHeight)
                        : null,
                    trailing: widget.trailing,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: bodyHeight,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: widget.body,
                    ),
                  ),
                  if (widget.footer != null) ...<Widget>[
                    const SizedBox(height: 8),
                    SizedBox(height: 46, child: widget.footer),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef InstrumentEventInputBuilder =
    Widget Function(
      BuildContext context,
      double heroHeight,
      double instrumentHeight,
    );

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
    required this.bodyScrollKey,
    required this.lowerSheetKey,
    this.fixedHeroHeight,
  });

  static const double footerHeight = 76;

  final Decoration decoration;
  final Widget instrument;
  final Widget instrumentFooter;
  final InstrumentEventInputBuilder inputBuilder;
  final Widget body;
  final Key bodyScrollKey;
  final Key lowerSheetKey;
  final double? fixedHeroHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 620.0;
        final heroHeight =
            fixedHeroHeight ??
            math.min(282.0, math.max(238.0, boundedHeight * 0.46));
        final instrumentHeight = heroHeight + footerHeight;
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
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: RepaintBoundary(child: instrument),
                        ),
                      ),
                    ),
                    SizedBox(height: footerHeight, child: instrumentFooter),
                  ],
                ),
              ),
              CustomScrollView(
                key: bodyScrollKey,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: instrumentHeight,
                      child: inputBuilder(
                        context,
                        heroHeight,
                        instrumentHeight,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(key: lowerSheetKey, child: body),
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
                      scrollPadding: keyboardManagedTextFieldScrollPadding,
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
    this.onVerticalDragUpdate,
    this.trailing,
  });

  final String semanticLabel;
  final Color handleColor;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
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
              child: Center(
                child: Semantics(
                  label: semanticLabel,
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}
