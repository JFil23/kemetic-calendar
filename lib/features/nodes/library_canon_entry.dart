import 'package:flutter/material.dart';

import '../../shared/glossy_text.dart';
import '../../shared/kemetic_text.dart';
import 'kemetic_numeral.dart';
import 'library_read_state.dart';
import 'library_visual_tokens.dart';
import 'widgets.dart';

class LibraryCanonEntry extends StatelessWidget {
  const LibraryCanonEntry({
    super.key,
    required this.chapterNumber,
    required this.title,
    required this.glyph,
    required this.themes,
    required this.openingLine,
    required this.readingMinutes,
    required this.visualState,
    required this.onTap,
  });

  final int chapterNumber;
  final String title;
  final String glyph;
  final List<String> themes;
  final String openingLine;
  final int readingMinutes;
  final LibraryChapterVisualState visualState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(visualState);
    final semanticLabel =
        '$title. Chapter $chapterNumber. $stateLabel. '
        '$readingMinutes minutes. Double tap to ${_semanticAction(visualState)}.';

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: _ChapterTablet(
                        chapterNumber: chapterNumber,
                        visualState: visualState,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ArticleCard(
                    title: title,
                    glyph: glyph,
                    themes: themes,
                    openingLine: openingLine,
                    readingMinutes: readingMinutes,
                    visualState: visualState,
                    onTap: onTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _stateLabel(LibraryChapterVisualState state) {
    return switch (state) {
      LibraryChapterVisualState.unread => 'Unread',
      LibraryChapterVisualState.inProgress => 'In progress',
      LibraryChapterVisualState.current => 'Current',
      LibraryChapterVisualState.completed => 'Complete',
    };
  }

  static String _semanticAction(LibraryChapterVisualState state) {
    return switch (state) {
      LibraryChapterVisualState.completed => 'read again',
      LibraryChapterVisualState.inProgress => 'continue reading',
      LibraryChapterVisualState.current => 'continue reading',
      _ => 'open',
    };
  }
}

class _ChapterTablet extends StatelessWidget {
  const _ChapterTablet({
    required this.chapterNumber,
    required this.visualState,
  });

  final int chapterNumber;
  final LibraryChapterVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final current = visualState == LibraryChapterVisualState.current;
    final completed = visualState == LibraryChapterVisualState.completed;
    final borderColor = current
        ? LibraryVisualTokens.gold
        : completed
        ? LibraryVisualTokens.spineLit.withValues(alpha: 0.74)
        : LibraryVisualTokens.spine;
    final numeralColor = current
        ? LibraryVisualTokens.gold
        : completed
        ? LibraryVisualTokens.spineLit.withValues(alpha: 0.74)
        : LibraryVisualTokens.goldDim;

    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: current
            ? LibraryVisualTokens.currentNodeBackgroundGradient
            : LibraryVisualTokens.nodeBackgroundGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: current ? 1.5 : 1),
        boxShadow: [
          if (completed)
            BoxShadow(
              color: LibraryVisualTokens.spineLit.withValues(alpha: 0.12),
              blurRadius: 10,
            ),
          if (current) ...[
            BoxShadow(
              color: LibraryVisualTokens.gold.withValues(alpha: 0.14),
              blurRadius: 0,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: LibraryVisualTokens.gold.withValues(alpha: 0.34),
              blurRadius: 18,
            ),
          ],
        ],
      ),
      child: KemeticNumeral(
        value: chapterNumber,
        color: numeralColor,
        onesColor: current ? LibraryVisualTokens.gold : numeralColor,
        fontSize: 18,
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.title,
    required this.glyph,
    required this.themes,
    required this.openingLine,
    required this.readingMinutes,
    required this.visualState,
    required this.onTap,
  });

  final String title;
  final String glyph;
  final List<String> themes;
  final String openingLine;
  final int readingMinutes;
  final LibraryChapterVisualState visualState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final current = visualState == LibraryChapterVisualState.current;
    final borderColor = current
        ? LibraryVisualTokens.gold.withValues(alpha: 0.76)
        : LibraryVisualTokens.cardEdge;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LibraryVisualTokens.cardGradient,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: current ? 1.25 : 1),
          boxShadow: current
              ? [
                  BoxShadow(
                    color: LibraryVisualTokens.gold.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          splashColor: LibraryVisualTokens.gold.withValues(alpha: 0.06),
          highlightColor: LibraryVisualTokens.gold.withValues(alpha: 0.08),
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _AccentStripe(),
              ),
              Positioned(
                left: -80,
                right: -80,
                top: -36,
                height: 88,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LibraryVisualTokens.crownBloomGradient,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _IconBox(glyph: glyph),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KemeticText(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: LibraryVisualTokens.cardTitleStyle(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right,
                          color: LibraryVisualTokens.goldDim,
                          size: 22,
                        ),
                      ],
                    ),
                    if (themes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _TextColumn(
                        child: KemeticText(
                          themes.take(2).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LibraryVisualTokens.themeStyle(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _TextColumn(child: _OpeningLine(text: openingLine)),
                    const SizedBox(height: 22),
                    _TextColumn(
                      child: _MetaRow(
                        readingMinutes: readingMinutes,
                        visualState: visualState,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextColumn extends StatelessWidget {
  const _TextColumn({required this.child});

  static const double _iconGutter = 52;
  static const double _maxTextWidth = 200;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _iconGutter),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: _maxTextWidth, child: child),
      ),
    );
  }
}

class _AccentStripe extends StatelessWidget {
  const _AccentStripe();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        gradient: LibraryVisualTokens.accentStripeGradient,
        backgroundBlendMode: BlendMode.srcOver,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.glyph});

  final String glyph;

  @override
  Widget build(BuildContext context) {
    final displayGlyph = glyph.trim().isEmpty
        ? MeduNeterGlyphs.library
        : glyph.replaceAll(RegExp(r'\s+'), '');
    return NodeGlyphMark(
      glyph: displayGlyph,
      width: 40,
      height: 40,
      fontSize: 27,
      padding: const EdgeInsets.all(7),
      framed: true,
      borderRadius: 11,
      frameColor: LibraryVisualTokens.iconBox,
      borderColor: LibraryVisualTokens.cardEdge,
      gradient: LibraryVisualTokens.flatGold,
    );
  }
}

class _OpeningLine extends StatelessWidget {
  const _OpeningLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final drop = trimmed.substring(0, 1);
    final rest = trimmed.length == 1 ? '' : trimmed.substring(1);
    final style = KemeticTypography.protect(
      LibraryVisualTokens.openingStyle(),
      trimmed,
    );

    return RichText(
      textAlign: TextAlign.start,
      textWidthBasis: TextWidthBasis.parent,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: drop,
            style: const TextStyle(color: LibraryVisualTokens.goldDim),
          ),
          TextSpan(text: rest),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.readingMinutes, required this.visualState});

  final int readingMinutes;
  final LibraryChapterVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final marker = switch (visualState) {
      LibraryChapterVisualState.unread => '✦ READ',
      LibraryChapterVisualState.inProgress => 'CONTINUE →',
      LibraryChapterVisualState.current => 'CONTINUE →',
      LibraryChapterVisualState.completed => 'COMPLETE',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$readingMinutes MIN', style: LibraryVisualTokens.metaStyle()),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            marker,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: LibraryVisualTokens.metaStyle().copyWith(
              color: visualState == LibraryChapterVisualState.current
                  ? LibraryVisualTokens.gold
                  : visualState == LibraryChapterVisualState.completed
                  ? LibraryVisualTokens.lowText
                  : LibraryVisualTokens.spineLit,
            ),
          ),
        ),
      ],
    );
  }
}
