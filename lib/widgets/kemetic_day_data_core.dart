part of 'kemetic_day_info.dart';

({int kMonth, int kDay, int decan})? _parseDayKeyForDecan(String dayKey) {
  final parsed = _parseDayKey(dayKey);
  if (parsed == null || parsed.month == 13) return null;

  final parts = dayKey.split('_');
  final explicitDecan = parts.length >= 3 ? int.tryParse(parts[2]) : null;
  final decan = explicitDecan ?? (((parsed.day - 1) ~/ 10) + 1);
  if (decan < 1 || decan > 3) return null;

  return (kMonth: parsed.month, kDay: parsed.day, decan: decan);
}

String? _resolveDecanNameFromKey(String dayKey, {bool expanded = false}) {
  final parsed = _parseDayKeyForDecan(dayKey);
  if (parsed == null) return null;
  return DecanMetadata.decanNameFor(
    kMonth: parsed.kMonth,
    kDay: parsed.kDay,
    expanded: expanded,
  );
}

// Shared flow list for Renwet I (Days 1–10)

MapEntry<String, KemeticDayInfo> _dayInfoEntry({
  required String key,
  required String kemeticDate,
  required String month,
  required String starCluster,
  required String maatPrinciple,
  required String cosmicContext,
  required List<DecanDayInfo> decanFlow,
  required MeduNeterKey meduNeter,
  String season = '🌊 Akhet – Season of Inundation',
  String? decanName,
}) {
  return MapEntry(
    key,
    KemeticDayInfo(
      kemeticDate: kemeticDate,
      season: season,
      month: month,
      decanName: decanName ?? _canonicalDecanName(key),
      starCluster: starCluster,
      maatPrinciple: maatPrinciple,
      cosmicContext: cosmicContext,
      decanFlow: decanFlow,
      meduNeter: meduNeter,
    ),
  );
}

String _canonicalDecanName(String dayKey) {
  const fallbackTitles = {
    'ꜥḥꜣy': 'ꜥḥꜣy ("The Riser")',
    'ḥry-ib ꜥḥꜣy': 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
    'sꜣḥ': 'sꜣḥ ("Sah")',
    'ḥry-ib sꜣḥ': 'ḥry-ib sꜣḥ ("Heart of Sah")',
    'sbꜣ nfr': 'sbꜣ nfr ("The Beautiful Star")',
    'sbꜣ sꜣḥ': 'sbꜣ sꜣḥ ("Star of Sah")',
    'msḥtjw': 'msḥtjw ("The Foreleg")',
    'ḥry-ib msḥtjw': 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
    'sbꜣ msḥtjw': 'sbꜣ msḥtjw ("Star of the Foreleg")',
  };
  final short = _resolveDecanNameFromKey(dayKey);
  if (short == null) return '';
  return fallbackTitles[short] ??
      _resolveDecanNameFromKey(dayKey, expanded: true) ??
      short;
}

List<DecanDayInfo> _buildFlowRows(
  List<({int day, String theme, String action, String reflection})> rows,
) {
  return [
    for (final row in rows)
      DecanDayInfo(
        day: row.day,
        theme: row.theme,
        action: row.action,
        reflection: row.reflection,
      ),
  ];
}

Map<String, KemeticDayInfo> _buildGeneratedDecanEntries({
  required String keyPrefix,
  required int decan,
  required String decanLabel,
  required String monthLabelForDate,
  required String month,
  String season = '🌊 Akhet – Season of Inundation',
  String? decanName,
  String Function(int totalDay, int dayInDecan)? kemeticDateBuilder,
  required List<DecanDayInfo> flowRows,
  required List<
    ({
      int totalDay,
      String starCluster,
      String maatPrinciple,
      String cosmicContext,
      String glyph,
      String colorFrequency,
      String mantra,
    })
  >
  entries,
}) {
  return Map.fromEntries(
    entries.map((entry) {
      final dayInDecan = entry.totalDay - ((decan - 1) * 10);
      return _dayInfoEntry(
        key: '${keyPrefix}_${entry.totalDay}_$decan',
        kemeticDate:
            kemeticDateBuilder?.call(entry.totalDay, dayInDecan) ??
            '$decanLabel, Day ${entry.totalDay}',
        season: season,
        month: month,
        decanName: decanName,
        starCluster: entry.starCluster,
        maatPrinciple: entry.maatPrinciple,
        cosmicContext: entry.cosmicContext,
        decanFlow: flowRows,
        meduNeter: MeduNeterKey(
          glyph: entry.glyph,
          colorFrequency: entry.colorFrequency,
          mantra: entry.mantra,
        ),
      );
    }),
  );
}

KemeticDayInfo? _getInfoForDay(String dayKey) {
  final direct = _dayInfoMap[dayKey];
  if (direct != null) return direct;

  final parsed = _parseDayKey(dayKey);
  if (parsed == null || parsed.month != 13) return null;

  return _dayInfoMap['epagomenal_${parsed.day}_1'];
}

/// Month key override map.
/// IMPORTANT: Keep in sync with the override map in day_key.dart.

const Map<int, String> _monthKeyOverride = {
  2: 'paophi',
  5: 'sefbedet',
  10: 'henti',
  11: 'ipt',
  12: 'mswtRa',
};

/// Parses a dayKey to extract (month, day, year?).
/// Handles:
/// - "epagomenal_1_1"
/// - "epagomenal_1_2026"
/// - `<monthKey>_<day>_<decan>`

({int month, int day, int? year})? _parseDayKey(String dayKey) {
  // Epagomenal days
  if (dayKey.startsWith('epagomenal_')) {
    final parts = dayKey.split('_'); // epagomenal, <day>, [year]
    if (parts.length >= 2) {
      final day = int.tryParse(parts[1]);
      if (day != null && day >= 1 && day <= 6) {
        final int? yearFromKey = parts.length >= 3
            ? int.tryParse(parts[2])
            : null;
        return (month: 13, day: day, year: yearFromKey);
      }
    }
    return null;
  }

  // Regular format: "<monthKey>_<day>_<decan>"
  final parts = dayKey.split('_');
  if (parts.length < 2) return null;

  final monthKey = parts[0];
  final dayStr = parts[1];
  final day = int.tryParse(dayStr);
  if (day == null || day < 1 || day > 30) return null;

  // Reverse lookup month ID from monthKey
  // First check override map
  final overrideEntry = _monthKeyOverride.entries.firstWhere(
    (e) => e.value == monthKey,
    orElse: () => const MapEntry(0, ''),
  );
  if (overrideEntry.key != 0) {
    return (month: overrideEntry.key, day: day, year: null);
  }

  // Then fall back to "real" month metadata
  for (int monthId = 1; monthId <= 12; monthId++) {
    final month = getMonthById(monthId);
    if (month.key == monthKey) {
      return (month: monthId, day: day, year: null);
    }
  }

  return null;
}

/// Calculates the Gregorian date label for a given dayKey.
///
/// - Uses year embedded in the key if present (epagomenal_1_2026),
///   otherwise falls back to [kYearParam], otherwise 1.
/// - Handles leap years via KemeticMath.toGregorian().
/// - Treats the result as a pure calendar date (no local timezone shifting).

String _calculateGregorianDate(String dayKey, {int? kYearParam}) {
  final parsed = _parseDayKey(dayKey);
  if (parsed == null) {
    return 'Unknown Date';
  }

  final int kMonth = parsed.month;
  final int kDay = parsed.day;

  // Choose a year: from key → from param → default 1
  final int kYear = (parsed.year ?? kYearParam ?? 1);
  if (kYear < 1) {
    return 'Invalid Year';
  }

  // Validate day ranges
  if (kMonth == 13) {
    // Epagomenal month
    final maxEpi = KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;
    if (kDay < 1 || kDay > maxEpi) {
      return 'Invalid Epagomenal Day';
    }
  } else {
    // Regular months
    if (kDay < 1 || kDay > 30) {
      return 'Invalid Day';
    }
  }

  try {
    // This returns a UTC DateTime corresponding to the Kemetic date.
    final DateTime gregorianUtc = KemeticMath.toGregorian(kYear, kMonth, kDay);

    // 🔑 KEY FIX:
    // For day cards, we only care about the calendar date,
    // not the local-time shift. Strip the time/zone.
    final DateTime dateOnly = DateTime(
      gregorianUtc.year,
      gregorianUtc.month,
      gregorianUtc.day,
    );

    return _formatGregorianDateString(dateOnly);
  } catch (_) {
    return 'Date Calculation Error';
  }
}

/// Formats a DateTime as "Month Day, Year" (e.g., "March 20, 2025").

String _formatGregorianDateString(DateTime date) {
  const monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
}
