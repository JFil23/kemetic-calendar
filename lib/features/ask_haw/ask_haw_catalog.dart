import '../../data/flows_repo.dart';
import '../calendar/decan_reflection_composition/maat_flow_profile_catalog.dart';
import '../calendar/maat_flow_catalog.dart';
import '../calendar/maat_flow_identity.dart';
import '../calendar/the_djed_flow.dart';
import '../calendar/the_kar/the_kar_flow.dart';
import '../calendar/the_offering_table_flow.dart';
import '../calendar/the_reading_house_flow.dart';
import '../nodes/kemetic_node_library.dart';
import '../nodes/library_canon_adapter.dart';
import 'ask_haw_flow_contract.dart';
import 'ask_haw_memory.dart';
import 'ask_haw_models.dart';
import 'ask_haw_recognizer.dart';

/// This is a projection, never a second content store or permission resolver.
/// Callers supply already authorized Flows. Public discovery performs no reads.
class AskHawCatalog {
  AskHawCatalog(Iterable<AskHawContent> entries)
    : entries = List<AskHawContent>.unmodifiable(entries);
  final List<AskHawContent> entries;
  AskHawContent? byId(String id) {
    for (final content in entries) {
      if (content.id == id) return content;
    }
    return null;
  }

  List<AskHawMatch> search(
    String query, {
    AskHawMemory? memory,
    bool optional = false,
    int? maxMinutes,
    int limit = 20,
    AskHawContentKind? kind,
    DateTime? nowUtc,
  }) {
    if (limit <= 0 || (optional && memory?.suggestionsEnabled == false)) {
      return [];
    }
    final normalized = normalizeAskHaw(query);
    final terms = askHawSearchTerms(normalized);
    final requiresBeginner =
        terms.remove('beginner') || terms.remove('beginners');
    final matches = <AskHawMatch>[];
    for (final content in entries) {
      if (kind != null && content.kind != kind) continue;
      if (optional && memory?.hiddenSuggestions.contains(content.id) == true) {
        continue;
      }
      if (maxMinutes != null &&
          (content.durationMinutes == null ||
              content.durationMinutes! > maxMinutes)) {
        continue;
      }
      if (requiresBeginner && content.beginner != true) continue;
      final title = normalizeAskHaw(content.title);
      final aliases = content.aliases.map(normalizeAskHaw).toList();
      final headings =
          '$title ${aliases.join(' ')} ${content.topics.map(normalizeAskHaw).join(' ')}';
      final summary = normalizeAskHaw(content.summary);
      final matched = <String>[];
      var score = 0;
      if (normalized.isNotEmpty &&
          (title == normalized || aliases.contains(normalized))) {
        score += 100;
      }
      for (final term in terms) {
        final word = RegExp('(^| )${RegExp.escape(term)}(s)?( |\$)');
        if (word.hasMatch(headings)) {
          matched.add(term);
          score += 12;
        } else if (word.hasMatch(summary)) {
          matched.add(term);
          score += 2;
        }
      }
      if (terms.isNotEmpty && matched.length != terms.length) continue;
      if (terms.isNotEmpty && score == 0) continue;
      if (content.active && !content.paused) score += 4;
      // Confirmed interests and bounded signals affect ordering, never eligibility.
      final interests = memory?.preferences['interests'];
      if (interests is List &&
          interests.whereType<String>().any(
            (value) => content.topics.any(
              (topic) => normalizeAskHaw(topic) == normalizeAskHaw(value),
            ),
          )) {
        score += 3;
      }
      final signal = memory?.signals[content.id];
      if (signal is Map && signal['selectedCount'] is num && nowUtc != null) {
        final selectedAt = DateTime.tryParse(
          signal['lastSelectedAt']?.toString() ?? '',
        );
        final age = selectedAt == null
            ? null
            : nowUtc.toUtc().difference(selectedAt.toUtc());
        if (age != null && !age.isNegative && age.inDays < 90) {
          final count = (signal['selectedCount'] as num)
              .toInt()
              .clamp(0, 3)
              .toInt();
          score += age.inDays < 30
              ? count
              : age.inDays < 60
              ? count.clamp(0, 2).toInt()
              : count.clamp(0, 1).toInt();
        }
      }
      final reason = matched.isNotEmpty
          ? 'Matches ${matched.join(', ')}${content.active ? ' in a Flow you already keep' : ''}.'
          : content.active
          ? 'From a Flow you already keep.'
          : maxMinutes != null
          ? 'Its ${content.durationMinutes}-minute reading fits your time.'
          : 'Available in your Library and Flow catalog.';
      matches.add(
        AskHawMatch(
          content: content,
          score: score,
          reason: reason,
          matchedTerms: List.unmodifiable(matched),
        ),
      );
    }
    matches.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.content.id.compareTo(b.content.id);
    });
    return List.unmodifiable(matches.take(limit));
  }
}

Set<String> askHawSearchTerms(String query) => query
    .split(' ')
    .map(
      (term) => term.length > 4 && term.endsWith('s')
          ? term.substring(0, term.length - 1)
          : term,
    )
    .where(
      (term) =>
          term.isNotEmpty &&
          !const {
            'a',
            'an',
            'the',
            'me',
            'some',
            'something',
            'about',
            'for',
            'with',
            'please',
            'flow',
            'flows',
            'library',
            'article',
            'articles',
          }.contains(term),
    )
    .toSet();

AskHawCatalog buildAskHawCatalog({
  Iterable<FlowRow> flows = const [],
  Set<int> editableFlowIds = const {},
  Map<int, AskHawFlowContract> contracts = const {},
}) {
  final entries = <AskHawContent>[
    for (final node in KemeticNodeLibrary.nodes)
      AskHawContent(
        id: 'library:${node.id}',
        kind: AskHawContentKind.library,
        title: node.title,
        aliases: [node.id, ...node.aliases],
        explanation: _authoredExplanation(node.body),
        summary: extractOpeningLine(node.body),
        topics: themesForNode(node),
        durationMinutes: estimateReadingMinutes(node.body),
        commitment: '${estimateReadingMinutes(node.body)} min read',
      ),
  ];
  const authored = <MaatFlowKind, (String, String, List<String>, String)>{
    MaatFlowKind.trackSky: (
      'Follow the Sky',
      'Follow major visible sky events with simple witness prompts and one clear line of observation.',
      ['sky', 'seasons', 'stars', 'observation', 'Track the Sky'],
      'Major sky events; timing follows the sky',
    ),
    MaatFlowKind.offeringTable: (
      kOfferingTableTitle,
      kOfferingTableOverview,
      ['nourishment', 'food', 'water', 'care', 'household', 'provision'],
      '30 days; a small morning practice',
    ),
    MaatFlowKind.readingHouse: (
      kReadingHouseTitle,
      kReadingHouseOverview,
      [
        'book',
        'books',
        'reading',
        'study',
        'learning',
        'private study',
        'book club',
      ],
      'The host sets the book, readings and sittings',
    ),
    MaatFlowKind.theDjed: (
      kTheDjedTitle,
      kDjedOverview,
      ['stability', 'support', 'repair', 'structure'],
      '9 sittings across 30 days',
    ),
    MaatFlowKind.theKar: (
      kKarTitle,
      kKarOverview,
      ['imagination', 'memory', 'shrine', 'imagining'],
      'Five scenes, then return visits',
    ),
  };
  for (final kind in discoverableMaatFlowKinds) {
    final data = authored[kind];
    if (data == null) continue;
    final profile = maatFlowStaticProfileForKey(kind.flowKey);
    entries.add(
      AskHawContent(
        id: 'maat:${kind.flowKey}',
        kind: AskHawContentKind.maatFlow,
        title: data.$1,
        summary: data.$2,
        aliases: data.$3,
        topics: [
          ...data.$3,
          if (profile != null)
            ...profile.attributes.map(
              (value) => value.value.replaceAll('_', ' '),
            ),
        ],
        commitment: data.$4,
      ),
    );
  }
  final seen = <int>{};
  for (final flow in flows) {
    if (!seen.add(flow.id)) continue;
    final maatKind = resolveMaatFlowKindFromFlowSnapshot(
      flowName: flow.name,
      flowNotes: flow.notes,
    );
    entries.add(
      AskHawContent(
        id: 'flow:${flow.id}',
        kind: AskHawContentKind.flow,
        title: flow.name,
        summary:
            'An accessible Flow. Open its full detail for its schedule and guidance.',
        active: flow.active && !flow.isSaved,
        paused: flow.pausedAt != null,
        maatFlowKey: maatKind?.flowKey,
        editable: editableFlowIds.contains(flow.id),
        flowId: flow.id,
        contract:
            contracts[flow.id] ??
            AskHawFlowContract.tryFromJson(flow.assistance),
        commitment: flow.remainingLiveEventCount > 0
            ? '${flow.remainingLiveEventCount} upcoming occurrences'
            : 'Open the Flow to review its commitment',
      ),
    );
  }
  return AskHawCatalog(entries);
}

String _authoredExplanation(String body) {
  final prose = body
      .split(RegExp(r'\n\s*\n'))
      .map((value) => value.trim())
      .where(
        (value) =>
            value.isNotEmpty && !RegExp(r'^(#|[|]|[-•]\s)').hasMatch(value),
      )
      .map(
        (value) => value
            .replaceAll(RegExp(r'\*{1,2}'), '')
            .replaceAll(RegExp(r'\s+'), ' '),
      )
      .where((value) => !(value.endsWith('?') && !value.contains('.')));
  final chosen = <String>[];
  var words = 0;
  for (final paragraph in prose) {
    final count = paragraph.split(' ').length;
    if (words + count > 80) {
      if (chosen.isEmpty) chosen.add(extractOpeningLine(paragraph));
      break;
    }
    chosen.add(paragraph);
    words += count;
    if (chosen.length == 2) break;
  }
  return chosen.join('\n\n');
}
