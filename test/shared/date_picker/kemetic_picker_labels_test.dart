import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/event_create_date_picker.dart';
import 'package:mobile/widgets/flow_start_date_picker.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' as kemetic_picker;
import 'package:mobile/widgets/maat_flow_date_picker.dart';
import 'package:mobile/widgets/recurrence_until_date_picker.dart';

void main() {
  test('Kemetic picker month labels are mobile-safe and bounded', () {
    expect(kKemeticPickerMonthLabels, hasLength(13));
    for (final label in kKemeticPickerMonthLabels) {
      expect(
        RegExp(r'^[\x20-\x7E]+$').hasMatch(label),
        isTrue,
        reason: '$label should avoid tofu-prone glyphs',
      );
      expect(label.length, lessThanOrEqualTo(13));
    }
  });

  test('Kemetic date picker adapters use safe wheel month labels', () {
    final seed = DateTime(2026, 6, 21);
    final kSeed = KemeticMath.fromGregorian(seed);

    final adapters = <String, List<StoneWheelColumn>>{
      'KemeticDatePickerAdapter': kemetic_picker.KemeticDatePickerAdapter(
        yearStart: kSeed.kYear - 200,
      ).buildColumns(seed, StoneDatePickerCalendarMode.kemetic),
      'FlowStartDatePickerAdapter': FlowStartDatePickerAdapter(
        today: DateTime(2026, 1, 1),
        kemeticYearStart: kSeed.kYear,
      ).buildColumns(seed, StoneDatePickerCalendarMode.kemetic),
      'RecurrenceUntilDatePickerAdapter': RecurrenceUntilDatePickerAdapter(
        today: DateTime(2026, 1, 1),
        kemeticYearStart: kSeed.kYear,
      ).buildColumns(seed, StoneDatePickerCalendarMode.kemetic),
      'EventCreateDatePickerAdapter':
          EventCreateDatePickerAdapter(
            gregorianYearStart: 2026,
            kemeticYearStart: kSeed.kYear - 200,
          ).buildColumns(
            EventCreateDatePickerValue(
              date: seed,
              mode: EventCreateDatePickerMode.kemetic,
            ),
            StoneDatePickerCalendarMode.kemetic,
          ),
      'MaatFlowDatePickerAdapter':
          MaatFlowDatePickerAdapter(
            today: DateTime(2026, 1, 1),
            kemeticYearStart: kSeed.kYear,
          ).buildColumns(
            MaatFlowDatePickerValue(
              date: seed,
              mode: MaatFlowDatePickerMode.kemetic,
            ),
            StoneDatePickerCalendarMode.kemetic,
          ),
    };

    for (final entry in adapters.entries) {
      final labels = entry.value
          .singleWhere((column) => column.id == 'month')
          .values;
      expect(labels, kKemeticPickerMonthLabels, reason: entry.key);
    }
  });
}
