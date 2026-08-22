/// Follow the Sky presentation adapter for day-sheet / join callers.
///
/// **Cut 3:** Markdown/prose parsing is deleted. This file loads the V2 canonical
/// UTC catalog and adapts it to legacy `TrackSkyEvent` shapes so day_view and
/// other Ma'at flows that only need timezone + display helpers keep compiling.
/// New product logic belongs in `follow_the_sky/`.
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'follow_the_sky/follow_the_sky.dart';
import 'track_sky_timezone.dart';

export 'track_sky_timezone.dart';

/// Compatibility presentation types for day-sheet / legacy join callers.
/// Backed by Follow the Sky V2 canonical catalog — no Markdown parsing.
class TrackSkyEventSchedule {
  final String dateIso;
  final String? startTime24;
  final String? endTime24;
  final bool allDay;

  const TrackSkyEventSchedule({
    required this.dateIso,
    required this.startTime24,
    required this.endTime24,
    required this.allDay,
  });
}

class TrackSkyEvent {
  final String category;
  final String title;
  final String exactLabel;
  final String scientificBreakdown;
  final String whatToSee;
  final String bestViewing;
  final String significance;
  final String notes;
  final TrackSkyEventSchedule schedule;
  final String? skyEventId;

  const TrackSkyEvent({
    required this.category,
    required this.title,
    required this.exactLabel,
    required this.scientificBreakdown,
    required this.whatToSee,
    required this.bestViewing,
    required this.significance,
    required this.notes,
    required this.schedule,
    this.skyEventId,
  });

  String get trackingGuidance => bestViewing;
  String get maatReflection => significance;
  String get detailSummary {
    final parts = <String>[
      if (trackingGuidance.trim().isNotEmpty) trackingGuidance.trim(),
      if (maatReflection.trim().isNotEmpty) maatReflection.trim(),
    ];
    return parts.join('\n\n');
  }

  String get teaserText =>
      trackingGuidance.trim().isNotEmpty ? trackingGuidance.trim() : title;

  String get detailText => detailSummary;
}

class TrackSkyFlowData {
  final TrackSkyTimeZone timezone;
  final List<TrackSkyEvent> events;

  const TrackSkyFlowData({required this.timezone, required this.events});
}

const List<String> kTrackSkyCategoryOrder = <String>[
  'Solar Events',
  'Lunar Events',
  'Meteor Showers',
  'Planetary Highlights',
];

final Map<TrackSkyTimeZone, Future<TrackSkyFlowData>> _cache = {};

Future<TrackSkyFlowData> loadTrackSkyFlowData(TrackSkyTimeZone timezone) {
  return _cache.putIfAbsent(timezone, () => _loadV2(timezone));
}

@visibleForTesting
void clearTrackSkyFlowDataCacheForTest() {
  _cache.clear();
}

void clearTrackSkyFlowCache([TrackSkyTimeZone? timezone]) {
  if (timezone == null) {
    _cache.clear();
    return;
  }
  _cache.remove(timezone);
}

Future<TrackSkyFlowData> _loadV2(TrackSkyTimeZone timezone) async {
  _ensureTz();
  final catalog = await SkyCatalogRepository().load();
  final materializer = TrackSkyMaterializer(
    toLocal: (utc, iana) {
      final location = tz.getLocation(iana);
      return tz.TZDateTime.from(utc.toUtc(), location);
    },
    toUtc: (local, iana) {
      final location = tz.getLocation(iana);
      return tz.TZDateTime(
        location,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ).toUtc();
    },
  );
  const visibility = SkyVisibilityService();
  final events = <TrackSkyEvent>[];
  for (final sky in catalog.materializableEvents) {
    final night = catalog.observingNight(sky);
    final decision = visibility.decide(night.windowSource);
    final occ = materializer.materialize(
      event: sky,
      night: night,
      ianaTimeZone: timezone.ianaName,
      visibilityNote: decision.userFacingNote,
    );
    final dateIso =
        '${occ.startsAtLocal.year.toString().padLeft(4, '0')}-'
        '${occ.startsAtLocal.month.toString().padLeft(2, '0')}-'
        '${occ.startsAtLocal.day.toString().padLeft(2, '0')}';
    final start24 = occ.allDay
        ? null
        : '${occ.startsAtLocal.hour.toString().padLeft(2, '0')}:'
            '${occ.startsAtLocal.minute.toString().padLeft(2, '0')}';
    final end24 = occ.allDay
        ? null
        : '${occ.endsAtLocal.hour.toString().padLeft(2, '0')}:'
            '${occ.endsAtLocal.minute.toString().padLeft(2, '0')}';
    events.add(
      TrackSkyEvent(
        category: occ.category,
        title: occ.title,
        exactLabel: dateIso,
        scientificBreakdown: sky.source,
        whatToSee: decision.userFacingNote,
        bestViewing: sky.precision == SkyEventPrecision.approximate
            ? 'Best tonight'
            : (start24 == null ? 'All day' : 'Local window $start24–$end24'),
        significance: 'Function: ${sky.function.displayLabel}',
        notes: sky.notes ?? '',
        skyEventId: sky.id,
        schedule: TrackSkyEventSchedule(
          dateIso: dateIso,
          startTime24: start24,
          endTime24: end24,
          allDay: occ.allDay,
        ),
      ),
    );
  }
  events.sort((a, b) => a.schedule.dateIso.compareTo(b.schedule.dateIso));
  return TrackSkyFlowData(timezone: timezone, events: events);
}

void _ensureTz() {
  try {
    tzdata.initializeTimeZones();
  } catch (_) {}
}

TrackSkyTimeZone detectTrackSkyTimeZone() {
  _ensureTz();
  final name = tz.local.name;
  if (name.contains('Los_Angeles') || name.contains('Vancouver')) {
    return TrackSkyTimeZone.pacific;
  }
  if (name.contains('Denver') || name.contains('Phoenix')) {
    return TrackSkyTimeZone.mountain;
  }
  if (name.contains('Chicago')) return TrackSkyTimeZone.central;
  if (name.contains('New_York') || name.contains('Detroit')) {
    return TrackSkyTimeZone.eastern;
  }
  return TrackSkyTimeZone.pacific;
}

List<TrackSkyEvent> upcomingTrackSkyEvents(
  TrackSkyFlowData data, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  return data.events.where((e) {
    final end = trackSkyEventEndLocal(e, data.timezone);
    return !end.isBefore(current);
  }).toList(growable: false);
}

DateTime trackSkyEventStartLocal(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  if (event.schedule.allDay) {
    return DateTime.parse(event.schedule.dateIso);
  }
  final start = event.schedule.startTime24 ?? '09:00';
  return _zonedLocal(timezone, event.schedule.dateIso, start);
}

DateTime trackSkyEventEndLocal(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  if (event.schedule.allDay) {
    final day = DateTime.parse(event.schedule.dateIso);
    return DateTime(day.year, day.month, day.day, 23, 59);
  }
  final end = event.schedule.endTime24 ?? event.schedule.startTime24 ?? '09:00';
  return _zonedLocal(timezone, event.schedule.dateIso, end);
}

DateTime trackSkyEventStartUtc(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  return trackSkyEventStartLocal(event, timezone).toUtc();
}

DateTime? trackSkyEventEndUtc(TrackSkyEvent event, TrackSkyTimeZone timezone) {
  if (event.schedule.allDay) return null;
  return trackSkyEventEndLocal(event, timezone).toUtc();
}

DateTime _zonedLocal(TrackSkyTimeZone timezone, String dateIso, String time24) {
  _ensureTz();
  final parts = time24.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final day = DateTime.parse(dateIso);
  final location = tz.getLocation(timezone.ianaName);
  return tz.TZDateTime(location, day.year, day.month, day.day, hour, minute);
}

String kemeticizeTrackSkyText(String text, {DateTime? anchorDate}) => text;

String normalizeTrackSkyDetailText(String detail) => detail.trim();

String buildTrackSkyNarrativeSummary({
  required String title,
  String? category,
  String? guidance,
  String? reflection,
  String? fallbackGuidance,
}) {
  final parts = <String>[
    if ((guidance ?? '').trim().isNotEmpty) guidance!.trim(),
    if ((reflection ?? '').trim().isNotEmpty) reflection!.trim(),
  ];
  if (parts.isNotEmpty) return parts.join('\n\n');
  final fallback = (fallbackGuidance ?? '').trim();
  if (fallback.isNotEmpty) return fallback;
  return title;
}

/// No-op: V2 schedules come from the catalog materializer.
TrackSkyEventSchedule normalizeTrackSkyViewingSchedule({
  required String title,
  required String category,
  required TrackSkyEventSchedule schedule,
  String? exactLabel,
}) {
  return schedule;
}
