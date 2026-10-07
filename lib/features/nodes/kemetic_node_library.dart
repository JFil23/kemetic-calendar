import 'kemetic_node_model.dart';
import 'retired_kemetic_nodes.dart';

class KemeticNodeLibrary {
  KemeticNodeLibrary._();

  static const List<String> _canonicalNodeOrder = [
    'cosmic_order',
    'human_emergence',
    'green_sahara',
    'nile',
    'kemet',
    'rise_of_kush_and_kemet',
    'maat',
    'isfet',
    'palermo_stone',
    'wadi_el_jarf_papyri',
    'imhotep',
    'house_of_life',
    'rekh_wer',
    'ptah',
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
    'jackal',
    'serpent',
    'hathor',
    'eye_of_ra',
    'sekhmet',
    'sopdet',
    'sah',
    'decans',
    'dendera',
    'architrave',
    'abydos',
    'duat',
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
    'pyramid_texts',
    'coffin_texts',
    'book_of_the_dead',
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

  // Retired entries resolve only for existing routes and account-owned links.
  // They are never offered by the canon, search inventory, or link picker.
  static final Map<String, KemeticNode> _retiredById = {
    for (final node in retiredKemeticNodes) node.id.toLowerCase(): node,
  };

  static bool isRetired(String id) =>
      _retiredById.containsKey(id.toLowerCase());

  static final Map<String, String> _titles = {
    for (final node in [...retiredKemeticNodes, ..._nodes])
      node.title.toLowerCase(): node.id.toLowerCase(),
  };

  static final List<KemeticNode> nodes = List.unmodifiable(
    _buildCanonicalNodes(),
  );

  static final Map<String, String> _aliases = {
    for (final node in [...retiredKemeticNodes, ..._nodes])
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
    final direct = _byId[key] ?? _retiredById[key];
    if (direct != null) return direct;
    final id = _titles[key] ?? _aliases[key];
    if (id == null) return null;
    return _byId[id] ?? _retiredById[id];
  }
}

const List<KemeticNode> _nodes = [
  KemeticNode(
    id: "cosmic_order",
    title: "Cosmic Order",
    glyph: "𓆄",
    aliases: ["Cosmic Beginnings", "Elemental Memory", "Stardust Becomes Life"],
    body: r'''Before there was a world to order, there was only potential.

Kemetic creation traditions named that boundless, unformed depth Nun. From it, distinction could emerge. Ra gives radiant order a divine form; Ma'at names the relations through which things take shape and hold together.

**Cosmic beginnings and sacred correspondences**

| Event | Modern Science | Ma'at-Based Interpretation |
| --- | --- | --- |
| Big Bang | Sudden release of energy and matter | Ra emerges from Nun — order born from undifferentiated potential |
| Inflation | Rapid expansion | Breath of Ma’at — establishing space, time, and motion |
| First atoms | Hydrogen and helium form | Sia (perception) and Hu (utterance) begin shaping matter |
| First stars | Light returns to the cosmos | Ra’s eye opens — energy begins organizing into memory |

## Stardust Becomes Life

Long before Earth existed, stars produced and released the heavier elements from which later worlds would form.

**Stellar functions and sacred meanings**

| Function | Purpose |
| --- | --- |
| Creates elements | Carbon, oxygen, iron, calcium, and other essential elements originate in stars |
| Distributes energy | Stars bathe nearby planets in light and radiation |
| Regulates galactic rhythm | Stellar life cycles shape time, transformation, and decay |
| Feeds Loosh (in Ma'at lens) | Light functions as life-giving, law-making cosmic speech |

About 4.6 billion years ago, material from older stars gathered into the solar system. Carbon, oxygen, nitrogen, iron, calcium, phosphorus, and other elements became part of Earth and eventually of living bodies. The planet received what earlier stars had made.

Ausar is broken, gathered, restored, and made productive again. Stellar material also continues beyond the form that held it, gathering into new worlds and entering living bodies. What is scattered can become the substance of another life.

## Order Is Not the Same as Certainty

Matter gathered into stars; stars produced the elements of later worlds; Earth formed, and life emerged under its conditions. Eventually, human beings could look back along this history and consider their place within it.

**Emergence and sacred awareness**

| Event or Shift | Impact |
| --- | --- |
| Sapiens emerge (~300,000 BCE) | Brain-to-body ratio expands; symbolic language becomes possible |
| Emotional range deepens | Grief, awe, reverence, and imagination intensify |
| Fire use becomes widespread | Warmth, ritual, protection, and communal focus emerge |
| Group memory develops | Oral lineage, ritual continuity, proto-time awareness |
| Celestial observation begins | Stars become meaningful; patterns begin to be remembered |
| First Loosh-based exchange | Emotional presence begins feeding the field, not only the tribe |
| Ma'at awakens | Not as deity alone, but as felt alignment — consciousness recognizing order |

Ma'at belongs to these relations from the beginning, before Earth takes form. A human life depends on this order of formation, inheritance, and change, already at work long before it.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
    ],
  ),
  KemeticNode(
    id: "human_emergence",
    title: "Human Emergence",
    glyph: "𓀀",
    aliases: ["Great Awakening", "Hominid Lineage", "Sapiens Awakening"],
    body: r'''Human emergence is not a ladder with one clean step at the top.

Human populations branched, overlapped, migrated, interbred, adapted, and disappeared over immense spans of time. Homo sapiens arose in Africa from an older African lineage, while Neanderthals and Denisovans developed along related branches outside the continent.

**Species, timeframes, and regions**

| Species | Timeframe | Region | Notes |
| --- | --- | --- | --- |
| Australopithecus afarensis | ~4–3 million BCE | East Africa | "Lucy"; upright walking but small brain |
| Homo habilis | ~2.4–1.4 million BCE | East Africa | First tool user (Oldowan tools) |
| Homo erectus | ~1.9 million–140,000 BCE | Started in Africa, spread to Asia | First to leave Africa; colonized Asia; ancestor of Neanderthals & Denisovans |
| Homo heidelbergensis | ~700,000–200,000 BCE | Africa and Europe | Last shared ancestor of Neanderthals and sapiens |
| Neanderthals (Homo neanderthalensis) | ~400,000–40,000 BCE | Europe, W. Asia | Cold-adapted offshoot of heidelbergensis in Europe |
| Denisovans | ~300,000–50,000 BCE | Central/East Asia | Offshoot of heidelbergensis or erectus in Asia |
| Homo sapiens | ~300,000 BCE–present | Emerged in East Africa | Only surviving human species |

Along this history came increasingly elaborate ways of naming, remembering, teaching, burying, marking, and imagining. Experience could be shared, and a tradition could last beyond the generation that began it.

## The African Human Story

The differences between Homo habilis and Homo erectus extend from anatomy to tools, fire, travel, and cooperation.

**Homo habilis and Homo erectus**

| Trait | Homo habilis ("Handy Man") | Homo erectus ("Upright Man") |
| --- | --- | --- |
| Timeframe | ~2.4–1.4 million BCE | ~1.9 million–140,000 BCE |
| Brain Size | ~510–600 cc | ~850–1100 cc, nearly doubled |
| Posture | Still somewhat hunched | Fully upright, long legs, better stride |
| Tool Use | Simple stone flakes (Oldowan) | Sophisticated tools, including Acheulean hand axes |
| Fire Use | Likely none | Mastery of fire begins |
| Migration | Africa-only | First to leave Africa into Asia and Europe |
| Social Behavior | Limited, uncertain | Cooperative hunting, long-distance travel |

Food, climate, and fire appear among the proposed explanations of these changes, alongside sacred accounts of origin.

**Proposed explanations**

| Theory | Explanation | Flaws / Mysteries |
| --- | --- | --- |
| Meat consumption | Better nutrition supported brain growth | Does not explain social and symbolic leaps by itself |
| Climate pressure | Forced adaptation under changing conditions | Still appears fast and coordinated |
| Fire mastery | Enabled cooking, safety, warmth, and culture | Fire may be part of the result, not only the cause |
| Spiritual Mutation | Sudden jump in symbolic awareness | Outside mainstream science; belongs to sacred interpretation |
| External Intervention (theoretical) | Some propose cosmic or ancestral seeding | Outside mainstream science; echoes certain ancient traditions |

The regional comparisons place related populations across Africa, Asia, and Europe, then set their traits beside the environments they occupied.

**Regional branches**

| Region | New Species | Traits |
| --- | --- | --- |
| Africa | Homo heidelbergensis | Larger brains, advanced tools |
| Asia | Homo erectus soloensis, later Denisovans | Adapted to mountains and cold |
| Europe | Homo antecessor → Neanderthals | Robust build, cold-weather traits |

**Three related populations**

| Region | Offspring | Notes |
| --- | --- | --- |
| Africa | Homo sapiens | Light-boned, adaptable, symbolic |
| Europe | Neanderthals (H. neanderthalensis) | Short, strong, cold-adapted |
| Asia | Denisovans (from a sibling branch) | Little-known, adapted to high altitude; Tibetan populations retain some Denisovan inheritance |

**Traits and environments**

| Lineage | Core Traits | Ecological Context |
| --- | --- | --- |
| Neanderthal | Physical strength, cold-resistance, tight social groups | Ice Age Europe; extreme climate demanded specialization |
| Denisovan | High-altitude adaptation, regional niche traits | Central and East Asian highlands; relative isolation |
| Sapiens | Language, symbolic thought, wide social networks, adaptability | Varied African environments; flexibility over specialization |

Changes in anatomy, diet, climate, social life, technology, and communication accumulated unevenly. By roughly 300,000 years ago, anatomically modern humans existed. Over the long period that followed, increasingly complex tools, long-distance exchange, pigments, ornaments, burials, and symbolic behavior became more visible. People could carry an understanding of their world and communicate it to someone else.

## When Survival Starts Remembering Itself

A burial gave the dead deliberate care. A repeated mark could remain after the hand that made it had gone. A shared story could carry what one generation had learned to children yet to be born, who could tell it to their children. Experience gained a life beyond its first witness, allowing people to act on what others remembered.

**Shared life and sacred awareness**

| Event or Shift | Impact |
| --- | --- |
| Sapiens emerge (~300,000 BCE) | Brain-to-body ratio expands; symbolic language becomes possible |
| Emotional range deepens | Grief, awe, reverence, and imagination awaken |
| Fire use becomes widespread | First external tool of spiritual focus: warmth, ritual, community |
| Group memory begins | Oral lineage, early ritual, proto-time awareness |
| Celestial observation begins | Stars become meaningful; constellations are silently named |
| Ma'at awakens | Not as a deity, but as felt alignment — Earth's intelligence mirroring itself through humanity |

Pattern, consequence, obligation, memory, and relation could be recognized before a civilization gave them the name Ma'at. As these capacities developed, people became better able to consider what their actions meant beyond the immediate moment.

Keeping time and recognizing place also meant attending to sky and land.

**Rhythms and spiritual correspondences**

| Cosmic Process | Human Mirror |
| --- | --- |
| Galactic alignment (spiritual reading) | Pineal attunement, symbolic dreams |
| Solar cycles | Calendar observation, circadian attunement |
| Orbital changes | Nomadic patterning, seasonal wisdom |
| Sahara's greening | First sacred geographies, star-watching cultures |

Memory and coordination let intelligence serve a shared life. A person could consider what an action meant for others, beyond the appetite that prompted it.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
      KemeticNodeLink(phrase: "Sahara's greening", targetId: "green_sahara"),
    ],
  ),
  KemeticNode(
    id: "green_sahara",
    title: "Green Sahara",
    glyph: "𓇅𓇾",
    aliases: [
      "African Humid Period",
      "Garden of Eden",
      "Prehistoric Civilizations in Saharan Africa",
      "Great Departure",
      "Saharan Eden",
    ],
    body: r'''The Sahara was not always desert.

During the African Humid Period, large parts of northern Africa held lakes, rivers, wetlands, grasslands, wildlife, and human communities. Orbital changes strengthened African monsoons. Across a region that changed at different times, places now among the driest on Earth supported this abundance for thousands of years.

People learned the movements of water, cattle, seasons, and sky in landscapes the desert has since concealed.

## A World Hidden by Sand

At Nabta Playa, evidence of pastoral life, cattle ritual, settlement, and seasonal observation survives from before dynastic Kemet. At Tassili n'Ajjer, rock art depicts herding, ceremonies, animals, and people in surroundings that have since changed.

Pottery, burials, bones, tools, rock art, and campsites preserve the activities of mobile communities. Their knowledge left traces along the places where they lived and the routes they traveled, even where no monumental capital stood.

## The Great Drying

The time of lakes and grasslands gave way to drier conditions. Communities moved toward the Nile, the Sahel, the Mediterranean, and other places where water and grazing remained. They took different routes, at different times, carrying knowledge of land and seasons into the places where life could continue.

Kemet emerged within this older northeastern African world. Pastoral traditions, cattle symbolism, and observation of land and sky preceded the dynastic state. Some of those practices continued, changed, and became established in the Nile Valley.

Knowledge of water, grazing, and seasonal return could remain useful after familiar ground ceased to support a community. Ma'at could be followed through changed conditions by attending to the relations on which life still depended.''',
    linkMap: [
      KemeticNodeLink(phrase: "Kemet", targetId: "kemet"),
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "nile",
    title: "Nile & Hapy (Inundation)",
    glyph: "𓈘",
    aliases: ["Hapy", "Nile", "Inundation", "Nile Inundation"],
    body: r'''The Nile is the river. Hapy is the inundation.

Hapy personifies the fertile annual rise, when water and silt changed the valley and made another agricultural cycle possible. The Nile supplied the channel. No king could command the arrival; people had to be ready to receive it.

## The Gift That Could Not Be Forced

The Hymn to Hapy praises the flood through what it supplies: grain, storehouses, livestock, offerings, and abundance. Temple and field shared the same dependence. Bread for an offering first required grain to grow.

The river's renewal also belonged to Ausar, whose death and restoration gave sacred form to fertility, hiddenness, and return. Water came back to land that depended on its coming.

In hꜣw's agricultural sequence, inundation opens Akhet, withdrawing water prepares Peret, and the crop reaches Shemu. This follows the movement of the seasons; the historical civil calendar moved gradually against them.

## Measure Was a Moral Problem

Too little water could bring scarcity; too much could destroy settlements and infrastructure. Nilometers recorded the flood's height, helping people judge what to expect from the harvest and how to tax, store, and distribute it. The Palermo Stone preserves these measurements beside royal events.

Water also covered field boundaries. When it withdrew, the land had to be measured again. A false boundary could take a household's ground; a false flood reading could change what it owed in tax. An accurate measure helped people keep what was theirs.

What the flood brings must be measured honestly, distributed fairly, and gathered into store for leaner years. Ma'at continues in the food a household receives, the land it keeps, and the tax it is asked to pay.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "hꜣw", targetId: "haw"),
      KemeticNodeLink(phrase: "Akhet", targetId: "akhet"),
      KemeticNodeLink(phrase: "Peret", targetId: "peret"),
      KemeticNodeLink(phrase: "Shemu", targetId: "shemu"),
      KemeticNodeLink(phrase: "Palermo Stone", targetId: "palermo_stone"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "kemet",
    title: "Kemet (Black Land)",
    glyph: "𓇾",
    aliases: [],
    body: r'''Kemet means the Black Land.

Its name comes from the dark Nile silt that supported cultivation along a strip of land surrounded by desert. The country was named for the ground on which people lived and grew their food.

## Black Land, Red Land

Kemet was the fertile, cultivated Nile valley; Deshret, the Red Land, was the desert beyond it. Fields, settlements, canals, temples, and administration occupied the watered ground. Beyond them lay stone, minerals, routes, and forms of life adapted to dry conditions.

The contrast entered sacred imagery. Set could belong to the Red Land, while cultivation gave order a visible form. Yet the desert also protected the valley and supplied its materials. Black soil and red sand marked different conditions within a connected landscape.

## A Country That Had to Be Re-Made

The flood covered fields and blurred their boundaries. When the water withdrew, each boundary had to return to its rightful place, not be moved for someone else's gain. Records and measurement helped each household keep its ground. Ma'at required that care again each time the land reappeared.

The narrow southern valley and the broad northern Delta also remained distinct within their union. Kingship named them the Two Lands, bringing Upper and Lower Kemet together without erasing their different landscapes, histories, and connections.

Temples, texts, calendars, and harvests belonged to people living on this ground. Their work of maintaining order began with the conditions that made life there possible.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Set", targetId: "set"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "rise_of_kush_and_kemet",
    title: "Rise of Kush and Kemet",
    glyph: "𓈘𓊖",
    aliases: [
      "Kush",
      "Kemet and Kush",
      "Nile Silt",
      "Ethiopian Highlands",
      "Medu Neter",
      "Symbolic Literacy",
      "Words of the Divine",
    ],
    body: r'''Kemet and Kush did not appear from an empty map.

Dynastic Kemet consolidated earlier; Kerma, the first major Kushite polity, rose centuries later to the south. Both developed along a Nile corridor already carrying cattle, trade, ritual, seasonal knowledge, and movement across northeastern Africa.

## The River Made Scale Possible

The Nile's annual rhythm supported intensive agriculture. Surplus could feed permanent settlements, specialized workers, temples, and building projects, while administration and long-term records helped organize the growing scale of the work.

Kemet's fertility depended on regions upstream: water and silt traveled north through the Nile system. The wider setting includes Ethiopia's volcanic landscapes and the East African Rift.

**Volcanic features and the East African Rift**

| Volcanic Feature | Location | Relevance |
| --- | --- | --- |
| Mount Dendi | West of Addis Ababa | One of the largest stratovolcanoes near Lake Tana's watershed |
| Mount Zuqualla | Southeast Ethiopia | Sacred crater lake volcano, culturally significant |
| Erta Ale (active) | Danakil Depression | Part of the same tectonic system |
| East African Rift | Runs through Ethiopia | Major geological source of uplift and erosion feeding silt into Blue Nile |

Stone, cattle, gold, people, and ideas moved along the corridor in both directions. The river connected the societies taking shape along it.

## Kemet and Kush

Kush developed south of Kemet in Nubia. Over time, it was a trading partner, rival, subordinate territory, independent kingdom, and imperial power. The relationship changed with the balance of power.

During the Twenty-Fifth Dynasty, Kushite rulers conquered Kemet and ruled as pharaohs. They used Kemetic royal forms while retaining traditions rooted farther south, continuing the long exchange and conflict between African civilizations of the same Nile world.

## Memory Becomes Institution

Medu Neter joined sound, image, object, title, number, ritual, and sacred association in writing used for administration and religion. The House of Life trained scribes, copied texts, preserved calendars, and maintained medical and ritual knowledge. Names could remain legible beyond the lives of those who first wrote them.

Each generation received knowledge it had not first discovered and records it had not first written. Measuring, copying, teaching, and building kept that inheritance usable. As power and surplus grew, Ma'at depended on the work of passing it to those who would come next.''',
    linkMap: [
      KemeticNodeLink(phrase: "Kemet", targetId: "kemet"),
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "House of Life", targetId: "house_of_life"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "maat",
    title: "Ma'at",
    glyph: "𓆄",
    aliases: [],
    body: r'''What holds when no one is watching?

The Egyptian word *ma’at* encompasses truth, justice, and order. It names the order established at creation and the conduct expected of people within it. A king was responsible for preserving ma’at throughout his reign. An individual could appeal to it in giving an account of their life.

The goddess Ma’at gave these meanings a visible form: a woman wearing a tall feather, sometimes represented by the feather alone. Carved scenes on temple walls show the king presenting a small figure of her to a god. The offering expresses the responsibility of his office—to maintain order and justice on the gods’ behalf.

## The Standard Is Practical

An account of living by ma’at gives that responsibility particulars. In his autobiographical inscription, the granary overseer Baki describes his service to the king alongside his treatment of parents, elders, and others. He says he did not rob or harm people, and that he spoke truthfully. These are the actions he puts forward as evidence of his character. He expects that character to be assessed in a court after death.

## The Feather

In funerary judgment scenes, the deceased’s heart is weighed against Ma’at’s feather, or sometimes a small image of the goddess. Ma’at supplies the standard for the assessment. The declarations associated with judgment make its requirements specific.

In the *Book of Coming Forth by Day*, commonly called the *Book of the Dead*, the deceased denies stealing, lying, causing hunger, and taking another person’s land. A just balance and honest weights belong among the requirements of Ma’at: the Declarations of Innocence deny altering the weights or diverting water from its course. Obligations to the gods and the dead include protecting food offerings. Truth and justice reach into the things by which a household keeps its livelihood.

The deceased then tells the divine judges they have fed the hungry, given water to the thirsty, clothed the naked, provided a boat for someone needing passage, and made offerings to the gods and departed. These acts form part of the same justification as the denials. Alongside the claim to have caused no hunger stands the claim to have fed someone who was hungry.''',
    linkMap: [
      KemeticNodeLink(phrase: "heart", targetId: "ib"),
      KemeticNodeLink(
        phrase: "Book of Coming Forth by Day",
        targetId: "book_of_the_dead",
      ),
    ],
  ),
  KemeticNode(
    id: "isfet",
    title: "Isfet",
    glyph: "𓆙",
    aliases: [],
    body: r'''Isfet is what happens when right relation is not maintained.

The term includes chaos, disorder, falsehood, and wrongdoing. Violence and usurpation belong to it, as do false records, dishonest measures, and obligations left unattended.

The royal formula places Ma'at “in the place of Isfet.” Keeping it there requires continuing work.

## Isfet Spreads

Apepi threatens Ra's night journey and the return of dawn. The serpent's threat recurs, and the response must recur with it.

One false count can undo much good. Entered into a grain record, it produces a bad levy and harms a household. Left uncorrected, it can become a precedent: the next decision inherits the wrong in the last one.

## Disorder With Intelligence

Skill can give wrongdoing greater reach. A trained scribe can make a false record convincing; a ruler can give force the standing of law; a speaker can make distortion sound measured. Knowledge, ritual, authority, and tradition remain answerable for what their use produces.

Repair has to reach the place where the wrong continues: the record corrected, the boundary restored, the harm stopped, what is owed returned. Until then, later decisions still proceed under its effects. A correction gives the next action a sounder place to begin.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
      KemeticNodeLink(phrase: "Apepi", targetId: "serpent"),
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
    ],
  ),
  KemeticNode(
    id: "palermo_stone",
    title: "Palermo Stone",
    glyph: "𓆳",
    aliases: ["Royal Annals", "Early Royal Chronicle", "Annals Stone"],
    body:
        r'''The Palermo Stone is broken, but it still shows what early kingship wanted remembered.

Its fragments preserve royal annals: kings in sequence, reigns divided into years, and events entered within them. Rites, offerings, cattle counts, building activity, and Nile heights share the record.

## A Year Had Contents

The acts of a reign were written into particular years: a flood measured, cattle counted, a ceremony held, an act of administration recorded. Sacred events and material conditions occupy the same account.

The flood level affected cultivation, taxation, storage, and expectations for the coming year. Recorded beside a king's acts, it keeps the conditions of his rule visible alongside what he did.

## Memory Under Measure

A royal account favors what its makers want remembered. Even so, a dated entry places an event under a particular ruler in a particular year. Djehuty's work of measure gives a later reader something definite to examine.

The stone survives in fragments, with a selection of events rather than a whole history. Within that record, dates, measures, names, and responsibility remain attached to one another. A claim can be brought back to what was recorded.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
    ],
  ),
  KemeticNode(
    id: "wadi_el_jarf_papyri",
    title: "Wadi el-Jarf Papyri",
    glyph: "𓏞",
    aliases: ["Diary of Merer", "Khufu Harbor Papyri", "Old Kingdom Work Logs"],
    body:
        r'''The Wadi el-Jarf Papyri make the Great Pyramid smaller in the best possible way.

Among them is the diary of Merer, an inspector whose crew transported limestone during Khufu's reign. He records where his men went, what they carried, and when they arrived. Through those entries, the great building operation becomes a succession of boats, routes, deliveries, and days.

## Monument Becomes Logistics

Stone had to be quarried, then moved along river and canal routes. Crews needed provisions, officials coordinated timing, and deliveries had to arrive in sequence. Records accompanied the work as it moved.

Akhet-Khufu, the “horizon of Khufu,” depended on thousands of these coordinated actions. Faithfulness in the small task helped make the great work possible: a boat arriving, a delivery recorded, a handoff made at the right time.

## Record Prevents Scale From Becoming Chaos

Merer's notes place Djehuty's measure within the making of sacred architecture. The monument's purpose depended on work that could be followed and coordinated, delivery by delivery.

The diary lets the pyramid be understood at the scale where people could actually build it.''',
    linkMap: [KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty")],
  ),
  KemeticNode(
    id: "imhotep",
    title: "Imhotep",
    glyph: "𓉴",
    aliases: ["Imhotep"],
    body:
        r'''The Step Pyramid has been standing for roughly forty-five centuries.

Imhotep served Djoser in the Third Dynasty and became associated with royal monumental building in large-scale stone. Later generations remembered him as architect, scribe, healer, and eventually a divine figure, bringing his name into several forms of knowledge put to use.

## The Step Pyramid as Proof

A wise builder begins with what will hold. Foundations must carry the stone above them; blocks must be quarried, transported, shaped, and placed, with a large labor force working together. Geometry, materials, supervision, correction, and time all entered the construction.

Ptah's conception taking form and Djehuty's measure meet in this work. The plan has to remain recognizable as it passes into material, through the hands that build it.

## Why He Endured

Centuries after his death, Imhotep was remembered as a sage and healer. He could be shown seated with a papyrus across his knees, an image that joined building with writing, healing, and advice in the memory of one life.

Each asks something of knowledge: a plan must become a structure, a treatment must heal, and a teaching must be usable by its recipient. Careful conception, honest measurement, and disciplined work give it a chance to endure in what it makes possible for someone else.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ptah", targetId: "ptah"),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
    ],
  ),
  KemeticNode(
    id: "house_of_life",
    title: "House of Life",
    glyph: "𓉐𓋹",
    aliases: ["Per Ankh", "House of Living Knowledge", "Temple Scriptorium"],
    body:
        r'''The House of Life was where knowledge was kept alive by being used.

The Per Ankh belonged to the temple world. Its work included copying, ritual texts, medicine, sacred literature, and other specialized knowledge. The words kept there could pass from a written page into practice.

## Knowledge Had to Remain Usable

A ritual text supplied words to perform; a calendar kept time; a medical text guided treatment; a funerary composition equipped the dead.

Papyrus Chester Beatty IV describes how a writer's name can endure in copied words after a monument has decayed. Knowledge and memory could travel beyond the life of the object that first carried them.

## Accuracy Is Part of the Sacred Work

A copied error can change a name, a quantity, a ritual sequence, or a formula. Djehuty's care for accuracy belongs within the act of preservation: what is passed on must remain trustworthy enough to use.

People had to read, understand, test, and apply the knowledge they received, then teach it diligently enough for another person to use it. Accuracy mattered each time the practice changed hands.''',
    linkMap: [
      KemeticNodeLink(
        phrase: "Papyrus Chester Beatty IV",
        targetId: "papyrus_chester_beatty_iv",
      ),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
    ],
  ),
  KemeticNode(
    id: "rekh_wer",
    title: "Rekh-Wer",
    glyph: "𓁹𓏞",
    aliases: ["Great Burning", "Rḫ Wr", "Rekh Wer"],
    body: r'''Rekh-Wer is a calendar name before it is a philosophy.

Its conventional meaning is “Great Burning,” paired with Rekh-Nedjes, “Little Burning.”

## A Name Inside the Calendar

The 365-day civil calendar moved gradually against the natural solar year. Over long periods, a named month passed through different seasons. Rekh-Wer kept its name as the weather surrounding it changed.

## What hꜣw Can Carry From It

In hꜣw's Peret sequence, Great Burning gives an image of knowledge tried under pressure. A method meets fatigue, resistance, and repetition; what has been learned must still be able to guide the action.

Ma'at gives that pressure a measure. Pressure can refine what is sound, but intensity that damages what it was meant to strengthen becomes Isfet.''',
    linkMap: [
      KemeticNodeLink(phrase: "hꜣw", targetId: "haw"),
      KemeticNodeLink(phrase: "Peret", targetId: "peret"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
      KemeticNodeLink(phrase: "Isfet", targetId: "isfet"),
    ],
  ),
  KemeticNode(
    id: "ptah",
    title: "Ptah",
    glyph: "𓊪𓏏𓎛",
    aliases: [],
    body: r'''Ptah creates before the hand moves.

In the Memphite Theology, creation begins in the heart and becomes effective through the tongue. What is conceived takes form through expression. Ptah brings intention and utterance into agreement.

## Heart, Tongue, Hand

Ptah is shown mummiform, holding signs of life, stability, and authority. His contained figure gives the inward act a form of its own, before the hand begins to move.

The account survives on the Shabaka Stone, a Twenty-Fifth Dynasty monument from around 710 BCE. The inscription says it preserves an older, damaged source.

Perception reaches the heart, and the heart teaches the tongue what to say. Utterance gives what was conceived a place in the world. In ritual and craft, that movement continues into what is made: an offering directed, a decree expressed, stone shaped according to a plan.

## Creation Is Responsible

Thought and speech help shape the world people share. What is repeatedly thought, said, and built has consequences, including those no one intended.

The Instruction of Ptahhotep asks that speech remain within knowledge. Djehuty brings measure to the work, and Imhotep gives knowledge a durable structure. The intention must survive each step into what is made; even a well-meant structure needs correction if it fails.''',
    linkMap: [
      KemeticNodeLink(phrase: "heart", targetId: "ib"),
      KemeticNodeLink(
        phrase: "Instruction of Ptahhotep",
        targetId: "instruction_ptahhotep",
      ),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
      KemeticNodeLink(phrase: "Imhotep", targetId: "imhotep"),
    ],
  ),
  KemeticNode(
    id: "shu",
    title: "Shu",
    glyph: "𓇯𓇾",
    aliases: [],
    body: r'''Shu is the space that lets things become themselves.

In the Heliopolitan creation tradition, Shu divides the sky above from the earth below, lifting Nut away from Geb. Their separation opens the room in which air and light can move, allowing sky and earth to function.

## The Space Between

Associated with air, light, and lifting, Shu is repeatedly invoked in the Pyramid Texts as the one who raises the sky and helps lift the deceased upward.

Light travels through the space he opens. Breath moves, birds fly, and the sun has room to complete its journey. Separation allows these things to remain distinct while belonging to the same world.

## Separation Is Not Rejection

A relationship needs enough room for two people to remain themselves. A household needs to distinguish what is shared from what belongs to each person; fair judgment needs to distinguish what happened from what someone wished had happened. Such boundaries give relation a workable shape.

Shu wears his own feather emblem, distinct from Ma'at's. The resemblance brings two parts of order into view: joining what belongs together and allowing what is distinct to have its space.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nut", targetId: "nut"),
      KemeticNodeLink(phrase: "Pyramid Texts", targetId: "pyramid_texts"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "nut",
    title: "Nut",
    glyph: "𓇯",
    aliases: ["Sky Mother", "Celestial Vault", "Mother of Stars"],
    body: r'''Nut is the sky as body.

She arches over the earth with the stars within her. In the west she receives the sun, carries it through the night, and gives birth to it again in the east. Her protection also surrounds the dead: in funerary imagery, the coffin can become an enclosure of sky.

## The Body Above

Ra's daily course passes through a mother's body, from being swallowed at evening to rebirth at dawn. The heavens hold the stars and carry the sun through its disappearance.

Beneath Nut, the dead are held as a child is held by its mother. Coffin lids can identify with her body, placing the deceased beneath a sky that is also a womb. Night and death take on the possibility of being carried through a change whose outcome is still hidden.

## Holding Is Work

A seed has soil around it; a body has a tomb; a thought can have time before it is spoken. Protection gives a change room to proceed. Ma'at includes this care for what is still becoming.

Nut carries Ra until she releases him. The enclosure has served its purpose when what it holds is ready to emerge.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "ra",
    title: "Ra",
    glyph: "𓇳",
    aliases: [],
    body: r'''Ra is not simply the sun.

He is the sun completing its course. Kemetic solar imagery follows his movement through danger, disappearance, renewal, and return. Shining belongs to a cycle that continues after the light has gone.

## Khepri, Ra, Atum

Khepri names the sun becoming visible at dawn. Ra is solar power fully underway; Atum is its completion, the setting form entering the west. The three names mark stages of one course.

In the solar barque, Ra crosses the day and enters the Duat at evening. The Amduat gives the night twelve hours, through which he passes opposition and finds renewal. In its deepest region that renewal is linked with Ausar, the power of restoration within death. By morning, he comes forth renewed as Khepri. Dawn brings into view what the night has carried through.

## Ra and Ma'at

The Book of Coming Forth by Day and related solar traditions repeatedly connect Ra's passage with Ma'at. His movement has direction, and his energy belongs to a course that includes descent as well as rising.

Activity can fill years while leaving what matters unfinished. Ra's full rhythm includes the hidden work through which energy is renewed. Return becomes possible because the passage through darkness has been completed.''',
    linkMap: [
      KemeticNodeLink(phrase: "Khepri", targetId: "khepri"),
      KemeticNodeLink(phrase: "Duat", targetId: "duat"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(
        phrase: "Book of Coming Forth by Day",
        targetId: "book_of_the_dead",
      ),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "khepri",
    title: "Khepri",
    glyph: "𓆣",
    aliases: ["Scarab", "Becoming", "Morning Sun", "Dawn Form of Ra"],
    body: r'''Khepri is the moment when becoming becomes visible.

The scarab rolls its rounded ball across the ground and works with buried material. Later, beetles can appear from what was hidden. These behaviors could suggest self-generation and return to ancient observers, giving Khepri a living form as the dawn aspect of Ra: solar power coming into being again.

## Becoming Happens Before Appearance

Dawn can look sudden. The sun has already made its night journey by the time it appears.

We can watch a life change without knowing all that made it grow. A practiced skill may suddenly look effortless; a decision may become clear after months of confusion. A restored life can look new to people who never saw the work done in darkness. The Duat gives that hidden phase a sacred structure, and Khepri is the emergence that follows it.

## Becoming Is Not Escape

The dawn sun is still Ra. Becoming carries something forward through change, allowing it to fulfill its purpose in another form.

The scarab works with the material before it until another form becomes possible. At a threshold, some things are ready to emerge while others still need time in the dark.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Duat", targetId: "duat"),
    ],
  ),
  KemeticNode(
    id: "khnum",
    title: "Khnum",
    glyph: "𓃝",
    aliases: ["Ram Creator", "Potter of Life", "Lord of the Wheel"],
    body: r'''Khnum creates with his hands.

At his potter's wheel, water makes clay workable and pressure slowly gives it form. Khnum is associated with formation, birth, the body, and the Nile region around the First Cataract. His creative work has the closeness of hands attending to material.

## The Potter's Wheel

Too much pressure collapses the vessel's wall; too little leaves it unformed. The hand has to feel what the clay can take and adjust as it works.

Intention meets the conditions of what is being shaped. Bodies have limits and crafts have grain; a teacher, too, has to attend to how understanding develops in a student.

## Body and Ka

In scenes of Khnum at work, body and ka take form together under the potter's hands. Material structure and animating presence are prepared in relation, the vessel alongside what will live through it.

Purpose needs a form capable of carrying it: tools, routines, and spaces that can sustain what is intended. Ptah gives conception its place in creation; Khnum attends to the shaping. Form affects what can live within it, and careful work gives that life a durable place to stay.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "ka", targetId: "ka"),
      KemeticNodeLink(phrase: "Ptah", targetId: "ptah"),
    ],
  ),
  KemeticNode(
    id: "djehuty",
    title: "Djehuty",
    glyph: "𓅝",
    aliases: ["Thoth", "Djehuty"],
    body:
        r'''Djehuty keeps the loudest voice from deciding what counts as truth.

Writing, reckoning, measurement, the moon, time, speech, and divine record fall within his care. Each depends on recognizing things clearly enough to count them, name them, and remember them.

## Measure Before Judgment

An account may seem right before it has been examined. Judgment requires a hearing and an honest measure. In the Hall of Two Truths, Anpu steadies the scale, Ma'at's feather supplies the standard, and Djehuty records the result. What is written must answer to what the measure reveals; desire has no place to alter the weight.

Calendars, boundaries, offerings, taxes, and ritual timing depend on the same care. A count carries consequences into everything arranged by it.

## Ibis, Baboon, Moon

The ibis probes beneath the surface at the waterline. The baboon greets dawn and marks its return. The moon changes continually, yet its phases remain measurable. Djehuty's forms bring careful attention to what is there.

## Exact Speech

The wisdom tradition asks that speech stay within knowledge. An imprecise promise, accusation, or instruction can become harder to correct once it has entered a record and other people have begun to rely on it.

Care passes from perception into measure, from measure into record, and from record into what is said and remembered. Exactness gives others something they can trust.''',
    linkMap: [
      KemeticNodeLink(phrase: "Anpu", targetId: "jackal"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "ausar",
    title: "Ausar",
    glyph: "𓊨𓁹",
    aliases: ["Asar", "Osiris", "Wsir"],
    body:
        r'''Ausar is the god who is restored without having death erased from his story.

Set kills and scatters him. Aset searches, Nebet-Het mourns and attends, and Anpu prepares the body; Heru gathers, restores, and succeeds him. Ausar becomes ruler in the Duat. His restored form carries the history of the wound into this new role.

## Gathered, Not Replaced

Restoration gathers what was scattered and binds the broken parts together. The Pyramid Texts repeatedly describe Heru gathering his father's limbs, finding the pieces and placing them in relation so the body can be whole.

The dead likewise needed body, ka, ba, ren, ib, sheut, memory, and offering kept together. Ausar gave funerary thought a form for this work of assembly, through which continuation became possible.

## Renewal in the Hidden Place

Ra travels at night through the Duat where Ausar rules. In the Amduat, solar renewal reaches its deepest point in this hidden world. Restoration is already taking place while the sun is out of sight.

Seed enters the earth, flood covers the land, and grain disappears before returning as food. These processes gave Kemet repeated occasions to recognize renewal within disappearance.

## Vindication

Restoring Ausar also requires an answer to the wrong against him. Heru's claim must be recognized; Set's temporary success cannot give his force legitimacy. The dead, too, seek to become “true of voice” before continuing.

Repair includes establishing the truth of what happened. What has been gathered must be made stable enough for those who come after it to inherit more than the damage.''',
    linkMap: [
      KemeticNodeLink(phrase: "Set", targetId: "set"),
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Nebet-Het", targetId: "nebet_het"),
      KemeticNodeLink(phrase: "Anpu", targetId: "jackal"),
      KemeticNodeLink(phrase: "Heru", targetId: "heru"),
      KemeticNodeLink(phrase: "Duat", targetId: "duat"),
      KemeticNodeLink(phrase: "Pyramid Texts", targetId: "pyramid_texts"),
      KemeticNodeLink(phrase: "ka", targetId: "ka"),
      KemeticNodeLink(phrase: "ba", targetId: "ba"),
      KemeticNodeLink(phrase: "ren", targetId: "ren"),
      KemeticNodeLink(phrase: "ib", targetId: "ib"),
      KemeticNodeLink(phrase: "sheut", targetId: "sheut"),
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Kemet", targetId: "kemet"),
      KemeticNodeLink(phrase: "true of voice", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "aset",
    title: "Aset",
    glyph: "𓊨",
    aliases: ["Isis", "Aset"],
    body: r'''Aset rarely wins by using more force.

She puts wisdom to work: searching for what is hidden, sheltering what is vulnerable, and speaking when words can change the situation. Heka, effective sacred power, belongs to this resourceful work. Her care depends on finding where an action can make a difference.

## She Finds What Was Scattered

After Ausar is killed and dismembered, Aset searches for what has been lost. Nebet-Het attends the mourning and restoration, Anpu prepares the body, and Heru eventually completes the succession. Aset begins by finding what can still be brought together.

Her wings over Ausar became an enduring funerary image of protection. Breath, enclosure, presence, and care surround what can still be restored.

## The Secret Name of Ra

To gain Ra's hidden name, Aset fashions a serpent from his own substance and creates a crisis only she can resolve. She withholds the cure until he reveals the name.

Her intelligence has found the point at which the situation can change. The story gives that power an uncomfortable use: she creates the danger through which she gains what she seeks.

## Protecting Heru

With the young Heru, Aset uses concealment, patience, protection, and time. Someone who is not ready needs shelter from a fight until they are strong enough to enter it.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Nebet-Het", targetId: "nebet_het"),
      KemeticNodeLink(phrase: "Anpu", targetId: "jackal"),
      KemeticNodeLink(phrase: "Heru", targetId: "heru"),
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "serpent", targetId: "serpent"),
    ],
  ),
  KemeticNode(
    id: "nebet_het",
    title: "Nebet-Het",
    glyph: "𓎟𓉐",
    aliases: ["Nephthys", "Lady of the House", "Mistress of the House"],
    body:
        r'''Nebet-Het is the presence that keeps a threshold from becoming abandonment.

Often called “Lady of the House,” she stands beside Aset in mourning. In the Ausar cycle she attends the dead and guards their passage, remaining near those who have crossed out of ordinary life.

## Mourning Is Work

When Ausar is broken, Aset searches and acts while Nebet-Het attends to mourning. Lament, naming, preparation, and protection keep the dead within social and ritual care.

Someone must remain near those who can no longer speak for themselves. Nebet-Het gives that quiet work a presence.

## The Edge of the House

Between inside and outside, the living and the dead, the known and the hidden, care can fall away because everyone assumes someone else is providing it. Nebet-Het attends these boundaries.

A funeral or a hospital room may ask someone to sit beside the grieving and weep with them. There may be no word that makes the passage easier. Ma'at gives weight to remaining there, keeping company through what no one can hurry or solve.''',
    linkMap: [
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "heru",
    title: "Heru",
    glyph: "𓅃",
    aliases: ["Horus", "Heru"],
    body: r'''Set is stronger.

Heru has the rightful claim. In the Contendings of Heru and Set, occupying a position leaves the question of legitimacy unsettled. Relation, duty, and judgment must establish who belongs there.

## The Son Who Tends His Father

Heru honors his father by tending what has been broken. The Pyramid Texts repeatedly describe him gathering Ausar's limbs, providing for him, and restoring what was damaged. The inheritance reaches him as work to be done.

Lineage places Heru in the succession; what he does for his father demonstrates his fitness to continue it.

## Contest and Recognition

A throne is made secure through the right relation it preserves. Set can defend, fight, and seize; his strength keeps the dispute alive. Heru's claim rests on continuity through Ausar, and the divine tribunal must determine which claim can sustain order beyond the contest.

Force has necessary uses, but the tribunal’s judgment concerns everyone who will live beneath that authority.

## Heru in the Living King

The living pharaoh could be identified with Heru, while the dead king entered the Ausar pattern. Kingship formed a chain in which the living heir tended, restored, and continued what came before.

An inherited responsibility carries work with it. Fitness appears in what the holder tends and restores, and in what becomes more whole under their care. Heru's legitimacy takes shape in that care before he defends it through power.''',
    linkMap: [
      KemeticNodeLink(phrase: "Set", targetId: "set"),
      KemeticNodeLink(phrase: "Pyramid Texts", targetId: "pyramid_texts"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
    ],
  ),
  KemeticNode(
    id: "set",
    title: "Set",
    glyph: "𓃩",
    aliases: ["Seth", "Sutekh", "Adversarial Force", "Red Land Power"],
    body: r'''Set is not chaos in animal form.

Storm, desert, conflict, protection, and rivalry belong to his power. Such force can be necessary and dangerous. It violates order when strength begins to treat itself as its own law.

## Force at the Boundary

The Red Land could kill, yet it protected the Nile valley and supplied routes, stone, and resources. A boundary could preserve life and require force to hold it.

Set appears as a defender as well as an adversary. Apepi obstructs the solar cycle itself; Set's dangerous strength can still have a place within the order it defends.

## The Crime Against Ausar

Set turns his force against rightful relation when he kills and scatters Ausar. Succession breaks, and the center is attacked by a power that should have helped defend the whole.

The Contendings with Heru carries this injury into the question of authority. Seizing a position leaves the rightful claim unresolved.

## Pressure Reveals Structure

Pressure can expose weakness in an unchallenged claim or reveal whether a boundary can hold. Set gives trial a place in the discovery of what is stable.

Some threats require confrontation. What strength makes possible must still be judged by what it sustains. Its place in Ma'at depends on whether it protects the relations that allow the whole to continue.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Apepi", targetId: "serpent"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Heru", targetId: "heru"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "jackal",
    title: "Jackal (Anpu)",
    glyph: "𓃢",
    aliases: ["Anubis", "Anpu"],
    body: r'''The jackal was seen where the dead were placed.

Wild canids moved along the desert edge near burial grounds, between cultivated land and the necropolis. From this landscape Anpu attends the passages of the dead through embalming, protection, and the weighing of the heart.

## Black Like Fertile Earth

Anpu's black color can evoke rich Nile silt, regeneration, and renewed fertility. Even as the body decays, the color suggests renewal.

Natron, wrapping, anointing, ritual speech, and preservation make that preparation practical. The body continues to receive care.

## He Holds the Scale

Anpu keeps the balance just. In the Hall of Two Truths, he steadies it so that the relation between heart and feather can be known accurately. His care lies in the holding: Ma'at supplies the standard, and Djehuty records what the scale reveals.

## What Boundaries Need

The necropolis, embalming chamber, tomb entrance, and judgment hall each require care between one condition and another. A passage can fail when no one attends to this work.

Anpu prepares the body, holds the scale, and guards the threshold. His guidance makes the passage possible while leaving its outcome to what is true.''',
    linkMap: [
      KemeticNodeLink(phrase: "heart", targetId: "ib"),
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Natron", targetId: "natron"),
      KemeticNodeLink(phrase: "Hall of Two Truths", targetId: "maat"),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
    ],
  ),
  KemeticNode(
    id: "serpent",
    title: "Serpent",
    glyph: "𓆙",
    aliases: ["Apophis", "Mehen"],
    body: r'''No single meaning can contain the serpent in Kemetic thought.

A serpent can obstruct Ra or protect him, defend a king, carry venom, reveal hidden knowledge, or guard nourishment. Its position and relation give the recognizable form its character.

## Apepi and Mehen

Apepi seeks to stop the solar barque and prevent dawn. Mehen coils around Ra to protect him. One serpent threatens the passage that the other makes secure.

## The Uraeus

Set upon the king's brow, the rearing cobra of the uraeus directs danger outward. It warns and protects. The form that can threaten life can also stand guard over it.

## Aset's Serpent

Aset fashions a serpent and uses the crisis it creates to gain Ra's hidden name. The crisis becomes part of a deliberate strategy.

Power takes its direction from what it serves. To distinguish Ma'at from Isfet requires attention to what a force protects or interrupts and who directs it. The serpent's form can carry danger into either protection or obstruction.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
      KemeticNodeLink(phrase: "Isfet", targetId: "isfet"),
    ],
  ),
  KemeticNode(
    id: "hathor",
    title: "Hathor",
    glyph: "𓃒",
    aliases: [],
    body: r'''Hathor refuses to fit into one mood.

Sky and cow, motherhood and sexuality, music, joy, intoxication, welcome, the western horizon, and the Eye of Ra all belong to her. These roles reach across the conditions through which the power of life becomes livable.

## Joy Is Not Outside the Sacred

The sistrum, music, beer, dance, beauty, and festival make room for a glad heart. Hathor gives these pleasures a place in the life that Ma’at sustains.

Such gladness can do a person good. Music brings bodies into rhythm together; celebration renews relationships. Beauty makes order felt, and delight gives people a way to be restored.

## The Eye Comes Home

Hathor is also connected with the Eye of Ra, a solar power that can become destructive when distant or enraged. In stories of the wandering Eye, welcome, music, drink, and reunion bring that dangerous heat back into relation.

Sekhmet and Hathor can express different conditions of the same power: burning force and returning delight. What has gone to an extreme needs a way home.

## Lady of the West

Hathor receives the dead at the western horizon, where the sun enters the hidden region. Her welcome reaches from joy at the beginning of life to a threshold people fear.

Pleasure, beauty, and warmth help make a stable life worth inhabiting.''',
    linkMap: [
      KemeticNodeLink(phrase: "Eye of Ra", targetId: "eye_of_ra"),
      KemeticNodeLink(phrase: "Sekhmet", targetId: "sekhmet"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "eye_of_ra",
    title: "Eye of Ra",
    glyph: "𓁹",
    aliases: ["Solar Eye", "Daughter of Ra", "Active Sight"],
    body: r'''The Eye of Ra is sight that can leave the one who sees.

In Kemetic stories, the Eye moves outward as a daughter, goddess, cobra, or lioness. It can protect or destroy. Ra's sight becomes an active force with the dangerous capacity to leave him and act in the world.

## Sight Becomes Action

Something is seen, and power goes out in response. The Eye carries perception into action; difficulty begins when that action exceeds the need.

Sekhmet can embody its destructive heat, while Hathor can embody its pacified, generative return. The uraeus places the Eye at the royal brow as active protection. Its forms show what can follow from seeing.

## The Distant Eye

The Eye leaves Ra, becomes independent, and needs to be brought back. Without it he is diminished, while its distance from him can make its power dangerous.

Attention can narrow into obsession, protection turn into aggression, or a response continue after the conditions that called it forth have changed. Return keeps action from outlasting its purpose.

## Seeing Is Not Enough

Ma'at holds perception, action, and proportion in relation. What has been seen may require a response strong enough to restore what is threatened.

Power must also be able to govern its own response. When its purpose has been met, the Eye must be able to return; otherwise action continues as wrath.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Sekhmet", targetId: "sekhmet"),
      KemeticNodeLink(phrase: "Hathor", targetId: "hathor"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "sekhmet",
    title: "Sekhmet",
    glyph: "𓃭",
    aliases: ["The Powerful One", "Eye of Ra", "Lioness Fire"],
    body: r'''Sekhmet is what happens when order needs teeth.

Her lioness heat joins plague and protection, royal terror and healing. The force that destroys can also burn corruption out of the body. Her dangerous and protective powers meet threats that cannot always be soothed away.

## The Eye Sent Forth

In the Book of the Heavenly Cow, Ra sends his Eye against rebellion, with Hathor named in the destructive role. Sekhmet also belongs to the wider tradition of this dangerous, punitive Eye.

The destruction must eventually stop. Red beer pacifies the raging Eye and turns its consuming force away from bloodshed. A response begun with a purpose has exceeded its measure.

## Healing and Harm

Heat can kill or purge; a blade can wound or remove what is killing the body. Sekhmet's healing power carries this demand for precision. The same intervention can help or harm according to its dose and place.

## The Necessary Limit

Sekhmet's force is terrifying. A boundary may require defense, a disease aggressive treatment, or a violent threat resistance; protection can call on dangerous powers.

Anger may answer a threat; it must still answer to what needs protecting. Sekhmet’s force has to reach the danger and stop where its work is done. Allowed to continue beyond that point, a response begins to feed its own appetite.''',
    linkMap: [
      KemeticNodeLink(
        phrase: "Book of the Heavenly Cow",
        targetId: "eye_of_ra",
      ),
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Hathor", targetId: "hathor"),
    ],
  ),
  KemeticNode(
    id: "sopdet",
    title: "Sopdet (Sirius)",
    glyph: "𓇼",
    aliases: ["Sopdet", "Sothis", "Sirius"],
    body: r'''Sopdet is Sirius at the moment it returns.

Sirius, the brightest star in the night sky, became a major annual marker in Kemetic timekeeping. Its heliacal rising is its first visible appearance before sunrise after a period out of sight. In the Old Kingdom, that return fell near the season of Nile inundation, bringing star, river, and year into relation.

## Seventy Days of Absence

Sirius disappears into the sun's glare before returning to view. The interval varies with place and era; its familiar reckoning at roughly seventy days became associated with embalming.

Sopdet was associated with Aset, and Sah (Orion) with Ausar. Their movements gave restoration a visible annual rhythm, joining the calendar and flood with royal and funerary images of renewal.

## A Fixed Reference

Sopdet's return became a sign for the season and the year, a starting point from which to follow the other stars and the calendar. Repeated observation supported the decanal system. Djehuty's work of measurement begins with such a reference: something known well enough for a count to proceed from it.

## The Long Drift

The civil calendar counted 365 days, leaving out the solar year's extra quarter-day. Over many centuries it drifted away from the seasons and Sopdet's rising, then returned to alignment. The count could remain consistent within itself even as it moved away from the event it once marked.

Sopdet continued to return. Careful watching made that rhythm recognizable and trustworthy, a way to find direction in the natural order of Ma'at.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Sah (Orion)", targetId: "sah"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "sah",
    title: "Sah (Orion)",
    glyph: "𓇼𓇼𓇼",
    aliases: ["Orion", "Sah"],
    body:
        r'''Sah is conventionally identified with Orion in the Kemetic sky. That identification is strong, but the ancient figure should not be forced star-for-star into the modern constellation boundaries and line drawing.

Sah was closely associated with Ausar (Osiris), and Sopdet (Sirius) with Aset. Their movements gave death and restoration a place in the night sky, where the sacred story could be watched as well as told.

## The Striding One

Orion is among the easiest large constellations to recognize. Its movement across the night, seasonal disappearance, and return made Sah a companion to Ausar. The Pyramid Texts place the ascending king with Orion and Sopdet, within this recognizable celestial order.

## Return Without Permanence

The circumpolar, imperishable stars remain above the horizon. Sah disappears and returns, carrying another form of continuity: the renewed presence of Ausar after what has happened to him.

## What the Sky Teaches

The order of the heavens could be watched in Sah's course. Generations learned to recognize its movement, disappearance, and return. Its position changed, but the relationships that made the figure recognizable endured, including through the season when it passed out of sight. Ma'at is present in that steadiness within movement.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar (Osiris)", targetId: "ausar"),
      KemeticNodeLink(phrase: "Sopdet (Sirius)", targetId: "sopdet"),
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Pyramid Texts", targetId: "pyramid_texts"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "decans",
    title: "Decans",
    glyph: "𓇼𓇼𓇼",
    aliases: [],
    body: r'''The decans turned the night sky into a clock.

These star groups were observed in sequence across the year. Middle Kingdom diagonal star tables and later astronomical ceilings preserve their use in reckoning the night, linking stellar risings with hours, ten-day periods, months, and seasons.

## A Clock Made of Stars

On coffin lids, diagonal rows of star names relate each ten-day period to the stars marking successive hours of the night. Someone trained to read them could look to the sky and locate themselves in time.

That orientation belonged with the dead as well. Their passage had gates, hours, and sequences to follow; the star clock placed above them gave the night a structure through which they could find their way.

## Ten Days at a Time

The civil year held twelve thirty-day months and five epagomenal days, with three ten-day periods in each month. hꜣw follows this rhythm as a way of numbering our days with attention. Its reflective themes give time to notice what has changed and consider it before the month ends.

## Why the Decans Matter Here

As the stars move and the night changes, their recurring relationships let an observer follow the hours.''',
    linkMap: [
      KemeticNodeLink(phrase: "epagomenal days", targetId: "epagomenal_days"),
      KemeticNodeLink(phrase: "hꜣw", targetId: "haw"),
    ],
  ),
  KemeticNode(
    id: "dendera",
    title: "Dendera",
    glyph: "𓉗",
    aliases: [],
    body: r'''Dendera puts the sky on the ceiling.

The surviving temple of Hathor is largely Greco-Roman, built within a much older sacred tradition at the site. Astronomical ceilings, decanal imagery, ritual texts, crypts, and rooftop spaces bring time, divine presence, and festival into the building's life.

## A Temple That Orients

Stars, decans, planets, and constellations spread across the stone ceilings, placing ritual beneath a visible cosmos. The circular zodiac brings older Kemetic astronomical material together with zodiacal forms received through the Hellenistic world. A continuing tradition has made room for these forms within its own sky.

## Hathor and the Return of the Eye

Music, sistrums, procession, and sacred drink belong to Hathor's festivals at Dendera. Joy has work to do here: welcoming the distant or dangerous Eye of Ra brings it home.

## The Roof and the New Year

Festival had its season, and the divine image its appointed place. At moments of renewal, movement toward the roof brought the image into relation with solar light. Architecture, timing, and action met in the observance.''',
    linkMap: [
      KemeticNodeLink(phrase: "Hathor", targetId: "hathor"),
      KemeticNodeLink(phrase: "decans", targetId: "decans"),
      KemeticNodeLink(phrase: "Eye of Ra", targetId: "eye_of_ra"),
    ],
  ),
  KemeticNode(
    id: "architrave",
    title: "Architrave",
    glyph: "𓉹",
    aliases: ["Temple Lintel", "Inscribed Beam", "Sacred Support"],
    body: r'''An architrave is the stone that carries what is above a passage.

People pass beneath it while the beam holds and the opening stays open. Its quiet support can be easy to overlook.

## Weight Has to Go Somewhere

Columns, beams, walls, and foundations distribute a building's weight. Each receives pressure and passes it on; a badly placed element can cause failure elsewhere. The architrave carries its share by receiving and redirecting what rests above it.

## Inscribed Support

Royal names, divine titles, and offering language often run across Kemetic architraves. Along with weight, the stone carries an account of the king, deity, and temple, naming those who maintain its sacred order.

## Bearing Without Display

People, habits, and institutions can provide this kind of unnoticed support, carrying pressure that allows something else to remain open. Their work belongs to Ma'at through the passage it sustains.

A load can become too heavy for the support carrying it. Those who hold a household or institution open need others to bear the burden with them. Holding it alone until the structure cracks defeats the purpose of keeping a passage open.''',
    linkMap: [
      KemeticNodeLink(phrase: "offering", targetId: "offering_formula"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "abydos",
    title: "Abydos",
    glyph: "𓊖",
    aliases: [],
    body: r'''Abydos became one of the great places of sacred memory in Kemet.

Early royal burials, a First Dynasty tomb later identified with Ausar (Osiris), pilgrimage, annual mysteries, private stelae, and royal ancestor lists gave people reasons to return. Memory gathered force in a place they could enter and take part in.

## Where Ausar Was Present

By the Middle Kingdom, Abydos was treated as Ausar's burial place. Processions and festivals enacted his death, mourning, restoration, and return. The mysteries drew people into the sacred cycle through their participation.

## Thousands of Names

Private individuals erected stelae at Abydos even when they could not be buried there. Their inscribed names kept them present near the sacred cycle. Through the Ren, a person could remain part of this community of memory beyond the body's location.

## The King List

In Seti I's temple, a sequence of earlier kings records a chosen lineage. Some rulers are absent from the Abydos King List; the names preserved make visible the inheritance the tradition wished to claim.

The generations to come would inherit the names this tradition kept before them. At Abydos, processions, festivals, and inscriptions gave that chosen memory a place they could enter, take part in, and pass on.''',
    linkMap: [
      KemeticNodeLink(phrase: "Kemet", targetId: "kemet"),
      KemeticNodeLink(phrase: "Ausar (Osiris)", targetId: "ausar"),
      KemeticNodeLink(phrase: "Ren", targetId: "ren"),
    ],
  ),
  KemeticNode(
    id: "duat",
    title: "Duat",
    glyph: "𓇽",
    aliases: ["Underworld", "Hidden Region", "Netherworld"],
    body: r'''The Duat is not simply “the underworld.”

Ra enters this hidden region each night, and the dead enter it after burial. Ausar rules there. Its gates and waters, beings and enemies, names and transformations give the passage a structure within the darkness.

## The Night Has Architecture

The Amduat maps twelve hours of the solar journey, each asking something different of the traveler. Renewal comes deep in the sixth hour; confrontation with Apepi follows later. Reaching dawn requires the whole passage, including what happens after strength has been renewed.

## The Dead Need Equipment

Even in the shadow of death, the traveler needs a passage to follow. The Book of Coming Forth by Day and related funerary traditions provide names, formulas, identifications, and protections for the journey. A gate has conditions the traveler needs to understand before passing.

The Ba must be free to travel, the Ren preserved, the heart ready for judgment, and the body maintained. These preparations keep the person from scattering and equip them to meet what the hidden region asks of them.

## Hidden Work

A seed develops underground. Grief may change someone before anyone else notices, and recovery can look inactive. The Duat gives sacred form to this interval when work is underway beyond the reach of ordinary sight.

Ma'at continues through that hidden work. Like the night passage with its gates, the process needs enough structure for a real transformation to emerge from it.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Apepi", targetId: "serpent"),
      KemeticNodeLink(
        phrase: "Book of Coming Forth by Day",
        targetId: "book_of_the_dead",
      ),
      KemeticNodeLink(phrase: "Ba", targetId: "ba"),
      KemeticNodeLink(phrase: "Ren", targetId: "ren"),
      KemeticNodeLink(phrase: "heart", targetId: "ib"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "ka",
    title: "Ka",
    glyph: "𓂓",
    aliases: [],
    body:
        r'''The Ka is one of the hardest Kemetic ideas to translate cleanly because “soul” is too broad and “life force” is too thin.

The Ka belongs to vitality, sustenance, inheritance, and continuing identity in life and after death. It can receive offerings, unite with the person it belongs to, and be satisfied. The raised arms of its written sign give that reception a visible form.

## What the Ka Needs

Funerary texts place bread, beer, and other provisions before the Ka. Sustenance continues through a relationship: the dead depend on those who provide it.

The tomb, offering formula, preserved name, and people maintaining the cult keep that provision possible. An offering needs someone it can reach, which is why erasing the recipient's name threatens more than remembrance alone.

## Ka and Ba

The Ba goes out and returns. The Ka is closer to an abiding presence, providing the point toward which it can return.

## The Human Meaning

A body needs its daily food, a relationship its contact, a craft its practice. Ma'at continues through the care that reaches them day after day. Even remembrance needs someone to speak the name once more.''',
    linkMap: [
      KemeticNodeLink(phrase: "offering formula", targetId: "offering_formula"),
      KemeticNodeLink(phrase: "Ba", targetId: "ba"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "ba",
    title: "Ba",
    glyph: "𓅽",
    aliases: [],
    body: r'''The Ba is the part of the person that can move.

Its familiar form in Kemetic art is a bird with a human head: the individual remains recognizable while moving beyond the body's ordinary range. Funerary texts give this movement practical requirements. The Ba needs to travel, pass doors, avoid imprisonment, and return.

## The Way Must Be Open

Spells in the Book of Coming Forth by Day equip the Ba to come forth, move through the hidden world, reach divine places, and find its way back. A gate that traps it interrupts that freedom, as does a departure from which it cannot return.

## Freedom Needs a Home

While the Ba travels, the Ka remains as a sustaining presence. Body, tomb, name, and offering cult keep the point of return recognizable, so that distance need not break the connection.

## The Ma'at of Movement

The Ba’s going out and coming in both need protection. Travel, ambition, and creativity may expand a life, provided the person remains connected to what keeps them coherent. That connection gives movement a home to return to, able to receive what the journey has made possible.''',
    linkMap: [
      KemeticNodeLink(
        phrase: "Book of Coming Forth by Day",
        targetId: "book_of_the_dead",
      ),
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
    ],
  ),
  KemeticNode(
    id: "akh",
    title: "Akh",
    glyph: "𓅜",
    aliases: [],
    body:
        r'''The Akh is what a person becomes when the parts hold together well enough to remain effective beyond ordinary life.

Luminous and capable, the Akh is an effective being. The Pyramid Texts repeatedly speak of becoming akh and place the successful dead among the imperishable stars.

## Not Just Survival

A body preserved, a name remembered, a Ba free to move, and a Ka sustained by offerings all contribute to continuation. The heart, ritual preparation, judgment, and memory belong to this work as well. Their effectiveness depends on their relation to one another.

## The Imperishable Stars

Circumpolar stars stay above the observer’s horizon. The Akhu join their enduring brightness, and a deceased king could be addressed as an imperishable star. Later funerary traditions extended an effective afterlife beyond kingship.

## Effectiveness Through Relation

The Pyramid Texts say that Heru becomes akh through Ausar. The one who restores another can also be changed through that care. Community, ritual, and memory participate in the same work of making continued effectiveness possible.

An effective life depends on these relations holding together. Through them, what remains of a person can still do good; Ma'at gives continuation this active purpose.''',
    linkMap: [
      KemeticNodeLink(phrase: "Pyramid Texts", targetId: "pyramid_texts"),
      KemeticNodeLink(phrase: "Ba", targetId: "ba"),
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
      KemeticNodeLink(phrase: "heart", targetId: "ib"),
      KemeticNodeLink(phrase: "Heru", targetId: "heru"),
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "ren",
    title: "Ren (Name)",
    glyph: "𓍷",
    aliases: [],
    body: r'''The Ren is the name as a living address.

Even in absence, a person could be called by name, remembered, recorded, invoked, and given offerings. The Ren distinguished them from others and kept a way of reaching them open.

## A Name Can Be Injured

Funerary texts ask for the name to endure. An offering formula names the person whose Ka will receive the gift; a petition to an Akh must reach someone recognizable. Erasing a name damages these means of contact.

## The Secret Name

In the story of Aset and Ra, the hidden name reaches a deeper part of Ra's identity than ordinary address. Aset seeks it because knowing that name changes what is possible between them. Intimacy and leverage meet in the knowledge of who someone is.

## More Than One Name

Kings carried a formal titulary to express several dimensions of royal identity. A person can likewise be a daughter, artist, employer, and friend, with each name describing a different relationship within the same life.

Truthful naming belongs to Ma'at. A name can honor what is there or distort it; leaving something unnamed can make neglect easier. Calling things what they are, and preserving the names through which people remain reachable, keeps those relations open to care.''',
    linkMap: [
      KemeticNodeLink(phrase: "offering formula", targetId: "offering_formula"),
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
      KemeticNodeLink(phrase: "Akh", targetId: "akh"),
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "ib",
    title: "Ib (Heart)",
    glyph: "𓄣",
    aliases: [],
    body: r'''The Ib is the heart as witness.

Thought, emotion, intention, memory, and character belong to the heart in Kemetic thought. In the Hall of Two Truths it carries this record to the balance, where it meets the feather of Ma'at. A person's account of themselves is answered by the heart that lived the life.

## “Heart of My Mother”

The Book of Coming Forth by Day speaks directly to the heart. The heart scarab and its spells address a heart capable of standing apart from its owner to testify. What it knows may differ from the explanation its owner gives.

## Heart and Tongue

In the Memphite Theology, perception reaches the heart, the heart conceives, and the tongue speaks. The heart takes part in creation as well as judgment.

What fills the heart finds its way to the tongue, and repeated words become easier to act upon.

## The Heart Is Being Made Now

Care for the heart begins in these ordinary choices, long before it reaches the scale. Habit is already making the witness that will speak there.

Living in Ma'at allows room to face that record honestly. A heart in right relation can have made mistakes and still be willing to acknowledge what it knows. Self-honesty makes it possible to bring the inner record and the outward account of a life into agreement.''',
    linkMap: [
      KemeticNodeLink(phrase: "Hall of Two Truths", targetId: "maat"),
      KemeticNodeLink(
        phrase: "Book of Coming Forth by Day",
        targetId: "book_of_the_dead",
      ),
      KemeticNodeLink(phrase: "Memphite Theology", targetId: "ptah"),
    ],
  ),
  KemeticNode(
    id: "sheut",
    title: "Sheut (Shadow)",
    glyph: "𓋺",
    aliases: [],
    body: r'''You cannot stand in light without casting a shadow.

The Sheut belongs among the Kemetic aspects of the person. It follows your form and carries your presence beyond the body's edge, a visible extension that remains your own.

## Presence Has Effects

Warmth can arrive as pressure; an ordinary presence can offer protection. Someone who feels invisible may leave an absence that changes a room.

## The Shadow Must Also Move

Some funerary compositions ask for the way to be opened for both Ba and shadow. The person has several aspects to protect and preserve, with needs for freedom, memory, and relationship. The shadow belongs to that continued presence.

## Seeing Your Own Shadow

A Coffin Text passage expresses the desire to see one’s shadow. Others may see our shadow before we see it ourselves. Our presence becomes known through what it produces, including effects we never intended.

Ma'at asks us to look at our own part in that experience and leave room for what another person can show us, without requiring control of every interpretation or fear of having an impact.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ba", targetId: "ba"),
      KemeticNodeLink(phrase: "Ma'at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "shai",
    title: "Shai",
    glyph: "𓀭",
    aliases: ["Destiny", "Fate", "Allotted Portion"],
    body: r'''Shai is the portion a life receives before choice has had its say.

Body, family, health, place, opportunity, and danger can all belong to that portion: conditions already underway when a person is born. Shai is often translated as fate or destiny. Within those conditions, conduct still matters.

## The Portion Given

A farmer cannot command the flood. A child enters a household they did not choose, and a ruler inherits a land with strengths, debts, wounds, and obligations. These are conditions someone must meet before they can decide how to respond.

The Tale of the Doomed Prince begins with a fate announced at birth. Attempts to control the future through fear create another confinement. The surviving story is incomplete, leaving the difficulty unresolved.

## Fate and Conduct

The Instruction of Amenemope calls for restraint, fairness, honesty, and protection of the vulnerable in a world where destiny has its place. The Hall of Two Truths still weighs the heart. What someone does with the life given to them remains consequential.

## Renenutet and Shai

A portion also needs nourishment. Renenutet belongs to fields, harvests, birth, and provision, the care that sustains what Shai has given. A child, a field, or a talent may be part of someone's portion; what it becomes depends partly on what it receives.

Time and chance enter every life. There can be joy in what a portion holds, and work in caring for it. Ma'at can guide that work within the life already here: what was given sets conditions, and what is done within them still matters.''',
    linkMap: [
      KemeticNodeLink(
        phrase: "Instruction of Amenemope",
        targetId: "instruction_amenemope",
      ),
      KemeticNodeLink(phrase: "Hall of Two Truths", targetId: "maat"),
      KemeticNodeLink(phrase: "Renenutet", targetId: "renenutet"),
    ],
  ),
  KemeticNode(
    id: "natron",
    title: "Natron",
    glyph: "𓈗",
    aliases: ["Purifying Salt", "Wadi Natrun Salt", "Sacred Cleansing Mineral"],
    body:
        r'''Natron is a naturally occurring mineral salt that became one of the practical foundations of Kemetic purification.

Its ability to remove moisture and slow decay made it useful for drying tissue during mummification. It also served in cleansing bodies, mouths, offerings, and sacred spaces. Purification took shape through these material effects.

## Purity as Function

A body prepared for burial needs protection from decay. A ritual object must be prepared for use, and a mouth made ready to speak sacred words. Natron removes what interferes with those functions through the work of drying, washing, and stabilizing.

## What Must Be Removed

Washing, clearing, and putting away prepare something for use again. A room needs its clutter removed; an argument needs attention to what keeps it unsettled; an overburdened body needs rest before another demand.

Salt, water, time, and attention to what must be removed belong to that preparation.''',
    linkMap: [],
  ),
  KemeticNode(
    id: "false_door",
    title: "False Door",
    glyph: "𓉿",
    aliases: ["Ka Door", "Tomb Doorway", "Door of Offerings"],
    body: r'''A false door was not built for the living to walk through.

Set into a tomb chapel, it gathered names, titles, images, and offering formulas around a point of contact with the deceased. The living could bring food and drink and speak the words preserved in stone. The door served the relationship across that threshold.

## An Address for the Dead

Here the Ren identifies the one whose Ka is to receive. The name and the offering have a place together, giving the living somewhere to speak, pour, set down provisions, and return.

## Stone Waiting for Voice

Someone still has to return to read the name and speak the offering formula. The inscription preserves the words; their use keeps the chapel within a living relationship.

## The Human Lesson

A visit to a grave, a spoken name, a kept recipe, an observed anniversary: each can become a memorial carried through a family’s generations. Returning gives memory a place in the living relationship.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ren", targetId: "ren"),
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
      KemeticNodeLink(phrase: "offering formula", targetId: "offering_formula"),
    ],
  ),
  KemeticNode(
    id: "offering_formula",
    title: "Offering Formula",
    glyph: "𓊵",
    aliases: ["Hotep-di-nesu", "Offering Prayer", "Bread and Beer Formula"],
    body: r'''The offering formula turns provision into relationship.

Bread, beer, cattle, fowl, linen, incense, oil, cool water, and “every good and pure thing” are given to a named recipient. The living address the Ka and continue their care for someone who has died.

## Food Needs an Address

The formula ḥtp-dỉ-nsw, “an offering which the king gives,” places the gift under divine authority and names the person whose Ka is to receive it. The Ren supplies that address. Spoken words and material provision come together in an offering directed to someone.

## Bread and Beer

The grain that feeds a household also supplies the offering table. Flood and field, harvest and storage, milling and brewing all enter the bread and beer placed there. Someone grew the grain and worked to prepare it before it could be given.

## Voice Offering

When physical provision was limited or absent, Kemetic practice also allowed for spoken offerings. Through remembrance, a name, and the ritual words, provision could be made present. Tomb inscriptions and false doors preserved those words for someone to return and speak.

## What Offering Teaches

Those who give have also been nourished. What has been received is transformed and given again, carrying provision into another relationship. Ma’at is present in this movement of a gift beyond one person’s possession.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
      KemeticNodeLink(phrase: "Ren", targetId: "ren"),
      KemeticNodeLink(phrase: "offering table", targetId: "hotep"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "hotep",
    title: "Hotep",
    glyph: "𓊵",
    aliases: ["Peace", "Offering", "Satisfaction", "Rest"],
    body: r'''Hotep is often translated as peace.

The word also holds offering, satisfaction, and rest. What is due has been placed where it belongs, and a settled condition becomes possible.

## The Offering Is the Image

The hotep sign is an offering mat with bread. Something has been given, a need has been met, and the relationship has been acknowledged. Rest follows the fulfillment of that obligation.

## Hotep-di-nesu

The familiar offering formula joins giving with satisfaction. Provision is directed toward a named recipient, sustaining the Ka and settling the relationship through care.

## False Peace

An argument can end with talk of peace while resentment remains. Avoidance, too, can preserve quiet without resolving harm. In hotep, the work of setting things right makes rest possible. As matters return to Ma’at, distress has room to subside.''',
    linkMap: [
      KemeticNodeLink(phrase: "offering formula", targetId: "offering_formula"),
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "pyramid_texts",
    title: "Pyramid Texts",
    glyph: "𓉴𓏞",
    aliases: [],
    body:
        r'''The Pyramid Texts are the oldest surviving large body of Kemetic religious literature.

Beginning with Unas, they appear on the interior walls of Old Kingdom royal pyramids. The stone preserves ritual speech that had already been performed, passed on, and adapted before it was carved there.

## Text Placed Into Architecture

Written upon the walls of the burial chamber, antechamber, and corridors, the utterances give offering, protection, and ascent a direction within the tomb. Sacred words are arranged around the passage they prepare, held in the architecture where their work is to be done.

Some provision the king, restore and awaken him, or protect him from danger. Others identify him with Ausar or raise him toward Ra and the imperishable stars. Together they provide several means by which he may continue.

## “Osiris Unas”

The dead king is addressed with Ausar’s name joined to his own. In the ritual, that naming brings him into the sacred pattern of restoration and changes what he can take part in.

## From Royal Walls to Wider Use

The language and concerns of the Pyramid Texts continued in the Middle Kingdom Coffin Texts and later the Book of Coming Forth by Day. Later generations found new forms in which the words could keep doing their work.

## Why They Matter Here

The Ka, Ba, Akh, and Ma’at belong to the sacred world these texts preserve. Continuation calls for feeding and protection, a name, orientation, restoration, and words correctly spoken. The surviving utterances give each part of that preparation a place in the work of surviving rupture.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Ra", targetId: "ra"),
      KemeticNodeLink(phrase: "Coffin Texts", targetId: "coffin_texts"),
      KemeticNodeLink(
        phrase: "Book of Coming Forth by Day",
        targetId: "book_of_the_dead",
      ),
      KemeticNodeLink(phrase: "Ka", targetId: "ka"),
      KemeticNodeLink(phrase: "Ba", targetId: "ba"),
      KemeticNodeLink(phrase: "Akh", targetId: "akh"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "coffin_texts",
    title: "Coffin Texts",
    glyph: "𓏞",
    aliases: [],
    body: r'''The Coffin Texts put sacred knowledge close to the body.

Beginning in the Middle Kingdom, spells written across coffin surfaces extended older royal funerary traditions to the non-royal dead. The coffin enclosed the person and equipped them for what lay ahead.

## A Small Cosmos

A decorated coffin could place the dead between sky and earth, oriented to the directions of solar movement and surrounded by words for protection, transformation, and guidance.

Some carried the Book of the Two Ways, an early map of afterlife routes. Others held diagonal star tables, arranging the decans for reckoning the night. The words were brought near, placing knowledge of the cosmos within reach of the person who would need it.

## Transformation

The spells offer the forms of falcon, lotus, serpent, fire, and divine identity. Each sacred identification gives the deceased capabilities for a domain beyond the ordinary limits of the human body.

## From King to Person

The Coffin Texts inherit and widen the concerns of the Pyramid Texts: how a person continues, moves, stays protected, and remains whole. Later funerary literature carries those needs onto papyrus, with the words required to meet them.

Effective knowledge can protect someone when placed where it is needed. Bringing it within reach allows more people to make use of it.''',
    linkMap: [
      KemeticNodeLink(phrase: "decans", targetId: "decans"),
      KemeticNodeLink(phrase: "Pyramid Texts", targetId: "pyramid_texts"),
    ],
  ),
  KemeticNode(
    id: "book_of_the_dead",
    title: "Book of Coming Forth by Day",
    glyph: "𓏞",
    aliases: [
      "Book of the Dead",
      "Per Em Hru",
      "Peret Em Heru",
      "Coming Forth by Day",
    ],
    body:
        r'''The Book of the Dead is better understood by its Kemetic title: Book of Coming Forth by Day.

Return is its goal. These funerary papyri gather spells, images, declarations, and protections so that the deceased can move and speak, remain whole, pass through judgment, and emerge from hiddenness.

## A Portable Ritual World

Sacred writing had occupied royal pyramid walls and coffin surfaces. Written on papyrus and placed with the dead, these compositions could travel with the person.

Families commissioned selections suited to their means and traditions. The contents varied with the period and the workshop preparing them.

## Coming Forth

The Ba needs freedom to move, the name must remain intact, and the heart must be able to testify truthfully about the life that carried it. Gates, beings, names, and formulas each require knowledge if the journey is to continue.

In the Hall of Two Truths, the heart meets Ma’at. Preparation for this passage includes the conduct of the life being judged.

## Image and Word

A judgment scene places the deceased visibly before the tribunal; a spell gives them words for passage. Image and speech work together within the papyrus, supplying ways to take part in the journey it prepares.

## The Human Meaning

The words for passage accompany a life already lived. At the balance, the heart bears witness to what the person has done as well as said. Names and formulas equip the traveler; lived conduct belongs to that preparation in Ma’at too.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ba", targetId: "ba"),
      KemeticNodeLink(phrase: "heart", targetId: "ib"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "papyrus_chester_beatty_iv",
    title: "Papyrus Chester Beatty IV",
    glyph: "𓏞",
    aliases: [],
    body:
        r'''Papyrus Chester Beatty IV makes an argument that still feels modern:

a text can outlive a monument because a text can be copied.

Writing depends on people continuing to pass it on. Stone may endure as an object; words endure as someone reads them, values them, and makes another copy.

## The Immortality of Writers

The body can be buried while the name lives on in words. The papyrus recalls sages whose tombs, families, and monuments could disappear while their names remained in books people still read. A reader could reach someone whose other traces had gone.

The Ren keeps a person available to be addressed. Each copy of a work creates another occasion for its writer’s name to be spoken, continuing the relationship through use.

## Copying Is the Technology

One fragile papyrus can be destroyed. With a hundred copies, the writing no longer depends on the survival of that single object.

Scribes in the House of Life and in schools carried knowledge from one hand and classroom to another. Each new generation could receive it because someone had done the work of copying it again.

## Worth Copying

A later reader has to find enough in a work to give time and labor to preserving it. What endures depends partly on those choices, made again in each generation.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ren", targetId: "ren"),
      KemeticNodeLink(phrase: "House of Life", targetId: "house_of_life"),
    ],
  ),
  KemeticNode(
    id: "instruction_ptahhotep",
    title: "Instruction of Ptahhotep",
    glyph: "𓏞",
    aliases: ["Maxims of Ptahhotep", "Sebait of Ptahhotep"],
    body:
        r'''The Instruction of Ptahhotep is one of the oldest surviving wisdom traditions in the world, and much of its power comes from how ordinary its problems are.

Listening, greed, speech, household responsibility, authority, age, and reputation all concern the way people live together. Harm can begin in those ordinary relations.

## What He Saw

A wise person still has more to hear. Ptahhotep asks that listening continue after authority has been gained, and that an answer wait until the other person has been heard. He warns against repeating what one does not know or confusing greed with intelligence. The care required in speech also belongs in the household.

Habits reach into trust, family, work, and judgment. Their consequences are also seen by the people who are learning how to act from watching.

## Example Outlives Advice

What is learned must become visible in what is done. Children receive the lesson and the example together: favoritism weakens teaching about fairness, and unchecked appetite weakens teaching about restraint. Ma’at passes through the conduct they see.''',
    linkMap: [KemeticNodeLink(phrase: "Ma’at", targetId: "maat")],
  ),
  KemeticNode(
    id: "instruction_amenemope",
    title: "Instruction of Amenemope",
    glyph: "𓏞",
    aliases: ["Amenemope", "Teaching of Amenemope", "Wisdom of Amenemope"],
    body: r'''The Instruction of Amenemope admires the quiet person.

The quiet person remains steady under pressure.

## Quiet and Heated

The “heated” person reacts loudly and quickly, turning pressure into harm. It is easy to learn those ways by answering in kind. Amenemope’s quiet person lets the first surge cool and waits long enough to see what the moment requires. That pause gives judgment time to guide the response.

## Do Not Move the Boundary

Do not move the boundary or take from the poor because they lack the power to resist. A shifted line takes someone else’s land; a false weight turns their vulnerability into another person’s wealth. Amenemope brings Ma’at to the point where that taking begins.

## Wealth and Rest

Wealth gained through disorder carries that disorder with it. Labor given entirely to becoming rich can leave little room for rest. Amenemope values modest security over abundance that keeps its owner anxious, always raising the amount required before peace can begin.

## The Human Lesson

Appetite, anger, fear, and concern for status can fill a moment before judgment has had time to work. A little time between impulse and action leaves room to choose a response.''',
    linkMap: [KemeticNodeLink(phrase: "Ma’at", targetId: "maat")],
  ),
  KemeticNode(
    id: "epagomenal_days",
    title: "Epagomenal Days",
    glyph: "𓏤𓏤𓏤𓏤𓏤",
    aliases: [
      "Five Days Outside the Year",
      "Birth Days of the Gods",
      "Days Upon the Year",
    ],
    body: r'''The civil year counted twelve months of thirty days.

That gave 360 days. Five more, the epagomenal days or “days upon the year,” stood outside the months, between the completion of the old cycle and the opening of the new.

## Births at the Edge

Later tradition associates these days with the births of Ausar, Heru the Elder, Set, Aset, and Nebet-Het. Restoration, sky power, force, protection, effective speech, mourning, and boundary gather at the threshold. The new year opens with the powers of these deities already present.

## Time Outside the Usual Count

The solar year exceeded twelve thirty-day months, so the remainder was given a place of its own. Ma’at allows order to accommodate what exceeds a pattern. The count can make room for the days that do not fit its regular divisions.

## Threshold Time

Associated with risk, purification, birth, and preparation, this interval invited clearing, completing, remembering, and protecting. The familiar structure of one year was ending before another began.

A transition deserves attention to what has changed and what should be left behind. Preparation has a time of its own before the regular count begins again.''',
    linkMap: [
      KemeticNodeLink(phrase: "Ausar", targetId: "ausar"),
      KemeticNodeLink(phrase: "Heru the Elder", targetId: "heru"),
      KemeticNodeLink(phrase: "Set", targetId: "set"),
      KemeticNodeLink(phrase: "Aset", targetId: "aset"),
      KemeticNodeLink(phrase: "Nebet-Het", targetId: "nebet_het"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "wp_rnpt",
    title: "Wp Rnpt",
    glyph: "𓊃𓆳",
    aliases: [
      "Opening of the Year",
      "Opener of the Year",
      "Wep Renpet",
      "New Year",
    ],
    body:
        r'''Wp Rnpt is better held as “Opening” or “Opener of the Year” than as a simple synonym for New Year's Day.

In Parker’s reconstruction of the early calendar, wp rnpt names Sopdet’s heliacal rising as the event that opens the year; tpy rnpt names its first day. Later use of wp rnpt broadened beyond that distinction.

## Sopdet Opens the Cycle

Sopdet’s heliacal rising was a signal of annual renewal. When it came near the Nile inundation, a return in the sky accompanied renewal on the land.

The 365-day civil calendar drifted against the solar year, carrying its first day away from Sopdet’s rising. The opening event and the calendar date could therefore part company.

## Not a Reset

The epagomenal days complete the old count, and Sopdet offers renewed orientation. What has been lived comes into the new cycle too: skills and debts, relationships, consequences, and memory.

Opening the year with Ma’at gives an occasion to examine our ways: what is ready, what remains unfinished, and what deserves release or renewed commitment. Disorder left unattended can cross the threshold with us.''',
    linkMap: [
      KemeticNodeLink(phrase: "Sopdet", targetId: "sopdet"),
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "epagomenal days", targetId: "epagomenal_days"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "akhet",
    title: "Akhet Season",
    glyph: "𓈗",
    aliases: ["Inundation Season", "Flood Season", "Season of the Nile Rising"],
    body: r'''Akhet is the inundation season.

The Nile rises beyond its channel and covers the fields, changing the routes and ground available for farming. Land that is temporarily out of use is being prepared for later agriculture.

## Covered Ground

Floodwater brings moisture and historically laid fertile sediment across the plain. Work shifts while the ground receives what it will need. Covered fields give preparation a quiet appearance: the conditions of later growth are being restored.

## Measure Still Matters

Too little water brings scarcity; too much can damage settlements, boundaries, and infrastructure. The field needs an amount it can receive and use. Ma’at is present in that proportion, which lets the flood sustain the land.

## Before Peret

Akhet leads into Peret and Shemu, through flood, emergence, and harvest. Water must withdraw, land reappear, and seed enter the prepared ground for the sequence to continue.

There is a time to plant and a time to gather. The yield belongs to another season; Akhet restores the conditions that make it possible.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
      KemeticNodeLink(phrase: "Peret", targetId: "peret"),
      KemeticNodeLink(phrase: "Shemu", targetId: "shemu"),
    ],
  ),
  KemeticNode(
    id: "peret",
    title: "Peret",
    glyph: "𓇾",
    aliases: ["Emergence Season", "Growing Season", "Season of Coming Forth"],
    body: r'''Peret begins when the land comes back.

As the flood withdraws, prepared ground appears, seed enters the soil, and growth begins to show. The name carries the sense of coming forth, heard also in solar emergence and funerary language.

## Emergence Is Not Completion

The first green shoot still has a season of care ahead of it. Patience belongs beside the work of tending: water managed, weakness noticed before it becomes loss, growth given time. That steady attention has to outlast the excitement of seeing something begin.

## Khepri and Coming Forth

Khepri appears at dawn after the hidden work of night. The seed develops underground before it shows, and the dead hope to come forth after preparation in hiddenness. Each emergence makes visible something already underway out of sight.

## The Work of Peret

A new habit or relationship can be lost through neglect, or disturbed by constant interference. Ma’at asks for enough continuity that what has begun can grow with ordinary care, without needing to be rescued every day.''',
    linkMap: [
      KemeticNodeLink(phrase: "Khepri", targetId: "khepri"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "shemu",
    title: "Shemu",
    glyph: "𓇓",
    aliases: ["Harvest Season", "Dry Season", "Season of Gathering"],
    body:
        r'''Shemu is conventionally rendered the harvest or dry season, and hꜣw uses it as the gathering phase of the agricultural arc.

The grain gathers what Akhet prepared and Peret raised. Cutting, threshing, counting, storing, offering, and distribution turn the crop into usable abundance. The harvest also makes visible what the cycle produced.

## The Field Gives an Answer

Flood, seed, timing, labor, and care have all entered the crop, along with weather, pests, and chance. What stands in the field is the result of those conditions together.

## Gathering Is Not the End

Grain must be brought from the field and placed where it can serve as food, seed, wages, offerings, and protection against scarcity. The granary makes those uses possible.

A granary can be full while the people who raised the grain go hungry. Food withheld and wages unpaid carry Isfet into the harvest, as do theft, poor records, and waste. Djehuty’s honest count must be followed by a fair distribution, so that what was gathered reaches the people it should sustain.

## Seed for Return

The harvest must leave bread to eat and seed to sow. Ma’at holds those needs together as the crop is shared and used, keeping today’s provision in relation to the next season.''',
    linkMap: [
      KemeticNodeLink(phrase: "hꜣw", targetId: "haw"),
      KemeticNodeLink(phrase: "Akhet", targetId: "akhet"),
      KemeticNodeLink(phrase: "Peret", targetId: "peret"),
      KemeticNodeLink(phrase: "Djehuty", targetId: "djehuty"),
      KemeticNodeLink(phrase: "Isfet", targetId: "isfet"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
    ],
  ),
  KemeticNode(
    id: "renenutet",
    title: "Renenutet",
    glyph: "𓆤",
    aliases: ["Harvest Serpent", "Nourishing Cobra", "Lady of the Granary"],
    body: r'''Renenutet appears where growth becomes security.

Her associations join nursing and nourishment with harvest, granaries, and destiny. In her cobra form, protection accompanies provision: what has grown, and the future it will feed, need guarding.

## The Granary Is Stored Time

Food laid up in a good year can sustain a household through a lean one. The granary holds the work of floodwater, sunlight, seed, and labor until it is needed again. Stored grain can support households and temples, supply offerings, and make the next planting possible.

## Nursing and Raising

A child needs food for character and skill to develop; a crop needs tending before it can feed anyone. Renenutet’s nursing and nourishment belong to this shared dependence. Care gives potential the means to become something.

## Renenutet and Shai

Shai names the portion allotted to a life. Renenutet brings attention to the food, shelter, care, and protection that make that portion livable. What a life becomes depends partly on receiving these things in time to use them.

The care that nourishes growth also guards what has been gathered, preserving seed even with a full storehouse.''',
    linkMap: [KemeticNodeLink(phrase: "Shai", targetId: "shai")],
  ),
  KemeticNode(
    id: "haw",
    title: "ḥꜣw",
    glyph: "𓇉𓄿𓅱𓏛𓏥",
    aliases: [
      "Haw",
      "HAw",
      "ḥꜣw",
      "Ḥꜣw",
      "Increase",
      "Surplus",
      "Abundance",
      "Excess",
      "Wealth",
      "haw",
    ],
    body: r'''ḥꜣw is increase.

The word can mean abundance or surplus, an amount beyond the baseline. The app takes its name from that increase and the possibilities it brings.

## Surplus Creates a Question

A granary holding more than today’s needs can feed others, support work, supply offerings, or preserve food for the future. The same store can also give its holder a means of control.

Extra authority can protect what has been entrusted to it or become a means of abuse. Speech can grow into insight or noise. An increase leaves something to be decided about the use of what is now available.

## Increase in Right Relation

Administrative surplus, offerings, Nile abundance, and the wisdom texts' warnings against excess direct attention to where an increase goes and what it supports.

In Ma’at, surplus helps sustain the relationships that produced it. Held apart from them, it can leave the appearance of abundance while those relations weaken into Isfet.

## Why the App Is Called ḥꜣw

A life is more than the abundance of its possessions. Tasks, opportunities, and money can multiply while attention fragments and relationships weaken. Increase needs a purpose that holds the whole in view.

“What is this increase for?” is the question behind ḥꜣw. The calendar is intended to help arrange activity and resources so that they strengthen the life they belong to, giving abundance a place within Ma’at.''',
    linkMap: [
      KemeticNodeLink(phrase: "Nile", targetId: "nile"),
      KemeticNodeLink(phrase: "Ma’at", targetId: "maat"),
      KemeticNodeLink(phrase: "Isfet", targetId: "isfet"),
    ],
  ),
];
