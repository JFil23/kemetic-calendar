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
}
