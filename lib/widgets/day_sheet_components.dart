import 'dart:math' as math;

import 'package:flutter/material.dart';

enum DaySheetTab { notes, reminders }

const List<Color> daySheetColorPalette = <Color>[
  Color(0xFF55DDE0),
  Color(0xFF7B7BE8),
  Color(0xFFF0726E),
  Color(0xFF5FC97A),
  Color(0xFFE8C34F),
  Color(0xFF5AA6E8),
  Color(0xFFC77BE0),
  Color(0xFF3FB89A),
  Color(0xFFE89A5A),
];

class DaySheetTokens {
  const DaySheetTokens._();

  static const bg = Color(0xFF0B0906);
  static const bgRaise = Color(0xFF120F0A);
  static const gold = Color(0xFFD4AE43);
  static const goldDim = Color(0xFFA4842F);
  static const silverHi = Color(0xFFC8C4BC);
  static const silverMid = Color(0xFF9E9A94);
  static const silverLo = Color(0xFF6A6660);
  static const hair = Color(0x29AA966E);
  static const hairStrong = Color(0x47AA966E);
  static const serif = 'CormorantGaramond';
  static const ui = 'Inter';

  static Color accentSoft(Color accent) => accent.withValues(alpha: 0.14);
  static Color accentLine(Color accent) => accent.withValues(alpha: 0.40);
}

class DaySheetScaffold extends StatelessWidget {
  const DaySheetScaffold({
    super.key,
    required this.height,
    required this.keyboardInset,
    required this.activeTab,
    required this.accent,
    required this.onTabSelected,
    required this.onClose,
    required this.body,
    required this.fab,
    this.onCartoucheTap,
  });

  final double height;
  final double keyboardInset;
  final DaySheetTab activeTab;
  final Color accent;
  final ValueChanged<DaySheetTab> onTabSelected;
  final VoidCallback onClose;
  final Widget body;
  final Widget fab;
  final VoidCallback? onCartoucheTap;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final effectiveBottom = keyboardInset + bottomSafe;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: DaySheetTokens.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: DaySheetTokens.hair, width: 1)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: effectiveBottom + 130),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    const _DaySheetHandle(),
                    DaySheetTabBar(
                      activeTab: activeTab,
                      accent: accent,
                      onSelected: onTabSelected,
                    ),
                    body,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 8,
            child: IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(
                Icons.close,
                color: DaySheetTokens.silverMid,
                size: 22,
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: effectiveBottom + 34,
            child: DaySheetCartouche(onTap: onCartoucheTap),
          ),
          Positioned(right: 22, bottom: effectiveBottom + 30, child: fab),
        ],
      ),
    );
  }
}

class _DaySheetHandle extends StatelessWidget {
  const _DaySheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: DaySheetTokens.silverLo.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class DaySheetTabBar extends StatelessWidget {
  const DaySheetTabBar({
    super.key,
    required this.activeTab,
    required this.accent,
    required this.onSelected,
  });

  final DaySheetTab activeTab;
  final Color accent;
  final ValueChanged<DaySheetTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DaySheetTabButton(
            label: 'Notes',
            selected: activeTab == DaySheetTab.notes,
            accent: accent,
            onTap: () => onSelected(DaySheetTab.notes),
          ),
          const SizedBox(width: 10),
          _DaySheetTabButton(
            label: 'Reminders',
            selected: activeTab == DaySheetTab.reminders,
            accent: accent,
            onTap: () => onSelected(DaySheetTab.reminders),
          ),
        ],
      ),
    );
  }
}

class _DaySheetTabButton extends StatelessWidget {
  const _DaySheetTabButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? DaySheetTokens.accentSoft(accent)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? DaySheetTokens.accentLine(accent)
                  : DaySheetTokens.hairStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 14, color: accent),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: DaySheetTokens.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.02,
                  color: selected ? accent : DaySheetTokens.silverMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DaySheetSectionHeader extends StatelessWidget {
  const DaySheetSectionHeader({
    super.key,
    required this.label,
    this.count,
    this.expanded,
    this.onTap,
    this.topMargin = 22,
    this.center = false,
  });

  final String label;
  final int? count;
  final bool? expanded;
  final VoidCallback? onTap;
  final double topMargin;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        DaySheetEyebrow(label, center: center),
        if (count != null) ...[
          const SizedBox(width: 12),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: DaySheetTokens.serif,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: DaySheetTokens.silverLo,
            ),
          ),
        ],
        if (!center) ...[
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: DaySheetTokens.hair),
          ),
        ],
        if (expanded != null) ...[
          const SizedBox(width: 12),
          AnimatedRotation(
            turns: expanded! ? 0 : -0.25,
            duration: const Duration(milliseconds: 180),
            child: const Icon(
              Icons.keyboard_arrow_down,
              color: DaySheetTokens.silverMid,
              size: 18,
            ),
          ),
        ],
      ],
    );
    return GestureDetector(
      behavior: onTap == null
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(top: topMargin, bottom: 4),
        child: content,
      ),
    );
  }
}

class DaySheetEyebrow extends StatelessWidget {
  const DaySheetEyebrow(this.label, {super.key, this.center = false});

  final String label;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        fontFamily: DaySheetTokens.ui,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.22,
        color: DaySheetTokens.gold,
      ),
    );
  }
}

class DaySheetTextField extends StatelessWidget {
  const DaySheetTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.scrollPadding = EdgeInsets.zero,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final EdgeInsets scrollPadding;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: minLines,
        maxLines: maxLines,
        scrollPadding: scrollPadding,
        style: const TextStyle(
          fontFamily: DaySheetTokens.serif,
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: DaySheetTokens.silverMid,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: DaySheetTokens.serif,
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: DaySheetTokens.silverLo,
          ),
          filled: true,
          fillColor: DaySheetTokens.bgRaise,
          contentPadding: const EdgeInsets.all(16),
          border: _border(DaySheetTokens.hair),
          enabledBorder: _border(DaySheetTokens.hair),
          focusedBorder: _border(DaySheetTokens.gold),
          disabledBorder: _border(DaySheetTokens.hair),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }
}

class DaySheetSwitch extends StatelessWidget {
  const DaySheetSwitch({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          color: value
              ? DaySheetTokens.accentSoft(accent)
              : DaySheetTokens.bgRaise,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? DaySheetTokens.accentLine(accent)
                : DaySheetTokens.hairStrong,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: value ? 27 : 3,
              top: 3,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? accent : DaySheetTokens.silverMid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DaySheetToggleRow extends StatelessWidget {
  const DaySheetToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
    this.topMargin = 24,
  });

  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: DaySheetTokens.serif,
              fontSize: 18,
              color: DaySheetTokens.silverHi,
            ),
          ),
          DaySheetSwitch(value: value, accent: accent, onChanged: onChanged),
        ],
      ),
    );
  }
}

class DaySheetTimePill extends StatelessWidget {
  const DaySheetTimePill({
    super.key,
    required this.caption,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.icon,
  });

  final String caption;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(
            fontFamily: DaySheetTokens.ui,
            fontSize: 12,
            color: DaySheetTokens.silverLo,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: DaySheetTokens.hairStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: DaySheetTokens.silverHi),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: DaySheetTokens.serif,
                      fontSize: 17,
                      color: DaySheetTokens.silverHi,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DaySheetMetaRow extends StatelessWidget {
  const DaySheetMetaRow({
    super.key,
    required this.label,
    this.value,
    this.valueColor = DaySheetTokens.gold,
    this.onTap,
    this.showChevron = true,
  });

  final String label;
  final String? value;
  final Color valueColor;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DaySheetTokens.hair)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: DaySheetTokens.serif,
                  fontSize: 18,
                  color: DaySheetTokens.silverHi,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: DaySheetTokens.ui,
                    fontSize: 14,
                    color: valueColor,
                  ),
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: DaySheetTokens.silverMid,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DaySheetCategoryChips extends StatelessWidget {
  const DaySheetCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final Color accent;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const DaySheetEyebrow('Category - optional', center: true),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in categories)
                _CategoryChip(
                  label: category,
                  selected: selected == category,
                  accent: accent,
                  onTap: () => onSelected(category),
                ),
              _CategoryChip(
                label: 'Clear',
                selected: false,
                accent: accent,
                muted: true,
                icon: Icons.close,
                onTap: () => onSelected(null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.muted = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool muted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? DaySheetTokens.accentSoft(accent)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? DaySheetTokens.accentLine(accent)
                : DaySheetTokens.hairStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? accent
                    : (muted
                          ? DaySheetTokens.silverLo
                          : DaySheetTokens.silverHi),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: DaySheetTokens.serif,
                fontSize: 16,
                color: selected
                    ? accent
                    : (muted
                          ? DaySheetTokens.silverLo
                          : DaySheetTokens.silverHi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DaySheetColorSwatches extends StatelessWidget {
  const DaySheetColorSwatches({
    super.key,
    required this.palette,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<Color> palette;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const DaySheetEyebrow('Color', center: true),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < palette.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: palette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedIndex == i
                              ? DaySheetTokens.gold
                              : Colors.transparent,
                          width: selectedIndex == i ? 2 : 0,
                          strokeAlign: BorderSide.strokeAlignOutside,
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
  }
}

class DaySheetSpectrumColorPicker extends StatelessWidget {
  const DaySheetSpectrumColorPicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  static Color colorFromHue(double hueDegrees) {
    return HSLColor.fromAHSL(1.0, hueDegrees % 360.0, 0.72, 0.48).toColor();
  }

  static double hueForColor(Color color) => HSLColor.fromColor(color).hue;

  static String hexForColor(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  static String colorNameForHue(double hue) {
    final normalized = hue % 360.0;
    if (normalized < 12 || normalized >= 345) return 'CRIMSON';
    if (normalized < 28) return 'VERMILION';
    if (normalized < 45) return 'EMBER';
    if (normalized < 62) return 'AMBER';
    if (normalized < 82) return 'GOLD';
    if (normalized < 115) return 'GREEN';
    if (normalized < 150) return 'JADE';
    if (normalized < 180) return 'TEAL';
    if (normalized < 205) return 'CYAN';
    if (normalized < 230) return 'SKY';
    if (normalized < 255) return 'INDIGO';
    if (normalized < 285) return 'VIOLET';
    if (normalized < 320) return 'MAGENTA';
    return 'ROSE';
  }

  @override
  Widget build(BuildContext context) {
    final hue = hueForColor(selectedColor);
    final hsl = HSLColor.fromColor(selectedColor);
    final softenedAccent = hsl
        .withSaturation(math.min(hsl.saturation * 0.62, 0.56))
        .withLightness(0.54)
        .toColor();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: DaySheetEyebrow('Color', center: true)),
          const SizedBox(height: 14),
          _DaySheetSpectrumBar(
            hue: hue,
            selectedColor: selectedColor,
            onHueChanged: (value) => onChanged(colorFromHue(value)),
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF050403),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: softenedAccent.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Container(
                  key: const ValueKey('day-sheet-color-preview-dot'),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedColor,
                    boxShadow: [
                      BoxShadow(
                        color: selectedColor.withValues(alpha: 0.18),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  hexForColor(selectedColor),
                  key: const ValueKey('day-sheet-color-hex'),
                  style: TextStyle(
                    color: selectedColor,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'GentiumPlus',
                  ),
                ),
                const Spacer(),
                Text(
                  colorNameForHue(hue),
                  key: const ValueKey('day-sheet-color-name'),
                  style: TextStyle(
                    color: selectedColor.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
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

class _DaySheetSpectrumBar extends StatelessWidget {
  const _DaySheetSpectrumBar({
    required this.hue,
    required this.selectedColor,
    required this.onHueChanged,
  });

  final double hue;
  final Color selectedColor;
  final ValueChanged<double> onHueChanged;

  void _updateHue(Offset localPosition, double width) {
    final t = (localPosition.dx / width).clamp(0.0, 1.0);
    onHueChanged(t * 360.0);
  }

  @override
  Widget build(BuildContext context) {
    const barHeight = 28.0;
    const thumbSize = 34.0;
    const hitHeight = 44.0;
    final gradientColors = <Color>[
      for (final hue in const [
        0.0,
        28.0,
        56.0,
        105.0,
        165.0,
        210.0,
        245.0,
        280.0,
        320.0,
        360.0,
      ])
        DaySheetSpectrumColorPicker.colorFromHue(hue),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth);
        final left = ((hue % 360.0) / 360.0) * width;
        final minThumbLeft = -thumbSize * 0.16;
        final maxThumbLeft = math.max(minThumbLeft, width - thumbSize * 0.84);
        return Semantics(
          label: 'day-sheet-spectrum',
          slider: true,
          value: hue.round().toString(),
          child: GestureDetector(
            key: const ValueKey('day-sheet-spectrum'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _updateHue(details.localPosition, width),
            onHorizontalDragStart: (details) =>
                _updateHue(details.localPosition, width),
            onHorizontalDragUpdate: (details) =>
                _updateHue(details.localPosition, width),
            child: SizedBox(
              height: hitHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    top: (hitHeight - barHeight) / 2,
                    bottom: (hitHeight - barHeight) / 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: LinearGradient(colors: gradientColors),
                        border: Border.all(
                          color: const Color(
                            0xFF4A3312,
                          ).withValues(alpha: 0.45),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x22FFFFFF),
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (left - thumbSize / 2).clamp(
                      minThumbLeft,
                      maxThumbLeft,
                    ),
                    child: Container(
                      key: const ValueKey('day-sheet-spectrum-thumb'),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF4EBDD),
                        boxShadow: [
                          BoxShadow(
                            color: selectedColor.withValues(alpha: 0.32),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Color(0xAA000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedColor,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DaySheetFlowRow extends StatelessWidget {
  const DaySheetFlowRow({
    super.key,
    required this.color,
    required this.name,
    required this.meta,
    this.onTap,
  });

  final Color color;
  final String name;
  final String meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DaySheetTokens.hair)),
      ),
      child: Row(
        children: [
          _Dot(color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: DaySheetTokens.serif,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: DaySheetTokens.silverHi,
                  ),
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      meta,
                      style: const TextStyle(
                        fontFamily: DaySheetTokens.ui,
                        fontSize: 12,
                        color: DaySheetTokens.silverLo,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: row,
    );
  }
}

class DaySheetNoteRow extends StatelessWidget {
  const DaySheetNoteRow({
    super.key,
    required this.name,
    required this.meta,
    this.color,
    required this.onTap,
    required this.onDelete,
  });

  final String name;
  final String meta;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DaySheetTokens.hair)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (color != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Dot(color: color!),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: DaySheetTokens.serif,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      color: DaySheetTokens.silverHi,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        meta,
                        style: const TextStyle(
                          fontFamily: DaySheetTokens.ui,
                          fontSize: 12,
                          color: DaySheetTokens.silverLo,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete note',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: DaySheetTokens.silverLo,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class DaySheetReminderRow extends StatelessWidget {
  const DaySheetReminderRow({
    super.key,
    required this.color,
    required this.name,
    required this.enabled,
    required this.rulePrimary,
    this.ruleSubline,
    required this.onTap,
    required this.menu,
  });

  final Color color;
  final String name;
  final bool enabled;
  final String rulePrimary;
  final String? ruleSubline;
  final VoidCallback onTap;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DaySheetTokens.hair)),
        ),
        child: Row(
          children: [
            _Dot(color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: DaySheetTokens.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? DaySheetTokens.silverHi
                          : DaySheetTokens.silverLo,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled ? 'On' : 'Off',
                    style: const TextStyle(
                      fontFamily: DaySheetTokens.ui,
                      fontSize: 11,
                      letterSpacing: 0.04,
                      color: DaySheetTokens.silverLo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rulePrimary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: DaySheetTokens.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DaySheetTokens.gold,
                    ),
                  ),
                  if (ruleSubline != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ruleSubline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: DaySheetTokens.ui,
                          fontSize: 11,
                          color: DaySheetTokens.silverLo,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            menu,
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class DaySheetFab extends StatelessWidget {
  const DaySheetFab.round({
    super.key,
    required this.label,
    required this.onPressed,
  }) : pill = false;

  const DaySheetFab.pill({
    super.key,
    required this.label,
    required this.onPressed,
  }) : pill = true;

  final String label;
  final VoidCallback onPressed;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: pill ? null : 96,
        height: pill ? null : 96,
        padding: pill
            ? const EdgeInsets.symmetric(horizontal: 28, vertical: 18)
            : null,
        decoration: BoxDecoration(
          color: DaySheetTokens.gold,
          borderRadius: BorderRadius.circular(pill ? 30 : 48),
          boxShadow: [
            BoxShadow(
              color: DaySheetTokens.gold.withValues(alpha: 0.28),
              blurRadius: 26,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pill) ...[
                const Text(
                  '+',
                  style: TextStyle(
                    fontFamily: DaySheetTokens.ui,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1305),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: DaySheetTokens.serif,
                  fontSize: pill ? 18 : 19,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1305),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DaySheetSaveButton extends StatelessWidget {
  const DaySheetSaveButton({
    super.key,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(accent);
    final softenedAccent = hsl
        .withSaturation(math.min(hsl.saturation * 0.62, 0.56))
        .withLightness(0.54)
        .toColor();
    const base = Color(0xFF050403);
    final background = Color.alphaBlend(
      softenedAccent.withValues(alpha: 0.13),
      base,
    );
    final border = softenedAccent.withValues(alpha: 0.34);
    final foreground = Color.lerp(
      softenedAccent,
      const Color(0xFFE8D6A8),
      0.18,
    )!;

    return SizedBox(
      width: 66,
      height: 36,
      child: TextButton(
        key: const ValueKey('day-sheet-save-cta'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: border),
          backgroundColor: background,
          minimumSize: const Size(66, 36),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'GentiumPlus',
          ),
        ),
      ),
    );
  }
}

class DaySheetCartouche extends StatelessWidget {
  const DaySheetCartouche({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: DaySheetTokens.goldDim),
        ),
        child: Text(
          '\u{13260}',
          style: TextStyle(
            fontFamily: 'Noto Sans Egyptian Hieroglyphs',
            fontSize: 22,
            color: DaySheetTokens.goldDim.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
