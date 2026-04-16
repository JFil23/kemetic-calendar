import 'dart:io';

import 'ics_parser_shared.dart';

class IcsParser {
  /// Parse an ICS file from a file path (mobile/desktop only).
  static Future<List<IcsEvent>> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      return parseIcsString(content);
    } catch (_) {
      return [];
    }
  }

  /// Parse an ICS string directly.
  static List<IcsEvent> parseString(String icsContent) {
    return parseIcsString(icsContent);
  }
}
