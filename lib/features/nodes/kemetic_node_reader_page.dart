import 'package:flutter/material.dart';
import '../../shared/glossy_text.dart';
import '../../widgets/insight_link_text.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_model.dart';
import 'widgets.dart';
import 'node_user_insights_section.dart';

class KemeticNodeReaderPage extends StatefulWidget {
  final KemeticNode node;

  const KemeticNodeReaderPage({super.key, required this.node});

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

  @override
  Widget build(BuildContext context) {
    final paragraphs = _buildParagraphs(_node);
    return WillPopScope(
      onWillPop: () async {
        final handled = _popNode();
        return !handled;
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
            onTap: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KemeticGold.text(
                'sꜣt',
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
                  NodeUserInsightsSection(node: _node),
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
        ShaderMask(
          shaderCallback: (Rect bounds) =>
              KemeticGold.gloss.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            _node.glyph,
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
              fontFamily: 'GentiumPlus',
              fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
                Shadow(
                  color: Colors.white12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
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
                      color: Colors.white.withOpacity(0.06),
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
                Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0),
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
      final spans = _linkifyParagraph(paragraph, node.linkMap, used);
      widgets.add(
        RichText(
          text: TextSpan(style: _bodyStyle, children: spans),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 14));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  List<InlineSpan> _linkifyParagraph(
    String paragraph,
    List<KemeticNodeLink> linkMap,
    Set<String> used,
  ) {
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
        spans.add(TextSpan(text: paragraph.substring(cursor, match.start)));
      }
      spans.add(_buildLinkSpan(match.link));
      cursor = match.end;
    }
    if (cursor < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(cursor)));
    }

    if (spans.isEmpty) {
      return [TextSpan(text: paragraph)];
    }
    return spans;
  }

  InlineSpan _buildLinkSpan(KemeticNodeLink link) {
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
              style: InsightLinkTextStyle.widgetStyle(_bodyStyle),
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
