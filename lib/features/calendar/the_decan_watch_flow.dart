import 'maat_flow_identity.dart';
import 'the_course_context.dart';
import 'track_sky_flow.dart';

const String kDecanWatchFlowKey = 'the-decan-watch';
const String kDecanWatchTitle = 'The Decan Watch';
const String kDecanWatchGlyph = '✵𓇳';
const String kDecanWatchTagline =
    'The sky has been counting. Stand under it and add your count.';
const String kDecanWatchOverview =
    'At each decan boundary, go outside, look up, note one line about the sky, read the day card, and name one bearing for the next ten days. The Decan Watch is an ongoing night-sky rhythm, not a drift-repair flow.';
const String kDecanWatchConfidenceLabel =
    'The ten-day sky observation pattern is attested in Kemetic astronomical practice. This household form is a careful modern reconstruction.';
const String kDecanWatchRequiredLine =
    'The Imperishable Stars never set. They mark where I am in time. The decans have counted this night for longer than I can reckon. I stand under them and add my count.';

const int kDecanWatchDefaultHour = 21;
const int kDecanWatchDefaultMinute = 0;
const int kDecanWatchEditableFromHour = 18;
const int kDecanWatchEditableToHour = 23;
const int kDecanWatchDurationMinutes = 15;

enum DecanWatchLens { neutral, ra, nut }

extension DecanWatchLensX on DecanWatchLens {
  String get key {
    switch (this) {
      case DecanWatchLens.neutral:
        return 'neutral';
      case DecanWatchLens.ra:
        return 'ra';
      case DecanWatchLens.nut:
        return 'nut';
    }
  }

  String get label {
    switch (this) {
      case DecanWatchLens.neutral:
        return 'Neutral';
      case DecanWatchLens.ra:
        return 'Ra';
      case DecanWatchLens.nut:
        return 'Nut';
    }
  }

  String get detailLine {
    switch (this) {
      case DecanWatchLens.neutral:
        return '';
      case DecanWatchLens.ra:
        return 'Let Ra frame the watch as the Sun passing hidden through the Duat while the night sky keeps count.';
      case DecanWatchLens.nut:
        return 'Let Nut frame the watch as standing beneath the sky-body that receives dusk and births dawn.';
    }
  }
}

class DecanWatchOccurrence {
  final int kYear;
  final int kMonth;
  final int decanIndex;
  final int decanStartDay;
  final int globalDecanId;
  final String decanName;
  final String eventDateIso;
  final TrackSkyTimeZone timezone;
  final int scheduleHour;
  final int scheduleMinute;
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;

  const DecanWatchOccurrence({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.decanStartDay,
    required this.globalDecanId,
    required this.decanName,
    required this.eventDateIso,
    required this.timezone,
    required this.scheduleHour,
    required this.scheduleMinute,
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
  });
}

DecanWatchLens? decanWatchLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in DecanWatchLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

DecanWatchLens decanWatchLensFromNotes(
  String? notes, {
  DecanWatchLens fallback = DecanWatchLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('dw_lens=')) continue;
    return decanWatchLensFromKey(trimmed.substring('dw_lens='.length)) ??
        fallback;
  }
  return fallback;
}

String decanWatchEventTitle(DecanWatchOccurrence occurrence) {
  return 'Decan Watch: ${occurrence.decanName}';
}

String decanWatchActionId(DecanWatchOccurrence occurrence) {
  return 'the-decan-watch-${occurrence.kYear}-m${occurrence.kMonth}-d${occurrence.decanStartDay}';
}

String decanWatchClientEventId({
  required int flowId,
  required DecanWatchOccurrence occurrence,
}) {
  return 'decan-watch:$flowId:${occurrence.kYear}:${occurrence.kMonth}:${occurrence.decanIndex}';
}

Map<String, dynamic> decanWatchBehaviorPayload({
  required DecanWatchOccurrence occurrence,
  required DecanWatchLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_decan_watch',
    'flow_key': kDecanWatchFlowKey,
    'k_year': occurrence.kYear,
    'k_month': occurrence.kMonth,
    'decan_index': occurrence.decanIndex,
    'decan_start_day': occurrence.decanStartDay,
    'global_decan_id': occurrence.globalDecanId,
    'decan_name': occurrence.decanName,
    'missed_event_rule': 'expire_quietly',
    'outdoor_required': true,
    'completion_options': const <String>[
      'observed',
      'observed_from_inside',
      'skipped',
    ],
    'duration_minutes': kDecanWatchDurationMinutes,
    'lens': lens.key,
    'schedule': <String, dynamic>{
      'type': 'local_time',
      'hour': occurrence.scheduleHour,
      'minute': occurrence.scheduleMinute,
      'editable_from_hour': kDecanWatchEditableFromHour,
      'editable_to_hour': kDecanWatchEditableToHour,
      'timezone': occurrence.timezone.key,
      'iana_timezone': occurrence.timezone.ianaName,
    },
  };
}

bool isDecanWatchFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.decanWatch,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

String decanWatchDetailText(
  DecanWatchOccurrence occurrence, {
  required DecanWatchLens lens,
  CourseCalendarContext? context,
}) {
  final lensLine = lens.detailLine.trim();
  final dayCardLine = context == null
      ? 'Open the ḥꜣw day card for this decan opening. Read the decan name, quality, and Ma’at principle.'
      : 'Open the ḥꜣw day card for ${context.kemeticDateLabel}. Read ${context.decanName} and the Ma’at principle: ${context.maatPrinciple}';
  return <String>[
    'Confidence\n$kDecanWatchConfidenceLabel',
    'Purpose\nStand under the night sky at the opening of ${occurrence.decanName} and take one bearing for the next ten days.',
    'Outdoor\nGo outside if you can. If safety, access, or weather prevents that, stand at a window or threshold and mark the completion as observed from inside.',
    'Words\n"$kDecanWatchRequiredLine"',
    'Steps\n${_numberedLines(const <String>['Go outside. Phone down; open sky for at least one minute.', 'Look up. Face north first for the Imperishable Stars, then scan the full sky.', 'Speak the required line.', 'Note the sky in one line. A clouded sky is still a valid record.', 'Open the ḥꜣw day card. Read the decan name, quality, and Ma’at principle.', 'Reset intention. Name one bearing for the coming ten days.'])}',
    'Day Card\n$dayCardLine',
    'Local Notes\nSky note and decan intention stay on this device only. They are not synced in event detail or completion metadata.',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
    'Source\nThe decans were thirty-six star groups used to keep night time and ten-day calendar order. The household act here reconstructs that sky-counting pattern without requiring star identification.',
  ].join('\n\n');
}

String decanWatchMilestoneMessage(int observedCount) {
  switch (observedCount) {
    case 3:
      return 'One decan month in the Kemetic sky.';
    case 12:
      return 'One third of the decan year observed.';
    case 36:
      return 'The full decan cycle. The Watchers have revived. The sky has returned.';
  }
  return '';
}

String _numberedLines(List<String> lines) {
  return lines
      .asMap()
      .entries
      .map((entry) {
        return '${entry.key + 1}. ${entry.value}';
      })
      .join('\n');
}
