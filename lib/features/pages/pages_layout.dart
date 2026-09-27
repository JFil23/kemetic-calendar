import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/profile_avatar_glyphs.dart';
import 'pages_board.dart';
import 'pages_models.dart';

class PagesLayout extends StatefulWidget {
  const PagesLayout({
    super.key,
    required this.cards,
    required this.onOpen,
    required this.onProfile,
    required this.onNewNote,
    required this.onSearchResult,
    required this.searchRecords,
    this.profileName = '',
    this.profileHandle = '',
    this.profileGlyphIds = const [],
  });
  final List<ValueListenable<PagesCard>> cards;
  final ValueChanged<PagesDestination> onOpen;
  final VoidCallback onProfile, onNewNote;
  final ValueChanged<PagesSearchRecord> onSearchResult;
  final List<PagesSearchRecord> Function() searchRecords;
  final String profileName, profileHandle;
  final List<String> profileGlyphIds;
  @override
  State<PagesLayout> createState() => _PagesLayoutState();
}

class _PagesLayoutState extends State<PagesLayout> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? const <PagesSearchRecord>[]
        : widget
              .searchRecords()
              .where(
                (r) => '${r.title} ${r.category}'.toLowerCase().contains(query),
              )
              .toList();
    return Scaffold(
      backgroundColor: const Color(0xff060504),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          58 + (MediaQuery.paddingOf(context).top * .5).clamp(12, 30),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: (MediaQuery.paddingOf(context).top * .5).clamp(12, 30),
          ),
          child: AppBar(
            backgroundColor: const Color(0xff060504),
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            toolbarHeight: 58,
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Semantics(
              button: true,
              label: 'Open profile',
              child: InkWell(
                onTap: widget.onProfile,
                child: SizedBox(
                  height: 50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.profileHandle.isNotEmpty) ...[
                        Text(
                          widget.profileHandle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            letterSpacing: .2,
                            color: Color(0xffd9d3c7),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final id in normalizeProfileAvatarGlyphIds(
                            widget.profileGlyphIds,
                          ))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              child: Text(
                                kProfileGlyphTileById[id]!.glyph,
                                style: const TextStyle(
                                  fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                                  fontSize: 17,
                                  height: 1,
                                  color: pagesGold,
                                ),
                              ),
                            ),
                          if (widget.profileGlyphIds.isEmpty)
                            const Icon(
                              Icons.person_outline,
                              color: pagesGold,
                              size: 24,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'New note',
                onPressed: widget.onNewNote,
                icon: const Icon(Icons.add, color: pagesGold, size: 28),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                child: TextField(
                  controller: _search,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['GentiumPlus'],
                    fontSize: 15,
                    color: pagesBone,
                  ),
                  decoration: InputDecoration(
                    constraints: const BoxConstraints.tightFor(height: 44),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0x600d0b07),
                    prefixIconConstraints: const BoxConstraints(minWidth: 43),
                    hintText: 'Search all of ḥꜣw',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: ['GentiumPlus'],
                      fontSize: 15,
                      color: Color(0xffa19b90),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xffd0c7b6),
                      size: 18,
                    ),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close, color: pagesBone),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0x8ca1967c)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: pagesGold),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                key: const PageStorageKey('pages-scroll'),
                slivers: [
                  if (query.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(6, 18, 6, 32),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = (constraints.crossAxisExtent - 8) / 2;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => ValueListenableBuilder<PagesCard>(
                                valueListenable: widget.cards[i],
                                builder: (context, card, _) => PagesTile(
                                  card: card,
                                  onTap: () => widget.onOpen(card.destination),
                                ),
                              ),
                              childCount: widget.cards.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 22,
                                  mainAxisExtent: width / 1.49 + 43,
                                ),
                          );
                        },
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'Showing what’s already loaded',
                          style: pagesSerif(
                            14,
                            color: const Color(0xffa39d92),
                            italic: true,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'No matches in loaded content',
                              style: pagesSerif(18),
                            ),
                          );
                        }
                        final r = matches[i];
                        return ListTile(
                          onTap: () => widget.onSearchResult(r),
                          title: Text(r.title, style: pagesSerif(22)),
                          subtitle: Text(
                            r.category,
                            style: pagesSerif(12, color: pagesGold),
                          ),
                        );
                      }, childCount: matches.isEmpty ? 1 : matches.length),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
