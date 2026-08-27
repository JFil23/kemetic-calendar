import 'package:flutter/foundation.dart';

import '../domain/observing_place.dart';
import '../domain/sky_catalog.dart';
import '../domain/sky_instrument_data.dart';
import '../services/sky_instrument_data_provider.dart';
import 'follow_sky_view_time_policy.dart';
import 'turning_meaning.dart';

@immutable
class FollowSkyPresentationContext {
  const FollowSkyPresentationContext({required this.place});

  final ObservingPlace place;

  static const losAngeles = FollowSkyPresentationContext(
    place: ObservingPlace(
      latitude: 34.0522,
      longitude: -118.2437,
      ianaTimeZone: 'America/Los_Angeles',
      label: 'Los Angeles',
      source: ObservingPlaceSource.manual,
    ),
  );
}

@immutable
class FollowSkySurfaceCopy {
  const FollowSkySurfaceCopy({
    required this.lensLabel,
    required this.lensStatement,
    required this.reflectionPrompt,
    required this.timingLabel,
    required this.dragLead,
    required this.intentionContext,
  });

  final String lensLabel;
  final String lensStatement;
  final String reflectionPrompt;
  final String timingLabel;
  final String dragLead;
  final String intentionContext;
}

@immutable
class FollowSkyInstrumentVisualSpec {
  const FollowSkyInstrumentVisualSpec({
    required this.family,
    required this.semanticLabel,
  });

  final SkyInstrumentFamily family;
  final String semanticLabel;
}

@immutable
class FollowSkyObservationPresentationModel {
  const FollowSkyObservationPresentationModel({
    required this.skyEventId,
    required this.title,
    required this.dateLabel,
    required this.locationLabel,
    required this.ianaTimeZone,
    required this.meaning,
    required this.intention,
    required this.instrument,
    required this.focusInstant,
    required this.initialSelection,
    required this.visual,
    required this.copy,
  });

  final String skyEventId;
  final String title;
  final String dateLabel;
  final String locationLabel;
  final String ianaTimeZone;
  final TurningMeaning meaning;
  final String? intention;
  final SkyInstrumentData instrument;
  final DateTime focusInstant;
  final DateTime initialSelection;
  final FollowSkyInstrumentVisualSpec visual;
  final FollowSkySurfaceCopy copy;
}

class FollowSkyObservationPresentationModelFactory {
  const FollowSkyObservationPresentationModelFactory({
    required this.instrumentProvider,
    this.meaningResolver = const TurningMeaningResolver(),
    this.context = FollowSkyPresentationContext.losAngeles,
  });

  final SkyInstrumentDataProvider instrumentProvider;
  final TurningMeaningResolver meaningResolver;
  final FollowSkyPresentationContext context;

  Future<FollowSkyObservationPresentationModel> build({
    required SkyCatalog catalog,
    required String skyEventId,
    String? intention,
  }) async {
    final anchor = catalog.byId(skyEventId);
    if (anchor == null || anchor.mergedIntoId != null) {
      throw StateError('$skyEventId is not a materializable observing night.');
    }
    final night = catalog.observingNight(anchor);
    final resolved = await instrumentProvider.resolve(
      night: night,
      place: context.place,
    );
    final instrument = _asWallTime(resolved);
    final meaning = meaningResolver.forNight(night);
    final resolvedFocus = followSkyFocusInstant(instrument);
    final focus = resolvedFocus.isBefore(instrument.viewingWindowStart)
        ? instrument.viewingWindowStart
        : resolvedFocus.isAfter(instrument.viewingWindowEnd)
        ? instrument.viewingWindowEnd
        : resolvedFocus;
    final family = instrument.family;
    return FollowSkyObservationPresentationModel(
      skyEventId: night.skyEventId,
      title: night.displayName,
      dateLabel: _formatDate(focus),
      locationLabel: context.place.label,
      ianaTimeZone: context.place.ianaTimeZone,
      meaning: meaning,
      intention: intention?.trim().isEmpty == true ? null : intention?.trim(),
      instrument: instrument,
      focusInstant: focus,
      initialSelection: focus,
      visual: FollowSkyInstrumentVisualSpec(
        family: family,
        semanticLabel: _semanticLabel(family),
      ),
      copy: FollowSkySurfaceCopy(
        lensLabel: meaning.significanceLabel,
        lensStatement: meaning.surfaceStatement ?? meaning.observation,
        reflectionPrompt: meaning.reflectionPrompt ?? meaning.personalQuestion,
        timingLabel: _timingLabel(instrument),
        dragLead:
            family == SkyInstrumentFamily.solarThreshold ||
                family == SkyInstrumentFamily.solarEclipse
            ? 'Drag the light. '
            : 'Drag the night. ',
        intentionContext:
            'Kept with this turning when you added Follow the sky.',
      ),
    );
  }
}

String _semanticLabel(SkyInstrumentFamily family) => switch (family) {
  SkyInstrumentFamily.lunarPath => 'lunar path',
  SkyInstrumentFamily.meteorWindow => 'meteor activity window',
  SkyInstrumentFamily.opposition => 'planet opposition window',
  SkyInstrumentFamily.elongation => 'planet elongation relationship',
  SkyInstrumentFamily.conjunction => 'conjunction separation',
  SkyInstrumentFamily.solarThreshold => 'solar threshold',
  SkyInstrumentFamily.solarEclipse => 'solar eclipse contacts',
};

String _timingLabel(SkyInstrumentData data) => switch (data) {
  LunarPathData value => 'Full phase · ${_formatTime(value.phaseInstant)}',
  MeteorWindowData value =>
    'Peak window · ${_formatTime(value.peakWindowStart)}–${_formatTime(value.peakWindowEnd)}',
  OppositionData value => 'Closest · ${_formatTime(value.closestApproach)}',
  ElongationData value => 'Maximum · ${_formatTime(value.maximumAt)}',
  ConjunctionData value => 'Closest · ${_formatTime(value.closestApproach)}',
  SolarThresholdData value =>
    'Threshold · ${_formatTime(value.thresholdInstant)}',
  SolarEclipseData value => 'Greatest · ${_formatTime(value.greatestEclipse)}',
};

String _formatDate(DateTime value) {
  const weekdays = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${weekdays[value.weekday - 1]} · ${months[value.month - 1]} ${value.day}';
}

String _formatTime(DateTime value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
}

DateTime _wall(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
);

SkyPositionSample _wallPosition(SkyPositionSample sample) => SkyPositionSample(
  at: _wall(sample.at),
  azimuthDegrees: sample.azimuthDegrees,
  altitudeDegrees: sample.altitudeDegrees,
);

SkyInstrumentData _asWallTime(SkyInstrumentData data) => switch (data) {
  LunarPathData value => LunarPathData(
    viewingWindowStart: _wall(value.viewingWindowStart),
    viewingWindowEnd: _wall(value.viewingWindowEnd),
    rise: value.rise == null ? null : _wall(value.rise!),
    transit: value.transit == null ? null : _wall(value.transit!),
    set: value.set == null ? null : _wall(value.set!),
    moonSamples: value.moonSamples.map(_wallPosition).toList(growable: false),
    eclipseContacts: value.eclipseContacts
        .map(
          (contact) => LunarEclipseContact(
            kind: contact.kind,
            at: _wall(contact.at),
            azimuthDegrees: contact.azimuthDegrees,
            altitudeDegrees: contact.altitudeDegrees,
            locallyVisible: contact.locallyVisible,
          ),
        )
        .toList(growable: false),
    phaseInstant: _wall(value.phaseInstant),
    provenance: value.provenance,
    visibility: value.visibility,
  ),
  MeteorWindowData value => MeteorWindowData(
    radiantName: value.radiantName,
    peakWindowStart: _wall(value.peakWindowStart),
    peakWindowEnd: _wall(value.peakWindowEnd),
    estimatedZenithalHourlyRate: value.estimatedZenithalHourlyRate,
    provenance: value.provenance,
    visibility: value.visibility,
  ),
  OppositionData value => OppositionData(
    bodyName: value.bodyName,
    closestApproach: _wall(value.closestApproach),
    altitudeSamples: value.altitudeSamples
        .map(_wallPosition)
        .toList(growable: false),
    viewingWindowStart: _wall(value.viewingWindowStart),
    viewingWindowEnd: _wall(value.viewingWindowEnd),
    provenance: value.provenance,
    visibility: value.visibility,
  ),
  ElongationData value => ElongationData(
    bodyName: value.bodyName,
    direction: value.direction,
    maximumElongationDegrees: value.maximumElongationDegrees,
    maximumAt: _wall(value.maximumAt),
    viewingWindowStart: _wall(value.viewingWindowStart),
    viewingWindowEnd: _wall(value.viewingWindowEnd),
    provenance: value.provenance,
    visibility: value.visibility,
  ),
  ConjunctionData value => ConjunctionData(
    bodyA: value.bodyA,
    bodyB: value.bodyB,
    closestApproach: _wall(value.closestApproach),
    minimumSeparationDegrees: value.minimumSeparationDegrees,
    separationSamples: value.separationSamples
        .map(
          (sample) =>
              SeparationSample(at: _wall(sample.at), degrees: sample.degrees),
        )
        .toList(growable: false),
    viewingWindowStart: _wall(value.viewingWindowStart),
    viewingWindowEnd: _wall(value.viewingWindowEnd),
    provenance: value.provenance,
    visibility: value.visibility,
  ),
  SolarThresholdData value => SolarThresholdData(
    thresholdKind: value.thresholdKind,
    thresholdInstant: _wall(value.thresholdInstant),
    solarSamples: value.solarSamples.map(_wallPosition).toList(growable: false),
    viewingWindowStart: _wall(value.viewingWindowStart),
    viewingWindowEnd: _wall(value.viewingWindowEnd),
    provenance: value.provenance,
    visibility: value.visibility,
  ),
  SolarEclipseData value => SolarEclipseData(
    greatestEclipse: _wall(value.greatestEclipse),
    contactInstants: value.contactInstants.map(_wall).toList(growable: false),
    globalVisibilitySummary: value.globalVisibilitySummary,
    viewingWindowStart: _wall(value.viewingWindowStart),
    viewingWindowEnd: _wall(value.viewingWindowEnd),
    provenance: value.provenance,
    visibility: value.visibility,
  ),
};
