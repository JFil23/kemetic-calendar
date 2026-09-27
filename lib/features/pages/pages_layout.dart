import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/profile_avatar.dart';
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
    this.profileGlyphIds = const [],
  });
  final List<ValueListenable<PagesCard>> cards;
  final ValueChanged<PagesDestination> onOpen;
  final VoidCallback onProfile, onNewNote;
  final ValueChanged<PagesSearchRecord> onSearchResult;
  final List<PagesSearchRecord> Function() searchRecords;
  final String profileName;
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
      appBar: AppBar(
        backgroundColor: const Color(0xff060504),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onProfile,
              child: ProfileAvatar(
                displayName: widget.profileName,
                avatarGlyphIds: widget.profileGlyphIds,
                radius: 23,
                borderColor: pagesGold.withValues(alpha: .35),
                borderWidth: 1,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Pages',
              style: pagesSerif(27, color: const Color(0xffe4c579)),
            ),
          ],
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
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          controller: _scroll,
          key: const PageStorageKey('pages-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 27),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['GentiumPlus'],
                    fontSize: 15,
                    color: pagesBone,
                  ),
                  decoration: InputDecoration(
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
                      size: 23,
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
                      vertical: 15,
                      horizontal: 15,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0x8ca1967c)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: pagesGold),
                    ),
                  ),
                ),
              ),
            ),
            if (query.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 32),
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }
}
