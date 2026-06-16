# Library Canon Refactor Inventory

Inventory completed before visual implementation.

## Route Entry Points

- `/nodes` is the durable primary Library route in `mobile/lib/main.dart`; it builds `KemeticNodeListPage(initialNodeId: state.uri.queryParameters['focus'])`.
- `/nodes/:nodeId` is the Library detail route; it builds `NodeReaderRoutePage`, resolves the node through `KemeticNodeLibrary.resolve`, then renders `KemeticNodeReaderPage`.
- `/nodes/:nodeId?action=add_insight` and legacy `?insight=new` are one-shot article routes that open the insight editor on load, then replace the route with stable `/nodes/:nodeId`.
- Drawer Library navigation uses `AppSection.library`, `NavigationPersistencePolicy.routeForSection`, and the canonical durable route `/nodes`.
- Calendar menu actions open `/nodes` through existing primary-section/restoration recording paths.
- Reader close/back uses `popOrGo(context, '/nodes?focus={nodeId}')`, preserving focus restoration on return.
- Living Text / Daily flow CTA panels open `/nodes/:nodeId?action=add_insight` when a node slug is known, otherwise `/nodes`.
- Decan reflection inline links, suggested nodes, and CTAs open `/nodes/:nodeId` through `openDetailRoute`.
- Calendar month info can resolve and display Library nodes inline with its own in-panel history; it does not route through the Library list.

## Current Data Source

- Library content is static Dart data in `mobile/lib/features/nodes/kemetic_node_library.dart`.
- Canonical order is the order of `KemeticNodeLibrary.nodes`, a `List.unmodifiable(_nodes)`.
- Node lookup supports ids and aliases through lowercase maps in `KemeticNodeLibrary.resolve`.
- Article body text is available on the list page through `KemeticNode.body`.
- Reading time is not currently stored and no Library-specific reading-time convention exists.

## Current Item Model

- `KemeticNode` currently contains `id`, `title`, `glyph`, `body`, `aliases`, `linkMap`, and `isSystemOwned`.
- Aliases act as the only existing theme/category-like metadata shown on the list.
- Existing icon/glyph data is the `glyph` string. No separate semantic icon system exists for Library list cards.
- Route target is `/nodes/{node.id}`.
- Hidden detail-page metadata is `linkMap` for inline cross-node links and `isSystemOwned` for node ownership.
- No read status, bookmark/save/favorite status, current/continue status, or stored reading time exists on the Library list model.

## Current Behaviors

- Tapping a Library card calls `openDetailRoute(context, '/nodes/{id}')`.
- Search is `showKemeticNodeSearch`, implemented by `KemeticNodeSearchDelegate`; it searches node id/title/aliases/body and up to 1000 user insight entries.
- Search result selection opens the existing node detail route from the list or pushes into in-reader node history from the reader.
- The list is a virtualized `ListView.separated` with `PageStorageKey('kemetic-node-library-list')`.
- `/nodes?focus={id}` uses estimated row offset plus `Scrollable.ensureVisible` retries to restore the focused node.
- Close on the list calls `popOrGo(context, '/')`; close/back behavior is centralized in `navigation_fallback.dart`.
- Reader tracks `node_opened` and `node_link_tapped` choice events through `ChoiceEventTracker`; the list itself does not track opens.
- Reader has internal node history for inline links, right-swipe body gesture to pop that history, and route back to `/nodes?focus={id}`.
- Reader contains `NodeUserInsightsSection`, including add/edit/delete/save/post behavior for insights.
- No current Library list loading, empty, error, pull-to-refresh, filters, category navigation, bookmarks, favorites, saved articles, recently viewed articles, read-completion persistence, or progress persistence were found.

## Dependent Surfaces

- `KemeticNodeListPage`: Library list route and visual target for this refactor.
- `KemeticNodeReaderPage`: detail route, search-in-reader, internal node history, node open/link telemetry, insight editor hosting.
- `KemeticNodeSearchDelegate`: search entry point from list and reader.
- `GlobalSideDrawer` / `_GlobalFloatingMenuShell`: Library drawer item and selected state.
- Calendar page menu actions and floating shell: open `/nodes`.
- `day_view.dart` Living Text CTA: opens Library root or node insight route.
- `decan_reflection_detail_page.dart`: opens Library nodes from reflection text, suggested nodes, and CTAs.
- `calendar_month_detail.dart`: resolves Library nodes inline inside month info.
- Navigation restoration services and tests classify `/nodes` as durable Library and `/nodes/` routes as restorable transient Library surfaces.

## Preservation Plan

- Keep existing routes, providers, navigation helpers, detail reader, search delegate, node data, and node ordering.
- Build the canon visuals as an adapter over `KemeticNodeLibrary.nodes`.
- Derive chapter index from list order, not node id.
- Derive opening sentence and reading-time display from existing `KemeticNode.body` without mutating node data.
- Use aliases as the quiet theme line because no other category/tag model exists.
- Use a visual-only state resolver. With no persisted Library read/progress source, show the first canonical node as `current` and all others as `unread` until a real source is added; do not write or infer read persistence.
- Bundle and register `NotoSansEgyptianHieroglyphs-Regular.ttf` because the current app references that family but does not register the asset.
