import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production date pickers route through Stone Register or documented exceptions',
    () async {
      final findings = <String>[];
      final libFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in libFiles) {
        final path = file.path.replaceAll('\\', '/');
        final source = await file.readAsString();
        final lines = source.split('\n');
        for (var index = 0; index < lines.length; index += 1) {
          final line = lines[index];
          if (_containsForbiddenDatePickerApi(line)) {
            findings.add('$path:${index + 1}: ${line.trim()}');
            continue;
          }
          if (_containsWheelApi(line) &&
              !_allowedWheelFilePaths.contains(path)) {
            findings.add('$path:${index + 1}: ${line.trim()}');
          }
        }
      }

      expect(findings, isEmpty, reason: findings.join('\n'));
    },
  );

  test(
    'audit records final Stone Register date picker sweep exceptions',
    () async {
      final audit = await File(
        'docs/stone_register_date_picker_audit.md',
      ).readAsString();

      expect(audit, contains('### Final Cleanup Sweep'));
      expect(audit, contains('Custom repeat interval'));
      expect(audit, contains("Ma'at enrollment-window"));
      expect(audit, contains('pickDateUniversal'));
      expect(
        audit,
        contains('Stone Register remains a skin and wheel interaction layer'),
      );
    },
  );
}

const _allowedWheelFilePaths = <String>{
  'lib/shared/date_picker/stone_register_date_picker_sheet.dart',
  'lib/shared/date_picker/stone_register_date_wheel.dart',
  'lib/features/calendar/calendar_custom_repeat_page.dart',
};

bool _containsForbiddenDatePickerApi(String line) {
  return line.contains('showDatePicker(') ||
      line.contains('CalendarDatePicker(') ||
      line.contains('CupertinoDatePicker(') ||
      line.contains('FixedExtentScrollPhysics') ||
      line.contains('pickDateUniversal');
}

bool _containsWheelApi(String line) {
  return line.contains('CupertinoPicker(') ||
      line.contains('FixedExtentScrollController(');
}
