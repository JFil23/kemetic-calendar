import 'package:flutter/material.dart';

import '../track_sky_flow.dart';
import 'the_kar_models.dart';

const String kKarFlowKey = 'the-kar';
const String kKarTitle = 'The Kꜣr';
const String kKarGlyph = '𓉐';
const String kKarOverview =
    'Build a private shrine of five impossible scenes, then return through them without making anything new.';
const String kKarHistoricalBadgeText =
    'In Kemet, a kꜣr was a shrine that held a presence in a fixed place. '
    'This walk gives five imagined scenes their own places so memory can '
    'return to them in order.';
const int kKarDefaultHour = 9;
const int kKarDefaultMinute = 0;

@immutable
class KarOccurrence {
  const KarOccurrence({
    required this.stageIndex,
    required this.stage,
    required this.startLocal,
    required this.endLocal,
    required this.title,
    required this.netjer,
    required this.cycleId,
  });

  final int stageIndex;
  final KarStage stage;
  final DateTime startLocal;
  final DateTime endLocal;
  final String title;
  final KarNetjer netjer;
  final String cycleId;

  bool get isWalk => stageIndex == 5;

  Map<String, dynamic> behaviorPayload({required int cycleSequence}) =>
      <String, dynamic>{
        'kind': isWalk ? 'maat_kar_walk' : 'maat_kar_scene',
        'flow_key': kKarFlowKey,
        'kar_cycle_id': cycleId,
        'kar_cycle_sequence': cycleSequence,
        'kar_netjer': netjer.key,
        'kar_stage_index': stageIndex,
        'kar_day': stage.day,
        'kar_place': stage.place,
        'kar_entry_source': isWalk ? 'closing_walk' : 'cycle_sitting',
        'kar_schema_version': 1,
      };
}

List<KarOccurrence> karSchedule({
  required DateTime anchorDate,
  required KarNetjer netjer,
  required String cycleId,
}) {
  final start = DateUtils.dateOnly(anchorDate);
  return List<KarOccurrence>.unmodifiable([
    for (var index = 0; index < kKarStages.length; index++)
      KarOccurrence(
        stageIndex: index,
        stage: kKarStages[index],
        startLocal: DateTime(
          start.year,
          start.month,
          start.day + kKarStages[index].day - 1,
          kKarDefaultHour,
          kKarDefaultMinute,
        ),
        endLocal: DateTime(
          start.year,
          start.month,
          start.day + kKarStages[index].day - 1,
          kKarDefaultHour + 1,
          kKarDefaultMinute,
        ),
        title: index == 5 ? 'Walk the kꜣr' : netjer.labels[index],
        netjer: netjer,
        cycleId: cycleId,
      ),
  ]);
}

String karFlowNotes({
  required KarNetjer netjer,
  required String cycleId,
  required int cycleSequence,
  required DateTime anchorDate,
  TrackSkyTimeZone timezone = TrackSkyTimeZone.pacific,
}) {
  final day = DateUtils.dateOnly(anchorDate);
  return <String>[
    'mode=gregorian',
    'split=1',
    'maat=$kKarFlowKey',
    'kar_netjer=${netjer.key}',
    'kar_cycle_id=$cycleId',
    'kar_cycle_sequence=$cycleSequence',
    'kar_anchor=${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    'kar_tz=${timezone.key}',
    'kar_schema_version=1',
  ].join(';');
}

KarNetjer karNetjerFromPayload(Map<String, dynamic>? payload) =>
    KarNetjerContent.fromKey(payload?['kar_netjer']?.toString() ?? 'djehuty');

KarNetjer karNetjerFromFlowNotes(String? notes) {
  for (final token in notes?.split(';') ?? const <String>[]) {
    final parts = token.split('=');
    if (parts.length == 2 && parts.first.trim() == 'kar_netjer') {
      return KarNetjerContent.fromKey(parts.last.trim());
    }
  }
  return KarNetjer.djehuty;
}

int karStageIndexFromPayload(Map<String, dynamic>? payload) {
  final raw = payload?['kar_stage_index'];
  return ((raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '')) ?? 0)
      .clamp(0, 5)
      .toInt();
}
