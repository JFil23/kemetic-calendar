import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

const _stoneWheelSnapDebounce = Duration(milliseconds: 90);
const _stoneWheelSnapDuration = Duration(milliseconds: 170);
const _stoneWheelLoopingCycleCount = 101;
const _stoneWheelLoopingCenterCycle = _stoneWheelLoopingCycleCount ~/ 2;

@immutable
class StoneWheelColumn {
  const StoneWheelColumn({
    required this.id,
    required this.values,
    required this.selectedIndex,
    this.flex = 1,
    this.looping = false,
    this.textStyle,
  });

  final String id;
  final List<String> values;
  final int selectedIndex;
  final int flex;
  final bool looping;
  final TextStyle? textStyle;
}

@immutable
class StoneWheelSelection {
  const StoneWheelSelection(this.indexes);

  final Map<String, int> indexes;

  int indexOf(String id) {
    final index = indexes[id];
    if (index == null) {
      throw ArgumentError('Missing wheel selection for "$id".');
    }
    return index;
  }

  StoneWheelSelection withIndex(String id, int index) {
    return StoneWheelSelection({...indexes, id: index});
  }
}

class StoneRegisterWheelMetrics {
  const StoneRegisterWheelMetrics._();

  static double initialOffsetFor(StoneWheelColumn column) {
    return offsetForSelectedIndex(column, column.selectedIndex);
  }

  static int selectedIndexForOffset(StoneWheelColumn column, double offset) {
    final valueCount = column.values.length;
    if (valueCount == 0) return 0;
    final virtualIndex = (offset / StoneRegisterDatePickerTheme.rowHeight)
        .round();
    return _normalizedIndexForVirtualIndex(column, virtualIndex);
  }

  static double snapOffsetFor(StoneWheelColumn column, double currentOffset) {
    return offsetForSelectedIndex(
      column,
      selectedIndexForOffset(column, currentOffset),
      currentOffset: currentOffset,
    );
  }

  static double offsetForSelectedIndex(
    StoneWheelColumn column,
    int selectedIndex, {
    double? currentOffset,
  }) {
    final virtualIndex = _virtualIndexForSelectedIndex(
      column,
      selectedIndex,
      currentOffset: currentOffset,
    );
    return virtualIndex * StoneRegisterDatePickerTheme.rowHeight;
  }

  static int itemCountFor(StoneWheelColumn column) {
    final valueCount = column.values.length;
    if (valueCount == 0) return 0;
    return column.looping
        ? valueCount * _stoneWheelLoopingCycleCount
        : valueCount;
  }

  static int valueIndexForVirtualIndex(
    StoneWheelColumn column,
    int virtualIndex,
  ) {
    return _normalizedIndexForVirtualIndex(column, virtualIndex);
  }

  static int _virtualIndexForSelectedIndex(
    StoneWheelColumn column,
    int selectedIndex, {
    double? currentOffset,
  }) {
    final valueCount = column.values.length;
    if (valueCount == 0) return 0;
    final normalized = selectedIndex % valueCount;
    final targetIndex = normalized < 0 ? normalized + valueCount : normalized;
    if (!column.looping) {
      return targetIndex.clamp(0, valueCount - 1).toInt();
    }

    if (currentOffset == null) {
      return _stoneWheelLoopingCenterCycle * valueCount + targetIndex;
    }

    final currentVirtual =
        (currentOffset / StoneRegisterDatePickerTheme.rowHeight).round();
    final currentCycle = (currentVirtual ~/ valueCount)
        .clamp(0, _stoneWheelLoopingCycleCount - 1)
        .toInt();
    var bestVirtual = currentCycle * valueCount + targetIndex;
    var bestDistance = (bestVirtual - currentVirtual).abs();

    for (final cycle in <int>[
      currentCycle - 1,
      currentCycle,
      currentCycle + 1,
    ]) {
      if (cycle < 0 || cycle >= _stoneWheelLoopingCycleCount) continue;
      final candidate = cycle * valueCount + targetIndex;
      final distance = (candidate - currentVirtual).abs();
      if (distance < bestDistance) {
        bestVirtual = candidate;
        bestDistance = distance;
      }
    }

    return bestVirtual
        .clamp(0, valueCount * _stoneWheelLoopingCycleCount - 1)
        .toInt();
  }

  static int _normalizedIndexForVirtualIndex(
    StoneWheelColumn column,
    int virtualIndex,
  ) {
    final valueCount = column.values.length;
    if (valueCount == 0) return 0;
    if (!column.looping) {
      return virtualIndex.clamp(0, valueCount - 1).toInt();
    }
    final normalized = virtualIndex % valueCount;
    return normalized < 0 ? normalized + valueCount : normalized;
  }
}

class StoneRegisterDateWheel extends StatelessWidget {
  const StoneRegisterDateWheel({
    super.key,
    required this.columns,
    required this.controllers,
    required this.accent,
    required this.onSelectedItemChanged,
  });

  final List<StoneWheelColumn> columns;
  final Map<String, ScrollController> controllers;
  final Color accent;
  final void Function(String columnId, int selectedIndex) onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF191309), Color(0xFF110D07)],
        ),
        borderRadius: BorderRadius.circular(
          StoneRegisterDatePickerTheme.plateRadius,
        ),
        border: Border.all(color: const Color(0xFF2E2616)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 48,
            spreadRadius: -26,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SizedBox(
          height: StoneRegisterDatePickerTheme.wheelHeight,
          child: Stack(
            children: [
              Positioned.fill(
                top:
                    StoneRegisterDatePickerTheme.rowHeight *
                    ((StoneRegisterDatePickerTheme.visibleRows - 1) / 2),
                bottom:
                    StoneRegisterDatePickerTheme.rowHeight *
                    ((StoneRegisterDatePickerTheme.visibleRows - 1) / 2),
                child: _StoneRegisterLens(accent: accent),
              ),
              Row(
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      flex: columns[i].flex,
                      child: _WheelColumnView(
                        column: columns[i],
                        controller: controllers[columns[i].id],
                        accent: accent,
                        onSelectedItemChanged: (index) =>
                            onSelectedItemChanged(columns[i].id, index),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelColumnView extends StatelessWidget {
  const _WheelColumnView({
    required this.column,
    required this.controller,
    required this.accent,
    required this.onSelectedItemChanged,
  });

  final StoneWheelColumn column;
  final ScrollController? controller;
  final Color accent;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    if (column.values.isEmpty || controller == null) {
      return const SizedBox.shrink();
    }

    return _WheelColumnScroller(
      column: column,
      controller: controller!,
      accent: accent,
      onSelectedItemChanged: onSelectedItemChanged,
    );
  }
}

class _WheelColumnScroller extends StatefulWidget {
  const _WheelColumnScroller({
    required this.column,
    required this.controller,
    required this.accent,
    required this.onSelectedItemChanged,
  });

  final StoneWheelColumn column;
  final ScrollController controller;
  final Color accent;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  State<_WheelColumnScroller> createState() => _WheelColumnScrollerState();
}

class _WheelColumnScrollerState extends State<_WheelColumnScroller> {
  late final ValueNotifier<double> _scrollOffset;
  Timer? _snapTimer;
  bool _frameScheduled = false;
  int? _lastReportedIndex;

  @override
  void initState() {
    super.initState();
    _scrollOffset = ValueNotifier<double>(
      widget.controller.hasClients
          ? widget.controller.offset
          : widget.controller.initialScrollOffset,
    );
    _lastReportedIndex = StoneRegisterWheelMetrics.selectedIndexForOffset(
      widget.column,
      _scrollOffset.value,
    );
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _WheelColumnScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
      _scrollOffset.value = widget.controller.hasClients
          ? widget.controller.offset
          : widget.controller.initialScrollOffset;
      _lastReportedIndex = StoneRegisterWheelMetrics.selectedIndexForOffset(
        widget.column,
        _scrollOffset.value,
      );
    }
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    widget.controller.removeListener(_handleScroll);
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.column.values;
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    final itemCount = StoneRegisterWheelMetrics.itemCountFor(widget.column);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0, 0.30, 0.70, 1],
      ).createShader(bounds),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _scheduleDeferredSnap();
          return false;
        },
        child: ListView.builder(
          key: ValueKey('stone-register-wheel-${widget.column.id}'),
          controller: widget.controller,
          itemExtent: StoneRegisterDatePickerTheme.rowHeight,
          padding: const EdgeInsets.symmetric(
            vertical: StoneRegisterDatePickerTheme.rowHeight * 2,
          ),
          itemCount: itemCount,
          itemBuilder: (context, virtualIndex) {
            final valueIndex =
                StoneRegisterWheelMetrics.valueIndexForVirtualIndex(
                  widget.column,
                  virtualIndex,
                );
            return ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, _) {
                final fractionalIndex =
                    offset / StoneRegisterDatePickerTheme.rowHeight;
                return _WheelItem(
                  label: values[valueIndex],
                  distance: (virtualIndex - fractionalIndex).abs(),
                  accent: widget.accent,
                  baseStyle: widget.column.textStyle,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleScroll() {
    _scheduleOffsetRepaint();
    _reportNearestIndex();
    _scheduleDeferredSnap();
  }

  void _scheduleOffsetRepaint() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted || !widget.controller.hasClients) return;
      _scrollOffset.value = widget.controller.offset;
    });
  }

  void _reportNearestIndex() {
    if (!widget.controller.hasClients) return;
    final selectedIndex = StoneRegisterWheelMetrics.selectedIndexForOffset(
      widget.column,
      widget.controller.offset,
    );
    if (_lastReportedIndex == selectedIndex) return;
    _lastReportedIndex = selectedIndex;
    widget.onSelectedItemChanged(selectedIndex);
  }

  void _scheduleDeferredSnap() {
    _snapTimer?.cancel();
    _snapTimer = Timer(_stoneWheelSnapDebounce, _snapToNearestIndex);
  }

  void _snapToNearestIndex() {
    if (!mounted || !widget.controller.hasClients) return;
    final target = StoneRegisterWheelMetrics.snapOffsetFor(
      widget.column,
      widget.controller.offset,
    );
    if ((target - widget.controller.offset).abs() < 0.5) return;
    unawaited(
      widget.controller.animateTo(
        target,
        duration: _stoneWheelSnapDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _WheelItem extends StatelessWidget {
  const _WheelItem({
    required this.label,
    required this.distance,
    required this.accent,
    this.baseStyle,
  });

  final String label;
  final double distance;
  final Color accent;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final visual = _WheelItemVisuals.fromDistance(distance);
    final selected = distance < 0.45;
    final style =
        (baseStyle ??
                const TextStyle(
                  fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  height: 1.05,
                ))
            .copyWith(
              color: visual.color,
              shadows: selected
                  ? [
                      Shadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 12,
                      ),
                      const Shadow(
                        color: Colors.black87,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            );

    return Center(
      child: Transform.scale(
        scale: visual.scale,
        child: Opacity(
          opacity: visual.opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _WheelItemVisuals {
  const _WheelItemVisuals({
    required this.scale,
    required this.opacity,
    required this.color,
  });

  final double scale;
  final double opacity;
  final Color color;

  static _WheelItemVisuals fromDistance(double distance) {
    final normalized = distance.clamp(0.0, 3.0).toDouble();
    if (normalized <= 1) {
      final t = normalized;
      return _WheelItemVisuals(
        scale: _lerp(1.06, 0.92, t),
        opacity: _lerp(1.0, 0.62, t),
        color: Color.lerp(
          const Color(0xFFEFE8DB),
          StoneRegisterDatePickerTheme.silverMid,
          t,
        )!,
      );
    }
    if (normalized <= 2) {
      final t = normalized - 1;
      return _WheelItemVisuals(
        scale: _lerp(0.92, 0.83, t),
        opacity: _lerp(0.62, 0.32, t),
        color: Color.lerp(
          StoneRegisterDatePickerTheme.silverMid,
          StoneRegisterDatePickerTheme.silverLow,
          t,
        )!,
      );
    }

    final t = normalized - 2;
    return _WheelItemVisuals(
      scale: _lerp(0.83, 0.76, t),
      opacity: _lerp(0.32, 0.08, t),
      color: StoneRegisterDatePickerTheme.silverLow,
    );
  }

  static double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }
}

class _StoneRegisterLens extends StatelessWidget {
  const _StoneRegisterLens({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final inner = Color.lerp(StoneRegisterDatePickerTheme.base, accent, 0.16)!;
    final mid = Color.lerp(StoneRegisterDatePickerTheme.base, accent, 0.09)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.25,
          colors: [inner, mid, const Color(0xFF0E0A06)],
          stops: const [0, 0.45, 1],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Align(
        alignment: const Alignment(0, 0.72),
        child: FractionallySizedBox(
          widthFactor: 0.88,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accent.withValues(alpha: 0.92),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.65),
                  blurRadius: 11,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
