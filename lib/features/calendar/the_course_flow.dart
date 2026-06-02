import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'the_course_context.dart';
import 'track_sky_flow.dart';

const String kTheCourseFlowKey = 'the-course';
const String kTheCourseTitle = 'The Course';
const String kTheCourseGlyph = '𓈐';
const String kTheCourseTagline = 'Know where you are in time. Act from there.';
const String kTheCourseEnrollmentCopy =
    'Required: open the ḥꜣw day card, read where you are in time, and do one time-appropriate act.';
const int kTheCourseDefaultMiddayHour = 11;
const int kTheCourseDefaultMiddayMinute = 0;
const int kTheCourseEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

const String kTheCourseOverview =
    'Three times per decan, locate yourself in the solar day, the ten-day decan, and the active Kemetic season, then do one time-appropriate act. '
    'The Course is a very low-burden thirty-day Ma\'at flow with nine sittings: Daily Course, Decan Course, and Seasonal Course. '
    'It is not an astronomy flow, a morning rite, passive day-card reading, or generic seasonal journaling; it makes the ḥꜣw calendar a practice document.';

enum CourseScheduleKind { solarDawn, solarDusk, midday, sealEvening }

extension CourseScheduleKindX on CourseScheduleKind {
  String get key {
    switch (this) {
      case CourseScheduleKind.solarDawn:
        return 'solar_dawn';
      case CourseScheduleKind.solarDusk:
        return 'solar_dusk';
      case CourseScheduleKind.midday:
        return 'midday';
      case CourseScheduleKind.sealEvening:
        return 'seal_evening';
    }
  }

  String get label {
    switch (this) {
      case CourseScheduleKind.solarDawn:
        return 'Dawn';
      case CourseScheduleKind.solarDusk:
        return 'Dusk';
      case CourseScheduleKind.midday:
        return '11:00 local';
      case CourseScheduleKind.sealEvening:
        return 'Sunset + 30 min';
    }
  }
}

enum CourseLens { neutral, ra, khepri }

extension CourseLensX on CourseLens {
  String get key {
    switch (this) {
      case CourseLens.neutral:
        return 'neutral';
      case CourseLens.ra:
        return 'ra';
      case CourseLens.khepri:
        return 'khepri';
    }
  }

  String get label {
    switch (this) {
      case CourseLens.neutral:
        return 'Neutral';
      case CourseLens.ra:
        return 'Ra';
      case CourseLens.khepri:
        return 'Khepri';
    }
  }

  String get detailLine {
    switch (this) {
      case CourseLens.neutral:
        return '';
      case CourseLens.ra:
        return 'Let Ra frame the day as a visible course: rise, travel, complete, pass through night.';
      case CourseLens.khepri:
        return 'Let Khepri frame each opening as emergence achieved by completing the passage in order.';
    }
  }
}

class CourseEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final CourseScheduleKind scheduleKind;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final List<String> optionalSteps;
  final String? sourceNote;
  final bool requiresDayCard;
  final bool seasonAware;
  final bool sharePromptOnComplete;

  const CourseEvent({
    required this.eventNumber,
    required this.flowDay,
    required this.decanSection,
    required this.title,
    required this.scheduleKind,
    required this.durationMinutesMin,
    required this.durationMinutesMax,
    required this.spokenLine,
    required this.steps,
    this.optionalSteps = const <String>[],
    this.sourceNote,
    this.requiresDayCard = true,
    this.seasonAware = false,
    this.sharePromptOnComplete = false,
  });
}

class CourseOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final String scheduleType;
  final String fallback;
  final int? middayHour;
  final int? middayMinute;

  const CourseOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocationName,
    required this.scheduleType,
    required this.fallback,
    this.middayHour,
    this.middayMinute,
  });
}

const List<CourseEvent> kTheCourseEvents = <CourseEvent>[
  CourseEvent(
    eventNumber: 1,
    flowDay: 1,
    decanSection: 'Daily Course',
    title: 'The Solar Course: Locate at Dawn',
    scheduleKind: CourseScheduleKind.solarDawn,
    durationMinutesMin: 3,
    durationMinutesMax: 5,
    spokenLine:
        'Riser, Riser! Beetle, Beetle! Your life is related to mine; my life is related to yours. Sustenance is for my morning, Abundance is for my evening. Famine will not have control of this life.',
    steps: <String>[
      'Open the ḥꜣw day card. Read the Kemetic date, decan name, and Ma\'at principle before you close it.',
      'Name one thing appropriate for the morning part of this particular day.',
      'Do one opening act that matches the day instead of only the task list.',
    ],
    optionalSteps: <String>[
      'Face east for a moment. This is the direction of return.',
    ],
    sourceNote:
        'In Kemet, the day began at dawn. Pyramid Texts Utterance 388 addresses the returning Sun directly as Riser and Beetle.',
  ),
  CourseEvent(
    eventNumber: 2,
    flowDay: 5,
    decanSection: 'Daily Course',
    title: 'The Solar Course: Mark the Transition',
    scheduleKind: CourseScheduleKind.solarDusk,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'The Sun\'s daily movement is a journey from birth to death, and its rebirth at dawn is made possible by what passes through the night. I have completed the visible portion of this day.',
    steps: <String>[
      'Open the ḥꜣw day card before you mark the transition.',
      'At dusk, stop one thing for thirty seconds and notice that the visible portion of the day has ended.',
      'Name one thing accomplished in the visible hours and one thing that will pass through night.',
    ],
    sourceNote:
        'The solar course moves from dawn birth through dusk completion and the hidden night passage.',
  ),
  CourseEvent(
    eventNumber: 3,
    flowDay: 9,
    decanSection: 'Daily Course',
    title: 'The Solar Course: The Pattern',
    scheduleKind: CourseScheduleKind.solarDawn,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'Riser, Riser! Beetle, Beetle! Your life is related to mine; my life is related to yours.',
    steps: <String>[
      'Open the ḥꜣw day card. Note the Kemetic date and read the Ma\'at principle aloud.',
      'Write one honest sentence about what the daily rhythm looked like in the last nine days.',
      'Name one shift in how you experience morning, midday, evening, or night.',
    ],
  ),
  CourseEvent(
    eventNumber: 4,
    flowDay: 11,
    decanSection: 'Decan Course',
    title: 'The Decan Course: Locate in Ten-Day Time',
    scheduleKind: CourseScheduleKind.solarDawn,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'The sky\'s door has been opened to you. You shall set course to your proper work and make your yearly supply.',
    steps: <String>[
      'Open the ḥꜣw day card before anything else.',
      'Read the decan name, ten-day theme, and Ma\'at principle for the current decan.',
      'Name what this specific decan calls for in your life right now.',
    ],
    sourceNote:
        'The decans divided Kemetic time into ten-day star arcs. Knowing the decan meant knowing the quality of the time.',
  ),
  CourseEvent(
    eventNumber: 5,
    flowDay: 15,
    decanSection: 'Decan Course',
    title: 'The Decan Course: One Decan Act',
    scheduleKind: CourseScheduleKind.midday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine: 'The sky\'s door has been opened to you. Set your course.',
    steps: <String>[
      'Open the ḥꜣw day card. Read the day\'s Ma\'at principle and daily theme.',
      'Name one thing you will do today, or already did today, that belongs to this decan\'s quality.',
      'Write: In this decan, the time calls for ___. Today I did ___.',
    ],
  ),
  CourseEvent(
    eventNumber: 6,
    flowDay: 19,
    decanSection: 'Decan Course',
    title: 'The Decan Course: The Arc Closes',
    scheduleKind: CourseScheduleKind.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'I have hoed emmer for you, I have plowed barley for you: barley for your supply, emmer for your yearly supply.',
    steps: <String>[
      'Open the ḥꜣw day card before the decan closes.',
      'Return to the decan\'s Ma\'at principle and ask whether it was lived at all.',
      'Name one completion from this decan that can feed the next ten days.',
    ],
    optionalSteps: <String>[
      'Read the next decan name and theme before the evening closes.',
    ],
  ),
  CourseEvent(
    eventNumber: 7,
    flowDay: 21,
    decanSection: 'Seasonal Course',
    title: 'The Seasonal Course: Locate in the Year',
    scheduleKind: CourseScheduleKind.solarDawn,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'I ordered everything in its proper place. Hapy gave me honor on every field, so that none hungered during my years, none thirsted therein.',
    steps: <String>[
      'Open the ḥꜣw day card and locate the current season before speaking.',
      'Read the season branch shown here and name what this season asks in your life.',
      'Write one active sentence: This is [season]. It asks me to ___.',
    ],
    seasonAware: true,
    sourceNote:
        'The Kemetic seasons were operational instructions: Akhet receives, Peret emerges, Shemu completes, and transition marks threshold.',
  ),
  CourseEvent(
    eventNumber: 8,
    flowDay: 25,
    decanSection: 'Seasonal Course',
    title: 'The Seasonal Course: One Seasonal Act',
    scheduleKind: CourseScheduleKind.midday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'You shall set course to the Marsh of Reeds, where you will farm emmer, reap barley, and make your yearly supply. The sky\'s door is open.',
    steps: <String>[
      'Open the ḥꜣw day card and read the current season.',
      'Name one act that belongs specifically to this season.',
      'Do the act today and write one sentence confirming it was done.',
    ],
    seasonAware: true,
  ),
  CourseEvent(
    eventNumber: 9,
    flowDay: 29,
    decanSection: 'Seasonal Course',
    title: 'The Course Holds',
    scheduleKind: CourseScheduleKind.solarDawn,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'Riser, Riser! Beetle, Beetle! Your life is related to mine; mine is related to yours. Sustenance is for the morning. Abundance is for the evening. I have ordered what I can in its proper place.',
    steps: <String>[
      'Open the ḥꜣw day card. Let it be the first thing you read.',
      'Speak only the closing truth lines that are true: I know the decan, I know the season, I greeted dawn, I did a decan act, I did a seasonal act.',
      'Name one practice from these thirty days that you will continue past the flow.',
      'Speak the final line: The course is continuous. I am in it.',
    ],
    optionalSteps: <String>[
      'If you share, share only one practice you will continue. Do not turn the private record into performance.',
    ],
    sourceNote:
        'The Course closes at dawn because the practice is not finished; it is established as a way of moving through time.',
    sharePromptOnComplete: true,
  ),
];

bool _courseTimeZonesInitialized = false;

void _ensureCourseTimeZonesInitialized() {
  if (_courseTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _courseTimeZonesInitialized = true;
}

DateTime defaultTheCourseStartDate(TrackSkyTimeZone timezone, {DateTime? now}) {
  final nowLocal = theCourseNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final todayStart = courseDawnScheduleForDate(
    today,
    timezone,
    durationMinutes: kTheCourseEvents.first.durationMinutesMax,
  ).startLocal;
  if (!todayStart.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime theCourseNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureCourseTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

CourseOccurrenceSchedule courseScheduleForDate(
  CourseEvent event,
  DateTime date,
  TrackSkyTimeZone timezone, {
  int middayHour = kTheCourseDefaultMiddayHour,
  int middayMinute = kTheCourseDefaultMiddayMinute,
}) {
  switch (event.scheduleKind) {
    case CourseScheduleKind.solarDawn:
      return courseDawnScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case CourseScheduleKind.solarDusk:
      return courseDuskScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case CourseScheduleKind.midday:
      return courseMiddayScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: middayHour,
        minute: middayMinute,
      );
    case CourseScheduleKind.sealEvening:
      return courseEveningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
  }
}

CourseOccurrenceSchedule courseDawnScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final startUtc = base.startUtc;
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return CourseOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_astronomical_dawn',
    fallback: 'sunrise_minus_15_minutes',
  );
}

CourseOccurrenceSchedule courseDuskScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kEveningThresholdDefaultFallbackMinutes,
  );
  final startUtc = base.usedFallback
      ? base.startUtc
      : base.startUtc.subtract(const Duration(minutes: 20));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return CourseOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_sunset',
    fallback: 'user_selected_evening_time',
  );
}

CourseOccurrenceSchedule courseMiddayScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  int hour = kTheCourseDefaultMiddayHour,
  int minute = kTheCourseDefaultMiddayMinute,
}) {
  _ensureCourseTimeZonesInitialized();
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
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  return CourseOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: false,
    timezone: timezone,
    referenceLocationName: timezone.label,
    scheduleType: 'fixed_local_midday',
    fallback: 'user_editable_local_time',
    middayHour: clampedHour,
    middayMinute: clampedMinute,
  );
}

CourseOccurrenceSchedule courseEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kTheCourseEveningFallbackMinutes,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return CourseOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_sunset_plus_30_minutes',
    fallback: 'user_selected_evening_time_plus_30_minutes',
  );
}

String courseEventTitle(CourseEvent event) {
  return 'Course ${event.eventNumber}: ${event.title}';
}

String courseActionId(CourseEvent event) {
  return 'the-course-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

CourseEvent? courseEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kTheCourseEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

CourseLens? courseLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in CourseLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

CourseLens courseLensFromNotes(
  String? notes, {
  CourseLens fallback = CourseLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('course_lens=')) continue;
    return courseLensFromKey(trimmed.substring('course_lens='.length)) ??
        fallback;
  }
  return fallback;
}

bool isCourseFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.theCourse,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

CourseEvent? courseEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = courseEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-course-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = courseEventByNumber(parseNumber(actionMatch?.group(1)));
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Course\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return courseEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalCourseDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
  CourseCalendarContext? context,
}) {
  if (!isCourseFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = courseEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      courseLensFromKey(behaviorPayload?['lens']?.toString()) ??
      courseLensFromNotes(flowNotes);
  return courseDetailText(event, lens: lens, context: context);
}

Map<String, dynamic> courseBehaviorPayload({
  required CourseEvent event,
  required CourseOccurrenceSchedule schedule,
  required CourseLens lens,
  CourseCalendarContext? context,
}) {
  return <String, dynamic>{
    'kind': 'maat_course_event',
    'flow_key': kTheCourseFlowKey,
    'event_number': event.eventNumber,
    'flow_day': event.flowDay,
    'decan_section': event.decanSection,
    'schedule_kind': event.scheduleKind.key,
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'burden': 'very_low',
    'props_profile': const <String, dynamic>{
      'required': <String>['day_card'],
      'optional': <String>[],
    },
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'missed_event_rule': 'expire_quietly',
    'requires_day_card': event.requiresDayCard,
    'season_aware': event.seasonAware,
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'schedule': <String, dynamic>{
      'type': schedule.scheduleType,
      'fallback': schedule.fallback,
      'used_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocationName,
      if (schedule.middayHour != null) 'midday_hour': schedule.middayHour,
      if (schedule.middayMinute != null) 'midday_minute': schedule.middayMinute,
    },
    if (context != null)
      'calendar_context': <String, dynamic>{
        'kemetic_month': context.kMonth,
        'kemetic_day': context.kDay,
        'decan_name': context.decanName,
        'season': context.seasonKey,
      },
    'lens': lens.key,
  };
}

String courseDetailText(
  CourseEvent event, {
  required CourseLens lens,
  CourseCalendarContext? context,
}) {
  final optional = event.optionalSteps
      .map((step) => '- $step')
      .join('\n')
      .trim();
  final lensLine = lens.detailLine.trim();
  final contextLines = <String>[
    if (context != null) 'Date: ${context.kemeticDateLabel}',
    if (context != null) 'Decan: ${context.decanName}',
    if (context != null) 'Ma\'at principle: ${context.maatPrinciple}',
    if (context != null) 'Season: ${context.seasonLabel}',
  ].join('\n');
  return <String>[
    'Purpose\n${_coursePurpose(event)}',
    if (contextLines.trim().isNotEmpty) 'Current ḥꜣw Context\n$contextLines',
    if (event.seasonAware && context != null)
      'Season Instruction\n${context.seasonInstruction}',
    'Day Card\nOpen the ḥꜣw day card before this sitting. Read the date, decan, season, and Ma\'at principle before choosing the act.',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (optional.isNotEmpty) 'Optional\n$optional',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String courseTimingLabel(CourseEvent event) {
  switch (event.scheduleKind) {
    case CourseScheduleKind.solarDawn:
      return 'Day ${event.flowDay} · dawn';
    case CourseScheduleKind.solarDusk:
      return 'Day ${event.flowDay} · dusk';
    case CourseScheduleKind.midday:
      return 'Day ${event.flowDay} · 11:00 local';
    case CourseScheduleKind.sealEvening:
      return 'Day ${event.flowDay} · sunset + 30 min';
  }
}

String _numberedLines(List<String> lines) {
  return lines
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value}')
      .join('\n');
}

String _coursePurpose(CourseEvent event) {
  switch (event.eventNumber) {
    case 1:
      return 'Begin by locating yourself in the returning solar day.';
    case 2:
      return 'Mark dusk as the transition where the visible day completes.';
    case 3:
      return 'Close the daily-course decan by naming the rhythm that actually formed.';
    case 4:
      return 'Locate yourself inside the current ten-day decan.';
    case 5:
      return 'Do one act that belongs to this decan rather than generic time.';
    case 6:
      return 'Seal the decan arc by naming what it asked and what was given.';
    case 7:
      return 'Locate yourself in Akhet, Peret, Shemu, or transition.';
    case 8:
      return 'Do one act that belongs to the active Kemetic season.';
    case 9:
      return 'Confirm the day card, decan, and season as continuing practice.';
  }
  return 'Know where you are in time. Act from there.';
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
