import 'ics_parser_shared.dart';

class IcsParser {
  /// File-path parsing is not available on web; return empty and log.
  static Future<List<IcsEvent>> parseFile(String filePath) async {
    return [];
  }

  /// Parse an ICS string directly.
  static List<IcsEvent> parseString(String icsContent) {
    return parseIcsString(icsContent);
  }
}
