import 'package:flutter/foundation.dart';

import 'kemetic_node_model.dart';
import 'library_read_state.dart';

const int kLibraryReadingWordsPerMinute = 225;

@immutable
class LibraryCanonEntryViewModel {
  const LibraryCanonEntryViewModel({
    required this.node,
    required this.chapterNumber,
    required this.title,
    required this.glyph,
    required this.themes,
    required this.openingLine,
    required this.readingMinutes,
    required this.visualState,
  });

  final KemeticNode node;
  final int chapterNumber;
  final String title;
  final String glyph;
  final List<String> themes;
  final String openingLine;
  final int readingMinutes;
  final LibraryChapterVisualState visualState;
}

List<LibraryCanonEntryViewModel> buildLibraryCanonEntries({
  required List<KemeticNode> nodes,
  LibraryReadSnapshot readSnapshot = const LibraryReadSnapshot(),
}) {
  final canonicalNodeIds = nodes.map((node) => node.id).toList(growable: false);
  return <LibraryCanonEntryViewModel>[
    for (var index = 0; index < nodes.length; index++)
      LibraryCanonEntryViewModel(
        node: nodes[index],
        chapterNumber: index + 1,
        title: nodes[index].title,
        glyph: nodes[index].glyph,
        themes: themesForNode(nodes[index]),
        openingLine: extractOpeningLine(nodes[index].body),
        readingMinutes: estimateReadingMinutes(nodes[index].body),
        visualState: resolveLibraryChapterVisualState(
          nodeId: nodes[index].id,
          canonicalNodeIds: canonicalNodeIds,
          readSnapshot: readSnapshot,
        ),
      ),
  ];
}

List<String> themesForNode(KemeticNode node, {int maxThemes = 2}) {
  if (maxThemes <= 0) return const <String>[];
  final preferred = _preferredThemeAliasesByNodeId[node.id];
  if (preferred != null) {
    return preferred.take(maxThemes).toList(growable: false);
  }
  final themes = <String>[];
  final seen = <String>{};
  for (final alias in node.aliases) {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) continue;
    if (!seen.add(trimmed.toLowerCase())) continue;
    themes.add(trimmed);
    if (themes.length >= maxThemes) break;
  }
  return themes;
}

const Map<String, List<String>> _preferredThemeAliasesByNodeId = {
  'human_emergence': ['Hominid Lineage', 'Sapiens Awakening'],
  'haw': ['Haw', 'Increase'],
};

String extractOpeningLine(String body) {
  for (final block in body.split(RegExp(r'\n\s*\n'))) {
    final prose = _cleanProseBlock(block);
    if (prose.isEmpty) continue;
    final sentence = _firstSentence(prose);
    if (sentence.isNotEmpty) return sentence;
  }
  return '';
}

int estimateReadingMinutes(
  String body, {
  int wordsPerMinute = kLibraryReadingWordsPerMinute,
}) {
  if (wordsPerMinute <= 0) {
    throw ArgumentError.value(
      wordsPerMinute,
      'wordsPerMinute',
      'must be greater than zero',
    );
  }

  final words = RegExp(
    r"[A-Za-z0-9\u00C0-\u024F\u1E00-\u1EFF]+(?:[-'][A-Za-z0-9\u00C0-\u024F\u1E00-\u1EFF]+)?",
  ).allMatches(body).length;
  if (words == 0) return 1;
  return (words / wordsPerMinute).ceil().clamp(1, 999).toInt();
}

String _cleanProseBlock(String rawBlock) {
  final lines = rawBlock
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) return '';

  final proseLines = <String>[];
  for (final line in lines) {
    if (line.startsWith('#')) continue;
    if (line.startsWith('|')) continue;
    if (RegExp(r'^:?-{3,}:?$').hasMatch(line)) continue;
    if (line.startsWith('---')) continue;
    if (line.startsWith('•')) continue;
    proseLines.add(line);
  }
  if (proseLines.isEmpty) return '';

  final prose = proseLines.join(' ');
  return prose
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (match) => match.group(1)!)
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (match) => match.group(1)!)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _firstSentence(String prose) {
  final match = RegExp(r'^(.+?[.!?])(?:\s|$)', dotAll: true).firstMatch(prose);
  if (match != null) return match.group(1)!.trim();
  return prose.length <= 180 ? prose : '${prose.substring(0, 180).trim()}...';
}
