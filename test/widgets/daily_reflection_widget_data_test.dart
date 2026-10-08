import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

void main() {
  test('daily reflection widget data matches KemeticDayData', () {
    final reflectionDays = _buildReflectionDays();
    expect(reflectionDays.length, 365);

    final expected = <String, Object?>{
      'schema': 1,
      'source': 'KemeticDayData.dayInfoMap.decanFlow.reflection',
      'days': reflectionDays,
    };

    final sharedFile = File('assets/widget/daily-reflection-days.json');
    final webFile = File('web/widgets/daily-reflection-days.json');
    final iosWidgetFile = File(
      'ios/DailyReflectionWidget/daily-reflection-days.json',
    );
    if (Platform.environment['UPDATE_DAILY_REFLECTION_WIDGET_DATA'] == '1') {
      final body = '${const JsonEncoder.withIndent('  ').convert(expected)}\n';
      sharedFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(body);
      webFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(body);
      iosWidgetFile
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(body);
    }

    final sharedActual = jsonDecode(sharedFile.readAsStringSync());
    final webActual = jsonDecode(webFile.readAsStringSync());
    final iosWidgetActual = jsonDecode(iosWidgetFile.readAsStringSync());
    expect(sharedActual, expected);
    expect(webActual, expected);
    expect(iosWidgetActual, expected);
  });
}

Map<String, Object?> _buildReflectionDays() {
  final days = <String, Object?>{};
  final entries = KemeticDayData.dayInfoMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final entry in entries) {
    final row = KemeticDayData.getFlowForDay(entry.key);
    if (row == null) continue;
    days[entry.key] = <String, Object?>{'question': row.reflection};
  }

  return days;
}
