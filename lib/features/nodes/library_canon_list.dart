import 'package:flutter/material.dart';

import '../../core/app_bottom_insets.dart';
import 'library_canon_adapter.dart';
import 'library_canon_entry.dart';
import 'library_visual_tokens.dart';

class LibraryCanonList extends StatelessWidget {
  const LibraryCanonList({
    super.key,
    required this.entries,
    required this.controller,
    required this.nodeKeyFor,
    required this.onOpenEntry,
  });

  final List<LibraryCanonEntryViewModel> entries;
  final ScrollController controller;
  final GlobalKey Function(String nodeId) nodeKeyFor;
  final ValueChanged<LibraryCanonEntryViewModel> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = AppBottomInsets.scrollBottomPadding(context, 180);
    return ListView.builder(
      key: const PageStorageKey<String>('kemetic-node-library-list'),
      controller: controller,
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const _CanonHeader();
        final entryIndex = index - 1;
        final entry = entries[entryIndex];
        return _SpinedCanonEntry(
          key: nodeKeyFor(entry.node.id),
          entry: entry,
          isFirst: entryIndex == 0,
          isLast: entryIndex == entries.length - 1,
          onTap: () => onOpenEntry(entry),
        );
      },
    );
  }
}

class _CanonHeader extends StatelessWidget {
  const _CanonHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: 'THE CANON · READ IN ORDER',
            child: ExcludeSemantics(
              child: Text(
                'THE CANON · READ IN ORDER',
                textAlign: TextAlign.center,
                style: LibraryVisualTokens.eyebrowStyle(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Text(
              'From the unformed deep to the human voice — one story, told in sequence.',
              textAlign: TextAlign.center,
              style: LibraryVisualTokens.canonSubtitleStyle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinedCanonEntry extends StatelessWidget {
  const _SpinedCanonEntry({
    super.key,
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  static const double _spineLeft = 23;

  final LibraryCanonEntryViewModel entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _spineLeft,
          top: isFirst ? 30 : 0,
          bottom: isLast ? 42 : 0,
          child: const IgnorePointer(
            child: ExcludeSemantics(child: _SpineSegment()),
          ),
        ),
        LibraryCanonEntry(
          chapterNumber: entry.chapterNumber,
          title: entry.title,
          glyph: entry.glyph,
          themes: entry.themes,
          openingLine: entry.openingLine,
          readingMinutes: entry.readingMinutes,
          visualState: entry.visualState,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _SpineSegment extends StatelessWidget {
  const _SpineSegment();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LibraryVisualTokens.spine.withValues(alpha: 0),
              LibraryVisualTokens.spine,
              LibraryVisualTokens.spine,
              LibraryVisualTokens.spine.withValues(alpha: 0),
            ],
            stops: const [0, 0.08, 0.86, 1],
          ),
        ),
      ),
    );
  }
}
