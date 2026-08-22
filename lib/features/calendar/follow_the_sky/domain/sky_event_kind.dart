enum SkyEventKind {
  equinox,
  solstice,
  fullMoon,
  lunarEclipse,
  solarEclipse,
  meteorShower,
  planetOpposition,
  planetElongation,
  planetConjunction,
}

extension SkyEventKindX on SkyEventKind {
  String get wireName {
    switch (this) {
      case SkyEventKind.equinox:
        return 'equinox';
      case SkyEventKind.solstice:
        return 'solstice';
      case SkyEventKind.fullMoon:
        return 'fullMoon';
      case SkyEventKind.lunarEclipse:
        return 'lunarEclipse';
      case SkyEventKind.solarEclipse:
        return 'solarEclipse';
      case SkyEventKind.meteorShower:
        return 'meteorShower';
      case SkyEventKind.planetOpposition:
        return 'planetOpposition';
      case SkyEventKind.planetElongation:
        return 'planetElongation';
      case SkyEventKind.planetConjunction:
        return 'planetConjunction';
    }
  }

  static SkyEventKind parse(String raw) {
    switch (raw.trim()) {
      case 'equinox':
        return SkyEventKind.equinox;
      case 'solstice':
        return SkyEventKind.solstice;
      case 'fullMoon':
        return SkyEventKind.fullMoon;
      case 'lunarEclipse':
        return SkyEventKind.lunarEclipse;
      case 'solarEclipse':
        return SkyEventKind.solarEclipse;
      case 'meteorShower':
        return SkyEventKind.meteorShower;
      case 'planetOpposition':
        return SkyEventKind.planetOpposition;
      case 'planetElongation':
        return SkyEventKind.planetElongation;
      case 'planetConjunction':
        return SkyEventKind.planetConjunction;
      default:
        throw FormatException('Unknown SkyEventKind: $raw');
    }
  }
}
