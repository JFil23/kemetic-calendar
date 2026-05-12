import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:mobile/core/kemetic_converter.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

void main() {
  test('resolves the decan reflection question for a local date', () {
    final converter = KemeticConverter();
    final localDate = converter.toGregorianMidnight(
      const KemeticDate(year: 1, month: 2, day: 23, epagomenal: false),
    );

    final question = dailyReflectionQuestionForDate(
      localDate,
      converter: converter,
    );
    final expected = KemeticDayData.getInfoForDay(
      'paophi_23_3',
    )!.decanFlow.firstWhere((row) => row.day == 23).reflection;

    expect(question?.dayKey, 'paophi_23_3');
    expect(question?.kYear, 1);
    expect(question?.question, expected);
  });
}
