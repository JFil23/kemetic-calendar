import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/user_events_repo.dart';
import 'package:mobile/features/calendar/notify.dart';
import 'package:flutter/rendering.dart';
import '../../model/entities.dart';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'landscape_month_view.dart';
import 'dart:convert' as json;
import 'dart:convert';
import 'day_view.dart';







/* ───────────────────── Premium Dark Theme + Gloss ───────────────────── */

const Color _bg = Color(0xFF0E0E10); // charcoal
const Color _gold = Color(0xFFD4AF37);
const Color _silver = Color(0xFFC8CCD2);
const Color _cardBorderGold = _gold;

// Gregorian blue (high contrast on dark)
const Color _blue = Color(0xFF4DA3FF);
const Color _blueLight = Color(0xFFBFE0FF);
const Color _blueDeep = Color(0xFF0B64C0);

// Gentle highlight and depth shades for glossy gradients
const Color _goldLight = Color(0xFFFFE8A3);
const Color _goldDeep = Color(0xFF8A6B16);
const Color _silverLight = Color(0xFFF5F7FA);
const Color _silverDeep = Color(0xFF7A838C);

// Gradients for gloss (top-left to bottom-right)
const Gradient _goldGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_goldLight, _gold, _goldDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient _silverGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_silverLight, _silver, _silverDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient _blueGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_blueLight, _blue, _blueDeep],
  stops: [0.0, 0.55, 1.0],
);

// "White" gloss for text that should render pure white via ShaderMask
const Gradient _whiteGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Colors.white, Colors.white, Colors.white],
);

// Base text styles (color overridden to white inside gloss wrappers)
const TextStyle _titleGold =
TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _monthTitleGold =
TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white, height: 1.2);
const TextStyle _rightSmall =
TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white);
const TextStyle _seasonStyle =
TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _decanStyle =
TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white);

/* Gregorian month names (1-based) */
const List<String> _gregMonthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/* ─────────── Month / Decan info text (unchanged) ─────────── */

const Map<int, String> _monthInfo = {
  1: '''
Month 1 – Thoth (Ḏḥwty)
The first month of Akhet — Thoth — opens with the Nile's swelling. The river bursts its banks, dissolving boundaries — a living metaphor for the chaos before order.
As waters spread, temple astronomer-priests rose before dawn to watch Sopdet's (Sirius's) heliacal rising and proclaim the renewal of the year. This was an ideal alignment: the civil first of Thoth did not always meet that dawn, yet the vigil framed the year's beginning. These were not abstract rituals — every farmer depended on them. The measurements determined when seed could be sown, when canals would be ready, and how far temples might be safe from the flood. The scribe's stylus, not the soldier's spear, kept civilization alive.
As the architect of cosmic measure, Thoth counts the days, names the stars, and fixes the span of the gods themselves. When creation first stirred and Ra's words set the world alight, Thoth recorded the command. He did not speak creation — he remembered it. His writing preserved the pattern of Maʿat so that time could repeat without decay. Thoth's month began with careful thought: the mind setting the tone for a balanced year.
''',
  2: '''
Month 2 – Paopi (Pȝ ỉp.t)
If Thoth's month teaches order through understanding, Paopi teaches order through movement. The ancients named this month Paopi; in reflection it bears the title Paopi — the Carrying — for its spirit of motion and renewal. The world has been measured; now it must be carried forward.
The word mnḫt appears in Old Kingdom agricultural records and means “to bring” or “to carry.” It evokes both the physical act of transport — bearing the first loads of mud and seed — and the spiritual duty of carrying Maʿat forward into the year.
The Nile, still full from the southern rains, moved like a goddess in motion — Hapi herself — and humanity’s task was to join her current, not resist it.
The Kemite did not see work as drudgery but as sacred rhythm. Every basket lifted, every pole balanced on a shoulder, was an offering.
In mythology, Paopi's current belonged to the Hathoric cycle — Hathor as Mistress of the West guiding sun and soul across the celestial river. The "bringings" of this month included tribute from each nome — baskets of fish, papyrus, wild herbs, and early lotus flowers. Women wore garlands of blue lotus, symbols of rebirth rising from water; men poured milk and beer into the current, feeding the flood that feeds us.
In the Coffin Texts, Thoth proclaims that he bears Maʿat before the gods. In Paopi, all people mirror that act — carrying balance through deeds. The flood is still too deep to sow, yet everyone is moving, preparing, connecting. Life is fluid but purposeful. The harmony of Maʿat is not stillness; it is motion in right proportion. In these processions, the community became one body; every shoulder lifting together embodied harmony.
''',
  3: '''
Month 3 – Hathor (Ḥwt-Ḥr)
Hathor — goddess of beauty and the celestial cow — teaches that pleasure is not the opposite of discipline; it perfects it. The laughter of the goddess is the same energy that turns seed to sprout and sorrow to song. To live her month rightly was to dance after toil, to honor beauty without waste, and to recognize that the sweetness of life is part of its order.
By this time — roughly May 19 to June17 in the resynced solar calendar — the floodwaters have begun to settle and the land glistens green. The joy of Hathor kept morale high after the hardships of the inundation, reminding all that work done in harmony and gratitude is sacred. Women wove garlands of lotus and papyrus; men brewed sweet beer colored with pomegranate.
At Dendera, ḥmwt-nṯr ḥwt-ḥr — “Servants of the Goddess” — led processions where polished mirrors flashed sunlight to honor her golden face. In village shrines, couples sought fertility and artists sought inspiration. Beauty was not vanity; it was the outward sign of inner balance, proof that joy and order can coexist.
ḥwt-ḥr means “House of Horus.” In the sky she is the great golden cow whose body forms the heavens, within whose belly the sun and stars travel. As the cow-sky upholds the stars, so joy upholds creation. Every heart that delights in truth becomes, for a moment, a House of Horus.
''',
  4: '''
Month 4 – Ka-ḥer-Ka (Kȝ-ḥr-Kȝ)
Ka-ḥer-ka translates literally as “Ka upon Ka,” the doubling of vital essence. In Kemetic theology, the Ka (vital spirit) is the sustaining life-force present in gods, kings, humans, and even places.
By this time — roughly June 9 to July 8 in the resynced solar calendar (March 20 = Thoth 1) — the floodwaters drew back, revealing the dark silt called kemet — the very word that named the country itself. Farmers pressed seed into the soft ground, oxen dragged simple wooden plows, and children scattered manure and ash.
To sow seed was to imitate the burial of Asar (Osiris) — a sacred promise that death would give way to life.
Families sang lines like:
“As Asar sleeps, so shall the earth awaken.”
The Kemite did not seek to escape death — they sought to understand it as part of the whole. To bury unjustly, to hoard grain, or to forget one’s ancestors was to sever the cycle and create isfet. To plant honestly, to mourn truthfully, to give offerings from gratitude — these were acts of divine alignment.
In this unity of labor and reverence, Maʿat became daily life — balance between what is gone and what is growing.
Scribes recorded flood heights and grain inventories — not as bureaucracy but as sacred measure, ensuring that the year’s balance matched heaven’s. Children were told stories of  Asar’s (Osiris’) patience: how he endured darkness without fear because he trusted the order of things. To live rightly was to live that same patience — to plant, to trust, to wait.
On clear nights of this month, the sky over Kemet transformed. Orion (Sah) and Sirius (Sopdet) gleamed low over the horizon — divine reminders of Asar (Osiris) and Aset (Isis) watching over the new-sown fields. The temple ceilings of Dendera and Abydos show this sky in motion. Priests used merkhets (sighting rods) to align their water clocks with the rising decans.
Each decan marked ten nights of Asar’s (Osiris’) journey through the Duat. The star priests — called “watchers of hours” — noted each rising, saying, “He sails the hidden waters.”
Thus the heavens became a mirror of the god’s resurrection. As Asar (Osiris) traversed the underworld, the earth sprouted, and the stars themselves declared the triumph of Maʿat.
''',
  5: '''
Month 5 – Šef-Bedet (Šf-bdt)
The name Šef-Bedet (šf-bdt) appears in the Old Kingdom temple lists of Edfu and Dendera, as well as in agricultural texts from the Middle Kingdom. It translates roughly to "The Nourisher" or "She Who Feeds with Grain." The word šf means "to feed or provide," while bdt denotes "offering, sustenance, or bread."
This month’s name embodied the first task of the reborn world: to feed life into form. The Kemite worldview held that every being — human, animal, river, or star — has a right to sustenance. To feed another was to feed Maʿat herself.
This compassion was not sentiment but cosmic maintenance. The villages, newly rebuilt after the flood, glowed with fresh whitewash. The world itself looked washed clean — and in that cleanliness, gratitude arose naturally. The floodplain was now firm enough to walk upon. Farmers rose before dawn to water seedlings with clay jars, ensuring even irrigation.
They sang short invocations like:
“The earth drinks — and I drink with her.”
Children followed behind, scattering handfuls of ashes and fish bones as fertilizer. Women shaped the first loaves from the previous year’s grain and offered them to Renenutet, saying, “What was given returns.”
The house of life — the temple's scribal school — reopened its lessons. Students copied hymns to Thoth and accounts of the flood level, connecting the intellectual and agricultural rhythms into one continuous practice of order. In every sense, this month was the first labor of reborn civilization.
Where Thoth's month (Ḏḥwty) had taught measure, and Ka-ḥer-Ka had taught trust in transformation, Šef-Bedet taught the ethics of care. Šef-Bedet was a month of balance without struggle — of tending rather than striving. It reminded every Kemite that order is not achieved through dominance, but through gentle consistency.
''',
  6: '''
Month 6 – Rekh-Wer (Rḫ-wr)
The title rḫ-wr, “Great Knowing,” comes from the root rḫ, “to know, to perceive, to understand.” It is found in the Pyramid Texts (Utterance 600) and Coffin Texts, describing the divine faculty that “guides the tongue and keeps the world upright.” This month therefore represents awareness taking form — as crops strengthen and human minds turn toward planning, counting, and teaching.
In every home, wisdom found practical expression. Women balanced granaries, recording storage and rationing grain fairly. Men taught apprentices the proper way to cut stone or carve wood. Elders gathered in the evenings to recite proverbs that began with the phrase, “He who knows Maʿat…” — a gentle reminder that to know is to live rightly, not merely to think.
In temple schools, scribes studied arithmetic, surveying, and astronomy. The “stretching of the cord” ceremony was performed again to measure field boundaries — a literal act of restoring Maʿat through precision.
At dusk, people poured small libations of water on the ground — symbolically “teaching” the soil, reminding it of the Nile’s rhythm, so that the roots would “remember the flood.” Every act of maintenance, from mending a canal to sharpening a sickle, was treated as sacred study — practice as prayer.
Rekh-Wer was considered sacred to Thoth (ḏḥwty) and the solar goddess Sekhmet, for in this time, knowledge and power had to remain in balance. After the renewal of Asar (Osiris) and the nurturing of Renenutet, the sun began to climb again. Ra's Eye — fiery and vigilant — looked upon the land. The scribes said that Thoth "measured her path" and "taught her restraint." Thus, the month became a symbol of controlled strength: intellect governing energy, compassion guiding productivity. As a later teaching attributed to the Book of Maʿat expressed:
“He who measures rightly keeps the balance of heaven and earth in his hand.”
''',
  7: '''
Month 7 – Rekh-Nedjes (Rḫ-nḏs)
The mythology of this month draws from the contests between Horus and Set following Asar's (Osiris') resurrection. The Two Lands were divided; judgment had to be tested through trial and endurance. Aset (Isis), embodying compassion, guided her son not to strike blindly but to learn restraint. In the Coffin Texts, Thoth tells Horus: "Patience is victory; Maʿat is not won by haste."
rḫ-nḏs, literally "small or lesser knowing," did not imply ignorance but applied learning — the testing of what had been gained in Rekh-Wer. It was the month of the apprentice, the craftsman, the young crop facing its first heat. The Kemite saw this as a sacred stage of life: the soul leaving theory and entering the field.
In inscriptions from Dendera and Esna, this month’s title is followed by epithets like “of the patient heart” and “of the watching eye. To know less was not to fall — it was to practice wisdom amid imperfection.
In everyday life, this month felt slower, more introspective. The novelty of the new year had passed; now came the steady heartbeat of maintenance. The Kemite saw divinity in persistence — not the grand miracles of gods but the quiet miracle of one who tends what he began. Even the scribes noted fewer festivals; this was a time of personal discipline. Households cleaned tools, sharpened knives, and recopied old hymns so they would not fade — the renewal of memory as the renewal of order. The sages taught:
“He who knows Maʿat must carry her in silence.
The one who acts without shouting keeps the world from cracking.”
Here lies the heart of the month — that wisdom untested is illusion. The people of Kemet lived this not as punishment, but as refinement: heat tempers metal; difficulty tempers truth. Through careful work and honest endurance, they honored Maʿat not in speech, but in motion — every furrow drawn straight, every measure fair, every rest deserved.
''',
  8: '''
Month 8 – Renwet (Rnnwt)
Renwet (rnnt) takes its name directly from the goddess Renenutet, the serpent of nourishment and fate. Her name derives from rnn (“to nurse, to suckle”) and is interpreted as meaning “She Who Nurtures into Being.” Her image — a rearing cobra with a soft face — adorned every granary wall and harvest vessel. Her domain was twofold: the abundance of the earth and the destiny (šai) of every living being.
The Kemite said that when a child was born, Renenutet whispered its true name into its ear — not the one given by parents, but the one known by the gods. Thus, she governed not only food but purpose itself. This was the busiest, most joyful time of the year. Laughter returned to the courtyards. The smell of bread, beer, and roasted fish filled the air. Workers were paid from temple granaries, and festivals lasted for days. Children played games of chance — symbolic rehearsals of Shai’s hand in life — while elders blessed them with sayings like:
“May your name be long, may your Ka be rich, may Renenutet remember you.”
Yet even amid joy, restraint remained sacred. Overindulgence was seen as offense to the goddess, for abundance must remain balanced. To hoard or waste was to anger Shai — to act against one’s own fate. To the Kemite, this was the final examination of the season: whether, after learning patience, endurance, and knowledge, one could live in humble gratitude. In Renwet, the cycle of Peret closed not with consumption, but with remembrance — returning the first share to the gods, to the ancestors, and to the poor.
The month of Renwet embodies the highest wisdom of Maʿat: that gratitude is not emotion, but justice. The one who honors the source of nourishment sustains it; the one who forgets it invites loss. In this sense, Renenutet was both gentle and stern — her smile filled the silos, but her silence emptied them. Her teaching was simple:
“Your destiny is what you nourish. Feed the world that feeds you.”
''',
  9: '''
Month 9 – Hnsw (Ḥnsw)
Hnsw opens Shemu as the "traveler's month" — radiant, demanding, alive. It reminds the Kemite that Maʿat is not a resting place, but a path — one walked beneath the eye of Ra, in heat, effort, and gratitude. The texts of the Amduat and Book of Gates describe how Ra, the Sun-God, travels through the sky by day and the Duat by night, sustaining the balance between light and darkness.
Hnsw (The Traveller) refers to both the sun's daily voyage and the movement of the people as the agricultural year neared completion. This month taught that life, too, must travel its course without resistance. The wise Kemite did not curse the heat; he understood it as Ra's testing of the world's endurance — the necessary fire that strengthens what has been tempered. Caravans of donkeys and boats moved along the river, carrying offerings to temples and food to cities. The people traveled under a blazing sky, yet found rhythm in the motion — as if imitating the sun's steady crossing from horizon to horizon.
Each journey, each trade, each pilgrimage was considered part of the “path of Ra” — every human journey a reflection of the cosmic voyage.
The Nile shrank within its banks, leaving gleaming lines of salt on the soil. Fields that once swayed green now stood bare, drying for threshing. Work shifted to transportation and preservation — storing grain, pressing oil, drying fruit and fish. In Hnsw, travel itself became sacred. Families visiting relatives, merchants crossing nomes, and fishermen tracing the Nile's edge all felt they were part of the same vast circulation that sustained Maʿat. Offerings were simple but radiant: bread baked in circular molds, golden beer, honey, and saffron oil — all colored like the sun. Each household was said to anoint their foreheads with oil at midday while reciting:
"May my path follow the sun's.
May my heat be righteous, my light not blind."
This was the heart of Hnsw's philosophy — that power without balance burns, but power guided by Maʿat illumines. Priests instructed meditation on Khepri, the scarab who rolls the sun each dawn, symbol of persistence through adversity. Children were taught to face the morning sun with open hands, to practice humility before its brilliance, and to remember that light must be carried, not hoarded.
Hnsw taught that Maʿat does not stand still. Even balance moves — like the pendulum of Ra's day and night. To live in Maʿat during the season of heat was to walk with the light without becoming consumed by it. The wise carried inner shade, knowing that endurance and humility are the highest forms of power.
As an old maxim carved at Heliopolis said:
“He who travels rightly leaves Maʿat behind him as footprints.”
''',
  10: '''
Month 10 – Ḥenti-ḥet (Ḥnt-ḥtj)
Ḥenti-ḥet (ḥnt-ḥtj) literally means "Foremost of Offerings." The word ḥeti (offering) comes from the same root as ḥtp (peace), showing how the act of giving was synonymous with bringing harmony. As the land dried, people began making thank-offerings to Ra, Asar (Osiris), and Renenutet — not to request more abundance, but to acknowledge that what had been received was sufficient.
To the Kemite, peace was not found in plenty but in knowing when to stop grasping.
For common folk, life slowed to the rhythm of endurance. Travelers moved by night, carrying water skins and palm-leaf fans. The markets shifted to trade in dried goods and shade cloths. Storytellers and musicians filled the courtyards in the evenings, singing tales of Sekhmet’s laughter and Hathor’s sweetness — cooling the soul as the gods cooled the sky.
Children learned from elders how to ration and repair, understanding that conservation was not scarcity but wisdom in rhythm with the desert. In the oldest solar hymns, this month corresponds to the time when Ra’s Eye blazes hottest and the gods retreat to shade.
Mythically, it was said that the fiery Eye (personified as Sekhmet) once grew so fierce that she nearly destroyed humankind. To calm her, Ra commanded the fields to be filled with beer dyed red, which she drank, mistaking it for blood. Her rage softened into laughter — and the world survived.
Thus, Ḥenti-ḥet celebrated the cooling of divine wrath, the restoration of proportion after excess. It was a warning that even light must rest, even gods must balance. Families made personal offerings of cool water, lotus petals, and milk. The poorest gave only breath — standing before the morning sun, exhaling slowly, saying:
“May my heat cool yours.
May my heart rest in Maʿat.”
Under the eye of Ra, the Kemite learns the oldest truth of Maʿat: nothing truly belongs to us — not our strength, not our harvest, not even our breath. All must be offered back in harmony.
''',
  11: '''
Month 11 – Pa-Ipi (ỉpt-ḥmt)
Pa-Ipi (ỉpt-ḥmt), "Bringing Together of the Women," is one of the most ancient month names in Kemet. It likely referred to renewal and reunion — the joining of sky and earth, of gods and ancestors, as the year neared its end. By the Middle Kingdom, it was often called Ipi, a shortened form used in temple and civil texts.
In priestly theology, Ipi carried the same meaning later expressed as Ḥnsw ḥr kꜣ — the traveler's reunion with the Ka, the merging of the living and the ancestral. The Kemite recognized that the year — like the soul — was moving toward death, only to rise again renewed. Offerings to the Ka of ancestors increased, and the living sought harmony with the unseen forces that sustained them.
This was a month of reflection and gratitude. Families visited graves, shared meals in the fields, and retold stories of their ancestors’ virtues. It was said that the Ka grows stronger through remembrance — and that forgetting was a form of death.
The air was filled with the scent of lotus and old incense; music slowed to soft flutes and hand drums. Nights were clear and deep — the Milky Way bright enough to guide travelers by its “River of Souls.” Farmers prayed for strength to rebuild; mothers whispered blessings over sleeping children, linking their breath to the rhythm of the river’s return.
As the Nile prepared to rise again, the people turned their devotion to Asar (Osiris), who dies and returns eternally — the seed that becomes the stalk, the man who becomes god.
The month taught that to live in Maʿat is to keep the line unbroken. The Kemite saw himself as one link in a living chain — not an isolated self, but a continuation of those before him. The ancestors were not gone; they were present in the Ka, woven into the body of the world. It reminded the Kemite that time itself is alive — that every cycle, every seed, every breath belongs to one vast current.
By remembering the ancestors and tending the Ka, the people aligned themselves with the eternal rhythm of Maʿat — the order that never dies.
This understanding dissolved fear of death. To die was to change form; to live rightly was to ensure one’s Ka would continue the journey. Hence the saying preserved at Abydos:
“He who remembers, endures;
He who is remembered, returns.”
''',
  12: '''
Month 12 – Mesut-Ra (Mswt-Rꜥ)
In inscriptions from the Old Kingdom through the Middle Kingdom temple calendars, Mesut-Ra, "The Birth of Ra," was treated as the gestational month of the year — when both earth and gods prepared to bring forth. It was the month of waiting in balance, just before the five Heriu Renpet (ḥr.w rnpt), when the gods themselves would be born anew.
The word msn (from msi, "to give birth") forms the root of the month's name and of later words such as Mswt ("births") and personal names like Ms-nfrt ("Born of Beauty"). The Hebrew name Moshe (Moses) is linguistically related to this same Egyptian root — all echoing one creative act: emergence from the hidden into the seen.
Mythologically, Mesut-Ra belongs to Nut, the sky goddess who swallows the sun each evening and gives birth to him each morning.
In this closing month, the myth expands: Nut becomes the cosmic womb preparing to deliver the divine children — Asar (Osiris), Horus the Elder, Set, Aset (Isis), and Nephthys — born during Heriu Renpet (ḥr.w rnpt).
Texts from Dendera describe the sky "bent in labor," the stars trembling with anticipation. The people saw in this cosmic image their own renewal: as Nut labored to bring forth the gods, the Nile too would soon "labor" to bring the flood.
The atmosphere of this month was serene — like a long exhale. The air was hot and still, yet the people's hearts felt light. Children were taught the "Counting of Years," scratching tallies on potsherds to mark the completion of another cycle. The old told stories of floods past — both gentle and wild — to remind the young that life's balance depends on reverence and readiness.
The nights were filled with ritual songs called ḥeset en renpet — "praises of the year" — sung to Nut and Sopdet, thanking them for carrying the world faithfully through its circle of transformation.
Temples across Kemet held the "Ritual of Sealing the Year." Priests extinguished the perpetual lamps of the closing cycle, reciting:
"The breath returns to the sky,
The seed returns to the soil,
The order stands — awaiting the dawn."
Only on the first day of the new year would the lamps be rekindled.
Families performed their own versions of this rite — clearing altars, washing statues, repainting household shrines. Offerings of water, natron, and lotus symbolized purification; small clay figurines of frogs and scarabs represented fertility and transformation.
Mesore is the last breath of the solar year — the sacred pause before rebirth. It is both the grave and the womb, the place where silence becomes song again. In this month, the Kemite world stood still not from exhaustion, but from awe. For soon, the five luminous days — the births of the gods — would arrive, and life itself would begin anew.
''',
};

const List<String> _decanInfo = [
  // 36 entries aligned to months 1..12 (each 3)
  'Ṯemat Horet (Little Mat) — A faint cluster low in the east just before dawn; priests saw it as the “little balance” setting the tone for the night’s final hour. Farmers used its rise to begin kneading bread so loaves would bake by sunrise. Its faintness was likened to newborn Ma’at: fragile but essential. The cluster’s invisibility during storms reinforced the idea that obscured balance leads to disorder.',
  'Ṯemat Kheret (Continuing Mat) — Slightly higher and steadier; its rise reassured watchers that the sequence of decans was intact. In temple lore it represented the continuation of Ma’at after the shaking of the world. Harvesters used its appearance to rotate tasks; one crew sharpened sickles while another rested. The pairing of two similar decans emphasized that order is maintained through careful handing off.',
  'Ushaty Bekety (Two Companions) — Two close points seen as twins. Storytellers said they were Anpu (Anubis) and Wepwawet, jackal-gods who guide souls and hunters. The stars reminded field workers to work in pairs, sharing burdens and sharpening each other’s skills. In the night sky, the twin lights seemed to walk together, teaching that wisdom grows through companionship.',
  'Ipedes — A bright spear-like star; priests used its first flash to begin certain germination rites. Hunters connected it with Set’s thrown spear in his battle with Ausar, a cautionary tale about misused power. Farmers sharpened plows at this hour, imitating the star’s pointed light.',
  'Sebeshen — A scatter of tiny sparks; farmers took it as the sign to begin weeding. Its many points evoked seeds and reminded everyone that small, persistent work yields abundance. Children were told that the star was Ausar’s beard hairs falling as he lay in the coffin, later sprouting into grain.',
  'Khentet Horet (Guide Foremost) — A leading star with a faint tail; caravans used it to set course across desert dunes. The netjeru Wepwawet (“Opener of the Ways”) was identified with it. The decan’s story taught that wisdom is in choosing the path as much as walking it.',
  'Khentet Kheret (Guide Behind) — A western decan associated with healing; families watched for its sinking to administer remedies. Midwives used its timing to recite protective spells around infants. The pairing with the previous decan illustrated that guidance requires both leading and watching the rear.',
  'Temes en Khentet (Mass of the Guide) — A dense group; foremen rotated labor gangs by its rise, ensuring fairness. Scribes marked wages at this hour. The decan became a symbol of equal turns, and disputes were sometimes settled by referencing it.',
  'Kedety (Builders) — Two moderate stars used by masons to test the straightness of walls. It was linked to Ptah, patron of craftsmen. When the decan rose, apprentices fetched plumb-lines; elders reminded them that physical alignment mirrored moral alignment.',
  'Khentiwy (The Two Eyes) — Bright pair identified with the Eyes of Heru. Healers timed certain ointments to this hour, believing the god’s gaze empowered cures. Parents taught children about fractions using these stars: one represented five parts, the other two, together forming the whole wedjat.',
  'Hery-Ib Wia (Within the Bark) — A cluster within the region of Sah (Orion) that priests interpreted as the crew inside Ra’s solar barque. Temple guards changed watch here; chants to keep the crew alert echoed through halls. Sailors on the river also took the hour to adjust rudders and sails.',
  'The Crew — A faint asterism seen as oarsmen. During its ten days, crews in fields and on boats emphasized teamwork; they ate together and sang rowing songs. The decan’s rise near midnight reminded everyone that collective effort carries the world through darkness.',
  'Khenemu (Potter’s Stars) — Associated with Khnum, the ram-headed shaper of bodies. Potters favored these nights for forming jars, saying the god’s hands guided theirs. Stories explained how Khnum fashioned Heru’s new eye during these hours after Djehuty healed the broken one.',
  'Semed Seret (Threshing Floor) — A scatter that looked like grain on a threshing floor. Farmers used this decan to start beating sheaves, accompanied by rhythmic clapping to separate kernels. The image taught that order emerges when chaff is beaten away.',
  'Seret (Serpent) — A winding line; mothers renewed serpent amulets here and told stories of the snake goddess Wadjet protecting the king. In fields, workers stamped ground at boundaries to mark property lines. The decan’s curve resembled the curve of the river, linking earth and sky serpents.',
  'Saawy Seret (Twin Serpents) — Two intertwined lights; healers mixed antidotes at its rise, believing venom and medicine are twins. Guards reviewed safety rules, and fishermen checked nets for tears. The decan taught that duality is everywhere and must be balanced.',
  'Kheri Kheped Seret (Serpent’s Tail West) — A western aspect of the serpent theme; rituals “against venom” took place. Grain stores were dusted with herbs, baskets inspected for scorpions. Parents retold the story of Heru being healed from a sting, linking myth to household practice.',
  'Tepi-a Akhuy (First of the Luminous Ones) — A bright marker that priests used to announce the start of first light. Rope-stretchers aligned their cords, and canal workers began early chores. Hymns about “opening the horizon” were sung softly as the stars faded.',
  'Akhuy (The Luminous Ones) — Strong cluster later folded into Orion lore. The decan sequence during these nights was used to divide the night into equal parts. Guards took pride in calling hours exactly; scribes recorded watches to time legal oaths.',
  'Imy-Khet Akhuy (Southern Luminous Ones) — Southern aspect favored by south-bound caravans. Merchants saw patience in its slow rise and told apprentices to plan carefully. The decan’s ten-day run often coincided with market expeditions.',
  'Baawy (The Two Souls) — Two lights considered twin souls of a deity or of king and ka. Wake-house customs at funerals were timed here: bread was broken for the living and the dead, reinforcing that memory keeps both together. The decan suggested that life and afterlife are paired.',
  'Qed (The Measure) — A single clear point used to square corners. Builders set thresholds and doorways under its light; parents hung protective charms on lintels. It taught that a good entrance is both physical and spiritual: you measure your words as well as your door frames.',
  'Khaw (The Shining Ones) — Glitter like ripening grain, reminding farmers to give first fruits to the gods. Offerings were timed to this decan, linking celestial shimmer to golden ears. Children were taught to see the sheen of wheat as a reflection of these stars.',
  'Art (The Chambers) — Compact cluster associated with tomb chambers; funerary craftsmen timed delicate inlays and paintings to this hour for concentration. Families visiting graves lit lamps facing this decan, whispering names of ancestors. Its steadiness underscored the importance of care for the dead.',
  'Kheri Art (Overseer of the Chamber) — Supervisory counterpart; necropolis workers performed inspections here and read lists aloud. The decan became associated with accountability: tools counted, promises reviewed. Its presence reminded that order in the unseen world required diligence in the seen.',
  'Remen Hery Sah (Part of Sah’s Body) — A star within the constellation Sah (Orion) identified with Ausar’s spine; priests made djed-pillar gestures, teaching that stability undergirds life. Carpenters true beams at this hour. Parents told children to “stand like a djed,” linking posture to moral uprightness.',
  'Remen Kheri Sah (Companion of Sah) — Sibling star used to align tomb shafts. The decan’s quiet dignity inspired awe; many simply watched it set. Myths said that Ausar’s other parts ascended here, so the decan taught that completeness comes from integration of all parts.',
  'Abwet (The Boat) — A neat boat-shaped cluster; ferrymen tossed bread crumbs into the Nile when it rose, thanking river spirits. Households used the hour for reconciliation, saying “let’s cross together.” The decan linked physical crossing to emotional crossing.',
  'Wa’aret Kheret Sah (Great One under Sah) — Companion of Orion tied to Osirian processions. Temples performed lamp-walks; villages imitated with lanterns between doorways. Children learned to keep step and to carry light with care. The decan underscored that dignity in ritual belongs to all, not just the elite.',
  'Tepi-a Sopdet (First of Sopdet) — A herald cluster near Sirius; watchers grew excited for the heliacal rising of Sopdet that announced the new year. Households swept thresholds and whitewashed walls to welcome the star. It taught that preparation is a form of reverence.',
  'Sopdet (Sothis / Sirius) — The brightest star, identified with Aset (Isis) and the flood. Priests kept careful dawn vigils to catch the first flash; when it appeared, people rejoiced because it meant the inundation was near and the cycle renewed. Even when civil calendar drift separated the observation from the actual flood, the custom of greeting Sopdet endured.',
  'Khenmet (The Guard) — A cluster near Sopdet called “the watchers.” Temple guards changed shifts with crisp rituals; mothers checked sleeping children and shuttered doors. It signified the vigilance required after renewal to protect new life.',
  'Saawy Khenmet (Twin Guards) — Doubling the guard theme; charms against theft and waste were renewed, store-room seals inspected. Neighborhood patrols were organized, reflecting that community safety is collective. The decan’s twins showed that protection works best in pairs.',
  'Kheri Kheped Khenmet (Overseer of Khenmet) — Supervisory star for the guardians; small offerings for household safety were timed now. Inventories were read; lamps trimmed. The decan reinforced that watching and accounting are acts of devotion.',
  'H’at Khaw (Foremost of the Shining) — Stars at harvest’s height that seemed extra keen. Hymns to Ra’s strength clustered here; reapers sang antiphons to keep pace. Children remembered these nights as the most beautiful of the year, associating brilliance with abundance.',
  'Pehew Khaw (Rear of the Shining) — The final decan closed the cycle. Lamps were extinguished deliberately at hour’s end and relit, enacting cosmic rebirth. Families told stories of the Bennu bird (phoenix) rising, linking the star’s disappearance and return to eternal renewal. The next night’s counting began, reminding everyone that endings and beginnings are inseparable parts of Ma’at.',
];

/* ─────────── Gloss helpers ─────────── */

class _Glossy extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  const _Glossy({required this.child, required this.gradient});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class _GlossyText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const _GlossyText({
    required this.text,
    required this.style,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return _Glossy(
      gradient: gradient,
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

class _GlossyIcon extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  const _GlossyIcon(this.icon, {required this.gradient});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _GlossyDot extends StatelessWidget {
  final Gradient gradient;
  const _GlossyDot({required this.gradient});
  @override
  Widget build(BuildContext context) {
    return _Glossy(
      gradient: gradient,
      child: Container(
        width: 4.5,
        height: 4.5,
        decoration:
        const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

/* ─────────── Flows (routines): palette + gloss-from-color ─────────── */

const List<Color> _flowPalette = [
  Color(0xFF55DDE0), // teal
  Color(0xFF7C5CFF), // violet
  Color(0xFFFF6B6B), // coral
  Color(0xFF2DD36F), // leaf
  Color(0xFFFFC145), // amber
  Color(0xFF41A5EE), // sky
  Color(0xFFE85DFF), // magenta
  Color(0xFF00C2A8), // sea
  Color(0xFFFF8E3C), // orange
  Color(0xFF7BB661), // moss
];

Gradient _glossFromColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  Color lighten(double by) =>
      hsl.withLightness((hsl.lightness + by).clamp(0.0, 1.0)).toColor();
  Color darken(double by) =>
      hsl.withLightness((hsl.lightness - by).clamp(0.0, 1.0)).toColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lighten(0.30), base, darken(0.25)],
    stops: const [0.0, 0.55, 1.0],
  );
}

/* ─────────── Flows (routines) – models & rules ─────────── */

/// Rules attach their own time window (all-day or start/end).
abstract class _FlowRule {
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  const _FlowRule({this.allDay = true, this.start, this.end});

  /// True if rule hits for the given Kemetic date and its Gregorian equivalent.
  bool matches({
    required int ky,
    required int km,
    required int kd,
    required DateTime g,
  });
}

/// Kemetic Decan rule.
class _RuleDecan extends _FlowRule {
  final Set<int> months; // 1..12
  final Set<int> decans; // 1..3
  final Set<int> daysInDecan; // 1..10 (optional)
  const _RuleDecan({
    required this.months,
    required this.decans,
    this.daysInDecan = const {},
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({required int ky, required int km, required int kd, required DateTime g}) {
    if (km == 13) return false;
    if (!months.contains(km)) return false;
    final dIndex = ((kd - 1) ~/ 10) + 1; // 1..3
    final dIn = ((kd - 1) % 10) + 1; // 1..10
    if (!decans.contains(dIndex)) return false;
    if (daysInDecan.isNotEmpty && !daysInDecan.contains(dIn)) return false;
    return true;
  }
}

/// Whole Kemetic month rule (1..13; 13 = epagomenal).
class _RuleKemeticMonth extends _FlowRule {
  final Set<int> months;
  const _RuleKemeticMonth({
    required this.months,
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({required int ky, required int km, required int kd, required DateTime g}) {
    return months.contains(km);
  }
}

/// Gregorian month rule (1..12).
class _RuleGregorianMonth extends _FlowRule {
  final Set<int> months;
  const _RuleGregorianMonth({
    required this.months,
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({required int ky, required int km, required int kd, required DateTime g}) {
    return months.contains(g.month);
  }
}

/// Gregorian weekday rule (Mon=1 .. Sun=7).
class _RuleWeek extends _FlowRule {
  final Set<int> weekdays; // 1..7
  const _RuleWeek({
    required this.weekdays,
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({required int ky, required int km, required int kd, required DateTime g}) {
    return weekdays.contains(g.weekday);
  }
}

/// Explicit Gregorian dates rule (date-only). Used when customizing per decan/week.
class _RuleDates extends _FlowRule {
  final Set<DateTime> dates; // store as DateUtils.dateOnly
  const _RuleDates({required this.dates, super.allDay = true, super.start, super.end});
  @override
  bool matches({required int ky, required int km, required int kd, required DateTime g}) {
    return dates.contains(DateUtils.dateOnly(g));
  }
}

/// A Flow (routine). Occurrences are computed on demand from rules.
class _Flow {
  int id; // assigned by app
  String name;
  Color color;
  bool active;
  DateTime? start; // inclusive (Gregorian local)
  DateTime? end;   // inclusive (Gregorian local)
  final List<_FlowRule> rules;
  String? notes; // optional description
  _Flow({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
    required this.rules,
    this.start,
    this.end,
    this.notes,
  });
}

/// One resolved instance of a flow on a day.
class _FlowOccurrence {
  final _Flow flow;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  const _FlowOccurrence({
    required this.flow,
    required this.allDay,
    this.start,
    this.end,
  });
}

/// Tiny helpers
Set<int> _fullRange(int from, int to) => {for (var i = from; i <= to; i++) i};
Set<int> _emptySet() => <int>{};

/* ───────────────────────── KEMETIC MATH ───────────────────────── */

class KemeticMath {
  // Epoch anchored to *local midnight*: Toth 1, Year 1 = 2025-03-20 (local).
  static final DateTime _epoch = DateTime(2025, 3, 20);

  // Repeating 4-year cycle lengths starting at Year 1: [365, 365, 366, 365]
  static const List<int> _cycle = [365, 365, 366, 365];
  static const int _cycleSum = 1461; // 365*4 + 1

  static int _mod(int a, int n) => ((a % n) + n) % n;

  static int _daysBeforeYear(int kYear) {
    if (kYear == 1) return 0;
    final y = kYear - 1;

    if (y > 0) {
      final full = y ~/ 4;
      final rem = y % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[i];
      }
      return sum;
    } else {
      final n = -y;
      final full = n ~/ 4;
      final rem = n % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[3 - i];
      }
      return -sum;
    }
  }

  static ({int kYear, int kMonth, int kDay}) fromGregorian(DateTime gLocal) {
    final g = DateUtils.dateOnly(gLocal);
    final diff = g.difference(_epoch).inDays;

    if (diff >= 0) {
      int kYear = 1;
      int rem = diff;

      final cycles = rem ~/ _cycleSum;
      kYear += cycles * 4;
      rem -= cycles * _cycleSum;

      int idx = 0;
      while (rem >= _cycle[idx]) {
        rem -= _cycle[idx];
        kYear++;
        idx = (idx + 1) & 3;
      }

      final dayOfYear = rem;
      if (dayOfYear < 360) {
        final kMonth = (dayOfYear ~/ 30) + 1;
        final kDay = (dayOfYear % 30) + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      } else {
        final kMonth = 13;
        final kDay = dayOfYear - 360 + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      }
    }

    int rem = -diff - 1;
    rem %= _cycleSum;

    int year = 0;
    final rev = [_cycle[3], _cycle[2], _cycle[1], _cycle[0]];

    for (int i = 0; i < 4; i++) {
      final len = rev[i];
      if (rem < len) {
        final dayOfYear = len - 1 - rem;
        year -= i;
        if (dayOfYear < 360) {
          final kMonth = (dayOfYear ~/ 30) + 1;
          final kDay = (dayOfYear % 30) + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        } else {
          final kMonth = 13;
          final kDay = dayOfYear - 360 + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        }
      }
      rem -= len;
    }

    return (kYear: -3, kMonth: 13, kDay: 1);
  }

  static DateTime toGregorian(int kYear, int kMonth, int kDay) {
    if (kMonth < 1 || kMonth > 13) {
      throw ArgumentError('kMonth 1..13');
    }
    if (kMonth == 13) {
      final maxEpi = isLeapKemeticYear(kYear) ? 6 : 5;
      if (kDay < 1 || kDay > maxEpi) {
        throw ArgumentError('kDay 1..$maxEpi for epagomenal in year $kYear');
      }
    } else {
      if (kDay < 1 || kDay > 30) throw ArgumentError('kDay 1..30');
    }

    final base = _daysBeforeYear(kYear);
    final dayIndex =
    (kMonth == 13) ? (360 + (kDay - 1)) : ((kMonth - 1) * 30 + (kDay - 1));
    final days = base + dayIndex;
    return _epoch.add(Duration(days: days));
  }

  static bool isLeapKemeticYear(int kYear) => _mod(kYear - 1, 4) == 2;
}

/* ───────────────────────── SUPPORTING WIDGETS ───────────────────────── */

class _SeasonHeader extends StatelessWidget {
  final String title;
  const _SeasonHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
      child:
      _GlossyText(text: title, style: _seasonStyle, gradient: _goldGloss),
    );
  }
}

/* ─────────── Shared dark input (top-level so all pages can use it) ─────────── */

InputDecoration _darkInput(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: _silver),
    hintStyle: const TextStyle(color: _silver),
    filled: true,
    fillColor: const Color(0xFF1A1B1F),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _gold, width: 1.2),
    ),
  );
}
/* ───────────────────────── Ma’at Flows (templates registry) ───────────────────────── */

class _MaatFlowDay {
  final String title;
  final String? detail;
  const _MaatFlowDay({required this.title, this.detail});
}

class _MaatFlowTemplate {
  final String key;         // stable identifier (e.g., "wealth-economy")
  final String title;       // flow title
  final String overview;    // overview / description
  final List<_MaatFlowDay> days; // strictly length 10
  final Color color;        // a nice default color
  const _MaatFlowTemplate({
    required this.key,
    required this.title,
    required this.overview,
    required this.days,
    required this.color,
  });
}

/// First five flows you provided (10 days each). You can add more later.
const List<_MaatFlowTemplate> kMaatFlowTemplates = [
  _MaatFlowTemplate(
    key: 'wealth-economy',
    title: 'Wealth & Economy',
    overview:
    'During the first decan we explore how Old Kingdom Egyptians thought about wealth, labour, trade and the cosmic order of Ma’at. Each entry begins with a question and then unfolds as if told by a Kemetic worker, artisan or family. These narratives paint vivid daily scenes based on primary and secondary sources—excavated texts, art and modern scholarship. Instead of modern astronomical notes, they focus on lived experiences: stretching ropes in a muddy field, scooping barley into baskets, tasting the sweet tang of fermenting beer, or lifting a copper adze. By stepping into their world we see how the values of Maʿat shaped choices and created balance—and we can almost smell the baking bread and hear the ring of chisels.',
    color: Color(0xFFFFC145),
    days: [
      _MaatFlowDay(
        title: 'Day 1 — How did the job market work in the Old Kingdom?',
        detail: '''The Old Kingdom did not lock people into fixed castes. A Kemetic family lived by the rhythm of the river. In summer the husband waded into his flooded fields, muddy water swirling around his ankles as he planted wheat; come drier months he sat in the shade carving a cedar handle or mending his wife’s loom; during the inundation he climbed scaffolding to set limestone blocks in the king’s tomb. Labour was seasonal and rotational, and those who built pyramids and temples during the floods were compensated in bread and beer. Skill was an offering to the cosmic whole rather than an identity: a fine cobbler gained respect and extra rations, not a private fortune. At night, by oil-lamp, he scratched his changing tasks and rations into a papyrus ledger, knowing that his versatility kept his household fed and maintained Maʿat.''',
      ),
      _MaatFlowDay(
        title: 'Day 2 — What role did gold play in the Kemetic economy?',
        detail: '''Gold was considered the flesh of the gods. In the dim light of a shrine a carpenter could glimpse a statue’s gilded face glowing like sunrise; he bowed his head and inhaled incense before returning to his workshop and the smell of sawdust. Copper, on the other hand, was everyday: chisels, adzes, axes, saws, drills and fish-hooks were all made from copper. A Kemetic artisan seldom held raw gold; his callused hands gripped copper chisels as he carved limestone and wood, the metal warm from his touch. For ordinary people gold was not money but sacred brilliance; it adorned amulets and burial goods and signified the gods’ skin. In the marketplace, value was measured in grain and labour; the glow of gold inspired reverence, not commerce.''',
      ),
      _MaatFlowDay(
        title: 'Day 3 — How was grain used as currency?',
        detail: '''Cereal crops were the bedrock of the Old Kingdom economy. Wheat and barley fed households and fermented into beer; they were also the primary medium of exchange and the basis of wages. Workers received rations of bread and beer in return for their labour. Taxes were assessed in grain, and surplus stored in state granaries functioned like a bank account. A Kemetic farmer poured scoops of grain into a woven basket, listening to the rustle as his wife counted handfuls; he filled jars for levies and set aside sacks for sandals, oil or pottery. He tested the kernels between his teeth and tapped his clay silo walls to check for damp. Grain was both sustenance and savings; a cracked bin could mean hunger in the dry season.''',
      ),
      _MaatFlowDay(
        title: 'Day 4 — Was wealth about hoarding or balance?',
        detail: '''Kemetic wealth was measured not by accumulation but by harmony. Too much hoarded grain was an imbalance against Ma’at; temples and the state held surplus to redistribute during famine or festivals. Households kept enough to feed their members and offer to the gods, trusting that reciprocity would provide security. In the stillness of evening a farmer might open his granary door and listen to the soft whisper of grain; he would glance at a neighbour’s nearly empty bin and carry over a basketful, knowing they would help when his canal wall burst. Shared labour on royal projects built not just monuments but social credit; a man who spent days hauling stone could expect assistance when floods failed. Wealth, to him, was a web of obligations and mutual care—not the number of baskets in his storehouse.''',
      ),
      _MaatFlowDay(
        title: 'Day 5 — How did barter trade function?',
        detail: '''Without coinage, Egyptians relied on barter. Wheat, barley and oil were common trade goods. On market day the air smelled of onions, fish and wet earth; donkey carts jostled as people haggled. A farmer might spread grain on a reed mat to swap for a potter’s jar, a potter might trade his jars for sandals, and a sandal-maker might swap footwear for beer. Scribes in linen kilts recorded these exchanges in temple ledgers, watching for fairness. The ability to bargain honestly was a practical expression of Ma’at: exaggeration disrupted cosmic order. A Kemetic woman balancing a basket of leeks on her head gauged the weight of a clay jug in her hands before measuring out barley. Fair dealing built trust that extended beyond the transaction into festival feasts and flood season repairs.''',
      ),
      _MaatFlowDay(
        title: 'Day 6 — What were copper tools used for?',
        detail: '''Copper was the workhorse metal of the Old Kingdom. Archaeometallurgical studies reveal a toolkit of chisels, adzes, axes, saws, drills, cosmetic spatulas, weaving needles, leather-working awls, fish-hooks and harpoons. Copper was smelted from malachite and chalcopyrite and sometimes alloyed with arsenic to make it harder. These tools built homes, carved hieroglyphs and prepared food. In the workshop a carpenter felt the weight of his copper adze bite into a beam as wood shavings curled at his feet; his wife warmed a copper needle in her lap while weaving linen; their son’s bare feet gripped the riverbank as he cast a gleaming hook into the water. While craftspeople shaped copper, gold sat behind locked doors in temples and tombs. Tools were the backbone of the earthly realm, just as the goddess Nut’s body supported the heavens.''',
      ),
      _MaatFlowDay(
        title: 'Day 7 — How were wages paid in bread and beer?',
        detail: '''State labourers were not paid in coins but in rations. Workers on pyramid projects received daily allocations of bread, beer, onions and sometimes meat. Beer, brewed from barley and lightly fermented, was safer than raw water and calorically dense. Brew houses were often run by women, giving them a role in the economy. In the afternoon heat men lined up outside a granary while scribes scooped loaves and filled clay jars with frothy beer; the workers wiped sweat from their faces as they took their rations. A Kemetic man hefted sacks of bread and jars of beer over his shoulder and trudged home along the canal. His wife might have spent the day stirring bubbling mash in clay vats, the yeasty smell filling their yard, turning grain into a drink that nourished the whole household. Wages were eaten and drunk; rations fed bodies and fuelled gratitude toward the state and the gods.''',
      ),
      _MaatFlowDay(
        title: 'Day 8 — How did Ma’at shape economic behaviour?',
        detail: '''Maʿat governed honesty in trade and fairness in distribution. In the marketplace a farmer set down his basket and swore an oath over the balance and cubit rod before measuring barley; a scribe watched his hands and recorded the weight with care. Greed and hoarding were considered forms of isfet (chaos), inviting divine retribution. When a canal wall cracked, neighbours came with baskets of mud and willow poles without being asked; helping repair it was both obligation and insurance for the future. A Kemetic merchant might refuse a customer who tried to tip his scale, knowing that false measures offended the gods and the community alike. A woman pressing an extra loaf into a widow’s hands believed she was protecting her own family’s future, because Maʿat was reciprocal: what you gave returned in time of need.''',
      ),
      _MaatFlowDay(
        title: 'Day 9 — How did temple redistribution support society?',
        detail: '''Temples were economic hubs. They collected taxes in grain and produce, stored them in massive granaries, and redistributed food and resources to priests, workers and those in need. Festivals such as the Opet celebration consumed large portions of these stores, feeding entire communities. In return, people donated goods and labour to the temples. On feast days a Kemetic family donned clean linen and walked to the temple carrying a basket of barley and a jug of beer; the children’s eyes widened at the towering granary bins. Inside, priests and scribes scooped out rations with large wooden ladles, and the smell of roasting goose and freshly baked bread hung in the air. When the barque of Amun sailed during Opet, temple granaries opened and everyone—rich or poor—ate together on mats spread under date palms. Redistribution was not charity; it was the embodied law of Maʿat, and the family knew their offerings would come back to them in rations, festival feasts or relief during a famine.''',
      ),
      _MaatFlowDay(
        title: 'Day 10 — How were artisans rewarded?',
        detail: '''Artisans produced stone vessels, jewellery, statuary and textiles. Payment came in rations and in honour: names of outstanding builders and carvers were sometimes inscribed in tombs or recorded by scribes. Reputation could lead to better living quarters or increased grain allocations. No one amassed private fortunes; instead, skill earned social credit that endured into the afterlife when descendants recited their names at offering tables. In his workshop a Kemetic sculptor sat cross-legged on the floor, chisel tapping stone as sunlight slanted through the doorway. He paused to wipe dust from his face and considered the divine face he carved. At supper he returned home with bread, beer and onions; neighbours stopped by to admire a small figurine he brought for his wife. His children listened wide-eyed as others praised his hands. That praise was its own reward, ensuring his name would live when his body did not.''',
      ),
    ],
  ),


  _MaatFlowTemplate(
    key: 'family-life-marriage',
    title: 'Family Life & Marriage',
    overview:
    'This decan immerses us in the intimate world of Old Kingdom households. We step into mud‑brick courtyards where couples share bread, watch toddlers learn to walk and negotiate the practical and spiritual bonds of marriage. Marriage was not a grand public rite but a personal contract; divorce was possible; property could be held by either spouse. Families honoured elders and tended ancestors; respect for parents was fundamental. Through these ten entries we witness a wife balancing grain accounts, a husband building a new room for his growing family and a grandmother teaching grandchildren the correct way to pour a libation. Maʿat binds the home just as it binds the cosmos.',
    color: Color(0xFF55DDE0), // teal
    days: [
      _MaatFlowDay(
        title: 'Day 1 — What did a Kemetic marriage look like?',
        detail:
        'For a Kemetic couple, marriage began when they chose to live together. There was no state ceremony; rather, they moved into a house and pooled resources. Young men and women were free to seek partners, and premarital intimacy was accepted. A farmer brings his betrothed a gift of linen and bread, and together they smear fresh mud onto the walls of their shared home. Friends joke and help them carry mats, while elders bless them with advice about patience and reciprocity. This everyday act of cohabitation was both practical and sacred, aligning their household with Maʿat.',
      ),
      _MaatFlowDay(
        title: 'Day 2 — How did couples decide to marry?',
        detail:
        'Choosing a spouse was pragmatic and affectionate. Parents might introduce potential partners, but adolescents had a say. A young woman in the weaving room whispers to her friend about the carpenter’s steady hands and shares a honey cake he brought to her mother. Later she watches him harvest barley; she imagines his ability to farm during flood season and craft tools in the dry months. Affection was expressed through gifts and shared labour rather than formal courtship. Marriage happened when two people decided that their lives fit together and that their combined efforts would sustain their family.',
      ),
      _MaatFlowDay(
        title: 'Day 3 — What were the roles of parents and children?',
        detail:
        'Kemetic families were nuclear units nested within extended kin. Parents nurtured and provided; children respected elders and learned by watching. The eldest son or daughter was expected to care for ageing parents and ensure proper burials. A daughter helps her father prepare a funerary stela for his own mother, carefully painting hieroglyphs as he tells her stories of their ancestors. The son sits nearby grinding grain, knowing he will inherit his father’s tools and obligations. Respect flowed both ways: parents instructed with patience, and children offered obedience because Maʿat required harmony between generations.',
      ),
      _MaatFlowDay(
        title: 'Day 4 — How did spouses manage property?',
        detail:
        'Property rights in marriage were clearly defined. Each spouse retained ownership of what they brought to the union, and joint property could be used by the husband but still belonged to both. A wife might own a field inherited from her mother; her husband might own tools. Together they planted wheat in her field, and he built her a storage bin. When they measured the harvest, she recorded her share on a clay tablet, confident that if he died or they separated she would retain her land. The clarity of these arrangements ensured that love coexisted with legal autonomy.',
      ),
      _MaatFlowDay(
        title: 'Day 5 — How did divorce work in Kemet?',
        detail:
        'Either partner could initiate divorce. If a marriage faltered—perhaps due to infidelity or incompatibility—property was divided: each spouse left with what they had brought plus a share of jointly acquired goods. A woman sits with a scribe at the town gate, dictating a list of items to take from her former home: a mirror, two baskets of barley, a goat. Her ex‑husband watches silently, understanding that she has the right to leave. There is no social stigma; neighbours still greet her warmly. Divorce was a practical solution, not a moral failing.',
      ),
      _MaatFlowDay(
        title: 'Day 6 — What did love and affection look like?',
        detail:
        'Love poetry and erotic imagery show that Kemetic couples were affectionate. Husbands expressed desire in letters; wives reciprocated with teasing songs. A potter returns from market with a string of blue faience beads for his wife. They sit together on the roof at twilight, feet dangling, sharing beer and roasted onions. He quotes a line from a love poem comparing her to a lotus; she laughs and hands him a fig. Affection was woven into daily chores and quiet moments; romance did not require lavish gestures.',
      ),
      _MaatFlowDay(
        title: 'Day 7 — How were households organized?',
        detail:
        'Ideally, married couples lived in their own house, though extended family might share walls. Homes were built of mud‑brick, with a central room for cooking and sleeping and a flat roof for work and relaxation. In Deir el‑Medina the front room often served as a birthing space; midwives and female relatives gathered there to support labouring women. Our couple adds a second level when their family grows, stacking bricks in the cool morning hours while children chase goats. Household organization was practical and flexible, adapting to seasons and life stages.',
      ),
      _MaatFlowDay(
        title: 'Day 8 — How were births and child-rearing celebrated?',
        detail:
        'Children were blessings and responsibilities. Births took place at home with female relatives, midwives and the goddess Taweret invoked for protection. After a baby’s arrival, neighbours brought bread and beads; the mother rested on woven mats and drank barley beer to regain strength. Fathers registered the child’s name with a scribe and thanked their ancestors at the household shrine. Older children learned to recite ancestor names and help with chores. Raising children was a communal act that reinforced family cohesion and continuity.',
      ),
      _MaatFlowDay(
        title: 'Day 9 — How were marriages celebrated?',
        detail:
        'There were no elaborate weddings. Friends and family acknowledged the union with small gifts and shared meals. The groom gave presents to his bride and her family—perhaps linen, jewellery or labour. Neighbours bring baskets of vegetables, beer and small amulets; musicians beat drums as the couple sprinkles natron and incense on their doorway. The simple exchange of gifts and the couple’s declaration were enough to sanctify the partnership. Community recognition mattered more than formal ritual.',
      ),
      _MaatFlowDay(
        title: 'Day 10 — How did Maʿat shape family life?',
        detail:
        'Maʿat required balance and reciprocity in the home. Husbands and wives shared labour and decision‑making; respect for parents ensured continuity; generosity toward neighbours built social safety nets. A father teaching his son to plough tells him that a straight furrow is like an honest word: both align with Maʿat. A mother dividing loaves reminds her daughters that fairness keeps chaos away. Families who upheld these values believed their names would be remembered and their spirits sustained in the afterlife. Harmony within the household mirrored cosmic order.',
      ),
    ],
  ),

  _MaatFlowTemplate(
    key: 'women-roles-rights',
    title: 'Women’s Roles & Rights',
    overview:
    'Women in Old Kingdom Kemet enjoyed legal autonomy and social influence... Maʿat empowered them to act justly.',
    color: Color(0xFFE85DFF), // magenta
    days: [
      _MaatFlowDay(
          title: 'Day 1 — What legal rights did women have?',
          detail:
          'From the earliest Old Kingdom records...'),
      _MaatFlowDay
        (title: 'Day 2 — Could women own land and run businesses?',
          detail:
          'Yes. Women owned about ten percent of farmland...'),
      _MaatFlowDay
        (title: 'Day 3 — What roles did women play in agriculture and craft?',
          detail:
          'Women worked alongside men...'),
      _MaatFlowDay
        (title: 'Day 4 — Were women part of the priesthood?',
          detail:
          'Noblewomen served as priestesses...'),
      _MaatFlowDay
        (title: 'Day 5 — How did marriage affect women’s property?',
          detail:
          'Marriage did not erase a woman’s ownership...'),
      _MaatFlowDay(title: 'Day 6 — Could women take legal action in court?', detail: 'Women could and did initiate lawsuits...'),
      _MaatFlowDay(title: 'Day 7 — How did daughters inherit and transmit property?', detail: 'Property could pass through the female line...'),
      _MaatFlowDay(title: 'Day 8 — How did women contribute beyond the home?', detail: 'Women brewed beer, sold goods and practiced midwifery...'),
      _MaatFlowDay(title: 'Day 9 — Were there female scribes or doctors?', detail: 'While rare, women could become scribes or physicians...'),
      _MaatFlowDay(title: 'Day 10 — How did Maʿat shape female identity?', detail: 'Women embodied Maʿat through fairness and ritual cleanliness...'),
    ],
  ),

  _MaatFlowTemplate(
    key: 'work-craftsmanship',
    title: 'Work & Craftsmanship',
    overview:
    'Craftsmanship in Kemet was both physical labour and spiritual service... These entries explore the rhythm of work and pride.',
    color: Color(0xFF7C5CFF), // violet
    days: [
      _MaatFlowDay(title: 'Day 1 — What was a day like for a tomb builder?', detail: 'At dawn a Kemetic mason... the work was sacred.'),
      _MaatFlowDay(title: 'Day 2 — How were artisans organized and paid?', detail: 'Artisans were organized into crews...'),
      _MaatFlowDay(title: 'Day 3 — What did craft specialisation mean?', detail: 'Many developed specialised skills...'),
      _MaatFlowDay(title: 'Day 4 — How did families participate in craft production?', detail: 'Craft was often a family affair...'),
      _MaatFlowDay(title: 'Day 5 — What roles did scribes and overseers play?', detail: 'Scribes recorded wages and materials...'),
      _MaatFlowDay(title: 'Day 6 — How did craftsmen maintain Maʿat in their work?', detail: 'Maʿat required precision and honesty...'),
      _MaatFlowDay(title: 'Day 7 — What was life like in Deir el-Medina?', detail: 'A planned village, tight-knit community...'),
      _MaatFlowDay(title: 'Day 8 — How were goods exchanged among craftsmen?', detail: 'Workers bartered goods and services...'),
      _MaatFlowDay(title: 'Day 9 — Were there labour disputes?', detail: 'Yes, seeds of collective action were present...'),
      _MaatFlowDay(title: 'Day 10 — How did Maʿat guide craftsmanship?', detail: 'Craftsmanship was a form of devotion...'),
    ],
  ),

  _MaatFlowTemplate(
    key: 'food-drink',
    title: 'Food & Drink',
    overview:
    'Food connected Kemetic households to the earth, the gods and each other... smell the bread baking and taste the beer.',
    color: Color(0xFF41A5EE), // sky
    days: [
      _MaatFlowDay(title: 'Day 1 — What was the Kemetic staple diet?', detail: 'Bread, beer and vegetables formed the core...'),
      _MaatFlowDay(title: 'Day 2 — How was bread made and consumed?', detail: 'Bread came in many shapes...'),
      _MaatFlowDay(title: 'Day 3 — What role did beer play?', detail: 'Beer was brewed by fermenting bread and barley...'),
      _MaatFlowDay(title: 'Day 4 — What vegetables and fruits were cultivated?', detail: 'Onions, leeks, garlic, figs, dates...'),
      _MaatFlowDay(title: 'Day 5 — Was meat common?', detail: 'Meat was rare; fish and legumes were common...'),
      _MaatFlowDay(title: 'Day 6 — What were communal feasts like?', detail: 'Festivals redistributed meat, beer and bread...'),
      _MaatFlowDay(title: 'Day 7 — How was food stored and preserved?', detail: 'Grain silos, drying, sealed jars...'),
      _MaatFlowDay(title: 'Day 8 — What sweet treats were enjoyed?', detail: 'Honey, dates and figs...'),
      _MaatFlowDay(title: 'Day 9 — How did Maʿat influence food sharing?', detail: 'Generosity and hospitality embodied Maʿat...'),
      _MaatFlowDay(title: 'Day 10 — What other drinks existed besides beer?', detail: 'Wine for the wealthy, palm wine, herbal infusions...'),
    ],
  ),
];

/* ─────────────────────────── CALENDAR PAGE (flows + notes) ─────────────────────────── */

GlobalKey keyForMonth(int ky, int km) => GlobalObjectKey('y${ky}m${km}');

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {

  // Track whether the clientEventId migration has been executed.
  // This ensures the migration runs at most once per app session to avoid
  // concurrent modification errors and repeated work.
  bool _ranMigration = false;

  int _dataVersion = 0;
  void _bumpDataVersion() {
    // why: force landscape PageView child to reconstruct once when data hydrates
    if (!mounted) return;
    setState(() => _dataVersion++);
  }

  /* ───── today + notes + flows state ───── */

  late final ({int kYear, int kMonth, int kDay}) _today =
  KemeticMath.fromGregorian(DateTime.now());

  final Map<String, List<_Note>> _notes = {};
  List<_Flow> _flows = [];
  int _nextFlowId = 1;
  // Removed _nextAlarmId; notifications are persisted via Notify.scheduleAlertWithPersistence
  final ScrollController _scrollCtrl = ScrollController();

  /* ───── ClientEventId utilities ───── */
  /// Build a canonical clientEventId from Kemetic date, title, time and flow id.
  /// This helper ensures that every note uses the same format when being persisted
  /// and deleted. It slugifies the title by stripping non-word characters and
  /// trimming whitespace. The start time is converted to minutes since midnight,
  /// defaulting to 9:00 (540) when allDay is true or no start time is provided.
  /// A flowId of -1 indicates a manual/unlinked note.
  String _buildCid({
    required int ky,
    required int km,
    required int kd,
    required String title,
    int? startHour,
    int? startMinute,
    bool allDay = false,
    required int flowId,
  }) {
    final int sMin = (allDay || startHour == null || startMinute == null)
        ? 9 * 60
        : (startHour * 60 + startMinute);
    final String tSlug =
    title.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    return 'ky=$ky-km=$km-kd=$kd|s=$sMin|t=$tSlug|f=$flowId';
  }

  /// Extract the flow id from a unified clientEventId string. Returns -1 if
  /// parsing fails or no flow id segment is present. This can be used when
  /// reconstructing notes from persisted events.
  int _flowIdFromCid(String cid) {
    final m = RegExp(r'\|f=([\-0-9]+)').firstMatch(cid);
    if (m != null) {
      return int.tryParse(m.group(1)!) ?? -1;
    }
    return -1;
  }

  /// Remove legacy clientEventId formats and replace them with unified ones. This
  /// migration runs once on startup (scheduled via microtask) and rewrites
  /// any lingering events that still use old identifiers. It is idempotent and
  /// safe to run multiple times. If Ma’at notes use a separate namespace,
  /// they can be migrated by adding the appropriate legacy patterns here.
  Future<void> _migrateOldClientEventIds() async {
    try {
      final repo = UserEventsRepo(Supabase.instance.client);
      // Iterate over all notes in memory and rebuild unified ids
      // Iterate over a snapshot of entries to avoid concurrent modifications while iterating.
      final entries = _notes.entries.toList();
      for (final entry in entries) {
        final key = entry.key;
        // Parse kYear, kMonth, kDay from the map key. Keys are strings generated by _kKey, e.g. "2025-10-8".  We parse by splitting on '-'.
        int ky;
        int km;
        int kd;
        {
          // Fallback: parse from string form. Even if key is int (unlikely), toString() will yield a numeric string. We expect parts length == 3.
          final parts = key.toString().split('-');
          if (parts.length != 3) {
            // If the key is purely numeric, derive ky, km, kd by integer arithmetic as a fallback.
            final maybeInt = int.tryParse(key.toString());
            if (maybeInt != null) {
              ky = maybeInt ~/ 10000;
              km = (maybeInt % 10000) ~/ 100;
              kd = maybeInt % 100;
            } else {
              // Unknown key format; skip this entry.
              continue;
            }
          } else {
            ky = int.tryParse(parts[0]) ?? 0;
            km = int.tryParse(parts[1]) ?? 0;
            kd = int.tryParse(parts[2]) ?? 0;
          }
        }
        for (final note in entry.value) {
          // Build unified cid for this note
          final int fid = note.flowId ?? -1;
          final String unifiedCid = _buildCid(
            ky: ky,
            km: km,
            kd: kd,
            title: note.title,
            startHour: note.start?.hour,
            startMinute: note.start?.minute,
            allDay: note.allDay,
            flowId: fid,
          );
          // Determine legacy patterns used previously and remove them
          final String rawTitle = note.title;
          final String hhmm = note.start != null
              ? '${note.start!.hour.toString().padLeft(2, '0')}${note.start!.minute.toString().padLeft(2, '0')}'
              : '';
          final legacyIds = <String>{
            'note:${ky}-${km}-${kd}:${rawTitle.hashCode}',
            'ky=${ky}-km=${km}-kd=${kd}|t=${rawTitle}',
            if (hhmm.isNotEmpty)
              'note:${ky}-${km}-${kd}:${rawTitle}:${hhmm}',
          };
          for (final oldId in legacyIds) {
            try {
              await repo.deleteByClientId(oldId);
            } catch (_) {}
          }
          // Upsert unified row (idempotent)
          try {
            final g = KemeticMath.toGregorian(ky, km, kd);
            final DateTime startsAt = DateTime(
              g.year,
              g.month,
              g.day,
              note.start?.hour ?? 9,
              note.start?.minute ?? 0,
            );
            final DateTime? endsAt = note.end == null
                ? null
                : DateTime(g.year, g.month, g.day, note.end!.hour, note.end!.minute);
            await repo.upsertByClientId(
              clientEventId: unifiedCid,
              title: note.title,
              startsAtUtc: startsAt.toUtc(),
              detail: note.detail?.trim().isEmpty ?? true ? null : note.detail!.trim(),
              location: note.location?.trim().isEmpty ?? true ? null : note.location!.trim(),
              allDay: note.allDay,
              endsAtUtc: endsAt?.toUtc(),
            );
          } catch (e) {
            debugPrint('[migrate-cid] Failed to upsert unified cid: $e');
          }
        }
      }
      debugPrint('[migrate-cid] Completed pass.');
    } catch (e) {
      debugPrint('[migrate-cid] Migration failed: $e');
    }
  }



  int? _lastViewKy;       // last centered Kemetic year
  int? _lastViewKm;       // last centered Kemetic month (1..13)
  
  // Debug logging fields
  int _buildCount = 0; // Track how many times build() is called
  Orientation? _lastOrientation; // Track orientation changes


// Find the month card whose vertical center is closest to the viewport center.
  void _updateCenteredMonth() {
    // Check a reasonable window of years around the current scroll position:
    final candidates = <(int ky, int km, double dist)>[];
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final viewportCenterY = box.size.height / 2;

    bool addIfMounted(int ky, int km) {
      final key = keyForMonth(ky, km);
      final ctx = key.currentContext;
      if (ctx == null) return false;
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null) return false;
      final topLeft = rb.localToGlobal(Offset.zero, ancestor: box);
      final centerY = topLeft.dy + rb.size.height / 2;
      final dist = (centerY - viewportCenterY).abs();
      candidates.add((ky, km, dist));
      return true;
    }

    final today = _today;
    for (var dy = -3; dy <= 3; dy++) {
      final ky = today.kYear + dy;
      for (var km = 1; km <= 13; km++) {
        addIfMounted(ky, km);
      }
    }
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    _lastViewKy = candidates.first.$1;
    _lastViewKm = candidates.first.$2;
  }

  void _updateCenteredMonthWide() {
    final candidates = <(int ky, int km, double dist)>[];
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final viewportCenterY = box.size.height / 2;

    bool addIfMounted(int ky, int km) {
      final ctx = keyForMonth(ky, km).currentContext;
      if (ctx == null) return false;
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null) return false;
      final topLeft = rb.localToGlobal(Offset.zero, ancestor: box);
      final centerY = topLeft.dy + rb.size.height / 2;
      final dist = (centerY - viewportCenterY).abs();
      candidates.add((ky, km, dist));
      return true;
    }

    // Scan a wider band once (matches your 200-year slivers either side)
    final base = _today.kYear;
    for (var dy = -220; dy <= 220; dy++) {
      final ky = base + dy;
      // Quick early exit once we’ve found enough nearby candidates
      var foundAny = false;
      for (var km = 1; km <= 13; km++) {
        foundAny = addIfMounted(ky, km) || foundAny;
      }
      if (foundAny && candidates.length >= 6) break;
    }

    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    _lastViewKy = candidates.first.$1;
    _lastViewKm = candidates.first.$2;
  }

// Call on scroll to keep tracking the centered month.
  void _onVerticalScroll() {
    _updateCenteredMonth();
  }

  // toggle: Kemetic (false) <-> Gregorian overlay (true)
  bool _showGregorian = false;

  // for centering and for snapping to today
  final _centerKey = GlobalKey();
  final _todayMonthKey = GlobalKey(); // month card
  final _todayDayKey = GlobalKey();   // 🔑 individual day chip

  @override
  void initState() {
    super.initState();
    _lastViewKy = _today.kYear;
    _lastViewKm = _today.kMonth;

    _scrollCtrl.addListener(_onVerticalScroll);

    // notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToToday();
    });

    // Schedule a one-time migration of clientEventIds to the unified format.
    // Using Future.microtask ensures this runs after the first frame without blocking UI.
    // We guard the migration with the _ranMigration flag so that it executes
    // exactly once per app session and does not collide with subsequent data
    // loading or other migrations.
    Future.microtask(() async {
      if (!_ranMigration) {
        _ranMigration = true;
        try {
          await _migrateOldClientEventIds();
        } catch (_) {
          // ignore errors; migration is best-effort
        }
      }
    });
  }

  @override
  void dispose() {
    debugPrint('');
    debugPrint('🗑️  _CalendarPageState DISPOSING');
    debugPrint('   Total builds: $_buildCount');
    debugPrint('');
    _scrollCtrl.dispose();
    super.dispose();
  }

  /* ───── helpers ───── */

  String _kKey(int ky, int km, int kd) => '$ky-$km-$kd';

  List<_Note> _getNotes(int kYear, int kMonth, int kDay) {
    final key = _kKey(kYear, kMonth, kDay);
    final result = _notes[key] ?? const [];
    if (result.isNotEmpty) {
      print('_getNotes($kYear, $kMonth, $kDay) returning ${result.length} notes: ${result.map((n) => n.title).join(", ")}');
    }
    return result;
  }

  /// Flow occurrences that apply to a given Kemetic date (computed on demand).
  List<_FlowOccurrence> _getFlowOccurrences(int kYear, int kMonth, int kDay) {
    final g = KemeticMath.toGregorian(kYear, kMonth, kDay);
    final out = <_FlowOccurrence>[];
    for (final f in _flows) {
      if (!f.active) continue;
      if (f.start != null && g.isBefore(DateUtils.dateOnly(f.start!))) continue;
      if (f.end != null && g.isAfter(DateUtils.dateOnly(f.end!))) continue;
      for (final r in f.rules) {
        if (r.matches(ky: kYear, km: kMonth, kd: kDay, g: g)) {
          out.add(_FlowOccurrence(
            flow: f,
            allDay: r.allDay,
            start: r.start,
            end: r.end,
          ));
        }
      }
    }
    return out;
  }

  void _addNote(
      int kYear,
      int kMonth,
      int kDay,
      String title,
      String? detail, {
        String? location,
        bool allDay = false,
        TimeOfDay? start,
        TimeOfDay? end,
        int? flowId, // <-- NEW (optional)
      }) {
    final k = _kKey(kYear, kMonth, kDay);
    final list = _notes.putIfAbsent(k, () => <_Note>[]);
    list.add(_Note(
      title: title.trim(),
      detail: detail?.trim(),
      location: (location == null || location.trim().isEmpty)
          ? null
          : location.trim(),
      allDay: allDay,
      start: allDay ? null : start,
      end: allDay ? null : end,
      flowId: flowId,
    ));
    // Do not schedule notifications here; scheduling is handled by the caller.
    setState(() {});
  }

  void _deleteNote(int kYear, int kMonth, int kDay, int index) {
    final k = _kKey(kYear, kMonth, kDay);
    final list = _notes[k];
    if (list == null || index < 0 || index >= list.length) return;

    // Capture note before removal so we know what to delete remotely
    final note = list[index];
    final String deletedTitle = note.title;

    // Remove locally for responsive UI
    list.removeAt(index);
    if (list.isEmpty) _notes.remove(k);
    setState(() {});

    // ═══════════════════════════════════════════════════════════════
    // 🔧 ENHANCED DELETION - Try multiple CID candidates and fallback
    // This deletion is run asynchronously so the UI remains responsive.
    // ═══════════════════════════════════════════════════════════════
    Future.microtask(() async {
      final repo = UserEventsRepo(Supabase.instance.client);
      final Set<int> candidateFlowIds = <int>{};

      // Priority 1: Use the note's own flowId
      if (note.flowId != null) {
        candidateFlowIds.add(note.flowId!);
        if (kDebugMode) {
          debugPrint('[delete-note] Primary candidate: flowId=${note.flowId}');
        }
      }

      // Priority 2: Standalone fallback (-1)
      candidateFlowIds.add(-1);

      // Priority 3: Pre-fetch events from Supabase to gather other possible flowIds
      try {
        // Limit to a reasonable number of events for performance
        final events = await repo.getAllEvents(limit: 1000);
        for (final evt in events) {
          if (evt.title == deletedTitle) {
            // Extract flowId from unified CID if present
            final cid = evt.clientEventId;
            if (cid != null && cid.isNotEmpty) {
              final parsed = _flowIdFromCid(cid);
              // Only add valid flowIds (including -1) to candidates
              candidateFlowIds.add(parsed);
              if (kDebugMode) {
                debugPrint('[delete-note] Candidate from CID: flowId=$parsed, CID=$cid');
              }
            }
            // Also consider flowLocalId provided by the server
            final fid = evt.flowLocalId;
            if (fid != null) {
              candidateFlowIds.add(fid);
              if (kDebugMode) {
                debugPrint('[delete-note] Candidate from flowLocalId: $fid');
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[delete-note] ⚠️ Could not pre-fetch events for deletion: $e');
        }
      }

      // Convert to list for ordered iteration
      final List<int> candidates = candidateFlowIds.toList();
      if (kDebugMode) {
        debugPrint('[delete-note] Will try ${candidates.length} candidate flowIds: $candidates');
      }

      bool removed = false;
      String? successfulCid;
      final List<String> attemptedCids = [];

      // Try each candidate flowId
      for (final fid in candidates) {
        final String cid = _buildCid(
          ky: kYear,
          km: kMonth,
          kd: kDay,
          title: deletedTitle,
          startHour: note.start?.hour,
          startMinute: note.start?.minute,
          allDay: note.allDay,
          flowId: fid,
        );
        attemptedCids.add(cid);
        if (kDebugMode) {
          debugPrint('[delete-note] Trying CID: $cid');
        }
        try {
          await repo.deleteByClientId(cid);
          // Cancel the notification for this event so it does not fire after deletion
          try {
            await Notify.cancelNotificationForEvent(cid);
          } catch (_) {
            // ignore cancellation errors
          }
          removed = true;
          successfulCid = cid;
          if (kDebugMode) {
            debugPrint('[delete-note] ✅ SUCCESS: Deleted with CID: $cid');
          }
          // Show success toast
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Deleted: $deletedTitle'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          }
          break;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[delete-note] ⚠️ Failed to delete with flowId=$fid: $e');
          }
          // Continue to next candidate
        }
      }

      // ═════════════════════════════════════════════════════════════
      // 🚨 LAST RESORT: Direct deletion by matching title/date
      // ═════════════════════════════════════════════════════════════
      if (!removed) {
        if (kDebugMode) {
          debugPrint('[delete-note] All candidate CIDs failed. Trying direct title-based deletion...');
        }
        try {
          final events = await repo.getAllEvents(limit: 1000);
          for (final evt in events) {
            final evtTime = evt.startsAtUtc.toLocal();
            final kEvt = KemeticMath.fromGregorian(evtTime);
            if (evt.title == deletedTitle &&
                kEvt.kYear == kYear &&
                kEvt.kMonth == kMonth &&
                kEvt.kDay == kDay) {
              final cid = evt.clientEventId;
              if (cid != null && cid.isNotEmpty) {
                await repo.deleteByClientId(cid);
                // Cancel the notification for this event so it does not fire after deletion
                try {
                  await Notify.cancelNotificationForEvent(cid);
                } catch (_) {
                  // ignore cancellation errors
                }
                removed = true;
                successfulCid = cid;
                if (kDebugMode) {
                  debugPrint('[delete-note] ✅ SUCCESS (direct): Deleted using actual CID: $cid');
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Deleted: $deletedTitle'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
                break;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[delete-note] ❌ Direct deletion failed: $e');
          }
        }
      }

      // Final status: if still not removed, show error
      if (!removed) {
        debugPrint('[delete-note] ❌❌❌ CRITICAL: Could not delete note!');
        debugPrint('[delete-note] Note: "$deletedTitle", flowId=${note.flowId}');
        debugPrint('[delete-note] Attempted ${attemptedCids.length} CIDs: ${attemptedCids.join(", ")}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Could not delete "$deletedTitle". Please delete manually in Supabase.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else if (kDebugMode) {
        debugPrint('[delete-note] ✓ Deletion confirmed: $successfulCid');
      }
    });
  }

  Future<void> _tryDeleteWithCandidates({
    required UserEventsRepo repo,
    required int kYear,
    required int kMonth,
    required int kDay,
    required _Note note,
    required List<int> candidates,
    required int attemptIndex,
  }) async {
    if (attemptIndex >= candidates.length) {
      // All attempts failed
      if (kDebugMode) {
        debugPrint('[delete-note] ❌❌❌ CRITICAL: All ${candidates.length} candidates failed!');
        debugPrint('[delete-note] Note: ${note.title}, Candidates tried: $candidates');
      }
      // Show user warning
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Delete failed. Try restarting the app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final flowId = candidates[attemptIndex];
    final String cid = _buildCid(
      ky: kYear,
      km: kMonth,
      kd: kDay,
      title: note.title,
      startHour: note.start?.hour,
      startMinute: note.start?.minute,
      allDay: note.allDay,
      flowId: flowId,
    );
    if (kDebugMode) {
      debugPrint('[delete-note] Attempt ${attemptIndex + 1}/${candidates.length}: Trying flowId=$flowId');
      debugPrint('[delete-note] CID: $cid');
    }
    try {
      await repo.deleteByClientId(cid);
      // Cancel the notification for this event so it does not fire after deletion
      try {
        await Notify.cancelNotificationForEvent(cid);
      } catch (_) {
        // ignore cancellation errors
      }
      if (kDebugMode) {
        debugPrint('[delete-note] ✅ SUCCESS: Deleted with flowId=$flowId, CID=$cid');
      }
      // Success - show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Deleted: ${note.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[delete-note] ⚠️ Attempt ${attemptIndex + 1} failed: $e');
      }
      // Try next candidate
      await _tryDeleteWithCandidates(
        repo: repo,
        kYear: kYear,
        kMonth: kMonth,
        kDay: kDay,
        note: note,
        candidates: candidates,
        attemptIndex: attemptIndex + 1,
      );
    }
  }
  final Map<int, int> _flowLocalIdAliases = {}; // ⬅︎ unique: alias map for serverId→localId

  // Flows — add/remove/toggle
  // >>> FIND-ME: PATCH-2 _saveNewFlow AFTER
  void _saveNewFlow(_Flow flow) {
    final localId = _nextFlowId++;
    flow.id = localId;
    _flows.add(flow);
    setState(() {});

    // Save to Supabase in background, then unify IDs (server id replaces local)
    Future.microtask(() async {
      try {
        final repo = UserEventsRepo(Supabase.instance.client);
        final rulesJson = jsonEncode(flow.rules.map(ruleToJson).toList());

        final savedId = await repo.upsertFlow(
          id: null, // let server assign id
          name: flow.name,
          color: flow.color.value,
          active: flow.active,
          startDate: flow.start,
          endDate: flow.end,
          notes: flow.notes,
          rules: rulesJson,
        );
        final now = DateTime.now().toUtc();
        final today = DateTime.utc(now.year, now.month, now.day);
        if (flow.active == false) {
          await repo.deleteByFlowId(savedId, fromDate: today);
          await repo.deleteFlow(savedId);
        }




        if (savedId != localId) {
          // 1) update the in-memory flow id
          final idx = _flows.indexWhere((f) => f.id == localId);
          if (idx >= 0) {
            _flows[idx].id = savedId;
            // Add debug logging
            if (kDebugMode) {
              debugPrint('[saveNewFlow] Remapped flow ID: $localId → $savedId');
              debugPrint('[saveNewFlow] Flow "${_flows[idx].name}" color: ${_flows[idx].color.value.toRadixString(16)}');
            }
          }
          // 2) re-stamp any notes that used the local id to now use the server id
          _rekeyNotesFlowId(localId, savedId);

          // 3) keep nextFlowId monotonic
          if (savedId >= _nextFlowId) _nextFlowId = savedId + 1;

          if (mounted) setState(() {});
        }
      } catch (e) {
        debugPrint('Background flow sync failed: $e');
      }
    });
  }




  void _rekeyNotesFlowId(int fromId, int toId) {
    // Collect all notes that need database updates
    final List<({int ky, int km, int kd, _Note note})> notesToPersist = [];
    
    // Walk the in-memory notes map and change any note.flowId == fromId to toId
    _notes.updateAll((key, list) {
      return list.map((n) {
        if ((n.flowId ?? -1) == fromId) {
          final updatedNote = _Note(
            title: n.title,
            detail: n.detail,
            location: n.location,
            allDay: n.allDay,
            start: n.start,
            end: n.end,
            flowId: toId,
          );
          
          // Parse the key to get ky, km, kd
          final parts = key.split('-');
          if (parts.length == 3) {
            final ky = int.tryParse(parts[0]);
            final km = int.tryParse(parts[1]);
            final kd = int.tryParse(parts[2]);
            if (ky != null && km != null && kd != null) {
              notesToPersist.add((ky: ky, km: km, kd: kd, note: updatedNote));
            }
          }
          
          return updatedNote;
        }
        return n;
      }).toList();
    });
    
    // Persist to database
    if (notesToPersist.isNotEmpty) {
      Future.microtask(() async {
        try {
          final repo = UserEventsRepo(Supabase.instance.client);
          for (final item in notesToPersist) {
            final gDay = KemeticMath.toGregorian(item.ky, item.km, item.kd);
            final String cid = _buildCid(
              ky: item.ky,
              km: item.km,
              kd: item.kd,
              title: item.note.title,
              startHour: item.note.start?.hour,
              startMinute: item.note.start?.minute,
              allDay: item.note.allDay,
              flowId: toId,
            );
            final DateTime startsAt = DateTime(
              gDay.year,
              gDay.month,
              gDay.day,
              item.note.start?.hour ?? 9,
              item.note.start?.minute ?? 0,
            );
            DateTime? endsAt;
            if (item.note.allDay == false && item.note.end != null) {
              endsAt = DateTime(
                gDay.year,
                gDay.month,
                gDay.day,
                item.note.end!.hour,
                item.note.end!.minute,
              );
            }
            final String prefix = toId >= 0 ? 'flowLocalId=$toId;' : '';
            final String? det = item.note.detail;
            final String detailPayload = prefix + (det?.trim() ?? '');
            await repo.upsertByClientId(
              clientEventId: cid,
              title: item.note.title,
              startsAtUtc: startsAt.toUtc(),
              detail: detailPayload.isEmpty ? null : detailPayload,
              location: (item.note.location ?? '').trim().isEmpty ? null : item.note.location!.trim(),
              allDay: item.note.allDay,
              endsAtUtc: endsAt?.toUtc(),
            );
          }
          if (kDebugMode) {
            debugPrint('[rekeyNotesFlowId] Updated ${notesToPersist.length} notes from flowId=$fromId to flowId=$toId in database');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[rekeyNotesFlowId] Failed to persist flow ID updates: $e');
          }
        }
      });
    }
  }


  void _toggleFlowActive(int flowId, bool active) {
    final idx = _flows.indexWhere((f) => f.id == flowId);
    if (idx >= 0) {
      _flows[idx].active = active;
      setState(() {});

      Future.microtask(() async {
        try {
          final repo = UserEventsRepo(Supabase.instance.client);
          final f = _flows[idx];
          final rulesJson = jsonEncode(f.rules.map(ruleToJson).toList());
          await repo.upsertFlow(
            id: f.id,
            name: f.name,
            color: f.color.value,
            active: active,
            startDate: f.start,
            endDate: f.end,
            notes: f.notes,
            rules: rulesJson,
          );
        } catch (_) {}
      });
    }
  }


  void _deleteFlow(int flowId) {
    // prune notes tied to this flow from the in-memory map
    final keysToPrune = <String>[];
    _notes.forEach((k, list) {
      list.removeWhere((n) => n.flowId == flowId);
      if (list.isEmpty) keysToPrune.add(k);
    });
    for (final k in keysToPrune) {
      _notes.remove(k);
    }

    _flows.removeWhere((f) => f.id == flowId);
    setState(() {});

    Future.microtask(() async {
      try {
        final repo = UserEventsRepo(Supabase.instance.client);
        await repo.deleteByFlowId(flowId);
        await repo.deleteFlow(flowId);
        await _loadFromDisk();

      } catch (_) {}
    });
  }



  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _addMinutes(TimeOfDay t, int delta) {
    final m = (_toMinutes(t) + delta) % (24 * 60);
    return TimeOfDay(hour: (m ~/ 60), minute: m % 60);
  }

  String _timeRangeLabel({required bool allDay, TimeOfDay? start, TimeOfDay? end}) {
    if (allDay) return 'All-day';
    String s(TimeOfDay t) => _formatTimeOfDay(t);
    if (start != null && end != null) return '${s(start)} – ${s(end)}';
    if (start != null) return s(start);
    if (end != null) return '… – ${s(end)}';
    return '';
  }

  /// Gregorian label for a Kemetic month/year (handles epagomenal spanning years).
  String _gregYearLabelFor(int kYear, int kMonth) {
    final lastDay =
    (kMonth == 13) ? (KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5) : 30;
    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  }

  String _monthLabel(int kMonth) =>
      kMonth == 13 ? 'Heriu Renpet (ḥr.w rnpt)' : _MonthCard.monthNames[kMonth];

  /* ───── TODAY snap/center ───── */


  void _scrollToToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Prefer the exact day; fall back to the month card if needed
      final targetCtx = _todayDayKey.currentContext ?? _todayMonthKey.currentContext;
      if (targetCtx == null) return;

      // Find the scrollable that owns the calendar
      final scrollableState = Scrollable.of(targetCtx);
      if (scrollableState == null) return;
      final position = scrollableState.position;

      // Render boxes for target and viewport
      final targetBox = targetCtx.findRenderObject();
      final viewportBox = scrollableState.context.findRenderObject();
      if (targetBox is! RenderBox || viewportBox is! RenderBox) return;

      // Compute centers in global coordinates
      final targetCenterGlobal =
          targetBox.localToGlobal(targetBox.size.center(Offset.zero)).dy;
      final viewportTopGlobal = viewportBox.localToGlobal(Offset.zero).dy;
      final viewportCenterGlobal = viewportTopGlobal + viewportBox.size.height / 2;

      // Delta required to bring target center to viewport center
      final delta = targetCenterGlobal - viewportCenterGlobal;

      // Desired scroll offset (clamped to extents)
      double targetPixels = position.pixels + delta;
      targetPixels = targetPixels.clamp(position.minScrollExtent, position.maxScrollExtent);

      // Animate to the computed offset
      position.animateTo(
        targetPixels,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
  void _centerMonth(int ky, int km) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final targetCtx = keyForMonth(ky, km).currentContext;
      if (targetCtx == null) return;

      final scrollableState = Scrollable.of(targetCtx);
      if (scrollableState == null) return;
      final position = scrollableState.position;

      final targetBox = targetCtx.findRenderObject();
      final viewportBox = scrollableState.context.findRenderObject();
      if (targetBox is! RenderBox || viewportBox is! RenderBox) return;

      final targetCenterGlobal =
          targetBox.localToGlobal(targetBox.size.center(Offset.zero)).dy;
      final viewportTopGlobal = viewportBox.localToGlobal(Offset.zero).dy;
      final viewportCenterGlobal = viewportTopGlobal + viewportBox.size.height / 2;

      double targetPixels = position.pixels + (targetCenterGlobal - viewportCenterGlobal);
      targetPixels = targetPixels.clamp(position.minScrollExtent, position.maxScrollExtent);

      position.jumpTo(targetPixels);
    });
  }


  /* ───── Search ───── */

  void _openSearch() {
    showSearch(
      context: context,
      delegate: _EventSearchDelegate(
        notes: _notes,
        monthName: (km) => km == 13 ? 'Heriu Renpet (ḥr.w rnpt)' : _MonthCard.monthNames[km],
        gregYearLabelFor: _gregYearLabelFor,
        openDay: (ky, km, kd) {
          Navigator.of(context).pop(); // dismiss search
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openDaySheet(ky, km, kd);
          });
        },
      ),
    );
  }

  /* ───── Flow Studio ───── */

  // Centralize applying Flow Studio results to calendar state
  Future<void> _applyFlowStudioResult(_FlowStudioResult edited) async {
    int? finalFlowId; // <-- NEW: ensure we know the actual flow id to tag notes

    if (edited.deleteFlowId != null) {
      _deleteFlow(edited.deleteFlowId!);
    } else if (edited.savedFlow != null) {
      final f = edited.savedFlow!;
      final editFlowId = f.id >= 0 ? f.id : null;
      if (editFlowId != null) {
        // ✅ FIX: Persist to database when editing existing flow
        await _persistFlowStudioResult(edited);
        finalFlowId = editFlowId;
      } else {
        _saveNewFlow(f);
        finalFlowId = f.id; // <-- id assigned inside _saveNewFlow
      }
    }

    if (edited.plannedNotes.isNotEmpty) {
      for (final p in edited.plannedNotes) {
        final n = p.note;


        _addNote(
          p.ky,
          p.km,
          p.kd,
          n.title,
          n.detail,
          location: n.location,
          allDay: n.allDay,
          start: n.start,
          end: n.end,
          flowId: n.flowId ?? finalFlowId, // <-- NEW: ensure notes carry the flow id
        );

        final gDay = KemeticMath.toGregorian(p.ky, p.km, p.kd);
        final when = n.allDay
            ? DateTime(gDay.year, gDay.month, gDay.day, 9, 0)
            : DateTime(
          gDay.year,
          gDay.month,
          gDay.day,
          (n.start ?? const TimeOfDay(hour: 9, minute: 0)).hour,
          (n.start ?? const TimeOfDay(hour: 9, minute: 0)).minute,
        );

        final bodyLines = <String>[
          if ((n.location ?? '').trim().isNotEmpty) n.location!.trim(),
          if ((n.detail ?? '').trim().isNotEmpty) n.detail!.trim(),
        ];
        final body = bodyLines.isEmpty ? null : bodyLines.join('\n');

        // Generate clientEventId for this flow event. Use the unified
        // schema so that notifications persist across restarts and can be
        // cancelled by CID. Determine the correct flow id to stamp:
        final int noteFlowId = (n.flowId ?? finalFlowId) ?? -1;
        final String flowCid = _buildCid(
          ky: p.ky,
          km: p.km,
          kd: p.kd,
          title: n.title,
          startHour: (n.start ?? const TimeOfDay(hour: 9, minute: 0)).hour,
          startMinute: (n.start ?? const TimeOfDay(hour: 9, minute: 0)).minute,
          allDay: n.allDay,
          flowId: noteFlowId,
        );
        await Notify.scheduleAlertWithPersistence(
          clientEventId: flowCid,
          scheduledAt: when,
          title: n.title,
          body: body,
          payload: '{}',
        );
      }

      // Persist planned notes to Supabase for custom flows. Without this,
      // notes created via applyFlowStudioResult (e.g. editing an existing
      // flow) would vanish after a restart. Use the same unified clientEventId
      // and detail prefix logic as in _persistFlowStudioResult. Also stamp
      // the flow id onto the in-memory note so that deletion can reference
      // the correct flow.
      try {
        final repo2 = UserEventsRepo(Supabase.instance.client);
        for (final p in edited.plannedNotes) {
          final n = p.note;
          // Determine which flow id to tag: prefer the note's current flowId,
          // else fall back to the captured finalFlowId, else -1.
          final int noteFlowId = (n.flowId ?? finalFlowId) ?? -1;
          // Create a persisted copy of the note with the selected flow id.
          final _Note persisted = _Note(
            title: n.title,
            detail: n.detail,
            location: n.location,
            allDay: n.allDay,
            start: n.start,
            end: n.end,
            flowId: noteFlowId,
          );
          // Build canonical id using placement and persisted note fields
          final String cid = _buildCid(
            ky: p.ky,
            km: p.km,
            kd: p.kd,
            title: persisted.title,
            startHour: persisted.start?.hour,
            startMinute: persisted.start?.minute,
            allDay: persisted.allDay,
            flowId: noteFlowId,
          );
          final gDay = KemeticMath.toGregorian(p.ky, p.km, p.kd);
          final DateTime startsAt = DateTime(
            gDay.year,
            gDay.month,
            gDay.day,
            persisted.start?.hour ?? 9,
            persisted.start?.minute ?? 0,
          );
          DateTime? endsAt;
          if (persisted.allDay == false && persisted.end != null) {
            endsAt = DateTime(gDay.year, gDay.month, gDay.day, persisted.end!.hour, persisted.end!.minute);
          } else {
            endsAt = null;
          }
          final String prefix = noteFlowId >= 0 ? 'flowLocalId=${noteFlowId};' : '';
          final String? det = persisted.detail;
          final String detailPayload = prefix + (det?.trim() ?? '');
          await repo2.upsertByClientId(
            clientEventId: cid,
            title: persisted.title,
            startsAtUtc: startsAt.toUtc(),
            detail: detailPayload.isEmpty ? null : detailPayload,
            location: (persisted.location ?? '').trim().isEmpty ? null : persisted.location!.trim(),
            allDay: persisted.allDay,
            endsAtUtc: endsAt?.toUtc(),
          );
        }
      } catch (e) {
        debugPrint('persist planned notes (apply) failed: $e');
      }
    }
  }

  // Slide-up Flow Studio shell with inner Navigator and draggable behavior
  Future<void> _openFlowStudioSheet({
    required Widget Function(BuildContext innerCtx) rootBuilder,
  }) async {
    final result = await showModalBottomSheet<_FlowStudioResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (outerCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 1.0,
          snap: true,
          snapSizes: const [0.8, 1.0],
          expand: false,
          builder: (innerCtx, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Material(
                color: const Color(0xFF121214),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Navigator(
                        onGenerateInitialRoutes: (nav, initial) {
                          return [
                            MaterialPageRoute(
                              builder: (ctx) => rootBuilder(ctx),
                            ),
                          ];
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await _applyFlowStudioResult(result);
    }
  }


  void _openFlowsViewer() {
    _openFlowStudioSheet(
      rootBuilder: (innerCtx) {
        return _FlowsViewerPage(
          flows: _flows,
          fmtGregorian: (d) => d == null
              ? '--'
              : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          onCreateNew: () async {
            final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
              MaterialPageRoute(
                builder: (_) => _FlowStudioPage(
                  existingFlows: _flows,
                ),
              ),
            );
            if (edited != null) await _persistFlowStudioResult(edited);
          },
          onEditFlow: (id) async {
            final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
              MaterialPageRoute(
                builder: (_) => _FlowStudioPage(
                  existingFlows: _flows,
                  editFlowId: id,
                ),
              ),
            );
            if (edited != null) await _persistFlowStudioResult(edited);
          },
          openMaatFlows: () {
            Navigator.of(innerCtx).push(
              MaterialPageRoute(
                builder: (ctx3) => _MaatCategoriesPage(
                  hasActiveForKey: (key) => _hasActiveMaatInstanceFor(key),
                  onPickTemplate: (tpl) {
                    Navigator.of(ctx3).push(
                      MaterialPageRoute(
                        builder: (ctx4) => _MaatFlowTemplateDetailPage(
                          template: tpl,
                          addInstance: ({
                            required _MaatFlowTemplate template,
                            required DateTime startDate,
                            required bool useKemetic,
                          }) {
                            final id = _addMaatFlowInstance(
                              template: template,
                              startDate: startDate,
                              useKemetic: useKemetic,
                            );
                            return id;
                          },
                        ),
                      ),
                    );
                  },
                  onCreateNew: () async {
                    final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
                      MaterialPageRoute(
                        builder: (_) => _FlowStudioPage(
                          existingFlows: _flows,
                        ),
                      ),
                    );
                    if (edited != null) await _persistFlowStudioResult(edited);
                  },
                ),
              ),
            );
          },
          onEndFlow: (id) => _endFlow(id),
        );
      },
    );
  }

/* ─────────── Ma’at Flows helpers ─────────── */

  /// True if there is at least one *active* instance of template [tplKey]
  /// with any remaining day today or in the future.
  bool _hasActiveMaatInstanceFor(String tplKey) {
    final today = DateUtils.dateOnly(DateTime.now());
    return _flows.any((f) {
      final meta = notesDecode(f.notes);
      if (meta.maatKey != tplKey || !f.active) return false;
      for (final r in f.rules) {
        if (r is _RuleDates &&
            r.dates.any((d) => !DateUtils.dateOnly(d).isBefore(today))) {
          return true;
        }
      }
      return false;
    });
  }


  /// Create a user-owned *instance* from a Ma’at template starting on [startDate].
  /// - [useKemetic]: true to interpret [startDate] as Kemetic (kY/kM/kD); false = Gregorian.
  /// - Produces a new _Flow with explicit dates (10 days) and adds 10 notes linked to the flowId.
  /// - Returns the created flow's id.
  int _addMaatFlowInstance({
    required _MaatFlowTemplate template,
    required DateTime startDate,
    required bool useKemetic,
  }) {
    // 1) Build the 10 Gregorian dates starting at chosen start.
    final dates = <DateTime>{};
    DateTime firstG;
    if (useKemetic) {
      final k = KemeticMath.fromGregorian(startDate);
      // interpret startDate as selected Kemetic (already dateOnly)
      firstG = KemeticMath.toGregorian(k.kYear, k.kMonth, k.kDay);
    } else {
      firstG = DateUtils.dateOnly(startDate);
    }
    for (int i = 0; i < 10; i++) {
      dates.add(DateUtils.dateOnly(firstG.add(Duration(days: i))));
    }

    // 2) Build the flow object (RuleDates over those 10 days).
    final flow = _Flow(
      id: -1, // assigned on save
      name: template.title,
      color: template.color,
      active: true,
      rules: [
        _RuleDates(
          dates: dates,
          allDay: false,
          start: const TimeOfDay(hour: 9, minute: 0),
          end: const TimeOfDay(hour: 10, minute: 0),
        ),
      ],

      start: firstG,
      end: firstG.add(const Duration(days: 9)),
      // Encode meta so we can recognize in preview/end:
      // "mode=gregorian|kemetic; split=1; ov=...; maat=<key>"
      notes: [
        useKemetic ? 'mode=kemetic' : 'mode=gregorian',
        'split=1', // using explicit dates
        if (template.overview.trim().isNotEmpty)
          'ov=${Uri.encodeComponent(template.overview.trim())}',
        'maat=${template.key}',
      ].join(';'),
    );

    _saveNewFlow(flow); // assigns id and adds to _flows
    final flowId = _flows.last.id;

    // 3) Add 10 linked notes (title + detail from template).
    // Use 9am default; users can edit/delete individual notes later if they want.
    int dayIndex = 0;
    final ordered = dates.toList()..sort();
    for (final g in ordered) {
      final kyKmKd = KemeticMath.fromGregorian(g);
      final day = template.days[dayIndex];
      _addNote(
        kyKmKd.kYear,
        kyKmKd.kMonth,
        kyKmKd.kDay,
        day.title,
        day.detail,
        allDay: false,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 10, minute: 0),
        flowId: flowId,
      );
      // sync each auto-created flow day to Supabase (fire-and-forget)
      Future.microtask(() async {
        try {
          final repo = UserEventsRepo(Supabase.instance.client);
          final scheduledAt = DateTime(g.year, g.month, g.day, 9, 0);
          // Use unified clientEventId for Ma’at flows as well. The note uses
          // the same 9:00 start and 10:00 end times; flowId identifies the
          // owning flow. This allows deletion to operate uniformly.
          final String cid = _buildCid(
            ky: kyKmKd.kYear,
            km: kyKmKd.kMonth,
            kd: kyKmKd.kDay,
            title: day.title,
            startHour: 9,
            startMinute: 0,
            allDay: false,
            flowId: flowId,
          );
          await repo.upsertByClientId(
            clientEventId: cid,
            title: day.title,
            startsAtUtc: scheduledAt.toUtc(),
            detail: (day.detail ?? '').trim().isEmpty ? null : day.detail!.trim(),
            location: null,
            allDay: false,
            endsAtUtc: DateTime(g.year, g.month, g.day, 10, 0).toUtc(),
          );
        } catch (_) {}
      });


      dayIndex++;
    }
    setState(() {});
    return flowId;
  }

  /// End a Ma’at flow instance:
  /// - removes any *linked* notes from today forward
  /// - sets the flow inactive
  //// === FLOW LIFECYCLE: END FLOW ===
  Future<void> _endFlow(int flowId) async {
    // ═══════════════════════════════════════════════════════════════
    // 🔧 FIXED _endFlow - Properly cleans up ALL notes (past AND future)
    // ═══════════════════════════════════════════════════════════════
    final today = DateTime.now().toUtc();
    final todayDateOnly = DateTime.utc(today.year, today.month, today.day);
    if (kDebugMode) {
      debugPrint('[endFlow] Starting cleanup for flowId=$flowId');
    }
    // 1) Remove from in-memory notes (both past AND future)
    final List<String> _keysToPrune = [];
    _notes.forEach((k, list) {
      // Remove ALL notes for this flow (not just future ones)
      final originalLength = list.length;
      list.removeWhere((n) => (n.flowId ?? -1) == flowId);
      if (kDebugMode && originalLength != list.length) {
        debugPrint('[endFlow] Removed ${originalLength - list.length} notes from day $k');
      }
      if (list.isEmpty) _keysToPrune.add(k);
    });
    for (final k in _keysToPrune) {
      _notes.remove(k);
    }
    // 2) Mark flow inactive in memory
    final idx = _flows.indexWhere((f) => f.id == flowId);
    if (idx >= 0) {
      final f = _flows[idx];
      _flows[idx] = _Flow(
        id: f.id,
        name: f.name,
        color: f.color,
        active: false,
        rules: f.rules,
        start: f.start,
        end: f.end,
        notes: f.notes,
      );
    }
    if (mounted) setState(() {});
    // 3) Persist to database
    final repo = UserEventsRepo(Supabase.instance.client);
    // Mark flow as inactive
    try {
      if (idx >= 0) {
        final f = _flows[idx];
        final rulesJson = jsonEncode(f.rules.map(ruleToJson).toList());
        await repo.upsertFlow(
          id: f.id,
          name: f.name,
          color: f.color.value,
          active: false,
          startDate: f.start,
          endDate: f.end,
          notes: f.notes,
          rules: rulesJson,
        );
        if (kDebugMode) {
          debugPrint('[endFlow] ✓ Marked flow $flowId as inactive');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[endFlow] ⚠️ Failed to mark flow inactive: $e');
      }
    }
    // 🔧 KEY FIX: Delete ALL notes for this flow, not just future ones
    try {
      await repo.deleteByFlowId(flowId);
      if (kDebugMode) {
        debugPrint('[endFlow] ✓ Deleted ALL notes for flowId=$flowId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[endFlow] ⚠️ Failed to delete notes: $e');
      }
    }

    // Cancel all notifications for this flow's events
    try {
      final events = await repo.getAllEvents();
      for (final evt in events) {
        if (evt.flowLocalId == flowId || _flowIdFromCid(evt.clientEventId ?? '') == flowId) {
          final String? cid = evt.clientEventId;
          if (cid != null) {
            try {
              await Notify.cancelNotificationForEvent(cid);
            } catch (_) {
              // ignore cancellation errors
            }
          }
        }
      }
      if (kDebugMode) {
        debugPrint('[endFlow] ✔ Cancelled notifications for flowId=$flowId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[endFlow] ⚠️ Failed to cancel notifications: $e');
      }
    }
    // Delete the flow itself
    try {
      await repo.deleteFlow(flowId);
      if (kDebugMode) {
        debugPrint('[endFlow] ✓ Deleted flow $flowId from database');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[endFlow] ⚠️ Failed to delete flow: $e');
      }
    }
    // Reload from disk to ensure UI is in sync
    await _loadFromDisk();
    if (kDebugMode) {
      debugPrint('[endFlow] ✓ Flow cleanup complete');
    }
  }
//// === END END FLOW ===






  /* ───── Day View Navigation ───── */

  void _openDayView(BuildContext ctx, int kYear, int kMonth, int kDay) {
    // Adapter: Convert _Note to NoteData
    final notesForDayFn = (int y, int m, int d) {
      final key = '$y-$m-$d';
      final notes = _notes[key] ?? [];
      return notes.map((n) => NoteData(
        title: n.title,
        detail: n.detail,
        location: n.location,
        allDay: n.allDay,
        start: n.start,
        end: n.end,
        flowId: n.flowId,
      )).toList();
    };

    // Adapter: Convert _Flow to FlowData
    final flowIndex = <int, FlowData>{};
    for (final f in _flows.where((f) => f.active)) {
      flowIndex[f.id] = FlowData(
        id: f.id,
        name: f.name,
        color: f.color,
        active: f.active,
      );
    }

    // Get month name function
    final getMonthName = (int km) {
      if (km == 13) return 'Heriu Renpet (ḥr.w rnpt)';
      return _MonthCard.monthNames[km] ?? 'Month $km';
    };

    // Navigate to Day View
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (context) => DayViewPage(
          initialKy: kYear,
          initialKm: kMonth,
          initialKd: kDay,
          showGregorian: _showGregorian,
          notesForDay: notesForDayFn,
          flowIndex: flowIndex,
          getMonthName: getMonthName,
          onManageFlows: _openFlowsViewer, // Wire up to existing method
          onAddNote: (ky, km, kd) => _openDaySheet(ky, km, kd, allowDateChange: true),
        ),
      ),
    );
  }

  /* ───── Day Sheet ───── */

  void _openDaySheet(
      int kYear,
      int kMonth,
      int kDay, {
        bool allowDateChange = false,
      }) {
    debugPrint('');
    debugPrint('┌─────────────────────────────────────┐');
    debugPrint('│ 📝 OPENING DAY SHEET                │');
    debugPrint('├─────────────────────────────────────┤');
    debugPrint('│ Date: $kYear/$kMonth/$kDay');
    debugPrint('│ allowDateChange: $allowDateChange');
    debugPrint('│ Context mounted: ${context.mounted}');
    debugPrint('│ Context widget: ${context.widget.runtimeType}');
    debugPrint('│ Build count: $_buildCount');
    debugPrint('└─────────────────────────────────────┘');
    debugPrint('');

    int selYear = kYear;
    int selMonth = kMonth;
    int selDay = kDay;

    int maxDayFor(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    final int yearStart = _today.kYear - 200;
    final int yearItem = kYear - yearStart;
    final yearCtrl =
    FixedExtentScrollController(initialItem: yearItem.clamp(0, 400).toInt());
    final monthCtrl =
    FixedExtentScrollController(initialItem: (kMonth - 1).clamp(0, 12).toInt());
    final dayCtrl = FixedExtentScrollController(initialItem: (kDay - 1));

    final controllerTitle = TextEditingController();
    final controllerLocation = TextEditingController();
    final controllerDetail = TextEditingController();

    bool allDay = false;
    TimeOfDay? startTime = const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay? endTime = const TimeOfDay(hour: 13, minute: 0);

    try {
      debugPrint('🚀 Attempting to show modal bottom sheet...');
    showModalBottomSheet(
        context: context,
      isScrollControlled: true,
        backgroundColor: Colors.transparent, // ✅ More stable like Flow Studio
        isDismissible: true,
        enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final media = MediaQuery.of(sheetCtx);

        final labelStyleWhite = const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        );

        final fieldLabel = const TextStyle(fontSize: 12, color: Color(0xFFBFC3C7));

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            const double _detailFontSize = 12.0;
            const double _detailLineHeight = 1.35;
            const int _detailVisibleLines = 3;
            const double _detailBoxHeight =
                _detailFontSize * _detailLineHeight * _detailVisibleLines;
            // Clamp before any toGregorian
            int dayCount = maxDayFor(selYear, selMonth);
            if (selDay > dayCount) {
              selDay = dayCount;
              if (allowDateChange && dayCtrl.hasClients) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => dayCtrl.jumpToItem(selDay - 1));
              }
            }

            final titleG = KemeticMath.toGregorian(selYear, selMonth, selDay); // safe
            final titleText = '${_monthLabel(selMonth)} $selDay • ${titleG.year}';

            final dayNotes = _getNotes(selYear, selMonth, selDay);
            final dayFlows = _getFlowOccurrences(selYear, selMonth, selDay);

            Future<void> pickStart() async {
              final t = await showTimePicker(
                context: sheetCtx,
                initialTime: startTime ?? const TimeOfDay(hour: 12, minute: 0),
                builder: (c, w) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _gold,
                      surface: _bg,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: w ?? const SizedBox.shrink(),
                ),
              );
              if (t == null) return;
              setSheetState(() {
                startTime = t;
                if (endTime != null && _toMinutes(endTime!) <= _toMinutes(t)) {
                  endTime = _addMinutes(t, 60);
                }
              });
            }

            Future<void> pickEnd() async {
              final t = await showTimePicker(
                context: sheetCtx,
                initialTime: endTime ??
                    (startTime != null
                        ? _addMinutes(startTime!, 60)
                        : const TimeOfDay(hour: 13, minute: 0)),
                builder: (c, w) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _gold,
                      surface: _bg,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: w ?? const SizedBox.shrink(),
                ),
              );
              if (t == null) return;
              setSheetState(() {
                endTime = t;
                if (startTime != null && _toMinutes(t) <= _toMinutes(startTime!)) {
                  startTime = _addMinutes(t, -60);
                }
              });
            }

            Widget timeButton({
              required String label,
              required TimeOfDay? value,
              required VoidCallback onTap,
              required bool enabled,
            }) {
              final text = value == null ? '--:--' : _formatTimeOfDay(value);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: fieldLabel),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _silver, width: 1),
                      ),
                      onPressed: enabled ? onTap : null,
                      child: Text(text),
                    ),
                  ),
                ],
              );
            }

            Widget datePicker() {
              if (!allowDateChange) {
                return Text(titleText, style: labelStyleWhite);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titleText,
                      textAlign: TextAlign.center, style: labelStyleWhite),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 128,
                    child: Row(
                      children: [
                        // Month
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: monthCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                selMonth = (i % 13) + 1;
                                final max = maxDayFor(selYear, selMonth);
                                if (selDay > max) {
                                  selDay = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance.addPostFrameCallback(
                                          (_) => dayCtrl.jumpToItem(selDay - 1),
                                    );
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(13, (i) {
                              final m = i + 1;
                              final label = (m == 13)
                                  ? 'Heriu Renpet (ḥr.w rnpt)'
                                  : _MonthCard.monthNames[m];
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Day
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dayCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                final max = maxDayFor(selYear, selMonth);
                                selDay = (i % max) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayCount, (i) {
                              final d = i + 1;
                              return Center(
                                child: _GlossyText(
                                  text: '$d',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Year (gregorian label)
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: yearCtrl,
                            itemExtent: 32,
                            looping: false,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                selYear = yearStart + i;
                                final max = maxDayFor(selYear, selMonth);
                                if (selDay > max) {
                                  selDay = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance.addPostFrameCallback(
                                          (_) => dayCtrl.jumpToItem(selDay - 1),
                                    );
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(401, (i) {
                              final ky = yearStart + i;
                              final label = _gregYearLabelFor(ky, selMonth);
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Container(
              height: media.size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF000000), // ✅ True black background
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: media.viewInsets.bottom + 12,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // drag handle
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Date (static or wheels)
                      datePicker(),
                      const SizedBox(height: 12),

                      // Scheduled flows (read-only preview)
                      if (dayFlows.isNotEmpty) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _GlossyText(
                            text: 'Scheduled flows',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            gradient: _silverGloss,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 160, // hard height so children get tight constraints
                          child: ListView.separated(
                            primary: false,
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: dayFlows.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 12, color: Colors.white10),
                            itemBuilder: (_, i) {
                              final occ = dayFlows[i];
                              final timeLine = _timeRangeLabel(
                                allDay: occ.allDay,
                                start: occ.start,
                                end: occ.end,
                              );
                              return Row(
                                children: [
                                  // colored dot
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: _glossFromColor(occ.flow.color),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _GlossyText(
                                          text: occ.flow.name,
                                          style: const TextStyle(fontSize: 14),
                                          gradient: _silverGloss,
                                        ),
                                        if (timeLine.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              timeLine,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _openFlowsViewer,
                            icon: const Icon(Icons.view_timeline, color: _silver),
                            label: const _GlossyText(
                              text: 'Manage flows',
                              style: TextStyle(fontSize: 14),
                              gradient: _silverGloss,
                            ),
                          ),
                        ),
                        const Divider(height: 16, color: Colors.white12),
                      ],

                      // Existing notes
                      if ((_dataVersion > 0) && dayNotes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: _GlossyText(
                            text: 'No notes yet',
                            style: TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        )
                      else
                        ListView.separated(
                          primary: false,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dayNotes.length,
                          separatorBuilder: (_, __) =>
                          const Divider(height: 12, color: Colors.white10),
                          itemBuilder: (_, i) {
                            final n = dayNotes[i];
                            final timeLine = _timeRangeLabel(
                              allDay: n.allDay,
                              start: n.start,
                              end: n.end,
                            );
                            final location = (n.location?.isEmpty ?? true) ? null : n.location!;
                            final detail = (n.detail?.isEmpty ?? true) ? null : n.detail!;

                            return SizedBox(
                              width: double.infinity,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _GlossyText(
                                          text: n.title,
                                          style: const TextStyle(fontSize: 16),
                                          gradient: _silverGloss,
                                        ),
                                        if (timeLine.isNotEmpty || location != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            [if (timeLine.isNotEmpty) timeLine, if (location != null) location!].join(' • '),
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        ],
                                        if (detail != null && detail.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            detail,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: _silver),
                                    onPressed: () async {
                                      final deletedTitle = n.title;

                                      // Immediate optimistic UI update
                                      setState(() {
                                        _deleteNote(selYear, selMonth, selDay, i);
                                      });

                                      // Close the current sheet if it is open (no reopen to avoid stale context crash)
                                      if (Navigator.canPop(sheetCtx)) {
                                        Navigator.pop(sheetCtx);
                                      }

                                      // Deletion of Supabase entries is handled inside _deleteNote via
                                      // unified clientEventId candidates. Simply reload from server
                                      // after deletion to refresh UI from truth.
                                      try {
                                        await _loadFromDisk();
                                      } catch (_) {}
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const Divider(height: 16, color: Colors.white12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _GlossyText(
                          text: 'Add note',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          gradient: _silverGloss,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      TextField(
                        controller: controllerTitle,
                        style: const TextStyle(color: Colors.white),
                        decoration: _darkInput('Title'),
                      ),
                      const SizedBox(height: 8),

                      // Location
                      TextField(
                        controller: controllerLocation,
                        style: const TextStyle(color: Colors.white),
                        decoration: _darkInput(
                          'Location or Video Call',
                          hint: 'e.g., Home • Zoom • https://meet…',
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Details
                      TextField(
                        controller: controllerDetail,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: _darkInput('Details (optional)'),
                      ),

                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: allDay,
                        onChanged: (v) => setSheetState(() => allDay = v),
                        title: const _GlossyText(
                          text: 'All-day',
                          style: TextStyle(fontSize: 14),
                          gradient: _silverGloss,
                        ),
                        activeThumbColor: _gold,
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: timeButton(
                              label: 'Starts',
                              value: startTime,
                              onTap: pickStart,
                              enabled: !allDay,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: timeButton(
                              label: 'Ends',
                              value: endTime,
                              onTap: pickEnd,
                              enabled: !allDay,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () async {
                            final t = controllerTitle.text.trim();
                            final loc = controllerLocation.text.trim();
                            final d = controllerDetail.text.trim();
                            if (t.isEmpty) return;

                            if (!allDay && startTime != null && endTime != null) {
                              if (_toMinutes(endTime!) <= _toMinutes(startTime!)) {
                                endTime = _addMinutes(startTime!, 60);
                              }
                            }

                            // Save to the in-memory notes map
                            _addNote(
                              selYear,
                              selMonth,
                              selDay,
                              t,
                              d.isEmpty ? null : d,
                              location: loc.isEmpty ? null : loc,
                              allDay: allDay,
                              start: startTime,
                              end: endTime,
                            );
// user_events: upsert
                            // (removed legacy duplicate upsert here; canonical upsert kept later)


                            // Compute when to alert
                            final gDay = KemeticMath.toGregorian(selYear, selMonth, selDay);
                            final scheduledAt = allDay
                                ? DateTime(gDay.year, gDay.month, gDay.day, 9, 0) // default 9:00 AM
                                : DateTime(
                                gDay.year, gDay.month, gDay.day, startTime!.hour, startTime!.minute);

                            // sync manual note to Supabase (fire-and-forget)
// (removed legacy duplicate upsert here; canonical upsert kept below)


                            // Build a simple text body: Location (if any) + Details (if any)
                            final bodyLines = <String>[
                              if (loc.isNotEmpty) loc,
                              if (d.isNotEmpty) d,
                            ];
                            final body = bodyLines.isEmpty ? null : bodyLines.join('\n');

                            // Build canonical clientEventId for this manual note. Use unified
                            // schema: include the Kemetic date, slugified title, optional start
                            // time (or null for all-day), and flowId=-1 since manual notes are
                            // not linked to a flow. This ensures that notifications persist
                            // across app restarts and can be cancelled by CID.
                            final String unifiedCid = _buildCid(
                              ky: selYear,
                              km: selMonth,
                              kd: selDay,
                              title: t,
                              startHour: (allDay || startTime == null) ? null : startTime!.hour,
                              startMinute: (allDay || startTime == null) ? null : startTime!.minute,
                              allDay: allDay,
                              flowId: -1,
                            );
                            // Schedule the local notification WITH PERSISTENCE
                            await Notify.scheduleAlertWithPersistence(
                              clientEventId: unifiedCid,
                              scheduledAt: scheduledAt,
                              title: t,
                              body: body,
                              payload: '{}',
                            );
// ── sync to Supabase: create/update this event for the signed-in user
                            try {
                              final repo = UserEventsRepo(Supabase.instance.client);

                              // Canonical client_event_id using unified schema. Use the
                              // placement date (selYear/selMonth/selDay) and slugified
                              // title. Include the start time (default 9:00) and flowId -1
                              // for manual notes.
                              final String unifiedCid = _buildCid(
                                ky: selYear,
                                km: selMonth,
                                kd: selDay,
                                title: t,
                                startHour: (allDay || startTime == null) ? null : startTime!.hour,
                                startMinute: (allDay || startTime == null) ? null : startTime!.minute,
                                allDay: allDay,
                                flowId: -1,
                              );

                              final endsAtUtc = (allDay || endTime == null)
                                  ? null
                                  : DateTime(gDay.year, gDay.month, gDay.day, endTime!.hour, endTime!.minute).toUtc();

                              await repo.upsertByClientId(
                                clientEventId: unifiedCid,
                                title: t,
                                startsAtUtc: scheduledAt.toUtc(),
                                detail: d.isEmpty ? null : d,
                                location: loc.isNotEmpty ? loc : null,
                                allDay: allDay,
                                endsAtUtc: endsAtUtc,
                              );
                            } catch (e) {
                              // non-fatal; keep UX flowing
                            }


                            Navigator.pop(sheetCtx);
                            _openDaySheet(
                              selYear,
                              selMonth,
                              selDay,
                              allowDateChange: allowDateChange,
                            );
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    
    debugPrint('✅ Modal bottom sheet opened successfully');
    
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ ERROR OPENING DAY SHEET');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('');
    }
  }


  /* ───── UI ───── */
  bool _initOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initOnce) {
      _initOnce = true;
      _loadFromDisk();
    }
  }

  Future<void> _loadFromDisk() async {
    print('=== _loadFromDisk START ===');

    try {
      final repo = UserEventsRepo(Supabase.instance.client);

      // Flow-first: clear, load flows, then events; join only to known active flows
      _notes.clear();
      _flows.clear();

      // Load flows into _flows list
      final serverFlows = await repo.getAllFlows();
      for (final f in serverFlows) {
        final flow = _Flow(
          id: f.id,
          name: f.name,
          color: Color(f.color),
          active: f.active,
          rules: _parseRules(f.rules),
          start: f.startDate,
          end: f.endDate,
          notes: f.notes,
        );
        _flows.add(flow);
        // 🔍 DEBUG: Log what color came from database for ALL custom flows
        // Log flows with ID greater than 156 to catch all user-created flows
        if (kDebugMode && f.id > 156) {
          debugPrint('[loadFlows] Flow ${f.id} "${f.name}" loaded with color=${f.color} (0x${f.color.toRadixString(16)})');
        }
        if (flow.id >= _nextFlowId) _nextFlowId = flow.id + 1;
      }
      final Set<int> activeFlowIds =
      _flows.where((f) => f.active).map((f) => f.id).toSet();

      // Load events → into _notes map (skip events whose flow is not active/known)
      final serverEvents = await repo.getAllEvents();

      print('[_loadFromDisk] events fetched: ${serverEvents.length}, activeFlowIds size: ${activeFlowIds.length}');

      // Fallback: if flows weren't hydrated (RLS/ordering), rehydrate locally to avoid gray paint
      Set<int> _activeIds = activeFlowIds;
      if (_activeIds.isEmpty) {
        try {
          final fallbackFlows = await repo.getAllFlows();
          _activeIds = fallbackFlows.where((f) => f.active).map((f) => f.id).toSet();
          print('[_loadFromDisk] fallback activeFlowIds size: ${_activeIds.length}');
        } catch (_) {}
      }

      int _added = 0;
      // Map for quick lookup of flows by id
      final Map<int, _Flow> _flowIndex = {for (final f in _flows) f.id: f};

      for (final evt in serverEvents) {
        // ═══════════════════════════════════════════════════════════════
        // 🔧 FIX STARTS HERE - Parse flowId from clientEventId FIRST
        // ═══════════════════════════════════════════════════════════════
        int? flowId;
        // Priority 1: extract from unified clientEventId format (|f=<id>)
        if (evt.clientEventId != null && evt.clientEventId!.isNotEmpty) {
          final parsedFlowId = _flowIdFromCid(evt.clientEventId!);
          // Accept values other than -1; -1 indicates standalone
          if (parsedFlowId != -1 || evt.clientEventId!.contains('|f=-1')) {
            flowId = parsedFlowId;
            if (kDebugMode) {
              debugPrint('[loader] ✓ Parsed flowId=$flowId from CID: ${evt.clientEventId}');
            }
          }
        }
        // Priority 2: fallback to server-provided flowLocalId field
        if (flowId == null && evt.flowLocalId != null) {
          flowId = evt.flowLocalId;
          if (kDebugMode) {
            debugPrint('[loader] ℹ️  Using server flowLocalId=$flowId (no CID)');
          }
        }
        // Priority 3: parse legacy format from detail field ("flowLocalId=N;...")
        String? detailStr = evt.detail;
        if (flowId == null && detailStr != null && detailStr.startsWith('flowLocalId=')) {
          final semi = detailStr.indexOf(';');
          if (semi > 0) {
            final idPart = detailStr.substring('flowLocalId='.length, semi);
            final parsed = int.tryParse(idPart);
            if (parsed != null) {
              flowId = parsed;
              if (kDebugMode) {
                debugPrint('[loader] ℹ️  Parsed flowId=$flowId from legacy detail prefix');
              }
            }
            // Strip the prefix so it never shows up in the UI
            detailStr = detailStr.substring(semi + 1);
          }
        }
        // Validate: ensure flowId maps to an active flow; otherwise skip notes from inactive/deleted flows
        if (flowId != null && flowId > 0) {
          final f = _flowIndex[flowId];
          if (f == null || !f.active) {
            // 🔧 KEY FIX: skip notes from inactive or deleted flows entirely
            if (kDebugMode) {
              debugPrint('[loader] ⚠️  flowId=$flowId inactive/deleted → SKIPPING note: "${evt.title}"');
            }
            continue;
          } else {
            if (kDebugMode) {
              debugPrint('[loader] ✓ flowId=$flowId validated against active flow: ${f.name}');
            }
          }
        } else if (flowId == -1) {
          // -1 is valid marker for standalone/manual note
          if (kDebugMode) {
            debugPrint('[loader] ✓ Standalone note (flowId=-1)');
          }
        }
        // ═══════════════════════════════════════════════════════════════
        // 🔧 FIX ENDS HERE
        // ═══════════════════════════════════════════════════════════════

        final localTime = evt.startsAtUtc.toLocal();
        final kDate = KemeticMath.fromGregorian(localTime);

        final note = _Note(
          title: evt.title,
          // Use the modified detail string if we stripped a legacy prefix; otherwise original
          detail: detailStr ?? evt.detail,
          location: evt.location,
          allDay: evt.allDay,
          start: evt.allDay ? null : TimeOfDay.fromDateTime(localTime),
          end: evt.endsAtUtc == null
              ? null
              : TimeOfDay.fromDateTime(evt.endsAtUtc!.toLocal()),
          // Pass parsed flowId (null for standalone) and not -1; unify representation
          flowId: (flowId != null && flowId > 0) ? flowId : null,
        );

        final key = _kKey(kDate.kYear, kDate.kMonth, kDate.kDay);
        final list = _notes.putIfAbsent(key, () => <_Note>[]);
        if (!list.any((n) => n.title == note.title && n.start == note.start)) {
          list.add(note);
          _added++;
          if (kDebugMode) {
            debugPrint('[loader] ✓ Added note: title="${evt.title}" flowId=${note.flowId} ky=${kDate.kYear} km=${kDate.kMonth} kd=${kDate.kDay}');
          }
        }
      }
      print('[_loadFromDisk] notes joined/added: $_added');

      setState(() {});
    } catch (e, stackTrace) {
      print('Supabase sync FAILED: $e');
      print('Stack: $stackTrace');
    }

    print('=== _loadFromDisk END ===');
    _bumpDataVersion();
  }

  Map<String, dynamic> ruleToJson(_FlowRule r) {
    if (r is _RuleWeek) {
      return {
        'type': 'week',
        'weekdays': r.weekdays.toList(),
        'allDay': r.allDay,
        if (r.start != null) 'startHour': r.start!.hour,
        if (r.start != null) 'startMinute': r.start!.minute,
        if (r.end != null) 'endHour': r.end!.hour,
        if (r.end != null) 'endMinute': r.end!.minute,
      };
    }
    if (r is _RuleDecan) {
      return {
        'type': 'decan',
        'months': r.months.toList(),
        'decans': r.decans.toList(),
        'daysInDecan': r.daysInDecan.toList(),
        'allDay': r.allDay,
        if (r.start != null) 'startHour': r.start!.hour,
        if (r.start != null) 'startMinute': r.start!.minute,
        if (r.end != null) 'endHour': r.end!.hour,
        if (r.end != null) 'endMinute': r.end!.minute,
      };
    }
    if (r is _RuleDates) {
      return {
        'type': 'dates',
        'dates': r.dates.map((d) => d.millisecondsSinceEpoch).toList(),
        'allDay': r.allDay,
        if (r.start != null) 'startHour': r.start!.hour,
        if (r.start != null) 'startMinute': r.start!.minute,
        if (r.end != null) 'endHour': r.end!.hour,
        if (r.end != null) 'endMinute': r.end!.minute,
      };
    }
    throw ArgumentError('Unknown rule type');
  }

  _FlowRule ruleFromJson(Map<String, dynamic> j) {
    final allDay = (j['allDay'] ?? true) as bool;
    TimeOfDay? start;
    TimeOfDay? end;

    if (j['startHour'] != null && j['startMinute'] != null) {
      start = TimeOfDay(
        hour: (j['startHour'] as num).toInt(),
        minute: (j['startMinute'] as num).toInt(),
      );
    }
    if (j['endHour'] != null && j['endMinute'] != null) {
      end = TimeOfDay(
        hour: (j['endHour'] as num).toInt(),
        minute: (j['endMinute'] as num).toInt(),
      );
    }

    switch (j['type']) {
      case 'week':
        return _RuleWeek(
          weekdays: {...(j['weekdays'] as List).map((e) => (e as num).toInt())},
          allDay: allDay,
          start: start,
          end: end,
        );
      case 'decan':
        return _RuleDecan(
          months: {...(j['months'] as List).map((e) => (e as num).toInt())},
          decans: {...(j['decans'] as List).map((e) => (e as num).toInt())},
          daysInDecan: {...(j['daysInDecan'] as List).map((e) => (e as num).toInt())},
          allDay: allDay,
          start: start,
          end: end,
        );
      case 'dates':
        return _RuleDates(
          dates: {
            for (final n in (j['dates'] as List))
              DateUtils.dateOnly(
                DateTime.fromMillisecondsSinceEpoch((n as num).toInt()),
              ),
          },
          allDay: allDay,
          start: start,
          end: end,
        );
    }
    throw ArgumentError('Unknown rule type ${j['type']}');
  }

  List<_FlowRule> _parseRules(String rulesJson) {
    if (rulesJson.isEmpty) return [];
    try {
      final parsed = jsonDecode(rulesJson) as List;
      return parsed.map((j) => ruleFromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }


// Persist flows + planned notes coming back from Flow Studio
  // AFTER
  Future<void> _persistFlowStudioResult(_FlowStudioResult r) async {
    final repo = UserEventsRepo(Supabase.instance.client);

    // 1) Deletes take precedence
    if (r.deleteFlowId != null) {
      if (kDebugMode) {
        debugPrint('[persistFlowStudio] Deleting flowId=${r.deleteFlowId}');
      }
      // 🔧 KEY FIX: Delete ALL notes for this flow (not just future ones)
      try {
        await repo.deleteByFlowId(r.deleteFlowId!);
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ✓ Deleted ALL notes for flow');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ⚠️ Failed to delete notes: $e');
        }
      }
      // Remove the flow from memory
      _flows.removeWhere((f) => f.id == r.deleteFlowId);
      setState(() {});
      if (kDebugMode) {
        debugPrint('[persistFlowStudio] ✓ Flow deletion complete');
      }
      return;
    }

    // 2) Save/create flow if provided
    _Flow? saved;
    if (r.savedFlow != null) {
      final rulesJson = jsonEncode(r.savedFlow!.rules.map(ruleToJson).toList());

      final savedId = await repo.upsertFlow(
        id: r.savedFlow!.id > 0 ? r.savedFlow!.id : null,
        name: r.savedFlow!.name,
        color: r.savedFlow!.color.value,
        active: r.savedFlow!.active,
        startDate: r.savedFlow!.start,
        endDate: r.savedFlow!.end,
        notes: r.savedFlow!.notes,
        rules: rulesJson,
      );

      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);

      if (r.savedFlow!.active == false) {
        await repo.deleteByFlowId(savedId, fromDate: today);
        await repo.deleteFlow(savedId);
      }




      saved = _Flow(
        id: savedId,
        name: r.savedFlow!.name,
        color: r.savedFlow!.color,
        active: r.savedFlow!.active,
        rules: r.savedFlow!.rules,
        start: r.savedFlow!.start,
        end: r.savedFlow!.end,
        notes: r.savedFlow!.notes,
      );

      final idx = _flows.indexWhere((f) => f.id == savedId);
      if (idx >= 0) {
        _flows[idx] = saved;
      } else {
        _flows.add(saved);
        if (savedId >= _nextFlowId) _nextFlowId = savedId + 1;
      }
      
      // Add verification logging
      if (kDebugMode) {
        debugPrint('[persistFlowStudio] Saved flow $savedId "${saved.name}" with color=${saved.color.value.toRadixString(16)} to database');
      }
    }

    // 3) Apply planned notes locally
    final flowId = saved?.id ?? r.savedFlow?.id ?? -1;
    for (final p in r.plannedNotes) {
      _addNote(
        p.ky,
        p.km,
        p.kd,
        p.note.title,
        p.note.detail,
        location: p.note.location,
        allDay: p.note.allDay,
        start: p.note.start,
        end: p.note.end,
        flowId: flowId >= 0 ? flowId : p.note.flowId,
      );
    }

    // Persist planned notes to Supabase. Without persistence, custom-flow
    // notes disappear after a restart. Build a canonical clientEventId using
    // _buildCid so that creation, deletion and migration all align on the
    // same format. Also ensure the in-memory note carries the flow id being
    // persisted to avoid mismatches when deleting.
    if (r.plannedNotes.isNotEmpty) {
      try {
        final repo2 = UserEventsRepo(Supabase.instance.client);
        for (final p in r.plannedNotes) {
          final n = p.note;
          // Determine the flow id to persist: use the final saved id if available,
          // else fall back to the note's own flow id, or -1 for standalone.
          final int noteFlowId = flowId >= 0 ? flowId : (n.flowId ?? -1);
          // Create a copy of the note with the correct flow id stamped so
          // deletion logic can reference n.flowId later.
          final _Note persisted = _Note(
            title: n.title,
            detail: n.detail,
            location: n.location,
            allDay: n.allDay,
            start: n.start,
            end: n.end,
            flowId: noteFlowId,
          );
          // Build canonical id using placement from p (ky/km/kd) and note fields.
          final String cid = _buildCid(
            ky: p.ky,
            km: p.km,
            kd: p.kd,
            title: persisted.title,
            startHour: persisted.start?.hour,
            startMinute: persisted.start?.minute,
            allDay: persisted.allDay,
            flowId: noteFlowId,
          );
          final gDay = KemeticMath.toGregorian(p.ky, p.km, p.kd);
          final DateTime startsAt = DateTime(
            gDay.year,
            gDay.month,
            gDay.day,
            persisted.start?.hour ?? 9,
            persisted.start?.minute ?? 0,
          );
          DateTime? endsAt;
          if (persisted.allDay == false && persisted.end != null) {
            endsAt = DateTime(gDay.year, gDay.month, gDay.day, persisted.end!.hour, persisted.end!.minute);
          } else {
            endsAt = null;
          }
          // Preserve legacy detail prefix to indicate local flow id for older clients
          final String prefix = noteFlowId >= 0 ? 'flowLocalId=${noteFlowId};' : '';
          final String? det = persisted.detail;
          final String detailPayload = prefix + (det?.trim() ?? '');
          await repo2.upsertByClientId(
            clientEventId: cid,
            title: persisted.title,
            startsAtUtc: startsAt.toUtc(),
            detail: detailPayload.isEmpty ? null : detailPayload,
            location: (persisted.location ?? '').trim().isEmpty ? null : persisted.location!.trim(),
            allDay: persisted.allDay,
            endsAtUtc: endsAt?.toUtc(),
          );
        }
      } catch (e) {
        debugPrint('persist custom-flow notes failed: $e');
      }
    }

    setState(() {});
  }



  @override
  Widget build(BuildContext context) {
    _buildCount++;

    final kToday = _today;
    final size = MediaQuery.sizeOf(context);
    final orientation = MediaQuery.orientationOf(context);
    final isLandscape = orientation == Orientation.landscape;
    final useGrid = isLandscape || size.width >= 900;

    // ========================================
    // DEBUG: Log orientation changes
    // ========================================
    if (_lastOrientation != null && _lastOrientation != orientation) {
      if (kDebugMode) {
        print('\n' + '🔄'*30);
        print('ORIENTATION CHANGED!');
        print('From: $_lastOrientation → To: $orientation');
        print('Navigator canPop: ${Navigator.canPop(context)}');
        print('Modal route active: ${ModalRoute.of(context)?.isCurrent ?? false}');
        print('🔄'*30 + '\n');
      }
    }
    _lastOrientation = orientation;

    if (useGrid) {
      debugPrint('📱 Rendering: LandscapeMonthView (build #$_buildCount)');
      _updateCenteredMonthWide();
      final ky = _lastViewKy ?? kToday.kYear;
      final km = _lastViewKm ?? kToday.kMonth;

      if (kDebugMode) {
        print('\n📱 [CALENDAR] Building LandscapeMonthView');
        print('   initialKy: $ky');
        print('   initialKm: $km');
        print('   initialKd: null');
        print('   onAddNote callback: ${_openDaySheet != null ? "PROVIDED" : "NULL"}');
      }
      
      return LandscapeMonthView(
        initialKy: ky,
        initialKm: km,
        initialKd: null, // No specific day from main calendar
        showGregorian: _showGregorian,
        notesForDay: (ky, km, kd) {
          final notes = _getNotes(ky, km, kd);
          return notes.map((n) => NoteData(
            title: n.title,
            detail: n.detail,
            location: n.location,
            allDay: n.allDay,
            start: n.start,
            end: n.end,
            flowId: n.flowId,
          )).toList();
        },
        flowIndex: _buildFlowIndex(),
        getMonthName: (km) {
          if (km == 13) return 'Heriu Renpet (ḥr.w rnpt)';
          return _MonthCard.monthNames[km] ?? 'Month $km';
        },
        onManageFlows: _openFlowsViewer,
        onAddNote: (ky, km, kd) {
          if (kDebugMode) {
            print('\n🎯 [CALLBACK] onAddNote received from landscape');
            print('   Date: $ky-$km-$kd');
          }
          _openDaySheet(ky, km, kd, allowDateChange: true);
        },
      );
    }

    debugPrint('📱 Rendering: Portrait Scaffold (build #$_buildCount)');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: GestureDetector(
          onTap: () => setState(() => _showGregorian = !_showGregorian),
          child: _GlossyText(
            text: "Ma'at",
            style: _titleGold,
            gradient: _showGregorian ? _whiteGloss : _goldGloss,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const _GlossyIcon(Icons.calendar_today, gradient: _silverGloss),
            onPressed: _scrollToToday,
          ),
          IconButton(
            tooltip: 'Search events',
            icon: const _GlossyIcon(Icons.search, gradient: _silverGloss),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Flow Studio',
            icon: const _GlossyIcon(Icons.view_timeline, gradient: _goldGloss),
            onPressed: () {
              _openFlowStudioSheet(
                rootBuilder: (innerCtx) {
                  return _FlowHubPage(
                    openMyFlows: () {
                      Navigator.of(innerCtx).push(
                        MaterialPageRoute(
                          builder: (ctx2) => _FlowsViewerPage(
                            flows: _flows,
                            fmtGregorian: (d) => d == null
                                ? '--'
                                : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                            onCreateNew: () async {
                              final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
                                MaterialPageRoute(
                                  builder: (_) => _FlowStudioPage(
                                    existingFlows: _flows,
                                  ),
                                ),
                              );
                              if (edited != null) await _persistFlowStudioResult(edited);
                            },
                            onEditFlow: (id) async {
                              final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
                                MaterialPageRoute(
                                  builder: (_) => _FlowStudioPage(
                                    existingFlows: _flows,
                                    editFlowId: id,
                                  ),
                                ),
                              );
                              if (edited != null) await _persistFlowStudioResult(edited);
                            },
                            openMaatFlows: () {
                              Navigator.of(innerCtx).push(
                                MaterialPageRoute(
                                  builder: (ctx3) => _MaatCategoriesPage(
                                    hasActiveForKey: (key) => _hasActiveMaatInstanceFor(key),
                                    onPickTemplate: (tpl) {
                                      Navigator.of(ctx3).push(
                                        MaterialPageRoute(
                                          builder: (ctx4) => _MaatFlowTemplateDetailPage(
                                            template: tpl,
                                            addInstance: ({
                                              required _MaatFlowTemplate template,
                                              required DateTime startDate,
                                              required bool useKemetic,
                                            }) {
                                              final id = _addMaatFlowInstance(
                                                template: template,
                                                startDate: startDate,
                                                useKemetic: useKemetic,
                                              );
                                              return id;
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    onCreateNew: () async {
                                      final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
                                        MaterialPageRoute(
                                          builder: (_) => _FlowStudioPage(
                                            existingFlows: _flows,
                                          ),
                                        ),
                                      );
                                      if (edited != null) await _persistFlowStudioResult(edited);
                                    },
                                  ),
                                ),
                              );
                            },
                            onEndFlow: (id) => _endFlow(id),
                          ),
                        ),
                      );
                    },
                    openMaatFlows: () {
                      Navigator.of(innerCtx).push(
                        MaterialPageRoute(
                          builder: (ctx3) => _MaatCategoriesPage(
                            hasActiveForKey: (key) => _hasActiveMaatInstanceFor(key),
                            onPickTemplate: (tpl) {
                              Navigator.of(ctx3).push(
                                MaterialPageRoute(
                                  builder: (ctx4) => _MaatFlowTemplateDetailPage(
                                    template: tpl,
                                    addInstance: ({
                                      required _MaatFlowTemplate template,
                                      required DateTime startDate,
                                      required bool useKemetic,
                                    }) {
                                      final id = _addMaatFlowInstance(
                                        template: template,
                                        startDate: startDate,
                                        useKemetic: useKemetic,
                                      );
                                      return id;
                                    },
                                  ),
                                ),
                              );
                            },
                            onCreateNew: () async {
                              final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
                                MaterialPageRoute(
                                  builder: (_) => _FlowStudioPage(
                                    existingFlows: _flows,
                                  ),
                                ),
                              );
                              if (edited != null) await _persistFlowStudioResult(edited);
                            },
                          ),
                        ),
                      );
                    },
                    onCreateNew: () async {
                      final edited = await Navigator.of(innerCtx).push<_FlowStudioResult>(
                        MaterialPageRoute(
                          builder: (_) => _FlowStudioPage(
                            existingFlows: _flows,
                          ),
                        ),
                      );
                      if (edited != null) await _persistFlowStudioResult(edited);
                    },
                  );
                },
              );
            },
          ),

          IconButton(
            tooltip: 'New note',
            icon: const _GlossyIcon(Icons.add, gradient: _goldGloss),
            onPressed: () => _openDaySheet(
              kToday.kYear,
              kToday.kMonth,
              kToday.kDay,
              allowDateChange: true,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollCtrl,
        anchor: 0.5, // center the "center" sliver in the viewport
        center: _centerKey, // current Kemetic year is the center
        slivers: [

          // PAST years
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                final kYear = kToday.kYear - (i + 1);
                return _YearSection(
                  kYear: kYear,
                  todayMonth: null,
                  todayDay: null,
                  todayDayKey: null, // no anchor in past/future lists
                  monthAnchorKeyProvider: (m) => keyForMonth(kYear, m),
                  onDayTap: (c, m, d) => _openDayView(c, kYear, m, d),
                  notesGetter: (m, d) => _getNotes(kYear, m, d),
                  flowsGetter: (m, d) => _getFlowOccurrences(kYear, m, d),
                  showGregorian: _showGregorian,
                );
              },
              childCount: 200, //
            ),
          ),

          // CENTER: current Kemetic year
          SliverToBoxAdapter(
            key: _centerKey,
            child: _YearSection(
              kYear: kToday.kYear,
              todayMonth: kToday.kMonth,
              todayDay: kToday.kDay,
              monthAnchorKeyProvider: (m) => keyForMonth(kToday.kYear, m),
              todayDayKey: _todayDayKey, // 🔑 pass day anchor
              onDayTap: (c, m, d) => _openDayView(c, kToday.kYear, m, d),
              notesGetter: (m, d) => _getNotes(kToday.kYear, m, d),
              flowsGetter: (m, d) => _getFlowOccurrences(kToday.kYear, m, d),
              showGregorian: _showGregorian,
            ),
          ),

          // FUTURE years
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                final kYear = kToday.kYear + (i + 1);
                return _YearSection(
                  kYear: kYear,
                  todayMonth: null,
                  todayDay: null,
                  todayDayKey: null,
                  monthAnchorKeyProvider: (m) => keyForMonth(kYear, m),
                  onDayTap: (c, m, d) => _openDayView(c, kYear, m, d),
                  notesGetter: (m, d) => _getNotes(kYear, m, d),
                  flowsGetter: (m, d) => _getFlowOccurrences(kYear, m, d),
                  showGregorian: _showGregorian,
                );
              },
              childCount: 200, //
            ),
          ),
        ],
      ), //
    );
  }

  // Helper method to build flow index for landscape month view
  Map<int, FlowData> _buildFlowIndex() {
    final index = <int, FlowData>{};
    for (final f in _flows.where((f) => f.active)) {
      index[f.id] = FlowData(
        id: f.id,
        name: f.name,
        color: f.color,
        active: f.active,
      );
    }
    return index;
  }
}



/* ───────────── Year Section (12 months + epagomenal) ───────────── */

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.kYear,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.monthAnchorKeyProvider,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final bool showGregorian;

  // existing notes
  final List<_Note> Function(int kMonth, int kDay) notesGetter;

  // flow occurrences for a given day
  final List<_FlowOccurrence> Function(int kMonth, int kDay) flowsGetter;

  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? Function(int kMonth)? monthAnchorKeyProvider;
  final Key? todayDayKey; // 🔑

  @override
  Widget build(BuildContext context) {
    final (tm, td) = (todayMonth, todayDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SeasonHeader(title: 'Flood season (Akhet)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(1),
          kYear: kYear,
          kMonth: 1,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(2),
          kYear: kYear,
          kMonth: 2,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(3),
          kYear: kYear,
          kMonth: 3,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(4),
          kYear: kYear,
          kMonth: 4,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),

        const _SeasonHeader(title: 'Emergence season (Peret)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(5),
          kYear: kYear,
          kMonth: 5,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(6),
          kYear: kYear,
          kMonth: 6,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(7),
          kYear: kYear,
          kMonth: 7,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(8),
          kYear: kYear,
          kMonth: 8,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),

        const _SeasonHeader(title: 'Harvest season (Shemu)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(9),
          kYear: kYear,
          kMonth: 9,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(10),
          kYear: kYear,
          kMonth: 10,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(11),
          kYear: kYear,
          kMonth: 11,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(12),
          kYear: kYear,
          kMonth: 12,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),

        _EpagomenalCard(
          kYear: kYear,
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: (m, d) => notesGetter(13, d),
          flowsGetter: (m, d) => flowsGetter(13, d),
          onDayTap: (c, m, d) => onDayTap(c, 13, d),
          showGregorian: showGregorian,
        ),
        const _GoldDivider(),
      ],
    );
  }
}

/* ───────────────────────── Month & Day Cards ───────────────────────── */

class _MonthCard extends StatelessWidget {
  final Key? anchorKey;
  final int kYear;
  final int kMonth; // 1..12
  final String seasonShort; // Akhet/Peret/Shemu
  final int? todayMonth;
  final int? todayDay;
  final Key? todayDayKey; // 🔑 day anchor to center
  final bool showGregorian;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<_FlowOccurrence> Function(int kMonth, int kDay) flowsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  // Optional overrides for taps (used by the detail page)
  final void Function(BuildContext context)? onMonthHeaderTap;
  final void Function(BuildContext context, int decanIndex)? onDecanTap;

  const _MonthCard({
    this.anchorKey,
    required this.kYear,
    required this.kMonth,
    required this.seasonShort,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.todayDayKey,
    this.onMonthHeaderTap,
    this.onDecanTap,
  });

  static const monthNames = [
    '',
    'Thoth (Ḏḥwty)',
    'Paopi (Pȝ ỉp.t)',
    'Hathor (Ḥwt-Ḥr)',
    'Ka-ḥer-Ka (Kȝ-ḥr-Kȝ)',
    'Šef-Bedet (Šf-bdt)',
    'Rekh-Wer (Rḫ-wr)',
    'Rekh-Nedjes (Rḫ-nḏs)',
    'Renwet (Rnnwt)',
    'Hnsw (Ḥnsw)',
    'Ḥenti-ḥet (Ḥnt-ḥtj)',
    'Pa-Ipi (ỉpt-ḥmt)',
    'Mesut-Ra (Mswt-Rꜥ)',
  ];

  static const Map<int, List<String>> decans = {
    1: ['ṯmꜣt ḥrt', 'ṯmꜣt ẖrt', 'wšꜣty bkꜣty'],
    2: ['ı͗pḏs', 'sbšsn', 'ḫntt ḥrt'],
    3: ['ḫntt ẖrt', 'ṯms n ḫntt', 'ḳdty'],
    4: ['ḫnwy', 'ḥry-ı͗b wı͗ꜣ', '“crew”'],
    5: ['knmw', 'smd srt', 'srt'],
    6: ['sꜣwy srt', 'ẖry ḫpd srt', 'tpy-ꜥ ꜣḫwy'],
    7: ['ꜣḫwy', 'ı͗my-ḫt ꜣḫwy', 'bꜣwy'],
    8: ['ḳd', 'ḫꜣw', 'ꜥrt'],
    9: ['ẖry ꜥrt', 'rmn ḥry sꜣḥ', 'rmn ẖry sꜣḥ'],
    10: ['ꜥbwt', 'wꜥrt ẖrt sꜣḥ', 'tpy-ꜥ spdt'],
    11: ['spdt (Sopdet/Sothis)', 'knmt', 'sꜣwy knmt'],
    12: ['ẖry ḫpd n knmt', 'ḥꜣt ḫꜣw', 'pḥwy ḫꜣw'],
  };

  String? _gregLabelForDecanRow(int ky, int km, int decanIndex) {
    final start = decanIndex * 10 + 1;
    final end = start + 9;
    for (int d = start; d <= end; d++) {
      final g = KemeticMath.toGregorian(ky, km, d);
      if (g.day == 1) {
        return _gregMonthNames[g.month];
      }
    }
    return null;
  }

  void _openMonthInfo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MonthDetailPage(
          kYear: kYear,
          kMonth: kMonth,
          seasonShort: seasonShort,
          todayMonth: todayMonth,
          todayDay: todayDay,
          showGregorian: showGregorian,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          decanIndex: null,
        ),
      ),
    );
  }

  void _openDecanInfo(BuildContext context, int decanIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MonthDetailPage(
          kYear: kYear,
          kMonth: kMonth,
          seasonShort: seasonShort,
          todayMonth: todayMonth,
          todayDay: todayDay,
          showGregorian: showGregorian,
          notesGetter: notesGetter,
          flowsGetter: flowsGetter,
          onDayTap: onDayTap,
          decanIndex: decanIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = decans[kMonth] ?? const ['Decan A', 'Decan B', 'Decan C'];

    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, 30).year;
    final rightLabel =
    (yStart == yEnd) ? '$seasonShort $yStart' : '$seasonShort $yStart/$yEnd';

    final isMonthToday = (todayMonth != null && todayMonth == kMonth);

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Card(
        color: const Color(0xFF121315),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Kemetic month name (left), Season+Year (right)
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (onMonthHeaderTap != null) {
                        onMonthHeaderTap!(context);
                      } else {
                        _openMonthInfo(context);
                      }
                    },
                    child: _GlossyText(
                      text: monthNames[kMonth],
                      style: _monthTitleGold,
                      gradient: _goldGloss,
                    ),
                  ),
                  const Spacer(),
                  _GlossyText(
                    text: rightLabel,
                    style: _rightSmall,
                    gradient: _whiteGloss,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Three decans
              for (var i = 0; i < 3; i++) ...[
                // Label row: decan on left (Kemetic), Gregorian month on right when needed
                Row(
                  children: [
                    // Kemetic decan name
                    Expanded(
                      child: Visibility(
                        visible: !showGregorian,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: GestureDetector(
                          onTap: () {
                            if (onDecanTap != null) {
                              onDecanTap!(context, i);
                            } else {
                              _openDecanInfo(context, i);
                            }
                          },
                          child: _GlossyText(
                            text: names[i],
                            style: _decanStyle,
                            gradient: _silverGloss,
                          ),
                        ),
                      ),
                    ),
                    // Gregorian month name right-aligned (only when needed)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Visibility(
                          visible: showGregorian &&
                              _gregLabelForDecanRow(kYear, kMonth, i) != null,
                          maintainState: true,
                          maintainAnimation: true,
                          maintainSize: true,
                          child: _GlossyText(
                            text: _gregLabelForDecanRow(kYear, kMonth, i) ?? '',
                            style: _decanStyle,
                            gradient: _blueGloss,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                _DecanRow(
                  kYear: kYear,
                  kMonth: kMonth,
                  decanIndex: i,
                  todayMonth: todayMonth,
                  todayDay: todayDay,
                  todayDayKey: isMonthToday ? todayDayKey : null,
                  notesGetter: notesGetter,
                  flowsGetter: flowsGetter,
                  onDayTap: onDayTap,
                  showGregorian: showGregorian,
                ),
                if (i < 2) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
@visibleForTesting
int filteredNoteCountForDay({
  required int kMonth,
  required int day,
  required List<_FlowOccurrence> Function(int kMonth, int kDay) flowsGetter,
  required List<_Note> Function(int kMonth, int kDay) notesGetter,
}) {
  final flows = flowsGetter(kMonth, day);
  final notes = notesGetter(kMonth, day);

  final hasFlowBacked = notes.any((n) => n.flowId != null);
  if (flows.isEmpty && hasFlowBacked) {
    return 0;
  }

  final activeFlowIds = <int>{for (final o in flows) o.flow.id};
  var count = 0;
  for (final n in notes) {
    final fid = n.flowId;
    if (fid == null || activeFlowIds.contains(fid)) {
      count++;
    }
  }
  return count;
}


class _DecanRow extends StatelessWidget {
  final int kYear; // to compute Gregorian numbers
  final int kMonth; // 1..12
  final int decanIndex; // 0..2
  final int? todayMonth;
  final int? todayDay;
  final Key? todayDayKey;
  final bool showGregorian;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<_FlowOccurrence> Function(int kMonth, int kDay) flowsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  const _DecanRow({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowsGetter,
    required this.onDayTap,
    required this.showGregorian,
    required this.todayDayKey,
  });

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == kMonth);
    return Row(
      children: List.generate(10, (j) {
        final day = decanIndex * 10 + (j + 1); // 1..30
        final isToday = isMonthToday && (todayDay == day);

        final noteCount = filteredNoteCountForDay(
          kMonth: kMonth,
          day: day,
          flowsGetter: flowsGetter,
          notesGetter: notesGetter,
        );
        final flows = flowsGetter(kMonth, day);

        // Unique colors for dots (cap to 3)
        final flowColors = <Color>[];
        for (final occ in flows) {
          if (!flowColors.contains(occ.flow.color)) {
            flowColors.add(occ.flow.color);
            if (flowColors.length == 3) break;
          }
        }

        final label = showGregorian
            ? '${KemeticMath.toGregorian(kYear, kMonth, day).day}'
            : '$day';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: j == 9 ? 0 : 6),
            child: _DayChip(
              anchorKey: isToday ? todayDayKey : null, // 🔑 attach
              label: label,
              isToday: isToday,
              noteCount: noteCount,
              flowColors: flowColors,
              onTap: () => onDayTap(context, kMonth, day),
              showGregorian: showGregorian,
            ),
          ),
        );
      }),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool isToday;
  final int noteCount;
  final List<Color> flowColors;
  final VoidCallback onTap;
  final Key? anchorKey;
  final bool showGregorian;

  const _DayChip({
    required this.label,
    required this.isToday,
    required this.noteCount,
    required this.flowColors,
    required this.onTap,
    required this.showGregorian,
    this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w400,
      fontSize: 15.2,
    );

    final gradient =
    isToday ? _goldGloss : (showGregorian ? _blueGloss : _silverGloss);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        key: anchorKey,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _GlossyText(
              text: label,
              style: textStyle,
              gradient: gradient,
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (noteCount > 0) const _GlossyDot(gradient: _silverGloss),
                  if (flowColors.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in flowColors.take(3)) ...[
                          _ColorDot(color: c),
                          const SizedBox(width: 2.5),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return _Glossy(
      gradient: _glossFromColor(color), // uses helper from Block 1
      child: Container(
        width: 4.5,
        height: 4.5,
        decoration:
        const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

/* ───────────── Epagomenal (5 or 6 extra days) ───────────── */

class _EpagomenalCard extends StatelessWidget {
  const _EpagomenalCard({
    required this.kYear,
    this.todayMonth,
    this.todayDay,
    required this.notesGetter,
    required this.flowsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<_FlowOccurrence> Function(int kMonth, int kDay) flowsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? todayDayKey;
  final bool showGregorian;

  String? _gregMonthForEpagomenal(int ky, int epiCount) {
    for (int d = 1; d <= epiCount; d++) {
      final g = KemeticMath.toGregorian(ky, 13, d);
      if (g.day == 1) return _gregMonthNames[g.month];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == 13);
    final epiCount = KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;

    final gLabel = _gregMonthForEpagomenal(kYear, epiCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Card(
        color: const Color(0xFF121315),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Kemetic header (left) and Gregorian month (right when present)
              Row(
                children: [
                  Expanded(
                    child: Visibility(
                      visible: !showGregorian, // visually removed in Gregorian
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true, // keep height so layout doesn't jump
                      child: const _GlossyText(
                        text: 'Heriu Renpet (ḥr.w rnpt)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        gradient: _goldGloss,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Visibility(
                        visible: showGregorian && gLabel != null,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: _GlossyText(
                          text: gLabel ?? '',
                          style: _decanStyle,
                          gradient: _blueGloss,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: List.generate(epiCount, (i) {
                  final n = i + 1; // 1..5 or 1..6
                  final isToday = isMonthToday && (todayDay == n);

                  final noteCount = filteredNoteCountForDay(
                    kMonth: 13,
                    day: n,
                    flowsGetter: flowsGetter,
                    notesGetter: notesGetter,
                  );
                  final flows = flowsGetter(13, n);
                  final flowColors = <Color>[];
                  for (final occ in flows) {
                    if (!flowColors.contains(occ.flow.color)) {
                      flowColors.add(occ.flow.color);
                      if (flowColors.length == 3) break;
                    }
                  }

                  final label = showGregorian
                      ? '${KemeticMath.toGregorian(kYear, 13, n).day}'
                      : '$n';

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == epiCount - 1 ? 0 : 6),
                      child: _DayChip(
                        anchorKey: isToday ? todayDayKey : null, // 🔑
                        label: label,
                        isToday: isToday,
                        noteCount: noteCount,
                        flowColors: flowColors,
                        onTap: () => onDayTap(context, 13, n),
                        showGregorian: showGregorian,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────── Detail Page (single-window behavior, flows-aware) ───────────── */

class _MonthDetailPage extends StatefulWidget {
  const _MonthDetailPage({
    required this.kYear,
    required this.kMonth,
    required this.seasonShort,
    required this.todayMonth,
    required this.todayDay,
    required this.showGregorian,
    required this.notesGetter,
    required this.flowsGetter,
    required this.onDayTap,
    required this.decanIndex, // null => month view; 0..2 => specific decan
  });

  final int kYear;
  final int kMonth;
  final String seasonShort;
  final int? todayMonth;
  final int? todayDay;
  final bool showGregorian;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<_FlowOccurrence> Function(int kMonth, int kDay) flowsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final int? decanIndex;

  @override
  State<_MonthDetailPage> createState() => _MonthDetailPageState();
}

class _MonthDetailPageState extends State<_MonthDetailPage> {
  int? _currentDecanIndex;

  @override
  void initState() {
    super.initState();
    _currentDecanIndex = widget.decanIndex;
  }


  @override
  Widget build(BuildContext context) {
    final infoTitle = _currentDecanIndex == null
        ? _MonthCard.monthNames[widget.kMonth]
        : _MonthCard.decans[widget.kMonth]![_currentDecanIndex!];

    final infoBody = _currentDecanIndex == null
        ? (_monthInfo[widget.kMonth] ?? '')
        : _decanInfo[(widget.kMonth - 1) * 3 + _currentDecanIndex!];

    final yStart = KemeticMath.toGregorian(widget.kYear, widget.kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(widget.kYear, widget.kMonth, 30).year;
    final rightLabel = (yStart == yEnd)
        ? '${widget.seasonShort} $yStart'
        : '${widget.seasonShort} $yStart/$yEnd';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          icon: const _GlossyIcon(Icons.close, gradient: _goldGloss),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _GlossyText(
          text: infoTitle,
          style: _monthTitleGold,
          gradient: _goldGloss,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: _GlossyText(
                text: rightLabel,
                style: _rightSmall,
                gradient: _whiteGloss,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10),
              children: [
                _MonthCard(
                  kYear: widget.kYear,
                  kMonth: widget.kMonth,
                  seasonShort: widget.seasonShort,
                  todayMonth: widget.todayMonth,
                  todayDay: widget.todayDay,
                  todayDayKey: null,
                  notesGetter: widget.notesGetter,
                  flowsGetter: widget.flowsGetter,
                  onDayTap: widget.onDayTap,
                  showGregorian: widget.showGregorian,
                  onMonthHeaderTap: (_) => setState(() => _currentDecanIndex = null),
                  onDecanTap: (_, idx) => setState(() => _currentDecanIndex = idx),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlossyText(
                    text: infoTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: _silverGloss,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    infoBody.trim(),
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────
// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

/* ---------- helper types used by Flow Studio (top-level; not nested) ---------- */

/// Range bucket for a specific Kemetic decan inside a Kemetic month.
class _KemeticDecanSpan {
  final String key;       // "ky-km-di"
  final int ky;           // Kemetic year
  final int km;           // 1..12
  final int di;           // 0..2  (0=days 1..10, 1=11..20, 2=21..30)
  final String label;     // "Month • Decan name"
  int minDay;             // 1..10 (trimmed by range)
  int maxDay;             // 1..10 (trimmed by range)
  DateTime gStart;        // first Gregorian day in span within range
  DateTime gEnd;          // last Gregorian day in span within range

  _KemeticDecanSpan({
    required this.key,
    required this.ky,
    required this.km,
    required this.di,
    required this.label,
    required this.minDay,
    required this.maxDay,
    required this.gStart,
    required this.gEnd,
  });
}

// Helper class representing a scheduled event/note with timing and display attributes.
class _EventItem {
  final String title;
  final Color color;
  final int startMin;
  final int endMin;
  _EventItem({
    required this.title,
    required this.color,
    required this.startMin,
    required this.endMin,
  });
}

/// Range bucket for a Gregorian week (Mon..Sun).
class _WeekSpan {
  final String key;       // ISO monday string "yyyy-mm-dd"
  final DateTime monday;  // dateOnly, local
  int minWd;              // 1..7
  int maxWd;              // 1..7
  _WeekSpan({
    required this.key,
    required this.monday,
    required this.minWd,
    required this.maxWd,
  });
}

/// Lightweight inputs holder for one planned note.
class _NoteDraft {
  final titleCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final detailCtrl = TextEditingController();
  bool allDay = false;
  TimeOfDay? start = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay? end = const TimeOfDay(hour: 13, minute: 0);

  _Note toNote() {
    final t = titleCtrl.text.trim();
    final loc = locationCtrl.text.trim();
    final det = detailCtrl.text.trim();
    return _Note(
      title: t,
      location: loc.isEmpty ? null : loc,
      detail: det.isEmpty ? null : det,
      allDay: allDay,
      start: allDay ? null : start,
      end: allDay ? null : end,
    );
  }

  void dispose() {
    titleCtrl.dispose();
    locationCtrl.dispose();
    detailCtrl.dispose();
  }
}

/// One concrete selected day derived from the chips.
class _SelectedDay {
  final String key; // "ky-km-kd"
  final int ky, km, kd;
  final DateTime g; // Gregorian
  _SelectedDay(this.key, this.ky, this.km, this.kd, this.g);
}

/// One editor group: either a concrete day or a pattern (weekday / decan day).
class _EditorGroup {
  final String key;              // day key: "ky-km-kd"; pattern key: "WD-2" / "DD-3"
  final bool isPattern;          // true for pattern (repeat), false for per-day
  final String header;           // display header
  final List<_SelectedDay> days; // all concrete days this editor applies to
  const _EditorGroup({
    required this.key,
    required this.isPattern,
    required this.header,
    required this.days,
  });
}

/// A note to add on a specific Kemetic day (result payload).
class _PlannedNote {
  final int ky, km, kd; // Kemetic Y/M/D
  final _Note note;
  const _PlannedNote({
    required this.ky,
    required this.km,
    required this.kd,
    required this.note,
  });
}

class _FlowStudioResult {
  final _Flow? savedFlow;
  final int? deleteFlowId;
  final List<_PlannedNote> plannedNotes;
  const _FlowStudioResult({
    this.savedFlow,
    this.deleteFlowId,
    this.plannedNotes = const [],
  });
}

/* ---------------------------------- page ---------------------------------- */

class _FlowStudioPage extends StatefulWidget {
  const _FlowStudioPage({
    required this.existingFlows,
    this.editFlowId,
    super.key,
  });

  final List<_Flow> existingFlows;
  final int? editFlowId;

  @override
  State<_FlowStudioPage> createState() => _FlowStudioPageState();
}

class _FlowStudioPageState extends State<_FlowStudioPage> {
  _Flow? _editing;

  // basic
  late final TextEditingController _nameCtrl;
  bool _active = true;

  // color + mode
  int _selectedColorIndex = 0;
  bool _useKemetic = false; // false = Gregorian, true = Kemetic

  // date range (Gregorian local, date-only)
  DateTime? _startDate, _endDate;
  bool get _hasFullRange => _startDate != null && _endDate != null;

  // “same for all” selections
  final Set<int> _selectedDecanDays = <int>{}; // 1..10
  final Set<int> _selectedWeekdays = <int>{};   // 1..7 (Mon..Sun)

  // per-period mode
  bool _splitByPeriod = false; // toggle to show rows per decan/week

  // cached spans + per-period selections
  List<_KemeticDecanSpan> _kemeticSpans = const [];
  List<_WeekSpan> _weekSpans = const [];
  final Map<String, Set<int>> _perDecanSel = {}; // key: "ky-km-di", values: {1..10}
  final Map<String, Set<int>> _perWeekSel = {};  // key: monday ISO "yyyy-mm-dd", values: {1..7}

  // editors
  final Map<String, _NoteDraft> _draftsByDay = {};     // key: "ky-km-kd" (customize mode)
  final Map<String, _NoteDraft> _draftsByPattern = {}; // key: "DD-n" or "WD-wd" (repeat mode)
  final GlobalKey _editorsAnchorKey = GlobalKey();

  void _scrollEditorsIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _editorsAnchorKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ---------- tiny utilities (local to this page) ----------

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  static DateTime _dateOnly(DateTime d) => DateUtils.dateOnly(d);

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
  TimeOfDay _addMinutes(TimeOfDay t, int delta) {
    final m = (_toMinutes(t) + delta) % (24 * 60);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  String _fmtGregorian(DateTime? d) => d == null
      ? '--'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _gregYearLabelFor(int kYear, int kMonth) {
    final lastDay =
    (kMonth == 13) ? (KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5) : 30;
    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  }

  String _fmtKemetic(DateTime? g) {
    if (g == null) return '--';
    final k = KemeticMath.fromGregorian(g);
    final month = (k.kMonth == 13) ? 'Heriu Renpet (ḥr.w rnpt)' : _MonthCard.monthNames[k.kMonth];
    final y = _gregYearLabelFor(k.kYear, k.kMonth);
    return '$month ${k.kDay} • $y';
  }
  int _daysInGregorianMonth(int year, int month) {
    final leap = (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
    switch (month) {
      case 1: return 31;
      case 2: return leap ? 29 : 28;
      case 3: return 31;
      case 4: return 30;
      case 5: return 31;
      case 6: return 30;
      case 7: return 31;
      case 8: return 31;
      case 9: return 30;
      case 10: return 31;
      case 11: return 30;
      case 12: return 31;
      default: return 30;
    }
  }
  static DateTime _mondayOf(DateTime d) {
    final back = d.weekday - 1; // Mon=1..Sun=7
    return DateUtils.dateOnly(d.subtract(Duration(days: back)));
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


  static const _wdLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Build editor groups:
  /// - per-day groups in customize mode
  /// - pattern groups (weekday/decan-day) in repeat mode
  List<_EditorGroup> _buildEditorGroups() {
    final selected = _computeSelectedDays();
    if (selected.isEmpty) return const [];

    if (_splitByPeriod) {
      // One editor per concrete day.
      return [
        for (final d in selected)
          _EditorGroup(
            key: d.key,
            isPattern: false,
            header:
            '${d.km == 13 ? 'Heriu Renpet (ḥr.w rnpt)' : _MonthCard.monthNames[d.km]} ${d.kd}  •  ${_fmtGregorian(d.g)}',
            days: [d],
          )
      ];
    }

    // Repeat mode: pattern editors.
    if (_useKemetic) {
      // group by decan-day number 1..10
      final by = <int, List<_SelectedDay>>{};
      for (final d in selected) {
        final n = ((d.kd - 1) % 10) + 1;
        (by[n] ??= <_SelectedDay>[]).add(d);
      }
      final nums = _selectedDecanDays.toList()..sort();
      return [
        for (final n in nums)
          if (by[n]?.isNotEmpty ?? false)
            _EditorGroup(
              key: 'DD-$n',
              isPattern: true,
              header: 'Decan day $n • ${by[n]!.length} matches',
              days: by[n]!,
            ),
      ];
    } else {
      // group by weekday 1..7
      final by = <int, List<_SelectedDay>>{};
      for (final d in selected) {
        (by[d.g.weekday] ??= <_SelectedDay>[]).add(d);
      }
      final wds = _selectedWeekdays.toList()..sort();
      return [
        for (final wd in wds)
          if (by[wd]?.isNotEmpty ?? false)
            _EditorGroup(
              key: 'WD-$wd',
              isPattern: true,
              header: '${_wdLabels[wd - 1]} • ${by[wd]!.length} matches',
              days: by[wd]!,
            ),
      ];
    }
  }

  List<_SelectedDay> _computeSelectedDays() {
    final out = <_SelectedDay>[];
    if (!_hasFullRange) return out;

    bool inside(DateTime d) =>
        !d.isBefore(_startDate!) && !d.isAfter(_endDate!);

    if (_splitByPeriod) {
      if (_useKemetic) {
        for (final s in _kemeticSpans) {
          final sel = _perDecanSel[s.key] ?? const <int>{};
          for (final n in sel) {
            final kd = s.di * 10 + n; // 1..30
            final g = KemeticMath.toGregorian(s.ky, s.km, kd);
            if (!inside(g)) continue;
            final key = '${s.ky}-${s.km}-$kd';
            out.add(_SelectedDay(key, s.ky, s.km, kd, g));
          }
        }
      } else {
        for (final w in _weekSpans) {
          final sel = _perWeekSel[w.key] ?? const <int>{};
          for (final wd in sel) {
            final g = w.monday.add(Duration(days: wd - 1));
            if (!inside(g)) continue;
            final k = KemeticMath.fromGregorian(g);
            final key = '${k.kYear}-${k.kMonth}-${k.kDay}';
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, g));
          }
        }
      }
    } else {
      if (_useKemetic) {
        for (DateTime d = _startDate!;
        !d.isAfter(_endDate!);
        d = d.add(const Duration(days: 1))) {
          final k = KemeticMath.fromGregorian(d);
          if (k.kMonth == 13) continue;
          final dayInDecan = ((k.kDay - 1) % 10) + 1;
          if (_selectedDecanDays.contains(dayInDecan)) {
            final key = '${k.kYear}-${k.kMonth}-${k.kDay}';
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, d));
          }
        }
      } else {
        for (DateTime d = _startDate!;
        !d.isAfter(_endDate!);
        d = d.add(const Duration(days: 1))) {
          if (_selectedWeekdays.contains(d.weekday)) {
            final k = KemeticMath.fromGregorian(d);
            final key = '${k.kYear}-${k.kMonth}-${k.kDay}';
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, d));
          }
        }
      }
    }

    out.sort((a, b) => a.g.compareTo(b.g));
    return out;
  }

  // Keep drafts in sync with the active groups.
  void _syncDraftsWithSelection() {
    final groups = _buildEditorGroups();

    // day drafts (customize mode)
    final wantDayKeys = {
      for (final g in groups.where((g) => !g.isPattern)) g.key
    };
    final removeDay = _draftsByDay.keys
        .where((k) => !wantDayKeys.contains(k))
        .toList();
    for (final k in removeDay) {
      _draftsByDay[k]?.dispose();
      _draftsByDay.remove(k);
    }
    for (final k in wantDayKeys) {
      _draftsByDay.putIfAbsent(k, () => _NoteDraft());
    }

    // pattern drafts (repeat mode)
    final wantPatKeys = {
      for (final g in groups.where((g) => g.isPattern)) g.key
    };
    final removePat = _draftsByPattern.keys
        .where((k) => !wantPatKeys.contains(k))
        .toList();
    for (final k in removePat) {
      _draftsByPattern[k]?.dispose();
      _draftsByPattern.remove(k);
    }
    for (final k in wantPatKeys) {
      _draftsByPattern.putIfAbsent(k, () => _NoteDraft());
    }

    setState(() {});
  }



  // ---------- span builders ----------

  void _rebuildSpans() {
    // normalize range order
    if (_hasFullRange && _endDate!.isBefore(_startDate!)) {
      final t = _startDate;
      _startDate = _endDate;
      _endDate = t;
    }

    if (!_hasFullRange) {
      setState(() {
        _kemeticSpans = const [];
        _weekSpans = const [];
      });
      _syncDraftsWithSelection();
      return;
    }

    // Kemetic decans present in [start..end]
    final kem = <String, _KemeticDecanSpan>{};
    for (DateTime d = _startDate!;
    !d.isAfter(_endDate!);
    d = d.add(const Duration(days: 1))) {
      final k = KemeticMath.fromGregorian(d);
      if (k.kMonth == 13) continue; // epagomenal -> no decan
      final di = ((k.kDay - 1) ~/ 10); // 0..2
      final inDec = ((k.kDay - 1) % 10) + 1; // 1..10
      final key = '${k.kYear}-${k.kMonth}-$di';
      kem.putIfAbsent(key, () {
        final monthName = _MonthCard.monthNames[k.kMonth];
        final diName =
        (_MonthCard.decans[k.kMonth] ?? const ['A', 'B', 'C'])[di];
        return _KemeticDecanSpan(
          key: key,
          ky: k.kYear,
          km: k.kMonth,
          di: di,
          label: '$monthName • $diName',
          minDay: inDec,
          maxDay: inDec,
          gStart: d,
          gEnd: d,
        );
      });
      final span = kem[key]!;
      if (inDec < span.minDay) span.minDay = inDec;
      if (inDec > span.maxDay) span.maxDay = inDec;
      if (d.isBefore(span.gStart)) span.gStart = d;
      if (d.isAfter(span.gEnd)) span.gEnd = d;
    }

    // Gregorian weeks in [start..end]
    final weeks = <String, _WeekSpan>{};
    for (DateTime d = _startDate!;
    !d.isAfter(_endDate!);
    d = d.add(const Duration(days: 1))) {
      final monday = _mondayOf(d);
      final key = _iso(monday);
      weeks.putIfAbsent(
        key,
            () => _WeekSpan(key: key, monday: monday, minWd: d.weekday, maxWd: d.weekday),
      );
      final w = weeks[key]!;
      if (d.weekday < w.minWd) w.minWd = d.weekday;
      if (d.weekday > w.maxWd) w.maxWd = d.weekday;
    }

    // trim selections outside bounds
    for (final s in kem.values) {
      final sel = _perDecanSel[s.key] ?? <int>{};
      sel.removeWhere((n) => n < s.minDay || n > s.maxDay);
      _perDecanSel[s.key] = sel;
    }
    _perDecanSel.removeWhere((k, _) => !kem.containsKey(k));

    for (final w in weeks.values) {
      final sel = _perWeekSel[w.key] ?? <int>{};
      sel.removeWhere((n) => n < w.minWd || n > w.maxWd);
      _perWeekSel[w.key] = sel;
    }
    _perWeekSel.removeWhere((k, _) => !weeks.containsKey(k));

    setState(() {
      _kemeticSpans = kem.values.toList()
        ..sort((a, b) => a.gStart.compareTo(b.gStart));
      _weekSpans = weeks.values.toList()
        ..sort((a, b) => a.monday.compareTo(b.monday));
    });

    _syncDraftsWithSelection();
  }

  // ---------- pickers ----------

  Future<DateTime?> _pickGregorianDate({DateTime? initial}) async {
    final now = DateTime.now();
    DateTime seed = DateUtils.dateOnly(initial ?? now);

    int y = seed.year;
    int m = seed.month;
    int d = seed.day;

    final int yearStart = now.year - 200;
    final yearCtrl =
    FixedExtentScrollController(initialItem: (y - yearStart).clamp(0, 400));
    final monthCtrl = FixedExtentScrollController(initialItem: (m - 1).clamp(0, 11));
    final dayCtrl   = FixedExtentScrollController(initialItem: (d - 1).clamp(0, 30));

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        int localY = y, localM = m, localD = d;

        int dayMax() => _daysInGregorianMonth(localY, localM);

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final max = dayMax();
            if (localD > max) localD = max;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const _GlossyText(
                    text: 'Pick Gregorian date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: _blueGloss,
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    height: 160,
                    child: Row(
                      children: [
                        // Month
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: monthCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localM = (i % 12) + 1;
                                final mx = dayMax();
                                if (localD > mx && dayCtrl.hasClients) {
                                  localD = mx;
                                  WidgetsBinding.instance.addPostFrameCallback(
                                        (_) => dayCtrl.jumpToItem(localD - 1),
                                  );
                                }
                              });
                            },
                            children: List<Widget>.generate(12, (i) {
                              final label = _gregMonthNames[i + 1];
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Day
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dayCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                final mx = dayMax();
                                localD = (i % mx) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayMax(), (i) {
                              final dd = i + 1;
                              return Center(
                                child: _GlossyText(
                                  text: '$dd',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Year
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: yearCtrl,
                            itemExtent: 32,
                            looping: false,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localY = yearStart + i;
                                final mx = dayMax();
                                if (localD > mx && dayCtrl.hasClients) {
                                  localD = mx;
                                  WidgetsBinding.instance.addPostFrameCallback(
                                        (_) => dayCtrl.jumpToItem(localD - 1),
                                  );
                                }
                              });
                            },
                            children: List<Widget>.generate(401, (i) {
                              final yy = yearStart + i;
                              return Center(
                                child: _GlossyText(
                                  text: '$yy',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _silver),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx, null),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            final out =
                            DateUtils.dateOnly(DateTime(localY, localM, localD));
                            Navigator.pop(sheetCtx, out);
                          },
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Future<DateTime?> _pickKemeticDate({DateTime? initial}) async {
    final initK = KemeticMath.fromGregorian(initial ?? DateTime.now());
    int ky = initK.kYear, km = initK.kMonth, kd = initK.kDay;

    int maxDayFor(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    final yearStart = initK.kYear - 200;
    final yearCtrl =
    FixedExtentScrollController(initialItem: (ky - yearStart).clamp(0, 400));
    final monthCtrl =
    FixedExtentScrollController(initialItem: (km - 1).clamp(0, 12));
    final dayCtrl = FixedExtentScrollController(initialItem: (kd - 1));

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        int localKy = ky, localKm = km, localKd = kd;

        int dayMax() => maxDayFor(localKy, localKm);

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            if (localKd > dayMax()) localKd = dayMax();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const _GlossyText(
                    text: 'Pick Kemetic date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: _goldGloss, // <- gold gleam
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: monthCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localKm = (i % 13) + 1;
                                final max = maxDayFor(localKy, localKm);
                                if (localKd > max) {
                                  localKd = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                            (_) => dayCtrl.jumpToItem(localKd - 1));
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(13, (i) {
                              final m = i + 1;
                              final label = (m == 13)
                                  ? 'Heriu Renpet (ḥr.w rnpt)'
                                  : _MonthCard.monthNames[m];
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dayCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                final max = maxDayFor(localKy, localKm);
                                localKd = (i % max) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayMax(), (i) {
                              final d = i + 1;
                              return Center(
                                child: _GlossyText(
                                  text: '$d',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: yearCtrl,
                            itemExtent: 32,
                            looping: false,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localKy = yearStart + i;
                                final max = maxDayFor(localKy, localKm);
                                if (localKd > max) {
                                  localKd = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                            (_) => dayCtrl.jumpToItem(localKd - 1));
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(401, (i) {
                              final ky = yearStart + i;
                              final label = _gregYearLabelFor(ky, localKm);
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _silver),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx, null),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.white, // text color pairs with glossy white label
                          ),
                          onPressed: () {
                            final g = KemeticMath.toGregorian(localKy, localKm, localKd);
                            Navigator.pop(sheetCtx, _dateOnly(g));
                          },
                          child: const _GlossyText(
                            text: 'Done',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            gradient: _whiteGloss, // subtle sheen on the label
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickRangeStart() async {
    final picked = _useKemetic
        ? await _pickKemeticDate(initial: _startDate)
        : await _pickGregorianDate(initial: _startDate);
    if (picked != null) {
      setState(() => _startDate = _dateOnly(picked));
      _rebuildSpans();
    }
  }

  Future<void> _pickRangeEnd() async {
    final picked = _useKemetic
        ? await _pickKemeticDate(initial: _endDate ?? _startDate)
        : await _pickGregorianDate(initial: _endDate ?? _startDate);
    if (picked != null) {
      setState(() => _endDate = _dateOnly(picked));
      _rebuildSpans();
    }
  }


  // ---------- Overview support ----------

  final TextEditingController _overviewCtrl = TextEditingController();


  Future<void> _openOverviewEditor() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const _GlossyText(
                text: 'Flow overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                gradient: _silverGloss,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _overviewCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 10,
                decoration: _darkInput(
                  'Describe this flow',
                  hint: 'What is this flow about? Any tips, links, or context?',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _silver),
                      ),
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    setState(() {}); // refresh anything that reflects overview (none inline yet)
  }

  // ---------- per-day/pattern note editors ----------

  Future<void> _pickStartFor(_NoteDraft draft) async {
    final t = await showTimePicker(
      context: context,
      initialTime: draft.start ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (c, w) => Theme(
        data: Theme.of(c!).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _gold,
            surface: _bg,
            onSurface: Colors.white,
          ),
        ),
        child: w!,
      ),
    );
    if (t == null) return;
    setState(() {
      draft.start = t;
      if (draft.end != null) {
        if (_toMinutes(draft.end!) <= _toMinutes(t)) {
          draft.end = _addMinutes(t, 60);
        }
      }
    });
  }

  Future<void> _pickEndFor(_NoteDraft draft) async {
    final t = await showTimePicker(
      context: context,
      initialTime: draft.end ??
          (draft.start != null
              ? _addMinutes(draft.start!, 60)
              : const TimeOfDay(hour: 13, minute: 0)),
      builder: (c, w) => Theme(
        data: Theme.of(c!).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _gold,
            surface: _bg,
            onSurface: Colors.white,
          ),
        ),
        child: w!,
      ),
    );
    if (t == null) return;
    setState(() {
      draft.end = t;
      if (draft.start != null) {
        if (_toMinutes(t) <= _toMinutes(draft.start!)) {
          draft.start = _addMinutes(t, -60);
        }
      }
    });
  }

  Widget _timeButton(
      String label, TimeOfDay? value, VoidCallback onTap, bool enabled) {
    final h = value?.hourOfPeriod == 0 ? 12 : (value?.hourOfPeriod ?? 12);
    final m = (value?.minute ?? 0).toString().padLeft(2, '0');
    final ap =
    (value == null) ? '' : (value.period == DayPeriod.am ? 'AM' : 'PM');
    final text = value == null ? '--:--' : '$h:$m $ap';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('', style: TextStyle(fontSize: 0)),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _silver, width: 1),
            ),
            onPressed: enabled ? onTap : null,
            child: Text('$label: $text'),
          ),
        ),
      ],
    );
  }

  Widget _notesEditorsPanel() {
    final groups = _buildEditorGroups();
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const _GlossyText(
          text: 'Notes for selection',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        const SizedBox(height: 8),
        ...groups.map((g) {
          final draft = g.isPattern
              ? (_draftsByPattern[g.key]!)
              : (_draftsByDay[g.key]!);

          return Padding(
            key: ValueKey(g.key),
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: const Color(0xFF121315),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _cardBorderGold, width: 1.0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlossyText(
                      text: g.header,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      gradient: _silverGloss,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: draft.titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _darkInput('Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: draft.locationCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _darkInput(
                        'Location or Video Call',
                        hint: 'e.g., Home • Zoom • https://…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: draft.detailCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: _darkInput('Details (optional)'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: draft.allDay,
                      onChanged: (v) => setState(() => draft.allDay = v),
                      title: const _GlossyText(
                        text: 'All-day',
                        style: TextStyle(fontSize: 14),
                        gradient: _silverGloss,
                      ),
                      activeThumbColor: _gold,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _timeButton(
                            'Starts',
                            draft.start,
                                () => _pickStartFor(draft),
                            !draft.allDay,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _timeButton(
                            'Ends',
                            draft.end,
                                () => _pickEndFor(draft),
                            !draft.allDay,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------- save/delete ----------

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give your flow a name.')));
      return;
    }

    // require rule choices only if a range is set
    if (_hasFullRange) {
      if (_useKemetic) {
        final ok = _splitByPeriod
            ? _perDecanSel.values.any((s) => s.isNotEmpty)
            : _selectedDecanDays.isNotEmpty;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pick at least one decan day.')));
          return;
        }
      } else {
        final ok = _splitByPeriod
            ? _perWeekSel.values.any((s) => s.isNotEmpty)
            : _selectedWeekdays.isNotEmpty;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pick at least one weekday.')));
          return;
        }
      }
    }

    // normalize
    if (_hasFullRange && _endDate!.isBefore(_startDate!)) {
      final t = _startDate;
      _startDate = _endDate;
      _endDate = t;
    }

    final rules = <_FlowRule>[];

    if (_hasFullRange) {
      if (_splitByPeriod) {
        // explicit dates rule
        final out = <DateTime>{};
        if (_useKemetic) {
          for (final s in _kemeticSpans) {
            final set = _perDecanSel[s.key] ?? const <int>{};
            for (final n in set) {
              final kd = s.di * 10 + n;
              final g = KemeticMath.toGregorian(s.ky, s.km, kd);
              final go = _dateOnly(g);
              if (!go.isBefore(_startDate!) && !go.isAfter(_endDate!)) out.add(go);
            }
          }
        } else {
          for (final w in _weekSpans) {
            final set = _perWeekSel[w.key] ?? const <int>{};
            for (final wd in set) {
              final g = _dateOnly(w.monday.add(Duration(days: wd - 1)));
              if (!g.isBefore(_startDate!) && !g.isAfter(_endDate!)) out.add(g);
            }
          }
        }
        if (out.isNotEmpty) rules.add(_RuleDates(dates: out));
      } else {
        // single-row rule
        if (_useKemetic) {
          rules.add(_RuleDecan(
            months: _fullRange(1, 12),
            decans: _fullRange(1, 3),
            daysInDecan: _selectedDecanDays,
            allDay: true,
          ));
        } else {
          rules.add(_RuleWeek(weekdays: _selectedWeekdays, allDay: true));
        }
      }
    }

    // collect planned notes
    final groups = _buildEditorGroups();
    final planned = <_PlannedNote>[];

// attach current flow id to notes created by this save
    final int? flowId = _editing?.id ?? widget.editFlowId;

    final notes = notesEncode(
      kemetic: _useKemetic,
      split: _splitByPeriod,
      overview: _overviewCtrl.text,
    );



    if (_splitByPeriod) {
      // per-day drafts
      for (final g in groups) {
        final d = g.days.first;
        final draft = _draftsByDay[d.key];
        if (draft == null) continue;
        if (draft.titleCtrl.text.trim().isEmpty) continue;

        final noteWithFlowId = draft.toNote();
        final linkedNote = _Note(
          title: noteWithFlowId.title,
          detail: noteWithFlowId.detail,
          location: noteWithFlowId.location,
          allDay: noteWithFlowId.allDay,
          start: noteWithFlowId.start,
          end: noteWithFlowId.end,
          flowId: flowId,
        );

        planned.add(_PlannedNote(ky: d.ky, km: d.km, kd: d.kd, note: linkedNote));
      }
    } else {
      // pattern drafts: apply to all concrete matches in the group
      for (final g in groups) {
        final draft = _draftsByPattern[g.key];
        if (draft == null) continue;
        if (draft.titleCtrl.text.trim().isEmpty) continue;

        final noteWithFlowId = draft.toNote();
        final linkedNote = _Note(
          title: noteWithFlowId.title,
          detail: noteWithFlowId.detail,
          location: noteWithFlowId.location,
          allDay: noteWithFlowId.allDay,
          start: noteWithFlowId.start,
          end: noteWithFlowId.end,
          flowId: flowId,
        );

        for (final d in g.days) {
          planned.add(_PlannedNote(ky: d.ky, km: d.km, kd: d.kd, note: linkedNote));
        }
      }
    }


// AFTER building `planned`

    final seen = <String>{};
    planned.retainWhere((p) {
      final key = '${p.ky}-${p.km}-${p.kd}|${p.note.title.trim()}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    });

    final flow = _Flow(
      id: _editing?.id ?? -1,
      name: name,
      color: _flowPalette[_selectedColorIndex],
      active: _active,
      rules: rules,
      start: _startDate,
      end: _endDate,
      notes: notes,
    );

    Navigator.of(context, rootNavigator: true)
        .pop(_FlowStudioResult(savedFlow: flow, plannedNotes: planned));
  }

  void _delete() {
    if (_editing == null) return;
    Navigator.of(context, rootNavigator: true)
        .pop(_FlowStudioResult(deleteFlowId: _editing!.id));
  }

  // ---------- Flow picker / preview ----------

  Future<void> _openFlowPicker() async {
    if (widget.existingFlows.isEmpty) return;

    final searchCtrl = TextEditingController();
    List<_Flow> filtered = List.of(widget.existingFlows)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        void applyFilter() {
          final q = searchCtrl.text.trim().toLowerCase();
          filtered = widget.existingFlows
              .where((f) => f.name.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }

        applyFilter();

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const _GlossyText(
                    text: 'Find / Edit a flow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: _silverGloss,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _darkInput('Search flows', hint: 'Type a name…'),
                    onChanged: (_) => setSheetState(applyFilter),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: filtered.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('No flows match', style: TextStyle(color: Colors.white70)),
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.white10),
                      itemBuilder: (_, i) {
                        final f = filtered[i];
                        return ListTile(
                          dense: true,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _showFlowPreview(f);
                          },
                          leading: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _glossFromColor(f.color),
                            ),
                          ),
                          title: Text(f.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            [
                              f.active ? 'Active' : 'Inactive',
                              if (f.start != null || f.end != null)
                                '${_fmtGregorian(f.start)} → ${_fmtGregorian(f.end)}',
                              notesDecode(f.notes).kemetic ? 'Kemetic' : 'Gregorian',
                            ].join(' • '),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: _silver),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _silver),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
  }

  void _showFlowPreview(_Flow f) {
    final meta = notesDecode(f.notes);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FlowPreviewPage(
          flow: f,
          kemetic: meta.kemetic,
          split: meta.split,
          overview: meta.overview,
          getDecanLabel: (km, di) =>
          (_MonthCard.decans[km] ?? const ['I','II','III'])[di],
          fmt: (d) => _fmtGregorian(d),
          onEdit: () {
            _loadFlowForEdit(f);
            Navigator.of(context).pop();
          },
          isMaatInstance: (f.notes ?? '').contains('maat='),
          onEndMaatFlow: null, // Flow Studio can't end flows (no access to _endFlow)
        ),
      ),
    );
  }

  void _clearEditorForNew() {
    setState(() {
      _editing = null;
      _nameCtrl.text = '';
      _active = true;
      _selectedColorIndex = 0;
      _useKemetic = false;
      _startDate = null;
      _endDate = null;
      _splitByPeriod = false;

      _selectedDecanDays.clear();
      _selectedWeekdays.clear();
      _perDecanSel.clear();
      _perWeekSel.clear();

      for (final d in _draftsByDay.values) { d.dispose(); }
      for (final d in _draftsByPattern.values) { d.dispose(); }
      _draftsByDay.clear();
      _draftsByPattern.clear();

      _overviewCtrl.text = '';

      _rebuildSpans();
    });
  }

  // Load an existing flow into the editor (best-effort reconstruction of rules)
  void _loadFlowForEdit(_Flow f) {
    // Add debug logging
    if (kDebugMode) {
      debugPrint('[loadFlowForEdit] Loading flow ${f.id} "${f.name}" with color=${f.color.value.toRadixString(16)}');
    }
    
    setState(() {
      _editing = f;
      _nameCtrl.text = f.name;
      _active = f.active;

      final idx = _flowPalette.indexWhere((c) => c.value == f.color.value);
      _selectedColorIndex = idx >= 0 ? idx : 0;
      
      // Add debug logging for color not found
      if (kDebugMode && idx < 0) {
        debugPrint('[loadFlowForEdit] Color ${f.color.value.toRadixString(16)} not found in palette, defaulting to index 0');
      }

      _startDate = f.start == null ? null : _dateOnly(f.start!);
      _endDate   = f.end   == null ? null : _dateOnly(f.end!);

      final meta = notesDecode(f.notes);
      _useKemetic = meta.kemetic;
      _splitByPeriod = meta.split;
      _overviewCtrl.text = meta.overview;

      // reset selections
      _selectedDecanDays.clear();
      _selectedWeekdays.clear();
      _perDecanSel.clear();
      _perWeekSel.clear();

      // try to reconstruct the selection state from rules
      if (f.rules.isNotEmpty) {
        final r = f.rules.first;
        if (r is _RuleDecan) {
          _useKemetic = true;
          _splitByPeriod = false;
          _selectedDecanDays.addAll(r.daysInDecan);
        } else if (r is _RuleWeek) {
          _useKemetic = false;
          _splitByPeriod = false;
          _selectedWeekdays.addAll(r.weekdays);
        } else if (r is _RuleDates) {
          _splitByPeriod = true;
          // build spans first
          _rebuildSpans();
          // seed per-period picks
          for (final g in r.dates) {
            if (_useKemetic) {
              final k = KemeticMath.fromGregorian(g);
              if (k.kMonth == 13) continue;
              final di = ((k.kDay - 1) ~/ 10);
              final inDec = ((k.kDay - 1) % 10) + 1;
              final key = '${k.kYear}-${k.kMonth}-$di';
              final set = _perDecanSel[key] ?? <int>{};
              set.add(inDec);
              _perDecanSel[key] = set;
            } else {
              final mon = _mondayOf(g);
              final key = _iso(mon);
              final set = _perWeekSel[key] ?? <int>{};
              set.add(g.weekday);
              _perWeekSel[key] = set;
            }
          }
        }
      }

      _rebuildSpans(); // refresh UI with new selections
    });
  }

  // ---------- scaffold ----------

  @override
  void initState() {
    super.initState();

    // preload if editing
    try {
      if (widget.editFlowId != null) {
        _editing =
            widget.existingFlows.firstWhere((f) => f.id == widget.editFlowId);
      }
    } catch (_) {
      _editing = null;
    }

    _nameCtrl = TextEditingController(text: _editing?.name ?? '');
    _active = _editing?.active ?? true;

    if (_editing != null) {
      _loadFlowForEdit(_editing!);
    } else {
      _rebuildSpans(); // harmless if range empty
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _overviewCtrl.dispose();
    for (final d in _draftsByDay.values) {
      d.dispose();
    }
    for (final d in _draftsByPattern.values) {
      d.dispose();
    }
    super.dispose();
  }

  // ---------- UI bits ----------

  Widget _colorDot(int i) {
    final selected = i == _selectedColorIndex;
    return InkWell(
      onTap: () => setState(() => _selectedColorIndex = i),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _glossFromColor(_flowPalette[i]),
          border: Border.all(
              color: selected ? _gold : Colors.white24,
              width: selected ? 2.0 : 1.0),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return CupertinoSegmentedControl<bool>(
      groupValue: _useKemetic,
      padding: const EdgeInsets.all(2),
      children: const {
        true: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('Kemetic')),
        false: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('Gregorian')),
      },
      onValueChanged: (v) {
        setState(() {
          _useKemetic = v;
        });
        _rebuildSpans();
      },
    );
  }

  Widget _dateRangeSection() {
    final startLabel =
    _useKemetic ? _fmtKemetic(_startDate) : _fmtGregorian(_startDate);
    final endLabel =
    _useKemetic ? _fmtKemetic(_endDate) : _fmtGregorian(_endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlossyText(
          text: 'Date range (optional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: _silver),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _pickRangeStart,
                child: Text(startLabel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: _silver),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _pickRangeEnd,
                child: Text(endLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preRulesHint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 16),
        _GlossyText(
          text: 'Set a start and end date to define rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        SizedBox(height: 6),
        Text(
          'After you pick both dates above, the rule chips will appear here.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // Single-row chips (same for all decans / all weeks)
  Widget _kemeticSingleRow() {
    FilterChip chip(int n) => FilterChip(
      label: Text('$n'),
      selected: _selectedDecanDays.contains(n),
      onSelected: (v) {
        setState(() {
          v ? _selectedDecanDays.add(n) : _selectedDecanDays.remove(n);
        });
        _syncDraftsWithSelection();
      },
      selectedColor: _gold.withOpacity(0.22),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: _silver),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1B1F),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlossyText(
          text: 'Kemetic rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (var n = 1; n <= 10; n++) chip(n)],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDecanDays
                    ..clear()
                    ..addAll({for (var i = 1; i <= 10; i++) i});
                });
                _syncDraftsWithSelection();
              },
              child: const Text('Select all'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedDecanDays.clear());
                _syncDraftsWithSelection();
              },
              child: const Text('Clear'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openOverviewEditor,
              icon: const Icon(Icons.subject, color: _silver),
              label: const Text('Overview'),
            ),
          ],
        ),
      ],
    );
  }


  Widget _gregorianSingleRow() {
    FilterChip chip(int n, String label) => FilterChip(
      label: Text(label),
      selected: _selectedWeekdays.contains(n),
      onSelected: (v) {
        setState(() {
          v ? _selectedWeekdays.add(n) : _selectedWeekdays.remove(n);
        });
        _syncDraftsWithSelection();
      },
      selectedColor: _gold.withOpacity(0.22),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: _silver),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1B1F),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlossyText(
          text: 'Gregorian rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 7; i++) chip(i + 1, _wdLabels[i]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedWeekdays..clear()..addAll({1, 2, 3, 4, 5, 6, 7});
                });
                _syncDraftsWithSelection();
              },
              child: const Text('Select all'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedWeekdays.clear());
                _syncDraftsWithSelection();
              },
              child: const Text('Clear'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openOverviewEditor,
              icon: const Icon(Icons.subject, color: _silver),
              label: const Text('Overview'),
            ),
          ],
        ),
      ],
    );
  }
  // Per-period rows (decans or weeks)
  Widget _kemeticPerDecan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlossyText(
          text: 'Kemetic rules • per decan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        Row(
          children: const [
            Spacer(),
            // keep spacing aligned with other sections
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _openOverviewEditor,
            icon: const Icon(Icons.subject, color: _silver),
            label: const Text('Overview'),
          ),
        ),
        const SizedBox(height: 8),
        if (_kemeticSpans.isEmpty)
          const Text('No decans in this range.',
              style: TextStyle(color: Colors.white70))
        else
          ..._kemeticSpans.map((s) {
            final sel = _perDecanSel[s.key] ?? <int>{};
            Widget chip(int n) {
              final enabled = n >= s.minDay && n <= s.maxDay;
              final selected = enabled && sel.contains(n);
              return FilterChip(
                label: Text('$n'),
                selected: selected,
                onSelected: !enabled
                    ? null
                    : (v) {
                  setState(() {
                    final set = _perDecanSel[s.key] ?? <int>{};
                    v ? set.add(n) : set.remove(n);
                    _perDecanSel[s.key] = set;
                  });
                  _syncDraftsWithSelection();
                },
                selectedColor: _gold.withOpacity(0.22),
                checkmarkColor: Colors.white,
                side: BorderSide(color: enabled ? _silver : Colors.white12),
                labelStyle: TextStyle(
                    color: enabled ? Colors.white : Colors.white30),
                backgroundColor: const Color(0xFF1A1B1F),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (var n = 1; n <= 10; n++) chip(n)],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _gregorianPerWeek() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlossyText(
          text: 'Gregorian rules • per week',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: _silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        if (_weekSpans.isEmpty)
          const Text('No weeks in this range.',
              style: TextStyle(color: Colors.white70))
        else
          ..._weekSpans.map((w) {
            final label = 'Week of ${_fmtGregorian(w.monday)}';
            final sel = _perWeekSel[w.key] ?? <int>{};

            Widget chip(int wd, String lab) {
              final enabled = wd >= w.minWd && wd <= w.maxWd;
              final selected = enabled && sel.contains(wd);
              return FilterChip(
                label: Text(lab),
                selected: selected,
                onSelected: !enabled
                    ? null
                    : (v) {
                  setState(() {
                    final set = _perWeekSel[w.key] ?? <int>{};
                    v ? set.add(wd) : set.remove(wd);
                    _perWeekSel[w.key] = set;
                  });
                  _syncDraftsWithSelection();
                },
                selectedColor: _gold.withOpacity(0.22),
                checkmarkColor: Colors.white,
                side: BorderSide(color: enabled ? _silver : Colors.white12),
                labelStyle: TextStyle(
                    color: enabled ? Colors.white : Colors.white30),
                backgroundColor: const Color(0xFF1A1B1F),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 7; i++) chip(i + 1, _wdLabels[i]),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // Toggle between single row vs per-period rows
  Widget _toggleCustomizeButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: !_hasFullRange
            ? null
            : () {
          setState(() {
            // when turning on, seed per-period selections from single-row choice
            if (!_splitByPeriod) {
              if (_useKemetic) {
                for (final s in _kemeticSpans) {
                  final base = _selectedDecanDays
                      .where((n) => n >= s.minDay && n <= s.maxDay);
                  _perDecanSel[s.key] = {...base};
                }
              } else {
                for (final w in _weekSpans) {
                  final base = _selectedWeekdays
                      .where((n) => n >= w.minWd && n <= w.maxWd);
                  _perWeekSel[w.key] = {...base};
                }
              }
            }
            _splitByPeriod = !_splitByPeriod;
          });
          _syncDraftsWithSelection();
        },
        icon: const Icon(Icons.tune, color: _silver),
        label: Text(
          _splitByPeriod
              ? (_useKemetic
              ? 'Same days for all decans'
              : 'Same days for every week')
              : (_useKemetic ? 'Customize per decan' : 'Customize per week'),
        ),
      ),
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Flow Studio', style: TextStyle(color: Colors.white)),
        actions: [
          // Only show the dropdown when there's at least one existing flow
          if (widget.existingFlows.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Flows menu',
              icon: const Icon(Icons.more_vert, color: _silver),
              onSelected: (v) {
                if (v == 1) _openFlowPicker();
                if (v == 2) _clearEditorForNew();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 1,
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Find / Edit flows…'),
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('New flow'),
                  ),
                ),
              ],
            ),
          if (_editing != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: _silver),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ListView(
          children: [
            const Text('Name', style: TextStyle(color: _silver, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _darkInput('Flow name'),
            ),
            const SizedBox(height: 8),
            // quick peek at overview (one-line, optional)
            if (_overviewCtrl.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _overviewCtrl.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Active', style: TextStyle(color: Colors.white)),
              activeThumbColor: _gold,
            ),

            const SizedBox(height: 8),
            const _GlossyText(
              text: 'Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              gradient: _silverGloss,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _flowPalette.length,
                itemBuilder: (_, i) => _colorDot(i),
              ),
            ),

            const SizedBox(height: 12),
            _modeToggle(),

            const SizedBox(height: 12),
            _dateRangeSection(),

            const SizedBox(height: 6),
            if (!_hasFullRange)
              _preRulesHint()
            else if (_useKemetic)
              (_splitByPeriod ? _kemeticPerDecan() : _kemeticSingleRow())
            else
              (_splitByPeriod ? _gregorianPerWeek() : _gregorianSingleRow()),

            // editors (pattern in repeat mode, per-day in customize mode)
            SizedBox(key: _editorsAnchorKey, height: 0),
            _notesEditorsPanel(),
          ],
        ),
      ),
    );
  }
}


/* ---------------- Flow Preview Page (read-only) ---------------- */

class _FlowPreviewPage extends StatelessWidget {
  const _FlowPreviewPage({
    required this.flow,
    required this.kemetic,
    required this.split,
    required this.overview,
    required this.getDecanLabel,
    required this.fmt,
    required this.onEdit,
    this.onEndMaatFlow,
    this.isMaatInstance = false,
  });

  final _Flow flow;
  final bool kemetic;
  final bool split;
  final String overview;
  final String Function(int km, int di) getDecanLabel;
  final String Function(DateTime? g) fmt;
  final VoidCallback onEdit;

  /// if provided & [isMaatInstance] true, show a gold-outline "End Flow" button.
  final VoidCallback? onEndMaatFlow;
  final bool isMaatInstance;

  List<Widget> _buildSchedule(BuildContext context) {
    final rows = <TableRow>[];

    TextStyle head = const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );
    TextStyle cell = const TextStyle(color: Colors.white, fontSize: 13);

    // Header
    rows.add(
      TableRow(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(kemetic ? 'DECAN' : 'WEEKDAY', style: head)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('DAYS', style: head, textAlign: TextAlign.right)),
      ]),
    );
    rows.add(
      const TableRow(children: [
        SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
        SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
      ]),
    );

    if (flow.rules.isEmpty) {
      rows.add(TableRow(children: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('—', style: TextStyle(color: Colors.white54))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No schedule', style: TextStyle(color: Colors.white54), textAlign: TextAlign.right)),
      ]));
      return [
        Table(columnWidths: const {1: FlexColumnWidth(2)}, children: rows),
      ];
    }

    final r = flow.rules.first;
    if (kemetic) {
      if (r is _RuleDecan) {
        final days = r.daysInDecan.toList()..sort();
        for (final di in [1, 2, 3]) {
          final label = ['I', 'II', 'III'][di - 1];
          rows.add(TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Decan $label', style: cell)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(days.isEmpty ? '—' : days.join(', '), style: cell, textAlign: TextAlign.right),
            ),
          ]));
        }
      } else if (r is _RuleDates) {
        // Group by Month • Decan
        final Map<String, List<int>> map = {};
        for (final g in r.dates) {
          final k = KemeticMath.fromGregorian(g);
          if (k.kMonth == 13) continue; // skip epagomenal
          final di = ((k.kDay - 1) ~/ 10); // 0..2
          final inDec = ((k.kDay - 1) % 10) + 1;
          final name = '${_MonthCard.monthNames[k.kMonth]} • ${getDecanLabel(k.kMonth, di)}';
          (map[name] ??= <int>[]).add(inDec);
        }
        final keys = map.keys.toList()..sort();
        for (final key in keys) {
          final days = map[key]!..sort();
          rows.add(TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(key, style: cell)),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(days.join(', '), style: cell, textAlign: TextAlign.right)),
          ]));
        }
      } else {
        rows.add(TableRow(children: [
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('—', style: TextStyle(color: Colors.white54))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Unsupported rule', style: TextStyle(color: Colors.white54), textAlign: TextAlign.right)),
        ]));
      }
    } else {
      if (r is _RuleWeek) {
        final names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        for (int i = 1; i <= 7; i++) {
          rows.add(TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(names[i-1], style: cell)),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(r.weekdays.contains(i) ? 'Yes' : '—', style: cell, textAlign: TextAlign.right)),
          ]));
        }
      } else if (r is _RuleDates) {
        // Group by week-of (Monday)
        final Map<DateTime, List<int>> byWeek = {};
        for (final g in r.dates) {
          final monday = _FlowStudioPageState._mondayOf(g);
          (byWeek[monday] ??= <int>[]).add(g.weekday);
        }
        final weeks = byWeek.keys.toList()..sort();
        final wdName = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        for (final m in weeks) {
          final days = byWeek[m]!..sort();
          rows.add(TableRow(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Week of ${_FlowStudioPageState._iso(m)}', style: cell)),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(days.map((wd)=>wdName[wd-1]).join(', '), style: cell, textAlign: TextAlign.right)),
          ]));
        }
      } else {
        rows.add(TableRow(children: [
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('—', style: TextStyle(color: Colors.white54))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Unsupported rule', style: TextStyle(color: Colors.white54), textAlign: TextAlign.right)),
        ]));
      }
    }

    return [
      Table(
        columnWidths: const {1: FlexColumnWidth(2)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: const Text('Flow', style: TextStyle(color: Colors.white)),
        actions: [
          if (isMaatInstance && onEndMaatFlow != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold, width: 1.2),
              ),
              onPressed: onEndMaatFlow,
              child: const Text('End Flow'),
            ),
          TextButton(
            onPressed: onEdit,
            child: const Text('Edit', style: TextStyle(color: Colors.white)),
          ),
        ],

      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Name
          _GlossyText(
            text: flow.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            gradient: _goldGloss,
          ),
          const SizedBox(height: 10),

          // Overview
          const _GlossyText(
            text: 'Overview',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: _silverGloss,
          ),
          const SizedBox(height: 6),
          Text(
            (overview.trim().isEmpty) ? '—' : overview.trim(),
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 16),

          // Date range + mode
          Row(
            children: [
              Expanded(
                child: Text(
                  kemetic ? 'Kemetic' : 'Gregorian',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                '${fmt(flow.start)} → ${fmt(flow.end)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Schedule
          const _GlossyText(
            text: 'Schedule',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: _silverGloss,
          ),
          const SizedBox(height: 6),
          ..._buildSchedule(context),
        ],
      ),
    );
  }
}

/* ---------------- Flows Viewer (list → preview) ---------------- */

String notesEncode({
  required bool kemetic,
  required bool split,
  required String overview,
  String? maatKey,
}) {
  final parts = <String>[
    kemetic ? 'mode=kemetic' : 'mode=gregorian',
    if (split) 'split=1',
    if (overview.trim().isNotEmpty) 'ov=${Uri.encodeComponent(overview.trim())}',
    if (maatKey != null) 'maat=$maatKey',
  ];
  return parts.join(';');
}

({bool kemetic, bool split, String overview, String? maatKey}) notesDecode(String? notes) {
  bool kemetic = false;
  bool split = false;
  String overview = '';
  String? maatKey;
  if (notes != null && notes.isNotEmpty) {
    for (final token in notes.split(';')) {
      final t = token.trim();
      if (t == 'mode=kemetic') kemetic = true;
      if (t == 'split=1') split = true;
      if (t.startsWith('ov=')) overview = Uri.decodeComponent(t.substring(3));
      if (t.startsWith('maat=')) maatKey = t.substring(5);
    }
  }
  return (kemetic: kemetic, split: split, overview: overview, maatKey: maatKey);
}


class _FlowsViewerPage extends StatefulWidget {
  const _FlowsViewerPage({
    required this.flows,
    required this.fmtGregorian,
    required this.onCreateNew,
    required this.onEditFlow,
    required this.openMaatFlows,
    required this.onEndFlow,
  });

  final List<_Flow> flows;
  final String Function(DateTime? d) fmtGregorian;
  final VoidCallback onCreateNew;
  final void Function(int flowId) onEditFlow;
  final VoidCallback openMaatFlows; // <-- NEW
  final void Function(int flowId) onEndFlow;

  @override
  State<_FlowsViewerPage> createState() => _FlowsViewerPageState();
}

class _FlowsViewerPageState extends State<_FlowsViewerPage> {
  @override
  Widget build(BuildContext context) {
    final items = widget.flows.where((f) => f.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));


    Widget emptyState = const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No flows yet', style: TextStyle(color: Colors.white70, fontSize: 16)),
          SizedBox(height: 8),
          Text('Tap + to create a flow, or explore Ma’at templates.',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );


    Widget list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.white10),
      itemBuilder: (ctx, i) {
        final f = items[i];
        final meta = notesDecode(f.notes);
        final modeLabel = meta.kemetic ? 'Kemetic' : 'Gregorian';
        final rangeLabel = '${widget.fmtGregorian(f.start)} → ${widget.fmtGregorian(f.end)}';

        return ListTile(
          onTap: () {
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (_) => _FlowPreviewPage(
                  flow: f,
                  kemetic: meta.kemetic,
                  split: meta.split,
                  overview: meta.overview,
                  getDecanLabel: (km, di) =>
                  (_MonthCard.decans[km] ?? const ['I','II','III'])[di],
                  fmt: widget.fmtGregorian,
                  onEdit: () => widget.onEditFlow(f.id),
                  isMaatInstance: (f.notes ?? '').contains('maat='),
                  onEndMaatFlow: (f.notes ?? '').contains('maat=')
                      ? () {
                    widget.onEndFlow(f.id);
                    Navigator.of(context).pop();
                  }
                      : null,

                ),
              ),
            )
                .then((_) => setState(() {}));
          },

          leading: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _glossFromColor(f.color),
            ),
          ),
          title: Text(f.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            [
              f.active ? 'Active' : 'Inactive',
              modeLabel,
              if (f.start != null || f.end != null) rangeLabel,
            ].join(' • '),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: _silver),
        );
      },
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: const Text('My Flows', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(Icons.add, color: _silver),
            onPressed: () { widget.onCreateNew(); if (mounted) setState(() {}); },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: items.isEmpty ? emptyState : list),
        ],
      ),
    );
  }
}



/* ───────────────────────── Flow Hub (entry page) ───────────────────────── */

class _FlowHubPage extends StatelessWidget {
  const _FlowHubPage({
    required this.openMyFlows,
    required this.openMaatFlows,
    required this.onCreateNew,
    super.key,
  });

  final VoidCallback openMyFlows;
  final VoidCallback openMaatFlows;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: const Text('Flow Studio', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(Icons.add, color: _silver),
            onPressed: onCreateNew,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // centers vertically
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlossyButton(
                text: 'My Flows',
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB8860B),
                    Color(0xFFD4AF37),
                    Color(0xFFF0D879),
                  ],
                ),
                borderColor: const Color(0xFFD4AF37),
                onPressed: openMyFlows, // <-- use the callback you passed in
              ),
              const SizedBox(height: 14),
              GlossyButton(
                text: "Ma'at Flows",
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7F8C8D),
                    Color(0xFFBDC3C7),
                    Color(0xFFEAECEE),
                  ],
                ),
                borderColor: const Color(0xFFBDC3C7),
                onPressed: openMaatFlows, // <-- use the callback you passed in
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- glossy button (local to this file) -----------------
class GlossyButton extends StatelessWidget {
  const GlossyButton({
    super.key,
    required this.text,
    required this.gradient,
    required this.borderColor,
    required this.onPressed,
  });

  final String text;
  final Gradient gradient;
  final Color borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // smaller “bubble” = shorter height + tighter radius
    const double height = 52;  // tweak 48–56 if you want
    const double radius = 26;  // half of height = soft pill
    const double textSize = 20;
    const FontWeight weight = FontWeight.w700;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // background with gradient + border + shadow
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 12,
                  offset: Offset(0, 6),
                  color: Colors.black26,
                ),
              ],
            ),
            child: const SizedBox.expand(),
          ),

          // gleam overlay (subtle diagonal shine)
          IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Align(
                alignment: Alignment.topLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.85,
                  heightFactor: 0.55,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.35),
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // tap surface + label
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              onTap: onPressed,
              child: const Center(
                child: Text(
                  '',
                  // placeholder, replaced below
                ),
              ),
            ),
          ),
          // we want the text above the gleam and centered
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: textSize,     // bigger text
                fontWeight: weight,
                color: Colors.black,    // contrasts on gold/silver
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/* ───────────────────────── Ma’at Flows categories ───────────────────────── */

class _MaatCategoriesPage extends StatelessWidget {
  const _MaatCategoriesPage({
    required this.hasActiveForKey,
    required this.onPickTemplate,
    required this.onCreateNew,
    super.key,
  });

  final bool Function(String key) hasActiveForKey;
  final void Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: const Text("Ma'at Flows", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(Icons.add, color: _silver),
            onPressed: onCreateNew,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MaatFlowsListPage(
                    hasActiveForKey: hasActiveForKey,
                    onPickTemplate: onPickTemplate,
                    onCreateNew: onCreateNew,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              alignment: Alignment.centerLeft,
            ),
            child: const Text('Kemetic Culture & History'),
          ),
          const Divider(height: 12, color: Colors.white10),
        ],
      ),
    );
  }
}

/* ───────────────────────── Ma’at Flows list ───────────────────────── */

class _MaatFlowsListPage extends StatelessWidget {
  const _MaatFlowsListPage({
    required this.hasActiveForKey,
    required this.onPickTemplate,
    required this.onCreateNew,
    super.key,
  });

  final bool Function(String key) hasActiveForKey;
  final void Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: const Text("Kemetic Culture & History", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(Icons.add, color: _silver),
            onPressed: onCreateNew,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: kMaatFlowTemplates.length,
        separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.white10),
        itemBuilder: (ctx, i) {
          final t = kMaatFlowTemplates[i];
          final added = hasActiveForKey(t.key);
          return ListTile(
            onTap: () => onPickTemplate(t),
            leading: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _glossFromColor(t.color),
              ),
            ),
            title: Text(t.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text('10 days • ${t.overview.isEmpty ? '—' : 'Tap for details'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            trailing: added
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _gold, width: 1.2),
              ),
              child: const Text('Added', style: TextStyle(color: _gold, fontSize: 12)),
            )
                : const Icon(Icons.chevron_right, color: _silver),
          );
        },
      ),
    );
  }
}

/* ───────────────────────── Template detail (Add Flow) ───────────────────────── */

class _MaatFlowTemplateDetailPage extends StatefulWidget {
  const _MaatFlowTemplateDetailPage({
    required this.template,
    required this.addInstance,
    super.key,
  });

  final _MaatFlowTemplate template;
  final int Function({
  required _MaatFlowTemplate template,
  required DateTime startDate,
  required bool useKemetic,
  }) addInstance;

  @override
  State<_MaatFlowTemplateDetailPage> createState() => _MaatFlowTemplateDetailPageState();
}

class _MaatFlowTemplateDetailPageState extends State<_MaatFlowTemplateDetailPage> {
  String _fmtGregorian(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _kemeticLabelFor(DateTime g) {
    final k = KemeticMath.fromGregorian(g);
    final lastDay =
    (k.kMonth == 13) ? (KemeticMath.isLeapKemeticYear(k.kYear) ? 6 : 5) : 30;
    final yStart = KemeticMath.toGregorian(k.kYear, k.kMonth, 1).year;
    final yEnd   = KemeticMath.toGregorian(k.kYear, k.kMonth, lastDay).year;
    final yLabel = (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
    final month = (k.kMonth == 13) ? 'Heriu Renpet (ḥr.w rnpt)' : _MonthCard.monthNames[k.kMonth];
    return '$month ${k.kDay} • $yLabel';
  }

  bool _useKemetic = false;
  DateTime? _picked;

  Future<void> _pickDate() async {
    // local working state (so you can switch modes inside the sheet)
    bool localKemetic = _useKemetic;

    // ---- Gregorian seed (default = tomorrow) ----
    final now = DateUtils.dateOnly(DateTime.now());
    DateTime gSeed = _picked ?? (() {
      int y = now.year, m = now.month, d = now.day + 1;
      final maxD = DateUtils.getDaysInMonth(y, m);
      if (d > maxD) { d = 1; m = (m == 12) ? 1 : m + 1; if (m == 1) y++; }
      return DateTime(y, m, d);
    })();
    int gy = gSeed.year, gm = gSeed.month, gd = gSeed.day;

    // ---- Kemetic seed (use today's Kemetic by default) ----
    var kSeed = KemeticMath.fromGregorian(_picked ?? now.add(const Duration(days: 1)));
    int ky = kSeed.kYear, km = kSeed.kMonth, kd = kSeed.kDay;

    int _gregDayMax(int y, int m) => DateUtils.getDaysInMonth(y, m);
    int _kemDayMax(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    // controllers
    final int gYearStart = now.year; // show future-oriented years
    final gYearCtrl  = FixedExtentScrollController(initialItem: (gy - gYearStart).clamp(0, 399));
    final gMonthCtrl = FixedExtentScrollController(initialItem: (gm - 1).clamp(0, 11));
    final gDayCtrl   = FixedExtentScrollController(initialItem: (gd - 1).clamp(0, 30));

    final int kYearStart = ky; // centered on current Kemetic year
    final kYearCtrl  = FixedExtentScrollController(initialItem: (ky - kYearStart).clamp(0, 400));
    final kMonthCtrl = FixedExtentScrollController(initialItem: (km - 1).clamp(0, 12));
    final kDayCtrl   = FixedExtentScrollController(initialItem: (kd - 1).clamp(0, 29));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // clamp wheels when parents change
            final gMax = _gregDayMax(gy, gm);
            if (gd > gMax) gd = gMax;
            final kMax = _kemDayMax(ky, km);
            if (kd > kMax) kd = kMax;

            Widget _gregWheel() => SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: gMonthCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          gm = (i % 12) + 1;
                          final mx = _gregDayMax(gy, gm);
                          if (gd > mx && gDayCtrl.hasClients) {
                            gd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => gDayCtrl.jumpToItem(gd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(12, (i) {
                        return Center(
                          child: _GlossyText(
                            text: _gregMonthNames[i + 1],
                            style: const TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: gDayCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          final mx = _gregDayMax(gy, gm);
                          gd = (i % mx) + 1;
                        });
                      },
                      children: List.generate(_gregDayMax(gy, gm), (i) {
                        final dd = i + 1;
                        return Center(
                          child: _GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: gYearCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          gy = gYearStart + i;
                          final mx = _gregDayMax(gy, gm);
                          if (gd > mx && gDayCtrl.hasClients) {
                            gd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => gDayCtrl.jumpToItem(gd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(40, (i) {
                        final yy = gYearStart + i;
                        return Center(
                          child: _GlossyText(
                            text: '$yy',
                            style: const TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );

            Widget _kemWheel() => SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: kMonthCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          km = (i % 13) + 1;
                          final mx = _kemDayMax(ky, km);
                          if (kd > mx && kDayCtrl.hasClients) {
                            kd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => kDayCtrl.jumpToItem(kd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(13, (i) {
                        final m = i + 1;
                        return Center(
                          child: _GlossyText(
                            text: (m == 13) ? 'Heriu Renpet (ḥr.w rnpt)' : _MonthCard.monthNames[m],
                            style: const TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: kDayCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          final mx = _kemDayMax(ky, km);
                          kd = (i % mx) + 1;
                        });
                      },
                      children: List.generate(_kemDayMax(ky, km), (i) {
                        final dd = i + 1;
                        return Center(
                          child: _GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: kYearCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          ky = kYearStart + i;
                          final mx = _kemDayMax(ky, km);
                          if (kd > mx && kDayCtrl.hasClients) {
                            kd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => kDayCtrl.jumpToItem(kd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(401, (i) {
                        final y = kYearStart + i;
                        // Show Gregorian year label for the chosen Kemetic month
                        final last =
                        (km == 13) ? (KemeticMath.isLeapKemeticYear(y) ? 6 : 5) : 30;
                        final yStart = KemeticMath.toGregorian(y, km, 1).year;
                        final yEnd   = KemeticMath.toGregorian(y, km, last).year;
                        final label  = (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
                        return Center(
                          child: _GlossyText(
                            text: label,
                            style: const TextStyle(fontSize: 14),
                            gradient: _silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // mode toggle
                  CupertinoSegmentedControl<bool>(
                    groupValue: localKemetic,
                    padding: const EdgeInsets.all(2),
                    children: const {
                      true: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('Kemetic'),
                      ),
                      false: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('Gregorian'),
                      ),
                    },
                    onValueChanged: (v) {
                      setSheetState(() {
                        if (v) {
                          // Switching to Kemetic: convert current Gregorian wheels via KemeticMath
                          final gNow = DateTime(gy, gm, gd);
                          final k = KemeticMath.fromGregorian(gNow);
                          ky = k.kYear;
                          km = k.kMonth;
                          kd = k.kDay;
                          final kMax = _kemDayMax(ky, km);
                          if (kd > kMax) kd = kMax;
                          localKemetic = true;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            kYearCtrl.jumpToItem((ky - kYearStart).clamp(0, 400));
                            kMonthCtrl.jumpToItem((km - 1).clamp(0, 12));
                            kDayCtrl.jumpToItem((kd - 1).clamp(0, 29));
                          });
                        } else {
                          // Switching to Gregorian: convert current Kemetic wheels via KemeticMath
                          final g = KemeticMath.toGregorian(ky, km, kd);
                          gy = g.year;
                          gm = g.month;
                          gd = g.day;
                          final gMax = _gregDayMax(gy, gm);
                          if (gd > gMax) gd = gMax;
                          localKemetic = false;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            gYearCtrl.jumpToItem((gy - gYearStart).clamp(0, 39));
                            gMonthCtrl.jumpToItem((gm - 1).clamp(0, 11));
                            gDayCtrl.jumpToItem((gd - 1).clamp(0, 30));
                          });
                        }
                      });
                    },
                  ),





                  const SizedBox(height: 10),

                  // title
                  _GlossyText(
                    text: localKemetic ? 'Start date (Kemetic)' : 'Start date (Gregorian)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: localKemetic ? _goldGloss : _blueGloss,
                  ),
                  const SizedBox(height: 8),

                  // wheels
                  localKemetic ? _kemWheel() : _gregWheel(),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _silver),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: localKemetic ? _gold : _blue,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            // Build the chosen Gregorian day from whichever mode we're in
                            final DateTime chosen = localKemetic
                                ? KemeticMath.toGregorian(ky, km, kd)
                                : DateUtils.dateOnly(DateTime(gy, gm, gd));
                            setState(() {
                              _useKemetic = localKemetic;
                              _picked = chosen;
                            });
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('Use this date'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: Text(widget.template.title, style: const TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _GlossyText(
            text: widget.template.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            gradient: _goldGloss,
          ),
          const SizedBox(height: 8),
          Text(widget.template.overview,
              style: const TextStyle(color: Colors.white, height: 1.35)),
          const SizedBox(height: 16),
          const _GlossyText(
            text: '10-Day Outline',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: _silverGloss,
          ),
          const SizedBox(height: 8),
          ...List.generate(10, (i) {
            final d = widget.template.days[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.title, style: const TextStyle(color: Colors.white)),
                  if ((d.detail ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(d.detail!.trim(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          // Single CTA: opens a bottom sheet that contains the Kemetic/Gregorian toggle + wheels
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _silver),
                alignment: Alignment.centerLeft,
              ),
              onPressed: _pickDate,
              child: Text(
                _picked == null
                    ? 'Pick start date'
                    : (_useKemetic
                    ? 'Start: ${_kemeticLabelFor(_picked!)}'
                    : 'Start: ${_fmtGregorian(_picked!)}'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_picked != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _useKemetic ? 'Mode: Kemetic' : 'Mode: Gregorian',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),

          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _picked == null ? null : () {
              final id = widget.addInstance(
                template: widget.template,
                startDate: _picked!,
                useKemetic: _useKemetic,
              );
              Navigator.of(context).pop(id);
            },
            child: const Text('Add Flow'),
          ),
        ],
      ),
    );
  }
}




/* ───────────────────────── Search (notes) ───────────────────────── */

class _EventSearchDelegate extends SearchDelegate<void> {
  _EventSearchDelegate({
    required this.notes,
    required this.monthName,
    required this.gregYearLabelFor,
    required this.openDay,
  });

  final Map<String, List<_Note>> notes;
  final String Function(int kMonth) monthName;
  final String Function(int kYear, int kMonth) gregYearLabelFor;
  final void Function(int ky, int km, int kd) openDay;

  @override
  String get searchFieldLabel => 'Search notes…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        color: Color(0xFF111215),
        elevation: 0.5,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: _silver),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(primary: _gold, surface: _bg, onSurface: Colors.white),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Clear',
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  Iterable<({int ky, int km, int kd, _Note note})> _matches(String q) sync* {
    if (q.trim().isEmpty) return;
    final qq = q.toLowerCase();
    for (final entry in notes.entries) {
      final parts = entry.key.split('-'); // ky-km-kd
      if (parts.length != 3) continue;
      final ky = int.tryParse(parts[0]) ?? 0;
      final km = int.tryParse(parts[1]) ?? 0;
      final kd = int.tryParse(parts[2]) ?? 0;
      for (final n in entry.value) {
        bool hit(String? s) => (s ?? '').toLowerCase().contains(qq);
        if (hit(n.title) || hit(n.location) || hit(n.detail)) {
          yield (ky: ky, km: km, kd: kd, note: n);
        }
      }
    }
  }

  Widget _resultsList(String q) {
    final items = _matches(q).toList()
      ..sort((a, b) {
        final ga = KemeticMath.toGregorian(a.ky, a.km, a.kd);
        final gb = KemeticMath.toGregorian(b.ky, b.km, b.kd);
        return ga.compareTo(gb);
      });

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No matches found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (ctx, i) {
        final it = items[i];
        final g = KemeticMath.toGregorian(it.ky, it.km, it.kd);
        final gLabel =
            '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';
        final kmLabel = it.km == 13 ? 'Heriu Renpet (ḥr.w rnpt)' : monthName(it.km);

        final subBits = <String>[
          '$kmLabel ${it.kd}',
          gLabel,
          if (it.note.location != null && it.note.location!.isNotEmpty) it.note.location!,
        ];
        final subtitle = subBits.join(' • ');

        return SizedBox(
          width: double.infinity,
          child: ListTile(
            onTap: () => openDay(it.ky, it.km, it.kd),
            title: Text(it.note.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.chevron_right, color: _silver),
          ),
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => _resultsList(query);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Type to search your notes', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return _resultsList(query);
  }
}

/* ───────────────────────── Simple Note model ───────────────────────── */

class _Note {
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;

  /// which flow created this note (for Ma’at flow cleanup). null for normal notes.
  final int? flowId;

  const _Note({
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.start,
    this.end,
    this.flowId, // <— NEW
  });
}

// ========================================
// GOLD DIVIDER WIDGET
// ========================================

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),  // 16px above and below
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,  // 80% width, centered
          height: 1,  // Thin line
          color: _cardBorderGold,  // Gold color
        ),
      ),
    );
  }
}