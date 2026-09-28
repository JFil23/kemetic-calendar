import 'pages_collections.dart';
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
    this.collectionState = const PagesCollectionState(),
    this.onCollectionChanged,
    this.onCollectionItem,
    this.onLoadMore,
    this.onRetry,
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
  final PagesCollectionState collectionState;
  final ValueChanged<PagesCollection?>? onCollectionChanged;
  final ValueChanged<PagesCollectionItem>? onCollectionItem;
  final VoidCallback? onLoadMore, onRetry;
  @override
  State<PagesLayout> createState() => _PagesLayoutState();
}

class _PagesLayoutState extends State<PagesLayout> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _listScroll = {
    for (final tab in PagesCollection.values) tab: ScrollController(),
  };
  PagesCollection? _selected;

  void _select(PagesCollection tab) {
    setState(() {
      _selected = _selected == tab ? null : tab;
    });
    widget.onCollectionChanged?.call(_selected);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    for (final scroll in _listScroll.values) {
      scroll.dispose();
    }
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
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: 'Open profile',
                child: InkWell(
                  onTap: widget.onProfile,
                  child: SizedBox(
                    height: 50,
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.profileHandle.isNotEmpty) ...[
                          Text(
                            widget.profileHandle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                    fontFamily:
                                        'Noto Sans Egyptian Hieroglyphs',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final tab in PagesCollection.values)
                    Expanded(
                      child: Semantics(
                        selected: _selected == tab,
                        child: TextButton(
                          onPressed: () => _select(tab),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: _selected == tab
                                ? pagesGold
                                : pagesBone,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selected == tab
                                      ? pagesGold
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              tab.label,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                    hintText: _selected == null
                        ? 'Search all of ḥꜣw'
                        : 'Search ${_selected!.label.toLowerCase()}',
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
                controller: _selected == null
                    ? _scroll
                    : _listScroll[_selected],
                key: PageStorageKey('pages-${_selected?.name ?? "scroll"}'),
                slivers: [
                  if (_selected != null)
                    _collectionList(query)
                  else if (query.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(6, 18, 6, 32),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = (constraints.crossAxisExtent - 8) / 2;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => i == PagesDestination.feed.index
                                  ? _SteadyFeedTile(
                                      card: widget.cards[i],
                                      onOpen: widget.onOpen,
                                    )
                                  : ValueListenableBuilder<PagesCard>(
                                      valueListenable: widget.cards[i],
                                      builder: (context, card, _) => PagesTile(
                                        card: card,
                                        onTap: () =>
                                            widget.onOpen(card.destination),
                                      ),
                                    ),
                              childCount: widget.cards.length,
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              // Caption space is already reserved in the tile extent.
                              mainAxisSpacing: 3,
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

  Widget _collectionList(String query) {
    final state = widget.collectionState;
    final items = state.collection == _selected
        ? state.items
              .where(
                (item) => '${item.title} ${item.detail}'.toLowerCase().contains(
                  query,
                ),
              )
              .toList()
        : <PagesCollectionItem>[];
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final item in items)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 5,
              ),
              leading: Container(
                width: 3,
                height: 32,
                color: Color(item.color),
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: pagesSerif(20),
              ),
              subtitle: item.detail.isEmpty
                  ? null
                  : Text(
                      item.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: pagesSerif(12, color: const Color(0xffa39d92)),
                    ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xffa39d92),
                size: 18,
              ),
              onTap: () => widget.onCollectionItem?.call(item),
            ),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: pagesGold,
                  ),
                ),
              ),
            ),
          if (state.failed)
            TextButton(
              onPressed: widget.onRetry,
              child: Text(
                'Could not load ${_selected!.label.toLowerCase()}. Retry',
                style: pagesSerif(16),
              ),
            ),
          if (!state.loading && !state.failed && items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                query.isEmpty
                    ? 'No ${_selected!.label.toLowerCase()} yet'
                    : 'No matches in loaded ${_selected!.label.toLowerCase()}',
                style: pagesSerif(16, color: const Color(0xffa39d92)),
              ),
            ),
          if (!state.loading && state.hasMore)
            TextButton(
              onPressed: widget.onLoadMore,
              child: Text('Load more', style: pagesSerif(16)),
            ),
        ]),
      ),
    );
  }
}

/// Defer an incoming card while it is being touched; no persisted seen state.
class _SteadyFeedTile extends StatefulWidget {
  const _SteadyFeedTile({required this.card, required this.onOpen});
  final ValueListenable<PagesCard> card;
  final ValueChanged<PagesDestination> onOpen;
  @override
  State<_SteadyFeedTile> createState() => _SteadyFeedTileState();
}

class _SteadyFeedTileState extends State<_SteadyFeedTile> {
  late PagesCard _shown;
  final _pointers = <int>{};
  @override
  void initState() {
    super.initState();
    _shown = widget.card.value;
    widget.card.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _SteadyFeedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card != widget.card) {
      oldWidget.card.removeListener(_refresh);
      widget.card.addListener(_refresh);
      _refresh();
    }
  }

  void _refresh() {
    if (mounted && _pointers.isEmpty && !identical(_shown, widget.card.value)) {
      setState(() => _shown = widget.card.value);
    }
  }

  void _release(PointerEvent event) {
    _pointers.remove(event.pointer);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    widget.card.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _pointers.add(event.pointer),
    onPointerUp: _release,
    onPointerCancel: _release,
    child: PagesTile(
      card: _shown,
      onTap: () => widget.onOpen(_shown.destination),
    ),
  );
}
