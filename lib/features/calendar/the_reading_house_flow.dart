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
    'Phase 4A keeps the house private-first while adding House Chat as a secondary support lane beside shared house margin, host announcements, opt-in fragments, and one-level replies: hosts shape sittings, readers keep local private margins, writing stays optional, and Carrying unlocks one chosen fragment for joined house members. Pods, public discovery, likes, ranking, and discussion rooms remain out of scope.';

const String kReadingHouseBookTitlePromptId = 'reading-house-book-title';
const String kReadingHouseEditionNotePromptId = 'reading-house-edition-note';
const String kReadingHouseQuestionPromptId = 'reading-house-question';
const String kReadingHouseModePromptId = 'reading-house-mode';
const String kReadingHousePrivateReflectionSpecId =
    'reading-house-private-reflection';
const String kReadingHouseShortNoteSpecId = 'reading-house-short-note';
const String kReadingHouseSitWithoutWritingSpecId =
    'reading-house-sit-without-writing';
const String kReadingHousePositionSpecId = 'reading-house-position';
const String kReadingHousePositionCarrying = 'carrying';
const String kReadingHousePositionNotYet = 'not_yet';

const String kReadingHouseDefaultBookTitle = 'the chosen book';
const String kReadingHouseDefaultQuestion =
    'What is this book asking the reader to hold?';
const String kReadingHouseDefaultMode = 'company';
const String kReadingHouseSoloMode = 'solo';
const String kReadingHouseDefaultState = 'draft_house';
const String kReadingHouseSittingSourceStarterDefault = 'starter_default';
const String kReadingHouseSittingSourceHostAuthored = 'host_authored';
const String kReadingHouseHostAuthoringPhaseFuture = 'future';
const String kReadingHouseHostAuthoringPhaseEnabled = 'enabled';
const String kReadingHouseHouseStateOpen = 'open_house';
const String kReadingHouseHouseStateCompany = 'company_house';
const String kReadingHouseHouseStateSolo = 'solo_study';
const String kReadingHouseMembershipSourceSharedCalendar =
    'shared_calendar_members';
const String kReadingHouseSharedFragmentsPhaseEnabled = 'enabled';
const String kReadingHouseFragmentRepliesPhaseEnabled = 'enabled';
const String kReadingHouseHouseMarginPhaseEnabled = 'enabled';
const String kReadingHouseHostAnnouncementsPhaseEnabled = 'enabled';
const String kReadingHouseHouseChatPhaseEnabled = 'enabled';
const String kReadingHouseConversationSurfacesPhaseFuture = 'future';
const int kReadingHouseCompanyMemberThreshold = 2;
const int kReadingHouseDefaultHour = 19;
const int kReadingHouseDefaultMinute = 0;
const int kReadingHouseDefaultDurationMinutes = 60;

const String kReadingHouseOverview =
    'The Reading House is registered as a Ma’at flow with host-authored private sittings, shared presence, opt-in shared fragments, one-level replies, a shared house margin, host announcements, and Phase 4A House Chat for logistics. A book can begin from three starter sittings, then the host can edit, add, reorder, or delete the sitting plan. Each sitting opens with section, theme, host note, and private prompt; the reader can keep a local private margin, sit without writing, and must mark Carrying or Not yet before Observed, Partly, or Skipped. Open House and Company House state comes from accepted shared-calendar membership. Carrying unlocks one chosen fragment for joined house members; private reflection, short-note text, and local private margin text are never copied automatically. Discussion rooms, pods, public discovery, likes, and ranking remain out of scope.';

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

String readingHouseHouseStateFor({
  required bool soloStudy,
  required int activeJoinedMemberCount,
}) {
  if (soloStudy) return kReadingHouseHouseStateSolo;
  final count = activeJoinedMemberCount < 0 ? 0 : activeJoinedMemberCount;
  if (count >= kReadingHouseCompanyMemberThreshold) {
    return kReadingHouseHouseStateCompany;
  }
  return kReadingHouseHouseStateOpen;
}

String readingHouseHouseStateLabel(String state) {
  switch (state) {
    case kReadingHouseHouseStateCompany:
      return 'Company House';
    case kReadingHouseHouseStateSolo:
      return 'Solo Study';
    case kReadingHouseHouseStateOpen:
    default:
      return 'Open House';
  }
}

String readingHouseMemberCountSummary(int activeJoinedMemberCount) {
  final count = activeJoinedMemberCount < 0 ? 0 : activeJoinedMemberCount;
  if (count == 1) return '1 member joined';
  return '$count members joined';
}

String readingHouseCarryingSummary(int carryingCount) {
  final count = carryingCount < 0 ? 0 : carryingCount;
  if (count == 1) return '1 reader Carrying';
  return '$count readers Carrying';
}

String readingHouseSharedFragmentCountSummary(int fragmentCount) {
  final count = fragmentCount < 0 ? 0 : fragmentCount;
  if (count == 1) return '1 fragment shared for this sitting';
  return '$count fragments shared for this sitting';
}

String? readingHouseSharedFragmentUnlockPosition(String? position) {
  final normalized = position?.trim().toLowerCase();
  if (normalized == kReadingHousePositionCarrying) {
    return kReadingHousePositionCarrying;
  }
  return null;
}

List<String> readingHouseFactualSummaryLines({
  required String houseState,
  required int activeJoinedMemberCount,
  int carryingCount = 0,
  String? nextSittingLabel,
}) {
  final count = activeJoinedMemberCount < 0 ? 0 : activeJoinedMemberCount;
  final lines = <String>[];
  switch (houseState) {
    case kReadingHouseHouseStateSolo:
      lines.add('Solo study · private calendar');
      break;
    case kReadingHouseHouseStateCompany:
      lines.add(readingHouseMemberCountSummary(count));
      break;
    case kReadingHouseHouseStateOpen:
    default:
      lines.add('House open · waiting for readers');
      break;
  }
  if (carryingCount > 0) {
    lines.add(readingHouseCarryingSummary(carryingCount));
  }
  final next = nextSittingLabel?.trim();
  if (next != null && next.isNotEmpty) {
    lines.add('Next sitting: $next');
  }
  return lines;
}

Map<String, dynamic> readingHouseCompanyPresenceContract(
  ReadingHousePlan plan,
) {
  return <String, dynamic>{
    'phase': 'phase_4a',
    'membership_source': kReadingHouseMembershipSourceSharedCalendar,
    'state_source': 'active_joined_member_count',
    'company_threshold': kReadingHouseCompanyMemberThreshold,
    'solo_state': kReadingHouseHouseStateSolo,
    'open_state': kReadingHouseHouseStateOpen,
    'company_state': kReadingHouseHouseStateCompany,
    'member_list': 'enabled',
    'invite_join': 'shared_calendar_invite',
    'factual_summary_only': true,
    'shared_fragments': kReadingHouseSharedFragmentsPhaseEnabled,
    'shared_fragment_unlock': 'carrying_position_mark',
    'shared_fragment_scope': 'house_sitting',
    'fragment_replies': kReadingHouseFragmentRepliesPhaseEnabled,
    'reply_depth': 1,
    'house_margin': kReadingHouseHouseMarginPhaseEnabled,
    'house_margin_scope': 'house',
    'host_announcements': kReadingHouseHostAnnouncementsPhaseEnabled,
    'announcement_scope': 'house_notice_lane',
    'house_chat': kReadingHouseHouseChatPhaseEnabled,
    'house_chat_scope': 'full_house_support_lane',
    'house_chat_membership': 'accepted_shared_calendar_members',
    'house_chat_role': 'logistics_and_quick_notes',
    'private_reader_text_shared': false,
    'replies': kReadingHouseFragmentRepliesPhaseEnabled,
    'discussion': kReadingHouseConversationSurfacesPhaseFuture,
    'global_commons_share': false,
    'solo_study_private': plan.isSolo,
  };
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
    this.sittingSource = kReadingHouseSittingSourceStarterDefault,
    this.hostEditable = false,
    this.hostAuthoringPhase = kReadingHouseHostAuthoringPhaseFuture,
    this.scheduledDate,
    this.hour = kReadingHouseDefaultHour,
    this.minute = kReadingHouseDefaultMinute,
  });

  final int eventNumber;
  final int flowDay;
  final String title;
  final String section;
  final String theme;
  final String privatePrompt;
  final String hostNote;
  final bool sharePromptOnComplete;
  final String sittingSource;
  final bool hostEditable;
  final String hostAuthoringPhase;
  final DateTime? scheduledDate;
  final int hour;
  final int minute;

  bool get isHostAuthored =>
      sittingSource == kReadingHouseSittingSourceHostAuthored ||
      hostAuthoringPhase == kReadingHouseHostAuthoringPhaseEnabled ||
      hostEditable;

  ReadingHouseSitting copyWith({
    int? eventNumber,
    int? flowDay,
    String? title,
    String? section,
    String? theme,
    String? privatePrompt,
    String? hostNote,
    bool? sharePromptOnComplete,
    String? sittingSource,
    bool? hostEditable,
    String? hostAuthoringPhase,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    int? hour,
    int? minute,
  }) {
    return ReadingHouseSitting(
      eventNumber: eventNumber ?? this.eventNumber,
      flowDay: flowDay ?? this.flowDay,
      title: title ?? this.title,
      section: section ?? this.section,
      theme: theme ?? this.theme,
      privatePrompt: privatePrompt ?? this.privatePrompt,
      hostNote: hostNote ?? this.hostNote,
      sharePromptOnComplete:
          sharePromptOnComplete ?? this.sharePromptOnComplete,
      sittingSource: sittingSource ?? this.sittingSource,
      hostEditable: hostEditable ?? this.hostEditable,
      hostAuthoringPhase: hostAuthoringPhase ?? this.hostAuthoringPhase,
      scheduledDate: clearScheduledDate
          ? null
          : scheduledDate ?? this.scheduledDate,
      hour: (hour ?? this.hour).clamp(0, 23).toInt(),
      minute: (minute ?? this.minute).clamp(0, 59).toInt(),
    );
  }

  ReadingHouseSitting asHostAuthored({
    int? eventNumber,
    int? flowDay,
    DateTime? scheduledDate,
  }) {
    return copyWith(
      eventNumber: eventNumber,
      flowDay: flowDay,
      scheduledDate: scheduledDate,
      sittingSource: kReadingHouseSittingSourceHostAuthored,
      hostEditable: true,
      hostAuthoringPhase: kReadingHouseHostAuthoringPhaseEnabled,
    );
  }
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
    hostNote: 'Choose one fragment privately. Shared surfaces come later.',
  ),
];

int readingHouseDefaultFlowDayForIndex(int index) {
  if (index <= 0) return 1;
  return index * 7;
}

List<ReadingHouseSitting> readingHouseStarterSittingsForAuthoring() {
  return <ReadingHouseSitting>[...kReadingHouseSittings];
}

List<ReadingHouseSitting> normalizeReadingHouseSittingOrder(
  List<ReadingHouseSitting> sittings, {
  bool markAsHostAuthored = false,
}) {
  return <ReadingHouseSitting>[
    for (var index = 0; index < sittings.length; index++)
      (markAsHostAuthored ? sittings[index].asHostAuthored() : sittings[index])
          .copyWith(
            eventNumber: index + 1,
            flowDay: sittings[index].scheduledDate == null
                ? readingHouseDefaultFlowDayForIndex(index)
                : sittings[index].flowDay,
          ),
  ];
}

List<ReadingHouseSitting> addReadingHouseSitting(
  List<ReadingHouseSitting> sittings, {
  ReadingHouseSitting? sitting,
}) {
  final nextIndex = sittings.length;
  final nextNumber = nextIndex + 1;
  final next =
      (sitting ??
              ReadingHouseSitting(
                eventNumber: nextNumber,
                flowDay: readingHouseDefaultFlowDayForIndex(nextIndex),
                title: 'New Sitting',
                section: 'New section',
                theme: 'What should this sitting hold?',
                privatePrompt:
                    'Read privately first, then mark what you are carrying.',
              ))
          .asHostAuthored(
            eventNumber: nextNumber,
            flowDay: readingHouseDefaultFlowDayForIndex(nextIndex),
          );
  return <ReadingHouseSitting>[...sittings, next];
}

List<ReadingHouseSitting> editReadingHouseSitting(
  List<ReadingHouseSitting> sittings,
  int eventNumber,
  ReadingHouseSitting updated,
) {
  return normalizeReadingHouseSittingOrder(<ReadingHouseSitting>[
    for (final sitting in sittings)
      sitting.eventNumber == eventNumber ? updated.asHostAuthored() : sitting,
  ]);
}

List<ReadingHouseSitting> deleteReadingHouseSitting(
  List<ReadingHouseSitting> sittings,
  int eventNumber,
) {
  return normalizeReadingHouseSittingOrder(<ReadingHouseSitting>[
    for (final sitting in sittings)
      if (sitting.eventNumber != eventNumber) sitting.asHostAuthored(),
  ], markAsHostAuthored: true);
}

List<ReadingHouseSitting> reorderReadingHouseSitting(
  List<ReadingHouseSitting> sittings,
  int oldIndex,
  int newIndex,
) {
  if (sittings.isEmpty ||
      oldIndex < 0 ||
      oldIndex >= sittings.length ||
      newIndex < 0 ||
      newIndex >= sittings.length ||
      oldIndex == newIndex) {
    return normalizeReadingHouseSittingOrder(sittings);
  }
  final next = <ReadingHouseSitting>[...sittings];
  final moved = next.removeAt(oldIndex);
  next.insert(newIndex, moved);
  return normalizeReadingHouseSittingOrder(next, markAsHostAuthored: true);
}

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
  return readingHouseLocalDateTimeForUtc(now ?? DateTime.now(), timezone);
}

DateTime readingHouseLocalDateTimeForUtc(
  DateTime instant,
  TrackSkyTimeZone timezone,
) {
  _ensureReadingHouseTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from(instant.toUtc(), location);
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

ReadingHouseOccurrenceSchedule readingHouseScheduleForSitting(
  ReadingHouseSitting sitting,
  DateTime firstStart,
  TrackSkyTimeZone timezone,
) {
  return readingHouseScheduleForDate(
    sitting,
    sitting.scheduledDate ??
        DateTime(
          firstStart.year,
          firstStart.month,
          firstStart.day,
        ).add(Duration(days: sitting.flowDay - 1)),
    timezone,
    hour: sitting.hour,
    minute: sitting.minute,
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
  final schedule = payload['schedule'] is Map
      ? Map<String, dynamic>.from(payload['schedule'] as Map)
      : const <String, dynamic>{};

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

  DateTime? dateValue(String key) {
    final raw = payload[key]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  final source = value(
    'sitting_source',
    fallback?.sittingSource ?? kReadingHouseSittingSourceHostAuthored,
  );
  final authoringPhase = value(
    'host_authoring_phase',
    fallback?.hostAuthoringPhase ?? kReadingHouseHostAuthoringPhaseEnabled,
  );
  final hostEditable = boolValue(
    'host_editable',
    fallback?.hostEditable ??
        (source == kReadingHouseSittingSourceHostAuthored ||
            authoringPhase == kReadingHouseHostAuthoringPhaseEnabled),
  );

  return ReadingHouseSitting(
    eventNumber: eventNumber,
    flowDay:
        parseNumber(payload['flow_day']) ??
        fallback?.flowDay ??
        readingHouseDefaultFlowDayForIndex(eventNumber - 1),
    title: value('sitting_title', fallback?.title ?? 'Sitting $eventNumber'),
    section: value('section', fallback?.section ?? ''),
    theme: value('theme', fallback?.theme ?? ''),
    privatePrompt: value('private_prompt', fallback?.privatePrompt ?? ''),
    hostNote: value('host_note', fallback?.hostNote ?? ''),
    sharePromptOnComplete: boolValue(
      'share_prompt_on_complete',
      fallback?.sharePromptOnComplete ?? false,
    ),
    sittingSource: source,
    hostEditable: hostEditable,
    hostAuthoringPhase: authoringPhase,
    scheduledDate:
        dateValue('scheduled_local_date') ??
        dateValue('local_date') ??
        _dateFromSchedule(schedule),
    hour:
        parseNumber(schedule['hour']) ??
        parseNumber(payload['hour']) ??
        fallback?.hour ??
        kReadingHouseDefaultHour,
    minute:
        parseNumber(schedule['minute']) ??
        parseNumber(payload['minute']) ??
        fallback?.minute ??
        kReadingHouseDefaultMinute,
  );
}

DateTime? _dateFromSchedule(Map<String, dynamic> schedule) {
  final raw = schedule['local_date']?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
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
    'sitting_source': sitting.sittingSource,
    'host_editable': sitting.hostEditable,
    'host_authoring_phase': sitting.hostAuthoringPhase,
    'scheduled_local_date': _readingHouseDateToken(schedule.startLocal),
    'book_title': plan.displayBookTitle,
    if (plan.editionNote.trim().isNotEmpty)
      'edition_note': plan.editionNote.trim(),
    'house_question': plan.displayQuestion,
    'house_mode': plan.normalizedMode,
    'house_state': plan.state,
    'private_first': true,
    'reader_sitting_phase': 'enabled',
    'writing_required': false,
    'unlock_gate': 'reading_position_mark',
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'presence_options': const <String>[
      kReadingHousePositionCarrying,
      kReadingHousePositionNotYet,
    ],
    'private_margin': const <String, dynamic>{
      'phase': 'enabled',
      'storage': 'local_only',
      'shared_fragments': kReadingHouseSharedFragmentsPhaseEnabled,
      'house_margin': kReadingHouseHouseMarginPhaseEnabled,
      'auto_copy_to_house_margin': false,
    },
    'house_presence': readingHouseCompanyPresenceContract(plan),
    'share_prompt_on_complete': false,
    'share_prompt_future': sitting.sharePromptOnComplete,
    'discussion_model': const <String, dynamic>{
      'phase': 'fragment_replies',
      'reply_depth': 1,
      'likes': false,
      'ranking': false,
      'discussion_room': false,
      'house_margin': kReadingHouseHouseMarginPhaseEnabled,
      'host_announcements': kReadingHouseHostAnnouncementsPhaseEnabled,
      'house_chat': kReadingHouseHouseChatPhaseEnabled,
      'house_chat_role': 'support_lane',
      'pod_chat': false,
    },
    'schedule': <String, dynamic>{
      'type': schedule.scheduleType,
      'fallback': schedule.fallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'local_date': _readingHouseDateToken(schedule.startLocal),
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
    'Private margin\nWrite a reflection, save a short note, or choose sit without writing. The margin stays on this device.',
    'Position gate\nChoose Carrying or Not yet before marking Observed, Partly, or Skipped. Carrying opens opt-in shared fragments; Not yet remains private waiting.',
    'House presence\nOpen House and Company House are derived from joined shared-calendar members. Shared fragments are chosen by the reader for this house and sitting only; one-level replies stay attached to those fragments.',
    'House margin\nHouse members can add shared quotes, questions, links, and between-sitting notes. Private margin text is not copied into the house margin.',
    'Host announcements\nHosts can leave schedule, pace, recap, or note announcements for joined house members.',
    'Fragment replies\nReplies stay one level deep on the chosen fragment. No likes, ranking, discussion room, or nested thread is active.',
    'House Chat\nA full-house support lane opens for Company House logistics and quick notes. The reading stays in sittings, fragments, and the house margin.',
    if (hostNote.isNotEmpty) 'Host note\n$hostNote',
    'Completion\nUse Observed when the sitting was honestly held, Partly when the reading position is partial, and Skipped when you did not sit. In company mode, Carrying and Not yet become factual presence states when shared surfaces arrive.',
  ].join('\n\n');
}

String readingHouseTimingLabel(ReadingHouseSitting sitting) {
  return 'Day ${sitting.flowDay} · ${_readingHouseTimeLabel(sitting.hour, sitting.minute)} local';
}

String _readingHouseDateToken(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _readingHouseTimeLabel(int hour, int minute) {
  final normalizedHour = hour.clamp(0, 23).toInt();
  final normalizedMinute = minute.clamp(0, 59).toInt();
  final period = normalizedHour >= 12 ? 'PM' : 'AM';
  final displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12;
  return '$displayHour:${normalizedMinute.toString().padLeft(2, '0')} $period';
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
