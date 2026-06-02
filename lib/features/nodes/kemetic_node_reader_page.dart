import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/navigation_fallback.dart';
import '../../shared/glossy_text.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import '../../widgets/insight_link_text.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_model.dart';
import 'kemetic_node_search_delegate.dart';
import 'widgets.dart';
import 'node_user_insights_section.dart';

class KemeticNodeReaderPage extends StatefulWidget {
  final KemeticNode node;
  final bool openInsightEditorOnLoad;
  final VoidCallback? onInsightEditorIntentConsumed;

  const KemeticNodeReaderPage({
    super.key,
    required this.node,
    this.openInsightEditorOnLoad = false,
    this.onInsightEditorIntentConsumed,
  });

  @override
  State<KemeticNodeReaderPage> createState() => _KemeticNodeReaderPageState();
}

class _KemeticNodeReaderPageState extends State<KemeticNodeReaderPage> {
  static const TextStyle _bodyStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    height: 1.55,
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
    letterSpacing: 0.1,
  );

  static const TextStyle _tableCellStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.35,
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
    letterSpacing: 0.1,
  );

  static const TextStyle _tableHeaderStyle = TextStyle(
    color: KemeticGold.light,
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
    letterSpacing: 0,
  );

  final List<KemeticNode> _history = [];
  final ScrollController _scrollController = ScrollController();
  double _horizontalDrag = 0;
  bool _dragConsumed = false;

  @override
  void initState() {
    super.initState();
    _history.add(widget.node);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  KemeticNode get _node => _history.last;

  void _openNode(String targetId) {
    final target = KemeticNodeLibrary.resolve(targetId);
    if (target == null) return;
    if (target.id.toLowerCase() == _node.id.toLowerCase()) return;
    setState(() {
      _history.add(target);
    });
    _scrollToTop();
  }

  Future<void> _scrollToTop() async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  bool _popNode() {
    if (_history.length <= 1) return false;
    setState(() {
      _history.removeLast();
    });
    _scrollToTop();
    return true;
  }

  void _handleBackNavigation() {
    if (_popNode()) return;
    final location = Uri(
      path: '/nodes',
      queryParameters: {'focus': _node.id},
    ).toString();
    popOrGo(context, location);
  }

  Future<void> _openSearch() async {
    final selectedNodeId = await showKemeticNodeSearch(context);
    if (!mounted || selectedNodeId == null) return;
    final target = KemeticNodeLibrary.resolve(selectedNodeId);
    if (target == null) return;
    if (target.id.toLowerCase() == _node.id.toLowerCase()) {
      await _scrollToTop();
      return;
    }
    setState(() {
      _history.add(target);
    });
    await _scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = _buildParagraphs(_node);
    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _popNode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 70,
          automaticallyImplyLeading: false,
          leadingWidth: 64,
          leading: GlyphBackButton(
            showLabel: false,
            onTap: _handleBackNavigation,
          ),
          titleSpacing: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: KemeticAppBarAction(
                tooltip: 'Search library',
                icon: const KemeticAppBarSearchIcon(),
                onPressed: () {
                  unawaited(_openSearch());
                },
              ),
            ),
          ],
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KemeticGold.text(
                'Library',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GentiumPlus',
                  fontFamilyFallback: [
                    'NotoSans',
                    'Roboto',
                    'Arial',
                    'sans-serif',
                  ],
                ),
                overflow: TextOverflow.clip,
              ),
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (Rect bounds) =>
                    KemeticGold.gloss.createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  '𓋴 𓄿 𓏏 𓂋',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontFamily: 'GentiumPlus',
                    fontFamilyFallback: [
                      'NotoSans',
                      'Roboto',
                      'Arial',
                      'sans-serif',
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _horizontalDrag = 0;
              _dragConsumed = false;
            },
            onHorizontalDragUpdate: (details) {
              if (_dragConsumed) return;
              final delta = details.primaryDelta ?? 0;
              if (delta > 0) {
                _horizontalDrag += delta;
              }
              if (_horizontalDrag > 48) {
                _dragConsumed = _popNode();
              }
            },
            onHorizontalDragEnd: (_) {
              _horizontalDrag = 0;
              _dragConsumed = false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  ...paragraphs,
                  NodeUserInsightsSection(
                    node: _node,
                    openEditorOnLoad: widget.openInsightEditorOnLoad,
                    onRouteEditorConsumed: widget.onInsightEditorIntentConsumed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final aliasChips = _node.aliases.where((a) => a.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NodeGlyphMark(
          glyph: _node.glyph,
          width: double.infinity,
          height: 50,
          fontSize: 42,
          alignment: Alignment.centerLeft,
          shadows: true,
        ),
        const SizedBox(height: 6),
        KemeticGold.text(
          _node.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        if (aliasChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: aliasChips
                .map(
                  (alias) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      alias,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildParagraphs(KemeticNode node) {
    final used = <String>{};
    final widgets = <Widget>[];
    for (final raw in node.body.split('\n\n')) {
      final paragraph = raw.trimRight();
      if (paragraph.isEmpty) continue;
      if (_isTableBlock(paragraph)) {
        widgets.add(_buildTableBlock(paragraph, node.linkMap, used));
      } else if (paragraph.startsWith('## ')) {
        widgets.add(_buildSectionHeading(paragraph.substring(3).trim()));
      } else {
        widgets.add(_buildTextBlock(paragraph, node.linkMap, used));
      }
      widgets.add(const SizedBox(height: 14));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _buildSectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: KemeticGold.text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.15,
          fontFamily: 'GentiumPlus',
          fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
        ),
      ),
    );
  }

  Widget _buildTextBlock(
    String paragraph,
    List<KemeticNodeLink> linkMap,
    Set<String> used,
  ) {
    final spans = _linkifyParagraph(paragraph, linkMap, used, _bodyStyle);
    return RichText(
      text: TextSpan(style: _bodyStyle, children: spans),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }

  bool _isTableBlock(String block) {
    final lines = block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 3) return false;
    if (!lines.first.startsWith('|')) return false;
    final separator = _splitTableRow(lines[1]);
    return separator.isNotEmpty &&
        separator.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
  }

  Widget _buildTableBlock(
    String block,
    List<KemeticNodeLink> linkMap,
    Set<String> used,
  ) {
    final rows = _parseTableRows(block);
    if (rows.isEmpty) return _buildTextBlock(block, linkMap, used);
    final columnCount = rows
        .map((row) => row.length)
        .reduce((value, element) => value > element ? value : element);
    final widths = <int, TableColumnWidth>{
      for (var i = 0; i < columnCount; i++)
        i: FixedColumnWidth(_tableColumnWidth(columnCount, i)),
    };
    final tableWidth = widths.values.fold<double>(
      0,
      (sum, width) => sum + (width as FixedColumnWidth).value,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Table(
          border: TableBorder.all(color: Colors.white24),
          columnWidths: widths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              TableRow(
                decoration: BoxDecoration(
                  color: rowIndex == 0
                      ? Colors.white.withValues(alpha: 0.08)
                      : rowIndex.isEven
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.transparent,
                ),
                children: [
                  for (var colIndex = 0; colIndex < columnCount; colIndex++)
                    _buildTableCell(
                      colIndex < rows[rowIndex].length
                          ? rows[rowIndex][colIndex]
                          : '',
                      isHeader: rowIndex == 0,
                      linkMap: linkMap,
                      used: used,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  double _tableColumnWidth(int columnCount, int columnIndex) {
    if (columnCount == 2) return columnIndex == 0 ? 190 : 420;
    if (columnCount == 3) {
      return switch (columnIndex) {
        0 => 140,
        1 => 260,
        _ => 360,
      };
    }
    return columnIndex == 0 ? 150 : 260;
  }

  Widget _buildTableCell(
    String text, {
    required bool isHeader,
    required List<KemeticNodeLink> linkMap,
    required Set<String> used,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: isHeader
          ? Text(text, style: _tableHeaderStyle)
          : RichText(
              text: TextSpan(
                style: _tableCellStyle,
                children: _linkifyParagraph(
                  text,
                  linkMap,
                  used,
                  _tableCellStyle,
                ),
              ),
            ),
    );
  }

  List<List<String>> _parseTableRows(String block) {
    final rows = <List<String>>[];
    for (final line in block.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final cells = _splitTableRow(trimmed);
      if (cells.isEmpty) continue;
      if (cells.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell))) {
        continue;
      }
      rows.add(cells);
    }
    return rows;
  }

  List<String> _splitTableRow(String line) {
    var normalized = line.trim();
    if (!normalized.startsWith('|')) return const [];
    if (normalized.startsWith('|')) normalized = normalized.substring(1);
    if (normalized.endsWith('|')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.split('|').map((cell) => cell.trim()).toList();
  }

  List<InlineSpan> _linkifyParagraph(
    String paragraph,
    List<KemeticNodeLink> linkMap,
    Set<String> used,
    TextStyle baseStyle,
  ) {
    final emphasisPattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in emphasisPattern.allMatches(paragraph)) {
      if (match.start > cursor) {
        spans.addAll(
          _linkifyPlainText(
            paragraph.substring(cursor, match.start),
            linkMap,
            used,
            baseStyle: baseStyle,
          ),
        );
      }

      final boldText = match.group(1);
      final italicText = match.group(2);
      final emphasisText = boldText ?? italicText ?? '';
      if (emphasisText.isNotEmpty) {
        final emphasisStyle = boldText != null
            ? const TextStyle(fontWeight: FontWeight.w700)
            : const TextStyle(fontStyle: FontStyle.italic);
        final emphasisBaseStyle = boldText != null
            ? baseStyle.copyWith(fontWeight: FontWeight.w700)
            : baseStyle.copyWith(fontStyle: FontStyle.italic);
        spans.addAll(
          _linkifyPlainText(
            emphasisText,
            linkMap,
            used,
            textStyle: emphasisStyle,
            baseStyle: emphasisBaseStyle,
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < paragraph.length) {
      spans.addAll(
        _linkifyPlainText(
          paragraph.substring(cursor),
          linkMap,
          used,
          baseStyle: baseStyle,
        ),
      );
    }

    if (spans.isEmpty) {
      return [TextSpan(text: paragraph)];
    }
    return spans;
  }

  List<InlineSpan> _linkifyPlainText(
    String paragraph,
    List<KemeticNodeLink> linkMap,
    Set<String> used, {
    TextStyle? textStyle,
    required TextStyle baseStyle,
  }) {
    final matches = <_LinkMatch>[];
    for (final link in linkMap) {
      if (used.contains(link.phrase)) continue;
      final matchIndex = _findFirstOccurrence(paragraph, link.phrase);
      if (matchIndex == null) continue;
      matches.add(
        _LinkMatch(
          link: link,
          start: matchIndex,
          end: matchIndex + link.phrase.length,
        ),
      );
      used.add(link.phrase);
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) continue; // avoid overlaps
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: paragraph.substring(cursor, match.start),
            style: textStyle,
          ),
        );
      }
      spans.add(_buildLinkSpan(match.link, baseStyle));
      cursor = match.end;
    }
    if (cursor < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(cursor), style: textStyle));
    }

    if (spans.isEmpty) {
      return [TextSpan(text: paragraph, style: textStyle)];
    }
    return spans;
  }

  InlineSpan _buildLinkSpan(KemeticNodeLink link, TextStyle baseStyle) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _openNode(link.targetId),
          child: ShaderMask(
            shaderCallback: (Rect bounds) =>
                KemeticGold.gloss.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              link.phrase,
              style: InsightLinkTextStyle.widgetStyle(baseStyle),
            ),
          ),
        ),
      ),
    );
  }

  int? _findFirstOccurrence(String paragraph, String phrase) {
    int? fallback;
    int index = paragraph.indexOf(phrase);
    while (index != -1) {
      final isWhole = _isWholeWordMatch(paragraph, index, phrase);
      if (!isWhole) {
        index = paragraph.indexOf(phrase, index + phrase.length);
        continue;
      }
      final insideQuote = _isInsideQuotedLine(paragraph, index, phrase.length);
      fallback ??= index;
      if (!insideQuote) {
        return index;
      }
      index = paragraph.indexOf(phrase, index + phrase.length);
    }
    return fallback;
  }

  bool _isWholeWordMatch(String source, int index, String phrase) {
    final beforeIndex = index - 1;
    final afterIndex = index + phrase.length;
    final before = beforeIndex >= 0 ? source[beforeIndex] : '';
    final after = afterIndex < source.length ? source[afterIndex] : '';
    final letterPattern = RegExp(r'[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]');
    final beforeIsLetter = letterPattern.hasMatch(before);
    final afterIsLetter = letterPattern.hasMatch(after);
    return !beforeIsLetter && !afterIsLetter;
  }

  bool _isInsideQuotedLine(String text, int index, int length) {
    final lineStart = text.lastIndexOf('\n', index) + 1;
    final lineEnd = text.indexOf('\n', index);
    final line = text
        .substring(lineStart, lineEnd == -1 ? text.length : lineEnd)
        .trimLeft();

    if (line.startsWith('“') ||
        line.startsWith('"') ||
        line.startsWith('‘') ||
        line.startsWith('—')) {
      return true;
    }

    final quotesBefore = RegExp(
      r'[“”"‘’]',
    ).allMatches(text.substring(0, index)).length;
    final quotesThrough = RegExp(
      r'[“”"‘’]',
    ).allMatches(text.substring(0, index + length)).length;

    return quotesBefore.isOdd && quotesThrough >= quotesBefore;
  }
}

class _LinkMatch {
  final KemeticNodeLink link;
  final int start;
  final int end;

  const _LinkMatch({
    required this.link,
    required this.start,
    required this.end,
  });
}
