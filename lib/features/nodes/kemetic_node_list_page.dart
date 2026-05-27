import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation_fallback.dart';
import '../../shared/glossy_text.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_model.dart';
import 'kemetic_node_search_delegate.dart';
import 'widgets.dart';

class KemeticNodeListPage extends StatefulWidget {
  const KemeticNodeListPage({super.key, this.initialNodeId});

  final String? initialNodeId;

  @override
  State<KemeticNodeListPage> createState() => _KemeticNodeListPageState();
}

class _KemeticNodeListPageState extends State<KemeticNodeListPage> {
  static const double _estimatedRowExtent = 168;
  static const double _targetTopInset = 96;

  late final ScrollController _scrollController;
  final Map<String, GlobalKey> _nodeKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _estimatedOffsetFor(widget.initialNodeId),
      keepScrollOffset: widget.initialNodeId == null,
    );
    _scheduleFocusedNodeRestore();
  }

  @override
  void didUpdateWidget(covariant KemeticNodeListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialNodeId != widget.initialNodeId) {
      _scheduleFocusedNodeRestore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  String _snippet(KemeticNode node) {
    final collapsed = node.body
        .replaceAll('\n', ' ')
        .replaceAll('  ', ' ')
        .trim();
    if (collapsed.length <= 140) return collapsed;
    return '${collapsed.substring(0, 140).trimRight()}…';
  }

  Future<void> _openSearch() async {
    final selectedNodeId = await showKemeticNodeSearch(context);
    if (!mounted || selectedNodeId == null) return;
    context.go('/nodes/${Uri.encodeComponent(selectedNodeId)}');
  }

  @override
  Widget build(BuildContext context) {
    final nodes = KemeticNodeLibrary.nodes;

    return Scaffold(
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
          showCloseIcon: true,
          onTap: () => popOrGo(context, '/'),
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
        child: ListView.separated(
          key: const PageStorageKey('kemetic-node-library-list'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemBuilder: (context, index) {
            final node = nodes[index];
            return _NodeCard(
              key: _nodeKey(node.id),
              node: node,
              subtitle: _snippet(node),
              onTap: () {
                context.go('/nodes/${Uri.encodeComponent(node.id)}');
              },
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemCount: nodes.length,
        ),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final KemeticNode node;
  final String subtitle;
  final VoidCallback onTap;

  const _NodeCard({
    super.key,
    required this.node,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aliasChips = node.aliases.where((a) => a.isNotEmpty).toList();
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: KemeticGold.base.withValues(alpha: 0.05),
        highlightColor: KemeticGold.base.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NodeGlyphMark(
                glyph: node.glyph,
                width: 48,
                height: 48,
                fontSize: 31,
                padding: const EdgeInsets.all(6),
                framed: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KemeticGold.text(
                      node.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (aliasChips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: aliasChips
                            .map(
                              (alias) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  alias,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.4,
                        fontFamily: 'GentiumPlus',
                        fontFamilyFallback: [
                          'NotoSans',
                          'Roboto',
                          'Arial',
                          'sans-serif',
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              KemeticGold.icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
