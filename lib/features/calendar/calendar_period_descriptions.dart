part of 'calendar_page.dart';

/* ─────────── Month / Decan info text ─────────── */

const Map<int, String> _monthInfo = {
  1: '''
Month 1 — Thoth / Ḏḥwty
Akhet · Finding orientation when familiar ground disappears

Water covers the land. Roads vanish. Field boundaries soften into the flood until almost nothing that once felt solid can be trusted by the eye alone.

Thoth meets the year here. Orientation comes first: learning to look before acting, gathering what the sky and river still show, and waiting for a pattern to form before deciding what it means.
''',
  2: '''
Month 2 — Paopi / Mnḫt
Akhet · Turning orientation into movement

The water still dominates, yet waiting has lost its claim. Boats begin to matter again. What watching revealed must now be carried forward.

Paopi tests the first movement. Can clarity become direction, and can direction survive the work of repetition without spilling its purpose?
''',
  3: '''
Month 3 — Hathor / Ḥwt-Ḥr
Akhet · Recognizing harmony when the world takes shape again

Banks reappear. Distances grow legible. The flood has withdrawn enough for shape itself to matter again.

Hathor receives that returning form and turns recognition toward harmony—not merely seeing the parts, but sensing when they belong together in a way that feels whole.
''',
  4: '''
Month 4 — Ka-ḥer-Ka / Kȝ-ḥr-Kȝ
Akhet · Strength that survives turning

The inundation has finished its work. Land returns, yet the year cannot simply pick up where it left off. What survives must still be made useful.

Ka-Ḥer-Ka concerns strength that can turn, move, and accept direction without losing itself in the process.
''',
  5: '''
Month 5 — Šef-Bedet / Šf-bdt
Peret · Seeing what has begun to grow

Peret opens with emergence. Water leaves the fields and the labor shifts from surviving abundance to tending what has already appeared.

The smallest signs now carry weight. Attention must deepen into sustained care, and care, in time, into trust.
''',
  6: '''
Month 6 — Rekh-Wer / Rḫ-wr
Peret · Giving form to what has emerged

Growth has begun, but emergence is not yet completion. Form must be shaped, tested, corrected, and made strong enough to hold.

Rekh-Wer is craft in the widest sense—the slow work of turning attention into skill that can be trusted.
''',
  7: '''
Month 7 — Rekh-Nedjes / Rḫ-nḏs
Peret · Discovering what holds under pressure

Resistance arrives. Heat rises. The ground hardens. Methods that once seemed sufficient begin to show their limits.

Rekh-Nedjes treats difficulty as information. Trial exposes the real structure; adaptation keeps what still matters intact.
''',
  8: '''
Month 8 — Renwet / Rnnwt
Peret · Gathering and giving what has matured

Promise has become yield. What grew must now be gathered, sorted, moved, and shared without letting abundance tip into disorder.

Renwet is the intelligence required to receive the harvest well—keeping plenty in right relation so it can continue to serve.
''',
  9: '''
Month 9 — Hnsw / Ḫnsw
Shemu · Carrying what must be carried

Heat, harvest, movement, and weight. The work is no longer mainly about making things grow. It is about carrying the consequences of what has already grown.

Hnsw asks how to leave, how to endure the road, and how to recover without losing the direction that first set the journey in motion.
''',
  10: '''
Month 10 — Ḥenti-ḥet / Ḥnt-ḥtj
Shemu · Knowing what to hold and what to release

The harvest is secured. Stores can be counted. The urgency of gathering gives way to another discipline: guarding what matters without becoming possessed by it.

Ḥenti-Ḥet concerns vigilance, clear boundaries, and the wisdom of releasing at the right moment.
''',
  11: '''
Month 11 — Pa-Ipi / ỉpt-ḥmt
Shemu · Turning experience into usable memory

The year has traveled far enough that memory itself becomes material. Events begin to resolve into pattern.

Pa-Ipi asks what deserves to be remembered, what must be integrated, and what is still fit to continue.
''',
  12: '''
Month 12 — Mesut-Ra / Mswt-Rꜥ
Shemu · Standing at the edge of another beginning

The visible work is nearly finished. Heat remains. The river has not yet remade the land. The next cycle has not fully announced itself.

Mesut-Ra belongs to the charged stillness before renewal—the moment when completion begins to turn into readiness.
''',
  13: '''
Month 13 – Heriu Renpet (ḥr.w rnpt)
Days Upon the Year — The Threshold Where the Gods Are Born

Heriu Renpet means the Days Upon the Year.

They stand outside the counted cycle, after the twelve months have finished their work and before Wp Rnpt opens the year again. These are days of suspension: not harvest, not flood, not planting, not travel, not offering, but the pause in which time loosens its ordinary form so the powers of the next cycle can enter.

The year has exhaled.

It has not yet inhaled again.

This is why the births of the gods belong here.

Ausar is born first: the one who will be broken, gathered, restored, and made ruler in the Duat. Heru the Elder is born as sky-power, horizon-force, and divine sight. Set is born as necessary force at the boundary, dangerous when it refuses its place. Aset is born as throne, speech, protection, and the intelligence that restores what force cannot repair. Nebet-Het is born as the guardian of the edge, the mourner, the one who keeps transition from becoming abandonment.

These are not separate mythic episodes set beside the calendar. They are the powers the year must carry if it is to begin again truthfully.

Every cycle requires death and restoration. Every cycle requires sight. Every cycle requires force placed under measure. Every cycle requires skillful protection. Every cycle requires mourning, boundary, and return. The gods born in Heriu Renpet are the conditions the coming year will need.

Nut holds the threshold.

As sky, mother, vault, and womb, she contains what has not yet emerged. The sun has passed through her darkness. The year has entered her stillness. What is to be born must remain held until the right moment.

The Book of Coming Forth by Day gives the stellar form of this threshold: “I hide myself among you, O ye Stars that set not.”

— Book of Coming Forth by Day

That line belongs here because Heriu Renpet stands between disappearance and return. The imperishable stars do not enter the ordinary cycle of rising and setting in the same way. They hold. They witness. They remain as fixed powers while the year prepares to turn.

Purification belongs to these days.

Natron, water, silence, cleared altars, completed offerings, and closed records all serve the same purpose: nothing disordered should cross into the opening of the year. What has ended must be released. What must continue must be made clean enough to pass.

Heriu Renpet teaches that renewal begins with readiness, not motion.

What has completed must be sealed, what is disordered left behind, and what is necessary born in its proper place. Only then can the year open without carrying Isfet across the threshold.
''',
};

const List<String> _decanInfo = [
  '''
tpy-ꜥ sbꜣw — “Foremost of the Stars”
Orientation

The flood has erased familiar boundaries. The first task is not action but bearing. The foremost stars matter because they give the eye somewhere to begin. Once one point is known, the rest of the sky can be read in relation to it.

Maat begins the same way. Before right action comes right orientation: knowing where you stand, what surrounds you, and which direction remains true when the usual landmarks have disappeared.
''',
  '''
ḥry-ib sbꜣw — “Heart of the Stars”
Integration

A single observation cannot guide by itself. At the heart of the stars, no one light explains the pattern. Meaning arrives through distance, proportion, repetition, and the relations among the lights.

Maat is not assembled from isolated truths. Wisdom gathers fragments until they disclose the larger form. What once looked disconnected begins to belong together, and what belongs together begins to offer direction.
''',
  '''
sbꜣw — “The Stars”
Expression

The flood is beginning to reveal the land again. What was hidden has not returned unchanged, yet enough points are visible now for the shape beneath them to be recognized.

Scattered stars become a figure once the eye can hold them together. Maat becomes visible in the same way: inner order eventually takes outward form. What has been learned begins to show in speech, choice, and movement.
''',
  '''
ꜥḥꜣy — “The Riser”
Initiation of Motion

The land is still mostly water, but waiting has ended. A rising star does not reveal the whole night at once. First there is only one point breaking free of the horizon.

That can be enough. Maat does not always begin with certainty. Sometimes it begins with the first movement that brings hidden order into view—the moment understanding finally becomes action.
''',
  '''
ḥry-ib ꜥḥꜣy — “Heart of the Riser”
Sustained Effort

The journey has started; now its direction must survive repetition. Emergence at the horizon is dramatic. Higher in the sky the work grows quieter: the star simply continues its course.

The heart of rising is not the first motion but the ability to keep moving after beginning has lost its novelty. In Maat, direction becomes character through repetition.
''',
  '''
sbꜣ nfr — “The Beautiful Star”
Stability

What began in ꜥḥꜣy and was regulated through its heart has now become dependable. The beautiful star is not beautiful because it never moves, but because it can be recognized again in its proper relation.

Nfr holds beauty, goodness, fitness, and completion close together. Stability in Maat is not stillness. It is a form that has become trustworthy because it continues to fit.
''',
  '''
sꜣḥ — “Sah”
Stability Recognized

The land shows its shape again. Sah is recognized not through a single point but through a distinctive arrangement of stars. The figure appears because several lights hold their places in relation to one another.

Maat can be recognized the same way. Rightness has a shape. When enough parts are rightly placed, the whole becomes unmistakable.
''',
  '''
ḥry-ib sꜣḥ — “Heart of Sah”
Harmonization

A star is useful because it appears in relation to others. At the heart of Sah, no shoulder, line, or bright point creates the figure alone. Proportion among them allows the eye to recognize a body.

Harmony in Maat is not sameness. It is difference held in relationships strong enough to become one form.
''',
  '''
sbꜣ sꜣḥ — “Star of Sah”
Expression

What has held inwardly now becomes visible outward. Once the figure of Sah is known, even one well-placed star can call the larger pattern to mind.

Expression works the same way. One gesture, one word, one act can reveal the order a person has been cultivating within. The whole becomes visible through the part.
''',
  '''
msḥtjw — “The Foreleg”
Renewed Strength

The Foreleg turns through the northern sky with the constancy of something that survives change without becoming fixed. Its stars change orientation while their relation to one another remains recognizable.

Maat can survive disruption the same way. Strength is not remaining untouched. It is preserving the relations that make you yourself while the world around you turns.
''',
  '''
ḥry-ib msḥtjw — “Heart of the Foreleg”
Control

The foreleg can brace, lift, push, or strike. Strength becomes useful only when joint, leverage, timing, and direction agree.

At the heart of the Foreleg, Maat turns power into purpose. Control is not the suppression of strength. It is strength governed well enough to serve what matters.

''',
  '''
sbꜣ msḥtjw — “Star of the Foreleg”
Application

The seed is in the earth. Intention has entered material reality.

A pattern in the sky becomes valuable when it can actually guide action below it. Knowledge reaches completion when it enters the hand. Maat is not only recognizing right order; it is learning how to put that order to work.
''',
  '''
ḫnty-ḥr — “Foremost of the Sky”
Attention

Peret has opened. The foremost point is noticed because it appears before the rest. It teaches the eye to care about sequence: what comes first, what follows, and what has not yet appeared.

Maat begins here as attention. Right timing depends on seeing the first small sign before it becomes obvious to everyone.
''',
  '''
ḥry-ib ḫnty-ḥr — “Heart of the Foremost”
Sustained Nurturing

Attention has identified what needs tending. The first appearance catches the eye; the heart of the pattern asks the watcher to remain.

Observation becomes knowledge only through return. What needs care is rarely transformed by one act. Maat is maintained through attention that stays after discovery.
''',
  '''
sbꜣ ḫnty-ḥr — “Star of the Foremost”
Trust

The early weakness has been seen and tended. What was uncertain begins to repeat itself.

A star becomes useful because it returns often enough to be trusted. That trust is not blind; it is earned through recurrence. Maat has the same quality: what is rightly tended becomes dependable, and what becomes dependable can guide.
''',
  '''
knmw — “Khnum”
Formation

Khnum shapes life on the potter's wheel. The image is useful because formation is neither instant nor passive: what begins without final shape is worked until a coherent form appears.

The eye does something similar when it joins separate stars into a recognizable figure. Maat is the order that lets many parts become something whole enough to live.
''',
  '''
ḥry-ib knmw — “Heart of Khnum”
Discernment

The first form has appeared, but it is not finished. Once a shape exists, the question changes from *Is something here?* to *Is it rightly formed?*

At the heart of formation, Maat becomes discernment: looking again, correcting proportion, removing what distorts, and bringing a thing closer to what it can properly become.
''',
  '''
sbꜣ knmw — “Star of Khnum”
Competence

What was shaped through understanding and corrected through discernment has become dependable.

Eventually the eye no longer struggles to recognize the pattern. What once demanded concentration becomes fluent. Competence is practiced order: hand, eye, memory, and judgment have learned to agree.
''',
  '''
špsswt — “The Noble Ones”
Trial

The late fields of Peret meet stronger heat, harder ground, and accumulated fatigue. A cluster of several stars asks more of the eye than one brilliant point: the watcher must distinguish real relationship from noise.

Trial does the same to character. Under easy conditions almost any pattern can look convincing. Pressure reveals which relations actually hold.
''',
  '''
ḥry-ib špsswt — “Heart of the Noble Ones”
Adaptation

The trial has revealed where the method bends. A familiar group does not always present itself at the same angle or under the same conditions, yet the pattern can remain recognizable.

Maat is not brittle. Right order can change its expression without surrendering its structure. Adaptation is the art of preserving what is essential while changing what is not.
''',
  '''
sbꜣ špsswt — “Star of the Noble Ones”
Quiet Competence

The hand now works cleanly. After enough nights, recognition becomes quiet. The practiced watcher no longer forces the pattern into view; the eye knows where to look.

Maat can become like that. Rightness no longer needs to be performed for display. It has been practiced deeply enough to become natural.
''',
  '''
ꜥpdw — “The Birds”
Return

Birds gather where food appears. A flock is recognized not through one rigid outline but through coordinated movement: many bodies continually returning into relation.

A stellar group is similar—separate lights held together by the eye as one figure. Return in Maat is not simply going backward. It is coming again into right relation.
''',
  '''
ḥry-ib ꜥpdw — “Heart of the Birds”
Distribution

Grain moves from field to basket, threshing floor, and granary. A flock survives by spacing: too close and movement collapses; too far apart and the group dissolves.

At the heart of the Birds is the intelligence of distribution. Maat asks not only what is possessed, but whether each thing reaches the place where it can serve the whole.
''',
  '''
sbꜣ ꜥpdw — “Star of the Birds”
Stability

The first grain has been gathered and shares are finding their destinations. Within movement, one recognizable point can anchor the eye and make the larger formation easier to follow.

Stability does not require the flock to stop. Maat can hold a moving system together without preventing it from changing.
''',
  '''
ẖry ꜥrt — “The One Beneath ꜥrt”
Departure

Shemu is no gentle season for travel. The One Beneath ꜥrt is known through relationship—its place beneath another marker helps define what it is.

Departure carries the same challenge. You may leave familiar ground, but you still need a relation by which to know where you are. Maat becomes orientation carried beyond the place that first taught it to you.
''',
  '''
rmn ḥry sꜣḥ — “Shoulder Above Sah”
Endurance

The departure has been made and the heat remains. A shoulder bears because it belongs to a body larger than itself. In Sah, the shoulder makes sense only through its place in the whole figure.

Endurance in Maat is not solitary toughness. It is the capacity to carry weight without losing your relation to the greater form.
''',
  '''
rmn ẖry sꜣḥ — “Shoulder Beneath Sah”
Recovery

Lifted weight must be set down. Above and below belong to the same body; strain and release belong to the same labor.

Recovery is not the opposite of strength. It restores strength to right proportion. Maat does not demand endless exertion. It asks that force be renewed so it can serve again without becoming destruction.
''',
  '''
ḥr-sꜣḥ — “Heru upon Sah”
Vigilance

Heru stands upon Sah. Two celestial identities can occupy the same region of sky without becoming the same thing. The watcher has to distinguish one pattern from another even where they overlap.

Vigilance in Maat is this kind of clear seeing: remaining alert enough to recognize what truly belongs together and what merely appears to.
''',
  '''
ḥry-ib ḥr-sꜣḥ — “Heart of Heru upon Sah”
Restraint

The harvest is secured and the stores are counted. At the heart of an overlapping pattern, the eye must resist the urge to force every light into the same figure.

Restraint is a form of accuracy. Maat is not only knowing what to do. It is also knowing the proper boundary of action—where one order ends and another must be allowed to begin.
''',
  '''
sbꜣ ḥr-sꜣḥ — “Star of Heru upon Sah”
Release

What has been held must be released in its time. A decan holds its place before another takes the watch. The sky preserves order through succession, not possession.

Release is therefore not abandonment. It is making space for the next rightful thing to appear.
''',
  '''
sbꜣ nfr — “The Beautiful Star”
Remembrance

The year has nearly completed its arc. A familiar star appearing again means something different now than it did before: recognition carries memory.

The eye knows because it has seen. Maat depends on this kind of remembrance. The past becomes a pattern by which the present can be measured—not to imprison the present, but to keep hard-won knowledge from disappearing.
''',
  '''
ḥry-ib sbꜣ nfr — “Heart of the Beautiful Star”
Integration

Everything that remains from the year cannot be carried forward in the same way. Memory without integration becomes weight.

At the heart of the Beautiful Star, remembrance is fitted back into the living pattern. What did the past teach? What still belongs? What must change form if it is to remain useful? Maat makes memory serve life.
''',
  '''
sbꜣ sbꜣ nfr — “Star of the Beautiful Star”
Continuity

Recognized memory has been weighed; now what deserves to continue must pass forward.

A star known through another star becomes a chain of recognition—one point helping the eye locate the next. Continuity works the same way. What deserves to survive does not merely repeat itself. It becomes guidance by which what follows can find its place.
''',
  '''
msḥtjw ḫt — “The Crocodiles of the Offering”
Emergence

The crocodile moves between surface and depth without announcing the full power held beneath the water. Eyes, ridge, ripple—sometimes the larger body is known before it is fully seen.

A stellar rising works in much the same way: the pattern does not arrive all at once. Maat often becomes visible first as a sign—enough order emerging from darkness to tell us what is coming.
''',
  '''
ḥry-ib msḥtjw ḫt — “Heart of the Crocodiles of the Offering”
Attentive Stillness

Stillness is not sleep. The crocodile can wait without becoming absent. The night watcher also learns that stillness can be active: remaining long enough for subtle change to become visible.

At the heart of Maat is attention disciplined enough not to mistake impatience for action. Some moments ask us to move. Others ask us to become ready enough to recognize the moment when movement is finally right.
''',
  '''
sbꜣ msḥtjw ḫt — “Star of the Crocodiles of the Offering”
Threshold

This is the last readiness, not the last action. The final marker matters because in a repeating stellar order, the last position already belongs to the return of the first.

A threshold is where completion and beginning touch. Maat does not preserve order by preventing endings. It carries one order to its proper limit and allows another to emerge from it.
''',
];
