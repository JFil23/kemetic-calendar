import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

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

class StoneRegisterDateWheel extends StatelessWidget {
  const StoneRegisterDateWheel({
    super.key,
    required this.columns,
    required this.controllers,
    required this.accent,
    required this.onSelectedItemChanged,
  });

  final List<StoneWheelColumn> columns;
  final Map<String, FixedExtentScrollController> controllers;
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
  final FixedExtentScrollController? controller;
  final Color accent;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    final values = column.values;
    if (values.isEmpty || controller == null) {
      return const SizedBox.shrink();
    }

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
      child: CupertinoPicker(
        key: ValueKey('stone-register-wheel-${column.id}'),
        scrollController: controller,
        itemExtent: StoneRegisterDatePickerTheme.rowHeight,
        looping: column.looping,
        backgroundColor: Colors.transparent,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (index) {
          final normalized = column.looping ? index % values.length : index;
          onSelectedItemChanged(normalized);
        },
        children: List<Widget>.generate(values.length, (index) {
          return _WheelItem(
            label: values[index],
            distance: _visualDistance(index, column),
            accent: accent,
            baseStyle: column.textStyle,
          );
        }),
      ),
    );
  }

  int _visualDistance(int index, StoneWheelColumn column) {
    final selected = column.selectedIndex
        .clamp(0, column.values.length - 1)
        .toInt();
    final raw = (index - selected).abs();
    if (!column.looping || column.values.isEmpty) return math.min(raw, 3);
    return math.min(raw, column.values.length - raw).clamp(0, 3).toInt();
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
  final int distance;
  final Color accent;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final selected = distance == 0;
    final color = switch (distance) {
      0 => const Color(0xFFEFE8DB),
      1 => StoneRegisterDatePickerTheme.silverMid.withValues(alpha: 0.72),
      2 => StoneRegisterDatePickerTheme.silverLow.withValues(alpha: 0.54),
      _ => StoneRegisterDatePickerTheme.silverLow.withValues(alpha: 0.30),
    };
    final scale = switch (distance) {
      0 => 1.06,
      1 => 0.92,
      2 => 0.83,
      _ => 0.78,
    };
    final style =
        (baseStyle ??
                const TextStyle(
                  fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  height: 1.05,
                ))
            .copyWith(
              color: color,
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
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        scale: scale,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          style: style,
          textAlign: TextAlign.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
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
