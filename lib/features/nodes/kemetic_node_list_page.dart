import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/navigation_fallback.dart';
import '../../shared/kemetic_text.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import 'kemetic_node_library.dart';
import 'library_canon_adapter.dart';
import 'library_canon_list.dart';
import 'library_read_progress_store.dart';
import 'library_read_state.dart';
import 'library_visual_tokens.dart';
import 'kemetic_node_search_delegate.dart';
import 'widgets.dart';

class KemeticNodeListPage extends StatefulWidget {
  const KemeticNodeListPage({
    super.key,
    this.initialNodeId,
    this.readProgressStore,
  });

  final String? initialNodeId;
  final LibraryReadProgressStore? readProgressStore;

  @override
  State<KemeticNodeListPage> createState() => _KemeticNodeListPageState();
}

class _KemeticNodeListPageState extends State<KemeticNodeListPage>
    with WidgetsBindingObserver {
  static const double _estimatedRowExtent = 338;
  static const double _targetTopInset = 112;

  late final ScrollController _scrollController;
  late LibraryReadProgressStore _readProgressStore;
  final Map<String, GlobalKey> _nodeKeys = {};
  LibraryReadSnapshot _readSnapshot = const LibraryReadSnapshot();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readProgressStore = widget.readProgressStore ?? LibraryReadProgressStore();
    _scrollController = ScrollController(
      initialScrollOffset: _estimatedOffsetFor(widget.initialNodeId),
      keepScrollOffset: widget.initialNodeId == null,
    );
    unawaited(_loadReadSnapshot());
    _scheduleFocusedNodeRestore();
  }

  @override
  void didUpdateWidget(covariant KemeticNodeListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readProgressStore != widget.readProgressStore) {
      _readProgressStore =
          widget.readProgressStore ?? LibraryReadProgressStore();
      unawaited(_loadReadSnapshot());
    }
    if (oldWidget.initialNodeId != widget.initialNodeId) {
      _scheduleFocusedNodeRestore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadReadSnapshot());
    }
  }

  int? _nodeIndex(String? nodeId) {
    if (nodeId == null || nodeId.trim().isEmpty) return null;
    final target = KemeticNodeLibrary.resolve(nodeId);
    if (target == null) return null;
    final targetId = target.id.toLowerCase();
    final index = KemeticNodeLibrary.nodes.indexWhere(
      (node) => node.id.toLowerCase() == targetId,
    );
    return index < 0 ? null : index;
  }

  String? _canonicalNodeId(String? nodeId) {
    if (nodeId == null || nodeId.trim().isEmpty) return null;
    return KemeticNodeLibrary.resolve(nodeId)?.id;
  }

  double _estimatedOffsetFor(String? nodeId) {
    final index = _nodeIndex(nodeId);
    if (index == null) return 0;
    return math.max(0, (index * _estimatedRowExtent) - _targetTopInset);
  }

  GlobalKey _nodeKey(String nodeId) =>
      _nodeKeys.putIfAbsent(nodeId, GlobalKey.new);

  Future<void> _loadReadSnapshot() async {
    final snapshot = await _readProgressStore.readSnapshot();
    if (!mounted) return;
    setState(() {
      _readSnapshot = snapshot;
    });
  }

  void _scheduleFocusedNodeRestore([int attempt = 0]) {
    final focusedNodeId = _canonicalNodeId(widget.initialNodeId);
    if (focusedNodeId == null) return;
    final focusedIndex = _nodeIndex(focusedNodeId);
    if (focusedIndex == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final focusedContext = _nodeKeys[focusedNodeId]?.currentContext;
      if (focusedContext != null) {
        Scrollable.ensureVisible(
          focusedContext,
          alignment: 0.18,
          duration: Duration.zero,
        );
        return;
      }

      final visibleIndexes = <int>[];
      for (var index = 0; index < KemeticNodeLibrary.nodes.length; index++) {
        final nodeId = KemeticNodeLibrary.nodes[index].id;
        if (_nodeKeys[nodeId]?.currentContext != null) {
          visibleIndexes.add(index);
        }
      }
      if (visibleIndexes.isEmpty) return;

      final minVisibleIndex = visibleIndexes.reduce(math.min);
      final maxVisibleIndex = visibleIndexes.reduce(math.max);
      final currentOffset = _scrollController.offset;
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      double nextOffset = currentOffset;

      if (focusedIndex < minVisibleIndex) {
        nextOffset -= (minVisibleIndex - focusedIndex) * _estimatedRowExtent;
      } else if (focusedIndex > maxVisibleIndex) {
        nextOffset += (focusedIndex - maxVisibleIndex) * _estimatedRowExtent;
      }

      nextOffset = nextOffset.clamp(0.0, maxScrollExtent).toDouble();
      if (attempt >= 8 || (nextOffset - currentOffset).abs() < 1) return;

      _scrollController.jumpTo(nextOffset);
      _scheduleFocusedNodeRestore(attempt + 1);
    });
  }

  Future<void> _openSearch() async {
    final selectedNodeId = await showKemeticNodeSearch(context);
    if (!mounted || selectedNodeId == null) return;
    unawaited(
      openDetailRoute<void>(
        context,
        '/nodes/${Uri.encodeComponent(selectedNodeId)}',
      ).whenComplete(() {
        if (mounted) unawaited(_loadReadSnapshot());
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = buildLibraryCanonEntries(
      nodes: KemeticNodeLibrary.nodes,
      readSnapshot: _readSnapshot,
    );

    return Scaffold(
      backgroundColor: LibraryVisualTokens.base,
      appBar: AppBar(
        backgroundColor: LibraryVisualTokens.base,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: LibraryVisualTokens.base,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: LibraryVisualTokens.base,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 92,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        leading: Semantics(
          button: true,
          label: 'Close Library',
          child: ExcludeSemantics(
            child: GlyphBackButton(
              showLabel: false,
              showCloseIcon: true,
              onTap: () => popOrGo(context, '/'),
            ),
          ),
        ),
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: KemeticAppBarAction(
              tooltip: 'Search library',
              icon: const KemeticAppBarSearchIcon(
                gradient: LibraryVisualTokens.flatGold,
              ),
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
            Text(
              'Library',
              style: LibraryVisualTokens.chromeTitleStyle(),
              overflow: TextOverflow.clip,
            ),
            Transform.translate(
              offset: const Offset(0, 5),
              child: MeduGlyphText(
                '𓊪𓏤𓂋𓏛',
                style: LibraryVisualTokens.chromeGlyphStyle(),
                overflow: TextOverflow.clip,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: LibraryVisualTokens.base,
            gradient: LibraryVisualTokens.pageGradient,
          ),
          child: LibraryCanonList(
            entries: entries,
            controller: _scrollController,
            nodeKeyFor: _nodeKey,
            onOpenEntry: (entry) {
              unawaited(
                openDetailRoute<void>(
                  context,
                  '/nodes/${Uri.encodeComponent(entry.node.id)}',
                ).whenComplete(() {
                  if (mounted) unawaited(_loadReadSnapshot());
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
