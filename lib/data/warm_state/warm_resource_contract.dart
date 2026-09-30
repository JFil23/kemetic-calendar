/// Stable resource contracts, independent of application/build versions.
/// Add a family here before introducing another persistent read boundary.
class WarmResourceSchema {
  const WarmResourceSchema({this.version = 1, this.migrations = const {}});
  final int version;

  /// Entry N migrates payload N to N+1. Never mutate account-owned data here.
  final Map<int, Object? Function(Object?)> migrations;
  Object? upgrade(Object? data, int from) {
    if (from > version || from < 1) {
      throw const FormatException('Unsupported warm schema');
    }
    for (var v = from; v < version; v++) {
      final migrate = migrations[v];
      if (migrate == null) {
        throw const FormatException('Missing warm migration');
      }
      data = migrate(data);
    }
    return data;
  }
}

class WarmResourceContract {
  static const families = <String, WarmResourceSchema>{
    'pages.': WarmResourceSchema(),
    'rhythm.': WarmResourceSchema(),
    'dm.': WarmResourceSchema(),
    'journal.': WarmResourceSchema(),
    'reflection.': WarmResourceSchema(),
    'social.': WarmResourceSchema(),
    'flow.': WarmResourceSchema(),
    'filing.': WarmResourceSchema(),
    'commons.': WarmResourceSchema(),
    'guidance.': WarmResourceSchema(),
    'calendars.': WarmResourceSchema(),
    'readingHouse.': WarmResourceSchema(),
    'image.': WarmResourceSchema(),
  };
  static WarmResourceSchema? find(String key) {
    for (final entry in families.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  static void requireRegistered(String key) {
    if (find(key) == null) {
      throw StateError('Register the warm resource contract for $key');
    }
  }
}
