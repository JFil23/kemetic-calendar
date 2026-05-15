part of 'kemetic_day_info.dart';

/// Model for Kemetic day information
class KemeticDayInfo {
  final String kemeticDate;
  final String season;
  final String month;
  final String decanName;
  final String starCluster;
  final String maatPrinciple;
  final String cosmicContext;
  final List<DecanDayInfo> decanFlow;
  final MeduNeterKey meduNeter;

  KemeticDayInfo({
    required this.kemeticDate,
    required this.season,
    required this.month,
    required this.decanName,
    required this.starCluster,
    required this.maatPrinciple,
    required this.cosmicContext,
    required this.decanFlow,
    required this.meduNeter,
  });
}

class DecanDayInfo {
  final int day;
  final String theme;
  final String action;
  final String reflection;

  DecanDayInfo({
    required this.day,
    required this.theme,
    required this.action,
    required this.reflection,
  });
}

class MeduNeterKey {
  final String glyph;
  final String colorFrequency;
  final String mantra;

  MeduNeterKey({
    required this.glyph,
    required this.colorFrequency,
    required this.mantra,
  });
}
