import 'dart:convert';

import '../../models/ai_flow_generation_response.dart';
import 'flow_prompt_classifier.dart';

class ItineraryContext {
  const ItineraryContext({
    this.hotelName,
    this.hotelAddress,
    this.setupNotes = const [],
    this.setupUrls = const [],
  });

  final String? hotelName;
  final String? hotelAddress;
  final List<String> setupNotes;
  final List<String> setupUrls;
}

class ItineraryEvent {
  const ItineraryEvent({
    required this.date,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.endMarker,
    this.locationName,
    this.address,
    this.urls = const [],
    this.notes = const [],
  });

  final DateTime date;
  final String title;
  final ItineraryClockTime startTime;
  final ItineraryClockTime endTime;
  final String? endMarker;
  final String? locationName;
  final String? address;
  final List<String> urls;
  final List<String> notes;

  ItineraryEvent copyWith({
    String? locationName,
    String? address,
    List<String>? notes,
  }) {
    return ItineraryEvent(
      date: date,
      title: title,
      startTime: startTime,
      endTime: endTime,
      endMarker: endMarker,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      urls: urls,
      notes: notes ?? this.notes,
    );
  }
}

class ItineraryClockTime {
  const ItineraryClockTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  String get hhmm {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  ItineraryClockTime addMinutes(int minutes) {
    final total = hour * 60 + minute + minutes;
    final normalized = total % (24 * 60);
    return ItineraryClockTime(hour: normalized ~/ 60, minute: normalized % 60);
  }
}

class ItineraryDateRange {
  const ItineraryDateRange({
    required this.startDate,
    required this.endDate,
    this.warnings = const [],
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<String> warnings;
}

class ItineraryParseResult {
  const ItineraryParseResult({
    required this.flowTitle,
    required this.startDate,
    required this.endDate,
    required this.context,
    required this.events,
    this.warnings = const [],
  });

  final String flowTitle;
  final DateTime startDate;
  final DateTime endDate;
  final ItineraryContext context;
  final List<ItineraryEvent> events;
  final List<String> warnings;

  AIFlowGenerationResponse toAIFlowGenerationResponse({String? flowColor}) {
    final notesJson = events
        .map((event) {
          final details = <String>[
            if (event.locationName != null &&
                !_titleContainsLocation(event.title, event.locationName!))
              'Location: ${event.locationName}',
            if (event.address != null) 'Address: ${event.address}',
            for (final url in event.urls) 'URL: $url',
            if (event.endMarker != null) 'End: ${event.endMarker}',
            ...event.notes,
          ];
          return <String, dynamic>{
            'day_index': _dateOnly(event.date).difference(startDate).inDays,
            'title': event.title,
            'details': details.join('\n'),
            'all_day': false,
            'start_time': event.startTime.hhmm,
            'end_time': event.endTime.hhmm,
            if (_eventLocation(event) != null)
              'location': _eventLocation(event),
            if (event.locationName != null) 'location_name': event.locationName,
            if (event.address != null) 'address': event.address,
            if (event.urls.isNotEmpty) 'urls': event.urls,
            if (event.endMarker != null) 'end_marker': event.endMarker,
          };
        })
        .toList(growable: false);

    return AIFlowGenerationResponse(
      success: true,
      flowName: flowTitle,
      flowColor: flowColor,
      overviewTitle: null,
      overviewSummary: _buildOverviewSummary(),
      notes: jsonEncode(notesJson),
      notesCount: notesJson.length,
      modelUsed: 'deterministic_itinerary_parser',
      cached: false,
      requestedStartDate: startDate,
      requestedEndDate: endDate,
      aiMetadata: <String, dynamic>{
        'prompt_type': 'itinerarySchedule',
        'deterministic_extraction': true,
        'warnings': warnings,
      },
    );
  }

  String _buildOverviewSummary() {
    final lines = <String>[];
    if (context.hotelName != null || context.hotelAddress != null) {
      lines.add('Hotel:');
      if (context.hotelName != null) lines.add(context.hotelName!);
      if (context.hotelAddress != null) lines.add(context.hotelAddress!);
    }
    if (context.setupNotes.isNotEmpty || context.setupUrls.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Setup:');
      lines.addAll(context.setupNotes.map(_cleanSetupNote));
      lines.addAll(context.setupUrls);
    }
    if (warnings.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Warnings:');
      lines.addAll(warnings);
    }
    return lines.join('\n');
  }

  String _cleanSetupNote(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower.contains('metro') && lower.contains('tap')) {
      return lower.contains('omny') ? 'Metro Tap / OMNY' : 'Metro Tap';
    }
    return trimmed
        .replaceFirst(
          RegExp(
            r'^(?:for\s+)?(?:subway\s+)?(?:travel\s+)?setup\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
}

ItineraryParseResult? parseItineraryPrompt(
  String prompt, {
  DateTime? selectedStartDate,
  DateTime? now,
}) {
  if (!looksLikeItinerarySchedulePrompt(prompt)) return null;

  final lines = _normalizedLines(prompt);
  final headers = _extractDateHeaders(lines);
  if (headers.isEmpty) return null;

  final firstHeaderLine = headers.first.lineIndex;
  final preheader = lines.take(firstHeaderLine).toList(growable: false);
  final context = _extractContext(preheader);
  final title = _extractFlowTitle(preheader);
  final explicitYear = _firstExplicitYear(prompt);
  final warnings = <String>[];
  final resolvedHeaders = <_ResolvedHeader>[];
  DateTime? previousDate;

  for (var i = 0; i < headers.length; i++) {
    final header = headers[i];
    final date = _resolveHeaderDate(
      header,
      selectedStartDate: selectedStartDate,
      now: now,
      previousDate: previousDate,
      explicitYear: header.year ?? explicitYear,
      warnings: warnings,
    );
    if (date == null) continue;
    previousDate = date;
    resolvedHeaders.add(_ResolvedHeader(header: header, date: date));
  }

  if (resolvedHeaders.isEmpty) return null;

  final events = <ItineraryEvent>[];
  var expectedTimeBlocks = 0;
  for (var i = 0; i < resolvedHeaders.length; i++) {
    final resolved = resolvedHeaders[i];
    final startLine = resolved.header.lineIndex + 1;
    final endLine = i + 1 < resolvedHeaders.length
        ? resolvedHeaders[i + 1].header.lineIndex
        : lines.length;
    final sectionLines = lines.sublist(startLine, endLine);
    final parsedDay = _parseDaySection(
      sectionLines,
      date: resolved.date,
      context: context,
    );
    expectedTimeBlocks += parsedDay.timeBlockCount;
    events.addAll(parsedDay.events);
  }

  if (events.isEmpty) return null;

  final adjustedEvents = _copyNearbyAddresses(events);
  adjustedEvents.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byHour = a.startTime.hour.compareTo(b.startTime.hour);
    if (byHour != 0) return byHour;
    return a.startTime.minute.compareTo(b.startTime.minute);
  });

  _validateExtraction(
    lines: lines,
    events: adjustedEvents,
    context: context,
    expectedTimeBlocks: expectedTimeBlocks,
    warnings: warnings,
  );

  final dates = adjustedEvents.map((event) => _dateOnly(event.date)).toList()
    ..sort();
  return ItineraryParseResult(
    flowTitle: title,
    startDate: dates.first,
    endDate: dates.last,
    context: context,
    events: adjustedEvents,
    warnings: warnings,
  );
}

ItineraryDateRange? inferItineraryDateRange(
  String prompt, {
  DateTime? selectedStartDate,
  DateTime? now,
}) {
  if (!looksLikeItinerarySchedulePrompt(prompt)) return null;
  final headers = _extractDateHeaders(_normalizedLines(prompt));
  if (headers.isEmpty) return null;

  final warnings = <String>[];
  final explicitYear = _firstExplicitYear(prompt);
  final dates = <DateTime>[];
  DateTime? previousDate;
  for (final header in headers) {
    final date = _resolveHeaderDate(
      header,
      selectedStartDate: selectedStartDate,
      now: now,
      previousDate: previousDate,
      explicitYear: header.year ?? explicitYear,
      warnings: warnings,
    );
    if (date == null) continue;
    dates.add(_dateOnly(date));
    previousDate = date;
  }
  if (dates.isEmpty) return null;
  dates.sort();
  return ItineraryDateRange(
    startDate: dates.first,
    endDate: dates.last,
    warnings: warnings,
  );
}

DateTime? resolveItineraryDate({
  required String? weekday,
  required int month,
  required int day,
  DateTime? selectedStartDate,
  DateTime? now,
  int? explicitYear,
}) {
  if (explicitYear != null) {
    return _validDate(explicitYear, month, day);
  }

  final weekdayNumber = weekday == null ? null : _weekdayNumber(weekday);
  if (selectedStartDate != null) {
    final selectedYearDate = _validDate(selectedStartDate.year, month, day);
    if (selectedYearDate != null &&
        (weekdayNumber == null || selectedYearDate.weekday == weekdayNumber)) {
      return selectedYearDate;
    }
  }

  final base = _dateOnly(now ?? DateTime.now());
  for (var year = base.year; year <= base.year + 12; year++) {
    final candidate = _validDate(year, month, day);
    if (candidate == null) continue;
    if (weekdayNumber != null && candidate.weekday != weekdayNumber) continue;
    if (!candidate.isBefore(base)) return candidate;
  }

  for (var year = base.year; year <= base.year + 12; year++) {
    final candidate = _validDate(year, month, day);
    if (candidate == null) continue;
    if (weekdayNumber == null || candidate.weekday == weekdayNumber) {
      return candidate;
    }
  }

  return _validDate(selectedStartDate?.year ?? base.year, month, day);
}

List<String> _normalizedLines(String prompt) {
  return normalizeFlowPromptLinesForSchedule(prompt);
}

List<_DateHeader> _extractDateHeaders(List<String> lines) {
  final headers = <_DateHeader>[];
  for (var i = 0; i < lines.length; i++) {
    final header = _parseDateHeader(lines[i], i);
    if (header != null) headers.add(header);
  }
  return headers;
}

_DateHeader? _parseDateHeader(String line, int lineIndex) {
  if (line.length > 96) return null;

  final monthDay = RegExp(
    r'^(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b.*?\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|sept|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:\s*,?\s*(\d{4}))?\b',
    caseSensitive: false,
  ).firstMatch(line);
  if (monthDay != null) {
    return _DateHeader(
      lineIndex: lineIndex,
      raw: line,
      weekday: monthDay.group(1),
      month: _monthNumber(monthDay.group(2)!),
      day: int.tryParse(monthDay.group(3)!),
      year: int.tryParse(monthDay.group(4) ?? ''),
    );
  }

  final slashDate = RegExp(
    r'^(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b.{0,16}\b(\d{1,2})[\/-](\d{1,2})(?:[\/-](\d{2,4}))?\b',
    caseSensitive: false,
  ).firstMatch(line);
  if (slashDate != null) {
    final year = _normalizeYear(slashDate.group(4));
    return _DateHeader(
      lineIndex: lineIndex,
      raw: line,
      weekday: slashDate.group(1),
      month: int.tryParse(slashDate.group(2)!),
      day: int.tryParse(slashDate.group(3)!),
      year: year,
    );
  }

  final dayNumber = RegExp(
    r'^day\s+(\d{1,3})(?:\b|:)',
    caseSensitive: false,
  ).firstMatch(line);
  if (dayNumber != null) {
    return _DateHeader(
      lineIndex: lineIndex,
      raw: line,
      dayNumber: int.tryParse(dayNumber.group(1)!),
    );
  }

  final weekdayOnly = RegExp(
    r'^(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (weekdayOnly != null) {
    return _DateHeader(
      lineIndex: lineIndex,
      raw: line,
      weekday: weekdayOnly.group(1),
    );
  }

  return null;
}

DateTime? _resolveHeaderDate(
  _DateHeader header, {
  required DateTime? selectedStartDate,
  required DateTime? now,
  required DateTime? previousDate,
  required int? explicitYear,
  required List<String> warnings,
}) {
  if (header.month != null && header.day != null) {
    final date = resolveItineraryDate(
      weekday: header.weekday,
      month: header.month!,
      day: header.day!,
      selectedStartDate: selectedStartDate,
      now: now,
      explicitYear: explicitYear,
    );
    if (date == null) {
      warnings.add('Could not resolve date header: ${header.raw}');
      return null;
    }
    final weekdayNumber = header.weekday == null
        ? null
        : _weekdayNumber(header.weekday!);
    if (weekdayNumber != null && date.weekday != weekdayNumber) {
      warnings.add(
        'The weekday and date do not match for ${header.raw}. Review the assigned date.',
      );
    }
    return _dateOnly(date);
  }

  final base = _dateOnly(selectedStartDate ?? now ?? DateTime.now());
  if (header.dayNumber != null) {
    return base.add(Duration(days: header.dayNumber! - 1));
  }

  final weekdayNumber = header.weekday == null
      ? null
      : _weekdayNumber(header.weekday!);
  if (weekdayNumber != null) {
    return _nextWeekdayDate(weekdayNumber, previousDate ?? base);
  }

  warnings.add('Could not resolve date header: ${header.raw}');
  return null;
}

_ParsedDay _parseDaySection(
  List<String> sectionLines, {
  required DateTime date,
  required ItineraryContext context,
}) {
  final blocks = <_TimeBlock>[];
  _TimeBlock? current;

  for (final line in sectionLines) {
    final time = _parseTimeStart(line);
    if (time != null) {
      if (current != null) blocks.add(current);
      current = _TimeBlock(
        start: time.start,
        explicitEnd: time.end,
        endMarker: time.endMarker,
        lines: [if (time.trailing.trim().isNotEmpty) time.trailing.trim()],
      );
    } else if (current != null) {
      current.lines.add(line);
    }
  }
  if (current != null) blocks.add(current);

  final events = <ItineraryEvent>[];
  for (final block in blocks) {
    final event = _eventFromBlock(block, date: date, context: context);
    if (event != null) events.add(event);
  }
  return _ParsedDay(events: events, timeBlockCount: blocks.length);
}

ItineraryEvent? _eventFromBlock(
  _TimeBlock block, {
  required DateTime date,
  required ItineraryContext context,
}) {
  final urls = <String>[];
  final cleanedContent = <String>[];
  for (final rawLine in block.lines) {
    final lineUrls = _extractUrls(rawLine);
    urls.addAll(lineUrls);
    final withoutUrls = rawLine.replaceAll(_urlPattern, '').trim();
    if (withoutUrls.isNotEmpty) cleanedContent.add(withoutUrls);
  }

  if (cleanedContent.isEmpty) return null;

  String? address;
  final nonAddressLines = <String>[];
  for (final line in cleanedContent) {
    if (address == null && _looksLikeAddress(line)) {
      address = line;
    } else {
      nonAddressLines.add(line);
    }
  }

  if (nonAddressLines.isEmpty) return null;
  final title = nonAddressLines.first.trim();
  if (_looksLikeAddress(title) || _urlOnlyPattern.hasMatch(title)) return null;

  String? locationName;
  final notes = <String>[];
  for (final line in nonAddressLines.skip(1)) {
    final normalized = _stripLocationPrefix(line);
    if (locationName == null && _looksLikeLocationName(normalized)) {
      locationName = normalized;
    } else {
      notes.add(line);
    }
  }

  locationName ??= _inferLocationNameFromTitle(title, address: address);
  if (address == null &&
      locationName == null &&
      _isHotelCheckInTitle(title) &&
      context.hotelName != null) {
    locationName = context.hotelName;
    address = context.hotelAddress;
  }

  final endTime =
      block.explicitEnd ??
      block.start.addMinutes(_defaultDurationMinutes(title, block.endMarker));

  return ItineraryEvent(
    date: _dateOnly(date),
    title: title,
    startTime: block.start,
    endTime: endTime,
    endMarker: block.endMarker,
    locationName: locationName,
    address: address,
    urls: urls.toSet().toList(growable: false),
    notes: notes,
  );
}

_ParsedTimeStart? _parseTimeStart(String line) {
  final range = RegExp(
    r'^\s*((?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM))\s*(?:-|to|\u2013|\u2014)\s*((?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM)|sunset)\b\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (range != null) {
    final start = _parseClockTime(range.group(1)!);
    final rawEnd = range.group(2)!.trim();
    final end = rawEnd.toLowerCase() == 'sunset'
        ? null
        : _parseClockTime(rawEnd);
    if (start == null) return null;
    return _ParsedTimeStart(
      start: start,
      end: end,
      endMarker: end == null ? _titleCase(rawEnd) : null,
      trailing: range.group(3) ?? '',
    );
  }

  final single = RegExp(
    r'^\s*((?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM))\b\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (single == null) return null;
  final start = _parseClockTime(single.group(1)!);
  if (start == null) return null;
  return _ParsedTimeStart(start: start, trailing: single.group(2) ?? '');
}

ItineraryClockTime? _parseClockTime(String raw) {
  final match = RegExp(
    r'^\s*(\d{1,2})(?::([0-5][0-9]))?\s*(AM|PM)\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2) ?? '0');
  if (hour == null || minute == null || hour < 1 || hour > 12) return null;
  final period = match.group(3)!.toLowerCase();
  if (period == 'pm' && hour != 12) hour += 12;
  if (period == 'am' && hour == 12) hour = 0;
  return ItineraryClockTime(hour: hour, minute: minute);
}

int _defaultDurationMinutes(String title, String? endMarker) {
  final lower = title.toLowerCase();
  if (endMarker != null) return 90;
  if (lower.contains('breakfast')) return 45;
  if (RegExp(r'\b(lunch|dinner|brunch)\b').hasMatch(lower)) return 60;
  if (RegExp(
    r'\b(arrive|arrival|check[ -]?in|leave|head back|uber|flight|airport)\b',
  ).hasMatch(lower)) {
    return 45;
  }
  if (RegExp(
    r'\b(museum|factory|gallery|exhibit|performance)\b',
  ).hasMatch(lower)) {
    return 90;
  }
  if (RegExp(r'\b(walk|visit|tour|around)\b').hasMatch(lower)) return 60;
  return 60;
}

ItineraryContext _extractContext(List<String> preheader) {
  String? hotelName;
  String? hotelAddress;
  final setupNotes = <String>[];
  final setupUrls = <String>[];

  for (var i = 0; i < preheader.length; i++) {
    final line = preheader[i];
    final lower = line.toLowerCase();
    if (lower == 'hotel' && i + 1 < preheader.length) {
      hotelName = preheader[i + 1];
      if (i + 2 < preheader.length && _looksLikeAddress(preheader[i + 2])) {
        hotelAddress = preheader[i + 2];
      }
      continue;
    }

    final urls = _extractUrls(line);
    if (urls.isNotEmpty ||
        RegExp(r'\b(setup|travel|subway|metro|omny)\b').hasMatch(lower)) {
      setupUrls.addAll(urls);
      final withoutUrls = line.replaceAll(_urlPattern, '').trim();
      if (withoutUrls.isNotEmpty && lower != 'hotel') {
        setupNotes.add(withoutUrls);
      }
    }
  }

  return ItineraryContext(
    hotelName: hotelName,
    hotelAddress: hotelAddress,
    setupNotes: setupNotes.toSet().toList(growable: false),
    setupUrls: setupUrls.toSet().toList(growable: false),
  );
}

String _extractFlowTitle(List<String> preheader) {
  for (final line in preheader) {
    final lower = line.toLowerCase();
    if (lower == 'hotel' ||
        lower.startsWith('for ') ||
        _looksLikeAddress(line) ||
        _urlPattern.hasMatch(line)) {
      continue;
    }
    final cleaned = _cleanHeading(line);
    if (cleaned.isNotEmpty) return _smartTitle(cleaned);
  }
  return 'Itinerary';
}

String _cleanHeading(String line) {
  final filtered = String.fromCharCodes(
    line.runes.where(
      (rune) =>
          rune < 0x2600 ||
          (rune > 0x27bf && (rune < 0x1f300 || rune > 0x1faff)),
    ),
  );
  return filtered.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _smartTitle(String raw) {
  final letters = raw.replaceAll(RegExp('[^A-Za-z]'), '');
  if (letters.isEmpty || letters != letters.toUpperCase()) return raw;
  return raw
      .split(RegExp(r'\s+'))
      .map((word) {
        final bare = word.replaceAll(RegExp('[^A-Za-z]'), '');
        if (bare.length <= 3 && bare == bare.toUpperCase()) return word;
        return _titleCase(word.toLowerCase());
      })
      .join(' ');
}

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

bool _looksLikeAddress(String line) {
  final trimmed = line.trim();
  if (trimmed.length > 140 || _urlPattern.hasMatch(trimmed)) return false;
  return RegExp(
        r"^\d+\s+.+,\s*[A-Za-z .'-]+,\s*[A-Z]{2}(?:\s+\d{5}(?:-\d{4})?)?$",
        caseSensitive: false,
      ).hasMatch(trimmed) ||
      RegExp(
        r"^[A-Za-z0-9 .#&'-]+,\s*[A-Za-z .'-]+,\s*[A-Z]{2}(?:\s+\d{5}(?:-\d{4})?)?$",
        caseSensitive: false,
      ).hasMatch(trimmed);
}

List<String> _extractUrls(String line) {
  return _urlPattern
      .allMatches(line)
      .map((match) => _cleanUrl(match.group(0)!))
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}

String _cleanUrl(String raw) {
  var url = raw.trim();
  while (url.isNotEmpty && RegExp(r'[),.;!?]$').hasMatch(url)) {
    url = url.substring(0, url.length - 1);
  }
  if (url.startsWith('www.')) return 'https://$url';
  return url;
}

String _stripLocationPrefix(String line) {
  return line.replaceFirst(
    RegExp(r'^\s*location\s*:\s*', caseSensitive: false),
    '',
  );
}

bool _looksLikeLocationName(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty ||
      _looksLikeAddress(trimmed) ||
      _urlPattern.hasMatch(trimmed) ||
      trimmed.length > 80) {
    return false;
  }
  if (RegExp(r'[.!?]$').hasMatch(trimmed)) return false;
  return RegExp(r'^[A-Z0-9]').hasMatch(trimmed) ||
      RegExp(
        r'\b(room|hall|center|centre|theater|theatre|hotel)\b',
        caseSensitive: false,
      ).hasMatch(trimmed);
}

String? _inferLocationNameFromTitle(String title, {String? address}) {
  final atMatch = RegExp(
    r'\b(?:at|@)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(title);
  if (atMatch != null) {
    final candidate = atMatch.group(1)!.trim();
    if (candidate.isNotEmpty && candidate.toLowerCase() != 'hotel') {
      return candidate;
    }
  }

  if (address != null &&
      RegExp(
        r'\b(museum|factory|hall|center|centre|theater|theatre)\b',
        caseSensitive: false,
      ).hasMatch(title)) {
    return title;
  }
  return null;
}

bool _isHotelCheckInTitle(String title) {
  final lower = title.toLowerCase();
  return lower.contains('hotel') &&
      RegExp(r'\b(arrive|check[ -]?in)\b').hasMatch(lower);
}

List<ItineraryEvent> _copyNearbyAddresses(List<ItineraryEvent> events) {
  final adjusted = <ItineraryEvent>[];
  ItineraryEvent? previousWithAddress;
  for (final event in events) {
    var next = event;
    if (event.address == null &&
        previousWithAddress != null &&
        _sharePlaceToken(event, previousWithAddress)) {
      next = event.copyWith(
        locationName: event.locationName ?? previousWithAddress.locationName,
        address: previousWithAddress.address,
      );
    }
    adjusted.add(next);
    if (next.address != null) previousWithAddress = next;
  }
  return adjusted;
}

bool _sharePlaceToken(ItineraryEvent event, ItineraryEvent previous) {
  final eventText = '${event.title} ${event.locationName ?? ''}'.toLowerCase();
  final previousText = '${previous.title} ${previous.locationName ?? ''}'
      .toLowerCase();
  const tokens = [
    'battery',
    'statue',
    'liberty',
    'carnegie',
    'rockefeller',
    'times',
    'apollo',
    'harlem',
  ];
  return tokens.any(
    (token) => eventText.contains(token) && previousText.contains(token),
  );
}

void _validateExtraction({
  required List<String> lines,
  required List<ItineraryEvent> events,
  required ItineraryContext context,
  required int expectedTimeBlocks,
  required List<String> warnings,
}) {
  if (expectedTimeBlocks != events.length) {
    warnings.add(
      'Some timed items could not be extracted. Review the schedule before saving.',
    );
  }

  final retainedUrls = <String>{
    ...context.setupUrls,
    for (final event in events) ...event.urls,
  };
  final sourceUrls = lines.expand(_extractUrls).toSet();
  for (final url in sourceUrls) {
    if (!retainedUrls.contains(url)) {
      warnings.add('URL was not attached to an item: $url');
    }
  }

  final retainedAddresses = <String>{
    if (context.hotelAddress != null) context.hotelAddress!,
    for (final event in events)
      if (event.address != null) event.address!,
  };
  final sourceAddresses = lines.where(_looksLikeAddress).toSet();
  for (final address in sourceAddresses) {
    if (!retainedAddresses.contains(address)) {
      warnings.add('Address was not attached to an item: $address');
    }
  }
}

DateTime _nextWeekdayDate(int weekday, DateTime start) {
  final first = _dateOnly(start);
  for (var offset = 0; offset < 14; offset++) {
    final candidate = first.add(Duration(days: offset));
    if (candidate.weekday == weekday) return candidate;
  }
  return first;
}

DateTime? _validDate(int year, int month, int day) {
  final candidate = DateTime(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    return null;
  }
  return candidate;
}

int? _firstExplicitYear(String prompt) {
  final match = RegExp(r'\b(20\d{2}|19\d{2})\b').firstMatch(prompt);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _normalizeYear(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = int.tryParse(raw);
  if (parsed == null) return null;
  if (parsed < 100) return parsed + 2000;
  return parsed;
}

int? _monthNumber(String raw) {
  final key = raw.toLowerCase();
  if (key.startsWith('jan')) return 1;
  if (key.startsWith('feb')) return 2;
  if (key.startsWith('mar')) return 3;
  if (key.startsWith('apr')) return 4;
  if (key == 'may') return 5;
  if (key.startsWith('jun')) return 6;
  if (key.startsWith('jul')) return 7;
  if (key.startsWith('aug')) return 8;
  if (key.startsWith('sep')) return 9;
  if (key.startsWith('oct')) return 10;
  if (key.startsWith('nov')) return 11;
  if (key.startsWith('dec')) return 12;
  return null;
}

int? _weekdayNumber(String raw) {
  final key = raw.toLowerCase();
  if (key.startsWith('mon')) return DateTime.monday;
  if (key.startsWith('tue')) return DateTime.tuesday;
  if (key.startsWith('wed')) return DateTime.wednesday;
  if (key.startsWith('thu')) return DateTime.thursday;
  if (key.startsWith('fri')) return DateTime.friday;
  if (key.startsWith('sat')) return DateTime.saturday;
  if (key.startsWith('sun')) return DateTime.sunday;
  return null;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String? _eventLocation(ItineraryEvent event) {
  final parts = <String>[
    if (event.locationName != null) event.locationName!,
    if (event.address != null) event.address!,
  ];
  return parts.isEmpty ? null : parts.join('\n');
}

bool _titleContainsLocation(String title, String locationName) {
  return title.toLowerCase().contains(locationName.toLowerCase());
}

final RegExp _urlPattern = RegExp(
  r'\b(?:https?:\/\/|www\.)[^\s<>()]+',
  caseSensitive: false,
);
final RegExp _urlOnlyPattern = RegExp(
  r'^\s*(?:https?:\/\/|www\.)\S+\s*$',
  caseSensitive: false,
);

class _DateHeader {
  const _DateHeader({
    required this.lineIndex,
    required this.raw,
    this.weekday,
    this.month,
    this.day,
    this.year,
    this.dayNumber,
  });

  final int lineIndex;
  final String raw;
  final String? weekday;
  final int? month;
  final int? day;
  final int? year;
  final int? dayNumber;
}

class _ResolvedHeader {
  const _ResolvedHeader({required this.header, required this.date});

  final _DateHeader header;
  final DateTime date;
}

class _TimeBlock {
  _TimeBlock({
    required this.start,
    required this.lines,
    this.explicitEnd,
    this.endMarker,
  });

  final ItineraryClockTime start;
  final ItineraryClockTime? explicitEnd;
  final String? endMarker;
  final List<String> lines;
}

class _ParsedTimeStart {
  const _ParsedTimeStart({
    required this.start,
    this.end,
    this.endMarker,
    this.trailing = '',
  });

  final ItineraryClockTime start;
  final ItineraryClockTime? end;
  final String? endMarker;
  final String trailing;
}

class _ParsedDay {
  const _ParsedDay({required this.events, required this.timeBlockCount});

  final List<ItineraryEvent> events;
  final int timeBlockCount;
}
