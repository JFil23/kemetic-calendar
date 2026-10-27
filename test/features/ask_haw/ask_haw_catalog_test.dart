import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/features/ask_haw/ask_haw_catalog.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_models.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';

void main() {
  test(
    'public projection contains actual canon and exactly five current Flows',
    () {
      final catalog = buildAskHawCatalog();
      final readings = catalog.entries.where(
        (item) => item.kind == AskHawContentKind.library,
      );
      final flows = catalog.entries.where(
        (item) => item.kind == AskHawContentKind.maatFlow,
      );
      expect(
        readings.map((value) => value.id).toSet(),
        KemeticNodeLibrary.nodes.map((value) => 'library:${value.id}').toSet(),
      );
      expect(
        readings.every(
          (value) => !KemeticNodeLibrary.isRetired(value.id.split(':').last),
        ),
        isTrue,
      );
      expect(flows, hasLength(5));
      expect(
        flows.map((value) => value.id).toSet(),
        discoverableMaatFlowKeys.map((value) => 'maat:$value').toSet(),
      );
      expect(catalog.byId('maat:track-the-sky')!.title, 'Follow the Sky');
    },
  );
  test(
    'exact, alias, plural and transliteration searches resolve real identities',
    () {
      final catalog = buildAskHawCatalog();
      expect(catalog.search('decan').first.content.id, 'library:decans');
      expect(catalog.search('Thoth').first.content.id, 'library:djehuty');
      expect(catalog.search('Kꜣr').first.content.id, 'maat:the-kar');
      expect(
        catalog
            .search('reading flows')
            .any((item) => item.content.id == 'maat:the-reading-house'),
        isTrue,
      );
      expect(catalog.search('beginner cooking flow'), isEmpty);
    },
  );
  test(
    'unknown duration cannot qualify and stable ties do not depend on iteration',
    () {
      const a = AskHawContent(
        id: 'library:a',
        kind: AskHawContentKind.library,
        title: 'Quiet',
        summary: 'A reading.',
        durationMinutes: 5,
      );
      const b = AskHawContent(
        id: 'library:b',
        kind: AskHawContentKind.library,
        title: 'Quiet',
        summary: 'Another reading.',
        durationMinutes: 5,
      );
      const unknown = AskHawContent(
        id: 'flow:1',
        kind: AskHawContentKind.flow,
        title: 'Quiet',
        summary: 'Duration unspecified.',
        active: true,
      );
      final first = AskHawCatalog([b, unknown, a]);
      final second = AskHawCatalog([a, b, unknown]);
      expect(
        first.search('quiet').map((value) => value.content.id).toList(),
        second.search('quiet').map((value) => value.content.id).toList(),
      );
      expect(
        first.search('', maxMinutes: 10).map((value) => value.content.id),
        ['library:a', 'library:b'],
      );
    },
  );
  test(
    'hidden and disabled optional suggestions remain explicitly searchable',
    () {
      final catalog = buildAskHawCatalog();
      final memory = AskHawMemory(
        payload: {
          'hidden': ['library:decans'],
          'preferences': {'suggestionsEnabled': false},
        },
      );
      expect(catalog.search('decan', memory: memory, optional: true), isEmpty);
      expect(
        catalog.search('decan', memory: memory).first.content.id,
        'library:decans',
      );
      final hidden = AskHawMemory(
        payload: {
          'hidden': ['library:decans'],
        },
      );
      expect(catalog.search('decan', memory: hidden, optional: true), isEmpty);
    },
  );
  test('signals cannot make unrelated or unavailable content eligible', () {
    final catalog = buildAskHawCatalog();
    final memory = AskHawMemory(
      payload: {
        'signals': {
          'maat:the-offering-table': {'selectedCount': 9999},
          'flow:nonexistent': {'selectedCount': 9999},
        },
      },
    );
    expect(catalog.search('cooking', memory: memory), isEmpty);
    expect(
      catalog.search('decan', memory: memory).first.content.id,
      'library:decans',
    );
  });
  test(
    'authorized Flow projection does not invent permissions or durations',
    () {
      final flow = FlowRow(
        id: 7,
        userId: 'owner',
        name: 'My quiet practice',
        color: 1,
        active: true,
        isSaved: false,
        startDate: null,
        endDate: null,
        notes: 'private note',
        rules: [],
      );
      final catalog = buildAskHawCatalog(flows: [flow]);
      final result = catalog.byId('flow:7')!;
      expect(result.editable, isFalse);
      expect(result.durationMinutes, isNull);
      expect(result.summary, isNot(contains('private note')));
      expect(
        buildAskHawCatalog(
          flows: [flow],
          editableFlowIds: {7},
        ).byId('flow:7')!.editable,
        isTrue,
      );
    },
  );
  test(
    'selection signals are bounded and decay without changing eligibility',
    () {
      const a = AskHawContent(
        id: 'library:a',
        kind: AskHawContentKind.library,
        title: 'Quiet',
        summary: 'A.',
      );
      const b = AskHawContent(
        id: 'library:b',
        kind: AskHawContentKind.library,
        title: 'Quiet',
        summary: 'B.',
      );
      final catalog = AskHawCatalog([a, b]);
      final now = DateTime.utc(2026, 10, 27);
      AskHawMemory selectedAt(int days) => AskHawMemory(
        payload: {
          'signals': {
            'library:b': {
              'selectedCount': 9999,
              'lastSelectedAt': now
                  .subtract(Duration(days: days))
                  .toIso8601String(),
            },
          },
        },
      );
      expect(
        catalog
            .search('quiet', memory: selectedAt(1), nowUtc: now)
            .first
            .content
            .id,
        'library:b',
      );
      expect(
        catalog
            .search('quiet', memory: selectedAt(91), nowUtc: now)
            .first
            .content
            .id,
        'library:a',
      );
      expect(
        catalog.search('absent', memory: selectedAt(1), nowUtc: now),
        isEmpty,
      );
      final boost =
          catalog
              .search('quiet', memory: selectedAt(1), nowUtc: now)
              .first
              .score -
          catalog.search('quiet', nowUtc: now).first.score;
      expect(boost, lessThanOrEqualTo(3));
    },
  );
}
