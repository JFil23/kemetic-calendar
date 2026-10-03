import 'kemetic_node_model.dart';

class KemeticNodeLibrary {
  KemeticNodeLibrary._();

  static const List<String> _canonicalNodeOrder = [
    'cosmic_order',
    'human_emergence',
    'ancient_african_tree',
    'green_sahara',
    'nile',
    'kemet',
    'rise_of_kush_and_kemet',
    'maat',
    'isfet',
    'regnal_year',
    'palermo_stone',
    'wadi_el_jarf_papyri',
    'imhotep',
    'house_of_life',
    'rekh_wer',
    'ptah',
    'memphite_theology',
    'shu',
    'nut',
    'ra',
    'khepri',
    'khnum',
    'djehuty',
    'ausar',
    'aset',
    'nebet_het',
    'heru',
    'set',
    'hawk',
    'jackal',
    'serpent',
    'hathor',
    'eye_of_ra',
    'sekhmet',
    'sopdet',
    'sah',
    'decans',
    'dendera',
    'esna_temple',
    'architrave',
    'abydos',
    'duat',
    'amduat',
    'horizon',
    'ka',
    'ba',
    'akh',
    'ren',
    'ib',
    'sheut',
    'shai',
    'natron',
    'false_door',
    'offering_formula',
    'hotep',
    'tomb_inscriptions',
    'pyramid_texts',
    'middle_kingdom_funerary',
    'coffin_texts',
    'book_of_the_dead',
    'declarations_of_innocence',
    'papyrus_chester_beatty_iv',
    'instruction_ptahhotep',
    'instruction_amenemope',
    'epagomenal_days',
    'wp_rnpt',
    'akhet',
    'peret',
    'shemu',
    'renenutet',
    'haw',
  ];

  static final Map<String, KemeticNode> _byId = {
    for (final node in _nodes) node.id.toLowerCase(): node,
  };

  static final List<KemeticNode> nodes = List.unmodifiable(
    _buildCanonicalNodes(),
  );

  static final Map<String, String> _aliases = {
    for (final node in _nodes)
      for (final alias in node.aliases)
        alias.toLowerCase(): node.id.toLowerCase(),
  };

  static List<KemeticNode> _buildCanonicalNodes() {
    final rawIds = _nodes.map((node) => node.id.toLowerCase()).toSet();
    final orderedIds = _canonicalNodeOrder
        .map((id) => id.toLowerCase())
        .toList(growable: false);

    final seen = <String>{};
    final duplicates = <String>{};

    for (final id in orderedIds) {
      if (!seen.add(id)) {
        duplicates.add(id);
      }
    }

    final orderedIdSet = orderedIds.toSet();
    final missingFromOrder = rawIds.difference(orderedIdSet);
    final unknownInOrder = orderedIdSet.difference(rawIds);

    if (duplicates.isNotEmpty ||
        missingFromOrder.isNotEmpty ||
        unknownInOrder.isNotEmpty) {
      throw StateError(
        'Invalid Kemetic library canonical order. '
        'Duplicates: ${duplicates.join(', ')}. '
        'Missing from order: ${missingFromOrder.join(', ')}. '
        'Unknown in order: ${unknownInOrder.join(', ')}.',
      );
    }

    return [for (final id in orderedIds) _byId[id]!];
  }

  static KemeticNode? resolve(String idOrAlias) {
    final key = idOrAlias.trim().toLowerCase();
    if (key.isEmpty) return null;
    final id = _byId.containsKey(key) ? key : _aliases[key];
    if (id == null) return null;
    return _byId[id];
  }
}

const List<KemeticNode> _nodes = [
  KemeticNode(
    id: 'cosmic_order',
    title: 'Cosmic Order',
    glyph: '𓆄',
    aliases: ['Cosmic Beginnings', 'Elemental Memory', 'Stardust Becomes Life'],
    body: '''
Before there was a world to order, there was only potential.

Kemetic creation traditions imagined that unformed depth as Nun: the boundless state from which distinction could emerge. Modern cosmology tells a different kind of story, but one with a striking material fact at its center: the elements in bodies, oceans, soil, and planets were forged through stellar processes long before Earth existed. Stars make heavier elements, release them, and later generations of worlds are built from what earlier stars gave up.

That does not make modern astrophysics a confirmation of Kemetic theology. It gives us a useful point of contact. Ra can be read as radiant order, Nun as undifferentiated potential, and Ma'at as the human language hꜣw uses for the emergence and maintenance of relation. The correspondence is interpretive, not scientific proof.

## Stardust Becomes Life

About 4.6 billion years ago, material from older stars gathered into the solar system. Carbon, oxygen, nitrogen, iron, calcium, phosphorus, and other elements became part of Earth and eventually part of living bodies. The phrase “we are made of stardust” is not metaphor alone. The materials of life really do have a stellar history.

This is the piece worth holding onto: stars do not keep what they make. Their life cycles distribute material forward. What ends in one form becomes condition for another.

That pattern later becomes recognizable in Kemetic images of Ausar (Osiris): broken, gathered, restored, and made productive again. The comparison should remain a comparison, but it is a powerful one.

## Order Is Not the Same as Certainty

The farther the Library moves from established astronomy into claims about human consciousness, cosmic radiation, or “alignment” with the galactic center, the evidence becomes weaker. Axial precession is real. Cosmic rays are real. Climate changes driven by orbital cycles are real. There is no established evidence that those mechanisms caused symbolic consciousness to emerge in Homo sapiens.

The mystery does not need a false answer to stay meaningful.

What we can say is enough: matter gathered into stars; stars made the elements of later worlds; Earth formed from that inheritance; life emerged under planetary conditions; and eventually a species appeared capable of looking back at the cosmos and asking what kind of order it belonged to.

Cosmic Order is the widest frame in the Library. It asks us to see existence not as a collection of isolated things, but as inheritance moving through transformation. In the Ma'at lens, the question is not whether the universe was secretly Egyptian. The question is whether we can recognize that nothing exists alone, and live as though relation has consequences.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar (Osiris)", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Homo sapiens', targetId: 'human_emergence'),
    ],
  ),
  KemeticNode(
    id: 'human_emergence',
    title: 'Human Emergence',
    glyph: '𓀀',
    aliases: ['Great Awakening', 'Hominid Lineage', 'Sapiens Awakening'],
    body: '''
Human emergence is not a ladder with one clean step at the top.

The human line branched, overlapped, migrated, interbred, adapted, and disappeared in different places over immense spans of time. Homo sapiens arose in Africa from a much older African lineage, while Neanderthals and Denisovans developed along related branches outside the continent. The record is complicated because evolution is complicated.

What matters for this Library is not a fantasy of sudden perfection. It is the long movement from surviving within an environment to becoming capable of representing that environment symbolically: naming, remembering, teaching, burying, marking, imagining, and eventually building traditions that could outlive a single generation.

## The African Human Story

Australopithecines walked upright millions of years before us. Homo habilis used stone tools. Homo erectus traveled beyond Africa, used increasingly sophisticated technology, and lived across a much wider range of environments. Later human populations developed in Africa and Eurasia, and Homo sapiens eventually became the only surviving human species.

The older production text treats some transitions as mysterious “leaps.” That language should be held carefully. The evidence does not require an unexplained supernatural jump. Changes in anatomy, diet, climate, social structure, technology, and communication accumulated unevenly over time.

The genuinely interesting threshold is symbolic life.

By roughly 300,000 years ago, anatomically modern humans existed. Over the long period that followed, evidence for increasingly complex tools, long-distance exchange, pigment use, ornament, burial, and symbolic behavior became more visible. Human beings were not only adapting to the world. They were beginning to carry models of the world inside themselves and transmit those models to one another.

## When Survival Starts Remembering Itself

Ritual matters here because ritual is survival made reflective. A burial says the dead are not treated like discarded matter. A repeated mark says an idea can outlast the hand that made it. A shared story allows people who were not present at an event to organize themselves around its meaning.

This is where the Ma'at lens becomes useful without pretending to be archaeology. Ma'at is a later Kemetic articulation of right relation, not a doctrine we can project hundreds of thousands of years backward. But the capacity required for Ma'at—to recognize pattern, consequence, obligation, memory, and relation—had to emerge before any civilization could name it.

Human Emergence is therefore less about the moment “consciousness switched on” than about a species becoming increasingly able to ask what its actions mean beyond the immediate moment.

Intelligence becomes culturally powerful when it can remember, coordinate, and hold itself accountable to something larger than appetite. That is the bridge from survival to civilization.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Homo sapiens', targetId: 'ancient_african_tree'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Kemetic', targetId: 'kemet'),
    ],
  ),
  KemeticNode(
    id: 'ancient_african_tree',
    title: 'Ancient African Tree',
    glyph: '𓆭𓀀',
    aliases: [
      'Homo Sapiens',
      'African Tree',
      'Latest Branch',
      'Homo Sapiens Were the Latest Branch on an Ancient African Tree',
    ],
    body: '''
Homo sapiens were not the beginning of humanity. We are the latest surviving branch of a much older African tree.

That matters because the human story is often told as though modern humans suddenly appeared and everything before us was rehearsal. It was not. Upright walking, tool use, migration, cooperation, fire, adaptation, and social learning all have histories older than our species.

## One Tree, Many Branches

Australopithecines lived in Africa millions of years before Homo sapiens. Later members of the genus Homo spread into different regions, where populations adapted to different climates and pressures. Neanderthals developed in western Eurasia; Denisovan populations left genetic traces across parts of Asia and Oceania; Homo sapiens emerged in Africa and later encountered and interbred with some of these populations.

The surviving line is African in origin, but human ancestry outside Africa is not genetically sealed from the branches it met. That is why many living populations carry Neanderthal or Denisovan ancestry alongside their overwhelmingly shared human genome.

The important point is not hierarchy. It is adaptation.

Different bodies were responses to different environments. Cold, altitude, diet, disease, mobility, and social networks all shaped what persisted. None of those adaptations amount to separate human origins.

## The Advantage of Connection

The older Library copy frames Homo sapiens' broader social networks as one reason our lineage proved unusually adaptable. That remains a useful emphasis, but it should not be turned into a single-cause explanation for the disappearance of other humans. Climate, population size, competition, interbreeding, disease, and demographic instability all likely mattered.

Still, the power of large social networks is real. Knowledge can travel farther than the person who discovered it. A tool can spread. A drought can be survived with information from another group. Story, trade, kinship, and symbolic identity let cooperation extend beyond immediate familiarity.

That is the Ma'at connection worth keeping.

Deep roots did not prevent branching. Branching did not erase common origin. Adaptation did not require isolation from the larger tree.

Human diversity makes more sense when understood as variation within relation. The mistake is not noticing difference. The mistake is treating branches as though they were separate trees.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Homo sapiens', targetId: 'human_emergence'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'green_sahara',
    title: 'Green Sahara',
    glyph: '𓇅𓇾',
    aliases: [
      'African Humid Period',
      'Garden of Eden',
      'Prehistoric Civilizations in Saharan Africa',
      'Great Departure',
      'Saharan Eden',
    ],
    body: '''
The Sahara was not always desert.

During the African Humid Period, large parts of northern Africa held lakes, rivers, wetlands, grasslands, wildlife, and human communities. The exact timing varied by region, but the broad transformation was driven by orbital changes that strengthened African monsoon systems. What is now one of the driest landscapes on Earth was, for thousands of years, a very different world.

That vanished landscape matters because people lived in it long enough to build memory around water, cattle, season, migration, and sky.

## A World Hidden by Sand

Sites such as Nabta Playa preserve evidence of pastoral life, cattle ritual, settlement, and deliberate seasonal observation in northeastern Africa before dynastic Kemet. Some proposed solar or stellar orientations are plausible, but the precision and intent of those alignments remain debated. Rock art at Tassili n'Ajjer preserves herding, ceremony, animals, and human figures across a landscape that no longer looks capable of supporting what the images show.

The desert did not erase that history completely. It made it harder to see.

That has consequences for how civilization gets imagined. Monumental stone and writing survive well, so cultures that built in those media dominate historical memory. Mobile pastoral communities leave a different record: pottery, burials, bones, tools, rock art, campsites, and patterns of movement rather than monumental capitals.

Absence of monuments is not absence of knowledge.

## The Great Drying

As the Sahara became drier, communities moved in many directions—toward the Nile, the Sahel, the Mediterranean, and other regions where water and grazing remained viable. This was not one migration by one people, and it should not be flattened into a single origin story for Kemet.

What can be said more carefully is that Kemet emerged within a much older northeastern African world. Pastoral traditions, cattle symbolism, seasonal observation, and long experience reading land and sky existed before the dynastic state. Some of those patterns continued, changed, and were institutionalized in the Nile Valley.

The “Garden of Eden” comparison in the older Library is better treated as comparative imagination, not history. Cultures often remember lost abundance. A greening Sahara gives that image a powerful African analogue, but not a proven source for Genesis.

The deeper lesson is less dramatic and more useful: conditions change, and knowledge has to travel when they do.

The Green Sahara is a story about a people-land relationship that could not remain fixed. In the Ma'at lens, alignment does not mean preserving one environment forever. It means learning a place well enough to live within it, then carrying what remains useful when the place itself changes.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'rise_of_kush_and_kemet',
    title: 'Rise of Kush and Kemet',
    glyph: '𓈘𓊖',
    aliases: [
      'Kush',
      'Kemet and Kush',
      'Nile Silt',
      'Ethiopian Highlands',
      'Medu Neter',
      'Symbolic Literacy',
      'Words of the Divine',
    ],
    body: '''
Kemet and Kush did not appear from an empty map.

They also did not take dynastic form at the same moment. Dynastic Kemet consolidated earlier; Kerma, the first major Kushite polity, rose centuries later to the south. Their histories eventually became deeply entangled along a Nile corridor already carrying long traditions of movement, cattle, trade, ritual, seasonal observation, and exchange across northeastern Africa.

## The River Made Scale Possible

The Nile's annual rhythm made intensive agriculture unusually dependable in the valley. Surplus could support permanent settlements, specialized labor, temples, administration, large building projects, and long-term recordkeeping.

That does not mean the Nile “caused civilization.” It means the river created conditions that people learned to organize.

The fertility carried north by the Nile system also tied Kemet materially to regions far upstream. Water, silt, stone, trade, cattle, gold, people, and ideas moved along the corridor in both directions.

## Kemet and Kush

Kush developed south of Kemet in Nubia and became, at different times, trading partner, rival, subordinate territory, independent kingdom, and imperial power. The relationship cannot be reduced to one civilization borrowing from the other. Their histories are entangled.

During the Twenty-Fifth Dynasty, Kushite rulers conquered and ruled Kemet as pharaohs. Their kings presented themselves through Kemetic royal forms while also carrying Kushite traditions rooted farther south.

That long relationship makes more sense when both are treated as African civilizations of the Nile world rather than as sealed cultures facing each other across a border.

## Memory Becomes Institution

What makes dynastic Kemet especially visible to us is not that earlier African societies lacked knowledge. It is that Kemet built institutions designed to preserve knowledge.

Medu Neter joined sound, image, object, title, number, ritual, and sacred association in a writing system used for administration as well as religion. The House of Life trained scribes, copied texts, preserved calendars, maintained medical and ritual knowledge, and kept names legible across generations.

This is where the Library's Ma'at connection becomes concrete.

A fertile environment can produce surplus. Surplus can disappear. Knowledge can be discovered and forgotten. A state can become powerful and still fail to transmit what it knows.

Kemet's durability came partly from turning memory into work: measuring, writing, copying, teaching, building, and repeating.

What the land gives becomes civilization only when people organize it. What a civilization learns becomes inheritance only when somebody takes responsibility for carrying it forward.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
      KemeticNodeLink(phrase: 'House of Life', targetId: 'house_of_life'),
    ],
  ),
  KemeticNode(
    id: 'serpent',
    title: 'Serpent',
    glyph: '𓆙',
    aliases: ['Apophis', 'Mehen'],
    body: '''
No single meaning can contain the serpent in Kemetic thought.

A serpent can obstruct Ra, protect him, defend a king, carry venom, reveal hidden knowledge, or guard nourishment. The form stays recognizable while the function changes.

This is one of the clearest examples of polysemy in the Library: the same image can hold different truths depending on position and relation.

## Apepi and Mehen

Apepi rises against the solar journey. Its role is obstruction: stop the bark, prevent dawn, break the cycle.

Mehen also coils, but around Ra as protection.

Same basic animal form. Opposite relation to the journey.

That difference makes the serpent more interesting than a simple “good versus evil” symbol. Power takes character from what it serves.

## The Uraeus

The rearing cobra at the brow of the king gives serpent force a third placement.

Here the danger points outward.

The uraeus warns, protects, and makes royal power visibly capable of striking. The threat is not hidden; it is positioned.

## Aset's Serpent

In the story of Aset and Ra, the serpent becomes strategy. Aset fashions it, places it, and uses the crisis it creates to gain access to Ra's hidden name.

The serpent is not random chaos there. It is controlled leverage.

That range is the lesson.

Power is not automatically Ma'at because it is powerful. Nor is danger automatically Isfet because it is dangerous.

The question is placement.

What is the force doing? What is it protecting? What is it interrupting? Who directs it? Can it be recalled?

The serpent is the Library's reminder that untamed energy is not a moral category yet.

Relation gives it direction.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: "Aset", targetId: 'aset'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'hawk',
    title: 'Hawk (Heru)',
    glyph: '𓅃',
    aliases: ['Falcon', 'Falcon (Heru)', 'Eye of Horus', 'Eye of Heru'],
    body: '''
The bird behind Heru is more precisely described as a falcon, though “hawk” remains common in older English renderings.

The falcon sees the ground from a position the ground cannot give. That is why the form became so closely associated with Heru and kingship.

Height creates perspective. A falcon can hold position, read a wide landscape, and commit suddenly when the moment to act arrives. Kemetic sacred thought turned those visible qualities into a language of authority.

## The Eye

The Eye of Heru complicates the image.

The eye is damaged in the conflict with Set, divided, then restored. Wholeness is not assumed; it is recovered.

That made the Eye useful far beyond mythology. It became an image of restoration, completeness, protection, and measure.

The old Library copy leans heavily on the Eye as a moral instrument, and that part is worth keeping: sight is not enough if what sees is damaged.

A person can have authority and still misread the field.

## Authority Requires Perspective

Heru's contest with Set asks whether power is legitimate simply because it can take a position. The hawk image adds another requirement: the ruler has to see more than the immediate appetite of the ruler.

That is the Ma'at connection.

Good authority should increase the field of view.

It should see who is affected, what lies beyond the nearest consequence, where the boundaries actually are, and what the whole requires rather than what one part wants.

The hawk is not a symbol of domination because it flies above.

It is a warning that elevation creates responsibility.

The higher the position, the more of the landscape you are expected to see before you strike.
''',
    linkMap: [KemeticNodeLink(phrase: "Ma'at", targetId: 'maat')],
  ),
  KemeticNode(
    id: 'jackal',
    title: 'Jackal (Anpu)',
    glyph: '𓃢',
    aliases: ['Anubis', 'Anpu'],
    body: '''
The jackal was seen where the dead were placed.

Kemetic theology followed observation.

Wild canids moved along the desert edge near burial grounds, the charged boundary between cultivated land and the necropolis. Anpu emerged from that landscape as the figure of correct transition: embalming, protection, passage, and the weighing of the heart.

He is not simply “the god of death.”

He is the one who attends what must cross.

## Black Like Fertile Earth

Anpu's black color is important.

Black in Kemet could evoke the rich Nile silt, regeneration, and renewed fertility. The color does not simply mark death. It marks the possibility that what enters decay can be prepared for another condition.

That fits embalming perfectly.

Natron, wrapping, anointing, ritual speech, and careful preservation all belong to a process that refuses to treat the body as abandoned matter.

## He Holds the Scale

In the Hall of Two Truths, Anpu steadies the balance.

He does not decide the result.

That distinction is the heart of his function.

The scale should be held accurately enough that the heart and feather can reveal their relation without manipulation. Anpu attends the procedure; Djehuty records; Ma'at supplies the standard.

## What Boundaries Need

The necropolis, embalming chamber, tomb entrance, and judgment hall are different places, but Anpu's work remains recognizable across them.

Something is leaving one state and entering another.

Transitions fail when nobody owns the care required between “before” and “after.”

That is Anpu's Ma'at lesson.

Do not confuse guiding a transition with controlling its outcome.

Prepare the body. Hold the scale. Guard the threshold. Make the passage possible.

Then let what is true determine what continues.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(
        phrase: 'Hall of Two Truths',
        targetId: 'declarations_of_innocence',
      ),
      KemeticNodeLink(phrase: "Natron", targetId: 'natron'),
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
    ],
  ),
  KemeticNode(
    id: 'nile',
    title: 'Nile & Hapy (Inundation)',
    glyph: '𓈘',
    aliases: ['Hapy', 'Nile', 'Inundation', 'Nile Inundation'],
    body: '''
The Nile is the river. Hapy is the inundation.

That distinction matters. Hapy is not simply another name for the Nile as a whole. He personifies the fertile annual rise—the arrival of water and silt that changed the condition of the valley and made the next agricultural cycle possible. The Nile was the enduring channel. Hapy was the life-giving event.

No king could command either.

Everything depended on learning how to meet what arrived.

## The Gift That Could Not Be Forced

The Hymn to Hapy praises the inundation as the source of grain, storehouses, offerings, livestock, and abundance. Even the temple economy depended on the flood because gods cannot be offered bread when fields do not produce grain.

Kemetic theology also linked the river's renewal with Asar (Osiris), whose death and restoration became a sacred language for fertility, hiddenness, and return. That sacred reading does not replace hydrology. It tells us what recurring water meant inside a culture built around receiving it.

In hꜣw's ideal agricultural frame, the inundation opens Akhet, the withdrawing water prepares Peret, and the crop eventually reaches Shemu. Historically, the civil calendar drifted against the natural seasons, so that sequence should be understood as a seasonal model rather than a fixed date map for every period of Egyptian history.

## Measure Was a Moral Problem

A flood too low meant scarcity. A flood too high could destroy settlements and infrastructure. What mattered was not simply more water.

What mattered was proportion.

Nilometers turned that proportion into record. Flood height shaped expectations for harvest, tax, storage, and distribution. The Palermo Stone preserves annual inundation measurements alongside royal events because the condition of the flood was part of the condition of the state.

Then the water erased another kind of certainty: boundaries.

Fields disappeared beneath the inundation. When the water withdrew, land had to be measured again. A false boundary could steal from one household and enrich another. A false flood reading could corrupt taxation. Measurement was therefore never neutral administration. It affected who ate, who paid, what was stored, and what remained for the future.

This is why the Nile and Hapy sit so naturally beside Ma'at.

The river and flood were not moral agents. The human response was.

Kemet survived not by controlling the water but by meeting it with preparation, accurate measure, fair distribution, and storage disciplined enough to carry abundance into scarcity.

Some of the forces that sustain a life will always remain outside your control.

Responsibility begins with how well you receive them. When receipt loses measure, abundance itself can become Isfet.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
      KemeticNodeLink(phrase: 'Asar (Osiris)', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
      KemeticNodeLink(phrase: 'Akhet', targetId: 'akhet'),
      KemeticNodeLink(phrase: 'Peret', targetId: 'peret'),
      KemeticNodeLink(phrase: 'Shemu', targetId: 'shemu'),
      KemeticNodeLink(phrase: 'Palermo Stone', targetId: 'palermo_stone'),
    ],
  ),
  KemeticNode(
    id: 'ptah',
    title: 'Ptah',
    glyph: '𓊪𓏏𓎛',
    body: '''
Ptah creates before the hand moves.

In the Memphite Theology, creation begins in the heart and becomes effective through the tongue. Thought is not enough. Speech is not enough. Form appears when conception and expression agree closely enough to become real.

That makes Ptah less a god of “ideas” than a god of formed intention.

## Heart, Tongue, Hand

Ptah is shown mummiform, contained rather than expansive, holding signs of life, stability, and authority. His power is not dramatic movement. It is the inward act that precedes movement.

The heart-and-tongue creation account comes to us through the Memphite Theology as preserved on the Twenty-Fifth Dynasty Shabaka Stone, around 710 BCE. The stone says it copied an older damaged source, but the age of that underlying composition is debated. This should not be presented as securely Old Kingdom Ptah doctrine.

Within the surviving theology, perception reaches the heart, the heart conceives, the tongue gives command, and creation follows.

Kemetic ritual and craft both make more sense through that sequence.

An offering formula is effective because words are placed correctly. A decree matters because what is intended is declared in a recognized form. A sculptor works from an idea toward measured material. A builder cannot skip the conception and expect the stone to discover the plan on its own.

## Creation Is Responsible

This is where Ptah becomes more than a creation story.

If thought and speech participate in making the human world, careless thought and careless speech are not private accidents. They produce.

The Instruction of Ptahhotep repeatedly warns against speaking beyond knowledge. Djehuty adds the discipline of measure. Imhotep becomes the human image of knowledge translated into durable structure.

Ptah's question is therefore simple and difficult: what are you actually making with what you repeatedly think, say, and build?

The point is not magical manifestation. The Kemetic idea is more demanding than that. Intention has to survive translation into speech, action, craft, and consequence.

In the Ma'at lens, a good intention that forms a bad structure still requires correction.

Creation is complete only when what was meant, what was said, and what was made belong to the same order.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(
        phrase: 'Memphite Theology',
        targetId: 'memphite_theology',
      ),
      KemeticNodeLink(phrase: 'Shabaka Stone', targetId: 'memphite_theology'),
      KemeticNodeLink(phrase: 'Imhotep', targetId: 'imhotep'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
    ],
  ),
  KemeticNode(
    id: 'djehuty',
    title: 'Djehuty',
    glyph: '𓅝',
    aliases: ['Thoth', 'Djehuty'],
    body: '''
Djehuty is what keeps reality from becoming whatever the loudest person says happened.

He is associated with writing, reckoning, measurement, the moon, time, speech, and divine record. These roles make sense together because they all depend on one discipline: things have to be distinguished accurately enough to be counted, named, and remembered.

## Measure Before Judgment

In the Hall of Two Truths, Anpu steadies the scale and the feather of Ma'at provides the standard. Djehuty records the result.

He is not there to make the heart lighter.

He writes what the measure reveals.

That is the core of his authority. A record should stand outside appetite.

The same principle appears in calendars, boundaries, offerings, taxes, and ritual timing. If the count drifts, everything that depends on the count drifts with it.

## Ibis, Baboon, Moon

Djehuty's forms make this abstract discipline visible.

The ibis probes the waterline, searching beneath the surface. The baboon greets dawn, marking return. The moon changes constantly while remaining measurable through its phases.

All three images reward careful attention rather than assumption.

## Exact Speech

The wisdom tradition adds another layer: speech should not outrun knowledge.

A person can create enormous disorder by saying something imprecise at the wrong moment and then allowing the statement to harden into record. A promise, accusation, instruction, diagnosis, or measurement can all fail this way.

Djehuty's Ma'at is therefore not silence.

It is correspondence.

See clearly enough to measure honestly. Measure honestly enough to record accurately. Speak precisely enough that what leaves your mouth does not become a distortion someone else has to live inside.

Memory becomes trustworthy only when someone accepts the burden of exactness.
''',
    linkMap: [KemeticNodeLink(phrase: "Ma'at", targetId: 'maat')],
  ),
  KemeticNode(
    id: 'shu',
    title: 'Shu',
    glyph: '𓇯𓇾',
    body: '''
Shu is the space that lets things become themselves.

In the Heliopolitan creation tradition, sky and earth—Nut and Geb—are separated by Shu. The image is physical: the sky lifted, the earth below, air and light opening between them.

Before that separation, there is closeness without function.

## The Space Between

Shu is often associated with air, light, and the act of lifting. The Pyramid Texts repeatedly invoke him as the one who raises the sky and helps lift the deceased upward.

The point is not empty distance.

Once there is space, movement becomes possible. Light can travel. Breath can move. A bird can fly. The solar journey has a field through which to pass. Distinct things can stand in relation instead of collapsing into one another.

That makes Shu one of the Library's clearest images of boundary as a creative act.

## Separation Is Not Rejection

Modern language often treats separation as loss: distance, alienation, disconnection. Shu shows another possibility.

Sometimes two things need distance in order to function.

A role needs a boundary. A relationship needs enough space for two people to remain two people. A judgment needs distinction between what happened and what someone wishes had happened. A household needs some clarity between what is shared and what belongs to each person.

Without distinction, fairness becomes difficult because nothing has a stable shape.

Shu has his own feather emblem, and it should not simply be collapsed into the feather of Ma'at. The visual resemblance still lets the two ideas speak beside one another: order depends not only on joining what belongs together but also on keeping apart what must remain distinct.

The lesson is not “create distance everywhere.”

It is: protect the space that allows relation to stay healthy.

A boundary is successful when it makes connection possible without collapse.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Nut', targetId: 'nut'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: "feather of Ma'at", targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'maat',
    title: "Ma'at",
    glyph: '𓆄',
    body: '''
What holds when no one is watching?

That question gets closer to Ma'at than the usual translation “truth,” “justice,” or “order.” Ma'at includes all of those, but it is larger than any one of them. It is the condition in which things stand in right relation: speech to truth, measure to reality, authority to responsibility, offering to obligation, person to community, and human action to the larger order it depends on.

Ma'at was personified as a netjeret and symbolized by the feather, but it was never only a deity to invoke. It was something that had to be done.

## The Standard Is Practical

A field boundary redrawn after the flood can be accurate or dishonest. A judge can apply one standard to the powerful and another to the weak. A scribe can record what happened or what is convenient. A household can give what is owed or quietly take more.

These look like different problems. In the Kemetic worldview they injure the same thing.

That is why Ma'at appears in law, agriculture, kingship, ritual, accounting, speech, and funerary judgment. Right order is not a separate spiritual layer placed on top of ordinary life. Ordinary life is where it is either maintained or damaged.

## The Feather

In the Hall of Two Truths, the heart of the deceased is weighed against the feather of Ma'at. The image is severe because reputation cannot substitute for substance. The heart carries what was lived.

The Declarations of Innocence make the standard concrete: do not steal, falsify, exploit, move boundaries unjustly, cause unnecessary suffering, or use power to take what is not yours. Older autobiographical inscriptions make the positive side equally clear: feed, hear, protect, judge fairly, speak truth when it matters.

Ma'at is therefore not perfection. It is disciplined relation.

The point is not to become morally weightless. It is to become the kind of person whose habits, speech, work, and obligations can withstand measurement.

That is why Ma'at still works inside hꜣw. A calendar organized around purpose is ultimately asking the same question the feather asks: does what you are doing fit the life, relationships, responsibilities, and values you claim to be serving?

Ma'at does not need grand gestures. It needs the measure to remain true when changing it would be easier.
''',
    linkMap: [
      KemeticNodeLink(
        phrase: 'Hall of Two Truths',
        targetId: 'declarations_of_innocence',
      ),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: 'feather', targetId: 'declarations_of_innocence'),
    ],
  ),
  KemeticNode(
    id: 'declarations_of_innocence',
    title: 'Declarations of Innocence',
    glyph: '𓉹𓆄𓆄',
    aliases: [
      'Hall of Two Truths',
      'Declarations of Virtue',
      'Forty-Two Declarations',
      'medu maat',
      'DOI',
      'DOV',
    ],
    body: '''
The Declarations of Innocence ask the dead to speak about the life already lived.

That distinction matters.

They are not promises about what the person will do better next time.

They are claims the heart must be able to survive.

## What Was Declared

In the Hall of Two Truths, the deceased addresses a divine tribunal and denies specific forms of wrongdoing.

The declarations include harm, theft, falsehood, abuse, crooked measure, unjust seizure, exploitation, and other failures of relation.

The exact lists and translations vary across manuscripts and scholarship, but the structure is clear: conduct is made specific.

Ma'at is not left as a vague feeling of being a good person.

## The Older Moral Tradition

Long before later judgment papyri, tomb autobiographies already preserved moral self-presentations.

Officials claimed they fed, protected, judged fairly, spoke truth, and did not abuse the vulnerable.

Those texts are not proof that every speaker lived perfectly.

They show what a life wanted to be able to claim publicly.

The standard becomes visible through the claim.

## The Hall Is Already Here

This is where the Library's older writing was especially strong.

The declarations do not become true because someone recites them at death.

The heart is weighed.

The statement and the life have to agree.

That gives the scene its enduring force.

You do not prepare for judgment by learning better excuses.

You prepare by living in a way that makes the declaration less false.

The Declarations of Innocence are therefore not mainly about fear of the afterlife.

They are a technology for bringing the future question into the present day.

What would you need to be able to say truthfully at the end?

Practice that before the hall.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
    ],
  ),
  KemeticNode(
    id: 'ausar',
    title: 'Ausar',
    glyph: '𓊨𓁹',
    aliases: ['Asar', 'Osiris', 'Wsir'],
    body: '''
Ausar is the god who is restored without having death erased from his story.

That is the point.

Set kills and scatters him. Aset searches. Nebet-Het mourns and attends. Anpu prepares the body. Heru gathers, restores, and succeeds. Ausar does not return to ordinary kingship among the living; he becomes ruler in the Duat.

The wound remains part of the restored form.

## Gathered, Not Replaced

The Pyramid Texts return again and again to the image of Heru gathering the limbs of his father.

Restoration is specific. Pieces have to be found. They have to be placed correctly. A body cannot be declared whole while its parts remain scattered.

That is why Ausar became such a powerful model for funerary thought. The person after death also has aspects that must remain in relation: ka, ba, ren, ib, sheut, body, memory, offering, name.

Continuation is not automatic.

It has to be assembled.

## Renewal in the Hidden Place

Ausar becomes lord of the Duat, the region through which Ra travels at night. In the Amduat, solar renewal reaches its deepest point in the hidden world associated with Ausar.

That places restoration where modern instinct often does not want it: inside darkness, not outside it.

The field carries the same logic. Seed enters the earth. Flood covers the land. Grain disappears before it returns as food. Kemet repeatedly found renewal in processes that looked, for a time, like disappearance.

## Vindication

Restoration is not only physical. The wrong against Ausar also has to be answered.

Heru's claim must be recognized. Set's force cannot simply become legitimacy because it succeeded temporarily. The dead likewise seek to become “true of voice” before continuing.

This is Ausar's Ma'at lesson.

Repair is incomplete if the pieces are reassembled but the truth of what happened is left unresolved.

What is broken needs more than survival.

It needs gathering, restoration, and a form stable enough that brokenness does not become the inheritance of whoever comes next.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Set', targetId: 'set'),
      KemeticNodeLink(phrase: "Aset", targetId: 'aset'),
      KemeticNodeLink(phrase: "Nebet-Het", targetId: 'nebet_het'),
      KemeticNodeLink(phrase: "Anpu", targetId: 'jackal'),
      KemeticNodeLink(phrase: "Heru", targetId: 'heru'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'ba', targetId: 'ba'),
      KemeticNodeLink(phrase: 'ren', targetId: 'ren'),
      KemeticNodeLink(phrase: 'ib', targetId: 'ib'),
      KemeticNodeLink(phrase: 'sheut', targetId: 'sheut'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Amduat', targetId: 'amduat'),
      KemeticNodeLink(
        phrase: 'true of voice',
        targetId: 'declarations_of_innocence',
      ),
    ],
  ),
  KemeticNode(
    id: 'aset',
    title: 'Aset',
    glyph: '𓊨',
    aliases: ['Isis', 'Aset'],
    body: '''
Aset rarely wins by using more force.

She wins by understanding the structure of the problem.

Her stories return to the same pattern: search carefully, discover what is hidden, protect what is vulnerable, speak at the right moment, and use leverage where direct power would fail.

That is why heka—effective sacred power—belongs so naturally to her.

## She Finds What Was Scattered

After Ausar is killed and dismembered, Aset searches for what was lost. Nebet-Het accompanies the mourning and restoration. Anpu prepares the body. Heru eventually completes the line of succession.

Aset's work comes first as attention.

She refuses to let scattering become the final condition.

Her wings over Ausar became one of the enduring images of funerary protection: breath, enclosure, presence, and active care directed toward what can still be restored.

## The Secret Name of Ra

The story of Aset and Ra shows her method at its sharpest.

Aset wants Ra's hidden name. She cannot simply overpower him. Instead, she fashions a serpent from his own substance, creates a crisis only she can resolve, and withholds the cure until he reveals the name.

The story is uncomfortable because it is supposed to show intelligence as power.

Aset understands where the situation can be moved.

She does not push everywhere. She finds the point that matters.

## Protecting Heru

She uses a different kind of strategy with the young Heru: concealment, patience, protection, time.

Not every problem should be confronted immediately. Sometimes the right act is to keep what is not yet strong enough away from the fight it will one day have to enter.

That is Aset's Ma'at connection.

Precision beats force when force cannot reach the real problem.

Understand first. Find the leverage. Protect what is not ready. Act when timing makes the action effective.

Aset is not passivity.

She is disciplined intelligence applied exactly where it can change the outcome.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: "Heru", targetId: 'heru'),
      KemeticNodeLink(phrase: "Nebet-Het", targetId: 'nebet_het'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'serpent', targetId: 'serpent'),
    ],
  ),
  KemeticNode(
    id: 'heru',
    title: 'Heru',
    glyph: '𓅃',
    aliases: ['Horus', 'Heru'],
    body: '''
Set is stronger.

Heru has the rightful claim.

The Contendings of Heru and Set matters because the tradition refuses to pretend those are the same thing.

Power can occupy a position. Legitimacy has to be recognized through relation, duty, and judgment.

## The Son Who Tends His Father

Heru's claim does not begin with a speech about entitlement.

It begins with Ausar.

The Pyramid Texts repeatedly describe Heru gathering his father's limbs, restoring what had been damaged, providing for him, and making him whole. The heir demonstrates fitness by tending what the office inherited in broken condition.

That changes the meaning of succession.

Heru does not deserve the throne merely because he is next in line. Lineage matters, but the work matters too.

## Contest and Recognition

The dispute with Set lasts because strength is persuasive.

Set can defend, fight, and seize. Heru represents continuity through Ausar. The divine tribunal has to decide what kind of claim can support order over time.

The answer is not that force has no value. Set remains a necessary power in other contexts. The answer is that force alone cannot create rightful authority.

Recognition matters because authority affects everyone beneath it.

## Heru in the Living King

The pharaoh in life could be identified with Heru, while the dead king entered the Ausar pattern. Kingship became a chain: the living heir tending, restoring, and continuing what came before.

That is the useful moral.

If you inherit a role, a family, a company, a craft, a community, or a responsibility, possession is not proof that you deserve it.

What do you tend?

What do you restore?

What becomes more whole because you held the position?

Heru's Ma'at is legitimacy demonstrated through care before it is defended through power.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Set', targetId: 'set'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
    ],
  ),
  KemeticNode(
    id: 'isfet',
    title: 'Isfet',
    glyph: '𓆙',
    body: '''
Isfet is what happens when right relation is not maintained.

It is often translated as chaos, disorder, falsehood, or wrongdoing, but none of those words fully captures its range. Isfet can be dramatic—violence, usurpation, destruction—but it can also be administrative: a false record, a crooked measure, an obligation ignored until the failure spreads into something larger.

That is why the old royal formula matters: Ma'at is established “in the place of Isfet.” Disorder is not imagined as something permanently defeated. It is something that returns wherever maintenance stops.

## Isfet Spreads

The solar image is Apepi, the serpent that rises against Ra's night journey and tries to stop the return of dawn. The threat recurs. The response must recur too.

In ordinary life, the same logic is quieter. A false grain count produces a bad levy. A bad levy harms a household. A corrupted record becomes precedent. An unresolved wrong becomes the condition under which another wrong is easier to excuse.

Isfet propagates.

The danger is not only the original act. It is what gets built on top of it.

## Disorder With Intelligence

The most uncomfortable form of Isfet is not ignorance. It is knowledge used out of relation.

A skilled scribe can falsify more convincingly than an untrained person. A powerful ruler can turn force into law. A clever speaker can make distortion sound measured. Expertise without Ma'at becomes refined disorder.

This is why the Library should resist treating knowledge, power, ritual, or tradition as automatically good. Everything depends on placement.

Isfet does not self-correct simply because its consequences become obvious. Someone has to tell the truth, repair the record, restore the boundary, stop the harm, return what is owed, or rebuild what was neglected.

The moral is demanding because it is ordinary: what you allow to remain out of place becomes part of the environment the next decision has to work inside.

Ma'at is maintenance. Isfet is what maintenance leaves behind when it stops.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
    ],
  ),
  KemeticNode(
    id: 'ra',
    title: 'Ra',
    glyph: '𓇳',
    body: '''
Ra is not simply the sun.

Ra is the sun completing its course.

That distinction matters because the Kemetic solar imagination is built around movement, danger, disappearance, renewal, and return. Light that only shines is incomplete. The cycle has to close.

## Khepri, Ra, Atum

The solar day can be understood through three names.

Khepri is becoming—the sun emerging at dawn. Ra is the solar power fully underway. Atum is completion, the setting form entering the west.

These are not three unrelated suns. They are different moments in one process.

The solar barque makes that process visible. Ra crosses the day, enters the Duat at night, passes through opposition, meets renewal in the hidden region, and returns.

The Amduat gives the night twelve ordered hours rather than treating darkness as an empty gap. In its deepest region, Ra's renewal is linked with Ausar (Osiris), the power of restoration within death. Khepri's dawn is therefore prepared before dawn is visible.

## Ra and Ma'at

The Book of Coming Forth by Day and related solar traditions repeatedly bind Ra's passage to Ma'at. The exact wording and placement vary across compositions, so the broader relationship is more important here than making one position in the bark carry the whole argument.

That relationship is enough.

Movement needs direction. Energy needs relation. Continuity needs something that keeps the course from becoming mere repetition.

A person can stay busy for years without completing what matters. Ra's pattern makes a different demand: begin, travel, descend, renew, return.

The cycle is not successful because no darkness occurred. It is successful because darkness did not stop the course.

That is the human lesson worth carrying from Ra.

Consistency is not doing the same thing forever. It is completing the full rhythm—including descent, hidden work, and renewal—so that return remains possible.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar (Osiris)", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Khepri', targetId: 'khepri'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Amduat', targetId: 'amduat'),
      KemeticNodeLink(
        phrase: 'Book of Coming Forth by Day',
        targetId: 'book_of_the_dead',
      ),
    ],
  ),
  KemeticNode(
    id: 'ka',
    title: 'Ka',
    glyph: '𓂓',
    body: '''
The Ka is one of the hardest Kemetic ideas to translate cleanly because “soul” is too broad and “life force” is too thin.

The Ka is tied to vitality, presence, sustenance, inheritance, and the continuing identity of a person. It can be spoken of in life and after death. It receives offerings. It can be joined. It can be satisfied.

The raised-arms sign that writes ka gives the concept an image of reception.

## What the Ka Needs

Funerary texts repeatedly place bread, beer, and other provisions before the Ka.

That does not mean Egyptians imagined a ghost physically chewing food in the ordinary sense. It means sustenance remained relational after death.

The dead did not continue alone.

The offering formula, the name of the deceased, the tomb, and the living people who maintained the cult all worked together so the Ka could keep receiving.

This is why erasing a name was so serious.

An offering needs an address.

## Ka and Ba

The Ka and Ba should not be collapsed into one “spirit.”

The Ba is mobile—capable of going out and returning. The Ka is closer to the abiding presence that gives return somewhere to land.

The older Library's metaphor is useful: the Ka stays; the Ba travels.

That is not a complete scholarly definition, but it helps preserve the functional difference.

## The Human Meaning

The Ka's Ma'at connection is sustenance.

Anything meant to remain present has to be fed.

A relationship needs contact. A craft needs practice. A community needs participation. A body needs food. A memory needs someone to speak the name.

We often admire continuity as though endurance were a property some things simply possess.

The Ka says otherwise.

Presence is maintained.

What you want to keep alive will eventually ask what you are actually giving it.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ba', targetId: 'ba'),
      KemeticNodeLink(phrase: 'offering formula', targetId: 'offering_formula'),
    ],
  ),
  KemeticNode(
    id: 'ba',
    title: 'Ba',
    glyph: '𓅽',
    body: '''
The Ba is the part of the person that can move.

Kemetic art often shows it as a bird with a human head: unmistakably individual, but not confined to the body's ordinary range.

Funerary texts are concerned not only with whether the Ba exists but whether it can travel, return, pass doors, and avoid imprisonment.

Freedom is functional.

## The Way Must Be Open

The Book of Coming Forth by Day includes spells for the Ba to come forth, move through the hidden world, reach divine places, and return.

That repeated concern tells us what mattered.

A Ba trapped at a gate is not fully able to be itself.

But movement in one direction is not enough either. The Ba's pattern is departure and return.

## Freedom Needs a Home

This is where the Ba and Ka make sense together.

The Ba travels. The Ka remains as sustaining presence. The body, tomb, name, and offering cult all help maintain a recognizable point of return.

Freedom is therefore not severance.

It depends on connection strong enough to survive distance.

That is a much richer idea than “the soul leaves the body.”

## The Ma'at of Movement

Modern life often treats freedom as having no obligations.

The Ba suggests almost the opposite.

You can move because something holds.

The question is whether travel expands the person and returns something to the foundation, or whether movement becomes scattering.

Exploration, ambition, creativity, travel, and change all need a way back to what makes the person coherent.

The Ba's lesson is not “stay home.”

It is: build a home strong enough that going out does not require losing yourself.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(
        phrase: 'Book of Coming Forth by Day',
        targetId: 'book_of_the_dead',
      ),
    ],
  ),
  KemeticNode(
    id: 'akh',
    title: 'Akh',
    glyph: '𓅜',
    body: '''
The Akh is what a person becomes when the parts hold together well enough to remain effective beyond ordinary life.

“Spirit” does not quite capture it.

The Akh is luminous, capable, operative. The Pyramid Texts place the successful dead among the imperishable stars and repeatedly use language of becoming akh—becoming effective.

Effectiveness is the key.

## Not Just Survival

The goal is not simply to continue existing.

A preserved body is not yet an Akh. A remembered name is not yet an Akh. A free Ba is not yet an Akh. A fed Ka is not yet an Akh.

The traditions gathered in this Library treat continuation as a coordinated achievement.

Body, name, heart, Ba, Ka, ritual preparation, judgment, offering, and memory all matter because the person should not merely persist as scattered pieces.

These concepts overlap across texts and periods; they should not be flattened into a single canonical Egyptian “parts of the soul” chart. The useful point is relational: continuation depends on multiple conditions working together.

The pieces have to function together.

## The Imperishable Stars

Circumpolar stars do not set below the horizon from the observer's perspective.

That made them a powerful image of endurance.

To join the Akhu is to enter a company imagined as present, luminous, and difficult to diminish.

The deceased king could be addressed as an imperishable star, but later funerary traditions widened access to effective afterlife beyond kingship.

## Effectiveness Through Relation

One of the most important lines in the Pyramid Texts says Heru becomes akh through Ausar.

That means effectiveness is not purely individual.

Restoring another can transform the restorer.

Community, ritual, memory, and care participate in making the Akh possible.

That is the Ma'at connection worth keeping.

A life becomes effective not by becoming self-sufficient but by getting its parts and relationships into working order.

The question of the Akh is not “Will something of me remain?”

It is “Will what remains still be able to do anything good?”
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Ba', targetId: 'ba'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: "Heru", targetId: 'heru'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'imperishable stars', targetId: 'decans'),
    ],
  ),
  KemeticNode(
    id: 'ren',
    title: 'Ren (Name)',
    glyph: '𓍷',
    body: '''
The Ren is the name as a living address.

That is stronger than saying Egyptians “valued names.”

A name lets a person be called, remembered, offered to, invoked, recorded, and distinguished from everyone else. When the body is absent, the name still gives relationship somewhere to go.

## A Name Can Be Injured

Funerary texts repeatedly ask that the name endure.

That concern becomes brutally clear in the deliberate erasure of names from monuments. Cutting a person's name away was not only historical censorship. Within Kemetic assumptions, it damaged the person's accessibility.

The offering formula names its recipient.

The Ka receives because the gift knows where it is going.

The living can petition an Akh because the person can still be identified.

Memory needs an address.

## The Secret Name

The story of Aset and Ra pushes the concept further.

Ra has a hidden name that contains access to a deeper level of his identity. Aset does not want a label. She wants the name that reaches what ordinary address does not.

The myth treats naming as intimacy and leverage at once.

To know what something is truly called is to stand in a different relationship to it.

## More Than One Name

Kings carried a formal titulary because one designation could not express every dimension of royal identity.

Modern life understands this more than it first appears.

A person can be daughter, father, artist, employer, friend, citizen, author. Each name activates a different relation without creating a different human being.

The Ren's Ma'at is truthful naming.

Names can honor reality or distort it.

Call something what it is.

Preserve the names that deserve to remain reachable.

And remember that what nobody can name becomes much easier to neglect.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Akh', targetId: 'akh'),
      KemeticNodeLink(phrase: "Aset", targetId: 'aset'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'offering formula', targetId: 'offering_formula'),
    ],
  ),
  KemeticNode(
    id: 'ib',
    title: 'Ib (Heart)',
    glyph: '𓄣',
    body: '''
The Ib is the heart as witness.

That is why it is weighed.

In Kemetic thought, the heart is not only the seat of emotion. It is closely tied to thought, intention, memory, character, and moral record. In the Hall of Two Truths, it is the heart—not the person's speech about the heart—that meets the feather of Ma'at.

## “Heart of My Mother”

The Book of Coming Forth by Day addresses the heart directly.

The heart scarab and the spells associated with it reveal an unsettling idea: your own heart can stand apart enough to testify.

You can explain yourself.

The heart carries what was lived.

That difference is the point.

## Heart and Tongue

The Memphite Theology places the heart before the tongue.

Perception is gathered inwardly. The heart conceives. Speech follows.

That makes the heart a creative organ as well as a moral one.

What is repeatedly entertained inwardly becomes easier to say. What is repeatedly said becomes easier to enact. Habit gives the heart shape.

The scale at death is therefore the end of a process that was happening all along.

## The Heart Is Being Made Now

This is where the old Library was strongest and should remain direct.

The heart does not become accountable at the moment of judgment.

It becomes whatever it is through ordinary days.

Small choices matter because they accumulate into character long before anyone gives the accumulation a dramatic name.

The Ib's Ma'at connection is self-honesty.

Not self-condemnation.

Can your inner record and your outer story survive comparison?

A heart in right relation is not a heart without mistakes.

It is one that has not built a life around hiding from what it already knows.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(
        phrase: 'Memphite Theology',
        targetId: 'memphite_theology',
      ),
      KemeticNodeLink(
        phrase: 'Hall of Two Truths',
        targetId: 'declarations_of_innocence',
      ),
      KemeticNodeLink(phrase: "feather of Ma'at", targetId: 'maat'),
      KemeticNodeLink(
        phrase: 'Book of Coming Forth by Day',
        targetId: 'book_of_the_dead',
      ),
    ],
  ),
  KemeticNode(
    id: 'sheut',
    title: 'Sheut (Shadow)',
    glyph: '𓋺',
    body: '''
You cannot stand in light without casting a shadow.

That physical fact gave the Sheut one of the clearest images among the Kemetic aspects of the person.

The shadow belongs to you, follows form, and extends your presence beyond the boundary of the body.

## Presence Has Effects

The older Library makes a useful interpretive move here: the shadow is what your presence does without asking permission.

Other people can experience the atmosphere you create before you understand it yourself.

You may intend warmth and cast pressure.

You may feel ordinary and cast protection.

You may think you are invisible and discover that your absence changed the room.

The literal Kemetic Sheut should not be reduced to modern psychology, but the image gives us a strong way to think about consequence.

## The Shadow Must Also Move

Some funerary compositions ask that the way be opened for both Ba and shadow. That is one attested strand of the tradition, not a single standardized doctrine of the Sheut across every period.

That matters because the person is not imagined as one simple essence leaving a body.

Different aspects need freedom, protection, memory, and relation.

The shadow remains part of the person worth preserving.

## Seeing Your Own Shadow

A Coffin Text passage expresses the desire to see one's shadow.

That is a powerful image because the shadow is easiest for others to see.

The Ma'at lesson here is awareness of effect.

You are not only what you intended.

You are also what your presence actually produces around you.

The goal is not to control every interpretation or become terrified of impact.

It is to become curious enough to look for evidence of the shadow you cast.

Self-knowledge gets deeper when it includes the version of you that exists in other people's light.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ba', targetId: 'ba'),
    ],
  ),
  KemeticNode(
    id: 'imhotep',
    title: 'Imhotep',
    glyph: '𓉴',
    aliases: ['Imhotep'],
    body: '''
The Step Pyramid has been standing for roughly forty-five centuries.

That fact does most of the work.

Imhotep served King Djoser in the Third Dynasty and became associated with one of the decisive changes in Egyptian architecture: royal monumentality translated into large-scale stone. Later tradition remembered him as architect, scribe, healer, and eventually divine figure.

What connects those identities is not fame. It is applied knowledge.

## The Step Pyramid as Proof

Building in stone at that scale required more than ambition. Weight had to be understood. Foundations had to hold. Blocks had to be quarried, transported, shaped, placed, and coordinated across a large workforce.

The monument records thinking that became structure.

That is why Imhotep belongs naturally beside Ptah, whose creative principle begins in conception and becomes form, and Djehuty, whose measure keeps form from drifting away from what was intended.

The Step Pyramid is a useful corrective to romantic ideas about inspiration. Vision matters. So do geometry, logistics, materials, supervision, error correction, and time.

## Why He Endured

Centuries after his death, Imhotep was remembered not only as an official but as a sage and healer. He was depicted as a seated scribe with papyrus across his knees—knowledge made transmissible.

That later reputation tells us as much about cultural memory as it does about the historical man. Kemet came to treat Imhotep as an image of knowledge that works: building, healing, writing, advising.

This is the Ma'at connection worth keeping.

Knowledge earns trust when it can survive contact with reality.

A plan that cannot be built is not complete. A treatment that does not restore is not enough. A teaching no one can use does not become inheritance.

Imhotep's lesson is tangible because the stone is still there: what is conceived well, measured honestly, and executed with discipline has a chance to outlive the person who first imagined it.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ptah', targetId: 'ptah'),
      KemeticNodeLink(phrase: "Djehuty", targetId: 'djehuty'),
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
    ],
  ),
  KemeticNode(
    id: 'sopdet',
    title: 'Sopdet (Sirius)',
    glyph: '𓇼',
    aliases: ['Sopdet', 'Sothis', 'Sirius'],
    body: '''
Sopdet is Sirius at the moment it returns.

That return mattered because Sirius is the brightest star in the night sky and because its heliacal rising—its first visible appearance before sunrise after a period of invisibility—became one of the great annual markers in Kemetic timekeeping.

In the Old Kingdom, the event fell near the season of Nile inundation. Star, river, and year became joined in observation and meaning.

## Seventy Days of Absence

Sirius disappears into the sun's glare for a period before returning to visibility. The exact interval varies with latitude and historical epoch.

The often-cited roughly seventy-day parallel with embalming is a meaningful religious and scholarly association, but it should not be treated as a universal observational constant. Sopdet became associated with Aset, while Sah (Orion) became associated with Ausar.

The sky gave the restoration story a visible annual rhythm.

That does not mean every later astronomical claim made about Sirius should be treated as exact Old Kingdom doctrine. What is secure is that Sopdet was watched carefully and became deeply entangled with calendar, flood, renewal, and royal/funerary symbolism.

## A Fixed Reference

The decanal system depended on repeated stellar observation. Sopdet's rising provided an important annual anchor against which the sequence of other stars and the calendar could be understood.

This is where Djehuty's principle appears in the sky: measurement needs a reference.

A system becomes useful when the observer knows where the count begins.

## The Long Drift

The civil calendar had 365 days without the extra quarter-day of the solar year. That meant it slowly drifted against the seasons and against Sopdet's heliacal rising. Over many centuries the two came back into alignment.

That slow drift is a useful reminder: a calendar can be internally consistent and still move away from the natural event it once marked.

Sopdet's Ma'at is therefore not mystical prediction.

It is reliable return noticed carefully enough to orient action.

A sign becomes meaningful when it is observed long enough to earn trust.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: "Aset", targetId: 'aset'),
      KemeticNodeLink(phrase: 'Sah (Orion)', targetId: 'sah'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: "Djehuty", targetId: 'djehuty'),
    ],
  ),
  KemeticNode(
    id: 'coffin_texts',
    title: 'Coffin Texts',
    glyph: '𓏞',
    body: '''
The Coffin Texts put sacred knowledge close to the body.

Beginning in the Middle Kingdom, funerary spells were written across coffin surfaces for non-royal dead in ways that expanded on older royal traditions.

The coffin became more than a container.

It became equipment.

## A Small Cosmos

Inside a decorated coffin, the dead could be placed between sky and earth, oriented toward the directions of solar movement, surrounded by words meant to protect, transform, and guide.

Some coffins carried the Book of the Two Ways, an early map of routes through the afterlife.

Others carried diagonal star tables—the decans arranged as a practical structure for night-time reckoning.

The person lay inside cosmology.

## Transformation

The Coffin Texts contain spells for taking forms: falcon, lotus, serpent, fire, divine identity.

To modern readers, transformation language can sound theatrical.

Within the ritual tradition it is functional.

A human form has limits. Identification with another sacred form gives the deceased access to capacities needed in a different domain.

The point is not costume.

It is capability.

## From King to Person

The Coffin Texts inherit, adapt, and widen themes from the Pyramid Texts. Later funerary literature carries many of the same concerns onto papyrus.

This is one of the clearest examples in Kemet of knowledge changing medium without losing its central problem.

How does a person continue?

How are they protected?

What words do they need?

How do they move?

What must remain whole?

The Coffin Texts' Ma'at is access to effective knowledge.

Knowledge locked where only a few can reach it may remain prestigious.

Knowledge placed where it is needed can actually protect someone.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: "decans", targetId: 'decans'),
    ],
  ),
  KemeticNode(
    id: 'papyrus_chester_beatty_iv',
    title: 'Papyrus Chester Beatty IV',
    glyph: '𓏞',
    body: '''
Papyrus Chester Beatty IV makes an argument that still feels modern:

a text can outlive a monument because a text can be copied.

Stone is physically durable.

Writing is socially durable when people keep choosing to transmit it.

## The Immortality of Writers

A famous passage remembers earlier sages whose tombs, families, and physical monuments could disappear while their names remained alive through texts still being read.

The logic is deeply Kemetic.

A spoken Ren keeps a person addressable.

A copied work keeps producing occasions for the name to be spoken.

The writer continues through use.

## Copying Is the Technology

One fragile papyrus can be destroyed.

A hundred copies are harder to erase.

That is the advantage of transmission over mere preservation.

The House of Life and scribal schools mattered because they created human chains capable of carrying knowledge from one generation into another medium, another classroom, another hand.

The medium survives because somebody repeats the work.

## Worth Copying

There is also an uncomfortable standard hidden inside the text.

Not everything gets copied.

A writing survives because later people find enough value in it to invest labor in preserving it.

That makes endurance partly editorial.

Generations keep choosing.

This is Papyrus Chester Beatty IV's Ma'at connection: leave something useful enough that another person wants to carry it.

A monument can demand remembrance.

A good text earns rereading.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ren', targetId: 'ren'),
      KemeticNodeLink(phrase: 'House of Life', targetId: 'house_of_life'),
    ],
  ),
  KemeticNode(
    id: 'kemet',
    title: 'Kemet (Black Land)',
    glyph: '𓇾',
    body: '''
Kemet means the Black Land.

The name points to the dark Nile silt that made cultivation possible along a narrow strip surrounded by desert. The civilization named itself for the ground that sustained it.

That tells us something before we reach theology: identity began with place.

## Black Land, Red Land

Kemetic geography was organized through a powerful contrast. Kemet, the Black Land, was the fertile and cultivated Nile valley. Deshret, the Red Land, was the desert beyond it.

The contrast was real before it was symbolic. One zone held fields, settlements, canals, temples, and administration. The other held stone, minerals, routes, horizons, danger, dryness, and forms of life adapted to a harsher environment.

Later sacred language drew on that landscape. Set could be associated with red-land force. Cultivation became an image of order. Boundaries mattered because the line between black soil and red sand was visible in the world itself.

But the contrast should not be flattened into “good land versus evil desert.” The desert also protected the valley, supplied materials, and formed part of Kemet's sacred geography. The issue is relation and placement.

## A Country That Had to Be Re-Made

Every flood covered the land and softened the human lines drawn across it. When the water withdrew, fields and boundaries had to be restored through record and measurement. That made the land itself an annual lesson in Ma'at: order was not permanent simply because it had once been established.

Upper and Lower Kemet added another layer. The narrow southern valley and the broad northern Delta had different landscapes, histories, and connections. Political unification did not erase those differences; kingship had to hold them together as the Two Lands.

A familiar and plausible etymology connects the later Greek and Latin names behind “Egypt” with Hwt-Ka-Ptah, the “House of the Ka of Ptah” at Memphis. The derivation is conventional rather than something that should be presented as mathematically certain. Kemet is what the people called the land itself.

The Black Land is therefore more than a historical name. It is a reminder that civilization is never independent of the conditions beneath it.

The temples, texts, calendars, harvests, and arguments about Ma'at all came from people standing on a very particular ground. If the Library starts to float free of that ground, it has misunderstood its own source.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Set', targetId: 'set'),
      KemeticNodeLink(phrase: 'Ptah', targetId: 'ptah'),
    ],
  ),
  KemeticNode(
    id: 'pyramid_texts',
    title: 'Pyramid Texts',
    glyph: '𓉴𓏞',
    body: '''
The Pyramid Texts are the oldest surviving large body of Kemetic religious literature.

They appear on the interior walls of Old Kingdom royal pyramids beginning with Unas, but the tradition behind them is older than the stone that preserves it.

The walls captured ritual speech that had already been performed, transmitted, and adapted.

## Text Placed Into Architecture

The utterances are not random decoration.

Their placement follows the spaces of the royal tomb: burial chamber, antechamber, corridors, directions, offerings, protection, ascent.

Reading them means entering a ritual environment.

Some texts provision the king.

Some restore and awaken him.

Some protect against dangerous forces.

Some identify him with Ausar.

Some lift him toward Ra and the imperishable stars.

The corpus is less like one “book” than a collection of technologies for continuation.

## “Osiris Unas”

One of the most important moves is identification.

The dead king can be addressed as Ausar joined to his own name.

The formula places the deceased inside a sacred pattern already known to result in restoration.

This is not modern metaphor.

Within the ritual logic, correct naming changes what the person is able to participate in.

## From Royal Walls to Wider Use

The Pyramid Texts did not remain sealed inside pyramids.

Their language and ritual concerns move into Middle Kingdom Coffin Texts and later into the Book of Coming Forth by Day.

That transmission matters as much as the age of the originals.

A tradition survives because people keep translating its function into forms the next period can actually use.

## Why They Matter Here

Nearly every major concept in the Library touches the Pyramid Texts somewhere: Ka, Ba, Akh, Heru, Ausar, Djehuty, offering, ascent, protection, stellar afterlife, Ma'at.

The text is not valuable because it is old.

It is valuable because it preserves an early map of how Kemet understood continuity: prepare, name, feed, protect, restore, orient, and speak correctly.

The oldest surviving words already assume that survival after rupture requires work.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: "Heru", targetId: 'heru'),
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Ba', targetId: 'ba'),
      KemeticNodeLink(phrase: 'Akh', targetId: 'akh'),
      KemeticNodeLink(phrase: 'Coffin Texts', targetId: 'coffin_texts'),
      KemeticNodeLink(
        phrase: 'Book of Coming Forth by Day',
        targetId: 'book_of_the_dead',
      ),
      KemeticNodeLink(phrase: 'imperishable stars', targetId: 'decans'),
    ],
  ),
  KemeticNode(
    id: 'hathor',
    title: 'Hathor',
    glyph: '𓃒',
    body: '''
Hathor refuses to fit into one mood.

She is sky, cow, mother, music, sexuality, joy, intoxication, welcome, the western horizon, and the Eye of Ra. Those roles are not random additions to one goddess. They circle a common problem: how powerful life becomes livable.

## Joy Is Not Outside the Sacred

Hathor's sistrum, music, beer, dance, beauty, and festival make her easy to flatten into a goddess of pleasure.

That misses the seriousness of the role.

A society built only around restraint would be incomplete. Delight restores people too. Music can synchronize bodies. Celebration can renew relationship. Beauty can make order felt rather than merely obeyed.

Hathor gives joy sacred standing.

## The Eye Comes Home

She is also connected with the Eye of Ra—the solar force that can become destructive when distant or enraged.

In stories of the wandering Eye, dangerous heat has to be brought back into relation through welcome, music, drink, and reunion.

Sekhmet and Hathor can represent different conditions of that same solar power: burning force and returning delight.

The point is not that rage is secretly happiness.

It is that a force that cannot return from its extreme becomes dangerous even when it began with purpose.

## Lady of the West

Hathor receives the dead at the western horizon, where the sun enters the hidden region.

That role completes the pattern.

She is not only joy at the beginning of life. She is welcome at a threshold people fear.

Her Ma'at is the knowledge that right order should not produce a world nobody wants to live in.

A stable life needs pleasure, beauty, reception, and warmth—not as rewards after the serious work is done, but as part of what makes the serious work worth sustaining.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Sekhmet', targetId: 'sekhmet'),
      KemeticNodeLink(phrase: 'Eye of Ra', targetId: 'eye_of_ra'),
    ],
  ),
  KemeticNode(
    id: 'dendera',
    title: 'Dendera',
    glyph: '𓉗',
    body: '''
Dendera puts the sky on the ceiling.

The surviving temple of Hathor is largely Greco-Roman in date, but it stands within a much older sacred tradition at the site. Its astronomical ceilings, decanal imagery, ritual texts, crypts, and rooftop spaces show a temple designed to coordinate architecture, time, divine presence, and festival.

## A Temple That Orients

The astronomical ceilings are not a modern planetarium, but they are more than decoration.

Stars, decans, planets, and constellations are organized across stone surfaces so the temple's ritual life is placed beneath a visible cosmos.

The famous circular zodiac combines older Kemetic astronomical material with zodiacal forms that entered Egypt through the Hellenistic world. That mixture is valuable because it shows continuity without pretending continuity means cultural isolation.

Traditions absorb.

The question is whether they remain intelligible while doing so.

## Hathor and the Return of the Eye

Dendera's identity is inseparable from Hathor.

Music, sistrums, festival, procession, sacred drink, and the return of the Eye of Ra belong to a ritual world where joy can do serious religious work.

The Eye that has gone distant or become dangerous must be brought back into relation.

At Dendera, welcome is not passive sweetness. It is a technology of return.

## The Roof and the New Year

Ritual movement toward the roof brought divine image and solar light into relation at moments tied to renewal.

That gives the architecture a simple lesson: sacred meaning is often produced by timing plus place plus action.

The same statue in the same building on a different day does not necessarily make the same event.

Dendera's Ma'at is choreography.

Order is not only what a thing is.

It is where it is, when it is there, and what relationship becomes possible because all three align.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Hathor', targetId: 'hathor'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Eye of Ra', targetId: 'eye_of_ra'),
      KemeticNodeLink(phrase: "decans", targetId: 'decans'),
    ],
  ),
  KemeticNode(
    id: 'sah',
    title: 'Sah (Orion)',
    glyph: '𓇼𓇼𓇼',
    aliases: ['Orion', 'Sah'],
    body: '''
Sah is conventionally identified with Orion in the Kemetic sky. That identification is strong, but the ancient figure should not be forced star-for-star into the modern constellation boundaries and line drawing.

Sah became closely associated with Ausar (Osiris), while Sopdet (Sirius) was associated with Aset. Their movements gave funerary and renewal imagery a stellar scale: death and restoration were not only told in story; they could be contemplated in the night sky.

## The Striding One

Orion is one of the easiest large constellations to recognize. Its pattern appears, moves across the night, disappears seasonally, and returns.

That rhythm made Sah a natural companion to Ausar.

The Pyramid Texts connect the ascending king with Orion and Sopdet, placing royal afterlife within a sky already structured by recognizable divine forms.

The dead king does not simply “go upward.”

He enters a known celestial order.

## Return Without Permanence

Sah is not one of the circumpolar stars that never set.

That difference matters.

The imperishable stars model continuous presence. Sah models recurring presence: disappearance followed by return.

Ausar fits that rhythm exactly. His sacred power is not that nothing happens to him. It is that what happens does not become final.

## What the Sky Teaches

The older Library copy connects Sah with pyramid alignment more confidently than the evidence allows. Monument orientation to the sky is real and important, but specific claims about Orion-based planning should be stated carefully.

The stronger point does not need speculation.

People watched this pattern for generations and recognized it.

That is enough.

Sah's Ma'at connection is the discipline of recognizing stability inside movement.

A thing can change position, disappear for a season, and still remain itself because the relations that define it hold.

Not all continuity looks like staying visible.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar (Osiris)", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Sopdet', targetId: 'sopdet'),
      KemeticNodeLink(phrase: 'Aset', targetId: 'aset'),
      KemeticNodeLink(phrase: 'imperishable stars', targetId: 'decans'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
    ],
  ),
  KemeticNode(
    id: 'abydos',
    title: 'Abydos',
    glyph: '𓊖',
    body: '''
Abydos became one of the great places of sacred memory in Kemet.

Its importance grew from several histories layered together: early royal burials, the later identification of a First Dynasty tomb with Ausar (Osiris), pilgrimage, annual mysteries, private stelae, and royal ancestor lists.

People went there because place could make memory more powerful.

## Where Ausar Was Present

By the Middle Kingdom, Abydos was treated as the burial place of Ausar.

That transformed the landscape.

The sacred story of death, mourning, restoration, and return was not only narrated there. It was enacted through processions and festival.

The mysteries of Ausar made restoration something people participated in.

## Thousands of Names

Private individuals erected stelae at Abydos so their names and identities could remain present near the sacred cycle even when they could not be buried there.

That practice says something important about the Ren.

Presence can be extended through inscription.

A name placed in the right context participates in a community of memory larger than the body that carried it.

## The King List

The temple of Seti I preserves a famous sequence of earlier kings.

The Abydos King List is historical evidence, but it is also selective sacred memory. Some rulers are omitted. The list is not a neutral database.

That makes it more interesting.

Every tradition decides what lineage it wants to stand inside.

Abydos makes that decision visible.

Its Ma'at lesson is not “remember everything.”

It is to understand that memory is structured by place, ritual, selection, and repetition.

What a culture keeps naming becomes part of what the future believes it inherited.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar (Osiris)", targetId: 'ausar'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ren', targetId: 'ren'),
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
    ],
  ),
  KemeticNode(
    id: 'decans',
    title: 'Decans',
    glyph: '𓇼𓇼𓇼',
    body: '''
The decans turned the night sky into a clock.

They were star groups observed in sequence across the year, especially known from Middle Kingdom diagonal star tables and later astronomical ceilings. Their risings helped organize night-time reckoning and linked ten-day periods, months, seasons, and stellar observation into one system.

## A Clock Made of Stars

On coffin lids, decanal tables arrange star names in diagonal patterns so that the observer can relate a ten-day period to the stars marking successive hours of night.

The table is not decoration.

It is information.

A person trained to read it could locate themselves in time by looking at the sky.

That is one reason the same material belongs inside funerary equipment. The afterlife was imagined as a passage with sequence, gates, hours, and orientation. A star clock above the dead was useful because the night itself had structure.

## Ten Days at a Time

The civil year contained twelve thirty-day months plus five epagomenal days. Three ten-day periods fit inside each month.

This is where hꜣw gets one of its most important differences from the seven-day week.

A decan is long enough to feel like a movement rather than a single day, but short enough to notice change before a month is over.

The ancient system was astronomical first. hꜣw's use of each decan as a reflective human theme is a modern interpretive layer.

Keeping that distinction clear makes the product stronger, not weaker.

## Why the Decans Matter Here

The deepest value of the decans is orientation.

They teach that time can be read through recurring relationships rather than only counted by numbers.

The night changes. The stars change position. The observer learns what those changes mean by watching the sequence long enough.

That is the Ma'at connection: rhythm becomes guidance when attention is disciplined enough to recognize where in the pattern you are.
''',
    linkMap: [],
  ),
  KemeticNode(
    id: 'duat',
    title: 'Duat',
    glyph: '𓇽',
    aliases: ['Underworld', 'Hidden Region', 'Netherworld'],
    body: '''
The Duat is not simply “the underworld.”

It is the hidden region of passage.

Ra enters it every night. The dead enter it after burial. Ausar rules within it. Gates, beings, waters, enemies, names, and transformations give it structure.

Darkness is only the surface.

## The Night Has Architecture

The Amduat maps the solar journey through twelve hours.

That alone tells us how the Duat should be imagined: not as vague shadow, but as ordered hiddenness.

Things happen in sequence.

Ra does not jump from sunset to sunrise. The passage has stages, and each stage asks something different of the traveler.

The sixth hour brings deep renewal. Later comes confrontation with Apepi. Dawn is produced through the whole route.

## The Dead Need Equipment

The Book of Coming Forth by Day and related funerary traditions give the deceased names, formulas, identifications, protections, and ways of moving.

A gate is not just a barrier.

It is a threshold whose conditions must be understood.

The dead need the ba free to travel, the ren preserved, the heart able to stand judgment, the body maintained, and the whole person kept from scattering.

This makes the Duat less like punishment and more like examination under hidden conditions.

## Hidden Work

The Duat's Ma'at connection may be the most useful part of it.

Not all important work is visible while it is happening.

Seeds develop underground. Grief changes a person before anyone else can see the change. A decision may be forming long before it becomes speech. Recovery can look like nothing from the outside.

The Duat gives sacred language to that interval.

But hiddenness is not an excuse for disorder.

The night still has gates.

The lesson is not “trust the darkness.”

It is: give unseen processes enough structure that what eventually emerges has actually been transformed.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Apepi', targetId: 'serpent'),
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Amduat', targetId: 'amduat'),
      KemeticNodeLink(
        phrase: 'Book of Coming Forth by Day',
        targetId: 'book_of_the_dead',
      ),
      KemeticNodeLink(phrase: 'ba', targetId: 'ba'),
      KemeticNodeLink(phrase: 'ren', targetId: 'ren'),
    ],
  ),
  KemeticNode(
    id: 'renenutet',
    title: 'Renenutet',
    glyph: '𓆤',
    aliases: ['Harvest Serpent', 'Nourishing Cobra', 'Lady of the Granary'],
    body: '''
Renenutet appears where growth becomes security.

She is associated with nourishment, nursing, harvest, granaries, and destiny. Her cobra form adds another dimension: what feeds the future also has to be guarded.

A harvest is not safe merely because it exists.

## The Granary Is Stored Time

Grain in a granary is past flood, sunlight, labor, water, seed, cutting, and threshing converted into future possibility.

Households depend on it.

Temples depend on it.

Offerings depend on it.

The next planting depends on it.

That is why storage is not passive.

The granary is a decision about how much of the present will still be available later.

## Nursing and Raising

Renenutet's association with nursing ties the field to childhood.

Both growth processes begin in dependence.

A child has to be fed before character, skill, or destiny can unfold. A crop has to be tended before it can become provision.

That makes nourishment morally important without making it sentimental.

What is not fed cannot become what it had the capacity to become.

## Renenutet and Shai

Shai names the allotted portion.

Renenutet belongs to the conditions that make the portion livable.

The association between Renenutet and Shai is real, but it develops in specific contexts and should not be treated as equally central in every period.

The pairing is useful because it keeps destiny material.

Fate does not float above food, shelter, care, and protection.

What a life can become is shaped partly by what it receives early enough to use.

Renenutet's Ma'at is abundance that protects a future.

Feed what should grow.

Guard what has been gathered.

And never celebrate a full storehouse so completely that you eat the seed.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Shai', targetId: 'shai'),
    ],
  ),
  KemeticNode(
    id: 'haw',
    title: 'ḥꜣw',
    glyph: '𓇉𓄿𓅱𓏛𓏥',
    aliases: [
      'Haw',
      'HAw',
      'ḥꜣw',
      'Ḥꜣw',
      'Increase',
      'Surplus',
      'Abundance',
      'Excess',
      'Wealth',
      'haw',
    ],
    body: '''
ḥꜣw is increase.

It can mean abundance, surplus, what extends beyond the baseline.

That is why it became the right name for this app.

The word carries a tension hꜣw should never lose: more can be blessing or disorder depending on what happens after more arrives.

## Surplus Creates a Question

Enough is relatively simple.

Excess creates choices.

A granary holding more than today's need can preserve the future, feed others, support ritual, finance work, or become an instrument of control.

Authority beyond what one task requires can protect a system or become abuse.

Speech beyond what is known can become insight or become noise.

The moral problem begins in the gap between what was required and what became available.

## Increase in Right Relation

The older Library connects ḥꜣw with administrative surplus, offering, Nile abundance, wisdom texts, and warnings against excess.

That range is exactly the point.

The same increase can be read differently depending on where it goes.

Surplus that remains inside the circuit that produced it becomes continuity.

Surplus sealed away from relation can become Isfet while still looking like success.

## Why the App Is Called ḥꜣw

The product should make this meaning personal.

A good calendar is not only trying to help someone fit more into a day.

More tasks can be disorder.

More money can be disorder.

More attention can become fragmentation.

More opportunity can become a life with no center.

The question is not “How do I increase?”

It is “What is this increase for?”

That is ḥꜣw's Ma'at.

Build abundance that strengthens the life it came from.

If the increase makes the whole less livable, it was never the kind of abundance worth organizing around.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'offering', targetId: 'offering_formula'),
    ],
  ),
  KemeticNode(
    id: 'house_of_life',
    title: 'House of Life',
    glyph: '𓉐𓋹',
    aliases: ['Per Ankh', 'House of Living Knowledge', 'Temple Scriptorium'],
    body: '''
The House of Life was where knowledge was kept alive by being used.

The Per Ankh belonged to the temple world. Clear evidence for the institution is strongest from the Middle Kingdom onward, and its exact functions varied by place and period. It is associated with scribal work, copying, ritual texts, medicine, sacred literature, and specialized knowledge, but it should not be imagined as one standardized library-laboratory-school operating unchanged for three thousand years.

Its importance is easier to understand if we stop thinking of writing as storage.

In Kemet, writing could act.

## Knowledge Had to Remain Usable

A ritual text mattered because someone could perform it. A calendar mattered because someone could keep time with it. A medical text mattered because someone could apply what it preserved. A funerary composition mattered because its words could equip the dead.

Papyrus Chester Beatty IV makes the scribal argument beautifully: stone monuments can decay, but a text that continues to be copied keeps its author's name alive.

That is the House of Life in one image.

Memory becomes portable.

## Accuracy Is Part of the Sacred Work

Djehuty stands behind scribal practice because preservation without accuracy can preserve the wrong thing.

A copied error can alter a name, a quantity, a ritual sequence, or a formula. The problem is not that scribes had to be perfect. The problem is that a culture dependent on transmission had to treat copying as responsibility.

Specialized knowledge becomes institutional when it can move through generations without becoming private possession or empty repetition.

The House of Life also explains why the Library itself should not feel like a warehouse of information.

A dead text is one nobody can use.

The point of preservation is renewed action: read it, understand it, test it, teach it, apply it, pass it on.

That is Ma'at in the domain of knowledge. Continuity is not keeping every word forever. It is keeping what matters accurate enough to keep doing its work.
''',
    linkMap: [
      KemeticNodeLink(
        phrase: 'Papyrus Chester Beatty IV',
        targetId: 'papyrus_chester_beatty_iv',
      ),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
    ],
  ),
  KemeticNode(
    id: 'instruction_ptahhotep',
    title: 'Instruction of Ptahhotep',
    glyph: '𓏞',
    aliases: ['Maxims of Ptahhotep', 'Sebait of Ptahhotep'],
    body: '''
The Instruction of Ptahhotep is one of the oldest surviving wisdom traditions in the world, and much of its power comes from how ordinary its problems are.

Listening.

Greed.

Speech.

Household responsibility.

Authority.

Age.

Reputation.

The text does not need spectacular villains because most damage happens in daily relationships.

## What He Saw

Ptahhotep's wisdom repeatedly returns to restraint.

Listen fully before answering.

Do not let rank make you deaf.

Do not let appetite convince you that taking more is intelligence.

Govern speech.

Do not repeat what you do not know.

Treat the household as part of moral life, not a private zone where public virtue no longer applies.

What makes the Instruction useful is that it understands consequence.

Bad habits do not remain internal.

They alter trust, family, work, judgment, and the people who learn by watching.

## Example Outlives Advice

Near the heart of the tradition is the idea that conduct teaches.

Children inherit more than instructions.

They inherit patterns.

That is where Ptahhotep's Ma'at becomes especially practical.

If you want to transmit a value, build it into behavior someone can observe.

A lecture about fairness cannot compete forever with a household organized around favoritism.

A teaching about restraint cannot survive a life organized around appetite.

The Instruction has endured because it refuses that split.

Wisdom is not what you know how to say.

It is what another person learns from watching how you live.
''',
    linkMap: [KemeticNodeLink(phrase: "Ma'at", targetId: 'maat')],
  ),
  KemeticNode(
    id: 'sekhmet',
    title: 'Sekhmet',
    glyph: '𓃭',
    aliases: ['The Powerful One', 'Eye of Ra', 'Lioness Fire'],
    body: '''
Sekhmet is what happens when order needs teeth.

She is lioness heat: plague and protection, royal terror and healing, destructive force and the power to burn corruption out of the body.

The contradiction is the point.

Some threats cannot be soothed away.

## The Eye Sent Forth

In the Book of the Heavenly Cow, Ra sends his Eye against rebellion. In the core narrative, Hathor is the goddess explicitly named in that destructive role. Later and broader Egyptian tradition also connects Sekhmet to the dangerous, punitive Eye of Ra, so the story belongs to the larger Eye tradition rather than serving as simple exclusive proof that “Sekhmet did this.”

The story then turns.

The destruction has to stop.

Red beer pacifies the raging Eye, and consuming force is returned from bloodshed toward another condition.

Whether read ritually, mythically, or psychologically, the warning is unmistakable: justified force can become unjustified by continuing past its measure.

## Healing and Harm

Sekhmet's association with healing makes the same point from another angle.

Heat can kill. Heat can purge. A blade can wound or remove what is killing the body. Medicine often works through controlled interventions that would be harmful at the wrong dose or in the wrong place.

Power becomes healing through precision.

## The Necessary Limit

The Library should not soften Sekhmet into “healthy anger.”

She is more dangerous than that.

Her value is that Kemetic thought made room for terrifying force without worshiping terror.

A boundary sometimes needs defense. A disease sometimes needs aggressive treatment. A violent threat sometimes requires resistance.

But Ma'at still governs the response.

Use enough force to protect what matters.

Do not let the force discover an appetite of its own.

Sekhmet's lesson is not to fear power.

It is to know how to send it—and how to call it back.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Eye of Ra', targetId: 'eye_of_ra'),
      KemeticNodeLink(
        phrase: 'Book of the Heavenly Cow',
        targetId: 'eye_of_ra',
      ),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Hathor', targetId: 'hathor'),
    ],
  ),
  KemeticNode(
    id: 'rekh_wer',
    title: 'Rekh-Wer',
    glyph: '𓁹𓏞',
    aliases: ['Great Burning', 'Rḫ Wr', 'Rekh Wer'],
    body: '''
Rekh-Wer is a calendar name before it is a philosophy.

In Egyptological convention, Rḫ Wr is usually rendered “Great Burning,” paired with Rḫ Nḏs, “Little Burning.” It should not be translated as “Great Knowing.” The temptation comes from treating rḫ as the verb “to know” outside the calendrical expression, but that is not the historical footing this month-name gives us.

That correction does not make the name less interesting.

It makes the interpretation cleaner.

## A Name Inside the Calendar

Rekh-Wer belongs first to the Egyptian calendrical and feast tradition. “Great Burning” and “Little Burning” form a named pair, but those names should not be treated as a modern weather report pinned to fixed dates.

The civil calendar was 365 days and drifted against the natural solar year. Over long periods, a named civil month moved through different parts of the natural seasons.

So the historical foundation is the name and its place in the calendar—not a claim that every Rekh-Wer in every period was literally the same meteorological moment.

## What hꜣw Can Carry From It

Within hꜣw's idealized Peret arc, Great Burning can still become a strong Ma'at reflection.

Heat tests form.

What has grown must now show whether it can hold under pressure. Methods that looked convincing in easy conditions have to survive fatigue, resistance, and repetition. Knowledge belongs here as a human application, not as the word's etymology: what you know becomes meaningful when pressure reveals whether it can guide action.

That distinction matters.

The ancient name gives us the fire.

The reflective layer asks what the fire reveals.

Under Ma'at, pressure should refine what is true without becoming cruelty for its own sake. When intensity loses measure and begins consuming what it was meant to strengthen, the burning has crossed into Isfet.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Peret', targetId: 'peret'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'set',
    title: 'Set',
    glyph: '𓃩',
    aliases: ['Seth', 'Sutekh', 'Adversarial Force', 'Red Land Power'],
    body: '''
Set is not chaos in animal form.

He is force that becomes dangerous when it refuses its place.

Storm, desert, conflict, violence, boundary, foreignness, protection, rivalry—Set carries powers that are genuinely necessary and genuinely dangerous. The mistake is treating strength itself as the problem.

The problem is strength becoming its own law.

## Force at the Boundary

The Red Land could kill, but it also protected the Nile valley and supplied routes, stone, and resources. A boundary needs force if it is going to remain a boundary.

Set can therefore appear as defender as well as adversary. He is not the same as Apepi, whose role is to obstruct the solar cycle itself.

That distinction matters.

Kemetic thought can place dangerous power inside order without pretending the danger has disappeared.

## The Crime Against Ausar

Set's defining violation is not simply that he is strong.

He uses force against rightful relation.

Ausar is killed and scattered. Succession is broken. The center is attacked by the very kind of power that should have defended the whole.

The Contendings with Heru then turns that wound into a political question: does strength create legitimacy simply because it can seize?

The answer is no.

## Pressure Reveals Structure

Set also functions as trial.

A claim that has never been challenged may be weak without knowing it. A boundary that has never been tested may be ceremonial. Pressure can reveal what is actually stable.

But not every pressure is righteous simply because it teaches a lesson.

This is the Ma'at problem of Set: use force without worshiping it.

Some moments require confrontation. Some threats cannot be reasoned away. But power should remain answerable to the thing it is meant to protect.

The moment strength starts confusing capability with permission, Set has moved out of place.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: "Heru", targetId: 'heru'),
      KemeticNodeLink(phrase: 'Apepi', targetId: 'serpent'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
    ],
  ),
  KemeticNode(
    id: 'esna_temple',
    title: 'Esna Temple',
    glyph: '𓉗',
    aliases: ['Temple of Khnum at Esna', 'House of Khnum', 'Esna'],
    body: '''
Esna Temple makes creation architectural.

Its surviving pronaos belongs to the Roman period, but its inscriptions preserve a dense local theology centered on Khnum, creation, ritual time, divine speech, and the ordered relationship between temple and cosmos.

Late stone can still carry old ideas.

## House of Khnum

Khnum shapes life on the potter's wheel.

At Esna, that forming principle extends outward into the temple itself. Stone is shaped into columns, ceilings, inscriptions, processional routes, and sanctuary. The building becomes a controlled environment in which form, speech, timing, and divine presence meet.

That is different from treating a temple as a monument to belief.

The temple is built to do something.

## The Ceiling as Cosmos

Astronomical and calendrical imagery places ritual underneath ordered time.

A festival needs a date. An offering needs a recipient. A recitation needs its correct setting. The temple's sacred life depends on distinctions being maintained.

This is where Djehuty and Khnum meet naturally: measure and formation.

## A Living Tradition

Esna's surviving inscriptions are comparatively late, which makes them especially useful.

They show that Kemetic religion did not survive by freezing one Old Kingdom form and refusing change. Older patterns were recopied, elaborated, combined, and re-expressed in later conditions.

That is the House of Life principle translated into stone.

A living tradition preserves function even while surfaces change.

Esna's Ma'at is therefore less about architectural perfection than about coherence.

Stone, word, time, body, and rite all have to support one another.

A temple becomes dead when those relationships stop working, even if the walls are still standing.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Khnum', targetId: 'khnum'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
      KemeticNodeLink(phrase: 'House of Life', targetId: 'house_of_life'),
    ],
  ),
  KemeticNode(
    id: 'shai',
    title: 'Shai',
    glyph: '𓀭',
    aliases: ['Destiny', 'Fate', 'Allotted Portion'],
    body: '''
Shai is the portion a life receives before choice has had its say.

That portion can include body, family, timing, inheritance, danger, opportunity, health, place, and the conditions already moving when a person enters the world.

Shai is often translated as fate or destiny, but neither word should erase responsibility.

## The Portion Given

A farmer cannot command the flood.

A child does not choose the household into which they are born.

A ruler inherits a land already carrying strengths, debts, wounds, and obligations.

That is Shai: the field given.

The Tale of the Doomed Prince explores the problem dramatically. A fate is announced at birth, and attempts to control the future through fear only produce another kind of confinement.

The story survives incompletely, which means it does not hand us a neat answer.

Maybe that is fitting.

## Fate and Conduct

Kemetic wisdom literature continues to insist on conduct even in a world where destiny exists.

Instruction of Amenemope still asks for restraint, fairness, honesty, and protection of the vulnerable. The Hall of Two Truths still weighs the heart.

That would make little sense if Shai excused behavior.

The person's answer still matters.

## Renenutet and Shai

Shai is often paired in the Library with Renenutet, the nourishing force associated with field, harvest, birth, and provision.

The relationship is useful.

A destiny has to be fed.

Potential without nourishment can become burden. A child, field, talent, relationship, or responsibility may all arrive as “portion,” but what they become depends partly on what receives and sustains them.

Shai's Ma'at is neither total control nor helpless surrender.

Know what was given.

Know what you cannot change.

Then become responsible for the quality of your answer.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(
        phrase: 'Instruction of Amenemope',
        targetId: 'instruction_amenemope',
      ),
      KemeticNodeLink(phrase: 'Renenutet', targetId: 'renenutet'),
      KemeticNodeLink(
        phrase: 'Hall of Two Truths',
        targetId: 'declarations_of_innocence',
      ),
    ],
  ),
  KemeticNode(
    id: 'offering_formula',
    title: 'Offering Formula',
    glyph: '𓊵',
    aliases: ['Hotep-di-nesu', 'Offering Prayer', 'Bread and Beer Formula'],
    body: '''
The offering formula turns provision into relationship.

Bread, beer, cattle, fowl, linen, incense, oil, cool water, and “every good and pure thing” are not simply listed. They are directed.

A recipient is named.

The Ka is addressed.

The living perform an obligation that allows care to cross the boundary of death.

## Food Needs an Address

The formula commonly called ḥtp-dỉ-nsw—“an offering which the king gives”—places gift, divine authority, named recipient, and provision into a recognizable structure.

The words matter because the offering is not anonymous.

The Ren identifies.

The Ka receives.

The material gift and the spoken formula work together.

## Bread and Beer

Bread and beer are ordinary enough to reveal the point.

The sacred economy rests on the same grain that feeds households.

Flood, field, harvest, milling, brewing, labor, storage, and ritual all meet on the offering table.

That is why offering is not an escape from economic life.

It is economic life made relational.

Someone had to grow what was given.

## Voice Offering

Kemetic practice also allowed spoken offering to matter when physical provision was limited or absent.

The voice does not become food in a crude material sense.

Speech activates remembrance, address, and the ritual form through which provision is made present.

That is why tomb inscriptions and false doors matter so much.

Stone holds the words until a mouth returns.

## What Offering Teaches

The offering formula's Ma'at is circulation.

Life is received, transformed, and returned.

A gift that never leaves the hand is still possession.

Provision becomes offering when it reaches the relationship that gives the provision meaning.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ka", targetId: 'ka'),
      KemeticNodeLink(phrase: "Ren", targetId: 'ren'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: "false doors", targetId: 'false_door'),
      KemeticNodeLink(phrase: 'offering table', targetId: 'hotep'),
      KemeticNodeLink(phrase: 'tomb', targetId: 'false_door'),
    ],
  ),
  KemeticNode(
    id: 'shemu',
    title: 'Shemu',
    glyph: '𓇓',
    aliases: ['Harvest Season', 'Dry Season', 'Season of Gathering'],
    body: '''
Shemu is conventionally rendered the harvest or dry season, and hꜣw uses it as the gathering phase of the agricultural arc.

Historically, the 365-day civil calendar drifted relative to the natural seasons, and reconstructions of earlier seasonal cycles can place harvest toward the end of Peret with Shemu leaning more toward low water and the post-harvest condition. So the arc here is intentional and idealized, not a claim that one fixed civil date always matched one fixed agricultural moment.

Within that frame, what Akhet prepared and Peret raised now has to answer in grain.

The field is cut, gathered, threshed, counted, stored, offered, distributed, and preserved.

Harvest is abundance.

It is also evidence.

## The Field Gives an Answer

A crop reflects many earlier conditions at once: flood, seed, timing, labor, care, weather, pests, and chance.

That makes Shemu a season of consequence.

Not punishment.

Result.

The field reveals what the cycle produced.

## Gathering Is Not the End

Grain left in the field cannot sustain the future.

It has to be moved into human systems.

Granaries hold food, seed, wages, offerings, and protection against scarcity.

Djehuty enters through measure because the harvest has to be counted honestly.

A full field can still become Isfet through theft, bad record, hoarding, waste, or distribution that starves the people who produced it.

## Seed for Return

The most important part of harvest may be what is not consumed.

Seed has to remain.

That turns Shemu away from a simple celebration of plenty.

A good harvest serves the present without devouring the next season.

That is its Ma'at connection.

Success is not only what you produced.

It is whether the result can be gathered, shared, stored, and used without destroying the conditions that made success possible.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Akhet', targetId: 'akhet'),
      KemeticNodeLink(phrase: 'Peret', targetId: 'peret'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'amduat',
    title: 'Amduat',
    glyph: '𓇽',
    aliases: [
      'What Is in the Duat',
      'Book of the Hidden Chamber',
      'Night Journey of Ra',
    ],
    body: '''
The Amduat is a map of what happens after sunset.

Its name means “What Is in the Duat,” and that directness matters. The text does not treat the hidden world as unknowable fog. It gives it hours, regions, beings, gates, threats, and sequence.

The invisible is organized.

## Twelve Hours

Ra's night journey is divided into twelve stages.

Each hour has its own environment and work. The bark moves through waters, caverns, fields, divine assemblies, and danger. Beings receive light. Enemies are restrained. Renewal is prepared.

Dawn becomes the result of sequence rather than an automatic switch.

This is why the Amduat matters beyond funerary literature.

It imagines transformation as staged.

## The Hidden Center

The sixth hour is the night at its deepest.

Here the solar power meets the regenerative presence associated with Ausar. Renewal happens before the sun is visible again.

Khepri's emergence at dawn therefore has a history.

The new form is produced in the place nobody watching the eastern horizon can see.

## Obstruction

After renewal comes resistance.

Apepi represents the force that tries to stop the bark and break continuity. The answer is not philosophical acceptance. The obstruction has to be bound, cut, defeated, and passed.

That gives the Amduat a sharp Ma'at lesson.

Not every difficulty is a sign to stop.

Some resistance is part of the passage. Some resistance is trying to end the passage.

Wisdom is knowing which is which.

The Amduat is ultimately a text about moving through darkness without surrendering sequence.

When you cannot see the destination yet, know what hour you are in.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Khepri', targetId: 'khepri'),
      KemeticNodeLink(phrase: 'Apepi', targetId: 'serpent'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'khepri',
    title: 'Khepri',
    glyph: '𓆣',
    aliases: ['Scarab', 'Becoming', 'Morning Sun', 'Dawn Form of Ra'],
    body: '''
Khepri is the moment when becoming becomes visible.

The scarab gave Kemetic imagination a living image for that process. It rolls a rounded ball across the ground, disappears into or works with buried material, and beetles can later appear from what had been hidden. Ancient observers did not need modern entomology for that behavior to suggest self-generation and return; the image should not be read as evidence that they understood scarab reproductive biology in modern terms.

Khepri became the dawn form of Ra: the solar power coming into being again.

## Becoming Happens Before Appearance

The most useful part of Khepri is timing.

Dawn looks sudden. It is not. The sun did not begin existing at the horizon. The night journey came first.

The same is true of many transformations that appear abrupt from the outside. A skill looks effortless after long practice. A decision becomes obvious after months of confusion. A seed appears after hidden development. A restored life often looks “new” only because no one saw the work being done in darkness.

The Duat gives that hidden phase sacred structure.

Khepri is what emerges when that phase has done enough.

## Becoming Is Not Escape

Khepri should not be read as endless reinvention.

Becoming does not mean rejecting everything that came before. The dawn sun is still Ra. The new form carries continuity through change.

That is its Ma'at connection.

Transformation is right when it makes a thing more capable of fulfilling what it is here to do, not when change itself becomes the goal.

The scarab does not perform novelty.

It works with what is in front of it until another form becomes possible.

Khepri asks a useful question at any threshold: what is actually ready to emerge now—and what still needs more time in the dark?
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'hotep',
    title: 'Hotep',
    glyph: '𓊵',
    aliases: ['Peace', 'Offering', 'Satisfaction', 'Rest'],
    body: '''
Hotep is often translated as peace.

That is true, but too thin.

The word also carries offering, satisfaction, rest, and the condition that follows when what is due has been placed where it belongs.

Peace is not the absence of movement here.

It is settlement after right placement.

## The Offering Is the Image

The hotep sign is an offering mat with bread.

That tells us something important about the concept.

Satisfaction is not imagined as a mood appearing from nowhere. Something has been given.

A need has been met.

A relationship has been acknowledged.

The body can rest because the obligation is no longer hanging open.

## Hotep-di-nesu

The familiar offering formula begins from this world of giving and satisfaction.

Provision moves through recognized order toward a named recipient.

The result is not simply food.

It is relation settled enough for the Ka to be sustained.

## False Peace

The older Library is right to keep one warning.

Not everything quiet is hotep.

Silence can hide unresolved harm. Avoidance can look peaceful. A person can stop arguing while resentment remains fully alive.

Hotep is deeper than the cessation of conflict.

The conditions themselves have to be brought into enough right relation that rest becomes honest.

That is its Ma'at connection.

Peace is not achieved by making the problem stop making noise.

Peace arrives when enough has been set right that the system no longer has to keep signaling distress.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ka", targetId: 'ka'),
      KemeticNodeLink(phrase: 'Hotep-di-nesu', targetId: 'offering_formula'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'instruction_amenemope',
    title: 'Instruction of Amenemope',
    glyph: '𓏞',
    aliases: ['Amenemope', 'Teaching of Amenemope', 'Wisdom of Amenemope'],
    body: '''
The Instruction of Amenemope admires the quiet person.

Not the timid person.

The person who is difficult to pull out of measure.

That distinction gives the text much of its character.

## Quiet and Heated

Amenemope contrasts controlled conduct with the “heated” person: reactive, loud, unstable, quick to turn pressure into harm.

The quiet person is not praised because silence is always virtuous.

Quietness represents inner regulation.

The person can wait long enough to see what the moment actually requires.

## Do Not Move the Boundary

One of the Instruction's recurring concerns is exploitation.

Do not move a field boundary to steal land.

Do not take advantage of the poor because they lack power.

Do not build wealth from false measure.

The advice is practical because injustice often enters through small administrative acts long before it becomes dramatic.

A line moved a little.

A weight adjusted slightly.

A vulnerable person assumed unable to resist.

Ma'at is lost by degrees.

## Wealth and Rest

Amenemope is skeptical of wealth gained without right relation.

What arrives through disorder carries the disorder inside it.

That is why the text often prefers modest security to anxious abundance.

The point is not poverty as virtue.

It is freedom from the appetite that keeps increasing the amount needed before the person believes they can be at peace.

## The Human Lesson

Amenemope's wisdom is emotional regulation in a moral frame.

Do not let heat choose the scale.

Cool enough to measure.

Then act.

Restraint is not doing nothing.

It is refusing to let the first surge of appetite, anger, fear, or status decide what happens next.
''',
    linkMap: [KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat')],
  ),
  KemeticNode(
    id: 'eye_of_ra',
    title: 'Eye of Ra',
    glyph: '𓁹',
    aliases: ['Solar Eye', 'Daughter of Ra', 'Active Sight'],
    body: '''
The Eye of Ra is sight that can leave the one who sees.

That is what makes it dangerous.

In Kemetic stories, the Eye is not passive perception. It can move outward as a daughter, goddess, cobra, lioness, protector, or destroyer. Ra's sight becomes force in the world.

## Sight Becomes Action

The Eye gives the Library a useful sequence:

first, something is seen.

Then power is sent in response.

That sounds simple until the response exceeds the need.

Sekhmet can embody the Eye as destructive heat. Hathor can embody it as returned, pacified, generative power. The uraeus places the Eye at the royal brow as active protection.

These are not separate lessons.

They are different stages in the problem of acting on what has been perceived.

## The Distant Eye

A recurring theme is distance.

The Eye goes out from Ra, becomes independent, and must be brought back. Ra is diminished without it, but the Eye can also become dangerous when separated from the source that gives its power meaning.

That image captures something psychologically sharp.

Attention can become obsession. Protection can become aggression. A justified response can keep moving long after the situation that justified it has changed.

The Eye needs return.

## Seeing Is Not Enough

The Ma'at connection is not “watch everything.”

It is to connect perception, action, and proportion.

See clearly. Respond when response is needed. Use enough force to restore relation. Then come back.

An eye that only looks is useless when action is required.

An eye that never stops acting becomes wrath.

The wisdom is in completing the whole movement.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Sekhmet', targetId: 'sekhmet'),
      KemeticNodeLink(phrase: 'Hathor', targetId: 'hathor'),
    ],
  ),
  KemeticNode(
    id: 'tomb_inscriptions',
    title: 'Tomb Inscriptions',
    glyph: '𓏞',
    aliases: ['Tomb Texts', 'Funerary Inscriptions', 'Inscribed Tomb Walls'],
    body: '''
The tomb wall was not silent stone.

It was prepared speech.

Names, titles, offering formulas, images, biographies, prayers, and ritual scenes turned the tomb into a place where memory could keep acting after the living voice was gone.

## The Name on the Wall

A written Ren is more than identification.

It gives later readers something to address.

That makes inscription part of the mechanism by which the dead remain socially and ritually present.

Erasure therefore carries enormous weight.

To remove the name is to damage the address.

## Biography as Claim

Tomb inscriptions also preserve self-presentations: the official who fed the hungry, judged fairly, protected the vulnerable, served the king, completed work, or acted without abuse.

These statements are not neutral autobiography.

They are moral claims made in public stone.

That is what makes them valuable even when we read them critically.

A claim carved for eternity invites comparison with the life behind it.

## Images That Act

Offering scenes, servants, food, ritual action, and the deceased seated before provision do not merely illustrate a past event.

Within the logic of the tomb, image and text help keep provision available.

The wall participates in continuation.

## Stone Needs Readers

The tomb inscription's Ma'at is the same tension we saw in Papyrus Chester Beatty IV.

Durability is not enough.

A name can survive physically and become meaningless if nobody can read it.

Memory requires both medium and relationship.

Stone gives the dead a long-lasting voice.

The living still have to listen.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ren", targetId: 'ren'),
      KemeticNodeLink(
        phrase: 'Papyrus Chester Beatty IV',
        targetId: 'papyrus_chester_beatty_iv',
      ),
      KemeticNodeLink(
        phrase: "offering formulas",
        targetId: 'offering_formula',
      ),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'middle_kingdom_funerary',
    title: 'Middle Kingdom Funerary Tradition',
    glyph: '𓏞𓇽',
    aliases: [
      'Middle Kingdom Tomb Tradition',
      'Coffin Text Tradition',
      'Funerary Expansion',
    ],
    body: '''
The Middle Kingdom changed who could carry royal funerary knowledge.

Material once known primarily from pyramid interiors began appearing on coffins, tomb equipment, stelae, and other non-royal funerary contexts.

The afterlife became more widely textual.

## From Pyramid Wall to Coffin Board

Coffins could become small cosmological spaces.

Sky above. Earth below. Direction encoded. Spells written close to the body. In some cases, maps of the underworld and diagonal star tables placed navigation directly inside the burial equipment.

The dead were not simply enclosed.

They were equipped.

## Wider Access, Same Problem

It is tempting to describe this as the “democratization” of the afterlife.

That word can be useful if handled carefully.

Access certainly widened beyond the king, but it still depended on wealth, status, local practice, and the ability to commission elaborate burial equipment.

The important shift is that the sacred technologies of passage were no longer exclusively royal in the same way.

More people could be placed inside patterns of transformation once reserved for kingship.

## Continuity Through Change

This period links the Pyramid Texts with the Coffin Texts and, later, the Book of Coming Forth by Day.

The content changes as it travels.

That is not corruption by default.

It is adaptation.

The Middle Kingdom funerary tradition's Ma'at connection is transmission that remains functional.

If knowledge is going to survive, it sometimes has to move to a new surface, a new audience, and a new form.

What matters is whether the passage still works.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'Coffin Texts', targetId: 'coffin_texts'),
      KemeticNodeLink(
        phrase: 'Book of Coming Forth by Day',
        targetId: 'book_of_the_dead',
      ),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'nut',
    title: 'Nut',
    glyph: '𓇯',
    aliases: ['Sky Mother', 'Celestial Vault', 'Mother of Stars'],
    body: '''
Nut is the sky as body.

She arches over the earth, holds the stars within her, receives the sun in the west, carries it through night, and gives birth to it again in the east. In funerary imagery she can also surround the dead, turning the coffin into a protected cosmic enclosure.

The sky is not empty in this view.

It holds.

## The Body Above

Nut's form makes the heavens intimate. Stars are not scattered in abstract space; they are within the body of a mother. Ra's daily cycle becomes a passage through her: swallowed at evening, reborn at dawn.

That image gives death and night a different character.

Disappearance does not automatically mean loss. Something can be hidden because it is being carried through a phase that has not yet become visible.

This is why Nut belongs so naturally to funerary thought. Coffin lids can identify with her body. The deceased rests beneath a sky that is also a womb, protected while transformation takes place.

## Holding Is Work

Nut's Ma'at connection is not simply motherhood.

It is containment with purpose.

A thing in transformation often needs a boundary strong enough to protect it without freezing it. A seed needs soil. A body needs a tomb. A thought needs time before it becomes speech. A cycle needs night before dawn.

The danger is confusing enclosure with permanence. Nut does not keep Ra inside herself. She releases him.

That is what makes the image useful.

Good protection knows what it is protecting toward.

To hold something well is not to possess it forever. It is to give it the conditions in which it can become ready to emerge.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'horizon',
    title: 'Akhet',
    glyph: '𓈌',
    aliases: ['Horizon', 'Place of Becoming Effective', 'Solar Threshold'],
    body: '''
Akhet, the horizon, is where hidden passage becomes visible return.

It is not the same thing as Akhet, the inundation season, though the shared transliteration can make that confusing. This Akhet is the horizon-zone: the place where the sun appears, where Khepri emerges from the night, and where the dead hope to become effective after passing through the Duat.

## The Threshold of Dawn

The horizon is neither fully earth nor fully sky.

That is why it works as a sacred threshold.

At dawn, what was hidden becomes visible. At sunset, what was visible enters hiddenness. The same line handles both directions.

The Pyramid Texts use the Akhet as a place of transformation and effectiveness. To become akh is linguistically and conceptually close to this horizon imagery: the effective being belongs to the zone where emergence has succeeded.

## Appearance Has a History

The useful lesson is not “new beginnings.”

It is stricter than that.

What appears at the horizon has already passed through something.

Ra has crossed the night. Khepri has formed in the hidden region. The dead have been prepared, protected, judged, and equipped.

The horizon is the moment the result becomes visible.

That makes it a good antidote to premature announcement.

Not everything that is becoming needs to be shown while it is still forming.

The Ma'at connection is readiness.

Cross the hidden passage first.

Then appear.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Khepri', targetId: 'khepri'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'akh', targetId: 'akh'),
      KemeticNodeLink(phrase: 'inundation', targetId: 'akhet'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'natron',
    title: 'Natron',
    glyph: '𓈗',
    aliases: ['Purifying Salt', 'Wadi Natrun Salt', 'Sacred Cleansing Mineral'],
    body: '''
Natron is a naturally occurring mineral salt that became one of the practical foundations of Kemetic purification.

It dried tissue during mummification, was used in cleansing, and appears in ritual contexts connected with preparing bodies, mouths, offerings, and sacred spaces.

Its meaning grew from what it physically did.

Natron removes moisture and slows decay.

## Purity as Function

“Purity” can sound moral or abstract in modern English.

Natron makes it concrete.

Something is purified because what would interfere with its function is removed.

A body prepared for burial cannot be left to decay unchecked. A ritual object cannot simply be assumed ready because it looks clean. The mouth that will speak sacred words has to be prepared for speech.

The material action comes first.

Drying, washing, removing, stabilizing.

The sacred language follows the practical transformation.

## What Must Be Removed

Natron's Ma'at connection is therefore not obsession with cleanliness.

It is preparation through subtraction.

Some things do not need more added to them. They need interference removed.

A schedule can be overloaded. A room can be cluttered. A relationship can be full of residue from arguments that were never addressed. A body can need rest before another demand.

Purification asks a different question from growth:

what has to leave for this thing to work properly again?

Natron is useful in the Library because it keeps “purity” from floating away into spiritual vagueness.

Sometimes restoration begins with salt, water, time, and the discipline to remove what cannot be carried forward.
''',
    linkMap: [KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat')],
  ),
  KemeticNode(
    id: 'nebet_het',
    title: 'Nebet-Het',
    glyph: '𓎟𓉐',
    aliases: ['Nephthys', 'Lady of the House', 'Mistress of the House'],
    body: '''
Nebet-Het is the presence that keeps a threshold from becoming abandonment.

Her name is often rendered “Lady of the House,” and her place in the Ausar cycle is consistently near the edge: beside Aset in mourning, near the dead, guarding passage, attending what has crossed out of ordinary life.

She is easy to overlook because she is not usually the figure who drives the plot.

That is exactly why she matters.

## Mourning Is Work

When Ausar is broken, Aset searches and acts. Nebet-Het remains with the work of mourning and attendance.

Kemetic funerary practice does not treat mourning as decorative grief. Lament, naming, presence, preparation, and protection all help prevent the dead from becoming socially and ritually abandoned.

Someone has to stay near what can no longer speak for itself.

That role is not lesser because it is quiet.

## The Edge of the House

Nebet-Het belongs to the boundary: inside and outside, living and dead, known and hidden.

Boundaries become dangerous when nobody takes responsibility for them. People fall through transitions when everyone assumes someone else is attending.

A funeral, a hospital room, the end of a relationship, a child leaving home, the closing of a project—thresholds can create exactly that kind of gap.

The Ma'at lesson here is not mystical.

Presence has moral weight.

Some things cannot be fixed by solving, persuading, or pushing. They need to be accompanied until the passage is complete.

Nebet-Het represents the person who does not leave simply because the old form is gone and the new one has not yet arrived.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Aset", targetId: 'aset'),
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'khnum',
    title: 'Khnum',
    glyph: '𓃝',
    aliases: ['Ram Creator', 'Potter of Life', 'Lord of the Wheel'],
    body: '''
Khnum creates with his hands.

That makes him different from creation through command alone. The potter's wheel is his central image: clay receiving pressure, water giving it plasticity, the vessel slowly taking form.

He is associated with formation, birth, the body, and the Nile region around the First Cataract.

## The Potter's Wheel

A pot cannot be made by force without attention to the material.

Press too hard and the wall collapses. Apply too little and the form never appears. The hand has to feel what the clay can take.

That is why Khnum's image remains useful even when separated from theology.

Formation is a relationship between intention and material.

A parent cannot shape a child like dead clay. A teacher cannot force understanding into a student. A designer cannot ignore the constraints of what is being built. A body has limits. A craft has grain.

The form succeeds when pressure is intelligent.

## Body and Ka

Kemetic scenes can show Khnum forming the body and ka together. The image joins material structure with animating presence: the vessel and what will live through it are prepared in relation.

That connection matters.

A strong idea needs a body capable of carrying it. A purpose needs routines, tools, spaces, and habits that can hold it. A life can want something sincerely and still fail if the structure around that desire cannot support it.

Ptah gives the Library a language of conception. Khnum gives it a language of shaping.

The Ma'at lesson is practical: form is not decoration added after meaning.

The vessel affects what can live inside it.

Shape carefully enough that what matters has somewhere durable to stay.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ptah', targetId: 'ptah'),
      KemeticNodeLink(phrase: 'ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'memphite_theology',
    title: 'Memphite Theology',
    glyph: '𓏞',
    aliases: ['Shabaka Stone', 'Theology of Ptah', 'Memphite Creation'],
    body: '''
The Memphite Theology begins creation inside the body.

But its date has to stay visible.

The text is preserved on the Shabaka Stone, a Twenty-Fifth Dynasty monument from around 710 BCE. The inscription says it was copied from an older damaged source, but how old the underlying composition actually is remains debated. Proposals range from earlier roots to composition in Shabaka's own period.

That uncertainty does not weaken the text.

It tells us what the surviving evidence can and cannot prove.

## Heart and Tongue

The theology centers Ptah and describes a sequence in which perception reaches the heart, the heart conceives, and the tongue gives effective expression to what the heart knows.

Creation is therefore not raw command detached from understanding.

The senses report. The heart forms. The tongue releases.

That sequence has consequences far beyond cosmology.

A craftsman sees, plans, measures, then makes. A judge hears, weighs, then speaks. A scribe receives information, understands it, then records it. When the sequence is reversed—when the mouth gets ahead of the heart—error becomes form.

## Why Naming Matters

Kemetic sacred practice repeatedly treats names and utterance as actions. To name a being establishes relation to it. To speak an offering formula directs provision. To identify the deceased with Ausar places that person inside a pattern of restoration.

The Memphite Theology gives one powerful theological explanation for that confidence in speech: words matter because rightly formed utterance can make thought effective in the world.

But the lesson is not “say anything and it becomes true.”

It is nearly the opposite.

Speech becomes dangerous when it separates from accurate perception. The tongue has power precisely because it can carry what the ib has understood—or distort it.

That is why this text belongs near Ma'at.

The deepest creative discipline is not speaking more forcefully. It is making sure the inner understanding is sound enough that the words built from it deserve to become action.

The surviving stone is late compared with the Old Kingdom world often associated with Ptah. hꜣw can use the theology confidently as evidence for the tradition preserved on the Shabaka Stone while leaving the age of its underlying composition open.

That is a stronger foundation than pretending certainty where the record does not give it.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ptah', targetId: 'ptah'),
      KemeticNodeLink(phrase: 'ib', targetId: 'ib'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'book_of_the_dead',
    title: 'Book of Coming Forth by Day',
    glyph: '𓏞',
    aliases: [
      'Book of the Dead',
      'Per Em Hru',
      'Peret Em Heru',
      'Coming Forth by Day',
    ],
    body: '''
The Book of the Dead is better understood by its Kemetic title: Book of Coming Forth by Day.

The name tells you the goal.

Not death.

Return.

These funerary papyri gather spells, images, declarations, protections, and ritual knowledge intended to help the deceased move, speak, remain whole, pass judgment, and emerge from hiddenness.

## A Portable Ritual World

Unlike the Pyramid Texts carved into royal stone or Coffin Texts painted onto coffins, these compositions could be written on papyrus and placed with the dead.

That portability mattered.

The text could travel with the person.

Different copies varied. There was no single modern-style fixed edition used everywhere for all time. Families commissioned selections appropriate to means, period, workshop, and tradition.

## Coming Forth

The deceased wants movement.

The Ba must not be imprisoned.

The name must remain intact.

The heart must not testify falsely against the life that carried it.

The person must know gates, beings, names, and formulas.

The Hall of Two Truths gives the journey its moral center: continuation is not only technical knowledge. The heart still has to meet Ma'at.

## Image and Word

The papyri combine text and vignette because seeing and speaking work together.

A judgment scene does not merely tell the reader that judgment exists. It places the deceased visually inside it.

A spell does not merely describe passage. It gives language for passage.

## The Human Meaning

The Book of Coming Forth by Day is easy to exoticize as a manual for the dead.

Its deeper logic is familiar.

When people approach an unknown passage, they prepare.

They gather names, maps, words, protections, identities, and standards for what counts as having arrived well.

The book's Ma'at is preparedness joined to truth.

Knowledge can open the gate.

Character still determines what crosses it.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ba", targetId: 'ba'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'Coffin Texts', targetId: 'coffin_texts'),
    ],
  ),
  KemeticNode(
    id: 'palermo_stone',
    title: 'Palermo Stone',
    glyph: '𓆳',
    aliases: ['Royal Annals', 'Early Royal Chronicle', 'Annals Stone'],
    body: '''
The Palermo Stone is broken, but it still shows what early kingship wanted remembered.

Its surviving fragments preserve royal annals: kings arranged in sequence, reigns divided into years, and years filled with events. Rituals, offerings, cattle counts, building activity, and Nile heights share the same record.

That mixture is the important part.

## A Year Had Contents

The annals do not treat history as a string of royal names. Each reign is made legible through what happened within it.

The Nile was measured. Cattle were counted. Ceremonies were performed. Institutions acted. The king existed inside an administrative world that had to keep track of material conditions as well as sacred events.

Nile height is especially revealing. Flood level affected agriculture, taxation, storage, and expectation for the year ahead. Recording it beside royal acts places environment and government in the same frame.

## Memory Under Measure

A royal annal can flatter power. The Palermo Stone is valuable because its form also constrains power: events must be placed somewhere, in a particular year, under a particular ruler.

That is Djehuty's domain. Record turns memory into something another generation can inspect.

The stone cannot give us a complete history of early Kemet. Too much is missing, and what was selected for royal commemoration was itself political. But it shows an old commitment to structured time: a reign should leave more than a name.

The Ma'at connection is simple. Memory becomes useful when it is organized well enough to test claims against a record.

A civilization that wants accountability needs more than stories about itself. It needs dates, measures, receipts, lists, names, and someone responsible for keeping them.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
    ],
  ),
  KemeticNode(
    id: 'wadi_el_jarf_papyri',
    title: 'Wadi el-Jarf Papyri',
    glyph: '𓏞',
    aliases: ['Diary of Merer', 'Khufu Harbor Papyri', 'Old Kingdom Work Logs'],
    body: '''
The Wadi el-Jarf Papyri make the Great Pyramid smaller in the best possible way.

They bring it down to boats, crews, routes, deliveries, days, and one official keeping track of work.

Among the papyri is the diary of Merer, an inspector whose team transported limestone during the reign of Khufu. Instead of speaking in the voice of monument, the text records movement: where the crew went, what it carried, when it arrived, and how the work fit into a larger system.

## Monument Becomes Logistics

A pyramid can make labor disappear behind the finished form. Merer's diary does the opposite.

Stone had to be quarried. Boats had to move through canals and river routes. Crews had to be fed. Officials had to coordinate timing. Deliveries had to arrive in sequence. Someone had to write it down.

Akhet-Khufu—the horizon of Khufu—was not built by an abstract “state.” It was built through thousands of correctly coordinated actions.

That is what makes the papyri so useful for hꜣw.

Large work is usually experienced from the outside as one thing. From the inside it is schedule, handoff, repetition, and record.

## Record Prevents Scale From Becoming Chaos

Merer's notes are not philosophical writing. Their value comes from being practical.

That practicality is itself the lesson. Djehuty's world of measure and record was not separate from sacred architecture. It was one of the conditions that made sacred architecture possible.

The Wadi el-Jarf Papyri remind us that purpose does not eliminate logistics. The more ambitious the work, the more ordinary its coordination becomes.

A great intention without counted days remains intention. A great structure is what happens when many small actions arrive where they are supposed to.
''',
    linkMap: [KemeticNodeLink(phrase: 'Akhet-Khufu', targetId: 'horizon')],
  ),
  KemeticNode(
    id: 'false_door',
    title: 'False Door',
    glyph: '𓉿',
    aliases: ['Ka Door', 'Tomb Doorway', 'Door of Offerings'],
    body: '''
A false door was not built for the living to walk through.

It was built so relationship could cross.

Set into tomb chapels, the false door gave the deceased a ritual point of contact with the living world. Names, titles, images, and offering formulas gathered around it. Food and drink could be presented there. Speech could activate what stone preserved.

The door did not swing.

It still functioned as a threshold.

## An Address for the Dead

The architecture makes sense once Ka and Ren are understood.

The Ka continues to receive.

The Ren makes the recipient findable.

The false door gives those relationships a place.

Without a point of address, remembrance remains diffuse. With one, the living know where to speak, pour, place, and return.

## Stone Waiting for Voice

This is one of the most beautiful things about the object.

The inscription is durable but incomplete on its own.

Someone has to come back.

The offering formula has to be spoken. The name has to be read. The chapel has to remain part of a living relationship.

Stone stores the possibility.

People activate it.

## The Human Lesson

The false door's Ma'at is ritualized access.

Relationships across absence need places, habits, and forms if they are going to remain active.

A grave visited, a name spoken, a recipe kept, an anniversary observed, a photograph returned to—modern practices are not the same as Kemetic tomb cult, but they reveal the same human need for structure around memory.

A threshold can be “false” architecturally and still be real relationally.

The door works because people keep coming to it.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ka", targetId: 'ka'),
      KemeticNodeLink(phrase: "Ren", targetId: 'ren'),
      KemeticNodeLink(phrase: 'offering formula', targetId: 'offering_formula'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'architrave',
    title: 'Architrave',
    glyph: '𓉹',
    aliases: ['Temple Lintel', 'Inscribed Beam', 'Sacred Support'],
    body: '''
An architrave is the stone that carries what is above a passage.

It is easy to ignore because its success looks like nothing happening.

The beam holds. The opening remains open. People move beneath it.

That makes the architrave one of the Library's best ordinary images of support.

## Weight Has to Go Somewhere

In monumental architecture, load travels.

Columns, beams, walls, lintels, and foundations distribute forces so the structure can stand. If one piece is badly placed, the failure may appear somewhere else.

An architrave therefore does not “defeat” weight.

It receives and redirects it.

That is a more useful idea.

## Inscribed Support

Kemetic architraves often carry royal names, divine titles, offering language, and statements of relationship between king, deity, and temple.

The object that physically holds the building can also carry the text that explains who maintains the sacred order inside it.

Structure and inscription meet in one piece of stone.

## Bearing Without Display

The Ma'at connection here should stay simple.

Not every essential role is visible from the center of the room.

Some people, systems, habits, and institutions matter because they carry pressure so something else can remain open.

The danger is romanticizing burden.

Good support distributes weight. It does not absorb everything until it cracks.

The architrave teaches a better question than “How much can I carry?”

Ask instead: what load belongs here, where should it move next, and what passage is this support meant to keep open?
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'offering', targetId: 'offering_formula'),
      KemeticNodeLink(phrase: 'temple', targetId: 'esna_temple'),
    ],
  ),
  KemeticNode(
    id: 'wp_rnpt',
    title: 'Wp Rnpt',
    glyph: '𓊃𓆳',
    aliases: [
      'Opening of the Year',
      'Opener of the Year',
      'Wep Renpet',
      'New Year',
    ],
    body: '''
Wp Rnpt is better held as “Opening” or “Opener of the Year” than as a simple synonym for New Year's Day.

In Parker's reconstruction of the early calendar, wp rnpt names the Sothic event—the heliacal rising of Sopdet—that opens the year, while tpy rnpt names the first day of the new year. Later usage broadened, so Egyptian texts do not preserve one perfectly rigid distinction in every period.

That is exactly why the distinction should remain visible here.

## Sopdet Opens the Cycle

Sopdet's heliacal rising became one of the great astronomical signals associated with annual renewal. In periods when that rising fell near the Nile inundation, return in the sky and return in the land reinforced one another.

But the civil calendar had 365 days and drifted against the natural solar year.

The rising of Sopdet and the first civil calendar day did not remain permanently locked together.

So Wp Rnpt should not be used as proof that one fixed civil date was always the natural New Year across Egyptian history. It is safer—and more interesting—to understand it as an opening event whose language later broadened.

## Not a Reset

That historical correction does not weaken hꜣw's threshold reading.

It strengthens it.

An opening is not an erasure.

The epagomenal days complete the ordinary count. Sopdet can announce renewed orientation. The calendar becomes available again under conditions inherited from what came before.

Debts remain.

Skills remain.

Relationships remain.

Consequences remain.

Memory remains.

Wp Rnpt's Ma'at connection is deliberate opening: know what is actually crossing the threshold with you.

What is ready?

What is unfinished?

What should be released?

What deserves renewed commitment?

A calendar can open a new count overnight.

A life changes only through what the person carries differently into it. If old disorder is simply renamed as a new beginning, Isfet has crossed the threshold with the date.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'epagomenal days', targetId: 'epagomenal_days'),
      KemeticNodeLink(phrase: 'Sopdet', targetId: 'sopdet'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'akhet',
    title: 'Akhet Season',
    glyph: '𓈗',
    aliases: ['Inundation Season', 'Flood Season', 'Season of the Nile Rising'],
    body: '''
Akhet is the inundation season.

The Nile rises, spreads beyond its ordinary channel, covers fields, and changes the landscape people use for farming and movement.

The disappearance of the land is not the failure of agriculture.

It is part of what makes later agriculture possible.

## Covered Ground

Floodwater brings moisture and historically deposited fertile sediment across the floodplain.

Fields can vanish beneath the water for a time, and work shifts accordingly.

Akhet therefore begins with a strange kind of productivity: the most important work in the field is happening while the field cannot be used in its ordinary way.

That is why the season works so well as a hꜣw metaphor.

Preparation can look inactive from the outside.

## Measure Still Matters

Water is life in right proportion.

Too little inundation brings scarcity.

Too much can damage settlements, boundaries, and infrastructure.

The Nile's value was never reducible to “more.”

Ma'at appears as measure.

The field needs what it can receive and use.

## Before Peret

Akhet is incomplete by itself.

The waters have to withdraw.

Land must reappear.

Seed must enter prepared ground.

The season exists in relation to Peret and Shemu.

Flood, emergence, harvest.

That sequence is the moral.

Not every phase should be asked to produce visible yield.

Some periods are for covering, restoring, receiving, and preparing the conditions from which later work will grow.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
      KemeticNodeLink(phrase: 'Peret', targetId: 'peret'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'peret',
    title: 'Peret',
    glyph: '𓇾',
    aliases: ['Emergence Season', 'Growing Season', 'Season of Coming Forth'],
    body: '''
Peret begins when the land comes back.

The flood withdraws.

Prepared ground becomes visible.

Seed enters the soil.

Growth starts to show itself.

The name carries the sense of coming forth, which lets agriculture, solar emergence, and funerary language echo one another without becoming identical.

## Emergence Is Not Completion

A green shoot is evidence.

It is not harvest.

That difference gives Peret its character.

The excitement of appearance can tempt people to act as though the work is finished. In reality, emergence creates a new responsibility.

Water has to be managed.

Growth has to be tended.

Weakness has to be noticed before it becomes loss.

## Khepri and Coming Forth

Khepri gives the season a useful sacred parallel.

The dawn sun appears after hidden night work.

The seed appears after development underground.

The dead hope to come forth after preparation in hiddenness.

Across these domains, visible emergence means something has already been happening out of sight.

## The Work of Peret

Peret's Ma'at is sustained care after the first success.

Do not abandon what has finally appeared.

Do not overcontrol it either.

A new habit, project, relationship, skill, or idea can die from neglect or from constant interference.

The work now is to create enough continuity that the fragile thing no longer needs you to rescue it every day.

Promise becomes real when it can survive ordinary care.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Khepri', targetId: 'khepri'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'epagomenal_days',
    title: 'Epagomenal Days',
    glyph: '𓏤𓏤𓏤𓏤𓏤',
    aliases: [
      'Five Days Outside the Year',
      'Birth Days of the Gods',
      'Days Upon the Year',
    ],
    body: '''
The civil year counted twelve months of thirty days.

That made 360.

Five additional days stood outside the ordinary monthly structure.

Those are the epagomenal days—the “days upon the year.”

Their position made them naturally charged: the old cycle was complete, but the new one had not yet opened.

## Births at the Edge

Later tradition associates the five days with the births of Ausar, Heru the Elder, Set, Aset, and Nebet-Het. That full mythic sequence belongs to later tradition and should not be projected unchanged backward into the Old Kingdom.

The sequence places major divine powers at the threshold between years.

Restoration.

Sky power.

Force.

Protection and effective speech.

Mourning and boundary.

The year approaches renewal already containing the powers that will make its conflicts and recoveries possible.

## Time Outside the Usual Count

What makes these days interesting is structural.

A calendar needs regularity, but the solar year did not fit neatly inside twelve thirty-day months.

The solution was not to pretend the remainder did not exist.

It was given a place.

That is almost a perfect Ma'at image.

Order does not mean forcing reality to fit a cleaner number.

Order makes room for what exceeds the pattern.

## Threshold Time

Epagomenal days became associated with risk, purification, birth, and preparation because thresholds always destabilize ordinary categories.

Not the old year.

Not yet the new one.

That makes them a natural space for clearing, completing, remembering, and protecting.

The lesson is not that five days are magically dangerous.

It is that transitions deserve more attention than routine.

When a normal structure ends, do not rush across the gap as though nothing changed.

Use the threshold to notice what should not follow you.
''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar", targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Heru the Elder', targetId: 'heru'),
      KemeticNodeLink(phrase: 'Set', targetId: 'set'),
      KemeticNodeLink(phrase: "Aset", targetId: 'aset'),
      KemeticNodeLink(phrase: "Nebet-Het", targetId: 'nebet_het'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'regnal_year',
    title: 'Regnal Year',
    glyph: '𓆳',
    aliases: ['Year of the Reign', 'Royal Year Count', 'King’s Year'],
    body: '''
A year in Kemet could be named by the reign of the king.

That made time political in a very concrete sense. A document did not merely say when something happened. It placed the event under a particular authority: this delivery, census, expedition, offering, or construction belonged to this year of this reign.

## Time Becomes Accountable

Regnal dating helped administration work because obligations could be located in a sequence. A shipment could be checked. A work crew could be assigned. A festival could be repeated. A record could be compared with an earlier year.

The Palermo Stone preserves this logic on a monumental scale, organizing royal annals into yearly compartments that contain events, ritual acts, counts, and Nile measurements.

The Wadi el-Jarf Papyri show the same principle at working scale. The diary of Merer records days, routes, crews, and stone transport under Khufu. Monumental achievement resolves into dated labor.

## The King Did Not Own the Year

The seasons continued whether a king ruled well or badly. Sopdet returned. The Nile rose or failed to rise. Akhet, Peret, and Shemu followed rhythms older than any throne.

The ruler's responsibility was therefore not to create time but to administer human life within it.

That distinction matters. Dating a year by a king could make royal authority feel total, but the natural cycle remained a standard the throne could not command. The king answered to conditions already present: flood, harvest, obligation, succession, and the expectation that rule should maintain Ma'at.

A regnal year is therefore both record and witness.

It says: this happened under this ruler.

That makes the year more than a number. It becomes a container for responsibility. The count preserves who had authority when the work was done—and therefore who cannot be separated from what the record shows.
''',
    linkMap: [
      KemeticNodeLink(phrase: 'Kemet', targetId: 'kemet'),
      KemeticNodeLink(phrase: 'Ma\'at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Palermo Stone', targetId: 'palermo_stone'),
      KemeticNodeLink(
        phrase: 'Wadi el-Jarf Papyri',
        targetId: 'wadi_el_jarf_papyri',
      ),
      KemeticNodeLink(phrase: 'Akhet', targetId: 'akhet'),
      KemeticNodeLink(phrase: 'Peret', targetId: 'peret'),
      KemeticNodeLink(phrase: 'Shemu', targetId: 'shemu'),
      KemeticNodeLink(phrase: 'Sopdet', targetId: 'sopdet'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
    ],
  ),
];
