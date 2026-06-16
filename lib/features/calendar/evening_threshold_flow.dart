import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kEveningThresholdFlowKey = 'evening_threshold';
const String kEveningThresholdTitle = 'The Evening Threshold';
const String kEveningThresholdGlyph = '𓇳𓏤𓆄';
const String kEveningThresholdTagline =
    'You named one measure this morning. Before the day closes, place it on the scale.';
const String kEveningThresholdSubtitle =
    'Daily · Carry one thing, land it at evening, decide at morning';
const String kEveningThresholdEnrollmentCopy =
    'Name what you carry today. Tonight you land it honestly; tomorrow morning you choose whether it crosses forward or is released.';
const String kEveningThresholdLinkedTo = 'daily_orientation.chosen_return';
const String kEveningThresholdCarryoverField =
    'daily_orientation.carryover_choice';
const String kEveningThresholdLandingField = 'daily_orientation.landing_status';
const String kEveningThresholdDecisionTable = 'evening_threshold_decisions';
const int kEveningThresholdDurationMinutes = 2;
const int kEveningThresholdEventDurationMinutes = 1;
const int kEveningThresholdDefaultMinutesAfterMidnight = 19 * 60;
const int kEveningThresholdDefaultMorningMinutesAfterMidnight = 7 * 60;
const int kEveningThresholdMaterializedDays = 30;

const String kEveningThresholdOverview =
    'The Evening Threshold is a carry-and-crossing practice. You name one thing to carry into the day, land it honestly at evening, then decide the next morning whether it crosses forward or is released. '
    'What is carried crosses intentionally. What is released is left at the threshold completely.';

enum EveningThresholdEventKind { theReturn, theCarry }

extension EveningThresholdEventKindX on EveningThresholdEventKind {
  String get key {
    switch (this) {
      case EveningThresholdEventKind.theReturn:
        return 'return';
      case EveningThresholdEventKind.theCarry:
        return 'carry';
    }
  }
}

class EveningThresholdEvent {
  const EveningThresholdEvent({
    required this.eventNumber,
    required this.kind,
    required this.title,
    required this.purpose,
    required this.spokenLine,
    required this.deliveryBeat,
    required this.sourceNote,
    required this.completionStatusLabels,
  });

  final int eventNumber;
  final EveningThresholdEventKind kind;
  final String title;
  final String purpose;
  final String spokenLine;
  final String deliveryBeat;
  final String sourceNote;
  final Map<String, String> completionStatusLabels;
}

class DailyEveningThresholdOccurrenceSchedule {
  const DailyEveningThresholdOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.timezone,
    required this.defaultMinutesAfterMidnight,
    required this.scheduledLocalDate,
    required this.orientationLocalDate,
    this.previousOrientationLocalDate,
  });

  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final TrackSkyTimeZone timezone;
  final int defaultMinutesAfterMidnight;
  final DateTime scheduledLocalDate;
  final DateTime orientationLocalDate;
  final DateTime? previousOrientationLocalDate;
}

const List<EveningThresholdEvent>
kEveningThresholdEvents = <EveningThresholdEvent>[
  EveningThresholdEvent(
    eventNumber: 1,
    kind: EveningThresholdEventKind.theReturn,
    title: 'How did it land?',
    purpose:
        'You held something this morning. Before the day closes, place it on the scale - not to judge it, but to know what was true.',
    spokenLine:
        'Read your morning return aloud or silently. "This was what I named. This is what I met."',
    deliveryBeat:
        'Pause. Do not rush this. The day is still happening. Let it settle before you answer.',
    sourceNote:
        'The Kemetic evening rite was not confession. It was reckoning: placing what occurred beside what was intended, and seeing the difference clearly.',
    completionStatusLabels: <String, String>{
      'held': 'I held it.',
      'slipped': 'I slipped.',
      'working': 'I\'m still working on it.',
    },
  ),
  EveningThresholdEvent(
    eventNumber: 2,
    kind: EveningThresholdEventKind.theCarry,
    title: 'What crosses with you?',
    purpose:
        'Morning stands on the other side of the night. Choose whether yesterday\'s carry crosses forward or is released.',
    spokenLine:
        'What I carry, I carry with intention. What I release, I release completely.',
    deliveryBeat:
        'Read yesterday clearly. Then choose what enters today before the day gathers speed.',
    sourceNote:
        'The threshold in Kemetic architecture was a ritual boundary. What crossed was chosen, named, and intentional. Nothing drifted through.',
    completionStatusLabels: <String, String>{
      'carry_forward': 'Carry it forward.',
      'release': 'Release it.',
    },
  ),
];

DateTime _fromZonedDateTime(tz.TZDateTime dateTime) {
  return DateTime(
    dateTime.year,
    dateTime.month,
    dateTime.day,
    dateTime.hour,
    dateTime.minute,
    dateTime.second,
    dateTime.millisecond,
    dateTime.microsecond,
  );
}

DateTime defaultEveningThresholdStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int defaultMinutesAfterMidnight =
      kEveningThresholdDefaultMinutesAfterMidnight,
}) {
  tzdata.initializeTimeZones();
  final location = tz.getLocation(timezone.ianaName);
  final localNow = now == null
      ? tz.TZDateTime.now(location)
      : tz.TZDateTime.from(now.toUtc(), location);
  final hour = defaultMinutesAfterMidnight ~/ 60;
  final minute = defaultMinutesAfterMidnight % 60;
  final todayThreshold = tz.TZDateTime(
    location,
    localNow.year,
    localNow.month,
    localNow.day,
    hour,
    minute,
  );
  final selected = localNow.isAfter(todayThreshold)
      ? todayThreshold.add(const Duration(days: 1))
      : todayThreshold;
  return DateTime(selected.year, selected.month, selected.day);
}

DailyEveningThresholdOccurrenceSchedule dailyEveningThresholdScheduleForDate({
  required DateTime localDate,
  required TrackSkyTimeZone timezone,
  required EveningThresholdEvent event,
  int defaultMinutesAfterMidnight =
      kEveningThresholdDefaultMinutesAfterMidnight,
}) {
  tzdata.initializeTimeZones();
  final location = tz.getLocation(timezone.ianaName);
  final scheduledLocalDate = DateTime(
    localDate.year,
    localDate.month,
    localDate.day,
  );
  final isMorningDecision = event.kind == EveningThresholdEventKind.theCarry;
  final scheduleDate = isMorningDecision
      ? scheduledLocalDate.add(const Duration(days: 1))
      : scheduledLocalDate;
  final scheduleMinutes = isMorningDecision
      ? kEveningThresholdDefaultMorningMinutesAfterMidnight
      : defaultMinutesAfterMidnight;
  final scheduleHour = scheduleMinutes ~/ 60;
  final scheduleMinute = scheduleMinutes % 60;
  final startZoned = tz.TZDateTime(
    location,
    scheduleDate.year,
    scheduleDate.month,
    scheduleDate.day,
    scheduleHour,
    scheduleMinute,
  );
  final endZoned = startZoned.add(
    const Duration(minutes: kEveningThresholdEventDurationMinutes),
  );

  return DailyEveningThresholdOccurrenceSchedule(
    startLocal: _fromZonedDateTime(startZoned),
    endLocal: _fromZonedDateTime(endZoned),
    startUtc: startZoned.toUtc(),
    endUtc: endZoned.toUtc(),
    timezone: timezone,
    defaultMinutesAfterMidnight: scheduleMinutes,
    scheduledLocalDate: _fromZonedDateTime(startZoned),
    orientationLocalDate: isMorningDecision
        ? DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day)
        : scheduledLocalDate,
    previousOrientationLocalDate: isMorningDecision ? scheduledLocalDate : null,
  );
}

String eveningThresholdEventTitle(EveningThresholdEvent event) => event.title;

String eveningThresholdActionId(EveningThresholdEvent event) {
  return 'evening-threshold-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

EveningThresholdEvent? eveningThresholdEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kEveningThresholdEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

EveningThresholdEvent? eveningThresholdEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = eveningThresholdEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'evening-threshold-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = eveningThresholdEventByNumber(
    parseNumber(actionMatch?.group(1)),
  );
  if (actionEvent != null) return actionEvent;

  final normalizedTitle = title?.trim().toLowerCase();
  for (final event in kEveningThresholdEvents) {
    if (event.title.toLowerCase() == normalizedTitle) return event;
  }
  return null;
}

bool isEveningThresholdFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.eveningThreshold,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

Map<String, dynamic> eveningThresholdBehaviorPayload({
  required EveningThresholdEvent event,
  required DailyEveningThresholdOccurrenceSchedule schedule,
}) {
  return <String, dynamic>{
    'kind': 'maat_evening_threshold_event',
    'flow_key': kEveningThresholdFlowKey,
    'event_number': event.eventNumber,
    'event_key': event.kind.key,
    'linked_to': kEveningThresholdLinkedTo,
    'carryover_field': kEveningThresholdCarryoverField,
    'landing_field': kEveningThresholdLandingField,
    'decision_table': kEveningThresholdDecisionTable,
    'duration_minutes': kEveningThresholdEventDurationMinutes,
    'burden': 'low',
    'completion_options': event.completionStatusLabels.keys.toList(),
    'completion_status_labels': event.completionStatusLabels,
    'missed_event_rule': event.kind == EveningThresholdEventKind.theCarry
        ? 'pause_until_explicit_decision'
        : 'skip_next_morning_decision',
    'journal_entry_required': false,
    'delivery_beat': event.deliveryBeat,
    'spoken_line': event.spokenLine,
    'orientation_local_date': _dateOnlyIso(schedule.orientationLocalDate),
    if (schedule.previousOrientationLocalDate != null)
      'previous_orientation_local_date': _dateOnlyIso(
        schedule.previousOrientationLocalDate!,
      ),
    'schedule': <String, dynamic>{
      'type': event.kind == EveningThresholdEventKind.theCarry
          ? 'morning_after_landing'
          : 'daily_local_default_time',
      'default': event.kind == EveningThresholdEventKind.theCarry
          ? '7:00 AM local'
          : '7:00 PM local',
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'default_minutes_after_midnight': schedule.defaultMinutesAfterMidnight,
      'event_offset_minutes': 0,
      if (event.kind == EveningThresholdEventKind.theCarry)
        'requires_prior_landing': true,
    },
  };
}

String eveningThresholdDetailText(EveningThresholdEvent event) {
  return <String>[
    'Purpose\n${event.purpose}',
    'Spoken line\n"${event.spokenLine}"',
    'Delivery beat\n${event.deliveryBeat}',
    'Source note\n${event.sourceNote}',
  ].join('\n\n');
}

String _dateOnlyIso(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
}
