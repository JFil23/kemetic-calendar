import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../shared/glossy_text.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../widgets/insight_link_text.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/kemetic_node_reader_page.dart';
import '../nodes/kemetic_node_model.dart';

class DecanReflectionDetailPage extends StatefulWidget {
  final String reflectionId;
  const DecanReflectionDetailPage({super.key, required this.reflectionId});

  @override
  State<DecanReflectionDetailPage> createState() => _DecanReflectionDetailPageState();
}

class _DecanReflectionDetailPageState extends State<DecanReflectionDetailPage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  final _insightRepo = InsightLinkRepo();
  List<InsightLink> _links = [];
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
          .where((l) =>
              l.sourceType == InsightSourceType.reflectionEntry &&
              l.sourceId == widget.reflectionId)
          .toList();
      _sheetController.text = data?.reflectionText ?? '';
      _loading = false;
    });
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
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
          if (reflection.decanTheme != null && reflection.decanTheme!.isNotEmpty)
            Text(
              reflection.decanTheme!,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          const SizedBox(height: 6),
          Text(
            dateRange,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SelectableText.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
              children: InsightLinkSpanBuilder.build(
                text: reflection.reflectionText,
                links: _links,
                baseStyle: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                onTap: (link) {
                  final node = KemeticNodeLibrary.resolve(link.targetId);
                  if (node == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KemeticNodeReaderPage(node: node),
                    ),
                  );
                },
              ),
            ),
            contextMenuBuilder: (context, EditableTextState state) {
              final items = <ContextMenuButtonItem>[
                ...state.contextMenuButtonItems,
                ContextMenuButtonItem(
                  onPressed: () async {
                    final selection = state.textEditingValue.selection;
                    final text = state.textEditingValue.text;
                    if (!selection.isValid || selection.isCollapsed) {
                      Navigator.of(context).pop(); // close menu
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select a phrase first.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    final selected = text.substring(selection.start, selection.end);
                    Navigator.of(context).pop(); // close menu
                    await _createLinkFromSelection(
                      selected,
                      selection.start,
                      selection.end,
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
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
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
                      backgroundColor: Colors.white.withOpacity(0.08),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final sel = _sheetController.selection;
                    if (!sel.isValid || sel.isCollapsed) return;
                    final phrase = _sheetController.text
                        .substring(sel.start, sel.end);
                    final node = await _pickNode();
                    if (node == null) return;
                    final now = DateTime.now();
                    final link = InsightLink(
                      id: 'link-${now.microsecondsSinceEpoch}',
                      userId: Supabase.instance.client.auth.currentUser?.id ??
                          'local',
                      sourceType: InsightSourceType.reflectionEntry,
                      sourceId: widget.reflectionId,
                      start: sel.start,
                      end: sel.end,
                      selectedText: phrase,
                      targetType: InsightTargetType.node,
                      targetId: node.id,
                      createdAt: now,
                      updatedAt: now,
                    );
                    final userId =
                        Supabase.instance.client.auth.currentUser?.id ?? 'local';
                    final all = await _insightRepo.fetchLinks(userId);
                    final filtered = all
                        .where((l) =>
                            !(l.sourceType ==
                                    InsightSourceType.reflectionEntry &&
                                l.sourceId == widget.reflectionId))
                        .toList();
                    filtered.addAll([..._links, link]);
                    await _insightRepo.saveLinks(userId, filtered);
                    setState(() {
                      _links = [..._links, link];
                    });
                    if (mounted) Navigator.of(ctx).pop();
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

  Future<void> _createLinkFromSelection(
    String selected,
    int start,
    int end,
  ) async {
    if (selected.trim().isEmpty) return;
    final node = await _pickNode();
    if (node == null) return;
    final now = DateTime.now();
    final link = InsightLink(
      id: 'link-${now.microsecondsSinceEpoch}',
      userId: Supabase.instance.client.auth.currentUser?.id ?? 'local',
      sourceType: InsightSourceType.reflectionEntry,
      sourceId: widget.reflectionId,
      start: start,
      end: end,
      selectedText: selected,
      targetType: InsightTargetType.node,
      targetId: node.id,
      createdAt: now,
      updatedAt: now,
    );
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final all = await _insightRepo.fetchLinks(userId);
    final filtered = all
        .where((l) =>
            !(l.sourceType == InsightSourceType.reflectionEntry &&
              l.sourceId == widget.reflectionId))
        .toList();
    filtered.addAll([..._links, link]);
    await _insightRepo.saveLinks(userId, filtered);
    setState(() {
      _links = [..._links, link];
    });
  }

  Future<void> _removeLink(InsightLink link) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final all = await _insightRepo.fetchLinks(userId);
    final filtered = all
        .where((l) =>
            !(l.sourceType == InsightSourceType.reflectionEntry &&
              l.sourceId == widget.reflectionId &&
              l.id == link.id))
        .toList();
    await _insightRepo.saveLinks(userId, filtered);
    setState(() {
      _links = _links.where((l) => l.id != link.id).toList();
    });
  }

  Future<KemeticNode?> _pickNode() async {
    final nodes = KemeticNodeLibrary.nodes;
    return showModalBottomSheet<KemeticNode>(
      context: context,
      backgroundColor: Colors.black,
      builder: (ctx) {
        final controller = TextEditingController();
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheet) {
              final query = controller.text.toLowerCase();
              final filtered = nodes
                  .where((n) =>
                      n.title.toLowerCase().contains(query) ||
                      n.aliases.any((a) => a.toLowerCase().contains(query)))
                  .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search nodes…',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final node = filtered[i];
                        return ListTile(
                          title: Text(node.title,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: node.aliases.isNotEmpty
                              ? Text(node.aliases.join(', '),
                                  style:
                                      const TextStyle(color: Colors.white54))
                              : null,
                          onTap: () => Navigator.of(ctx).pop(node),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
