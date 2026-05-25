import 'package:mobile/core/day_key.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;
import 'package:mobile/widgets/kemetic_day_info.dart';

import 'decan_metadata.dart';
import 'kemetic_month_metadata.dart';

class CourseCalendarContext {
  final int kYear;
  final int kMonth;
  final int kDay;
  final String dayKey;
  final bool dayCardAvailable;
  final String kemeticDateLabel;
  final String monthLabel;
  final String decanName;
  final String maatPrinciple;
  final String seasonKey;
  final String seasonLabel;
  final String seasonInstruction;

  const CourseCalendarContext({
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.dayKey,
    required this.dayCardAvailable,
    required this.kemeticDateLabel,
    required this.monthLabel,
    required this.decanName,
    required this.maatPrinciple,
    required this.seasonKey,
    required this.seasonLabel,
    required this.seasonInstruction,
  });
}

CourseCalendarContext courseContextForKemeticDate({
  required int kYear,
  required int kMonth,
  required int kDay,
}) {
  final month = getMonthById(kMonth);
  final rawDayKey = kemeticDayKey(kMonth, kDay);
  final info = KemeticDayData.getInfoForDay(rawDayKey);
  final dayKey = info == null ? 'unknown_${kDay}_$kYear' : rawDayKey;
  final seasonKey = _seasonKeyFor(month.season);
  final monthLabel = month.displayFull;
  final decanName =
      info?.decanName ??
      DecanMetadata.decanNameFor(kMonth: kMonth, kDay: kDay, expanded: true);
  return CourseCalendarContext(
    kYear: kYear,
    kMonth: kMonth,
    kDay: kDay,
    dayKey: dayKey,
    dayCardAvailable: info != null,
    kemeticDateLabel: '$monthLabel $kDay',
    monthLabel: monthLabel,
    decanName: decanName,
    maatPrinciple: info?.maatPrinciple ?? 'Read today\'s Ma\'at principle.',
    seasonKey: seasonKey,
    seasonLabel: _seasonLabelFor(month.season),
    seasonInstruction: courseSeasonInstruction(month.season),
  );
}

CourseCalendarContext courseContextForGregorianDate(DateTime date) {
  final k = KemeticMath.fromGregorian(date);
  return courseContextForKemeticDate(
    kYear: k.kYear,
    kMonth: k.kMonth,
    kDay: k.kDay,
  );
}

String courseSeasonInstruction(KemeticSeason season) {
  switch (season) {
    case KemeticSeason.akhet:
      return 'Receive; do not force. Name what is submerged, preparing, or not yet ready to be worked.';
    case KemeticSeason.peret:
      return 'Emerge; plant or tend what the flood prepared. Name what is ready for its first concrete act.';
    case KemeticSeason.shemu:
      return 'Complete; gather, release, or redistribute. Name what is ready to leave the field.';
    case KemeticSeason.transition:
      return 'Threshold days: note the crossing explicitly before choosing what carries forward.';
  }
}

String _seasonKeyFor(KemeticSeason season) {
  switch (season) {
    case KemeticSeason.akhet:
      return 'akhet';
    case KemeticSeason.peret:
      return 'peret';
    case KemeticSeason.shemu:
      return 'shemu';
    case KemeticSeason.transition:
      return 'transition';
  }
}

String _seasonLabelFor(KemeticSeason season) {
  switch (season) {
    case KemeticSeason.akhet:
      return 'Akhet - Inundation';
    case KemeticSeason.peret:
      return 'Peret - Emergence';
    case KemeticSeason.shemu:
      return 'Shemu - Harvest';
    case KemeticSeason.transition:
      return 'Transition - Days upon the Year';
  }
}
