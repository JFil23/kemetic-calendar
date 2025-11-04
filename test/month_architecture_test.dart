import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architecture Guards - CI Enforcement', () {
    test('GUARD 1: No string comparisons on month names', () async {
      final violations = await _findPatternViolations([
        RegExp(r'''==\s*['"]Paopi|==\s*['"]Phaophi|==\s*['"]Menkhet'''),
        RegExp(r'''contains\(\s*['"](Paopi|Phaophi|Menkhet)'''),
        RegExp(r'''switch.*month.*case\s*['"]'''),
      ]);

      expect(
        violations,
        isEmpty,
        reason: 'String-based month logic:\n${violations.join('\n')}',
      );
    });

    test('GUARD 2: No new deprecated shim usage', () async {
      final violations = await _findPatternViolations([
        RegExp(r'''monthNamesCompat'''),
        RegExp(r'''kemeticMonthsHellenized'''),
      ], skipTests: true);

      expect(
        violations,
        isEmpty,
        reason: 'New deprecated usage:\n${violations.join('\n')}',
      );
    });

    test('GUARD 3: No hardcoded month arrays', () async {
      final violations = await _findPatternViolations([
        RegExp(r'''['"]Thoth['"].*['"]Paopi['"].*['"]Hathor['"]'''),
        RegExp(r'''(const|final)\s+\w*\s*monthNames\s*=\s*\['''),
      ]);

      expect(
        violations,
        isEmpty,
        reason: 'Hardcoded arrays:\n${violations.join('\n')}',
      );
    });

    test('GUARD 4: No season string comparisons', () async {
      final violations = await _findPatternViolations([
        RegExp(r'''season\.(name|label)\s*=='''),
        RegExp(r'''==\s*['"]Akhet|==\s*['"]Peret|==\s*['"]Shemu'''),
      ]);

      expect(
        violations,
        isEmpty,
        reason: 'Season string logic:\n${violations.join('\n')}',
      );
    });

    test('GUARD 5: Month text must use MonthNameText widget', () async {
      final violations = await _findPatternViolations([
        RegExp(
          r'''Text\(\s*getMonthById.*\.(displayFull|displayShort|displayTransliteration)''',
        ),
      ]);

      expect(
        violations,
        isEmpty,
        reason: 'Use MonthNameText:\n${violations.join('\n')}',
      );
    });
  });
}

Future<List<String>> _findPatternViolations(
  List<RegExp> patterns, {
  bool skipTests = false,
}) async {
  // Resolve lib directory - try multiple paths
  Directory? libDir;
  for (final path in ['lib', 'mobile/lib', '../lib']) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      libDir = dir;
      break;
    }
  }

  if (libDir == null || !libDir.existsSync()) {
    // Return empty if we can't find lib directory (tests might run from different locations)
    return [];
  }

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.contains('kemetic_month_metadata.dart') &&
            !f.path.contains('month_name_text.dart') &&
            (!skipTests || !f.path.contains('_test.dart')),
      );

  final violations = <String>[];

  for (final file in dartFiles) {
    final content = await file.readAsString();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('//')) continue; // Skip comments

      for (final pattern in patterns) {
        if (pattern.hasMatch(line)) {
          violations.add('${file.path}:${i + 1} -> $line');
        }
      }
    }
  }

  return violations;
}
