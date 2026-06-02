import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kMoonReturnFlowKey = 'the-moon-return';
const String kMoonReturnTitle = 'The Moon Return';
const String kMoonReturnGlyph = '𓇹';
const String kMoonReturnTagline =
    'The eye empties and fills. Receive what the cycle gives.';
const String kMoonReturnConfidenceLabel =
    'Draws on new/full moon timing in Kemetic sacred calendars and the Eye of Heru cycle.';
const int kMoonReturnDurationMinutes = 5;

const String kMoonReturnOverview =
    'At each new moon, set down one thing at dusk. At each full moon, go outside at moonrise and name what filled. '
    'The Moon Return is an ongoing Ma\'at flow for the Eye of Heru cycle: emptying, restoration, and wholeness across each lunar month. '
    'Enrollment opens only at the new moon threshold.';

enum MoonReturnEventKind { emptyEye, wholeEye }

extension MoonReturnEventKindX on MoonReturnEventKind {
  String get key {
    switch (this) {
      case MoonReturnEventKind.emptyEye:
        return 'new';
      case MoonReturnEventKind.wholeEye:
        return 'full';
    }
  }

  String get title {
    switch (this) {
      case MoonReturnEventKind.emptyEye:
        return 'The Empty Eye';
      case MoonReturnEventKind.wholeEye:
        return 'The Whole Eye';
    }
  }

  String get payloadKind {
    switch (this) {
      case MoonReturnEventKind.emptyEye:
        return 'maat_moon_return_new';
      case MoonReturnEventKind.wholeEye:
        return 'maat_moon_return_full';
    }
  }
}

enum MoonReturnCopyVariant {
  standard,
  solarEclipseNew,
  lunarEclipseFull,
  blueMoonFull,
  supermoonFull,
  wepRonpetNew,
}

extension MoonReturnCopyVariantX on MoonReturnCopyVariant {
  String get key {
    switch (this) {
      case MoonReturnCopyVariant.standard:
        return 'standard';
      case MoonReturnCopyVariant.solarEclipseNew:
        return 'solar_eclipse_new';
      case MoonReturnCopyVariant.lunarEclipseFull:
        return 'lunar_eclipse_full';
      case MoonReturnCopyVariant.blueMoonFull:
        return 'blue_moon_full';
      case MoonReturnCopyVariant.supermoonFull:
        return 'supermoon_full';
      case MoonReturnCopyVariant.wepRonpetNew:
        return 'wep_ronpet_new';
    }
  }

  String get label {
    switch (this) {
      case MoonReturnCopyVariant.standard:
        return 'Standard';
      case MoonReturnCopyVariant.solarEclipseNew:
        return 'Solar eclipse';
      case MoonReturnCopyVariant.lunarEclipseFull:
        return 'Blood moon';
      case MoonReturnCopyVariant.blueMoonFull:
        return 'Blue moon';
      case MoonReturnCopyVariant.supermoonFull:
        return 'Supermoon';
      case MoonReturnCopyVariant.wepRonpetNew:
        return 'Wep Ronpet eclipse';
    }
  }
}

enum MoonReturnLens { neutral, heru, djehuty }

extension MoonReturnLensX on MoonReturnLens {
  String get key {
    switch (this) {
      case MoonReturnLens.neutral:
        return 'neutral';
      case MoonReturnLens.heru:
        return 'heru';
      case MoonReturnLens.djehuty:
        return 'djehuty';
    }
  }

  String get label {
    switch (this) {
      case MoonReturnLens.neutral:
        return 'Neutral';
      case MoonReturnLens.heru:
        return 'Heru';
      case MoonReturnLens.djehuty:
        return 'Djehuty';
    }
  }

  String get detailLine {
    switch (this) {
      case MoonReturnLens.neutral:
        return '';
      case MoonReturnLens.heru:
        return 'Let Heru frame the month as the Eye taken, restored, and made whole again.';
      case MoonReturnLens.djehuty:
        return 'Let Djehuty frame the month as a clean count: empty, fill, witness, return.';
    }
  }
}

class MoonReturnOccurrence {
  final MoonReturnEventKind kind;
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final String phaseDateIso;
  final MoonReturnCopyVariant variant;
  final bool isBonusBlueMoon;
  final TrackSkyTimeZone timezone;
  final String scheduleType;
  final String referenceLocationName;
  final bool usedFallback;

  const MoonReturnOccurrence({
    required this.kind,
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.phaseDateIso,
    required this.variant,
    required this.isBonusBlueMoon,
    required this.timezone,
    required this.scheduleType,
    required this.referenceLocationName,
    required this.usedFallback,
  });
}

class MoonReturnEnrollmentWindow {
  final DateTime opensAtLocal;
  final DateTime closesAtLocal;
  final DateTime newMoonInstantLocal;
  final DateTime newMoonInstantUtc;
  final String newMoonDateIso;
  final MoonReturnCopyVariant enrollProminence;
  final TrackSkyTimeZone timezone;

  const MoonReturnEnrollmentWindow({
    required this.opensAtLocal,
    required this.closesAtLocal,
    required this.newMoonInstantLocal,
    required this.newMoonInstantUtc,
    required this.newMoonDateIso,
    required this.enrollProminence,
    required this.timezone,
  });
}

MoonReturnLens? moonReturnLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in MoonReturnLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

MoonReturnLens moonReturnLensFromNotes(
  String? notes, {
  MoonReturnLens fallback = MoonReturnLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('moon_lens=')) continue;
    return moonReturnLensFromKey(trimmed.substring('moon_lens='.length)) ??
        fallback;
  }
  return fallback;
}

String moonReturnEventTitle(MoonReturnOccurrence occurrence) {
  final suffix = switch (occurrence.variant) {
    MoonReturnCopyVariant.solarEclipseNew => 'Solar Eclipse',
    MoonReturnCopyVariant.lunarEclipseFull => 'Blood Moon',
    MoonReturnCopyVariant.blueMoonFull => 'Blue Moon',
    MoonReturnCopyVariant.supermoonFull => 'Supermoon',
    MoonReturnCopyVariant.wepRonpetNew => 'Wep Ronpet Eclipse',
    MoonReturnCopyVariant.standard => null,
  };
  return suffix == null
      ? 'Moon Return: ${occurrence.kind.title}'
      : 'Moon Return: ${occurrence.kind.title} ($suffix)';
}

String moonReturnActionId(MoonReturnOccurrence occurrence) {
  return 'the-moon-return-${occurrence.kind.key}-${occurrence.phaseDateIso}';
}

String moonReturnClientEventId({
  required int flowId,
  required MoonReturnOccurrence occurrence,
}) {
  return 'moon-return:$flowId:${occurrence.kind.key}:${occurrence.phaseDateIso}'
      '${occurrence.isBonusBlueMoon ? ':blue' : ''}';
}

Map<String, dynamic> moonReturnBehaviorPayload({
  required MoonReturnOccurrence occurrence,
  required MoonReturnLens lens,
}) {
  return <String, dynamic>{
    'kind': occurrence.kind.payloadKind,
    'flow_key': kMoonReturnFlowKey,
    'phase': occurrence.kind.key,
    'phase_date': occurrence.phaseDateIso,
    'variant': occurrence.variant.key,
    'is_bonus_blue_moon': occurrence.isBonusBlueMoon,
    'missed_event_rule': 'expire_quietly',
    'outdoor_required': true,
    'completion_options': const <String>['observed', 'skipped'],
    'duration_minutes': kMoonReturnDurationMinutes,
    'lens': lens.key,
    'schedule': <String, dynamic>{
      'type': occurrence.scheduleType,
      'timezone': occurrence.timezone.key,
      'iana_timezone': occurrence.timezone.ianaName,
      'reference_location': occurrence.referenceLocationName,
      'used_fallback': occurrence.usedFallback,
    },
  };
}

bool isMoonReturnFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.moonReturn,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

MoonReturnEventKind? moonReturnKindForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  final phase = behaviorPayload?['phase']?.toString().trim().toLowerCase();
  if (phase == 'new') return MoonReturnEventKind.emptyEye;
  if (phase == 'full') return MoonReturnEventKind.wholeEye;
  final kind = behaviorPayload?['kind']?.toString().trim().toLowerCase();
  if (kind == 'maat_moon_return_new') return MoonReturnEventKind.emptyEye;
  if (kind == 'maat_moon_return_full') return MoonReturnEventKind.wholeEye;
  final id = actionId?.trim().toLowerCase() ?? '';
  if (id.contains('the-moon-return-new')) return MoonReturnEventKind.emptyEye;
  if (id.contains('the-moon-return-full')) return MoonReturnEventKind.wholeEye;
  final normalizedTitle = title?.trim().toLowerCase() ?? '';
  if (normalizedTitle.contains('empty eye')) {
    return MoonReturnEventKind.emptyEye;
  }
  if (normalizedTitle.contains('whole eye')) {
    return MoonReturnEventKind.wholeEye;
  }
  return null;
}

String moonReturnDetailText(
  MoonReturnOccurrence occurrence, {
  required MoonReturnLens lens,
}) {
  final lensLine = lens.detailLine.trim();
  final variant = _moonReturnVariantLine(occurrence.variant);
  return <String>[
    'Purpose\n${_moonReturnPurpose(occurrence.kind)}',
    if (variant.isNotEmpty) 'Variant\n$variant',
    'Words\n"${_moonReturnSpokenLine(occurrence.kind)}"',
    'Steps\n${_numberedLines(_moonReturnSteps(occurrence.kind, occurrence.variant))}',
    'Outdoor\n${_moonReturnOutdoorLine(occurrence.kind)}',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String _moonReturnPurpose(MoonReturnEventKind kind) {
  switch (kind) {
    case MoonReturnEventKind.emptyEye:
      return 'Stand under the empty sky at the new moon and set down one thing from the last cycle.';
    case MoonReturnEventKind.wholeEye:
      return 'Stand under the full moon sky and name one thing that filled in this cycle.';
  }
}

String _moonReturnSpokenLine(MoonReturnEventKind kind) {
  switch (kind) {
    case MoonReturnEventKind.emptyEye:
      return 'The eye has gone. The sky is cleared. I set down what the last cycle carried and let the dark receive it.';
    case MoonReturnEventKind.wholeEye:
      return 'Horus has filled you complete with his eye. The Eye of Heru is whole. I receive what has been given.';
  }
}

List<String> _moonReturnSteps(
  MoonReturnEventKind kind,
  MoonReturnCopyVariant variant,
) {
  switch (kind) {
    case MoonReturnEventKind.emptyEye:
      return <String>[
        'Step outside at dusk. You are not looking for the moon; you are standing with the empty sky.',
        'Name one thing from the last lunar cycle that you are setting down.',
        if (variant == MoonReturnCopyVariant.wepRonpetNew)
          'Name the year-opening threshold plainly: what should not cross into the opened year?'
        else if (variant == MoonReturnCopyVariant.solarEclipseNew)
          'If this is an eclipse window, name the rare darkness as a marked threshold.',
        'Speak the line, then return inside.',
      ].where((line) => line.trim().isNotEmpty).toList();
    case MoonReturnEventKind.wholeEye:
      return <String>[
        'Go outside at moonrise. If clouds block the moon, face its direction and stand under the sky anyway.',
        'Stand for one minute in the full moon sky.',
        if (variant == MoonReturnCopyVariant.blueMoonFull)
          'Notice that the Eye fills twice this Gregorian month; receive what filled again.'
        else if (variant == MoonReturnCopyVariant.lunarEclipseFull)
          'If the moon passes through shadow tonight, name the restoration that returns from shadow.'
        else if (variant == MoonReturnCopyVariant.supermoonFull)
          'Notice the nearest full Eye of the year and receive accordingly.',
        'Name one thing that has filled since the new moon: In this cycle, ___ filled.',
        'Speak the line, then return inside.',
      ].where((line) => line.trim().isNotEmpty).toList();
  }
}

String _moonReturnOutdoorLine(MoonReturnEventKind kind) {
  switch (kind) {
    case MoonReturnEventKind.emptyEye:
      return 'The new moon event requires going outside at dusk, but it does not require seeing the moon.';
    case MoonReturnEventKind.wholeEye:
      return 'The full moon event requires going outside at moonrise. Clouds are acceptable; presence under the sky is the act.';
  }
}

String _moonReturnVariantLine(MoonReturnCopyVariant variant) {
  switch (variant) {
    case MoonReturnCopyVariant.standard:
      return '';
    case MoonReturnCopyVariant.solarEclipseNew:
      return 'The new moon is also a solar eclipse. The Eye covers the Sun: this threshold is marked.';
    case MoonReturnCopyVariant.lunarEclipseFull:
      return 'Tonight the Eye passes through shadow and returns. Use the blood moon framing.';
    case MoonReturnCopyVariant.blueMoonFull:
      return 'The Eye fills twice this month. This is a bonus Whole Eye for users already in the practice.';
    case MoonReturnCopyVariant.supermoonFull:
      return 'Tonight the Eye is nearest and brighter than ordinary. Receive what has filled.';
    case MoonReturnCopyVariant.wepRonpetNew:
      return 'The Moon covers the Sun as the Kemetic year opens. Begin here with maximum prominence.';
  }
}

String _numberedLines(List<String> lines) {
  return lines
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value}')
      .join('\n');
}
