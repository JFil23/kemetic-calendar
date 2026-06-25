import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/event_create_date_picker.dart';

enum DaySheetDatePickerMode { kemetic, gregorian }

class DaySheetDatePickerResult {
  const DaySheetDatePickerResult({required this.date, required this.mode});

  final DateTime date;
  final DaySheetDatePickerMode mode;
}

class DaySheetDatePicker {
  const DaySheetDatePicker._();

  static Future<DaySheetDatePickerResult?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DaySheetDatePickerMode initialMode,
  }) async {
    final seed = DateUtils.dateOnly(initialDate);
    final kSeed = KemeticMath.fromGregorian(seed);
    final picked =
        await StoneRegisterDatePicker.show<EventCreateDatePickerValue>(
          context,
          initialValue: EventCreateDatePickerValue(
            date: seed,
            mode: initialMode._eventMode,
          ),
          adapter: EventCreateDatePickerAdapter(
            gregorianYearStart: seed.year - 200,
            kemeticYearStart: kSeed.kYear - 200,
          ),
          initialMode: initialMode._stoneMode,
          title: 'Day sheet date',
        );
    if (picked == null) return null;
    return DaySheetDatePickerResult(
      date: DateUtils.dateOnly(picked.date),
      mode: picked.mode._daySheetMode,
    );
  }
}

extension on DaySheetDatePickerMode {
  EventCreateDatePickerMode get _eventMode {
    return switch (this) {
      DaySheetDatePickerMode.gregorian => EventCreateDatePickerMode.gregorian,
      DaySheetDatePickerMode.kemetic => EventCreateDatePickerMode.kemetic,
    };
  }

  StoneDatePickerCalendarMode get _stoneMode {
    return switch (this) {
      DaySheetDatePickerMode.gregorian => StoneDatePickerCalendarMode.gregorian,
      DaySheetDatePickerMode.kemetic => StoneDatePickerCalendarMode.kemetic,
    };
  }
}

extension on EventCreateDatePickerMode {
  DaySheetDatePickerMode get _daySheetMode {
    return switch (this) {
      EventCreateDatePickerMode.gregorian => DaySheetDatePickerMode.gregorian,
      EventCreateDatePickerMode.kemetic => DaySheetDatePickerMode.kemetic,
    };
  }
}
