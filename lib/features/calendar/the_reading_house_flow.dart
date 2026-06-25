import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'maat_flow_identity.dart';
import 'maat_flow_response_models.dart';
import 'track_sky_flow.dart';

const String kReadingHouseFlowKey = 'the-reading-house';
const String kReadingHouseTitle = 'The Reading House';
const String kReadingHouseGlyph = '𓉐';
const String kReadingHouseTagline = 'A private-study foundation for one book.';
const String kReadingHouseEnrollmentCopy =
    'Phase 1A creates private starter sittings. Company mode is saved as intent only; invite links, shared fragments, replies, and house chat are not live yet.';

const String kReadingHouseBookTitlePromptId = 'reading-house-book-title';
const String kReadingHouseEditionNotePromptId = 'reading-house-edition-note';
const String kReadingHouseQuestionPromptId = 'reading-house-question';
const String kReadingHouseModePromptId = 'reading-house-mode';

const String kReadingHouseDefaultBookTitle = 'the chosen book';
const String kReadingHouseDefaultQuestion =
    'What is this book asking the reader to hold?';
const String kReadingHouseDefaultMode = 'company';
const String kReadingHouseSoloMode = 'solo';
const String kReadingHouseDefaultState = 'draft_house';
const int kReadingHouseDefaultHour = 19;
const int kReadingHouseDefaultMinute = 0;
const int kReadingHouseDefaultDurationMinutes = 60;

const String kReadingHouseOverview =
    'The Reading House is registered as a Ma’at flow with a Phase 1A private-study skeleton. A book is divided into three generated starter sittings. Each sitting begins with private reflection, lets the reader mark position without mandatory writing, and keeps company surfaces future-facing. It is not yet a book-club engine.';

class ReadingHousePlan {
  const ReadingHousePlan({
    this.bookTitle = kReadingHouseDefaultBookTitle,
    this.editionNote = '',
    this.houseQuestion = kReadingHouseDefaultQuestion,
    this.mode = kReadingHouseDefaultMode,
    this.state = kReadingHouseDefaultState,
  });

  final String bookTitle;
  final String editionNote;
  final String houseQuestion;
  final String mode;
  final String state;

  String get displayBookTitle {
    final trimmed = bookTitle.trim();
    return trimmed.isEmpty ? kReadingHouseDefaultBookTitle : trimmed;
  }

  String get displayQuestion {
    final trimmed = houseQuestion.trim();
    return trimmed.isEmpty ? kReadingHouseDefaultQuestion : trimmed;
  }

  String get normalizedMode {
    final normalized = mode.trim().toLowerCase();
    if (normalized == kReadingHouseSoloMode) return kReadingHouseSoloMode;
    return kReadingHouseDefaultMode;
  }

  bool get isSolo => normalizedMode == kReadingHouseSoloMode;
}

class ReadingHouseSitting {
  const ReadingHouseSitting({
    required this.eventNumber,
    required this.flowDay,
    required this.title,
    required this.section,
    required this.theme,
    required this.privatePrompt,
    this.hostNote = '',
    this.sharePromptOnComplete = false,
  });

  final int eventNumber;
  final int flowDay;
  final String title;
  final String section;
  final String theme;
  final String privatePrompt;
  final String hostNote;
  final bool sharePromptOnComplete;
}

class ReadingHouseOccurrenceSchedule {
  const ReadingHouseOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.timezone,
    required this.scheduleType,
    required this.fallback,
    required this.hour,
    required this.minute,
  });

  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final TrackSkyTimeZone timezone;
  final String scheduleType;
  final String fallback;
  final int hour;
  final int minute;
}

const List<ReadingHouseSitting> kReadingHouseSittings = <ReadingHouseSitting>[
  ReadingHouseSitting(
    eventNumber: 1,
    flowDay: 1,
    title: 'Open the Text',
    section: 'Opening section',
    theme: 'What is the text asking you to carry?',
    privatePrompt:
        'Before company shapes the reading, write one private line, save a short note, or sit without writing.',
    hostNote:
        'Begin with your own encounter. The house can receive a fragment later.',
  ),
  ReadingHouseSitting(
    eventNumber: 2,
    flowDay: 7,
    title: 'Hold the Middle',
    section: 'Middle section',
    theme: 'Where does the book change your measure?',
    privatePrompt:
        'Name one passage, question, or resistance that appeared while reading this portion.',
  ),
  ReadingHouseSitting(
    eventNumber: 3,
    flowDay: 14,
    title: 'Seal the Reading',
    section: 'Closing section',
    theme: 'What fragment should the house keep?',
    privatePrompt:
        'Mark what remains after the book closes: sentence, question, practice, or passage.',
    hostNote:
        'Only share a fragment if you choose. The private record remains private.',
    sharePromptOnComplete: true,
  ),
];

bool _readingHouseTimeZonesInitialized = false;

void _ensureReadingHouseTimeZonesInitialized() {
  if (_readingHouseTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _readingHouseTimeZonesInitialized = true;
}

DateTime defaultReadingHouseStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = readingHouseNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final start = readingHouseScheduleForDate(
    kReadingHouseSittings.first,
    today,
    timezone,
  ).startLocal;
  if (!start.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime readingHouseNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureReadingHouseTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromReadingHouseZonedDateTime(zoned);
}

ReadingHouseOccurrenceSchedule readingHouseScheduleForDate(
  ReadingHouseSitting sitting,
  DateTime date,
  TrackSkyTimeZone timezone, {
  int hour = kReadingHouseDefaultHour,
  int minute = kReadingHouseDefaultMinute,
}) {
  _ensureReadingHouseTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final location = tz.getLocation(timezone.ianaName);
  final clampedHour = hour.clamp(0, 23).toInt();
  final clampedMinute = minute.clamp(0, 59).toInt();
  final startUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    clampedHour,
    clampedMinute,
  ).toUtc();
  final endUtc = startUtc.add(
    const Duration(minutes: kReadingHouseDefaultDurationMinutes),
  );
  return ReadingHouseOccurrenceSchedule(
    startLocal: _fromReadingHouseZonedDateTime(
      tz.TZDateTime.from(startUtc, location),
    ),
    endLocal: _fromReadingHouseZonedDateTime(
      tz.TZDateTime.from(endUtc, location),
    ),
    startUtc: startUtc,
    endUtc: endUtc,
    timezone: timezone,
    scheduleType: 'fixed_local_evening',
    fallback: 'user_editable_local_time',
    hour: clampedHour,
    minute: clampedMinute,
  );
}

String readingHouseSittingTitle(ReadingHouseSitting sitting) {
  return 'Reading House ${sitting.eventNumber}: ${sitting.title}';
}

String readingHouseActionId(ReadingHouseSitting sitting) {
  return 'the-reading-house-sitting-${sitting.eventNumber.toString().padLeft(2, '0')}';
}

ReadingHouseSitting? readingHouseSittingByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final sitting in kReadingHouseSittings) {
    if (sitting.eventNumber == eventNumber) return sitting;
  }
  return null;
}

ReadingHousePlan readingHousePlanFromDraftValues(
  Map<String, MaatFlowResponseValue> values,
) {
  String text(String id) => values[id]?.text?.trim() ?? '';
  String choice(String id, String fallback) {
    final options = values[id]?.optionIds ?? const <String>[];
    if (options.isEmpty) return fallback;
    final selected = options.first.trim().toLowerCase();
    return selected.isEmpty ? fallback : selected;
  }

  return ReadingHousePlan(
    bookTitle: text(kReadingHouseBookTitlePromptId),
    editionNote: text(kReadingHouseEditionNotePromptId),
    houseQuestion: text(kReadingHouseQuestionPromptId),
    mode: choice(kReadingHouseModePromptId, kReadingHouseDefaultMode),
  );
}

ReadingHousePlan readingHousePlanFromFlowNotes(
  String? notes, {
  ReadingHousePlan fallback = const ReadingHousePlan(),
}) {
  if (notes == null || notes.isEmpty) return fallback;
  final values = <String, String>{};
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    final key = trimmed.substring(0, index);
    final value = trimmed.substring(index + 1);
    values[key] = Uri.decodeComponent(value);
  }
  return ReadingHousePlan(
    bookTitle: values['reading_house_book'] ?? fallback.bookTitle,
    editionNote: values['reading_house_edition'] ?? fallback.editionNote,
    houseQuestion: values['reading_house_question'] ?? fallback.houseQuestion,
    mode: values['reading_house_mode'] ?? fallback.mode,
    state: values['reading_house_state'] ?? fallback.state,
  );
}

List<String> readingHouseFlowNoteTokens(ReadingHousePlan plan) {
  String enc(String value) => Uri.encodeComponent(value.trim());
  return <String>[
    'reading_house_mode=${plan.normalizedMode}',
    'reading_house_state=${plan.state}',
    if (plan.bookTitle.trim().isNotEmpty)
      'reading_house_book=${enc(plan.bookTitle)}',
    if (plan.editionNote.trim().isNotEmpty)
      'reading_house_edition=${enc(plan.editionNote)}',
    if (plan.houseQuestion.trim().isNotEmpty)
      'reading_house_question=${enc(plan.houseQuestion)}',
  ];
}

ReadingHouseSitting? readingHouseSittingForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadSitting = _readingHouseSittingFromPayload(
    behaviorPayload,
    parseNumber,
  );
  if (payloadSitting != null) return payloadSitting;

  final actionMatch = RegExp(
    r'the-reading-house-sitting-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionSitting = readingHouseSittingByNumber(
    parseNumber(actionMatch?.group(1)),
  );
  if (actionSitting != null) return actionSitting;

  final titleMatch = RegExp(
    r'^\s*Reading\s+House\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return readingHouseSittingByNumber(parseNumber(titleMatch?.group(1)));
}

ReadingHouseSitting? _readingHouseSittingFromPayload(
  Map<String, dynamic>? payload,
  int? Function(dynamic value) parseNumber,
) {
  if (payload == null) return null;
  final eventNumber = parseNumber(payload['event_number']);
  if (eventNumber == null) return null;
  final fallback = readingHouseSittingByNumber(eventNumber);
  if (fallback == null) return null;

  String value(String key, String fallbackValue) {
    final raw = payload[key]?.toString().trim();
    return raw == null || raw.isEmpty ? fallbackValue : raw;
  }

  bool boolValue(String key, bool fallbackValue) {
    final raw = payload[key];
    if (raw is bool) return raw;
    if (raw == null) return fallbackValue;
    final normalized = raw.toString().trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return fallbackValue;
  }

  return ReadingHouseSitting(
    eventNumber: eventNumber,
    flowDay: parseNumber(payload['flow_day']) ?? fallback.flowDay,
    title: value('sitting_title', fallback.title),
    section: value('section', fallback.section),
    theme: value('theme', fallback.theme),
    privatePrompt: value('private_prompt', fallback.privatePrompt),
    hostNote: value('host_note', fallback.hostNote),
    sharePromptOnComplete: boolValue(
      'share_prompt_on_complete',
      fallback.sharePromptOnComplete,
    ),
  );
}

bool isReadingHouseFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.readingHouse,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

String? canonicalReadingHouseDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isReadingHouseFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final sitting = readingHouseSittingForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (sitting == null) return null;
  final plan = readingHousePlanFromPayload(
    behaviorPayload,
    fallback: readingHousePlanFromFlowNotes(flowNotes),
  );
  return readingHouseDetailText(sitting, plan: plan);
}

ReadingHousePlan readingHousePlanFromPayload(
  Map<String, dynamic>? payload, {
  ReadingHousePlan fallback = const ReadingHousePlan(),
}) {
  if (payload == null) return fallback;
  String value(String key, String fallbackValue) {
    final raw = payload[key]?.toString().trim();
    return raw == null || raw.isEmpty ? fallbackValue : raw;
  }

  return ReadingHousePlan(
    bookTitle: value('book_title', fallback.bookTitle),
    editionNote: value('edition_note', fallback.editionNote),
    houseQuestion: value('house_question', fallback.houseQuestion),
    mode: value('house_mode', fallback.mode),
    state: value('house_state', fallback.state),
  );
}

Map<String, dynamic> readingHouseBehaviorPayload({
  required ReadingHouseSitting sitting,
  required ReadingHouseOccurrenceSchedule schedule,
  required ReadingHousePlan plan,
}) {
  return <String, dynamic>{
    'kind': 'maat_reading_house_sitting',
    'flow_key': kReadingHouseFlowKey,
    'event_number': sitting.eventNumber,
    'flow_day': sitting.flowDay,
    'sitting_title': sitting.title,
    'section': sitting.section,
    'theme': sitting.theme,
    'private_prompt': sitting.privatePrompt,
    if (sitting.hostNote.trim().isNotEmpty)
      'host_note': sitting.hostNote.trim(),
    'sitting_source': 'starter_default',
    'host_editable': false,
    'host_authoring_phase': 'future',
    'book_title': plan.displayBookTitle,
    if (plan.editionNote.trim().isNotEmpty)
      'edition_note': plan.editionNote.trim(),
    'house_question': plan.displayQuestion,
    'house_mode': plan.normalizedMode,
    'house_state': plan.state,
    'private_first': true,
    'writing_required': false,
    'unlock_gate': 'reading_position_mark',
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'presence_options': const <String>['carrying', 'not_yet'],
    'share_prompt_on_complete': sitting.sharePromptOnComplete,
    'discussion_model': const <String, dynamic>{
      'phase': 'future',
      'reply_depth': 1,
      'likes': false,
      'ranking': false,
    },
    'schedule': <String, dynamic>{
      'type': schedule.scheduleType,
      'fallback': schedule.fallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'hour': schedule.hour,
      'minute': schedule.minute,
    },
  };
}

String readingHouseDetailText(
  ReadingHouseSitting sitting, {
  required ReadingHousePlan plan,
}) {
  final edition = plan.editionNote.trim();
  final hostNote = sitting.hostNote.trim();
  return <String>[
    'Book\n${plan.displayBookTitle}${edition.isEmpty ? '' : '\nEdition: $edition'}',
    'House question\n${plan.displayQuestion}',
    'Section\n${sitting.section}',
    'Theme\n${sitting.theme}',
    'Private prompt\n${sitting.privatePrompt}',
    'Position gate\nWrite a reflection, save a short note, sit without writing, or mark Not yet. This release records the private reading position only; shared fragments and discussion unlock in a later phase.',
    if (hostNote.isNotEmpty) 'Host note\n$hostNote',
    'Completion\nUse Observed when the sitting was honestly held, Partly when the reading position is partial, and Skipped when you did not sit. In company mode, Carrying and Not yet become factual presence states when shared surfaces arrive.',
  ].join('\n\n');
}

String readingHouseTimingLabel(ReadingHouseSitting sitting) {
  return 'Day ${sitting.flowDay} · 7:00 PM local';
}

DateTime _fromReadingHouseZonedDateTime(tz.TZDateTime zoned) {
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
