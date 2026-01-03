/* 
 * ═══════════════════════════════════════════════════════════════
 *   ⚠️  KEMETIC YEAR 1 ONLY - HARDCODED DATES
 * ═══════════════════════════════════════════════════════════════
 * 
 * Valid Period: March 20, 2025 - March 19, 2026 (Gregorian)
 * 
 * These day cards contain HARDCODED Gregorian dates for Kemetic
 * Year 1 ONLY. They will be INCORRECT for other Kemetic years.
 * 
 * DO NOT use for:
 *   • Year 2 or later (dates wrong)
 *   • Year 0 or earlier (pre-epoch)
 * 
 * For multi-year support, see: docs/MULTI_YEAR_MIGRATION.md
 * 
 * ═══════════════════════════════════════════════════════════════
 */

import 'package:flutter/material.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';

/// Model for Kemetic day information
class KemeticDayInfo {
  final String gregorianDate;
  final String kemeticDate;
  final String season;
  final String month;
  final String decanName;
  final String starCluster;
  final String maatPrinciple;
  final String cosmicContext;
  final List<DecanDayInfo> decanFlow;
  final MeduNeterKey meduNeter;

  KemeticDayInfo({
    required this.gregorianDate,
    required this.kemeticDate,
    required this.season,
    required this.month,
    required this.decanName,
    required this.starCluster,
    required this.maatPrinciple,
    required this.cosmicContext,
    required this.decanFlow,
    required this.meduNeter,
  });
}

class DecanDayInfo {
  final int day;
  final String theme;
  final String action;
  final String reflection;

  DecanDayInfo({
    required this.day,
    required this.theme,
    required this.action,
    required this.reflection,
  });
}

class MeduNeterKey {
  final String glyph;
  final String colorFrequency;
  final String mantra;

  MeduNeterKey({
    required this.glyph,
    required this.colorFrequency,
    required this.mantra,
  });
}

/// Sample data for Day 11 (Renwet II, Day 1)
class KemeticDayData {
  // Shared flow list for Renwet I (Days 1–10)
  static final List<DecanDayInfo> renwetIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Receive the Gift', action: 'Acknowledge what has arrived — harvest, payment, relief, breakthrough — without denial or boasting.', reflection: '"What did I just receive that I refused to call sacred because I was too used to struggle?"'),
    DecanDayInfo(day: 2, theme: 'Sort the Blessing', action: 'Separate what is for you, what is for the house, what is for offering.', reflection: '"Can I tell the difference between mine and ours?"'),
    DecanDayInfo(day: 3, theme: 'Offer First Share', action: 'Return the first portion to Source: ancestors, gods, community need.', reflection: '"Did I honor where this came from before I kept any for myself?"'),
    DecanDayInfo(day: 4, theme: 'Feed the House', action: 'Make sure the people under your care are nourished in body and spirit.', reflection: '"Is anyone in my circle hungry, unseen, or running on empty?"'),
    DecanDayInfo(day: 5, theme: 'Record the Gain Honestly', action: 'Write down what truly came in. No inflation, no hiding.', reflection: '"If I vanished tomorrow, could someone read the record and know I lived in Maʿat?"'),
    DecanDayInfo(day: 6, theme: 'Pay the Hands', action: 'Compensate labor. Cancel hidden debt. Acknowledge who carried you.', reflection: '"Have I thanked the ones who lifted with me, or am I acting like I did this alone?"'),
    DecanDayInfo(day: 7, theme: 'Rest the Field', action: 'Do not strip the source bare. Leave breathing room for renewal.', reflection: '"Am I harvesting — or am I draining?"'),
    DecanDayInfo(day: 8, theme: 'Speak Gratitude Aloud', action: 'Say thank you where it can be heard — to the living, to the dead, to the divine.', reflection: '"Who needs to hear that I am grateful for them today?"'),
    DecanDayInfo(day: 9, theme: 'Secure the Store', action: 'Protect what remains with order: seal containers, plan rations, prevent spoilage and theft.', reflection: '"Can I keep this blessing safe without becoming paranoid or stingy?"'),
    DecanDayInfo(day: 10, theme: 'Seal the Name', action: 'Declare who you are now that you have received. Align fate (šai) with how you intend to carry this.', reflection: '"What does Renenutet know my name to mean — and am I living like that name is true?"'),
  ];

  // Shared flow list for Renwet II (Days 11–20)
  static final List<DecanDayInfo> renwetIIFlowRows = [
    DecanDayInfo(day: 11, theme: 'Stand in the Light', action: 'Let yourself be seen as you really are in this season.', reflection: '"If someone watched how I handled abundance, would they call me honorable?"'),
    DecanDayInfo(day: 12, theme: 'Weigh the Heart', action: 'Compare intention vs behavior. Did you live what you preached?', reflection: '"Does my heart match my mouth?"'),
    DecanDayInfo(day: 13, theme: 'Confess the Excess', action: 'Name where you took too much, ignored need, or acted out of fear.', reflection: '"Where did I slip into greed, and why?"'),
    DecanDayInfo(day: 14, theme: 'Correct the Imbalance', action: 'Make a concrete repair: repay, apologize, redistribute, restore dignity.', reflection: '"Who deserves repair from me before this cycle can be called clean?"'),
    DecanDayInfo(day: 15, theme: 'Protect the Innocent', action: 'Shield the vulnerable with what you\'ve gained — children, elders, exhausted workers, yourself.', reflection: '"Who is still exposed, and why am I okay with that?"'),
    DecanDayInfo(day: 16, theme: 'Speak the Record Publicly', action: 'Say what happened this cycle in front of witnesses: what came in, what you did, what you\'ll fix.', reflection: '"Do the people around me know my truth, or just my performance?"'),
    DecanDayInfo(day: 17, theme: 'Honor the Honest Worker', action: 'Tell the stories of those who carried the season with integrity.', reflection: '"Whose name deserves to shine from this harvest?"'),
    DecanDayInfo(day: 18, theme: 'Consecrate the Oath', action: 'State what code you will live by going forward.', reflection: '"What promise will I stake my name on?"'),
    DecanDayInfo(day: 19, theme: 'Seal Reputation', action: 'Accept that how you moved in this harvest is now part of your name.', reflection: '"If my child repeated what I did this season, would I feel pride or shame?"'),
    DecanDayInfo(day: 20, theme: 'Rest in Witness', action: 'Release anxiety. You faced truth. You corrected what you could. Be still in Maʿat.', reflection: '"Can I sit in quiet knowing I did not hide?"'),
  ];

  // Shared flow list for Renwet III (Days 21–30)
  static final List<DecanDayInfo> renwetIIIFlowRows = [
    DecanDayInfo(day: 21, theme: 'Store the Harvest', action: 'Secure what you gathered. Clean jars. Label. Seal.', reflection: '"Do I know what I actually have — or am I just assuming I\'m fine?"'),
    DecanDayInfo(day: 22, theme: 'Thank the Source', action: 'Offer first-share gratitude to what fed you: land, river, hands, ancestors, the Divine.', reflection: '"Have I returned gratitude in a way the Source would recognize as real?"'),
    DecanDayInfo(day: 23, theme: 'Bless the Tools', action: 'Clean, oil, and wrap what served you this cycle — body tools, money tools, craft tools.', reflection: '"Do I show respect to what carried the work, or do I only use and discard?"'),
    DecanDayInfo(day: 24, theme: 'Close the Ledger', action: 'Write the final account of this season. What came in, what went out, what remains.', reflection: '"Is there any number I\'m scared to face?"'),
    DecanDayInfo(day: 25, theme: 'Name the Lessons', action: 'State clearly what this cycle taught you — skill, warning, truth about yourself.', reflection: '"What will not be repeated? What must be repeated?"'),
    DecanDayInfo(day: 26, theme: 'Give Quiet Blessing Forward', action: 'Place intention on the next cycle without trying to control it. Speak life into what comes.', reflection: '"Can I bless what hasn\'t happened yet without grabbing for it?"'),
    DecanDayInfo(day: 27, theme: 'Release the Burden', action: 'Let go of the strain response. You are not in active crisis anymore.', reflection: '"Am I still clenching like I\'m in survival mode, even though I\'m not?"'),
    DecanDayInfo(day: 28, theme: 'Return to Silence', action: 'Practice sacred quiet. Reduce noise, opinion, performance. Let the nervous system settle.', reflection: '"When was the last time I let myself be silent in front of the Source and didn\'t fill the silence?"'),
    DecanDayInfo(day: 29, theme: 'Lay Down the Body', action: 'Honor rest as a holy act. Sleep early. Move gently. Stop proving.', reflection: '"Do I believe rest is allowed, or do I still treat it like theft?"'),
    DecanDayInfo(day: 30, theme: 'Offer the Cycle Back to Time', action: 'Accept completion. Nothing left to squeeze. Give the season back to Maʿat and step into peace.', reflection: '"Can I end without dragging guilt, hoarding fear, or clinging to control?"'),
  ];

  // Shared flow list for Hnsw I (Days 1–10)
  static final List<DecanDayInfo> hnswIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Step Onto the Path', action: 'Declare today\'s path out loud. Move with stated purpose, not drift.', reflection: '"Where am I going — and why?"'),
    DecanDayInfo(day: 2, theme: 'Carry the Light', action: 'Let your presence uplift, not scorch. Travel with calm face, steady breath.', reflection: '"Does my heat nourish or dominate?"'),
    DecanDayInfo(day: 3, theme: 'Honor the Heat', action: 'Accept difficulty without complaint. Dress for it, plan for it, respect it.', reflection: '"Am I angry at conditions that are simply part of the season?"'),
    DecanDayInfo(day: 4, theme: 'Travel Clean', action: 'Check conduct while in motion — tone, honesty, promises, money exchanges.', reflection: '"Would Maʿat be ashamed to walk beside me today?"'),
    DecanDayInfo(day: 5, theme: 'Move With Offering', action: 'Bring something with you when you arrive (help, food, clarity, skill).', reflection: '"Do I enter spaces as a taker, or as a contributor?"'),
    DecanDayInfo(day: 6, theme: 'Protect the Vessel', action: 'Guard your body and mind while traveling. Hydrate, rest joints, shield spirit from nonsense.', reflection: '"Am I treating myself like cargo or like sacred transport?"'),
    DecanDayInfo(day: 7, theme: 'Witness the Route', action: 'Pay attention. Notice patterns, people, needs. The road itself is intelligence.', reflection: '"What is this path showing me about the world I serve?"'),
    DecanDayInfo(day: 8, theme: 'Speak the Blessing', action: 'Offer safe-travel words for others. "May you arrive in peace. May your load return multiplied."', reflection: '"Do I extend protection, or do I only ask for mine?"'),
    DecanDayInfo(day: 9, theme: 'Record the Day\'s Distance', action: 'Take simple account of what was done, earned, delivered, promised.', reflection: '"What actually happened on my path today — not the story, the facts?"'),
    DecanDayInfo(day: 10, theme: 'Lay Down Without Arrogance', action: 'Rest without boasting about how hard you worked. Sit in quiet, thank Ra for safe passage, close the day.', reflection: '"Can I end today without demanding applause for surviving it?"'),
  ];

  // Shared flow list for Hnsw II (Days 11–20)
  static final List<DecanDayInfo> hnswIIFlowRows = [
    DecanDayInfo(day: 11, theme: 'Name the Terms', action: 'State clearly what you are doing, trading, agreeing to.', reflection: '"Have I said aloud what I am promising, or am I hiding vagueness inside the deal?"'),
    DecanDayInfo(day: 12, theme: 'Travel With Witness', action: 'Assume Maʿat is standing beside you. Conduct yourself like you\'re being recorded forever.', reflection: '"Would I repeat today\'s words in front of my ancestors?"'),
    DecanDayInfo(day: 13, theme: 'Keep Measure', action: 'Track energy, money, time, and voice. Don\'t overspend any of them for pride.', reflection: '"Where am I leaking resources just to feel powerful in the moment?"'),
    DecanDayInfo(day: 14, theme: 'Speak Cleanly', action: 'No frantic speech. No panicked promises. No lies to "smooth things over."', reflection: '"Did I warp truth today just to avoid discomfort?"'),
    DecanDayInfo(day: 15, theme: 'Honor the Exchange', action: 'Pay fair, demand fair. No exploiting desperation, and no offering yourself cheaply.', reflection: '"Did I cheapen myself, or did I try to cheapen someone else?"'),
    DecanDayInfo(day: 16, theme: 'Travel Under Oath', action: 'Treat your word as binding. If you say you will do it, you have placed seal on it.', reflection: '"Do I use language like a contract, or like smoke?"'),
    DecanDayInfo(day: 17, theme: 'Protect the Quiet', action: 'Schedule silence. You cannot think clearly if you never withdraw.', reflection: '"Where in this day did my mind get to breathe?"'),
    DecanDayInfo(day: 18, theme: 'Check for Poison', action: 'Scan for corruption in your circle — lies, envy, exploitation, manipulation disguised as love or help.', reflection: '"Who walks with me that is secretly against my balance?"'),
    DecanDayInfo(day: 19, theme: 'Assert the Boundary', action: 'Say "no" without apology. You are not obligated to carry what bends you out of Maʿat.', reflection: '"Where did I accept a load that is not mine?"'),
    DecanDayInfo(day: 20, theme: 'Seal the Ledger', action: 'Record agreements, payments, distances, loyalties. Make it written, not just remembered.', reflection: '"If I vanished tonight, would someone know what I built, what I owed, and what I am owed?"'),
  ];

  // Shared flow list for Hnsw III (Days 21–30)
  static final List<DecanDayInfo> hnswIIIFlowRows = [
    DecanDayInfo(day: 21, theme: 'Ease the Pace', action: 'Consciously slow output. Shorten the workday. Move with deliberate steps.', reflection: '"Why am I still sprinting when the road has already been won?"'),
    DecanDayInfo(day: 22, theme: 'Cool the Body', action: 'Treat heat damage: rehydrate, bathe, stretch, oil the joints, restore breath.', reflection: '"Where is my body asking me to listen, not to push?"'),
    DecanDayInfo(day: 23, theme: 'Redistribute the Load', action: 'Shift weight. Ask for help. Hand off tasks. Share the burden so nothing (including you) cracks.', reflection: '"What am I carrying alone that was never meant to be carried alone?"'),
    DecanDayInfo(day: 24, theme: 'Guard the Core', action: 'Pull your energy back from distractions, leaks, and performative work.', reflection: '"Where do I spend effort just to be seen?"'),
    DecanDayInfo(day: 25, theme: 'Honor Fatigue', action: 'Fatigue is proof of offering, not weakness. Let the body rest without apology.', reflection: '"Can I let tiredness be holy?"'),
    DecanDayInfo(day: 26, theme: 'Release the Excess', action: 'Remove what you gathered on the road but do not need — resentment, clutter, stale obligations.', reflection: '"What will not travel with me into the next cycle?"'),
    DecanDayInfo(day: 27, theme: 'Enter Stillness', action: 'Shorten speech. Move quietly. Sit in evening light and allow the nervous system to drop.', reflection: '"Have I given my spirit true silence before I re-enter the world?"'),
    DecanDayInfo(day: 28, theme: 'Give Thanks for Distance Traveled', action: 'Record where you started and where you are. See the distance honestly and bless it.', reflection: '"If I met myself from the beginning of this path, what would I tell them I learned?"'),
    DecanDayInfo(day: 29, theme: 'Return to Center / Come Home', action: 'Re-ground in home, altar, lineage, promise. Make contact with the source you move for.', reflection: '"To whom — or to what law — do I ultimately belong?"'),
    DecanDayInfo(day: 30, theme: 'Offer the Report to Ra', action: 'Deliver your accounting: what you carried, how you behaved, what you upheld. Close the journey in Maʿat.', reflection: '"If Ra asked, \'How did you travel in my light?,\' what would I truthfully answer?"'),
  ];

  // Shared flow list for Ḥenti-ḥet I (Days 1–10)
  static final List<DecanDayInfo> hentiHetIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Rise Before the Heat', action: 'Wake early. Begin sacred work in first light. Honor the sun by meeting it, not chasing it.', reflection: '"Did I greet the day as a keeper, or stumble into it as a beggar?"'),
    DecanDayInfo(day: 2, theme: 'Work Clean, Work Brief', action: 'Do essential labor only. No waste motion. Finish before the blaze.', reflection: '"How much of what I call \'work\' is actually noise?"'),
    DecanDayInfo(day: 3, theme: 'Guard the Breath', action: 'Regulate breathing. Slow the heart. Keep speech cool, especially when provoked.', reflection: '"Did my mouth pour fire or water?"'),
    DecanDayInfo(day: 4, theme: 'Offer Back the Excess Heat', action: 'Release anger, urgency, and greed as offerings — not suppressed, but surrendered to Ra.', reflection: '"What in me is running too hot for balance?"'),
    DecanDayInfo(day: 5, theme: 'Honor Proportion', action: 'Take only what is needed today. Ration calmly. Do not grasp.', reflection: '"Am I consuming for need, or out of fear?"'),
    DecanDayInfo(day: 6, theme: 'Shade the Vulnerable', action: 'Protect children, elders, the tired, the overworked. Become shade for someone else.', reflection: '"Whose suffering did I cool today?"'),
    DecanDayInfo(day: 7, theme: 'Keep the Record', action: 'Write what was given and what was spent. Peace comes from accounted exchange.', reflection: '"Can I name what I owe, what I\'ve received, and what I returned?"'),
    DecanDayInfo(day: 8, theme: 'Cool the Eye', action: 'Lower the gaze. Refuse escalation. Practice gentleness where wrath is expected.', reflection: '"Did I calm the Eye, or did I feed it?"'),
    DecanDayInfo(day: 9, theme: 'Speak Soft to the Body', action: 'Oil, water, shade, rest. Treat the body like entrusted temple equipment, not disposable gear.', reflection: '"Did I keep the vessel worthy of the Ka?"'),
    DecanDayInfo(day: 10, theme: 'Seal the Morning Oath', action: 'Affirm aloud who you intend to be under heat. Set vow for the rest of the month.', reflection: '"When the sun tests me, what do I refuse to become?"'),
  ];

  // Shared flow list for Ḥenti-ḥet II (Days 11–20)
  static final List<DecanDayInfo> hentiHetIIFlowRows = [
    DecanDayInfo(day: 11, theme: 'Name the Fire', action: 'Admit honestly what burns in you — anger, desire, urgency, hunger for control.', reflection: '"What is the true heat in me right now?"'),
    DecanDayInfo(day: 12, theme: 'Purify the Intention', action: 'Decide what that fire is for. Give it a purpose that serves Maʿat, not ego.', reflection: '"Does my will build life or just prove I\'m powerful?"'),
    DecanDayInfo(day: 13, theme: 'Sweeten the Flame', action: 'Perform a cooling act: incense, water on the forehead, soft words where you\'d usually strike.', reflection: '"How did I soften something today that could have scorched?"'),
    DecanDayInfo(day: 14, theme: 'Repair Harm Done in Heat', action: 'Apologize. Rebalance. Return what you took harshly. Restore what you broke.', reflection: '"Where did my heat injure someone who trusted me?"'),
    DecanDayInfo(day: 15, theme: 'Speak Under Oath', action: 'Speak only what you are willing to stand beside in the Hall of Maʿat.', reflection: '"Would I repeat these words in front of the scales?"'),
    DecanDayInfo(day: 16, theme: 'Burn Away the Rot', action: 'Release habits, cravings, alliances, or objects that rot the spirit. Let fire consume what should end.', reflection: '"What must not cross into the next season with me?"'),
    DecanDayInfo(day: 17, theme: 'Consecrate the Body', action: 'Oil, cleanse, adorn. Present yourself as sacred vessel, not exhausted tool.', reflection: '"Do I carry myself like temple equipment, or like scrap?"'),
    DecanDayInfo(day: 18, theme: 'Offer Heat as Service', action: 'Use your strength where it actually matters — defense of the weak, hard labor no one else will do.', reflection: '"Who received my strength today besides me?"'),
    DecanDayInfo(day: 19, theme: 'Hold Still in the Blaze', action: 'Practice composure under provocation. Do not flinch, do not erupt.', reflection: '"When I was tested, did I hold form?"'),
    DecanDayInfo(day: 20, theme: 'Seal the Flame in Devotion', action: 'State aloud what your fire now serves. Bind it.', reflection: '"Who does my power answer to?"'),
  ];

  // Shared flow list for Ḥenti-ḥet III (Days 21–30)
  static final List<DecanDayInfo> hentiHetIIIFlowRows = [
    DecanDayInfo(day: 21, theme: 'Stand Down the Body', action: 'Release tension. Allow muscles to unlock. Acknowledge fatigue without shame.', reflection: '"Where am I still pretending I\'m not tired?"'),
    DecanDayInfo(day: 22, theme: 'Secure the Storehouse', action: 'Check what you\'ve gathered — food, money, agreements, tools. Protect it with care and thanks.', reflection: '"Have I honored what I asked the world to give me?"'),
    DecanDayInfo(day: 23, theme: 'Sharpen and Mend', action: 'Clean blades, repair handles, sweep workspaces. Restore your instruments to readiness.', reflection: '"Will Future Me inherit tools in dignity, or in chaos?"'),
    DecanDayInfo(day: 24, theme: 'Release the Burden', action: 'Lay down tasks that are no longer yours to carry. Stop hauling out of pride.', reflection: '"What weight am I carrying just so no one thinks I\'m weak?"'),
    DecanDayInfo(day: 25, theme: 'Honor the Body as Survivor', action: 'Tend bruises, burns, soreness. Oil joints. Feed and water yourself with patience.', reflection: '"Do I treat my own body like a worker I value?"'),
    DecanDayInfo(day: 26, theme: 'Speak Gratitude to the Source', action: 'Offer thanks aloud — to Ra, to the river, to the ancestors, to the people who labored with you.', reflection: '"Did I act like I did this alone?"'),
    DecanDayInfo(day: 27, theme: 'Record the Season', action: 'Write what was gained, lost, learned. Fix this cycle in memory so Maʿat can witness it.', reflection: '"If I vanished, would the record show that I served balance?"'),
    DecanDayInfo(day: 28, theme: 'Establish Boundary for Rest', action: 'Declare that rest is not laziness. State that no one may demand more of you than Maʿat allows.', reflection: '"Have I granted myself lawful rest?"'),
    DecanDayInfo(day: 29, theme: 'Return Excess', action: 'Give back overflow — food, money, attention, teaching — so that no blessing rots in hoarding.', reflection: '"What am I keeping that should be circulating?"'),
    DecanDayInfo(day: 30, theme: 'Seal the Offering', action: 'Close the month with an intentional offering (object, action, vow) that says: "It was enough."', reflection: '"Have I ended this cycle in gratitude, not in hunger?"'),
  ];

  // Shared flow list for Ipt-ḥmt I (Days 1–10)
  static final List<DecanDayInfo> iptHmtIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Call the Lineage', action: 'Speak the names of your people out loud, living and passed. Invite them to stand with you.', reflection: '"Whose strength is still moving in me?"'),
    DecanDayInfo(day: 2, theme: 'Clean the Shrine / Clean the Room', action: 'Wipe, sweep, clear dust from any place of memory (altar, photos, grave, heirloom).', reflection: '"Do I keep my ancestors in neglect or in honor?"'),
    DecanDayInfo(day: 3, theme: 'Offer Sustenance', action: 'Place water, bread, fruit, incense, song, or breath as an offering to the Ka that sustains you.', reflection: '"Have I thanked the force that is quietly feeding me?"'),
    DecanDayInfo(day: 4, theme: 'Listen for Instruction', action: 'Sit in stillness and ask for guidance from those who endured before you.', reflection: '"What are they telling me to correct while I still can?"'),
    DecanDayInfo(day: 5, theme: 'Repair the Story', action: 'Tell the truth about what happened in your line — including the pain — without shame.', reflection: '"Which silence in my family is killing us?"'),
    DecanDayInfo(day: 6, theme: 'Carry Forward a Virtue', action: 'Choose one trait from an ancestor (craft, discipline, tenderness, defiance) and practice it.', reflection: '"What gift of theirs will I keep alive today on purpose?"'),
    DecanDayInfo(day: 7, theme: 'Reaffirm Your Place', action: 'Say plainly: "I am not alone. I am carried." Declare yourself part of an unbroken chain.', reflection: '"Do I live like an isolated self or as a continuation?"'),
    DecanDayInfo(day: 8, theme: 'Bind the Household', action: 'Share blessing with the living: protect children, comfort elders, resolve tension at home.', reflection: '"Did I extend the protection I pray for, or did I hoard it?"'),
    DecanDayInfo(day: 9, theme: 'Promise Continuity', action: 'Write or speak one thing you will pass on — knowledge, ritual, land, ethic, defense.', reflection: '"If I fall tomorrow, what survives because of me?"'),
    DecanDayInfo(day: 10, theme: 'Seal the Lineage Vow', action: 'Mark this cycle with a vow to honor and maintain your line in Maʿat going forward.', reflection: '"Will my name be spoken with pride when I cross into the West?"'),
  ];

  // Shared flow list for Ipt-ḥmt II (Days 11–20)
  static final List<DecanDayInfo> iptHmtIIFlowRows = [
    DecanDayInfo(day: 11, theme: 'Stand Before Your Name', action: 'Look at your own life plainly. No excuses.', reflection: '"If I died today, would they call me true of voice?"'),
    DecanDayInfo(day: 12, theme: 'Pour the Water', action: 'Make a quiet offering to those who walked in Maʿat before you.', reflection: '"Who in my line actually lived right, and what did that look like in practice?"'),
    DecanDayInfo(day: 13, theme: 'Measure Your Conduct', action: 'Compare how you move with how you say you move. Close that gap.', reflection: '"Where am I pretending to be aligned but I am not?"'),
    DecanDayInfo(day: 14, theme: 'Correct Harm You Caused', action: 'Repair something you damaged — relationship, trust, agreement, boundary, resource.', reflection: '"Who deserves repair from me?"'),
    DecanDayInfo(day: 15, theme: 'Clean Your Name', action: 'Remove filth from around your name — gossip, needless drama, falsehood, self-sabotage you keep feeding.', reflection: '"What stain around my name is my own doing?"'),
    DecanDayInfo(day: 16, theme: 'Speak Your Standard Aloud', action: 'State clearly what is and is not acceptable for you anymore.', reflection: '"What line in the sand must I draw for myself?"'),
    DecanDayInfo(day: 17, theme: 'Protect Your Word', action: 'Do not say what you will not keep. Do not promise what you cannot carry.', reflection: '"Where am I cheap with my word?"'),
    DecanDayInfo(day: 18, theme: 'Hold Your Center in Heat', action: 'Stay aligned under pressure. Anger, temptation, insult — do not betray yourself.', reflection: '"Do I only live Maʿat when it\'s easy?"'),
    DecanDayInfo(day: 19, theme: 'Honor the Quiet Ones', action: 'Give thanks to the ancestor whose greatness wasn\'t loud — the consistent, the humble, the overlooked.', reflection: '"Whose quiet strength have we failed to praise?"'),
    DecanDayInfo(day: 20, theme: 'Prepare to Be Remembered', action: 'Decide what memory of you should survive. Start living so it will be true.', reflection: '"What sentence will my people speak about me when I am gone — and will it be honest?"'),
  ];

  // Shared flow list for Ipt-ḥmt III (Days 21–30)
  static final List<DecanDayInfo> iptHmtIIIFlowRows = [
    DecanDayInfo(day: 21, theme: 'Claim the Line', action: 'Accept that you are in the lineage — you are not separate from it.', reflection: '"Whose work am I continuing with my life?"'),
    DecanDayInfo(day: 22, theme: 'Receive the Charge', action: 'Identify the specific duty that has fallen to you to carry.', reflection: '"What responsibility is now mine because others are gone?"'),
    DecanDayInfo(day: 23, theme: 'Name the Scar', action: 'Acknowledge the wound, failure, or break in the line you are inheriting.', reflection: '"What damage am I inheriting that I refuse to pass forward?"'),
    DecanDayInfo(day: 24, theme: 'Swear Continuity', action: 'Make a vow to preserve what must endure: protection, dignity, resource, story, sanctuary.', reflection: '"What will not be allowed to die with me?"'),
    DecanDayInfo(day: 25, theme: 'Refuse the Rot', action: 'Name what ends with you — violence, shame, silence, addiction, cowardice, hunger, abandonment.', reflection: '"What poison stops in my generation?"'),
    DecanDayInfo(day: 26, theme: 'Build the Bridge', action: 'Create or repair one structure that lets the next ones stand taller: money set aside, knowledge recorded.', reflection: '"What tool or record can I create so they do not have to start over from zero?"'),
    DecanDayInfo(day: 27, theme: 'Transfer the Teachings', action: 'Teach something forward — skill, law, prayer, map.', reflection: '"Who needs to know what I know while I am still breathing?"'),
    DecanDayInfo(day: 28, theme: 'Pledge Publicly', action: 'Announce (out loud, in writing, in ritual) what you are carrying and for whom.', reflection: '"Who will I say I stand for?"'),
    DecanDayInfo(day: 29, theme: 'Seal the House', action: 'Put your affairs in order before the year turns: physical, spiritual, financial, relational.', reflection: '"If I vanish tonight, is the path after me clear or chaos?"'),
    DecanDayInfo(day: 30, theme: 'Stand Before the Dawn', action: 'Present yourself to the threshold of the new year as Horus does: upright, accountable, unhidden.', reflection: '"Am I ready to stand on Sah — to inherit Maʿat without apology?"'),
  ];

  // Shared flow list for Mswt-Rꜥ I (Days 1–10)
  static final List<DecanDayInfo> mswtRaIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Surrender to Stillness', action: 'Stop forcing motion. Stop scrambling. Be still on purpose.', reflection: '"Where am I pretending I\'m \'fine\' just to avoid stopping?"'),
    DecanDayInfo(day: 2, theme: 'Lay Down Weapons', action: 'Release defenses you don\'t need anymore — the argument, the posture, the mask.', reflection: '"What am I gripping that is actually wounding me?"'),
    DecanDayInfo(day: 3, theme: 'Loosen the Jaw / Breathe', action: 'Unclench the jaw, drop the shoulders, lengthen the exhale. Invite breath like sacred water.', reflection: '"What would my breath sound like if I was safe?"'),
    DecanDayInfo(day: 4, theme: 'Return to Body', action: 'Place hands on chest, belly, throat. Feel where you are tense, numb, or missing. Name each place without judgment.', reflection: '"Where have I stopped living inside myself?"'),
    DecanDayInfo(day: 5, theme: 'Offer the Remains', action: 'Gather what\'s left of you — even if it\'s pieces — and place it before Maʿat honestly.', reflection: '"If I lay myself on the altar as I am, what do I place there?"'),
    DecanDayInfo(day: 6, theme: 'Receive Reassembly', action: 'Let yourself be put back together. Accept help. Accept rest. Accept being held.', reflection: '"Where do I still refuse to be helped because I think I must deserve pain?"'),
    DecanDayInfo(day: 7, theme: 'Raise the Djed', action: 'Feel the spine as Djed — the backbone of Asar (Osiris) re-stood. Sit upright in quiet strength, not performance.', reflection: '"Can I sit in my own stability without needing applause?"'),
    DecanDayInfo(day: 8, theme: 'Accept the Naming', action: 'Speak your true name, not the insult or the label thrown on you. Claim the name that aligns with Maʿat.', reflection: '"What am I really called in this world, beneath survival titles?"'),
    DecanDayInfo(day: 9, theme: 'Keep Silent Watch', action: 'Observe without reacting. Become witness. Hold the border of your life like a temple guard at night.', reflection: '"What crosses my boundary that does not belong in the next cycle?"'),
    DecanDayInfo(day: 10, theme: 'Hold the Gate', action: 'Stand at the threshold of rebirth with discipline and tenderness. No panic. No begging. Only readiness.', reflection: '"Can I wait with dignity for what is mine, instead of chasing?"'),
  ];

  // Shared flow list for Mswt-Rꜥ II (Days 11–20)
  static final List<DecanDayInfo> mswtRaIIFlowRows = [
    DecanDayInfo(day: 11, theme: 'Enter the Hidden', action: 'Step back from noise, withdraw from excess, honor stillness.', reflection: '"What part of me must go quiet to be reborn?"'),
    DecanDayInfo(day: 12, theme: 'Release the Light', action: 'Let go of something visible — habit, tension, clutter, identity crust.', reflection: '"What brightness has become burden?"'),
    DecanDayInfo(day: 13, theme: 'Sink into Trust', action: 'Accept the unseen process working beneath visibility.', reflection: '"Can I trust what I cannot measure?"'),
    DecanDayInfo(day: 14, theme: 'Prepare the Vessel', action: 'Clean body, space, tools — the womb must be ready.', reflection: '"What container must be purified for what is coming?"'),
    DecanDayInfo(day: 15, theme: 'Seal the Silence', action: 'Commit to a quiet inner chamber — no gossip, no leaks.', reflection: '"Where is my silence being stolen?"'),
    DecanDayInfo(day: 16, theme: 'Hold the Unborn', action: 'Sit in expectancy without forcing clarity.', reflection: '"Can I hold potential without demanding answers?"'),
    DecanDayInfo(day: 17, theme: 'Warm the Inner Flame', action: 'Tend breath, posture, intention — build gentle power.', reflection: '"What inner spark needs gentle tending?"'),
    DecanDayInfo(day: 18, theme: 'Call the Ancestors', action: 'Speak their names, recall their endurance.', reflection: '"Who walked before me while unseen?"'),
    DecanDayInfo(day: 19, theme: 'Discern the Signs', action: 'Notice omens, patterns, alignments emerging from the quiet.', reflection: '"What is revealing itself subtly?"'),
    DecanDayInfo(day: 20, theme: 'Stand at the Threshold', action: 'Prepare for the epagomenal days — the births of the gods.', reflection: '"What must I carry across the border of the year?"'),
  ];

  // Shared flow list for Mswt-Rꜥ III (Days 21–30)
  static final List<DecanDayInfo> mswtRaIIIFlowRows = [
    DecanDayInfo(day: 21, theme: 'The First Fracture', action: 'Acknowledge what has broken this year — without shame or denial.', reflection: '"What cracked for a reason?"'),
    DecanDayInfo(day: 22, theme: 'Name the Pieces', action: 'Identify the parts of self, life, or purpose scattered across months.', reflection: '"What lies where it fell?"'),
    DecanDayInfo(day: 23, theme: 'Call the Pieces Back', action: 'Invite what was lost to return — strength, clarity, boundaries.', reflection: '"What wants to return to me?"'),
    DecanDayInfo(day: 24, theme: 'Rebind the Limbs', action: 'Begin reuniting what belongs together — habits, goals, identity.', reflection: '"What naturally goes with what?"'),
    DecanDayInfo(day: 25, theme: 'Excise the False', action: 'Remove what does not belong to your restored self.', reflection: '"What was never truly mine?"'),
    DecanDayInfo(day: 26, theme: 'Anoint the Wounds', action: 'Tend the vulnerable parts of your psyche, body, or home.', reflection: '"What wounds require oil, not armor?"'),
    DecanDayInfo(day: 27, theme: 'Strengthen the Forming', action: 'Reinforce what is returning — stability, order, ritual.', reflection: '"What must be strengthened now, before rebirth?"'),
    DecanDayInfo(day: 28, theme: 'Seal the New Shape', action: 'Commit to the form you will carry into the new year.', reflection: '"What shape am I choosing?"'),
    DecanDayInfo(day: 29, theme: 'Stand as Osiris', action: 'Claim the restored throne of your life — quiet, sovereign, whole.', reflection: '"What authority returns to me through wholeness?"'),
    DecanDayInfo(day: 30, theme: 'Prepare for Birth', action: 'Final purification before the Heriu Renpet. Everything is aligned.', reflection: '"What must be cleansed to welcome the gods?"'),
  ];

  // Shared flow list for Heriu Renpet (Days 1–5)
  static final List<DecanDayInfo> epagomenalIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Awakening', action: 'Water what is dormant — body, mind, plan, altar.', reflection: '"What in me is ready to sprout again?"'),
    DecanDayInfo(day: 2, theme: 'Sight Restored', action: 'Clarify vision; clean lenses, screens, intentions.', reflection: '"What must I see without distortion?"'),
    DecanDayInfo(day: 3, theme: 'Fire Balanced', action: 'Destroy one thing causing disorder or stagnation.', reflection: '"What chaos must I place back into its orbit?"'),
    DecanDayInfo(day: 4, theme: 'Name Remembered', action: 'Speak truth aloud; declare your identity and aim.', reflection: '"What truth restores my power?"'),
    DecanDayInfo(day: 5, theme: 'Threshold Kept', action: 'Honor ancestors, endings, and the unseen.', reflection: '"What must be remembered so nothing is lost?"'),
  ];

  // Shared flow list for Rekh-Nedjes I (Days 1–10)
  static final List<DecanDayInfo> rekhnedjesIFlowRows = [
    DecanDayInfo(day: 1, theme: 'Ground the Apprentice', action: 'Acknowledge you are in training; set one clear focus for these 10 days.', reflection: '"Where in my life am I willing to be a student again?"'),
    DecanDayInfo(day: 2, theme: 'Stand Under the Stars', action: 'Rise early or step outside at night; look for Orion or imagine him.', reflection: '"What does my \'spine\' look like when no one is watching?"'),
    DecanDayInfo(day: 3, theme: 'Quiet Repetition', action: 'Choose one simple skill and repeat it with care, not speed.', reflection: '"Can I love the practice, not just the result?"'),
    DecanDayInfo(day: 4, theme: 'Straighten the Line', action: 'Correct one crooked thing — a habit, schedule, boundary, or object.', reflection: '"Where has my line bent away from Maʿat?"'),
    DecanDayInfo(day: 5, theme: 'Carry the Weight Well', action: 'Do one physically or mentally demanding task with steady pacing.', reflection: '"Do I collapse under weight or learn how to carry it?"'),
    DecanDayInfo(day: 6, theme: 'Listen While Working', action: 'Work in silence or with sacred sound; let insight arise while in motion.', reflection: '"What does endurance teach me that comfort never could?"'),
    DecanDayInfo(day: 7, theme: 'Heat of Trial', action: 'Notice when irritation rises; do not speak until breath has cooled it.', reflection: '"What story do I tell myself when things get hard?"'),
    DecanDayInfo(day: 8, theme: 'Silent Mastery', action: 'Complete a task excellently without announcing it to anyone.', reflection: '"Can I let the work speak louder than my mouth?"'),
    DecanDayInfo(day: 9, theme: 'Hold the Standard', action: 'Review your progress; tighten anything that has grown sloppy.', reflection: '"What minimum level of order will I refuse to fall below?"'),
    DecanDayInfo(day: 10, theme: 'Seal the Lesson', action: 'Record what these 10 days taught you; make one vow for the next decan.', reflection: '"What endurance skill am I formally carrying forward?"'),
  ];

  // Shared flow list for Rekh-Nedjes II (Days 11–20)
  static final List<DecanDayInfo> rekhnedjesIIFlowRows = [
    DecanDayInfo(day: 11, theme: 'Seek the Elders', action: 'Identify one living or ancestral "teacher" whose example you respect.', reflection: '"Whose pattern of life would I be honored to resemble?"'),
    DecanDayInfo(day: 12, theme: 'Ask for Counsel', action: 'Bring one real question about your path to that source of wisdom.', reflection: '"Where am I willing to be corrected?"'),
    DecanDayInfo(day: 13, theme: 'Receive the Mirror', action: 'Listen to feedback without defending yourself.', reflection: '"What truth about me keeps repeating in different mouths?"'),
    DecanDayInfo(day: 14, theme: 'Apprentice in Action', action: 'Apply one piece of counsel immediately in a concrete way.', reflection: '"How does obedience feel in my body?"'),
    DecanDayInfo(day: 15, theme: 'Refine the Craft', action: 'Practice your main skill under a higher standard set by your teachers.', reflection: '"What small adjustment makes my work more honest and precise?"'),
    DecanDayInfo(day: 16, theme: 'Teach What You Know', action: 'Share one lesson you\'ve embodied with someone younger or earlier on.', reflection: '"What do I now carry that is worth passing on?"'),
    DecanDayInfo(day: 17, theme: 'Tend the Lineage', action: 'Honor your line of influence — mentors, ancestors, unseen helpers.', reflection: '"Who kept the light for me before I arrived?"'),
    DecanDayInfo(day: 18, theme: 'Discern the Voices', action: 'Separate wise guidance from noise, fear, or flattery.', reflection: '"Which voices leave me clearer, not more confused or inflated?"'),
    DecanDayInfo(day: 19, theme: 'Choose Your Council', action: 'Consciously select the few people/teachings that will shape your next year.', reflection: '"Who has earned the right to advise my life?"'),
    DecanDayInfo(day: 20, theme: 'Seal the Teaching', action: 'Record the guidance you\'re keeping and the actions it requires.', reflection: '"What teachings will I treat as law for myself going forward?"'),
  ];

  // Shared flow list for Rekh-Nedjes III (Days 21–30)
  static final List<DecanDayInfo> rekhnedjesIIIFlowRows = [
    DecanDayInfo(day: 21, theme: 'Release the Strain', action: 'Acknowledge where you are clenched — body, schedule, or mind — and soften it.', reflection: '"What am I gripping that Maʿat is asking me to loosen?"'),
    DecanDayInfo(day: 22, theme: 'Repair the Breaks', action: 'Fix one small but real crack in your world (canal, budget, boundary).', reflection: '"What fracture, once mended, would let life flow more easily?"'),
    DecanDayInfo(day: 23, theme: 'Clean the Tools', action: 'Wash, sharpen, or organize the instruments of your work.', reflection: '"Are my tools treated as sacred or as afterthoughts?"'),
    DecanDayInfo(day: 24, theme: 'Reconcile Within', action: 'Bring two parts of yourself back into honest agreement.', reflection: '"Where am I telling myself two different stories?"'),
    DecanDayInfo(day: 25, theme: 'Reconcile With Others', action: 'Take one step toward peace with someone where tension lingers.', reflection: '"What would it cost my ego — and save my spirit — to make amends?"'),
    DecanDayInfo(day: 26, theme: 'Stabilize the Rhythm', action: 'Set a sustainable pattern for sleep, work, food, and movement.', reflection: '"Does my current rhythm support peace or sabotage it?"'),
    DecanDayInfo(day: 27, theme: 'Honor Quiet Victories', action: 'Name and bless the small ways you\'ve endured and improved.', reflection: '"What quiet strengths do I usually refuse to acknowledge?"'),
    DecanDayInfo(day: 28, theme: 'Simplify the Load', action: 'Release one obligation, item, or habit that no longer serves Maʿat.', reflection: '"What weight can I lay down without betraying my purpose?"'),
    DecanDayInfo(day: 29, theme: 'Prepare for the Crossing', action: 'Organize records, spaces, and plans for the coming month.', reflection: '"If the year turned tonight, what would I want already in order?"'),
    DecanDayInfo(day: 30, theme: 'Rest in Maʿat', action: 'Practice deliberate rest as sacred duty, not laziness.', reflection: '"Can I trust that the world will not fall if I stop pushing?"'),
  ];

  static final Map<String, KemeticDayInfo> dayInfoMap = {
    // ==========================================================
    // 🌞 THOTH I — DAYS 1–10  (Month of Divine Order & Rebirth)
    // ==========================================================
    'thoth_1_1': KemeticDayInfo(
      gregorianDate: 'March 20, 2025',
      kemeticDate: 'Thoth I – Day 1',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Truth & Right Speech — the spoken word as cosmic law',
      cosmicContext: '''
This is the first breath of the Kemetic year.
The rising of Sopdet marks renewal: flood, fertility, order returning.
Today's words are not casual — they are vows.
To speak truth now is to write the law of your year.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓂀 (Eye of Djehuty) — sacred sight, truthful witnessing',
        colorFrequency: 'Deep indigo and silver — clarity emerging from night',
        mantra: '"My word becomes world."',
      ),
    ),

    'thoth_2_1': KemeticDayInfo(
      gregorianDate: 'March 21, 2025',
      kemeticDate: 'Thoth I – Day 2',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Vision in Right Measure — seeing what is sustainable',
      cosmicContext: '''
Day 2 clarifies vision.
You've spoken truth; now you draw its architecture.
Describe what balance looks and feels like when lived.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓏏 (Palette and Reed) — intention becoming design',
        colorFrequency: 'White over blue — clarity on deep order',
        mantra: '"I see through Ma\'at\'s measure."', // ignore: unnecessary_string_escapes
      ),
    ),

    'thoth_3_1': KemeticDayInfo(
      gregorianDate: 'March 22, 2025',
      kemeticDate: 'Thoth I – Day 3',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Purification Before Building',
      cosmicContext: '''
Flood waters leave both fertile silt and debris.
Day 3 cleans the field before planting.
Remove habits and clutter that choke growth.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓋹 (Ankh) — life-force renewed by clearing',
        colorFrequency: 'Pale blue and white — rinse, reset',
        mantra: '"I renew life through clarity."',
      ),
    ),

    'thoth_4_1': KemeticDayInfo(
      gregorianDate: 'March 23, 2025',
      kemeticDate: 'Thoth I – Day 4',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Naming as Creation',
      cosmicContext: '''
To name is to bind into existence.
Assign names to your projects and disciplines with clarity —
so the universe can respond.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓏠 (Ink Pot & Reed Pen) — authorship of reality',
        colorFrequency: 'Cobalt blue and black — script on cosmic backdrop',
        mantra: '"My words draw the lines of creation."',
      ),
    ),

    'thoth_5_1': KemeticDayInfo(
      gregorianDate: 'March 24, 2025',
      kemeticDate: 'Thoth I – Day 5',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Alignment of Speech and Deed',
      cosmicContext: '''
Day 5 is the heart's weighing.
Compare promise to practice and re-align without shame.
Integrity keeps the year on course.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓂻 (Feet toward the Scales) — walking your talk',
        colorFrequency: 'Gold on black — truth held to light',
        mantra: '"I am balanced in truth."',
      ),
    ),

    'thoth_6_1': KemeticDayInfo(
      gregorianDate: 'March 25, 2025',
      kemeticDate: 'Thoth I – Day 6',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Right Exchange / Sacred Reciprocity',
      cosmicContext: '''
Energy must circulate.
Offer something today — service, gratitude, art.
Giving keeps Ma\'at\'s current alive.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓋴 (Ka in motion) — energy extended outward',
        colorFrequency: 'Deep gold / warm copper — circulation',
        mantra: '"My offering sustains the balance."',
      ),
    ),

    'thoth_7_1': KemeticDayInfo(
      gregorianDate: 'March 26, 2025',
      kemeticDate: 'Thoth I – Day 7',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Purity / Quieting Interference',
      cosmicContext: '''
The river settles; clarity returns.
Fast, bathe, or enter silence.
Stillness separates signal from noise.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓈖 (Water ripple) — calm surface, depth below',
        colorFrequency: 'Blue-white — rinsed and quiet',
        mantra: '"In stillness I return to Ma\'at."',
      ),
    ),

    'thoth_8_1': KemeticDayInfo(
      gregorianDate: 'March 27, 2025',
      kemeticDate: 'Thoth I – Day 8',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Receiving Wisdom',
      cosmicContext: '''
From silence comes message.
Listen for truth that feels like recognition, not novelty.
Write it down — your year is speaking.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓅓 (Ibis of Djehuty) — divine intellect',
        colorFrequency: 'Pearl gray — moonlit logic',
        mantra: '"I hear the language of light."',
      ),
    ),

    'thoth_9_1': KemeticDayInfo(
      gregorianDate: 'March 28, 2025',
      kemeticDate: 'Thoth I – Day 9',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Action in Harmony',
      cosmicContext: '''
Take one physical act that matches your intention.
Small motion anchors spirit into timeline.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓂧 (Hand in act) — will translated into deed',
        colorFrequency: 'Bronze — living will in motion',
        mantra: '"I move as truth moves."',
      ),
    ),

    'thoth_10_1': KemeticDayInfo(
      gregorianDate: 'March 29, 2025',
      kemeticDate: 'Thoth I – Day 10',
      season: '🌊 Akhet – Season of Inundation',
      month: 'Thoth (Djehuty)',
      decanName: 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
      starCluster: '✨ Foremost of the Stars — orientation after uncertainty.',
      maatPrinciple: 'Completion with Gratitude',
      cosmicContext: '''
Close the first cycle with thanks.
Gratitude seals the container so your energy doesn't leak.
Witness what you've built in ten days.''',
      decanFlow: [
        DecanDayInfo(day: 1, theme: 'Genesis of Speech', action: 'Speak your intention for the year clearly — out loud or written.', reflection: '"What truth am I willing to build upon?"'),
        DecanDayInfo(day: 2, theme: 'Vision Declared', action: 'Map the image of what balance looks like for you.', reflection: '"How does my life look when it is aligned?"'),
        DecanDayInfo(day: 3, theme: 'Foundation of Order', action: 'Cleanse your space; remove what contradicts your new truth.', reflection: '"What must be cleared to make way?"'),
        DecanDayInfo(day: 4, theme: 'Naming Power', action: 'Name your projects, goals, or vows with sacred clarity.', reflection: '"What do I call forth into being?"'),
        DecanDayInfo(day: 5, theme: 'Alignment Day', action: 'Perform a Ma\'at ritual — balance the scales of speech and action.', reflection: '"Are my words matching my deeds?"'),
        DecanDayInfo(day: 6, theme: 'First Offering', action: 'Give something symbolic to the world (art, gratitude, time, service).', reflection: '"How does giving anchor truth?"'),
        DecanDayInfo(day: 7, theme: 'Purification', action: 'Fast, bathe, or enter intentional silence to reset signal vs noise.', reflection: '"What noise needs to quiet for clarity to speak?"'),
        DecanDayInfo(day: 8, theme: 'Insight Rising', action: 'Journal or meditate; record what rises without forcing it.', reflection: '"What truth emerges when I listen?"'),
        DecanDayInfo(day: 9, theme: 'Order Manifest', action: 'Take one measurable action in line with your declaration.', reflection: '"What is the first visible sign of alignment?"'),
        DecanDayInfo(day: 10, theme: 'Completion of Utterance', action: 'Re-read Day 1. Seal it with gratitude and decision.', reflection: '"What cycle have I begun?"'),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓏞 (Rolled papyrus) — sealed decree',
        colorFrequency: 'Gold on ivory — sacred contract formalized',
        mantra: '"I seal truth with gratitude."',
      ),
    ),

  'thoth_11_2': KemeticDayInfo(
    gregorianDate: 'March 30, 2025',
    kemeticDate: 'Thoth II – Day 1 (Day 11 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Sacred Service — aligning your effort to something beyond yourself',
    cosmicContext: '''
The first decan (Days 1–10) was about declaration, cleansing, naming, alignment.

Now, in this second decan, you become a carrier of what you spoke. Day 11 is the handoff point:
"This is no longer just my desire — this is my assignment."

You dedicate your work to something larger than ego: family line, community, balance, restoration.

This is the moment you stop treating your path like a wish, and start treating it like a responsibility.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓋴 (Ka in motion) — energy extended outward in rightful proportion',
      colorFrequency: 'Deep gold / warm copper — energy in motion, not hoarded',
      mantra: '"My offering sustains the balance."',
    ),
  ),

  'thoth_12_2': KemeticDayInfo(
    gregorianDate: 'March 31, 2025',
    kemeticDate: 'Thoth II – Day 2 (Day 12 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Reciprocity / Right Exchange',
    cosmicContext: '''
Day 12 is about exchange, not extraction.

This is not "networking." This is sacred commerce: idea for idea, help for help, resource for resource, in fairness.

In Kemet, balance wasn't only spiritual — it was economic. Fair exchange was Ma'at. Unfair exchange was isfet (chaos).

Today, you ask: "Am I moving in circles where energy truly circulates, or am I leaking?"
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓋴 (Ka in motion) — the hand extended, not clenched',
      colorFrequency: 'Warm copper — circulation of value',
      mantra: '"Balance is a living exchange."',
    ),
  ),

  'thoth_13_2': KemeticDayInfo(
    gregorianDate: 'April 1, 2025',
    kemeticDate: 'Thoth II – Day 3 (Day 13 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Circulation of Presence',
    cosmicContext: '''
Day 13 is a "move your body / move your field" day.

In Kemetic rhythm, truth is not supposed to sit still. You carry it. You walk it into new rooms, new people, new opportunities.

Today is for showing up physically where your purpose needs to be seen — even if that's just one intentional trip, one conversation in person, one presence-making act.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓋴 (Ka in motion) — force projected outward, actively carried',
      colorFrequency: 'Sun-warmed bronze — kinetic energy',
      mantra: '"My purpose travels with me."',
    ),
  ),

  'thoth_14_2': KemeticDayInfo(
    gregorianDate: 'April 2, 2025',
    kemeticDate: 'Thoth II – Day 4 (Day 14 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Refinement / Tempering',
    cosmicContext: '''
Day 14 is your sharpening stone.

This is where you cut off the extra, the sloppy, the unfocused. You edit. You refine. You correct tone. You set standards.

The energy of this day is "I respect this work enough to polish it."

In Kemet, that's sacred. Sloppiness is a form of disrespect to the divine pattern.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓃒 / blade / cutting symbol (controlled edge) — discipline, precision',
      colorFrequency: 'Tempered gold — not flashy, refined',
      mantra: '"Precision is devotion."',
    ),
  ),

  'thoth_15_2': KemeticDayInfo(
    gregorianDate: 'April 3, 2025',
    kemeticDate: 'Thoth II – Day 5 (Day 15 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Energetic Accounting',
    cosmicContext: '''
Day 15 is not laziness. It's intelligent conservation.

The question today is: Are you overspending yourself to "prove" you're serious? That's ego, not Ma'at.

Ancient Kemet prized sustainability — crops had to last the whole season. Your energy is the same.

You do a balance check now so you don't burn out in the next decan.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂋 (mouth/measure) + ⚖️ (scales) — self-audit of expenditure',
      colorFrequency: 'Muted bronze and charcoal — controlled burn, not wildfire',
      mantra: '"I spend energy in balance."',
    ),
  ),

  'thoth_16_2': KemeticDayInfo(
    gregorianDate: 'April 4, 2025',
    kemeticDate: 'Thoth II – Day 6 (Day 16 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Right Relationship',
    cosmicContext: '''
Day 16 is reconnection.

In Kemetic cosmology, you are not a lone hero. You are a node in a living network of responsibility and power.

Today is about reaching back to someone (human or ancestor) who stabilizes you — the person who reminds you who you actually are when you drift.

This is maintenance of alignment through relationship.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓇋𓇋 (paired reeds / partnership) — connection, alliance, mutual strengthening',
      colorFrequency: 'Warm gold beside deep blue — companionship next to purpose',
      mantra: '"I keep the ones who keep me aligned."',
    ),
  ),

  'thoth_17_2': KemeticDayInfo(
    gregorianDate: 'April 5, 2025',
    kemeticDate: 'Thoth II – Day 7 (Day 17 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Recommitment with Specificity',
    cosmicContext: '''
Day 17 is "say it again, but sharper."

You return to your vow with upgraded precision. Not "I'll be healthier," but "I will walk 30 mins before 9am daily."

In Kemet, repetition was not weakness — repetition was spellcraft. Repetition carved reality into stone.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏞 (sealed decree / papyrus roll) — vow renewed and re-stamped',
      colorFrequency: 'Ivory with gold edge — formal commitment',
      mantra: '"I restate my oath in clarity."',
    ),
  ),

  'thoth_18_2': KemeticDayInfo(
    gregorianDate: 'April 6, 2025',
    kemeticDate: 'Thoth II – Day 8 (Day 18 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Receiving Without Corruption',
    cosmicContext: '''
Day 18 is about letting abundance land without guilt or distortion.

You did the work. You held alignment. You served. If praise, money, opportunity, visibility, or help shows up — accept it in dignity.

Kemet did not teach "shrink yourself." It taught "carry power in balance."

Today you practice receiving clean.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓅨 (open hands) — acceptance, blessing received',
      colorFrequency: 'Soft gold — prosperity acknowledged, not hidden',
      mantra: '"I receive in balance and remain clean."',
    ),
  ),

  'thoth_19_2': KemeticDayInfo(
    gregorianDate: 'April 7, 2025',
    kemeticDate: 'Thoth II – Day 9 (Day 19 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Closing the Loop',
    cosmicContext: '''
Day 19 is return offering.

Whatever you've received — insight, support, resources — you now send some of that energy back into the field so the circuit is complete.

Without this step, flow becomes hoarding. With this step, flow becomes lineage.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓍑 (loop / tied cord) — completion, knot, obligation honored',
      colorFrequency: 'Copper sealed with dark umber — flow closed, bond kept',
      mantra: '"I return what was given, in balance."',
    ),
  ),

  'thoth_20_2': KemeticDayInfo(
    gregorianDate: 'April 8, 2025',
    kemeticDate: 'Thoth II – Day 10 (Day 20 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'ḥry-ib sbꜣw ("Heart of the Stars")',
      starCluster: '✨ Heart of the Stars — integration before action.',
    maatPrinciple: 'Integration and Transition',
    cosmicContext: '''
Day 20 is the bridge.

You're not just ending a cycle — you're deciding what carries forward into the next one and what stays behind.

Ancient Kemet ran on smooth transitions. No chaos, no lurching. You archive the teachings of this decan so the next one doesn't have to restart from zero.

This is where wisdom becomes infrastructure.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Offering Begins', action: 'Dedicate your current project to something beyond self.', reflection: '"Who benefits from my effort?"'),
      DecanDayInfo(day: 12, theme: 'Exchange', action: 'Trade or share an idea/resource.', reflection: '"What flows because I gave?"'),
      DecanDayInfo(day: 13, theme: 'Circulation', action: 'Movement or travel; stretch your field.', reflection: '"What did I learn from contact?"'),
      DecanDayInfo(day: 14, theme: 'Refinement', action: 'Edit, polish, or temper excess.', reflection: '"What strengthens through restraint?"'),
      DecanDayInfo(day: 15, theme: 'Balance Check', action: 'Rest or partial fast; measure output vs cost.', reflection: '"Where am I overspending energy?"'),
      DecanDayInfo(day: 16, theme: 'Reconnection', action: 'Reach out / reconnect with someone aligned to your purpose.', reflection: '"Who restores my alignment?"'),
      DecanDayInfo(day: 17, theme: 'Recommitment', action: 'Re-state your vow, but louder and more specific.', reflection: '"What deserves another push?"'),
      DecanDayInfo(day: 18, theme: 'Abundance Flow', action: 'Accept prosperity or recognition gracefully.', reflection: '"How do I receive with Ma\'at?"'),
      DecanDayInfo(day: 19, theme: 'Return Offering', action: 'Give back again; close the loop you opened on Day 11.', reflection: '"How can I close this exchange?"'),
      DecanDayInfo(day: 20, theme: 'Transition', action: 'Prepare for the next decan. Archive what matters, release what doesn\'t.', reflection: '"What lesson is ready to move forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂦 (archive / bound scroll / carried bundle) — prepared transfer of knowledge',
      colorFrequency: 'Deep gold edge on matte black — wisdom packed, ready for the next phase',
      mantra: '"I carry forward only what serves Ma\'at."',
    ),
  ),

  // ==========================================================
  // 🌞 THOTH III — DAYS 21–30  (Third Decan)
  // ==========================================================

  'thoth_21_3': KemeticDayInfo(
    gregorianDate: 'April 9, 2025',
    kemeticDate: 'Thoth III, Day 1 (Day 21 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Standing in Role',
    cosmicContext: '''
The first decan (1–10) was "Speak truth."
The second decan (11–20) was "Carry truth into the world."
The third decan (21–30) is "I AM that truth now."
Day 21 is the moment you assume the throne of your own life. You're not pitching who you're becoming — you're embodying who you are. You move like a person whose path is not up for casual debate.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂝 (upraised arm / commanded force) — authority exercised with consciousness',
      colorFrequency: 'Matte black edged in gold — sovereign, contained, self-defined',
      mantra: '"I hold my position in Ma\'at."',
    ),
  ),

  'thoth_22_3': KemeticDayInfo(
    gregorianDate: 'April 10, 2025',
    kemeticDate: 'Thoth III, Day 2 (Day 22 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Protection of the Field',
    cosmicContext: '''
Day 22 is boundary-setting.
In Kemet, sacred spaces were defended. Temples had restricted zones. Not everyone had access to every chamber.
Same with you: not everyone gets direct access to your focus, your emotional channel, your sacred hours.
If you do not guard the field, the field is not sacred — it's public. Day 22 fixes that.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂝 (raised arm in defense / command) — active enforcement, not passive hoping',
      colorFrequency: 'Obsidian edged in copper — "do not cross this line" energy',
      mantra: '"My field is protected."',
    ),
  ),

  'thoth_23_3': KemeticDayInfo(
    gregorianDate: 'April 11, 2025',
    kemeticDate: 'Thoth III, Day 3 (Day 23 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Rhythmic Order',
    cosmicContext: '''
Day 23 is about workflow as ritual.
You're not "trying to be disciplined," you're installing a sacred rhythm. In Kemet, offerings and temple cleanings happened at exact, repeating intervals. That wasn't control freak behavior — it was energetic hygiene.
You're doing the same: defining what repeats in your life because it supports balance.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏛 (tied bundle / ordered arrangement) — organized, repeatable process',
      colorFrequency: 'Deep brown + gold threads — woven stability',
      mantra: '"My rhythm is sacred."',
    ),
  ),

  'thoth_24_3': KemeticDayInfo(
    gregorianDate: 'April 12, 2025',
    kemeticDate: 'Thoth III, Day 4 (Day 24 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Focus Is Sacred',
    cosmicContext: '''
Day 24 is surgical.
You identify what's pulling you off-path — distractions, fake urgency, obligations that don't serve Ma'at — and you cut them.
This is the difference between "I'm busy" and "I'm effective."
In Kemetic terms: you are removing access to the inner sanctuary from anything that is not divine.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓃒 / cutting edge / defensive posture — controlled exclusion',
      colorFrequency: 'Matte black with a thin gold line — focus ring, keep out',
      mantra: '"Distraction does not enter the sanctuary."',
    ),
  ),

  'thoth_25_3': KemeticDayInfo(
    gregorianDate: 'April 13, 2025',
    kemeticDate: 'Thoth III, Day 5 (Day 25 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Stability / Resourcing',
    cosmicContext: '''
Day 25 is inventory.
You check the physical world: money, tools, workspace, health, sleep, nourishment. Can this body and environment SUPPORT the identity you've claimed — not just today, but sustainably?
In Kemet, power was logistics. You cannot embody divine order if your practical base is chaos.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓊖 (walled estate / enclosed domain) — resources arranged under your control',
      colorFrequency: 'Earth gold + stone gray — grounded power',
      mantra: '"My foundation is secured."',
    ),
  ),

  'thoth_26_3': KemeticDayInfo(
    gregorianDate: 'April 14, 2025',
    kemeticDate: 'Thoth III, Day 6 (Day 26 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Lineage / Continuity',
    cosmicContext: '''
Day 26 plugs you into why this matters beyond you.
You're not just doing this for yourself; you are literally a carrier of a current that existed before you and will exist after you.
In Kemet, nothing was "mine," it was "ours across time."
When you see your work like that, it stops being ego performance and becomes custodianship.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓀭 (ancestor / deified forebear) — ancestral presence walking with you',
      colorFrequency: 'Deep amber with dark wine red — bloodline + sunline',
      mantra: '"I walk with those who walked before me."',
    ),
  ),

  'thoth_27_3': KemeticDayInfo(
    gregorianDate: 'April 15, 2025',
    kemeticDate: 'Thoth III, Day 7 (Day 27 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Presentation / Signaling',
    cosmicContext: '''
Day 27 is about how you show up publicly.
Kemet understood appearance, posture, speech style, and titles as part of sacred order. The way you present yourself teaches others how to treat you.
Today's question is: does your exterior presentation match the current you are actually carrying, or are you visually underselling / misbranding yourself?
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓌂 (scepter / staff of office) — visible authority, presence carried in public',
      colorFrequency: 'Polished gold on black — unmistakable signal',
      mantra: '"I present myself as I am."',
    ),
  ),

  'thoth_28_3': KemeticDayInfo(
    gregorianDate: 'April 16, 2025',
    kemeticDate: 'Thoth III, Day 8 (Day 28 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Codifying the Standard',
    cosmicContext: '''
Day 28 is where you write your code.
In Kemet, royal houses, temples, and guilds had explicit standards. "This is how we do things here."
You are doing that for yourself: your rules. Your non-negotiables. Your operating instructions.
This is how future-you (and anyone in your orbit) knows what's sacred and what's off-limits.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏠 (ink pot and reed pen) — law recorded, structure made explicit',
      colorFrequency: 'Cobalt on parchment ivory — script on living order',
      mantra: '"My code is written."',
    ),
  ),

  'thoth_29_3': KemeticDayInfo(
    gregorianDate: 'April 17, 2025',
    kemeticDate: 'Thoth III, Day 9 (Day 29 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Fortification / Defense',
    cosmicContext: '''
Day 29 is defense build-out.
Your identity needs walls, contracts, protections. This is where you think like a strategist: LLCs, NDAs, insurance, time blocks, emotional no-go zones, "this is how you talk to me / this is how you don't."
You're not hardening your heart. You're hardening your perimeter.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓉐 (walled house / fortified enclosure) — protected domain, secured boundary',
      colorFrequency: 'Stone gray with gold seams — defended, but alive',
      mantra: '"What I am building will be kept."',
    ),
  ),

  'thoth_30_3': KemeticDayInfo(
    gregorianDate: 'April 18, 2025',
    kemeticDate: 'Thoth III, Day 10 (Day 30 of Thoth)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Thoth (Djehuty) – Month of Divine Order and Rebirth',
      decanName: 'sbꜣw ("The Stars")',
      starCluster: '✨ The Stars — understanding held in relation.',
    maatPrinciple: 'Sealing Identity',
    cosmicContext: '''
Day 30 is the close of the Month of Thoth.
Today you "name the identity that is now permanent." This is not a mood. This is a station.
In Kemetic logic, once something is ritually sealed, it's binding — and reality orients around it.
You are declaring: "This is who I am going into the next month." That declaration becomes the baseline going forward. You just finished the month of Djehuty. You leave it as someone with order, boundaries, rhythm, lineage, and protection.
''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Claim Authority', action: 'State clearly (to yourself or aloud) who you are in this season — title yourself.', reflection: '"What role do I hold now, without apology?"'),
      DecanDayInfo(day: 22, theme: 'Set Boundaries', action: 'Draw one boundary that protects your work / energy.', reflection: '"What drains me that I will no longer permit?"'),
      DecanDayInfo(day: 23, theme: 'Structure Workflow', action: 'Define repeatable structure: hours, rituals, checkpoints.', reflection: '"What predictable rhythm keeps me aligned?"'),
      DecanDayInfo(day: 24, theme: 'Protect Focus', action: 'Remove distractions, access, or obligations that fracture attention.', reflection: '"Who/what pulls me off my path?"'),
      DecanDayInfo(day: 25, theme: 'Stability Check', action: 'Audit your material base (money, tools, space).', reflection: '"Do I have what I need to sustain this identity?"'),
      DecanDayInfo(day: 26, theme: 'Lineage Alignment', action: 'Connect your purpose to ancestry / legacy / historical current.', reflection: '"Who walked this pattern before me?"'),
      DecanDayInfo(day: 27, theme: 'Public Presentation', action: 'Present yourself in alignment (appearance, language, posture, bio, portfolio, feed).', reflection: '"Does the world see the real current I\'m carrying?"'),
      DecanDayInfo(day: 28, theme: 'Codify Standard', action: 'Write or record your code: how you operate, what you do / don\'t do.', reflection: '"What law do I live under?"'),
      DecanDayInfo(day: 29, theme: 'Fortify the Perimeter', action: 'Put protection in place (legal, financial, emotional, time-guarding).', reflection: '"How do I defend this standard?"'),
      DecanDayInfo(day: 30, theme: 'Lock the Identity', action: 'Close the month of Thoth: archive lessons, name this month\'s core truth.', reflection: '"What identity is now permanent going forward?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓅓 + 𓏞 (the scribe\'s ibis + sealed decree) — wisdom recorded, identity ratified',
      colorFrequency: 'Gold sealed on matte black — royal decree energy',
      mantra: '"This is my station going forward."',
    ),
  ),

  // ==========================================================
  // 🌞 PAOPI I — DAYS 1–10  (Month of Menkhet - The Carrying)
  // ==========================================================

  'paophi_1_1': KemeticDayInfo(
    gregorianDate: 'April 19, 2025',
    kemeticDate: 'Paopi I, Day 1 (Day 1 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet – "The Carrying," "The Bringing")',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Intention Becomes Motion',
    cosmicContext: '''
This is the moment you stop planning and start carrying.
Thoth gave you order in the mind. Paopi forces that order into the body.
In Kemet, as ỉpḏs rose, workers re-entered the floodplain, clearing channels and preparing seed. It was understood as sacred restart — not "back to work like a slave," but "we rejoin the current of life."
Day 1 is you picking up the first load of the new cycle and saying: I am active again.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓍿 (yoke / pole across the shoulders) — literal carrying, sacred duty embodied',
      colorFrequency: 'Wet silt brown with Nile blue — the body moving offerings along the flooded banks',
      mantra: '"What I shoulder is holy."',
    ),
  ),

  'paophi_2_1': KemeticDayInfo(
    gregorianDate: 'April 20, 2025',
    kemeticDate: 'Paopi I, Day 2 (Day 2 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Movement As One Body',
    cosmicContext: '''
Today is about rejoining the current.
In Paopi, nobody pretends to be an island. Labor is communal choreography. Barge pullers chant together. Porters walk shoulder-to-shoulder. Tribute travels in processions, not in secret.
Day 2 asks: Who are you moving with? You're allowed to carry as part of a body. That's Ma'at.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓉐 + 𓈗 (house + flowing water) — the household moving in rhythm with the river, not against it',
      colorFrequency: 'Nile blue lined with gold — shared motion, honored by the divine current',
      mantra: '"We move this together."',
    ),
  ),

  'paophi_3_1': KemeticDayInfo(
    gregorianDate: 'April 21, 2025',
    kemeticDate: 'Paopi I, Day 3 (Day 3 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Rhythmic Endurance',
    cosmicContext: '''
Day 3 is about pace.
The floodplain labor didn't explode in chaos. It settled into repeatable cadence. Song, chant, footfall, pull-pause-pull.
In other words: sustainability is holy.
Today you ask: Can I carry this pace for 10 days without injuring myself, burning out, or poisoning my mood? If not, adjust. That's Ma'at.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏌 (looped cord / measured tether) — controlled tempo, not frantic flailing',
      colorFrequency: 'Deep river blue in even bands — the Nile\'s steady pull',
      mantra: '"My pace is intelligent."',
    ),
  ),

  'paophi_4_1': KemeticDayInfo(
    gregorianDate: 'April 22, 2025',
    kemeticDate: 'Paopi I, Day 4 (Day 4 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Sacred Labor, Not Humiliation',
    cosmicContext: '''
Day 4 is about how you regard your own effort.
In Paopi, carrying tribute for the nome, hauling reeds for repair, bringing fish and papyrus up from the flood — these weren't seen as degrading chores. They were ceremonial. You were literally feeding the nation, feeding the temple, feeding continuity.
If you narrate your work as "I'm struggling," you poison it. If you narrate it as "I am feeding the system that feeds us," you align it with Ma'at.
Today: rename your labor.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓎡 (uplifted hands bearing something upward) — carrying as devotion, not subservience',
      colorFrequency: 'Sun-warm gold over Nile blue — honored work in motion',
      mantra: '"My work is worthy."',
    ),
  ),

  'paophi_5_1': KemeticDayInfo(
    gregorianDate: 'April 23, 2025',
    kemeticDate: 'Paopi I, Day 5 (Day 5 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Shared Load / Shared Survival',
    cosmicContext: '''
Day 5 is redistribution of weight.
This is extremely Old Kingdom: nobody lets one body snap while the rest watch. You rotate. You carry for someone an hour; they carry for you next hour. That's Ma'at in motion.
Today's honesty: Where am I quietly breaking while pretending I'm fine? And also: Who around me is breaking while pretending they're fine?
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓃒 (yoke / two-point carry) — weight shared across more than one shoulder',
      colorFrequency: 'Copper, wet clay, deep river blue — living cooperation',
      mantra: '"Balance is shared, or it\'s not Ma\'at."',
    ),
  ),

  'paophi_6_1': KemeticDayInfo(
    gregorianDate: 'April 24, 2025',
    kemeticDate: 'Paopi I, Day 6 (Day 6 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Only Carry What\'s Aligned',
    cosmicContext: '''
Day 6 is ruthless.
This is the moment in the procession where you look at what's on your shoulder and ask: "Does this even belong to me?"
Because a lot of us are bleeding under loads that are actually someone else's neglect, someone else's laziness, someone else's crisis.
In Paopi logic, carrying misaligned weight is not noble. It's disordered.
Today: Drop what is not yours.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓌡 (standard / emblem carried on a pole) — "I carry what represents me, not what erases me"',
      colorFrequency: 'Black edged in gold — authority over what you agree to bear',
      mantra: '"I refuse loads that are not mine."',
    ),
  ),

  'paophi_7_1': KemeticDayInfo(
    gregorianDate: 'April 25, 2025',
    kemeticDate: 'Paopi I, Day 7 (Day 7 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Speak From Your Station',
    cosmicContext: '''
Day 7 is voice alignment.
In Nile processions, you didn't just lift. You declared. "Bearer of the House of Hathor." "Messenger of the West." "Offering-bearer for the Nome."
Your mouth matched your duty.
Modern version: Stop talking like you're nobody doing random chores. Speak like someone entrusted with delivery.
Your language teaches the world how to regard your work.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂋 (mouth / voice) beside 𓌡 (standard) — the voice that carries authority, not apology',
      colorFrequency: 'Gold over river blue — declared function moving through the floodplain',
      mantra: '"My voice matches my work."',
    ),
  ),

  'paophi_8_1': KemeticDayInfo(
    gregorianDate: 'April 26, 2025',
    kemeticDate: 'Paopi I, Day 8 (Day 8 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Maintain the Carrier',
    cosmicContext: '''
Day 8 is repair/restore.
Paopi is physical. Shoulders bruise. Hands tear. Knees swell. Backs lock. That's real.
Ancients understood this, which is why carriers were fed, cooled, massaged, sung to. Because the carrier is infrastructure.
Today is not "pamper yourself because you earned it." Today is "maintain the machine because the machine is sacred."
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏏 (bread / sustenance) with 𓈗 (water) — feed, water, cool the carrier',
      colorFrequency: 'Clay brown + warm amber + Nile blue — body tended, not ignored',
      mantra: '"The carrier is worth preserving."',
    ),
  ),

  'paophi_9_1': KemeticDayInfo(
    gregorianDate: 'April 27, 2025',
    kemeticDate: 'Paopi I, Day 9 (Day 9 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Honor the Route / Know the Destination',
    cosmicContext: '''
Day 9 is clarity of destination.
You're not just "working hard." You're transporting meaning.
In Paopi, the procession wasn't random cardio. It was delivery: lotus, fish, papyrus, herbs, beer — offerings for Hathor, for the nome, for the household, for the year.
So ask: Where is this load supposed to arrive? Who will eat because you carried this? Who will rest because you carried this?
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓈗 (river / channel) — the path itself is sacred',
      colorFrequency: 'Deep Nile blue edged with gold — guided current with purpose',
      mantra: '"My movement has a destination."',
    ),
  ),

  'paophi_10_1': KemeticDayInfo(
    gregorianDate: 'April 28, 2025',
    kemeticDate: 'Paopi I, Day 10 (Day 10 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ꜥḥꜣy ("The Riser")',
      starCluster: '✨ The Riser — initiation of motion.',
    maatPrinciple: 'Labor As Offering',
    cosmicContext: '''
Day 10 seals the decan of ỉpḏs.
When the procession finally delivered what it carried, that moment was ritual. Goods weren't "dropped off." They were presented — to Hathor, to the nome chief, to the home, to the ancestors.
This is where you acknowledge: "I placed something of value in the world. I delivered."
You're allowed to call that sacred.
''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Accept the Load', action: 'Name what you are now carrying forward from last month.', reflection: '"What work is truly mine to move?"'),
      DecanDayInfo(day: 2, theme: 'Join the Current', action: 'Re-sync with your people / crew / household so you\'re not dragging alone.', reflection: '"Who is moving beside me in this season?"'),
      DecanDayInfo(day: 3, theme: 'Steady the Pace', action: 'Choose a repeatable pace instead of panic bursts.', reflection: '"Can I continue this rhythm for 10 days without collapse?"'),
      DecanDayInfo(day: 4, theme: 'Carry With Grace', action: 'Treat the work as sacred process, not humiliation or desperation.', reflection: '"Do I see my labor as honor or insult?"'),
      DecanDayInfo(day: 5, theme: 'Shared Provisioning', action: 'Shift weight, redistribute load, ask for help, give help.', reflection: '"Where can balanced effort keep us all upright?"'),
      DecanDayInfo(day: 6, theme: 'Alignment in Motion', action: 'Audit the cargo: am I hauling what serves my path, or am I hauling someone else\'s chaos?', reflection: '"Does this weight belong to my purpose?"'),
      DecanDayInfo(day: 7, theme: 'Voice of the Procession', action: 'Speak in alignment with the work you do. Announce yourself like you\'re part of a sacred procession.', reflection: '"Does my language reflect who I actually am?"'),
      DecanDayInfo(day: 8, theme: 'Nourish the Carrier', action: 'Restore the body doing the carrying (rest, water, minerals, food, breath).', reflection: '"What restores the one holding the load?"'),
      DecanDayInfo(day: 9, theme: 'Honor the Route', action: 'Name where this work is headed, and why it matters when it reaches there.', reflection: '"Where is this going, and who will it feed?"'),
      DecanDayInfo(day: 10, theme: 'Consecrate the Labor', action: 'Declare: this is not struggle theater; this is offering.', reflection: '"How does my work stabilize Ma\'at around me?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓊤 (two arms presenting an offering forward) — "Receive what I have carried."',
      colorFrequency: 'Gold laid over deep Nile blue — tribute delivered to life itself',
      mantra: '"My work lands as an offering."',
    ),
  ),

  // ==========================================================
  // 🌞 PAOPI II — DAYS 11–20  (Second Decan - sbšsn)
  // ==========================================================

  'paophi_11_2': KemeticDayInfo(
    gregorianDate: 'April 29, 2025',
    kemeticDate: 'Paopi II, Day 11 (Day 11 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet – "The Carrying / The Bringing")',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Many Small Fires Keep the Land Alive',
    cosmicContext: '''
The first decan of Paopi (ỉpḏs) was one spear of motion: everyone shoulders together, one procession, one surge.
Now sbšsn begins. The procession breaks apart and spreads.
Day 11 is about lighting the outposts. You acknowledge every place that still needs you — children, elders, clients, allies, crew, neighbors, distant family, supporters of your work. The sparks are them.
You are responsible to more than just the one place you're standing.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓇋𓏤 repeated (points/sparks / "each one lit") scattered along 𓈗 (water line) — little lights along the flood channels',
      colorFrequency: 'Ember orange over Nile blue — sparks across the current',
      mantra: '"I keep every fire lit."',
    ),
  ),

  'paophi_12_2': KemeticDayInfo(
    gregorianDate: 'April 30, 2025',
    kemeticDate: 'Paopi II, Day 12 (Day 12 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Send the Provision Outward',
    cosmicContext: '''
Day 12 is not about hoarding. It's about circulation.
This is when boats start running between nomes again, carrying fish, papyrus, oil, herbs, grain, tools. The point isn't "what I have." The point is "what I keep alive by sending."
In modern terms: a transfer, a phone call, a warm meal dropped off, a text that stabilizes somebody, fixing a thing for them they couldn't fix.
You prove someone is not abandoned.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂞 (libation / poured-out gift) along a channel — giving as life support, not showing off',
      colorFrequency: 'Copper and deep water blue — supply flowing out along the river routes',
      mantra: '"I keep the others fed."',
    ),
  ),

  'paophi_13_2': KemeticDayInfo(
    gregorianDate: 'May 1, 2025',
    kemeticDate: 'Paopi II, Day 13 (Day 13 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Build the Lane, Don\'t Wing It',
    cosmicContext: '''
Day 13 is where you formalize the route.
In Kemet this wasn't vibes. They set patterns: "This boat runs between these two nomes every 3 days." "This cousin checks on that elder every morning." "This storage jar always refills that household."
That's civilization.
Today's move: lock in cadence. Don't just "hit me if you need anything." Build an actual channel.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓈉 (district / territory marker) linked to 𓈗 (waterway) — fixed route between places',
      colorFrequency: 'River blue crossed with boundary gold — structured connection',
      mantra: '"I build the lane."',
    ),
  ),

  'paophi_14_2': KemeticDayInfo(
    gregorianDate: 'May 2, 2025',
    kemeticDate: 'Paopi II, Day 14 (Day 14 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Exchange, Not Extraction',
    cosmicContext: '''
Day 14 is about reciprocity.
Kemet understood that if the flow only goes one direction, resentment rots the bond and Maʿat fractures.
So boats don't just drop off. They also pick up. Care doesn't only move down from power; it moves sideways, neighbor to neighbor.
Today you check: Is this relationship mutual, or is somebody being used?
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓍢 (two-way exchange / dual-arms passing) — mutual giving, not one-way tribute',
      colorFrequency: 'Paired amber lights over dark water — warmth flowing in both directions',
      mantra: '"We feed each other."',
    ),
  ),

  'paophi_15_2': KemeticDayInfo(
    gregorianDate: 'May 3, 2025',
    kemeticDate: 'Paopi II, Day 15 (Day 15 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'See the Work You Can\'t See',
    cosmicContext: '''
Day 15 is about witnessing remote labor.
In Paopi, different nomes carry different weight: fishing here, reed-cutting there, repairing levees somewhere else. You don't always see it, but you live off it.
Today is: name and respect the people carrying what you benefit from but don't touch. That includes emotional labor, financial support, home care, holding the kids, doing the boring stability work while you chase the "important" thing.
You do not ignore invisible carriers and still claim Ma'at.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓁐 (watchful eye) above 𓂡 (working arm) — "I see your work"',
      colorFrequency: 'Ember orange on deep indigo — respect given to distant, often unseen fire',
      mantra: '"I honor the labor I don\'t witness."',
    ),
  ),

  'paophi_16_2': KemeticDayInfo(
    gregorianDate: 'May 4, 2025',
    kemeticDate: 'Paopi II, Day 16 (Day 16 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Reinforce the Weak Points',
    cosmicContext: '''
Day 16 is repair duty.
In this phase, you're not just circulating supplies, you're actively shoring up where the system is failing — the overwhelmed friend, the kid slipping, the part of your own routine that's collapsing, the money leak, the structural crack.
You go where Ma'at is wobbling and you stabilize it. That is holy work.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂧 (hand placing / repairing / setting in place) reinforcing 𓉐 (house/structure) — active stabilization',
      colorFrequency: 'Clay, brick red, protective gold — patching the wall before it cracks',
      mantra: '"I go where the balance shakes."',
    ),
  ),

  'paophi_17_2': KemeticDayInfo(
    gregorianDate: 'May 5, 2025',
    kemeticDate: 'Paopi II, Day 17 (Day 17 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Carry Ma\'at In Your Mouth',
    cosmicContext: '''
Day 17 is messaging.
When boats moved between nomes, they didn't just move goods. They moved tone. They carried news, reassurance, warnings, terms of peace.
You are doing that constantly. Your words set atmosphere in spaces you aren't physically inside — via text, call, post, reputation, silence.
So ask: What are you actually exporting emotionally?
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂋 (mouth/voice) carried above 𓈗 (water path) — words traveling on the current',
      colorFrequency: 'Blue-black water with lines of gold — messages sent like light on a river',
      mantra: '"I export Ma\'at with my voice."',
    ),
  ),

  'paophi_18_2': KemeticDayInfo(
    gregorianDate: 'May 6, 2025',
    kemeticDate: 'Paopi II, Day 18 (Day 18 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Tend the Web Before It Tears',
    cosmicContext: '''
Day 18 is early conflict resolution.
Distributed systems break from silence, not from drama. Resentment builds quietly in the outposts. Someone feels ignored. Someone feels used. Someone feels like the only one doing real work.
Today you scan for fracture lines — envy, fatigue, miscommunication, hunger — and you treat it before it becomes rupture.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏚 (cord/binding) repaired before it snaps — keeping connection intact',
      colorFrequency: 'Ember orange around a stress point in dark blue — heat where the break would start',
      mantra: '"I fix the tension early."',
    ),
  ),

  'paophi_19_2': KemeticDayInfo(
    gregorianDate: 'May 7, 2025',
    kemeticDate: 'Paopi II, Day 19 (Day 19 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'See the Whole Network',
    cosmicContext: '''
Day 19 is wide-angle vision.
You zoom out and map the whole field: Where are my resources? Where are my weak points? Who is doing what? Who has surplus? Who is starving? Where is Ma'at stable? Where is it thin?
Ancient administrators did this constantly — not as greed, but as balance management.
Today's truth moment: Do you actually understand the system you're inside, or are you just reacting to every ping?
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓇾 (papyrus marsh / district map) over 𓈗 (waterways) — a managed web of sites and channels',
      colorFrequency: 'Deep blue with branching gold lines — the living network visualized',
      mantra: '"I see the whole field."',
    ),
  ),

  'paophi_20_2': KemeticDayInfo(
    gregorianDate: 'May 8, 2025',
    kemeticDate: 'Paopi II, Day 20 (Day 20 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
      starCluster: '✨ Heart of the Riser — sustained, aware motion.',
    maatPrinciple: 'Bless the Distributed Body',
    cosmicContext: '''
Day 20 ends the decan of sbšsn.
The teaching is humility: You are not the whole system. You are one spark in a constellation that keeps the land alive.
This day is about openly honoring that. You give thanks to the network — the helpers, runners, fixers, watchers, steady ones, early risers, quiet holders, givers of warmth.
You include yourself in that blessing. You are part of why balance still exists.
''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Spark the Outposts', action: 'Identify every place / person / pocket of your world that needs touch, presence, or supply from you.', reflection: '"Who depends on me staying connected, not disappearing?"'),
      DecanDayInfo(day: 12, theme: 'Send the Carry Forward', action: 'Deliver something outward: a resource, message, payment, repair, comfort, protection — even if it\'s small.', reflection: '"What can I send that proves \'you are not abandoned\'?"'),
      DecanDayInfo(day: 13, theme: 'Establish Channels', action: 'Formalize the lane: schedule, route, contact rhythm, standing check-in.', reflection: '"How do I keep this connection alive without chaos?"'),
      DecanDayInfo(day: 14, theme: 'Exchange, Not Extraction', action: 'Make sure the flow goes both ways — this is partnership, not tribute.', reflection: '"Is this relationship mutual, or am I draining or being drained?"'),
      DecanDayInfo(day: 15, theme: 'Witness the Remote Labor', action: 'Acknowledge work happening away from you. Name and respect what others are carrying where you can\'t see them.', reflection: '"Who is holding it down in silence, and have I honored them?"'),
      DecanDayInfo(day: 16, theme: 'Reinforce Weak Zones', action: 'Go where the system is thin, tired, or unstable and strengthen it.', reflection: '"Where is Ma\'at wobbling right now, and how can I steady it?"'),
      DecanDayInfo(day: 17, theme: 'Carry Messages of Ma\'at', action: 'Speak peace, structure, clarity across distance. Set emotional tone in the spaces you touch.', reflection: '"What tone am I sending into rooms I\'m not physically in?"'),
      DecanDayInfo(day: 18, theme: 'Tend the Network Health', action: 'Check for resentment, isolation, miscommunication, resource starving. Repair tension fast.', reflection: '"Where is fracture starting?"'),
      DecanDayInfo(day: 19, theme: 'Account for the Web', action: 'Step back and map the whole web — where resources are, where they need to go next.', reflection: '"Do I understand the system I\'m part of, or am I just reacting?"'),
      DecanDayInfo(day: 20, theme: 'Bless the Distributed Body', action: 'Offer gratitude and blessing to everyone in the network, including yourself.', reflection: '"Can I honor this whole body of effort, not just the piece I touch?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓊤 (offering arms) radiating small sparks 𓇋𓇋𓇋 — blessing sent out to all nodes',
      colorFrequency: 'Ember gold on midnight blue — a constellation, not a spotlight',
      mantra: '"We keep Ma\'at alive together."',
    ),
  ),

  // ==========================================================
  // 🌞 PAOPI III — DAYS 21–30  (Third Decan - ḫntt ḥrt)
  // ==========================================================

  'paophi_21_3': KemeticDayInfo(
    gregorianDate: 'May 9, 2025',
    kemeticDate: 'Paopi III, Day 21 (Day 21 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet – "The Carrying / The Bringing")',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'You Are Now Responsible',
    cosmicContext: '''The first Paopi decan (ỉpḏs) was muscle.
The second (sbšsn) was distribution and connection.
Now ḫntt ḥrt begins, and the energy shifts: stewardship.

Day 21 is you accepting that you are not just a mover in the system — you are a keeper of the system. That's different.

Priests said this decan was "the banner before Ra," which means:
carry yourself like you answer to light, not to ego.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓌡 (standard / banner) carried before the sun — "I am carrying responsibility in front of the light"',
      colorFrequency: 'Solar gold above deep river blue — earthly labor answerable to higher order',
      mantra: '"I am keeper, not consumer."',
    ),
  ),

  'paophi_22_3': KemeticDayInfo(
    gregorianDate: 'May 10, 2025',
    kemeticDate: 'Paopi III, Day 22 (Day 22 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Inspect the Channels',
    cosmicContext: '''
Day 22 is literal inspection.
In Kemet this is where you walk the canals and levees and check for breaches, blockages, theft, weak banks.

In your life, "canals" = the paths where energy/resources/emotion/money/attention are supposed to travel.
If a canal is leaking, Ma'at drains out.

Today's job: go look.
Stop assuming it's fine because you're tired of checking.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓈗 (waterway / canal) under 𓁹 (the eye) — "the channels are being watched"',
      colorFrequency: 'Nile blue under clear gold — light tracing the waterlines',
      mantra: '"I check where the lifeblood flows."',
    ),
  ),

  'paophi_23_3': KemeticDayInfo(
    gregorianDate: 'May 11, 2025',
    kemeticDate: 'Paopi III, Day 23 (Day 23 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Verify the Storehouse',
    cosmicContext: '''
Day 23 is audit day.
Ancient temple accountants literally counted grain, oil, fish, linen, incense, silver, beer.
No "we're good." Show me the jar. Open the seal.

For you: check cash, time, energy, promises.
Are the numbers real, or are you lying to yourself to feel safe?

There is no Ma'at in cooked books.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓎝 (sealed jar / store vessel) under inspection — counted in front of the banner of Ra',
      colorFrequency: 'Clay jar brown and solar gold — resources measured in truth',
      mantra: '"I count what is real, not what I wish."',
    ),
  ),

  'paophi_24_3': KemeticDayInfo(
    gregorianDate: 'May 12, 2025',
    kemeticDate: 'Paopi III, Day 24 (Day 24 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Call Out Rot',
    cosmicContext: '''
Day 24 is uncomfortable but necessary.
If someone is sabotaging the flow — stealing resources, poisoning morale, playing victim to dodge duty, pretending loyalty while draining you — you name it. Calm. Direct. Clean.

This is not drama. This is sanitation.
Kemet did not confuse "keeping peace" with "hiding rot." Rot spreads.

You are allowed to say "This is corruption," and still be in Ma'at.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂋 (mouth / declaration) + 𓆣 (coil / decay / snake imagery) — naming the corruption so it can be removed',
      colorFrequency: 'Bright gold against dark rot — light exposing infection',
      mantra: '"I expose what would rot the balance."',
    ),
  ),

  'paophi_25_3': KemeticDayInfo(
    gregorianDate: 'May 13, 2025',
    kemeticDate: 'Paopi III, Day 25 (Day 25 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Restore Standards',
    cosmicContext: '''
Day 25 is boundary work.
Once you've named the rot, you have to reset the line:

"This is how we move.
This is what's acceptable.
This is what will not happen anymore."

In Nile terms: You re-mark the canal banks so the flood won't eat the village.
In modern terms: policy, rule, expectation, vow, consequence.

That is not cruelty. That is protection of Ma'at.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏭 (boundary marker / staked limit) next to 𓌡 (standard) — the law carried in public',
      colorFrequency: 'Bright line of gold cutting across deep blue — the boundary re-drawn so water doesn\'t swallow the village',
      mantra: '"I state the line, and I hold it."',
    ),
  ),

  'paophi_26_3': KemeticDayInfo(
    gregorianDate: 'May 14, 2025',
    kemeticDate: 'Paopi III, Day 26 (Day 26 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Put the Right People in the Right Role',
    cosmicContext: '''
Day 26 is reassignment.
This is where you say, "You can't hold this role. You keep dropping it. You burn it. You corrupt it. I'm moving this to someone who can."

In Kemet, that stopped famine.
In families, that stops resentment.
In teams, that stops collapse.

It's not punishment. It's correcting misalignment so Ma'at can survive the next season.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂧 (hand placing / assigning) over 𓌡 (standard / charge) — "I place this standard in your hands now"',
      colorFrequency: 'Gold (authority) being set into clay (real world) — duty placed where it can live',
      mantra: '"I give the role to the true carrier."',
    ),
  ),

  'paophi_27_3': KemeticDayInfo(
    gregorianDate: 'May 15, 2025',
    kemeticDate: 'Paopi III, Day 27 (Day 27 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Seal the Agreements',
    cosmicContext: '''
Day 27 is contract energy.
After reassignment, you lock in who is doing what, on what timeline, with what support, and what success looks like. No ambiguity.

In Nile terms: who tends which canal bank; who owes which rations; who ensures which storehouse stays clean.
In modern terms: "Here is exactly what we are doing, and here is what you can expect from me."

Ma'at does not run on vibes.
It runs on clarity.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓏭 (boundary mark / contract line) + 𓂋 (spoken word) — agreement spoken and fixed',
      colorFrequency: 'Gold line sealed into clay — a promise made real',
      mantra: '"We move in declared agreement."',
    ),
  ),

  'paophi_28_3': KemeticDayInfo(
    gregorianDate: 'May 16, 2025',
    kemeticDate: 'Paopi III, Day 28 (Day 28 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Report Up to the Light',
    cosmicContext: '''
Day 28 is accountability upward.
You speak the real status: what is healthy, what is damaged, what you fixed, what you couldn't, what support you need. You don't hide it to appear strong.

In Old Kingdom practice, this is literally priestly and administrative reporting.
Spiritually: this is confession without shame. "Here is the truth of my domain."''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓁹 (the Eye / divine sight) above 𓌡 (the standard) — "I report under the gaze of light"',
      colorFrequency: 'Solar gold over dark blue — truth delivered to the light without flinching',
      mantra: '"I tell the truth upward."',
    ),
  ),

  'paophi_29_3': KemeticDayInfo(
    gregorianDate: 'May 17, 2025',
    kemeticDate: 'Paopi III, Day 29 (Day 29 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet)',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Stabilize the System',
    cosmicContext: '''
Day 29 is reinforcement and lock-down.
Now that you've inspected, audited, called out rot, reassigned, and sealed agreements, you physically patch things so they'll survive the next cycle.

In Nile terms: reinforce the canal bank before the water drops and the walls crack.
In you: repair, redistribute, finalize, set guards, put systems in place so things don't fall apart the second you look away.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓉐 (house / structure) reinforced by 𓂧 (hand setting support in place) — fortifying the structure',
      colorFrequency: 'Clay red and steady gold — repaired walls holding firm',
      mantra: '"I leave this stable, not shaky."',
    ),
  ),

  'paophi_30_3': KemeticDayInfo(
    gregorianDate: 'May 18, 2025',
    kemeticDate: 'Paopi III, Day 30 (Day 30 of Paopi / Menkhet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Paopi (Menkhet – "The Carrying / The Bringing")',
      decanName: 'sbꜣ nfr ("The Beautiful Star")',
      starCluster: '✨ The Beautiful Star — continuity proven in motion.',
    maatPrinciple: 'Stewardship Before the Sun',
    cosmicContext: '''
Day 30 ends Paopi.
Paopi began with bodies carrying (ỉpḏs).
It spread into a network of living connection (sbšsn).
It ends here, under ḫntt ḥrt, with you standing in front of the light saying:

"I watched it. I protected it. I corrected it. I did not pretend."

This is not pride. This is accountability to Ma'at.
You hand the month back clean.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Step Into Stewardship', action: 'Accept that you are now responsible for guarding what was moved and shared.', reflection: '"What territory / people / system am I responsible for protecting right now?"'),
      DecanDayInfo(day: 22, theme: 'Inspect the Channels', action: 'Check for leaks, blockages, weak banks, damage, theft, decay in the routes (money flow, emotional flow, resource flow).', reflection: '"Where is loss happening?"'),
      DecanDayInfo(day: 23, theme: 'Verify the Storehouse', action: 'Count what\'s actually there vs what was promised. No fantasy math.', reflection: '"Are the accounts honest?"'),
      DecanDayInfo(day: 24, theme: 'Call Out Rot', action: 'Name corruption / laziness / sabotage / lies — calmly, factually.', reflection: '"Where is someone faking alignment with Ma\'at but actually draining it?"'),
      DecanDayInfo(day: 25, theme: 'Restore Standards', action: 'Reassert boundaries, expectations, and codes of conduct.', reflection: '"What line must be redrawn so balance survives?"'),
      DecanDayInfo(day: 26, theme: 'Reassign Responsibility', action: 'Move duties to the people who can actually carry them without collapse or betrayal.', reflection: '"Who should really be holding this role?"'),
      DecanDayInfo(day: 27, theme: 'Seal the Agreements', action: 'Make it explicit: who is doing what, for whom, by when, with what support.', reflection: '"Do we all understand what we just agreed to?"'),
      DecanDayInfo(day: 28, theme: 'Report Up to the Light', action: 'Acknowledge openly (to yourself, to your people, to Source) what is true — progress and failures.', reflection: '"Can I speak the real status without flinching?"'),
      DecanDayInfo(day: 29, theme: 'Stabilize the System', action: 'Patch, repair, redistribute, lock things down so they hold through the next month.', reflection: '"What needs to be fixed today so it won\'t break tomorrow?"'),
      DecanDayInfo(day: 30, theme: 'Offer Stewardship Back to Ra', action: 'Close the cycle by saying: I watched this in truth. I protected it. I stayed clean.', reflection: '"Did I act as keeper of Ma\'at, or as owner?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓌡 (standard / banner) lifted before 𓂀 (Ra\'s eye/light) — presenting clean stewardship to the sun',
      colorFrequency: 'Full solar gold over deep indigo — work raised up to be judged in light',
      mantra: '"I return this in truth."',
    ),
  ),

  // ==========================================================
  // 🌞 HATHOR I — DAYS 1–10  (First Decan - sꜣḥ)
  // ==========================================================

  'hathor_1_1': KemeticDayInfo(
    gregorianDate: 'May 19, 2025',
    kemeticDate: 'Hathor I, Day 1 (Day 1 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet) — Hathor, "House of Horus," golden cow whose body is the sky, patron of joy that heals',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'You Lived. Honor That.',
    cosmicContext: '''The flood tested you. Paopi demanded carrying, distributing, protecting, auditing.
Hathor opens with mercy.

Day 1 is not "get back to work." Day 1 is witness.
Say out loud: "I made it through that."

Ancient farmers looked out over wet black earth shining under dawn and breathed.
The canals held. The house still stands.

This day is sacred because you're still here.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'ḥwt-ḥr (𓉗𓅃) — "House of Horus," the womb/temple that shelters light',
      colorFrequency: 'Warm gold over fertile black earth — joy returning to a world that just survived chaos',
      mantra: '"My survival is holy."',
    ),
  ),

  'hathor_2_1': KemeticDayInfo(
    gregorianDate: 'May 20, 2025',
    kemeticDate: 'Hathor I, Day 2 (Day 2 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Put Your Body Back in Safety',
    cosmicContext: '''Hathor is not only cosmic cow; she's tenderness made structural.

Day 2 is about somatic reset: breath, spine, hydration, sleep, stretch, warmth, touch.
The Kemite knew: a body in tension cannot carry Ma'at with softness.

You can't pour beauty into the world if you're clenched and starving.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂝 (uplifted arm / vitality) inside ḥwt (enclosure/house) — "the body protected"',
      colorFrequency: 'Milk white and warm gold — nourishment and sun on skin',
      mantra: '"My body is allowed to heal."',
    ),
  ),

  'hathor_3_1': KemeticDayInfo(
    gregorianDate: 'May 21, 2025',
    kemeticDate: 'Hathor I, Day 3 (Day 3 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Clear the Path So Joy Can Walk',
    cosmicContext: '''After flood season, the land is muddy, cluttered, chaotic.
Before you can plant, you harrow — break crust, clear debris, smooth channels.

Day 3 is harrow energy.
You gently clean your path: your space, your inbox, your calendar, your promises.
You clear stale obligations that are not aligned with Ma'at.

This is not "burn it all down."
This is "make the lane walkable."''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'sweeping arm 𓂣 clearing before ḥwt (house) — "prepare the threshold"',
      colorFrequency: 'Fresh earth brown and lotus green — cleaned ground, ready to receive life',
      mantra: '"I make room for life to grow."',
    ),
  ),

  'hathor_4_1': KemeticDayInfo(
    gregorianDate: 'May 22, 2025',
    kemeticDate: 'Hathor I, Day 4 (Day 4 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Invite Joy, On Purpose',
    cosmicContext: '''Pleasure in Hathor's month is not "treat yourself and forget the world."
Pleasure is medicine, morale, spiritual glue.

Day 4: choose one form of sweetness — scent, music, softness, dance, taste, touch, art — but do it awake. Not binge. Not numb. A devotional sweetness.

The Kemites brewed sweet beer, wore lotus, played music, touched each other with tenderness.
That wasn't laziness.
That was maintenance of spirit.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'mirror/sistrum energy (Hathor\'s rattle) — joy as sacred instrument, not distraction',
      colorFrequency: 'Rose-gold and lotus blue — pleasure with clarity',
      mantra: '"My joy is disciplined, not reckless."',
    ),
  ),

  'hathor_5_1': KemeticDayInfo(
    gregorianDate: 'May 23, 2025',
    kemeticDate: 'Hathor I, Day 5 (Day 5 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Restore the Sanctuary',
    cosmicContext: '''Day 5 is house-repair / nest-repair.
You put your physical world back in Ma'at: sheets washed, floors cleared, altar refreshed, workspace aligned, cooking space reset.

The Kemite didn't split "holy" and "home."
The bed, the kitchen, the courtyard, the shrine — same ecosystem.

You are literally rebuilding your temple.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓉐 (house / sacred enclosure) under Hathor\'s name — "the house as shrine"',
      colorFrequency: 'Fresh linen white and sunlit gold',
      mantra: '"My space is holy again."',
    ),
  ),

  'hathor_6_1': KemeticDayInfo(
    gregorianDate: 'May 24, 2025',
    kemeticDate: 'Hathor I, Day 6 (Day 6 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Warm the Bonds',
    cosmicContext: '''Day 6 is relational repair.
In flood/strain mode, you go cold just to survive. You go distant. You get sharp.

This day is "I'm here again."
Not to fix, not to argue logistics, not to lecture. Just to be soft and present in someone's space.

In Kemet: couples sought fertility, artists sought inspiration, families rejoined under Hathor's blessing.
Connection itself was seen as medicine to the land.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'two arms embracing 𓂝𓂝 around a heart/offering — held, not alone',
      colorFrequency: 'Soft rose and skin-warm gold',
      mantra: '"My presence is comfort."',
    ),
  ),

  'hathor_7_1': KemeticDayInfo(
    gregorianDate: 'May 25, 2025',
    kemeticDate: 'Hathor I, Day 7 (Day 7 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Beauty as Offering',
    cosmicContext: '''Day 7 is active offering.
Cook something nourishing. Dress the body with care. Write the words that heal. Light the room. Make music. Speak blessing.

This is not performance. It's devotion.
In Hathor's month, beauty itself was temple service.

Your softness can be someone else's survival point.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'offering arms 𓊤 lifting a lotus 𓆸 — "I raise beauty to the world"',
      colorFrequency: 'Lotus blue and honey gold',
      mantra: '"My beauty blesses, it doesn\'t just impress."',
    ),
  ),

  'hathor_8_1': KemeticDayInfo(
    gregorianDate: 'May 26, 2025',
    kemeticDate: 'Hathor I, Day 8 (Day 8 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Bring Work Back With Grace',
    cosmicContext: '''Day 8 is where routine starts again — but you refuse to re-enter grind mode like nothing happened.

You ask: How can I fulfill my duties without burning the vessel?
Hathor rejects self-erasure.

This is the opposite of "collapse now, hustle later."
This is "structure my rhythm so I don't collapse."''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'working arm 𓂡 paired with Hathor\'s standard 𓉗𓅃 — labor under protection, not under abuse',
      colorFrequency: 'Gold on calm earth brown',
      mantra: '"My work serves Ma\'at, not my destruction."',
    ),
  ),

  'hathor_9_1': KemeticDayInfo(
    gregorianDate: 'May 27, 2025',
    kemeticDate: 'Hathor I, Day 9 (Day 9 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Walk Like You Are Worthy',
    cosmicContext: '''In survival mode, you shrink. You get practical, grim, efficient. You feel "dirty," "tired," "less than."

Day 9 is image healing.
It's posture, voice, gaze, grooming, presentation — not as vanity, but as alignment.

Hathor teaches that radiance isn't arrogance.
Radiance is proof that life is still flowing.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Hathor\'s face in mirror (sacred mirror iconography), reflecting light back without apology',
      colorFrequency: 'Polished gold and deep indigo',
      mantra: '"My presence is allowed to shine."',
    ),
  ),

  'hathor_10_1': KemeticDayInfo(
    gregorianDate: 'May 28, 2025',
    kemeticDate: 'Hathor I, Day 10 (Day 10 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sꜣḥ ("Sah")',
      starCluster: '✨ Sah — stability regained.',
    maatPrinciple: 'Thank the Ones Who Held You',
    cosmicContext: '''Day 10 is offering and gratitude.
In Kemet, people poured beer into the Nile, hung lotus garlands, lifted music to the goddess.
Gratitude was ritual, not just thought.

Today is: name and thank what carried you — your own body, your ancestors, your people, your tools, your discipline, your Source.

Hathor's month teaches that joy is not naive.
Joy is earned survival, honored.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Step Back Onto the Earth', action: 'Acknowledge: you survived the flood season. Name what you just carried.', reflection: '"What did I make it through?"'),
      DecanDayInfo(day: 2, theme: 'Re-center the Body', action: 'Ground in the physical: breath, spine, feet, joints, hydration, warmth, sleep.', reflection: '"Is my body safe and calm?"'),
      DecanDayInfo(day: 3, theme: 'Clear and Sweep the Path', action: 'Light cleanse of your space / calendar / obligations. Remove stale obligations that no longer serve Ma\'at.', reflection: '"What clutter pulls me out of balance?"'),
      DecanDayInfo(day: 4, theme: 'Invite Joy On Purpose', action: 'Bring in sweetness: music, scent, softness, beauty. Choose one delight intentionally, not as escape.', reflection: '"What beauty actually restores me (not numbs me)?"'),
      DecanDayInfo(day: 5, theme: 'Restore the House/Sanctuary', action: 'Tend home, altar, workspace, bed, kitchen. Re-establish order that supports you.', reflection: '"Does my daily space reflect the life I say I\'m living?"'),
      DecanDayInfo(day: 6, theme: 'Warm the Bonds', action: 'Reconnect gently with close people (family, partner, child, friend) without agenda.', reflection: '"Who needs to feel me present, calm, and loving — not fixing, just present?"'),
      DecanDayInfo(day: 7, theme: 'Offer Beauty as Service', action: 'Make or share something beautiful (meal, words, care, style, scent) as an offering, not a flex.', reflection: '"Can my presence make the space softer for someone else today?"'),
      DecanDayInfo(day: 8, theme: 'Align Work With Grace', action: 'Bring your duties back online — but in rhythm, not panic. Rebuild routine that honors both output and well-being.', reflection: '"Can I work in a way that doesn\'t grind my spirit?"'),
      DecanDayInfo(day: 9, theme: 'Stand in Worth', action: 'Check self-image. Release shame stories from survival mode. Carry yourself like Hathor: dignified, vibrant, whole.', reflection: '"Do I move like I believe I deserve balanced joy?"'),
      DecanDayInfo(day: 10, theme: 'Give Thanks for Safe Return', action: 'Gratitude ritual: thank body, land, helpers, ancestors, Source. Mark survival as sacred, not accidental.', reflection: '"Who/what held me up while I was in the flood?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓊤 (offering arms raised) + lotus 𓆸 + ḥwt-ḥr sign — thanksgiving lifted toward the golden cow of the sky',
      colorFrequency: 'Honey gold, lotus blue, fertile black earth — joy anchored in survival and land',
      mantra: '"I honor what kept me alive."',
    ),
  ),

  // ==========================================================
  // 🌞 HATHOR II — DAYS 11–20  (Second Decan - ḥry-ib sꜣḥ)
  // ==========================================================

  'hathor_11_2': KemeticDayInfo(
    gregorianDate: 'May 29, 2025',
    kemeticDate: 'Hathor II, Day 11 (Day 11 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet — "House of Horus")',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Declare We',
    cosmicContext: '''The first Hathor decan (ḫntt ẖrt) was you returning to your body, your home, your worth.
The second decan (ṯms n ḫntt) says: now return to your people.

Day 11 is naming the partnership honestly.
Not vague "us," not codependent blur.
Specific: "Me + You are doing this work together."

In Kemet, this is the moment crews actually formed to rebuild channels and repair granaries after flood stress. The bond was spoken out loud.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'two walking figures side by side 𓂝𓂝 beneath one standard — "companions under one purpose"',
      colorFrequency: 'Twin gold lines on rich earth brown — partnership grounded in real work',
      mantra: '"This bond is intentional."',
    ),
  ),

  'hathor_12_2': KemeticDayInfo(
    gregorianDate: 'May 30, 2025',
    kemeticDate: 'Hathor II, Day 12 (Day 12 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Sync the Rhythm',
    cosmicContext: '''Day 12 is pace-setting.
You and your person/crew decide: When are we working? When are we resting? When do we check in?

This prevents resentment from "You're tired now? NOW? When I finally need you?"

Kemet ran on rhythm — rowing chants, field songs, grinding songs.
Harmony wasn't cute. It was logistics.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'metronomic drum / clapper + two feet in stride — shared tempo',
      colorFrequency: 'Warm gold pulsing over deep river blue — steady beat over flowing water',
      mantra: '"We set our pace together."',
    ),
  ),

  'hathor_13_2': KemeticDayInfo(
    gregorianDate: 'May 31, 2025',
    kemeticDate: 'Hathor II, Day 13 (Day 13 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Share the Load Fairly',
    cosmicContext: '''Day 13 is redistribution.
Who is quietly doing 80% of the house work / money work / emotional work / parenting work / clean-up work / damage control work — and pretending they're fine?

In Hathor's logic, love is not "I'll kill myself so you can rest."
Love is "We carry this in a way that doesn't break either one of us."

In Kemet, this kept households from collapsing.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'load-bearing pole balanced across two shoulders — literal two-person carry bar',
      colorFrequency: 'Paired earth-brown silhouettes under shared band of gold',
      mantra: '"We don\'t exhaust one to spare the other."',
    ),
  ),

  'hathor_14_2': KemeticDayInfo(
    gregorianDate: 'June 1, 2025',
    kemeticDate: 'Hathor II, Day 14 (Day 14 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Be Honest in Friction',
    cosmicContext: '''Day 14 is the conversation nobody wants to have until it's already toxic.

This is: "Here's where I feel abandoned," "Here's where I'm overwhelmed,"
"Here's where I don't feel respected,"
said without humiliation, without name-calling.

In Kemetic survival logic, unresolved resentment wrecks harvests.
Harmony is not silence. Harmony is clean truth early.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: '𓂋 (truth spoken) between two figures — "truth placed between us, not used against us"',
      colorFrequency: 'Gold line between two bodies, not cutting them apart but linking them cleanly',
      mantra: '"We speak truth to heal, not to win."',
    ),
  ),

  'hathor_15_2': KemeticDayInfo(
    gregorianDate: 'June 2, 2025',
    kemeticDate: 'Hathor II, Day 15 (Day 15 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Repair the Commons',
    cosmicContext: '''Day 15 is where y'all fix the actual shared system.
Not theory. Actual fix.

That could be: how food gets handled, how money moves, how kid schedule works,
how the workspace is set, how chores are divided, how you're tracking time.

Kemet knew: if the canal wall breaks, it floods both houses.
So you fix the canal wall together.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'canal wall 𓈗 + repair hand 𓂧 — "we shore up what protects both of us"',
      colorFrequency: 'Mud brown reinforced with steady gold — stability as love',
      mantra: '"We fix the system, not each other."',
    ),
  ),

  'hathor_16_2': KemeticDayInfo(
    gregorianDate: 'June 3, 2025',
    kemeticDate: 'Hathor II, Day 16 (Day 16 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'I Guard You / You Guard Me',
    cosmicContext: '''Day 16 is mutual protection.

You say out loud:
"When you're not in the room, I hold you up, not tear you down."

That is sacred. That's Hathor loyalty.
Protection is Ma'at because it preserves dignity,
and dignity preserves stability.

Kemet understood reputation as infrastructure.
If somebody slanders you, that can cost food.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'protective arm curved around another figure (embrace / shielding gesture) under a shared standard',
      colorFrequency: 'Deep indigo (night watch) and protective gold',
      mantra: '"I hold your name clean."',
    ),
  ),

  'hathor_17_2': KemeticDayInfo(
    gregorianDate: 'June 4, 2025',
    kemeticDate: 'Hathor II, Day 17 (Day 17 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Honor What We Built Together',
    cosmicContext: '''Day 17 is recognition.
Not "Look what I did."
"We did that."

Give actual praise for shared wins — money stabilized, kids fed, crisis handled,
canal patched, house cleaned, account protected, peace kept.

Kemet made music in the fields during work for a reason.
Celebration wasn't extra.
It bonded crews so they'd keep showing up.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'joined hands / clasped wrists symbolizing alliance (classic mutual-aid posture in reliefs)',
      colorFrequency: 'Paired gold glow — two lights, not one',
      mantra: '"We acknowledge our shared strength."',
    ),
  ),

  'hathor_18_2': KemeticDayInfo(
    gregorianDate: 'June 5, 2025',
    kemeticDate: 'Hathor II, Day 18 (Day 18 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Refine the System Together',
    cosmicContext: '''Day 18 is shared optimization.

Now that you've talked honesty (Day 14),
repaired infrastructure (Day 15),
and affirmed loyalty (Day 16–17),
you co-engineer the routine going forward.

This is literally process design.
"How do mornings go?"
"How does money move?"
"How do we protect alone-time without resentment?"

In Kemet, this is how you prevent next month's crisis.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'straight measuring cord / plumb line held by two hands — cooperative alignment',
      colorFrequency: 'Calm river blue crossed with a steady gold line',
      mantra: '"We tune this so it won\'t break us later."',
    ),
  ),

  'hathor_19_2': KemeticDayInfo(
    gregorianDate: 'June 6, 2025',
    kemeticDate: 'Hathor II, Day 19 (Day 19 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'Rest in Harmony',
    cosmicContext: '''Day 19 is shared rest.

No performance. No fixing. No strategy talk.
Just safe proximity — "I'm allowed to relax next to you."

In Hathor's cult this is not laziness. It's proof of trust.
If you can't rest near someone,
you're not truly partnered with them.
You're negotiating with them.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'two seated figures at ease under one roof/enclosure 𓉐 — shared sanctuary',
      colorFrequency: 'Lotus blue and warm clay brown — calm, grounded companionship',
      mantra: '"I am allowed to be unguarded with you."',
    ),
  ),

  'hathor_20_2': KemeticDayInfo(
    gregorianDate: 'June 7, 2025',
    kemeticDate: 'Hathor II, Day 20 (Day 20 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'ḥry-ib sꜣḥ ("Heart of Sah")',
      starCluster: '✨ Heart of Sah — harmonized stability.',
    maatPrinciple: 'This Bond Is Part of Balance',
    cosmicContext: '''Day 20 seals this decan.

You speak gratitude to the person/people walking beside you.
Not romantic necessarily — loyal. Witness. Reliable. Present.

In Hathor's theology, companionship is sacred
because it keeps human hearts from collapsing after strain.

You tell them:
"You are not just convenient. You're part of my Ma'at."''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Name the Partnership', action: 'Say clearly who you\'re building with right now (family, crew, partner, teammate). Declare "we," not just "me."', reflection: '"Who is actually walking next to me?"'),
      DecanDayInfo(day: 12, theme: 'Sync the Rhythm', action: 'Align pace, schedules, expectations. Talk tempo: when do we move, rest, check in.', reflection: '"Are we moving in sync or stepping on each other?"'),
      DecanDayInfo(day: 13, theme: 'Share the Load Fairly', action: 'Divide tasks and emotional weight so one person isn\'t secretly carrying everything.', reflection: '"Where am I letting \'love\' or \'duty\' become exploitation?"'),
      DecanDayInfo(day: 14, theme: 'Keep Honesty in Friction', action: 'When tension shows up, address it cleanly, early, without poison.', reflection: '"Can I say what\'s not working without attacking who I love?"'),
      DecanDayInfo(day: 15, theme: 'Repair the Commons', action: 'Work together on shared infrastructure: house, money flow, workspace, calendar, kids\' routine, food system.', reflection: '"What shared system needs fixing so both of us can breathe?"'),
      DecanDayInfo(day: 16, theme: 'Pledge Mutual Protection', action: 'Make it explicit: I protect you in rooms you\'re not in. You protect me in rooms I\'m not in.', reflection: '"Do we defend each other\'s dignity when the other isn\'t there?"'),
      DecanDayInfo(day: 17, theme: 'Honor the Work Done Together', action: 'Celebrate cooperative wins, not just solo heroics.', reflection: '"Do we name and praise what we built side-by-side?"'),
      DecanDayInfo(day: 18, theme: 'Refine the System Together', action: 'Adjust the plan so it\'s sustainable for both/all going forward. Shared optimization.', reflection: '"How do we make this smoother for both of us, not just efficient for one of us?"'),
      DecanDayInfo(day: 19, theme: 'Rest in Harmony', action: 'Rest together without guilt. Shared stillness, not just shared grind.', reflection: '"Can we be peaceful in the same room without performing?"'),
      DecanDayInfo(day: 20, theme: 'Reaffirm the Bond to Ma\'at', action: 'Speak gratitude for the partnership itself. Say: this bond is part of balance, not an accident.', reflection: '"Do we both understand this isn\'t casual — this is sacred alignment work?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'shared standard 𓌡 above two linked figures — one purpose, two carriers',
      colorFrequency: 'Twin golds merging into one line of light',
      mantra: '"Our bond serves Ma\'at."',
    ),
  ),

  // ==========================================================
  // 🌞 HATHOR III — DAYS 21–30  (Third Decan - sbꜣ sꜣḥ)
  // ==========================================================

  'hathor_21_3': KemeticDayInfo(
    gregorianDate: 'June 8, 2025',
    kemeticDate: 'Hathor III, Day 21 (Day 21 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet — "House of Horus," sky-cow, joy as order)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Choose What You Will Build',
    cosmicContext: '''Day 21 is declaration. This is "I'm making this real."

In Kemet, that meant deciding: "This storage wall gets rebuilt," "This shrine gets raised," "This canal gate gets reinforced." Naming gave it legitimacy.

In your life, this is not vague ambition. It's: "The system I'm about to build is X."
Your house? Your money system? Your creative work? Your body discipline? Your app? Your altar? Say it.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'mason\'s hand with tool against a rising block — deliberate shaping',
      colorFrequency: 'Clay red and steady gold — earth lifted toward divine order',
      mantra: '"I choose what gets built."',
    ),
  ),

  'hathor_22_3': KemeticDayInfo(
    gregorianDate: 'June 9, 2025',
    kemeticDate: 'Hathor III, Day 22 (Day 22 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Prepare the Ground',
    cosmicContext: '''Day 22 is foundation.

In Kemet: clear debris, level earth, lay stone base, mark corners with cord.
In your world: pull tools, line up accounts, open the doc, claim the physical corner of the room where this work lives, set the rule.

Nothing holds if the base is sloppy.
Hathor might be pleasure, but she's not casual. She's honest craft.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'measuring cord stretched taut across ground — sacred surveying',
      colorFrequency: 'Wet earth brown, leveled and ready, under a thin line of bright gold',
      mantra: '"I make the ground worthy of what I\'m raising."',
    ),
  ),

  'hathor_23_3': KemeticDayInfo(
    gregorianDate: 'June 10, 2025',
    kemeticDate: 'Hathor III, Day 23 (Day 23 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Shape the Raw Material',
    cosmicContext: '''Day 23 is first form, not final form.

You rough it out. You block it in. You draft ugly.
Ancient masons didn't expect perfection on stroke one. They roughed the block before they polished the edge.

This day says: start shaping the thing without shaming yourself for not being "finished."
Perfectionism is anti-Ma'at because it delays balance in the real world.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'sculptor\'s hand striking chisel to stone',
      colorFrequency: 'Raw clay red, unpolished, alive',
      mantra: '"It doesn\'t have to be perfect to be sacred."',
    ),
  ),

  'hathor_24_3': KemeticDayInfo(
    gregorianDate: 'June 11, 2025',
    kemeticDate: 'Hathor III, Day 24 (Day 24 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Raise the First Form',
    cosmicContext: '''Day 24 is when something stands.

In Kemet: first wall goes up. First doorway frame. First altar post. You can point at it and say "there."
In your world: first working prototype, first visible habit, first published draft, first money bucket with rules, first physical altar corner.

Rough is fine. We are out of theory now.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'upright pillar being raised by hands — stability entering the world',
      colorFrequency: 'Stone grey kissed with gold at the top — unfinished but undeniable',
      mantra: '"It exists now."',
    ),
  ),

  'hathor_25_3': KemeticDayInfo(
    gregorianDate: 'June 12, 2025',
    kemeticDate: 'Hathor III, Day 25 (Day 25 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Give It Meaning',
    cosmicContext: '''Day 25 is soulwork.
You carve intention into the structure.

In Kemet that meant inscriptions, protective texts, dedicatory lines:
"This granary feeds the village,"
"This shrine honors Hathor for fertility."

For you, that means saying, in writing or design:
"This system exists to protect my household,"
"This project feeds my child,"
"This altar is for my healing, not my performance."

Without declared purpose, a build becomes empty status.
Hathor rejects empty.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'chisel meeting stone + offering hands — labor plus devotion',
      colorFrequency: 'Deep carved stone with gold inlay',
      mantra: '"This has a purpose, and I declare it."',
    ),
  ),

  'hathor_26_3': KemeticDayInfo(
    gregorianDate: 'June 13, 2025',
    kemeticDate: 'Hathor III, Day 26 (Day 26 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Stabilize the Build',
    cosmicContext: '''Day 26 is reinforcement.

You go through what you've raised and you lock it down.
Seal leaks. Strengthen hinges. Put passwords on things. Add boundaries. Close energy drains.

Ancient rule: if your new wall leaks, rats get the grain and the whole house starves.
So you do not skip reinforcement.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'bound knot / sealed cord around a stored vessel',
      colorFrequency: 'Deep clay red and protective black',
      mantra: '"I protect what I\'ve built."',
    ),
  ),

  'hathor_27_3': KemeticDayInfo(
    gregorianDate: 'June 14, 2025',
    kemeticDate: 'Hathor III, Day 27 (Day 27 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Beautify With Purpose',
    cosmicContext: '''Day 27 is finish work.
You soften edges, clean surfaces, set scent, hang fabric, add warmth, polish the interface, refine the copy, make it welcoming.

Not decoration for ego — invitation for the spirit.
Kemet always finished sacred builds with color, music, incense.
Beauty makes people want to enter and keep using the thing, which keeps it alive.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'perfume jar / cosmetic palette offered upward to the gods (classic Hathor offering scene)',
      colorFrequency: 'Honey gold and lotus blue in soft light',
      mantra: '"Beauty is part of the function."',
    ),
  ),

  'hathor_28_3': KemeticDayInfo(
    gregorianDate: 'June 15, 2025',
    kemeticDate: 'Hathor III, Day 28 (Day 28 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Dedicate the Work',
    cosmicContext: '''Day 28 is consecration.
You say: "This is not random. This serves balance."

For Kemet, finishing a shrine or storage wall wasn't "done, cool."
It ended in offering — beer poured, incense burned,
gratitude spoken to Hathor for restored fertility and safety.

In your practice, you bless the build. You thank collaborators.
You acknowledge Source. You mark the build as sacred, not disposable.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'arms raised in offering 𓊤 over a finished pillar — "I lift this to the divine"',
      colorFrequency: 'Gold and incense smoke white',
      mantra: '"This work belongs to Ma\'at now."',
    ),
  ),

  'hathor_29_3': KemeticDayInfo(
    gregorianDate: 'June 16, 2025',
    kemeticDate: 'Hathor III, Day 29 (Day 29 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Live With It',
    cosmicContext: '''Day 29 is integration.

The thing you built is no longer "the project." It's now part of your normal ecosystem.

In Kemet, that means grain is actually stored in the wall you built,
offerings are actively made at that shrine,
the new gate is actually being used to regulate water flow.

In your life: you actually use the system.
The altar's not for show.
The money rule is enforced.
The practice is lived.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'house/storehouse 𓉐 marked and sealed, in active use',
      colorFrequency: 'Warm clay + stored grain gold',
      mantra: '"This isn\'t theory anymore. This feeds me."',
    ),
  ),

  'hathor_30_3': KemeticDayInfo(
    gregorianDate: 'June 17, 2025',
    kemeticDate: 'Hathor III, Day 30 (Day 30 of Hathor / Tepy-a Kenmet)',
    season: '🌊 Akhet – Season of Inundation',
    month: 'Hathor (Tepy-a Kenmet)',
      decanName: 'sbꜣ sꜣḥ ("Star of Sah")',
      starCluster: '✨ Star of Sah — order expressed in beauty.',
    maatPrinciple: 'Record the Legacy',
    cosmicContext: '''Day 30 is witness.
You document. You acknowledge. You archive.

In Kemet, this is when records were made: who labored, what was raised, what it was for.
Receipts were literally sacred, because memory protects truth.

In your world: capture photos, notes, agreements, receipts, "before/after," first live version, first revenue, first ritual moment.

This is not flex.
This is evidence that order was restored in your lifetime.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Name What Will Be Built', action: 'Declare one thing you\'re going to actually make, fix, or establish in the physical world.', reflection: '"What structure am I about to leave behind me?"'),
      DecanDayInfo(day: 22, theme: 'Lay the Ground / Foundation', action: 'Begin groundwork. Clear site, gather tools, source materials, set base rules or outline.', reflection: '"Did I prepare the ground so it can hold what I\'m about to raise?"'),
      DecanDayInfo(day: 23, theme: 'Shape the Raw Material', action: 'Mold clay, sketch the plan, draft the framework, cut the wood, write the first bones.', reflection: '"Can I start forming this without judging it yet?"'),
      DecanDayInfo(day: 24, theme: 'Raise the First Form', action: 'Put up the first visible piece. First wall, first interface, first habit in public reality.', reflection: '"Is it standing in the real world yet, even in rough form?"'),
      DecanDayInfo(day: 25, theme: 'Carve the Meaning In', action: 'Add intentional symbolism: blessing, inscription, stated purpose. Make sure it\'s not empty structure.', reflection: '"Does this thing reflect my values, or is it just \'productive\'?"'),
      DecanDayInfo(day: 26, theme: 'Stabilize the Build', action: 'Reinforce joints, seal leaks, tighten money flow, lock permissions, secure boundaries.', reflection: '"Where could this fall apart if I don\'t shore it up now?"'),
      DecanDayInfo(day: 27, theme: 'Beautify With Purpose', action: 'Refine surface: finish, aesthetic, scent, color, polish, the welcoming layer. Not vanity — invitation.', reflection: '"Is it pleasing to enter, to hold, to use?"'),
      DecanDayInfo(day: 28, theme: 'Consecrate / Dedicate', action: 'Offer it up. Mark the build as sacred. Thank whoever helped. Thank the Source that allowed it.', reflection: '"Who/what am I acknowledging as co-creator here?"'),
      DecanDayInfo(day: 29, theme: 'Integration Into Daily Life', action: 'Fold it into your normal rhythm. Use it. Let it serve.', reflection: '"Is this now part of how I live — or is it just a nice idea sitting in a corner?"'),
      DecanDayInfo(day: 30, theme: 'Witness and Record', action: 'Document what was created: photos, notes, receipts, agreements, first usage. Claim it as real legacy, not a moment.', reflection: '"If I disappeared tomorrow, could someone see this and know who I was and what I served?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'scribe\'s palette and papyrus roll beside the finished pillar — the act of recording the build as sacred memory',
      colorFrequency: 'Ink black on gold',
      mantra: '"My work is real and witnessed."',
    ),
  ),

  // ==========================================================
  // 🌿 KA-ḤER-KA I — DAYS 1–10  (First Decan - ḫnwy)
  // ==========================================================

  'kaherka_1_1': KemeticDayInfo(
    gregorianDate: 'June 18, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 1 (Day 1 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka ("Ka upon Ka," doubling of life-force; resurrection through planting)',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Enter Stillness',
    cosmicContext: '''Day 1 is the pause after loss. The Nile has pulled back and the black earth (kemet) lies soft and exposed. The people lower their voices. The temples dim their music.

This is the moment when Asar (Osiris) is laid in the Duat, and Aset (Isis) and Nebet-Het (Nephthys) hold him.
Nothing is rushed. Nothing is "fixed."

Maʿat in this phase is not movement — it's honoring what has passed without pretending you're fine.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Two outstretched arms embracing/protecting — containment and care',
      colorFrequency: 'Black Nile silt with a thin silver line of dawn starlight',
      mantra: '"I am held so I may heal."',
    ),
  ),

  'kaherka_2_1': KemeticDayInfo(
    gregorianDate: 'June 19, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 2 (Day 2 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka ("Ka upon Ka")',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Cleanse the Altar',
    cosmicContext: '''Day 2 is purification.

Old offerings, old ash, old tokens of last season's grind — they get cleared.
In Kemet this was physical: wiping down family shrines, refreshing oil lamps, sweeping floors still damp from flood air.

Spiritually: you are saying "the space that receives new life must be worthy of that life."
Aset (Isis) and Nebet-Het (Nephthys) do not sit in filth while guarding Asar (Osiris).
You shouldn't either.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Libation pouring + wiping cloth — ritual cleansing',
      colorFrequency: 'Cool water blue over black silt',
      mantra: '"I refresh the place where renewal will happen."',
    ),
  ),

  'kaherka_3_1': KemeticDayInfo(
    gregorianDate: 'June 20, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 3 (Day 3 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Name the Loss',
    cosmicContext: '''Day 3 is honesty.

The people of Kemet did not pretend that Asar (Osiris) "was fine."
They named his death. They cried for him. They said his name.
They understood that pretending nothing happened breaks Maʿat, because Maʿat is truth.

Today is not about dramatizing pain — it's about refusing to lie about impact.
"This ended." Say it.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Mouth-sign + teardrop — voiced grief',
      colorFrequency: 'Deep indigo, lamplight gold at the edge',
      mantra: '"I speak what ended so that truth can breathe."',
    ),
  ),

  'kaherka_4_1': KemeticDayInfo(
    gregorianDate: 'June 21, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 4 (Day 4 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Hold Memory',
    cosmicContext: '''Day 4 is honoring without clinging.

In Kemet, families would keep tokens — a lock of hair, a necklace, a tool — and place it with quiet gratitude.
The point wasn't "never let go."
The point was "what was good in this will keep feeding us."

Today, you choose what you will carry forward,
not what will drag you backward.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Offering hands holding a small relic',
      colorFrequency: 'Soft brown (wood/relic) and warm amber',
      mantra: '"What fed me is allowed to stay."',
    ),
  ),

  'kaherka_5_1': KemeticDayInfo(
    gregorianDate: 'June 22, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 5 (Day 5 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Ground the Body',
    cosmicContext: '''Day 5 is embodiment.

After shock and mourning, you re-enter your own physical life.
In Kemet: bare feet in wet soil, stretching the spine at dawn, eating something simple from the land.

This is medicine. This is also spiritual:
Asar (Osiris) is not just an idea — he is grain, body, fertility.
Touching earth is touching him.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Foot on earth / grounded stance',
      colorFrequency: 'Damp black-brown soil and living green',
      mantra: '"I come back into my body."',
    ),
  ),

  'kaherka_6_1': KemeticDayInfo(
    gregorianDate: 'June 23, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 6 (Day 6 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Watch the Sky',
    cosmicContext: '''Day 6 is cosmic alignment.

In Kemet, astronomer-priests tracked the faint paired stars of ḫnwy to mark the passing hours of night.
That wasn't superstition — that was discipline.

This day trains you to look up. To learn your sky.
To remember that balance is patterned, not random.
You're not drifting alone. You're inside timing.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Star above an eye — conscious observing of the heavens',
      colorFrequency: 'Pre-dawn blue and silver-white',
      mantra: '"Order is written in the sky, and I am under that order."',
    ),
  ),

  'kaherka_7_1': KemeticDayInfo(
    gregorianDate: 'June 24, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 7 (Day 7 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Soft Speech Only',
    cosmicContext: '''Day 7 is control of the mouth.

In Kemet, mourners of Asar (Osiris) did not scream rage into the night to tear the air.
They keened, but with purpose — controlled, rhythmic, directed.

To tear at random isfet is to invite chaos.
Today, your voice is a tool of healing.
No reckless stabbing at people you love. No casual poison.

You speak as if the room is sacred, because it is.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Mouth with gently raised hand — restrained speech',
      colorFrequency: 'Muted gold and deep indigo (lamp light in a quiet house)',
      mantra: '"My voice keeps balance."',
    ),
  ),

  'kaherka_8_1': KemeticDayInfo(
    gregorianDate: 'June 25, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 8 (Day 8 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Tend the Seed',
    cosmicContext: '''Day 8 is preparation to plant.

In Kemet this is literal: pressing first grain into the black silt left by the flood.
Planting is not seen as "goodbye," it's seen as "see you in new form."

The burial of the seed repeats the burial of Asar (Osiris).
You are not throwing something away — you are committing it to transformation.

Today you choose what goes into the ground.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Seed/grain beneath a cupped hand',
      colorFrequency: 'Wet black soil and living green emerging at the edges',
      mantra: '"What I plant is not gone. It\'s changing shape."',
    ),
  ),

  'kaherka_9_1': KemeticDayInfo(
    gregorianDate: 'June 26, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 9 (Day 9 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Trust the Hidden Work',
    cosmicContext: '''Day 9 is faith in the unseen.

The seed is underground. You cannot see roots forming. You cannot see stem pushing. But life is moving.

Priests said of Asar (Osiris), "He sails the hidden waters."
Translation: just because you can't watch it doesn't mean it's stalled.

Today is about not ripping open the soil to "check progress."
You trust that resurrection can happen in the dark.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Enclosed boat beneath horizon line — journey in the unseen',
      colorFrequency: 'Deep underwater blue-green, nearly black',
      mantra: '"Life is moving where I cannot see."',
    ),
  ),

  'kaherka_10_1': KemeticDayInfo(
    gregorianDate: 'June 27, 2025',
    kemeticDate: 'Ka-ḥer-ka I, Day 10 (Day 10 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'msḥtjw ("The Foreleg")',
      starCluster: '✨ The Foreleg — renewed strength.',
    maatPrinciple: 'Seal the Chamber',
    cosmicContext: '''Day 10 is closure of the first movement.

In Kemet, lamps were extinguished. Doors were shut. Sleep was taken early.
This act was not abandonment of Asar (Osiris) — it was trust.

You stop hovering over the wound.
You allow the burial to become gestation.
You let tomorrow arrive clean.

By sealing, you create the condition for resurrection.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Enter Stillness', action: 'Pause unnecessary motion; let noise drain away.', reflection: '"What within me needs silence before it can rise?"'),
      DecanDayInfo(day: 2, theme: 'Cleanse the Altar', action: 'Wash and clear old offerings, tools, clutter, stale energy.', reflection: '"What remnants of past harvests block renewal?"'),
      DecanDayInfo(day: 3, theme: 'Name the Loss', action: 'Acknowledge what ended — say it without spin or denial.', reflection: '"Can I bless what left without bitterness?"'),
      DecanDayInfo(day: 4, theme: 'Hold Memory', action: 'Set out one token (photo, item, name) in respect, not obsession.', reflection: '"What good did this bring that still feeds me?"'),
      DecanDayInfo(day: 5, theme: 'Ground the Body', action: 'Touch the earth, breathe deep, eat something simple and real.', reflection: '"Am I anchored in the living world?"'),
      DecanDayInfo(day: 6, theme: 'Watch the Sky', action: 'Look to the west before dawn; note the faint twin lights.', reflection: '"What pattern returns even in darkness?"'),
      DecanDayInfo(day: 7, theme: 'Soft Speech Only', action: 'Speak kindly or not at all today. Tone is ritual.', reflection: '"Does my voice restore order or fracture it?"'),
      DecanDayInfo(day: 8, theme: 'Tend the Seed', action: 'Prepare soil (literal or symbolic). Ready something to plant.', reflection: '"What is ready to be buried, not abandoned?"'),
      DecanDayInfo(day: 9, theme: 'Trust the Hidden Work', action: 'Accept that growth can begin in darkness, out of sight.', reflection: '"Can I believe life is rebuilding even if I can\'t prove it yet?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Chamber', action: 'Close the vigil. Dim lights early. Let it rest.', reflection: '"Have I allowed the old self to lay down so a new self can rise?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Closed door / sealed shrine',
      colorFrequency: 'Darkened room brown with a rim of dawn gold at the threshold',
      mantra: '"I let it rest so it can rise."',
    ),
  ),

  // ==========================================================
  // 🌿 KA-ḤER-KA II — DAYS 11–20  (Second Decan - ḥry-ib wꜣ)
  // ==========================================================

  'kaherka_11_2': KemeticDayInfo(
    gregorianDate: 'June 28, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 11 (Day 11 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka ("Ka upon Ka," doubled life-force, resurrection through burial and growth)',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Stand Back Up',
    cosmicContext: '''Day 11 is first movement.

The mourning chamber is sealed — now the god sails.
Asar (Osiris) is no longer lying still under guard. He is in motion, escorted through the Duat in the night boat.

In the fields, this is the moment where buried seed begins to swell and push.
In your body, this is: I rise. I am not "finished healing," but I am vertical again.

You're allowed to stand before you're "over it."''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Solar bark carrying a seated god through dark water',
      colorFrequency: 'Deep river blue with gold firelight on the surface',
      mantra: '"I rise and I travel."',
    ),
  ),

  'kaherka_12_2': KemeticDayInfo(
    gregorianDate: 'June 29, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 12 (Day 12 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Reclaim Your Name',
    cosmicContext: '''Day 12 is identity.

After the flood, after the burial, after the stillness, you state who you are now.
In Kemet, names carry power. Aset (Isis) guarded the true name of Asar (Osiris) because identity is throne-right.

Today you say "I am ___, I serve ___, I answer to ___."
You are not the version that died.
You are the one steering the bark now.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Name standard / banner on a pole carried in procession',
      colorFrequency: 'White linen and deep green (living authority)',
      mantra: '"My name still holds power."',
    ),
  ),

  'kaherka_13_2': KemeticDayInfo(
    gregorianDate: 'June 30, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 13 (Day 13 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Feed What\'s Returning',
    cosmicContext: '''Day 13 is resourcing the revival.

The Kemetic mind understood this: if you want something to come back to life, you must feed it.
That includes your body, your craft, your household system, the thing you're rebuilding.

If you starve it, it dies again.
Tonight, you nourish the "boat."
You are helping Asar (Osiris) travel.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Offering table piled with bread and beer',
      colorFrequency: 'Barley gold and lamp-flame orange',
      mantra: '"I feed what is coming back to life."',
    ),
  ),

  'kaherka_14_2': KemeticDayInfo(
    gregorianDate: 'July 1, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 14 (Day 14 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Accept Sacred Obligation',
    cosmicContext: '''Day 14 is responsibility.

In Kemet, once Asar (Osiris) is in motion, he is not unattended.
Aset (Isis), Nebet-Het (Nephthys), and protective Netjeru take shifts guarding him. Everybody takes a role.

Today is you saying: "This part is mine. I'm on watch."
No more "I don't know, life is wild."
No. You pick up what is yours to guard.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Crook and flail crossed on the chest — guardianship',
      colorFrequency: 'Deep green of living Asar (Osiris) and protective linen white',
      mantra: '"This is mine to guard."',
    ),
  ),

  'kaherka_15_2': KemeticDayInfo(
    gregorianDate: 'July 2, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 15 (Day 15 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Speak Protection Over It',
    cosmicContext: '''Day 15 is verbal defense.

Aset (Isis) protects Asar (Osiris) with word as weapon, vow as shield.
Today you actively defend what's coming back to life in you.

"No, you will not disrespect this boundary."
"No, this healing is not up for debate."
"No, this build is not your punchline."

You lock the perimeter with language.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Open mouth with protective cobra/uraeus',
      colorFrequency: 'White-hot gold against night blue',
      mantra: '"My words are a shield."',
    ),
  ),

  'kaherka_16_2': KemeticDayInfo(
    gregorianDate: 'July 3, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 16 (Day 16 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Organize the Living',
    cosmicContext: '''Day 16 is systems.

This is you cleaning the altar table, fixing your sleep, tightening money leaks, cooking actual food, putting rhythm back in your day.

Resurrection is not vibes — it's order.
Asar (Osiris) cannot return to sit on the throne of the Duat if the boat itself is sloppy and off-course.

You fix the boat.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Coiled rope tied into neat order / bound bundle',
      colorFrequency: 'Soft linen white and orderly reed green',
      mantra: '"My order is an act of survival."',
    ),
  ),

  'kaherka_17_2': KemeticDayInfo(
    gregorianDate: 'July 4, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 17 (Day 17 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Ask for Help Without Shame',
    cosmicContext: '''Day 17 is shared carrying.

In the Kemetic story, Nebet-Het (Nephthys) does not leave Aset (Isis) alone in this work.
She shows up. She assists. She literally holds the body with her.

Today is where you admit where you're past capacity and ask for backup without guilt.
Isolation is isfet. Mutual aid is Maʿat.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Two figures lifting together',
      colorFrequency: 'Paired flame light on dark water',
      mantra: '"Shared load is holy."',
    ),
  ),

  'kaherka_18_2': KemeticDayInfo(
    gregorianDate: 'July 5, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 18 (Day 18 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Re-Enter Community',
    cosmicContext: '''Day 18 is reconnection.

You step back into your circle — family, crew, temple body, flow community.
This is not performative socializing. This is "I'm alive, and I'm with my people again."

After grief withdrawal, you return to the living network.
In Kemet, if you stayed gone too long, the thread between you and the village thinned.
Today you braid it back.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Linked arms / joined hands',
      colorFrequency: 'Community firelight reflected on water black',
      mantra: '"I belong and I return."',
    ),
  ),

  'kaherka_19_2': KemeticDayInfo(
    gregorianDate: 'July 6, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 19 (Day 19 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Let Growth Be Visible',
    cosmicContext: '''Day 19 is witness.

In Kemet, when the lamps floated, everyone could see the flame crossing water.
The point was visibility: "The god still moves. The journey continues."

Today, you let someone see that you are improving.
You show a small success, a healed behavior, a stabilized habit, a rebuild milestone.

Visibility affirms that the work is real — and makes it harder to abandon.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Flame held aloft in a boat',
      colorFrequency: 'Gold light on black-green water',
      mantra: '"My recovery is real enough to be seen."',
    ),
  ),

  'kaherka_20_2': KemeticDayInfo(
    gregorianDate: 'July 7, 2025',
    kemeticDate: 'Ka-ḥer-ka II, Day 20 (Day 20 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
      starCluster: '✨ Heart of the Foreleg — strength governed.',
    maatPrinciple: 'Give Thanks for Endurance',
    cosmicContext: '''Day 20 is gratitude to endurance itself.

Not to perfection, not to performance — to endurance.
This is the prayer of "I'm still here."

In Kemet, safe passage through the Duat was everything.
If Asar (Osiris) remained whole in the bark, the world stayed in balance.

You honor that same force in you.
You say thank you to the part of you that refused to disappear.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Stand Back Up', action: 'Re-enter movement. Choose one responsibility you resume today.', reflection: '"Where can I rise without pretending I don\'t still hurt?"'),
      DecanDayInfo(day: 12, theme: 'Reclaim Your Name', action: 'Say your name, your role, your purpose out loud.', reflection: '"Who am I — even after what happened?"'),
      DecanDayInfo(day: 13, theme: 'Feed What\'s Returning', action: 'Give energy (time, food, money, protection, attention) to something that\'s trying to live again in your world.', reflection: '"Am I nurturing revival, or starving it?"'),
      DecanDayInfo(day: 14, theme: 'Accept Sacred Obligation', action: 'Acknowledge you are again responsible for someone / something (child, craft, house, land, self).', reflection: '"What is now mine to guard?"'),
      DecanDayInfo(day: 15, theme: 'Speak Protection Over It', action: 'Guard your rising the way Aset (Isis) guarded Asar (Osiris): "No harm will take you while I breathe."', reflection: '"Do I defend what I love in word and act?"'),
      DecanDayInfo(day: 16, theme: 'Organize the Living', action: 'Re-establish order in basics — time, food, money, sleep, cleanliness.', reflection: '"Does my daily rhythm honor life, or exhaust it?"'),
      DecanDayInfo(day: 17, theme: 'Ask for Help Without Shame', action: 'Call in assistance (like Nebet-Het (Nephthys) supporting Aset (Isis)). No isolation pride.', reflection: '"Where am I pretending I can do this alone and silently drowning?"'),
      DecanDayInfo(day: 18, theme: 'Re-Enter Community', action: 'Reconnect with one circle (household, crew, temple, flow community).', reflection: '"Where do I belong that I\'ve been avoiding?"'),
      DecanDayInfo(day: 19, theme: 'Let Growth Be Visible', action: 'Show one sign of recovery in public space. Let someone witness that you are coming back.', reflection: '"Am I allowing others to witness my return to life?"'),
      DecanDayInfo(day: 20, theme: 'Give Thanks for Endurance', action: 'Offer gratitude not for perfection, but for survival.', reflection: '"Do I honor the part of me that stayed?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Heart upheld in two hands',
      colorFrequency: 'Deep green of living Asar (Osiris) lit with steady lantern gold',
      mantra: '"I thank the part of me that would not sink."',
    ),
  ),

  // ==========================================================
  // 🌿 KA-ḤER-KA III — DAYS 21–30  (Third Decan - remetch en pet)
  // ==========================================================

  'kaherka_21_3': KemeticDayInfo(
    gregorianDate: 'July 8, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 21 (Day 21 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka ("Ka upon Ka," resurrection through renewal)',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Work as Worship',
    cosmicContext: '''Day 21 is when grief becomes duty.

Ka-ḥer-ka I held the mourning of Asar (Osiris).
Ka-ḥer-ka II carried his body through the Duat in the sacred bark guided by Aset (Isis).
Now, in Ka-ḥer-ka III, the living step in.

The Kemite didn't wait for gods to fix the world — the Kemite understood: we are the crew of heaven.

So the work — cleaning, repairing, hauling, sorting, logging grain, restoring order at home — is worship.
Your labor today is not "chores." It's priest-work. Treat it like that.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Oar beneath the solar disk — the mortal hand rowing divine light forward',
      colorFrequency: 'Dawn gold over river blue',
      mantra: '"My work keeps the world alive."',
    ),
  ),

  'kaherka_22_3': KemeticDayInfo(
    gregorianDate: 'July 9, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 22 (Day 22 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Reopen the Flow',
    cosmicContext: '''Day 22 is the canal day.

When the Nile receded, it left silt choking channels. If those channels weren't reopened, whole plots stayed dead.
In Kemet, people waded in and pulled mud by hand. That was survival. That was Ma'at.

Today your "canal" is anywhere life is backed up: unspoken resentment, unpaid invoice, blocked creative output, sugar-junk buildup in the body, clutter in the room where you're supposed to think clearly.

You don't complain about the blockage.
You clear it.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Wavy water line opening beneath a gate',
      colorFrequency: 'Deep teal and silt-bronze',
      mantra: '"I clear the channels so life can move."',
    ),
  ),

  'kaherka_23_3': KemeticDayInfo(
    gregorianDate: 'July 10, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 23 (Day 23 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Raise the Pillar',
    cosmicContext: '''Day 23 is spine.

In Koiak rites (this same season), the Djed of Asar (Osiris) was physically lifted back upright. This wasn't abstract theater — it was a vow: the world will not remain collapsed.

Your "Djed" is anything foundational that fell over in your life while you were in the dark: boundaries, money discipline, prayer rhythm, health routine, your authority in your own house.

Today is the day you stand it back up with both hands and say, "This is stable again."''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Djed pillar gripped by two hands',
      colorFrequency: 'Sandstone gold with rooted green at the base',
      mantra: '"I restore my spine."',
    ),
  ),

  'kaherka_24_3': KemeticDayInfo(
    gregorianDate: 'July 11, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 24 (Day 24 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Restore the Home',
    cosmicContext: '''Day 24 is domestic priesthood.

Kemetic homes were not "less sacred" than temples. Your floor was still Ma'at's floor. Your doorway was still a threshold between chaos and order.

So today is sweep, scrub, repair, reset. Patch what's torn. Throw out what carries rot. Rearrange the space so it supports who you are now — not who you were when you were in crisis.

A neglected home body is open invitation to isfet.
A restored home body is a shrine.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'House with a steady flame inside',
      colorFrequency: 'Clay red and hearth gold',
      mantra: '"My home is an altar."',
    ),
  ),

  'kaherka_25_3': KemeticDayInfo(
    gregorianDate: 'July 12, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 25 (Day 25 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Feed the Fire',
    cosmicContext: '''Day 25 is ignition.

Fire is transformation — raw to cooked, damp to warm, potential to active.

This is where you relight what went cold in you: your creative engine, your courage, your physical heat, your intimacy, your ambition.

No flame = no life.
Your job today is to tend a specific flame and say, "This will not go out on my watch."''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Torch held up in both hands',
      colorFrequency: 'Ember red and sun gold',
      mantra: '"I keep the light alive."',
    ),
  ),

  'kaherka_26_3': KemeticDayInfo(
    gregorianDate: 'July 13, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 26 (Day 26 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Anchor Community',
    cosmicContext: '''Day 26 is alignment with your crew.

The Kemite knew survival was collective. Canal clearing, Djed raising, grain guarding — these were done in teams with rhythm and chant.

Today is identify, affirm, and strengthen your living circle. Who rows with you? Who is actually in the boat? Who do you feed and who feeds you back?

Ma'at is not isolation.
Ma'at is interdependence held in honesty.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Two parallel oars moving in sync',
      colorFrequency: 'River blue and shared sunlight gold',
      mantra: '"We move together."',
    ),
  ),

  'kaherka_27_3': KemeticDayInfo(
    gregorianDate: 'July 14, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 27 (Day 27 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Celebrate Endurance',
    cosmicContext: '''Day 27 is praise for the fact that you're still here.

Not fake hype. Not ego. Just "I went into darkness, and I did not dissolve."

In Kemet, celebration after flood season wasn't decadence — it was maintenance. Spirits that never get to exhale break.

Today is exhale. Eat sweetness. Laugh loud. Stretch your nerves back open. Let your crew feel relief with you.
This joy is structural. It keeps you from collapsing later.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Arms raised in song',
      colorFrequency: 'Sunrise coral and river green',
      mantra: '"My survival is holy."',
    ),
  ),

  'kaherka_28_3': KemeticDayInfo(
    gregorianDate: 'July 15, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 28 (Day 28 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Offer Gratitude in Motion',
    cosmicContext: '''Day 28 is moving gratitude.

This is not "sit, journal affirmations." This is "say thank you while your hands are in the work."

Tell the Source thank you while you scrub, while you email, while you code, while you cook, while you repair that relationship.

Kemet did not split labor and devotion. Neither should you.
Your motion itself is an altar.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Arms rowing beneath the sun disk',
      colorFrequency: 'Bright river gold',
      mantra: '"My action is devotion."',
    ),
  ),

  'kaherka_29_3': KemeticDayInfo(
    gregorianDate: 'July 16, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 29 (Day 29 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Synchronize with the Sun',
    cosmicContext: '''Day 29 is rhythm check.

Ancient life was solar. Up with first light = work. Dark = rest. Bodies, finances, agriculture, protection — all tuned around the sun's cycle.

Modern chaos tries to pull you off that current and call that "freedom," but drifting out of rhythm is how you get sick, broke, resentful, unstable.

Today is fix your clock. Wake with intention. Act in clean daylight. Shut down in honest darkness.
Reclaim circadian Ma'at.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Sun disk over measured strokes',
      colorFrequency: 'White-gold over deep azure',
      mantra: '"I move with light, not against it."',
    ),
  ),

  'kaherka_30_3': KemeticDayInfo(
    gregorianDate: 'July 17, 2025',
    kemeticDate: 'Ka-ḥer-ka III, Day 30 (Day 30 of Ka-ḥer-ka / Ka-ḥer-ka)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Ka-ḥer-ka',
      decanName: 'sbꜣ msḥtjw ("Star of the Foreleg")',
      starCluster: '✨ Star of the Foreleg — applied, balanced force.',
    maatPrinciple: 'Seal the Cycle',
    cosmicContext: '''Day 30 is witness.

Kemet documented. They recorded grain counts, canal status, who labored, what was restored in the name of Ma'at. That record wasn't bureaucracy — it was sacred proof that balance had been re-established.

Today you archive.
Photos. Receipts. Agreements. Before/after. First usage. First payment. Names of who helped.

If you disappeared tomorrow, would someone know what you restored? Would they know you served order?
That's the point of today.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Work as Worship', action: 'Approach daily labor as offering. Align intention with function.', reflection: '"Am I rowing in rhythm with heaven?"'),
      DecanDayInfo(day: 22, theme: 'Reopen the Flow', action: 'Clear blockages — physical, emotional, financial, spiritual.', reflection: '"Where has the canal of my life silted shut?"'),
      DecanDayInfo(day: 23, theme: 'Raise the Pillar', action: 'Restore foundation. In Kemet this meant lifting the Djed — stability itself.', reflection: '"What will I stand upright again in my world?"'),
      DecanDayInfo(day: 24, theme: 'Restore the Home', action: 'Sweep, mend, rebuild, reset — your dwelling is your temple.', reflection: '"Does my space reflect balance or neglect?"'),
      DecanDayInfo(day: 25, theme: 'Feed the Fire', action: 'Relight hearths, resume warmth and creation.', reflection: '"What flame must I tend to keep light in my life?"'),
      DecanDayInfo(day: 26, theme: 'Anchor Community', action: 'Coordinate with others — shared meals, shared purpose.', reflection: '"Who rows beside me in this phase of renewal?"'),
      DecanDayInfo(day: 27, theme: 'Celebrate Endurance', action: 'Mark that you made it through the dark. Joy is not extra — it\'s fuel.', reflection: '"Do I allow myself to honor survival as sacred?"'),
      DecanDayInfo(day: 28, theme: 'Offer Gratitude in Motion', action: 'Work and thank simultaneously. Labor itself is prayer.', reflection: '"Am I remembering Source while I act?"'),
      DecanDayInfo(day: 29, theme: 'Synchronize with the Sun', action: 'Align your rhythm with daylight. Rise, act, and rest in honest timing.', reflection: '"Is my pattern aligned with life, or am I fighting the current?"'),
      DecanDayInfo(day: 30, theme: 'Seal the Cycle', action: 'Close this phase with order, record, blessing. Claim what was restored.', reflection: '"What am I formally carrying into the next month of my life?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette + papyrus beside an upright Djed',
      colorFrequency: 'Ink black on dawn gold',
      mantra: '"My restoration is real and recorded."',
    ),
  ),

  // ==========================================================
  // 🌿 ŠEF-BEDET I — DAYS 1–10  (First Decan - knmw)
  // ==========================================================

  'sefbedet_1_1': KemeticDayInfo(
    gregorianDate: 'July 18, 2025',
    kemeticDate: 'Šef-Bedet I, Day 1 (Day 1 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet (šf-bdt) — "The Nourisher," "She Who Feeds with Grain." šf = to feed, to provide. bdt = offering, bread, sustenance. This month is not conquest — it is compassionate maintenance.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Form the Vessel',
    cosmicContext: '''Day 1 is not "start hustling." Day 1 is "prepare the vessel."

Khnum does not throw raw mud at fate — he kneads, shapes, and smooths a container that can actually hold life. The Kemite mirrored that. Floors were swept. Storage jars were rinsed. Sleeping mats were dried in sun. Quiet routines were reestablished after the violence of flood and grief.

This is how balance begins: not with drama, but with readiness.

Today you clear a space, physically and in rhythm. You decide: this is where nourishment will live.
You choose one part of your life that will receive care this cycle — body, home, craft, lineage — and you build it a seat.

In Kemet, an unprepared jar wasted grain.
In you, an unprepared life wastes blessing.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Potter\'s wheel beneath a ram\'s head — Khnum forming a body from wet clay',
      colorFrequency: 'Damp earth brown with first-light gold at the rim',
      mantra: '"I prepare a place for life."',
    ),
  ),

  'sefbedet_2_1': KemeticDayInfo(
    gregorianDate: 'July 19, 2025',
    kemeticDate: 'Šef-Bedet I, Day 2 (Day 2 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — "The Nourisher," the ethical demand to feed life, not just witness it.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Moisten the Clay',
    cosmicContext: '''Day 2 is hydration.

In Kemet this was literal: the first careful watering so young roots wouldn't die. But it was also body-law. After grief, after fear, after hunger, a person dries out inside — lips, joints, sleep, patience.

Today you reintroduce moisture. Drink. Oil skin. Stretch slowly. Schedule breath between demands so you stop moving like a hunted animal.

This is not indulgence. This is structural repair. Cracked clay shatters on the wheel. Khnum can't shape what's already split.

Your task is to soften, not collapse — to become workable again.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Water jar tilted over sprouting grain',
      colorFrequency: 'River blue against young green',
      mantra: '"I soften what was hardened by fear."',
    ),
  ),

  'sefbedet_3_1': KemeticDayInfo(
    gregorianDate: 'July 20, 2025',
    kemeticDate: 'Šef-Bedet I, Day 3 (Day 3 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Feeding as law, provision as devotion.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Plant Intention',
    cosmicContext: '''Day 3 is root.

Today is not "set 12 goals." Kemet didn't scatter seed everywhere on the first pass — that wastes labor and insults the land.

Today you choose one living intention for this 10-day cycle. One. You name it aloud. You write it. You plant it.

That intention can be physical (repair sleep), relational (restore trust with one person), economic (stabilize one bill), or sacred (reclaim morning prayer).

Ma'at hates chaos. Chaos is "I want everything." Order is "I will grow this."

Your job is to commit to something that deserves to live in you, and press it gently into the soil.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Seed pressed into open palm',
      colorFrequency: 'Wet black soil with a single green point',
      mantra: '"I plant what I will protect."',
    ),
  ),

  'sefbedet_4_1': KemeticDayInfo(
    gregorianDate: 'July 21, 2025',
    kemeticDate: 'Šef-Bedet I, Day 4 (Day 4 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The month where feeding is civilization\'s first duty.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Feed What You Planted',
    cosmicContext: '''Day 4 is proof.

Anyone can say "I'm going to change." Kemet didn't respect speech without grain.

Today you materially feed the thing you planted yesterday. If you swore to heal your body, you feed your body — real nutrients, real rest. If you swore to repair trust, you feed that relationship — time, apology, presence. If you swore to stabilize money, you feed that ledger — sit down and look at it in daylight.

Ma'at is not fantasy. Ma'at is resourced.

Ask yourself: "Did I give life calories, or did I just declare a dream?"''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Open hand offering bread and a small jar',
      colorFrequency: 'Warm grain-gold and baked-clay red',
      mantra: '"I give real fuel to what I said matters."',
    ),
  ),

  'sefbedet_5_1': KemeticDayInfo(
    gregorianDate: 'July 22, 2025',
    kemeticDate: 'Šef-Bedet I, Day 5 (Day 5 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The ethics of care, made visible.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Protect the Fragile',
    cosmicContext: '''Day 5 is boundary.

In Kemet, you did not shame a seed for needing protection. You ringed it. You watched. You warned children not to stomp. You moved goats.

So today you name what is still too tender to survive attack, and you place gentle guard around it. Limit noise. Limit exposure. Limit access.

This is not hiding. This is stewardship.

A sprout is not a forest, but a forest dies if you mock the sprout for needing guarding.

You have permission to protect new life in you without apology.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Reed fence around a young shoot',
      colorFrequency: 'Pale green wrapped in protective straw-gold',
      mantra: '"I guard the tender so it can become strong."',
    ),
  ),

  'sefbedet_6_1': KemeticDayInfo(
    gregorianDate: 'July 23, 2025',
    kemeticDate: 'Šef-Bedet I, Day 6 (Day 6 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Compassion as infrastructure.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Breathe Into the Work',
    cosmicContext: '''Day 6 is nervous system alignment.

After crisis, the body keeps behaving like danger is still here. Shoulders lock. Jaw grinds. Sleep stays shallow. You move like you're outrunning a wave that already passed.

Kemet understood: frantic hands spill grain.

Today you slow. You inhale fully. You exhale longer than you inhale. You match task to breath instead of desperation. You let your body register, "We are in Emergence now, not drowning."

This is not laziness. This is you re-teaching your body Ma'at.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Curved ram horn above flowing breath lines',
      colorFrequency: 'Soft river teal fading into calm sand',
      mantra: '"I move in calm strength, not panic."',
    ),
  ),

  'sefbedet_7_1': KemeticDayInfo(
    gregorianDate: 'July 24, 2025',
    kemeticDate: 'Šef-Bedet I, Day 7 (Day 7 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — "She Who Feeds with Grain," which includes honoring whoever grows, cooks, carries, and serves.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Honor the Providers',
    cosmicContext: '''Day 7 is gratitude with names.

In Kemet, they thanked Renenutet (goddess of the stored grain) and they thanked the woman who baked the bread. Both were sacred.

Today you speak the names — of the people, forces, and systems that keep you nourished. The person who watches your child. The check that cleared. The body that still carries you. The elder who taught you how to survive.

You do not pretend you did this alone. Isolation is a lie from isfet.

Recognition is not weakness.
Recognition is alignment with reality.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hands presenting a full bowl',
      colorFrequency: 'Harvest gold cupped by human brown',
      mantra: '"I name and honor the ones who keep me alive."',
    ),
  ),

  'sefbedet_8_1': KemeticDayInfo(
    gregorianDate: 'July 25, 2025',
    kemeticDate: 'Šef-Bedet I, Day 8 (Day 8 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Provision equals justice.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Distribute Fairly',
    cosmicContext: '''Day 8 is balance of giving.

Kemet fed the vulnerable — not as pity, but as law. At the same time, Kemet did not demand self-erasure from the provider. Both extremes break Ma'at.

So today you examine how you share. Money, time, attention, food, presence. Are you hoarding out of fear? Are you bleeding out to prove worth?

To live Ma'at is to circulate resources so life continues — without starving yourself to decorate someone else's comfort.

Your sharing must sustain the circle, including you.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Balanced scale with grain on both pans',
      colorFrequency: 'Matte clay brown and measured sun-yellow',
      mantra: '"I circulate what sustains life — and I include myself in that life."',
    ),
  ),

  'sefbedet_9_1': KemeticDayInfo(
    gregorianDate: 'July 26, 2025',
    kemeticDate: 'Šef-Bedet I, Day 9 (Day 9 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Month of provision, of counting what exists so no one starves in illusion.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Record the Yield',
    cosmicContext: '''Day 9 is ledger.

Kemet wrote everything: water level, grain in storage, labor owed, mouths to be fed. This wasn't greed. This was survival through clarity.

Today you count. Not fantasize — count. What have you actually stabilized so far this cycle? What money came in? What tasks were completed? What healing occurred between you and someone else? What strength returned to your body?

Ma'at is reality, not wish.

If the number is small, you honor that number.
If the number is big, you honor that number.
You refuse delusion either way.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette with tally marks beside a grain heap',
      colorFrequency: 'Ink black against stored-grain gold',
      mantra: '"I face the truth of what exists."',
    ),
  ),

  'sefbedet_10_1': KemeticDayInfo(
    gregorianDate: 'July 27, 2025',
    kemeticDate: 'Šef-Bedet I, Day 10 (Day 10 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Month of nourishment as civilization\'s first vow after chaos.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Seal the Promise to Continue',
    cosmicContext: '''Day 10 is vow.

Kemet never ended a decan with "That was nice." They ended with commitment. The question was always: will you keep feeding what you brought to life, or will you abandon it the moment the crisis feeling wears off?

Today you speak a quiet promise to your own future. Not loud. Not performative. Just real.

You decide what you will keep alive through steady care — body practice, shared table, repaired bond, restored income stream, morning prayer, a child's stability.

You tell that life, "I'm staying."
That is Ma'at: continuity.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Form the Vessel', action: 'Prepare the container: clean jars, steady routines, clear a place for what will grow.', reflection: '"Have I shaped a stable place for life to sit?"'),
      DecanDayInfo(day: 2, theme: 'Moisten the Clay', action: 'Water deliberately. Hydrate body, soil, schedule.', reflection: '"Where am I cracked from neglect and in need of moisture?"'),
      DecanDayInfo(day: 3, theme: 'Plant Intention', action: 'Choose one living goal this cycle and plant it. Not ten. One.', reflection: '"What deserves to be rooted in me right now?"'),
      DecanDayInfo(day: 4, theme: 'Feed What You Planted', action: 'Give it fuel: calories, time, presence, protection.', reflection: '"Did I actually nourish what I claimed I cared about?"'),
      DecanDayInfo(day: 5, theme: 'Protect the Fragile', action: 'Put small boundaries around early growth.', reflection: '"What new growth needs shielding from noise and chaos?"'),
      DecanDayInfo(day: 6, theme: 'Breathe Into the Work', action: 'Slow the nervous system. Long exhale. Labor without panic.', reflection: '"Is my body still acting like I\'m in crisis even though I\'m not?"'),
      DecanDayInfo(day: 7, theme: 'Honor the Providers', action: 'Acknowledge who/what nourishes you materially.', reflection: '"Do I treat my sources of support as sacred or as automatic?"'),
      DecanDayInfo(day: 8, theme: 'Distribute Fairly', action: 'Share food, money, time, attention in balance — not hoarding, not self-erasure.', reflection: '"Is my giving Ma\'at-balanced or am I draining myself?"'),
      DecanDayInfo(day: 9, theme: 'Record the Yield', action: 'Take inventory. What did you actually grow, save, repair, stabilize so far?', reflection: '"Can I point to proof of order — or am I telling a story?"'),
      DecanDayInfo(day: 10, theme: 'Seal the Promise to Continue', action: 'Make a quiet vow to keep feeding this life tomorrow.', reflection: '"What will I keep alive through consistency, not hype?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Joined hands over a small, steady flame in a clay lamp',
      colorFrequency: 'Ember red held inside protective earth-brown',
      mantra: '"I keep feeding what I chose to keep alive."',
    ),
  ),

  // ==========================================================
  // 🌿 ŠEF-BEDET II — DAYS 11–20  (Second Decan - smd srt)
  // ==========================================================

  'sefbedet_11_2': KemeticDayInfo(
    gregorianDate: 'July 28, 2025',
    kemeticDate: 'Šef-Bedet II, Day 11 (Day 11 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet (šf-bdt) — "The Nourisher," declaring that to feed and to sustain is sacred duty, not charity.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Walk the Boundary',
    cosmicContext: '''Day 11 is patrol.

After the clay is shaped and the shoots are up, the work shifts from forming to guarding. The ancients walked the edges of their plots at dawn and dusk, scanning for burrows, tracks, chew marks, fungus, theft. That walk was not paranoia. It was love.

Today you walk your own perimeter — money, body, time, home, children, peace. You look honestly at where chaos is slipping in: late-night scrolling that wrecks your sleep, a person who only calls when they're hungry, a leak in your spending, a stress spiral that's already drying you out.

Renenutet's gaze was considered mercy because it caught the threat early. You do the same. You do not look away.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Coiled cobra encircling a bundle of grain',
      colorFrequency: 'Guarding bronze around ripening green',
      mantra: '"I see what approaches my field."',
    ),
  ),

  'sefbedet_12_2': KemeticDayInfo(
    gregorianDate: 'July 29, 2025',
    kemeticDate: 'Šef-Bedet II, Day 12 (Day 12 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The month where nourishment becomes a social contract.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Name the Pest',
    cosmicContext: '''Day 12 is honesty.

In Kemet, you did not pretend rats were "not that bad." You named them. You trapped them. You sealed the grain.

Today you stop romanticizing the thing that is draining you. You say its name — the habit that's bleeding money, the person who escalates drama then says it's love, the excuse that keeps you tired, the food that keeps you inflamed and fogged, the self-story that keeps you small.

You don't have to fix it all in one motion. But you must stop lying about it.

Ma'at cannot operate where denial is being worshiped.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Cobra head flared, tongue extended toward a gnawing rat',
      colorFrequency: 'Warning red at the hood edge, deep soil brown beneath',
      mantra: '"I will not pretend the threat is harmless."',
    ),
  ),

  'sefbedet_13_2': KemeticDayInfo(
    gregorianDate: 'July 30, 2025',
    kemeticDate: 'Šef-Bedet II, Day 13 (Day 13 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The ethic of keeping what lives, alive.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Lay Protective Offerings',
    cosmicContext: '''Day 13 is reinforcement.

This is where you add actual measures that keep you safe tomorrow, not just today. You install a boundary and you also fortify that boundary.

In Kemet that meant patching the grain store, posting a watcher, smoothing the mud seal, leaving milk at the edge of the field. In your life that means: meal prep to keep your body steady, password changes, sleep schedule enforcement, cash moved somewhere it won't get casually spent, a conversation where expectations are stated in daylight.

Protection is not just "back off." Protection is "here is the system that keeps me well."

You are allowed to build that system.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Four small offering bowls at the four corners of a planted square',
      colorFrequency: 'Milk white cooling over fertile green',
      mantra: '"I maintain the guard that maintains me."',
    ),
  ),

  'sefbedet_14_2': KemeticDayInfo(
    gregorianDate: 'July 31, 2025',
    kemeticDate: 'Šef-Bedet II, Day 14 (Day 14 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Nourishment requires defense.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Strike the Threat',
    cosmicContext: '''Day 14 is decisive removal.

There is a point where guarding is not enough. You don't negotiate with the rat inside the grain bin. You remove it.

Today you cut off something that is actively harming what you're growing. That might mean blocking access, saying "No, that's done," canceling a drain subscription, throwing out what keeps dragging you backward, refusing to keep arguing with someone who feeds on the argument.

In Kemet this wasn't considered cruelty. It was considered kindness to the entire village.

You are allowed to eliminate what is killing the field.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Striking cobra over fallen vermin',
      colorFrequency: 'Sunlit gold at the hood edge, blacked-out shadow beneath',
      mantra: '"I remove what endangers my future."',
    ),
  ),

  'sefbedet_15_2': KemeticDayInfo(
    gregorianDate: 'August 1, 2025',
    kemeticDate: 'Šef-Bedet II, Day 15 (Day 15 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The month where compassion is maintenance, not softness.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Cool the Field',
    cosmicContext: '''Day 15 is heat management.

Too much sun scorches sprouts. Too much anger scorches relationships. Too much adrenaline scorches the body.

Cooling the field is not apathy. It's intelligent regulation.

Today you deliberately lower destructive heat. You de-escalate a fight before it becomes scorched earth. You reduce input that overstimulates you. You ice inflammation. You step back from the argument that will cost you sleep and money.

In Kemet they shaded the most tender growth. You shade what is tender in you and around you.

Your calm is not surrender. Your calm is preservation.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Curled serpent exhaling cool breath across young shoots',
      colorFrequency: 'Pale blue-green over sun-warmed earth',
      mantra: '"I lower the heat so life can keep growing."',
    ),
  ),

  'sefbedet_16_2': KemeticDayInfo(
    gregorianDate: 'August 2, 2025',
    kemeticDate: 'Šef-Bedet II, Day 16 (Day 16 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Survival is stored, not improvised.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Guard the Storehouse',
    cosmicContext: '''Day 16 is defense of what you already secured.

Kemet counted grain, sealed jars, posted watchers, logged access. That wasn't greed. That was "these lives will eat in the dry months."

Today you secure your stored value. That could be literal food, money you finally put aside, the energy you finally reclaimed, trust you rebuilt with someone, even knowledge you worked hard to earn.

Ask, "Is it actually safe, or is it bleeding out through casual leaks?"

You are allowed to protect your reserves without guilt.
You are not required to let others raid what you bled to save.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Bound grain jar with serpent coiled around the lid',
      colorFrequency: 'Deep storage brown, sealed with protective bronze',
      mantra: '"What I saved will remain mine."',
    ),
  ),

  'sefbedet_17_2': KemeticDayInfo(
    gregorianDate: 'August 3, 2025',
    kemeticDate: 'Šef-Bedet II, Day 17 (Day 17 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Feeding is communal, but not everyone is allowed in the granary.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Tighten the Circle',
    cosmicContext: '''Day 17 is access control.

Ancient villages understood something a lot of modern people pretend not to understand: not everyone should be inside your protected space.

Today you redraw who is allowed close. Who gets your time, your softness, your attention, your plans, your body, your money, your peace. You are not required to be available to everyone who wants you.

This is not cruelty. This is hygiene.

Renenutet does not apologize for who she keeps out of the grain house. Neither do you.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent coiled at a doorway, head lifted',
      colorFrequency: 'Threshold copper edging into shadow',
      mantra: '"Not everyone crosses into my protected ground."',
    ),
  ),

  'sefbedet_18_2': KemeticDayInfo(
    gregorianDate: 'August 4, 2025',
    kemeticDate: 'Šef-Bedet II, Day 18 (Day 18 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Your responsibility now includes record of loss.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Track the Losses',
    cosmicContext: '''Day 18 is accounting without shame.

In Kemet, the scribe didn't cry over what was gone. They wrote it down. "We lost this much to mold. We lost this much to rats. We lost this much to neglect." Then they changed the system.

Today you admit where life leaked. Money you shouldn't have spent. Time you gave to chaos. Food you ate that made you weak. Words you said that damaged trust. Hours of sleep you burned.

This is not self-hate. This is survival math.

If you won't face where you're bleeding, you will keep bleeding.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette beside a jar with a crack',
      colorFrequency: 'Ink black and warning red traced along the fracture line',
      mantra: '"I admit the leak so I can seal it."',
    ),
  ),

  'sefbedet_19_2': KemeticDayInfo(
    gregorianDate: 'August 5, 2025',
    kemeticDate: 'Šef-Bedet II, Day 19 (Day 19 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The duty to feed includes the duty to define terms.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Reinforce the Oath',
    cosmicContext: '''Day 19 is declaration.

In Kemet, they spoke vows out loud: how grain would be used, who had rights to take, how peace in the household would be kept. Spoken law became lived law.

Today you restate your terms for your own life. Say them aloud or write them clearly. "This is how I will be treated. This is how my resources will move. This is how I keep my body. This is how we speak in this house. This is how conflict will be handled."

You are not being dramatic. You are engraving Ma'at.

If you don't say your law, people will pretend you don't have one.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Raised cobra beside a carved oath-staff / standard',
      colorFrequency: 'Statement gold on disciplined dark brown',
      mantra: '"My law is spoken and will be honored."',
    ),
  ),

  'sefbedet_20_2': KemeticDayInfo(
    gregorianDate: 'August 6, 2025',
    kemeticDate: 'Šef-Bedet II, Day 20 (Day 20 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — "The Nourisher," now fortified.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Stand Watch at Dusk',
    cosmicContext: '''Day 20 is quiet vigilance.

The end of this decan is not explosive. It's settled. Serpent-coiled. Eyes half-lidded but awake.

Tonight you sit with awareness. You slow your body, soften your jaw, and you review the patterns you saw across these ten days: Where did threats show up? Where did you shut them down early? Where did you wait too long? Who proved trustworthy? Who revealed themselves?

Renenutet inspects the fields at night. You inspect your life at night.

This is not anxiety. This is guardianship.

You tell the world, and yourself: "I am awake at my own border."''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Walk the Boundary', action: 'Inspect the perimeter of your life: health, money, relationships, space. Note every breach.', reflection: '"Where is chaos sneaking in?"'),
      DecanDayInfo(day: 12, theme: 'Name the Pest', action: 'Identify the actual drain (person, habit, substance, thought) without lying about it.', reflection: '"What is quietly eating my field at night?"'),
      DecanDayInfo(day: 13, theme: 'Lay Protective Offerings', action: 'Strengthen the guard: rituals, nutrition, sleep, locks, agreements, budgeting, passwords.', reflection: '"What will I put in place tonight so I wake safer tomorrow?"'),
      DecanDayInfo(day: 14, theme: 'Strike the Threat', action: 'Remove what actively harms growth. Cut access. Say no. Block.', reflection: '"What am I allowing near me that Ma\'at would drive into the sand?"'),
      DecanDayInfo(day: 15, theme: 'Cool the Field', action: 'Lower heat before it scorches: de-escalate conflict, reduce stress load, cool inflammation.', reflection: '"Where am I running too hot to stay fertile?"'),
      DecanDayInfo(day: 16, theme: 'Guard the Storehouse', action: 'Protect stored value: food, money, saved energy, repaired trust.', reflection: '"What I saved — is it actually safe?"'),
      DecanDayInfo(day: 17, theme: 'Tighten the Circle', action: 'Reconfirm who is inside your protected space and who is not.', reflection: '"Who has access to me that should not?"'),
      DecanDayInfo(day: 18, theme: 'Track the Losses', action: 'Record leaks, waste, theft, relapse, erosion. No denial.', reflection: '"Where did life escape my hands?"'),
      DecanDayInfo(day: 19, theme: 'Reinforce the Oath', action: 'Restate your terms: how you will be treated, how resources will be handled, how peace is kept.', reflection: '"Have I spoken my law out loud?"'),
      DecanDayInfo(day: 20, theme: 'Stand Watch at Dusk', action: 'End the decan in awareness. Quiet body, sharpen perception. Stay awake to patterns.', reflection: '"Do I see threats early enough, or only after damage is done?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent coiled in a ring, single eye open',
      colorFrequency: 'Twilight bronze around deep green life',
      mantra: '"I remain awake at my border."',
    ),
  ),

  // ==========================================================
  // 🌿 ŠEF-BEDET III — DAYS 21–30  (Third Decan - srt)
  // ==========================================================

  'sefbedet_21_3': KemeticDayInfo(
    gregorianDate: 'August 7, 2025',
    kemeticDate: 'Šef-Bedet III, Day 21 (Day 21 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet (šf-bdt) — "The Nourisher," the promise that life will be fed.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Exhale the Tension',
    cosmicContext: '''Day 21 is unclench.

For twenty days you've been shaping and guarding. You've been on alert. You've checked doors, watched tone, watched faces, watched bills, watched your own mind for sabotage.

Today is the first sanctioned loosening. In Kemet, this was when the village shoulders literally dropped. Laughter returned to normal volume. People stretched longer. Sleep deepened.

You are not "slacking." You are letting your nervous system come down from defense mode.

Ask your body, "Where am I still braced for danger that already passed?" and let that place soften.

Trust is part of Ma'at. Panic forever is not.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Long serpent stretched in a relaxed curve around a planted field',
      colorFrequency: 'Soft dusk gold around calm green',
      mantra: '"I can breathe. The field is held."',
    ),
  ),

  'sefbedet_22_3': KemeticDayInfo(
    gregorianDate: 'August 8, 2025',
    kemeticDate: 'Šef-Bedet III, Day 22 (Day 22 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Feeding made real.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Acknowledge the Living Field',
    cosmicContext: '''Day 22 is witness.

You look directly at what is alive because of your discipline and you refuse to downplay it.

In Kemet, this was a quiet walk-through. Adults would point for children: "See that canal? We dug that. See those shoots? We kept the pests off. See that storage? We sealed it." You did not pretend it "just worked out." You tied survival to labor and to Ma'at.

Today you inventory the life that still exists because you showed up. Your household. Your own body. Your work. Your clarity. Your children's sense of safety.

Let yourself say, "That's alive because I guarded it."

That naming is not ego. That naming is instruction.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Eye of a serpent looking inward at a thriving stalk',
      colorFrequency: 'Living green with steady bronze outline',
      mantra: '"I see what is alive because of me."',
    ),
  ),

  'sefbedet_23_3': KemeticDayInfo(
    gregorianDate: 'August 9, 2025',
    kemeticDate: 'Šef-Bedet III, Day 23 (Day 23 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The Nourisher.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Bless What Will Feed Others',
    cosmicContext: '''Day 23 is generosity with structure.

In Kemet, part of what was guarded was always meant to circulate — to elders, to children, to ritual, to the temple granary that would feed the town in famine. Feeding others was not "extra credit." It was woven into the system from the start.

Today you locate what in your life will nourish beyond you — your labor, your skill, your stored resource, your steadiness, your clarity — and you bless it for that purpose.

Ask, "Who will eat because I did not collapse?"

This is sacred. You are not small. Your survival is not private.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent encircling a basket of grain being handed outward',
      colorFrequency: 'Warm gold over shared earth-brown',
      mantra: '"What I guarded will feed more than me."',
    ),
  ),

  'sefbedet_24_3': KemeticDayInfo(
    gregorianDate: 'August 10, 2025',
    kemeticDate: 'Šef-Bedet III, Day 24 (Day 24 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Compassion as infrastructure.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Loosen Control (Without Abandoning Order)',
    cosmicContext: '''Day 24 is the release of the death grip.

You cannot micromanage every drop of water and every breath of everyone you love forever. That turns you into the drought.

The work now is to trust the systems you built. Trust the canal you dug. Trust the lock you set. Trust the boundary you spoke. Trust the person you trained to help. Trust your own rhythm.

You do not abandon order — you simply stop strangling it.

Ask, "Where can I let go of constant panic and let Ma'at carry some weight?"

If you never rest, you become the predator you swore to keep out.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Long serpent in a loose ring, not constricting — simply present',
      colorFrequency: 'Calm olive and warm clay',
      mantra: '"I trust the order I built."',
    ),
  ),

  'sefbedet_25_3': KemeticDayInfo(
    gregorianDate: 'August 11, 2025',
    kemeticDate: 'Šef-Bedet III, Day 25 (Day 25 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The month that keeps the world fed.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Tend the Vessel',
    cosmicContext: '''Day 25 is maintenance of the carrier.

In Kemet, they did oiling, bandaging, sharpening, retying, mending. Tools were serviced. Feet were washed. Backs were rubbed with oils. Throats were soothed with honey and beer. This was seen as duty, not luxury.

You are the vessel that delivers nourishment to your world. Your throat carries instruction. Your hands carry food. Your body carries presence.

Today you tend that vessel. Sleep, stretch, hydrate, clean, soothe, repair, groom, re-center.

Ask: "Am I treating the carrier of all this life like something sacred, or something disposable?"

You cannot pour if you keep tearing the container.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent curled gently around a water jar, not squeezing — supporting',
      colorFrequency: 'Restful blue-grey and body-warm amber',
      mantra: '"I keep the carrier intact."',
    ),
  ),

  'sefbedet_26_3': KemeticDayInfo(
    gregorianDate: 'August 12, 2025',
    kemeticDate: 'Šef-Bedet III, Day 26 (Day 26 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Nourishment is a lineage act.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Name the Inheritance',
    cosmicContext: '''Day 26 is clarity about what continues after you.

In Kemet, nothing was allowed to be "accidental legacy." Skills were handed down deliberately — irrigation timing, seed choice, preservation methods, prayer cadence, negotiation style, law of the household. You said what stays.

Today you define your inheritance. Not money only — pattern. Rhythm. Expectation of order. Emotional safety. A way to speak truth without humiliation.

Ask, "What am I actually handing forward?"

If you don't name it, chaos will name it for you.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent encircling a small bundle handed from a larger hand to a smaller hand',
      colorFrequency: 'Ancestral brown and dawn gold',
      mantra: '"I decide what continues."',
    ),
  ),

  'sefbedet_27_3': KemeticDayInfo(
    gregorianDate: 'August 13, 2025',
    kemeticDate: 'Šef-Bedet III, Day 27 (Day 27 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The month where feeding becomes proof of devotion.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Give Thanks Without Apology',
    cosmicContext: '''Day 27 is unapologetic thanksgiving.

Kemet did not practice fake humility. When the field held, they thanked loudly. When the jars sealed, they thanked. When the children ate, they thanked. Gratitude was considered intelligent recognition of cosmic partnership.

Today you thank openly. Not "I'm lucky, I don't deserve this," but "I worked with Ma'at, and we kept this alive together."

Can you sit in what you actually did without shrinking, joking, or dismissing it?

Ask, "Can I receive the reality that I did sacred work?"

Receiving that truth stabilizes your spirit for the next cycle.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hands holding grain upward within a serpent ring',
      colorFrequency: 'Offering gold over river-deep green',
      mantra: '"I honor what we built, without apology."',
    ),
  ),

  'sefbedet_28_3': KemeticDayInfo(
    gregorianDate: 'August 14, 2025',
    kemeticDate: 'Šef-Bedet III, Day 28 (Day 28 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — The Nourisher, preparing to conclude her term.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Bind the Promise',
    cosmicContext: '''Day 28 is vow.

You now speak continuation into reality. In Kemet, this might be: "This canal will be cleared again next season." "This household will remain in Ma'at." "This food will be apportioned with justice." "This voice will not lie."

You choose one balance — one — and you bind yourself to holding it.

Ask, "What balance will I refuse to let collapse after today?"

This is not theater. This is maintenance of civilization at your scale.

Civilization falls when no one binds promise at the small level.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent forming a closed ring around a single upright Djed',
      colorFrequency: 'Oath gold and pillar-stable sandstone',
      mantra: '"This balance will remain under my watch."',
    ),
  ),

  'sefbedet_29_3': KemeticDayInfo(
    gregorianDate: 'August 15, 2025',
    kemeticDate: 'Šef-Bedet III, Day 29 (Day 29 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — Still feeding, but beginning to turn toward harvest logic.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Align with Graceful Pace',
    cosmicContext: '''Day 29 is rhythm correction.

You cannot carry the next month if your current pace is devouring you. The serpent who encircles the world moves in one unbroken line, not in panic jolts.

Today you examine your tempo: sleep, speech, work hours, spending rate, emotional output. You ask, "Is this pace survivable long-term?"

If the answer is no, you slow something. Not everything — something. You adjust toward grace, not collapse.

Kemet understood this: no field survives if the farmer burns out before harvest.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Long serpent flowing in one smooth line above evenly spaced footprints',
      colorFrequency: 'Even river blue and grounded earth umber',
      mantra: '"I move at a pace I can keep."',
    ),
  ),

  'sefbedet_30_3': KemeticDayInfo(
    gregorianDate: 'August 16, 2025',
    kemeticDate: 'Šef-Bedet III, Day 30 (Day 30 of Šef-Bedet / Tybi)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Šef-Bedet — "The Nourisher," at completion.',
      decanName: 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — trusted growth.',
    maatPrinciple: 'Prepare the Hand-Off',
    cosmicContext: '''Day 30 is transfer.

Šef-Bedet is closing. A new month is about to begin. You are not supposed to stumble into it exhausted and chaotic. You are supposed to enter carrying order.

Today you ready the hand-off: you organize notes, label stores, clarify who's doing what next, log what was promised, give instructions where needed, rest your body so it can start clean.

Ask: "How do I enter the next month as keeper, not as casualty?"

This is how Kemet stayed standing for millennia: each cycle did not just end — it prepared the next one with dignity.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Exhale the Tension', action: 'Let the body unclench. Rest nervous systems you\'ve been holding tight.', reflection: '"Where am I still braced for danger that has already passed?"'),
      DecanDayInfo(day: 22, theme: 'Acknowledge the Living Field', action: 'Look directly at what you\'ve kept alive — family, body, work, order. Witness it without minimizing.', reflection: '"What survived because of my care?"'),
      DecanDayInfo(day: 23, theme: 'Bless What Will Feed Others', action: 'Offer gratitude for what will nourish more than just you.', reflection: '"Who will be fed by what I\'ve protected?"'),
      DecanDayInfo(day: 24, theme: 'Loosen Control (Without Abandoning Order)', action: 'Release micromanaging. Trust the processes you\'ve built.', reflection: '"Where can I stop gripping and let Ma\'at carry some of the weight?"'),
      DecanDayInfo(day: 25, theme: 'Tend the Vessel', action: 'Care for the carrier — your own body, your tools, your hands, your voice.', reflection: '"Am I maintaining the vessel that delivers nourishment?"'),
      DecanDayInfo(day: 26, theme: 'Name the Inheritance', action: 'Say clearly what will be passed forward — knowledge, rhythm, safety, stored grain, example.', reflection: '"What am I preparing to hand to the next set of hands?"'),
      DecanDayInfo(day: 27, theme: 'Give Thanks Without Apology', action: 'Give thanks openly, without shrinking or performing humility.', reflection: '"Can I receive the reality that I did sacred work?"'),
      DecanDayInfo(day: 28, theme: 'Bind the Promise', action: 'State your continuation vow: "This order will continue."', reflection: '"What balance will I refuse to let collapse after today?"'),
      DecanDayInfo(day: 29, theme: 'Align with Graceful Pace', action: 'Match your movement to sustainable rhythm, not panic speed.', reflection: '"Is my current tempo survivable long-term?"'),
      DecanDayInfo(day: 30, theme: 'Prepare the Hand-Off', action: 'Close the month not in exhaustion, but in readiness to begin the next cycle with dignity intact.', reflection: '"How do I enter the next month as keeper, not as casualty?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Serpent forming a circle around two hands passing a marked jar',
      colorFrequency: 'Transition gold over orderly clay-red',
      mantra: '"I do not just survive the cycle — I hand it forward in order."',
    ),
  ),

  // ==========================================================
  // 🌿 REKH-WER I — DAYS 1–10  (First Decan - rs-ḥr)
  // ==========================================================

  'rekhwer_1_1': KemeticDayInfo(
    gregorianDate: 'August 17, 2025',
    kemeticDate: 'Rekh-Wer I, Day 1 (Day 1 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Emergence moving toward stewardship',
    month: 'Rekh-Wer (rḫ-wr) — "Great Knowing," the month where knowledge becomes duty, not ego',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Wake to Responsibility',
    cosmicContext: '''Day 1 is acceptance.

In Rekh-Wer, knowing is not intellectual. Knowing is guardianship. The one who "knows Maʿat" is the one who keeps their world upright.

In Kemet, the first act after dawn was not talking — it was walking. You did not assume yesterday's order survived the night. You went to see.

Today, you acknowledge that parts of reality are yours to hold. Your household rhythm. Your finances. Your agreements. Your wellness. Your spiritual hygiene. Your children's sense of safety.

Ask, "What in my world answers to me?" Say it without fear and without apology.

You are not waiting for someone else to be the adult. You are the adult.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Udjat-style vigilant eye above a boundary line',
      colorFrequency: 'Dawn gold over boundary black',
      mantra: '"I am awake to what is mine to keep."',
    ),
  ),

  'rekhwer_2_1': KemeticDayInfo(
    gregorianDate: 'August 18, 2025',
    kemeticDate: 'Rekh-Wer I, Day 2 (Day 2 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The Month of Great Knowing',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Walk the Perimeter',
    cosmicContext: '''Day 2 is inspection.

In Kemet, you physically walked the line — the edges of the field, the walls of the granary, the dikes controlling the water. You looked for leaks, cracks, theft, trespass.

Today, your perimeter includes more than walls. It includes mood shifts in your house. It includes bank activity. It includes tone in your relationships. It includes your own slipping habits.

Ask yourself: "Where is something crossing a line without permission?"

You don't argue with the breach. You note it. You name it. Quietly. Fully. Truthfully.

This is not paranoia. This is care.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Footsteps tracing a border line with an upright measuring rod',
      colorFrequency: 'Boundary clay-red and measured linen-white',
      mantra: '"I walk my edges with clear eyes."',
    ),
  ),

  'rekhwer_3_1': KemeticDayInfo(
    gregorianDate: 'August 19, 2025',
    kemeticDate: 'Rekh-Wer I, Day 3 (Day 3 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, "Great Knowing," meaning not trivia but correct perception',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Name What\'s Off',
    cosmicContext: '''Day 3 is sober naming.

In the Kemetic mind, lying about the state of a canal was a spiritual crime, not just a logistical one. To say "it's fine" when it's broken is to invite isfet — disorder.

Today you speak one thing plainly. "This bill is behind." "This habit is making me weak." "This tension in the house is real." "This workspace is chaos." "I'm exhausted and pretending I'm not."

You are not shaming yourself. You are labeling reality so Maʿat can be applied.

Ask, "Where am I lying to myself about the state of things?"

Truth is not cruelty here. Truth is first medicine.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'An open eye over a crooked line being straightened by a hand',
      colorFrequency: 'Direct sunlight gold over correction red',
      mantra: '"I speak what is unbalanced so it can be balanced."',
    ),
  ),

  'rekhwer_4_1': KemeticDayInfo(
    gregorianDate: 'August 20, 2025',
    kemeticDate: 'Rekh-Wer I, Day 4 (Day 4 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The Month of Great Knowing',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Correct the Channel',
    cosmicContext: '''Day 4 is surgical correction.

In Kemet, you didn't rebuild the whole irrigation system every morning. You fixed the blockage you found. You pulled one clump of silt, patched one leak in the dike, redirected one trickle.

Today is that. Make one direct adjustment that prevents a future problem from getting teeth.

Repay something small you owe. Re-say something clean that you fumbled in anger. Re-label a boundary and mean it. Throw out the object that keeps pulling you backward.

Ask, "What small fix today prevents a larger problem tomorrow?"

You're not "being dramatic." You're preventing flood damage of the soul.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'A hand clearing silt from a narrow water channel',
      colorFrequency: 'Canal blue and corrective clay',
      mantra: '"I adjust early, so balance holds."',
    ),
  ),

  'rekhwer_5_1': KemeticDayInfo(
    gregorianDate: 'August 21, 2025',
    kemeticDate: 'Rekh-Wer I, Day 5 (Day 5 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, "Great Knowing," guided by Thoth and tempered by Sekhmet',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Account for the Store',
    cosmicContext: '''Day 5 is inventory.

Kemet understood that fantasy math is a form of chaos. Saying you have 30 sacks when you have 17 is a lie against Maʿat — and an insult to everyone depending on you.

Today you count honestly. Money. Energy. Time. Food. Bandwidth. Trust. Attention. Health. You write the real number.

Ask, "What do I truly have, not what I wish I had?"

This is not to shame you. This is to give you power. You cannot command what you refuse to measure.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Measuring cord and tally marks beside a sealed grain jar',
      colorFrequency: 'Scribe black and stored-grain ochre',
      mantra: '"I deal in what\'s real, not what\'s wished."',
    ),
  ),

  'rekhwer_6_1': KemeticDayInfo(
    gregorianDate: 'August 22, 2025',
    kemeticDate: 'Rekh-Wer I, Day 6 (Day 6 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The Month of Applied Understanding',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Stabilize the Schedule',
    cosmicContext: '''Day 6 is time governance.

Kemet did not live by chaotic impulse. Tasks were sequenced: open the canal, feed the animals, sharpen the blades, teach the apprentice, rest in shade, record output.

Today you take control of your hours. You prioritize what actually moves life forward, not what drags you into noise or keeps you performing for other people's comfort.

Ask, "Is my day shaped by intention or by interruption?"

If interruption is writing your life, you are not in Maʿat. You are being carried by currents that do not love you.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Sun disk over evenly divided time marks',
      colorFrequency: 'Disciplined linen-white over solar gold',
      mantra: '"My hours answer to Maʿat, not to chaos."',
    ),
  ),

  'rekhwer_7_1': KemeticDayInfo(
    gregorianDate: 'August 23, 2025',
    kemeticDate: 'Rekh-Wer I, Day 7 (Day 7 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Knowledge applied as protection',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Cut Hidden Waste',
    cosmicContext: '''Day 7 is leak control.

In a Kemetic village, it wasn't the dramatic robbery that ruined you — it was the slow seep. A loose seal on a grain jar. A lazy trickle in a canal. A cousin who "borrows" daily. Your own habit that drains your life-force but you keep calling it nothing.

Today you stop one leak. Just one.

Ask, "Where am I bleeding out and calling it normal?"

You are allowed to seal that tear without guilt. That is not selfishness. That is duty to the household you protect.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'A cracked jar being sealed with pressed clay',
      colorFrequency: 'Conserved grain-gold and sealant brown',
      mantra: '"I refuse slow loss."',
    ),
  ),

  'rekhwer_8_1': KemeticDayInfo(
    gregorianDate: 'August 24, 2025',
    kemeticDate: 'Rekh-Wer I, Day 8 (Day 8 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Great Knowing under Thoth\'s measure and Sekhmet\'s fire',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Reinforce Authority with Calm',
    cosmicContext: '''Day 8 is calm enforcement.

In Kemet, order was often re-stated quietly: "This canal stays closed at night." "This jar is sealed." "This area is for grain, not gossip." Tone low. Eyes steady. Boundary clear.

Today you reassert one boundary — not with anger (anger gives your power away), but with clarity.

Ask, "Can I assert order without shouting?"

If you can speak a law without shaking, then you are truly holding it. If you must explode to be heard, the law is already compromised.

Calm is not softness. Calm is ownership.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Upright reed staff held steady, not raised to strike',
      colorFrequency: 'Authority red anchored with cool shadow blue',
      mantra: '"My boundary is law even when I whisper it."',
    ),
  ),

  'rekhwer_9_1': KemeticDayInfo(
    gregorianDate: 'August 25, 2025',
    kemeticDate: 'Rekh-Wer I, Day 9 (Day 9 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The month where knowledge is passed, not hoarded',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Teach the Rule',
    cosmicContext: '''Day 9 is instruction.

In Kemet, skill was inheritance. You didn't let your child guess how to carry water without spilling. You showed them. You explained the why. "We seal this jar because rats will come." "We sweep before heat because snakes sleep in cool shade by noon." You gave them Ma'at in sentences.

Today you tell someone who depends on you, plainly and without contempt, what the rule is — and why that rule exists.

Ask, "Did I explain the 'why,' or am I demanding obedience without understanding?"

When you teach the rule, you are multiplying your guardianship instead of chaining yourself to endless emergency response.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Mouth speaking beside a guiding hand over a younger hand',
      colorFrequency: 'Teacher gold and apprentice clay',
      mantra: '"I transfer order on purpose."',
    ),
  ),

  'rekhwer_10_1': KemeticDayInfo(
    gregorianDate: 'August 26, 2025',
    kemeticDate: 'Rekh-Wer I, Day 10 (Day 10 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, "Great Knowing"',
      decanName: 'knmw ("Khnum")',
      starCluster: '✨ Khnum — formation through knowledge.',
    maatPrinciple: 'Document the State of the House',
    cosmicContext: '''Day 10 is record-keeping.

Kemet was obsessive about ledgers, boundary maps, flood marks, work rosters. This wasn't bureaucracy. This was continuity. If the one in charge died, the next could step in without guessing.

Today you write down the truth of your house. Resources. Debts. Fractures. Supports. Goals. Concerns. Agreements.

Ask, "If I vanished tonight, would someone know where things stand because I wrote it down?"

This is love. This is maturity. This is Maʿat.

Your memory should not be the only place your world exists.''',
    decanFlow: [
      DecanDayInfo(day: 1, theme: 'Wake to Responsibility', action: 'Rise with purpose. Accept that keeping order is your role now.', reflection: '"What in my world answers to me?"'),
      DecanDayInfo(day: 2, theme: 'Walk the Perimeter', action: 'Inspect physical, emotional, financial, and spiritual boundaries. Look for breaches.', reflection: '"Where is something crossing a line without permission?"'),
      DecanDayInfo(day: 3, theme: 'Name What\'s Off', action: 'Say out loud what is out of balance — no softening, no pretending.', reflection: '"Where am I lying to myself about the state of things?"'),
      DecanDayInfo(day: 4, theme: 'Correct the Channel', action: 'Make one direct adjustment (repair, repay, re-say, re-mark a line).', reflection: '"What small fix today prevents a larger problem tomorrow?"'),
      DecanDayInfo(day: 5, theme: 'Account for the Store', action: 'Count what is actually there — money, energy, grain, time, attention. No fantasy math.', reflection: '"What do I truly have, not what I wish I had?"'),
      DecanDayInfo(day: 6, theme: 'Stabilize the Schedule', action: 'Align today\'s time blocks with what matters most, not noise.', reflection: '"Is my day shaped by intention or by interruption?"'),
      DecanDayInfo(day: 7, theme: 'Cut Hidden Waste', action: 'Identify one leak: energy drain, money drain, attention drain. Seal it.', reflection: '"Where am I bleeding out and calling it normal?"'),
      DecanDayInfo(day: 8, theme: 'Reinforce Authority with Calm', action: 'Re-state a boundary without anger. Calm is not weakness — it\'s proof of control.', reflection: '"Can I assert order without shouting?"'),
      DecanDayInfo(day: 9, theme: 'Teach the Rule', action: 'Tell someone who depends on you what the rule is and why. Pass on structure like inheritance.', reflection: '"Did I explain the \'why,\' or am I expecting obedience without understanding?"'),
      DecanDayInfo(day: 10, theme: 'Document the State of the House', action: 'Record conditions: resources, risks, supports, goals. This becomes the baseline for the rest of the month.', reflection: '"If I vanished tonight, would someone know where things stand because I wrote it down?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette and papyrus scroll beside an outlined house',
      colorFrequency: 'Ink black and foundation clay',
      mantra: '"I leave order behind me in writing."',
    ),
  ),

  // ==========================================================
  // 🌿 REKH-WER II — DAYS 11–20  (Second Decan - ḥry-ib rꜣ)
  // ==========================================================

  'rekhwer_11_2': KemeticDayInfo(
    gregorianDate: 'August 27, 2025',
    kemeticDate: 'Rekh-Wer II, Day 11 (Day 11 of Rekh-Wer / Mechir)',
    season: '🌿 Peret — Emergence under guided strength',
    month: 'Rekh-Wer (rḫ-wr) — "Great Knowing," the sober application of intelligence',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Center the Fire',
    cosmicContext: '''Day 11 is stabilization of force.

In Kemet, rage that sprayed everywhere was considered childish. Power that gathered, aimed, and disciplined itself — that was divine.

Today you ask: what is actually fueling you right now? Anger? Hunger? Protection instinct? Fear of sliding backward? Loyalty to someone you refuse to let fall?

You don't judge the source. You identify it and hold it steady like a flame cupped in both hands.

Your job today is simple: do not let your core fire scatter. Keep it centered so it can be used with intention and not spill into harm.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Solar disk set over a seated heart',
      colorFrequency: 'Ember gold contained in deep red',
      mantra: '"My fire is held, not spilled."',
    ),
  ),

  'rekhwer_12_2': KemeticDayInfo(
    gregorianDate: 'August 28, 2025',
    kemeticDate: 'Rekh-Wer II, Day 12 (Day 12 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The Month of Great Knowing',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Breathe the Field',
    cosmicContext: '''Day 12 is oxygen.

A crop can be green and still be suffocating. The roots need air. The soil needs loosened space. If you don't break the crust, it starves quietly.

Your life is the same. Something in you is alive but gasping. A relationship. A talent. A project. Your nervous system. Your body. Your household.

Today you create breathable space. You open a window. You tell the real truth. You remove one demand that's crushing someone you love. You unclench.

Ask, "Where in my life is something alive but gasping?"

Your job is not to "work harder." Your job is to let it breathe.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Curved breath-lines rising from tilled earth',
      colorFrequency: 'Fresh earth brown and cool morning blue',
      mantra: '"I make room for life to breathe."',
    ),
  ),

  'rekhwer_13_2': KemeticDayInfo(
    gregorianDate: 'August 29, 2025',
    kemeticDate: 'Rekh-Wer II, Day 13 (Day 13 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Knowledge in motion, not theory',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Act Without Fury',
    cosmicContext: '''Day 13 is clean execution.

In Kemet, there were times to raise your voice, and times you simply moved. You lifted. You carried. You shut. You opened. You fixed. You enforced. No tantrum. No spectacle.

Today, handle one necessary task firmly, without losing your face.

File the thing. End the thing. Begin the thing. Enforce the rule. Make the call.

Ask, "Can I move with authority without losing my face?"

If the only way you know how to act is by exploding, you are still leaking power instead of holding it.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'A steady hand gripping a staff, not raised to strike',
      colorFrequency: 'Tempered gold and disciplined charcoal',
      mantra: '"I move with power, not panic."',
    ),
  ),

  'rekhwer_14_2': KemeticDayInfo(
    gregorianDate: 'August 30, 2025',
    kemeticDate: 'Rekh-Wer II, Day 14 (Day 14 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, the month of great perception',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Align Power With Purpose',
    cosmicContext: '''Day 14 is aim.

The Kemite lesson: raw strength that isn't aimed at purpose becomes random heat — and random heat becomes destruction.

Today you take your available force (time, focus, physical stamina, voice, reputation, money, attention) and you point it at what actually matters for your path — not at whatever or whoever irritated you first today.

Ask, "Is my effort feeding my purpose, or just feeding my irritation?"

This is where a lot of people betray themselves: they spend sacred fire chasing petty smoke. You will not.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Sun ray drawn like an arrow toward a single point',
      colorFrequency: 'Focused sun-gold on matte black',
      mantra: '"My fire serves my purpose."',
    ),
  ),

  'rekhwer_15_2': KemeticDayInfo(
    gregorianDate: 'August 31, 2025',
    kemeticDate: 'Rekh-Wer II, Day 15 (Day 15 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The Month of Applied Understanding',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Maintain Heat, Don\'t Burn',
    cosmicContext: '''Day 15 is pacing.

The Kemite did not romanticize burnout. Collapse is not noble in this system. Collapse means you can't protect what depends on you.

Today you regulate the fire. You keep steady heat — not frantic blaze. Eat. Hydrate. Stretch. Breathe. Take shade. Step back for 10 quiet minutes to keep from frying your nerves.

Ask, "Am I keeping a steady flame or am I scorching myself?"

You're allowed to be powerful and kind to your own vessel at the same time. In fact, you're required.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Gentle flame held inside a protective curve',
      colorFrequency: 'Sustained ember red and healing aloe green',
      mantra: '"I keep my fire livable."',
    ),
  ),

  'rekhwer_16_2': KemeticDayInfo(
    gregorianDate: 'September 1, 2025',
    kemeticDate: 'Rekh-Wer II, Day 16 (Day 16 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, Great Knowing under Thoth\'s measure',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Speak Clean Command',
    cosmicContext: '''Day 16 is clarity of directive.

In Kemet, leaders (from household heads to foremen to priest-supervisors) were expected to speak in clean instruction: not guilt, not whining, not manipulation.

Today you issue one clear ask. Short. Direct. Need-based, not ego-based. "Do this because it supports balance," not "Do this because I said so."

Ask, "Did I make the ask in clean language, or did I posture?"

Your words must become efficient tools, not weapons that spray resentment.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Mouth-sign above a straight vertical line (order spoken into place)',
      colorFrequency: 'Command gold and unbroken pillar brown',
      mantra: '"My words place things where they belong."',
    ),
  ),

  'rekhwer_17_2': KemeticDayInfo(
    gregorianDate: 'September 2, 2025',
    kemeticDate: 'Rekh-Wer II, Day 17 (Day 17 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — "Great Knowing," which includes knowing you are part of the labor, not above it',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Carry Sun Into the Work',
    cosmicContext: '''Day 17 is embodied leadership.

In Kemet, authority that never touched the work was mistrusted. The foreman still lifted stone. The scribe still carried water sometimes. The priest still helped brace a wall in flood season.

Today you physically stand next to something you are responsible for. You don't just send instructions from a distance. You put your hands on it. You sweat with it.

Ask, "Did I stand next to the work I'm calling for?"

This is how trust is built. This is how your power stops feeling like domination and starts feeling like protection.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Sun disk carried on two shoulders',
      colorFrequency: 'Labor earth-brown lit by active gold',
      mantra: '"I show up in person."',
    ),
  ),

  'rekhwer_18_2': KemeticDayInfo(
    gregorianDate: 'September 3, 2025',
    kemeticDate: 'Rekh-Wer II, Day 18 (Day 18 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — month of wise guardianship',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Shield With Strength',
    cosmicContext: '''Day 18 is protection.

In Kemet, raw force was justified when it kept harm from crossing into the domain of someone who could not yet defend themselves — a child, a worker, a field not yet rooted.

Today you actively use your position, voice, resources, or presence to protect someone or something that would otherwise be exposed.

Ask, "Who needed my cover today — and did they get it?"

If you have strength and do not shelter with it, Maʿat calls that negligence.

Protection is not optional. It is oath.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Solar disk behind an upraised protective hand',
      colorFrequency: 'Guardian red-gold and protective shadow',
      mantra: '"My strength is a shelter."',
    ),
  ),

  'rekhwer_19_2': KemeticDayInfo(
    gregorianDate: 'September 4, 2025',
    kemeticDate: 'Rekh-Wer II, Day 19 (Day 19 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Great Knowing, tempered compassion',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Cool With Honor',
    cosmicContext: '''Day 19 is sanctioned rest.

The Kemite did not glorify constant blaze. Midday shade, water poured on the ground, quiet song to Sekhmet to lower her teeth — these were ritual acts. Cooling the fire was an offering, not laziness.

Today you cool yourself and possibly those around you. You lower temperature without shame. You slow the pace. You feed, hydrate, stretch, sleep, quiet the nervous system.

Ask, "Do I guilt myself for needing restoration?"

If you treat recovery like weakness, you are insulting the very vessel Maʿat needs to act through tomorrow.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Water poured over the sun',
      colorFrequency: 'Cooling blue over banked ember red',
      mantra: '"I let my fire rest without shame."',
    ),
  ),

  'rekhwer_20_2': KemeticDayInfo(
    gregorianDate: 'September 5, 2025',
    kemeticDate: 'Rekh-Wer II, Day 20 (Day 20 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, wisdom embodied',
      decanName: 'ḥry-ib knmw ("Heart of Khnum")',
      starCluster: '✨ Heart of Khnum — discerning, guided craft.',
    maatPrinciple: 'Oath of Restraint',
    cosmicContext: '''Day 20 is oath.

Sekhmet is holy because she can burn. She is safe because she can stop.

Today you speak one line — out loud — defining how you will not allow your power to turn predatory, careless, or cruel.

It can sound like: "I will not weaponize my voice against the people I claim to protect." "I will not scorch my own body for other people's chaos." "I will not spend rage where wisdom is needed."

Ask, "Where must I promise myself: 'I will not become the fire that harms what I love'?"

This is the seal of the decan. This is how you prove you are not just strong — you are trustworthy.''',
    decanFlow: [
      DecanDayInfo(day: 11, theme: 'Center the Fire', action: 'Locate your driving force (anger, urgency, ambition, loyalty). Hold it steady instead of spraying it.', reflection: '"What is actually fueling me right now?"'),
      DecanDayInfo(day: 12, theme: 'Breathe the Field', action: 'Loosen what\'s suffocating. Aerate the space: open windows, let truth and air in.', reflection: '"Where in my life is something alive but gasping?"'),
      DecanDayInfo(day: 13, theme: 'Act Without Fury', action: 'Do the necessary task firmly, without tantrum.', reflection: '"Can I move with authority without losing my face?"'),
      DecanDayInfo(day: 14, theme: 'Align Power With Purpose', action: 'Aim your strength at what matters, not whatever annoyed you first.', reflection: '"Is my effort feeding my purpose, or just feeding my irritation?"'),
      DecanDayInfo(day: 15, theme: 'Maintain Heat, Don\'t Burn', action: 'Sustain energy at a livable temperature. Pace yourself.', reflection: '"Am I keeping a steady flame or am I scorching myself?"'),
      DecanDayInfo(day: 16, theme: 'Speak Clean Command', action: 'Issue one clear directive today. Short. Precise. Need-based, not ego-based.', reflection: '"Did I make the ask in clean language, or did I posture?"'),
      DecanDayInfo(day: 17, theme: 'Carry Sun Into the Work', action: 'Show up physically. Do visible labor that signals "I am part of this," not just "Do this for me."', reflection: '"Did I stand next to the work I\'m calling for?"'),
      DecanDayInfo(day: 18, theme: 'Shield With Strength', action: 'Use your position/voice/resources to protect someone or something more vulnerable.', reflection: '"Who needed my cover today — and did they get it?"'),
      DecanDayInfo(day: 19, theme: 'Cool With Honor', action: 'Enforce rest, shade, cooling, recovery as sacred — not laziness.', reflection: '"Do I guilt myself for needing restoration?"'),
      DecanDayInfo(day: 20, theme: 'Oath of Restraint', action: 'State, out loud, one line you will not cross with your power.', reflection: '"Where must I promise myself: \'I will not become the fire that harms what I love\'?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'A raised hand stopping a flame before it spreads',
      colorFrequency: 'Guarding shadow over controlled gold',
      mantra: '"My power will not turn against what I protect."',
    ),
  ),

  // ==========================================================
  // 🌿 REKH-WER III — DAYS 21–30  (Third Decan - msḥtjw)
  // ==========================================================

  'rekhwer_21_3': KemeticDayInfo(
    gregorianDate: 'September 6, 2025',
    kemeticDate: 'Rekh-Wer III, Day 21 (Day 21 of Rekh-Wer / Mechir)',
    season: '🌿 Peret — Emergence at full alertness',
    month: 'Rekh-Wer (rḫ-wr) — "Great Knowing," the discipline of applied understanding',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Take Inventory',
    cosmicContext: '''Day 21 is the spread-out cloth.

In Kemet, before harvest, tools were laid out and checked: sickles, baskets, cords, ledgers, jars. Any tool that failed in the field could cost food. So you didn't wait. You inspected now.

Spiritually, you do the same. You lay yourself out on the mat with honesty: your finances, sleep, promises, energy, trust circle, obligations, temper, spiritual rhythm. You ask, quietly, "What do I actually have going into the next cycle?"

Today is not romantic. Today is clarity. The worst lie is "I'm fine" when you are not.

Maʿat is never impressed by denial. Maʿat is impressed by accuracy.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Foreleg of a bull bound at the joint',
      colorFrequency: 'Earth-brown shot through with iron red',
      mantra: '"I face what I have, exactly."',
    ),
  ),

  'rekhwer_22_3': KemeticDayInfo(
    gregorianDate: 'September 7, 2025',
    kemeticDate: 'Rekh-Wer III, Day 22 (Day 22 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The Month of Great Knowing',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Name the Damage',
    cosmicContext: '''Day 22 is confession without drama.

You cannot repair what you refuse to name. You cannot strengthen what you refuse to admit is weak.

In Kemet, to lie about the condition of a harvest tool was considered dangerous, because that lie could cost the entire house food later. So truth-telling about damage was an act of loyalty.

Today you ask, "Where am I pretending I'm fine when I'm not?"

Call the fracture a fracture. Call the exhaustion exhaustion. Call the debt debt. Call the habit poison. Call the fear fear.

There is no Maʿat in pretending you are unbreakable. There is Maʿat in saying, "Yes, this is cracked," and then making sure it will not fail in the field.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Broken shaft marked with a repair line',
      colorFrequency: 'Dry clay and exposed wood grain',
      mantra: '"I tell the truth about what\'s wearing out."',
    ),
  ),

  'rekhwer_23_3': KemeticDayInfo(
    gregorianDate: 'September 8, 2025',
    kemeticDate: 'Rekh-Wer III, Day 23 (Day 23 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, applied wisdom',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Sharpen the Edge',
    cosmicContext: '''Day 23 is refinement.

A dull blade forces you to hack. Hacking ruins grain and wastes strength. A clean edge lets you cut once, cleanly, with less harm.

Spiritually: you pick one instrument in your life that must be sharp if you're going to move forward. Your body? Your skill? Your focus? Your paperwork system? Your morning discipline?

You ask, "What must be honed so I can cut cleanly instead of hacking?"

Then you sharpen it today. Not someday. Today.

Your future self depends on what you hone, not what you brag you could sharpen "when it's time."''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Whetstone against a sickle',
      colorFrequency: 'Metal flash on river-cool gray',
      mantra: '"I refine what I will depend on."',
    ),
  ),

  'rekhwer_24_3': KemeticDayInfo(
    gregorianDate: 'September 9, 2025',
    kemeticDate: 'Rekh-Wer III, Day 24 (Day 24 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Month of structured intelligence',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Repair Alignment',
    cosmicContext: '''Day 24 is bring-it-back-into-true.

Things drift. Budgets drift. Sleep drifts. Boundaries drift. Agreements drift. Your posture drifts. Your calendar drifts.

Today you select one thing and you realign it before it snaps under pressure. You tighten the loose joint. You rewrite the agreement so it's actually honest. You fix the schedule so it stops stealing from you.

You ask, "What needs realignment so it doesn't fail under pressure?"

This is quiet work. No applause. But this is the difference between "almost made it" and "made it."''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Straightened plumb line against a pillar',
      colorFrequency: 'Bone-white chalk against dark wood',
      mantra: '"I bring this back into true."',
    ),
  ),

  'rekhwer_25_3': KemeticDayInfo(
    gregorianDate: 'September 10, 2025',
    kemeticDate: 'Rekh-Wer III, Day 25 (Day 25 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, knowing how to govern force',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Yoke the Bull',
    cosmicContext: '''Day 25 is disciplined power.

This is where you point your force toward duty, not appetite.

You ask: "Is my power serving Maʿat, or just serving my appetite?"

If you have stamina, it must feed the work that protects and sustains the house. If you have voice, it must defend truth, not just win arguments. If you have presence, it must steady the room, not dominate it.

The bull is not evil. The bull is sacred. But left unyoked, it will trample seedbeds before harvest ever comes.

Your job today is to set the yoke. On yourself.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Bull\'s foreleg bound to a plow-beam',
      colorFrequency: 'Ox-blood red and work-rope tan',
      mantra: '"My strength serves, it doesn\'t crush."',
    ),
  ),

  'rekhwer_26_3': KemeticDayInfo(
    gregorianDate: 'September 11, 2025',
    kemeticDate: 'Rekh-Wer III, Day 26 (Day 26 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — "Great Knowing," now moving toward oath',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Set Obligation Clearly',
    cosmicContext: '''Day 26 is assignment.

No more "somebody should." Somebody is you. Say it.

In Kemet, obligation was not assumed — it was declared in front of witnesses and the gods, so that both honor and accountability were in place.

Today you answer, "What is mine to keep alive, no excuses?"

A child's emotional safety? A tool? A schedule? A healing routine? A partnership? A flow of money that feeds the house?

You speak it aloud. Once named, you are in covenant with it. This is how Maʿat is anchored in a household.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hand touching a storage jar',
      colorFrequency: 'Grain-gold and oath-red',
      mantra: '"This is mine to protect."',
    ),
  ),

  'rekhwer_27_3': KemeticDayInfo(
    gregorianDate: 'September 12, 2025',
    kemeticDate: 'Rekh-Wer III, Day 27 (Day 27 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Knowledge enforced by pruning',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Cut Loose the Rot',
    cosmicContext: '''Day 27 is severance.

You already took inventory. You already named damage. Now you act.

You ask, "What will sabotage the harvest if I keep feeding it?" and you cut it loose.

That can be a spending leak. A self-humiliating pattern. A person who refuses alignment. A habit that keeps dumping chaos right back into your nervous system. A fake obligation you never actually agreed to carry.

This is not cruelty. This is protection of the storehouse.

In Kemet, rot in the grain bins was not "oh well." It was death. You learned to pull it early.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Knife separating spoiled grain from clean grain',
      colorFrequency: 'Clean straw gold and discarded dark brown',
      mantra: '"I will not carry what rots my future."',
    ),
  ),

  'rekhwer_28_3': KemeticDayInfo(
    gregorianDate: 'September 13, 2025',
    kemeticDate: 'Rekh-Wer III, Day 28 (Day 28 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — The knowing that becomes vow',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Swear Continuity',
    cosmicContext: '''Day 28 is promise of steady hand.

The flood season is over. The soil is set. The tools are forming. Now comes the slow, daily tending work that actually decides whether you'll eat.

Today you choose one thing that will still receive care from you tomorrow, and next week, and next month. You say it.

You ask, "What deserves my steady hand past today?"

Then you vow, out loud: "I will continue tending this through the next phase."

This is long-term loyalty. This is how Maʿat survives boredom.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Hand on a tether line, holding steady tension',
      colorFrequency: 'Rope-sand and sunrise amber',
      mantra: '"I will keep holding this."',
    ),
  ),

  'rekhwer_29_3': KemeticDayInfo(
    gregorianDate: 'September 14, 2025',
    kemeticDate: 'Rekh-Wer III, Day 29 (Day 29 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — Great Knowing, now tested',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Submit to Measure',
    cosmicContext: '''Day 29 is accountability without flinch.

In Kemet, tallying was sacred. The count itself was a vow that nothing would "mysteriously disappear" between field and storehouse.

Today you face the truth in numbers: money in, money out; hours slept; hours wasted; tasks promised vs. tasks done; moods tracked; calories, reps, invoices, messages sent.

You ask, "Can I face the numbers without lying?"

This is where fake stories die. This is where "I'm almost there" becomes either "Yes, I'm actually almost there," or "No, I've been pretending."

Maʿat is the balance. You cannot claim Maʿat and fear measurement.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette with counting marks',
      colorFrequency: 'Ink black on papyrus gold',
      mantra: '"I let the truth be counted."',
    ),
  ),

  'rekhwer_30_3': KemeticDayInfo(
    gregorianDate: 'September 15, 2025',
    kemeticDate: 'Rekh-Wer III, Day 30 (Day 30 of Rekh-Wer / Mechir)',
    season: '🌿 Peret – Season of Emergence',
    month: 'Rekh-Wer — rḫ-wr, the month of Great Knowing',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Present Yourself to Maʿat',
    cosmicContext: '''Day 30 is presentation.

In Kemet, before a new phase, you didn't just roll forward wild. You stood, composed, equipped, and offered yourself — as you are — to service.

This was not performance. This was availability.

Today you ask, "Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"

You stand in truth: sharpened, boundaries set, rot cut, vow spoken, numbers faced.

You say — silently or out loud — "I am ready to be part of keeping balance, not just talking about balance."

This is the handover from survival to stewardship.''',
    decanFlow: [
      DecanDayInfo(day: 21, theme: 'Take Inventory', action: 'Lay out your tools, habits, alliances, money, body, promises. See them clearly.', reflection: '"What do I actually have going into the next cycle?"'),
      DecanDayInfo(day: 22, theme: 'Name the Damage', action: 'Admit what\'s cracked, dull, corroded, exhausted, dishonest, or slipping.', reflection: '"Where am I pretending I\'m fine when I\'m not?"'),
      DecanDayInfo(day: 23, theme: 'Sharpen the Edge', action: 'Restore one instrument you will need: skill, body, gear, discipline.', reflection: '"What must be honed so I can cut cleanly instead of hacking?"'),
      DecanDayInfo(day: 24, theme: 'Repair Alignment', action: 'Bring something back into true: posture, schedule, agreement, budget, boundary.', reflection: '"What needs realignment so it doesn\'t fail under pressure?"'),
      DecanDayInfo(day: 25, theme: 'Yoke the Bull', action: 'Direct raw force into service, not dominance. Channel strength toward duty.', reflection: '"Is my power serving Maʿat, or just serving my appetite?"'),
      DecanDayInfo(day: 26, theme: 'Set Obligation Clearly', action: 'State aloud what you are now responsible for maintaining.', reflection: '"What is mine to keep alive, no excuses?"'),
      DecanDayInfo(day: 27, theme: 'Cut Loose the Rot', action: 'Remove one attachment, behavior, or drain you cannot carry forward.', reflection: '"What will sabotage the harvest if I keep feeding it?"'),
      DecanDayInfo(day: 28, theme: 'Swear Continuity', action: 'Promise continuity of care: "I will continue tending this through the next phase."', reflection: '"What deserves my steady hand past today?"'),
      DecanDayInfo(day: 29, theme: 'Submit to Measure', action: 'Accept accountability. Record numbers, track progress, document truth without inflation.', reflection: '"Can I face the numbers without lying?"'),
      DecanDayInfo(day: 30, theme: 'Present Yourself to Maʿat', action: 'Stand as you are — sharpened, yoked, honest — and offer yourself as an instrument of balance going forward.', reflection: '"Am I prepared to be used in the work of order, not just praised for surviving the last cycle?"'),
    ],
    meduNeter: MeduNeterKey(
      glyph: 'Standing figure offering a foreleg to the altar',
      colorFrequency: 'Controlled iron red over balanced gold',
      mantra: '"I am ready to serve order."',
    ),
  ),

  // ==========================================================
  // ☀️ RENWET I — DAYS 1–10  (First Decan - ḫntt wꜣ)
  // ==========================================================
  'renwet_1_1': KemeticDayInfo(
    gregorianDate: 'February 13, 2026',
    kemeticDate: 'Renwet I, Day 1 (Day 1 of Renwet / Pa-Renutet)',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet (rnnt) — "The Month of Gratitude and Fate," overseen by Renenutet, She Who Nurtures into Being',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Receive the Gift',
    cosmicContext: '''Day 1 is arrival.
In Kemet this was the first open acknowledgment: "The work bore fruit. We did not starve. Renenutet remembered us." Grain, fish, beer, oil — the visible proof of survival.
To refuse to call it sacred was considered disrespect. To brag was also disrespect. The correct posture was awe.
Today you ask, "What did I just receive that I refused to call sacred because I was too used to struggle?"
This is not just money. It's rest that you finally got. It's safety. It's clarity. It's a person who stayed loyal.
You are allowed to say, "This is provision," without shame.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Cobra rearing over a basket of grain',
      colorFrequency: 'Harvest gold edged in serpent green',
      mantra: '"What arrived is holy."',
    ),
  ),

  'renwet_2_1': KemeticDayInfo(
    gregorianDate: 'February 14, 2026',
    kemeticDate: 'Renwet I, Day 2',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Sort the Blessing',
    cosmicContext: '''Day 2 is division with conscience.
In Kemet, harvest was piled, then separated: share for the laborers, share for the house, share for offering, share for storage, share for trade. No one pretended the whole pile was "mine."
Today you ask: "Can I tell the difference between mine and ours?"
This includes time. Energy. Attention. Money. Food. Praise.
To keep what belongs to the house as if it belongs only to you was considered theft against Maʿat — even if no one called you out. The goddess saw.
Sorting is not loss. Sorting is protection of relationship.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two outstretched hands dividing grain into baskets',
      colorFrequency: 'Split gold and shared earth-brown',
      mantra: '"I honor the difference between my portion and our portion."',
    ),
  ),

  'renwet_3_1': KemeticDayInfo(
    gregorianDate: 'February 15, 2026',
    kemeticDate: 'Renwet I, Day 3',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — rnnt, governed by Renenutet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Offer First Share',
    cosmicContext: '''Day 3 is first-fruits.
In Kemet the first portion of grain, oil, beer, and fish went to shrine, ancestor altar, or community need — not because the gods "demanded payment," but because you refused to pretend you did this alone.
Today you ask, "Did I honor where this came from before I kept any for myself?"
You might give food. You might send money. You might give time. You might light incense and pour water for the dead who protected you.
This act is protection. Renenutet is generous, but she is not casual. Hoarders lose favor.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Small bowl raised toward a serpent-crowned goddess',
      colorFrequency: 'Offering-white and warm amber',
      mantra: '"First, I return thanks. Then I eat."',
    ),
  ),

  'renwet_4_1': KemeticDayInfo(
    gregorianDate: 'February 16, 2026',
    kemeticDate: 'Renwet I, Day 4',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — "Gratitude and Fate"',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Feed the House',
    cosmicContext: '''Day 4 is provision to your circle.
In Kemet the household — not just blood family, but anyone under your protection — ate first in honor. You did not feast while your people were in quiet starvation. That was seen as a curse you called onto yourself.
Today you ask, "Is anyone in my circle hungry, unseen, or running on empty?"
Food counts. Money counts. Rest counts. Encouragement counts.
You cannot claim Maʿat if the people depending on you are collapsing while you post how "blessed" you are.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Open palm passing bread to another hand',
      colorFrequency: 'Warm loaf-brown and shared gold',
      mantra: '"No one under my roof starves."',
    ),
  ),

  'renwet_5_1': KemeticDayInfo(
    gregorianDate: 'February 17, 2026',
    kemeticDate: 'Renwet I, Day 5',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Record the Gain Honestly',
    cosmicContext: '''Day 5 is the ledger.
In Kemet, scribes tallied grain, oil, labor hours, and distribution. Lying on harvest records was an offense against Maʿat because it damaged trust, and trust was the spine of survival.
Today you ask, "If I vanished tomorrow, could someone read the record and know I lived in Maʿat?"
Write down what truly came in: money received, hours worked, kindness shown to you, favors owed.
This is how you stay aligned with truth instead of building a myth of yourself.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette and tally marks beside a coiled serpent',
      colorFrequency: 'Ink black on stored-grain yellow',
      mantra: '"Truth is my receipt."',
    ),
  ),

  'renwet_6_1': KemeticDayInfo(
    gregorianDate: 'February 18, 2026',
    kemeticDate: 'Renwet I, Day 6',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Pay the Hands',
    cosmicContext: '''Day 6 is honoring labor.
In Kemet, workers were paid from temple granaries. Beer. Bread. Fish. Oil. Cloth. Payment was seen as both justice and purification — it kept resentment from poisoning the house.
Today you ask, "Have I thanked the ones who lifted with me, or am I acting like I did this alone?"
This might be literal wages. It might be public credit. It might be release from a favor you've been quietly holding over someone's head.
If you prosper and pretend you carried it by yourself, fate (šai) marks you as false.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two hands exchanging a loaf and a jar',
      colorFrequency: 'Beer-amber and bread-gold',
      mantra: '"I pay what was earned."',
    ),
  ),

  'renwet_7_1': KemeticDayInfo(
    gregorianDate: 'February 19, 2026',
    kemeticDate: 'Renwet I, Day 7',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Rest the Field',
    cosmicContext: '''Day 7 is restraint.
In Kemet, you did not strip every reed, every fish, every stalk. You left edges uncut. You let the land recover. This was not softness — this was survival math.
Today you ask, "Am I harvesting — or am I draining?"
This applies to people too. Are you draining someone's patience, presence, skill, body, love, focus — just because they keep giving?
To keep tearing at a source without pause is to declare yourself more important than Maʿat. That declaration always comes back on you.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Reed bed left standing beside harvested stalks',
      colorFrequency: 'Living green beside cut gold',
      mantra: '"I will not kill the source to enjoy the moment."',
    ),
  ),

  'renwet_8_1': KemeticDayInfo(
    gregorianDate: 'February 20, 2026',
    kemeticDate: 'Renwet I, Day 8',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Speak Gratitude Aloud',
    cosmicContext: '''Day 8 is spoken thanks.
In Kemet, they didn't hide their gratitude like it was weakness. They named names. "I thank you. I saw what you did." They thanked the Nile, their elders, their workers, their gods, their own bodies for carrying them.
Today you ask, "Who needs to hear that I am grateful for them today?"
Say it out loud, in full sentences, with no sarcasm. Tell the ancestor. Tell the friend. Tell your own body. Tell Renenutet.
Ungrateful mouths were believed to poison their own fate.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Mouth-sign above offerings',
      colorFrequency: 'Warm breath-white against sunlit gold',
      mantra: '"I speak my thanks into the world so the world knows I honor it."',
    ),
  ),

  'renwet_9_1': KemeticDayInfo(
    gregorianDate: 'February 21, 2026',
    kemeticDate: 'Renwet I, Day 9',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Secure the Store',
    cosmicContext: '''Day 9 is protection without fear.
In Kemet, grain was sealed, labeled, tracked. Theft, mold, pests — all were considered insults to Renenutet, because they turned her gift into rot.
Today you ask, "Can I keep this blessing safe without becoming paranoid or stingy?"
This is where you plan, not panic. You set boundaries. You create storage. You build margin. You choose who has keys.
Guarding is not greed. Guarding is respect.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Jar sealed with a serpent mark',
      colorFrequency: 'Clay red and guarded gold',
      mantra: '"I keep what was given alive."',
    ),
  ),

  'renwet_10_1': KemeticDayInfo(
    gregorianDate: 'February 22, 2026',
    kemeticDate: 'Renwet I, Day 10',
    season: '☀️ Shemu — Harvest, distribution, responsibility',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal the Name',
    cosmicContext: '''Day 10 is declaration.
In Kemet, after the first wave of harvest distribution, festival, offering, wage, and store-guarding, there was a moment of identity: Who are you now?
Not "Who are you when starving?" You already proved that.
Who are you in abundance? Do you become generous or reckless? Loyal or arrogant? Settled or hungry for more than you need?
Today you ask, "What does Renenutet know my name to mean — and am I living like that name is true?"
You state aloud who you are committing to be with what you've been given. This is how fate is braided to behavior.''',
    decanFlow: renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Serpent whispering into a human ear',
      colorFrequency: 'Fate-deep indigo around harvest gold',
      mantra: '"I accept the name destiny gave me — and I will act like it\'s mine."',
    ),
  ),

  // ==========================================================
  // ☀️ RENWET II — DAYS 11–20  (Second Decan - ḥry-ib sbꜣ)
  // ==========================================================

  'renwet_11_2': KemeticDayInfo(
    gregorianDate: 'February 23, 2026',
    kemeticDate: 'Renwet II, Day 11 (Day 11 of Renwet / Pa-Renutet)',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet (rnnt) — month of gratitude, fate, and accountability before Renenutet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Stand in the Light',
    cosmicContext: '''Day 11 is exposure — not humiliation, exposure.
In Kemet, after the first joy of harvest, people gathered and said plainly what was done: who worked, who helped, who shared, who tried to cheat, who tried to hide. This wasn't gossip. It was cleansing.
Today you ask, "If someone watched how I handled abundance, would they call me honorable?"
This is not about perfection. It's about whether you tried to move in Maʿat, or you tried to move like no one was watching.
You let yourself be seen today. You let the light fall where you would normally keep the curtain closed.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Heart beneath a shining star',
      colorFrequency: 'White-gold on deep night blue',
      mantra: '"I do not run from the light."',
    ),
  ),

  'renwet_12_2': KemeticDayInfo(
    gregorianDate: 'February 24, 2026',
    kemeticDate: 'Renwet II, Day 12',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Weigh the Heart',
    cosmicContext: '''Day 12 is comparison between word and act.
In Kemet, truth wasn't a speech. Truth was conduct. You could praise Maʿat at dawn and still be false if, by noon, you were robbing workers or lying on grain counts.
Today you ask, "Does my heart match my mouth?"
You review what you claimed: "I'm generous," "I'm loyal," "I'm disciplined," "I don't play with people's trust," "I take care of mine."
Did you actually move like that? If not, the gap itself is what must be addressed, not hidden.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Heart on a balance scale, feather above',
      colorFrequency: 'Feather-white and oath-red',
      mantra: '"My heart and my speech must weigh the same."',
    ),
  ),

  'renwet_13_2': KemeticDayInfo(
    gregorianDate: 'February 25, 2026',
    kemeticDate: 'Renwet II, Day 13',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Confess the Excess',
    cosmicContext: '''Day 13 is confession, not performance.
In Kemet, people openly admitted, "I took more than I should," "I kept quiet when I should have spoken," "I watched someone carry the load and pretended not to see." This was not shame theater. It was maintenance of social trust.
Today you ask, "Where did I slip into greed, and why?"
You don't excuse it. You also don't self-destroy. You name it so you can correct it in Maʿat instead of letting it rot in silence.
Renenutet nourishes — but she also remembers.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Open mouth above a bowed head',
      colorFrequency: 'Ash gray and cleansing white',
      mantra: '"I won\'t let silence rot my name."',
    ),
  ),

  'renwet_14_2': KemeticDayInfo(
    gregorianDate: 'February 26, 2026',
    kemeticDate: 'Renwet II, Day 14',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Correct the Imbalance',
    cosmicContext: '''Day 14 is repair.
In Kemet, you could not claim purity by saying "my bad" and walking away. You restored what you distorted. If you shorted someone, you paid them. If you disrespected someone publicly, you lifted their name publicly.
Today you ask, "Who deserves repair from me before this cycle can be called clean?"
Maʿat is not theory. Maʿat is correction.
This is one of the holiest acts in the whole year.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Balanced scale brought level by a steadying hand',
      colorFrequency: 'Restored gold on deep, corrective red',
      mantra: '"I fix what I bent."',
    ),
  ),

  'renwet_15_2': KemeticDayInfo(
    gregorianDate: 'February 27, 2026',
    kemeticDate: 'Renwet II, Day 15',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Protect the Innocent',
    cosmicContext: '''Day 15 is guardianship.
In Kemet, harvest didn't mean safety for everyone. Children could still be vulnerable. Elders could still be overlooked. Workers could still be used up and then discarded.
Today you ask, "Who is still exposed, and why am I okay with that?"
Protection is not just threat response. It's preemptive care: food delivered before hunger hits, shelter secured before danger comes, rest enforced before collapse happens.
If you are resourced and someone close to you is still in danger, Maʿat demands you move.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched arm forming a protective curve over a seated child',
      colorFrequency: 'Guarding bronze over sanctuary blue',
      mantra: '"Under my watch, you are safe."',
    ),
  ),

  'renwet_16_2': KemeticDayInfo(
    gregorianDate: 'February 28, 2026',
    kemeticDate: 'Renwet II, Day 16',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Speak the Record Publicly',
    cosmicContext: '''Day 16 is testimony.
In Kemet, heads of households would state: "This is what came in. This is what I did. This is what I owe. This is where I failed. This is how I will correct it."
It prevented quiet corruption. It also built trust.
Today you ask, "Do the people around me know my truth, or just my performance?"
You don't have to publish online. You do have to be known by your circle in a way that keeps you honest. Secrets breed decay. Witness breeds discipline.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Mouth-sign before a gathered circle of seated figures',
      colorFrequency: 'Oath-red and witness-gold',
      mantra: '"My truth is not private corruption."',
    ),
  ),

  'renwet_17_2': KemeticDayInfo(
    gregorianDate: 'March 1, 2026',
    kemeticDate: 'Renwet II, Day 17',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Honor the Honest Worker',
    cosmicContext: '''Day 17 is lifting the deserving.
In Kemet, names were currency. To have your name spoken with respect in public was a form of immortality. So people would say, "This woman kept us fed," "This man never cheated us," "This crew stayed loyal when it was hard."
Today you ask, "Whose name deserves to shine from this harvest?"
You do not center yourself here. You elevate the hands, the support, the labor, the steadfastness that made this season possible.
This is how Maʿat remembers them.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Name-ring (cartouche form) lifted by two hands',
      colorFrequency: 'Honoring gold on reverent deep blue',
      mantra: '"I speak your name so you remain."',
    ),
  ),

  'renwet_18_2': KemeticDayInfo(
    gregorianDate: 'March 2, 2026',
    kemeticDate: 'Renwet II, Day 18',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Consecrate the Oath',
    cosmicContext: '''Day 18 is vow.
In Kemet, after confession and correction, you didn't just say "I'll do better." You fixed the words into shape: "From this day, I will not cheat the measure," "From this day, I will feed the elder first," "From this day, I will not lie on my ledger."
Today you ask, "What promise will I stake my name on?"
This is not aesthetic. This is identity. Your oath becomes part of how Maʿat knows you.
You are telling Renenutet and your own lineage: "Judge me by this."''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Raised hand making declaration before the feather of Maʿat',
      colorFrequency: 'Oath-scarlet and feather-white',
      mantra: '"By this I will be known."',
    ),
  ),

  'renwet_19_2': KemeticDayInfo(
    gregorianDate: 'March 3, 2026',
    kemeticDate: 'Renwet II, Day 19',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal Reputation',
    cosmicContext: '''Day 19 is ownership.
In Kemet, after oath came sealing. "This is who I am now," was not metaphor. It was reputation. It followed you into trade, into marriage negotiations, into temple standing, into how your children were treated.
Today you ask, "If my child repeated what I did this season, would I feel pride or shame?"
This is where you admit: I am now tied to how I used power. I am tied to how I handled food, money, trust, and labor. I don't get to pretend that didn't happen.
This is the cost — and the honor — of living in Maʿat.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A name-ring (cartouche) sealed with the feather of Maʿat',
      colorFrequency: 'Reputation gold edged with law-white',
      mantra: '"My name now carries my conduct."',
    ),
  ),

  'renwet_20_2': KemeticDayInfo(
    gregorianDate: 'March 4, 2026',
    kemeticDate: 'Renwet II, Day 20',
    season: '☀️ Shemu — Harvest under judgment',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Rest in Witness',
    cosmicContext: '''Day 20 is stillness without hiding.
In Kemet, after the communal accounting, there was rest. Not indulgence, not collapse — rest in which you let yourself be seen and did not flinch.
Today you ask, "Can I sit in quiet knowing I did not hide?"
If yes, you breathe. You eat slow. You sleep deep. You let nervous vigilance unclench.
If no, then the work is clear: return to Day 14 energy and correct imbalance.
This rest is not laziness. It is earned peace — the peace of a heart that faced the light.''',
    decanFlow: renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Seated figure at peace beneath a star',
      colorFrequency: 'Deep indigo calm with white-gold witness',
      mantra: '"The light saw me — and I did not run."',
    ),
  ),

  // ==========================================================
  // ☀️ RENWET III — DAYS 21–30  (Third Decan - rsw)
  // ==========================================================

  'renwet_21_3': KemeticDayInfo(
    gregorianDate: 'March 5, 2026',
    kemeticDate: 'Renwet III, Day 21 (Day 21 of Renwet / Pa-Renutet)',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet (rnnt) — Gratitude, Fate, Just Distribution',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Store the Harvest',
    cosmicContext: '''Day 21 is containment.
In Kemet, harvest did not end with cutting the grain. It ended with grain sealed in safety. Clay jars were cleaned, dried, marked. The good grain went high and dry; mold or rot was thrown out. This was love, not paranoia. It said, "Life will continue."
Today you ask, "Do I know what I actually have — or am I just assuming I'm fine?"
You count what's real. You secure what matters. You make sure what feeds you is protected from moisture, theft, waste, and forgetfulness.
Stored nourishment is stored future.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Closed jar sealed with a band of cord',
      colorFrequency: 'Clay brown and guarded gold',
      mantra: '"What sustained me is protected."',
    ),
  ),

  'renwet_22_3': KemeticDayInfo(
    gregorianDate: 'March 6, 2026',
    kemeticDate: 'Renwet III, Day 22',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Thank the Source',
    cosmicContext: '''Day 22 is return offering.
In Kemet, no one pretended they "did it alone." The Nile, the black silt, the hands of workers, the patience of women storing grain, the blessings of Renenutet — all were named, praised, fed first.
Today you ask, "Have I returned gratitude in a way the Source would recognize as real?"
Not words. Action. Who fed you? Feed them. Who covered you? Cover them. Who held your spirit up when you were shaking? Honor them in a way that lands.
Gratitude is not mood. Gratitude is redistribution.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two hands extending an offering bowl upward',
      colorFrequency: 'Honey gold and living earth brown',
      mantra: '"I give back to what gave to me."',
    ),
  ),

  'renwet_23_3': KemeticDayInfo(
    gregorianDate: 'March 7, 2026',
    kemeticDate: 'Renwet III, Day 23',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Bless the Tools',
    cosmicContext: '''Day 23 is reverence for what carried you.
In Kemet, they wiped blades with oil, repaired baskets, washed workcloths, stretched sore hands with scented fat. The message was clear: "You served me. I now care for you."
Today you ask, "Do I show respect to what carried the work, or do I only use and discard?"
Your tools include your own body. Your nervous system. Your voice. Your vehicle. Your laptop. Your crews.
To bless the tool is to admit you are not entitled to endless output from it.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Sickle crossed with an open palm',
      colorFrequency: 'Oiled bronze and rested umber',
      mantra: '"I honor what served me."',
    ),
  ),

  'renwet_24_3': KemeticDayInfo(
    gregorianDate: 'March 8, 2026',
    kemeticDate: 'Renwet III, Day 24',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Close the Ledger',
    cosmicContext: '''Day 24 is the final count.
In Kemet, this was when the tally was written: how much grain exists, how much fish is dried, how much beer is stored, how much debt is forgiven, how much promise remains outstanding.
Today you ask, "Is there any number I'm scared to face?"
You don't lie to yourself. You can only plan truthfully from numbers you actually looked at.
False records become future famine.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette, tally marks, sealed jar',
      colorFrequency: 'Ink black and stored grain gold',
      mantra: '"I do not lie to my future."',
    ),
  ),

  'renwet_25_3': KemeticDayInfo(
    gregorianDate: 'March 9, 2026',
    kemeticDate: 'Renwet III, Day 25',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Name the Lessons',
    cosmicContext: '''Day 25 is articulation.
In Kemet, they didn't just say "we made it." They said, "Here is how we made it, and here is what almost broke us." Those sentences became curriculum for the next cycle.
Today you ask, "What will not be repeated? What must be repeated?"
You name the habit that nearly destroyed you. You name the practice that saved you. You give them language so you can recognize them when they return.
Unspoken lessons are lost lessons.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Open papyrus scroll, rays of light touching it',
      colorFrequency: 'Teaching gold and honest clay',
      mantra: '"I name what saved me."',
    ),
  ),

  'renwet_26_3': KemeticDayInfo(
    gregorianDate: 'March 10, 2026',
    kemeticDate: 'Renwet III, Day 26',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Give Quiet Blessing Forward',
    cosmicContext: '''Day 26 is release of control disguised as blessing.
In Kemet, people spoke life into the next cycle, but they did not grab at it with fear. They would say, "May the river rise kindly," "May the children sleep in safety," "May our names remain clean," and then let it go.
Today you ask, "Can I bless what hasn't happened yet without grabbing for it?"
You are allowed to want goodness. You are not allowed to strangle it before it's born.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hand releasing a small flame upward',
      colorFrequency: 'Pale dawn gold and breath-soft rose',
      mantra: '"I bless what comes without trying to own it."',
    ),
  ),

  'renwet_27_3': KemeticDayInfo(
    gregorianDate: 'March 11, 2026',
    kemeticDate: 'Renwet III, Day 27',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Release the Burden',
    cosmicContext: '''Day 27 is de-tension.
In Kemet, this was when bodies were rubbed with oil, backs were stretched, songs were sung softly, and work chants became lullabies instead of battle rhythm. The body had been acting like every day was emergency.
Today you ask, "Am I still clenching like I'm in survival mode, even though I'm not?"
Your shoulders don't have to live up by your ears anymore. Your jaw doesn't have to be locked. Your sleep doesn't have to stay shallow and alert.
You are allowed to admit: the crisis window closed.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Bent-back figure exhaling, arms released downward',
      colorFrequency: 'Warm umber and loosening copper',
      mantra: '"My body may stop bracing now."',
    ),
  ),

  'renwet_28_3': KemeticDayInfo(
    gregorianDate: 'March 12, 2026',
    kemeticDate: 'Renwet III, Day 28',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Return to Silence',
    cosmicContext: '''Day 28 is sacred quiet.
In Kemet, silence wasn't empty. Silence was contact. You sat in the dark-before-dawn and you let yourself exist without needing to speak, defend, convince, sell, apologize, or narrate.
Today you ask, "When was the last time I let myself be silent in front of the Source and didn't fill the silence?"
Silence is how Maʿat re-enters the body after strain.
If you cannot sit in quiet, you are not healed yet — you are just distracted.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Closed mouth sign beneath a rising sun line',
      colorFrequency: 'Deep indigo and held gold',
      mantra: '"Silence is how I heal."',
    ),
  ),

  'renwet_29_3': KemeticDayInfo(
    gregorianDate: 'March 13, 2026',
    kemeticDate: 'Renwet III, Day 29',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — rnnt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Lay Down the Body',
    cosmicContext: '''Day 29 is embodied surrender.
In Kemet, there is no holiness in constant exhaustion. That's not Maʿat. That's self-violence.
Today you ask, "Do I believe rest is allowed, or do I still treat it like theft?"
You sleep early. You move slow. You eat warm, simple, nourishing food. You stop proving you deserve rest and actually rest.
Your nervous system is part of creation. You are required to keep it alive.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Reclining figure beneath a protective curve',
      colorFrequency: 'Hearth amber and night blue',
      mantra: '"Rest is lawful."',
    ),
  ),

  'renwet_30_3': KemeticDayInfo(
    gregorianDate: 'March 14, 2026',
    kemeticDate: 'Renwet III, Day 30',
    season: '☀️ Shemu — Harvest, sealing, surrender',
    month: 'Renwet — The Month of Gratitude and Fate',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Offer the Cycle Back to Time',
    cosmicContext: '''Day 30 is surrender and seal.
In Kemet, the last act of Shemu was not more work. It was consecration. The harvest was now considered "under protection," and the people stepped back. "It is in Maʿat's hands," they said.
Today you ask, "Can I end without dragging guilt, hoarding fear, or clinging to control?"
You stop squeezing this cycle. You let it be closed. You acknowledge: I gathered, I accounted, I repaired, I blessed, I rested.
Now I release.
Completion is an offering.''',
    decanFlow: renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Pair of uplifted hands releasing a sealed jar toward the rising sun line',
      colorFrequency: 'Pale dawn gold over resting earth brown',
      mantra: '"I return this cycle to Maʿat."',
    ),
  ),

  // ==========================================================
  // ☀️ HNSW I — DAYS 1–10  (First Decan - ḥry-ib wꜣ)
  // ==========================================================

  'hnsw_1_1': KemeticDayInfo(
    gregorianDate: 'March 15, 2026',
    kemeticDate: 'Hnsw I, Day 1 (Day 1 of Hnsw / Pa-Khonsu)',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw ("The Traveler") — sacred motion, dignified endurance under Ra',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Step Onto the Path',
    cosmicContext: '''Day 1 is declaration.
In Kemet, travel was not random. Caravans formed at dawn with intention stated: where they were going, why, and under whose protection. The road itself was treated like a shrine — you didn't walk onto it confused.
Today you ask, "Where am I going — and why?"
You speak your purpose aloud before you move. You enter the day like stepping onto sacred stone.
Drift is not allowed on Day 1. Drift insults the barque.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Solar barque with a heart mark at its center',
      colorFrequency: 'Dawn gold over river blue',
      mantra: '"I begin in clarity."',
    ),
  ),

  'hnsw_2_1': KemeticDayInfo(
    gregorianDate: 'March 16, 2026',
    kemeticDate: 'Hnsw I, Day 2',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Carry the Light',
    cosmicContext: '''Day 2 is presentation.
To travel in Kemet was to carry light into other houses, nomes, markets, temples. You were not only transporting goods — you were transporting presence.
Today you ask, "Does my heat nourish or dominate?"
You are allowed to be strong. You are expected to be strong. But the test of strength is whether other beings can live near it without injury.
Radiance without cruelty — that is divine travel.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Radiant disk held in two calm hands',
      colorFrequency: 'Sun gold edged with cool indigo shadow',
      mantra: '"My light nourishes, it does not scorch."',
    ),
  ),

  'hnsw_3_1': KemeticDayInfo(
    gregorianDate: 'March 17, 2026',
    kemeticDate: 'Hnsw I, Day 3',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Honor the Heat',
    cosmicContext: '''Day 3 is discipline in harshness.
The Kemite didn't curse the sun. The Kemite prepared for it — head cloths, water skins, shaded rest points, measured pace. Complaining at Ra would have sounded immature.
Today you ask, "Am I angry at conditions that are simply part of the season?"
Your job is not to resent the heat. Your job is to adapt with dignity.
Spiritual maturity means: I do not waste holy energy fighting reality.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Khepri (scarab) pushing the sun',
      colorFrequency: 'Blazing gold over baked clay red',
      mantra: '"I respect the fire and am not consumed."',
    ),
  ),

  'hnsw_4_1': KemeticDayInfo(
    gregorianDate: 'March 18, 2026',
    kemeticDate: 'Hnsw I, Day 4',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Travel Clean',
    cosmicContext: '''Day 4 is honor in motion.
In Kemet, your name traveled faster than your feet. If you lied, broke deals, insulted hosts, or spread poison, word outran you — and doors closed ahead of you.
Today you ask, "Would Maʿat be ashamed to walk beside me today?"
Your tone, your promises, your money exchanges, your gossip, your posture — all of that is part of your journey.
Movement without integrity is not sacred travel. It's looting.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Feather of Maʿat beside a traveling barque',
      colorFrequency: 'White-gold and river blue',
      mantra: '"My path is clean, so my name can move ahead of me without shame."',
    ),
  ),

  'hnsw_5_1': KemeticDayInfo(
    gregorianDate: 'March 19, 2026',
    kemeticDate: 'Hnsw I, Day 5',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Move With Offering',
    cosmicContext: '''Day 5 is reciprocity.
In Kemet, you did not arrive empty if you had anything to give. You brought fish, oil, labor, information, healing skill, a tool, a story. Arrival was contribution, not extraction.
Today you ask, "Do I enter spaces as a taker, or as a contributor?"
Your presence should lighten a room, not drain it.
To travel under Ra and refuse to nourish others is to lie about who carried you here.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hand offering bread and jar',
      colorFrequency: 'Sun-honey gold and warm ochre',
      mantra: '"Where I arrive, nourishment arrives."',
    ),
  ),

  'hnsw_6_1': KemeticDayInfo(
    gregorianDate: 'March 20, 2026',
    kemeticDate: 'Hnsw I, Day 6',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Protect the Vessel',
    cosmicContext: '''Day 6 is self-guardianship.
In Kemet, travelers tended feet, backs, joints, throat, and spirit. Water skins were checked constantly. Shade was planned. Arguments were avoided in heat. "Do not tear your vessel while you are still far from home," the elders said.
Today you ask, "Am I treating myself like cargo or like sacred transport?"
You cannot pour out your life on the road and call that devotion.
Self-neglect is not holiness. It's sabotage.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Enclosed barque with protective arc over it',
      colorFrequency: 'Shielded gold and cooled blue',
      mantra: '"My body is the sacred carrier of light."',
    ),
  ),

  'hnsw_7_1': KemeticDayInfo(
    gregorianDate: 'March 21, 2026',
    kemeticDate: 'Hnsw I, Day 7',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw — Pa-Khonsu',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Witness the Route',
    cosmicContext: '''Day 7 is awareness.
In Kemet, the road itself was teacher. Who is hungry along this route? Who is overworked? Where is corruption obvious? Where is kindness quietly keeping people alive?
Today you ask, "What is this path showing me about the world I serve?"
If you move through the world and learn nothing of its condition, you are not traveling — you're consuming scenery.
Service begins with seeing.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Eye above a winding road',
      colorFrequency: 'Watchful amber and traveled earth brown',
      mantra: '"I see what this path reveals."',
    ),
  ),

  'hnsw_8_1': KemeticDayInfo(
    gregorianDate: 'March 22, 2026',
    kemeticDate: 'Hnsw I, Day 8',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Speak the Blessing',
    cosmicContext: '''Day 8 is spoken protection.
In Kemet, before separating at crossroads, people said, "May you arrive in peace. May your load return multiplied." That was not small talk. That was spell-work in the mouth, in service of Maʿat.
Today you ask, "Do I extend protection, or do I only ask for mine?"
You are not the only one moving through heat. See someone else's labor. Send them with blessing.
Your words are allowed to build shelter.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two figures facing each other with an ankh between them',
      colorFrequency: 'Blessing gold and road-dust bronze',
      mantra: '"Your path is protected, and I say so aloud."',
    ),
  ),

  'hnsw_9_1': KemeticDayInfo(
    gregorianDate: 'March 23, 2026',
    kemeticDate: 'Hnsw I, Day 9',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Record the Day\'s Distance',
    cosmicContext: '''Day 9 is accounting-in-motion.
In Kemet, the day ended with tally: How far did we go? What did we carry? What did we earn? What did we owe? Who is expecting us now? This prevented lies — especially self-lies.
Today you ask, "What actually happened on my path today — not the story, the facts?"
You write it down, simply. No drama, no inflation, no self-punishment. Just truth.
Truth keeps you aligned for Day 10.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Papyrus scroll beside a walking staff',
      colorFrequency: 'Ink black and sun-baked linen',
      mantra: '"I tell the truth about my movement."',
    ),
  ),

  'hnsw_10_1': KemeticDayInfo(
    gregorianDate: 'March 24, 2026',
    kemeticDate: 'Hnsw I, Day 10',
    season: '☀️ Shemu — Heat, Movement, Distribution',
    month: 'Hnsw — Pa-Khonsu, Traveler',
      decanName: 'ḫntt ("The Foremost")',
      starCluster: '✨ The Foremost — movement beginning.',
    maatPrinciple: 'Lay Down Without Arrogance',
    cosmicContext: '''Day 10 is humility at sunset.
In Kemet, no one bragged to Ra about how hard they worked. You simply thanked the day for letting you cross it alive, washed the dust from your body, anointed with oil, and went quiet.
Today you ask, "Can I end today without demanding applause for surviving it?"
You close the day with gratitude, not performance. You acknowledge safe passage.
To rest without boasting is to prove you are traveling with Maʿat, not ego.''',
    decanFlow: hnswIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Setting sun cradled in a boat, head bowed',
      colorFrequency: 'Low amber and cooled violet-gold',
      mantra: '"I end in gratitude, not display."',
    ),
  ),

  // ==========================================================
  // ☀️ HNSW II — DAYS 11–20  (Second Decan - sbꜣ ḏḥwty)
  // ==========================================================

  'hnsw_11_2': KemeticDayInfo(
    gregorianDate: 'March 25, 2026',
    kemeticDate: 'Hnsw II, Day 11 (Day 11 of Hnsw / Pa-Khonsu)',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw ("The Traveler") — pilgrimage, commerce, endurance',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Name the Terms',
    cosmicContext: '''Day 11 is declaration of terms.
In Kemet, nothing serious was done in a haze. Before boats left, before donkeys were loaded, before copper was traded for grain, people spoke the agreement aloud in front of witnesses. This was protection for both sides.
Today you ask, "Have I said aloud what I am promising, or am I hiding vagueness inside the deal?"
Do not let silence become a trap you later pretend you didn't see.
If it cannot survive daylight language, it is not Maʿat.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Crescent ibis-head over a writing palette',
      colorFrequency: 'Ink black and moon-washed gold',
      mantra: '"I say what is true, before I move."',
    ),
  ),

  'hnsw_12_2': KemeticDayInfo(
    gregorianDate: 'March 26, 2026',
    kemeticDate: 'Hnsw II, Day 12',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Travel With Witness',
    cosmicContext: '''Day 12 is accountability.
In Kemet, people swore "under Maʿat" — meaning: I am acting as if I'm being watched by truth itself. That vow made exploitation spiritually dangerous.
Today you ask, "Would I repeat today's words in front of my ancestors?"
Move like the record is permanent — because it is.
Reputation was currency then. It still is now.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Eye of Maʿat above a scroll',
      colorFrequency: 'Reflective bronze and deep indigo',
      mantra: '"I move as if truth is beside me, because it is."',
    ),
  ),

  'hnsw_13_2': KemeticDayInfo(
    gregorianDate: 'March 27, 2026',
    kemeticDate: 'Hnsw II, Day 13',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Keep Measure',
    cosmicContext: '''Day 13 is resource honesty.
In Kemet, caravans that overextended — too far, too fast, too heavy — were the ones that collapsed in the open heat. Thoth teaches: count what you have, not what you pretend to have.
Today you ask, "Where am I leaking resources just to feel powerful in the moment?"
Your voice, your time, your money, your physical energy — these are not infinite.
Pride is the most expensive fuel on earth.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Balanced scales over tally marks',
      colorFrequency: 'Measured gold and disciplined clay-brown',
      mantra: '"I respect my limits. That is why I endure."',
    ),
  ),

  'hnsw_14_2': KemeticDayInfo(
    gregorianDate: 'March 28, 2026',
    kemeticDate: 'Hnsw II, Day 14',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Speak Cleanly',
    cosmicContext: '''Day 14 is truth of mouth.
Kemet understood that the tongue shapes destiny. Crooked speech bends fate away from Maʿat. When you lie "to keep peace," you are actually protecting decay.
Today you ask, "Did I warp truth today just to avoid discomfort?"
You are allowed to speak gently. You are not allowed to speak false.
Thoth records every word. Assume the record will be read.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ibis head over an open mouth with a feather at the lips',
      colorFrequency: 'Pale gold and truthful white',
      mantra: '"My mouth does not betray my spirit."',
    ),
  ),

  'hnsw_15_2': KemeticDayInfo(
    gregorianDate: 'March 29, 2026',
    kemeticDate: 'Hnsw II, Day 15',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — Pa-Khonsu',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Honor the Exchange',
    cosmicContext: '''Day 15 is fairness.
In Kemet, exploiters were not admired — they were feared and remembered. "He takes more than he gives," people would whisper, and his name would rot. Equally condemned: the one who sells himself beneath his worth.
Today you ask, "Did I cheapen myself, or did I try to cheapen someone else?"
Every trade is sacred. It's an altar between two beings.
You cannot poison the altar and expect blessing to follow.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two hands exchanging a weighed bundle beneath the feather of Maʿat',
      colorFrequency: 'Fair copper and balanced gold',
      mantra: '"What passes between us remains clean."',
    ),
  ),

  'hnsw_16_2': KemeticDayInfo(
    gregorianDate: 'March 30, 2026',
    kemeticDate: 'Hnsw II, Day 16',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Travel Under Oath',
    cosmicContext: '''Day 16 is vow-consciousness.
In Kemet, "I will do this" was not decoration. It was a seal. A spoken contract. Thoth, scribe of the gods, was believed to write it down, and later your heart would be weighed against it.
Today you ask, "Do I use language like a contract, or like smoke?"
Stop promising loosely. Stop agreeing just to calm a moment you don't want to sit in.
Your word is a living thing. Do not throw it around like broken grain.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Thoth\'s ibis head above a sealed knot / cord',
      colorFrequency: 'Oath gold and deep ink violet',
      mantra: '"My word is a bond placed in the hands of the gods."',
    ),
  ),

  'hnsw_17_2': KemeticDayInfo(
    gregorianDate: 'March 31, 2026',
    kemeticDate: 'Hnsw II, Day 17',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Protect the Quiet',
    cosmicContext: '''Day 17 is withdrawal for clarity.
The Kemite traveler knew: when the sun is highest and tempers spark, pause under shade, water the body, settle the mind. Silence was not laziness. It was survival. It kept blades in their sheaths and tongues from tearing alliances.
Today you ask, "Where in this day did my mind get to breathe?"
You cannot keep Maʿat on the road if you never step out of the noise.
Silence is maintenance.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Crescent ibis head above a shaded seated figure',
      colorFrequency: 'Cooling indigo and rest gold',
      mantra: '"My mind is allowed shade."',
    ),
  ),

  'hnsw_18_2': KemeticDayInfo(
    gregorianDate: 'April 1, 2026',
    kemeticDate: 'Hnsw II, Day 18',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Check for Poison',
    cosmicContext: '''Day 18 is vigilance.
The Kemite saying was: "Not all who walk beside you walk for you." On the road, betrayal often wore a smile. Thoth's star demanded that you look past charm and notice alignment.
Today you ask, "Who walks with me that is secretly against my balance?"
You are not paranoid for scanning motive. You are wise.
Maʿat can't grow in a field salted by envy.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ibis eye over a coiled serpent, caught before the strike',
      colorFrequency: 'Warning amber and guarded black',
      mantra: '"I see the threat before it enters my field."',
    ),
  ),

  'hnsw_19_2': KemeticDayInfo(
    gregorianDate: 'April 2, 2026',
    kemeticDate: 'Hnsw II, Day 19',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Assert the Boundary',
    cosmicContext: '''Day 19 is refusal without guilt.
In Kemet, saying "no" was not disrespectful. It was often considered an act of order: "That load is not mine to carry." "That request breaks Maʿat." "That pace will injure me." The wise traveler did not accept every burden just to look generous.
Today you ask, "Where did I accept a load that is not mine?"
You are allowed to set limits. You are required to set limits.
A boundary is not violence. It is architecture.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Raised hand before the feather of Maʿat',
      colorFrequency: 'Protective gold and refusal red',
      mantra: '"I do not carry what breaks my balance."',
    ),
  ),

  'hnsw_20_2': KemeticDayInfo(
    gregorianDate: 'April 3, 2026',
    kemeticDate: 'Hnsw II, Day 20',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'ḥry-ib ḫntt ("Heart of the Foremost")',
      starCluster: '✨ Heart of the Foremost — measured travel.',
    maatPrinciple: 'Seal the Ledger',
    cosmicContext: '''Day 20 is accounting of relationship and debt.
In Kemet, nothing was left floating. Loose obligations become rot. Silent resentment becomes poison. So before a camp slept, they clarified: what was delivered, what remains open, who stood in Maʿat, who failed it.
Today you ask, "If I vanished tonight, would someone know what I built, what I owed, and what I am owed?"
Write it. Name it. Seal it.
Clarity is protection for everyone who walks with you.''',
    decanFlow: hnswIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette and cord-wrapped seal',
      colorFrequency: 'Ledger black and oath gold',
      mantra: '"Nothing is left unclear. I close this day in truth."',
    ),
  ),

  // ==========================================================
  // ☀️ HNSW III — DAYS 21–30  (Third Decan - msḥtjw wr)
  // ==========================================================

  'hnsw_21_3': KemeticDayInfo(
    gregorianDate: 'April 4, 2026',
    kemeticDate: 'Hnsw III, Day 21 (Day 21 of Hnsw / Pa-Khonsu)',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw ("The Traveler") — the sun\'s path made human',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Ease the Pace',
    cosmicContext: '''Day 21 is deceleration by law.
In Kemet, people ended work early under this decan. Not because they were weak — because they were wise. The sun was still burning. The body had already given. To keep sprinting after the task was secure was considered arrogance against Ra.
Today you ask, "Why am I still sprinting when the road has already been won?"
Shorten the day. Walk instead of run. Speak instead of argue.
This is not laziness. This is honoring the boundary between effort and vanity.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Foreleg of the bull, lowered — strength at rest',
      colorFrequency: 'Warm earth red and cooling dusk gold',
      mantra: '"Slowing is power."',
    ),
  ),

  'hnsw_22_3': KemeticDayInfo(
    gregorianDate: 'April 5, 2026',
    kemeticDate: 'Hnsw III, Day 22',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Cool the Body',
    cosmicContext: '''Day 22 is repair of the vessel.
In Kemet, the body was not "just flesh." It was the carrier of the Ka itself. Overheating it without mercy was seen as disrespect to your own divine charge.
Today you ask, "Where is my body asking me to listen, not to push?"
Drink water like an offering. Stretch like you are untwisting rope. Bathe like you're rinsing off burned days.
You cannot carry light if you let the lamp crack.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Libation water poured over an outstretched arm',
      colorFrequency: 'Cooling blue, oil-gold at the joints',
      mantra: '"I cool the fire so I can continue."',
    ),
  ),

  'hnsw_23_3': KemeticDayInfo(
    gregorianDate: 'April 6, 2026',
    kemeticDate: 'Hnsw III, Day 23',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Redistribute the Load',
    cosmicContext: '''Day 23 is shared carrying.
In Kemet, one person trying to haul everything was not heroic — it was reckless. If you fell, the caravan stalled. So weight was transferred. Balance was adjusted. Pride was denied.
Today you ask, "What am I carrying alone that was never meant to be carried alone?"
Ask for help. Assign help. Accept help.
You dishonor the journey if you let yourself break to protect ego.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two arms lifting a single bundle together',
      colorFrequency: 'Shared copper and protective brown',
      mantra: '"We arrive as a unit."',
    ),
  ),

  'hnsw_24_3': KemeticDayInfo(
    gregorianDate: 'April 7, 2026',
    kemeticDate: 'Hnsw III, Day 24',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Guard the Core',
    cosmicContext: '''Day 24 is containment.
As caravans neared their destination, distractions multiplied — side deals, ego talk, performance for attention. The wise withdrew their energy from anything that did not serve delivery.
Today you ask, "Where do I spend effort just to be seen?"
Close the channels that drain you. Pull your focus back to what actually feeds your life and your vow.
The bull is strongest when it is not being baited.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Tied bundle at the chest / foreleg bound with cord',
      colorFrequency: 'Guarded red-brown and inner gold',
      mantra: '"My force is mine to direct."',
    ),
  ),

  'hnsw_25_3': KemeticDayInfo(
    gregorianDate: 'April 8, 2026',
    kemeticDate: 'Hnsw III, Day 25',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — Pa-Khonsu',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Honor Fatigue',
    cosmicContext: '''Day 25 is sacred tiredness.
In Kemet, to collapse after long travel was not shameful. It was proof: "I gave what I had to give." The body was praised, massaged, fed. No one mocked a laborer for needing to lie down.
Today you ask, "Can I let tiredness be holy?"
Stop apologizing for being worn. Stop pretending you are inexhaustible. That lie is not Maʿat.
Rest in daylight. You are allowed.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Reclining bull beneath a protective sun disk',
      colorFrequency: 'Warm ochre and soot-soft shadow',
      mantra: '"My rest is an offering."',
    ),
  ),

  'hnsw_26_3': KemeticDayInfo(
    gregorianDate: 'April 9, 2026',
    kemeticDate: 'Hnsw III, Day 26',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Release the Excess',
    cosmicContext: '''Day 26 is shedding.
In Kemet, to hoard what was spoiled was madness. You dropped it in the desert and didn't look back. Emotionally, spiritually, socially — same law.
Today you ask, "What will not travel with me into the next cycle?"
Name it. Lay it down. Do not take it forward out of habit.
Maʿat is not sentimental about decay.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Open hand releasing a knotted cord onto the ground',
      colorFrequency: 'Desert bronze and liberated white',
      mantra: '"I do not carry rot forward."',
    ),
  ),

  'hnsw_27_3': KemeticDayInfo(
    gregorianDate: 'April 10, 2026',
    kemeticDate: 'Hnsw III, Day 27',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Enter Stillness',
    cosmicContext: '''Day 27 is nervous-system surrender.
In Kemet, stillness wasn't "doing nothing." Stillness was lowering back into yourself after long, bright strain. Evening sitting — oil lamp, quiet body, eyes half-closed — was medicine.
Today you ask, "Have I given my spirit true silence before I re-enter the world?"
Shorten your speech. Move gently. Sit in dusk without filling it with noise.
You are landing. Let yourself land.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Seated figure in profile, hands resting on knees, sun low behind',
      colorFrequency: 'Dusk violet and banked ember gold',
      mantra: '"I allow my flame to settle."',
    ),
  ),

  'hnsw_28_3': KemeticDayInfo(
    gregorianDate: 'April 11, 2026',
    kemeticDate: 'Hnsw III, Day 28',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Give Thanks for Distance Traveled',
    cosmicContext: '''Day 28 is witness of distance.
In Kemet, gratitude wasn't vague. It was documented. "On this day we left. On this day we almost failed. On this day we were carried." That record made the labor sacred and kept arrogance from rewriting memory.
Today you ask, "If I met myself from the beginning of this path, what would I tell them I learned?"
Say it. Write it. Give thanks to every force that kept you moving.
You did not arrive alone.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette beside a path curling like the Nile',
      colorFrequency: 'River blue and ink black',
      mantra: '"I remember how far I have come."',
    ),
  ),

  'hnsw_29_3': KemeticDayInfo(
    gregorianDate: 'April 12, 2026',
    kemeticDate: 'Hnsw III, Day 29',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Return to Center / Come Home',
    cosmicContext: '''Day 29 is re-entry.
In Kemet, coming home was ritual, not casual. People bathed, anointed, touched doorway lintels with forehead and hands, whispered prayers of thanks to the household spirits, and re-gifted a portion of what they brought back.
Today you ask, "To whom — or to what law — do I ultimately belong?"
Touch your altar. Pour water. Name the force you answer to.
You are not just a traveler. You are a vessel of a lineage.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'House-sign with an ankh at the doorway',
      colorFrequency: 'Hearth gold and earth red',
      mantra: '"I return what I am to where I come from."',
    ),
  ),

  'hnsw_30_3': KemeticDayInfo(
    gregorianDate: 'April 13, 2026',
    kemeticDate: 'Hnsw III, Day 30',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Hnsw — The Traveler\'s Month',
      decanName: 'sbꜣ ḫntt ("Star of the Foremost")',
      starCluster: '✨ Star of the Foremost — endurance established.',
    maatPrinciple: 'Offer the Report to Ra',
    cosmicContext: '''Day 30 is testimony.
In Kemet, you did not just arrive and fall asleep. You stood, even tired, and made formal report. "Here is what we did in your light. Here is what we upheld. Here is what we refused." That act sealed the journey clean.
Today you ask, "If Ra asked, 'How did you travel in my light?,' what would I truthfully answer?"
Speak it aloud, even if alone.
You close Hnsw not by vanishing into rest, but by placing the journey in Maʿat and saying: It is complete.''',
    decanFlow: hnswIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Solar disk carried on upraised hands beside a scribe palette',
      colorFrequency: 'Final-sun gold and ink-true black',
      mantra: '"I returned in truth."',
    ),
  ),

  // ==========================================================
  // ☀️ ḤENTI-ḤET I — DAYS 1–10  (First Decan - sbꜣ ḥrw)
  // ==========================================================

  'henti_1_1': KemeticDayInfo(
    gregorianDate: 'December 6, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 1 (Day 1 of Ḥenti-ḥet / Pa-en-Ḥenti-ḥet)',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings") — peace through giving back what you were given',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Rise Before the Heat',
    cosmicContext: '''Day 1 is first light discipline.
In Kemet, people woke before sunrise in this period, not to "get ahead," but to greet Ra with a clean face, oiled skin, and intention. The first hours belonged to Maʿat. The late hours belonged to danger.
Today you ask, "Did I greet the day as a keeper, or stumble into it as a beggar?"
Your job is to meet the day with clarity, not desperation. You rise early to set tone, to align breath, to claim calm before the sun claims you.
This is ritual obedience to balance.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Falcon eye over the horizon line',
      colorFrequency: 'Pale dawn gold and protective kohl black',
      mantra: '"I meet the sun awake."',
    ),
  ),

  'henti_2_1': KemeticDayInfo(
    gregorianDate: 'December 7, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 2',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet — "Foremost of Offerings"',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Work Clean, Work Brief',
    cosmicContext: '''Day 2 is essential labor only.
In Kemet, wandering, bragging, over-doing in midday heat was seen as foolishness, not strength. The wise finished what actually mattered early, then withdrew.
Today you ask, "How much of what I call 'work' is actually noise?"
Cut the performance-work. Cut the ego-work. Do the task that feeds life, then stop.
Efficiency is not greed here. It's reverence. You refuse to waste your life-force just to appear tireless.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Falcon standing with one raised talon — poised, not wasting motion',
      colorFrequency: 'Sunlit bronze against deep shadow',
      mantra: '"My effort is precise, not frantic."',
    ),
  ),

  'henti_3_1': KemeticDayInfo(
    gregorianDate: 'December 8, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 3',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Guard the Breath',
    cosmicContext: '''Day 3 is thermal control of the mouth and lungs.
In Kemet, to let anger spill during the blazing hours was seen as a type of fire-worship — feeding Sekhmet's rage instead of cooling it.
Today you ask, "Did my mouth pour fire or water?"
Slow the inhale. Lengthen the exhale. Lower your voice. Refuse to snap just because the world feels hot.
Breath is how you choose whether you protect Maʿat or rupture it.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Curved breath-line before the falcon\'s beak',
      colorFrequency: 'Cool blue at the throat, steady gold at the chest',
      mantra: '"My breath keeps Maʿat."',
    ),
  ),

  'henti_4_1': KemeticDayInfo(
    gregorianDate: 'December 9, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 4',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Offer Back the Excess Heat',
    cosmicContext: '''Day 4 is surrender of the overheat.
The Kemite did not pretend to be above rage, panic, hunger for control. They knew heat rises in the chest. Instead of letting it scorch the village, they offered it up — to Ra, to the altar, to running water.
Today you ask, "What in me is running too hot for balance?"
Name it. Give it back. Say aloud: "This is not mine to carry into the evening."
That act is not weakness. It is priesthood.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Vessel poured out before the sun disk',
      colorFrequency: 'Blood-red fading into soft amber',
      mantra: '"I return the fire before it burns the world."',
    ),
  ),

  'henti_5_1': KemeticDayInfo(
    gregorianDate: 'December 10, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 5',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Honor Proportion',
    cosmicContext: '''Day 5 is righteous ration.
To the Kemite, greed was a form of heat — a swelling, grasping impulse that violates Maʿat. In this period, families practiced measured consumption, not out of fear, but out of deep trust: "What we have is enough."
Today you ask, "Am I consuming for need, or out of fear?"
Eat what steadies, not what numbs. Spend what is proper, not what shouts.
Proportion is worship. You prove trust in Ra by not clawing for more.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Balanced offering table with equal loaves',
      colorFrequency: 'Pale bread-gold and calm clay brown',
      mantra: '"Enough is holy."',
    ),
  ),

  'henti_6_1': KemeticDayInfo(
    gregorianDate: 'December 11, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 6',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet — "Foremost of Offerings"',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Shade the Vulnerable',
    cosmicContext: '''Day 6 is protection-as-offering.
In Kemet, during the fiercest sun, elders and children were physically shaded with cloth and palm leaves. Water was pressed into their hands first. Not charity — law.
Today you ask, "Whose suffering did I cool today?"
Check on the exhausted. Feed the overwhelmed. Intervene gently where someone is burning out.
To walk through this day and offer no shade is to fail Ḥenti-ḥet.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched shade-fan over a seated figure',
      colorFrequency: 'Palm green and protective bronze',
      mantra: '"My strength is a shelter, not a blade."',
    ),
  ),

  'henti_7_1': KemeticDayInfo(
    gregorianDate: 'December 12, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 7',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Keep the Record',
    cosmicContext: '''Day 7 is clean accounting.
In Kemet, ledgers were a form of prayer. "What has been given. What has been spent. What remains." You cannot offer rightly if you do not know what you hold.
Today you ask, "Can I name what I owe, what I've received, and what I returned?"
Write it. Say it. Bring your exchanges into clarity.
Maʿat hates vague debt. Maʿat loves honest balance.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette beside three measured jars',
      colorFrequency: 'Ink black and storage-clay orange',
      mantra: '"Clarity is peace."',
    ),
  ),

  'henti_8_1': KemeticDayInfo(
    gregorianDate: 'December 13, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 8',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet — "Foremost of Offerings"',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Cool the Eye',
    cosmicContext: '''Day 8 is deliberate gentleness in the face of heat.
In the myths, Sekhmet's fury is only calmed when her hunger for blood is redirected into sweetness and rest. Humans mirrored this by softening their own confrontations.
Today you ask, "Did I calm the Eye, or did I feed it?"
Choose softness where wrath expects itself. Offer ease where conflict wants spectacle.
Cooling rage is not surrender. It is world-preservation.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Wadjet eye with a cooling water line beneath it',
      colorFrequency: 'Protective kohl black and healing blue-green',
      mantra: '"I turn wrath into mercy."',
    ),
  ),

  'henti_9_1': KemeticDayInfo(
    gregorianDate: 'December 14, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 9',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Speak Soft to the Body',
    cosmicContext: '''Day 9 is tenderness toward flesh.
In Kemet, oiling the skin, washing the dust, sitting in shade, drinking cool water, slowing the pulse — these were not luxuries. They were maintenance of the divine charge you carry.
Today you ask, "Did I keep the vessel worthy of the Ka?"
Soothe joints. Loosen jaw. Stretch spine. Refuse self-harm disguised as duty.
You cannot offer yourself back to Maʿat shattered and call that devotion.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ankh held gently to the lips',
      colorFrequency: 'Milk-white and softened gold',
      mantra: '"My body is sacred equipment."',
    ),
  ),

  'henti_10_1': KemeticDayInfo(
    gregorianDate: 'December 15, 2025',
    kemeticDate: 'Ḥenti-ḥet I, Day 10',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet — "Foremost of Offerings," peace by returning what is not yours to keep',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal the Morning Oath',
    cosmicContext: '''Day 10 is vow-setting.
In the villages, this marked the formal close of the first decan: you declare who you intend to be under pressure for the rest of Ḥenti-ḥet. You speak it aloud so you can be held to it.
Today you ask, "When the sun tests me, what do I refuse to become?"
Say it. Claim it. Bind yourself to it.
Maʿat is not an idea. Maʿat is an oath you walk in public heat.''',
    decanFlow: hentiHetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'The falcon of Horus standing before the sun disk with a vow-hand (palm forward) raised',
      colorFrequency: 'Dawn gold and oath-black',
      mantra: '"My heat serves Maʿat, not chaos."',
    ),
  ),

  // ==========================================================
  // ☀️ ḤENTI-ḤET II — DAYS 11–20  (Second Decan - ḥry-ib ḫꜣ)
  // ==========================================================

  'henti_11_2': KemeticDayInfo(
    gregorianDate: 'December 16, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 11',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings") — peace through giving back and cooling excess',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Name the Fire',
    cosmicContext: '''Day 11 is confession of heat.
In this phase, the Kemite did not pretend to be calm. Rage, jealousy, craving, panic — all of it was spoken aloud in offering halls the way oil or incense was offered. Because unnamed heat turns to violence.
Today you ask, "What is the true heat in me right now?"
Do not decorate it. Do not justify it. Just name it in clear speech.
This is how you keep Sekhmet from walking through your body and tearing your house apart.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Solar disk with flaring uraeus at the brow',
      colorFrequency: 'Blood-red edged in disciplined gold',
      mantra: '"I will not lie about my fire."',
    ),
  ),

  'henti_12_2': KemeticDayInfo(
    gregorianDate: 'December 17, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 12',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Purify the Intention',
    cosmicContext: '''Day 12 is alignment of motive.
The Kemite knew: raw force becomes holy only when its aim is pure. Sekhmet becomes healer when her rage defends the innocent, not her pride.
Today you ask, "Does my will build life or just prove I'm powerful?"
Choose what your fire serves. Set its direction.
Unaimed heat burns everyone. Aimed heat becomes protection.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Sekhmet\'s lioness head crowned with the sun disk and uraeus',
      colorFrequency: 'Ember orange fading into lotus-white smoke',
      mantra: '"My power moves for Maʿat, not for ego."',
    ),
  ),

  'henti_13_2': KemeticDayInfo(
    gregorianDate: 'December 18, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 13',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Sweeten the Flame',
    cosmicContext: '''Day 13 is cooling ritual.
When you are about to scorch someone, you choose instead to bless them. Not because they "deserve it," but because you refuse to turn yourself into a weapon. This is Sekhmet drinking the red beer and softening.
Today you ask, "How did I soften something today that could have scorched?"
You pour water on the coals while they are still glowing, not after the house catches fire.
That is devotion.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Incense cone steaming over an altar',
      colorFrequency: 'Resin gold and cooled rose smoke',
      mantra: '"I turn fury into medicine."',
    ),
  ),

  'henti_14_2': KemeticDayInfo(
    gregorianDate: 'December 19, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 14',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Repair Harm Done in Heat',
    cosmicContext: '''Day 14 is restoration work.
In Kemet, when someone lashed out in anger during Shemu, it wasn't shrugged off as "that's just how I am." They were expected to repair it: apology, physical help, food, shade, resource. Balance restored in the same sun that witnessed the harm.
Today you ask, "Where did my heat injure someone who trusted me?"
You fix it. Directly. Tangibly. Quickly.
This is not guilt. This is sacred maintenance.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hands returning an object, palm-up',
      colorFrequency: 'Burnished copper turning to soft clay',
      mantra: '"I restore what my heat disturbed."',
    ),
  ),

  'henti_15_2': KemeticDayInfo(
    gregorianDate: 'December 20, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 15',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Speak Under Oath',
    cosmicContext: '''Day 15 is oath-speech.
The Kemite viewed the tongue as an instrument of Maʿat. Words were not casual, because once spoken, they entered the record of your heart. This is why confessions in the Hall of Maʿat begin with "I have not…" — every word counts.
Today you ask, "Would I repeat these words in front of the scales?"
No idle curses. No false promises. No boiling gossip disguised as "truth."
You speak only what you'll defend when you're weighed.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Feather of Maʿat beside a speaking mouth',
      colorFrequency: 'White feather over deep red',
      mantra: '"My words are already being weighed."',
    ),
  ),

  'henti_16_2': KemeticDayInfo(
    gregorianDate: 'December 21, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 16',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Burn Away the Rot',
    cosmicContext: '''Day 16 is severance.
You identify what cannot continue with you — a habit that keeps you weak, a loyalty that drains you, an object carrying sick memory, a substance that dirties clarity. And you release it. Fully.
Today you ask, "What must not cross into the next season with me?"
This is fire in its rightful place: destroying decay so the rest survives.
If you keep the rot, you defy Maʿat. If you burn it, you honor her.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Flame over a discarded snake-skin',
      colorFrequency: 'Charred black and rebirth gold',
      mantra: '"I refuse to carry rot forward."',
    ),
  ),

  'henti_17_2': KemeticDayInfo(
    gregorianDate: 'December 22, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 17',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Consecrate the Body',
    cosmicContext: '''Day 17 is presentation of self as sacred instrument.
The workers of Kemet would oil their skin, wash dust from their limbs, braid or wrap their hair, apply perfumed fat to the neck — not vanity, but consecration. The body was temple hardware.
Today you ask, "Do I carry myself like temple equipment, or like scrap?"
Clean yourself. Anoint yourself. Dress with intention.
You are not debris. You are carried light.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Lioness head above an ankh resting on the chest',
      colorFrequency: 'Sunlit amber and living red',
      mantra: '"My body is not frantic — it is consecrated."',
    ),
  ),

  'henti_18_2': KemeticDayInfo(
    gregorianDate: 'December 23, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 18',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Offer Heat as Service',
    cosmicContext: '''Day 18 is holy exertion.
In Kemet, the strongest took the heaviest loads during this phase, not to boast but to spare the worn. Hauling jars of water, lifting grain sacks, reinforcing shade structures — this was worship.
Today you ask, "Who received my strength today besides me?"
You give your power in a way that lightens another's suffering.
Heat is justified when it shelters the vulnerable.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Muscled arm offering a jar of water to another figure',
      colorFrequency: 'Sun-bleached linen and river blue',
      mantra: '"My strength exists to protect, not to dominate."',
    ),
  ),

  'henti_19_2': KemeticDayInfo(
    gregorianDate: 'December 24, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 19',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Hold Still in the Blaze',
    cosmicContext: '''Day 19 is unshakenness.
In Kemet, trials came hottest in Shemu — shortages, tempers, exhaustion. To erupt was normal. To remain steady was divine. The disciplined heart was considered proof of alignment with Maʿat.
Today you ask, "When I was tested, did I hold form?"
Do not erupt just because eruption is available. Hold your shape. Keep your oath from Day 15.
Calm is not passivity. Calm is rulership.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Seated lioness, still, with tail wrapped calm around forepaws',
      colorFrequency: 'Deep sun-red over grounded brown',
      mantra: '"My stillness is protection, not weakness."',
    ),
  ),

  'henti_20_2': KemeticDayInfo(
    gregorianDate: 'December 25, 2025',
    kemeticDate: 'Ḥenti-ḥet II, Day 20',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal the Flame in Devotion',
    cosmicContext: '''Day 20 is consecration of power.
This is when you declare, out loud, what your strength is for. You state who your fire answers to. After this point, you no longer get to say "I couldn't help it." You chose. You aligned. You bound your will.
Today you ask, "Who does my power answer to?"
Say it. Bind it.
In Kemet, that moment separated destroyers from protectors.''',
    decanFlow: hentiHetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Sun disk held gently between two open hands instead of clenched fists',
      colorFrequency: 'Disciplined gold over cooled red',
      mantra: '"My fire is sworn to Maʿat."',
    ),
  ),

  // ==========================================================
  // ☀️ ḤENTI-ḤET III — DAYS 21–30  (Third Decan - msḥtjw nfr)
  // ==========================================================

  'henti_21_3': KemeticDayInfo(
    gregorianDate: 'December 26, 2025',
    kemeticDate: 'Ḥenti-ḥet III, Day 21',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings") — to give back is to create peace',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Stand Down the Body',
    cosmicContext: '''Day 21 is surrender of strain.
By this point in Shemu, backs are tight, hands are split, sleep is thin. In Kemet, this was not denied — it was honored. People stopped pretending to be invincible. You do not insult the body that carried you through the heat by demanding silence from it at the end.
Today you ask, "Where am I still pretending I'm not tired?"
Let yourself unclench. Stretch. Breathe slow. Admit that you need recovery.
This is not quitting. This is intelligent survival under Ra.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Bent foreleg of a bull laid calmly on an altar, not in struggle',
      colorFrequency: 'Sun-browned leather and cooled earth',
      mantra: '"I am allowed to rest."',
    ),
  ),

  'henti_22_3': KemeticDayInfo(
    gregorianDate: 'December 27, 2025',
    kemeticDate: 'Ḥenti-ḥet III, Day 22',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Secure the Storehouse',
    cosmicContext: '''Day 22 is stewardship.
In Kemet, grain was counted, sealed, and blessed. Oil jars were checked. Tools were gathered from the field so none would be lost to thieves or weather. This was not greed; this was honoring what the Nile and your own sweat made possible.
Today you ask, "Have I honored what I asked the world to give me?"
Organize your resources. Don't let what you worked for spoil through neglect.
Care is devotion.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Sealed granary with watching cobra at the door',
      colorFrequency: 'Clay jar red and guarded gold',
      mantra: '"I protect what sustains life."',
    ),
  ),

  'henti_23_3': KemeticDayInfo(
    gregorianDate: 'December 28, 2025',
    kemeticDate: 'Ḥenti-ḥet III, Day 23',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Sharpen and Mend',
    cosmicContext: '''Day 23 is maintenance.
Blades were sharpened. Handles were repaired. Nets were untangled and hung to dry. Work areas were swept and cleared. Why? Because tools left neglected decay, and decay invites disorder.
Today you ask, "Will Future Me inherit tools in dignity, or in chaos?"
Clean your instruments. Tighten what's loose. Prepare your station so that tomorrow's you steps into readiness, not rubble.
This is love across time.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Stone blade being honed against a whetstone',
      colorFrequency: 'Iron grey and disciplined white',
      mantra: '"I leave no chaos for my future self."',
    ),
  ),

  'henti_24_3': KemeticDayInfo(
    gregorianDate: 'December 29, 2025',
    kemeticDate: 'Ḥenti-ḥet III, Day 24',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Release the Burden',
    cosmicContext: '''Day 24 is surrender of false weight.
In Kemet, pride made people hold too much for too long. The wise knew when to hand tasks off, pause a route, or say "this is no longer mine." That was not weakness. That was obedience to Maʿat.
Today you ask, "What weight am I carrying just so no one thinks I'm weak?"
Set it down. Give it back. Reassign it. Let it go.
Carrying past purpose is disobedience, not loyalty.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Load sliding from the back of a kneeling figure, hands open',
      colorFrequency: 'Dust-brown falling into soft shadow',
      mantra: '"What is no longer mine, I release."',
    ),
  ),

  'henti_25_3': KemeticDayInfo(
    gregorianDate: 'December 30, 2025',
    kemeticDate: 'Ḥenti-ḥet III, Day 25',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Honor the Body as Survivor',
    cosmicContext: '''Day 25 is reverence for the vessel.
This is where you tend bruises without judging yourself for having them. You oil joints. You eat slow, mineral-rich food. You drink deeply. You cool swollen places. In Kemet, this tending was ceremonial — survival was praised, not ignored.
Today you ask, "Do I treat my own body like a worker I value?"
If not, correct it. Your flesh is not disposable equipment. It is sanctified instrument.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ankh held over a reclining figure',
      colorFrequency: 'Soft amber and cooling blue',
      mantra: '"My survival is sacred and must be maintained."',
    ),
  ),

  'henti_26_3': KemeticDayInfo(
    gregorianDate: 'December 31, 2025',
    kemeticDate: 'Ḥenti-ḥet III, Day 26',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Speak Gratitude to the Source',
    cosmicContext: '''Day 26 is public gratitude.
Not silent "I appreciate it." Spoken. Witnessed. Named. In Kemet, people thanked those who carried water, those who cooked, those who watched children during the hottest days, those who held shade over the elders.
Today you ask, "Did I act like I did this alone?"
Call names. Give honor. Let those who labored beside you hear your voice blessing them.
This is wealth.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Libation jar pouring onto the earth',
      colorFrequency: 'Gold pouring into dark ochre soil',
      mantra: '"I name the hands that carried me."',
    ),
  ),

  'henti_27_3': KemeticDayInfo(
    gregorianDate: 'January 1, 2026',
    kemeticDate: 'Ḥenti-ḥet III, Day 27',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Record the Season',
    cosmicContext: '''Day 27 is witness.
If there is no record, chaos can rewrite the story. Kemet knew that. So they documented: who helped, what failed, what survived, what must change next cycle. This wasn't vanity — it was protection from false memory.
Today you ask, "If I vanished, would the record show that I served balance?"
Write it. Archive it. Put your restoration on record so Maʿat can point to it.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe palette and reed pen beside a coiled rope (measured order)',
      colorFrequency: 'Ink black and orderly tan',
      mantra: '"I leave Maʿat a clear account."',
    ),
  ),

  'henti_28_3': KemeticDayInfo(
    gregorianDate: 'January 2, 2026',
    kemeticDate: 'Ḥenti-ḥet III, Day 28',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Establish Boundary for Rest',
    cosmicContext: '''Day 28 is lawful rest.
In Kemet, there were days when work simply stopped. Not laziness — protection of the body and protection of the order they had just rebuilt. You were not allowed to be endlessly extracted.
Today you ask, "Have I granted myself lawful rest?"
State it. Out loud. "I am not available for more today."
Whoever disrespects that boundary is asking you to betray Maʿat. You do not.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Bull lying down inside an enclosure line',
      colorFrequency: 'Bone white edged in protective dark brown',
      mantra: '"My rest is righteous and non-negotiable."',
    ),
  ),

  'henti_29_3': KemeticDayInfo(
    gregorianDate: 'January 3, 2026',
    kemeticDate: 'Ḥenti-ḥet III, Day 29',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet ("Foremost of Offerings")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Return Excess',
    cosmicContext: '''Day 29 is circulation.
The Kemite knew that stored abundance rots if it does not move. So the last days of Ḥenti-ḥet were for giving back what you could spare — food to the hungry, tools on loan, knowledge handed down. This kept the whole community in Maʿat.
Today you ask, "What am I keeping that should be circulating?"
Give it. Quietly if you like. Publicly if it teaches.
You are not draining yourself. You are preventing sacred resource from dying in a dark corner.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Open hand extending grain',
      colorFrequency: 'Harvest gold on palm-brown',
      mantra: '"Nothing dies in my hoarding. I keep the flow alive."',
    ),
  ),

  'henti_30_3': KemeticDayInfo(
    gregorianDate: 'January 4, 2026',
    kemeticDate: 'Ḥenti-ḥet III, Day 30',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ḥenti-ḥet',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal the Offering',
    cosmicContext: '''Day 30 is closure in reverence.
This is where you say: "It was enough." Not "it should've been more." Not "next time I'll be perfect." Enough.
In Kemet, a final gesture was made: water poured to the ground, bread set aside, incense burned, forehead touched to earth. The month ended not in grasping, but in quiet thankfulness.
Today you ask, "Have I ended this cycle in gratitude, not in hunger?"
Make one deliberate offering — an object, a vow, an action of service — that seals this phase.
You close the month the way a priest closes the shrine: with dignity.''',
    decanFlow: hentiHetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Foreleg laid on an offering table beside a libation jar',
      colorFrequency: 'Quiet bronze and altar-white',
      mantra: '"I end in gratitude, not in hunger."',
    ),
  ),

  // ==========================================================
  // ☀️ IPT-ḤMT I — DAYS 1–10  (First Decan - ꜥḥꜣy)
  // ==========================================================

  'ipt_1_1': KemeticDayInfo(
    gregorianDate: 'April 14, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 1',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together / Union") — reunion of living and ancestral lines, renewal through remembrance',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Call the Lineage',
    cosmicContext: '''Day 1 is invocation.
In Kemet, when ꜥḥꜣy began to rise, families went to the tomb chapels and spoke the names of their dead aloud, starting with the most recent and walking backward as far as memory could reach. It was understood that silence kills: a forgotten name is a starving Ka.
Today you ask, "Whose strength is still moving in me?"
Say their names. Parents, grandparents, blood-relations, chosen kin, teachers, the one who fed you when no one else did. Speak them into the air like you're lighting lamps in a dark hallway.
You are not alone. You never were.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched arms calling to a seated ancestor spirit (Ka arms raised)',
      colorFrequency: 'Deep indigo with warm ember-gold at the edges',
      mantra: '"I call you. Stand with me."',
    ),
  ),

  'ipt_2_1': KemeticDayInfo(
    gregorianDate: 'April 15, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 2',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Clean the Shrine / Clean the Room',
    cosmicContext: '''Day 2 is purification of memory.
Kemites scrubbed ancestor stelae, brushed sand from carved names, refreshed flowers, re-wrapped jars. Even in poor homes with no carved tomb, they would wipe and straighten a simple corner of the house where keepsakes lived. Neglect was considered an insult to the line itself.
Today you ask, "Do I keep my ancestors in neglect or in honor?"
Wipe dust from photos. Clean the shelf where their objects live. Straighten what is crooked.
You are not decorating. You are restoring dignity to your blood.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Water jar pouring over an inscribed name',
      colorFrequency: 'Cool clay-grey and cleansing water blue',
      mantra: '"I keep your place clean."',
    ),
  ),

  'ipt_3_1': KemeticDayInfo(
    gregorianDate: 'April 16, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 3',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Reunion")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Offer Sustenance',
    cosmicContext: '''Day 3 is feeding the unseen.
In Kemet, water was poured, bread was placed, beer was set out, incense was burned — all given to sustain the Ka of the dead and to link them lovingly to the living. The belief: if you feed them, they feed you. If you starve them, your own path weakens.
Today you ask, "Have I thanked the force that is quietly feeding me?"
Pour clean water in their honor. Light a candle. Hum a song that belongs to the elders. Even one slow breath, offered on purpose, counts.
This is worship through loyalty.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Offering table with bread and water jars before a Ka-sign figure',
      colorFrequency: 'Bread-gold and incense smoke white',
      mantra: '"I feed you; feed me in return."',
    ),
  ),

  'ipt_4_1': KemeticDayInfo(
    gregorianDate: 'April 17, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 4',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Listen for Instruction',
    cosmicContext: '''Day 4 is counsel.
After feeding the Ka, the Kemite did not rush away. They sat in stillness. Eyes lowered. Breath even. Waiting. It was understood that the ancestors still advise — especially on matters of protection, resource, and dignity.
Today you ask, "What are they telling me to correct while I still can?"
Sit. Be quiet on purpose. Let a single directive surface. Do not argue with it.
Guidance from those who survived before you is not theory. It is field-tested law.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Seated ancestor figure with one hand raised in speech and one hand over the heart',
      colorFrequency: 'Night blue and ember red at the mouth',
      mantra: '"I receive your instruction."',
    ),
  ),

  'ipt_5_1': KemeticDayInfo(
    gregorianDate: 'April 18, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 5',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together of the Women / Union of Forces")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Repair the Story',
    cosmicContext: '''Day 5 is truth-telling.
Kemet did not worship a fake past. Honesty itself was Maʿat. On this day, families spoke aloud what really happened — struggle, betrayal, abuse, sacrifice, escape, cleverness, survival. Because if the story stays broken, the line stays poisoned.
Today you ask, "Which silence in my family is killing us?"
Name it. Calmly. Without theater. Without blaming the dead. You are not reopening a wound to bleed; you are cleaning it to close.
This is how you stop inheritance of rot.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Broken papyrus scroll being re-tied with cord',
      colorFrequency: 'Raw clay red with threads of white linen',
      mantra: '"I tell the truth so we can heal."',
    ),
  ),

  'ipt_6_1': KemeticDayInfo(
    gregorianDate: 'April 19, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 6',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Carry Forward a Virtue',
    cosmicContext: '''Day 6 is skill and character inheritance.
The Kemite did not worship ancestors just to worship them. The point was: take what was excellent in them and keep it alive. Fierce honesty. Craftsmanship. Relentless tenderness. Refusal to bow to injustice. Ability to make food stretch. Laughter under pressure.
Today you ask, "What gift of theirs will I keep alive today on purpose?"
Choose one trait from a specific ancestor and live it consciously for the next 24 hours. That is resurrection in practice.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Hand passing an ankh to another hand',
      colorFrequency: 'Warm gold traveling into living flesh tones',
      mantra: '"Your strength moves through me today."',
    ),
  ),

  'ipt_7_1': KemeticDayInfo(
    gregorianDate: 'April 20, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 7',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Reunion of lines")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Reaffirm Your Place',
    cosmicContext: '''Day 7 is declaration.
In Kemet, identity was not "I am myself." Identity was "I am of this house, of this river, of this Name." You announced out loud that you were not rootless. That you came from a current of survival, skill, and favor.
Today you ask, "Do I live like an isolated self or as a continuation?"
Say: "I am carried. I am not here alone. I am one link in an unbroken chain and I accept that responsibility."
This is protection against despair. Isolation is how chaos hunts.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Standing figure with Ka arms raised behind them like wings',
      colorFrequency: 'Warm ochre body with protective shadow behind',
      mantra: '"I am a continuation, not an accident."',
    ),
  ),

  'ipt_8_1': KemeticDayInfo(
    gregorianDate: 'April 21, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 8',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Bind the Household',
    cosmicContext: '''Day 8 is household protection.
Kemetic devotion was not only incense and hymns. It was also: "Are the children safe?" "Is the elder comforted?" "Is the anger in this house cooling?" You extend the same protection you pray for.
Today you ask, "Did I extend the protection I pray for, or did I hoard it?"
Check on someone under your roof. Feed someone. Apologize where you caused fracture. Hold an elder's hand. Tell a child, "You are guarded."
Maʿat begins inside the doorway.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two figures touching foreheads inside an enclosing protection loop',
      colorFrequency: 'Hearth gold and protective dark umber',
      mantra: '"I guard what is mine in Maʿat."',
    ),
  ),

  'ipt_9_1': KemeticDayInfo(
    gregorianDate: 'April 22, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 9',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Renewal")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Promise Continuity',
    cosmicContext: '''Day 9 is inheritance on purpose.
In Kemet, people swore aloud what they would preserve: a piece of land, a ritual, a craft, a moral law. You did not wait for accident to decide what survived. You named it.
Today you ask, "If I fall tomorrow, what survives because of me?"
Write or speak one thing you will pass on. Teach it to someone if you can. This is legal. This is cosmic paperwork.
You are ensuring that your line does not break when you do.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scroll being handed to a smaller figure',
      colorFrequency: 'Aged parchment gold and living skin brown',
      mantra: '"What I keep, I pass."',
    ),
  ),

  'ipt_10_1': KemeticDayInfo(
    gregorianDate: 'April 23, 2026',
    kemeticDate: 'Ipt-ḥmt I, Day 10',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal the Lineage Vow',
    cosmicContext: '''Day 10 is oath.
This is where you stop treating all this like mood and name it as duty. In Kemet, people declared before witnesses — living or dead — that they would uphold the line in Maʿat. Care for graves. Defend children. Guard names. Maintain dignity. Feed the chain.
Today you ask, "Will my name be spoken with pride when I cross into the West?"
Make one vow aloud: "I will…" and finish it with something real.
The gods record. Your ancestors hear. You become answerable.''',
    decanFlow: iptHmtIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ka-arms raised behind a kneeling supplicant before an offering table',
      colorFrequency: 'Vow red over ancestral midnight blue',
      mantra: '"I swear to keep the line in Maʿat."',
    ),
  ),

  // ==========================================================
  // ☀️ IPT-ḤMT II — DAYS 11–20  (Second Decan - špsswt)
  // ==========================================================

  'ipt_11_2': KemeticDayInfo(
    gregorianDate: 'April 24, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 11',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Bringing Together of the Line")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Stand Before Your Name',
    cosmicContext: '''Day 11 is judgment without funeral.
In Kemet, to be "true of voice" meant you could stand before Maʿat and speak truth about your own life without choking. That status wasn't automatic. You had to live into it.
Today you ask, "If I died today, would they call me true of voice?"
Not "would they love me," not "would they defend me," but: would they say I lived in balance, kept my word, fed where I could feed, and did not rot what I touched?
This is not guilt. This is calibration. You're checking your own weight while you're still alive enough to adjust.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Feather of Maʿat beside an open mouth (truth spoken under judgment)',
      colorFrequency: 'Bone white and night blue',
      mantra: '"Let my name be clean when it is spoken."',
    ),
  ),

  'ipt_12_2': KemeticDayInfo(
    gregorianDate: 'April 25, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 12',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Pour the Water',
    cosmicContext: '''Day 12 is reverence for those who earned honor.
The Kemite didn't act like everyone in the lineage was glorious. They knew exactly who upheld Maʿat and who didn't. On this day, offerings were given specifically to the ones who lived right — the ones whose names were safe to invoke.
Today you ask, "Who in my line actually lived right, and what did that look like in practice?"
Pour water. Call their names softly. Study what they did, not just who they were: how they worked, how they kept dignity, how they handled pressure.
You are not worshiping them. You are apprenticing under them.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Libation jar tipping forward above rippling lines of water',
      colorFrequency: 'Cool silver-blue with a thin line of white light',
      mantra: '"I honor those who walked in Maʿat."',
    ),
  ),

  'ipt_13_2': KemeticDayInfo(
    gregorianDate: 'April 26, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 13',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Reunion")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Measure Your Conduct',
    cosmicContext: '''Day 13 is alignment check.
The Kemite understood that false presentation is a kind of rot. To speak Maʿat while living isfet (imbalance, disorder) was shameful. This day existed to stop that drift.
Today you ask, "Where am I pretending to be aligned but I am not?"
Name it. Are you calling something "love" that is really control? Calling something "generosity" that is really guilt? Calling something "work" that is really avoidance?
The blessed dead you just honored are not fooled by costume. Neither should you be.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Feather of Maʿat on a balance scale beside a human heart',
      colorFrequency: 'Dawn gold against deep charcoal',
      mantra: '"I bring my life into agreement with my mouth."',
    ),
  ),

  'ipt_14_2': KemeticDayInfo(
    gregorianDate: 'April 27, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 14',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Correct Harm You Caused',
    cosmicContext: '''Day 14 is repair.
Maʿat is not "I never messed up." Maʿat is "when I break something, I fix it." This day existed so you could return balance while you're still alive, so the debt does not follow you into judgment.
Today you ask, "Who deserves repair from me?"
Call. Apologize. Replace. Pay back. Rebuild trust you damaged. Reinstate a boundary you violated.
You are not groveling. You are cleaning the ledger your own spirit will face.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two hands extended with an offering back toward another figure',
      colorFrequency: 'Warm clay red and reconciliatory pale blue',
      mantra: '"I fix what I broke."',
    ),
  ),

  'ipt_15_2': KemeticDayInfo(
    gregorianDate: 'April 28, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 15',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Clean Your Name',
    cosmicContext: '''Day 15 is name purification.
In Kemet, your name (rn) was a living body. To pollute it with lies, chaos, trash talk, reckless drama — that was self-harm. To cleanse it was spiritual maintenance.
Today you ask, "What stain around my name is my own doing?"
You stop feeding gossip. You step out of mess you helped create. You refuse to repeat lies you once repeated. You stop entertaining people who drag your name through rot with your permission.
This is not rebranding. This is spiritual hygiene.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Name-ring (cartouche shape) being washed by flowing lines',
      colorFrequency: 'Pale linen white and cleansing water blue',
      mantra: '"My name will not carry rot."',
    ),
  ),

  'ipt_16_2': KemeticDayInfo(
    gregorianDate: 'April 29, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 16',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Speak Your Standard Aloud',
    cosmicContext: '''Day 16 is boundary spoken as oath.
The Kemite understood that unspoken standards dissolve. Said aloud, they harden. On this day, a person would state what was now forbidden and what was now required in their life, calling the ancestors to witness.
Today you ask, "What line in the sand must I draw for myself?"
Say it. "I do not let people speak to me this way." "I will rest without guilt." "I do not betray my health for approval." Speak it like law, because it is law.
The honored dead hear you and hold you accountable.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hand in a "stop" gesture beside the feather of Maʿat',
      colorFrequency: 'Boundary red edged with white feather-light',
      mantra: '"My life now moves under declared law."',
    ),
  ),

  'ipt_17_2': KemeticDayInfo(
    gregorianDate: 'April 30, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 17',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Reunion of lines")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Protect Your Word',
    cosmicContext: '''Day 17 is oath protection.
In Kemet, careless speech was considered spiritual fraud. You did not promise what you would not do. You did not pledge loyalty you didn't mean. You did not swear love you would not keep. Your word and your Ka were tied.
Today you ask, "Where am I cheap with my word?"
Tighten it. Do not offer what you cannot maintain. Pull back false yeses. Give no more empty "I got you."
Your voice is an altar. Stop spilling on it.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Mouth symbol guarded by a protective loop',
      colorFrequency: 'Burnished copper and sealed black',
      mantra: '"My word is not for waste."',
    ),
  ),

  'ipt_18_2': KemeticDayInfo(
    gregorianDate: 'May 1, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 18',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Hold Your Center in Heat',
    cosmicContext: '''Day 18 is trial.
The Kemite knew: Maʿat that only works when life is easy is not Maʿat. The honored dead are honored because they stayed aligned under pressure — insult, hunger, temptation, humiliation, rage.
Today you ask, "Do I only live Maʿat when it's easy?"
Your task is to stay in balance in one live moment of stress. Do not lash where you promised you would heal. Do not betray your vow from Day 16 just because you're provoked.
This is posture under flame.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Solar disk above a seated, steady figure',
      colorFrequency: 'Sun gold over steady dark earth brown',
      mantra: '"Heat does not move me off my center."',
    ),
  ),

  'ipt_19_2': KemeticDayInfo(
    gregorianDate: 'May 2, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 19',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Reunion")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Honor the Quiet Ones',
    cosmicContext: '''Day 19 is gratitude for the unpraised.
Kemet understood that whole households, whole fields, whole temples survived because of people who never got named in stone. The woman who rationed grain with perfect fairness. The uncle who defended children. The neighbor who showed up every time.
Today you ask, "Whose quiet strength have we failed to praise?"
Name them. Tell them. Or, if they're gone, tell the air. Let their name sit among špsswt.
This corrects an old injustice: work without honor.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Small flame cupped in two hands',
      colorFrequency: 'Low ember red and soft brown-black',
      mantra: '"I honor the ones who held us together quietly."',
    ),
  ),

  'ipt_20_2': KemeticDayInfo(
    gregorianDate: 'May 3, 2026',
    kemeticDate: 'Ipt-ḥmt II, Day 20',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Prepare to Be Remembered',
    cosmicContext: '''Day 20 is legacy alignment.
The Kemite did not fear death because he understood continuation. The only true fear was dying untrue — leaving behind a name that cannot be spoken with honor.
Today you ask, "What sentence will my people speak about me when I am gone — and will it be honest?"
Write that sentence. Say it aloud. Then start living that sentence on purpose.
This is not fantasy. This is reputation as ritual — you forming the memory you will become.''',
    decanFlow: iptHmtIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe\'s palette placed beneath a star cluster',
      colorFrequency: 'Ink black and ancestral starlight white',
      mantra: '"Live now so your memory can stand among the honored."',
    ),
  ),

  // ==========================================================
  // ☀️ IPT-ḤMT III — DAYS 21–30  (Third Decan - ḥr sꜣḥ)
  // ==========================================================

  'ipt_21_3': KemeticDayInfo(
    gregorianDate: 'May 4, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 21',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together / Reunion of the Line")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Claim the Line',
    cosmicContext: '''Day 21 is acceptance: you are not an accident.
In Kemet, kingship was not about ego. It was about continuity — Horus standing upon Sah meant: "I stand on what my ancestor built, not apart from it."
Today you ask, "Whose work am I continuing with my life?"
Not whose drama, not whose pain — whose work. Who held the world up in your line? Who fed people? Who defended? Who created safety? You are not "inspired by them," you are literally the next piece of them.
Claiming the line is not cosplay. It is custodianship.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Falcon (Horus) standing atop the star-figure of Sah',
      colorFrequency: 'Deep night blue with a band of gold at the horizon',
      mantra: '"I accept that I continue them."',
    ),
  ),

  'ipt_22_3': KemeticDayInfo(
    gregorianDate: 'May 5, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 22',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Receive the Charge',
    cosmicContext: '''Day 22 is assignment.
Inheritance in Kemet was not "you get stuff." It was "you get responsibility." When Horus stands on Sah, it means: the work is yours now. Feed who must be fed. Guard what must be guarded. Keep Maʿat with your body.
Today you ask, "What responsibility is now mine because others are gone?"
Who is no longer here to protect, to advocate, to keep order, to hold memory, to hold the door? That is now you. Stop pretending you don't see it.
This is when you say, "Yes. I'll carry it."''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Falcon grasping the was-scepter (authority, responsibility)',
      colorFrequency: 'Bronze authority with a line of solar white',
      mantra: '"I accept the duty that is mine."',
    ),
  ),

  'ipt_23_3': KemeticDayInfo(
    gregorianDate: 'May 6, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 23',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together / Reunion")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Name the Scar',
    cosmicContext: '''Day 23 is courage in honesty.
When Horus stands on Sah, he stands on a body that was torn, scattered, reassembled — Asar (Osiris). Kemet never hides that. It teaches: every inheritance carries wound.
Today you ask, "What damage am I inheriting that I refuse to pass forward?"
Name it clear. Violence. Silence. Addiction. Poverty management that turns into self-erasure. Fear of intimacy. Fear of softness. Rage that poisons love.
You do not pretend it wasn't there. You say, "I see it. It stops here."''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Eye of Horus (the restored eye) above the banded Djed of Asar (Osiris)',
      colorFrequency: 'Healing lapis blue over rooted earth gold',
      mantra: '"The wound is not my shame, the repetition is."',
    ),
  ),

  'ipt_24_3': KemeticDayInfo(
    gregorianDate: 'May 7, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 24',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Swear Continuity',
    cosmicContext: '''Day 24 is vow.
The Kemite believed that certain things are not allowed to die: sanctuary, dignity, a child's safety, a house where people can rest without terror, an honest account of what happened. Someone must swear to keep those alive.
Today you ask, "What will not be allowed to die with me?"
Say it aloud. "In this house, there will always be tenderness." "In this family, we do not starve each other's spirit." "Our story will not be erased or rewritten against us."
This is you taking oath as living temple.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ankh (life) held out in an offering hand',
      colorFrequency: 'Living gold edged with protective red',
      mantra: '"This does not die while I live."',
    ),
  ),

  'ipt_25_3': KemeticDayInfo(
    gregorianDate: 'May 8, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 25',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Union / Reunion with the Ka")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Refuse the Rot',
    cosmicContext: '''Day 25 is prohibition.
If Day 24 is "this will live through me," Day 25 is "this will not live through me." Horus inherits Asar (Osiris), but he does not inherit Set's poison.
Today you ask, "What poison stops in my generation?"
You say it directly. "This house will not repeat our old violence." "We will not normalize humiliation." "We do not starve each other of love and call that strength."
You are cutting a cord. You are killing a pattern so the next ones don't have to.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Knife cutting a serpent coil',
      colorFrequency: 'Protective matte black with a thin edge of white',
      mantra: '"The poison stops here."',
    ),
  ),

  'ipt_26_3': KemeticDayInfo(
    gregorianDate: 'May 9, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 26',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Build the Bridge',
    cosmicContext: '''Day 26 is infrastructure.
Kemet did not believe in "they'll figure it out." They documented, stored grain, carved names, built tombs with maps, taught measurement. A righteous heir leaves bridges, not mysteries.
Today you ask, "What tool or record can I create so they do not have to start over from zero?"
Write down what you know. Save money for the one after you. Put passwords in order. Leave instructions. Organize the ritual. Sketch the map.
This is love as architecture.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Stairway / stepped platform beneath the falcon',
      colorFrequency: 'Foundation clay red and structural sandstone gold',
      mantra: '"I build the path for the ones after me."',
    ),
  ),

  'ipt_27_3': KemeticDayInfo(
    gregorianDate: 'May 10, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 27',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Transfer the Teachings',
    cosmicContext: '''Day 27 is transmission.
Keeping wisdom to yourself so you stay "needed" is isfet. In Kemet, knowledge hoarded was corruption. Knowledge shared was continuity.
Today you ask, "Who needs to know what I know while I am still breathing?"
Teach them. Show them the technique. Walk them through the paperwork. Give them the prayer. Tell them the real story. Tell them where the danger is. Tell them how to navigate.
You are not immortal. Share the map.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Hand of an elder passing an ankh to a smaller hand',
      colorFrequency: 'Soft ochre and teaching amber',
      mantra: '"I give the living knowledge while I live."',
    ),
  ),

  'ipt_28_3': KemeticDayInfo(
    gregorianDate: 'May 11, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 28',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together / Reunion")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Pledge Publicly',
    cosmicContext: '''Day 28 is declaration.
In Kemet, the heir does not sneak into power. The heir is revealed before the Two Lands and named as guardian of Maʿat. That revelation is both accountability and protection.
Today you ask, "Who will I say I stand for?"
Say it aloud, write it, record it, burn incense over it. "I stand for my children's safety." "I stand for the memory of the ones whose names were erased." "I stand for clean love in this house."
When you declare it, the world can measure you by it. That pressure is holy.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Falcon standard raised upright before a pair of outstretched arms',
      colorFrequency: 'Royal gold and proclamation white',
      mantra: '"I say openly what I serve."',
    ),
  ),

  'ipt_29_3': KemeticDayInfo(
    gregorianDate: 'May 12, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 29',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Seal the House',
    cosmicContext: '''Day 29 is order.
This is the day you put everything in place so chaos doesn't burst in the second you step out of view. In Kemet, nothing rolled into the new year sloppy. The home was sealed in Maʿat.
Today you ask, "If I vanish tonight, is the path after me clear or chaos?"
Check: debts, passwords, guardianship, medicine, savings, tools, instructions, burial wishes, spiritual instructions, emotional guidance. Make sure the people after you are not left in panic.
That is love. That is protection. That is Maʿat.''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Closed door bolt over a coiled rope (secured household)',
      colorFrequency: 'Protective deep brown and sealed matte red',
      mantra: '"I leave no chaos behind me."',
    ),
  ),

  'ipt_30_3': KemeticDayInfo(
    gregorianDate: 'May 13, 2026',
    kemeticDate: 'Ipt-ḥmt III, Day 30',
    season: '☀️ Shemu — Heat and Distribution',
    month: 'Ipt-ḥmt ("Bringing Together / Reunion with the Ka")',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Stand Before the Dawn',
    cosmicContext: '''Day 30 is presentation.
You arrive at the threshold of the new cycle as the heir: not hiding, not pretending to be smaller than you are, not making yourself unworthy so no one will expect anything. Horus at dawn is unhidden.
Today you ask, "Am I ready to stand on Sah — to inherit Maʿat without apology?"
This is not arrogance. This is readiness. You've cleaned your name, repaired harm, sworn continuity, refused rot, prepared those after you.
Now you stand upright and say: "I am here, in order, under Maʿat. I will carry."''',
    decanFlow: iptHmtIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Falcon standing atop the Orion-standard, facing east toward sunrise',
      colorFrequency: 'Horizon gold over night blue dissolving into pale dawn',
      mantra: '"I rise in Maʿat and I carry it forward."',
    ),
  ),

  // ==========================================================
  // 🌞 MSWT-Rꜥ I — DAYS 1–10  (First Decan - sꜣḥ)
  // ==========================================================

  'mswtRa_1_1': KemeticDayInfo(
    gregorianDate: 'February 4, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 1',
    season: '🌞 Threshold of Heriu Renpet — the womb before birth',
    month: 'Mswt-Rꜥ ("The Birth of Ra," the gestation of renewal)',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Surrender to Stillness',
    cosmicContext: '''Day 1 is stillness by obedience, not collapse.
In Kemet, stillness was not laziness — it was ritual. The lamps in the temples of the old year were extinguished on purpose, not because the fire died, but because the priests said "Rest now. The god is being prepared."
This is Sah: the quiet form of Asar (Osiris) risen in the night sky, not moving, just present — undeniable.
Today you ask, "Where am I pretending I'm 'fine' just to avoid stopping?"
You are allowed to stop running. You are ordered to stop running.
You do not earn worth by frantic motion. You sit, you breathe, you let the pieces of you settle in front of you.
Stillness is not retreat. Stillness is preparation for reassembly.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Sah as a striding, star-marked figure of Asar (Osiris), outlined in constellation points',
      colorFrequency: 'Deep midnight indigo, barely pierced by white fire points',
      mantra: '"I will be still so I can rise."',
    ),
  ),

  'mswtRa_2_1': KemeticDayInfo(
    gregorianDate: 'February 5, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 2',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ ("The Birth of Ra")',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Lay Down Weapons',
    cosmicContext: '''Day 2 is disarmament.
In the restoration myth, Asar (Osiris) is not raised with his rage — he is raised with his dignity. The rage belongs to Set. The Dignity belongs to Asar.
There are weapons you picked up because you were not safe. There are weapons you now carry out of habit. They cut you every day.
Today you ask, "What am I gripping that is actually wounding me?"
You do not have to keep your jaw braced, your shoulders high, your voice sharpened like a blade, just to prove you won't be broken again.
Maʿat is not impressed with constant armor.
Lay it down for one day. See what remains of you when you are not busy defending.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Open palm releasing a blade to the ground before the Djed pillar',
      colorFrequency: 'Matte black surrender with a single line of grounded brown',
      mantra: '"I don\'t need to bleed to prove I am strong."',
    ),
  ),

  'mswtRa_3_1': KemeticDayInfo(
    gregorianDate: 'February 6, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 3',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Loosen the Jaw / Breathe',
    cosmicContext: '''Day 3 is breath returned to the body like water poured back into a dry canal.
Kemetic physicians and temple healers knew: locked jaw, high shoulders, shallow breath means "battle-state." You cannot crown a king in battle-state. You calm the nervous system before enthronement.
Today you ask, "What would my breath sound like if I was safe?"
You lengthen the exhale. You let the shoulders drop. You soften the tongue from the roof of the mouth. You let the ribs widen instead of bracing.
This is not self-care. This is ritual pre-throne conditioning.
Sah rises in silence so the nervous system of the land can follow.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'The hieroglyph for breath / air-lines rising before the nose of a seated figure',
      colorFrequency: 'Cool Nile blue entering warm terracotta body',
      mantra: '"My breath is allowed to return to me."',
    ),
  ),

  'mswtRa_4_1': KemeticDayInfo(
    gregorianDate: 'February 7, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 4',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ ("The Birth of Ra")',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Return to Body',
    cosmicContext: '''Day 4 is re-entering yourself.
When the body is in chronic defense, parts of you go offline — throat tight, belly numb, chest armored, hands cold. The Kemite healer would place hands and name where life had retreated. Naming was medicine.
Today you ask, "Where have I stopped living inside myself?"
Touch your chest. Touch your throat. Touch your belly. Say, "This is mine."
You do not apologize for needing tenderness in the flesh. You are a living shrine, not a discarded tool.
To be reborn under Ra, you must first be fully present under Nut.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hands over the seated human figure (gesture of protection and indwelling)',
      colorFrequency: 'Warm body ochre ringed in protective deep blue',
      mantra: '"I live here. I return to myself."',
    ),
  ),

  'mswtRa_5_1': KemeticDayInfo(
    gregorianDate: 'February 8, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 5',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Offer the Remains',
    cosmicContext: '''Day 5 is honest offering.
In the myth, Aset (Isis) does not demand that Asar (Osiris) "be whole" before she loves him. She gathers even the broken parts and says: "This is still my lord." That act itself calls resurrection.
Today you ask, "If I lay myself on the altar as I am, what do I place there?"
This is where you stop curating your pain to look noble. You put the mess down in front of Maʿat without lying about it.
You do not need to be pretty to be worthy of restoration.
This is how the next birth begins: not with perfection, but with truth placed in sacred hands.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Aset\'s knot (the tit) beside the Djed, union of holding and raising',
      colorFrequency: 'Blood red of devotion tied around steady muted gold',
      mantra: '"Even in pieces, I am worthy of being lifted."',
    ),
  ),

  'mswtRa_6_1': KemeticDayInfo(
    gregorianDate: 'February 9, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 6',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ ("The Birth of Ra")',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Receive Reassembly',
    cosmicContext: '''Day 6 is letting yourself be helped without shame.
Aset (Isis) and Nebet-Het do not ask Asar (Osiris), "Can you get up on your own?" They build him back. Limb, breath, name. That rebuilding is holy, not humiliating.
Today you ask, "Where do I still refuse to be helped because I think I must deserve pain?"
You are not meant to stitch your own wounds in the dark forever.
Allow rest. Allow feeding. Allow someone to sit next to you while you sleep.
You are not weak for needing that. You are in ceremony.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two supporting arms lifting the Djed upright',
      colorFrequency: 'Supportive earth brown and quiet resurrection blue',
      mantra: '"It is holy to let myself be lifted."',
    ),
  ),

  'mswtRa_7_1': KemeticDayInfo(
    gregorianDate: 'February 10, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 7',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Raise the Djed',
    cosmicContext: '''Day 7 is spine.
The rite of "Raising the Djed" in temple scenes is not body-building bravado. It is the quiet, disciplined act of re-stabilizing the world. The pillar stands, and with it, the kingdom stands.
Today you ask, "Can I sit in my own stability without needing applause?"
You sit upright. You feel the line from tailbone through crown. You do not puff your chest. You do not shrink your chest. You just align.
This is what dignity looks like in Kemet: not noise, not performance — structural presence.
When you sit like Djed, the room knows balance has returned.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'The Djed pillar, banded and upright',
      colorFrequency: 'Rooted sandstone gold with four calm horizontal bands',
      mantra: '"I am steady. The world can stand on me."',
    ),
  ),

  'mswtRa_8_1': KemeticDayInfo(
    gregorianDate: 'February 11, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 8',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ ("The Birth of Ra")',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Accept the Naming',
    cosmicContext: '''Day 8 is reclamation of name.
You have been called lazy, angry, too much, too soft, unreliable, dangerous, ungrateful, crazy, disposable. None of those are your true name. Those are chains.
In Kemet, to know the ren — the true name — is to know the function of a being in Maʿat. Your true name is not aesthetic; it is assignment.
Today you ask, "What am I really called in this world, beneath survival titles?"
Call yourself what you are in order: Restorer. Guardian. Nourisher. Witness. Builder. Healer.
Say it out loud. The body hears you. The soul hears you. Maʿat hears you.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Name-ring / cartouche enclosing a ren, protected by a looped rope-oval',
      colorFrequency: 'Bright declaration gold against matte black background',
      mantra: '"I speak my true name into the year."',
    ),
  ),

  'mswtRa_9_1': KemeticDayInfo(
    gregorianDate: 'February 12, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 9',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Keep Silent Watch',
    cosmicContext: '''Day 9 is quiet guard.
You do not argue. You do not plead. You observe. You decide what may enter and what may not.
The Kemite gatekeeper at night did not perform rage. He simply stood, staff in hand, and nothing profane crossed the line. That is how shrines survive.
Today you ask, "What crosses my boundary that does not belong in the next cycle?"
This could be a person. A habit. A schedule. A self-story.
You are not required to drag any of that into rebirth. You are allowed to say, "No further."''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A standing guardian figure with staff beside a sealed doorway',
      colorFrequency: 'Night-guard charcoal with a single protective line of red at the threshold',
      mantra: '"Nothing unclean crosses into my next year."',
    ),
  ),

  'mswtRa_10_1': KemeticDayInfo(
    gregorianDate: 'February 13, 2026',
    kemeticDate: 'Mswt-Rꜥ I, Day 10',
    season: '🌞 Heriu Renpet approaches',
    month: 'Mswt-Rꜥ ("The Birth of Ra")',
      decanName: 'msḥtjw ḫt ("The Sacred Foreleg")',
      starCluster: '✨ The Sacred Foreleg — strength held in reserve.',
    maatPrinciple: 'Hold the Gate',
    cosmicContext: '''Day 10 is readiness without desperation.
Rebirth is close. But you do not claw at it. You do not beg the dawn to hurry. You stand like Sah: assembled, named, guarded, breathing, upright.
Today you ask, "Can I wait with dignity for what is mine, instead of chasing?"
In Kemet, to stand at the gate before sunrise was an honor. The priests called that posture "enoughness."
You are not half-formed. You are not "almost worthy."
You are standing at the door of the next cycle as living structure, holding Maʿat in place until Ra crowns the sky.''',
    decanFlow: mswtRaIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A sealed doorway with the Djed set before it like a pillar of oath',
      colorFrequency: 'Horizon line of pale dawn gold against deep pre-sun violet',
      mantra: '"I stand at the gate in Maʿat."',
    ),
  ),

  // ==========================================================
  // ☀️ MSWT-Rꜥ II — DAYS 11–20  (Second Decan - sbꜣ nfr)
  // ==========================================================

  'mswtRa_11_2': KemeticDayInfo(
    gregorianDate: 'February 23, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 11',
    season: '☀️ Shemu — The Closing Heat',
    month: 'Mswt-Rꜥ ("Births of Ra") — msi = to give birth, emergence',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Enter the Hidden',
    cosmicContext: '''Today begins the inward turn of the final month.
In Kemet, the disappearance of Sirius was not fear but reverence — the belief that even stars require dark chambers to be remade.
Mswt-Rꜥ 11 is the first step into that chamber.
The priests taught that nothing significant is born in noise.
Farmers finished their last tasks early; households cooled lamps and reduced speech.
Even the animals moved slower, sensing the thinning of the veil.
This was the day when the world agreed to stop performing strength and started preparing for renewal.
Your task mirrors theirs: withdraw without shame.
What goes quiet today will bloom in a way that loudness could never achieve.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Sopdet\'s five-pointed star rising from the womb of Nut',
      colorFrequency: 'Deep indigo with a single point of white-gold',
      mantra: '"What hides in darkness prepares to rise."',
    ),
  ),

  'mswtRa_12_2': KemeticDayInfo(
    gregorianDate: 'February 24, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 12',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ ("The Births of Ra")',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Release the Light',
    cosmicContext: '''Day 12 teaches that not all light is helpful.
The Kemite understood that even radiance can exhaust, distract, or blind when held past its purpose.
When Sirius vanished, the priests said: "She releases her shine to return with power."
So today you release something visible — a habit, an identity, a possession, a posture others expect from you.
This is not loss; this is unburdening.
A star must dim to be reborn.
Let go so you can rise without the weight of old brightness.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Fading star dissolving into the curve of Nut',
      colorFrequency: 'Pale silver melting into blue-black',
      mantra: '"I release what no longer nourishes my return."',
    ),
  ),

  'mswtRa_13_2': KemeticDayInfo(
    gregorianDate: 'February 25, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 13',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Sink into Trust',
    cosmicContext: '''Day 13 is surrender to the unseen.
The Kemite watched Sirius disappear into the brightness of Ra and understood a secret:
If the star can vanish and yet signal the year's rebirth, then the unseen can be trusted.
No seed demands proof of the soil; it simply rests.
No newborn demands a calendar; it simply arrives.
Today is faith without spectacle — belief without evidence.
Let the process beneath your life work without interference.
Trust does not weaken you; it frees your energy for what is coming.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Closed eye beneath the rising curve of Nut',
      colorFrequency: 'Midnight blue infused with soft violet',
      mantra: '"The unseen is working for me."',
    ),
  ),

  'mswtRa_14_2': KemeticDayInfo(
    gregorianDate: 'February 26, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 14',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Prepare the Vessel',
    cosmicContext: '''Day 14 is the cleansing before the birth.
In Kemet, no shrine received rebirth-water unless it had been washed with natron and swept with palm fibers.
Likewise, Nut does not give birth into disorder.
The priests taught: "The vessel that is unprepared rejects the blessing."
So today you purify: body, home, tools, schedule, altar.
Strip away residue.
Make space with intention.
The gods are preparing for birth — your life must not be cluttered when the new enters.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Jar of purification water beneath the arc of the sky',
      colorFrequency: 'White-blue with touches of lotus silver',
      mantra: '"I clean the place where rebirth will land."',
    ),
  ),

  'mswtRa_15_2': KemeticDayInfo(
    gregorianDate: 'February 27, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 15',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Seal the Silence',
    cosmicContext: '''Day 15 is the locking of the chamber.
In temple ritual, before the great births of the epagomenal days, the sanctuary was sealed — no sound, no incense, no movement except the breath of the gods.
This was the womb closed before delivery.
Your work today is to create a sealed inner room within yourself.
No gossip.
No leaks of energy.
No explaining yourself.
No defending what is gestating.
Silence is not retreat — it is protection.
You are guarding the unborn within you.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Closed shrine door beneath Nut\'s arch',
      colorFrequency: 'Black-blue silence with a single silver seal',
      mantra: '"My silence protects my becoming."',
    ),
  ),

  'mswtRa_16_2': KemeticDayInfo(
    gregorianDate: 'February 28, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 16',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ ("Births of Ra")',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Hold the Unborn',
    cosmicContext: '''Day 16 is patient expectation.
In Kemet, this was the softest day of the year — the day when even priests spoke less, sensing the weightless fullness of something forming beyond sight.
The myth taught that Nut carries all five divine children at once; so this day symbolized holding multitudes without rushing birth.
The people imitated her: slowing tasks, softening voices, moving with deliberation.
This was not laziness — it was protective patience, safeguarding a future not yet ready to emerge.
Today you resist the urge to force clarity, to push outcomes, to demand proof.
You cradle the unformed inside yourself, trusting its shape will reveal itself in sacred timing.
Everything unborn needs warmth, not pressure.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A womb-shaped crescent holding a single point of light',
      colorFrequency: 'Womb-red deepening into midnight indigo',
      mantra: '"I protect what has not yet taken form."',
    ),
  ),

  'mswtRa_17_2': KemeticDayInfo(
    gregorianDate: 'March 1, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 17',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Warm the Inner Flame',
    cosmicContext: '''Day 17 is the kindling of the internal fire.
Though the outer world remains still, the inner world begins to heat — the same way the womb of Nut warms before the births of the gods.
This was the day when Kemet practiced breath rituals, slow stretching, oiling of the body, and lighting of small personal lamps.
Not bright flames — quiet embers.
The lesson: rebirth does not arrive cold.
It requires the gentle ignition of intention, discipline, posture, and breath.
Today you warm your inner flame — not for display, but for gestation.
This heat is what will empower you to cross the year's threshold with strength.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A small flame nested in cupped hands',
      colorFrequency: 'Ember-gold over deep maroon',
      mantra: '"My fire grows quietly."',
    ),
  ),

  'mswtRa_18_2': KemeticDayInfo(
    gregorianDate: 'March 2, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 18',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Call the Ancestors',
    cosmicContext: '''Day 18 is remembrance with purpose.
In Mswt-Rꜥ, the people of Kemet knew: no one crosses into a new year alone.
As Sopdet gestates in Nut's womb, she draws upon the power of all who came before — the ancestors who endured famine, flood, labor, conquest, and rebirth.
So on this day families spoke names aloud, poured water, lit lamps for the departed, and told stories that kept the Ka strong.
This was not mourning — it was inheritance activation.
Your ancestors, known and unknown, surround you in the unseen.
Call them.
You stand where you stand because they survived what tried to stop them.
Today your lineage becomes your fuel.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ka-arms emerging from a star',
      colorFrequency: 'Ancestral gold over deep brown-earth',
      mantra: '"Those before me rise through me."',
    ),
  ),

  'mswtRa_19_2': KemeticDayInfo(
    gregorianDate: 'March 3, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 19',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Discern the Signs',
    cosmicContext: '''Day 19 is subtle revelation.
When Sirius was invisible, priests studied tiny changes: the color of the horizon, the shapes of clouds at dusk, the behavior of birds, or the stillness of wind.
They believed the world whispers before it speaks.
This was the day to notice the small alignments that foretell what is coming.
Not superstition — pattern recognition elevated to ritual practice.
Today you quiet yourself enough to detect the new cycle before it breaks the surface.
A conversation, a number, a symbol, a chance encounter — these are not coincidences.
Pay attention.
The future is announcing itself gently.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Eye of intuition beneath a star',
      colorFrequency: 'Pale gold over twilight blue',
      mantra: '"The world reveals itself to the quiet."',
    ),
  ),

  'mswtRa_20_2': KemeticDayInfo(
    gregorianDate: 'March 4, 2026',
    kemeticDate: 'Mswt-Rꜥ II, Day 20',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
      starCluster: '✨ Heart of the Sacred Foreleg — aware stillness.',
    maatPrinciple: 'Stand at the Threshold',
    cosmicContext: '''Day 20 is the final doorway.
The Kemite understood that the night is darkest just before Sopdet begins her heliacal return — and just before the five Heriu Renpet, the birthdays of the gods.
This day was the world holding its breath.
Temples were silent.
Lamps remained extinguished.
Families gathered small items they wished to carry into the new cycle — not objects of wealth, but objects of meaning.
This is the day to prepare your offering for the next year of your life: a vow, a symbol, a decision, a truth.
Stand with stillness and intention.
You are one breath away from the birth of the gods — and from your own renewal.''',
    decanFlow: mswtRaIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Gateway with a star poised above the lintel',
      colorFrequency: 'Dawn-gold hovering over void-black',
      mantra: '"I step toward rebirth with intention."',
    ),
  ),

  // ==========================================================
  // ☀️ MSWT-Rꜥ III — DAYS 21–30  (Third Decan - msḥtjw ḫt)
  // ==========================================================

  'mswtRa_21_3': KemeticDayInfo(
    gregorianDate: 'March 5, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 21',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'The First Fracture',
    cosmicContext: '''This day honors the moment of breaking — not as tragedy, but as divine engineering.
In myth, the Sacred Foreleg is the dismembered limb of the Bull of Heaven, carried into the sky as a constellation.
Its separation makes resurrection possible.

The Kemite did not fear the break.
He feared failing to see its purpose.

Day 21 asks you to recognize what cracked this year — identity, relationships, plans, illusions — and to view it with Osirian clarity:

Some things must break so they can be rebuilt on Maʿat.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A foreleg of a bull with a fine fracture line and a small star above it',
      colorFrequency: 'Deep indigo (night of unknowing) with bone white (truth revealed)',
      mantra: '"I honor what broke to reveal truth."',
    ),
  ),

  'mswtRa_22_3': KemeticDayInfo(
    gregorianDate: 'March 6, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 22',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'What Breaks, Begins',
    cosmicContext: '''Isis did not gather Osiris blindly.
She knew the location of every limb, every bone, every fragment.

Day 22 is her discipline.

You look at the year and identify:

* What fell apart

* What you abandoned

* What you forgot

* What you sacrificed

* What life took from you

* What you willingly laid down

Naming the pieces is a sacred act.
You cannot restore what you refuse to recognize.

This is inventory before resurrection.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A papyrus scroll unrolled, with small fragment-marks along its length',
      colorFrequency: 'Sand-gold (memory of the year) and ink black (clear naming)',
      mantra: '"I see every piece of my becoming."',
    ),
  ),

  'mswtRa_23_3': KemeticDayInfo(
    gregorianDate: 'March 7, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 23',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Restoration Requires Seeking',
    cosmicContext: '''Isis did not merely locate Osiris's pieces —
she summoned them.

Day 23 is magnetic.

What was lost this year — confidence, discipline, joy, boundaries, creativity — is now called back with intention.

The Kemite belief:

"What belongs to you will hear your voice."

Today is the voice.

Stand outside.
Breathe.
Call back what left you.

Something will stir.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two outstretched arms drawing small fragments inward toward a central heart',
      colorFrequency: 'Deep Nile blue (returning flow) with solar gold (summoning power)',
      mantra: '"What is mine returns to me in Maʿat."',
    ),
  ),

  'mswtRa_24_3': KemeticDayInfo(
    gregorianDate: 'March 8, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 24',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Strength Returns in Pieces',
    cosmicContext: '''Reassembly begins.

The Kemites wrapped the limbs of Osiris not only to preserve but to unify him.
They believed identity is woven — not found.

Today you rebind:

* Your routines

* Your values

* Your goals

* Your roles

* Your name

* Your purpose

Things that drifted apart through the year now braid themselves together again.

Day 24 restores coherence.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A linen band crossing and knotting around a restored limb',
      colorFrequency: 'Linen white (wrapping) and fresh green (living unity)',
      mantra: '"I bind myself back into wholeness."',
    ),
  ),

  'mswtRa_25_3': KemeticDayInfo(
    gregorianDate: 'March 9, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 25',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'The Body Remembers',
    cosmicContext: '''Once Osiris was reassembled, priests removed anything foreign — weeds from linen, dust from resin, insects from oils.

Purity is not perfection; purity is alignment.

Today you remove:

* False expectations

* False personas

* False obligations

* False stories about yourself

* False emotional debts

* False guilt or shame

Nothing false survives into the rebirth.

Day 25 is a blade — precise, clean, sacred.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A ritual knife beside the feather of Maʿat, cutting away a small dark knot',
      colorFrequency: 'Blade-silver and desert ochre (what is cut away and left behind)',
      mantra: '"I release what was never truly mine."',
    ),
  ),

  'mswtRa_26_3': KemeticDayInfo(
    gregorianDate: 'March 10, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 26',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Stillness Before Wholeness',
    cosmicContext: '''This is the day of tenderness.

In the Osirian rites, oils were applied to every seam of the restored body — not as decoration, but as healing.
They used cedar, lotus, and juniper: scents of renewal.

Today you tend the raw parts of yourself:

* Emotional bruises

* Physical exhaustion

* Self-neglect

* Doubt

* Old grief

* Quiet fears

Day 26 softens what has been hardened by survival.

It prepares you for strength without brittleness.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A droplet of oil falling onto a wrapped limb or open palm',
      colorFrequency: 'Warm amber (healing oil) with soft rose-gold (tenderness)',
      mantra: '"I touch my wounds with gentleness and power."',
    ),
  ),

  'mswtRa_27_3': KemeticDayInfo(
    gregorianDate: 'March 11, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 27',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Order Assembles Itself',
    cosmicContext: '''Osiris is almost whole.

Day 27 is reinforcement.
The priests tightened the wrappings, checked the bindings, added resin, stabilized the joints.

You stabilize what is emerging inside you:

* Routines

* Boundaries

* Plans

* Rituals

* Disciplines

* Identity

* Resolve

Rebirth without reinforcement collapses under pressure.
This day ensures your return will be durable.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A Djed pillar tightly bound with supporting cords',
      colorFrequency: 'Basalt black (endurance) and emerald green (rising strength)',
      mantra: '"I reinforce the structure of my rebirth."',
    ),
  ),

  'mswtRa_28_3': KemeticDayInfo(
    gregorianDate: 'March 12, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 28',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Wholeness Approaches',
    cosmicContext: '''Rebirth is not just restoration — it is decision.

On Day 28, the final wrappings were sealed with wax and resin.
This meant:
"No more alterations. This is the form."

In your life, this is the moment to choose:

* Who you are becoming

* What your new year identity will be

* What shape your energy will take

* What you will refuse to return to

A sealed shape is a declaration.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A seal-ring pressed into a wax disk over a wrapped form',
      colorFrequency: 'Wax-gold (finalizing) over midnight blue (mystery held)',
      mantra: '"I choose and seal the form I will carry."',
    ),
  ),

  'mswtRa_29_3': KemeticDayInfo(
    gregorianDate: 'March 13, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 29',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Life Stirs Within Silence',
    cosmicContext: '''This is the day Osiris rises.

Not yet resurrected — but enthroned.
Silent.
Whole.
Sovereign.

This is the day you stand in your full form, no longer negotiating with your old self.

The Egyptians believed the restored Osiris radiated a stillness so powerful that even the gods paused.

Day 29 is dignity.
Quiet authority.
Identity without apology.

You sit on your own restored throne.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A throne with the crook and flail crossed upon it',
      colorFrequency: 'Deep Osirian green with black-gold (sovereignty in stillness)',
      mantra: '"I sit in the quiet authority of my restored self."',
    ),
  ),

  'mswtRa_30_3': KemeticDayInfo(
    gregorianDate: 'March 14, 2026',
    kemeticDate: 'Mswt-Rꜥ III, Day 30',
    season: '☀️ Shemu',
    month: 'Mswt-Rꜥ',
      decanName: 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
      starCluster: '✨ Star of the Sacred Foreleg — ready at the threshold.',
    maatPrinciple: 'Completion Before Creation',
    cosmicContext: '''The last day of the year.

All lamps extinguished.
All altars cleaned.
All offerings simple and pure.

This is the day before the birthdays of the gods:

* Osiris

* Horus the Elder

* Set

* Isis

* Nephthys

Day 30 is not celebration —
It is purification.

You shed the last remnants of the previous cycle.
You enter stillness with a clean heart and a steady breath.

Tomorrow, the world begins again.''',
    decanFlow: mswtRaIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A lotus opening above the horizon line of the sun',
      colorFrequency: 'Pale sky blue and dawn rose (pre-light)',
      mantra: '"I purify the path for new light to enter."',
    ),
  ),

  // ==========================================================
  // ✨ HERIU RENPET — DAYS 1–5  (The Births of the Gods)
  // ==========================================================

  'epagomenal_1_1': KemeticDayInfo(
    gregorianDate: 'March 15, 2026',
    kemeticDate: 'Heriu Renpet — Day 1',
    season: '✨ Time Outside Time',
    month: 'The Births of the Gods — five days beyond the year',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Life is eternal; renewal emerges from darkness.',
    cosmicContext: '''On this day, Nut labors for the first time, breaking Ra's decree that no child be born during the year.
In this hidden interval, she brings forth Asar (Osiris) — grain within black soil, death turning into life.
The Kemite understood this birth as the moment when the universe remembers itself.
In temples, barley beds carved in Osiris's form were watered; the first green shoots were prophecy: life refuses to end.
Asar's birth reawakens the Djed — the backbone of stability — and signals that every ending of the year is the seed of its beginning.
You, too, rise today from the dark soil of everything you buried, everything you thought was finished.
This day whispers the core truth of Ma'at: nothing alive truly dies; it only transforms.''',
    decanFlow: epagomenalIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Djed rising from black soil',
      colorFrequency: 'Green over deep khem-black',
      mantra: '"I rise through darkness."',
    ),
  ),

  'epagomenal_2_1': KemeticDayInfo(
    gregorianDate: 'March 16, 2026',
    kemeticDate: 'Heriu Renpet — Day 2',
    season: '✨ Time Outside Time',
    month: 'The Births of the Gods — five days beyond the year',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Clarity is sacred; sight governs justice.',
    cosmicContext: '''Today Nut gives birth to Horus the Elder, the original sky-falcon whose eyes are sun and moon.
His birth restores vision — not eyesight, but cosmic orientation.
Priests carried winged sun-disks at dawn, chanting for the renewal of royal clarity.
On this day, families practiced sekhem-ḥeru, "strength through voice," calling their intentions into alignment with truth.
Horus the Elder teaches that rulership begins with perception: you cannot guide what you cannot see.
This is a day to track the horizon — literally and figuratively — to realign direction before the next year begins.
Let your sight sharpen.
Let your internal sun rise.''',
    decanFlow: epagomenalIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Winged solar disk',
      colorFrequency: 'Gold over sky-blue',
      mantra: '"My sight is my sovereignty."',
    ),
  ),

  'epagomenal_3_1': KemeticDayInfo(
    gregorianDate: 'March 17, 2026',
    kemeticDate: 'Heriu Renpet — Day 3',
    season: '✨ Time Outside Time',
    month: 'The Births of the Gods — five days beyond the year',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Rightly placed force protects balance.',
    cosmicContext: '''The third birth is Set, often misunderstood but essential: he is not evil; he is raw force without guidance.
Ra himself relies on Set in the Duat, where Set strikes the serpent Apophis with thunderous precision.
The Kemite honored Set not to invite chaos, but to contain it.
On this day, people smashed old clay pots or tools to symbolically break disorder before it enters the new year.
Incense of cedar and juniper cleared the path of Ra's barque.
Set represents the truth that some things must end sharply so life may continue cleanly.
Today is fire, discipline, boundaries — not anger.
You don't destroy life; you destroy what destroys life.''',
    decanFlow: epagomenalIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Set-standard with forked tail',
      colorFrequency: 'Desert red over storm-black',
      mantra: '"My power protects my order."',
    ),
  ),

  'epagomenal_4_1': KemeticDayInfo(
    gregorianDate: 'March 18, 2026',
    kemeticDate: 'Heriu Renpet — Day 4',
    season: '✨ Time Outside Time',
    month: 'The Births of the Gods — five days beyond the year',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Wisdom and love speak creation into order.',
    cosmicContext: '''Tonight Nut gives birth to Aset (Isis) — the mind and heart unified.
She is the one who finds the scattered pieces of Asar (Osiris) and restores him; the one whose voice carries heka, the magic of creative speech.
Her feast was kept with lamps burning through the night while hymns declared:
"I am Aset — mother of every living thing."
Women tied red tjet-knots; families offered milk and honey for unity.
This is the day to remember your true name — the identity beneath roles, wounds, and noise.
Aset teaches that order is restored not only by strength but by truth spoken from the center of the heart.''',
    decanFlow: epagomenalIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Tjet-knot of Isis',
      colorFrequency: 'Red over milk-white',
      mantra: '"My true name restores my world."',
    ),
  ),

  'epagomenal_5_1': KemeticDayInfo(
    gregorianDate: 'March 19, 2026',
    kemeticDate: 'Heriu Renpet — Day 5',
    season: '✨ Time Outside Time',
    month: 'The Births of the Gods — five days beyond the year',
      decanName: 'sbꜣ knmw ("Star of Khnum")',
      starCluster: '✨ Star of Khnum — reliable, guiding skill.',
    maatPrinciple: 'Compassion for the unseen completes the cycle.',
    cosmicContext: '''On this final epagomenal day, Nut brings forth Nebet-Het (Nephthys) — guardian of thresholds, dusk, memory, and the quiet fields of the dead.
Her presence completes the divine family and seals the cycle of births.
Families lit soft lamps, burned fragrant oils, and poured water for ancestors.
Names were spoken aloud so none would be lost in the transition into the New Year.
Nebet-Het teaches that the unseen world sustains the visible one — memory is nourishment.
This day is soft, reflective, protective: a veil drawn gently across the closing year.
At dawn tomorrow, Sopdet will rise, and Thoth 1 will begin.
Tonight is the final breath of the old world.''',
    decanFlow: epagomenalIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'House-and-basket crest of Nebet-Het',
      colorFrequency: 'Indigo over silver',
      mantra: '"Nothing is lost when it is remembered."',
    ),
  ),

  // ==========================================================
  // 🌿 REKH-NEDJES I — DAYS 1–10  (First Decan - sꜣḥ)
  // ==========================================================

  'rekhnedjes_1_1': KemeticDayInfo(
    gregorianDate: 'September 16, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 1',
    season: '🌿 Peret — Season of Emergence',
    month: 'Rekh-Nedjes (Pa-Menoth) — "Lesser Knowing," applied wisdom under trial',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Endurance Is Divine',
    cosmicContext: '''Rekh-Nedjes opens with Orion standing like a backbone in the sky, reminding the Kemite that true strength is quiet and sustained.
This is the month when knowledge leaves the safety of scrolls and enters the frictions of real life.
The fields are no longer tender seedlings; they must endure heat, wind, and the weight of human feet.
In the myths, Asar (Osiris) has already risen — now the question is whether his followers can embody his steadiness.
Day 1 marks your entry as an apprentice of Ma'at: you are not tested to break, but to be tempered.
Every small task completed with calm is a prayer; every moment you stay centered under pressure is a hymn to Orion.
The heavens watch not for perfection, but for persistence.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Orion as a three-star belt forming a Djed-like spine in the southern sky',
      colorFrequency: 'Deep indigo night with silver-white points of light',
      mantra: '"My endurance is visible to heaven."',
    ),
  ),

  'rekhnedjes_2_1': KemeticDayInfo(
    gregorianDate: 'September 17, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 2',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes — Lesser Knowing, the month of the apprentice',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Patience Cuts Straighter than Force',
    cosmicContext: '''On Day 2, the lesson of Sah shifts from merely standing to aligning.
Farmers in Kemet waited for these stars to mark when to inspect dikes and furrows; fields drawn in haste wasted water, but fields aligned to the sky stayed fruitful.
So too in your life: the temptation is to push harder, louder, faster — but Rekh-Nedjes trains you to cut straighter through patience.
The apprentice watches first, acts second.
Today is about measuring your line: your tone, timing, spending, and exertion.
If Orion can cross the sky without rushing, so can you move through your tasks without violence.
Ma'at is preserved not by sudden force, but by quiet precision.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Straight measuring cord drawn beneath Orion\'s belt',
      colorFrequency: 'Steel grey against star-white',
      mantra: '"Patience is how I cut true."',
    ),
  ),

  'rekhnedjes_3_1': KemeticDayInfo(
    gregorianDate: 'September 18, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 3',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Honor the Practice',
    cosmicContext: '''By Day 3, the excitement of "starting" fades, and the soul meets the real work of repetition.
In Kemet, scribes copied the same lines again and again; farmers walked the same furrows; stonecutters chiseled the same angles until their hands knew the motion better than their minds.
This was not drudgery — it was devotion.
Rekh-Nedjes asks: can you treat your practice as sacred, even when nobody applauds and nothing "new" happens?
Orion returns every night without demanding surprise; its holiness lies in showing up.
Today, you bless your repetitions.
You choose one small act and perform it as if the gods themselves are watching — because in the Kemite mind, they are.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Repeated chisel strokes along a stone block beneath Orion',
      colorFrequency: 'Stone beige and starlight white',
      mantra: '"Practice is my prayer."',
    ),
  ),

  'rekhnedjes_4_1': KemeticDayInfo(
    gregorianDate: 'September 19, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 4',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Straighten What Has Bent',
    cosmicContext: '''Day 4 brings the corrective edge of Lesser Knowing.
By now, the apprentice has made small mistakes — uneven cuts, wasted effort, poorly timed decisions.
Kemet did not hide these; it adjusted.
Under the gaze of Sah, farmers walked their channels and mended each weak point before the next flood could exploit it.
Today is for honest review and gentle correction.
You are not asked to condemn yourself, only to admit where the line has bent away from Ma'at and to pull it back.
Straightening a schedule, a boundary, or a habit is a sacred act; it is how you tell the cosmos you can be trusted with more power.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A plumb line hanging straight beside a slightly bent reed',
      colorFrequency: 'Soft green of reeds with a line of pure white',
      mantra: '"I lovingly pull my life back into true."',
    ),
  ),

  'rekhnedjes_5_1': KemeticDayInfo(
    gregorianDate: 'September 20, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 5',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Carry the Weight Well',
    cosmicContext: '''By Day 5, the load of the month is fully on your shoulders.
The Kemite worker felt this in aching muscles; the scribe felt it in tired eyes.
Yet Orion shining over the desert taught that even a "small" cluster can bear a vast meaning.
Today is not about dropping burdens, but learning the art of carrying them without twisting your soul.
Pace, posture, and attitude all become spiritual matters.
You do not dramatize your load, nor do you pretend it is light.
You acknowledge it, breathe through it, and adjust how you move.
In this way, endurance becomes elegance — the grace of one who can hold much without losing form.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A worker bearing a balanced yoke beneath the stars of Orion',
      colorFrequency: 'Earth brown with a band of starlight silver',
      mantra: '"I learn the art of carrying."',
    ),
  ),

  'rekhnedjes_6_1': KemeticDayInfo(
    gregorianDate: 'September 21, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 6',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Listen While Working',
    cosmicContext: '''Day 6 turns endurance inward.
In the Coffin Texts, Thoth tells Horus that victory comes not from loudness but from a "patient heart" that hears Ma'at even in confusion.
As Sah glows through thin cloud, the Kemite understood that guidance is not always sharp and obvious.
Today you let insight emerge while your hands are busy.
You do not stop working to overthink; you keep moving and open your inner ear.
Often the clearest instructions from your higher self arrive in the middle of repetitive tasks.
Rekh-Nedjes trains you to recognize that voice and distinguish it from fear or pride.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Ear symbol beside a working hand under dim stars',
      colorFrequency: 'Soft blue-grey with muted silver',
      mantra: '"I hear Ma\'at while I move."',
    ),
  ),

  'rekhnedjes_7_1': KemeticDayInfo(
    gregorianDate: 'September 22, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 7',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Face the Heat of Trial',
    cosmicContext: '''Day 7 is the friction point.
Heat rises — in the air, in the body, in relationships.
Tools irritate the hand; repetitive tasks grate on the nerves.
In myth, this is when Set provokes, when tempers flare and the apprentice longs to throw down his work.
The wisdom of Rekh-Nedjes is to acknowledge the heat without becoming it.
Orion flickers but does not fall apart; its pattern holds even as the air trembles.
Your task today is to notice the stories your mind tells when things feel hard: "They don't appreciate me," "This will never end," "I can't do this."
You are not required to believe any of them.
You simply keep your form.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Flame rising beside the calm Djed-like pattern of Orion',
      colorFrequency: 'Ember red against dark blue',
      mantra: '"Heat reveals, but it does not rule me."',
    ),
  ),

  'rekhnedjes_8_1': KemeticDayInfo(
    gregorianDate: 'September 23, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 8',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Silent Mastery',
    cosmicContext: '''On Day 8, the grandeur of the constellation fades into normalcy.
The same pattern appears again in the sky, unannounced, steady.
This is the image of quiet excellence.
In the Kemite villages, the most respected artisans were not those who boasted, but those whose work simply never failed.
Rekh-Nedjes trains this quality into you: skill that does not need a spotlight.
Today you aim to do something exceptionally well with no announcement, no proof posted, no report filed unless necessary.
The reward is internal — the feeling that you and your craft are finally moving as one.
This is Lesser Knowing at its highest: not theory, but embodied competence.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A finished, flawless block of stone beneath Orion',
      colorFrequency: 'Smooth limestone white with faint blue shadow',
      mantra: '"My work speaks for me."',
    ),
  ),

  'rekhnedjes_9_1': KemeticDayInfo(
    gregorianDate: 'September 24, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 9',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Hold the Standard',
    cosmicContext: '''Day 9 is evaluation.
Priests and surveyors in Kemet checked their work against known stars; Sah was one of the primary measures.
Likewise, you are invited to compare your current rhythm to the standard you know is right for you — not to shame yourself, but to calibrate.
Lesser Knowing means you accept that you are still learning, yet you also refuse to pretend you don't know better when you do.
Where have your bedtimes slipped, your spending loosened, your rituals thinned out?
Under Orion's gaze, you calmly pull them back to the bar you've already set.
This is how apprentices become trustworthy artisans.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Measuring rod set beside Orion\'s upright pattern',
      colorFrequency: 'Dark sky indigo with a line of gold',
      mantra: '"I return to the standard I chose."',
    ),
  ),

  'rekhnedjes_10_1': KemeticDayInfo(
    gregorianDate: 'September 25, 2025',
    kemeticDate: 'Rekh-Nedjes I, Day 10',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'špsswt ("The Noble Ones")',
      starCluster: '✨ The Noble Ones — tested understanding.',
    maatPrinciple: 'Seal the Lesson of Endurance',
    cosmicContext: '''Day 10 completes the first trial of Rekh-Nedjes.
Sah's movement across the sky mirrors your own passage through these ten days: from intention to practice, from friction to quiet strength.
In Kemet, such cycles were always sealed — never left vague.
Scribes tallied grain; artisans signed their marks; priests closed rites with a final offering.
You are invited to do the same with your endurance work.
What did you discover about your patience, your pace, your posture under weight?
What one change will you refuse to let slip when the next decan begins?
In the theology of Ma'at, unsealed lessons leak away.
Sealed lessons become part of your Ka.''',
    decanFlow: rekhnedjesIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe\'s palette beneath Orion setting toward the west',
      colorFrequency: 'Sunset gold fading into deep blue',
      mantra: '"I seal endurance into my Ka."',
    ),
  ),

  // ==========================================================
  // 🌿 REKH-NEDJES II — DAYS 11–20  (Second Decan - sbꜣw)
  // ==========================================================

  'rekhnedjes_11_2': KemeticDayInfo(
    gregorianDate: 'September 26, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 11',
    season: '🌿 Peret — Season of Emergence',
    month: 'Rekh-Nedjes (Pa-Menoth) — "Lesser Knowing," applied wisdom under trial',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Seek the Elders',
    cosmicContext: '''Rekh-Nedjes now moves from solitary endurance to guidance.
As the scattered stars of sbꜣw rise, the priests spoke of a "council of light" — wise ones whose only throne is experience.
The Kemite knew that Lesser Knowing is not solved by more books, but by sitting near those who have walked the path longer.
Day 11 is the moment you stop pretending you must invent everything alone.
You look honestly at your life and ask: who already carries a pattern I respect?
A living elder, a long-gone ancestor, a writer, a builder, a farmer — any soul whose choices ring with Ma'at.
Today your task is simple and radical: admit you need teachers, and name them.
Stars are individual, but they shine in constellations; so do you.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Circle of small stars around a central guiding star',
      colorFrequency: 'Deep indigo with warm gold points of light',
      mantra: '"I find the lights who can shape me."',
    ),
  ),

  'rekhnedjes_12_2': KemeticDayInfo(
    gregorianDate: 'September 27, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 12',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Ask for Counsel',
    cosmicContext: '''Day 12 is when humility becomes action.
In Kemet, apprentices did not simply watch the master; they brought real questions at the end of the workday: "Where did I cut wrong? How do I correct this?"
Under sbꜣw, questions were a form of offering — proof that the student valued the elder's time.
Today you bring one sincere question about your path to a teacher: in conversation, in prayer, in writing to an ancestor, or by returning to a text that has never lied to you.
The key is honesty.
Lesser Knowing becomes Greater Knowing only when you risk being shown where you are off.
To ask is to open the gate; the stars cannot teach a closed heart.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Outstretched hand offering a small flame to a larger star',
      colorFrequency: 'Amber glow against midnight blue',
      mantra: '"I bring my real questions to real wisdom."',
    ),
  ),

  'rekhnedjes_13_2': KemeticDayInfo(
    gregorianDate: 'September 28, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 13',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Receive the Mirror',
    cosmicContext: '''Day 13 is the mirror you may not enjoy but deeply need.
Elders in Kemet did not flatter apprentices; they told the truth in simple sentences: "Your line is crooked. Your pace is wrong. Your attitude will cost you."
Under sbꜣw, such words were considered medicine, not insult.
Today your work is to accept feedback without instinctively defending, explaining, or shrinking.
Listen, write it down, and sit with it.
If several teachers — across years — have pointed to the same pattern in you, that pattern is real.
Ma'at is not offended by being seen; only ego is.
When you can stand still under a truthful mirror, you are ready for real transformation.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Eye sign above a polished mirror-disk',
      colorFrequency: 'Silver-white over dark violet',
      mantra: '"I let true reflections reach me."',
    ),
  ),

  'rekhnedjes_14_2': KemeticDayInfo(
    gregorianDate: 'September 29, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 14',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Apprentice in Action',
    cosmicContext: '''Day 14 is where talk becomes form.
In Kemet, an apprentice who nodded at instruction but changed nothing dishonored the craft.
The stars of sbꜣw do not merely shine suggestions; they expect response.
Today you take one concrete piece of counsel — recent or long-standing — and you obey it.
Adjust the budget the way your elder advised; structure your sleep the way your body has been begging; handle conflict the way the wise model has shown you.
The feeling of obedience may be awkward or even humbling, but it is also freeing.
You do not have to invent the road; you only have to walk it with care.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Pair of footsteps beneath a guiding star',
      colorFrequency: 'Earth brown with a single white-gold point',
      mantra: '"I honor wisdom by moving my feet."',
    ),
  ),

  'rekhnedjes_15_2': KemeticDayInfo(
    gregorianDate: 'September 30, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 15',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Refine the Craft',
    cosmicContext: '''By Day 15, the relationship with your teachers matures; they are no longer only correcting gross errors, but refining details.
In the workshops of Kemet, this was the stage where a master adjusted the way an apprentice held a chisel, breathed during a stroke, or planned a sequence of tasks.
Tiny shifts changed everything.
Today you invite that level of refinement into your main craft — creative, professional, relational, or bodily.
Under sbꜣw, you ask: what small adjustment would make my work more honest, more precise, more aligned with who I say I am?
In Lesser Knowing, such refinements are not vanity; they are devotion.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Fine chisel and straight edge beneath a star',
      colorFrequency: 'Cool stone grey with pinpoint starlight',
      mantra: '"I let wisdom sharpen my edge."',
    ),
  ),

  'rekhnedjes_16_2': KemeticDayInfo(
    gregorianDate: 'October 1, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 16',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Teach What You Know',
    cosmicContext: '''Day 16 turns the current around: you move from only receiving wisdom to becoming one of the lights in sbꜣw.
In Kemet, adolescents were given younger helpers to train; even a modest skill, once embodied, became a trust to pass on.
The reflection of star on water showed that true teaching is not perfection, but faithful echo.
Today you share one lesson you've actually lived — not theory — with someone earlier in the journey: a child, a peer, your own future self in a journal.
You do this not from ego but from gratitude.
Ma'at is preserved when each generation refuses to hoard its hard-won clarity.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Star above, same star reflected in water',
      colorFrequency: 'River blue with twin points of gold',
      mantra: '"What I know, I pass on."',
    ),
  ),

  'rekhnedjes_17_2': KemeticDayInfo(
    gregorianDate: 'October 2, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 17',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Tend the Lineage',
    cosmicContext: '''Day 17 widens the frame beyond personal mentors to the whole lineage that brought you here.
The Kemite looked up at the Milky Way and saw a celestial Nile carrying the blessed dead; each bright point was an ancestor or righteous soul.
Under sbꜣw, this meant that every lesson had roots beyond the present teacher.
Today you pause to honor that chain: the ones who survived long enough to teach your teachers, the ones whose names you'll never know who still kept the fire alive.
You might pour water, light a flame, or simply speak thanks.
Recognizing lineage keeps humility alive; it reminds you that you are not the source, only the latest link.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Flowing river line filled with tiny star-signs',
      colorFrequency: 'Milky white river across dark indigo',
      mantra: '"I am a child of a long light."',
    ),
  ),

  'rekhnedjes_18_2': KemeticDayInfo(
    gregorianDate: 'October 3, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 18',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Discern the Voices',
    cosmicContext: '''Not every bright thing in the sky is a trustworthy star; some are passing fires, some are illusions of the air.
Day 18 teaches discernment.
The Kemite knew that some "teachers" serve Ma'at, and some serve their own hunger.
Under sbꜣw, the rule was simple: true guidance leaves the heart clearer and more responsible; false guidance leaves it confused, inflated, or dependent.
Today you quietly review the voices that shape you — online, in your ear, in your bloodline.
Which ones consistently bring you back to order, honesty, and meaningful work?
Which ones pull you toward fantasy, chaos, or stagnation?
You are allowed to step back from any star that does not actually light your path.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'True star above; wavering flame crossed out beneath',
      colorFrequency: 'Clear white and steady gold contrasted with smoky red',
      mantra: '"I choose lights that leave me lucid."',
    ),
  ),

  'rekhnedjes_19_2': KemeticDayInfo(
    gregorianDate: 'October 4, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 19',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Choose Your Council',
    cosmicContext: '''Day 19 is selection.
The Kemite did not let just anyone speak into his destiny.
Even pharaohs kept a small circle of trusted advisors whose loyalty to Ma'at had been proven over years.
Under sbꜣw, you are invited to consciously decide: who are the few voices you will allow to shape your next season — in money, health, spirit, work, love?
Three, five, perhaps fewer — but chosen, not accidental.
This is not about elitism; it is about responsibility.
Your life is a vessel in the river of time; not everyone gets to hold the rudder.
Lesser Knowing ends when you stop letting random noise pilot you and invite a small, true council to sit close.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Triangle of three stars enclosed within a protective circle',
      colorFrequency: 'Bright gold within, deep blue around',
      mantra: '"I decide who may shape my course."',
    ),
  ),

  'rekhnedjes_20_2': KemeticDayInfo(
    gregorianDate: 'October 5, 2025',
    kemeticDate: 'Rekh-Nedjes II, Day 20',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'ḥry-ib špsswt ("Heart of the Noble Ones")',
      starCluster: '✨ Heart of the Noble Ones — adaptive refinement.',
    maatPrinciple: 'Seal the Teaching',
    cosmicContext: '''Day 20 closes the decan of counsel.
As sbꜣw leans toward the horizon, the Kemite understood that teachings must be sealed before they fade into vague memory.
Priests recorded oracular answers on papyrus; craftsmen scratched marks into stone to fix new techniques into their hands.
Today you gather what this decan has shown you about guidance, mentorship, and your place in the lineage.
You write down the counsel you are keeping, the teachers you have chosen, and the actions those choices require.
Anything not written, spoken into ritual, or embedded into a clear decision is treated as passing weather.
Ma'at respects what you are willing to formalize.''',
    decanFlow: rekhnedjesIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Scribe\'s palette beneath a row of small star-signs',
      colorFrequency: 'Ink black on parchment gold, dotted with white',
      mantra: '"I fix true teaching into my path."',
    ),
  ),

  // ==========================================================
  // 🌿 REKH-NEDJES III — DAYS 21–30  (Third Decan - ḫnt-sḥtp)
  // ==========================================================

  'rekhnedjes_21_3': KemeticDayInfo(
    gregorianDate: 'October 6, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 21',
    season: '🌿 Peret — Season of Emergence',
    month: 'Rekh-Nedjes (Pa-Menoth) — "Lesser Knowing," applied learning under trial',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Release the Strain',
    cosmicContext: '''With ḫnt-sḥtp, the month begins to exhale.
The contests of Horus and Set stand behind you; now comes the quiet work of easing what their struggle left tense.
In the fields, this was the time when hands unclenched from tools, shoulders unknotted, and farmers stood a moment just listening to the restored rhythm of water in the canals they had repaired.
Day 21 invites you to notice where you are still braced for impact — muscles locked, thoughts racing, schedule jammed — long after the danger has passed.
Lesser Knowing has taught you endurance and humility; Foremost of Peace teaches you trust.
To relax here is not laziness but obedience to Maʿat: you are not meant to live in permanent fight.
Today, you consciously soften one grip — a plan, a resentment, a pace — and let balance begin to re-enter your body.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Relaxed open hand beneath the Maʿat feather',
      colorFrequency: 'Pale sky blue over soft earth beige',
      mantra: '"I let tension leave so order can return."',
    ),
  ),

  'rekhnedjes_22_3': KemeticDayInfo(
    gregorianDate: 'October 7, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 22',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Repair the Breaks',
    cosmicContext: '''Peace is not only a feeling; it is structure repaired.
In Kemet, as Rekh-Nedjes closed, families walked the canal edges checking for small fissures, weak gates, or places where water might either leak away or flood unexpectedly.
Under ḫnt-sḥtp, this simple maintenance was considered prayer — a way of saying to Maʿat, "We take your balance seriously."
Day 22 asks you to pick one small but real crack in your world and mend it: a bill ignored, a boundary crossed, a tool broken, a commitment unclarified.
Lesser Knowing let you learn the hard way; Foremost of Peace lets you apply what you learned by quietly fixing what you once allowed to remain fractured.
This is how rest becomes safe instead of fragile.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Cracked line sealed by a small Maʿat feather at the gap',
      colorFrequency: 'Clay brown with a narrow band of bright white-gold',
      mantra: '"I mend what keeps peace from holding."',
    ),
  ),

  'rekhnedjes_23_3': KemeticDayInfo(
    gregorianDate: 'October 8, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 23',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Clean the Tools',
    cosmicContext: '''By the end of Rekh-Nedjes, fields were less demanding, but the work did not stop; it shifted inward.
Farmers and craftsmen cleaned and sharpened their tools, oiled wooden handles, and stored blades in order.
This was not mere tidiness; a dull tool wastes strength and invites injury.
Under ḫnt-sḥtp, such care became a form of gratitude for the work already done and the work yet to come.
Day 23 asks you to turn toward the instruments that carry your daily power — your body, your digital devices, your kitchen, your creative tools — and treat them as sacred.
Wash, organize, sharpen, update.
Peace is easier to keep when what you rely on is ready.
Kemet knew: a clean tool is a quiet blessing.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Knife-blade with droplets of water above and a small spark at the tip',
      colorFrequency: 'Steel grey with clear water white and a point of gold',
      mantra: '"I keep my instruments worthy of my work."',
    ),
  ),

  'rekhnedjes_24_3': KemeticDayInfo(
    gregorianDate: 'October 9, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 24',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Reconcile Within',
    cosmicContext: '''The disputes of Horus and Set were not only between gods; they were mirrors of the inner struggle between impulse and restraint, pride and humility, hurt and duty.
ḫnt-sḥtp closes that story by showing the sky relaxed and even — no side brighter than the other.
Day 24 turns this myth inward.
Where in you are two voices still fighting?
Perhaps one part demands revenge while another longs for release; one part clings to an old identity while another is already changing.
In Kemet, healing rites often involved naming the conflicting parts aloud and asking the gods to "bind the heart in one."
Today, you do the same: you tell yourself the truth about your divided intentions and choose a single, honest story to live from.
Inner peace is not fog; it is alignment.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two hearts or lungs facing each other with a single feather between them',
      colorFrequency: 'Soft green and rose with a central line of white',
      mantra: '"I let my inner voices agree on one truth."',
    ),
  ),

  'rekhnedjes_25_3': KemeticDayInfo(
    gregorianDate: 'October 10, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 25',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Reconcile With Others',
    cosmicContext: '''The trials of Horus and Set did not end in endless war; they ended in a negotiated order.
Maʿat demanded not the fantasy of no conflict, but the reality of restored proportion.
Under ḫnt-sḥtp, the people of Kemet took this seriously: harvest-tired but heart-awake, they chose certain evenings to mend quarrels, forgive debts, or at least lay down weapons of the tongue.
Day 25 asks you to take one step — not all steps — toward peace with someone where tension still hums.
A message, a boundary spoken calmly instead of in anger, an apology for your share, a decision to stop rehearsing their offense in your mind.
Maʿat does not require you to embrace danger; she does invite you to relieve what can be relieved, for your own spirit's sake.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Two outstretched hands meeting around a small Maʿat feather',
      colorFrequency: 'Warm sand and gentle gold with a hint of soft blue',
      mantra: '"I move my relationships one step closer to balance."',
    ),
  ),

  'rekhnedjes_26_3': KemeticDayInfo(
    gregorianDate: 'October 11, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 26',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Stabilize the Rhythm',
    cosmicContext: '''By now, the month has shown its lesson: knowing is nothing without endurance, and endurance is nothing without a rhythm the body and spirit can survive.
In Kemet, this phase meant adjusting the daily cycle to something sustainable after the surges of planting and repair.
Wake, work, rest, eat, pray, play — not as chaos but as measured sequence.
Under ḫnt-sḥtp, you are invited to look at your current pattern with honest eyes.
Are you sleeping enough to hear Maʿat?
Are you working in a way that leaves any room for joy?
Day 26 is not about perfection; it's about choosing a tempo you can keep.
Peace is not found in dramatic sprints; it is found in a stride that does not betray you.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Repeating wave or drum-beat marks beneath a small sun disk',
      colorFrequency: 'Soft gold pulses over muted blue-grey',
      mantra: '"I choose a pace that protects my peace."',
    ),
  ),

  'rekhnedjes_27_3': KemeticDayInfo(
    gregorianDate: 'October 12, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 27',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Honor Quiet Victories',
    cosmicContext: '''Not all miracles are loud.
Lesser Knowing has asked you to keep walking under imperfect conditions; Foremost of Peace now asks you to recognize what that walk has built in you.
In Kemet, families in this phase of the month would sit together and recount the season's simple successes: a field that did not fail, a sickness survived, a child's new skill, a quarrel that did not become war.
These were written not on papyrus but on the heart.
Day 27 invites you to do the same: list the small, easily dismissed ways you have endured and grown.
Naming them does not make you arrogant; it makes you truthful.
Maʿat is honored when reality — including your quiet strength — is fully seen.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Small notches or tally marks beside a discreet Maʿat feather',
      colorFrequency: 'Soft parchment gold with fine ink-black lines',
      mantra: '"I acknowledge the strength I usually hide."',
    ),
  ),

  'rekhnedjes_28_3': KemeticDayInfo(
    gregorianDate: 'October 13, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 28',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Simplify the Load',
    cosmicContext: '''As Rekh-Nedjes closes, the people of Kemet did not add more; they pared back.
Excess tools were stored, unnecessary tasks dropped, and households quietly decided which ambitions would not cross into the next phase.
This was not defeat; it was wisdom.
ḫnt-sḥtp teaches that peace often arrives not by gaining more, but by releasing what no longer serves Maʿat.
Day 28 asks you to lay down one weight — a possession, a habit, an obligation, even a story about yourself — that drains your energy without honoring your purpose.
In a sky too crowded with demands, no star can be properly seen.
Simplifying is how you make room for the right light.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Basket with one item being lifted out and a feather remaining inside',
      colorFrequency: 'Muted earth tones with a single clear white accent',
      mantra: '"I release what keeps my peace from breathing."',
    ),
  ),

  'rekhnedjes_29_3': KemeticDayInfo(
    gregorianDate: 'October 14, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 29',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Prepare for the Crossing',
    cosmicContext: '''On the penultimate day of Rekh-Nedjes, the Kemite looked ahead.
The sky signaled transition; the gentle, steady stars of ḫnt-sḥtp drew closer to the earth's edge, hinting at the coming shift into Renwet.
Practically, this meant gathering records, tying up small obligations, and arranging spaces so the next phase would not begin in chaos.
Day 29 is your administrative devotion.
You file, you list, you clear surfaces, you finalize what can be finished.
If the year were to turn tonight — and in the great cycles, it soon will — what would you want already in order?
Peace does not arrive to a scattered table; it comes where there is room set aside for it.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Doorway sign with a small bundle neatly placed at its base',
      colorFrequency: 'Threshold stone grey with a band of soft gold at the edge',
      mantra: '"I set my affairs in order before I cross."',
    ),
  ),

  'rekhnedjes_30_3': KemeticDayInfo(
    gregorianDate: 'October 15, 2025',
    kemeticDate: 'Rekh-Nedjes III, Day 30',
    season: '🌿 Peret',
    month: 'Rekh-Nedjes',
      decanName: 'sbꜣ špsswt ("Star of the Noble Ones")',
      starCluster: '✨ Star of the Noble Ones — quiet, proven competence.',
    maatPrinciple: 'Rest in Maʿat',
    cosmicContext: '''The month of Lesser Knowing ends not with a test, but with a Sabbath.
Orion (Sah) taught you endurance; sbꜣw taught you to seek and honor teachers; ḫnt-sḥtp now teaches you to stop.
In Kemet, the final day of such a phase often meant shortened work, extended shade, and slow meals.
People trusted that the canals would hold, the tools would be ready, and the gods would not punish them for ceasing.
Day 30 is a vow that you are more than your output.
You practice rest as an offering to Maʿat — proof that you understand the world is upheld by a balance far larger than your individual effort.
Close what can be closed, then sit, lie down, or walk gently without agenda.
Let your body believe that peace is not a brief accident but a rightful state.''',
    decanFlow: rekhnedjesIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'Reclining figure beneath the Maʿat feather and a small sun set low on the horizon',
      colorFrequency: 'Dusk lavender with a soft band of gold',
      mantra: '"My stillness also serves the balance."',
    ),
  ),
  };

  static KemeticDayInfo? getInfoForDay(String dayKey) {
    return dayInfoMap[dayKey];
  }

  /// Month key override map.
  /// IMPORTANT: Keep in sync with the override map in day_key.dart.
  static const Map<int, String> _monthKeyOverride = {
    2:  'paophi',
    5:  'sefbedet',
    10: 'henti',
    11: 'ipt',
    12: 'mswtRa',
  };

  /// Parses a dayKey to extract (month, day, year?).
  /// Handles:
  /// - "epagomenal_1_1"
  /// - "epagomenal_1_2026"
  /// - "<monthKey>_<day>_<decan>"
  static ({int month, int day, int? year})? _parseDayKey(String dayKey) {
    // Epagomenal days
    if (dayKey.startsWith('epagomenal_')) {
      final parts = dayKey.split('_'); // epagomenal, <day>, [year]
      if (parts.length >= 2) {
        final day = int.tryParse(parts[1]);
        if (day != null && day >= 1 && day <= 6) {
          final int? yearFromKey =
              parts.length >= 3 ? int.tryParse(parts[2]) : null;
          return (month: 13, day: day, year: yearFromKey);
        }
      }
      return null;
    }

    // Regular format: "<monthKey>_<day>_<decan>"
    final parts = dayKey.split('_');
    if (parts.length < 2) return null;

    final monthKey = parts[0];
    final dayStr = parts[1];
    final day = int.tryParse(dayStr);
    if (day == null || day < 1 || day > 30) return null;

    // Reverse lookup month ID from monthKey
    // First check override map
    final overrideEntry = _monthKeyOverride.entries.firstWhere(
      (e) => e.value == monthKey,
      orElse: () => const MapEntry(0, ''),
    );
    if (overrideEntry.key != 0) {
      return (month: overrideEntry.key, day: day, year: null);
    }

    // Then fall back to "real" month metadata
    for (int monthId = 1; monthId <= 12; monthId++) {
      final month = getMonthById(monthId);
      if (month.key == monthKey) {
        return (month: monthId, day: day, year: null);
      }
    }

    return null;
  }

  /// Calculates the Gregorian date label for a given dayKey.
  ///
  /// - Uses year embedded in the key if present (epagomenal_1_2026),
  ///   otherwise falls back to [kYearParam], otherwise 1.
  /// - Handles leap years via KemeticMath.toGregorian().
  /// - Treats the result as a pure calendar date (no local timezone shifting).
  static String calculateGregorianDate(
    String dayKey, {
    int? kYearParam,
  }) {
    final parsed = _parseDayKey(dayKey);
    if (parsed == null) {
      return 'Unknown Date';
    }

    final int kMonth = parsed.month;
    final int kDay = parsed.day;

    // Choose a year: from key → from param → default 1
    final int kYear = (parsed.year ?? kYearParam ?? 1);
    if (kYear < 1) {
      return 'Invalid Year';
    }

    // Validate day ranges
    if (kMonth == 13) {
      // Epagomenal month
      final maxEpi =
          KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;
      if (kDay < 1 || kDay > maxEpi) {
        return 'Invalid Epagomenal Day';
      }
    } else {
      // Regular months
      if (kDay < 1 || kDay > 30) {
        return 'Invalid Day';
      }
    }

    try {
      // This returns a UTC DateTime corresponding to the Kemetic date.
      final DateTime gregorianUtc =
          KemeticMath.toGregorian(kYear, kMonth, kDay);

      // 🔑 KEY FIX:
      // For day cards, we only care about the calendar date,
      // not the local-time shift. Strip the time/zone.
      final DateTime dateOnly = DateTime(
        gregorianUtc.year,
        gregorianUtc.month,
        gregorianUtc.day,
      );

      return _formatGregorianDateString(dateOnly);
    } catch (_) {
      return 'Date Calculation Error';
    }
  }

  /// Formats a DateTime as "Month Day, Year" (e.g., "March 20, 2025").
  static String _formatGregorianDateString(DateTime date) {
    const monthNames = <String>[
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

    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Dropdown card widget for displaying Kemetic day information
class KemeticDayDropdown extends StatelessWidget {
  final KemeticDayInfo dayInfo;
  final VoidCallback onClose;
  final String? dayKey;
  final int? kYear;

  const KemeticDayDropdown({
    Key? key,
    required this.dayInfo,
    required this.onClose,
    this.dayKey,
    this.kYear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.85;
    
    // Calculate the date string
    final String gregorianDateString =
        (dayKey != null)
            ? KemeticDayData.calculateGregorianDate(
                dayKey!,
                kYearParam: kYear,
              )
            : dayInfo.gregorianDate; // fallback
    
    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF000000), // True black background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFC9A961), // Richer gold border
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF000000), // True black header
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0xFFC9A961), // Richer gold divider
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '☀️ Kemetic Date Alignment',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC9A961), // Richer gold color
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFC9A961)),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Flexible(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection('Gregorian Date:', gregorianDateString),
                      _buildInfoSection('Kemetic Date:', dayInfo.kemeticDate),
                      _buildInfoSection('Season:', dayInfo.season),
                      _buildInfoSection('Month:', dayInfo.month),
                      _buildInfoSection('Decan Name:', dayInfo.decanName),
                      _buildInfoSection('Star Cluster:', dayInfo.starCluster),
                      _buildInfoSection('Ma\'at Principle:', dayInfo.maatPrinciple),
                      const SizedBox(height: 20),
                      _buildSectionHeader('△ Cosmic Context'),
                      const SizedBox(height: 8),
                      Text(
                        dayInfo.cosmicContext,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFCCCCCC),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('▽ Decan Flow'),
                      const SizedBox(height: 12),
                      _buildDecanFlowTable(context),
                      const SizedBox(height: 24),
                      _buildSectionHeader('▽ Medu Neter Key'),
                      const SizedBox(height: 12),
                      _buildMeduNeterSection(context),
                      const SizedBox(height: 8), // Bottom padding
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFC9A961), // Richer gold for labels
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFC9A961), // Richer gold
      ),
    );
  }

  Widget _buildDecanFlowTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3A3A3A)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF000000), // True black background
      ),
      child: Column(
        children: [
          // Table Header Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFF3A3A3A), width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'Day',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC9A961),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Theme',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC9A961),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Action',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC9A961),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Reflection',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC9A961),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Data Rows
          ...dayInfo.decanFlow.map((day) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF3A3A3A),
                    width: day == dayInfo.decanFlow.last ? 0 : 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Column
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC9A961),
                      ),
                    ),
                  ),
                  // Theme Column
                  Expanded(
                    flex: 2,
                    child: Text(
                      day.theme,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Action Column
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        day.action,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
                  ),
                  // Reflection Column
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        day.reflection,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMeduNeterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
              children: [
                const TextSpan(
                  text: '• Glyph: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC9A961), // Richer gold
                  ),
                ),
                TextSpan(text: dayInfo.meduNeter.glyph),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
              children: [
                const TextSpan(
                  text: '• Color Frequency: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC9A961), // Richer gold
                  ),
                ),
                TextSpan(text: dayInfo.meduNeter.colorFrequency),
              ],
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
            children: [
              const TextSpan(
                text: '• Mantra: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC9A961), // Richer gold
                ),
              ),
              TextSpan(text: dayInfo.meduNeter.mantra),
            ],
          ),
        ),
      ],
    );
  }
}

/// Controller/Service for managing the dropdown overlay
class KemeticDayDropdownController {
  OverlayEntry? _overlayEntry;
  
  // Dropdown width constant - good fit for mobile screens
  static const double dropdownWidth = 340;

  void show({
    required BuildContext context,
    required String dayKey,
    required Offset buttonPosition,
    required Size buttonSize,
    int? kYear,
  }) {
    hide(); // Hide any existing overlay

    final dayInfo = KemeticDayData.getInfoForDay(dayKey);
    
    if (dayInfo == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        return Stack(
          children: [
            // Background tap-to-dismiss
            GestureDetector(
              onTap: hide,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black54),
            ),
            // Dropdown centered horizontally, positioned below pressed date
            Positioned(
              // Center horizontally
              left: (screenWidth / 2) - (dropdownWidth / 2),
              // Keep vertical logic consistent (appears below pressed date)
              top: buttonPosition.dy + buttonSize.height + 8,
              child: SizedBox(
                width: dropdownWidth,
                child: KemeticDayDropdown(
                  dayInfo: dayInfo,
                  dayKey: dayKey,
                  kYear: kYear,
                  onClose: hide,
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// Button widget that shows the dropdown on long press
class KemeticDayButton extends StatefulWidget {
  final Widget child;
  final String dayKey;
  final int? kYear;

  const KemeticDayButton({
    Key? key,
    required this.child,
    required this.dayKey,
    this.kYear,
  }) : super(key: key);

  @override
  State<KemeticDayButton> createState() => _KemeticDayButtonState();
}

class _KemeticDayButtonState extends State<KemeticDayButton> {
  final KemeticDayDropdownController _controller = KemeticDayDropdownController();
  final GlobalKey _buttonKey = GlobalKey();

  void _showDropdown() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _controller.show(
      context: context,
      dayKey: widget.dayKey,
      kYear: widget.kYear,
      buttonPosition: position,
      buttonSize: size,
    );
  }

  @override
  void dispose() {
    _controller.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onLongPress: _showDropdown,
      child: widget.child,
    );
  }
}

































































