import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/insight_entry_model.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/kemetic_node_search_delegate.dart';

void main() {
  test('search matches library body text', () {
    final delegate = KemeticNodeSearchDelegate(
      nodes: KemeticNodeLibrary.nodes,
      insightEntriesFuture: Future.value(const <InsightEntry>[]),
    );

    expect(
      delegate.debugMatchingNodeIds('right order', const <InsightEntry>[]),
      contains('maat'),
    );
  });

  test('search keeps legacy haw transliteration alias', () {
    final delegate = KemeticNodeSearchDelegate(
      nodes: KemeticNodeLibrary.nodes,
      insightEntriesFuture: Future.value(const <InsightEntry>[]),
    );

    expect(delegate.debugMatchingNodeIds('Ḥꜣw', const <InsightEntry>[]), [
      'haw',
    ]);
  });

  test('search matches user insight body text', () {
    final now = DateTime(2026, 5, 16);
    final entry = InsightEntry(
      id: 'entry-1',
      userId: 'user-1',
      nodeId: 'maat',
      nodeTitle: 'Ma’at',
      nodeGlyph: '𓆄',
      bodyText: 'A private reflection phrase for the library search.',
      entryDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final delegate = KemeticNodeSearchDelegate(
      nodes: KemeticNodeLibrary.nodes,
      insightEntriesFuture: Future.value([entry]),
    );

    expect(
      delegate.debugMatchingNodeIds('private reflection phrase', [entry]),
      ['maat'],
    );
  });
}
