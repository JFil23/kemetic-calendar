import 'package:flutter/material.dart' show DateUtils;

import 'package:mobile/core/day_key.dart';
import 'package:mobile/core/kemetic_converter.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

typedef DailyReflectionQuestion = ({String dayKey, int kYear, String question});

DailyReflectionQuestion? dailyReflectionQuestionForDate(
  DateTime localDate, {
  KemeticConverter? converter,
}) {
  final kemeticConverter = converter ?? KemeticConverter();
  final kd = kemeticConverter.fromGregorian(DateUtils.dateOnly(localDate));
  final dayKey = kemeticDayKey(kd.epagomenal ? 13 : kd.month, kd.day);
  final info = KemeticDayData.getInfoForDay(dayKey);
  if (info == null) return null;

  for (final flowDay in info.decanFlow) {
    if (flowDay.day != kd.day) continue;
    final question = flowDay.reflection.trim();
    if (question.isEmpty) return null;
    return (dayKey: dayKey, kYear: kd.year, question: question);
  }

  return null;
}
