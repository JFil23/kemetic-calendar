import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../shared/glossy_text.dart';

import '../../data/decan_reflection_repo.dart';
import '../../data/decan_reflection_model.dart';
import '../../data/decan_reflection_prompt_state.dart';
import '../../data/insight_link_model.dart';
import '../../data/insight_link_repo.dart';
import '../../data/insight_link_utils.dart';
import '../../widgets/insight_link_text.dart';
import '../calendar/calendar_page.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/kemetic_node_model.dart';
import '../nodes/node_link_picker_sheet.dart';

class DecanReflectionDetailPage extends StatefulWidget {
  final String reflectionId;
  const DecanReflectionDetailPage({super.key, required this.reflectionId});

  @override
  State<DecanReflectionDetailPage> createState() =>
      _DecanReflectionDetailPageState();
}

class _DecanReflectionDetailPageState extends State<DecanReflectionDetailPage> {
  final _repo = DecanReflectionRepo(Supabase.instance.client);
  final _promptState = DecanReflectionPromptState(Supabase.instance.client);
  final _insightRepo = InsightLinkRepo();
  List<InsightLink> _links = [];
  final List<GestureRecognizer> _linkGestureRecognizers = [];
  List<InlineSpan> _reflectionSpans = const [];
  DecanReflection? _reflection;
  DecanReflectionGraphHints? _graphHints;
  List<DecanReflectionSuggestedNodeLink> _suggestedNodeLinks = const [];
  TextSelection _reflectionSelection = const TextSelection.collapsed(
    offset: -1,
  );
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeLinkGestureRecognizers();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _repo.getById(widget.reflectionId);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    final links = await _insightRepo.fetchLinks(userId);
    final graphHints = data == null
        ? null
        : await _repo.getGraphHintsForReflection(data);
    if (data != null) {
      await _promptState.markInteracted(data.decanStart);
      await _repo.markPromptInteracted(
        decanStart: data.decanStart,
        decanEnd: data.decanEnd,
        interactionKind: 'archived',
      );
    }
    if (!mounted) return;
    final reflectionLinks = links
        .where(
          (l) =>
              l.sourceType == InsightSourceType.reflectionEntry &&
              l.sourceId == widget.reflectionId,
        )
        .toList();
    setState(() {
      _reflection = data;
      _graphHints = graphHints;
      _links = reflectionLinks;
      _suggestedNodeLinks = buildDecanReflectionSuggestedNodeLinks(
        graphHints,
        _links,
      );
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
    context.go('/nodes/${Uri.encodeComponent(node.id)}');
  }

  Future<void> _openSuggestedNode(
    DecanReflectionSuggestedNodeLink suggestion,
  ) async {
    await _repo.recordSuggestedNodeTap(
      reflectionId: widget.reflectionId,
      nodeSlug: suggestion.node.id,
    );
    if (!mounted) return;
    context.go('/nodes/${Uri.encodeComponent(suggestion.node.id)}');
  }

  Future<void> _handleReflectionCta(DecanReflectionCta cta) async {
    if (!cta.hasDestination) return;
    switch (cta.type) {
      case 'node':
        context.go('/nodes/${Uri.encodeComponent(cta.ref)}');
        return;
      case 'flow':
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: <String, dynamic>{
            'mode': 'myFlows',
            if (int.tryParse(cta.ref) != null)
              'initialFlowId': int.parse(cta.ref),
          },
        );
        return;
      case 'flow_template':
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: <String, dynamic>{
            'mode': 'maatTemplate',
            'templateKey': cta.ref,
          },
        );
        return;
      case 'flow_personalized':
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: <String, dynamic>{
            'mode': cta.fallbackRef == null ? 'maatFlows' : 'maatTemplate',
            if (cta.fallbackRef != null) 'templateKey': cta.fallbackRef,
          },
        );
        return;
      default:
        return;
    }
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
        _suggestedNodeLinks = buildDecanReflectionSuggestedNodeLinks(
          _graphHints,
          _links,
        );
        _rebuildReflectionSpans();
      });
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
      _suggestedNodeLinks = buildDecanReflectionSuggestedNodeLinks(
        _graphHints,
        _links,
      );
      _rebuildReflectionSpans();
    });
  }

  Future<void> _startLinkFlow() async {
    final reflection = _reflection;
    if (reflection == null) return;
    await _saveLinkSelection(
      rawSelection: _reflectionSelection,
      text: reflection.reflectionText,
    );
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
          onPressed: () => popOrGo(context, '/reflections'),
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
            onPressed: _startLinkFlow,
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
            onSelectionChanged: (selection, _) {
              _reflectionSelection = selection;
            },
          ),
          if (_graphHints?.cta?.hasDestination == true) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleReflectionCta(_graphHints!.cta!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KemeticGold.base,
                  side: BorderSide(
                    color: KemeticGold.base.withValues(alpha: 0.55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _graphHints!.cta!.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (_suggestedNodeLinks.isNotEmpty) ...[
            const SizedBox(height: 18),
            DecanReflectionSuggestedNodeChips(
              suggestions: _suggestedNodeLinks,
              onOpenSuggestedNode: _openSuggestedNode,
            ),
          ],
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
      _suggestedNodeLinks = buildDecanReflectionSuggestedNodeLinks(
        _graphHints,
        _links,
      );
      _rebuildReflectionSpans();
    });
  }
}

class DecanReflectionSuggestedNodeLink {
  final KemeticNode node;
  final String reason;

  const DecanReflectionSuggestedNodeLink({
    required this.node,
    required this.reason,
  });
}

class DecanReflectionSuggestedNodeChips extends StatelessWidget {
  const DecanReflectionSuggestedNodeChips({
    super.key,
    required this.suggestions,
    required this.onOpenSuggestedNode,
  });

  final List<DecanReflectionSuggestedNodeLink> suggestions;
  final void Function(DecanReflectionSuggestedNodeLink suggestion)
  onOpenSuggestedNode;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Continue in the graph',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map(
                (suggestion) => ActionChip(
                  avatar: suggestion.node.glyph.trim().isEmpty
                      ? null
                      : Text(
                          suggestion.node.glyph,
                          style: const TextStyle(
                            color: KemeticGold.base,
                            fontSize: 15,
                          ),
                        ),
                  label: Text(
                    suggestion.node.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  tooltip: suggestion.reason,
                  onPressed: () => onOpenSuggestedNode(suggestion),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: KemeticGold.base.withValues(alpha: 0.35),
                  ),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

const Map<String, List<String>> _leadAxisNodeCandidates = {
  'T': ['maat', 'djehuty'],
  'M': ['djehuty', 'maat'],
  'H': ['ka', 'sekhmet'],
  'V': ['instruction_amenemope', 'renenutet'],
  'J': ['maat', 'instruction_amenemope'],
  'S': ['renenutet', 'nile'],
  'E': ['nile', 'renenutet'],
  'R': ['instruction_amenemope', 'sekhmet'],
  'C': ['ptah', 'maat'],
};

const Map<String, String> _leadAxisReason = {
  'T': 'Truth and speech integrity',
  'M': 'Measure and record',
  'H': 'Life-preserving rhythm',
  'V': 'Protection and care',
  'J': 'Due measure',
  'S': 'Provision and stewardship',
  'E': 'Seasonal flow',
  'R': 'Restraint and self-command',
  'C': 'Continuity and role fidelity',
};

List<DecanReflectionSuggestedNodeLink> buildDecanReflectionSuggestedNodeLinks(
  DecanReflectionGraphHints? hints,
  List<InsightLink> existingLinks,
) {
  if (hints == null || hints.isEmpty) {
    return const <DecanReflectionSuggestedNodeLink>[];
  }

  final linkedNodeIds = existingLinks
      .where((link) => link.targetType == InsightTargetType.node)
      .map((link) => link.targetId.trim().toLowerCase())
      .toSet();
  final seenNodeIds = <String>{...linkedNodeIds};
  final suggestions = <DecanReflectionSuggestedNodeLink>[];

  void addNode(String slugOrAlias, String reason) {
    if (suggestions.length >= 2) return;
    final slug = slugOrAlias.trim();
    if (slug.isEmpty || slug.toLowerCase() == 'isfet') return;
    final node = KemeticNodeLibrary.resolve(slug);
    if (node == null) return;
    final key = node.id.toLowerCase();
    if (seenNodeIds.contains(key)) return;
    seenNodeIds.add(key);
    suggestions.add(
      DecanReflectionSuggestedNodeLink(node: node, reason: reason),
    );
  }

  final fallbackNode = hints.fallbackNode;
  if (fallbackNode?.hasNode == true) {
    addNode(fallbackNode!.ref, fallbackNode.label);
  }

  final leadAxis = hints.leadAxis?.trim().toUpperCase();
  if (leadAxis != null) {
    for (final slug in _leadAxisNodeCandidates[leadAxis] ?? const <String>[]) {
      addNode(slug, _leadAxisReason[leadAxis] ?? 'Reflection pattern');
      if (suggestions.isNotEmpty) break;
    }
  }

  for (final slug in hints.anchorNodes) {
    addNode(slug, 'From this reflection');
  }

  if (suggestions.length < 2 && leadAxis != null) {
    for (final slug in _leadAxisNodeCandidates[leadAxis] ?? const <String>[]) {
      addNode(slug, _leadAxisReason[leadAxis] ?? 'Reflection pattern');
    }
  }

  return List.unmodifiable(suggestions);
}
