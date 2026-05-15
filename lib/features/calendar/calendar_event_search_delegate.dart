part of 'calendar_page.dart';

class _EventSearchDelegate extends SearchDelegate<void> {
  _EventSearchDelegate({
    required this.notes,
    required List<_Flow> flows,
    required this.monthName,
    required this.gregYearLabelFor,
    required this.openDay,
  }) : _flowById = {for (final flow in flows) flow.id: flow};

  final Map<String, List<_Note>> notes;
  final Map<int, _Flow> _flowById;
  final String Function(int kMonth) monthName;
  final String Function(int kYear, int kMonth) gregYearLabelFor;
  final void Function(int ky, int km, int kd) openDay;

  @override
  String get searchFieldLabel => 'Search notes…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0.5,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: _silver),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _gold,
        surface: _bg,
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

  Iterable<({int ky, int km, int kd, _Note note})> _matches(String q) sync* {
    if (q.trim().isEmpty) return;
    final qq = q.toLowerCase();
    for (final entry in notes.entries) {
      final parts = entry.key.split('-'); // ky-km-kd
      if (parts.length != 3) continue;
      final ky = int.tryParse(parts[0]) ?? 0;
      final km = int.tryParse(parts[1]) ?? 0;
      final kd = int.tryParse(parts[2]) ?? 0;
      for (final n in entry.value) {
        if (_searchableTextFor(n).contains(qq)) {
          yield (ky: ky, km: km, kd: kd, note: n);
        }
      }
    }
  }

  List<String> _contextFieldsFor(_Note note) {
    final fields = <String>[
      _cleanDetail(note.detail),
      note.location ?? '',
      note.category ?? '',
    ];

    final flowId = note.flowId;
    if (flowId != null && flowId > 0) {
      final flow = _flowById[flowId];
      if (flow != null) {
        final overview = _effectiveOverview(
          flow.notes,
          notesDecode(flow.notes).overview,
        );
        final repeatingMeta = _decodeRepeatingNoteMetadata(flow.notes);
        fields.addAll([
          overview,
          repeatingMeta.detail ?? '',
          repeatingMeta.location ?? '',
          repeatingMeta.category ?? '',
        ]);
      }
    }

    final seen = <String>{};
    final cleaned = <String>[];
    for (final field in fields) {
      final normalized = field.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) continue;
      if (seen.add(normalized.toLowerCase())) {
        cleaned.add(normalized);
      }
    }
    return cleaned;
  }

  String _searchableTextFor(_Note note) {
    final fields = <String>[note.title, ..._contextFieldsFor(note)];

    final flowId = note.flowId;
    if (flowId != null && flowId > 0) {
      final flow = _flowById[flowId];
      if (flow != null) {
        fields.add(flow.name);
      }
    }

    return fields
        .where((field) => field.trim().isNotEmpty)
        .join('\n')
        .toLowerCase();
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

  String? _contextSnippetFor(_Note note, String rawQuery) {
    final context = _contextFieldsFor(note).join(' ');
    final normalized = context.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;

    final terms = _queryTerms(rawQuery);
    if (terms.isEmpty) return normalized;
    final matches = _searchHighlightRanges(normalized, terms);

    if (matches.isEmpty) {
      return normalized.length <= 110
          ? normalized
          : '${normalized.substring(0, 107).trimRight()}...';
    }
    final match = matches.first;
    final matchStart = match.start;
    final matchLength = match.end - match.start;

    var start = (matchStart - 32).clamp(0, normalized.length);
    var end = (matchStart + matchLength + 72).clamp(0, normalized.length);

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
    if (snippet.isEmpty) return null;
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < normalized.length ? ' ...' : '';
    return '$prefix$snippet$suffix';
  }

  Widget _resultsList(String q) {
    final items = _matches(q).toList()
      ..sort((a, b) {
        final ga = KemeticMath.toGregorian(a.ky, a.km, a.kd);
        final gb = KemeticMath.toGregorian(b.ky, b.km, b.kd);
        return ga.compareTo(gb);
      });
    final terms = _queryTerms(q);

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No matches found',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Colors.white10),
      itemBuilder: (ctx, i) {
        final it = items[i];
        final g = KemeticMath.toGregorian(it.ky, it.km, it.kd);
        final gLabel =
            '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';
        final kmLabel = it.km == 13
            ? 'Heriu Renpet (ḥr.w rnpt)'
            : monthName(it.km);

        final subBits = <String>[
          '$kmLabel ${it.kd}',
          gLabel,
          if (it.note.location != null && it.note.location!.isNotEmpty)
            it.note.location!,
        ];
        final subtitle = subBits.join(' • ');
        final snippet = _contextSnippetFor(it.note, q);

        return SizedBox(
          width: double.infinity,
          child: ListTile(
            onTap: () => openDay(it.ky, it.km, it.kd),
            isThreeLine: snippet != null,
            title: Text(
              it.note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snippet != null) ...[
                  const SizedBox(height: 4),
                  _SearchSnippetText(snippet: snippet, terms: terms),
                  const SizedBox(height: 4),
                ],
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: _silver),
          ),
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => _resultsList(query);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Type to search your notes',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return _resultsList(query);
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
