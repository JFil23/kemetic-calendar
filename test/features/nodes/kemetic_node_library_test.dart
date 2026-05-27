import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';

void main() {
  test('cosmic order is the first document-style node', () {
    final node = KemeticNodeLibrary.nodes.first;

    expect(node.id, 'cosmic_order');
    expect(node.title, 'Cosmic Order');
    expect(
      node.body,
      contains('Before there was a world to order, there was only potential.'),
    );
    expect(
      node.body,
      contains('Cosmic Beginnings, Around 13.8 Billion Years Ago'),
    );
    expect(node.body, contains('| Event | Modern Science |'));
    expect(node.body, contains('| Function | Purpose |'));
    expect(node.body, contains('| Event or Shift | Impact |'));
    expect(node.body, contains('How Stardust Becomes Life'));
    expect(
      node.body,
      contains('It received the conditions from which life could emerge.'),
    );
    expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
  });

  test('human emergence is the second document-style node', () {
    final node = KemeticNodeLibrary.nodes[1];

    expect(node.id, 'human_emergence');
    expect(node.title, 'Human Emergence');
    expect(node.body, contains('After Cosmic Order forms the body of matter'));
    expect(node.body, contains('| Species | Timeframe | Region | Notes |'));
    expect(node.body, contains('| Region | New Species | Traits |'));
    expect(node.body, contains('| Trait | Homo habilis'));
    expect(node.body, contains('| Theory | Explanation | Flaws / Mysteries |'));
    expect(node.body, contains('| Event or Shift | Impact |'));
    expect(node.body, contains('| Cosmic Process | Human Mirror |'));
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
        contains('| Lineage | Core Traits | Ecological Context |'),
      );
      expect(
        node.body,
        contains('Neanderthals did not fail because they were less.'),
      );
      expect(node.body, contains('The Ancient African Tree defines'));
      expect(node.body, isNot(contains('the table')));
      expect(node.body, isNot(contains('The table')));
      expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
    },
  );

  test('green sahara is the fourth document-style prose node', () {
    final node = KemeticNodeLibrary.nodes[3];

    expect(node.id, 'green_sahara');
    expect(node.title, 'Green Sahara');
    expect(node.body, contains('The Sahara was not always sand.'));
    expect(node.body, contains('Why This Is Not Widely Known'));
    expect(node.body, contains('The Garden of Eden — A Comparative Reading'));
    expect(node.body, contains('The Great Departure'));
    expect(node.body, contains('The Green Sahara and Ma\'at'));
    expect(node.body, isNot(contains('|')));
    expect(node.body, isNot(contains('the table')));
    expect(node.body, isNot(contains('The table')));
    expect(RegExp(r'\n\d+\. ').hasMatch(node.body), isFalse);
  });

  test('rise of kush and kemet preserves the volcanic grid', () {
    final node = KemeticNodeLibrary.nodes[4];

    expect(node.id, 'rise_of_kush_and_kemet');
    expect(node.title, 'Rise of Kush and Kemet');
    expect(node.body, contains('Every year, without fail, it flooded.'));
    expect(node.body, contains('| Volcanic Feature | Location | Relevance |'));
    expect(node.body, contains('| Mount Dendi | West of Addis Ababa |'));
    expect(
      node.body,
      contains('Kemet and Kush as Continuations of Older African Patterns'),
    );
    expect(node.body, contains('Medu Neter'));
    expect(node.body, contains('The Rise of Kush and Kemet defines'));
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

  test('updated moral instruction nodes are present', () {
    final maat = KemeticNodeLibrary.resolve('maat');
    final declarations = KemeticNodeLibrary.resolve(
      'declarations_of_innocence',
    );
    final ib = KemeticNodeLibrary.resolve('ib');
    final ptahhotep = KemeticNodeLibrary.resolve('instruction_ptahhotep');

    expect(maat, isNotNull);
    expect(declarations, isNotNull);
    expect(ib, isNotNull);
    expect(ptahhotep, isNotNull);

    expect(maat!.title, "Ma'at");
    expect(
      maat.body,
      contains('What holds a civilization together when no one is watching'),
    );
    expect(
      maat.linkMap.map((link) => link.targetId),
      contains('declarations_of_innocence'),
    );

    expect(
      declarations!.body,
      contains('There is a hall at the center of the Duat'),
    );
    expect(declarations.aliases, contains('Hall of Two Truths'));
    expect(ib!.body, contains('The heart scarab was placed over the chest'));
    expect(ptahhotep!.aliases, contains('Maxims of Ptahhotep'));

    for (final node in [maat, declarations, ib, ptahhotep]) {
      for (final link in node.linkMap) {
        expect(
          node.body.contains(link.phrase),
          isTrue,
          reason: '${node.id} link phrase is not in body: ${link.phrase}',
        );
      }
    }
  });

  test('ausar node carries the restoration and vindication essay', () {
    final node = KemeticNodeLibrary.resolve('ausar');
    expect(node, isNotNull);

    expect(node!.aliases, containsAll(['Asar', 'Osiris', 'Wsir']));
    expect(
      node.body,
      contains('Ausar was not restored because death disappeared.'),
    );
    expect(node.body, contains('Gathered by Heru'));
    expect(node.body, contains('The Body That Must Become Effective'));
    expect(node.body, contains('Lord of the Duat'));
    expect(node.body, contains('Ra and Ausar'));
    expect(node.body, contains('Nile, Grain, and Return'));
    expect(node.body, contains('The Djed Raised'));
    expect(node.body, contains('Vindication'));

    for (final link in node.linkMap) {
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
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
    }
  });

  test('duat node carries the hidden passage essay', () {
    final node = KemeticNodeLibrary.resolve('duat');
    expect(node, isNotNull);

    expect(
      node!.aliases,
      containsAll(['Underworld', 'Hidden Region', 'Netherworld']),
    );
    expect(
      node.body,
      contains('The Duat is not a place where the dead simply go.'),
    );
    expect(node.body, contains('The Hidden Region'));
    expect(node.body, contains('The Night Journey of Ra'));
    expect(node.body, contains('The Sixth Hour'));
    expect(node.body, contains('The Dead in the Duat'));
    expect(node.body, contains('Gates, Names, and Speech'));
    expect(node.body, contains('The Duat and the Akhet'));
    expect(node.body, contains('Not Punishment, But Passage'));
    expect(node.body, contains('The Hidden Work'));

    expect(
      node.linkMap.where((link) => link.phrase == 'Akhet').single.targetId,
      'horizon',
    );

    for (final link in node.linkMap) {
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
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
    }
  });

  test('night journey nodes carry the new long-form essays', () {
    final expectedSections = <String, List<String>>{
      'amduat': [
        'The Amduat begins after the world loses sight of the sun.',
        'What Is in the Duat',
        'The Twelve Hours',
        'The Sixth Hour',
        'The Seventh Hour',
        'Names as Passage',
        'The Hidden Chamber',
      ],
      'book_of_the_dead': [
        'It is not a book of death.',
        'Coming Forth',
        'The Heart Must Remain',
        'The Body as Divine Assembly',
        "The Declaration Before Ma'at",
        'Ra, Ausar, and the Bark',
        'A Portable House of Ritual',
      ],
      'set': [
        'Set is not disorder by itself.',
        'The Force at the Boundary',
        'The Crime Against Ausar',
        'The Contest with Heru',
        'Set and Apepi Are Not the Same',
        'The Red Land and the Black Land',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'amduat': [
        'What Is in the Duat',
        'Book of the Hidden Chamber',
        'Night Journey of Ra',
      ],
      'book_of_the_dead': [
        'Book of the Dead',
        'Per Em Hru',
        'Peret Em Heru',
        'Coming Forth by Day',
      ],
      'set': ['Seth', 'Sutekh', 'Adversarial Force', 'Red Land Power'],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }
  });

  test('solar force and sky nodes carry the new long-form essays', () {
    final expectedSections = <String, List<String>>{
      'sekhmet': [
        'Sekhmet appears when order has to burn.',
        'The Eye Sent Forth',
        'Fire Without Measure',
        'Lioness of Protection',
        'Sekhmet and Healing',
        'Hathor and Sekhmet',
        'The Necessary Terror',
      ],
      'khepri': [
        'Khepri rises after the sun has disappeared.',
        'The Scarab',
        'Coming Into Being',
        'Ra as Khepri',
        'Khepri and the Duat',
        'The Person as Becoming',
        'The Daily Creation',
      ],
      'nut': [
        'Nut holds the dead above the earth before they rise.',
        'The Body of the Sky',
        'Mother of the Sun',
        'Mother of Ausar and the Divine Line',
        'The Coffin as Nut',
        'Stars in Her Body',
        'The Sky as Limit',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'sekhmet': ['The Powerful One', 'Eye of Ra', 'Lioness Fire'],
      'khepri': ['Scarab', 'Becoming', 'Morning Sun', 'Dawn Form of Ra'],
      'nut': ['Sky Mother', 'Celestial Vault', 'Mother of Stars'],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }

    final khepri = KemeticNodeLibrary.resolve('khepri')!;
    expect(
      khepri.linkMap.where((link) => link.phrase == 'Akhet').single.targetId,
      'horizon',
    );

    final nut = KemeticNodeLibrary.resolve('nut')!;
    expect(
      nut.linkMap
          .where((link) => link.phrase == 'imperishable stars')
          .single
          .targetId,
      'sah',
    );
    expect(
      nut.linkMap
          .where((link) => link.phrase == 'imperishable akhs')
          .single
          .targetId,
      'akh',
    );
  });

  test('threshold formation and harvest nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'nebet_het': [
        'Nebet-Het stands where the house reaches its edge.',
        'Lady of the Boundary',
        'With Aset Beside Ausar',
        'Mourning as Protection',
        'The Sister at the Outer Edge',
        'Guardian of the Dead',
        'Threshold and Ma\'at',
        'The Work After Rupture',
      ],
      'khnum': [
        'Khnum shapes life before it can breathe.',
        'The Potter\'s Wheel',
        'Body and Ka',
        'Birth and Royal Becoming',
        'Water and the First Cataract',
        'The Ram and Generative Strength',
        'Khnum and Ptah',
        'The Vessel Must Hold',
      ],
      'renenutet': [
        'Renenutet appears when grain becomes security.',
        'The Field That Must Feed',
        'Serpent of Nourishment',
        'Nursing and Raising',
        'The Granary as Future',
        'Harvest and Destiny',
        'The Offering Economy',
        'Abundance Under Ma\'at',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'nebet_het': ['Nephthys', 'Lady of the House', 'Mistress of the House'],
      'khnum': ['Ram Creator', 'Potter of Life', 'Lord of the Wheel'],
      'renenutet': [
        'Harvest Serpent',
        'Nourishing Cobra',
        'Lady of the Granary',
      ],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }

    final renenutet = KemeticNodeLibrary.resolve('renenutet')!;
    expect(
      renenutet.linkMap
          .where((link) => link.phrase == 'inundation')
          .single
          .targetId,
      'akhet',
    );
  });

  test('scribal offering and false door nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'house_of_life': [
        'The House of Life kept the dead from becoming silent.',
        'The House That Preserved Speech',
        'Writing as Protection',
        'Scribe and Ma\'at',
        'The Temple Mind',
        'Medicine, Ritual, and the Body',
        'Living Knowledge',
        'The Danger of Broken Transmission',
      ],
      'offering_formula': [
        'The dead were fed by words made exact.',
        'A Gift That Moves Through Order',
        'Bread and Beer',
        'The Ka Receives',
        'The Role of the Living',
        'Voice Offering',
        'The Offering Table',
        'When Offerings Fail',
      ],
      'false_door': [
        'The false door was not meant for the living to enter.',
        'A Door That Does Not Swing',
        'Name, Image, and Offering',
        'The Ka at the Threshold',
        'Tomb Chapel and Living Duty',
        'Threshold Without Confusion',
        'Stone as Memory',
        'When the Door Fails',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'house_of_life': [
        'Per Ankh',
        'House of Living Knowledge',
        'Temple Scriptorium',
      ],
      'offering_formula': [
        'Hotep-di-nesu',
        'Offering Prayer',
        'Bread and Beer Formula',
      ],
      'false_door': ['Ka Door', 'Tomb Doorway', 'Door of Offerings'],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }

    final houseOfLife = KemeticNodeLibrary.resolve('house_of_life')!;
    expect(
      houseOfLife.linkMap.any((link) => link.targetId == 'house_of_life'),
      isFalse,
    );

    final offeringFormula = KemeticNodeLibrary.resolve('offering_formula')!;
    expect(
      offeringFormula.linkMap
          .where((link) => link.phrase == 'offering table')
          .single
          .targetId,
      'hotep',
    );

    final falseDoor = KemeticNodeLibrary.resolve('false_door')!;
    expect(
      falseDoor.linkMap
          .where((link) => link.phrase == 'tomb inscriptions')
          .single
          .targetId,
      'tomb_inscriptions',
    );
  });

  test('horizon and agricultural season nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'horizon': [
        'Akhet is the place where hidden passage becomes visible return.',
        'The Threshold of Dawn',
        'Becoming Effective',
        'Between Duat and Sky',
        'The Two Horizons',
        'Horizon as Measure',
        'Akhet and the Pyramid',
        'What the Horizon Teaches',
      ],
      'akhet': [
        'Akhet began when the land disappeared under water.',
        'The Flood Arrives',
        'Covered Fields',
        'Sopdet and the Year',
        'Akhet and Ausar',
        'Labor During the Flood',
        'The Danger of Wrong Measure',
        'When the Waters Withdraw',
      ],
      'peret': [
        'Peret begins when the land comes back.',
        'The Land Reappears',
        'Seed Enters the Prepared Earth',
        'Coming Forth',
        'Growth Requires Care',
        'Peret and Khepri',
        'The Risk of Emergence',
        'Toward Shemu',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'horizon': ['Horizon', 'Place of Becoming Effective', 'Solar Threshold'],
      'akhet': [
        'Inundation Season',
        'Flood Season',
        'Season of the Nile Rising',
      ],
      'peret': ['Emergence Season', 'Growing Season', 'Season of Coming Forth'],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }

    final horizon = KemeticNodeLibrary.resolve('horizon')!;
    expect(horizon.glyph, '𓈌');
    expect(
      horizon.linkMap
          .where((link) => link.phrase == 'inundation')
          .single
          .targetId,
      'akhet',
    );

    final akhet = KemeticNodeLibrary.resolve('akhet')!;
    expect(akhet.glyph, '𓈗');

    final peret = KemeticNodeLibrary.resolve('peret')!;
    expect(
      peret.linkMap.where((link) => link.phrase == 'Akhet').single.targetId,
      'akhet',
    );
  });

  test('harvest and year-threshold nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'shemu': [
        'Shemu begins when growth has to answer for itself.',
        'The Field Gives Its Answer',
        'Cutting and Gathering',
        'The Granary',
        'Offering from the Harvest',
        'Measuring the Crop',
        'Heat and Exposure',
        'Harvest as Consequence',
      ],
      'epagomenal_days': [
        'The year ended, but time was not finished.',
        'Days Outside the Count',
        'Birth at the Threshold',
        'Time and Risk',
        'Ausar and the Future of Death',
        'Set and the Problem of Force',
        'Aset and Nebet-Het',
        'Calendar as Theology',
        'The Edge Before Opening',
      ],
      'wp_rnpt': [
        'The year does not begin by moving forward.',
        'Opening After the Threshold',
        'Sopdet Returns',
        'The River and the Year',
        'Opening as Ritual Act',
        'Renewal and Record',
        'Not a Reset',
        'The First Breath of the Cycle',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'shemu': ['Harvest Season', 'Dry Season', 'Season of Gathering'],
      'epagomenal_days': [
        'Five Days Outside the Year',
        'Birth Days of the Gods',
        'Days Upon the Year',
      ],
      'wp_rnpt': ['Opening of the Year', 'Wep Renpet', 'New Year'],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }

    final shemu = KemeticNodeLibrary.resolve('shemu')!;
    expect(
      shemu.linkMap.where((link) => link.phrase == 'Akhet').single.targetId,
      'akhet',
    );

    final wpRnpt = KemeticNodeLibrary.resolve('wp_rnpt')!;
    expect(wpRnpt.glyph, '𓊃𓆳');
    expect(
      wpRnpt.linkMap.where((link) => link.phrase == 'Akhet').single.targetId,
      'akhet',
    );
    expect(
      wpRnpt.linkMap.where((link) => link.phrase == 'shadow').single.targetId,
      'sheut',
    );

    final epagomenalDays = KemeticNodeLibrary.resolve('epagomenal_days')!;
    expect(epagomenalDays.glyph, '𓏤𓏤𓏤𓏤𓏤');
  });

  test('royal record nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'regnal_year': [
        'A year in Kemet did not stand alone.',
        'Time Under the King',
        'The Year as Record',
        'Counting and Responsibility',
        'The King and the Cycle',
        'Wadi el-Jarf and Working Time',
        'Succession and Renewal',
        'Time as Witness',
      ],
      'palermo_stone': [
        'The Palermo Stone remembers kings by years.',
        'Broken Stone, Ordered Time',
        'The Year Compartments',
        'Nile Height and Ma\'at',
        'Counting Cattle, Counting Obligation',
        'Ritual Memory',
        'The Stone as Djehuty\'s Work',
        'What the Stone Teaches',
      ],
      'wadi_el_jarf_papyri': [
        'The largest works in Kemet were held together by small records.',
        'The Diary of Merer',
        'Akhet-Khufu',
        'Stone on the River',
        'The Crew as Ordered Body',
        'Record Against Confusion',
        'The Human Scale of Monument',
        'What the Papyri Teach',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'regnal_year': ['Year of the Reign', 'Royal Year Count', 'King’s Year'],
      'palermo_stone': [
        'Royal Annals',
        'Early Royal Chronicle',
        'Annals Stone',
      ],
      'wadi_el_jarf_papyri': [
        'Diary of Merer',
        'Khufu Harbor Papyri',
        'Old Kingdom Work Logs',
      ],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
        expect(
          link.targetId,
          isNot('akhet_inundation'),
          reason: '${resolvedNode.id} should use existing akhet node',
        );
      }
    }

    expect(KemeticNodeLibrary.resolve('regnal_year')!.glyph, '𓆳');
    expect(KemeticNodeLibrary.resolve('palermo_stone')!.glyph, '𓆳');
    expect(KemeticNodeLibrary.resolve('wadi_el_jarf_papyri')!.glyph, '𓏞');

    final palermoStone = KemeticNodeLibrary.resolve('palermo_stone')!;
    expect(
      palermoStone.linkMap
          .where((link) => link.phrase == 'inundation')
          .single
          .targetId,
      'akhet',
    );

    final wadiPapyri = KemeticNodeLibrary.resolve('wadi_el_jarf_papyri')!;
    expect(
      wadiPapyri.linkMap
          .where((link) => link.phrase == 'Akhet-Khufu')
          .single
          .targetId,
      'horizon',
    );
    expect(wadiPapyri.linkMap.any((link) => link.phrase == 'Khufu'), isFalse);
  });

  test('inscription funerary and memphite nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'tomb_inscriptions': [
        'The tomb wall was not silent stone.',
        'The Name on the Wall',
        'Offering Made Permanent',
        'Biography as Ma\'at',
        'The Wall as Threshold',
        'Images That Act',
        'The Danger of Erasure',
        'Stone Waiting for Voice',
      ],
      'middle_kingdom_funerary': [
        'The words once carved for kings began to travel.',
        'From Pyramid Wall to Coffin Board',
        'The Coffin as World',
        'The Democratized Pattern',
        'The Field of Rushes',
        'The Map of Passage',
        'Local Tomb, Cosmic Journey',
        'Continuity Through Change',
      ],
      'memphite_theology': [
        'Ptah created before the hand moved.',
        'Heart and Tongue',
        'Creation by Naming',
        'Ptah and the Craftsman',
        'The Body of Creation',
        'Memphis as Center',
        'Ptah, Atum, and the Gods',
        'Speech as Responsibility',
        'Creation Must Hold',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'tomb_inscriptions': [
        'Tomb Texts',
        'Funerary Inscriptions',
        'Inscribed Tomb Walls',
      ],
      'middle_kingdom_funerary': [
        'Middle Kingdom Tomb Tradition',
        'Coffin Text Tradition',
        'Funerary Expansion',
      ],
      'memphite_theology': [
        'Shabaka Stone',
        'Theology of Ptah',
        'Memphite Creation',
      ],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
        expect(
          link.targetId,
          isNot('akhet_inundation'),
          reason: '${resolvedNode.id} should use existing akhet node',
        );
      }
    }

    expect(KemeticNodeLibrary.resolve('tomb_inscriptions')!.glyph, '𓏞');
    expect(
      KemeticNodeLibrary.resolve('middle_kingdom_funerary')!.glyph,
      '𓏞𓇽',
    );
    expect(KemeticNodeLibrary.resolve('memphite_theology')!.glyph, '𓏞');
    expect(
      KemeticNodeLibrary.resolve('middle_kingdom_funerary_tradition'),
      isNull,
    );

    final memphiteTheology = KemeticNodeLibrary.resolve('memphite_theology')!;
    expect(
      memphiteTheology.linkMap.any((link) => link.phrase == 'Memphis'),
      isFalse,
    );
  });

  test('wisdom eye and great knowing nodes carry long-form essays', () {
    final expectedSections = <String, List<String>>{
      'instruction_amenemope': [
        'Amenemope teaches that a person can be destroyed by a mouth.',
        'The Quiet Person',
        'The Heated Person',
        'Do Not Move the Boundary',
        'The Poor and the Vulnerable',
        'Wealth Without Ma\'at',
        'Heart, Mouth, and Conduct',
        'Wisdom as Protection',
      ],
      'eye_of_ra': [
        'The Eye of Ra does not only see.',
        'Sight That Moves',
        'The Distant Goddess',
        'Sekhmet as the Eye',
        'Hathor as the Eye',
        'Cobra at the Brow',
        'Returning the Eye',
        'Fire and Nourishment',
        'The Eye as Consequence',
      ],
      'rekh_wer': [
        'Great knowing is dangerous when it is not disciplined.',
        'Knowing as Relation',
        'Djehuty and the Measure of Knowledge',
        'The House of Life',
        'Names and Passage',
        'Medicine and Hidden Causes',
        'The Danger of Cleverness',
        'Seeing Deeply',
        'Knowledge That Serves',
      ],
    };

    final expectedAliases = <String, List<String>>{
      'instruction_amenemope': [
        'Amenemope',
        'Teaching of Amenemope',
        'Wisdom of Amenemope',
      ],
      'eye_of_ra': ['Solar Eye', 'Daughter of Ra', 'Active Sight'],
      'rekh_wer': ['Great Knowing', 'Great Knowledge', 'Sacred Knowing'],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull);

      final resolvedNode = node!;
      expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section));
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${resolvedNode.id} links to missing node ${link.targetId}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }

    expect(KemeticNodeLibrary.resolve('instruction_amenemope')!.glyph, '𓏞');
    expect(KemeticNodeLibrary.resolve('eye_of_ra')!.glyph, '𓁹');
    expect(KemeticNodeLibrary.resolve('rekh_wer')!.glyph, '𓁹𓏞');
    expect(KemeticNodeLibrary.resolve('instruction_of_amenemope'), isNull);

    final eyeOfRa = KemeticNodeLibrary.resolve('eye_of_ra')!;
    expect(
      eyeOfRa.linkMap
          .where((link) => link.phrase == 'Book of the Heavenly Cow')
          .single
          .targetId,
      'sekhmet',
    );
  });

  test(
    'destiny temple cleansing peace and support nodes carry long-form essays',
    () {
      final expectedSections = <String, List<String>>{
        'shai': [
          'Shai is not the end of choice.',
          'The Portion Given',
          'The Doomed Prince',
          'Fate and Conduct',
          'Renenutet and Nourished Destiny',
          'Shai and the Heart',
          'The Danger of Blaming Fate',
          'The Measure of a Life',
        ],
        'esna_temple': [
          'At Esna, the ceiling still carries the sky.',
          'House of Khnum',
          'The Ceiling as Cosmos',
          'Creation Through Speech',
          'Water, Clay, and Body',
          'Ritual Time',
          'The Temple as Ordered Body',
          'Late Stone, Ancient Pattern',
          'The Work of the Temple',
        ],
        'natron': [
          'Natron removes what decay wants to keep.',
          'Salt Against Decay',
          'Cleansing the Mouth',
          'Purity as Function',
          'Natron and the Offering',
          'The Dead Made Stable',
          'The Desert Mineral',
          'What Must Be Removed',
        ],
        'hotep': [
          'Hotep is peace because the offering has been placed.',
          'The Offering Placed',
          'Peace as Satisfaction',
          'Hotep-di-nesu',
          'The Table and the Heart',
          'Rest After Proper Action',
          'Hotep and the Dead',
          'False Peace',
          'The Condition of Settlement',
        ],
        'architrave': [
          'The architrave carries weight above the passage.',
          'Stone That Holds',
          'Threshold and Passage',
          'Inscribed Authority',
          'The King as Builder',
          'Columns and Sky',
          'Bearing Without Display',
          'When Support Fails',
          'The Beam and the Burden',
        ],
      };

      final expectedAliases = <String, List<String>>{
        'shai': ['Destiny', 'Fate', 'Allotted Portion'],
        'esna_temple': ['Temple of Khnum at Esna', 'House of Khnum', 'Esna'],
        'natron': [
          'Purifying Salt',
          'Wadi Natrun Salt',
          'Sacred Cleansing Mineral',
        ],
        'hotep': ['Peace', 'Offering', 'Satisfaction', 'Rest'],
        'architrave': ['Temple Lintel', 'Inscribed Beam', 'Sacred Support'],
      };

      for (final entry in expectedSections.entries) {
        final node = KemeticNodeLibrary.resolve(entry.key);
        expect(node, isNotNull);

        final resolvedNode = node!;
        expect(resolvedNode.aliases, containsAll(expectedAliases[entry.key]!));

        for (final section in entry.value) {
          expect(resolvedNode.body, contains(section));
        }

        for (final link in resolvedNode.linkMap) {
          expect(
            resolvedNode.body.contains(link.phrase),
            isTrue,
            reason:
                '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
          );
          expect(
            KemeticNodeLibrary.resolve(link.targetId),
            isNotNull,
            reason: '${resolvedNode.id} links to missing node ${link.targetId}',
          );
          expect(
            link.targetId.toLowerCase(),
            isNot(resolvedNode.id.toLowerCase()),
            reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
          );
        }
      }

      expect(KemeticNodeLibrary.resolve('shai')!.glyph, '𓀭');
      expect(KemeticNodeLibrary.resolve('esna_temple')!.glyph, '𓉗');
      expect(KemeticNodeLibrary.resolve('natron')!.glyph, '𓈗');
      expect(KemeticNodeLibrary.resolve('hotep')!.glyph, '𓊵');
      expect(KemeticNodeLibrary.resolve('architrave')!.glyph, '𓉹');

      final shai = KemeticNodeLibrary.resolve('shai')!;
      expect(
        shai.linkMap
            .where((link) => link.phrase == 'Instruction of Amenemope')
            .single
            .targetId,
        'instruction_amenemope',
      );
      expect(
        shai.linkMap.any((link) => link.phrase == 'Tale of the Doomed Prince'),
        isFalse,
      );
    },
  );

  test('library glyphs use pictorial medu neter signs', () {
    final glyphs = {
      for (final node in KemeticNodeLibrary.nodes) node.id: node.glyph,
    };
    final expectedGlyphs = <String, String>{
      'cosmic_order': '𓆄',
      'human_emergence': '𓀀',
      'ancient_african_tree': '𓆭𓀀',
      'green_sahara': '𓇅𓇾',
      'rise_of_kush_and_kemet': '𓈘𓊖',
      'serpent': '𓆙',
      'nile': '𓈘',
      'ptah': '𓊪𓏏𓎛',
      'djehuty': '𓅝',
      'shu': '𓇯𓇾',
      'declarations_of_innocence': '𓉹𓆄𓆄',
      'ausar': '𓊨𓁹',
      'aset': '𓊨',
      'heru': '𓅃',
      'isfet': '𓆙',
      'ra': '𓇳',
      'ka': '𓂓',
      'ba': '𓅽',
      'akh': '𓅜',
      'ren': '𓍷',
      'ib': '𓄣',
      'sheut': '𓋺',
      'imhotep': '𓉴',
      'sopdet': '𓇼',
      'coffin_texts': '𓏞',
      'papyrus_chester_beatty_iv': '𓏞',
      'kemet': '𓇾',
      'pyramid_texts': '𓉴𓏞',
      'hathor': '𓃒',
      'sah': '𓇼𓇼𓇼',
      'abydos': '𓊖',
      'decans': '𓇼𓇼𓇼',
      'duat': '𓇽',
      'house_of_life': '𓉐𓋹',
      'instruction_ptahhotep': '𓏞',
      'rekh_wer': '𓁹𓏞',
      'set': '𓃩',
      'shai': '𓀭',
      'offering_formula': '𓊵',
      'amduat': '𓇽',
      'instruction_amenemope': '𓏞',
      'eye_of_ra': '𓁹',
      'tomb_inscriptions': '𓏞',
      'middle_kingdom_funerary': '𓏞𓇽',
      'nebet_het': '𓎟𓉐',
      'khnum': '𓃝',
      'memphite_theology': '𓏞',
      'book_of_the_dead': '𓏞',
      'palermo_stone': '𓆳',
      'wadi_el_jarf_papyri': '𓏞',
      'false_door': '𓉿',
      'architrave': '𓉹',
      'wp_rnpt': '𓊃𓆳',
      'horizon': '𓈌',
      'akhet': '𓈗',
      'epagomenal_days': '𓏤𓏤𓏤𓏤𓏤',
      'regnal_year': '𓆳',
    };

    for (final entry in expectedGlyphs.entries) {
      expect(glyphs[entry.key], entry.value, reason: entry.key);
    }

    expect(
      glyphs.values.any(
        (glyph) =>
            glyph.contains('✦') || glyph.contains('✷') || glyph.contains('✵'),
      ),
      isFalse,
    );
  });

  test('pyramid texts node carries the long-form transmission essay', () {
    final node = KemeticNodeLibrary.resolve('pyramid_texts');
    expect(node, isNotNull);

    expect(node!.title, 'Pyramid Texts');
    expect(
      node.body,
      contains(
        'They are carved on stone. But they were written on papyrus first.',
      ),
    );
    expect(node.body, contains('The Corpus of Unas'));
    expect(node.body, contains('Three Content Streams'));
    expect(node.body, contains('What the Library Has Drawn From'));
    expect(node.body, contains('The Transmission'));
    expect(
      node.body,
      contains('The Pyramid Texts define a continuous condition'),
    );

    for (final link in node.linkMap) {
      expect(
        node.body.contains(link.phrase),
        isTrue,
        reason: '${node.id} link phrase is not in body: ${link.phrase}',
      );
      expect(
        link.targetId.toLowerCase(),
        isNot(node.id.toLowerCase()),
        reason: '${node.id} has a self-link for ${link.phrase}',
      );
    }
  });

  test('astronomy and temple nodes carry the updated long-form essays', () {
    final expectedSections = <String, List<String>>{
      'hathor': [
        'Hathor does not mean one thing.',
        'The Sky-Cow',
        'The Eye of Ra',
        'The Lady of the West',
      ],
      'dendera': [
        'The ceiling of the Dendera temple records time.',
        'The Temple Structure',
        'The Astronomical Ceilings',
        'The New Year at the Roof',
      ],
      'sah': [
        'When Asar (Osiris) entered the Duat, he entered the sky.',
        'The Sahu',
        'The 70-Day Parallel',
        'The Heavenly Field',
      ],
      'abydos': [
        'To be remembered at Abydos was to be remembered where it mattered most.',
        "Umm el-Qa'ab",
        'The Mysteries of Asar',
        'The Abydos King List',
      ],
      'decans': [
        'The night has hours. Knowing which hour you are in requires a clock.',
        'The Diagonal Star Tables',
        'Calibration Against Sopdet',
        'The Decanal Ceilings',
      ],
    };

    for (final entry in expectedSections.entries) {
      final node = KemeticNodeLibrary.resolve(entry.key);
      expect(node, isNotNull, reason: entry.key);
      final resolvedNode = node!;

      for (final section in entry.value) {
        expect(resolvedNode.body, contains(section), reason: resolvedNode.id);
      }

      for (final link in resolvedNode.linkMap) {
        expect(
          resolvedNode.body.contains(link.phrase),
          isTrue,
          reason:
              '${resolvedNode.id} link phrase is not in body: ${link.phrase}',
        );
        expect(
          link.targetId.toLowerCase(),
          isNot(resolvedNode.id.toLowerCase()),
          reason: '${resolvedNode.id} has a self-link for ${link.phrase}',
        );
      }
    }
  });

  test('all library jump link targets resolve', () {
    for (final node in KemeticNodeLibrary.nodes) {
      for (final link in node.linkMap) {
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${node.id} links to missing node ${link.targetId}',
        );
      }
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
