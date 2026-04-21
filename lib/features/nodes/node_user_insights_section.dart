import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../widgets/insight_link_text.dart';
import 'kemetic_node_model.dart';
import 'kemetic_node_library.dart';
import 'kemetic_node_reader_page.dart';
import '../../shared/glossy_text.dart';
import '../../data/journal_repo.dart';
import '../../data/decan_reflection_repo.dart';
import '../reflections/decan_reflection_detail_page.dart';
import '../journal/journal_entry_detail_page.dart';

class NodeUserInsightsSection extends StatefulWidget {
  final KemeticNode node;

  const NodeUserInsightsSection({super.key, required this.node});

  @override
  State<NodeUserInsightsSection> createState() =>
      _NodeUserInsightsSectionState();
}

class _NodeUserInsightsSectionState extends State<NodeUserInsightsSection> {
  final _repo = InsightLinkRepo();
  final _textCtrl = TextEditingController();
  String _prevText = '';
  bool _editing = false;
  List<NodeUserContent> _allContent = [];
  List<InsightLink> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    var content = await _repo.fetchNodeContent(userId);
    final links = await _repo.fetchLinks(userId);
    var current = content.firstWhere(
      (c) => c.nodeId == widget.node.id,
      orElse: () => NodeUserContent(
        id: 'node-${widget.node.id}',
        userId: userId,
        nodeId: widget.node.id,
        text: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    if (!content.any((c) => c.nodeId == widget.node.id)) {
      content = [...content, current];
    }
    setState(() {
      _allContent = content;
      _links = links
          .where(
            (l) =>
                l.sourceType == InsightSourceType.nodeUserText &&
                l.sourceId == current.id,
          )
          .toList();
      _textCtrl.text = current.text;
      _prevText = current.text;
      _loading = false;
    });
  }

  Future<void> _saveText() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final now = DateTime.now();
    final existingIdx = _allContent.indexWhere(
      (c) => c.nodeId == widget.node.id && c.userId == userId,
    );
    if (existingIdx == -1) {
      _allContent.add(
        NodeUserContent(
          id: 'node-${widget.node.id}',
          userId: userId,
          nodeId: widget.node.id,
          text: _textCtrl.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      _allContent[existingIdx] = _allContent[existingIdx].copyWith(
        text: _textCtrl.text.trim(),
        updatedAt: now,
      );
    }
    await _repo.saveNodeContent(userId, _allContent);
    setState(() {
      _prevText = _textCtrl.text;
      _editing = false;
    });
  }

  void _onTextChanged(String value) {
    final updated = InsightLinkRangeUpdater.shiftRanges(
      previous: _prevText,
      next: value,
      links: _links,
    );
    setState(() {
      _links = updated;
      _prevText = value;
    });
    _saveLinks();
  }

  Future<void> _saveLinks() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final existing = await _repo.fetchLinks(userId);
    final filtered = existing
        .where(
          (l) =>
              !(l.sourceType == InsightSourceType.nodeUserText &&
                  l.sourceId == 'node-${widget.node.id}'),
        )
        .toList();
    filtered.addAll(_links);
    await _repo.saveLinks(userId, filtered);
  }

  Future<void> _removeLink(InsightLink link) async {
    setState(() {
      _links = _links.where((l) => l.id != link.id).toList();
    });
    await _saveLinks();
  }

  Future<void> _startLinkToEntry(InsightTargetType target) async {
    final selection = _textCtrl.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final selected = _textCtrl.text
        .substring(selection.start, selection.end)
        .trim();
    if (selected.isEmpty) return;
    final targetChoice = await _pickTarget(target);
    if (targetChoice == null) return;
    final now = DateTime.now();
    final newLink = InsightLink(
      id: 'link-${now.microsecondsSinceEpoch}',
      userId: Supabase.instance.client.auth.currentUser?.id ?? 'local',
      sourceType: InsightSourceType.nodeUserText,
      sourceId: 'node-${widget.node.id}',
      start: selection.start,
      end: selection.end,
      selectedText: selected,
      targetType: target,
      targetId: targetChoice.id,
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _links = [..._links, newLink];
    });
    await _saveLinks();
  }

  Future<_PickerResult?> _pickTarget(InsightTargetType target) async {
    if (target == InsightTargetType.journalEntry) {
      final repo = JournalRepo(Supabase.instance.client);
      final entries = await repo.listRecent(days: 60);
      if (!mounted) return null;
      if (entries.isEmpty) return null;
      return showModalBottomSheet<_PickerResult>(
        context: context,
        backgroundColor: Colors.black,
        builder: (ctx) {
          final controller = TextEditingController();
          return SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheet) {
                final query = controller.text.toLowerCase();
                final filtered = entries.where((e) {
                  return e.body.toLowerCase().contains(query) ||
                      e.category?.toLowerCase().contains(query) == true;
                }).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search journal…',
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
                          final e = filtered[i];
                          return ListTile(
                            title: Text(
                              e.body.trim().isEmpty
                                  ? '(empty entry)'
                                  : e.body.trim().split('\n').first,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              e.gregDate.toIso8601String().split('T').first,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () => Navigator.of(ctx).pop(
                              _PickerResult(
                                e.id,
                                e.body,
                                subtitle: e.gregDate
                                    .toIso8601String()
                                    .split('T')
                                    .first,
                              ),
                            ),
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
    if (target == InsightTargetType.reflectionEntry) {
      final repo = DecanReflectionRepo(Supabase.instance.client);
      final latest = await repo.getLatest();
      if (latest == null) return null;
      return _PickerResult(
        latest.id,
        latest.decanName,
        subtitle: latest.decanTheme ?? '',
      );
    }
    return null;
  }

  void _handleLinkTap(InsightLink link) {
    if (link.targetType == InsightTargetType.node) {
      final node = KemeticNodeLibrary.resolve(link.targetId);
      if (node == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KemeticNodeReaderPage(node: node)),
      );
      return;
    }
    if (link.targetType == InsightTargetType.journalEntry) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JournalEntryDetailPage(entryId: link.targetId),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              DecanReflectionDetailPage(reflectionId: link.targetId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(KemeticGold.base),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            KemeticGold.text(
              'Your Insights',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _editing = !_editing),
              icon: Icon(
                _editing ? Icons.check : Icons.edit,
                color: KemeticGold.base,
                size: 18,
              ),
              label: Text(
                _editing ? 'Done' : 'Edit',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_editing) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  controller: _textCtrl,
                  onChanged: _onTextChanged,
                  maxLines: null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Add your insight or notes for this node...',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                if (_links.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _links
                          .map(
                            (l) => InputChip(
                              label: Text(
                                l.selectedText.isNotEmpty
                                    ? l.selectedText
                                    : (l.targetType ==
                                              InsightTargetType.journalEntry
                                          ? 'Journal link'
                                          : 'Reflection link'),
                                overflow: TextOverflow.ellipsis,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _removeLink(l),
                              backgroundColor: Colors.white.withOpacity(0.08),
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _startLinkToEntry(InsightTargetType.journalEntry),
                      icon: const Icon(
                        Icons.book,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        'Link to Journal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _startLinkToEntry(InsightTargetType.reflectionEntry),
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        'Link to Reflection',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _saveText,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KemeticGold.base.withOpacity(0.2),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          if (_textCtrl.text.trim().isEmpty)
            const Text(
              'No insights yet. Add your own reflections for this node.',
              style: TextStyle(color: Colors.white60),
            )
          else
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, height: 1.4),
                children: InsightLinkSpanBuilder.build(
                  text: _textCtrl.text,
                  links: _links,
                  baseStyle: const TextStyle(color: Colors.white, height: 1.4),
                  onTap: _handleLinkTap,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PickerResult {
  final String id;
  final String title;
  final String? subtitle;

  _PickerResult(this.id, this.title, {this.subtitle});
}
