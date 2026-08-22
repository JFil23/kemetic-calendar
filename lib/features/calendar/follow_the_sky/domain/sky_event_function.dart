/// System-owned purpose for a sky turning. Not chosen by the user.
enum SkyEventFunction {
  measure,
  reveal,
  reconsider,
  turn,
  attend,
}

extension SkyEventFunctionX on SkyEventFunction {
  String get wireName {
    switch (this) {
      case SkyEventFunction.measure:
        return 'measure';
      case SkyEventFunction.reveal:
        return 'reveal';
      case SkyEventFunction.reconsider:
        return 'reconsider';
      case SkyEventFunction.turn:
        return 'turn';
      case SkyEventFunction.attend:
        return 'attend';
    }
  }

  String get displayLabel {
    switch (this) {
      case SkyEventFunction.measure:
        return 'Measure';
      case SkyEventFunction.reveal:
        return 'Reveal';
      case SkyEventFunction.reconsider:
        return 'Reconsider';
      case SkyEventFunction.turn:
        return 'Turn';
      case SkyEventFunction.attend:
        return 'Attend';
    }
  }

  static SkyEventFunction parse(String raw) {
    switch (raw.trim()) {
      case 'measure':
        return SkyEventFunction.measure;
      case 'reveal':
        return SkyEventFunction.reveal;
      case 'reconsider':
        return SkyEventFunction.reconsider;
      case 'turn':
        return SkyEventFunction.turn;
      case 'attend':
        return SkyEventFunction.attend;
      default:
        throw FormatException('Unknown SkyEventFunction: $raw');
    }
  }

  static SkyEventFunction forKind(String kindWire) {
    switch (kindWire) {
      case 'equinox':
        return SkyEventFunction.measure;
      case 'fullMoon':
        return SkyEventFunction.reveal;
      case 'lunarEclipse':
      case 'solarEclipse':
        return SkyEventFunction.reconsider;
      case 'solstice':
        return SkyEventFunction.turn;
      case 'meteorShower':
      case 'planetOpposition':
      case 'planetElongation':
      case 'planetConjunction':
        return SkyEventFunction.attend;
      default:
        return SkyEventFunction.attend;
    }
  }
}
