import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/daily_reflection_snapshot.dart';

void main() {
  test('daily reflection snapshot fixture decodes and re-encodes', () {
    final file = File(
      'assets/widget/daily-reflection-snapshot.v1.example.json',
    );
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final snapshot = DailyReflectionSnapshot.fromJson(json);

    expect(
      snapshot.schemaVersion,
      DailyReflectionSnapshot.currentSchemaVersion,
    );
    expect(snapshot.kind, DailyReflectionSnapshot.dailyReflectionKind);
    expect(snapshot.validForLocalDate, '2026-05-09');
    expect(snapshot.timezone, 'America/Los_Angeles');
    expect(snapshot.reflection, '"What survived this labor in good form?"');
    expect(snapshot.kemeticDate.dayKey, 'paophi_21_3');
    expect(snapshot.kemeticDate.kYear, 2);
    expect(snapshot.intent.route, '/rhythm/today');
    expect(snapshot.intent.params['openDayCard'], '1');
    expect(snapshot.authRequired, isFalse);

    final reencoded = snapshot.toJson();
    expect(reencoded['schemaVersion'], json['schemaVersion']);
    expect(reencoded['kind'], json['kind']);
    expect(reencoded['validForLocalDate'], json['validForLocalDate']);
    expect(reencoded['reflection'], json['reflection']);
    expect(reencoded['kemeticDate'], json['kemeticDate']);
    expect(reencoded['intent'], json['intent']);
    expect(reencoded['authRequired'], json['authRequired']);
    expect(reencoded['sourceVersion'], json['sourceVersion']);
    expect(DateTime.tryParse(reencoded['generatedAt']! as String), isNotNull);
    expect(DateTime.tryParse(reencoded['expiresAt']! as String), isNotNull);
  });
}
