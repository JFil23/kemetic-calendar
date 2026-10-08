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
  final question = KemeticDayData.getFlowForDay(dayKey)?.reflection.trim();
  if (question == null || question.isEmpty) return null;
  return (dayKey: dayKey, kYear: kd.year, question: question);
}
