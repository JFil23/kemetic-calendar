import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;

import 'kemetic_month_metadata.dart';

part 'track_sky_flow_data.g.dart';

enum TrackSkyTimeZone { pacific, mountain, central, eastern }

extension TrackSkyTimeZoneX on TrackSkyTimeZone {
  String get key {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'pacific';
      case TrackSkyTimeZone.mountain:
        return 'mountain';
      case TrackSkyTimeZone.central:
        return 'central';
      case TrackSkyTimeZone.eastern:
        return 'eastern';
    }
  }

  String get label {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'Pacific Time';
      case TrackSkyTimeZone.mountain:
        return 'Mountain Time';
      case TrackSkyTimeZone.central:
        return 'Central Time';
      case TrackSkyTimeZone.eastern:
        return 'Eastern Time';
    }
  }

  String get shortLabel {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'PT';
      case TrackSkyTimeZone.mountain:
        return 'MT';
      case TrackSkyTimeZone.central:
        return 'CT';
      case TrackSkyTimeZone.eastern:
        return 'ET';
    }
  }

  String get ianaName {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'America/Los_Angeles';
      case TrackSkyTimeZone.mountain:
        return 'America/Denver';
      case TrackSkyTimeZone.central:
        return 'America/Chicago';
      case TrackSkyTimeZone.eastern:
        return 'America/New_York';
    }
  }

  String get assetPath => 'assets/ma_at_flows/track_sky_$key.md';
}

class TrackSkyEventSchedule {
  final String dateIso;
  final String? startTime24;
  final String? endTime24;
  final bool allDay;

  const TrackSkyEventSchedule({
    required this.dateIso,
    required this.startTime24,
    required this.endTime24,
    required this.allDay,
  });
}

class TrackSkyEvent {
  final String category;
  final String title;
  final String exactLabel;
  final String scientificBreakdown;
  final String whatToSee;
  final String bestViewing;
  final String significance;
  final String notes;
  final TrackSkyEventSchedule schedule;

  const TrackSkyEvent({
    required this.category,
    required this.title,
    required this.exactLabel,
    required this.scientificBreakdown,
    required this.whatToSee,
    required this.bestViewing,
    required this.significance,
    required this.notes,
    required this.schedule,
  });

  List<String> get detailSegments =>
      <String>[bestViewing, whatToSee, scientificBreakdown, significance, notes]
          .map(_normalizeTrackSkyInlineSegment)
          .where((part) => part.isNotEmpty)
          .toList();

  String get detailSummary => detailSegments.join(' | ');

  String get teaserText {
    for (final value in <String>[bestViewing, whatToSee, scientificBreakdown]) {
      final normalized = _normalizeTrackSkyInlineSegment(value);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  String get detailText {
    return detailSummary;
  }
}

const String _trackSkyMonthTokenPattern =
    r'(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)';

const Set<String> _trackSkySectionHeadings = <String>{
  'Exact Time',
  'Scientific Breakdown',
  "What You'll See & How to Track",
  'Best Viewing Practices',
  'Rarity / Significance / Kemetic Tie',
  'Notes',
};

const Set<String> _trackSkyDistinctHeadings = <String>{
  'Exact Time',
  'Scientific Breakdown',
  "What You'll See & How to Track",
  'Best Viewing Practices',
  'Rarity / Significance / Kemetic Tie',
};

String _normalizeTrackSkyInlineSegment(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeTrackSkyDetailText(String detail) {
  final trimmed = detail.trim();
  if (trimmed.isEmpty) return '';

  final lines = trimmed
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final hasSkyHeadings = lines.any(_trackSkyDistinctHeadings.contains);
  if (!hasSkyHeadings) {
    return trimmed;
  }

  final sections = <String, String>{};
  String? currentHeading;
  final currentBody = <String>[];

  void flushSection() {
    final heading = currentHeading;
    if (heading == null || heading == 'Exact Time') {
      currentBody.clear();
      return;
    }
    final body = _normalizeTrackSkyInlineSegment(currentBody.join(' '));
    if (body.isNotEmpty) {
      sections[heading] = body;
    }
    currentBody.clear();
  }

  for (final line in lines) {
    if (_trackSkySectionHeadings.contains(line)) {
      flushSection();
      currentHeading = line;
      continue;
    }
    if (currentHeading != null) {
      currentBody.add(line);
    }
  }
  flushSection();

  final parts = <String>[
    sections['Best Viewing Practices'] ?? '',
    sections["What You'll See & How to Track"] ?? '',
    sections['Scientific Breakdown'] ?? '',
    sections['Rarity / Significance / Kemetic Tie'] ?? '',
    sections['Notes'] ?? '',
  ].where((part) => part.isNotEmpty).toList();

  if (parts.isEmpty) {
    return trimmed;
  }
  return parts.join(' | ');
}

String kemeticizeTrackSkyText(String text, {DateTime? anchorDate}) {
  var output = text;
  final normalizedAnchor = anchorDate == null
      ? null
      : DateTime(anchorDate.year, anchorDate.month, anchorDate.day);

  output = output.replaceAllMapped(
    RegExp(
      '\\b($_trackSkyMonthTokenPattern)\\s+(\\d{1,2})[–-](\\d{1,2}),\\s*(\\d{4})\\b',
    ),
    (match) {
      final month = _monthToNumber(match.group(1)!);
      final startDay = int.parse(match.group(2)!);
      final endDay = int.parse(match.group(3)!);
      final year = int.parse(match.group(4)!);
      final start = DateTime(year, month, startDay);
      final end = DateTime(year, month, endDay);
      return '${_kemeticLabelForDate(start)} – ${_kemeticLabelForDate(end)}';
    },
  );

  output = output.replaceAllMapped(
    RegExp('\\b($_trackSkyMonthTokenPattern)\\s+(\\d{1,2}),\\s*(\\d{4})\\b'),
    (match) {
      final month = _monthToNumber(match.group(1)!);
      final day = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      return _kemeticLabelForDate(DateTime(year, month, day));
    },
  );

  if (normalizedAnchor != null) {
    output = output.replaceAllMapped(
      RegExp('\\b($_trackSkyMonthTokenPattern)\\s+(\\d{1,2})[–-](\\d{1,2})\\b'),
      (match) {
        final month = _monthToNumber(match.group(1)!);
        final startDay = int.parse(match.group(2)!);
        final endDay = int.parse(match.group(3)!);
        final start = _closestDateForMonthDay(
          month: month,
          day: startDay,
          anchorDate: normalizedAnchor,
        );
        final end = _closestDateForMonthDay(
          month: month,
          day: endDay,
          anchorDate: start,
        );
        return '${_kemeticLabelForDate(start)} – ${_kemeticLabelForDate(end)}';
      },
    );

    output = output.replaceAllMapped(
      RegExp('\\b($_trackSkyMonthTokenPattern)\\s+(\\d{1,2})\\b'),
      (match) {
        final month = _monthToNumber(match.group(1)!);
        final day = int.parse(match.group(2)!);
        final date = _closestDateForMonthDay(
          month: month,
          day: day,
          anchorDate: normalizedAnchor,
        );
        return _kemeticLabelForDate(date);
      },
    );
  }

  return output;
}

DateTime _closestDateForMonthDay({
  required int month,
  required int day,
  required DateTime anchorDate,
}) {
  final candidates = <DateTime>[
    DateTime(anchorDate.year - 1, month, day),
    DateTime(anchorDate.year, month, day),
    DateTime(anchorDate.year + 1, month, day),
  ];
  candidates.sort(
    (a, b) => a
        .difference(anchorDate)
        .abs()
        .compareTo(b.difference(anchorDate).abs()),
  );
  return candidates.first;
}

String _kemeticLabelForDate(DateTime date) {
  final k = KemeticMath.fromGregorian(date);
  final lastDay = (k.kMonth == 13)
      ? (KemeticMath.isLeapKemeticYear(k.kYear) ? 6 : 5)
      : 30;
  final yStart = KemeticMath.toGregorian(k.kYear, k.kMonth, 1).year;
  final yEnd = KemeticMath.toGregorian(k.kYear, k.kMonth, lastDay).year;
  final yLabel = (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  final month = getMonthById(k.kMonth).displayFull;
  return '$month ${k.kDay} • $yLabel';
}

class TrackSkyFlowData {
  final TrackSkyTimeZone timezone;
  final List<TrackSkyEvent> events;

  const TrackSkyFlowData({required this.timezone, required this.events});
}

const List<String> kTrackSkyCategoryOrder = <String>[
  'Solar Events',
  'Lunar Events',
  'Meteor Showers',
  'Planetary Highlights',
];

final Map<TrackSkyTimeZone, Future<TrackSkyFlowData>> _trackSkyFlowCache =
    <TrackSkyTimeZone, Future<TrackSkyFlowData>>{};

bool _trackSkyTimeZonesInitialized = false;

Future<TrackSkyFlowData> loadTrackSkyFlowData(TrackSkyTimeZone timezone) {
  return _trackSkyFlowCache.putIfAbsent(timezone, () {
    return () async {
      try {
        return await _loadTrackSkyFlowDataUncached(timezone);
      } catch (error, stackTrace) {
        _trackSkyFlowCache.remove(timezone);
        if (kDebugMode) {
          debugPrint('[trackSky] Failed to load ${timezone.assetPath}: $error');
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }();
  });
}

void clearTrackSkyFlowCache([TrackSkyTimeZone? timezone]) {
  if (timezone == null) {
    _trackSkyFlowCache.clear();
    return;
  }
  _trackSkyFlowCache.remove(timezone);
}

Future<TrackSkyFlowData> _loadTrackSkyFlowDataUncached(
  TrackSkyTimeZone timezone,
) async {
  late final String markdown;
  try {
    markdown = await rootBundle.loadString(timezone.assetPath);
  } catch (error) {
    if (kDebugMode) {
      debugPrint(
        '[trackSky] Falling back to embedded markdown for ${timezone.assetPath}: $error',
      );
    }
    markdown = _embeddedTrackSkyMarkdownByTimeZone[timezone]!;
  }
  return _parseTrackSkyMarkdown(timezone, markdown);
}

TrackSkyTimeZone detectTrackSkyTimeZone() {
  final name = DateTime.now().timeZoneName.toUpperCase();
  if (name.contains('PACIFIC') || name == 'PST' || name == 'PDT') {
    return TrackSkyTimeZone.pacific;
  }
  if (name.contains('MOUNTAIN') || name == 'MST' || name == 'MDT') {
    return TrackSkyTimeZone.mountain;
  }
  if (name.contains('CENTRAL') || name == 'CST' || name == 'CDT') {
    return TrackSkyTimeZone.central;
  }
  if (name.contains('EASTERN') || name == 'EST' || name == 'EDT') {
    return TrackSkyTimeZone.eastern;
  }

  switch (DateTime.now().timeZoneOffset.inHours) {
    case -7:
    case -8:
      return TrackSkyTimeZone.pacific;
    case -6:
      return TrackSkyTimeZone.mountain;
    case -5:
      return TrackSkyTimeZone.central;
    case -4:
      return TrackSkyTimeZone.eastern;
    default:
      return TrackSkyTimeZone.pacific;
  }
}

List<TrackSkyEvent> upcomingTrackSkyEvents(
  TrackSkyFlowData data, {
  DateTime? now,
}) {
  return data.events
      .where((event) => isTrackSkyEventUpcoming(event, data.timezone, now: now))
      .toList()
    ..sort(
      (a, b) => _trackSkyEventSortKey(
        a,
        data.timezone,
      ).compareTo(_trackSkyEventSortKey(b, data.timezone)),
    );
}

bool isTrackSkyEventUpcoming(
  TrackSkyEvent event,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = _nowInZone(timezone, now: now);
  final endLocal = trackSkyEventEndLocal(event, timezone);
  return !endLocal.isBefore(nowLocal);
}

DateTime trackSkyEventStartLocal(
  TrackSkyEvent event,
  TrackSkyTimeZone timezone,
) {
  final start = event.schedule.startTime24 ?? '09:00';
  return _fromZonedDateTime(
    _zonedDateTimeInZone(timezone, event.schedule.dateIso, start),
  );
}

DateTime trackSkyEventEndLocal(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  if (event.schedule.allDay) {
    return _fromZonedDateTime(
      _zonedDateTimeInZone(timezone, event.schedule.dateIso, '23:59'),
    );
  }
  final end = event.schedule.endTime24 ?? event.schedule.startTime24 ?? '09:00';
  return _fromZonedDateTime(
    _zonedDateTimeInZone(timezone, event.schedule.dateIso, end),
  );
}

DateTime trackSkyEventStartUtc(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  final start = event.schedule.startTime24 ?? '09:00';
  return _zonedDateTimeInZone(timezone, event.schedule.dateIso, start).toUtc();
}

DateTime? trackSkyEventEndUtc(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  if (event.schedule.allDay) return null;
  final end = event.schedule.endTime24 ?? event.schedule.startTime24 ?? '09:00';
  return _zonedDateTimeInZone(timezone, event.schedule.dateIso, end).toUtc();
}

DateTime _trackSkyEventSortKey(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  return trackSkyEventStartLocal(event, timezone);
}

TrackSkyFlowData _parseTrackSkyMarkdown(
  TrackSkyTimeZone timezone,
  String markdown,
) {
  final events = <TrackSkyEvent>[];
  String? currentCategory;

  for (final rawLine in markdown.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('## 1. Solar Events')) {
      currentCategory = 'Solar Events';
      continue;
    }
    if (line.startsWith('## Lunar Events')) {
      currentCategory = 'Lunar Events';
      continue;
    }
    if (line.startsWith('## Meteor Showers')) {
      currentCategory = 'Meteor Showers';
      continue;
    }
    if (line.startsWith('## Planetary Highlights')) {
      currentCategory = 'Planetary Highlights';
      continue;
    }
    if (currentCategory == null ||
        !line.startsWith('|') ||
        line.startsWith('|---')) {
      continue;
    }

    final cells = line
        .substring(1, line.length - 1)
        .split('|')
        .map((cell) => cell.trim())
        .toList();
    if (cells.isEmpty || cells.first == 'Event' || cells.length < 7) {
      continue;
    }

    final schedule = _deriveSchedule(currentCategory, cells[1]);
    if (schedule == null) continue;
    final anchorDate = DateTime.parse(schedule.dateIso);

    events.add(
      TrackSkyEvent(
        category: currentCategory,
        title: cells[0],
        exactLabel: kemeticizeTrackSkyText(cells[1], anchorDate: anchorDate),
        scientificBreakdown: kemeticizeTrackSkyText(
          cells[2],
          anchorDate: anchorDate,
        ),
        whatToSee: kemeticizeTrackSkyText(cells[3], anchorDate: anchorDate),
        bestViewing: kemeticizeTrackSkyText(cells[4], anchorDate: anchorDate),
        significance: kemeticizeTrackSkyText(cells[5], anchorDate: anchorDate),
        notes: kemeticizeTrackSkyText(cells[6], anchorDate: anchorDate),
        schedule: schedule,
      ),
    );
  }

  return TrackSkyFlowData(timezone: timezone, events: events);
}

TrackSkyEventSchedule? _deriveSchedule(String category, String exactLabel) {
  final normalized = exactLabel.toLowerCase();
  if (normalized.contains('not visible')) {
    return null;
  }

  switch (category) {
    case 'Solar Events':
    case 'Lunar Events':
      return _deriveSolarOrLunarSchedule(exactLabel);
    case 'Meteor Showers':
      return _deriveMeteorSchedule(exactLabel);
    case 'Planetary Highlights':
      return _derivePlanetarySchedule(exactLabel);
    default:
      return null;
  }
}

TrackSkyEventSchedule? _deriveSolarOrLunarSchedule(String exactLabel) {
  final totalityMatch = RegExp(
    r'totality (\d{1,2}:\d{2}) (AM|PM) [A-Z]{2,5}–(\d{1,2}:\d{2}) (AM|PM)',
  ).firstMatch(exactLabel);
  final baseDate = _extractFirstDate(exactLabel);
  if (baseDate == null) return null;

  if (totalityMatch != null) {
    return TrackSkyEventSchedule(
      dateIso: baseDate,
      startTime24: _to24(totalityMatch.group(1)!, totalityMatch.group(2)!),
      endTime24: _to24(totalityMatch.group(3)!, totalityMatch.group(4)!),
      allDay: false,
    );
  }

  final roughWindowMatch = RegExp(
    r'roughly (?:[A-Z][a-z]+ \d{1,2}, \d{4}, )?(\d{1,2}:\d{2}) (AM|PM) [A-Z]{2,5}–(?:[A-Z][a-z]+ \d{1,2}, \d{4}, )?(\d{1,2}:\d{2}) (AM|PM)',
  ).firstMatch(exactLabel);
  if (roughWindowMatch != null) {
    final start = _to24(roughWindowMatch.group(1)!, roughWindowMatch.group(2)!);
    var end = _to24(roughWindowMatch.group(3)!, roughWindowMatch.group(4)!);
    if (_time24ToMinutes(end) <= _time24ToMinutes(start)) {
      end = '23:59';
    }
    return TrackSkyEventSchedule(
      dateIso: baseDate,
      startTime24: start,
      endTime24: end,
      allDay: false,
    );
  }

  final exactTimeMatch = RegExp(
    r'^([A-Z][a-z]+) \d{1,2}, \d{4}, (\d{1,2}:\d{2}) (AM|PM)',
  ).firstMatch(exactLabel);
  if (exactTimeMatch != null) {
    final start = _to24(exactTimeMatch.group(2)!, exactTimeMatch.group(3)!);
    return TrackSkyEventSchedule(
      dateIso: baseDate,
      startTime24: start,
      endTime24: _oneHourAfter(start),
      allDay: false,
    );
  }

  return TrackSkyEventSchedule(
    dateIso: baseDate,
    startTime24: null,
    endTime24: null,
    allDay: true,
  );
}

TrackSkyEventSchedule? _deriveMeteorSchedule(String exactLabel) {
  final preDawnDate =
      _extractPreDawnDate(exactLabel) ?? _extractFirstDate(exactLabel);
  if (preDawnDate == null) return null;

  final normalized = exactLabel.toLowerCase();
  if (normalized.contains('pre-dawn') &&
      !normalized.contains('after midnight') &&
      !normalized.contains('night of')) {
    return TrackSkyEventSchedule(
      dateIso: preDawnDate,
      startTime24: '04:00',
      endTime24: '05:30',
      allDay: false,
    );
  }

  return TrackSkyEventSchedule(
    dateIso: preDawnDate,
    startTime24: '00:00',
    endTime24: '05:00',
    allDay: false,
  );
}

TrackSkyEventSchedule? _derivePlanetarySchedule(String exactLabel) {
  final baseDate = _extractFirstDate(exactLabel);
  if (baseDate == null) return null;

  final normalized = exactLabel.toLowerCase();
  if (normalized.contains('after local sunset') ||
      normalized.contains('after sunset') ||
      normalized.contains('best visible before sunrise') ||
      normalized.contains('before sunrise mid-march')) {
    return TrackSkyEventSchedule(
      dateIso: baseDate,
      startTime24: null,
      endTime24: null,
      allDay: true,
    );
  }

  final allNightMatch = RegExp(
    r'exact [^~]*~(\d{1,2}:\d{2}) (AM|PM)',
  ).firstMatch(exactLabel);
  if (normalized.contains('all night') && allNightMatch != null) {
    final start = _to24(allNightMatch.group(1)!, allNightMatch.group(2)!);
    return TrackSkyEventSchedule(
      dateIso: baseDate,
      startTime24: start,
      endTime24: _oneHourAfter(start),
      allDay: false,
    );
  }

  final exactTimeMatch = RegExp(
    r'^([A-Z][a-z]+) \d{1,2}, \d{4}, (\d{1,2}:\d{2}) (AM|PM)',
  ).firstMatch(exactLabel);
  if (exactTimeMatch != null) {
    final start = _to24(exactTimeMatch.group(2)!, exactTimeMatch.group(3)!);
    if (normalized.contains('best visible before sunrise') &&
        _time24ToMinutes(start) >= _time24ToMinutes('08:00')) {
      return TrackSkyEventSchedule(
        dateIso: baseDate,
        startTime24: null,
        endTime24: null,
        allDay: true,
      );
    }
    return TrackSkyEventSchedule(
      dateIso: baseDate,
      startTime24: start,
      endTime24: _oneHourAfter(start),
      allDay: false,
    );
  }

  return TrackSkyEventSchedule(
    dateIso: baseDate,
    startTime24: null,
    endTime24: null,
    allDay: true,
  );
}

String? _extractFirstDate(String input) {
  final match = RegExp(
    r'([A-Z][a-z]+) (\d{1,2})(?:–\d{1,2})?, (\d{4})',
  ).firstMatch(input);
  if (match == null) return null;
  return _dateIso(match.group(1)!, match.group(2)!, match.group(3)!);
}

String? _extractPreDawnDate(String input) {
  final match = RegExp(
    r'pre-dawn ([A-Z][a-z]+) (\d{1,2}), (\d{4})',
  ).firstMatch(input);
  if (match == null) return null;
  return _dateIso(match.group(1)!, match.group(2)!, match.group(3)!);
}

String _dateIso(String monthToken, String day, String year) {
  final month = _monthToNumber(monthToken);
  return '$year-${month.toString().padLeft(2, '0')}-${int.parse(day).toString().padLeft(2, '0')}';
}

int _monthToNumber(String token) {
  const map = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  final normalized = token.trim().toLowerCase();
  final month = map[normalized];
  if (month == null) {
    throw ArgumentError('Unsupported month token: $token');
  }
  return month;
}

String _to24(String time, String meridiem) {
  final pieces = time.split(':');
  var hour = int.parse(pieces[0]);
  final minute = int.parse(pieces[1]);
  final upper = meridiem.toUpperCase();
  if (upper == 'AM') {
    if (hour == 12) hour = 0;
  } else if (hour != 12) {
    hour += 12;
  }
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _oneHourAfter(String time24) {
  final total = _time24ToMinutes(time24);
  final next = (total + 60).clamp(0, (24 * 60) - 1);
  final hour = next ~/ 60;
  final minute = next % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

int _time24ToMinutes(String time24) {
  final pieces = time24.split(':');
  return (int.parse(pieces[0]) * 60) + int.parse(pieces[1]);
}

DateTime _nowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureTrackSkyTimeZonesInitialized();
  final utcNow = (now ?? DateTime.now()).toUtc();
  final zoned = tz.TZDateTime.from(utcNow, tz.getLocation(timezone.ianaName));
  return _fromZonedDateTime(zoned);
}

tz.TZDateTime _zonedDateTimeInZone(
  TrackSkyTimeZone timezone,
  String dateIso,
  String time24,
) {
  _ensureTrackSkyTimeZonesInitialized();
  final datePieces = dateIso.split('-').map(int.parse).toList();
  final timePieces = time24.split(':').map(int.parse).toList();
  return tz.TZDateTime(
    tz.getLocation(timezone.ianaName),
    datePieces[0],
    datePieces[1],
    datePieces[2],
    timePieces[0],
    timePieces[1],
  );
}

void _ensureTrackSkyTimeZonesInitialized() {
  if (_trackSkyTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _trackSkyTimeZonesInitialized = true;
}

DateTime _fromZonedDateTime(tz.TZDateTime zoned) {
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}
