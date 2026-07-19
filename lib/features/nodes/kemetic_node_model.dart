import 'package:flutter/foundation.dart';

@immutable
class KemeticNodeLink {
  final String phrase;
  final String targetId;

  const KemeticNodeLink({required this.phrase, required this.targetId});
}

@immutable
class KemeticNode {
  final String id;
  final String title;
  final String glyph;
  final String body;
  final List<String> aliases;
  final List<KemeticNodeLink> linkMap;
  final bool isSystemOwned;

  const KemeticNode({
    required this.id,
    required this.title,
    required this.glyph,
    required this.body,
    this.aliases = const [],
    this.linkMap = const [],
    this.isSystemOwned = true,
  });

  List<String> get displayAliases {
    final titleKey = title.trim().toLowerCase();
    final display = <String>[];
    final seen = <String>{};

    for (final alias in aliases) {
      final trimmed = alias.trim();
      if (trimmed.isEmpty) continue;

      final key = trimmed.toLowerCase();
      if (key == titleKey) continue;
      if (!seen.add(key)) continue;

      display.add(trimmed);
    }

    return display;
  }
}
