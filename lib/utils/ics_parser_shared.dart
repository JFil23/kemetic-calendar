// Shared ICS parsing logic (platform-neutral).

class IcsEvent {
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final String? location;
  final String? description;
  final bool isAllDay;

  IcsEvent({
    required this.title,
    required this.startTime,
    this.endTime,
    this.location,
    this.description,
    this.isAllDay = false,
  });

  @override
  String toString() {
    return 'IcsEvent(title: $title, start: $startTime, end: $endTime, location: $location, allDay: $isAllDay)';
  }
}

List<IcsEvent> parseIcsString(String icsContent) {
  try {
    final events = <IcsEvent>[];
    final lines = _unfoldIcsLines(icsContent);

    bool inEvent = false;
    Map<String, String> currentEvent = {};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed == 'BEGIN:VEVENT') {
        inEvent = true;
        currentEvent = {};
      } else if (trimmed == 'END:VEVENT') {
        inEvent = false;
        final event = parseIcsEventMap(currentEvent);
        if (event != null) {
          events.add(event);
        }
      } else if (inEvent) {
        final colonIndex = trimmed.indexOf(':');
        if (colonIndex > 0) {
          final key = trimmed.substring(0, colonIndex).toUpperCase();
          final value = _decodeTextValue(trimmed.substring(colonIndex + 1));
          currentEvent[key] = value;
        }
      }
    }

    return events;
  } catch (_) {
    return [];
  }
}

IcsEvent? parseIcsEventMap(Map<String, String> properties) {
  try {
    final title = _propertyValue(properties, 'SUMMARY') ?? 'Untitled Event';

    final startKey = _propertyKey(properties, 'DTSTART');
    final startRaw = startKey == null ? null : properties[startKey];
    if (startKey == null || startRaw == null) {
      return null;
    }

    final isAllDay = _isAllDayProperty(startKey, startRaw);
    final startTime = parseIcsDateTime(startRaw, isDateOnly: isAllDay);
    if (startTime == null) {
      return null;
    }

    DateTime? endTime;
    final endKey = _propertyKey(properties, 'DTEND');
    final endRaw = endKey == null ? null : properties[endKey];
    if (endRaw != null) {
      endTime = parseIcsDateTime(
        endRaw,
        isDateOnly: _isAllDayProperty(endKey, endRaw),
      );
    }

    final location = _propertyValue(properties, 'LOCATION');
    final description = _propertyValue(properties, 'DESCRIPTION');

    return IcsEvent(
      title: title,
      startTime: startTime,
      endTime: endTime,
      location: location,
      description: description,
      isAllDay: isAllDay,
    );
  } catch (_) {
    return null;
  }
}

/// Parse a datetime string (YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ)
DateTime? parseIcsDateTime(String dtStr, {bool isDateOnly = false}) {
  try {
    final cleaned = dtStr.trim();
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    if (isDateOnly || RegExp(r'^\d{8}$').hasMatch(cleaned)) {
      if (digitsOnly.length < 8) {
        return null;
      }
      final year = int.parse(digitsOnly.substring(0, 4));
      final month = int.parse(digitsOnly.substring(4, 6));
      final day = int.parse(digitsOnly.substring(6, 8));
      return DateTime(year, month, day);
    }

    final normalized = cleaned.replaceAll(RegExp(r'[^0-9TZ]'), '');

    if (normalized.length >= 15) {
      final year = int.parse(normalized.substring(0, 4));
      final month = int.parse(normalized.substring(4, 6));
      final day = int.parse(normalized.substring(6, 8));
      final hour = int.parse(normalized.substring(9, 11));
      final minute = int.parse(normalized.substring(11, 13));
      final second = int.parse(normalized.substring(13, 15));

      final isUtc = normalized.endsWith('Z');

      if (isUtc) {
        return DateTime.utc(year, month, day, hour, minute, second);
      } else {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    return null;
  } catch (_) {
    return null;
  }
}

List<String> _unfoldIcsLines(String icsContent) {
  final rawLines = icsContent
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final unfolded = <String>[];

  for (final rawLine in rawLines) {
    if ((rawLine.startsWith(' ') || rawLine.startsWith('\t')) &&
        unfolded.isNotEmpty) {
      unfolded[unfolded.length - 1] += rawLine.substring(1);
      continue;
    }
    unfolded.add(rawLine.trimRight());
  }

  return unfolded;
}

String? _propertyKey(Map<String, String> properties, String propertyName) {
  final upperName = propertyName.toUpperCase();
  if (properties.containsKey(upperName)) {
    return upperName;
  }
  for (final key in properties.keys) {
    if (key == upperName || key.startsWith('$upperName;')) {
      return key;
    }
  }
  return null;
}

String? _propertyValue(Map<String, String> properties, String propertyName) {
  final key = _propertyKey(properties, propertyName);
  return key == null ? null : properties[key];
}

bool _isAllDayProperty(String? key, String value) {
  if (key != null && key.contains('VALUE=DATE')) {
    return true;
  }
  return RegExp(r'^\d{8}$').hasMatch(value.trim());
}

String _decodeTextValue(String raw) {
  return raw
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');
}
