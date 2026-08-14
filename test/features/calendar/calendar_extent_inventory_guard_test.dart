import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed calendar extent inventory matches audited source fragments', () {
    final manifestFile = File('docs/calendar_extent_inventory_manifest.json');
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['schema'], 1);
    final fragments = (manifest['fragments'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(fragments, isNotEmpty);

    final names = <String>{};
    for (final fragment in fragments) {
      final name = fragment['name'] as String;
      expect(names.add(name), isTrue, reason: 'Duplicate fragment: $name');
      final path = fragment['file'] as String;
      var source = File(path).readAsStringSync();
      final start = fragment['start'] as String?;
      final end = fragment['end'] as String?;

      if (start != null) {
        expect(
          start.allMatches(source),
          hasLength(1),
          reason: '$name start marker must occur exactly once in $path',
        );
        source = source.substring(source.indexOf(start));
      }
      if (end != null) {
        expect(
          end.allMatches(source),
          hasLength(1),
          reason: '$name end marker must occur exactly once after start',
        );
        source = source.substring(0, source.indexOf(end));
      }

      final actual = sha256.convert(utf8.encode(source)).toString();
      expect(
        actual,
        fragment['sha256'],
        reason:
            '$name changed. Re-audit the closed contributor list and equations '
            'before updating its manifest hash.',
      );
    }
  });
}
