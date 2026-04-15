import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/glossy_text.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../data/insight_link_utils.dart';
import '../../widgets/insight_link_text.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/node_link_picker_sheet.dart';
import '../nodes/kemetic_node_reader_page.dart';

class DecanReflectionDetailPage extends StatefulWidget {
  final String reflectionId;
  const DecanReflectionDetailPage({super.key, required this.reflectionId});

  @override
  State<DecanReflectionDetailPage> createState() =>
      _DecanReflectionDetailPageState();
}

class _DecanReflectionDetailPageState extends State<DecanReflectionDetailPage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  final _insightRepo = InsightLinkRepo();
  List<InsightLink> _links = [];
  final List<GestureRecognizer> _linkGestureRecognizers = [];
  List<InlineSpan> _reflectionSpans = const [];
  DecanReflection? _reflection;
  bool _loading = true;
  final _sheetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeLinkGestureRecognizers();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _repo.getById(widget.reflectionId);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final links = await _insightRepo.fetchLinks(userId);
    if (!mounted) return;
    setState(() {
      _reflection = data;
      _links = links
          .where(
            (l) =>
                l.sourceType == InsightSourceType.reflectionEntry &&
                l.sourceId == widget.reflectionId,
          )
          .toList();
      _sheetController.text = data?.reflectionText ?? '';
      _rebuildReflectionSpans();
      _loading = false;
    });
  }

  void _disposeLinkGestureRecognizers() {
    for (final recognizer in _linkGestureRecognizers) {
      recognizer.dispose();
    }
    _linkGestureRecognizers.clear();
  }

  void _rebuildReflectionSpans() {
    _disposeLinkGestureRecognizers();
    final reflection = _reflection;
    if (reflection == null) {
      _reflectionSpans = const [];
      return;
    }
    // SelectableText.rich only supports TextSpan children, so this page uses
    // recognizer-backed text spans instead of the default WidgetSpan links.
    _reflectionSpans = InsightLinkSpanBuilder.build(
      text: reflection.reflectionText,
      links: _links,
      baseStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.5,
      ),
      onTap: _handleLinkTap,
      mode: InsightLinkSpanRenderMode.textSpan,
      gestureRecognizers: _linkGestureRecognizers,
    );
  }

  void _handleLinkTap(InsightLink link) {
    final node = KemeticNodeLibrary.resolve(link.targetId);
    if (node == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KemeticNodeReaderPage(node: node)),
    );
  }

  void _showSelectionRequiredMessage() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Select a phrase first.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(context).viewInsets.bottom + 120,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _saveLinkSelection({
    required TextSelection rawSelection,
    required String text,
    VoidCallback? onComplete,
  }) async {
    final selection = normalizeInsightSelection(
      text: text,
      selection: rawSelection,
    );
    if (selection == null) {
      _showSelectionRequiredMessage();
      return;
    }

    final existingLink = findInsightLinkForSelection(
      links: _links,
      selection: selection,
    );
    final currentNode = existingLink == null
        ? null
        : KemeticNodeLibrary.resolve(existingLink.targetId);

    FocusManager.instance.primaryFocus?.unfocus();

    final result = await showNodeLinkPickerSheet(
      context: context,
      selectedText: selectedInsightText(text: text, selection: selection),
      currentNode: currentNode,
    );
    if (!mounted || result == null) return;

    final remaining = removeInsightLinksForSelection(
      links: _links,
      selection: selection,
    );
    if (result.action == NodeLinkPickerAction.unlink) {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
      final all = await _insightRepo.fetchLinks(userId);
      final filtered =
          all
              .where(
                (link) =>
                    !(link.sourceType == InsightSourceType.reflectionEntry &&
                        link.sourceId == widget.reflectionId),
              )
              .toList()
            ..addAll(remaining);
      await _insightRepo.saveLinks(userId, filtered);
      setState(() {
        _links = remaining;
        _rebuildReflectionSpans();
      });
      onComplete?.call();
      return;
    }

    final targetNode = result.node;
    if (targetNode == null) return;

    final now = DateTime.now();
    final link = InsightLink(
      id: existingLink?.id ?? 'link-${now.microsecondsSinceEpoch}',
      userId: Supabase.instance.client.auth.currentUser?.id ?? 'local',
      sourceType: InsightSourceType.reflectionEntry,
      sourceId: widget.reflectionId,
      start: selection.start,
      end: selection.end,
      selectedText: selectedInsightText(text: text, selection: selection),
      targetType: InsightTargetType.node,
      targetId: targetNode.id,
      createdAt: existingLink?.createdAt ?? now,
      updatedAt: now,
    );

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final all = await _insightRepo.fetchLinks(userId);
    final filtered =
        all
            .where(
              (existing) =>
                  !(existing.sourceType == InsightSourceType.reflectionEntry &&
                      existing.sourceId == widget.reflectionId),
            )
            .toList()
          ..addAll([...remaining, link]);
    await _insightRepo.saveLinks(userId, filtered);
    setState(() {
      _links = [...remaining, link]..sort((a, b) => a.start.compareTo(b.start));
      _rebuildReflectionSpans();
    });
    onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        iconTheme: const IconThemeData(color: KemeticGold.base),
        title: Text(
          _reflection?.decanName ?? 'Decan Reflection',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openLinkSheet,
            icon: KemeticGold.icon(Icons.link),
            tooltip: 'Link Insight',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(KemeticGold.base),
              ),
            )
          : _reflection == null
          ? Center(
              child: Text(
                'Reflection not found',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : _buildBody(_reflection!),
    );
  }

  Widget _buildBody(DecanReflection reflection) {
    final dateRange =
        '${reflection.decanStart.toLocal().toIso8601String().split("T").first} → ${reflection.decanEnd.toLocal().toIso8601String().split("T").first}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KemeticGold.text(
            reflection.decanName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (reflection.decanTheme != null &&
              reflection.decanTheme!.isNotEmpty)
            Text(
              reflection.decanTheme!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            dateRange,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SelectableText.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
              children: _reflectionSpans,
            ),
            contextMenuBuilder: (context, EditableTextState state) {
              final items = <ContextMenuButtonItem>[
                ...state.contextMenuButtonItems,
                ContextMenuButtonItem(
                  onPressed: () async {
                    final selection = state.textEditingValue.selection;
                    final text = state.textEditingValue.text;
                    Navigator.of(context).pop(); // close menu
                    await _saveLinkSelection(
                      rawSelection: selection,
                      text: text,
                    );
                  },
                  label: 'Link to Node',
                ),
              ];
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: items,
              );
            },
          ),
          if (_links.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Linked nodes',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _links
                  .map(
                    (l) => InputChip(
                      label: Text(
                        l.selectedText.isNotEmpty
                            ? l.selectedText
                            : 'Linked node',
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeLink(l),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openLinkSheet() async {
    if (_reflection == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 12,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Highlight a phrase, then link it to a node.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sheetController,
                readOnly: true,
                maxLines: null,
                enableInteractiveSelection: true,
                style: const TextStyle(color: Colors.white, height: 1.4),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _saveLinkSelection(
                      rawSelection: _sheetController.selection,
                      text: _sheetController.text,
                      onComplete: () {
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Link to Node'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeLink(InsightLink link) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final all = await _insightRepo.fetchLinks(userId);
    final filtered = all
        .where(
          (l) =>
              !(l.sourceType == InsightSourceType.reflectionEntry &&
                  l.sourceId == widget.reflectionId &&
                  l.id == link.id),
        )
        .toList();
    await _insightRepo.saveLinks(userId, filtered);
    setState(() {
      _links = _links.where((l) => l.id != link.id).toList();
      _rebuildReflectionSpans();
    });
  }
}
