import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';

void main() {
  test('cosmic order is the first document-style node', () {
    final node = KemeticNodeLibrary.nodes.first;

    expect(node.id, 'cosmic_order');
    expect(node.title, 'Cosmic Order');
    expect(
      node.body,
      contains('Cosmic Beginnings, Around 13.8 Billion Years Ago'),
    );
    expect(node.body, contains('| Event | Modern Science |'));
    expect(node.body, contains('| Function | Purpose |'));
    expect(node.body, contains('How Stardust Becomes Life'));
    expect(
      node.body,
      contains(
        'Earth did not receive life already formed. It received conditions.',
      ),
    );
    expect(node.body, isNot(contains('•')));
    expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
  });

  test('human emergence is the second document-style node', () {
    final node = KemeticNodeLibrary.nodes[1];

    expect(node.id, 'human_emergence');
    expect(node.title, 'Human Emergence');
    expect(node.body, contains('| Region | New Species | Traits |'));
    expect(node.body, contains('| Trait | Homo habilis'));
    expect(node.body, contains('| Theory | Explanation | Flaws / Mysteries |'));
    expect(node.body, contains('| Cosmic Process | Human Mirror |'));
    expect(node.body, isNot(contains('•')));
    expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
  });

  test(
    'ancient african tree preserves grids without redundant direction text',
    () {
      final node = KemeticNodeLibrary.nodes[2];

      expect(node.id, 'ancient_african_tree');
      expect(node.title, 'Ancient African Tree');
      expect(node.body, contains('| Species | Timeframe | Region | Notes |'));
      expect(
        node.body,
        contains('| Fractured Lineage | Core Traits | Symbolic Fate |'),
      );
      expect(
        node.body,
        contains('They failed because they were less connected.'),
      );
      expect(node.body, isNot(contains('•')));
      expect(node.body, isNot(contains('the table')));
      expect(node.body, isNot(contains('The table')));
      expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
    },
  );

  test('green sahara is the fourth document-style prose node', () {
    final node = KemeticNodeLibrary.nodes[3];

    expect(node.id, 'green_sahara');
    expect(node.title, 'Green Sahara');
    expect(node.body, contains('Before It Was Desert, It Was Paradise'));
    expect(node.body, contains('The Great Departure'));
    expect(node.body, contains('The Cultures That Memory Built'));
    expect(node.body, isNot(contains('|')));
    expect(node.body, isNot(contains('•')));
    expect(node.body, isNot(contains('the table')));
    expect(node.body, isNot(contains('The table')));
    expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
  });

  test('rise of kush and kemet preserves the volcanic grid', () {
    final node = KemeticNodeLibrary.nodes[4];

    expect(node.id, 'rise_of_kush_and_kemet');
    expect(node.title, 'Rise of Kush and Kemet');
    expect(node.body, contains('| Volcanic Feature | Location | Relevance |'));
    expect(node.body, contains('| Mount Dendi | West of Addis Ababa |'));
    expect(node.body, contains('The Rise of Kush and Kemet'));
    expect(node.body, contains('Medu Neter'));
    expect(node.body, isNot(contains('•')));
    expect(node.body, isNot(contains('the table')));
    expect(node.body, isNot(contains('The table')));
    expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
  });

  test('cosmic order links resolve and match visible body text', () {
    final node = KemeticNodeLibrary.resolve('cosmic_order');
    expect(node, isNotNull);

    for (final link in node!.linkMap) {
      expect(
        KemeticNodeLibrary.resolve(link.targetId),
        isNotNull,
        reason: '${node.id} links to missing node ${link.targetId}',
      );
      expect(
        link.targetId.toLowerCase(),
        isNot(node.id.toLowerCase()),
        reason: '${node.id} has a self-link for ${link.phrase}',
      );
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
    }
  });

  test('human emergence links resolve and match visible body text', () {
    final node = KemeticNodeLibrary.resolve('human_emergence');
    expect(node, isNotNull);

    for (final link in node!.linkMap) {
      expect(
        KemeticNodeLibrary.resolve(link.targetId),
        isNotNull,
        reason: '${node.id} links to missing node ${link.targetId}',
      );
      expect(
        link.targetId.toLowerCase(),
        isNot(node.id.toLowerCase()),
        reason: '${node.id} has a self-link for ${link.phrase}',
      );
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
    }
  });

  test('ancient african tree links resolve and match visible body text', () {
    final node = KemeticNodeLibrary.resolve('ancient_african_tree');
    expect(node, isNotNull);

    for (final link in node!.linkMap) {
      expect(
        KemeticNodeLibrary.resolve(link.targetId),
        isNotNull,
        reason: '${node.id} links to missing node ${link.targetId}',
      );
      expect(
        link.targetId.toLowerCase(),
        isNot(node.id.toLowerCase()),
        reason: '${node.id} has a self-link for ${link.phrase}',
      );
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
    }
  });

  test('green sahara links resolve and match visible body text', () {
    final node = KemeticNodeLibrary.resolve('green_sahara');
    expect(node, isNotNull);

    for (final link in node!.linkMap) {
      expect(
        KemeticNodeLibrary.resolve(link.targetId),
        isNotNull,
        reason: '${node.id} links to missing node ${link.targetId}',
      );
      expect(
        link.targetId.toLowerCase(),
        isNot(node.id.toLowerCase()),
        reason: '${node.id} has a self-link for ${link.phrase}',
      );
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
    }
  });

  test('rise of kush and kemet links resolve and match visible body text', () {
    final node = KemeticNodeLibrary.resolve('rise_of_kush_and_kemet');
    expect(node, isNotNull);

    for (final link in node!.linkMap) {
      expect(
        KemeticNodeLibrary.resolve(link.targetId),
        isNotNull,
        reason: '${node.id} links to missing node ${link.targetId}',
      );
      expect(
        link.targetId.toLowerCase(),
        isNot(node.id.toLowerCase()),
        reason: '${node.id} has a self-link for ${link.phrase}',
      );
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
    }
  });

  test('candidate batch nodes were not kept as separate short nodes', () {
    expect(KemeticNodeLibrary.resolve('zep_tepi'), isNull);
    expect(KemeticNodeLibrary.resolve('stardust'), isNull);
    expect(KemeticNodeLibrary.resolve('supernova'), isNull);
    expect(KemeticNodeLibrary.resolve('first_maat'), isNull);
  });

  test('node ids remain unique', () {
    final ids = <String>{};

    for (final node in KemeticNodeLibrary.nodes) {
      expect(
        ids.add(node.id.toLowerCase()),
        isTrue,
        reason: 'Duplicate node id: ${node.id}',
      );
    }
  });
}
