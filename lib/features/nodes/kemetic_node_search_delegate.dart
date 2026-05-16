import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/insight_entry_model.dart';
import '../../data/insight_entry_repo.dart';
import '../../shared/glossy_text.dart';
import '../../utils/kemetic_date_format.dart';
import '../../widgets/insight_link_text.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_model.dart';

Future<String?> showKemeticNodeSearch(BuildContext context) {
  return showSearch<String?>(
    context: context,
    delegate: KemeticNodeSearchDelegate(
      nodes: KemeticNodeLibrary.nodes,
      insightEntriesFuture: _loadInsightEntriesForSearch(),
    ),
  );
}

Future<List<InsightEntry>> _loadInsightEntriesForSearch() async {
  try {
    return await InsightEntryRepo(
      Supabase.instance.client,
    ).fetchMyEntries(limit: 1000);
  } catch (_) {
    return const <InsightEntry>[];
  }
}

@visibleForTesting
class KemeticNodeSearchDelegate extends SearchDelegate<String?> {
  KemeticNodeSearchDelegate({
    required this.nodes,
    required this.insightEntriesFuture,
  });

  final List<KemeticNode> nodes;
  final Future<List<InsightEntry>> insightEntriesFuture;

  @override
  String get searchFieldLabel => 'Search library…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0.5,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: silver),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Clear',
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _resultsList(query);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type to search the library',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return _resultsList(query);
  }

  @visibleForTesting
  List<String> debugMatchingNodeIds(
    String rawQuery,
    List<InsightEntry> entries,
  ) => _matches(rawQuery, entries).map((result) => result.nodeId).toList();

  Widget _resultsList(String rawQuery) {
    final trimmedQuery = rawQuery.trim();
    if (trimmedQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<InsightEntry>>(
      future: insightEntriesFuture,
      builder: (context, snapshot) {
        final terms = _queryTerms(trimmedQuery);
        final entries = snapshot.data ?? const <InsightEntry>[];
        final results = _matches(trimmedQuery, entries);
        final loadingInsights =
            snapshot.connectionState == ConnectionState.waiting;

        if (results.isEmpty && loadingInsights) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(gold),
              ),
            ),
          );
        }

        if (results.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matches found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: results.length + (loadingInsights ? 1 : 0),
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (ctx, index) {
            if (loadingInsights && index == results.length) {
              return const ListTile(
                title: Text(
                  'Searching your insights…',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              );
            }

            final result = results[index];
            return ListTile(
              onTap: () => close(ctx, result.nodeId),
              leading: _ResultGlyph(glyph: result.glyph),
              title: Text(
                result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _SearchSnippetText(snippet: result.snippet, terms: terms),
                  const SizedBox(height: 4),
                  Text(
                    result.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: silver),
            );
          },
        );
      },
    );
  }

  List<_NodeSearchResult> _matches(
    String rawQuery,
    List<InsightEntry> entries,
  ) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final results = <_NodeSearchResult>[];
    for (final node in nodes) {
      final title = node.title.trim();
      final aliases = node.aliases.where((alias) => alias.trim().isNotEmpty);
      final searchable = <String>[
        node.id,
        title,
        ...aliases,
        node.body,
      ].join('\n').toLowerCase();
      if (!searchable.contains(q)) continue;

      final rank = _nodeRank(node, q);
      results.add(
        _NodeSearchResult(
          nodeId: node.id,
          title: title,
          glyph: node.glyph,
          subtitle: aliases.isEmpty
              ? 'Library entry'
              : 'Library entry • ${aliases.join(', ')}',
          snippet: _snippetFor(
            [node.body, title, ...aliases],
            rawQuery,
            fallback: node.body,
          ),
          rank: rank,
          secondarySort: title.toLowerCase(),
        ),
      );
    }

    for (final entry in entries) {
      final node = KemeticNodeLibrary.resolve(entry.nodeId);
      if (node == null) continue;

      final searchable = <String>[
        entry.nodeTitle,
        entry.nodeId,
        entry.bodyText,
      ].join('\n').toLowerCase();
      if (!searchable.contains(q)) continue;

      results.add(
        _NodeSearchResult(
          nodeId: node.id,
          title: entry.nodeTitle.trim().isEmpty
              ? node.title
              : entry.nodeTitle.trim(),
          glyph: entry.nodeGlyph?.trim().isNotEmpty == true
              ? entry.nodeGlyph!.trim()
              : node.glyph,
          subtitle: 'Your insight • ${formatKemeticDate(entry.entryDate)}',
          snippet: _snippetFor(
            [entry.bodyText, entry.nodeTitle],
            rawQuery,
            fallback: entry.bodyText,
          ),
          rank: _insightRank(entry, q),
          secondarySort: '${entry.entryDate.toIso8601String()}-${entry.id}',
        ),
      );
    }

    results.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      if (byRank != 0) return byRank;
      return a.secondarySort.compareTo(b.secondarySort);
    });

    return results;
  }

  int _nodeRank(KemeticNode node, String q) {
    final title = node.title.toLowerCase();
    if (title == q) return 0;
    if (title.startsWith(q)) return 1;
    if (title.contains(q)) return 2;
    if (node.aliases.any((alias) => alias.toLowerCase() == q)) return 3;
    if (node.aliases.any((alias) => alias.toLowerCase().startsWith(q))) {
      return 4;
    }
    if (node.aliases.any((alias) => alias.toLowerCase().contains(q))) {
      return 5;
    }
    return 6;
  }

  int _insightRank(InsightEntry entry, String q) {
    final title = entry.nodeTitle.toLowerCase();
    if (title == q) return 7;
    if (title.startsWith(q)) return 8;
    if (title.contains(q)) return 9;
    return 10;
  }

  String _snippetFor(
    List<String> fields,
    String rawQuery, {
    required String fallback,
  }) {
    final normalizedFields = fields
        .map((field) => field.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((field) => field.isNotEmpty)
        .toList();
    if (normalizedFields.isEmpty) return '';

    final q = rawQuery.trim().toLowerCase();
    final source = normalizedFields.firstWhere(
      (field) => field.toLowerCase().contains(q),
      orElse: () => fallback.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';

    final matchStart = normalized.toLowerCase().indexOf(q);
    if (matchStart == -1) {
      return normalized.length <= 118
          ? normalized
          : '${normalized.substring(0, 115).trimRight()}...';
    }

    final matchLength = q.length;
    var start = (matchStart - 36).clamp(0, normalized.length);
    var end = (matchStart + matchLength + 82).clamp(0, normalized.length);

    while (start > 0 && normalized[start] != ' ') {
      start--;
    }
    while (end < normalized.length && normalized[end - 1] != ' ') {
      end++;
      if (end >= normalized.length) {
        end = normalized.length;
        break;
      }
    }

    final snippet = normalized.substring(start, end).trim();
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < normalized.length ? ' ...' : '';
    return '$prefix$snippet$suffix';
  }

  List<String> _queryTerms(String rawQuery) {
    final trimmed = rawQuery.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    final seen = <String>{};
    final terms = <String>[];

    void addTerm(String term) {
      final normalized = term.trim().toLowerCase();
      if (normalized.length < 2) return;
      if (seen.add(normalized)) {
        terms.add(normalized);
      }
    }

    for (final term in trimmed.split(RegExp(r'\s+'))) {
      addTerm(term);
    }

    terms.sort((a, b) => b.length.compareTo(a.length));
    return terms;
  }
}

class _NodeSearchResult {
  const _NodeSearchResult({
    required this.nodeId,
    required this.title,
    required this.glyph,
    required this.subtitle,
    required this.snippet,
    required this.rank,
    required this.secondarySort,
  });

  final String nodeId;
  final String title;
  final String glyph;
  final String subtitle;
  final String snippet;
  final int rank;
  final String secondarySort;
}

class _ResultGlyph extends StatelessWidget {
  const _ResultGlyph({required this.glyph});

  final String glyph;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: Center(
        child: ShaderMask(
          shaderCallback: (Rect bounds) =>
              KemeticGold.gloss.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            glyph,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'GentiumPlus',
              fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSnippetText extends StatelessWidget {
  const _SearchSnippetText({required this.snippet, required this.terms});

  final String snippet;
  final List<String> terms;

  static const _baseStyle = TextStyle(
    color: Colors.white70,
    fontSize: 13,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) {
      return Text(
        snippet,
        style: _baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final matches = _searchHighlightRanges(snippet, terms);
    if (matches.isEmpty) {
      return Text(
        snippet,
        style: _baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxes = _computeHighlightBoxes(
          snippet,
          matches,
          constraints.maxWidth,
          Directionality.of(context),
        );
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(children: _buildSnippetSpans(snippet, matches, boxes)),
        );
      },
    );
  }

  List<InlineSpan> _buildSnippetSpans(
    String snippet,
    List<_SearchHighlightRange> matches,
    Map<String, Rect> boxes,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: snippet.substring(cursor, match.start),
            style: _baseStyle,
          ),
        );
      }

      final phrase = snippet.substring(match.start, match.end);
      final box = boxes[_rangeKey(match)];
      final fontSize = _baseStyle.fontSize ?? 13.0;
      final shaderRect = box == null
          ? null
          : Rect.fromLTWH(
              box.left,
              box.top,
              box.width < fontSize ? fontSize : box.width,
              box.height < fontSize * 1.4 ? fontSize * 1.4 : box.height,
            );
      spans.add(
        TextSpan(
          text: phrase,
          style: InsightLinkTextStyle.textSpanStyle(
            _baseStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            phrase,
            shaderRect: shaderRect,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(cursor), style: _baseStyle));
    }

    return spans;
  }

  Map<String, Rect> _computeHighlightBoxes(
    String text,
    List<_SearchHighlightRange> matches,
    double maxWidth,
    TextDirection textDirection,
  ) {
    if (!maxWidth.isFinite ||
        maxWidth <= 0 ||
        matches.isEmpty ||
        text.isEmpty) {
      return const {};
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: _baseStyle),
      textDirection: textDirection,
      maxLines: 2,
      ellipsis: '…',
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    )..layout(maxWidth: maxWidth);

    final boxes = <String, Rect>{};
    for (final match in matches) {
      final start = match.start.clamp(0, text.length);
      final end = match.end.clamp(start, text.length);
      if (start >= end) continue;

      final textBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
      if (textBoxes.isEmpty) continue;

      var left = textBoxes.first.left;
      var top = textBoxes.first.top;
      var right = textBoxes.first.right;
      var bottom = textBoxes.first.bottom;

      for (final textBox in textBoxes.skip(1)) {
        if (textBox.left < left) left = textBox.left;
        if (textBox.top < top) top = textBox.top;
        if (textBox.right > right) right = textBox.right;
        if (textBox.bottom > bottom) bottom = textBox.bottom;
      }

      boxes[_rangeKey(match)] = Rect.fromLTRB(left, top, right, bottom);
    }

    return boxes;
  }

  String _rangeKey(_SearchHighlightRange range) =>
      '${range.start}:${range.end}';
}

class _SearchHighlightRange {
  const _SearchHighlightRange(this.start, this.end);

  final int start;
  final int end;
}

final RegExp _searchWordChar = RegExp(r'[A-Za-z0-9\u00C0-\u024F\u1E00-\u1EFF]');

List<_SearchHighlightRange> _searchHighlightRanges(
  String text,
  List<String> terms,
) {
  if (text.isEmpty || terms.isEmpty) return const [];

  final lower = text.toLowerCase();
  final candidates = <_SearchHighlightRange>[];

  for (final term in terms) {
    if (term.isEmpty) continue;
    var searchFrom = 0;
    while (searchFrom < lower.length) {
      final start = lower.indexOf(term, searchFrom);
      if (start == -1) break;
      final end = start + term.length;
      if (_isValidSearchMatch(text, term, start, end)) {
        candidates.add(_SearchHighlightRange(start, end));
      }
      searchFrom = start + 1;
    }
  }

  candidates.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return (b.end - b.start).compareTo(a.end - a.start);
  });

  final accepted = <_SearchHighlightRange>[];
  for (final candidate in candidates) {
    if (accepted.isEmpty || candidate.start >= accepted.last.end) {
      accepted.add(candidate);
    }
  }
  return accepted;
}

bool _isValidSearchMatch(String text, String term, int start, int end) {
  final needsLeadingBoundary = _isSearchWordChar(term[0]);
  final needsTrailingBoundary = _isSearchWordChar(term[term.length - 1]);

  if (needsLeadingBoundary && start > 0 && _isSearchWordChar(text[start - 1])) {
    return false;
  }
  if (needsTrailingBoundary &&
      end < text.length &&
      _isSearchWordChar(text[end])) {
    return false;
  }
  return true;
}

bool _isSearchWordChar(String char) => _searchWordChar.hasMatch(char);
