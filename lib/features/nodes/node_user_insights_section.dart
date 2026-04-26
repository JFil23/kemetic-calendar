import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/insight_entry_model.dart';
import '../../data/insight_entry_repo.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../data/journal_repo.dart';
import '../../data/profile_repo.dart';
import '../../shared/glossy_text.dart';
import '../../utils/kemetic_date_format.dart';
import '../../widgets/kemetic_date_picker.dart';
import '../../widgets/insight_link_text.dart';
import 'kemetic_node_model.dart';

class NodeUserInsightsSection extends StatefulWidget {
  final KemeticNode node;

  const NodeUserInsightsSection({super.key, required this.node});

  @override
  State<NodeUserInsightsSection> createState() =>
      _NodeUserInsightsSectionState();
}

class _NodeUserInsightsSectionState extends State<NodeUserInsightsSection> {
  final _entryRepo = InsightEntryRepo(Supabase.instance.client);
  final _linkRepo = InsightLinkRepo();
  final _profileRepo = ProfileRepo(Supabase.instance.client);

  List<InsightEntry> _entries = const [];
  Set<String> _postingEntryIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _entryRepo.fetchEntriesForNode(widget.node.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openEditor({InsightEntry? entry}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF050505),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return _InsightEntryEditorSheet(node: widget.node, initialEntry: entry);
      },
    );

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _postEntry(InsightEntry entry) async {
    if (_postingEntryIds.contains(entry.id)) return;
    setState(() => _postingEntryIds = {..._postingEntryIds, entry.id});
    final posted = await _profileRepo.postInsightEntry(entry.id);
    if (!mounted) return;
    setState(() => _postingEntryIds.remove(entry.id));

    if (posted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not post this insight.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insight posted to your profile'),
        backgroundColor: KemeticGold.base,
      ),
    );
  }

  Future<void> _deleteEntry(InsightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF090909),
        title: const Text(
          'Delete insight?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This removes the dated insight from this node and from your posted insights if it has already been shared.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _entryRepo.deleteEntry(entry);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this insight.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final existingLinks = await _linkRepo.fetchLinks(userId);
    await _linkRepo.saveLinks(
      userId,
      existingLinks
          .where(
            (link) =>
                !(link.sourceType == InsightSourceType.nodeUserText &&
                    link.sourceId == entry.id),
          )
          .toList(),
    );

    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insight deleted'),
        backgroundColor: KemeticGold.base,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
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
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, color: KemeticGold.base, size: 18),
              label: const Text(
                'Add Insight',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Save dated entries for this pillar, revise them later, or add a new one beneath the last.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        if (_entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'No insights yet. Add your first dated reflection for this node.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.35,
              ),
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < _entries.length; i++) ...[
                _buildEntryCard(_entries[i]),
                if (i != _entries.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildEntryCard(InsightEntry entry) {
    final posting = _postingEntryIds.contains(entry.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatKemeticDate(entry.entryDate),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openEditor(entry: entry),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: posting ? null : () => _postEntry(entry),
                child: posting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
              PopupMenuButton<_InsightEntryCardAction>(
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                color: const Color(0xFF141414),
                onSelected: (action) {
                  switch (action) {
                    case _InsightEntryCardAction.delete:
                      _deleteEntry(entry);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _InsightEntryCardAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.bodyText.trim(),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightEntryEditorSheet extends StatefulWidget {
  final KemeticNode node;
  final InsightEntry? initialEntry;

  const _InsightEntryEditorSheet({
    required this.node,
    required this.initialEntry,
  });

  @override
  State<_InsightEntryEditorSheet> createState() =>
      _InsightEntryEditorSheetState();
}

class _InsightEntryEditorSheetState extends State<_InsightEntryEditorSheet> {
  final _entryRepo = InsightEntryRepo(Supabase.instance.client);
  final _linkRepo = InsightLinkRepo();
  final _textCtrl = TextEditingController();

  List<InsightLink> _links = const [];
  DateTime _entryDate = DateTime.now();
  String _previousText = '';
  bool _saving = false;
  bool _loading = true;

  String? get _entryId => widget.initialEntry?.id;

  @override
  void initState() {
    super.initState();
    _textCtrl.text = widget.initialEntry?.bodyText ?? '';
    _previousText = _textCtrl.text;
    _entryDate = widget.initialEntry?.entryDate ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    if (_entryId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final links = await _linkRepo.fetchLinks(userId);
    if (!mounted) return;
    setState(() {
      _links = links
          .where(
            (link) =>
                link.sourceType == InsightSourceType.nodeUserText &&
                link.sourceId == _entryId,
          )
          .toList();
      _loading = false;
    });
  }

  Future<void> _saveLinks() async {
    final sourceId = _entryId;
    if (sourceId == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final existing = await _linkRepo.fetchLinks(userId);
    final filtered =
        existing
            .where(
              (link) =>
                  !(link.sourceType == InsightSourceType.nodeUserText &&
                      link.sourceId == sourceId),
            )
            .toList()
          ..addAll(_links);
    await _linkRepo.saveLinks(userId, filtered);
  }

  void _onTextChanged(String value) {
    final updated = InsightLinkRangeUpdater.shiftRanges(
      previous: _previousText,
      next: value,
      links: _links,
    );
    setState(() {
      _links = updated;
      _previousText = value;
    });
    _saveLinks();
  }

  Future<void> _removeLink(InsightLink link) async {
    setState(() {
      _links = _links.where((entry) => entry.id != link.id).toList();
    });
    await _saveLinks();
  }

  Future<void> _startLinkToEntry(InsightTargetType targetType) async {
    final sourceId = _entryId;
    if (sourceId == null) {
      _showMessage('Save this insight once before linking phrases.');
      return;
    }

    final selection = _textCtrl.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _showMessage('Select a phrase first.');
      return;
    }

    final selected = _textCtrl.text
        .substring(selection.start, selection.end)
        .trim();
    if (selected.isEmpty) {
      _showMessage('Select a phrase first.');
      return;
    }

    final targetChoice = await _pickTarget(targetType);
    if (!mounted || targetChoice == null) return;

    final now = DateTime.now();
    final link = InsightLink(
      id: 'link-${now.microsecondsSinceEpoch}',
      userId: Supabase.instance.client.auth.currentUser?.id ?? 'local',
      sourceType: InsightSourceType.nodeUserText,
      sourceId: sourceId,
      start: selection.start,
      end: selection.end,
      selectedText: selected,
      targetType: targetType,
      targetId: targetChoice.id,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _links = [..._links, link];
    });
    await _saveLinks();
  }

  Future<_InsightTargetChoice?> _pickTarget(
    InsightTargetType targetType,
  ) async {
    if (targetType == InsightTargetType.journalEntry) {
      final repo = JournalRepo(Supabase.instance.client);
      final entries = await repo.listRecent(days: 90);
      if (!mounted || entries.isEmpty) return null;

      return showModalBottomSheet<_InsightTargetChoice>(
        context: context,
        backgroundColor: Colors.black,
        builder: (ctx) {
          final controller = TextEditingController();
          return SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheet) {
                final query = controller.text.toLowerCase();
                final filtered = entries.where((entry) {
                  return entry.body.toLowerCase().contains(query) ||
                      entry.category?.toLowerCase().contains(query) == true;
                }).toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
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
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          return ListTile(
                            title: Text(
                              entry.body.trim().isEmpty
                                  ? '(empty entry)'
                                  : entry.body.trim().split('\n').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              formatKemeticDate(entry.gregDate),
                              style: const TextStyle(color: Colors.white54),
                            ),
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pop(_InsightTargetChoice(entry.id));
                            },
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

    if (targetType == InsightTargetType.reflectionEntry) {
      final repo = DecanReflectionRepo(Supabase.instance.client);
      final latest = await repo.getLatest();
      if (latest == null) return null;
      return _InsightTargetChoice(latest.id);
    }

    return null;
  }

  Future<void> _pickDate() async {
    final selected = await showKemeticDatePicker(
      context: context,
      initialDate: _entryDate,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _entryDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _saveEntry() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      _showMessage('Write something before saving.');
      return;
    }

    setState(() => _saving = true);
    final saved = await _entryRepo.saveEntry(
      entryId: _entryId,
      nodeSlug: widget.node.id,
      bodyText: text,
      entryDate: _entryDate,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (saved == null) {
      _showMessage('Could not save this insight.');
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(KemeticGold.base),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      widget.initialEntry == null
                          ? 'New ${widget.node.title} Insight'
                          : 'Edit ${widget.node.title} Insight',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _pickDate,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                        foregroundColor: KemeticGold.base,
                      ),
                      icon: const Icon(Icons.event_note_outlined, size: 18),
                      label: Text(
                        formatKemeticDate(_entryDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textCtrl,
                                onChanged: _onTextChanged,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'Add your insight for this node. You can date it like a journal entry.',
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                            if (_links.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _links
                                      .map(
                                        (link) => InputChip(
                                          label: Text(
                                            link.selectedText.isNotEmpty
                                                ? link.selectedText
                                                : (link.targetType ==
                                                          InsightTargetType
                                                              .journalEntry
                                                      ? 'Journal link'
                                                      : 'Reflection link'),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          deleteIcon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          onDeleted: () => _removeLink(link),
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.08),
                                          labelStyle: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _startLinkToEntry(InsightTargetType.journalEntry),
                          icon: const Icon(
                            Icons.book_outlined,
                            size: 18,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'Link to Journal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _startLinkToEntry(
                            InsightTargetType.reflectionEntry,
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'Link to Reflection',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KemeticGold.base,
                          foregroundColor: Colors.black,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Text('Save Insight'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InsightTargetChoice {
  final String id;

  const _InsightTargetChoice(this.id);
}

enum _InsightEntryCardAction { delete }
