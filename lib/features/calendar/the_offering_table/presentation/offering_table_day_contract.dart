import 'package:flutter/foundation.dart';

enum OfferingTableMoveKind { name, tap, pick, drink, timer, truth }

@immutable
class OfferingTableMoveContract {
  const OfferingTableMoveContract({
    required this.id,
    required this.kind,
    required this.label,
    this.slot,
    this.fieldLabel,
    this.placeholder,
    this.options = const <String>[],
    this.binds,
    this.targetSeconds,
    this.completeUnderTarget = false,
    this.optional = false,
  });

  final String id;
  final OfferingTableMoveKind kind;
  final String label;
  final String? slot;
  final String? fieldLabel;
  final String? placeholder;
  final List<String> options;
  final String? binds;
  final int? targetSeconds;
  final bool completeUnderTarget;
  final bool optional;
}

@immutable
class OfferingTableDayContract {
  const OfferingTableDayContract({
    required this.day,
    required this.title,
    required this.prompt,
    required this.orientation,
    required this.instruction,
    required this.context,
    required this.moves,
  });

  final int day;
  final String title;
  final String prompt;
  final String orientation;
  final String instruction;
  final String context;
  final List<OfferingTableMoveContract> moves;

  String get stage => day <= 10
      ? 'Personal Table'
      : day <= 20
      ? 'Household Table'
      : 'Flowing Table';

  int get stageDay => ((day - 1) % 10) + 1;
  bool get isWideInstrument =>
      const <int>{10, 15, 20, 25, 26, 30}.contains(day);
}

OfferingTableMoveContract _name(
  String id,
  String label,
  String fieldLabel,
  String placeholder,
) => OfferingTableMoveContract(
  id: id,
  kind: OfferingTableMoveKind.name,
  label: label,
  slot: id,
  fieldLabel: fieldLabel,
  placeholder: placeholder,
);

OfferingTableMoveContract _tap(
  String id,
  String label,
  String? binds, {
  bool optional = false,
}) => OfferingTableMoveContract(
  id: id,
  kind: OfferingTableMoveKind.tap,
  label: label,
  binds: binds,
  optional: optional,
);

OfferingTableMoveContract _pick(
  String id,
  String label,
  List<String> options,
) => OfferingTableMoveContract(
  id: id,
  kind: OfferingTableMoveKind.pick,
  label: label,
  options: options,
);

OfferingTableMoveContract _drink(String id, String label, String? binds) =>
    OfferingTableMoveContract(
      id: id,
      kind: OfferingTableMoveKind.drink,
      label: label,
      binds: binds,
    );

OfferingTableMoveContract _timer(
  String id,
  String label,
  String binds,
  int targetSeconds, {
  bool completeUnderTarget = false,
}) => OfferingTableMoveContract(
  id: id,
  kind: OfferingTableMoveKind.timer,
  label: label,
  binds: binds,
  targetSeconds: targetSeconds,
  completeUnderTarget: completeUnderTarget,
);

OfferingTableMoveContract _truth(String id, String label) =>
    OfferingTableMoveContract(
      id: id,
      kind: OfferingTableMoveKind.truth,
      label: label,
    );

final List<OfferingTableDayContract>
kOfferingTableDayViewContracts = <OfferingTableDayContract>[
  OfferingTableDayContract(
    day: 1,
    title: 'The Small Supply',
    prompt: 'check one thing before it runs out',
    orientation: 'Check one supply before it becomes an emergency.',
    instruction:
        'Check one thing you rely on: medication, water bottle, groceries, soap, clean clothes, or transit fare. Refill it, or write down the next concrete step.',
    context:
        'The supplies that run out do so silently. This rite catches one while the correction is still small.',
    moves: <OfferingTableMoveContract>[
      _name('supply', 'Name one supply running low.', 'SUPPLY', 'supply…'),
      _tap('refill', 'Refill it, or write down the next step.', 'refilled'),
      _tap('visible', 'Put it in sight or set one reminder.', 'visible'),
    ],
  ),
  OfferingTableDayContract(
    day: 2,
    title: 'The Cup Before the Noise',
    prompt: 'choose your first input',
    orientation: 'Choose what reaches you before the noise does.',
    instruction:
        'Choose the first thing you want to give your attention to. Then give your body water before feeds, messages, or tasks get first claim.',
    context:
        "The day's demands begin competing for attention before the body has been given anything. This rite reverses that order.",
    moves: <OfferingTableMoveContract>[
      _name(
        'input',
        'Name the first thing you want to give your attention to.',
        'INPUT',
        'first thing…',
      ),
      _drink(
        'drink',
        'Drink a glass of water before you open anything.',
        'drunk',
      ),
      _timer('quiet', 'Give that first thing one quiet minute.', 'quiet', 60),
    ],
  ),
  OfferingTableDayContract(
    day: 3,
    title: 'Bread Enough',
    prompt: 'put real food within reach',
    orientation: 'Make sure real food has a place in your day.',
    instruction:
        'Choose your first real food before hunger has to improvise for you.',
    context:
        "Food treated as fuel is not being received — it's being used. This rite makes one meal an act of provision rather than consumption.",
    moves: <OfferingTableMoveContract>[
      _name(
        'food',
        'Name the first real food you will eat today.',
        'FOOD',
        'first real food…',
      ),
      _tap(
        'place',
        'Put it within reach now — on the counter or in your bag.',
        'placed',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 4,
    title: 'The Body Washed',
    prompt: 'do one piece of delayed care',
    orientation: "Give your body one piece of care you've been putting off.",
    instruction: 'Make one delayed care task small enough to move today.',
    context:
        'Neglect rarely announces itself — it accumulates in small deferrals. This rite names one and corrects it.',
    moves: <OfferingTableMoveContract>[
      _tap('wash', 'Wash your face, hands, or mouth slowly.', 'washed'),
      _name(
        'care',
        'Name the body-care task you keep putting off.',
        'CARE',
        'body-care task…',
      ),
      _tap('do', 'Do the two-minute version now — or book it.', 'carried'),
    ],
  ),
  OfferingTableDayContract(
    day: 5,
    title: 'The Midpoint: Rest',
    prompt: "protect tonight's rest now",
    orientation: "Protect tonight's rest before the day spends it.",
    instruction:
        'Make one concrete change now that gives tonight a better chance.',
    context:
        'Provision is not only food. The Ka is sustained by repeated supports, and rest is one of the supports that disappears when it is not counted.',
    moves: <OfferingTableMoveContract>[
      _name('hours', 'Name how many hours you slept.', 'HOURS', 'hours…'),
      _name(
        'shortener',
        'Name what is most likely to cut tonight short.',
        'SHORTENER',
        'what cuts sleep short…',
      ),
      _tap(
        'reduce',
        'Cut thirty minutes from it, or set a stop time.',
        'reduced',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 6,
    title: 'The Standing Appointment',
    prompt: "book the thing you've been meaning to book",
    orientation:
        'Turn one postponed appointment into a date or a callable next step.',
    instruction:
        "Name one appointment you have been deferring. Find the number or booking page. Book it, or put the call on today's calendar with the number already in the note.",
    context:
        'A needed appointment can stay vague for weeks. A date, booking page, or callable number turns it into something you can actually finish.',
    moves: <OfferingTableMoveContract>[
      _name(
        'appointment',
        'Name the appointment you have been deferring.',
        'APPOINTMENT',
        'appointment…',
      ),
      _tap('find', 'Find the number or booking page.', 'found'),
      _tap('book', 'Book it — or calendar the call with the number.', 'booked'),
    ],
  ),
  OfferingTableDayContract(
    day: 7,
    title: 'Dignity at the Table',
    prompt: 'do one thing that protects your dignity',
    orientation: 'Do one thing that protects your dignity today.',
    instruction:
        'Choose one ordinary act that says your body does not have to earn basic provision.',
    context:
        "The Kemetic offering table held ointment and linen alongside food — care for the body's surface, not only its interior.",
    moves: <OfferingTableMoveContract>[
      _pick(
        'dignity',
        'Choose one thing that tells your body it matters.',
        <String>[
          'Clean clothes',
          'Sit down to eat',
          'A real pause',
          'Ask without apology',
        ],
      ),
      _tap('act', 'Do it today.', 'acted'),
    ],
  ),
  OfferingTableDayContract(
    day: 8,
    title: 'The Quiet Hunger',
    prompt: 'give one non-food need a real portion',
    orientation: "Notice a need that isn't food but still leaves you depleted.",
    instruction:
        "Name the kind of deprivation that can hide behind 'I'm fine.' Give it one real portion, or make the first opening concrete.",
    context:
        "The hunger that doesn't feel like hunger is usually the oldest one. This rite names it before it gets louder.",
    moves: <OfferingTableMoveContract>[
      _name(
        'hunger',
        'Name one: sleep, quiet, sunlight, touch, movement, medical care, or help.',
        'HUNGER',
        'what are you going without?…',
      ),
      _tap('portion', 'Give it one real portion today.', 'portioned'),
      _tap(
        'schedule',
        'If today cannot hold it, put the first opening on your calendar.',
        'scheduled',
        optional: true,
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 9,
    title: 'The First Repair',
    prompt: 'close one small gap before noon',
    orientation: 'Close one small gap before noon.',
    instruction:
        'Choose one repair that is small enough to finish before noon. Do it, then close the rite with water.',
    context:
        'The first decan closes. One small gap is the only repair the seal requires — not everything, just the one that can move.',
    moves: <OfferingTableMoveContract>[
      _pick('repair', 'Choose one repair you can finish before noon.', <String>[
        'Eat',
        'Wash',
        'Stretch',
        'Rest 10 min',
        'Refill',
        'Step outside',
        'Ask for help',
      ]),
      _tap('do', 'Do it.', 'acted'),
      _drink('drink', 'Drink water.', 'received'),
    ],
  ),
  OfferingTableDayContract(
    day: 10,
    title: 'The Personal Table Sealed',
    prompt: 'name what was fed and what still needs care',
    orientation: 'Close the first table with an honest account.',
    instruction:
        'Name what improved and what still needs provision. Then make tomorrow slightly easier.',
    context:
        "The scribe's record closes with what is — not what was intended, but what actually happened.",
    moves: <OfferingTableMoveContract>[
      _name('fed', 'Name one need that was fed.', 'FED', 'fed…'),
      _name('asking', 'Name one need still asking.', 'ASKING', 'still asking…'),
      _tap('prepare', 'Set up one support for tomorrow.', 'prepared'),
    ],
  ),
  OfferingTableDayContract(
    day: 11,
    title: 'The Household Table Opens',
    prompt: 'name exactly what someone depends on',
    orientation: 'Notice who depends on your table.',
    instruction:
        "Make another person's need concrete enough that you can move one small part of it.",
    context:
        'Offering lists in tombs and temples are records of sustained relationship. Provision is not private when others depend on the table.',
    moves: <OfferingTableMoveContract>[
      _name(
        'dependent',
        'Name one person, animal, plant, or shared space that depends on you.',
        'WHO',
        'who depends on you…',
      ),
      _name(
        'need',
        'Name exactly what they need this week.',
        'NEED',
        'food, ride, call, repair, money, time…',
      ),
      _tap(
        'provide',
        'Do the smallest part now — or send one message about it.',
        'provided',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 12,
    title: 'The Dependent Named',
    prompt: "make one dependent's need exact",
    orientation: 'Make care specific enough to act on.',
    instruction:
        'Choose one dependent. Name the need in exact words, then answer one part of it.',
    context:
        'Abstract care changes nothing. Named care in exact words produces the act that can follow it.',
    moves: <OfferingTableMoveContract>[
      _name(
        'dependent',
        'Name one person or animal who depends on you.',
        'WHO',
        'who depends on you…',
      ),
      _name(
        'need',
        'Name what they need today, in exact words.',
        'NEED',
        'exact need…',
      ),
      _tap('care', 'Send the message, or do the task now.', 'provided'),
    ],
  ),
  OfferingTableDayContract(
    day: 13,
    title: 'The Fair Share',
    prompt: 'move one shared load toward even',
    orientation: 'Notice where a shared load could feel fairer.',
    instruction:
        'Describe the load without judging the person. Then move one part toward even.',
    context:
        "Someone is always carrying more than their share — usually quietly. This rite asks whether it's you or someone else, and acts accordingly.",
    moves: <OfferingTableMoveContract>[
      _name(
        'resource',
        'Name one thing the household shares.',
        'RESOURCE',
        'food, money, cleaning, time, space…',
      ),
      _pick('position', 'How is it sitting right now?', <String>[
        'I carry more',
        'About even',
        'Someone else carries more',
      ]),
      _tap(
        'adjust',
        'Move it one step toward even — pay, clean, refill, cover, or ask.',
        'adjusted',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 14,
    title: 'The Waiting Bowl',
    prompt: 'refill one thing under three minutes',
    orientation: 'Find the thing that has been waiting for someone to notice.',
    instruction:
        'Name one household thing that is empty or running low. If the refill is under three minutes, finish it now.',
    context:
        'Things run low without announcement. This rite finds the one that has been waiting for someone to notice.',
    moves: <OfferingTableMoveContract>[
      _name(
        'refill',
        'Name what is low or empty.',
        'REFILL',
        'what needs refill…',
      ),
      _timer(
        'refillTimer',
        'Refill it now — under three minutes.',
        'filled',
        180,
        completeUnderTarget: true,
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 15,
    title: 'The Midpoint: Attention',
    prompt: 'give one minute of full attention',
    orientation:
        'Give one person or responsibility more than your leftover attention.',
    instruction:
        'Give one undistracted minute, then keep the phone out of the way when the minute ends.',
    context:
        'In offering scenes, the table is visible because provision must be seen and carried. Attention is one way a household table becomes visible.',
    moves: <OfferingTableMoveContract>[
      _name(
        'attention',
        "Name who's been getting your leftover attention.",
        'ATTENTION',
        'person or responsibility…',
      ),
      _timer(
        'attentionTimer',
        'Give them one undistracted minute.',
        'attended',
        60,
      ),
      _tap(
        'phone',
        'After the minute, put the phone face down and leave it there.',
        'phoneDown',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 16,
    title: 'The Cost Named',
    prompt: 'name the cost of care',
    orientation: 'Name the cost of care before it becomes depletion.',
    instruction:
        'Make one care cost visible, then cover one part of it instead of carrying it invisibly.',
    context:
        'Care that does not account for its own cost depletes the one giving it. This rite names the cost before it becomes resentment.',
    moves: <OfferingTableMoveContract>[
      _name(
        'cost',
        'Name the cost of care.',
        'COST',
        'money, time, patience, transport…',
      ),
      _tap(
        'cover',
        'Cover one part now — pay, schedule, ask, or set a boundary.',
        'covered',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 17,
    title: 'The Care Message',
    prompt: 'send the practical message',
    orientation: 'Say the practical thing while it is still simple.',
    instruction:
        'Use one plain sentence to keep a provision line from becoming a crisis.',
    context:
        'The provision line breaks quietly through deferred communication. This rite names what needs to be said while saying it is still simple.',
    moves: <OfferingTableMoveContract>[
      _pick('stem', 'Choose one plain sentence.', <String>[
        'I have this',
        'I need this',
        "I'll bring this",
        "I can't do this today",
      ]),
      _name(
        'message',
        'Finish it in one line.',
        'MESSAGE',
        'plain care message…',
      ),
      _tap('send', 'Send it now.', 'sent'),
    ],
  ),
  OfferingTableDayContract(
    day: 18,
    title: 'The Shared Rest',
    prompt: 'change one thing that makes rest harder',
    orientation: 'Give some rest back to the household.',
    instruction:
        'Notice one way your pace makes rest harder for someone else. Change one part tonight.',
    context:
        'Rest is a shared resource when multiple people live under one schedule. This rite asks what your pace is doing to the rest around it.',
    moves: <OfferingTableMoveContract>[
      _name(
        'impact',
        'Name one thing you do that makes rest harder for someone else.',
        'IMPACT',
        'time, volume, room, interruption…',
      ),
      _tap(
        'adjust',
        'Change one part tonight — the time, volume, room, or interruption.',
        'adjusted',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 19,
    title: 'The Unseen Labor',
    prompt: 'take one unseen load off someone',
    orientation: 'Put one piece of unseen work back into the account.',
    instruction:
        'Name the work that usually disappears into the background. Then carry one part yourself.',
    context:
        'What sustains a household without being recorded disappears from the account. This rite puts it in.',
    moves: <OfferingTableMoveContract>[
      _name(
        'labor',
        'Name the work that keeps this house running unnoticed.',
        'LABOR',
        'unseen labor…',
      ),
      _tap('credit', 'Say who carries it.', 'credited'),
      _tap(
        'lighten',
        "Take one load off them today, without announcing it.",
        'lightened',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 20,
    title: 'The Household Table Sealed',
    prompt: 'put one household patch on the calendar',
    orientation: 'Close the household table with one honest repair.',
    instruction:
        'Name what improved, what still leaks, and the smallest patch worth scheduling.',
    context:
        'What improved? What still leaks? The second seal requires only these two facts, not a full solution.',
    moves: <OfferingTableMoveContract>[
      _name('improved', 'Name what improved.', 'IMPROVED', 'improved…'),
      _name('leak', 'Name what still leaks.', 'STILL LEAKS', 'still leaks…'),
      _name('patch', 'Name the smallest patch.', 'PATCH', 'next patch…'),
      _tap('calendar', "Put it on today's calendar.", 'scheduled'),
    ],
  ),
  OfferingTableDayContract(
    day: 21,
    title: 'The Flowing Table Opens',
    prompt: 'clear one small block in the flow',
    orientation:
        'Notice what supports you, then clear one small block in the flow.',
    instruction:
        'Name a source you usually overlook. If something is blocked, move it. If nothing is blocked, acknowledge the source directly.',
    context:
        'Hapy personifies the Nile flood as abundance that moves. Provision becomes disorder when flow is hoarded, blocked, or denied.',
    moves: <OfferingTableMoveContract>[
      _name(
        'source',
        "Name a source you haven't acknowledged.",
        'SOURCE',
        'source…',
      ),
      _tap(
        'clear',
        'Clear one small obstruction. If none is blocked, acknowledge the source directly.',
        'cleared',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 22,
    title: 'The Source Named',
    prompt: 'trace one thing back to its source',
    orientation: 'Trace one thing you use back to its source.',
    instruction:
        'Follow one ordinary thing backward one step, then return something to the chain that made it possible.',
    context:
        'What you use today did not begin with you. This rite traces one step back in the chain before the day moves forward.',
    moves: <OfferingTableMoveContract>[
      _name(
        'thing',
        "Name one thing you'll use today.",
        'THING',
        'what you use…',
      ),
      _name(
        'source',
        'Name its source — who grew, made, carried, taught, or paid for it.',
        'SOURCE',
        'source…',
      ),
      _tap(
        'offer',
        'Return something today — thanks, payment, credit, or care.',
        'returned',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 23,
    title: 'The River Unblocked',
    prompt: 'move one delayed thing today',
    orientation: 'Move one thing you have been holding up.',
    instruction:
        'Move one delayed thing one real step. If it cannot move, make sure the waiting person knows why.',
    context:
        'Something you are holding — a reply, a payment, a permission — is keeping something else from moving. This rite moves it.',
    moves: <OfferingTableMoveContract>[
      _name(
        'delayed',
        "Name what you've been holding.",
        'DELAYED',
        'delayed thing…',
      ),
      _tap('moved', 'Move it one real step today.', 'moved'),
      _tap(
        'truth',
        "If it can't move, tell the person waiting.",
        'truth',
        optional: true,
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 24,
    title: 'The Hoard Checked',
    prompt: 'move one surplus back into circulation',
    orientation: 'Check whether something extra has become a blockage.',
    instruction:
        'Name one surplus and move one small portion out of the house or account today.',
    context:
        "Surplus is not a problem unless it's preventing flow. This rite checks the line between supply and obstruction.",
    moves: <OfferingTableMoveContract>[
      _name('surplus', 'Name one surplus.', 'SURPLUS', 'surplus…'),
      _tap(
        'release',
        'Move one portion out today — give, return, donate, or pass it on.',
        'released',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 25,
    title: 'The Midpoint: Hapy',
    prompt: 'send one part of provision onward',
    orientation:
        'Notice where provision reached you, then let some of it keep moving.',
    instruction:
        'Name what reached you and where it can go next without draining you. Move one part today.',
    context:
        'Hymns to Hapy praise the flood because it feeds fields and households. Flow is provision made visible across more than one table.',
    moves: <OfferingTableMoveContract>[
      _name(
        'received',
        'Name where provision reached you this week.',
        'RECEIVED',
        'what reached you…',
      ),
      _name(
        'onward',
        'Name where it can go next.',
        'ONWARD',
        'where it can go…',
      ),
      _tap('flow', 'Send one part there today.', 'flowing'),
    ],
  ),
  OfferingTableDayContract(
    day: 26,
    title: 'The Return Given',
    prompt: 'use one support you already have',
    orientation: 'Use what has already been given.',
    instruction:
        'Name one support already available to you. Receive it by actually using it.',
    context:
        'In the temple, offerings were eventually consumed — that was called reversion, and it was sacred. Provision that is never received serves nothing.',
    moves: <OfferingTableMoveContract>[
      _name(
        'support',
        "Name one support you already have but haven't used.",
        'SUPPORT',
        'support already available…',
      ),
      _tap(
        'use',
        'Use it today — eat it, spend it, accept it, or put the tool to work.',
        'returned',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 27,
    title: 'The Land Remembered',
    prompt: 'return one act of care',
    orientation: 'Return one small act of care to what supports your life.',
    instruction:
        'Name one way land, water, weather, or public infrastructure provisions you. Make one concrete return before the day ends.',
    context:
        "The table never existed apart from the land that supplied it. This rite names the land's role before the debt goes unrecorded.",
    moves: <OfferingTableMoveContract>[
      _name(
        'provision',
        'Name what provisions you today — land, water, weather, or public works.',
        'PROVISION',
        'what provisions you…',
      ),
      _pick('returnKind', 'Choose one return.', <String>[
        'Pick up',
        'Conserve',
        'Water',
        'Repair',
        'Recycle',
        'Walk',
        'Use less',
      ]),
      _tap('return', 'Do it before the day ends.', 'returned'),
    ],
  ),
  OfferingTableDayContract(
    day: 28,
    title: 'The Relationship Fed',
    prompt: 'give one relationship something usable',
    orientation:
        'Feed one relationship with something the other person can actually receive.',
    instruction:
        'Choose a sustaining relationship and give it one concrete form of provision today.',
    context:
        'Relationships sustained by history alone are slowly depleting. This rite adds one provision before the account needs to draw down.',
    moves: <OfferingTableMoveContract>[
      _name(
        'relationship',
        'Name a relationship that sustains you.',
        'RELATIONSHIP',
        'relationship…',
      ),
      _pick('provision', 'Choose what they can actually receive.', <String>[
        'Thanks',
        'Time',
        'Food',
        'Help',
        'Repair',
        'Clean boundary',
      ]),
      _tap('give', 'Give it today.', 'fed'),
    ],
  ),
  OfferingTableDayContract(
    day: 29,
    title: 'The Flow Prepared',
    prompt: "set tomorrow's support out tonight",
    orientation: 'Make tomorrow easier before it begins.',
    instruction:
        'Prepare one support tonight so the next morning starts with less friction.',
    context:
        'The table that is set the night before is the table that works in the morning. This rite prepares one thing so tomorrow starts provisioned.',
    moves: <OfferingTableMoveContract>[
      _pick('support', "Choose tomorrow's support.", <String>[
        'Water',
        'Breakfast',
        'Medicine',
        'Clothes',
        'Message',
        'Money',
        'Clear space',
      ]),
      _tap('prepare', 'Set it out tonight.', 'prepared'),
      _name(
        'easier',
        'Name what this makes easier.',
        'EASIER',
        'what gets easier…',
      ),
    ],
  ),
  OfferingTableDayContract(
    day: 30,
    title: 'The Table Is Complete',
    prompt: 'close the table with what is true',
    orientation: 'Close the cycle with accuracy, not perfection.',
    instruction:
        'Speak only the lines that are true. Name one shortfall and one surprise. Drink the water, then sit for one quiet breath.',
    context:
        'The offering table is not an end point. The water is consumed, the support returns to life, and the next cycle starts from what is now known.',
    moves: <OfferingTableMoveContract>[
      _truth('truth1', 'My water was placed with attention.'),
      _truth('truth2', 'Food, rest, or care was not treated as imaginary.'),
      _truth('truth3', 'I fed one need before it became collapse.'),
      _truth('truth4', 'I noticed who else depends on the table.'),
      _truth('truth5', 'What flowed to me was allowed to return.'),
      _name('shortfall', 'Name one shortfall.', 'SHORTFALL', 'one shortfall…'),
      _name(
        'surprise',
        'Name one provision that surprised you.',
        'SURPRISE',
        'one surprise…',
      ),
      _drink('drink', 'Drink the water.', null),
      _timer('breath', 'Sit for one quiet breath.', 'sealed', 8),
      _tap(
        'share',
        'Share one thing only if you choose.',
        null,
        optional: true,
      ),
    ],
  ),
];

OfferingTableDayContract offeringTableDayViewContract(int day) {
  if (day < 1 || day > kOfferingTableDayViewContracts.length) {
    throw RangeError.range(
      day,
      1,
      kOfferingTableDayViewContracts.length,
      'day',
    );
  }
  return kOfferingTableDayViewContracts[day - 1];
}
