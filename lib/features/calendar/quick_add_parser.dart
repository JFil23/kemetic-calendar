part of 'calendar_page.dart';

class _QuickAddSpan {
  const _QuickAddSpan(this.start, this.end);

  final int start;
  final int end;

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && otherEnd > start;
}

class _KemeticMonthToken {
  const _KemeticMonthToken({required this.pattern, required this.monthId});

  final RegExp pattern;
  final int monthId;
}

final List<_KemeticMonthToken> _kemeticMonthTokens = _buildKemeticMonthTokens();

List<_KemeticMonthToken> _buildKemeticMonthTokens() {
  final tokens = <_KemeticMonthToken>[];
  final seen = <String>{};

  for (final month in kKemeticMonths.skip(1)) {
    final names = <String>{
      month.displayShort,
      month.displayTransliteration,
      month.transliterationFull,
      month.hellenized,
      month.key,
      ...month.searchAliases,
    };
    for (final name in names) {
      final trimmed = name.trim();
      if (trimmed.length < 3) continue;
      final key = normalizeForMatch(trimmed);
      if (key.isEmpty || !seen.add('$key:${month.id}')) continue;
      tokens.add(
        _KemeticMonthToken(
          pattern: RegExp(_monthTokenPattern(trimmed), caseSensitive: false),
          monthId: month.id,
        ),
      );
    }
  }

  tokens.sort((a, b) {
    final lengthCmp = b.pattern.pattern.length.compareTo(
      a.pattern.pattern.length,
    );
    return lengthCmp != 0 ? lengthCmp : a.monthId.compareTo(b.monthId);
  });
  return tokens;
}

String _monthTokenPattern(String name) {
  final escaped = RegExp.escape(name.trim())
      .replaceAll(r'\-', r'[-_\s]*')
      .replaceAll('-', r'[-_\s]*')
      .replaceAll(r'\ ', r'[-_\s]*')
      .replaceAll(' ', r'[-_\s]*');
  return '(?<![A-Za-z0-9])$escaped(?![A-Za-z0-9])';
}

int _toQuickAddHour(int hour, String? meridian) {
  if (meridian == null) return hour;
  final lower = meridian.toLowerCase().replaceAll('.', '');
  if (lower == 'am') return hour == 12 ? 0 : hour;
  return hour == 12 ? 12 : hour + 12;
}

bool _isValidTimeOfDay(int hour, int minute) =>
    hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;

class _QuickAddParser {
  _QuickAddParser(this.raw, this.now);

  final String raw;
  final DateTime now;
  final List<_QuickAddSpan> _claimed = <_QuickAddSpan>[];

  QuickAddParse? parse() {
    final input = raw.trim();
    if (input.isEmpty) return null;

    DateTime date = DateUtils.dateOnly(now);
    var rollGregorianYearIfPast = false;
    TimeOfDay? start;
    TimeOfDay? end;
    String? location;

    final numericDate = _claimGregorianNumericDate(input);
    if (numericDate != null) {
      date = numericDate;
      rollGregorianYearIfPast = true;
    } else {
      final namedDate = _claimGregorianNamedDate(input);
      if (namedDate != null) {
        date = namedDate;
        rollGregorianYearIfPast = true;
      } else {
        final kemeticDate = _claimKemeticDate(input);
        if (kemeticDate != null) {
          date = kemeticDate;
        } else {
          final relativeDate = _claimRelativeDate(input);
          if (relativeDate != null) {
            date = relativeDate;
          }
        }
      }
    }

    if (rollGregorianYearIfPast && date.isBefore(DateUtils.dateOnly(now))) {
      date = DateUtils.dateOnly(DateTime(date.year + 1, date.month, date.day));
    }

    final range = _claimTimeRange(input);
    if (range != null) {
      start = range.$1;
      end = range.$2;
    } else {
      start = _claimSingleTime(input);
      if (start != null) {
        end = TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);
      }
    }

    final durationHours = _claimDurationHours(input);
    if (durationHours != null && start != null && range == null) {
      end = TimeOfDay(
        hour: (start.hour + durationHours) % 24,
        minute: start.minute,
      );
    }

    location = _claimLocation(input);

    final title = _titleFromSpans(input);
    return (
      date: date,
      allDay: start == null,
      start: start,
      end: start == null ? null : end,
      title: title.isEmpty ? input : title,
      location: location,
    );
  }

  bool _isFree(int start, int end) =>
      !_claimed.any((span) => span.overlaps(start, end));

  void _claim(int start, int end) {
    if (start < end) _claimed.add(_QuickAddSpan(start, end));
  }

  Match? _firstFreeMatch(RegExp pattern, String input) {
    for (final match in pattern.allMatches(input)) {
      if (_isFree(match.start, match.end)) return match;
    }
    return null;
  }

  int _leadingGlueLength(String input, int start, List<String> glues) {
    if (start == 0) return 0;
    final before = input.substring(0, start);
    for (final glue in glues) {
      final pattern = RegExp(
        '${RegExp.escape(glue)}\\s+\$',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(before);
      if (match != null && _isFree(match.start, start)) {
        return start - match.start;
      }
    }
    return 0;
  }

  DateTime? _claimGregorianNumericDate(String input) {
    final match = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![A-Za-z0-9])',
      ),
      input,
    );
    if (match == null) return null;
    var month = int.parse(match.group(1)!);
    var day = int.parse(match.group(2)!);
    var year = match.group(3) != null ? int.parse(match.group(3)!) : now.year;
    if (year < 100) year += 2000;
    final glue = _leadingGlueLength(input, match.start, const ['on']);
    _claim(match.start - glue, match.end);
    return DateUtils.dateOnly(DateTime(year, month, day));
  }

  DateTime? _claimGregorianNamedDate(String input) {
    const months = <String, int>{
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
    final match = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sept|sep|october|oct|november|nov|december|dec)\.?\s+(\d{1,2})(?:,\s*(\d{2,4}))?(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (match == null) return null;
    final key = match.group(1)!.toLowerCase().replaceAll('.', '');
    final prefix = key.length >= 3 ? key.substring(0, 3) : key;
    final month = months[key] ?? months[prefix];
    if (month == null) return null;
    final day = int.parse(match.group(2)!);
    var year = match.group(3) != null ? int.parse(match.group(3)!) : now.year;
    if (year < 100) year += 2000;
    final glue = _leadingGlueLength(input, match.start, const ['on']);
    _claim(match.start - glue, match.end);
    return DateUtils.dateOnly(DateTime(year, month, day));
  }

  DateTime? _claimKemeticDate(String input) {
    Match? bestMatch;
    var bestMonthId = 0;
    for (final token in _kemeticMonthTokens) {
      final pattern = RegExp(
        '${token.pattern.pattern}\\s+(\\d{1,2})(?![A-Za-z0-9])',
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(input)) {
        if (!_isFree(match.start, match.end)) continue;
        final day = int.parse(match.group(1)!);
        if (!_kemeticDayIsPlausible(token.monthId, day)) continue;
        if (bestMatch == null ||
            match.start < bestMatch.start ||
            (match.start == bestMatch.start && match.end > bestMatch.end)) {
          bestMatch = match;
          bestMonthId = token.monthId;
        }
      }
    }
    if (bestMatch == null) return null;
    final day = int.parse(bestMatch.group(1)!);
    final resolved = _gregorianFromKemeticMonthDay(bestMonthId, day);
    if (resolved == null) return null;
    final glue = _leadingGlueLength(input, bestMatch.start, const ['on']);
    _claim(bestMatch.start - glue, bestMatch.end);
    return resolved;
  }

  bool _kemeticDayIsPlausible(int monthId, int day) {
    if (day < 1) return false;
    if (monthId == 13) return day <= 6;
    return day <= 30;
  }

  DateTime? _gregorianFromKemeticMonthDay(int monthId, int day) {
    final current = KemeticMath.fromGregorian(now);
    for (var offset = 0; offset <= 4; offset++) {
      final year = current.kYear + offset;
      try {
        final utc = KemeticMath.toGregorian(year, monthId, day);
        final local = DateUtils.dateOnly(
          DateTime(utc.year, utc.month, utc.day),
        );
        if (!local.isBefore(DateUtils.dateOnly(now)) || offset > 0) {
          return local;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  DateTime? _claimRelativeDate(String input) {
    final todayOrTomorrow = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(today|tomorrow)(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (todayOrTomorrow != null) {
      final glue = _leadingGlueLength(input, todayOrTomorrow.start, const [
        'on',
      ]);
      _claim(todayOrTomorrow.start - glue, todayOrTomorrow.end);
      if (todayOrTomorrow.group(1)!.toLowerCase() == 'tomorrow') {
        return DateUtils.dateOnly(now.add(const Duration(days: 1)));
      }
      return DateUtils.dateOnly(now);
    }

    final inDays = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])in\s+(\d+)\s+days?(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (inDays != null) {
      _claim(inDays.start, inDays.end);
      return DateUtils.dateOnly(
        now.add(Duration(days: int.parse(inDays.group(1)!))),
      );
    }

    const weekdays = <String, int>{
      'monday': DateTime.monday,
      'mon': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'tues': DateTime.tuesday,
      'tue': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'wed': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'thurs': DateTime.thursday,
      'thur': DateTime.thursday,
      'thu': DateTime.thursday,
      'friday': DateTime.friday,
      'fri': DateTime.friday,
      'saturday': DateTime.saturday,
      'sat': DateTime.saturday,
      'sunday': DateTime.sunday,
      'sun': DateTime.sunday,
    };
    final weekdayMatch = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(?:next\s+)?(monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thur|thu|friday|fri|saturday|sat|sunday|sun)(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (weekdayMatch == null) return null;
    final weekday = weekdays[weekdayMatch.group(1)!.toLowerCase()];
    if (weekday == null) return null;
    final glue = _leadingGlueLength(input, weekdayMatch.start, const ['on']);
    _claim(weekdayMatch.start - glue, weekdayMatch.end);
    return CalendarPage._nextWeekdayForQuickAdd(now, weekday);
  }

  (TimeOfDay, TimeOfDay)? _claimTimeRange(String input) {
    final match = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(?:from\s+|between\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\s*(?:-|–|to)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (match == null) return null;
    final start = _timeFromMatch(
      hour: match.group(1)!,
      minute: match.group(2),
      meridian: match.group(3),
    );
    final end = _timeFromMatch(
      hour: match.group(4)!,
      minute: match.group(5),
      meridian: match.group(6) ?? match.group(3),
    );
    if (start == null || end == null) return null;
    _claim(match.start, match.end);
    return (start, end);
  }

  TimeOfDay? _claimSingleTime(String input) {
    final named = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(?:at\s+)?(noon|midnight)(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (named != null) {
      _claim(named.start, named.end);
      return named.group(1)!.toLowerCase() == 'midnight'
          ? const TimeOfDay(hour: 0, minute: 0)
          : const TimeOfDay(hour: 12, minute: 0);
    }

    final meridiem = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (meridiem != null) {
      final time = _timeFromMatch(
        hour: meridiem.group(1)!,
        minute: meridiem.group(2),
        meridian: meridiem.group(3),
      );
      if (time != null) {
        _claim(meridiem.start, meridiem.end);
        return time;
      }
    }

    final atHour = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])at\s+(\d{1,2})(?::(\d{2}))?(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (atHour != null) {
      final time = _timeFromMatch(
        hour: atHour.group(1)!,
        minute: atHour.group(2),
        meridian: null,
      );
      if (time != null) {
        _claim(atHour.start, atHour.end);
        return time;
      }
    }

    final clock = _firstFreeMatch(
      RegExp(r'(?<![A-Za-z0-9])(\d{1,2}):(\d{2})(?![A-Za-z0-9])'),
      input,
    );
    if (clock != null) {
      final time = _timeFromMatch(
        hour: clock.group(1)!,
        minute: clock.group(2),
        meridian: null,
      );
      if (time != null) {
        _claim(clock.start, clock.end);
        return time;
      }
    }

    final bare = _firstFreeMatch(
      RegExp(r'(?<![A-Za-z0-9])(\d{1,2})(?![A-Za-z0-9])'),
      input,
    );
    if (bare == null) return null;
    final time = _timeFromMatch(
      hour: bare.group(1)!,
      minute: null,
      meridian: null,
    );
    if (time == null) return null;
    _claim(bare.start, bare.end);
    return time;
  }

  TimeOfDay? _timeFromMatch({
    required String hour,
    String? minute,
    String? meridian,
  }) {
    final parsedHour = int.parse(hour);
    final parsedMinute = minute == null ? 0 : int.parse(minute);
    final converted = _toQuickAddHour(parsedHour, meridian);
    if (!_isValidTimeOfDay(converted, parsedMinute)) return null;
    return TimeOfDay(hour: converted, minute: parsedMinute);
  }

  int? _claimDurationHours(String input) {
    final match = _firstFreeMatch(
      RegExp(
        r'(?<![A-Za-z0-9])for\s+(an\s+hour|a\s+hour|one\s+hour|\d+\s+hours?)(?![A-Za-z0-9])',
        caseSensitive: false,
      ),
      input,
    );
    if (match == null) return null;
    final body = match.group(1)!.toLowerCase();
    final numeric = RegExp(r'^(\d+)').firstMatch(body);
    final hours = numeric == null ? 1 : int.parse(numeric.group(1)!);
    if (hours <= 0) return null;
    _claim(match.start, match.end);
    return hours;
  }

  String? _claimLocation(String input) {
    final glue = RegExp(r'(?<![A-Za-z0-9])(in|at)\s+');
    final properNoun = RegExp(
      r'[A-Z][A-Za-z0-9\x27-]*(?:\s+[A-Z][A-Za-z0-9\x27-]*)*',
    );
    var chosenStart = -1;
    var chosenEnd = -1;
    String? chosenName;
    for (final match in glue.allMatches(input)) {
      final name = properNoun.matchAsPrefix(input, match.end);
      if (name == null || name.group(0)!.isEmpty) continue;
      final start = match.start;
      final end = name.end;
      if (!_isFree(start, end)) continue;
      chosenStart = start;
      chosenEnd = end;
      chosenName = name.group(0)!.trim();
    }
    if (chosenName == null) return null;
    _claim(chosenStart, chosenEnd);
    return chosenName;
  }

  String _titleFromSpans(String input) {
    final spans = [..._claimed]..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final span in spans) {
      if (span.start > cursor) {
        buffer.write(input.substring(cursor, span.start));
      }
      if (span.end > cursor) cursor = span.end;
    }
    if (cursor < input.length) buffer.write(input.substring(cursor));
    return buffer
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,;:]+|[\s,;:]+$'), '')
        .trim();
  }
}
