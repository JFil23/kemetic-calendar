part of 'calendar_page.dart';

class _MyFlowCardDisplaySpec {
  const _MyFlowCardDisplaySpec({
    required this.name,
    required this.dateRange,
    required this.flowColor,
    required this.completedCount,
    required this.totalCount,
    required this.categoryLabel,
    required this.maatKind,
    required this.maatPalette,
  });

  final String name;
  final String dateRange;
  final Color flowColor;
  final int completedCount;
  final int totalCount;
  final String? categoryLabel;
  final MaatFlowKind? maatKind;
  final MaatFlowPalette? maatPalette;

  bool get isMaatFlow => maatKind != null && maatPalette != null;

  static _MyFlowCardDisplaySpec fromFlow({
    required _Flow flow,
    required _MyFlowsFilingSnapshot snapshot,
  }) {
    final kind = resolveMaatFlowKind(
      flowName: flow.name,
      flowNotes: flow.notes,
    );
    final maatPalette = kind == null
        ? null
        : MaatFlowPalette.resolve(flowId: kind.flowKey, accent: flow.color);
    final total = snapshot.totalEventCounts[flow.id] ?? 0;
    final remaining = snapshot.remainingEventCounts[flow.id] ?? 0;
    final completed = math.max(0, math.min(total, total - remaining));

    return _MyFlowCardDisplaySpec(
      name: flow.name,
      dateRange: _formatMyFlowDateRange(flow.start, flow.end),
      flowColor: flow.color,
      completedCount: completed,
      totalCount: total,
      categoryLabel: kind == null
          ? null
          : _resolveMyFlowMaatCategoryLabel(kind),
      maatKind: kind,
      maatPalette: maatPalette,
    );
  }
}

class _MyFlowCardPalette {
  const _MyFlowCardPalette({
    required this.accent,
    required this.cardBase,
    required this.leftWash,
    required this.cardBorder,
    required this.categoryColor,
    required this.nameColor,
    required this.iconBg,
    required this.iconBorder,
    required this.iconColor,
    required this.progressColor,
    required this.chevronColor,
  });

  final Color accent;
  final Color cardBase;
  final Color leftWash;
  final Color cardBorder;
  final Color categoryColor;
  final Color nameColor;
  final Color iconBg;
  final Color iconBorder;
  final Color iconColor;
  final Color progressColor;
  final Color chevronColor;

  static const Color _pageBlack = Color(0xFF030303);
  static const Color _warmIvory = Color(0xFFE8D6A8);
  static const Color _warmGoldInfluence = Color(0xFFE0C076);

  factory _MyFlowCardPalette.fromColor(Color flowColor) {
    final hsl = HSLColor.fromColor(flowColor);
    final muted = hsl
        .withSaturation(math.min(hsl.saturation * 0.55, 0.52))
        .withLightness(0.58)
        .toColor();
    final softenedAccent = Color.lerp(muted, _warmGoldInfluence, 0.08) ?? muted;
    final lowSaturation = hsl.saturation < 0.20;

    return _MyFlowCardPalette(
      accent: softenedAccent,
      cardBase: Color.alphaBlend(
        softenedAccent.withValues(alpha: lowSaturation ? 0.12 : 0.09),
        _pageBlack,
      ),
      leftWash: softenedAccent.withValues(alpha: lowSaturation ? 0.13 : 0.11),
      cardBorder: softenedAccent.withValues(alpha: 0.16),
      categoryColor: softenedAccent.withValues(alpha: 0.68),
      nameColor: Color.lerp(softenedAccent, _warmIvory, 0.10) ?? softenedAccent,
      iconBg: Color.alphaBlend(
        softenedAccent.withValues(alpha: 0.11),
        _pageBlack,
      ),
      iconBorder: softenedAccent.withValues(alpha: 0.24),
      iconColor: Color.lerp(softenedAccent, _warmIvory, 0.16) ?? softenedAccent,
      progressColor: softenedAccent.withValues(alpha: 0.72),
      chevronColor: softenedAccent.withValues(alpha: 0.55),
    );
  }
}

String _formatMyFlowDateRange(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  if (start == null) return '\u2014 \u2192 ${_formatMyFlowDate(end!)}';
  if (end == null) return '${_formatMyFlowDate(start)} \u2192 \u2014';
  if (_isMonthRange(start, end)) {
    return '${_monthNames[start.month - 1]} ${start.year} \u2192 '
        '${_monthNames[end.month - 1]} ${end.year}';
  }
  if (start.year == end.year) {
    return '${_monthNames[start.month - 1]} ${start.day} \u2192 '
        '${_monthNames[end.month - 1]} ${end.day}, ${end.year}';
  }
  return '${_formatMyFlowDate(start)} \u2192 ${_formatMyFlowDate(end)}';
}

String _formatMyFlowDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

bool _isMonthRange(DateTime start, DateTime end) {
  if (start.day != 1 || end.day != 1) return false;
  final monthSpan = (end.year - start.year) * 12 + end.month - start.month;
  return monthSpan >= 3;
}

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String? _resolveMyFlowMaatCategoryLabel(MaatFlowKind kind) {
  final template = _myFlowMaatTemplateFor(kind);
  if (template == null) return null;
  final category = _MaatFlowSubtitleParts.parse(
    template.subtitle,
  ).category.trim();
  return category.isEmpty ? null : category;
}

_MaatFlowTemplate? _myFlowMaatTemplateFor(MaatFlowKind kind) {
  final flowKey = kind.flowKey;
  for (final template in _kMaatFlowTemplates) {
    if (template.key == flowKey) return template;
  }
  return null;
}
