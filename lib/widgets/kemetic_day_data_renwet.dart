part of 'kemetic_day_info.dart';

// Sole authored source for all 30 Renwet cards and reflection questions.
// Final v2 copy: Return → Distribution → Stability, within Peret.
// Gregorian dates are resolved from the day key and Kemetic year.

final List<DecanDayInfo> _renwetIFlowRows = [
  DecanDayInfo(
    day: 1,
    theme: 'Now It Needs a Decision',
    action: 'When the waiting has done its work, act; delay adds nothing now.',
    reflection: '"What is ready, and only waiting on me to decide?"',
  ),
  DecanDayInfo(
    day: 2,
    theme: 'Less Lost Is a Gain',
    action:
        'Count what no longer goes to waste before calling it a poor return.',
    reflection: '"Where is my real gain that less is being lost?"',
  ),
  DecanDayInfo(
    day: 3,
    theme: 'One Patch Isn\'t the Whole',
    action: 'Understand the bad part; do not let it stand for the whole.',
    reflection: '"What one failure am I letting judge everything?"',
  ),
  DecanDayInfo(
    day: 4,
    theme: 'Finish What\'s in Front',
    action: 'Finish what is already down before bringing in more.',
    reflection: '"What waiting thing should I finish before starting another?"',
  ),
  DecanDayInfo(
    day: 5,
    theme: 'Ready Beats Perfect',
    action: 'Let a thing be useful; stop improving what is already ready.',
    reflection: '"What am I polishing that is already good enough to use?"',
  ),
  DecanDayInfo(
    day: 6,
    theme: 'Proven by Use',
    action: 'Put the unfinished-looking thing to use; let it prove itself.',
    reflection: '"What am I hiding that would hold up if I tried it?"',
  ),
  DecanDayInfo(
    day: 7,
    theme: 'Cut Isn\'t Finished',
    action: 'Do the work still between what you have and what can serve.',
    reflection: '"What still stands between having this and using it?"',
  ),
  DecanDayInfo(
    day: 8,
    theme: 'Count Before You Promise',
    action: 'Count the whole before promising from one good result.',
    reflection: '"What am I promising on one good result alone?"',
  ),
  DecanDayInfo(
    day: 9,
    theme: 'Some Is for Today',
    action: 'Stop for the thing the work was partly for.',
    reflection: '"What worth stopping for am I rushing past today?"',
  ),
  DecanDayInfo(
    day: 10,
    theme: 'Not Yet a Promise',
    action: 'Count what is truly yours before answering a request.',
    reflection: '"What am I being asked to give before I\'ve counted it?"',
  ),
];

final List<DecanDayInfo> _renwetIIFlowRows = [
  DecanDayInfo(
    day: 11,
    theme: 'Debt Before Gift',
    action: 'Repay what made the good year possible before you give gifts.',
    reflection: '"What debt am I celebrating past instead of settling?"',
  ),
  DecanDayInfo(
    day: 12,
    theme: 'Keep the Need in View',
    action:
        'Hold the real need in mind, and the tempting offer loses its pull.',
    reflection: '"What was this for, before the better offer appeared?"',
  ),
  DecanDayInfo(
    day: 13,
    theme: 'Ask What Helps',
    action:
        'Give the help the person actually needs, not the help you brought.',
    reflection: '"Am I offering what helps, or only what\'s easy to give?"',
  ),
  DecanDayInfo(
    day: 14,
    theme: 'Say the Unsaid Part',
    action: 'Name the expectation aloud before it strains the bond.',
    reflection: '"What am I leaving unsaid that should be agreed?"',
  ),
  DecanDayInfo(
    day: 15,
    theme: 'A Feast Is Their Work Too',
    action: 'Get the agreement of the hands that will carry out your plan.',
    reflection: '"Whose work am I promising without asking them?"',
  ),
  DecanDayInfo(
    day: 16,
    theme: 'Let the Gift Be Theirs',
    action: 'Let the one you gave to decide what the gift becomes.',
    reflection: '"Where am I still ruling a gift I already gave?"',
  ),
  DecanDayInfo(
    day: 17,
    theme: 'Each Brings Their Own',
    action: 'Trade what you do well for what another does well.',
    reflection: '"What do I do well that could meet another\'s gap?"',
  ),
  DecanDayInfo(
    day: 18,
    theme: 'Count Unwatched Work',
    action: 'Count the work finished before anyone arrived to see it.',
    reflection: '"Whose unwatched work am I about to overlook?"',
  ),
  DecanDayInfo(
    day: 19,
    theme: 'Listen for the Mistake',
    action: 'Let the complaint finish; past generosity hides present errors.',
    reflection: '"What am I defending instead of checking?"',
  ),
  DecanDayInfo(
    day: 20,
    theme: 'Give Some Back',
    action: 'Return a part of what you could not have grown alone.',
    reflection: '"What part of this should leave my hands in thanks?"',
  ),
];

final List<DecanDayInfo> _renwetIIIFlowRows = [
  DecanDayInfo(
    day: 21,
    theme: 'Let the Saved Be Spent',
    action: 'Let what you set aside for a need actually meet it.',
    reflection: '"What am I hoarding past the need it was saved for?"',
  ),
  DecanDayInfo(
    day: 22,
    theme: 'Keep Back the Seed',
    action:
        'Hold back what the next beginning will need from today\'s appetite.',
    reflection: '"What must I protect now for a start not yet here?"',
  ),
  DecanDayInfo(
    day: 23,
    theme: 'Fix It Once',
    action: 'Set the recurring thing in order once, for everyone.',
    reflection: '"What small problem are we solving again every day?"',
  ),
  DecanDayInfo(
    day: 24,
    theme: 'Clear One Corner',
    action: 'Finish one small part so the whole mess turns workable.',
    reflection: '"What one corner could I actually finish today?"',
  ),
  DecanDayInfo(
    day: 25,
    theme: 'More Than Their Work',
    action: 'Keep a person\'s place even when they cannot work this week.',
    reflection: '"Whose place am I measuring only by their output?"',
  ),
  DecanDayInfo(
    day: 26,
    theme: 'Able to Run Without You',
    action: 'Share what you know, so things can go on while you\'re away.',
    reflection: '"What would stall if I stepped away tomorrow?"',
  ),
  DecanDayInfo(
    day: 27,
    theme: 'Keep the Freed Time',
    action: 'Let time your work earned stay free, not refilled with work.',
    reflection: '"What freed time am I about to hand back to work?"',
  ),
  DecanDayInfo(
    day: 28,
    theme: 'Tend the Ground',
    action: 'Care for what fed you; it will be asked again next year.',
    reflection: '"What that sustained me still needs tending after the gain?"',
  ),
  DecanDayInfo(
    day: 29,
    theme: 'Can\'t Pack Every Worry',
    action: 'Prepare what the journey needs; stop packing against every fear.',
    reflection: '"What am I over-packing out of worry, not need?"',
  ),
  DecanDayInfo(
    day: 30,
    theme: 'Leave It Able to Stand',
    action: 'Leave the next beginning something steady to stand on.',
    reflection: '"What have I built that can go on without me?"',
  ),
];

final Map<String, KemeticDayInfo> _renwetDayInfoMap = {
  'renwet_1_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 1 (Day 1 of Renwet)',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'Patience Brought the Work This Far; Now It Asks for a Decision',
    cosmicContext:
        '''The grain that was still soft in Rekh-Nedjes is firm now under the thumbnail. The Kemite checks a second head, a third, then calls the son for the baskets. The readiness they waited all season for has come — and leaving it standing another day would not add to it.

Patience brought the work this far. Now it asks for a decision.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A ripe head tested under the thumbnail, the baskets called for',
      colorFrequency:
          'A season\'s waiting arriving at the moment it must be acted on',
      mantra: '"When the waiting has done its work, I decide."',
    ),
  ),

  'renwet_2_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 2',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'Sometimes the Gain Is Not More Arriving, but Less Being Lost',
    cosmicContext:
        '''The gathered pile looks smaller than hoped, and the first thought is a poor year. Then the daughter sets down the basket that last year came back half-spoiled — this year it is sound to the bottom. Nothing rotted in the drying. The Kemite counts again before calling it a bad harvest.

Sometimes the gain is not more arriving. It is less being lost on the way.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A basket sound to the bottom where last year\'s came back spoiled',
      colorFrequency:
          'A smaller pile that is whole, measured against a larger one that rotted',
      mantra:
          '"I count what no longer goes to waste before I call it a poor return."',
    ),
  ),

  'renwet_3_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 3',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'One Bad Patch Asks to Be Understood, Not to Stand for the Whole',
    cosmicContext:
        '''One strip gives almost nothing, and for a moment the Kemite calls the whole season a failure. Then comes a walk back to it: silt has choked the water channel here, nowhere else. The spot is marked to repair. Every other row has filled its baskets.

One bad patch asks to be understood, not to stand in for the whole.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A silt-choked channel marked for repair while the other rows stand full',
      colorFrequency:
          'One thin strip understood for its cause, the full rows kept in view',
      mantra:
          '"I understand the bad part instead of letting it judge the whole."',
    ),
  ),

  'renwet_4_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 4',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple: 'Bringing in More Is Not Always the Next Thing',
    cosmicContext:
        '''A fresh basket waits at the courtyard gate, and the Kemite's hands go to it first. Then across the yard is the wife, turning grain on mats already crowded, the low autumn sun too weak to dry a deeper pile. The new basket is left; the grain already down gets finished.

Bringing in more is not always the next thing. Sometimes it is finishing what you already have.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A fresh basket set aside to finish grain already drying on crowded mats',
      colorFrequency:
          'A weak autumn sun that cannot dry more than is already down',
      mantra:
          '"I finish what is already in front of me before I bring in more."',
    ),
  ),

  'renwet_5_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 5',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple: 'Past a Point, Improving a Thing Only Delays Its Use',
    cosmicContext:
        '''The storage jar is done, but the potter keeps the wheel turning for one more painted band. A woman stands waiting with grain that needs a home before nightfall. The potter looks at the rim once more, sets the brush down, and hands the jar over.

Past a point, improving a thing only delays its use. Ready and useful beats perfect and waiting.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A finished jar handed over instead of given one more painted band',
      colorFrequency: 'A brush set down so the vessel can finally do its work',
      mantra:
          '"I let a thing be useful instead of improving it past the point of need."',
    ),
  ),

  'renwet_6_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 6',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'A Thing Shows Its Worth in Use, Not in How It Looks Untried',
    cosmicContext:
        '''The son hides the basket he wove behind the wall — the rim came out crooked and he is ashamed of it. The Kemite fills it with grain to test it; the bindings hold fast. When a neighbor needs one for gathering, the boy carries his own out to lend.

A thing shows its worth in use, not in how it looks before anyone has tried it.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A crooked-rimmed basket filled with grain, its bindings holding fast',
      colorFrequency:
          'A thing judged by what it carries, not by how its edge looks',
      mantra:
          '"I put the unfinished-looking thing to use, and let it prove itself."',
    ),
  ),

  'renwet_7_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 7',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'Having Something in Hand Is Not the Same as Having Something That Can Serve',
    cosmicContext:
        '''The last basket thumps down by the door and the son says the harvest is done. The Kemite lifts a bundle and carries it to the threshing floor instead. Cut grain is not yet food — it still has to be threshed, winnowed, and ground before it is bread.

Having something in hand is not the same as having something that can serve.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A bundle carried on to the threshing floor, the harvest not yet food',
      colorFrequency:
          'Cut grain still owing threshing, winnowing, and grinding before bread',
      mantra: '"I do the work still between what I have and what can serve."',
    ),
  ),

  'renwet_8_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 8',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'One Good Result Is Worth Enjoying; a Bigger Promise Needs the Whole Picture',
    cosmicContext:
        '''One tree fills three baskets, and the mind is already on a second plot, more land, a bigger year. Then the next tree gives barely one. Before promising anyone more, the Kemite counts the whole harvest together — and the hands it took to bring in.

One good result is worth enjoying. A bigger promise needs the whole picture first.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'Three baskets from one tree, barely one from the next, counted together',
      colorFrequency:
          'A best result set honestly beside the lean ones before any promise',
      mantra: '"I count the whole before I promise from one good result."',
    ),
  ),

  'renwet_9_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 9',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'There Can Be More to Do and Still Something Worth Stopping For Today',
    cosmicContext:
        '''Steam rises as the wife breaks the first loaf from the new grain. The Kemite opens to speak of tomorrow's gathering — then takes the warm piece she holds out and eats it with her while it lasts. For months, this was part of what the work was for.

There can be more to do and still something worth stopping for today.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'The first warm loaf of new grain shared before the talk of tomorrow',
      colorFrequency:
          'Steam off new bread, a moment the whole season was partly for',
      mantra: '"I stop for the thing the work was partly for."',
    ),
  ),

  'renwet_10_1': KemeticDayInfo(
    kemeticDate: 'Renwet I, Day 10',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ꜥpdw ("The Birds")',
    starCluster:
        '✨ ꜥpdw — the Birds, the stars of this group, watched through this ten-day interval.',
    maatPrinciple:
        'Having Something Does Not Mean Every Request Must Be Answered on the Spot',
    cosmicContext:
        '''A cousin asks for grain for a feast before the last basket has even reached the courtyard. The Kemite does not answer yet. That evening the household's winter food is set aside first, then what is left gets counted. Only now is there a true answer to give.

Having something does not mean every request must be answered on the spot.''',
    decanFlow: _renwetIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A request held unanswered until the winter food is set aside and the rest counted',
      colorFrequency:
          'A full store that is not yet a promise until it is reckoned',
      mantra: '"I count what is truly mine before I answer a request."',
    ),
  ),

  'renwet_11_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 11 (Day 11 of Renwet)',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'The Help That Made the Good Year Possible Should Not Wait Behind the Celebrating',
    cosmicContext:
        '''A hand goes to the grain to send as a gift — then the Kemite sees the neighbor's empty basket by the wall. Seed borrowed from that house is part of why this harvest grew at all. The promised share is measured back first. Only now has the year made repaying it possible.

The help that made the good year possible should not have to wait behind the celebrating.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A borrowed share measured back before any gift is sent out',
      colorFrequency:
          'A debt to the house whose seed grew this harvest, repaid first',
      mantra: '"I repay what made the good year possible before I give gifts."',
    ),
  ),

  'renwet_12_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 12',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'A Tempting Offer Is Easier to Refuse When You Remember What the Thing Was For',
    cosmicContext:
        '''A bright woven shawl catches the wife's eye at the stall, and her hand is already on it. Then she unfolds the children's sleeping mat — worn thin, and the nights are turning cold. She trades the grain for a sturdier mat and lets the shawl go.

A tempting offer is easier to refuse when you remember what the thing was actually for.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A bright shawl let go for a sturdy mat against the cold nights',
      colorFrequency:
          'A tempting stall offer refused in favor of the real, cooler-weather need',
      mantra:
          '"I keep the real need in view, and the tempting offer loses its hold."',
    ),
  ),

  'renwet_13_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 13',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Help Only Helps When It Meets the Trouble the Person Is Actually Having',
    cosmicContext:
        '''Another basket of grain is almost left at the older neighbor's door — but she has food already. What she can't do is haul her grain to the grinding stones. So the Kemite asks, then lifts the sack with the son. By evening she has flour for supper.

Help only helps when it meets the trouble the person is actually having.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A grain sack carried to the grinding stones instead of another basket left',
      colorFrequency:
          'Help reshaped to the actual difficulty once the question is asked',
      mantra:
          '"I give the help the person actually needs, not the help I brought."',
    ),
  ),

  'renwet_14_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 14',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'A Spoken Agreement Spares a Friendship the Strain of an Unsaid Expectation',
    cosmicContext:
        '''The sickle is already held out to the neighbor when the Kemite remembers needing it at dawn. The easy thing is to hand it over and hope. Instead, plainly: this is when it must come back. They agree where it will be left tonight.

A spoken agreement spares a friendship the strain of an expectation no one ever said aloud.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A lent sickle given with the hour of its return named plainly',
      colorFrequency:
          'An expectation spoken aloud instead of left to strain the bond',
      mantra: '"I name the expectation before it can quietly strain the bond."',
    ),
  ),

  'renwet_15_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 15',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'A Generous Plan Needs the Agreement of the Hands That Will Carry It Out',
    cosmicContext:
        '''The guest list grows as the Kemite names one more friend, then another. Across the yard the wife is still bent over the day's grinding. The naming stops, and the question comes instead: how much would this meal really take to make? Together they settle on a smaller gathering they can manage.

A generous plan needs the agreement of the hands that will have to carry it out.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A growing guest list brought back to a meal two hands can actually make',
      colorFrequency:
          'Generosity sized to the labor the household can truly give',
      mantra: '"I get the agreement of the hands that will carry out my plan."',
    ),
  ),

  'renwet_16_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 16',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'To Give Something Is Also to Let the Other Decide What It Becomes',
    cosmicContext:
        '''The brother has traded away the grain he was given — for lamp oil. The Kemite's first reaction is to object. Then comes the sight of the dark, empty lamp beside the evening meal. The brother's house needed light more than more grain. The oil gets poured, and nothing is said.

To give something is also to let the other decide what it becomes.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A gift of grain traded for lamp oil, the objection swallowed',
      colorFrequency:
          'A dark lamp filled, a gift allowed to become what its keeper needed',
      mantra: '"I let the one I gave to decide what the gift becomes."',
    ),
  ),

  'renwet_17_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 17',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'People Get Further Together When Each Brings the One Thing They Do Well',
    cosmicContext:
        '''The potter has no field; the Kemite cannot shape a storage jar to save the harvest. So grain is set beside finished pottery, and they trade. She feeds her household; the grain is protected. Neither one had to become skilled at everything to get what they needed.

People get further together when each can bring the one thing they do well.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'Grain set beside finished pottery, each trading what the other lacks',
      colorFrequency:
          'Two skills meeting so neither hand must master everything',
      mantra: '"I trade what I do well for what another does well."',
    ),
  ),

  'renwet_18_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 18',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'A Fair Share Remembers the Work Done Before the Watching Began',
    cosmicContext:
        '''The cousin tallies the loads he carried and asks for the largest share. The Kemite's wife points to the grain already sorted and the baskets she mended before either man showed up. The work is counted again — including the hours that happened before anyone arrived to see them.

A fair share remembers the work that was already done before the watching began.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'Sorted grain and mended baskets counted beside the loads that were carried',
      colorFrequency:
          'The unseen early hours weighed into a share, not just the visible lifting',
      mantra: '"I count the work finished before anyone arrived to see it."',
    ),
  ),

  'renwet_19_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 19',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Having Been Generous Before Does Not Mean You Got It Right This Time',
    cosmicContext:
        '''A helper says his share came up short. The Kemite starts listing everything already given him — then stops, and lets the man finish. One basket had been marked to the wrong household. The count is fixed before the helper leaves.

Having been generous before does not mean you got it right this time. Listening is how you find out.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A short share heard out, a mismarked basket found and corrected',
      colorFrequency:
          'Past generosity set aside long enough to catch a present mistake',
      mantra:
          '"I let the complaint finish, because past giving can hide a present error."',
    ),
  ),

  'renwet_20_2': KemeticDayInfo(
    kemeticDate: 'Renwet II, Day 20',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    starCluster:
        '✨ ḥry-ib ꜥpdw — the Heart of the Birds, the central stars of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Gratitude Becomes Real When Some of the Harvest Actually Leaves Your Hands',
    cosmicContext:
        '''A fresh loaf cools beside the family meal, untouched. Before the bowls are filled, the Kemite wraps it for the shrine. The river fed the roots; other hands kept the water moving; the grain was never his alone. A part of what could not be grown alone is given back.

Gratitude becomes real when some of the harvest actually leaves your hands.''',
    decanFlow: _renwetIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A fresh loaf wrapped for the shrine before the family bowls are filled',
      colorFrequency:
          'A part given back of what the river and many hands helped grow',
      mantra: '"I return a part of what I could not have grown alone."',
    ),
  ),

  'renwet_21_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 21 (Day 21 of Renwet)',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple: 'What You Set Aside for a Need Has to Be Allowed to Meet It',
    cosmicContext:
        '''The wife waits with the bowl while the Kemite hesitates over a sealed jar. The full stores have become a comfort in themselves; breaking one feels like going backward. Then the seal breaks and the meal is measured out. This is exactly the hunger the jar was filled for.

What you set aside for a need has to be allowed to meet it.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph: 'A sealed jar opened for the meal it was always filled to feed',
      colorFrequency:
          'A full store spent for its purpose, not kept as comfort alone',
      mantra: '"I let what I set aside for a need actually meet it."',
    ),
  ),

  'renwet_22_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 22',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Today\'s Appetite Has to Leave Something for the Life Not Yet Planted',
    cosmicContext:
        '''The son dips the measuring bowl toward the small jar. The Kemite stops the hand and shows him: this is the seed, kept for planting, not for eating. The meal's grain comes from another jar, and the seed is marked clearly before it is set back. The next sowing is months off, but its grain is already here.

Today's appetite has to leave something for the life not yet planted.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'The seed jar marked and set apart from the grain meant for eating',
      colorFrequency:
          'Next season\'s sowing protected from this season\'s hunger',
      mantra:
          '"I keep back what the next beginning needs from today\'s appetite."',
    ),
  ),

  'renwet_23_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 23',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Setting It in Order Once Saves Everyone From Solving the Same Thing Tomorrow',
    cosmicContext:
        '''Every morning someone asks which jar to open. So the Kemite marks the jars for daily use and shows the household where the reserves begin. The next morning the daughter finds what she needs on her own, while the travel baskets get bound.

Setting it in order once saves everyone from solving the same small thing again tomorrow.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'Jars marked for daily use, the reserves set apart so no one asks again',
      colorFrequency:
          'A recurring question answered once, for the whole household',
      mantra: '"I set the recurring thing in order once, for everyone."',
    ),
  ),

  'renwet_24_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 24',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'A Big Mess Gets Smaller the Moment One Corner Is Small Enough to Finish',
    cosmicContext:
        '''Empty baskets, loose tools, torn sacks — the storehouse is a tangle, and the Kemite keeps shifting things from pile to pile without getting anywhere. So the shifting stops: one corner by the door gets emptied. The tools go up on the wall there before the next pile is touched.

A big mess gets smaller the moment one corner is small enough to actually finish.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'One corner by the door cleared and the tools hung, the rest left for after',
      colorFrequency:
          'A tangle made workable by finishing one small part completely',
      mantra: '"I finish one small part so the whole mess turns workable."',
    ),
  ),

  'renwet_25_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 25',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Someone\'s Place in the House Is Bigger Than the Work They Can Do This Week',
    cosmicContext:
        '''The cousin arrives with a hand wrapped in linen, carrying nothing this week, and starts to explain himself. The Kemite slides a bowl toward him before the apology is done. There is a place at this table while the hand heals.

Someone's place in the house is bigger than the work they can do this week.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A bowl slid toward the injured cousin before his apology is finished',
      colorFrequency:
          'A place at the table kept while the hand heals, apart from output',
      mantra:
          '"I keep a person\'s place even when they cannot work this week."',
    ),
  ),

  'renwet_26_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 26',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'What You Have Shared Lets You Step Away Without Leaving Everyone Stuck',
    cosmicContext:
        '''The young keeper has to take his mother to another village. Before going, he shows the Kemite which shares are still owed and where the key hangs. The account is checked together. The next morning the storehouse opens at its usual hour, with him gone.

What you've shared lets you step away without leaving everyone else stuck.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'The shares owed and the key shown before the keeper leaves for a journey',
      colorFrequency:
          'A storehouse opening on time though the one who ran it is away',
      mantra: '"I share what I know, so things go on while I am away."',
    ),
  ),

  'renwet_27_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 27',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Time That Good Work Earns You Doesn\'t Have to Be Spent on More Work',
    cosmicContext:
        '''Stores checked, tools away, tomorrow's delivery arranged — and the Kemite is already hunting for the next task. Then the daughter calls from the courtyard, where the children are playing in the last warm sun. A seat beside them, and the afternoon is let to simply stay free.

Time that good work earns you doesn't have to be spent on more work.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'The hunt for another task set down to sit with the children in warm sun',
      colorFrequency:
          'An earned free afternoon left free instead of refilled with work',
      mantra: '"I let time my work earned stay free, not refilled with work."',
    ),
  ),

  'renwet_28_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 28',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'What Made This Harvest Will Be Asked Again; Looking After It Is Part of Finishing Well',
    cosmicContext:
        '''The son reaches to pull the last stalks clean. The Kemite stops him and leaves them lying over the soil, where they'll keep the winter rains from washing it away. The grain is home, but the field that grew it still needs care.

What made this harvest will be asked again next year. Looking after it is part of finishing well.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'The last stalks left over the soil to hold it through the winter rains',
      colorFrequency:
          'The ground that fed the harvest tended, not stripped, at the end',
      mantra: '"I care for what fed me; it will be asked again next year."',
    ),
  ),

  'renwet_29_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 29',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'Preparing Well Makes the Next Step Safer, but Never Packs Away Every Uncertainty',
    cosmicContext:
        '''The travel basket is full, but the Kemite keeps adding grain — picturing every delay the road might throw out. When it lifts onto the shoulder, walking is barely possible. It comes back down, and everything the journey does not truly need comes out.

Preparing well makes the next step safer. It will never pack away every uncertainty.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'An over-packed travel basket set down and emptied back to what the road needs',
      colorFrequency:
          'Preparation sized to the journey, not to every imagined delay',
      mantra:
          '"I prepare what the journey needs and stop packing against every fear."',
    ),
  ),

  'renwet_30_3': KemeticDayInfo(
    kemeticDate: 'Renwet III, Day 30',
    season: '🌱 Peret – Emergence Season',
    month: 'Renwet ("Rnnwtt")',
    decanName: 'sbꜣ ꜥpdw ("Star of the Birds")',
    starCluster:
        '✨ sbꜣ ꜥpdw — the Star of the Birds, the bright marker of the group, watched through this ten-day interval.',
    maatPrinciple:
        'A Good Ending Leaves the Next Beginning Something Steady to Stand On',
    cosmicContext:
        '''As Renwet closes, a travel basket waits by the door. The grain is dry, the household knows the stores, the neighbors know their shares. Hnsw will carry some of this harvest farther out. The Kemite can go — because what was built here can keep going without him.

A good ending leaves the next beginning something steady to stand on.''',
    decanFlow: _renwetIIIFlowRows,
    meduNeter: MeduNeterKey(
      glyph:
          'A travel basket by the door, the household and neighbors able to carry on',
      colorFrequency:
          'Renwet handed into Hnsw on a base that can stand without its keeper',
      mantra: '"I leave the next beginning something steady to stand on."',
    ),
  ),
};
