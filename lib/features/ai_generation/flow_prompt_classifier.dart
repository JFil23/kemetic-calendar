enum FlowPromptType {
  itinerarySchedule,
  routineHabit,
  maatGuidedFlow,
  wellnessNutrition,
  studyLearning,
  projectPlan,
  openEndedCreative,
  editExistingFlow,
  unknown,
}

FlowPromptType classifyFlowPrompt(
  String prompt, {
  bool isEditingExistingFlow = false,
}) {
  final trimmed = prompt.trim();
  if (trimmed.isEmpty) return FlowPromptType.unknown;

  if (isEditingExistingFlow || _looksLikeEditPrompt(trimmed)) {
    return FlowPromptType.editExistingFlow;
  }
  if (looksLikeItinerarySchedulePrompt(trimmed)) {
    return FlowPromptType.itinerarySchedule;
  }
  if (_maatPattern.hasMatch(trimmed)) {
    return FlowPromptType.maatGuidedFlow;
  }
  if (_studyPattern.hasMatch(trimmed)) {
    return FlowPromptType.studyLearning;
  }
  if (_routinePattern.hasMatch(trimmed)) {
    return FlowPromptType.routineHabit;
  }
  if (_wellnessPattern.hasMatch(trimmed)) {
    return FlowPromptType.wellnessNutrition;
  }
  if (_projectPattern.hasMatch(trimmed)) {
    return FlowPromptType.projectPlan;
  }
  if (_creativePattern.hasMatch(trimmed)) {
    return FlowPromptType.openEndedCreative;
  }
  return FlowPromptType.unknown;
}

bool looksLikeItinerarySchedulePrompt(String prompt) {
  final lines = normalizeFlowPromptLinesForSchedule(prompt);
  if (lines.isEmpty) return false;

  final timeCount = _timePattern.allMatches(prompt).length;
  final timedLineCount = lines.where(_lineStartsWithTime).length;
  final dayHeaderCount = lines.where(_looksLikeDayHeaderLine).length;
  final addressCount = lines.where(_looksLikeAddressLine).length;
  final urlCount = _urlPattern.allMatches(prompt).length;
  final travelWordCount = _travelPattern.allMatches(prompt).length;
  final hasScheduleCue = _scheduleCuePattern.hasMatch(prompt);

  if (dayHeaderCount >= 2 && timeCount >= 2) return true;
  if (dayHeaderCount >= 1 && timedLineCount >= 4) return true;
  if (timeCount >= 5 &&
      (addressCount >= 1 || urlCount >= 1 || hasScheduleCue)) {
    return true;
  }
  if (timedLineCount >= 4 &&
      (addressCount >= 1 ||
          urlCount >= 1 ||
          travelWordCount >= 3 ||
          hasScheduleCue)) {
    return true;
  }
  if (addressCount >= 2 && timeCount >= 3 && hasScheduleCue) return true;
  if (hasScheduleCue && dayHeaderCount >= 1 && timeCount >= 3) return true;

  return false;
}

List<String> normalizeFlowPromptLinesForSchedule(String prompt) {
  final expanded = _expandInlineScheduleText(prompt);
  return expanded
      .replaceAll('\r', '\n')
      .split('\n')
      .map(_cleanScheduleLine)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

String _expandInlineScheduleText(String prompt) {
  var text = prompt.replaceAll('\r', '\n').replaceAll(RegExp(r'[ \t]+'), ' ');

  text = text.replaceAllMapped(_inlineHotelHeaderPattern, (match) {
    return '\n${match.group(0)!.trim()}\n';
  });
  text = text.replaceAllMapped(_inlineWeekdayMonthDayHeaderPattern, (match) {
    return '\n${match.group(0)!.trim()}\n';
  });
  text = text.replaceAllMapped(_inlineWeekdaySlashDateHeaderPattern, (match) {
    return '\n${match.group(0)!.trim()}\n';
  });
  text = text.replaceAllMapped(_inlineTimeBlockPattern, (match) {
    return '\n${match.group(0)!.trim()}\n';
  });
  text = text.replaceAllMapped(_inlineNumberedAddressPattern, (match) {
    return '\n${match.group(1)!.trim()}';
  });
  text = text.replaceAllMapped(_inlinePlaceAddressPattern, (match) {
    final previous = match.start > 0 ? text[match.start - 1] : '';
    final lineStart = match.start <= 0
        ? -1
        : text.lastIndexOf('\n', match.start - 1);
    final beforeOnLine = text.substring(lineStart + 1, match.start).trimRight();
    if (RegExp(r'\d').hasMatch(previous) ||
        RegExp(r'(?:^|\s)\d+\s+[^,\n]*$').hasMatch(beforeOnLine)) {
      return match.group(0)!;
    }
    return '\n${match.group(1)!.trim()}';
  });

  return text.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
}

String _cleanScheduleLine(String line) {
  return line.trim().replaceFirst(RegExp(r'^(?:[-*]|\u2022)+\s*'), '').trim();
}

bool _looksLikeEditPrompt(String prompt) {
  return _editPattern.hasMatch(prompt) && _existingFlowPattern.hasMatch(prompt);
}

bool _lineStartsWithTime(String line) {
  return RegExp(
    r'^\s*(?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM)\b',
    caseSensitive: false,
  ).hasMatch(line);
}

bool _looksLikeDayHeaderLine(String line) {
  final trimmed = line.trim();
  if (trimmed.length > 80) return false;
  return _weekdayMonthDayHeaderPattern.hasMatch(trimmed) ||
      _weekdaySlashDateHeaderPattern.hasMatch(trimmed) ||
      _standaloneWeekdayHeaderPattern.hasMatch(trimmed) ||
      _dayNumberHeaderPattern.hasMatch(trimmed);
}

bool _looksLikeAddressLine(String line) {
  final trimmed = line.trim();
  if (trimmed.length > 120 || _urlPattern.hasMatch(trimmed)) return false;
  return _numberedAddressPattern.hasMatch(trimmed) ||
      _placeAddressPattern.hasMatch(trimmed);
}

final RegExp _timePattern = RegExp(
  r'\b(?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM)\b',
  caseSensitive: false,
);
final RegExp _inlineTimeBlockPattern = RegExp(
  r'\b(?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM)\s*(?:(?:-|to|\u2013|\u2014)\s*(?:(?:[1-9]|1[0-2])(?::[0-5][0-9])?\s*(?:AM|PM)|sunset))?',
  caseSensitive: false,
);
final RegExp _urlPattern = RegExp(
  r'\b(?:https?:\/\/|www\.)\S+',
  caseSensitive: false,
);
final RegExp _inlineHotelHeaderPattern = RegExp(r'\bHOTEL\b');
final RegExp _inlineWeekdayMonthDayHeaderPattern = RegExp(
  r'\b(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b\s*(?:[\u2022.\-]\s*)?\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|sept|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:\s*,?\s*\d{4})?\b',
  caseSensitive: false,
);
final RegExp _inlineWeekdaySlashDateHeaderPattern = RegExp(
  r'\b(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b\s*(?:[\u2022.\-]\s*)?\b\d{1,2}[\/-]\d{1,2}(?:[\/-]\d{2,4})?\b',
  caseSensitive: false,
);
final RegExp _weekdayMonthDayHeaderPattern = RegExp(
  r'^(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b.{0,32}\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|sept|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}\b',
  caseSensitive: false,
);
final RegExp _weekdaySlashDateHeaderPattern = RegExp(
  r'^(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b.{0,16}\b\d{1,2}[\/-]\d{1,2}(?:[\/-]\d{2,4})?\b',
  caseSensitive: false,
);
final RegExp _standaloneWeekdayHeaderPattern = RegExp(
  r'^(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)$',
  caseSensitive: false,
);
final RegExp _dayNumberHeaderPattern = RegExp(
  r'^day\s+\d{1,3}\b',
  caseSensitive: false,
);
final RegExp _numberedAddressPattern = RegExp(
  r"^\d+\s+.+,\s*[A-Za-z .'-]+,\s*[A-Z]{2}(?:\s+\d{5}(?:-\d{4})?)?$",
  caseSensitive: false,
);
final RegExp _placeAddressPattern = RegExp(
  r"^[A-Za-z0-9 .#&'-]+,\s*[A-Za-z .'-]+,\s*[A-Z]{2}(?:\s+\d{5}(?:-\d{4})?)?$",
  caseSensitive: false,
);
final RegExp _inlineNumberedAddressPattern = RegExp(
  r"\s+(\d+\s+[^,\n]+,\s*[A-Z][A-Za-z .'-]+,\s*[A-Z]{2}\s+\d{5}(?:-\d{4})?)",
  caseSensitive: false,
);
final RegExp _inlinePlaceAddressPattern = RegExp(
  r"\s+([A-Z][A-Za-z0-9 .#&'-]{1,48},\s*[A-Z][A-Za-z .'-]+,\s*[A-Z]{2}\s+\d{5}(?:-\d{4})?)",
  caseSensitive: false,
);
final RegExp _travelPattern = RegExp(
  r'\b(itinerary|agenda|hotel|arrive|arrival|check[ -]?in|leave for|head back|uber|flight|airport|rehearsal|performance|lunch|dinner|breakfast|museum|walk|visit|conference|wedding|retreat|field trip|tournament|travel|trip)\b',
  caseSensitive: false,
);
final RegExp _scheduleCuePattern = RegExp(
  r'\b(itinerary|agenda|conference|wedding(?: weekend)?|trip|travel plan|field trip|tournament|retreat|rehearsal|performance|hotel)\b',
  caseSensitive: false,
);
final RegExp _editPattern = RegExp(
  r'\b(edit|change|modify|update|replace|revise)\b',
  caseSensitive: false,
);
final RegExp _existingFlowPattern = RegExp(
  r'\b(existing|current|this|saved)\s+(flow|schedule|plan)\b|\b(flow|schedule|plan)\s+(I already|we already|that I)\b',
  caseSensitive: false,
);
final RegExp _maatPattern = RegExp(
  r"\b(ma['\u2019]?at|ma\u02bbat|decan|follow the sky|kemetic|rite)\b",
  caseSensitive: false,
);
final RegExp _studyPattern = RegExp(
  r'\b(study|lesson|learning|math|course|class|homework|reading|curriculum)\b',
  caseSensitive: false,
);
final RegExp _wellnessPattern = RegExp(
  r'\b(wellness|nutrition|meal plan|hydration|protein|workout|exercise|sleep|meditation|breathwork)\b',
  caseSensitive: false,
);
final RegExp _routinePattern = RegExp(
  r'\b(routine|habit|morning|evening|daily|weekly|bedtime|wake)\b',
  caseSensitive: false,
);
final RegExp _projectPattern = RegExp(
  r'\b(project|milestone|sprint|deliverable|launch|roadmap|deadline)\b',
  caseSensitive: false,
);
final RegExp _creativePattern = RegExp(
  r'\b(create|build|make|design|write|brainstorm|generate)\b',
  caseSensitive: false,
);
