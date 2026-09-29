import '../../../core/day_key.dart';
import 'pronunciation_catalog.dart';

/// Calendar data adapters. Invalid identities and leap day six have no clip.
class PronunciationIdentity {
  static PronunciationKey? day(int month, int day) {
    if (month < 1 || month > 13 || day < 1 || day > (month == 13 ? 5 : 30)) {
      return null;
    }
    return PronunciationKey.forDay(month, day);
  }

  static PronunciationKey? dayKey(String value) {
    final parts = value.split('_');
    if (parts.length != 3) return null;
    final dayNumber = int.tryParse(parts[1]);
    if (dayNumber == null) return null;
    for (var month = 1; month <= 13; month++) {
      if (parts.first == monthKeyFor(month) ||
          (month == 13 && parts.first == 'epagomenal')) {
        return day(month, dayNumber);
      }
    }
    return null;
  }

  static PronunciationKey? compass(String value) {
    if (value == 'epagomenal') return PronunciationKey.month(13);
    final match = RegExp(r'^m(\d{2})_d([123])$').firstMatch(value);
    if (match == null) return null;
    final month = int.parse(match[1]!);
    return day(month, (int.parse(match[2]!) - 1) * 10 + 1);
  }

  static PronunciationKey? period(String value) {
    final match = RegExp(
      r'^\d{4}-\d{2}-\d{2}:\d{4}-\d{2}-\d{2}:(\d{1,2})-([123])$',
    ).firstMatch(value);
    if (match == null) return null;
    return day(int.parse(match[1]!), (int.parse(match[2]!) - 1) * 10 + 1);
  }
}
