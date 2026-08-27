import '../../domain/sky_instrument_data.dart';
import '../follow_sky_observation_presentation_model.dart';
import '../turning_meaning.dart';

/// Deterministic reference specimen for the approved Full Moon presentation.
/// Production consumes the same generic model type for every observing night.
final FollowSkyObservationPresentationModel
losAngelesFullMoonPresentationFixture = _losAngelesFullMoonFixture();

FollowSkyObservationPresentationModel _losAngelesFullMoonFixture() {
  final rise = DateTime(2026, 8, 27, 19, 17, 18);
  final u1 = DateTime(2026, 8, 27, 19, 33, 23);
  final maximum = DateTime(2026, 8, 27, 21, 12, 49);
  final fullPhase = DateTime(2026, 8, 27, 21, 18);
  final u4 = DateTime(2026, 8, 27, 22, 52, 14);
  final p4 = DateTime(2026, 8, 28, 0, 2, 2);
  final transit = DateTime(2026, 8, 28, 1, 0, 9);
  final set = DateTime(2026, 8, 28, 6, 51);

  const meaning = TurningMeaningResolver.approvedLunarEclipse;
  final instrument = LunarPathData(
    viewingWindowStart: rise,
    viewingWindowEnd: set,
    rise: rise,
    transit: transit,
    set: set,
    moonSamples: <SkyPositionSample>[
      SkyPositionSample(at: rise, azimuthDegrees: 101.8824, altitudeDegrees: 0),
      SkyPositionSample(
        at: u1,
        azimuthDegrees: 104.0382,
        altitudeDegrees: 2.6274,
      ),
      SkyPositionSample(
        at: DateTime(2026, 8, 27, 20),
        azimuthDegrees: 108.105,
        altitudeDegrees: 7.934,
      ),
      SkyPositionSample(
        at: maximum,
        azimuthDegrees: 119.0314,
        altitudeDegrees: 21.2959,
      ),
      SkyPositionSample(
        at: fullPhase,
        azimuthDegrees: 120.311,
        altitudeDegrees: 22.512,
      ),
      SkyPositionSample(
        at: u4,
        azimuthDegrees: 139.7716,
        altitudeDegrees: 37.2084,
      ),
      SkyPositionSample(
        at: p4,
        azimuthDegrees: 159.9779,
        altitudeDegrees: 44.6312,
      ),
      SkyPositionSample(
        at: transit,
        azimuthDegrees: 179.9999,
        altitudeDegrees: 46.9393,
      ),
      SkyPositionSample(
        at: DateTime(2026, 8, 28, 2),
        azimuthDegrees: 201.08,
        altitudeDegrees: 44.93,
      ),
      SkyPositionSample(
        at: DateTime(2026, 8, 28, 3, 30),
        azimuthDegrees: 225.41,
        altitudeDegrees: 35.84,
      ),
      SkyPositionSample(
        at: DateTime(2026, 8, 28, 5),
        azimuthDegrees: 245.82,
        altitudeDegrees: 20.16,
      ),
      SkyPositionSample(at: set, azimuthDegrees: 261.52, altitudeDegrees: 0),
    ],
    eclipseContacts: <LunarEclipseContact>[
      LunarEclipseContact(
        kind: LunarEclipseContactKind.p1,
        at: DateTime(2026, 8, 27, 18, 23, 36),
        azimuthDegrees: 94.8891,
        altitudeDegrees: -11.0243,
        locallyVisible: false,
      ),
      LunarEclipseContact(
        kind: LunarEclipseContactKind.u1,
        at: u1,
        azimuthDegrees: 104.0382,
        altitudeDegrees: 2.6274,
        locallyVisible: true,
      ),
      LunarEclipseContact(
        kind: LunarEclipseContactKind.maximum,
        at: maximum,
        azimuthDegrees: 119.0314,
        altitudeDegrees: 21.2959,
        locallyVisible: true,
      ),
      LunarEclipseContact(
        kind: LunarEclipseContactKind.u4,
        at: u4,
        azimuthDegrees: 139.7716,
        altitudeDegrees: 37.2084,
        locallyVisible: true,
      ),
      LunarEclipseContact(
        kind: LunarEclipseContactKind.p4,
        at: p4,
        azimuthDegrees: 159.9779,
        altitudeDegrees: 44.6312,
        locallyVisible: true,
      ),
    ],
    phaseInstant: fullPhase,
    provenance: const SkyInstrumentProvenance(
      source: 'presentation-fixture',
      sourceVersion: 'los-angeles-2026-08-27',
      calculationVersion: 'verified-live-specimen',
    ),
    visibility: const SkyInstrumentVisibility(
      isLocal: true,
      isTimeFallback: false,
      summary: 'Los Angeles local sky',
    ),
  );
  return FollowSkyObservationPresentationModel(
    skyEventId: 'full-moon-2026-08-28',
    title: 'Full Moon + Partial Lunar Eclipse',
    dateLabel: 'THU · AUG 27',
    locationLabel: 'Los Angeles',
    ianaTimeZone: 'America/Los_Angeles',
    meaning: meaning,
    intention: 'self confidence',
    instrument: instrument,
    focusInstant: maximum,
    initialSelection: maximum,
    visual: const FollowSkyInstrumentVisualSpec(
      family: SkyInstrumentFamily.lunarPath,
      semanticLabel: 'lunar path',
    ),
    copy: const FollowSkySurfaceCopy(
      lensLabel: 'ENDURE',
      lensStatement: 'Stay true when conditions change.',
      reflectionPrompt:
          'What did staying true to your choice look like tonight?',
      timingLabel: 'Full phase · 9:18 PM',
      dragLead: 'Drag the night. ',
      intentionContext: 'Kept with this turning when you added Follow the sky.',
    ),
  );
}
