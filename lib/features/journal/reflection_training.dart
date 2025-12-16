/// Training guidance and exemplar reflections for the decan reflection generator.
/// This is intended to be fed to an LLM alongside the current badge/context
/// data so the model can stay on-tone and concise.

class ReflectionSample {
  final String decan;
  final List<String> badges;
  final String text;

  const ReflectionSample({
    required this.decan,
    required this.badges,
    required this.text,
  });
}

/// Instruction template the model should follow.
const String reflectionPromptTemplate = '''
Given: decan name, badge count, and a list of badge titles (with day numbers), write a decan reflection.
Structure:
1) “You saved N badge(s).”
2) Summarize marked badges by name (cap at 5; otherwise say “+N more”).
3) State how the badges connect to the decan’s theme.
4) Close with an invitation: what unmarked days imply.
Tone: concise, Kemetic, reverent, present tense, no fluff. Avoid generic therapy language.
''';

/// High-quality exemplars the model can pattern-match against.
const List<ReflectionSample> reflectionSamples = [
  ReflectionSample(
    decan: 'Renwet II',
    badges: ['Day 12 — Weigh the Heart', 'Day 14 — Correct the Imbalance', 'Day 15 — Protect the Innocent'],
    text:
        'You saved 3 badges. You weighed the heart, corrected imbalance, and protected the innocent. Each mark shows you repairing abundance with honesty, action, and defense of the vulnerable. What stays unmarked is an invitation to finish the repairs you promised.',
  ),
  ReflectionSample(
    decan: 'Renwet III',
    badges: ['Day 23 — Bless the Tools', 'Day 24 — Close the Ledger', 'Day 27 — Return to Silence'],
    text:
        'You saved 3 badges. Blessing tools, closing the ledger, and returning to silence braid this decan together: respect what carried you, account for what was given and spent, and quiet the noise. What remains unmarked is the gap between duty and rest.',
  ),
  ReflectionSample(
    decan: 'Hnsw I',
    badges: ['Day 2 — Carry the Light', 'Day 5 — Move With Offering', 'Day 9 — Record the Day’s Distance'],
    text:
        'You saved 3 badges. You carried the light, moved with offering, and recorded your distance. Travel is not drift; it’s measured, generous, and accountable. Unmarked days are routes still waiting for witness.',
  ),
  ReflectionSample(
    decan: 'Hnsw II',
    badges: ['Day 13 — Keep Measure', 'Day 15 — Honor the Exchange', 'Day 18 — Check for Poison'],
    text:
        'You saved 3 badges. You kept measure, honored the exchange, and checked for poison. This decan asks you to guard integrity while in motion. What you did not mark may be where leaks or hidden costs remain.',
  ),
  ReflectionSample(
    decan: 'Ḥenti-ḥet I',
    badges: ['Day 3 — Guard the Breath', 'Day 6 — Shade the Vulnerable', 'Day 10 — Seal the Morning Oath'],
    text:
        'You saved 3 badges. You guarded breath, shaded the vulnerable, and sealed your oath. In the heat, calm breath, shelter, and vow keep proportion. Unmarked days are places to cool what still runs too hot.',
  ),
  ReflectionSample(
    decan: 'Rekh-Wer II',
    badges: ['Day 11 — Great Knowing', 'Day 14 — Repair Harm', 'Day 19 — Hold Still in the Blaze'],
    text:
        'You saved 3 badges. You named what you know, repaired harm, and held still under heat. Knowledge, repair, and composure form the spine of this decan. What stays unmarked is where truth still needs practice.',
  ),
  ReflectionSample(
    decan: 'Rekh-Nedjes III',
    badges: ['Day 21 — Ease the Pace', 'Day 24 — Guard the Core', 'Day 29 — Return to Center'],
    text:
        'You saved 3 badges. You eased the pace, guarded the core, and returned to center. Lesser knowing is refined by restraint, focus, and coming home. Unmarked space is room to rest without apology.',
  ),
];
