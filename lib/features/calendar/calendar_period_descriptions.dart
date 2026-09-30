part of 'calendar_page.dart';

/* ─────────── Month / Decan info text ─────────── */

const Map<int, String> _monthInfo = {
  1: '''
Month 1 — Thoth / Ḏḥwty
Akhet · Finding orientation when familiar ground disappears

Water covers the land. Roads vanish. Field boundaries soften into the flood until almost nothing that once felt solid can be trusted by the eye alone. Thoth meets the year here because the first need is orientation: look before acting, gather what can still be observed, and allow a pattern to form before deciding what it means.

This is more than patience. A mistaken starting point carries its error into every correction that follows. Maat begins by making uncertainty legible—knowing where you stand, what remains true, and what deserves attention before labor begins. The work of this month is not to force clarity from the flood, but to measure carefully enough that right action will have somewhere firm to begin.
''',
  2: '''
Month 2 — Paopi / Mnḫt
Akhet · Turning orientation into movement

The water still dominates, yet waiting has lost its claim. Boats begin to matter again. What watching revealed must now be carried forward, and the first test is whether clarity can become direction without losing itself in motion.

Paopi is not a call to hurry. A burden carried badly spills; a direction that cannot survive repetition was never stable enough to guide. Maat here means keeping purpose intact while conditions change—adjusting the load, the pace, or the route without forgetting where the movement is meant to lead. What has been understood now has to travel well enough to arrive whole.
''',
  3: '''
Month 3 — Hathor / Ḥwt-Ḥr
Akhet · Recognizing harmony when the world takes shape again

Banks reappear. Distances grow legible. The flood has withdrawn enough for shape itself to matter again, and what was previously hidden can be seen in relation to what surrounds it. Hathor turns that recognition toward harmony—not merely seeing the parts, but sensing when the parts belong together.

The lesson is not that order should feel severe. Right relation can be felt as beauty, ease, rhythm, and joy. But pleasure is not proof by itself; harmony has to rest on something real. Maat asks you to notice where life has become coherent enough to be enjoyed without confusing intensity for wholeness. What has truly stabilized can now become graceful.
''',
  4: '''
Month 4 — Ka-ḥer-Ka / Kȝ-ḥr-Kȝ
Akhet · Strength that survives turning

The inundation has finished its work. Land returns, yet the year cannot simply resume where it left off. What survived the flood must now be made useful. Ka-Ḥer-Ka is strength that can turn, move, and accept direction without losing the relations that make it recognizable.

Renewed power should not be spent simply to prove that it has returned. The deeper test is whether strength can serve continuity. Maat turns vitality into purpose: preserve what matters through change, then place your force where it can actually support what comes next. Strength becomes trustworthy when it can be directed without becoming waste, excess, or display.
''',
  5: '''
Month 5 — Šef-Bedet / Šf-bdt
Peret · Seeing what has begun to grow

Peret opens with emergence. Water leaves the fields and the labor shifts from surviving abundance to tending what has already appeared. The smallest signs now carry weight because what is fragile can still be strengthened—or quietly lost—before the damage becomes obvious.

Attention must therefore deepen into sustained care, and care, in time, into trust. Too little abandons what has begun; too much can smother it. Maat here is nourishment held in proportion: enough attention to keep growth alive, enough consistency to let it strengthen, and enough restraint to stop interfering once it begins to hold its own.
''',
  6: '''
Month 6 — Rekh-Wer / Rḫ-wr
Peret · Giving form to what has emerged

Growth has begun, but emergence is not completion. Form must now be shaped, tested, corrected, and made strong enough to hold. Rekh-Wer is craft in the widest sense—the slow work of turning attention into knowledge, and knowledge into skill that can survive outside the moment in which it was learned.

The moral is practical: knowing is unfinished until it can guide reliable action. Maat asks for accuracy without vanity—look again, correct what is off, and make the method repeatable enough to be trusted by another hand. Skill becomes valuable when it can carry weight. Knowledge that cannot be used, tested, or transmitted is still only potential.
''',
  7: '''
Month 7 — Rekh-Nedjes / Rḫ-nḏs
Peret · Discovering what holds under pressure

Resistance arrives. Heat rises. The ground hardens. Repetition becomes tiring. Methods that once seemed sufficient begin to show their limits, and what was learned under easier conditions must now prove what it actually contains.

Rekh-Nedjes treats difficulty as information rather than insult. Pressure exposes structure. Maat does not require a method to remain unchanged; it requires the direction to remain true while the method adapts. Do not defend an approach merely because it once worked. Let strain reveal what is weak, keep what still serves, and change what no longer carries the work.
''',
  8: '''
Month 8 — Renwet / Rnnwt
Peret · Gathering and giving what has matured

Promise has become yield. What grew must now be gathered, sorted, moved, and shared without letting abundance tip into disorder. Renwet is not simply the pleasure of having more; it is the intelligence required to receive the harvest without damaging the future that produced it.

Scarcity forces restraint. Plenty requires you to choose it. Maat asks where the harvest should go, what must be enjoyed now, what must be protected, and what must be returned to circulation so life can continue beyond the moment of success. The harvest is not complete when it is gathered. It is complete when abundance has been placed into right relation.
''',
  9: '''
Month 9 — Hnsw / Ḫnsw
Shemu · Carrying what must be carried

Shemu brings heat, harvest, movement, and weight. The work is no longer mainly about making things grow. It is about carrying the consequences of what has already grown—moving goods, obligations, decisions, and responsibilities toward the places where they belong.

Hnsw asks how to leave, endure, and recover without losing the direction that first set the journey in motion. Maat turns endurance into proportion rather than stubbornness. Carry the load in a way that lets both the carrier and what is carried arrive whole. A journey is not made righteous by difficulty; it is made right by maintaining purpose through difficulty.
''',
  10: '''
Month 10 — Ḥenti-ḥet / Ḥnt-ḥtj
Shemu · Knowing what to hold and what to release

The harvest is secured. Stores can be counted. The immediate urgency of gathering gives way to another discipline: guarding what matters without becoming possessed by it. Ḥenti-Ḥet is about vigilance, clear boundaries, and the wisdom of timely release.

Power includes the ability to stop. What once required force may now require restraint; what once needed protection may eventually need to circulate. Maat asks you to distinguish stewardship from possession. Hold what still serves continuity, release what has reached its proper destination, and do not let the strength that built the storehouse become the force that closes it forever.
''',
  11: '''
Month 11 — Pa-Ipi / ỉpt-ḥmt
Shemu · Turning experience into usable memory

The year has traveled far enough that memory itself becomes material. What happened can now be seen as pattern rather than merely event, and experience can be weighed for what it actually taught rather than for how strongly it is remembered.

Pa-Ipi asks what deserves to be kept, what must be integrated, and what is still fit to continue. Maat does not turn the past into a shrine. It turns memory into guidance. Keep what proved true, repair what still has value, and release what survives only because no one has questioned it. Continuity depends on choosing inheritance rather than merely receiving it.
''',
  12: '''
Month 12 — Mesut-Ra / Mswt-Rꜥ
Shemu · Standing at the edge of another beginning

The visible work is nearly finished. Heat remains. The river has not yet remade the land, and the next cycle has not fully announced itself. Mesut-Ra belongs to the charged stillness before renewal—the moment when completion begins to turn into readiness.

No more needs to be demanded from the old year simply because a new one is coming. Maat here is completion without grasping: close what can be closed, name what remains unresolved, and do not carry disorder forward disguised as inheritance. What has ended should be allowed to end. What is forming should be given enough darkness and quiet to become ready before it is asked to appear.
''',
  13: '''
Month 13 – Heriu Renpet (ḥr.w rnpt)
Days Upon the Year · The threshold between completion and return

Heriu Renpet stands outside the twelve counted months, after the year's work has completed and before Wp Rnpt opens the cycle again. These days are a pause in ordinary time, remembered through the births of Ausar, Heru the Elder, Set, Aset, and Nebet-Het—powers of restoration, sight, force, protection, mourning, and passage gathered at the edge of renewal.

The year has exhaled and has not yet inhaled again. That is the point. Renewal begins with readiness, not motion. Maat asks that what is complete be sealed, what is disordered be left behind, and what must continue be made fit to cross the threshold. A new cycle should not begin because the calendar turned; it should begin because space has been made for it to arrive cleanly.
''',
};

const List<String> _decanInfo = [
  '''
tpy-ꜥ sbꜣw — “Foremost of the Stars”
Orientation

The flood has erased familiar boundaries. The first task is not action but bearing. The foremost stars matter because they give the eye somewhere to begin. Once one point is known, the rest of the sky can be read in relation to it.

Maat begins the same way. Before right action comes right orientation: know where you stand, what surrounds you, and which direction remains true when the usual landmarks disappear. A misplaced beginning carries its error forward. Before correcting anything, make sure you are looking from the right point.
''',
  '''
ḥry-ib sbꜣw — “Heart of the Stars”
Integration

A single observation cannot guide by itself. At the heart of the stars, no one light explains the pattern. Meaning arrives through distance, proportion, repetition, and the relations among the lights.

Maat is not assembled from isolated truths either. Wisdom gathers fragments until the larger form appears. Do not rush to act on pieces that have not yet become coherent. Judgment becomes reliable only after the observations can live together without being forced.
''',
  '''
sbꜣw — “The Stars”
Expression

The flood is beginning to reveal the land again. What was hidden has not returned unchanged, yet enough points are visible now for the shape beneath them to be recognized.

Scattered stars become a figure once the eye can hold them together. Maat becomes visible in the same way: inner order eventually takes outward form. Understanding is not complete while it remains private. What you have learned should begin to show in how you speak, choose, record, and move.
''',
  '''
ꜥḥꜣy — “The Riser”
Initiation of Motion

The land is still mostly water, but waiting has ended. A rising star does not reveal the whole night at once. First there is only one point breaking free of the horizon.

That can be enough. Maat does not always begin with certainty; sometimes it begins with the first movement that brings hidden order into view. Start what is ready, but do not confuse urgency with direction. A measured beginning creates a path that can sustain what follows.
''',
  '''
ḥry-ib ꜥḥꜣy — “Heart of the Riser”
Sustained Effort

The journey has started; now its direction must survive repetition. Emergence at the horizon is dramatic. Higher in the sky the work grows quieter: the star simply continues its course.

The heart of rising is not the first motion but the ability to keep moving after beginning has lost its novelty. In Maat, direction becomes character through repetition. Keep asking whether the movement still serves the reason it began; effort that outruns discernment can travel far in the wrong direction.
''',
  '''
sbꜣ nfr — “The Beautiful Star”
Stability

What began in ꜥḥꜣy and was regulated through its heart has now become dependable. The beautiful star is not beautiful because it never moves, but because it can be recognized again in its proper relation.

Nfr holds beauty, goodness, fitness, and completion close together. Stability in Maat is not stillness; it is a form that continues to fit. The goal now is repeatability. What is truly stable can be trusted to carry the work without being rebuilt every time.
''',
  '''
sꜣḥ — “Sah”
Stability Recognized

The land shows its shape again. Sah is recognized not through a single point but through a distinctive arrangement of stars. The figure appears because several lights hold their places in relation to one another.

Maat can be recognized the same way. Rightness has a shape. When enough parts are rightly placed, the whole becomes unmistakable. Confirm the ground before celebrating it. Stability assumed too early turns relief into another source of error.
''',
  '''
ḥry-ib sꜣḥ — “Heart of Sah”
Harmonization

A star is useful because it appears in relation to others. At the heart of Sah, no shoulder, line, or bright point creates the figure alone. Proportion among them allows the eye to recognize a body.

Harmony in Maat is not sameness. It is difference held in relationships strong enough to become one form. The work now is relational: timing, proportion, cooperation, and adjustment. A stable part is not enough if the parts cannot live together.
''',
  '''
sbꜣ sꜣḥ — “Star of Sah”
Expression

What has held inwardly now becomes visible outward. Once the figure of Sah is known, even one well-placed star can call the larger pattern to mind.

Expression works the same way. One gesture, one word, one act can reveal the order a person has been cultivating within. Let what is beautiful make the underlying order easier to recognize, but keep delight inside measure. Expression should reveal harmony, not become a substitute for it.
''',
  '''
msḥtjw — “The Foreleg”
Renewed Strength

The Foreleg turns through the northern sky with the constancy of something that survives change without becoming fixed. Its stars change orientation while their relation to one another remains recognizable.

Maat can survive disruption the same way. Strength is not remaining untouched; it is preserving what makes you coherent while the world turns. Do not spend renewed power as soon as you feel it. Let strength become stable before asking it to carry the next burden.
''',
  '''
ḥry-ib msḥtjw — “Heart of the Foreleg”
Control

The foreleg can brace, lift, push, or strike. Strength becomes useful only when joint, leverage, timing, and direction agree.

At the heart of the Foreleg, Maat turns power into purpose. Control is not suppression; it is strength governed well enough to serve what matters. The question is no longer whether you have force, but whether you can place it precisely enough that it supports instead of damages.
''',
  '''
sbꜣ msḥtjw — “Star of the Foreleg”
Application

The seed is in the earth. Intention has entered material reality, and what was only potential now has consequences.

A pattern in the sky becomes valuable when it can guide action below it. Knowledge reaches completion when it enters the hand. Maat is not only recognizing right order; it is putting that order to work. Apply strength where continuity needs it, not where effort will be most visible.
''',
  '''
ḫnty-ḥr — “Foremost of the Sky”
Attention

Peret has opened. The foremost point is noticed because it appears before the rest. It teaches the eye to care about sequence: what comes first, what follows, and what has not yet appeared.

Maat begins here as attention. Right timing depends on seeing the first small sign before it becomes obvious to everyone. Notice early enough that care can still be gentle. What is ignored until crisis will require repair instead of tending.
''',
  '''
ḥry-ib ḫnty-ḥr — “Heart of the Foremost”
Sustained Nurturing

Attention has identified what needs tending. The first appearance catches the eye; the heart of the pattern asks the watcher to remain.

Observation becomes knowledge only through return. What needs care is rarely transformed by one act. Maat is maintained through attention that stays after discovery. Consistency matters more than intensity here: keep giving what is needed without exhausting the source or overwhelming what is growing.
''',
  '''
sbꜣ ḫnty-ḥr — “Star of the Foremost”
Trust

The early weakness has been seen and tended. What was uncertain begins to repeat itself, and what needed constant correction starts to hold its own rhythm.

A star becomes useful because it returns often enough to be trusted. That trust is earned, not blind. Maat has the same quality: what is rightly tended becomes dependable. The lesson now is to stop overcorrecting. What has been cared for also needs room to become itself.
''',
  '''
knmw — “Khnum”
Formation

Khnum shapes life on the potter's wheel. Formation is neither instant nor passive: what begins without final shape is worked until a coherent form appears.

The eye does something similar when it joins separate stars into a recognizable figure. Maat is the order that lets many parts become something whole enough to live. Shape with understanding rather than force. Pressure that ignores the material can build failure directly into the thing being made.
''',
  '''
ḥry-ib knmw — “Heart of Khnum”
Discernment

The first form has appeared, but it is not finished. Once a shape exists, the question changes from *Is something here?* to *Is it rightly formed?*

At the heart of formation, Maat becomes discernment: look again, correct proportion, remove what distorts, and bring the thing closer to what it can properly become. Precision alone is not wisdom. A highly skilled correction made without judgment can create disorder with remarkable efficiency.
''',
  '''
sbꜣ knmw — “Star of Khnum”
Competence

What was shaped through understanding and corrected through discernment has become dependable. Eventually the eye no longer struggles to recognize the pattern; what once demanded concentration becomes fluent.

Competence is practiced order: hand, eye, memory, and judgment have learned to agree. Maat becomes visible as repeatable right action rather than performance. If a skill cannot survive repetition or be carried without constant rescue, it is not finished yet.
''',
  '''
špsswt — “The Noble Ones”
Trial

The late fields of Peret meet stronger heat, harder ground, and accumulated fatigue. A cluster of several stars asks more of the eye than one brilliant point: the watcher must distinguish real relationship from noise.

Trial does the same to character. Under easy conditions almost any pattern can look convincing. Pressure reveals which relations actually hold. Let difficulty tell the truth. What survives first strain deserves deeper trust; what immediately collapses needs more formation, not more defense.
''',
  '''
ḥry-ib špsswt — “Heart of the Noble Ones”
Adaptation

The trial has revealed where the method bends. A familiar group does not always present itself at the same angle or under the same conditions, yet the pattern can remain recognizable.

Maat is not brittle. Right order can change its expression without surrendering its structure. Adaptation means preserving what is essential while changing what is not. Hold the direction; change the method. Refusing a necessary adjustment turns useful pressure into fracture.
''',
  '''
sbꜣ špsswt — “Star of the Noble Ones”
Quiet Competence

The hand now works cleanly. After enough nights, recognition becomes quiet. The practiced watcher no longer forces the pattern into view; the eye knows where to look.

Maat can become like that. Rightness no longer needs to be performed for display because it has been practiced deeply enough to become natural. Let the work prove the skill. A competence that still needs constant announcement has not yet fully settled into itself.
''',
  '''
ꜥpdw — “The Birds”
Return

Birds gather where food appears. A flock is recognized not through one rigid outline but through coordinated movement: many bodies continually returning into relation.

A stellar group is similar—separate lights held together by the eye as one figure. Return in Maat is not simply going backward; it is coming again into right relation. Receive the first result as confirmation, not completion. Early gain is information before it is abundance.
''',
  '''
ḥry-ib ꜥpdw — “Heart of the Birds”
Distribution

Grain moves from field to basket, threshing floor, and granary. A flock survives by spacing: too close and movement collapses; too far apart and the group dissolves.

At the heart of the Birds is the intelligence of distribution. Maat asks not only what is possessed, but whether each thing reaches the place where it can serve the whole. Receiving creates responsibility. Plenty becomes continuity only when it is routed rather than merely held.
''',
  '''
sbꜣ ꜥpdw — “Star of the Birds”
Stability

The first grain has been gathered and shares are finding their destinations. Within movement, one recognizable point can anchor the eye and make the larger formation easier to follow.

Stability does not require the flock to stop. Maat can hold a moving system together without preventing change. The harvest is truly stable when it can feed the present without emptying the future. Enough now and enough later are part of the same measure.
''',
  '''
ẖry ꜥrt — “The One Beneath ꜥrt”
Departure

Shemu is no gentle season for travel. The One Beneath ꜥrt is known through relationship—its place beneath another marker helps define what it is.

Departure carries the same challenge. You may leave familiar ground, but you still need a relation by which to know where you are. Maat becomes orientation carried beyond the place that first taught it to you. Leave if you must, but take your measure with you.
''',
  '''
rmn ḥry sꜣḥ — “Shoulder Above Sah”
Endurance

The departure has been made and the heat remains. A shoulder bears because it belongs to a body larger than itself. In Sah, the shoulder makes sense only through its place in the whole figure.

Endurance in Maat is not solitary toughness. It is the capacity to carry weight without losing relation to the greater form. Pace, load, and recovery all matter. Persistence that breaks the carrier or damages the burden is not discipline; it is mismeasure.
''',
  '''
rmn ẖry sꜣḥ — “Shoulder Beneath Sah”
Recovery

Lifted weight must be set down. Above and below belong to the same body; strain and release belong to the same labor.

Recovery is not the opposite of strength. It restores strength to right proportion. Maat does not demand endless exertion; it asks that force be renewed so it can serve again without becoming destruction. Rest is part of the work when the work is meant to continue.
''',
  '''
ḥr-sꜣḥ — “Heru upon Sah”
Vigilance

Heru stands upon Sah. Two celestial identities can occupy the same region of sky without becoming the same thing. The watcher has to distinguish one pattern from another even where they overlap.

Vigilance in Maat is this kind of clear seeing: remain alert enough to recognize what truly belongs together and what merely appears to. Watchfulness should sharpen judgment, not harden into suspicion or control. Protect the boundary without inventing threats beyond it.
''',
  '''
ḥry-ib ḥr-sꜣḥ — “Heart of Heru upon Sah”
Restraint

The harvest is secured and the stores are counted. At the heart of an overlapping pattern, the eye must resist the urge to force every light into the same figure.

Restraint is a form of accuracy. Maat is not only knowing what to do; it is knowing the proper boundary of action—where one order ends and another must begin. Stopping can be right action. Continuing past the measure of the moment can damage what earlier effort successfully preserved.
''',
  '''
sbꜣ ḥr-sꜣḥ — “Star of Heru upon Sah”
Release

What has been held must be released in its time. A decan holds its place before another takes the watch. The sky preserves order through succession, not possession.

Release is therefore not abandonment. It is making space for the next rightful thing to appear. Maat completes holding through timely letting go. What should move onward eventually becomes disorder if the closed hand mistakes possession for preservation.
''',
  '''
sbꜣ nfr — “The Beautiful Star”
Remembrance

The year has nearly completed its arc. A familiar star appearing again means something different now than it did before: recognition carries memory.

The eye knows because it has seen. Maat depends on this kind of remembrance. The past becomes a pattern by which the present can be measured—not to imprison the present, but to keep hard-won knowledge from disappearing. Remember what proved true, not merely what was vivid.
''',
  '''
ḥry-ib sbꜣ nfr — “Heart of the Beautiful Star”
Integration

Everything that remains from the year cannot be carried forward in the same way. Memory without integration becomes weight.

At the heart of the Beautiful Star, remembrance is fitted back into the living pattern. What did the past teach? What still belongs? What must change form if it is to remain useful? Maat makes memory serve life. The goal is not to preserve everything; it is to turn experience into clear inheritance.
''',
  '''
sbꜣ sbꜣ nfr — “Star of the Beautiful Star”
Continuity

Recognized memory has been weighed; now what deserves to continue must pass forward. A star known through another star becomes a chain of recognition—one point helping the eye locate the next.

Continuity works the same way. What deserves to survive does not merely repeat itself; it becomes guidance by which what follows can find its place. Pass on the measure, not just the habit. Inheritance should reduce confusion for the next cycle rather than reproduce it.
''',
  '''
msḥtjw ḫt — “The Crocodiles of the Offering”
Emergence

The crocodile moves between surface and depth without announcing the full power held beneath the water. Eyes, ridge, ripple—sometimes the larger body is known before it is fully seen.

A stellar rising works much the same way: the pattern does not arrive all at once. Maat often becomes visible first as a sign—enough order emerging from darkness to tell us what is coming. Let the sign be enough. Forcing full visibility too early can damage what is still becoming.
''',
  '''
ḥry-ib msḥtjw ḫt — “Heart of the Crocodiles of the Offering”
Attentive Stillness

Stillness is not sleep. The crocodile can wait without becoming absent. The night watcher also learns that stillness can be active: remaining long enough for subtle change to become visible.

At the heart of Maat is attention disciplined enough not to mistake impatience for action. Some moments ask us to move; others ask us to become ready enough to recognize when movement is finally right. Do not manufacture an action merely to escape the discomfort of waiting.
''',
  '''
sbꜣ msḥtjw ḫt — “Star of the Crocodiles of the Offering”
Threshold

This is the last readiness, not the last action. The final marker matters because in a repeating stellar order, the last position already belongs to the return of the first.

A threshold is where completion and beginning touch. Maat does not preserve order by preventing endings; it carries one order to its proper limit and allows another to emerge. Readiness is complete when nothing more needs to be added. Finish cleanly enough that the next beginning does not inherit unfinished disorder.
''',
];
