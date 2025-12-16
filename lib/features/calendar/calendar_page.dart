import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/user_events_repo.dart';
import '../../data/flows_repo.dart';
import 'package:mobile/features/calendar/notify.dart';
import 'package:flutter/rendering.dart';
import '../../model/entities.dart';
import '../../data/note_category.dart';
import 'dart:io' show File, Directory;
import 'package:mobile/utils/color_bits.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'landscape_month_view.dart';
import 'dart:convert' as json;
import 'dart:convert';
import 'day_view.dart';
import '../profile/profile_page.dart';
import '../journal/journal_controller.dart';
import '../../core/ui_guards.dart';
import '../../main.dart' show routeObserver;
import '../../data/share_repo.dart';
import '../sharing/share_flow_sheet.dart';
import '../../data/share_models.dart';
import '../../widgets/inbox_icon_with_badge.dart';
import '../ai_generation/ai_flow_generation_modal.dart';
import '../../services/ai_flow_generation_service.dart';
import '../../models/ai_flow_generation_response.dart';
import '../../widgets/kemetic_day_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/widgets/month_name_text.dart';
import 'package:mobile/core/day_key.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../reminders/reminder_service.dart';
import '../reminders/reminder_model.dart';
import '../../data/reminders_repo.dart';
import '../../utils/event_cid_util.dart';
import 'package:share_plus/share_plus.dart';
import '../journal/journal_event_badge.dart';
import '../journal/journal_swipe_layer.dart';

typedef _QuickAddParse = ({
  DateTime date,
  bool allDay,
  TimeOfDay? start,
  TimeOfDay? end,
  String title,
});







/* ───────────────────── Premium Dark Theme + Gloss ───────────────────── */

const Color _bg = Colors.black; // True black
const Color _silver = Color(0xFFC8CCD2);

// Gregorian blue (high contrast on dark)
const Color _blue = Color(0xFF4DA3FF);
const Color _blueLight = Color(0xFFBFE0FF);
const Color _blueDeep = Color(0xFF0B64C0);

// Richer, deeper gold with visible gleam
const Color _gold = Color(0xFFD4AF37);
const Color _cardBorderGold = _gold;
const Color _goldLight = Color(0xFFE6C85A);  // Slightly brighter than base gold (for visible gleam)
const Color _goldMid = Color(0xFFD4AF37);     // Base gold as mid-tone
const Color _goldDeep = Color(0xFF9D7A1F);    // Much deeper shadow
const Color _silverLight = Color(0xFFF5F7FA);
const Color _silverDeep = Color(0xFF7A838C);

// Gradients are now imported from shared/glossy_text.dart

// Base text styles (color overridden to white inside gloss wrappers)
const TextStyle _titleGold =
TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _monthTitleGold =
TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _rightSmall =
TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white);
const TextStyle _seasonStyle =
TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _decanStyle =
TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white);
// Neutral on black — match day numbers / decan rows (no gradient, no glow)
const TextStyle _neutralOnBlack = TextStyle(
  fontSize: 12,                // match day-number size
  fontWeight: FontWeight.w400, // same as day numbers
  letterSpacing: 0.0,
  color: Colors.white,         // same color as the day numbers
);

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
Month 2 – Paopi (Mnḫt)
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

// GlossyText is now imported from shared/glossy_text.dart as GlossyText

// --- Month header rendering helper (crisp + glossy) ---
class _GlossyMonthNameText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const _GlossyMonthNameText({
    required this.text,
    required this.gradient,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final s = style ?? const TextStyle();
    final double fs = (s.fontSize ?? 20.0);
    final bool small = fs < 18.0;

    // White base for mask happens inside MonthNameText via color override here.
    final TextStyle masked = s.copyWith(
      color: const Color(0xFFFFFFFF),
      fontSize: fs.roundToDouble(),
      letterSpacing: 0,
      height: s.height,
      // keep caller's family; MonthNameText merges canonical stack
      fontFamily: s.fontFamily,
      fontFamilyFallback: s.fontFamilyFallback,
      // Gate shadows: small text + mask + shadows = mush
      shadows: small ? null : s.shadows,
    );

    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (Rect r) => gradient.createShader(r),
        blendMode: BlendMode.srcIn,
        child: MonthNameText(
          text,
          style: masked,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
        ),
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

// ============================================================================
// NUTRITION-TO-FLOW CONVERSION TYPES
// ============================================================================

/// Callback type for creating a flow from nutrition schedule data
typedef CreateFlowFromNutrition = Future<void> Function(FlowFromNutritionIntent intent);

/// Intent data for creating a flow from a nutrition item schedule
class FlowFromNutritionIntent {
  final String flowName;
  final int colorArgb;
  final DateTime startDate;
  final DateTime endDate;
  final String noteTitle;
  final String? noteDetails;
  final bool isWeekdayMode;
  final Set<int> weekdays; // 1-7 for weekdays (Mon=1, Sun=7)
  final Set<int> decanDays; // 1-10 for decan days
  final TimeOfDay timeOfDay;

  const FlowFromNutritionIntent({
    required this.flowName,
    required this.colorArgb,
    required this.startDate,
    required this.endDate,
    required this.noteTitle,
    this.noteDetails,
    required this.isWeekdayMode,
    required this.weekdays,
    required this.decanDays,
    required this.timeOfDay,
  });
}

/// Rules attach their own time window (all-day or start/end).
abstract class FlowRule {
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  const FlowRule({this.allDay = true, this.start, this.end});

  /// True if rule hits for the given Kemetic date and its Gregorian equivalent.
  bool matches({
    required int ky,
    required int km,
    required int kd,
    required DateTime g,
  });
}

/// Kemetic Decan rule.
class _RuleDecan extends FlowRule {
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
class _RuleKemeticMonth extends FlowRule {
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
class _RuleGregorianMonth extends FlowRule {
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
class _RuleWeek extends FlowRule {
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

// ============================================================================
// REPEATING NOTES - UI ENUMS
// ============================================================================

/// UI-level repeat options for individual notes.
enum NoteRepeatOption {
  never,
  everyDay,
  everyWeek,
  every2Weeks,
  everyMonth,
  everyYear,
  custom,
}

/// How the repeating series should end.
enum NoteRepeatEndType {
  never,
  onDate,
  afterCount,
}

/// Generic recurrence frequency to map into FlowRule.
enum SimpleRecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}

/// Explicit Gregorian dates rule (date-only). Used when customizing per decan/week.
class _RuleDates extends FlowRule {
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
  final List<FlowRule> rules;
  String? notes; // optional description
  String? shareId; // NEW: Track original share if imported from inbox
  bool isHidden; // Client-only flag for UI filtering (repeating notes)
  _Flow({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
    required this.rules,
    this.start,
    this.end,
    this.notes,
    this.shareId, // Optional: null for user-created flows
    this.isHidden = false, // Default to visible
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

class _CandidateEvent {
  final String clientEventId;
  final String title;
  final DateTime startsAtUtc;
  final DateTime? endsAtUtc;
  final String? detail;
  final String? location;
  final bool allDay;
  final int flowLocalId;
  const _CandidateEvent({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    this.endsAtUtc,
    this.detail,
    this.location,
    required this.allDay,
    required this.flowLocalId,
  });
}

/// Tiny helpers
Set<int> _fullRange(int from, int to) => {for (var i = from; i <= to; i++) i};
Set<int> _emptySet() => <int>{};

/* ───────────────────────── KEMETIC MATH ───────────────────────── */

class KemeticMath {
  // Epoch anchored to *local midnight*: Toth 1, Year 1 = 2025-03-20 (local).
  static final DateTime _epoch = kKemeticEpochUtc;  // UTC epoch from constants

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
    // FIXED: Normalize to UTC noon first to avoid DST gaps/ambiguities
    final gUtcNoon = DateTime.utc(gLocal.year, gLocal.month, gLocal.day, 12);
    final g = toUtcDateOnly(gUtcNoon);
    final diff = epochDayFromUtc(g);

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

    // FIXED: Use integer epoch-day arithmetic for clarity and robustness
    final base = _daysBeforeYear(kYear);
    final dayIndex =
        (kMonth == 13) ? (360 + (kDay - 1)) : ((kMonth - 1) * 30 + (kDay - 1));
    final epochDays = base + dayIndex;
    return utcFromEpochDay(epochDays);
  }

  static bool isLeapKemeticYear(int kYear) => _mod(kYear - 1, 4) == 2;

  /// Add months to a Kemetic date, handling year rollovers and epagomenal day clamping.
  static ({int kYear, int kMonth, int kDay}) addMonths({
    required int kYear,
    required int kMonth,
    required int kDay,
    required int monthsToAdd,
  }) {
    int newYear = kYear;
    int newMonth = kMonth + monthsToAdd;

    // Handle year overflow/underflow
    while (newMonth > 13) {
      newYear += (newMonth - 1) ~/ 13;
      newMonth = ((newMonth - 1) % 13) + 1;
    }
    while (newMonth < 1) {
      newYear -= ((1 - newMonth - 1) ~/ 13) + 1;
      newMonth = 13 - ((1 - newMonth - 1) % 13);
    }

    // Clamp day to valid range for target month
    int newDay = kDay;
    if (newMonth == 13) {
      final maxEpi = isLeapKemeticYear(newYear) ? 6 : 5;
      if (newDay > maxEpi) newDay = maxEpi;
    } else {
      if (newDay > 30) newDay = 30;
    }

    return (kYear: newYear, kMonth: newMonth, kDay: newDay);
  }
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
      GlossyText(text: title, style: _seasonStyle, gradient: goldGloss),
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

/// Medu Neter category.
const List<_MaatFlowTemplate> kMaatFlowTemplatesMeduNeter = [
  _MaatFlowTemplate(
    key: 'haw-ten-layers',
    title: 'ḥꜣw Series: Ten Layers of Time\'s Presence',
    overview:
        'A 10-day exploration of ḥꜣw—a Kemetic word that holds meanings of moment, lifetime, environment, and belongings. Each day pairs scholarship with a reflection practice.',
    color: Color(0xFF6AD19B), // greenish accent
    days: [
      _MaatFlowDay(
        title: 'Day 1 — The Kemetic Quantum: One Word, Many Worlds',
        detail:
            'Kemetic scribes worked in a worldview where language didn’t aim for a single, fixed definition. Instead, words carried layers. One root could express time, place, state, and relationship—because the world itself was understood as woven, not separate.\n\nThis is the quantum of ancient thought: that one symbol could radiate several truths at once. A falcon could mean sight, protection, kingship, horizon. A single hieroglyph could lean toward the Netjeru—the diverse expressions of divine order—or toward the rhythms of daily life.\n\nThe word ḥꜣw, written with the twisted-wick ḥ-sign, the vulture ꜣ, and the quail chick w, appears in inscriptions to mark a moment, a reign, a neighborhood, a circumstance. One word, many domains.\n\nPractice:\nChoose an everyday object—a cup, a door, a shadow—and write three meanings it could hold at once. Let your mind expand when you stop forcing one truth.',
      ),
      _MaatFlowDay(
        title: 'Day 2 — Djehuty: He Who Reckons Time',
        detail:
            'Among the Netjeru, Djehuty embodies measurement, writing, calculation, and renewal. Scribes invoked him as He Who Reckons Time, the one who keeps cycles aligned with the moon’s rhythm and the solar year.\n\nIn tombs such as Senenmut’s at Deir el-Bahri, astronomical ceilings show decans, lunar phases, and star tables—all realms where Djehuty’s influence was felt. He was not a distant figure but a principle of intelligent order, the inner mathematics of the cosmos.\n\nTo the scribes, timing was never merely mechanical—when you acted shaped what you became. Djehuty’s presence reminded them that a single skill could serve many roles: writing as creation, healing, connection, and harmonizing with Ma’at.\n\nPractice:\nName one talent you have. List three ways it functions in your life. Reflect on how one ability can carry many identities.',
      ),
      _MaatFlowDay(
        title: 'Day 3 — Time Worn as Masks: Deities of the Calendar',
        detail:
            'In Kemet, time moved through divine rhythms. Each month carried the name of a festival, many dedicated to the Netjeru: the Month of Tekh (associated with Djehuty), the Month of Pa-en-Ipet (linked to Opet rites), and others.\n\nTemple calendars at Dendera and Edfu inscribed these cycles, making the year a procession of sacred qualities. A month wasn’t an empty box of days—it was an invitation. Time itself wore masks, each guiding mood, labor, and ritual.\n\nRoyal records in Urkunden IV often date events by these months, embedding history within sacred rhythm.\n\nPractice:\nName your next seven days after qualities or Netjeru aspects. Journal how each name influences the way you meet your day.',
      ),
      _MaatFlowDay(
        title: 'Day 4 — ḥꜣw as Moment: The Instant That Anchors Events',
        detail:
            'One of the oldest meanings of ḥꜣw is the simple, potent “at the time of.” In inscriptions such as Urk. IV 969 and Cairo 20061, phrases like m-ḥꜣw mark the moment an event unfolds, or describe a reigning king as imi-ḥꜣw.f—“the one who is in his (appointed) time.”\n\nA moment in Kemet was not a neutral tick of a clock—it was a placement, a charged intersection of action and cosmic rhythm.\n\nPractice:\nPause once today and journal: What is the quality of this moment? What small action honors it?\n\nAttested Text (Urkunden IV 969 — Royal Annals):\nTransliteration:\nm-ḥꜣw nsw-bity ḫpr-kꜣ-Rꜥ …\nEnglish:\n“At the time of the King of Upper and Lower Egypt, Kheper-ka-Ra…”\nContext: Used to date events by the reigning king’s moment in time.\n\nAttested Text (Cairo CG 20061 — Royal Stela):\nTransliteration:\n… imi-ḥꜣw.f …\nEnglish:\n“… he who is in his (appointed) time.”\nContext: A title describing the king’s rightful presence within his destined moment.',
      ),
      _MaatFlowDay(
        title: 'Day 5 — ḥꜣw as Lifetime: The Arc of a Life',
        detail:
            'In texts like British Museum Papyrus BM 614, ḥꜣw refers to a lifetime—the full span of a person’s earthly journey. In royal inscriptions, it can mark the reign of a ruler, weaving personal epochs into cosmic cycles.\n\nLife was a bend in the Nile: carrying what came before, nourishing the present, flowing into what comes after.\n\nPractice:\nJournal your life as a river. Mark three major bends—turns that shaped who you are now.\n\nAttested Text (BM Papyrus 614, line 14 — Funerary Papyrus):\nTransliteration:\n… ḥꜣw n ḥm.t nṯr …\nEnglish:\n“… the lifetime of the divine woman …”\nContext: Refers to the full span of a woman’s earthly life.',
      ),
      _MaatFlowDay(
        title: 'Day 6 — ḥꜣw as Presence: Being in One’s Time',
        detail:
            'When ḥꜣw appears in duty rosters and autobiographies, it often means being in the right moment—present, aligned, in one’s ḥꜣw. Priests in Siut inscriptions are described this way: awake to their role, standing in the moment meant for them.\n\nPresence, in this view, is a sacred alignment—a way of tuning oneself to Ma’at.\n\nPractice:\nSit for one minute and journal what you notice when you give full attention to a single sense.\n\nAttested Text (Siut Tomb Inscriptions — Priest Duty Roster):\nTransliteration:\nḥm-kꜣ ḥr imi-ḥꜣw.f m pr-ḫrw …\nEnglish:\n“The ka-servant who is in his time in the offering-house…”\nContext: A priest performing his ritual duties in the correct, appointed moment.',
      ),
      _MaatFlowDay(
        title: 'Day 7 — ḥꜣw as Neighborhood: The Near Circle',
        detail:
            'ḥꜣw also describes the neighborhood—the lived surroundings shaping one’s relationships. Egyptians saw community as an extension of self; proximity formed obligation and meaning.\n\nIn the Peasant’s Tale, ḥꜣw appears in disputes over possessions and local ties. In geographic inscriptions, it marks vicinity or nearness.\n\nPractice:\nJournal the names of three people whose presence shapes your daily world. Reflect on what each brings into your “near circle.”\n\nAttested Text (Hammamat 114,8 — Expedition Inscription):\nTransliteration:\nwḏ mdw m-ḥꜣw-ḥr st …\nEnglish:\n“… issuing the order in front of the place …”\nContext: Uses the ḥꜣw-root to mark spatial relation (in front of / before).\n\nAttested Text (Lesko 98,21 — Ritual / Divine Movement):\nTransliteration:\njr nṯr pn m ḥꜣw.f …\nEnglish:\n“When this god is in his vicinity …”\nContext: Uses ḥꜣw to describe nearness or presence within one’s spatial circle.',
      ),
      _MaatFlowDay(
        title: 'Day 8 — ḥꜣw as Environment: The World That Holds You',
        detail:
            'From “neighborhood,” ḥꜣw naturally expands into environment—the broader setting in which a life unfolds. Egyptians mapped closeness, distance, and relation with subtlety, expressing nearness through this same root.\n\nEarthly environments mirrored cosmic ones; landscapes were reflections of order.\n\nPractice:\nLook around your current environment. Journal one detail that feels symbolic of your inner state.\n\nAttested Text (Urkunden IV 584 — Geographic Description):\nTransliteration:\nr-ḥꜣw …\nEnglish:\n“near.”\nContext: Used to describe the area near a landmark or spatial feature.',
      ),
      _MaatFlowDay(
        title: 'Day 9 — ḥꜣw as Belongings: The Objects That Travel With You',
        detail:
            'In the Eloquent Peasant, ḥꜣw describes belongings—the items that accompany a person’s identity, responsibilities, and fate. What one carries is part of one’s story.\n\nEgyptian texts often treat personal goods as extensions of the ka, the vital essence that travels with and through a person.\n\nPractice:\nChoose one object you keep close. Journal what story it holds for you.\n\nAttested Text (Eloquent Peasant B1,105 — Narrative Tale):\nTransliteration:\nẖr ḥꜣw.i r ḫrp.k …\nEnglish:\n“As for my belongings, they are under your authority…”\nContext: The peasant appeals for the protection of his property.\n\nAttested Text (Eloquent Peasant B1,135 — Narrative Tale):\nTransliteration:\njr wnn ḥꜣw pn …\nEnglish:\n“If this circumstance exists…”\nContext: Part of a logical argument describing conditions in a legal plea.',
      ),
      _MaatFlowDay(
        title: 'Day 10 — ḥꜣw as Affairs: The Interwoven Dance of Life Events',
        detail:
            'Finally, ḥꜣw appears as affairs, circumstances, matters—the web of unfolding situations in which one acts. Egyptians saw events as connected threads rather than isolated points.\n\nYour affairs, like your moments and belongings, are part of the weave of your life.\n\nPractice:\nReview your journal from this series. Identify one situation in your life where time, place, people, and objects all intersect. Write what wisdom appears when you see the whole pattern.\n\nAttested Text (Eloquent Peasant B1,262 — Narrative Tale):\nTransliteration:\njw ḥꜣw pn nfr n jryt …\nEnglish:\n“This affair is good to be done…”\nContext: Used to judge the goodness or propriety of an action within a larger situation.',
      ),
    ],
  ),
];

/* ─────────────────────────── CALENDAR PAGE (flows + notes) ─────────────────────────── */

GlobalKey keyForMonth(int ky, int km) => GlobalObjectKey('y${ky}m${km}');

class CalendarPage extends StatefulWidget {
  final int? initialFlowIdToEdit;
  
  const CalendarPage({
    super.key,
    this.initialFlowIdToEdit,
  });
  
  // Global key for accessing calendar state from other pages
  static final GlobalKey<_CalendarPageState> globalKey = GlobalKey<_CalendarPageState>();

  // Static method for parsing rules from JSON (used by inbox import)
  static FlowRule ruleFromJson(Map<String, dynamic> j) {
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

  // Headless persistence helper: save/delete flows + planned notes without calendar state.
  static Future<int?> persistFlowStudioResultHeadless(_FlowStudioResult r) async {
    final userEventsRepo = UserEventsRepo(Supabase.instance.client);
    final flowsRepo = FlowsRepo(Supabase.instance.client);

    // Deletes
    if (r.deleteFlowId != null) {
      await userEventsRepo.deleteByFlowId(r.deleteFlowId!);
      await userEventsRepo.deleteFlow(r.deleteFlowId!);
      return r.deleteFlowId;
    }

    // Saves
    if (r.savedFlow == null) return null;
    final f = r.savedFlow!;
    final rulesJson = jsonEncode(f.rules.map(_CalendarPageState.ruleToJson).toList());

    final savedId = await userEventsRepo.upsertFlow(
      id: f.id > 0 ? f.id : null,
      name: f.name,
      color: f.color.value,
      active: f.active,
      startDate: f.start,
      endDate: f.end,
      notes: f.notes,
      rules: rulesJson,
      isHidden: f.isHidden,
    );

    // Persist planned notes (with individual titles)
    if (r.plannedNotes.isNotEmpty) {
      for (final p in r.plannedNotes) {
        final n = p.note;
        final gDay = KemeticMath.toGregorian(p.ky, p.km, p.kd);
        final startsAt = DateTime(
          gDay.year,
          gDay.month,
          gDay.day,
          n.start?.hour ?? 9,
          n.start?.minute ?? 0,
        );
        DateTime? endsAt;
        if (!n.allDay && n.end != null) {
          endsAt = DateTime(gDay.year, gDay.month, gDay.day, n.end!.hour, n.end!.minute);
        } else if (!n.allDay) {
          endsAt = startsAt.add(const Duration(hours: 1));
        }

        final cid = EventCidUtil.buildClientEventId(
          ky: p.ky,
          km: p.km,
          kd: p.kd,
          title: n.title,
          startHour: n.start?.hour ?? 9,
          startMinute: n.start?.minute ?? 0,
          allDay: n.allDay,
          flowId: savedId,
        );

        await userEventsRepo.upsertByClientId(
          clientEventId: cid,
          title: n.title,
          startsAtUtc: startsAt.toUtc(),
          detail: (n.detail ?? '').trim().isEmpty ? null : n.detail,
          location: (n.location ?? '').trim().isEmpty ? null : n.location,
          allDay: n.allDay,
          endsAtUtc: endsAt?.toUtc(),
          flowLocalId: savedId,
        );
      }
    }

    return savedId;
  }

  static Future<int?> importFlowFromShare(BuildContext context, ImportFlowData data) async {
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
          builder: (_, __) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Material(
                color: Colors.black,
                child: Navigator(
                  onGenerateInitialRoutes: (nav, __) => [
                    MaterialPageRoute(
                      builder: (ctx) => _FlowStudioPage(
                        existingFlows: const [],
                        importData: data,
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

    if (result != null && result.savedFlow != null) {
      final state = CalendarPage.globalKey.currentState;
      if (state != null) {
        return await state._persistFlowStudioResult(result);
      } else {
        return await CalendarPage.persistFlowStudioResultHeadless(result);
      }
    }
    return null;
  }
  
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with WidgetsBindingObserver, RouteAware {

  // Track whether the clientEventId migration has been executed.
  // This ensures the migration runs at most once per app session to avoid
  // concurrent modification errors and repeated work.
  bool _ranMigration = false;

  // ⚠️ ONE-TIME CACHE CLEANUP FLAG
  // Set to true once to clear stale local cache, then set back to false
  // This should be removed after the cleanup runs successfully
  bool _runOneTimeCacheCleanup = false;

  int _dataVersion = 0;
  void _bumpDataVersion() {
    // why: force landscape PageView child to reconstruct once when data hydrates
    if (!mounted) return;
    setState(() => _dataVersion++);
  }

  // Build a reminder id that is unique per event occurrence and alert time.
  String _reminderIdForNote(_Note n, DateTime alertUtc) {
    final base = n.id ?? n.title;
    return '$base-${alertUtc.toIso8601String()}';
  }

  // UI still filters by end date even though repos do, because _flows is an
  // in-memory cache that can contain stale rows until the next sync. This keeps
  // ended flows out of visible lists.
  bool _isActiveByEndDate(DateTime? endDate) {
    if (endDate == null) return true;
    final endUtc = endDate.toUtc();
    final endDateOnly = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return !endDateOnly.isBefore(today);
  }

  // ✅ RouteObserver subscription tracking
  bool _isSubscribed = false;
  DateTime? _lastRefreshTime;

  /* ───── today + notes + flows state ───── */

  late final ({int kYear, int kMonth, int kDay}) _today =
  KemeticMath.fromGregorian(DateTime.now());

  final Map<String, List<_Note>> _notes = {};
  List<_Flow> _flows = [];
  int _nextFlowId = 1;
  // Removed _nextAlarmId; notifications are persisted via Notify.scheduleAlertWithPersistence
  final ScrollController _scrollCtrl = ScrollController();

  // Journal controller and state
  late JournalController _journalController;
  bool _journalInitialized = false;

  // Repository instances
  late final FlowsRepo _flowsRepo = FlowsRepo(Supabase.instance.client);
  // Reminders (Flutter-only layer)
  late final ReminderService _reminderService = ReminderService();
  StreamSubscription<List<Reminder>>? _reminderSub; // unused now (safety)
  bool _remindersLoaded = false;
  bool _remindersEnabled = false; // disable floating badges for now
  bool _settingsCatchUp = true;
  bool _settingsEndOfDay = true;
  bool _settingsMissedOnOpen = true;
  DateTime? _lastSummaryShownDay;
  late final RemindersRepo _remindersRepo = RemindersRepo(Supabase.instance.client);
  List<Reminder> _floatingReminders = [];
  bool _overlayActive = false;

  Future<void> _loadReminderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _settingsCatchUp = prefs.getBool('settings:catchUpReminders') ?? true;
        _settingsEndOfDay = prefs.getBool('settings:endOfDaySummary') ?? true;
        _settingsMissedOnOpen = prefs.getBool('settings:missedOnOpen') ?? true;
      });
    } catch (_) {}
  }

  /* ───── ClientEventId utilities ───── */
  /// Build a canonical clientEventId using the shared EventCidUtil (URL-encoded).
  /// Defaults start time to 9:00 when missing or all-day.
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
    final int sHour = (allDay || startHour == null) ? 9 : startHour;
    final int sMinute = (allDay || startMinute == null) ? 0 : startMinute;
    return EventCidUtil.buildClientEventId(
      ky: ky,
      km: km,
      kd: kd,
      title: title,
      startHour: sHour,
      startMinute: sMinute,
      allDay: allDay,
      flowId: flowId,
    );
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
  int? _lastViewKd;       // last viewed Kemetic day (1..30, or 1..5/6 for month 13)
  
  // Debug logging fields
  int _buildCount = 0; // Track how many times build() is called
  Orientation? _lastOrientation; // Track orientation changes
  
  // ✅ ADD: Preference keys for state persistence
  static const String _kPrefLastViewYear = 'calendar_last_view_ky';
  static const String _kPrefLastViewMonth = 'calendar_last_view_km';
  static const String _kPrefLastViewDay = 'calendar_last_view_kd';

  // ✅ ADD: Flag to prevent auto-scroll on orientation change
  bool _skipScrollToToday = false;

  // ✅ ADD: Feedback loop prevention flag
  bool _isUpdatingFromLandscape = false;
  bool _isUpdatingFromPortrait = false;
  
  // ✅ ADD: First-build gating flag to prevent race condition
  bool _restored = false;


// Find the month card whose vertical center is closest to the viewport center.
  void _updateCenteredMonth() {

    final candidates = <(int ky, int km, double dist)>[];
    
    // ✅ OPTIMIZED: Try saved/today month first (most likely mounted)
    final baseKy = _lastViewKy ?? _today.kYear;
    final baseKm = _lastViewKm ?? _today.kMonth;
    
    ScrollableState? scrollableState;
    RenderBox? viewportBox;
    
    // Try saved/today month first
    var ctx = keyForMonth(baseKy, baseKm).currentContext;
    if (ctx != null) {
      scrollableState = Scrollable.of(ctx);  // ✅ Use CHILD context!
      if (scrollableState != null) {
        final vpBox = scrollableState.context.findRenderObject() as RenderBox?;
        if (vpBox != null && vpBox.hasSize) {
          viewportBox = vpBox;
        }
      }
    }
    
    // Fallback: search nearby months if first attempt failed
    if (viewportBox == null) {
      for (var dY = -3; dY <= 3 && viewportBox == null; dY++) {
        final ky = baseKy + dY;
        for (var km = 1; km <= 13; km++) {
          ctx = keyForMonth(ky, km).currentContext;
          if (ctx == null) continue;
          scrollableState = Scrollable.of(ctx);
          if (scrollableState != null) {
            final vpBox = scrollableState.context.findRenderObject() as RenderBox?;
            if (vpBox != null && vpBox.hasSize) {
              viewportBox = vpBox;
              break;
            }
          }
        }
      }
    }
    
    if (scrollableState == null || viewportBox == null) return;
    
    // ✅ Viewport must be valid and laid out
    final position = scrollableState.position;
    if (!position.hasPixels || position.viewportDimension <= 0) return;
    
    // ✅ Calculate viewport center in global coordinates
    final viewportTopGlobal = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportCenterY = viewportTopGlobal + (viewportBox.size.height / 2);

    bool addIfMounted(int ky, int km) {
      final ctx = keyForMonth(ky, km).currentContext;
      if (ctx == null) return false;
      
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null || !rb.hasSize) return false;
      
      // ✅ CORRECT: size.center() exists and matches _centerMonth() pattern
      final monthCenterGlobal = rb.localToGlobal(rb.size.center(Offset.zero)).dy;
      
      final dist = (monthCenterGlobal - viewportCenterY).abs();
      candidates.add((ky, km, dist));
      return true;
    }

    // Search from saved state (already correct from v3)
    for (var dY = -3; dY <= 3; dY++) {
      final ky = baseKy + dY;
      for (var km = 1; km <= 13; km++) {
        addIfMounted(ky, km);
      }
    }
    
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    
    final newKy = candidates.first.$1;
    final newKm = candidates.first.$2;
    
    // ✅ ONLY UPDATE IF CHANGED AND NOT UPDATING FROM LANDSCAPE OR PORTRAIT
    if ((_lastViewKy != newKy || _lastViewKm != newKm) &&
        !_isUpdatingFromLandscape && !_isUpdatingFromPortrait) {
      
      // ✅ HARDENING 1: Clamp day when month changes
      final maxDay = _maxDayForMonth(newKy, newKm);
      final clampedKd = (_lastViewKd ?? 1).clamp(1, maxDay);
      
      _setView(newKy, newKm, kd: clampedKd);
    }
  }

  void _updateCenteredMonthWide() {
    // ✅ ONLY update if we don't already have a valid state
    // ✅ FIX 2: Removed _lastViewKy! >= 1 check - accept historical years
    if (_lastViewKy != null && _lastViewKm != null && 
        _lastViewKm! >= 1 && _lastViewKm! <= 13) {
      if (kDebugMode) {
        print('✓ [CALENDAR] Skipping _updateCenteredMonthWide - using existing state: $_lastViewKy-$_lastViewKm');
      }
      return;
    }
    
    final candidates = <(int ky, int km, double dist)>[];
    
    // ✅ OPTIMIZED: Try saved/today month first (most likely mounted)
    final base = _lastViewKy ?? _today.kYear;
    final baseMonth = _lastViewKm ?? _today.kMonth;
    
    ScrollableState? scrollableState;
    RenderBox? viewportBox;
    
    // Try saved/today month first
    var ctx = keyForMonth(base, baseMonth).currentContext;
    if (ctx != null) {
      scrollableState = Scrollable.of(ctx);  // ✅ Use CHILD context!
      if (scrollableState != null) {
        final vpBox = scrollableState.context.findRenderObject() as RenderBox?;
        if (vpBox != null && vpBox.hasSize) {
          viewportBox = vpBox;
        }
      }
    }
    
    // Fallback: search nearby months if first attempt failed
    if (viewportBox == null) {
      for (var dy = -220; dy <= 220; dy++) {
        final ky = base + dy;
        for (var km = 1; km <= 13; km++) {
          ctx = keyForMonth(ky, km).currentContext;
          if (ctx != null) {
            scrollableState = Scrollable.of(ctx);
            if (scrollableState != null) {
              final vpBox = scrollableState.context.findRenderObject() as RenderBox?;
              if (vpBox != null && vpBox.hasSize) {
                viewportBox = vpBox;
                break;
              }
            }
          }
        }
        if (viewportBox != null) break;
      }
    }
    
    if (scrollableState == null || viewportBox == null) return;
    
    // ✅ Calculate viewport center in global coordinates (SAME as _updateCenteredMonth)
    final viewportTopGlobal = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportCenterY = viewportTopGlobal + (viewportBox.size.height / 2);

    bool addIfMounted(int ky, int km) {
      final ctx = keyForMonth(ky, km).currentContext;
      if (ctx == null) return false;
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null || !rb.hasSize) return false;
      
      // ✅ CORRECT: Use same calculation as _centerMonth() and _updateCenteredMonth()
      final monthCenterGlobal = rb.localToGlobal(rb.size.center(Offset.zero)).dy;
      final dist = (monthCenterGlobal - viewportCenterY).abs();
      candidates.add((ky, km, dist));
      return true;
    }

    // Wider search for landscape (±220 years)
    for (var dy = -220; dy <= 220; dy++) {
      final ky = base + dy;
      var foundAny = false;
      for (var km = 1; km <= 13; km++) {
        foundAny = addIfMounted(ky, km) || foundAny;
      }
      if (foundAny && candidates.length >= 6) break;
    }

    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.$3.compareTo(b.$3));
    
    // ✅ Only update if not already set
    if (_lastViewKy == null || _lastViewKm == null) {
      final newKy = candidates.first.$1;
      final newKm = candidates.first.$2;
      final maxDay = _maxDayForMonth(newKy, newKm);
      final clampedKd = (_lastViewKd ?? 1).clamp(1, maxDay);
      
      _lastViewKy = newKy;
      _lastViewKm = newKm;
      _lastViewKd = clampedKd;
    }
  }

// Call on scroll to keep tracking the centered month.
  void _onVerticalScroll() {
    // ✅ Debounce to next frame to avoid stale RenderObjects
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCenteredMonth();
      }
    });
  }

  /// ✅ FIX 4: Compute centered month precisely using getOffsetToReveal
  (int, int) _computeCenteredMonthPrecisely() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return (_lastViewKy ?? _today.kYear, _lastViewKm ?? _today.kMonth);
    }

    final vp = RenderAbstractViewport.of(box);
    if (vp == null) {
      return (_lastViewKy ?? _today.kYear, _lastViewKm ?? _today.kMonth);
    }
    
    final viewportCenter = _scrollCtrl.offset + (box.size.height / 2);

    // Search ±2 years around last known position
    var bestKy = _lastViewKy ?? _today.kYear;
    var bestKm = _lastViewKm ?? _today.kMonth;
    double bestDist = double.infinity;

    for (int dy = -2; dy <= 2; dy++) {
      final baseKy = (_lastViewKy ?? _today.kYear) + dy;
      for (int km = 1; km <= 13; km++) {
        final ctx = keyForMonth(baseKy, km).currentContext;
        if (ctx == null) continue;
        
        final ro = ctx.findRenderObject();
        if (ro == null || ro is! RenderBox) continue;

        // ✅ Use getOffsetToReveal for precision
        final revealResult = vp.getOffsetToReveal(ro, 0.5);
        final revealOffset = revealResult.offset;
        final dist = (revealOffset - viewportCenter).abs();
        
        if (dist < bestDist) {
          bestDist = dist;
          bestKy = baseKy;
          bestKm = km;
        }
      }
    }
    
    return (bestKy, bestKm);
  }

  /// ✅ FIX 4: Handle month change from portrait scroll (with feedback loop guard)
  void _handlePortraitMonthChanged(int ky, int km) {
    if (_isUpdatingFromLandscape || _isUpdatingFromPortrait) return;
    
    _isUpdatingFromPortrait = true;
    try {
      final maxDay = _maxDayForMonth(ky, km);
      final clampedKd = (_lastViewKd ?? 1).clamp(1, maxDay);
      
      _setView(ky, km, kd: clampedKd);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [CALENDAR] Error in portrait month change: $e');
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdatingFromPortrait = false;
      });
    }
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
    WidgetsBinding.instance.addObserver(this);
    
    _loadReminderSettings();

    // Load local reminders cache and check any due on startup.
    _reminderService.load().then((_) {
      _remindersLoaded = true;
      _floatingReminders = [];
    });
    // We no longer listen to every change to avoid UI loops; checks happen on load/resume/refresh.
    
    // ✅ Load persisted state first, fallback to today
    _loadPersistedViewState();

    _scrollCtrl.addListener(_onVerticalScroll);

    // notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ✅ Only scroll to today if no persisted state
      if (!_skipScrollToToday) {
      _scrollToToday();
      }
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

    // Initialize journal controller
    _journalController = JournalController(Supabase.instance.client);
    _journalController.init().then((_) {
      if (mounted) {
        setState(() => _journalInitialized = true);
      }
    });
  }

  /// ✅ Load persisted view state from SharedPreferences
  Future<void> _loadPersistedViewState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKy = prefs.getInt(_kPrefLastViewYear);
      final savedKm = prefs.getInt(_kPrefLastViewMonth);
      final savedKd = prefs.getInt(_kPrefLastViewDay);
      
      // ✅ FIX 2: Allow years < 1 in saved state - support historical dates
      if (savedKy != null && savedKm != null && savedKm >= 1 && savedKm <= 13) {
        final today = KemeticMath.fromGregorian(DateTime.now());
        
        if (savedKy > today.kYear + 2) {
          if (kDebugMode) {
            print('⚠️ [CALENDAR] Future persisted date $savedKy/$savedKm — defaulting to today');
          }
          _setView(today.kYear, today.kMonth, kd: today.kDay);
          _restored = true;
          return;
        }

        // Restore valid saved state
        final maxDay = _maxDayForMonth(savedKy, savedKm);
        final clamped = (savedKd != null && savedKd >= 1 && savedKd <= maxDay) ? savedKd : 1;
        
        if (kDebugMode) {
          print('📂 [CALENDAR] Restored $savedKy/$savedKm/$clamped');
        }
        
        setState(() {
          _lastViewKy = savedKy;
          _lastViewKm = savedKm;
          _lastViewKd = clamped;
          _skipScrollToToday = true;
          _restored = true;
        });
      } else {
        if (kDebugMode) {
          print('📂 [CALENDAR] No persisted state — defaulting to today');
        }
        _setView(_today.kYear, _today.kMonth, kd: _today.kDay);
        _restored = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [CALENDAR] Persist load error — defaulting to today: $e');
      }
      _setView(_today.kYear, _today.kMonth, kd: _today.kDay);
      _restored = true;
    }
  }

  /// ✅ Helper: Calculate max days in a Kemetic month
  int _maxDayForMonth(int ky, int km) {
    if (km == 13) {
      return KemeticMath.isLeapKemeticYear(ky) ? 6 : 5;
    }
    return 30;
  }

  /// ✅ Central writer for view state - single source of truth
  void _setView(int ky, int km, {int? kd}) {
    if (_lastViewKy == ky && _lastViewKm == km && (kd == null || _lastViewKd == kd)) return;
    
    _lastViewKy = ky;
    _lastViewKm = km;
    if (kd != null) _lastViewKd = kd;
    
    _saveViewState(ky, km, kd); // existing signature
    setState(() {}); // keep headers/UI in sync
  }

  /// ✅ Save view state to SharedPreferences
  Future<void> _saveViewState(int ky, int km, [int? kd]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefLastViewYear, ky);
      await prefs.setInt(_kPrefLastViewMonth, km);
      // ✅ HARDENING 1: Save day if provided, otherwise keep existing or use 1
      final dayToSave = kd ?? _lastViewKd ?? 1;
      // Clamp day to valid range before saving
      final maxDay = _maxDayForMonth(ky, km);
      final clampedDay = dayToSave.clamp(1, maxDay);
      await prefs.setInt(_kPrefLastViewDay, clampedDay);
      
      if (kDebugMode) {
        print('💾 [CALENDAR] Saved view state: Year $ky, Month $km, Day $clampedDay');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [CALENDAR] Error saving view state: $e');
      }
    }
  }

  /// ✅ Handle month change from landscape view (WITH CORRECT FEEDBACK LOOP GUARD TIMING)
  void _handleLandscapeMonthChanged(int ky, int km) {
    // ✅ PREVENT FEEDBACK LOOP: Don't update if we're already updating
    if (_isUpdatingFromLandscape) {
      if (kDebugMode) {
        print('🔄 [CALENDAR] Ignoring landscape update (already updating)');
      }
      return;
    }
    
    if (kDebugMode) {
      print('🔄 [CALENDAR] Landscape month changed: Year $ky, Month $km');
    }
    
    // ✅ SET FLAG: Prevent portrait from triggering landscape update
    _isUpdatingFromLandscape = true;
    
    // ✅ FIX 5: Exception-safe callback handling
    try {
      // ✅ HARDENING 1: Clamp day when month changes, or use today's day if month matches today
      final maxDay = _maxDayForMonth(ky, km);
      int clampedKd;
      
      // If this is today's month, use today's day; otherwise clamp existing day
      if (ky == _today.kYear && km == _today.kMonth) {
        clampedKd = _today.kDay.clamp(1, maxDay);
      } else {
        clampedKd = (_lastViewKd ?? 1).clamp(1, maxDay);
      }
      
      _setView(ky, km, kd: clampedKd);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [CALENDAR] Error in landscape month change: $e');
      }
    } finally {
      // ✅ CLEAR FLAG AFTER FRAME: This ensures portrait's scroll listener can see the flag
      // Using post-frame callback prevents the flag from clearing before portrait processes the update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdatingFromLandscape = false;
      });
    }
  }

  @override
  void dispose() {
    // ✅ Unsubscribe from RouteObserver
    if (_isSubscribed) {
      routeObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _reminderSub?.cancel();
    _reminderService.dispose();
    debugPrint('');
    debugPrint('🗑️  _CalendarPageState DISPOSING');
    debugPrint('   Total builds: $_buildCount');
    debugPrint('');
    _journalController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ✅ Called when we pop back to Calendar from another page
  @override
  void didPopNext() {
    _refreshAfterReturn();
  }

  // ✅ Fallback: app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastRefreshTime == null ||
          now.difference(_lastRefreshTime!) > const Duration(seconds: 2)) {
        _refreshAfterReturn();
      }
      _checkDueReminders();
    }
  }

  // ✅ Refresh when returning to this page
  Future<void> _refreshAfterReturn() async {
    if (!mounted) return;

    // Small delay to make sure any DB writes (like imports) are done
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    try {
      await _loadFromDisk(); // reuse your existing loader
      _lastRefreshTime = DateTime.now();
      if (mounted) setState(() {});
      _checkDueReminders();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CalendarPage] Error refreshing: $e');
      }
    }
  }

  Future<void> _checkDueReminders() async {
    if (!_remindersEnabled) return;
    if (!_remindersLoaded || !mounted) return;
    if (!_settingsCatchUp && !_settingsMissedOnOpen && !_settingsEndOfDay) return;
    try {
      final nowUtc = DateTime.now().toUtc();
      // Use local cache only for now to avoid id mismatches causing reappearing chips
      List<Reminder> due = _reminderService.dueReminders(nowUtc);
      if (due.isEmpty) {
        if (_floatingReminders.isNotEmpty && mounted) {
          setState(() => _floatingReminders = []);
        }
        return;
      }

      // Mark as shown locally so they stop re-queuing
      for (final r in due) {
        _reminderService.markStatus(r.id, ReminderStatus.shownInApp);
      }

      // De-dupe and update overlay
      final seen = <String>{};
      // Cap to at most 5 to avoid UI overload
      setState(() {
        _floatingReminders = [
          for (final r in due)
            if (seen.add(r.id)) r,
        ].take(5).toList();
        _overlayActive = _floatingReminders.isNotEmpty;
      });

      // End-of-day summary trigger (local only): after 9pm local, show once per day
      await _maybeShowEndOfDaySummary(due);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reminders] _checkDueReminders failed: $e');
      }
    }
  }

  void _showReminderSheet(List<Reminder> due) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF000000),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reminders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...due.map((r) {
                  final local = r.alertAtUtc.toLocal();
                  final timeStr =
                      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      timeStr +
                          (r.detail != null && r.detail!.isNotEmpty
                              ? ' • ${r.detail}'
                              : ''),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        _reminderService.markStatus(
                            r.id, ReminderStatus.completed);
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Color(0xFFD4AF37)),
                      ),
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFD4AF37)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _maybeShowEndOfDaySummary(List<Reminder> dueAll) async {
    if (!_settingsEndOfDay) return;
    final now = DateTime.now();
    final localDate = DateUtils.dateOnly(now);
    if (now.hour < 21) return; // after 9pm local
    if (_lastSummaryShownDay != null &&
        DateUtils.isSameDay(_lastSummaryShownDay, localDate)) {
      return;
    }

    List<Reminder> dueToday = dueAll.where((r) {
      final local = r.alertAtUtc.toLocal();
      return DateUtils.isSameDay(local, localDate) &&
          r.status != ReminderStatus.completed;
    }).toList();

    if (dueToday.isEmpty) {
      _lastSummaryShownDay = localDate;
      return;
    }

    _lastSummaryShownDay = localDate;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF000000),
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s reminders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...dueToday.map((r) {
                  final local = r.alertAtUtc.toLocal();
                  final timeStr =
                      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: r.status == ReminderStatus.completed,
                    onChanged: (_) {
                      _completeReminder(r, addToJournal: false);
                    },
                    title: Text(
                      r.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      timeStr +
                          (r.detail != null && r.detail!.isNotEmpty
                              ? ' • ${r.detail}'
                              : ''),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    activeColor: const Color(0xFFD4AF37),
                    checkColor: Colors.black,
                  );
                }),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFD4AF37)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReminderOverlays() {
    return const SizedBox.shrink();
  }

  Future<void> _completeReminder(Reminder r, {bool addToJournal = true}) async {
    try {
      _reminderService.markStatus(r.id, ReminderStatus.completed);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Reminder] completeReminder failed: $e');
      }
    }
    if (mounted) {
      setState(() {
        _floatingReminders.removeWhere((x) => x.id == r.id);
        _overlayActive = _floatingReminders.isNotEmpty;
      });
    }
  }
  
  // ✅ Rotation reconcile: re-center on last view after rotation settles
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final orientation = MediaQuery.orientationOf(context);
      final ky = _lastViewKy ?? _today.kYear;
      final km = _lastViewKm ?? _today.kMonth;
      
      if (orientation == Orientation.portrait) {
        _centerMonth(ky, km); // your existing helper
      }
      // Landscape rebuild pulls initialKy/Km from _lastView* in build()
    });
  }

  /* ───── helpers ───── */

  String _kKey(int ky, int km, int kd) => '$ky-$km-$kd';

  /// Get flow colors for a given day (for month grid dots).
  /// Derives colors from notes in _notes, not from recomputed flow occurrences.
  List<Color> getFlowColorsForDay(int kYear, int kMonth, int kDay) {
    final notes = _getNotes(kYear, kMonth, kDay);
    final flowIds = notes
        .where((n) => n.flowId != null && n.flowId != -1)
        .map((n) => n.flowId!)
        .toSet();

    final colors = <Color>[];
    for (final fid in flowIds) {
      try {
        final flow = _flows.firstWhere((f) => f.id == fid);
        if (!colors.contains(flow.color)) {
          colors.add(flow.color);
          if (colors.length == 3) break; // Cap to 3 colors
        }
      } catch (_) {
        // Flow not found, skip
      }
    }
    return colors;
  }

  /// Get flow colors for a given day using a notes getter function.
  /// Used by stateless widgets that can't access instance methods.
  List<Color> getFlowColorsForDayFromNotes(
    int kYear,
    int kMonth,
    int kDay,
    List<_Note> Function(int kMonth, int kDay) notesGetter,
  ) {
    final notes = notesGetter(kMonth, kDay);
    final flowIds = notes
        .where((n) => n.flowId != null && n.flowId != -1)
        .map((n) => n.flowId!)
        .toSet();

    final colors = <Color>[];
    for (final fid in flowIds) {
      try {
        final flow = _flows.firstWhere((f) => f.id == fid);
        if (!colors.contains(flow.color)) {
          colors.add(flow.color);
          if (colors.length == 3) break; // Cap to 3 colors
        }
      } catch (_) {
        // Flow not found, skip
      }
    }
    return colors;
  }

  List<_Note> _getNotes(int kYear, int kMonth, int kDay) {
    final key = _kKey(kYear, kMonth, kDay);
    if (kDebugMode) {
      debugPrint('🔎 Day view requesting notes for key: "$key" (ky=$kYear km=$kMonth kd=$kDay)');
    }
    final result = _notes[key] ?? const [];
    if (kDebugMode) {
      debugPrint('🔎 Found ${result.length} notes for this key');
      if (result.isNotEmpty) {
        debugPrint('🔎 Titles: ${result.map((n) => n.title).join(", ")}');
      }
    }
    if (result.isNotEmpty && !kDebugMode) {
      // Keep original print for non-debug builds
      print('_getNotes($kYear, $kMonth, $kDay) returning ${result.length} notes: ${result.map((n) => n.title).join(", ")}');
    }
    return result;
  }

  /// Flow occurrences that apply to a given Kemetic date (computed on demand).
  List<_FlowOccurrence> _getFlowOccurrences(int kYear, int kMonth, int kDay) {
    final g = KemeticMath.toGregorian(kYear, kMonth, kDay);
    final gDate = DateUtils.dateOnly(g);
    final out = <_FlowOccurrence>[];
    for (final f in _flows) {
      if (!f.active) continue;
      if (f.isHidden) continue; // repeating notes should NOT appear as flows
      final start = f.start != null ? DateUtils.dateOnly(f.start!) : null;
      final end = f.end != null ? DateUtils.dateOnly(f.end!) : null;
      if (start != null && gDate.isBefore(start)) continue;
      if (end != null && gDate.isAfter(end)) continue;
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
        int? flowId,
        Color? manualColor,
        String? category,
      }) {
    final k = _kKey(kYear, kMonth, kDay);
    final list = _notes.putIfAbsent(k, () => <_Note>[]);
    list.add(_Note(
      id: null,
      title: title.trim(),
      detail: detail?.trim(),
      location: (location == null || location.trim().isEmpty)
          ? null
          : location.trim(),
      allDay: allDay,
      start: allDay ? null : start,
      end: allDay ? null : end,
      flowId: flowId,
      manualColor: manualColor,
      category: category,
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

  int? _findNoteIndexByEvent(int ky, int km, int kd, EventItem evt) {
    final key = _kKey(ky, km, kd);
    final list = _notes[key];
    if (list == null) return null;

    int startHour = evt.startMin ~/ 60;
    int startMinute = evt.startMin % 60;
    int endHour = evt.endMin ~/ 60;
    int endMinute = evt.endMin % 60;

    for (int i = 0; i < list.length; i++) {
      final n = list[i];
      if ((n.flowId ?? -1) != -1) continue; // only standalone notes
      if (n.allDay != evt.allDay) continue;
      if (!evt.allDay) {
        if (n.start == null ||
            n.start!.hour != startHour ||
            n.start!.minute != startMinute) continue;
        if (n.end != null &&
            (n.end!.hour != endHour || n.end!.minute != endMinute)) continue;
      }
      final titlesMatch =
          n.title.trim().toLowerCase() == evt.title.trim().toLowerCase();
      final locMatch =
          (n.location ?? '').trim().toLowerCase() == (evt.location ?? '').trim().toLowerCase();
      final detMatch =
          (n.detail ?? '').trim().toLowerCase() == (evt.detail ?? '').trim().toLowerCase();
      if (titlesMatch && locMatch && detMatch) {
        return i;
      }
    }
    return null;
  }

  void _deleteNoteByEvent(int ky, int km, int kd, EventItem evt) {
    final idx = _findNoteIndexByEvent(ky, km, kd, evt);
    if (idx != null) {
      _deleteNote(ky, km, kd, idx);
    }
  }

  Future<void> _editNoteByEvent(int ky, int km, int kd, EventItem evt) async {
    final idx = _findNoteIndexByEvent(ky, km, kd, evt);
    if (idx == null) return;
    final key = _kKey(ky, km, kd);
    final note = _notes[key]![idx];

    await Future<void>.delayed(Duration.zero, () {
      _openDaySheet(
        ky,
        km,
        kd,
        allowDateChange: false,
        initialTitle: note.title,
        initialLocation: note.location,
        initialDetail: note.detail,
        initialAllDay: note.allDay,
        initialStartTime: note.start,
        initialEndTime: note.end,
        initialColor: note.manualColor,
        initialCategory: note.category,
        editingIndex: idx,
      );
    });
  }

  Future<void> _shareNoteSimple(EventItem evt) async {
    String _fmtTime(int mins) {
      final h = mins ~/ 60;
      final m = mins % 60;
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:${m.toString().padLeft(2, '0')} $period';
    }

    final buffer = StringBuffer();
    buffer.writeln(evt.title);
    buffer.writeln('${_fmtTime(evt.startMin)} – ${_fmtTime(evt.endMin)}');
    if (evt.detail != null && evt.detail!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(evt.detail!.trim());
    }
    if (evt.location != null && evt.location!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Location: ${evt.location!.trim()}');
    }

    // Open the same sharing UI as flows, but in note mode.
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareFlowSheet(
        flowId: null,
        flowTitle: evt.title,
        noteShareText: buffer.toString().trim(),
        eventId: evt.id,
      ),
    );
  }
  final Map<int, int> _flowLocalIdAliases = {}; // ⬅︎ unique: alias map for serverId→localId

  // Flows — add/remove/toggle
  // >>> FIND-ME: PATCH-2 _saveNewFlow AFTER
  Future<int> _saveNewFlow(_Flow flow) async {
    final localId = _nextFlowId++;
    flow.id = localId;
    _flows.add(flow);
    if (mounted) setState(() {});

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
        isHidden: flow.isHidden,
      );

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
      return savedId;
    } catch (e) {
      debugPrint('Flow save failed: $e');
      // Keep local id on failure; caller will still attach notes to local
      return localId;
    }
  }




  void _rekeyNotesFlowId(int fromId, int toId) {
    // Collect all notes that need database updates
    final List<({int ky, int km, int kd, _Note note})> notesToPersist = [];
    
    // Walk the in-memory notes map and change any note.flowId == fromId to toId
    _notes.updateAll((key, list) {
      return list.map((n) {
        if ((n.flowId ?? -1) == fromId) {
          final updatedNote = _Note(
            id: n.id,
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
            final String? det = item.note.detail;
            final String detailPayload = det?.trim() ?? '';
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
            isHidden: f.isHidden,
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

      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('[deleteFlow] ✗ Failed to delete flow $flowId: $e');
          debugPrint('[deleteFlow] Stack trace: $stackTrace');
        }
        // Resync local state to match server (restores flow if delete failed)
        await _loadFromDisk();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete flow. Please try again.'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _deleteFlow(flowId),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
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
      getMonthById(kMonth).displayFull;

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
    UiGuards.disableJournalSwipe();
    showSearch(
      context: context,
      delegate: _EventSearchDelegate(
        notes: _notes,
        monthName: (km) => getMonthById(km).displayFull,
        gregYearLabelFor: _gregYearLabelFor,
        openDay: (ky, km, kd) {
          Navigator.of(context).pop(); // dismiss search
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openDaySheet(ky, km, kd);
          });
        },
      ),
    ).then((_) {
      UiGuards.enableJournalSwipe();
    });
  }

  /* ───── Flow Studio ───── */

  // Centralize applying Flow Studio results to calendar state
  Future<void> _applyFlowStudioResult(_FlowStudioResult edited) async {
    int? finalFlowId; // <-- NEW: ensure we know the actual flow id to tag notes
    bool notesAlreadyPersisted = false; // When true, skip duplicate planned-note persistence

    if (edited.deleteFlowId != null) {
      _deleteFlow(edited.deleteFlowId!);
    } else if (edited.savedFlow != null) {
      final f = edited.savedFlow!;
      final editFlowId = f.id >= 0 ? f.id : null;
      if (editFlowId != null) {
        // ✅ FIX: Persist to database when editing existing flow
        await _persistFlowStudioResult(edited);
        finalFlowId = editFlowId;
        notesAlreadyPersisted = true; // plannedNotes handled inside _persistFlowStudioResult
      } else {
        finalFlowId = await _saveNewFlow(f); // await save and get server ID
      }
    }

    // Only handle plannedNotes here when we didn't already persist them via _persistFlowStudioResult
    if (!notesAlreadyPersisted && edited.plannedNotes.isNotEmpty) {
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
          category: n.category,
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
            id: n.id,
            title: n.title,
            detail: n.detail,
            location: n.location,
            allDay: n.allDay,
            start: n.start,
            end: n.end,
            flowId: noteFlowId,
            manualColor: n.manualColor,
            category: n.category,
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
          final String? det = persisted.detail;
          final String detailPayload = det?.trim() ?? '';
          
          // 🔍 DIAGNOSTIC LOGGING: Before upsert
          print('🔍 ABOUT TO UPSERT:');
          print('   noteFlowId=$noteFlowId');
          print('   n.flowId=${n.flowId}');
          print('   finalFlowId=$finalFlowId');
          print('   cid=$cid');
          
          await repo2.upsertByClientId(
            clientEventId: cid,
            title: persisted.title,
            startsAtUtc: startsAt.toUtc(),
            detail: detailPayload.isEmpty ? null : detailPayload,
            location: (persisted.location ?? '').trim().isEmpty ? null : persisted.location!.trim(),
            allDay: persisted.allDay,
            endsAtUtc: endsAt?.toUtc(),
            flowLocalId: noteFlowId >= 0 ? noteFlowId : null, // ✅ FIX: Set flow_local_id for Flow Studio saves
            category: persisted.category,
          );
          
          // 🔍 DIAGNOSTIC LOGGING: After upsert - verify database
          print('🔍 AFTER UPSERT - checking database...');
          try {
            final verify = await Supabase.instance.client
                .from('user_events')
                .select('flow_local_id, title, starts_at')
                .eq('client_event_id', cid)
                .maybeSingle();
            print('🔍 DB shows: flow_local_id=${verify?['flow_local_id']}, title=${verify?['title']}, starts_at=${verify?['starts_at']}');
          } catch (e) {
            print('🔍 Verification query failed: $e');
          }
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
    UiGuards.disableJournalSwipe();
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
                color: Colors.black,
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
    
    UiGuards.enableJournalSwipe();
  }


  // Directly open My Flows list (no Flow Hub chooser).
  void _openMyFlowsList({int? initialFlowId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Navigator(
              onGenerateInitialRoutes: (nav, __) {
                return [
                  MaterialPageRoute(
                    builder: (ctx2) {
                      // If a flowId was provided, push editor after first frame.
                      if (initialFlowId != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          nav.push(
                            MaterialPageRoute(
                              builder: (_) => _FlowStudioPage(
                                existingFlows: _flows,
                                editFlowId: initialFlowId,
                              ),
                            ),
                          );
                        });
                      }

                      return _FlowsViewerPage(
                        flows: _flows,
                        fmtGregorian: (d) => d == null
                            ? '--'
                            : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                        onCreateNew: () async {
                          final edited = await nav.push<_FlowStudioResult>(
                            MaterialPageRoute(
                              builder: (_) => _FlowStudioPage(
                                existingFlows: _flows,
                              ),
                            ),
                          );
                          if (edited != null) await _persistFlowStudioResult(edited);
                          await _loadFromDisk();
                        },
                        onEditFlow: (id) async {
                          final edited = await nav.push<_FlowStudioResult>(
                            MaterialPageRoute(
                              builder: (_) => _FlowStudioPage(
                                existingFlows: _flows,
                                editFlowId: id,
                              ),
                            ),
                          );
                          if (edited != null) await _persistFlowStudioResult(edited);
                          await _loadFromDisk();
                        },
                        openMaatFlows: () {
                          nav.push(
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
                                        }) async {
                                          final id = await _addMaatFlowInstance(
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
                                  final edited = await nav.push<_FlowStudioResult>(
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
                        onImportFlow: (importedFlowId) async {
                          if (importedFlowId != null) {
                            await _loadFromDisk();
                          }
                        },
                        onAppendToJournal: _journalInitialized
                            ? (text) => _journalController.appendToToday(text)
                            : null,
                      );
                    },
                  ),
                ];
              },
            ),
          ),
        );
      },
    );
  }

  // Manage Flows callback: jump straight to My Flows (or specific flow editor if id provided).
  void Function(int? flowId) _getMyFlowsCallback() {
    return (int? flowId) {
      if (flowId != null) {
        // Open the existing Flow editor directly when a flowId is provided.
        _openFlowEditorDirectly(flowId);
        return;
      }
      _openMyFlowsList();
    };
  }

  // Flow Studio callback that opens the Flow Hub (same as main calendar)
  void Function(int? flowId) _getFlowStudioCallback() {
    return (int? flowId) {
      // If flowId provided, go directly to that flow
      if (flowId != null) {
        _openFlowEditorDirectly(flowId);
        return;
      }
      
      // Otherwise open Flow Hub as before
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
                      // ✅ Refresh calendar data after flow operations
                      await _loadFromDisk();
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
                      // ✅ Refresh calendar data after flow operations
                      await _loadFromDisk();
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
                                    }) async {
                                      final id = await _addMaatFlowInstance(
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
                    onImportFlow: (importedFlowId) async {
                      if (importedFlowId != null) {
                        await _loadFromDisk();
                      }
                    },
                    onAppendToJournal: _journalInitialized
                        ? (text) => _journalController.appendToToday(text)
                        : null,
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
    };
  }

  void _openFlowEditorDirectly(int flowId) {
    _openFlowStudioSheet(
      rootBuilder: (innerCtx) {
        return _FlowStudioPage(
          // Force DB load for full fidelity (rules/notes) when editing.
          existingFlows: const [],
          editFlowId: flowId,
        );
      },
    );
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
            // ✅ Refresh calendar data after flow operations
            await _loadFromDisk();
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
            // ✅ Refresh calendar data after flow operations
            await _loadFromDisk();
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
          onImportFlow: (importedFlowId) async {
            if (importedFlowId != null) {
              await _loadFromDisk();
            }
          },
          onAppendToJournal: _journalInitialized
              ? (text) => _journalController.appendToToday(text)
              : null,
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


  /// Create a user-owned *instance* from a Ma'at template starting on [startDate].
  /// - [useKemetic]: true to interpret [startDate] as Kemetic (kY/kM/kD); false = Gregorian.
  /// - Produces a new _Flow with explicit dates (10 days) and adds 10 notes linked to the flowId.
  /// - Returns the created flow's id.
  Future<int> _addMaatFlowInstance({
    required _MaatFlowTemplate template,
    required DateTime startDate,
    required bool useKemetic,
  }) async {
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

    final serverFlowId = await _saveNewFlow(flow); // await save and get server ID

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
        flowId: serverFlowId,
      );
      // sync each auto-created flow day to Supabase (fire-and-forget)
      Future.microtask(() async {
        try {
          final repo = UserEventsRepo(Supabase.instance.client);
          final scheduledAt = DateTime(g.year, g.month, g.day, 9, 0);
          // Use unified clientEventId for Ma'at flows as well. The note uses
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
            flowId: serverFlowId,
          );
          await repo.upsertByClientId(
            clientEventId: cid,
            title: day.title,
            startsAtUtc: scheduledAt.toUtc(),
            detail: (day.detail ?? '').trim().isEmpty ? null : day.detail!.trim(),
            location: null,
            allDay: false,
            endsAtUtc: DateTime(g.year, g.month, g.day, 10, 0).toUtc(),
            flowLocalId: serverFlowId, // ✅ attach to the flow you just created
          );
        } catch (_) {}
      });


      dayIndex++;
    }
    setState(() {});
    return serverFlowId;
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
        isHidden: f.isHidden, // Preserve hidden status
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
          isHidden: f.isHidden,
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
    // Adapter: Convert _Note to NoteData, and prime reminders for the day
    final notesForDayFn = (int y, int m, int d) {
      final key = '$y-$m-$d';
      final notes = _notes[key] ?? [];

      // Create/update local reminders for timed events on this day (Flutter-only)
      for (final n in notes) {
        if (n.allDay || n.start == null) continue;
        final alertLocal = DateTime(
          y,
          m,
          d,
          n.start!.hour,
          n.start!.minute,
        );
        final alertUtc = alertLocal.toUtc();
        final rid = _reminderIdForNote(n, alertUtc);
        _reminderService.addOrUpdate(
          Reminder(
            id: rid,
            eventId: n.id?.toString(),
            title: n.title,
            detail: n.detail,
            alertAtUtc: alertUtc,
            flowId: n.flowId?.toString(),
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

      }

      return notes.map((n) => NoteData(
        id: n.id?.toString(),
        title: n.title,
        detail: n.detail,
        location: n.location,
        allDay: n.allDay,
        start: n.start,
        end: n.end,
        flowId: n.flowId,
        manualColor: n.manualColor,
        category: n.category,
      )).toList();
    };

    // Adapter: Convert _Flow to FlowData
    final flowIndex = <int, FlowData>{};
    for (final f in _flows.where((f) => f.active && !f.isHidden && _isActiveByEndDate(f.end))) {
      flowIndex[f.id] = FlowData(
        id: f.id,
        name: f.name,
        color: f.color,
        active: f.active,
      );
    }

    // Get month name function
    final getMonthName = (int km) => getMonthById(km).displayFull;

    // Navigate to Day View
    UiGuards.disableJournalSwipe();
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
          onManageFlows: (flowId) => _getMyFlowsCallback()(flowId),
          onOpenFlowStudio: () => _getFlowStudioCallback()(null),
          onDeleteNote: (ky, km, kd, evt) async {
            _deleteNoteByEvent(ky, km, kd, evt);
          },
          onEditNote: (ky, km, kd, evt) async {
            await _editNoteByEvent(ky, km, kd, evt);
          },
          onShareNote: (evt) async {
            await _shareNoteSimple(evt);
          },
          onAddNote: (ky, km, kd) => _openDaySheet(ky, km, kd, allowDateChange: true),
          onOpenAddNoteWithTime: (ky, km, kd, {TimeOfDay? start, TimeOfDay? end, bool allDay = false}) {
            _openDaySheet(
              ky,
              km,
              kd,
              allowDateChange: true,
              initialStartTime: start,
              initialEndTime: end,
              initialAllDay: allDay,
            );
          },
          onCreateTimedEvent: _handleCreateTimedEvent,
          onEndFlow: (id) => _endFlow(id),
          onAppendToJournal: (text) async {
            if (_journalInitialized) {
              await _journalController.appendToToday(text);
            }
          },
        ),
      ),
    ).then((_) {
      // ✅ Save state when returning from day view
      if (mounted) {
        final ky = _lastViewKy ?? kYear;
        final km = _lastViewKm ?? kMonth;
        final kd = _lastViewKd ?? kDay;
        _saveViewState(ky, km, kd);
        
        if (kDebugMode) {
          print('💾 [CALENDAR] Saved state on day view close: $ky-$km-$kd');
        }
      }
      UiGuards.enableJournalSwipe();
    });
  }

  /* ───── Day Sheet ───── */

  Future<void> _handleCreateTimedEvent(
    int ky,
    int km,
    int kd, {
    required String title,
    String? detail,
    String? location,
    required TimeOfDay start,
    required TimeOfDay end,
    bool allDay = false,
  }) async {
    await _saveSingleNoteOnly(
      selYear: ky,
      selMonth: km,
      selDay: kd,
      title: title,
      detail: detail,
      location: location,
      allDay: allDay,
      startTime: allDay ? null : start,
      endTime: allDay ? null : end,
      color: null,
    );
  }

  void _openDaySheet(
      int kYear,
      int kMonth,
      int kDay, {
        bool allowDateChange = false,
        TimeOfDay? initialStartTime,
        TimeOfDay? initialEndTime,
        bool initialAllDay = false,
        String? initialTitle,
        String? initialLocation,
        String? initialDetail,
        Color? initialColor,
        String? initialCategory,
        int? editingIndex,
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

    final controllerTitle = TextEditingController(text: initialTitle ?? '');
    final controllerLocation = TextEditingController(text: initialLocation ?? '');
    final controllerDetail = TextEditingController(text: initialDetail ?? '');

    bool allDay = initialAllDay;
    TimeOfDay? startTime = initialStartTime ?? const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay? endTime = initialEndTime ?? const TimeOfDay(hour: 13, minute: 0);
    String? selectedCategory = initialCategory;
    
    // Repeat state
    NoteRepeatOption repeatOption = NoteRepeatOption.never;
    NoteRepeatEndType endType = NoteRepeatEndType.never;
    SimpleRecurrenceFrequency customFrequency = SimpleRecurrenceFrequency.daily;
    int customInterval = 1;
    DateTime? endDate;
    int endCount = 10;
    
    // Color state – index into _flowPalette
    int selectedColorIndex = initialColor != null
        ? _flowPalette.indexWhere((c) => c.value == initialColor.value)
        : 0;
    if (selectedColorIndex < 0) selectedColorIndex = 0;

    try {
      debugPrint('🚀 Attempting to show modal bottom sheet...');
      UiGuards.disableJournalSwipe();
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
                              final label = getMonthById(m).displayFull;
                              return Center(
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                                child: GlossyText(
                                  text: '$d',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                          child: GlossyText(
                            text: 'Scheduled flows',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            gradient: silverGloss,
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
                                        GlossyText(
                                          text: occ.flow.name,
                                          style: const TextStyle(fontSize: 14),
                                          gradient: silverGloss,
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
                            label: const GlossyText(
                              text: 'Manage flows',
                              style: TextStyle(fontSize: 14),
                              gradient: silverGloss,
                            ),
                          ),
                        ),
                        const Divider(height: 16, color: Colors.white12),
                      ],

                      // Existing notes
                      if ((_dataVersion > 0) && dayNotes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: GlossyText(
                            text: 'No notes yet',
                            style: TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
                                        GlossyText(
                                          text: n.title,
                                          style: const TextStyle(fontSize: 16),
                                          gradient: silverGloss,
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
                        child: GlossyText(
                          text: 'Add note',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          gradient: silverGloss,
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

                      const SizedBox(height: 12),
                      Text(
                        'Category (optional)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ) ??
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cat in NoteCategory.all)
                            ChoiceChip(
                              label: Text(cat),
                              selected: selectedCategory == cat,
                              onSelected: (_) => setSheetState(() {
                                selectedCategory = cat;
                              }),
                              selectedColor: const Color(0xFFD4AF37).withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: selectedCategory == cat ? const Color(0xFFD4AF37) : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: const Color(0xFF1A1A1A),
                              side: BorderSide(
                                color: selectedCategory == cat ? const Color(0xFFD4AF37) : Colors.white24,
                              ),
                            ),
                          ActionChip(
                            label: const Text('Clear', style: TextStyle(color: Colors.white)),
                            avatar: const Icon(Icons.close, size: 18, color: Colors.white70),
                            onPressed: selectedCategory == null
                                ? null
                                : () => setSheetState(() => selectedCategory = null),
                            backgroundColor: const Color(0xFF1A1A1A),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: allDay,
                        onChanged: (v) => setSheetState(() => allDay = v),
                        title: const GlossyText(
                          text: 'All-day',
                          style: TextStyle(fontSize: 14),
                          gradient: silverGloss,
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
                      
                      // Repeat row
                      InkWell(
                        onTap: () async {
                          final result = await showCupertinoModalPopup<NoteRepeatOption>(
                            context: sheetCtx,
                            builder: (_) {
                              return CupertinoActionSheet(
                                title: const GlossyText(
                                  text: 'Repeat',
                                  gradient: silverGloss,
                                  style: TextStyle(fontSize: 18),
                                ),
                                actions: [
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatOption.never),
                                    child: const GlossyText(
                                      text: 'Never',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatOption.everyDay),
                                    child: const GlossyText(
                                      text: 'Every Day',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatOption.everyWeek),
                                    child: const GlossyText(
                                      text: 'Every Week',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatOption.every2Weeks),
                                    child: const GlossyText(
                                      text: 'Every 2 Weeks',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatOption.everyMonth),
                                    child: const GlossyText(
                                      text: 'Every Month',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatOption.everyYear),
                                    child: const GlossyText(
                                      text: 'Every Year',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () async {
                                      Navigator.pop(sheetCtx);
                                      final customResult = await Navigator.of(context).push<Map<String, dynamic>>(
                                        MaterialPageRoute(
                                          builder: (_) => _CustomRepeatPage(
                                            initialFrequency: customFrequency,
                                            initialInterval: customInterval,
                                          ),
                                        ),
                                      );
                                      if (customResult != null) {
                                        setSheetState(() {
                                          repeatOption = NoteRepeatOption.custom;
                                          customFrequency = customResult['frequency'] as SimpleRecurrenceFrequency;
                                          customInterval = customResult['interval'] as int;
                                        });
                                      }
                                    },
                                    child: const GlossyText(
                                      text: 'Custom…',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                ],
                                cancelButton: CupertinoActionSheetAction(
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  child: const Text('Cancel'),
                                ),
                              );
                            },
                          );
                          if (result != null) {
                            setSheetState(() {
                              repeatOption = result;
                              if (result == NoteRepeatOption.never) {
                                endType = NoteRepeatEndType.never;
                                endDate = null;
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const GlossyText(
                                text: 'Repeat',
                                gradient: silverGloss,
                                style: TextStyle(fontSize: 14),
                              ),
                              Row(
                                children: [
                                  GlossyText(
                                    text: _repeatOptionLabel(repeatOption, customFrequency, customInterval),
                                    gradient: goldGloss,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // End Repeat row
                      InkWell(
                        onTap: repeatOption == NoteRepeatOption.never ? null : () async {
                          final result = await showCupertinoModalPopup<NoteRepeatEndType>(
                            context: sheetCtx,
                            builder: (_) {
                              return CupertinoActionSheet(
                                title: const GlossyText(
                                  text: 'End Repeat',
                                  gradient: silverGloss,
                                  style: TextStyle(fontSize: 18),
                                ),
                                actions: [
                                  CupertinoActionSheetAction(
                                    onPressed: () => Navigator.pop(sheetCtx, NoteRepeatEndType.never),
                                    child: const GlossyText(
                                      text: 'Never',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  CupertinoActionSheetAction(
                                    onPressed: () async {
                                      Navigator.pop(sheetCtx);
                                      final gDay = KemeticMath.toGregorian(selYear, selMonth, selDay);
                                      final picked = await pickDateUniversal(
                                        context: context,
                                        initialDate: endDate ?? gDay.add(const Duration(days: 30)),
                                        allowPast: false,
                                        firstDate: gDay,
                                        lastDate: gDay.add(const Duration(days: 365 * 10)),
                                      );
                                      if (picked != null) {
                                        setSheetState(() {
                                          endType = NoteRepeatEndType.onDate;
                                          endDate = picked;
                                        });
                                      }
                                    },
                                    child: const GlossyText(
                                      text: 'On Date…',
                                      gradient: goldGloss,
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                ],
                                cancelButton: CupertinoActionSheetAction(
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  child: const Text('Cancel'),
                                ),
                              );
                            },
                          );
                          if (result != null) {
                            setSheetState(() {
                              endType = result;
                              if (result == NoteRepeatEndType.never) {
                                endDate = null;
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GlossyText(
                                text: 'End Repeat',
                                gradient: repeatOption == NoteRepeatOption.never ? silverGloss : silverGloss,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: repeatOption == NoteRepeatOption.never ? Colors.white54 : Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  if (repeatOption != NoteRepeatOption.never)
                                    GlossyText(
                                      text: _endRepeatLabel(endType, endDate, endCount),
                                      gradient: goldGloss,
                                      style: const TextStyle(fontSize: 14),
                                    )
                                  else
                                    const Text(
                                      'Never',
                                      style: TextStyle(fontSize: 14, color: Colors.white54),
                                    ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: repeatOption == NoteRepeatOption.never ? Colors.white24 : Colors.white54,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      
                      // COLOR PICKER – same look as Flow Studio
                      const GlossyText(
                        text: 'Color',
                        gradient: silverGloss,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _flowPalette.length,
                          itemBuilder: (_, i) {
                            final selected = i == selectedColorIndex;
                            final color = _flowPalette[i];

                            return InkWell(
                              onTap: () => setSheetState(() {
                                selectedColorIndex = i;
                              }),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 30,
                                height: 30,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _glossFromColor(color),
                                  border: Border.all(
                                    color: selected ? _gold : Colors.white24,
                                    width: selected ? 2.0 : 1.0,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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

                            // Validate end time is after start time
                            if (!allDay && startTime != null && endTime != null) {
                              if (_toMinutes(endTime!) <= _toMinutes(startTime!)) {
                                endTime = _addMinutes(startTime!, 60);
                              }
                            }

                            final bool isRepeating = repeatOption != NoteRepeatOption.never;
                            
                          final selectedColor = _flowPalette[selectedColorIndex];
                          
                          try {
                            // If editing an existing note, remove the old one first.
                            if (editingIndex != null) {
                              _deleteNote(selYear, selMonth, selDay, editingIndex!);
                            }

                            if (!isRepeating) {
                              // Single note
                              await _saveSingleNoteOnly(
                                selYear: selYear,
                                selMonth: selMonth,
                                  selDay: selDay,
                                  title: t,
                                  detail: d.isEmpty ? null : d,
                                  location: loc.isEmpty ? null : loc,
                                  allDay: allDay,
                                  startTime: startTime,
                                  endTime: endTime,
                                  color: selectedColor,
                                  category: selectedCategory,
                                );
                              } else {
                                // Repeating note - create hidden flow
                                await _saveRepeatingNoteAsHiddenFlow(
                                  selYear: selYear,
                                  selMonth: selMonth,
                                  selDay: selDay,
                                  title: t,
                                  detail: d.isEmpty ? null : d,
                                  location: loc.isEmpty ? null : loc,
                                  allDay: allDay,
                                  startTime: startTime,
                                  endTime: endTime,
                                  repeatOption: repeatOption,
                                  customFrequency: customFrequency,
                                  customInterval: customInterval,
                                  endType: endType,
                                  endDate: endDate,
                                  endCount: endCount,
                                  color: selectedColor,
                                  category: selectedCategory,
                                );
                              }
                            } catch (e, stackTrace) {
                              if (kDebugMode) {
                                debugPrint('[SaveNote] Error saving note: $e');
                                debugPrint('[SaveNote] Stack trace: $stackTrace');
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save note: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                              return; // Don't close sheet on error
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
    ).then((_) {
      UiGuards.enableJournalSwipe();
    });
    
    debugPrint('✅ Modal bottom sheet opened successfully');
    
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ ERROR OPENING DAY SHEET');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('');
      UiGuards.enableJournalSwipe(); // Re-enable even on error
    }
  }

  /* ───── Natural language quick add ───── */

  DateTime _nextWeekday(DateTime base, int weekday) {
    final delta = (weekday - base.weekday + 7) % 7;
    final add = delta == 0 ? 7 : delta;
    return DateUtils.dateOnly(base.add(Duration(days: add)));
  }

  _QuickAddParse? _parseQuickAdd(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final now = DateTime.now();
    DateTime date = DateUtils.dateOnly(now);
    bool hasDate = false;
    final lower = input.toLowerCase();
    final removals = <String>[];

    // Explicit mm/dd(/yy) or m/d
    final mmdd = RegExp(r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?').firstMatch(lower);
    if (mmdd != null) {
      int m = int.parse(mmdd.group(1)!);
      int d = int.parse(mmdd.group(2)!);
      int y = mmdd.group(3) != null ? int.parse(mmdd.group(3)!) : now.year;
      if (y < 100) y += 2000;
      date = DateUtils.dateOnly(DateTime(y, m, d));
      hasDate = true;
      removals.add(mmdd.group(0)!);
    } else {
      // Month name
      final months = {
        'jan': 1, 'january': 1,
        'feb': 2, 'february': 2,
        'mar': 3, 'march': 3,
        'apr': 4, 'april': 4,
        'may': 5,
        'jun': 6, 'june': 6,
        'jul': 7, 'july': 7,
        'aug': 8, 'august': 8,
        'sep': 9, 'sept': 9, 'september': 9,
        'oct': 10, 'october': 10,
        'nov': 11, 'november': 11,
        'dec': 12, 'december': 12,
      };
      final monthMatch = RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+(\d{1,2})(?:,\s*(\d{2,4}))?')
          .firstMatch(lower);
      if (monthMatch != null) {
        final m = months[monthMatch.group(1)!]!;
        final d = int.parse(monthMatch.group(2)!);
        int y = monthMatch.group(3) != null ? int.parse(monthMatch.group(3)!) : now.year;
        if (y < 100) y += 2000;
        date = DateUtils.dateOnly(DateTime(y, m, d));
        hasDate = true;
        removals.add(monthMatch.group(0)!);
      }
    }

    // Relative terms
    if (!hasDate) {
      if (lower.contains('today')) {
        date = DateUtils.dateOnly(now);
        hasDate = true;
        removals.add('today');
      } else if (lower.contains('tomorrow')) {
        date = DateUtils.dateOnly(now.add(const Duration(days: 1)));
        hasDate = true;
        removals.add('tomorrow');
      }

      final inDays = RegExp(r'in\s+(\d+)\s+day').firstMatch(lower);
      if (!hasDate && inDays != null) {
        final n = int.parse(inDays.group(1)!);
        date = DateUtils.dateOnly(now.add(Duration(days: n)));
        hasDate = true;
        removals.add(inDays.group(0)!);
      }

      // Weekday names
      if (!hasDate) {
        final weekdays = {
          'mon': DateTime.monday,
          'tue': DateTime.tuesday,
          'tues': DateTime.tuesday,
          'wed': DateTime.wednesday,
          'thu': DateTime.thursday,
          'thur': DateTime.thursday,
          'thurs': DateTime.thursday,
          'fri': DateTime.friday,
          'sat': DateTime.saturday,
          'sun': DateTime.sunday,
        };
        final wdMatch = RegExp(r'(next\s+)?(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)')
            .firstMatch(lower);
        if (wdMatch != null) {
          final wd = weekdays[wdMatch.group(2)!]!;
          date = _nextWeekday(now, wd);
          hasDate = true;
          removals.add(wdMatch.group(0)!);
        }
      }
    }

    // If explicit date is in the past, roll to next year
    if (hasDate && date.isBefore(DateUtils.dateOnly(now))) {
      date = DateUtils.dateOnly(DateTime(date.year + 1, date.month, date.day));
    }

    // Time parsing
    TimeOfDay? start;
    TimeOfDay? end;
    bool allDay = true;

    int toHour(int h, String? ap) {
      if (ap == null) return h;
      final l = ap.toLowerCase();
      if (l == 'am') {
        return h == 12 ? 0 : h;
      } else {
        return h == 12 ? 12 : h + 12;
      }
    }

    final range = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|–|to)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (range != null) {
      final h1 = int.parse(range.group(1)!);
      final m1 = range.group(2) != null ? int.parse(range.group(2)!) : 0;
      final ap1 = range.group(3);
      final h2 = int.parse(range.group(4)!);
      final m2 = range.group(5) != null ? int.parse(range.group(5)!) : 0;
      final ap2 = range.group(6);
      start = TimeOfDay(hour: toHour(h1, ap1), minute: m1);
      end = TimeOfDay(hour: toHour(h2, ap2 ?? ap1), minute: m2);
      allDay = false;
      removals.add(range.group(0)!);
    } else {
      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false)
          .firstMatch(lower);
      if (timeMatch != null) {
        final h = int.parse(timeMatch.group(1)!);
        final m = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
        final ap = timeMatch.group(3);
        start = TimeOfDay(hour: toHour(h, ap), minute: m);
        end = TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);
        allDay = false;
        removals.add(timeMatch.group(0)!);
      }
    }

    final title = () {
      var t = input;
      for (final r in removals) {
        t = t.replaceFirst(RegExp(RegExp.escape(r), caseSensitive: false), '');
      }
      t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.isEmpty ? input : t;
    }();

    return (
      date: date,
      allDay: allDay,
      start: start,
      end: end,
      title: title,
    );
  }

  Future<void> _openQuickAddSheet() async {
    final textCtrl = TextEditingController();
    String? error;
    final focusNode = FocusNode();
    final fieldKey = GlobalKey();
    final scrollCtrl = ScrollController();
    bool scheduledFocus = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                // Request focus and ensure visibility once after layout/keyboard settle
                if (!scheduledFocus) {
                  scheduledFocus = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    focusNode.requestFocus();
                    await Future.delayed(const Duration(milliseconds: 50));
                    if (fieldKey.currentContext != null) {
                      Scrollable.ensureVisible(
                        fieldKey.currentContext!,
                        alignment: 0.1,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }

                return SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick add (natural language)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: fieldKey,
                        controller: textCtrl,
                        autofocus: false,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g., “Fri 3pm-4pm coffee with Amara”',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF111111),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(error!, style: const TextStyle(color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () async {
                                final parsed = _parseQuickAdd(textCtrl.text);
                                if (parsed == null) {
                                  setSheetState(() {
                                    error = 'Please enter a description.';
                                  });
                                  return;
                                }
                                final k = KemeticMath.fromGregorian(parsed.date);
                                await _saveSingleNoteOnly(
                                  selYear: k.kYear,
                                  selMonth: k.kMonth,
                                  selDay: k.kDay,
                                  title: parsed.title,
                                  detail: null,
                                  location: null,
                                  allDay: parsed.allDay,
                                  startTime: parsed.allDay ? null : parsed.start,
                                  endTime: parsed.allDay ? null : parsed.end,
                                  color: null,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added "${parsed.title}"'),
                                      backgroundColor: const Color(0xFF1E1E1E),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Quick add'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _openDaySheet(
                                _today.kYear,
                                _today.kMonth,
                                _today.kDay,
                                allowDateChange: true,
                              );
                            },
                            child: const Text(
                              'Open full editor',
                              style: TextStyle(color: Color(0xFFD4AF37)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    focusNode.dispose();
  }


  /* ───── UI ───── */
  bool _initOnce = false;

  /// ⚠️ ONE-TIME CACHE CLEANUP
  /// Clears stale Supabase storage and SharedPreferences cache
  /// Run once to remove "Alkaline Lunch" ghosts and ensure only true Supabase data shows
  /// Remove this method after successful cleanup
  Future<void> _performOneTimeCacheCleanup() async {
    if (kDebugMode) {
      debugPrint('🧹 [CACHE CLEANUP] Starting one-time cleanup...');
    }

    try {
      // Clear SharedPreferences (manual cache)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (kDebugMode) {
        debugPrint('🧹 [CACHE CLEANUP] Cleared SharedPreferences');
      }

      // Sign out to force fresh session (this will also clear Supabase session cache)
      await Supabase.instance.client.auth.signOut();
      if (kDebugMode) {
        debugPrint('🧹 [CACHE CLEANUP] Signed out (app will need to re-login)');
      }

      if (kDebugMode) {
        debugPrint('✅ [CACHE CLEANUP] Cleanup complete - restart app to see fresh data');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [CACHE CLEANUP] Error during cleanup: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // ✅ Subscribe to RouteObserver FIRST (before _initOnce check)
    final route = ModalRoute.of(context);
    if (route is PageRoute && !_isSubscribed) {
      routeObserver.subscribe(this, route);
      _isSubscribed = true;
    }
    
    // ✅ PRESERVE existing _initOnce logic
    if (!_initOnce) {
      _initOnce = true;
      
      // ⚠️ ONE-TIME CACHE CLEANUP
      // Set _runOneTimeCacheCleanup = true to clear stale cache, then set back to false
      if (_runOneTimeCacheCleanup) {
        _performOneTimeCacheCleanup().then((_) {
          // After cleanup, user needs to restart app to re-login
          if (kDebugMode) {
            debugPrint('⚠️ [CACHE CLEANUP] App will need restart after sign-out');
          }
        });
        return; // Don't load data yet - wait for restart
      }
      
      // 1) First load everything from disk
      _loadFromDisk().then((_) {
        // 2) After flows are loaded, if we have an initial flow to edit, open it
        if (mounted && widget.initialFlowIdToEdit != null) {
          _openFlowEditorDirectly(widget.initialFlowIdToEdit!);
        }
      });
    } else if (widget.initialFlowIdToEdit != null) {
      // Already initialized (flows loaded), but widget has an initial flow id
      // e.g., if CalendarPage got rebuilt with a different target flow
      _openFlowEditorDirectly(widget.initialFlowIdToEdit!);
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
        final repMeta = _decodeRepeatingNoteMetadata(f.notes);
        final derivedHidden = f.isHidden ||
            repMeta.detail != null ||
            repMeta.location != null ||
            repMeta.category != null;
        final flow = _Flow(
          id: f.id,
          name: f.name,
          color: Color(rgbToArgb(f.color)),
          active: f.active,
          rules: _parseRules(f.rules),
          start: f.startDate,
          end: f.endDate,
          notes: f.notes,
          shareId: f.shareId, // NEW: Load share_id
          isHidden: derivedHidden,
        );
        _flows.add(flow);
        // 🔍 DEBUG: Log what color came from database for ALL custom flows
        // Log flows with ID greater than 156 to catch all user-created flows
        if (kDebugMode && f.id > 156) {
          debugPrint('[loadFlows] Flow ${f.id} "${f.name}" loaded with color=${f.color} (0x${f.color.toRadixString(16)})');
        }
        if (flow.id >= _nextFlowId) _nextFlowId = flow.id + 1;
      }

      // Build index/maps for later use
      final Map<int, _Flow> flowIndex = {
        for (final f in _flows) f.id: f,
      };

      // We'll only hydrate events for flows that are still active AND visible.
      final activeFlowIds = _flows
          .where((f) => f.active && !f.isHidden && _isActiveByEndDate(f.end))
          .map((f) => f.id)
          .toSet(); // 👈 Set for O(1) contains() lookups

      int addedCount = 0;

      for (final flowId in activeFlowIds) {
        try {
          // 🔥 NEW: pull ALL events for this specific flow from DB,
          // even if they're past the pagination horizon
          final flowEvents = await repo.getEventsForFlow(flowId);

          for (final evt in flowEvents) {
            // Convert DB UTC timestamps -> device local -> Kemetic date
            final localStart = evt.startsAtUtc.toLocal();

            final kDate = KemeticMath.fromGregorian(localStart);

            // Build _Note, same shape the rest of the app expects
            // 👈 SAFETY NET: Skip events for flows that don't exist or are inactive
            final owningFlow = flowIndex[flowId];
            final flowVisible = owningFlow != null &&
                owningFlow.active &&
                !owningFlow.isHidden &&
                _isActiveByEndDate(owningFlow.end);
            if (!flowVisible) {
              // skip events that belong to deleted / inactive / hidden / expired flows
              continue;
            }

            final note = _Note(
              title: evt.title,
              detail: _cleanDetail(evt.detail), // Clean the flowLocalId prefix
              location: evt.location,
              allDay: evt.allDay,
              start: evt.allDay
                  ? null
                  : TimeOfDay.fromDateTime(localStart),
              end: evt.endsAtUtc == null
                  ? null
                  : TimeOfDay.fromDateTime(evt.endsAtUtc!.toLocal()),
              flowId: flowId,
              category: evt.category,
            );

            final key = _kKey(kDate.kYear, kDate.kMonth, kDate.kDay);
            final bucket = _notes.putIfAbsent(key, () => <_Note>[]);

            // Dedup (title + start time match) so we don't spam UI
          final already = bucket.any((n) =>
              n.flowId == note.flowId &&
              n.start?.hour == note.start?.hour &&
              n.start?.minute == note.start?.minute);

            if (!already) {
              bucket.add(note);
              addedCount++;
            }
          }
        } catch (err, st) {
          if (kDebugMode) {
            debugPrint(
                '[loadFromDisk] failed to hydrate events for flow $flowId: $err');
            debugPrint('$st');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('[_loadFromDisk] notes joined/added via per-flow hydration: $addedCount');
      }

      // Load standalone events (single notes with flow_local_id = null)
      // 🚫 HARD GUARDS prevent old/zombie flow events from loading
      try {
        final allEvents = await repo.getAllEvents(limit: 2000);

        for (final evt in allEvents) {
          final cid = evt.clientEventId ?? '';
          final rawDetail = evt.detail ?? '';

          // 🚫 HARD GUARD 1: Any event with a flowLocalId is NOT standalone
          if (evt.flowLocalId != null) {
            if (kDebugMode) {
              debugPrint(
                '[loadFromDisk] ⛔ Skipping event "${evt.title}" '
                'with flowLocalId=${evt.flowLocalId} in standalone loader.',
              );
            }
            continue;
          }

          // 🚫 HARD GUARD 2: Legacy flow copies where detail starts with "flowLocalId="
          if (rawDetail.startsWith('flowLocalId=')) {
            if (kDebugMode) {
              debugPrint(
                '[loadFromDisk] 👻 Skipping legacy flow event "${evt.title}" '
                'with detail starting with "flowLocalId=".',
              );
            }
            continue;
          }

          // 🚫 HARD GUARD 3: Legacy Ma'at events using "maat:" prefix
          if (cid.startsWith('maat:')) {
            if (kDebugMode) {
              debugPrint(
                '[loadFromDisk] 👻 Skipping legacy Ma\'at event "${evt.title}" '
                'with clientEventId=$cid.',
              );
            }
            continue;
          }

          // 🚫 HARD GUARD 4: Unified CID events (ky=...|f=123) referencing flows.
          // If f != -1 AND evt.flowLocalId == null → orphaned zombie.
          if (cid.contains('|f=')) {
            final match = RegExp(r'\|f=([\-0-9]+)').firstMatch(cid);
            if (match != null) {
              final fVal = int.tryParse(match.group(1) ?? '-1') ?? -1;
              if (fVal != -1) {
                if (kDebugMode) {
                  debugPrint(
                    '[loadFromDisk] 👻 Skipping orphaned flow event "${evt.title}" '
                    'with clientEventId=$cid (f=$fVal but flowLocalId is null).',
                  );
                }
                continue;
              }
            }
          }

          // ✅ If it passed all guards → this is a true standalone note
          final localStart = evt.startsAtUtc.toLocal();
          final kDate = KemeticMath.fromGregorian(localStart);
          final decoded = _decodeDetailColor(rawDetail);
          final cleanedDetail = _cleanDetail(decoded.detail);

          final note = _Note(
            title: evt.title,
            detail: cleanedDetail,
            location: evt.location,
            allDay: evt.allDay,
            start: evt.allDay
                ? null
                : TimeOfDay.fromDateTime(localStart),
            end: evt.endsAtUtc == null
                ? null
                : TimeOfDay.fromDateTime(evt.endsAtUtc!.toLocal()),
            flowId: -1, // Standalone notes have flowId = -1
            manualColor: decoded.color,
            category: evt.category,
          );

          final key = _kKey(kDate.kYear, kDate.kMonth, kDate.kDay);
          final bucket = _notes.putIfAbsent(key, () => <_Note>[]);

          // Deduplication: only for other standalone notes
          final already = bucket.any((n) {
            if ((n.flowId ?? -1) != -1) return false; // skip flow-driven notes
            if (n.allDay != note.allDay) return false;
            if (n.start?.hour != note.start?.hour ||
                n.start?.minute != note.start?.minute) return false;
            return n.title.trim().toLowerCase() ==
                note.title.trim().toLowerCase();
          });

          if (!already) {
            bucket.add(note);
            addedCount++; // ✅ important: track how many actually added
          }
        }

        if (kDebugMode) {
          debugPrint(
            '[_loadFromDisk] loaded $addedCount standalone events after filtering',
          );
        }
      } catch (err, st) {
        if (kDebugMode) {
          debugPrint('[loadFromDisk] failed to load standalone events: $err');
          debugPrint('$st');
        }
      }

      // force rebuild
      setState(() {});
      _bumpDataVersion();
    } catch (e, stackTrace) {
      print('Supabase sync FAILED: $e');
      print('Stack: $stackTrace');
    }

    print('=== _loadFromDisk END ===');
  }

  /// Allows other screens (e.g., Settings) to trigger a fresh sync of flows/notes.
  Future<void> reloadFromOutside() => _loadFromDisk();

  static Map<String, dynamic> ruleToJson(FlowRule r) {
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

  List<FlowRule> _parseRules(String rulesJson) {
    if (rulesJson.isEmpty) return [];
    try {
      final parsed = jsonDecode(rulesJson) as List;
      return parsed.map((j) => CalendarPage.ruleFromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  bool _rulesEqual(List<dynamic> oldRulesJson, List<FlowRule> newRules) {
    if (oldRulesJson.length != newRules.length) return false;
    List<Map<String, dynamic>> _normalize(List<Map<String, dynamic>> list) {
      list.sort((a, b) => (a['type'] as String? ?? '').compareTo(b['type'] as String? ?? ''));
      return list;
    }

    final oldNormalized = _normalize(oldRulesJson
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList());
    final newNormalized = _normalize(newRules
        .map(ruleToJson)
        .map((r) => Map<String, dynamic>.from(r))
        .toList());
    return jsonEncode(oldNormalized) == jsonEncode(newNormalized);
  }

  bool _isColorOnlyChange(FlowRow oldFlow, _Flow newFlow) {
    if (oldFlow.name != newFlow.name) return false;
    if (oldFlow.notes != newFlow.notes) return false;
    if (oldFlow.startDate != newFlow.start) return false;
    if (oldFlow.endDate != newFlow.end) return false;
    if (!_rulesEqual(oldFlow.rules, newFlow.rules)) return false;
    return oldFlow.color != newFlow.color.value;
  }


// Persist flows + planned notes coming back from Flow Studio
  // AFTER
  Future<int?> _persistFlowStudioResult(_FlowStudioResult r) async {
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
        rethrow; // bubble up so we don't silently keep the flow
      }
      try {
        await repo.deleteFlow(r.deleteFlowId!);
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ✓ Deleted flow from database');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ⚠️ Failed to delete flow: $e');
        }
        rethrow; // bubble up and avoid thinking it was removed
      }
      // Remove the flow from memory
      _flows.removeWhere((f) => f.id == r.deleteFlowId);
      setState(() {});
      if (kDebugMode) {
        debugPrint('[persistFlowStudio] ✓ Flow deletion complete');
      }
      return r.deleteFlowId;
    }

    // 2) Save/create flow if provided
    _Flow? saved;
    FlowRow? oldFlowRow;
    if (r.savedFlow != null) {
      // Capture previous state for change detection (best-effort)
      if (r.savedFlow!.id > 0) {
        try {
          oldFlowRow = await _flowsRepo.getFlowById(r.savedFlow!.id);
        } catch (_) {
          oldFlowRow = null;
        }
      }

      // ✅ For imported flows (with plannedNotes), clear rules to prevent rule-based rescheduling
      // The rules are already cleared in _save() when widget.importData != null,
      // but we also check here as a safety measure
      final bool hasSnapshotEvents = r.plannedNotes.isNotEmpty;
      final rulesJson = hasSnapshotEvents 
          ? jsonEncode([]) 
          : jsonEncode(r.savedFlow!.rules.map(ruleToJson).toList());

      final savedId = await repo.upsertFlow(
        id: r.savedFlow!.id > 0 ? r.savedFlow!.id : null,
        name: r.savedFlow!.name,
        color: r.savedFlow!.color.value,
        active: r.savedFlow!.active,
        startDate: r.savedFlow!.start,
        endDate: r.savedFlow!.end,
        notes: r.savedFlow!.notes,
        rules: rulesJson,
        isHidden: r.savedFlow!.isHidden,
      );




      saved = _Flow(
        id: savedId,
        name: r.savedFlow!.name,
        color: r.savedFlow!.color,
        active: r.savedFlow!.active,
        rules: r.savedFlow!.rules,
        start: r.savedFlow!.start,
        end: r.savedFlow!.end,
        notes: r.savedFlow!.notes,
        shareId: r.savedFlow!.shareId,
        isHidden: r.savedFlow!.isHidden, // Preserve hidden status
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
    final aiGenerated =
        oldFlowRow?.aiMetadata == null ? null : oldFlowRow!.aiMetadata?['generated'];
    final isAIFlow = aiGenerated is bool && aiGenerated;

    if (r.plannedNotes.isNotEmpty) {
      final repo2 = UserEventsRepo(Supabase.instance.client);

      // For AI-generated flows, wipe existing events first to avoid duplicates
      if (isAIFlow && flowId > 0) {
        try {
          await repo2.deleteByFlowId(flowId);
          if (kDebugMode) {
            debugPrint(
              '[persistFlowStudio] Cleared existing events for AI flow $flowId to avoid duplicates',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '[persistFlowStudio] Failed to clear events for AI flow $flowId: $e',
            );
          }
        }
      }

      for (final p in r.plannedNotes) {
        final n = p.note;
        final noteFlowId = (n.flowId ?? flowId) ?? -1;

        // Add to in-memory notes
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
          flowId: noteFlowId >= 0 ? noteFlowId : null,
          category: n.category,
        );

        // Persist to database
        final cid = EventCidUtil.buildClientEventId(
          ky: p.ky,
          km: p.km,
          kd: p.kd,
          title: n.title,
          startHour: n.start?.hour ?? 9,
          startMinute: n.start?.minute ?? 0,
          allDay: n.allDay,
          flowId: noteFlowId,
        );

        final gDay = KemeticMath.toGregorian(p.ky, p.km, p.kd);
        final startsAt = DateTime(
          gDay.year,
          gDay.month,
          gDay.day,
          n.start?.hour ?? 9,
          n.start?.minute ?? 0,
        );

        DateTime? endsAt;
        if (!n.allDay && n.end != null) {
          endsAt = DateTime(gDay.year, gDay.month, gDay.day, n.end!.hour, n.end!.minute);
        } else if (!n.allDay) {
          endsAt = startsAt.add(const Duration(hours: 1));
        }

        await repo2.upsertByClientId(
          clientEventId: cid,
          title: n.title,
          startsAtUtc: startsAt.toUtc(),
          detail: (n.detail ?? '').trim().isEmpty ? null : n.detail,
          location: (n.location ?? '').trim().isEmpty ? null : n.location,
          allDay: n.allDay,
          endsAtUtc: endsAt?.toUtc(),
          flowLocalId: noteFlowId >= 0 ? noteFlowId : null,
          category: n.category,
        );
      }
    }

    // Use shared scheduler for flow notes if we have a saved flow
    if (saved != null && saved.active && saved.rules.isNotEmpty) {
      // If we have planned notes, skip rule-based scheduling to preserve titles/times.
      if (r.plannedNotes.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ✅ Skipping scheduleFlowNotes - using plannedNotes with individual titles');
        }
        setState(() {});
        return saved.id;
      }
      // If rules list was cleared (e.g., snapshot-only imports), skip scheduling.
      if (saved.rules.isEmpty) {
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ✅ Skipping scheduleFlowNotes - flow has no rules (snapshot-only)');
        }
        setState(() {});
        return saved.id;
      }
      try {
        // Check if this is an AI-generated flow before scheduling
        // (AI flows already have individually-titled events that shouldn't be regenerated)
        final flowRow = await _flowsRepo.getFlowById(saved.id);

        // Defensive type checking for ai_metadata.generated field
        final aiGenerated = flowRow?.aiMetadata?['generated'];
        final isAIFlow = aiGenerated is bool && aiGenerated == true;

        if (isAIFlow) {
          if (kDebugMode) {
            debugPrint('[persistFlowStudio] ✅ Skipping scheduleFlowNotes for AI-generated flow ${saved.id} (preserving individual note titles)');
          }
          
          // TODO: Add analytics once analytics service is integrated
          // Example: _analyticsService.logEvent('ai_flow_schedule_skipped', {'flowId': saved.id});
        } else {
          // Imported flow with only color change? Skip reschedule.
          if (saved.shareId != null &&
              oldFlowRow != null &&
              _isColorOnlyChange(oldFlowRow, saved)) {
            if (kDebugMode) {
              debugPrint('[persistFlowStudio] ⚠️ Skipping reschedule for color-only change on imported flow ${saved.id}');
            }
          } else {
            // Only regenerate notes for manually-created flows with recurring rules
            await scheduleFlowNotes(
              flowId: saved.id,
              rules: saved.rules,
              flowNotes: saved.notes,
              startDate: saved.start,
              endDate: saved.end,
            );
            
            if (kDebugMode) {
              debugPrint('[persistFlowStudio] ✅ Scheduled recurring notes for flow ${saved.id}');
            }
          }
          
          // TODO: Add analytics once analytics service is integrated
          // Example: _analyticsService.logEvent('flow_notes_scheduled', {
          //   'flowId': saved.id,
          //   'ruleCount': saved.rules.length,
          //   'dateRange': '${saved.start} to ${saved.end}',
          // });
        }
      } catch (e, stackTrace) {
        // Log error but don't crash - flow is already saved
        if (kDebugMode) {
          debugPrint('[persistFlowStudio] ⚠️ Failed to check/schedule flow notes: $e');
          debugPrint('Stack trace: $stackTrace');
        }
        
        // TODO: Add error tracking once analytics service is integrated
        // Example: _analyticsService.logError('flow_schedule_error', e, stackTrace);
      }
    }

    setState(() {});
    return saved?.id;
  }

  /// Schedules all note occurrences for a flow to the calendar
  /// This is the shared logic used by both Flow Studio and Inbox imports
  // Save a single (non-repeating) note only
  Future<void> _saveSingleNoteOnly({
    required int selYear,
    required int selMonth,
    required int selDay,
    required String title,
    String? detail,
    String? location,
    required bool allDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    String? category,
  }) async {
    // Add to in-memory notes with manualColor so UI uses it.
    _addNote(
      selYear,
      selMonth,
      selDay,
      title,
      detail,
      location: location,
      allDay: allDay,
      start: startTime,
      end: endTime,
      manualColor: color,
      category: category,
    );

    // Compute when to alert
    final gDay = KemeticMath.toGregorian(selYear, selMonth, selDay);
    final scheduledAt = allDay
        ? DateTime(gDay.year, gDay.month, gDay.day, 9, 0) // default 9:00 AM
        : DateTime(
            gDay.year, gDay.month, gDay.day, startTime!.hour, startTime!.minute);

    // Build a simple text body: Location (if any) + Details (if any)
    final bodyLines = <String>[
      if (location != null && location.isNotEmpty) location,
      if (detail != null && detail.isNotEmpty) detail,
    ];
    final body = bodyLines.isEmpty ? null : bodyLines.join('\n');

    // Build canonical clientEventId for this manual note
    final String unifiedCid = _buildCid(
      ky: selYear,
      km: selMonth,
      kd: selDay,
      title: title,
      startHour: (allDay || startTime == null) ? null : startTime!.hour,
      startMinute: (allDay || startTime == null) ? null : startTime!.minute,
      allDay: allDay,
      flowId: -1,
    );
    
    final encodedDetail = _encodeDetailWithColor(detail, color);
    final notificationBodyLines = <String>[
      if (location != null && location.isNotEmpty) location,
      if (detail != null && detail.isNotEmpty) detail,
      if (color != null)
        'Color: ${(color.value & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}',
    ];
    final notificationBody =
        notificationBodyLines.isEmpty ? null : notificationBodyLines.join('\n');

    // Schedule the local notification WITH PERSISTENCE
    await Notify.scheduleAlertWithPersistence(
      clientEventId: unifiedCid,
      scheduledAt: scheduledAt,
      title: title,
      body: notificationBody ?? body,
      payload: '{}',
    );

    // Sync to Supabase
    try {
      final repo = UserEventsRepo(Supabase.instance.client);
      final endsAtUtc = (allDay || endTime == null)
          ? null
          : DateTime(gDay.year, gDay.month, gDay.day, endTime!.hour, endTime!.minute).toUtc();

      await repo.upsertByClientId(
        clientEventId: unifiedCid,
        title: title,
        startsAtUtc: scheduledAt.toUtc(),
        detail: encodedDetail,
        location: location,
        allDay: allDay,
        endsAtUtc: endsAtUtc,
        category: category,
      );
      
      // Also log to app_events for analytics
      try {
        await repo.track(
          event: 'note_created',
          properties: {
            'title': title,
            if (detail != null && detail.isNotEmpty) 'body': detail,
            if (location != null && location.isNotEmpty) 'location': location,
            'all_day': allDay,
          },
          source: 'client',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SaveSingleNote] failed to log app_events: $e');
        }
      }
    } catch (e) {
      // non-fatal; keep UX flowing
      if (kDebugMode) {
        debugPrint('[SaveSingleNote] failed to save: $e');
      }
    }
  }

  // Save a repeating note as a hidden micro-flow
  Future<void> _saveRepeatingNoteAsHiddenFlow({
    required int selYear,
    required int selMonth,
    required int selDay,
    required String title,
    String? detail,
    String? location,
    required bool allDay,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required NoteRepeatOption repeatOption,
    required SimpleRecurrenceFrequency customFrequency,
    required int customInterval,
    required NoteRepeatEndType endType,
    required DateTime? endDate,
    required int endCount,
    required Color color,
    String? category,
  }) async {
    // 1. First occurrence = selected Kemetic day -> Gregorian
    final DateTime firstOccurrence = KemeticMath.toGregorian(
      selYear,
      selMonth,
      selDay,
    );

    final DateTime now = DateUtils.dateOnly(DateTime.now());

    // 2. Determine horizon for recurrence generation and flow.end.
    late final DateTime horizonEnd;
    if (endType == NoteRepeatEndType.onDate && endDate != null) {
      horizonEnd = DateUtils.dateOnly(endDate);
    } else if (endType == NoteRepeatEndType.afterCount) {
      // Rough upper bound: assume worst-case yearly interval * count.
      horizonEnd = firstOccurrence.add(Duration(days: 365 * endCount));
    } else {
      // Never ends: use a sane horizon (e.g. 1 year out).
      horizonEnd = firstOccurrence.add(const Duration(days: 365));
    }

    // 3. Generate `_RuleDates` with Kemetic-aware recurrence logic.
    final _RuleDates rule = _buildNoteRuleDates(
      firstOccurrenceDate: firstOccurrence,
      repeatOption: repeatOption,
      customFrequency: customFrequency,
      customInterval: customInterval,
      endType: endType,
      endDate: endDate,
      endCount: endCount,
      allDay: allDay,
      startTime: startTime,
      endTime: endTime,
      horizonEnd: horizonEnd,
    );

    // 4. Guard: if we somehow got no dates, fall back to single note.
    if (rule.dates.isEmpty) {
      if (kDebugMode) {
        debugPrint('[RepeatNote] Empty date set for repeating note "$title"; falling back to single note.');
      }
      await _saveSingleNoteOnly(
        selYear: selYear,
        selMonth: selMonth,
        selDay: selDay,
        title: title,
        detail: detail,
        location: location,
        allDay: allDay,
        startTime: startTime,
        endTime: endTime,
        color: color,
        category: category,
      );
      return;
    }

    // 5. Create a hidden flow object in memory (micro-flow just for this note pattern).
    final flow = _Flow(
      id: -1, // Will be replaced by DB id
      name: title,
      color: color, // Use selected color
      active: true,
      rules: [rule],
      start: firstOccurrence,
      end: horizonEnd,
      notes: _encodeRepeatingNoteMetadata(detail: detail, location: location, category: category),
      shareId: null,
      isHidden: true, // Critical: these never show in Flow Studio lists
    );

    final repo = UserEventsRepo(Supabase.instance.client);

    // 6. Persist the flow row to Supabase, storing rules as JSON.
    final rulesJson = jsonEncode([_CalendarPageState.ruleToJson(rule)]);

    final int flowId = await repo.upsertFlow(
      id: null,
      name: flow.name,
      color: flow.color.value,
      active: flow.active,
      startDate: flow.start,
      endDate: flow.end,
      notes: flow.notes,
      rules: rulesJson,
      isHidden: flow.isHidden,
    );

    // 7. Insert into in-memory _flows list with correct ID.
    final savedFlow = _Flow(
      id: flowId,
      name: flow.name,
      color: flow.color,
      active: flow.active,
      rules: flow.rules,
      start: flow.start,
      end: flow.end,
      notes: flow.notes,
      shareId: flow.shareId,
      isHidden: flow.isHidden,
    );

    _flows.add(savedFlow);
    if (flowId >= _nextFlowId) {
      _nextFlowId = flowId + 1;
    }

    // 8. Trigger materialization of events into user_events via the shared engine.
    await _triggerFlowSchedule(flowId);
  }

  /// Universal date picker supporting Kemetic/Gregorian toggle
  Future<DateTime?> pickDateUniversal({
    required BuildContext context,
    required DateTime initialDate,
    bool allowPast = false,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    // Default to Gregorian mode for repeat-end selection
    bool localKemetic = false;

    // ---- Gregorian seed ----
    final now = DateUtils.dateOnly(DateTime.now());
    DateTime gSeed = initialDate;
    int gy = gSeed.year, gm = gSeed.month, gd = gSeed.day;

    // ---- Kemetic seed ----
    var kSeed = KemeticMath.fromGregorian(initialDate);
    int ky = kSeed.kYear, km = kSeed.kMonth, kd = kSeed.kDay;

    int _gregDayMax(int y, int m) => DateUtils.getDaysInMonth(y, m);
    int _kemDayMax(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    // ---- Controllers ----
    final gYearStart = now.year;
    final gYearCtrl = FixedExtentScrollController(initialItem: (gy - gYearStart).clamp(0, 399));
    final gMonthCtrl = FixedExtentScrollController(initialItem: (gm - 1).clamp(0, 11));
    final gDayCtrl = FixedExtentScrollController(initialItem: (gd - 1).clamp(0, 30));

    final kYearStart = ky;
    final kYearCtrl = FixedExtentScrollController(initialItem: (ky - kYearStart).clamp(0, 400));
    final kMonthCtrl = FixedExtentScrollController(initialItem: (km - 1).clamp(0, 12));
    final kDayCtrl = FixedExtentScrollController(initialItem: (kd - 1).clamp(0, 29));

    // ---------------------------------------------------------------------------
    // SHOW THE BOTTOM SHEET
    // ---------------------------------------------------------------------------
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // Clamp wheels against month/day changes
            final gMax = _gregDayMax(gy, gm);
            if (gd > gMax) gd = gMax;
            final kMax = _kemDayMax(ky, km);
            if (kd > kMax) kd = kMax;

            // -------------------------------------------------------------------
            // Gregorian wheel
            // -------------------------------------------------------------------
            Widget _gregWheel() => SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      // MONTH
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
                          children: List.generate(
                            12,
                            (i) => Center(
                              child: GlossyText(
                                text: _gregMonthNames[i + 1],
                                style: const TextStyle(fontSize: 14),
                                gradient: silverGloss,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // DAY
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
                          children: List.generate(
                            _gregDayMax(gy, gm),
                            (i) => Center(
                              child: GlossyText(
                                text: '${i + 1}',
                                style: const TextStyle(fontSize: 14),
                                gradient: silverGloss,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // YEAR
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
                          children: List.generate(
                            40,
                            (i) {
                              final yy = gYearStart + i;
                              return Center(
                                child: GlossyText(
                                  text: '$yy',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );

            // -------------------------------------------------------------------
            // Kemetic wheel
            // -------------------------------------------------------------------
            Widget _kemWheel() => SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      // MONTH
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
                          children: List.generate(
                            13,
                            (i) => Center(
                              child: MonthNameText(
                                getMonthById(i + 1).displayFull,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // DAY
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
                          children: List.generate(
                            _kemDayMax(ky, km),
                            (i) => Center(
                              child: GlossyText(
                                text: '${i + 1}',
                                style: const TextStyle(fontSize: 14),
                                gradient: silverGloss,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // YEAR
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
                          children: List.generate(
                            401,
                            (i) {
                              final y = kYearStart + i;
                              final last = (km == 13)
                                  ? (KemeticMath.isLeapKemeticYear(y) ? 6 : 5)
                                  : 30;
                              final yStart = KemeticMath.toGregorian(y, km, 1).year;
                              final yEnd = KemeticMath.toGregorian(y, km, last).year;
                              final label = (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
                              return Center(
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );

            // -------------------------------------------------------------------
            // UI SHEET CONTENT
            // -------------------------------------------------------------------
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
                          // Switch to Kemetic
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
                          // Switch to Gregorian
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

                  GlossyText(
                    text: localKemetic
                        ? 'Pick date (Kemetic)'
                        : 'Pick date (Gregorian)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    gradient: localKemetic ? goldGloss : blueGloss,
                  ),

                  const SizedBox(height: 8),

                  localKemetic ? _kemWheel() : _gregWheel(),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // CANCEL
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: silver, width: 1.25),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // USE THIS DATE
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: localKemetic ? _gold : _blue,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            final DateTime chosen = localKemetic
                                ? KemeticMath.toGregorian(ky, km, kd)
                                : DateUtils.dateOnly(DateTime(gy, gm, gd));

                            // Apply constraints
                            DateTime finalResult = chosen;
                            if (!allowPast &&
                                firstDate != null &&
                                finalResult.isBefore(firstDate)) {
                              finalResult = firstDate;
                            }
                            if (lastDate != null && finalResult.isAfter(lastDate)) {
                              finalResult = lastDate;
                            }

                            Navigator.pop(sheetCtx, finalResult);
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

    return result;
  }

  /// Trigger function: central place to (re)schedule events for a flow.
  ///
  /// This is the only method that should call `scheduleFlowNotes` directly.
  /// It is used by:
  ///  - Flow Studio saves/updates
  ///  - Repeating notes (hidden micro-flows)
  Future<void> _triggerFlowSchedule(int flowId) async {
    _Flow flow;

    try {
      flow = _flows.firstWhere((f) => f.id == flowId);
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[triggerFlowSchedule] Flow $flowId not found in _flows; skipping schedule.');
      }
      return;
    }

    // If flow is inactive or has no rules, just clear its events.
    if (!flow.active || flow.rules.isEmpty) {
      if (kDebugMode) {
        debugPrint('[triggerFlowSchedule] Flow $flowId inactive or has no rules; deleting events.');
      }
      final repo = UserEventsRepo(Supabase.instance.client);
      await repo.deleteByFlowId(flowId);
      return;
    }

    if (kDebugMode) {
      debugPrint('[triggerFlowSchedule] Scheduling flow $flowId with ${flow.rules.length} rules');
    }

    await scheduleFlowNotes(
      flowId: flow.id,
      rules: flow.rules,
      flowNotes: flow.notes,
      startDate: flow.start,
      endDate: flow.end,
    );
  }

  Future<void> scheduleFlowNotes({
    required int flowId,
    required List<FlowRule> rules,
    required String? flowNotes,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final repo = UserEventsRepo(Supabase.instance.client);
    final scheduleStart = startDate ?? DateTime.now();
    final scheduleEnd = endDate ?? scheduleStart.add(const Duration(days: 90)); // Default 90 days

    if (kDebugMode) {
      debugPrint('[scheduleFlowNotes] Starting for flowId=$flowId from $scheduleStart to $scheduleEnd');
    }

    // Look up flow object for name and metadata
    _Flow? flow;
    try {
      flow = _flows.firstWhere((f) => f.id == flowId);
    } catch (_) {
      flow = null;
    }

    final flowStart = flow?.start ?? DateTime(1970);
    final flowEnd = flow?.end ?? DateTime(2100);
    final hasOverlap = !flowEnd.isBefore(scheduleStart) && !flowStart.isAfter(scheduleEnd);
    if (!hasOverlap) {
      if (kDebugMode) {
        debugPrint('[scheduleFlowNotes] ⚠️ No overlap: flow ($flowStart-$flowEnd) vs schedule ($scheduleStart-$scheduleEnd)');
      }
      return;
    }

    String noteTitle = flow?.name ?? 'Flow Event';
    String? noteDetail;
    String? noteLocation;

    // Decode flow.notes to extract detail and location for repeating notes
    if (flowNotes != null && flowNotes.isNotEmpty) {
      try {
        // Try JSON first (for repeating notes)
        final meta = jsonDecode(flowNotes) as Map<String, dynamic>;
        if (meta['kind'] == 'repeating_note') {
          noteDetail = (meta['detail'] as String?)?.trim();
          noteLocation = (meta['location'] as String?)?.trim();
        } else {
          // Legacy flowNotes format - try notesDecode
          try {
            final decoded = notesDecode(flowNotes);
            if (decoded.overview.isNotEmpty) noteDetail = decoded.overview;
          } catch (_) {
            // Ignore if decode fails
          }
        }
      } catch (_) {
        // Not JSON, try legacy format
        try {
          final decoded = notesDecode(flowNotes);
          if (decoded.overview.isNotEmpty) noteDetail = decoded.overview;
        } catch (_) {
          // Ignore if both fail
        }
      }
    }

    // Build candidate events first; only delete/insert if we have any.
    final candidateEvents = <_CandidateEvent>[];
    try {
      var date = scheduleStart;
      while (!date.isAfter(scheduleEnd)) {
        final kDate = KemeticMath.fromGregorian(date);

        for (final rule in rules) {
          if (rule.matches(ky: kDate.kYear, km: kDate.kMonth, kd: kDate.kDay, g: date)) {
            final startHour = rule.allDay ? 9 : (rule.start?.hour ?? 9);
            final startMinute = rule.allDay ? 0 : (rule.start?.minute ?? 0);

            final cid = _buildCid(
              ky: kDate.kYear,
              km: kDate.kMonth,
              kd: kDate.kDay,
              title: noteTitle,
              startHour: startHour,
              startMinute: startMinute,
              allDay: rule.allDay,
              flowId: flowId,
            );

            final startsAt = DateTime(
              date.year,
              date.month,
              date.day,
              startHour,
              startMinute,
            );

            DateTime? endsAt;
            if (!rule.allDay) {
              if (rule.end != null) {
                endsAt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  rule.end!.hour,
                  rule.end!.minute,
                );
              } else {
                // Default to 1 hour if end is missing
                endsAt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  startHour,
                  startMinute,
                ).add(const Duration(hours: 1));
              }
            }

            candidateEvents.add(_CandidateEvent(
              clientEventId: cid,
              title: noteTitle,
              startsAtUtc: startsAt.toUtc(),
              endsAtUtc: endsAt?.toUtc(),
              detail: noteDetail,
              location: noteLocation,
              allDay: rule.allDay,
              flowLocalId: flowId,
            ));
          }
        }

        date = date.add(const Duration(days: 1));
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[scheduleFlowNotes] ⚠️ Generation failed for flowId=$flowId: $e');
        debugPrint(stack.toString());
      }
      return;
    }

    if (candidateEvents.isEmpty) {
      if (kDebugMode) {
        debugPrint('[scheduleFlowNotes] ⚠️ No events generated for flowId=$flowId; skipping delete.');
      }
      return;
    }

    try {
    // Clear existing scheduled notes for this flow after successful generation
    await repo.deleteByFlowId(flowId, fromDate: scheduleStart.toUtc());

      for (final ev in candidateEvents) {
        await repo.upsertByClientId(
          clientEventId: ev.clientEventId,
          title: ev.title,
          startsAtUtc: ev.startsAtUtc,
          detail: ev.detail,
          location: ev.location,
          allDay: ev.allDay,
          endsAtUtc: ev.endsAtUtc,
          flowLocalId: ev.flowLocalId,
        );
      }

      if (kDebugMode) {
        debugPrint('[scheduleFlowNotes] Scheduled ${candidateEvents.length} notes for flowId=$flowId');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[scheduleFlowNotes] ⚠️ CRITICAL: delete/insert failed for flowId=$flowId: $e');
        debugPrint(stack.toString());
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // ✅ HARDENING 2: Gate build until state is restored to prevent race condition
    if (!_restored) {
      return const SizedBox.shrink();
    }
    
    _buildCount++;
    debugPrint('📔 Journal initialized: $_journalInitialized');

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
      
      // ✅ FIX 1: Scroll to saved month when switching to portrait
      // _centerMonth() already uses addPostFrameCallback internally, so direct call is safe
      if (orientation == Orientation.portrait && 
          _lastViewKy != null && 
          _lastViewKm != null) {
        if (kDebugMode) {
          print('📜 [CALENDAR] Scrolling to saved month: $_lastViewKy-$_lastViewKm');
        }
        _centerMonth(_lastViewKy!, _lastViewKm!);
      }
    }
    _lastOrientation = orientation;

    if (useGrid) {
      debugPrint('📱 Rendering: LandscapeMonthView (build #$_buildCount)');
      
      // ✅ FIX 5: Only call if state is missing (optimization)
      // The method already has a guard, but this prevents unnecessary function calls
      // ✅ FIX 6: Also prevent during landscape updates to avoid side effects
      if (!_isUpdatingFromLandscape && 
          (_lastViewKy == null || _lastViewKm == null)) {
      _updateCenteredMonthWide();
      }
      
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
        initialKd: _lastViewKd ?? _today.kDay,  // ✅ Highlight current day
        showGregorian: _showGregorian,
        notesForDay: (ky, km, kd) {
          final notes = _getNotes(ky, km, kd);
          return notes.map((n) => NoteData(
            id: n.id?.toString(),
            title: n.title,
            detail: n.detail,
            location: n.location,
            allDay: n.allDay,
            start: n.start,
            end: n.end,
            flowId: n.flowId,
            manualColor: n.manualColor,
            category: n.category,
          )).toList();
        },
        flowIndex: _buildFlowIndex(),
        getMonthName: (km) => getMonthById(km).displayFull,
        onManageFlows: _getMyFlowsCallback(),
        onAddNote: (ky, km, kd) {
          if (kDebugMode) {
            print('\n🎯 [CALLBACK] onAddNote received from landscape');
            print('   Date: $ky-$km-$kd');
          }
          _openDaySheet(ky, km, kd, allowDateChange: true);
        },
        onMonthChanged: _handleLandscapeMonthChanged, // ✅ ADD CALLBACK
        onDeleteNote: (ky, km, kd, evt) => _deleteNoteByEvent(ky, km, kd, evt),
        onEditNote: (ky, km, kd, evt) async {
          await _editNoteByEvent(ky, km, kd, evt);
        },
        onShareNote: (evt) async {
          await _shareNoteSimple(evt);
        },
        onAppendToJournal: _journalInitialized
            ? (text) => _journalController.appendToToday(text)
            : null,
      );
    }

    debugPrint('📱 Rendering: Portrait Scaffold (build #$_buildCount)');

    return Scaffold(
      key: CalendarPage.globalKey,
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        // Left-biased title (not centered, not flush)
        centerTitle: false,
        titleSpacing: 12, // 10–14; 12 matches your "correct" look
        iconTheme: const IconThemeData(color: _gold), // ensure action icons use rich gold
        title: GestureDetector(
          onTap: () => setState(() => _showGregorian = !_showGregorian),
          child: Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: GlossyText(
              text: "ḥꜣw",
              gradient: _showGregorian ? whiteGloss : goldGloss,
              style: _titleGold.copyWith(
                fontSize: (_titleGold.fontSize ?? 22.0).roundToDouble(),
                letterSpacing: 0,
                // shadows off for button text; mask + small shadows = haze
                shadows: null,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const _GlossyIcon(Icons.calendar_today, gradient: silverGloss),
            onPressed: _scrollToToday,
          ),
          IconButton(
            tooltip: 'Search events',
            icon: const _GlossyIcon(Icons.search, gradient: silverGloss),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Flow Studio',
            icon: const _GlossyIcon(Icons.view_timeline, gradient: goldGloss),
            onPressed: () => _getFlowStudioCallback()(null),
          ),

          IconButton(
            tooltip: 'New note',
            icon: const _GlossyIcon(Icons.add, gradient: goldGloss),
            onPressed: _openQuickAddSheet,
          ),
          // My Profile button
          IconButton(
            tooltip: 'My Profile',
            icon: const _GlossyIcon(Icons.person, gradient: goldGloss),
            onPressed: () {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId != null) {
                UiGuards.disableJournalSwipe();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: userId, isMyProfile: true),
                  ),
                ).then((_) {
                  UiGuards.enableJournalSwipe();
                  // ✅ Reload calendar when returning from profile (in case flows were imported)
                  _loadFromDisk();
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to view your profile')),
                );
              }
            },
          ),
        ],
      ),
      body: _buildBodyWithJournal(),
    );
  }

  Widget _buildBodyWithJournal() {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    debugPrint('🔧 _buildBodyWithJournal called: portrait=$isPortrait, initialized=$_journalInitialized');
    
    return JournalSwipeLayer(
      controller: _journalController,
      isPortrait: isPortrait,
      child: _buildCalendarScrollView(),
    );
  }

  Widget _buildCalendarScrollView() {
    final kToday = _today;
    
    // ✅ FIX 4: Wrap with NotificationListener to capture scroll-end events
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        // ✅ Only update centered month when scrolling STOPS
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          final centered = _computeCenteredMonthPrecisely();
          if (centered.$1 != _lastViewKy || centered.$2 != _lastViewKm) {
            _handlePortraitMonthChanged(centered.$1, centered.$2);
          }
        });
        return false;
      },
      child: CustomScrollView(
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
                flowColorsGetter: (ky, km, kd) => getFlowColorsForDay(ky, km, kd),
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
            flowColorsGetter: (ky, km, kd) => getFlowColorsForDay(ky, km, kd),
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
                flowColorsGetter: (ky, km, kd) => getFlowColorsForDay(ky, km, kd),
                showGregorian: _showGregorian,
              );
            },
            childCount: 200, //
          ),
        ),
      ],
      ),
    );
  }

  // Helper method to build flow index for landscape month view
  Map<int, FlowData> _buildFlowIndex() {
    final index = <int, FlowData>{};
    for (final f in _flows.where((f) => f.active && _isActiveByEndDate(f.end))) {
      index[f.id] = FlowData(
        id: f.id,
        name: f.name,
        color: f.color,
        active: f.active,
      );
    }
    return index;
  }

  @visibleForTesting
  int filteredNoteCountForDay(int kYear, int kMonth, int kDay) {
    // Unified logic: all views read from _notes (which is the canonical source).
    // Zombie filters are already applied during _loadFromDisk, so we just count.
    final key = _kKey(kYear, kMonth, kDay);
    return (_notes[key] ?? const []).length;
  }
}



/* ───────────── Year Section (12 months + epagomenal) ───────────── */

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.kYear,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
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
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;

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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
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
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.todayDayKey,
    this.onMonthHeaderTap,
    this.onDecanTap,
  });

  // monthNames removed - use getMonthById(kMonth).displayFull instead

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
          flowColorsGetter: flowColorsGetter,
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
          flowColorsGetter: flowColorsGetter,
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
        color: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.none, // avoids unnecessary AA clip
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
                    child: _GlossyMonthNameText(
                      text: getMonthById(kMonth).displayFull,
                      style: _monthTitleGold, // MonthNameText handles font families
                      gradient: goldGloss,
                    ),
                  ),
                  const Spacer(),
                  RepaintBoundary(
                    child: Text(
                      rightLabel,
                      style: _neutralOnBlack.copyWith(
                        fontFamilyFallback: const ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
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
                          child: GlossyText(
                            text: names[i],
                            style: _decanStyle,
                            gradient: silverGloss,
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
                          child: GlossyText(
                            text: _gregLabelForDecanRow(kYear, kMonth, i) ?? '',
                            style: _decanStyle,
                            gradient: blueGloss,
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
                  flowColorsGetter: flowColorsGetter,
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

/// Helper function to generate Kemetic day keys for the info dropdown
String _getKemeticDayKey(int kYear, int kMonth, int kDay) {
  // Use stable keys from metadata

  // Safety fallback if somehow we're out of normal 1–13 range
  if (kMonth < 1 || kMonth > 13) {
    return 'unknown_${kDay}_$kYear';
  }

  // decan math:
  // days 1–10   → decan 1
  // days 11–20  → decan 2
  // days 21–30  → decan 3
  final decan = ((kDay - 1) ~/ 10) + 1;

  // final key format must match kemetic_day_info.dart exactly
  // e.g. thoth_11_2
  return kemeticDayKey(kMonth, kDay);
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
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  const _DecanRow({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
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

        final notes = notesGetter(kMonth, day);
        final noteCount = notes.length;
        final flowColors = flowColorsGetter(kYear, kMonth, day);

        final label = showGregorian
            ? '${safeLocalDisplay(KemeticMath.toGregorian(kYear, kMonth, day)).day}'
            : '$day';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: j == 9 ? 0 : 6),
            child: _DayChip(
              key: ValueKey('k:$kYear-$kMonth-$day|${showGregorian ? "G" : "K"}'), // 🔑 Unique key with mode
              anchorKey: isToday ? todayDayKey : null, // 🔑 attach
              label: label,
              isToday: isToday,
              noteCount: noteCount,
              flowColors: flowColors,
              onTap: () => onDayTap(context, kMonth, day),
              showGregorian: showGregorian,
              dayKey: _getKemeticDayKey(kYear, kMonth, day),
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
  final String dayKey;

  const _DayChip({
    super.key,  // Add key parameter
    required this.label,
    required this.isToday,
    required this.noteCount,
    required this.flowColors,
    required this.onTap,
    required this.showGregorian,
    this.anchorKey,
    required this.dayKey,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w400,
      fontSize: 16.0,      // <- round to whole px to avoid subpixel blur
      letterSpacing: 0.0,  // <- reduce fuzz on CanvasKit
    );

    final gradient =
    isToday ? goldGloss : (showGregorian ? blueGloss : silverGloss);

    return KemeticDayButton(
      dayKey: dayKey,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          key: anchorKey,
          height: 36,
          child: RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GlossyText(
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
                    if (noteCount > 0) const _GlossyDot(gradient: silverGloss),
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
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
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
        color: Colors.black,
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
                  Visibility(
                    visible: !showGregorian, // visually removed in Gregorian
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true, // keep height so layout doesn't jump
                    child: GlossyText(
                      text: 'Heriu Renpet (ḥr.w rnpt)',
                      style: _monthTitleGold.copyWith(
                        fontFamily: 'GentiumPlus',
                        fontFamilyFallback: const ['NotoSans', 'Roboto'],
                      ),
                      gradient: goldGloss,
                    ),
                  ),
                  const Spacer(),
                  Visibility(
                    visible: showGregorian && gLabel != null,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: GlossyText(
                      text: gLabel ?? '',
                      style: _decanStyle,
                      gradient: blueGloss,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: List.generate(epiCount, (i) {
                  final n = i + 1; // 1..5 or 1..6
                  final isToday = isMonthToday && (todayDay == n);

                  final notes = notesGetter(13, n);
                  final noteCount = notes.length;
                  final flowColors = flowColorsGetter(kYear, 13, n);

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
                        dayKey: 'epagomenal_${n}_$kYear', // Epagomenal days use their own key format
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
    required this.flowColorsGetter,
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
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
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
        ? getMonthById(widget.kMonth).displayFull
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
        backgroundColor: Colors.black,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          icon: const _GlossyIcon(Icons.close, gradient: goldGloss),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GlossyText(
          text: infoTitle,
          style: _monthTitleGold,
          gradient: goldGloss,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: GlossyText(
                text: rightLabel,
                style: _rightSmall,
                gradient: whiteGloss,
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
                  flowColorsGetter: widget.flowColorsGetter,
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
                  GlossyText(
                    text: infoTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: silverGloss,
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
  String? category;

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
      category: category,
    );
  }

  void dispose() {
    titleCtrl.dispose();
    locationCtrl.dispose();
    detailCtrl.dispose();
  }
}

class _DraftNoteData {
  final String title;
  final String location;
  final String detail;
  final bool allDay;
  final int? startMinutes; // null when all-day
  final int? endMinutes;   // null when all-day
  final String? category;

  const _DraftNoteData({
    required this.title,
    required this.location,
    required this.detail,
    required this.allDay,
    required this.startMinutes,
    required this.endMinutes,
    required this.category,
  });

  factory _DraftNoteData.fromDraft(_NoteDraft draft) {
    return _DraftNoteData(
      title: draft.titleCtrl.text,
      location: draft.locationCtrl.text,
      detail: draft.detailCtrl.text,
      allDay: draft.allDay,
      startMinutes: draft.allDay || draft.start == null
          ? null
          : draft.start!.hour * 60 + draft.start!.minute,
      endMinutes: draft.allDay || draft.end == null
          ? null
          : draft.end!.hour * 60 + draft.end!.minute,
      category: draft.category,
    );
  }

  _NoteDraft toDraft() {
    final d = _NoteDraft();
    d.titleCtrl.text = title;
    d.locationCtrl.text = location;
    d.detailCtrl.text = detail;
    d.allDay = allDay;
    if (!allDay && startMinutes != null && endMinutes != null) {
      d.start = TimeOfDay(hour: (startMinutes! ~/ 60) % 24, minute: startMinutes! % 60);
      d.end = TimeOfDay(hour: (endMinutes! ~/ 60) % 24, minute: endMinutes! % 60);
    } else {
      d.start = null;
      d.end = null;
    }
    d.category = category;
    return d;
  }
}

class _FlowStudioDraft {
  final int? editingFlowId;
  final bool editingIsHidden;
  final String name;
  final bool active;
  final int selectedColorIndex;
  final bool useKemetic;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool splitByPeriod;
  final Set<int> selectedDecanDays;
  final Set<int> selectedWeekdays;
  final Map<String, Set<int>> perDecanSel;
  final Map<String, Set<int>> perWeekSel;
  final Map<String, List<_DraftNoteData>> draftsByDay;
  final Map<String, _DraftNoteData> draftsByPattern;
  final String overview;
  final bool isAIGeneratedFlow;

  const _FlowStudioDraft({
    required this.editingFlowId,
    required this.editingIsHidden,
    required this.name,
    required this.active,
    required this.selectedColorIndex,
    required this.useKemetic,
    required this.startDate,
    required this.endDate,
    required this.splitByPeriod,
    required this.selectedDecanDays,
    required this.selectedWeekdays,
    required this.perDecanSel,
    required this.perWeekSel,
    required this.draftsByDay,
    required this.draftsByPattern,
    required this.overview,
    required this.isAIGeneratedFlow,
  });
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
class ImportFlowData {
  final InboxShareItem share;
  final String name;
  final int color;
  final String? notes;
  final List<dynamic> rules;
  final DateTime? suggestedStartDate;
  const ImportFlowData({
    required this.share,
    required this.name,
    required this.color,
    this.notes,
    required this.rules,
    this.suggestedStartDate,
  });
}

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
    this.importData,
    super.key,
  });

  final List<_Flow> existingFlows;
  final int? editFlowId;
  final ImportFlowData? importData;

  @override
  State<_FlowStudioPage> createState() => _FlowStudioPageState();
}

class _FlowStudioPageState extends State<_FlowStudioPage> {
  static _FlowStudioDraft? _sessionDraft;
  bool _suppressDraftSave = false;
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

  // Readiness gate: only allow sync when the editor's state is fully initialized.
  bool _syncReady = false;

  // Single source-of-truth for day keys used by _draftsByDay.
  static String dayKey(int ky, int km, int kd) => '$ky-$km-$kd';

  // "same for all" selections
  final Set<int> _selectedDecanDays = <int>{}; // 1..10
  final Set<int> _selectedWeekdays = <int>{};   // 1..7 (Mon..Sun)

  // per-period mode
  bool _splitByPeriod = false; // toggle to show rows per decan/week
  
  // AI mode flag
  bool _isAIGeneratedFlow = false;

  // Loading flag for async flow loading
  bool _isLoadingFlow = false;

  // cached spans + per-period selections
  List<_KemeticDecanSpan> _kemeticSpans = const [];
  List<_WeekSpan> _weekSpans = const [];
  final Map<String, Set<int>> _perDecanSel = {}; // key: "ky-km-di", values: {1..10}
  final Map<String, Set<int>> _perWeekSel = {};  // key: monday ISO "yyyy-mm-dd", values: {1..7}

  // editors
  final Map<String, List<_NoteDraft>> _draftsByDay = {};     // key: "ky-km-kd" (customize mode) - supports multiple notes per day
  final Map<String, _NoteDraft> _draftsByPattern = {}; // key: "DD-n" or "WD-wd" (repeat mode)
  final GlobalKey _editorsAnchorKey = GlobalKey();
  
  // analytics
  int _originalEventCount = 0;  // Store count of AI-generated events

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
    final month = getMonthById(k.kMonth).displayFull;
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

  _FlowStudioDraft? _captureDraft() {
    final hasContent = _nameCtrl.text.trim().isNotEmpty ||
        _overviewCtrl.text.trim().isNotEmpty ||
        _draftsByDay.isNotEmpty ||
        _draftsByPattern.isNotEmpty ||
        _startDate != null ||
        _endDate != null;

    if (!hasContent) return null;

    Map<String, List<_DraftNoteData>> cloneDraftsByDay = {};
    _draftsByDay.forEach((k, list) {
      cloneDraftsByDay[k] = list.map(_DraftNoteData.fromDraft).toList();
    });

    final cloneDraftsByPattern = _draftsByPattern.map(
      (k, v) => MapEntry(k, _DraftNoteData.fromDraft(v)),
    );

    return _FlowStudioDraft(
      editingFlowId: _editing?.id,
      editingIsHidden: _editing?.isHidden ?? false,
      name: _nameCtrl.text,
      active: _active,
      selectedColorIndex: _selectedColorIndex,
      useKemetic: _useKemetic,
      startDate: _startDate,
      endDate: _endDate,
      splitByPeriod: _splitByPeriod,
      selectedDecanDays: Set<int>.from(_selectedDecanDays),
      selectedWeekdays: Set<int>.from(_selectedWeekdays),
      perDecanSel: _perDecanSel.map((k, v) => MapEntry(k, Set<int>.from(v))),
      perWeekSel: _perWeekSel.map((k, v) => MapEntry(k, Set<int>.from(v))),
      draftsByDay: cloneDraftsByDay,
      draftsByPattern: cloneDraftsByPattern,
      overview: _overviewCtrl.text,
      isAIGeneratedFlow: _isAIGeneratedFlow,
    );
  }

  void _restoreDraft(_FlowStudioDraft draft) {
    setState(() {
      // Recreate minimal editing stub if we need to preserve the ID/hidden status
      if (draft.editingFlowId != null) {
        final colorIdx = draft.selectedColorIndex.clamp(0, _flowPalette.length - 1);
        _editing = _Flow(
          id: draft.editingFlowId!,
          name: draft.name.isEmpty ? '' : draft.name,
          color: _flowPalette[colorIdx],
          active: draft.active,
          rules: const [],
          start: draft.startDate,
          end: draft.endDate,
          notes: '',
          isHidden: draft.editingIsHidden,
          shareId: null,
        );
      } else {
        _editing = null;
      }

      _nameCtrl.text = draft.name;
      _active = draft.active;
      _selectedColorIndex = draft.selectedColorIndex.clamp(0, _flowPalette.length - 1);
      _useKemetic = draft.useKemetic;
      _startDate = draft.startDate;
      _endDate = draft.endDate;
      _splitByPeriod = draft.splitByPeriod;
      _selectedDecanDays
        ..clear()
        ..addAll(draft.selectedDecanDays);
      _selectedWeekdays
        ..clear()
        ..addAll(draft.selectedWeekdays);
      _perDecanSel
        ..clear()
        ..addAll(draft.perDecanSel.map((k, v) => MapEntry(k, Set<int>.from(v))));
      _perWeekSel
        ..clear()
        ..addAll(draft.perWeekSel.map((k, v) => MapEntry(k, Set<int>.from(v))));

      // Rebuild drafts
      for (final list in _draftsByDay.values) {
        for (final d in list) {
          d.dispose();
        }
      }
      for (final d in _draftsByPattern.values) {
        d.dispose();
      }
      _draftsByDay
        ..clear()
        ..addAll(draft.draftsByDay.map((k, list) =>
            MapEntry(k, list.map((n) => n.toDraft()).toList())));
      _draftsByPattern
        ..clear()
        ..addAll(draft.draftsByPattern.map((k, n) => MapEntry(k, n.toDraft())));

      _overviewCtrl.text = draft.overview;
      _isAIGeneratedFlow = draft.isAIGeneratedFlow;

      _syncReady = true;
      _rebuildSpans();
    });
  }

  void _clearSessionDraft() {
    _sessionDraft = null;
  }


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
            '${getMonthById(d.km).displayFull} ${d.kd}  •  ${_fmtGregorian(d.g)}',
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

  List<_EditorGroup> _groupsFromDraftsFallback() {
    if (_draftsByDay.isEmpty) return const [];
    final out = <_EditorGroup>[];

    for (final entry in _draftsByDay.entries) {
      final key = entry.key; // "ky-km-kd"
      final parts = key.split('-');
      if (parts.length != 3) continue;

      final ky = int.tryParse(parts[0]) ?? 0;
      final km = int.tryParse(parts[1]) ?? 0;
      final kd = int.tryParse(parts[2]) ?? 0;

      // Skip invalid kemetic keys
      if (ky <= 0 || km <= 0 || kd <= 0) continue;

      // Convert to Gregorian; skip if conversion fails (throws ArgumentError)
      DateTime g;
      try {
        g = KemeticMath.toGregorian(ky, km, kd);
      } catch (_) {
        continue; // Invalid date, skip this entry
      }

      final header = '${getMonthById(km).displayFull} $kd  •  ${_fmtGregorian(g)}';

      out.add(
        _EditorGroup(
          key: key,
          isPattern: false,
          header: header,
          days: [
            _SelectedDay(key, ky, km, kd, g),
          ],
        ),
      );
    }

    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
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
            final key = dayKey(s.ky, s.km, kd);
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
            final key = dayKey(k.kYear, k.kMonth, k.kDay);
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
            final key = dayKey(k.kYear, k.kMonth, k.kDay);
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, d));
          }
        }
      } else {
        for (DateTime d = _startDate!;
        !d.isAfter(_endDate!);
        d = d.add(const Duration(days: 1))) {
          if (_selectedWeekdays.contains(d.weekday)) {
            final k = KemeticMath.fromGregorian(d);
            final key = dayKey(k.kYear, k.kMonth, k.kDay);
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
    // Hard gate: never sync while not ready.
    if (!_syncReady) return;

    final groups = _buildEditorGroups();

    // Day-draft syncing (customize mode).
    final wantDayKeys = {
      for (final g in groups.where((g) => !g.isPattern)) g.key
    };

    if (_hasFullRange) {
      // Remove only keys that are NOT wanted AND are empty shells.
      final removeDay = _draftsByDay.keys
          .where((k) => !wantDayKeys.contains(k))
          .toList();

      for (final k in removeDay) {
        final list = _draftsByDay[k];
        if (list == null || list.isEmpty) {
          for (final draft in list ?? []) {
            draft.dispose();
          }
          _draftsByDay.remove(k);
        }
      }

      // Seed missing wanted keys (one empty draft per day in customize mode).
      for (final k in wantDayKeys) {
        final existing = _draftsByDay[k];
        if (existing == null || existing.isEmpty) {
          if (!_draftsByDay.containsKey(k) || (_draftsByDay[k]?.isEmpty ?? true)) {
            _draftsByDay.putIfAbsent(
              k,
              () => _splitByPeriod ? <_NoteDraft>[_NoteDraft()] : <_NoteDraft>[],
            );
          }
        }
      }
    }
    // When !_hasFullRange: do not remove/seed; fallback render will show seeded shells.

    // Pattern-draft syncing (repeat mode).
    final wantPatKeys = {
      for (final g in groups.where((g) => g.isPattern)) g.key
    };

    if (_hasFullRange) {
      final removePat = _draftsByPattern.keys
          .where((k) => !wantPatKeys.contains(k))
          .toList();
      for (final k in removePat) {
        _draftsByPattern[k]?.dispose();
        _draftsByPattern.remove(k);
      }
    }
    for (final k in wantPatKeys) {
      _draftsByPattern.putIfAbsent(k, () => _NoteDraft());
    }

    setState(() {}); // Trigger UI update
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
      // IMPORTANT: do NOT call _syncDraftsWithSelection() here
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
        final monthName = getMonthById(k.kMonth).displayFull;
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

    // Only sync if we are ready AND we have a full range.
    if (_syncReady && _hasFullRange) {
      _syncDraftsWithSelection();
    }
  }

  /// Centralizes: "rebuild spans then (if ready) sync".
  /// NOTE: _rebuildSpans() already calls _syncDraftsWithSelection()
  /// when _syncReady && _hasFullRange, so we do not call it again here.
  void _applySelectionToDrafts() {
    _rebuildSpans();
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
      backgroundColor: Colors.black,
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

                  const GlossyText(
                    text: 'Pick Gregorian date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: blueGloss,
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
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                                child: GlossyText(
                                  text: '$dd',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                                child: GlossyText(
                                  text: '$yy',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                            side: const BorderSide(color: silver, width: 1.25),
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
      backgroundColor: Colors.black,
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
                  const GlossyText(
                    text: 'Pick Kemetic date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: goldGloss, // <- gold gleam
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
                              final label = getMonthById(m).displayFull;
                              return Center(
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                                child: GlossyText(
                                  text: '$d',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
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
                            side: const BorderSide(color: silver, width: 1.25),
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
                          child: const GlossyText(
                            text: 'Done',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            gradient: whiteGloss, // subtle sheen on the label
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
      _applySelectionToDrafts();
    }
  }

  Future<void> _pickRangeEnd() async {
    final picked = _useKemetic
        ? await _pickKemeticDate(initial: _endDate ?? _startDate)
        : await _pickGregorianDate(initial: _endDate ?? _startDate);
    if (picked != null) {
      setState(() => _endDate = _dateOnly(picked));
      _applySelectionToDrafts();
    }
  }


  // ---------- Overview support ----------

  final TextEditingController _overviewCtrl = TextEditingController();


  Future<void> _openOverviewEditor() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
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
              const GlossyText(
                text: 'Flow overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                gradient: silverGloss,
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
                        side: const BorderSide(color: silver, width: 1.25),
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
    List<_EditorGroup> groups = _buildEditorGroups();
    // Fallback: if selection/range isn't ready but drafts exist, render from drafts.
    if (groups.isEmpty) {
      if (_draftsByDay.isNotEmpty) {
        groups = _groupsFromDraftsFallback();
        if (groups.isEmpty) return const SizedBox.shrink();
      } else {
        return const SizedBox.shrink();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const GlossyText(
          text: 'Notes for selection',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 8),
        ...groups.expand((g) {
          // For customize mode: return multiple cards (one per draft in the list)
          if (!g.isPattern && _draftsByDay[g.key] != null) {
            final drafts = _draftsByDay[g.key]!;
            return drafts.asMap().entries.map((entry) {
              final index = entry.key;
              final draft = entry.value;
              return Padding(
                key: ValueKey('${g.key}-$index'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Colors.black,
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
                        GlossyText(
                          text: g.header,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          gradient: silverGloss,
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
                          title: const GlossyText(
                            text: 'All-day',
                            style: TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
            });
          }
          // For pattern mode or empty list: skip
          return [];
        }),
      ],
    );
  }

  // ---------- save/delete ----------

  /// Show AI Flow Generation Modal
  Future<void> _showAIGenerationModal() async {
    final result = await showModalBottomSheet<AIFlowGenerationResponse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AIFlowGenerationModal(),
    );

    if (result != null && result.flowId != null && mounted) {
      // AI generated a flow! Close modal and open Flow Studio with the generated flow
      Navigator.pop(context); // Close AI generation modal
      
      // Open Flow Studio with the generated flow ID
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FlowStudioPage(
            existingFlows: const [], // Will be loaded from editFlowId
            editFlowId: result.flowId,
          ),
        ),
      );
      
      // Refresh calendar after Flow Studio closes
      if (mounted) {
        setState(() {});
      }
    }
  }

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

    final rules = <FlowRule>[];

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
      // per-day drafts (handle multiple drafts per day)
      for (final g in groups) {
        final d = g.days.first;
        final drafts = _draftsByDay[d.key];
        if (drafts == null || drafts.isEmpty) continue;
        
        // Loop through all drafts for this day
        for (final draft in drafts) {
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

    // ✅ For imported flows, clear rules to prevent rule-based rescheduling
    // This ensures snapshot events are the single source of truth
    final bool isImportedFlow = widget.importData != null;
    final List<FlowRule> rulesToSave = isImportedFlow ? <FlowRule>[] : rules;

    final flow = _Flow(
      id: _editing?.id ?? -1,
      name: name,
      color: _flowPalette[_selectedColorIndex],
      active: _active,
      rules: rulesToSave, // ✅ Empty rules for imported flows
      start: _startDate,
      end: _endDate,
      notes: notes,
      shareId: null,
      isHidden: _editing?.isHidden ?? false, // Preserve hidden status if editing
    );

    // Reset AI mode flag after save - flow is now a normal editable flow
    if (_isAIGeneratedFlow) {
      _isAIGeneratedFlow = false;
    }

    _clearSessionDraft();
    _suppressDraftSave = true;
    Navigator.of(context, rootNavigator: true)
        .pop(_FlowStudioResult(savedFlow: flow, plannedNotes: planned));
  }

  void _delete() {
    if (_editing == null) return;
    _clearSessionDraft();
    _suppressDraftSave = true;
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
      backgroundColor: Colors.black,
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
                  const GlossyText(
                    text: 'Find / Edit a flow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: silverGloss,
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
                            side: const BorderSide(color: silver, width: 1.25),
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
          onAppendToJournal: null,
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

      for (final dayList in _draftsByDay.values) { 
        for (final d in dayList) { d.dispose(); }
      }
      for (final d in _draftsByPattern.values) { d.dispose(); }
      _draftsByDay.clear();
      _draftsByPattern.clear();

      _overviewCtrl.text = '';

      _syncReady = false; // prevent any sync during wipe/reset
      _rebuildSpans(); // clears spans; no sync happens
    });

    _clearSessionDraft();
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
      _overviewCtrl.text = _effectiveOverview(f.notes, meta.overview);

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

      // refresh UI with new selections
      _syncReady = true;
      _applySelectionToDrafts();
    });
  }

  /// Load AI-generated flow by ID and populate Flow Studio
  Future<void> _loadAIGeneratedFlow(int flowId) async {
    try {
      // 1. Fetch the flow from database
      final repo = FlowsRepo(Supabase.instance.client);
      final flow = await repo.getFlowById(flowId);
      if (flow == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Flow not found')),
          );
        }
        return;
      }
      
      // 2. Convert FlowRow to _Flow
      final flowObj = _Flow(
        id: flow.id,
        name: flow.name,
        color: Color(rgbToArgb(flow.color)),
        active: flow.active,
        start: flow.startDate,
        end: flow.endDate,
        notes: flow.notes,
        rules: const [],  // AI flows have no recurring rules
        shareId: null,
        isHidden: flow.isHidden, // Preserve hidden flag if present
      );
      
      // 3. Fetch events for this flow
      final eventsRepo = UserEventsRepo(Supabase.instance.client);
      final eventRecords = await eventsRepo.getEventsForFlow(flowId);
      
      // Convert record type to UserEvent objects
      final userEvents = eventRecords.map((record) {
        return UserEvent(
          id: record.id ?? '', // id is String? (UUID from database)
          clientEventId: record.clientEventId,
        title: record.title,
        detail: record.detail,
        location: record.location,
        allDay: record.allDay,
        startsAt: record.startsAtUtc,
        endsAt: record.endsAtUtc,
        flowLocalId: record.flowLocalId,
        category: record.category,
      );
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      // Dedupe by id/cid/composite to avoid duplicate drafts
      final seen = <String, UserEvent>{};
      for (final e in userEvents) {
        String key;
        if (e.id.isNotEmpty) {
          key = 'id:${e.id}';
        } else if (e.clientEventId != null) {
          key = 'cid:${e.clientEventId}';
        } else {
          final endKey = e.endsAt?.toIso8601String() ?? 'NO_END';
          key = 'cmp|${e.title.trim().toLowerCase()}|${e.startsAt.toIso8601String()}|$endKey|${e.allDay}';
        }
        if (!seen.containsKey(key)) {
          seen[key] = e;
        }
      }
      final dedupedEvents = seen.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      
      if (kDebugMode) {
        print('🔍 [AI Flow Init] flowId: $flowId');
        print('🔍 [AI Flow Init] userEvents.length: ${userEvents.length}');
        print('🔍 [AI Flow Init] titles: ${userEvents.map((e) => e.title).toList()}');
      }
      
      // 4. 🚨 CRITICAL ORDERING: Set context BEFORE initializing selections
      // _populateGregorianSelections() needs _startDate to calculate week indices
      // _convertEventsToDrafts() needs _useKemetic to build correct date keys
      final meta = notesDecode(flowObj.notes);
      _startDate = flowObj.start == null ? null : _dateOnly(flowObj.start!);
      _endDate = flowObj.end == null ? null : _dateOnly(flowObj.end!);
      _useKemetic = meta.kemetic;
      _splitByPeriod = true;  // Force customize mode for AI flows
      
      _syncReady = true;
      // 5. Build spans now that mode is known
      _rebuildSpans();
      
      // 6. Graceful fallback if no events loaded
      if (userEvents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "We created your Flow but couldn't load scheduled blocks. You can add blocks below.",
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        // Manual hydration of header fields (no _loadFlowForEdit call)
        setState(() {
          _editing = flowObj;
          _nameCtrl.text = flowObj.name;
          _active = flowObj.active;
          
          final idx = _flowPalette.indexWhere((c) => c.value == flowObj.color.value);
          _selectedColorIndex = idx >= 0 ? idx : 0;
          
          _overviewCtrl.text = _effectiveOverview(flowObj.notes, meta.overview);
          
          _isAIGeneratedFlow = true;
        });
        return;
      }
      
      // 7. NOW initialize AI flow selections (depends on _startDate, _endDate, _useKemetic set above)
      // Convert events to drafts and populate _draftsByDay
      _convertEventsToDrafts(
        dedupedEvents,
        renumberAiTitles: true,
        startDateForRenumbering: _startDate,
        forceTimedDrafts: true,
      );
      
      // 8. Clear and populate selection state
      _perWeekSel.clear();
      _perDecanSel.clear();
      
      if (_hasFullRange && _draftsByDay.isNotEmpty) {
        if (_useKemetic) {
          _populateKemeticSelections(dedupedEvents);
        } else {
          _populateGregorianSelections(dedupedEvents);
        }
      }

      _applySelectionToDrafts(); // one entry point
      
      // 9. Count ALL notes for analytics
      _originalEventCount = _draftsByDay.values
          .fold<int>(0, (sum, list) => sum + list.length);
      
      if (kDebugMode) {
        print('🔍 [AI Flow Init] _originalEventCount: $_originalEventCount (days: ${_draftsByDay.keys.length})');
      }
      
      // 10. 🔑 CRITICAL: Manually hydrate header fields WITHOUT calling _loadFlowForEdit()
      setState(() {
        _editing = flowObj;
        
        // Header fields only
        _nameCtrl.text = flowObj.name;
        _active = flowObj.active;
        
        // Color picker
        final idx = _flowPalette.indexWhere((c) => c.value == flowObj.color.value);
        _selectedColorIndex = idx >= 0 ? idx : 0;
        
        // Overview
        _overviewCtrl.text = _effectiveOverview(flowObj.notes, meta.overview);
        
        // 🚨 LOCK IN AI MODE - this prevents _loadFlowForEdit from being called
        _isAIGeneratedFlow = true;
        
        // Note: _startDate, _endDate, _useKemetic, _splitByPeriod already set above
      });
      
      // 11. Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('✨ Generated "${flowObj.name}" with ${userEvents.length} events. Review and save!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E3A5F),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading AI flow: $e')),
        );
      }
    }
  }

  /// Load a flow by ID from database (for imported or AI flows not in existingFlows)
  Future<void> _loadFlowByIdFromDb(int flowId) async {
    if (kDebugMode) {
      print('🔍 [LoadFlow] START: flowId=$flowId');
    }
    
    final flowsRepo = FlowsRepo(Supabase.instance.client);
    final eventsRepo = UserEventsRepo(Supabase.instance.client);
    
    // 1️⃣ Load the flow row
    final flowRow = await flowsRepo.getFlowById(flowId);
    if (flowRow == null) {
      if (kDebugMode) {
        print('🔍 [LoadFlow] ERROR: Flow not found');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flow not found')),
        );
      }
      return;
    }

    if (kDebugMode) {
      print('🔍 [LoadFlow] Flow found: name="${flowRow.name}", startDate=${flowRow.startDate}, endDate=${flowRow.endDate}');
    }

    // If this is an AI-generated flow, keep the existing AI path
    final isAiGenerated = (flowRow.aiMetadata?['generated'] as bool?) == true;
    if (isAiGenerated) {
      if (kDebugMode) {
        print('🔍 [LoadFlow] Detected AI flow, delegating to _loadAIGeneratedFlow');
      }
      await _loadAIGeneratedFlow(flowId);
      return;
    }

    // 2️⃣ Load all events for this flow (this is what the importer writes)
    final eventRecords = await eventsRepo.getEventsForFlow(flowId);
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] Loaded ${eventRecords.length} event records');
    }
    
    // ✅ CORRECTED: Map records → UserEvent using the same helper as AI path
    final userEvents = eventRecords.map((record) {
      return UserEvent(
        id: record.id ?? '',
        clientEventId: record.clientEventId,
        title: record.title,
        detail: record.detail,
        location: record.location,
        allDay: record.allDay,
        startsAt: record.startsAtUtc,
        endsAt: record.endsAtUtc,
        flowLocalId: record.flowLocalId,
        category: record.category,
      );
    }).toList();

    // If there are *no* events, fall back to the existing rule-based loader
    if (userEvents.isEmpty) {
      if (kDebugMode) {
        print('🔍 [LoadFlow] No events found, using rule-based loader fallback');
      }
      final rules = flowRow.rules
          .map((r) => CalendarPage.ruleFromJson(r as Map<String, dynamic>))
          .toList();

      final f = _Flow(
        id: flowRow.id,
        name: flowRow.name,
        color: Color(rgbToArgb(flowRow.color)),
        active: flowRow.active,
        start: flowRow.startDate,
        end: flowRow.endDate,
        notes: flowRow.notes,
        rules: rules,
        shareId: null,
        isHidden: false,
      );

      _editing = f;
      _nameCtrl.text = f.name;
      _active = f.active;
      _loadFlowForEdit(f);
      return;
    }

    // 3️⃣ Calculate start / end dates from the imported events
    userEvents.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final firstDate = userEvents.first.startsAt.toLocal();
    final lastDate = userEvents.last.startsAt.toLocal();
    final startDate = _dateOnly(flowRow.startDate ?? firstDate);
    final endDate = _dateOnly(flowRow.endDate ?? lastDate);

    if (kDebugMode) {
      print('🔍 [LoadFlow] Calculated dates:');
      print('  firstDate from events: $firstDate');
      print('  lastDate from events: $lastDate');
      print('  flowRow.startDate: ${flowRow.startDate}');
      print('  flowRow.endDate: ${flowRow.endDate}');
      print('  final startDate: $startDate');
      print('  final endDate: $endDate');
    }

    // 4️⃣ Build _Flow model for the editor
    final rules = flowRow.rules
        .map((r) => CalendarPage.ruleFromJson(r as Map<String, dynamic>))
        .toList();

    final f = _Flow(
      id: flowRow.id,
      name: flowRow.name,
      color: Color(rgbToArgb(flowRow.color)),
      active: flowRow.active,
      start: startDate,
      end: endDate,
      notes: flowRow.notes,
      rules: rules,
      shareId: null,
      isHidden: false,
    );

    // 5️⃣ Decode notes meta (overview, kemetic flag, split)
    final meta = notesDecode(f.notes);
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] Decoded meta: kemetic=${meta.kemetic}, overview="${meta.overview}"');
    }
    
    // Clear existing drafts before converting
    for (final dayList in _draftsByDay.values) {
      for (final draft in dayList) {
        draft.dispose();
      }
    }
    _draftsByDay.clear();

    // 6️⃣ 🚨 CRITICAL ORDERING: Set context BEFORE initializing selections
    // _populateGregorianSelections() needs _startDate to calculate week indices
    // _convertEventsToDrafts() needs _useKemetic to build correct date keys
    // Match AI flow path EXACTLY: set dates OUTSIDE setState
    _startDate = startDate;
    _endDate = endDate;
    _useKemetic = meta.kemetic;
    _splitByPeriod = true;  // imported flows behave like customize mode
    _syncReady = true;
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] Set state variables OUTSIDE setState:');
      print('  _startDate: $_startDate');
      print('  _endDate: $_endDate');
      print('  _useKemetic: $_useKemetic');
      print('  _splitByPeriod: $_splitByPeriod');
      print('  _syncReady: $_syncReady');
      print('  _hasFullRange: $_hasFullRange');
    }
    
    // 7️⃣ Build spans now that mode is known (BEFORE converting events, like AI path)
    if (kDebugMode) {
      print('🔍 [LoadFlow] Calling _rebuildSpans() (first call)');
    }
    _rebuildSpans();
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] After first _rebuildSpans():');
      print('  _kemeticSpans.length: ${_kemeticSpans.length}');
      print('  _weekSpans.length: ${_weekSpans.length}');
    }
    
    // 8️⃣ NOW convert events → drafts (same helper AI uses)
    if (kDebugMode) {
      print('🔍 [LoadFlow] Converting ${userEvents.length} events to drafts');
    }
    _convertEventsToDrafts(userEvents);

    if (kDebugMode) {
      print('🔍 [LoadFlow] After _convertEventsToDrafts():');
      print('  _draftsByDay.length: ${_draftsByDay.length}');
      print('  _draftsByDay.keys: ${_draftsByDay.keys.toList()}');
    }

    // 9️⃣ Clear and populate selection state
    _perWeekSel.clear();
    _perDecanSel.clear();
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] Populating selections: _hasFullRange=$_hasFullRange, _draftsByDay.isNotEmpty=${_draftsByDay.isNotEmpty}');
    }
    
    if (_hasFullRange && _draftsByDay.isNotEmpty) {
      if (_useKemetic) {
        _populateKemeticSelections(userEvents);
      } else {
        _populateGregorianSelections(userEvents);
      }
      
      if (kDebugMode) {
        print('🔍 [LoadFlow] After populating selections:');
        print('  _perDecanSel.length: ${_perDecanSel.length}');
        print('  _perWeekSel.length: ${_perWeekSel.length}');
      }
    } else {
      if (kDebugMode) {
        print('🔍 [LoadFlow] SKIPPED selection population: _hasFullRange=$_hasFullRange, _draftsByDay.isNotEmpty=${_draftsByDay.isNotEmpty}');
      }
    }

    // 🔟 Apply selections to drafts (calls _rebuildSpans() again, like AI path)
    if (kDebugMode) {
      print('🔍 [LoadFlow] Calling _applySelectionToDrafts() (will call _rebuildSpans() again)');
    }
    _applySelectionToDrafts();
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] After _applySelectionToDrafts():');
      print('  _kemeticSpans.length: ${_kemeticSpans.length}');
      print('  _weekSpans.length: ${_weekSpans.length}');
    }

    // 1️⃣1️⃣ 🔑 CRITICAL: Manually hydrate header fields WITHOUT setting dates again
    // Match AI flow path: dates already set above, only set header fields here
    if (!mounted) {
      if (kDebugMode) {
        print('🔍 [LoadFlow] ERROR: Widget not mounted, aborting setState');
      }
      return;
    }
    
    if (kDebugMode) {
      print('🔍 [LoadFlow] About to call setState with header fields:');
      print('  _editing will be: ${f.name}');
      print('  _startDate (already set): $_startDate');
      print('  _endDate (already set): $_endDate');
    }
    
    setState(() {
      _editing = f;
      _nameCtrl.text = f.name;
      _active = f.active;
      
      final idx = _flowPalette.indexWhere((c) => c.value == f.color.value);
      _selectedColorIndex = idx >= 0 ? idx : 0;
      
      _overviewCtrl.text = _effectiveOverview(f.notes, meta.overview);
      
      // ⛔️ Do NOT set dates here - they're already set above (like AI path)
      // ⛔️ Do NOT set _useKemetic, _splitByPeriod, _syncReady - already set above
      // ⛔️ Do NOT set _isAIGeneratedFlow - this is an imported flow
    });

    if (kDebugMode) {
      print('🔍 [LoadFlow] After setState:');
      print('  _editing: ${_editing?.name}');
      print('  _startDate: $_startDate');
      print('  _endDate: $_endDate');
      print('  _hasFullRange: $_hasFullRange');
      print('  _draftsByDay.length: ${_draftsByDay.length}');
      print('  _kemeticSpans.length: ${_kemeticSpans.length}');
      print('  _weekSpans.length: ${_weekSpans.length}');
      print('🔍 [LoadFlow] END');
    }
  }

  /// Populate Kemetic selections based on events
  void _populateKemeticSelections(List<UserEvent> events) {
    for (final event in events) {
      final localStart = event.startsAt.toLocal();
      final (:kYear, :kMonth, :kDay) = KemeticMath.fromGregorian(localStart);
      
      // Calculate decan index and day within decan
      final di = ((kDay - 1) ~/ 10); // decan index (0-3)
      final inDec = ((kDay - 1) % 10) + 1; // day in decan (1-10)
      final key = '$kYear-$kMonth-$di';
      
      final set = _perDecanSel[key] ?? <int>{};
      set.add(inDec);
      _perDecanSel[key] = set;
    }
  }

  /// Populate Gregorian weekday selections based on events
  void _populateGregorianSelections(List<UserEvent> events) {
    for (final event in events) {
      final localStart = event.startsAt.toLocal();
      final mondayOfWeek = _mondayOf(localStart);
      final weekKey = _iso(mondayOfWeek);
      final weekday = localStart.weekday;
      
      final set = _perWeekSel[weekKey] ?? <int>{};
      set.add(weekday);
      _perWeekSel[weekKey] = set;
    }
  }

  /// Convert database events to _NoteDraft objects in _draftsByDay
  /// ✅ Handles multiple events per day correctly (Map of Lists)
  void _convertEventsToDrafts(
    List<UserEvent> events, {
    bool renumberAiTitles = false,
    DateTime? startDateForRenumbering,
    bool forceTimedDrafts = false,
  }) {
    // Step 1: Dispose all existing drafts properly (nested loop for lists)
    for (final dayList in _draftsByDay.values) {
      for (final draft in dayList) {
        draft.dispose();
      }
    }
    _draftsByDay.clear();
    
    final dayLabelRegex = RegExp(r'^day\s+(\d+)', caseSensitive: false);

    for (final event in events) {
      // Convert UTC to local
      final localStart = event.startsAt.toLocal();
      final localEnd = event.endsAt?.toLocal();
      final startDateOnly = _dateOnly(localStart);

      // Renumber common "Day X" prefixes so the first block is always Day 1
      String title = event.title;
      if (renumberAiTitles && startDateForRenumbering != null) {
        final dayOffset =
            startDateOnly.difference(_dateOnly(startDateForRenumbering)).inDays +
                1; // clamp below handled by regex guard
        if (dayOffset > 0) {
          final m = dayLabelRegex.firstMatch(title.trim());
          if (m != null) {
            title = title.replaceRange(
              m.start,
              m.end,
              'Day $dayOffset',
            );
          }
        }
      }
      
      // Get Kemetic date
      final (:kYear, :kMonth, :kDay) = KemeticMath.fromGregorian(localStart);
      final dateKey = dayKey(kYear, kMonth, kDay);
      
      // Create draft
      final draft = _NoteDraft();
      
      // Populate controllers
      draft.titleCtrl.text = title;
      draft.locationCtrl.text = event.location ?? '';
      draft.detailCtrl.text = event.detail ?? '';
      
      // Set times
      final hasExplicitTime =
          (localStart.hour != 0 || localStart.minute != 0) ||
              (localEnd != null &&
                  (localEnd.hour != 0 || localEnd.minute != 0));

      final treatAsTimed = forceTimedDrafts || (!event.allDay || hasExplicitTime);
      draft.allDay = treatAsTimed ? false : event.allDay;

      if (treatAsTimed) {
        final startTime = (localStart.hour == 0 && localStart.minute == 0 && forceTimedDrafts)
            ? const TimeOfDay(hour: 12, minute: 0)
            : TimeOfDay(hour: localStart.hour, minute: localStart.minute);

        draft.start = startTime;

        if (localEnd != null) {
          draft.end = TimeOfDay(
            hour: localEnd.hour,
            minute: localEnd.minute,
          );
        } else {
          draft.end = _addMinutes(startTime, 60);
        }
      }
      
      // ✅ CRITICAL: Append to list, don't overwrite (multiple events per day)
      final listForDay = _draftsByDay[dateKey] ?? <_NoteDraft>[];
      listForDay.add(draft);
      _draftsByDay[dateKey] = listForDay;
      
      if (kDebugMode) {
        print('🔍 [Draft] $dateKey → title: "${draft.titleCtrl.text}" (${listForDay.length} total)');
      }
    }
  }

  // ---------- scaffold ----------

  /// Initialize Flow Studio from inbox import data
  Future<void> _initializeFromImport(ImportFlowData data) async {
    _nameCtrl = TextEditingController(text: data.name);
    _active = true;
    _isLoadingFlow = true;
    setState(() {});

    try {
      final colorIdx = _flowPalette.indexWhere((c) => c.value == data.color);
      _selectedColorIndex = colorIdx >= 0 ? colorIdx : 0;

      _startDate = data.suggestedStartDate != null
          ? _dateOnly(data.suggestedStartDate!)
          : _dateOnly(DateTime.now());

      if (data.notes != null) {
        try {
          final meta = notesDecode(data.notes!);
          _useKemetic = meta.kemetic;
          _splitByPeriod = meta.split;
          _overviewCtrl.text = _effectiveOverview(data.notes, meta.overview);
        } catch (_) {}
      } else {
        _useKemetic = false;
        _splitByPeriod = true;
      }

      final payload = data.share.payloadJson;
      final eventsJson = payload?['events'] as List<dynamic>?;

    if (eventsJson != null && eventsJson.isNotEmpty) {
      final baseDate = _startDate ?? DateTime.now();
      final userEvents = <UserEvent>[];
      for (final e in eventsJson) {
        try {
            final offset = (e['offset_days'] as num?)?.toInt() ?? 0;
            final date = baseDate.add(Duration(days: offset));

            int sh = 9, sm = 0;
            final st = e['start_time'] as String?;
            if (st != null && st.length >= 5) {
              sh = int.parse(st.substring(0, 2));
              sm = int.parse(st.substring(3, 5));
            }

            int? eh, em;
            final et = e['end_time'] as String?;
            if (et != null && et.length >= 5) {
              eh = int.parse(et.substring(0, 2));
              em = int.parse(et.substring(3, 5));
            }

            final allDay = e['all_day'] as bool? ?? false;
            final startsAt = DateTime(date.year, date.month, date.day, sh, sm);
            DateTime? endsAt;
            if (!allDay) {
              if (eh != null && em != null) {
                endsAt = DateTime(date.year, date.month, date.day, eh, em);
              } else {
                endsAt = startsAt.add(const Duration(hours: 1));
              }
            }

            userEvents.add(UserEvent(
              id: '',
              clientEventId: null,
              title: (e['title'] as String?) ?? data.name,
              detail: (e['detail'] as String?) ?? '',
              location: (e['location'] as String?) ?? '',
              allDay: allDay,
              startsAt: startsAt,
              endsAt: endsAt,
              flowLocalId: null,
              category: null,
            ));
          } catch (_) {
            // skip malformed event
          }
        }

        if (userEvents.isNotEmpty) {
          final allDates = userEvents
              .map((ev) => _dateOnly(ev.startsAt.toLocal()))
              .toList()
            ..sort();
          _endDate = allDates.last;
        } else {
          _endDate = _startDate;
        }

        _syncReady = false;
        _convertEventsToDrafts(userEvents);
        _rebuildSpans(); // safe while _syncReady is false
        if (_hasFullRange && _draftsByDay.isNotEmpty) {
          if (_useKemetic) {
            _populateKemeticSelections(userEvents);
          } else {
            _populateGregorianSelections(userEvents);
          }
          // Do NOT call _applySelectionToDrafts() here to avoid duplicates
        }
        if (mounted) {
          setState(() {
            _syncReady = true;
          });
        } else {
          _syncReady = true;
        }
      } else {
        _endDate = _startDate;
        _syncReady = true;
        _rebuildSpans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading import: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFlow = false;
        });
      }
    }
  }

  /// Helper to load a flow from DB with loading spinner
  void _loadFromDbWithSpinner(int flowId) {
    if (kDebugMode) {
      print('🔧 [FlowStudio] _loadFromDbWithSpinner: flowId=$flowId');
    }
    
    _nameCtrl = TextEditingController();
    _active = true;
    _isLoadingFlow = true;
    
    _loadFlowByIdFromDb(flowId).then((_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFlow = false;
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFlow = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading flow: $e')),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
      print('🔧 [FlowStudio] initState: editFlowId=${widget.editFlowId}, '
            'existingFlows=${widget.existingFlows.length}');
    }

    if (widget.importData != null) {
      _initializeFromImport(widget.importData!);
      return;
    }

    // Load flow if provided
    if (widget.editFlowId != null) {
      final id = widget.editFlowId!;
      final match = widget.existingFlows.where((f) => f.id == id).toList();

      if (match.isNotEmpty) {
        final flow = match.first;
        
        if (kDebugMode) {
          print('🔧 [FlowStudio] Found flow in existingFlows: id=$id, name="${flow.name}", shareId=${flow.shareId}');
        }
        
        // ✅ CRITICAL: If flow has shareId, it's imported and needs event-based loading
        // Imported flows have events in DB that _loadFlowForEdit doesn't load
        if (flow.shareId != null) {
          if (kDebugMode) {
            print('🔍 [FlowStudio] Import detected (shareId=${flow.shareId}) → using _loadFlowByIdFromDb');
          }
          _loadFromDbWithSpinner(id);
        } else if (flow.rules.isEmpty) {
          if (kDebugMode) {
            print('🔍 [FlowStudio] Snapshot-only flow detected (rules empty) → using _loadFlowByIdFromDb');
          }
          _loadFromDbWithSpinner(id);
        } else {
          if (kDebugMode) {
            print('📝 [FlowStudio] Local/custom flow → using _loadFlowForEdit');
          }
          // ✅ Flow is already in existingFlows and NOT imported → treat like normal/custom flow
          _editing = flow;
          _nameCtrl = TextEditingController(text: _editing!.name);
          _active = _editing!.active;
          _loadFlowForEdit(_editing!);
        }
      } else {
        if (kDebugMode) {
          print('🔎 [FlowStudio] Flow id=$id not in existingFlows → loading from DB');
        }
        // ✅ Flow not in existing list (AI or imported) → load from DB
        _loadFromDbWithSpinner(id);
      }
    } else {
      if (kDebugMode) {
        print('✨ [FlowStudio] New flow creation mode');
      }
      // Initialize for new flow creation
      _editing = null;
      _nameCtrl = TextEditingController();
      _active = true;
      _useKemetic = false;
      _splitByPeriod = true;
      _syncReady = true; // new editor can sync once range exists
      _rebuildSpans(); // harmless if range empty; no sync without range

      if (_sessionDraft != null) {
        _restoreDraft(_sessionDraft!);
        _sessionDraft = null;
      }
    }
  }

  @override
  void dispose() {
    if (!_suppressDraftSave) {
      _sessionDraft = _captureDraft();
    } else {
      _sessionDraft = null;
    }

    _nameCtrl.dispose();
    _overviewCtrl.dispose();
      for (final dayList in _draftsByDay.values) {
        for (final d in dayList) {
          d.dispose();
        }
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
        _applySelectionToDrafts();
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
        const GlossyText(
          text: 'Date range (optional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: silver, width: 1.25),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.1),
                ),
                onPressed: _pickRangeStart,
                child: Text(
                  startLabel,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: silver, width: 1.25),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.1),
                ),
                onPressed: _pickRangeEnd,
                child: Text(
                  endLabel,
                  style: const TextStyle(fontSize: 14),
                ),
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
        GlossyText(
          text: 'Set a start and end date to define rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
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
        _applySelectionToDrafts();
      },
      selectedColor: _gold.withOpacity(0.22),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: silver, width: 1.25),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1B1F),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Kemetic rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
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
                _applySelectionToDrafts();
              },
              child: const Text('Select all'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedDecanDays.clear());
                _applySelectionToDrafts();
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
        _applySelectionToDrafts();
      },
      selectedColor: _gold.withOpacity(0.22),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: silver, width: 1.25),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1B1F),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Gregorian rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
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
                _applySelectionToDrafts();
              },
              child: const Text('Select all'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedWeekdays.clear());
                _applySelectionToDrafts();
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
        const GlossyText(
          text: 'Kemetic rules • per decan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
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
                  _applySelectionToDrafts();
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
        const GlossyText(
          text: 'Gregorian rules • per week',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
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
                  _applySelectionToDrafts();
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
          _applySelectionToDrafts();
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

  // ---------- close handler ----------

  Future<void> _handleClose() async {
    // ✅ FIX: Check if we can actually pop
    if (!Navigator.of(context).canPop()) {
      print('[FlowStudio] ⚠️ Cannot pop - navigation stack empty');
      return;
    }

    // Check if this is an AI-generated flow that hasn't been saved yet
    final shouldDelete = _isAIGeneratedFlow && _editing != null && _editing!.id != null;
    
    if (shouldDelete) {
      // Confirm deletion
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Delete AI Flow?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This flow was generated by AI but hasn\'t been saved yet. '
            'Canceling will permanently delete it. Continue?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      
      if (confirm == true && _editing?.id != null) {
        try {
          // Delete events FIRST to avoid FK constraint violation
          final eventsRepo = UserEventsRepo(Supabase.instance.client);
          await eventsRepo.deleteByFlowId(_editing!.id);
          
          // Then delete the flow
          final flowsRepo = FlowsRepo(Supabase.instance.client);
          await flowsRepo.delete(_editing!.id);
          
          // ✅ FIX: Check mounted and canPop before popping
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.pop(context);
            
            // ✅ FIX: Use Future.microtask for snackbar after pop
            Future.microtask(() {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Flow deleted')),
                );
              }
            });
          }
          return;  // ← CRITICAL: Must return here
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting flow: $e')),
            );
          }
        }
      }
    }
    
    // Regular cancel (no deletion)
    // ✅ FIX: Check canPop again before final pop
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    // ✅ Show loading indicator while loading flow from DB
    if (_isLoadingFlow) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0.5,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _handleClose,
          ),
          title: const Text('Flow Studio', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _handleClose,
        ),
        title: const Text('Flow Studio', style: TextStyle(color: Colors.white)),
        actions: [
          // ✨ NEW: AI Generation Button
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37)),
            onPressed: _showAIGenerationModal,
            tooltip: 'Generate with AI',
          ),
          // Only show the dropdown when there's at least one existing flow
          if (widget.existingFlows.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Flows menu',
              icon: const Icon(Icons.more_vert, color: _silver),
              onSelected: (v) {
                if (v == 1) _openFlowPicker();
                if (v == 2) _clearEditorForNew();
                if (v == 3) _clearEditorForNew();
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
                PopupMenuItem(
                  value: 3,
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Reset fields'),
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
            const GlossyText(
              text: 'Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              gradient: silverGloss,
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

class _FlowPreviewPage extends StatefulWidget {
  const _FlowPreviewPage({
    required this.flow,
    required this.kemetic,
    required this.split,
    required this.overview,
    required this.getDecanLabel,
    required this.fmt,
    required this.onEdit,
    this.onAppendToJournal,
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
  final Future<void> Function(String text)? onAppendToJournal;

  /// if provided & [isMaatInstance] true, show a gold-outline "End Flow" button.
  final VoidCallback? onEndMaatFlow;
  final bool isMaatInstance;

  @override
  State<_FlowPreviewPage> createState() => _FlowPreviewPageState();
}

class _FlowPreviewPageState extends State<_FlowPreviewPage> {
  late final UserEventsRepo _userEventsRepo;

  // The record type matches getEventsForFlow() in user_events_repo.dart
  List<({
    String? id,
    String? clientEventId,
    String title,
    String? detail,
    String? location,
    bool allDay,
    DateTime startsAtUtc,
    DateTime? endsAtUtc,
    int? flowLocalId,
    String? category,
  })> _events = const [];

  bool _loadingEvents = false;
  Object? _eventsError;

  @override
  void initState() {
    super.initState();
    _userEventsRepo = UserEventsRepo(Supabase.instance.client);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
      _eventsError = null;
    });

    try {
      final events = await _userEventsRepo.getEventsForFlow(widget.flow.id);

      // Dedupe: merge entries that represent the same day/title/time even if their
      // client_event_id differs (prevents double-rendering). Prefer rows with a DB id,
      // then with clientEventId, else fallback.
      String _canonKey((
        {
          String? id,
          String? clientEventId,
          String title,
          String? detail,
          String? location,
          bool allDay,
          DateTime startsAtUtc,
          DateTime? endsAtUtc,
          int? flowLocalId,
          String? category,
        }
      ) e) {
        final titleKey = e.title.trim().toLowerCase();
        final startKey = e.startsAtUtc.toIso8601String();
        final endKey = e.endsAtUtc?.toIso8601String() ?? 'NO_END';
        final locKey = (e.location ?? '').trim().toLowerCase();
        final detailKey = (e.detail ?? '').trim().toLowerCase();
        final flowKey = (e.flowLocalId ?? -1).toString();
        return [
          titleKey,
          startKey,
          endKey,
          e.allDay ? 'allDay' : 'timed',
          locKey,
          detailKey,
          flowKey,
          (e.category ?? '').toLowerCase(),
        ].join('|');
      }

      int _quality((
        {
          String? id,
          String? clientEventId,
          String title,
          String? detail,
          String? location,
          bool allDay,
          DateTime startsAtUtc,
          DateTime? endsAtUtc,
          int? flowLocalId,
          String? category,
        }
      ) e) {
        if (e.id != null) return 3;
        if (e.clientEventId != null) return 2;
        return 1;
      }

      final merged = <String, ({
        String? id,
        String? clientEventId,
        String title,
        String? detail,
        String? location,
        bool allDay,
        DateTime startsAtUtc,
        DateTime? endsAtUtc,
        int? flowLocalId,
        String? category,
      })>{};

      for (final e in events) {
        final key = _canonKey(e);
        final existing = merged[key];
        if (existing == null || _quality(e) > _quality(existing)) {
          merged[key] = e;
        }
      }

      final deduped = merged.values.toList()
        ..sort((a, b) => a.startsAtUtc.compareTo(b.startsAtUtc));

      if (!mounted) return;
      setState(() {
        _events = deduped;
        _loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsError = e;
        _loadingEvents = false;
      });
    }
  }

  String _buildFlowBadgeToken() {
    DateTime start = widget.flow.start ?? DateTime.now();
    DateTime end = widget.flow.end ?? start.add(const Duration(hours: 1));
    if (_events.isNotEmpty) {
      start = _events.first.startsAtUtc.toLocal();
      end = (_events.first.endsAtUtc ?? start.add(const Duration(hours: 1))).toLocal();
    }
    final description = _effectiveOverview(widget.flow.notes, widget.overview);
    final id = 'badge-${DateTime.now().microsecondsSinceEpoch}';
    return EventBadgeToken.buildToken(
      id: id,
      title: widget.flow.name.isEmpty ? 'Flow block' : widget.flow.name,
      start: start,
      end: end,
      color: widget.flow.color,
      description: description,
    );
  }

  Future<void> _handleAddFlowToJournal() async {
    final cb = widget.onAppendToJournal;
    if (cb == null) return;
    final token = _buildFlowBadgeToken();
    try {
      await cb('$token ');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to journal'),
            backgroundColor: Color(0xFFFFC145),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  List<Widget> _buildSchedule(BuildContext context) {
    final rows = <TableRow>[];
    final flow = widget.flow;
    final kemetic = widget.kemetic;

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
          final name = '${getMonthById(k.kMonth).displayFull} • ${widget.getDecanLabel(k.kMonth, di)}';
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
    final flow = widget.flow;
    final displayOverview = _effectiveOverview(flow.notes, widget.overview);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Flow', style: TextStyle(color: Colors.white)),
        actions: [
          if (widget.isMaatInstance && widget.onEndMaatFlow != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                minimumSize: const Size(0, 35),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
              ),
              onPressed: widget.onEndMaatFlow,
              child: const Text('End Flow'),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37)), // ⋮ vertical dots
            tooltip: 'Flow options',
            onSelected: (value) async {
              if (value == 'journal') {
                await _handleAddFlowToJournal();
              } else if (value == 'edit') {
                widget.onEdit();
              } else if (value == 'share') {
                _openShareSheet(context, widget.flow);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'journal',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFFD4AF37)),
                    SizedBox(width: 12),
                    Text('Done / Add to journal', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Color(0xFFD4AF37)),
                    SizedBox(width: 12),
                    Text('Edit Flow', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Color(0xFFD4AF37)),
                    SizedBox(width: 12),
                    Text('Share Flow', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
            color: const Color(0xFF000000), // True black
          ),
        ],

      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Name
          GlossyText(
            text: flow.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            gradient: goldGloss,
          ),
          const SizedBox(height: 10),

          // Overview
          const GlossyText(
            text: 'Overview',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: silverGloss,
          ),
          const SizedBox(height: 6),
          Text(
            (displayOverview.isEmpty) ? '—' : displayOverview,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 16),

          // Date range + mode
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.kemetic ? 'Kemetic' : 'Gregorian',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                '${widget.fmt(flow.start)} → ${widget.fmt(flow.end)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Schedule
          const GlossyText(
            text: 'Schedule',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: silverGloss,
          ),
          const SizedBox(height: 6),
          ..._buildSchedule(context),
          
          const SizedBox(height: 24),

          // Days & Notes (event-level note fields)
          const GlossyText(
            text: 'Days & Notes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: silverGloss,
          ),
          const SizedBox(height: 6),
          if (_loadingEvents)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_eventsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Could not load flow days/notes.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
            )
          else if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No days or notes for this flow yet.',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            )
          else
            ..._events.map(_buildEventTile),
        ],
      ),
    );
  }

  Widget _buildEventTile((
    {
      String? id,
      String? clientEventId,
      String title,
      String? detail,
      String? location,
      bool allDay,
      DateTime startsAtUtc,
      DateTime? endsAtUtc,
      int? flowLocalId,
      String? category,
    }
  ) e) {
    final localStart = e.startsAtUtc.toLocal();
    final localEnd = e.endsAtUtc?.toLocal();
    bool _isCidDetail(String text) {
      final trimmed = text.trim().replaceAll(RegExp(r'\s+'), '');
      final withPrefix = trimmed.startsWith('kemet_cid:')
          ? trimmed.substring('kemet_cid:'.length)
          : trimmed;
      final cidPattern = RegExp(r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$');
      return cidPattern.hasMatch(withPrefix);
    }
    final detailText = _stripCidLines(e.detail?.trim() ?? '');
    final hasDetail = detailText.isNotEmpty && !_isCidDetail(detailText);
    final hasLocation = (e.location != null && e.location!.trim().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + date/time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  e.title.isEmpty ? '(Untitled day)' : e.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatEventTime(localStart, localEnd, e.allDay),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),

          if (hasDetail) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white),
                children: _buildDetailSpans(detailText),
              ),
            ),
          ],

          if (hasLocation) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchLocationFromPreview(e.location!.trim()),
              child: Text(
                e.location!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEventTime(
    DateTime start,
    DateTime? end,
    bool allDay,
  ) {
    if (allDay) {
      return widget.fmt(start);
    }

    final startTime = TimeOfDay.fromDateTime(start);
    final startTimeStr = startTime.format(context);

    if (end == null) {
      return '${widget.fmt(start)} · $startTimeStr';
    }

    final endTime = TimeOfDay.fromDateTime(end);
    final endTimeStr = endTime.format(context);

    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    if (sameDay) {
      return '${widget.fmt(start)} · $startTimeStr–$endTimeStr';
    }

    return '${widget.fmt(start)} $startTimeStr → ${widget.fmt(end)} $endTimeStr';
  }

  List<TextSpan> _buildDetailSpans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(https?://\S+)', multiLine: true);
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            color: Color(0xFF4DA3FF),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  bool _isLikelyUrl(String text) {
    final lower = text.toLowerCase().trim();
    
    // Already has protocol
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    
    // Email pattern (check early - most specific)
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
      return true;
    }
    
    // Phone number pattern (check for phone-like formatting)
    final phonePattern = RegExp(r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$');
    final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (phonePattern.hasMatch(lower) || (digitsOnly.length >= 10 && digitsOnly.length <= 15 && RegExp(r'^\+?[0-9]+$').hasMatch(digitsOnly))) {
      return true;
    }
    
    // Known service domains (most reliable)
    final knownServices = [
      r'zoom\.us',
      r'meet\.google\.com',
      r'youtube\.com',
      r'youtu\.be',
      r'facebook\.com',
      r'instagram\.com',
      r'twitter\.com',
      r'linkedin\.com',
      r'tiktok\.com',
      r'discord\.gg',
      r'slack\.com',
      r'teams\.microsoft\.com',
    ];
    
    for (final service in knownServices) {
      if (RegExp(service).hasMatch(lower)) {
        return true;
      }
    }
    
    // Generic domain pattern (but require at least one dot and TLD, no spaces)
    if (RegExp(r'^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}(/.*)?$').hasMatch(lower) && 
        lower.contains('.') && 
        !lower.contains(' ')) { // No spaces = likely URL, not address
      return true;
    }
    
    // www. prefix
    if (lower.startsWith('www\.')) {
      return true;
    }
    
    return false;
  }

  Future<void> _launchLocationFromPreview(String raw) async {
    final loc = raw.trim();
    if (loc.isEmpty) return;

    Uri uri;

    if (_isLikelyUrl(loc)) {
      final lower = loc.toLowerCase();

      // Already a full URL
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        uri = Uri.parse(loc);
      }
      // Email
      else if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
        uri = Uri.parse('mailto:$loc');
      }
      // Phone
      else {
        final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
        final phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
        if (phonePattern.hasMatch(digitsOnly)) {
          uri = Uri.parse('tel:$loc');
        } else {
          // Bare domain or known service → assume https
          uri = Uri.parse('https://$loc');
        }
      }
    } else {
      // Not URL/email/phone → treat as address (Maps)
      final q = Uri.encodeComponent(loc);
      uri = Uri.parse('https://maps.google.com/?q=$q');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _openShareSheet(BuildContext context, _Flow flow) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareFlowSheet(
        flowId: flow.id,
        flowTitle: flow.name,
      ),
    );
    
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flow shared successfully!'),
          backgroundColor: Color(0xFFD4AF37),
          duration: Duration(seconds: 2),
        ),
      );
    }
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

// Derive a human-friendly overview string, falling back to stored notes content
// (including repeating-note metadata) when the encoded overview is empty.
String _effectiveOverview(String? notes, String decodedOverview) {
  final trimmed = decodedOverview.trim();
  if (trimmed.isNotEmpty) return trimmed;

  final raw = (notes ?? '').trim();
  if (raw.isEmpty) return '';

  final repMeta = _decodeRepeatingNoteMetadata(notes);
  if (repMeta.detail?.trim().isNotEmpty == true) {
    return repMeta.detail!.trim();
  }

  return raw;
}

// Helper: encode detail and location for repeating notes in flow.notes
String? _encodeRepeatingNoteMetadata({String? detail, String? location, String? category}) {
  if (detail == null && location == null && category == null) return null;
  final parts = <String, dynamic>{'kind': 'repeating_note'};
  if (detail != null && detail.isNotEmpty) {
    parts['detail'] = detail;
  }
  if (location != null && location.isNotEmpty) {
    parts['location'] = location;
  }
  if (category != null && category.isNotEmpty) {
    parts['category'] = category;
  }
  return jsonEncode(parts);
}

// Helper: decode detail and location from flow.notes for repeating notes
({String? detail, String? location, String? category}) _decodeRepeatingNoteMetadata(String? notes) {
  if (notes == null || notes.isEmpty) return (detail: null, location: null, category: null);
  try {
    final meta = jsonDecode(notes) as Map<String, dynamic>;
    if (meta['kind'] == 'repeating_note') {
      return (
        detail: (meta['detail'] as String?)?.trim(),
        location: (meta['location'] as String?)?.trim(),
        category: (meta['category'] as String?)?.trim(),
      );
    }
  } catch (_) {
    // Not JSON or not our format
  }
  return (detail: null, location: null, category: null);
}

// Helper: clean event detail by stripping legacy flowLocalId= prefix
String _cleanDetail(String? s) {
  if (s == null || s.isEmpty) return '';
  var t = s;
  if (t.startsWith('flowLocalId=')) {
    final i = t.indexOf(';');
    t = (i >= 0 && i < t.length - 1) ? t.substring(i + 1) : '';
  }
  return t.trim();
}

// Helper: strip cid-only lines and legacy flowLocalId lines from detail text.
String _stripCidLines(String detail) {
  final lines = detail.split(RegExp(r'\r?\n'));
  final cidRegex = RegExp(r'^(kemet_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$');
  final kept = lines.where((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false; // drop blanks
    if (trimmed.startsWith('flowLocalId=')) return false;
    final norm = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (cidRegex.hasMatch(norm)) return false;
    return true;
  }).toList();
  return kept.join('\n').trim();
}

/// Extract a stored manual color (encoded as `color=RRGGBB;` prefix) and return
/// the remaining detail string without the prefix.
({Color? color, String? detail}) _decodeDetailColor(String? raw) {
  if (raw == null || raw.isEmpty) return (color: null, detail: null);

  final prefix = RegExp(r'^color=([0-9a-fA-FxX]+);');
  final match = prefix.firstMatch(raw);
  if (match != null) {
    final hex = match.group(1)!;
    try {
      final int rgb = hex.toLowerCase().startsWith('0x')
          ? int.parse(hex)
          : int.parse('0x$hex');
      final remainder = raw.substring(match.end);
      return (color: Color(0xFF000000 | (rgb & 0x00FFFFFF)), detail: remainder);
    } catch (_) {
      // fall through to raw detail if parsing fails
    }
  }
  return (color: null, detail: raw);
}

String? _encodeDetailWithColor(String? detail, Color? color) {
  if (color == null) return detail;
  final hex = (color.value & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
  final meta = 'color=$hex;';
  if (detail == null || detail.isEmpty) return meta;
  return '$meta$detail';
}

// Helper: label for repeat option
String _repeatOptionLabel(NoteRepeatOption option, SimpleRecurrenceFrequency customFreq, int customInterval) {
  switch (option) {
    case NoteRepeatOption.never:
      return 'Never';
    case NoteRepeatOption.everyDay:
      return 'Every Day';
    case NoteRepeatOption.everyWeek:
      return 'Every Week';
    case NoteRepeatOption.every2Weeks:
      return 'Every 2 Weeks';
    case NoteRepeatOption.everyMonth:
      return 'Every Month';
    case NoteRepeatOption.everyYear:
      return 'Every Year';
    case NoteRepeatOption.custom:
      final unit = () {
        switch (customFreq) {
          case SimpleRecurrenceFrequency.daily:
            return 'day';
          case SimpleRecurrenceFrequency.weekly:
            return 'week';
          case SimpleRecurrenceFrequency.monthly:
            return 'month';
          case SimpleRecurrenceFrequency.yearly:
            return 'year';
        }
      }();
      if (customInterval == 1) {
        return 'Every $unit';
      } else {
        return 'Every $customInterval ${unit}s';
      }
  }
}

// Helper: label for end repeat
String _endRepeatLabel(NoteRepeatEndType endType, DateTime? endDate, [int? endCount]) {
  switch (endType) {
    case NoteRepeatEndType.never:
      return 'Never';
    case NoteRepeatEndType.onDate:
      if (endDate == null) return 'On Date…';
      return '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    case NoteRepeatEndType.afterCount:
      return 'After ${endCount ?? 10} times';
  }
}

/// Generate dates for a repeating note series, respecting Kemetic months/years
/// when frequency is monthly/yearly.
Set<DateTime> generateNoteRecurrenceDates({
  required DateTime startDate,
  required NoteRepeatOption repeatOption,
  required SimpleRecurrenceFrequency customFrequency,
  required int customInterval,
  required NoteRepeatEndType endType,
  required DateTime? endDate,
  required int endCount,
  required DateTime horizonEnd,
}) {
  final dates = <DateTime>{};

  // Determine effective frequency + interval from repeatOption/custom
  SimpleRecurrenceFrequency frequency;
  int interval;

  if (repeatOption == NoteRepeatOption.custom) {
    frequency = customFrequency;
    interval = (customInterval <= 0) ? 1 : customInterval;
  } else {
    switch (repeatOption) {
      case NoteRepeatOption.never:
        frequency = SimpleRecurrenceFrequency.daily;
        interval = 1;
        break;
      case NoteRepeatOption.everyDay:
        frequency = SimpleRecurrenceFrequency.daily;
        interval = 1;
        break;
      case NoteRepeatOption.everyWeek:
        frequency = SimpleRecurrenceFrequency.weekly;
        interval = 1;
        break;
      case NoteRepeatOption.every2Weeks:
        frequency = SimpleRecurrenceFrequency.weekly;
        interval = 2;
        break;
      case NoteRepeatOption.everyMonth:
        frequency = SimpleRecurrenceFrequency.monthly;
        interval = 1;
        break;
      case NoteRepeatOption.everyYear:
        frequency = SimpleRecurrenceFrequency.yearly;
        interval = 1;
        break;
      case NoteRepeatOption.custom:
        frequency = customFrequency;
        interval = (customInterval <= 0) ? 1 : customInterval;
        break;
    }
  }

  // Effective limit: min(horizonEnd, endDate) if "On Date"
  DateTime limit = DateUtils.dateOnly(horizonEnd);
  if (endType == NoteRepeatEndType.onDate && endDate != null) {
    final e = DateUtils.dateOnly(endDate);
    if (e.isBefore(limit)) {
      limit = e;
    }
  }

  int remainingCount =
      endType == NoteRepeatEndType.afterCount ? endCount : 1 << 30; // a big number

  DateTime current = DateUtils.dateOnly(startDate);

  // Special-case: starting in Month 13 with "Every Month" -> treat as yearly
  if (repeatOption == NoteRepeatOption.everyMonth) {
    final kStart = KemeticMath.fromGregorian(current);
    if (kStart.kMonth == 13) {
      frequency = SimpleRecurrenceFrequency.yearly;
      interval = 1;
    }
  }

  void addOccurrence(DateTime d) {
    final dayOnly = DateUtils.dateOnly(d);
    if (dayOnly.isAfter(limit)) return;
    if (remainingCount <= 0) return;
    dates.add(dayOnly);
    remainingCount--;
  }

  while (!current.isAfter(limit) && remainingCount > 0) {
    addOccurrence(current);

    switch (frequency) {
      case SimpleRecurrenceFrequency.daily:
        current = current.add(Duration(days: interval));
        break;

      case SimpleRecurrenceFrequency.weekly:
        current = current.add(Duration(days: 7 * interval));
        break;

      case SimpleRecurrenceFrequency.monthly:
        // Kemetic month arithmetic
        final k = KemeticMath.fromGregorian(current);
        final nextK = KemeticMath.addMonths(
          kYear: k.kYear,
          kMonth: k.kMonth,
          kDay: k.kDay,
          monthsToAdd: interval,
        );
        current = KemeticMath.toGregorian(
          nextK.kYear,
          nextK.kMonth,
          nextK.kDay,
        );
        break;

      case SimpleRecurrenceFrequency.yearly:
        // Kemetic year arithmetic (handles epagomenal/leap)
        final k = KemeticMath.fromGregorian(current);
        int newYear = k.kYear + interval;
        int newMonth = k.kMonth;
        int newDay = k.kDay;

        if (newMonth == 13) {
          final maxEpi = KemeticMath.isLeapKemeticYear(newYear) ? 6 : 5;
          if (newDay > maxEpi) newDay = maxEpi;
        }

        current = KemeticMath.toGregorian(newYear, newMonth, newDay);
        break;
    }
  }

  if (kDebugMode) {
    debugPrint('[RepeatNote] Generated ${dates.length} dates for $repeatOption '
        '(freq=$frequency, interval=$interval, limit=$limit)');
  }

  return dates;
}

/// Build a note-specific rule using `_RuleDates` and the Kemetic-aware generator.
_RuleDates _buildNoteRuleDates({
  required DateTime firstOccurrenceDate,
  required NoteRepeatOption repeatOption,
  required SimpleRecurrenceFrequency customFrequency,
  required int customInterval,
  required NoteRepeatEndType endType,
  required DateTime? endDate,
  required int endCount,
  required bool allDay,
  required TimeOfDay? startTime,
  required TimeOfDay? endTime,
  required DateTime horizonEnd,
}) {
  final dates = generateNoteRecurrenceDates(
    startDate: firstOccurrenceDate,
    repeatOption: repeatOption,
    customFrequency: customFrequency,
    customInterval: customInterval,
    endType: endType,
    endDate: endDate,
    endCount: endCount,
    horizonEnd: horizonEnd,
  );

  return _RuleDates(
    dates: dates,
    allDay: allDay,
    start: startTime,
    end: endTime,
  );
}


class _FlowsViewerPage extends StatefulWidget {
  const _FlowsViewerPage({
    required this.flows,
    required this.fmtGregorian,
    required this.onCreateNew,
    required this.onEditFlow,
    required this.openMaatFlows,
    required this.onEndFlow,
    this.onImportFlow,
    this.onAppendToJournal,
  });

  final List<_Flow> flows;
  final String Function(DateTime? d) fmtGregorian;
  final VoidCallback onCreateNew;
  final void Function(int flowId) onEditFlow;
  final VoidCallback openMaatFlows; // <-- NEW
  final void Function(int flowId) onEndFlow;
  final Future<void> Function(int? importedFlowId)? onImportFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  @override
  State<_FlowsViewerPage> createState() => _FlowsViewerPageState();
}

class _FlowsViewerPageState extends State<_FlowsViewerPage> {
  // UI still filters by end date even though repos do, because _flows is an
  // in-memory cache that can contain stale rows until the next sync. This keeps
  // ended flows out of the view.
  bool _isActiveByEndDate(DateTime? endDate) {
    if (endDate == null) return true;
    final endUtc = endDate.toUtc();
    final endDateOnly = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return !endDateOnly.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.flows.where((f) =>
      f.active &&
      !f.isHidden &&
      _isActiveByEndDate(f.end)
    ).toList()
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
                  onAppendToJournal: widget.onAppendToJournal,
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
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('My Flows', style: TextStyle(color: Colors.white)),
        actions: [
          InboxIconWithBadge(
            onRefreshSync: () => setState(() {}),
            onImportFlow: widget.onImportFlow,
          ),
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
        backgroundColor: Colors.black,
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
        backgroundColor: Colors.black,
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
                    title: 'Kemetic Culture & History',
                    templates: kMaatFlowTemplates,
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
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MaatFlowsListPage(
                    title: 'Medu Neter',
                    templates: kMaatFlowTemplatesMeduNeter,
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
            child: const Text('Medu Neter'),
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
    required this.title,
    required this.templates,
    super.key,
  });

  final bool Function(String key) hasActiveForKey;
  final void Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: Text(title, style: const TextStyle(color: Colors.white)),
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
        itemCount: templates.length,
        separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.white10),
        itemBuilder: (ctx, i) {
          final t = templates[i];
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
  final Future<int> Function({
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
    final month = getMonthById(k.kMonth).displayFull;
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
      backgroundColor: Colors.black,
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
                          child: GlossyText(
                            text: _gregMonthNames[i + 1],
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
                          child: GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
                          child: GlossyText(
                            text: '$yy',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
                          child: MonthNameText(
                            getMonthById(m).displayFull,
                            style: const TextStyle(fontSize: 14),
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
                          child: GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
                          child: GlossyText(
                            text: label,
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
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
                  GlossyText(
                    text: localKemetic ? 'Start date (Kemetic)' : 'Start date (Gregorian)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: localKemetic ? goldGloss : blueGloss,
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
                            side: const BorderSide(color: silver, width: 1.25),
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
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: Text(widget.template.title, style: const TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          GlossyText(
            text: widget.template.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            gradient: goldGloss,
          ),
          const SizedBox(height: 8),
          Text(widget.template.overview,
              style: const TextStyle(color: Colors.white, height: 1.35)),
          const SizedBox(height: 16),
          const GlossyText(
            text: '10-Day Outline',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: silverGloss,
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
                side: const BorderSide(color: silver, width: 1.25),
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
            onPressed: _picked == null ? null : () async {
              final id = await widget.addInstance(
                template: widget.template,
                startDate: _picked!,
                useKemetic: _useKemetic,
              );
              if (context.mounted) {
                Navigator.of(context).pop(id);
              }
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
        color: Colors.black,
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
  final String? id; // optional persistent id
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;

  /// which flow created this note (for Ma'at flow cleanup). null for normal notes.
  final int? flowId;

  /// Manual color for notes that aren't driven by a flow.
  final Color? manualColor;
  final String? category; // optional category label

  const _Note({
    this.id,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.start,
    this.end,
    this.flowId,
    this.manualColor,
    this.category,
  });
}

// ========================================
// CUSTOM REPEAT PAGE
// ========================================

class _CustomRepeatPage extends StatefulWidget {
  final SimpleRecurrenceFrequency initialFrequency;
  final int initialInterval;

  const _CustomRepeatPage({
    Key? key,
    required this.initialFrequency,
    required this.initialInterval,
  }) : super(key: key);

  @override
  State<_CustomRepeatPage> createState() => _CustomRepeatPageState();
}

class _CustomRepeatPageState extends State<_CustomRepeatPage> {
  late SimpleRecurrenceFrequency _freq;
  late int _interval;

  @override
  void initState() {
    super.initState();
    _freq = widget.initialFrequency;
    _interval = widget.initialInterval.clamp(1, 999);
  }

  String _freqLabel(SimpleRecurrenceFrequency f) {
    switch (f) {
      case SimpleRecurrenceFrequency.daily:
        return 'Daily';
      case SimpleRecurrenceFrequency.weekly:
        return 'Weekly';
      case SimpleRecurrenceFrequency.monthly:
        return 'Monthly';
      case SimpleRecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  String _unitLabel() {
    switch (_freq) {
      case SimpleRecurrenceFrequency.daily:
        return _interval == 1 ? 'day' : 'days';
      case SimpleRecurrenceFrequency.weekly:
        return _interval == 1 ? 'week' : 'weeks';
      case SimpleRecurrenceFrequency.monthly:
        return _interval == 1 ? 'month' : 'months';
      case SimpleRecurrenceFrequency.yearly:
        return _interval == 1 ? 'year' : 'years';
    }
  }

  Widget _divider() => Container(
        height: 1,
        color: Colors.white12,
        margin: const EdgeInsets.symmetric(horizontal: 16),
      );

  Widget _row({
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlossyText(
              text: label,
              gradient: goldGloss,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _showFrequencySheet() async {
    final result = await showCupertinoModalPopup<SimpleRecurrenceFrequency>(
      context: context,
      builder: (_) {
        return CupertinoActionSheet(
          title: const GlossyText(
            text: 'Frequency',
            gradient: silverGloss,
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            for (final f in SimpleRecurrenceFrequency.values)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context, f);
                },
                child: GlossyText(
                  text: _freqLabel(f),
                  gradient: goldGloss,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _freq = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.black,
        border: null,
        previousPageTitle: 'Repeat',
        middle: const GlossyText(
          text: 'Custom',
          gradient: silverGloss,
          style: TextStyle(fontSize: 18),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.pop<Map<String, dynamic>>(context, {
              'frequency': _freq,
              'interval': _interval,
            });
          },
          child: GlossyText(
            text: 'Done',
            gradient: goldGloss,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // MAIN CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Column(
                  children: [
                    _row(
                      label: 'Frequency',
                      trailing: Row(
                        children: [
                          GlossyText(
                            text: _freqLabel(_freq),
                            gradient: silverGloss,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                        ],
                      ),
                      onTap: _showFrequencySheet,
                    ),

                    _divider(),

                    _row(
                      label: 'Every',
                      trailing: GlossyText(
                        text: _unitLabel().capitalizeFirst(),
                        gradient: goldGloss,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),

                    _divider(),

                    // INTERVAL PICKER
                    SizedBox(
                      height: 160,
                      child: CupertinoPicker(
                        itemExtent: 34,
                        scrollController: FixedExtentScrollController(
                          initialItem: (_interval - 1).clamp(0, 998),
                        ),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _interval = index + 1;
                          });
                        },
                        backgroundColor: Colors.black,
                        children: List.generate(999, (i) {
                          final v = i + 1;
                          return Center(
                            child: GlossyText(
                              text: '$v',
                              gradient: silverGloss,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // SUMMARY
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlossyText(
                text: 'Event will occur every $_interval ${_unitLabel()}.',
                gradient: silverGloss,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper extension for capitalizeFirst
extension _CapitalizeFirst on String {
  String capitalizeFirst() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

// ========================================
// GOLD DIVIDER WIDGET
// ========================================

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width * 0.82).floorToDouble(); // snap to px
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),  // 16px above and below
      child: Center(
        child: RepaintBoundary(
          child: ShaderMask(
            shaderCallback: (Rect r) => goldGloss.createShader(r), // same gradient as titles
            blendMode: BlendMode.srcIn,
            child: SizedBox(
              width: w,
              height: 1.0,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFFFFFFF)), // white base for mask
              ),
            ),
          ),
        ),
      ),
    );
  }
}
