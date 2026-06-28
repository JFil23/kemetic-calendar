import 'package:flutter/material.dart';

import '../../shared/kemetic_text.dart';
import 'library_visual_tokens.dart';

@immutable
class KemeticNumeralGroup {
  const KemeticNumeralGroup({
    required this.value,
    required this.glyph,
    required this.count,
    required this.rows,
  });

  final int value;
  final String glyph;
  final int count;
  final List<String> rows;
}

const List<({int value, String glyph})> _kemeticGlyphs = [
  (value: 1000000, glyph: '𓁨'),
  (value: 100000, glyph: '𓆐'),
  (value: 10000, glyph: '𓂭'),
  (value: 1000, glyph: '𓆼'),
  (value: 100, glyph: '𓍢'),
  (value: 10, glyph: '𓎆'),
  (value: 1, glyph: '𓏺'),
];

List<KemeticNumeralGroup> decomposeKemeticNumber(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'value', 'must be greater than zero');
  }

  var remaining = value;
  final groups = <KemeticNumeralGroup>[];
  for (final spec in _kemeticGlyphs) {
    final count = remaining ~/ spec.value;
    if (count == 0) continue;
    remaining -= count * spec.value;
    final perRow = spec.value == 1 ? 3 : 2;
    groups.add(
      KemeticNumeralGroup(
        value: spec.value,
        glyph: spec.glyph,
        count: count,
        rows: _stackKemeticRows(spec.glyph, count, perRow),
      ),
    );
  }
  return groups;
}

List<String> _stackKemeticRows(String glyph, int count, int perRow) {
  final rows = <String>[];
  var remaining = count;
  while (remaining > 0) {
    final rowCount = remaining < perRow ? remaining : perRow;
    rows.add(List<String>.filled(rowCount, glyph).join());
    remaining -= rowCount;
  }
  return rows;
}

class KemeticNumeral extends StatelessWidget {
  const KemeticNumeral({
    super.key,
    required this.value,
    required this.color,
    this.onesColor,
    this.fontSize = 18,
  });

  final int value;
  final Color color;
  final Color? onesColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final groups = decomposeKemeticNumber(value);
    return Semantics(
      label: 'Chapter $value',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final group in groups)
                _KemeticNumeralGroupWidget(
                  group: group,
                  color: group.value == 1 ? onesColor ?? color : color,
                  fontSize: group.value == 1 ? fontSize - 2 : fontSize,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KemeticNumeralGroupWidget extends StatelessWidget {
  const _KemeticNumeralGroupWidget({
    required this.group,
    required this.color,
    required this.fontSize,
  });

  final KemeticNumeralGroup group;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize.clamp(11.0, 26.0).toDouble();
    final style = TextStyle(
      color: color,
      fontFamily: LibraryVisualTokens.glyphFont,
      fontFamilyFallback: LibraryVisualTokens.glyphFontFallback,
      fontSize: effectiveFontSize,
      height: 0.82,
      letterSpacing: 0,
    );
    final strutStyle = StrutStyle(
      fontFamily: LibraryVisualTokens.glyphFont,
      fontFamilyFallback: LibraryVisualTokens.glyphFontFallback,
      fontSize: effectiveFontSize,
      height: 0.82,
      forceStrutHeight: true,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in group.rows)
            MeduGlyphText(
              row,
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              strutStyle: strutStyle,
              style: style,
            ),
        ],
      ),
    );
  }
}
