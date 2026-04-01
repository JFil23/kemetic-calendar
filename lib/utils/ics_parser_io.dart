import 'dart:io';

import 'ics_parser_shared.dart';

class IcsParser {
  /// Parse an ICS file from a file path (mobile/desktop only).
  static Future<List<IcsEvent>> parseFile(String filePath) async {
    try {
      print('[IcsParser] Reading file: $filePath');
      final file = File(filePath);
      final content = await file.readAsString();
      print('[IcsParser] File content length: ${content.length} characters');
      return parseIcsString(content);
    } catch (e) {
      print('[IcsParser] Error reading file: $e');
      return [];
    }
  }

  /// Parse an ICS string directly.
  static List<IcsEvent> parseString(String icsContent) {
    return parseIcsString(icsContent);
  }
}
