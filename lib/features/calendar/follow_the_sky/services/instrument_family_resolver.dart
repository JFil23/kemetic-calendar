import '../domain/sky_event_kind.dart';
import '../domain/sky_instrument_data.dart';
import '../domain/sky_observing_night.dart';

class InstrumentFamilyResolver {
  const InstrumentFamilyResolver();

  SkyInstrumentFamily resolve(SkyObservingNight night) {
    return switch (night.serviceKind) {
      SkyEventKind.fullMoon ||
      SkyEventKind.lunarEclipse => SkyInstrumentFamily.lunarPath,
      SkyEventKind.meteorShower => SkyInstrumentFamily.meteorWindow,
      SkyEventKind.planetOpposition => SkyInstrumentFamily.opposition,
      SkyEventKind.planetElongation => SkyInstrumentFamily.elongation,
      SkyEventKind.planetConjunction => SkyInstrumentFamily.conjunction,
      SkyEventKind.equinox ||
      SkyEventKind.solstice => SkyInstrumentFamily.solarThreshold,
      SkyEventKind.solarEclipse => SkyInstrumentFamily.solarEclipse,
    };
  }
}
