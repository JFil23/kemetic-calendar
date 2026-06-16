import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';

import '../../data/choice_event_repo.dart';
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
import 'decan_reflection_skin.dart';

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
  final ChoiceEventTracker _choiceEvents = SupabaseChoiceEventTracker(
    Supabase.instance.client,
  );
  final _insightRepo = InsightLinkRepo();
  List<InsightLink> _links = [];
  final List<GestureRecognizer> _linkGestureRecognizers = [];
  final Set<String> _nodeLinkTapKeys = <String>{};
  List<InlineSpan> _reflectionSpans = const [];
  String _reflectionBodyText = '';
  String? _reflectionRiteText;
  DecanReflection? _reflection;
  DecanReflectionGraphHints? _graphHints;
  List<DecanReflectionSuggestedNodeLink> _suggestedNodeLinks = const [];
  TextSelection _reflectionSelection = const TextSelection.collapsed(
    offset: -1,
  );
  bool _loading = true;
  bool _reflectionOpenRecorded = false;

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
      unawaited(_recordReflectionOpened(data));
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

  Future<void> _recordReflectionOpened(DecanReflection reflection) async {
    if (_reflectionOpenRecorded) return;
    _reflectionOpenRecorded = true;
    await _choiceEvents.trackChoiceEvent(
      eventType: 'reflection_opened',
      reflectionId: reflection.id,
      sourceSurface: 'decan_reflection_detail',
      metadata: <String, dynamic>{
        'decan_start': reflection.decanStart.toUtc().toIso8601String(),
        'decan_end': reflection.decanEnd.toUtc().toIso8601String(),
        'decan_name': reflection.decanName,
      },
    );
  }

  Future<void> _recordNodeLinkTapped({
    required String nodeSlug,
    required String sourceSurface,
    Map<String, dynamic>? metadata,
  }) async {
    final slug = nodeSlug.trim();
    if (slug.isEmpty) return;
    final key = '$sourceSurface:$slug';
    if (!_nodeLinkTapKeys.add(key)) return;
    await _choiceEvents.trackChoiceEvent(
      eventType: 'node_link_tapped',
      nodeSlug: slug,
      reflectionId: widget.reflectionId,
      sourceSurface: sourceSurface,
      metadata: metadata,
    );
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
      _reflectionBodyText = '';
      _reflectionRiteText = null;
      return;
    }
    final parts = _splitReflectionTextForFolio(reflection.reflectionText);
    _reflectionBodyText = parts.body;
    _reflectionRiteText = parts.rite;
    final bodyLinks = _links
        .where((link) => link.start >= 0 && link.end <= parts.body.length)
        .toList(growable: false);
    // SelectableText.rich only supports TextSpan children, so this page uses
    // recognizer-backed text spans instead of the default WidgetSpan links.
    _reflectionSpans = InsightLinkSpanBuilder.build(
      text: parts.body,
      links: bodyLinks,
      baseStyle: DecanReflectionTokens.bodyStyle,
      onTap: _handleLinkTap,
      mode: InsightLinkSpanRenderMode.textSpan,
      gestureRecognizers: _linkGestureRecognizers,
    );
  }

  void _handleLinkTap(InsightLink link) {
    final node = KemeticNodeLibrary.resolve(link.targetId);
    if (node == null) return;
    unawaited(
      _recordNodeLinkTapped(
        nodeSlug: node.id,
        sourceSurface: 'decan_reflection_inline_link',
        metadata: <String, dynamic>{'link_id': link.id},
      ),
    );
    unawaited(
      openDetailRoute<void>(context, '/nodes/${Uri.encodeComponent(node.id)}'),
    );
  }

  Future<void> _openSuggestedNode(
    DecanReflectionSuggestedNodeLink suggestion,
  ) async {
    await _repo.recordSuggestedNodeTap(
      reflectionId: widget.reflectionId,
      nodeSlug: suggestion.node.id,
    );
    unawaited(
      _recordNodeLinkTapped(
        nodeSlug: suggestion.node.id,
        sourceSurface: 'decan_reflection_library_continuation',
        metadata: <String, dynamic>{'reason': suggestion.reason},
      ),
    );
    if (!mounted) return;
    unawaited(
      openDetailRoute<void>(
        context,
        '/nodes/${Uri.encodeComponent(suggestion.node.id)}',
      ),
    );
  }

  Future<void> _handleReflectionCta(DecanReflectionCta cta) async {
    if (!cta.hasDestination) return;
    switch (cta.type) {
      case 'node':
        unawaited(
          _recordNodeLinkTapped(
            nodeSlug: cta.ref,
            sourceSurface: 'decan_reflection_cta',
            metadata: <String, dynamic>{'cta_label': cta.label},
          ),
        );
        unawaited(
          openDetailRoute<void>(
            context,
            '/nodes/${Uri.encodeComponent(cta.ref)}',
          ),
        );
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
    return DecanReflectionSkinScaffold(
      navBar: DecanReflectionNavBar(
        title: 'Reflection',
        onBack: () => popOrGo(context, '/reflections'),
        right: DecanReflectionNavIconButton(
          onPressed: _startLinkFlow,
          icon: Icons.link,
          iconSize: 22,
          tooltip: 'Link Insight',
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(DecanReflectionTokens.gold),
          strokeWidth: 2,
        ),
      );
    }
    if (_reflection == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'Reflection not found',
            textAlign: TextAlign.center,
            style: DecanReflectionTokens.emptyBodyStyle,
          ),
        ),
      );
    }
    return _buildBody(_reflection!);
  }

  Widget _buildBody(DecanReflection reflection) {
    final dateRange =
        '${reflection.decanStart.toLocal().toIso8601String().split("T").first} → ${reflection.decanEnd.toLocal().toIso8601String().split("T").first}';
    final bottomPadding =
        DecanReflectionTokens.scrollBottomPadding +
        MediaQuery.paddingOf(context).bottom;
    final subtitle = _folioSubtitleFor(reflection);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(30, 14, 30, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecanFolioMasthead(
            title: reflection.decanName,
            subtitle: subtitle,
            dateRange: dateRange,
          ),
          if (_reflectionBodyText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
              child: SelectableText.rich(
                TextSpan(
                  style: DecanReflectionTokens.bodyStyle,
                  children: _reflectionSpans,
                ),
                onSelectionChanged: (selection, _) {
                  _reflectionSelection = selection;
                },
              ),
            ),
          if (_reflectionRiteText != null)
            DecanRiteBlock(question: _reflectionRiteText!),
          if (_graphHints?.cta?.hasDestination == true) ...[
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                DecanBridgeAction(
                  label: _graphHints!.cta!.label,
                  onPressed: () => _handleReflectionCta(_graphHints!.cta!),
                ),
              ],
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
            const SizedBox(height: 18),
            Text(
              'Linked nodes',
              style: DecanReflectionTokens.bridgeStyle.copyWith(
                color: DecanReflectionTokens.inkMid,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _links
                  .map(
                    (link) => InputChip(
                      label: Text(
                        link.selectedText.isNotEmpty
                            ? link.selectedText
                            : 'Linked node',
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeLink(link),
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: DecanReflectionTokens.hairline,
                      ),
                      deleteIconColor: DecanReflectionTokens.gold,
                      labelStyle: DecanReflectionTokens.bridgeStyle.copyWith(
                        color: DecanReflectionTokens.inkSoft,
                      ),
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

class _ReflectionTextParts {
  const _ReflectionTextParts({required this.body, this.rite});

  final String body;
  final String? rite;
}

_ReflectionTextParts _splitReflectionTextForFolio(String value) {
  final text = value.trim();
  if (text.isEmpty) return const _ReflectionTextParts(body: '');

  final separators = RegExp(r'\n\s*\n').allMatches(text).toList();
  if (separators.isEmpty) {
    return _ReflectionTextParts(body: text);
  }

  final lastSeparator = separators.last;
  final candidate = text.substring(lastSeparator.end).trim();
  final body = text.substring(0, lastSeparator.start).trimRight();
  if (body.isEmpty || !_looksLikeRiteText(candidate)) {
    return _ReflectionTextParts(body: text);
  }

  return _ReflectionTextParts(body: body, rite: candidate);
}

bool _looksLikeRiteText(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  return text.endsWith('?') || lower.startsWith('before the next decan opens');
}

String? _folioSubtitleFor(DecanReflection reflection) {
  final theme = reflection.decanTheme?.trim();
  if (theme == null || theme.isEmpty || theme == reflection.decanName.trim()) {
    return null;
  }
  return theme;
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
      children: <Widget>[
        Text(
          'Continue in the graph',
          style: DecanReflectionTokens.bridgeStyle.copyWith(
            color: DecanReflectionTokens.inkMid,
          ),
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
                            color: DecanReflectionTokens.gold,
                            fontSize: 15,
                          ),
                        ),
                  label: Text(
                    suggestion.node.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  tooltip: suggestion.reason,
                  onPressed: () => onOpenSuggestedNode(suggestion),
                  backgroundColor: const Color.fromRGBO(212, 174, 67, 0.05),
                  side: const BorderSide(color: DecanReflectionTokens.hairline),
                  labelStyle: DecanReflectionTokens.bridgeStyle.copyWith(
                    color: DecanReflectionTokens.gold,
                  ),
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
  final primaryCta = hints.cta;
  if (primaryCta?.type == 'node' && primaryCta?.hasDestination == true) {
    addNode(primaryCta!.ref, primaryCta.label);
  }
  if (fallbackNode?.hasNode == true) {
    addNode(fallbackNode!.ref, fallbackNode.label);
  }
  final canonicalNode = hints.canonicalNode;
  if (canonicalNode?.hasNode == true) {
    addNode(canonicalNode!.ref, canonicalNode.label);
  }

  for (final slug in hints.anchorNodes) {
    addNode(slug, 'From this reflection');
  }

  final leadAxis = hints.leadAxis?.trim().toUpperCase();
  if (leadAxis != null) {
    for (final slug in _leadAxisNodeCandidates[leadAxis] ?? const <String>[]) {
      addNode(slug, _leadAxisReason[leadAxis] ?? 'Reflection pattern');
      if (suggestions.isNotEmpty) break;
    }
  }

  if (suggestions.length < 2 && leadAxis != null) {
    for (final slug in _leadAxisNodeCandidates[leadAxis] ?? const <String>[]) {
      addNode(slug, _leadAxisReason[leadAxis] ?? 'Reflection pattern');
    }
  }

  return List.unmodifiable(suggestions);
}
