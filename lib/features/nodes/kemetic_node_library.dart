import 'kemetic_node_model.dart';

class KemeticNodeLibrary {
  KemeticNodeLibrary._();

  static final List<KemeticNode> nodes = List.unmodifiable(_nodes);

  static final Map<String, KemeticNode> _byId = {
    for (final node in _nodes) node.id.toLowerCase(): node,
  };

  static final Map<String, String> _aliases = {
    for (final node in _nodes)
      for (final alias in node.aliases)
        alias.toLowerCase(): node.id.toLowerCase(),
  };

  static KemeticNode? byId(String id) => _byId[id.toLowerCase()];

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
    id: 'serpent',
    title: 'Serpent',
    glyph: '𓆑',
    aliases: ['Apophis', 'Mehen'],
    body: '''
The serpent appears in Kemetic texts as a force whose nature is not fixed. Its effect depends on how it is positioned, contained, or opposed.
In early Pyramid Texts, serpents are named, invoked, repelled, and controlled. They are not singular in meaning—they are multiple, specific, and situational.
“Fall, crawl away… turn yourself back.”
— Pyramid Texts, serpent spells (various utterances)
This establishes a condition. The serpent is something that must be addressed directly. It is not ignored. It is named, confronted, and placed.
In later solar texts, this pattern becomes clearer:
“Mehen encircles Ra.”
— protective serpent surrounding and containing
“Apophis is cut… he is overthrown.”
— opposing serpent rising against order
These do not describe different forces. They describe different conditions of the same force.
The serpent is also present in relation to multiple netjeru:
* with Ra, as both protector (Mehen) and adversary (Apophis)
* with kingship, as the uraeus—fire at the brow, directed outward
* with Aset, as a constructed instrument used to force revelation
This establishes a pattern. The serpent does not define itself. Its condition is determined by placement, containment, and use.
The serpent defines a continuous condition:
• what has power must be positioned
• what is positioned can protect or oppose
• what is uncontrolled acts against order
Where this is maintained, power supports Ma’at. Where it is not, it becomes Isfet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Aset', targetId: 'aset'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'hawk',
    title: 'Hawk (Heru)',
    glyph: '𓅃',
    aliases: ['Eye of Horus', 'Eye of Heru'],
    body: '''
The hawk is the form through which Heru is recognized. In Kemetic texts, this form is not symbolic alone—it reflects position, sight, and rule.
“Horus… the great god, lord of the sky.”
— Pyramid Texts, Utterance 478
This establishes a condition. What is above sees what is below. Height determines perception.
Heru is not only elevated—he is contested. His position is not assumed. It is challenged, damaged, and restored.
This appears most clearly in the Eye of Heru.
In early tradition, the Eye is:
* taken
* diminished
* divided
* restored
* returned
“The Eye of Horus is whole.”
— recurring formula in Pyramid Texts offerings
The Eye is not simply sight. It is measure, power, and completeness. When damaged, order is reduced. When restored, order returns.
This establishes a pattern:
vision can be lost
what is lost can be restored
what is restored reestablishes rightful position
Heru does not rule without conflict. His authority follows injury, recovery, and recognition.
The hawk defines a continuous condition:
• what must be done must be seen clearly
• what is seen may be challenged or damaged
• what is restored directs rightful action
Where this is maintained, action holds within Ma’at. Where it is not, misjudgment and false claim lead to Isfet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Heru', targetId: 'heru'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'jackal',
    title: 'Jackal (Anpu)',
    glyph: '𓃢',
    aliases: ['Anubis', 'Anpu'],
    body: '''
The jackal is the form of Anpu, associated with the edge of the desert and the place of burial.
In early observation, wild canids moved along the boundary where the cultivated land meets the desert—where the dead are placed.
This establishes the form:
an animal at the boundary
moving between settlement and wasteland
present where the living and the dead meet
In the Pyramid Texts:
“Anubis… who is upon his mountain.”
— Pyramid Texts, Utterance 217
“He who is in the place of embalming.”
— repeated funerary designation
This establishes a condition. The dead do not pass on their own. They must be prepared, preserved, and placed correctly.
Anpu oversees this process.
In later judgment scenes:
“He weighs the heart.”
— Book of Coming Forth by Day, Spell 125
This is not separate from his earlier role. It is the same function extended.
At the boundary:
the body is prepared
the heart is examined
what continues is determined
This establishes a pattern. Transition is not movement alone. It requires correct handling and correct distinction.
The jackal defines a continuous condition:
• what passes must be attended at the boundary
• what is attended must be examined
• what is examined determines what continues
Where this is maintained, transition holds within Ma’at. Where it is not, what should not continue is carried forward, and Isfet spreads.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'nile',
    title: 'Nile (Hapy)',
    glyph: '𓇋𓏏𓊖',
    aliases: ['Hapy', 'Nile'],
    body: '''
The Nile is the source of renewal through inundation. In Kemetic life, it determines growth, sustenance, and survival.
In the Pyramid Texts, the flood is already tied to life-giving provision:
“The canals are filled… the fields are inundated.”
— agricultural imagery in Old Kingdom funerary context
Water is not passive. It brings growth, fills basins, and sustains offerings.
In later hymns, this is made explicit:
“Hapy comes, bringing abundance…
he floods the land with life.”
— Hymn to Hapy
“He makes barley… he creates emmer…
he fills the storehouses.”
This describes a repeating condition. The river rises, withdraws, and returns again. Each phase is required.
Without the flood: nothing grows
without withdrawal: nothing can be used
This establishes a pattern. Life depends on renewal that comes from outside immediate control.
The Nile defines a continuous condition:
• what sustains must be received
• what is received must return in its cycle
• what does not return leads to lack
Where this is maintained, life continues within Ma’at. Where it is interrupted, scarcity develops and Isfet spreads.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'ptah',
    title: 'Ptah',
    glyph: '𓊪𓏏𓎛',
    body: '''
Ptah is the principle of formation through the heart and the tongue. In Kemetic texts, what exists is not formed randomly—it is brought into effect through thought and command.
“It is the heart and the tongue that have power over all limbs…
for every god, every man, every animal… lives by what the heart thinks and the tongue commands.”
— Memphite Theology (Shabaka Stone)
This establishes a condition. What is formed internally does not remain internal. It becomes effective when brought into expression.
The heart conceives.
The tongue declares.
What is declared takes form.
This pattern is not limited to creation. It applies continuously.
In instruction texts, speech is controlled because it produces consequence. In ritual, words are spoken because they establish what is real.
Ptah defines a continuous condition:
• what is formed begins in thought
• what is thought must be expressed
• what is expressed takes effect
Where this is aligned, what is formed holds within Ma’at. Where it is not, what is formed contributes to Isfet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'djehuty',
    title: 'Djehuty',
    glyph: '𓅝',
    aliases: ['Thoth', 'Djehuty'],
    body: '''
Djehuty is the principle of measure, record, and exact determination.
In early texts, he is associated with counting, reckoning, and fixing what is correct. Nothing remains in place without being measured.
“The reckoning of the heavens… the counting of the stars.”
— early hymnic associations to Djehuty
This establishes a condition. What exists must be made exact. Without measure, there is no distinction between what is correct and what has deviated.
This appears most clearly in judgment:
“The heart is weighed against Ma’at.”
— Book of Coming Forth by Day, Spell 125
Djehuty records the result. What is out of balance cannot remain.
Measurement is not passive. It determines what holds.
Djehuty defines a continuous condition:
• what exists must be measured
• what is measured must be recorded
• what is recorded establishes what is true
Where this is maintained, order holds within Ma’at. Where it is not, deviation spreads and Isfet develops.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'shu',
    title: 'Shu',
    glyph: '𓇳𓏏',
    body: '''
Shu is the principle of separation and structural space.
“Shu has lifted up Nut from Geb.”
— Pyramid Texts, Utterance 222
This describes a necessary act. Before separation, sky and earth are not distinct. There is no space for movement or life.
Shu creates distance.
By separating what is joined, he allows function to exist.
This establishes a condition. What is not separated cannot operate. What collapses into sameness loses distinction.
Separation is not a single act. It must be maintained.
Shu defines a continuous condition:
• what must function must be separated
• what is separated must be held apart
• what collapses returns to confusion
Where this is maintained, structure holds within Ma’at. Where it is not, distinction disappears and Isfet spreads.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'maat',
    title: 'Ma’at',
    glyph: '𓆄',
    body: '''
Ma’at is the condition in which all things function correctly.
In early royal texts, this is the central responsibility:
“I have established Ma’at in place of Isfet.”
— Pyramid Texts, Utterance 177
This establishes a condition. Order does not exist on its own. It must be placed and maintained.
Ma’at governs action, speech, and relation.
In instruction texts:
“Do not be arrogant because of your knowledge…
consult with the ignorant as with the wise.”
— Instruction of Ptahhotep
In narrative:
“Do Ma’at for the lord of Ma’at…
it endures.”
— The Eloquent Peasant
Ma’at is not abstract. It is enacted.
This appears across all conditions:
* in creation, where structure must be formed
* in speech, where truth must be aligned
* in judgment, where balance must be determined
Ma’at defines a continuous condition:
• what exists must be in right relation
• what is done must align with truth
• what is said must correspond to what is
Where this holds, order continues. Where it is not maintained, Isfet appears.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
      KemeticNodeLink(phrase: 'Shu', targetId: 'shu'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
    ],
  ),
  KemeticNode(
    id: 'ausar',
    title: 'Ausar',
    glyph: '𓁹',
    aliases: ['Osiris', 'Ausar', 'Asar'],
    body: '''
Ausar is the principle of restoration through gathering and support. In early texts, he is not restored alone—he is found, held, and reestablished by others.
“Isis has come, Nephthys has come…
they have found you.”
— Pyramid Texts
“They take hold of your arm…
they raise you up.”
— Pyramid Texts
This establishes a condition. What is broken does not return on its own. It is located, addressed, and lifted by those around it.
The accounts are not singular. They appear in multiple forms:
* the sisters arrive
* the body is found
* the limbs are attended
* the dead is raised
These are not separate stories. They are repeated actions forming a pattern.
Ausar is preserved, restored, and made to stand again through this collective process.
This establishes a pattern. Loss does not end function if it is met with recognition and support.
Ausar defines a continuous condition:
• what is lost must be found
• what is found must be attended
• what is attended can be restored
Where this is maintained, what has broken can stand again within Ma’at. Where it is not, fragmentation remains and Isfet persists.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Aset', targetId: 'aset'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'aset',
    title: 'Aset',
    glyph: '𓊨',
    aliases: ['Isis', 'Aset'],
    body: '''
Aset is the principle of strategy and effective speech.
In early texts, she does not act through force. She acts through recognition, timing, and words that produce result.
“She has found you… she speaks to you.”
— Osirian funerary texts (continuous tradition from Pyramid Texts)
Her speech accompanies restoration. What she says is not separate from what happens.
This pattern becomes clearer in later tradition:
“Tell me your name…
for a man lives when his name is spoken.”
— Isis and Ra
This establishes a condition. Words do not describe reality—they can alter it when used correctly.
Aset does not speak at random. She constructs the moment, then speaks within it.
This defines a pattern:
knowledge alone does nothing
speech alone does nothing
timed and directed speech produces effect
Her role in the restoration of Ausar and her interaction with Ra follow the same structure.
Aset defines a continuous condition:
• what must be changed must be understood
• what is understood must be applied at the right moment
• what is applied correctly produces result
Where this is maintained, change occurs within Ma’at. Where it is not, effort fails and Isfet remains.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'name', targetId: 'ren'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'heru',
    title: 'Heru',
    glyph: '𓅃',
    aliases: ['Horus', 'Heru'],
    body: '''
Heru is the principle of rightful position established through contest.
“I give the office to Horus, the son of Osiris.”
— The Contendings of Horus and Seth
This follows conflict. Position is not assumed—it is disputed, tested, and decided.
Heru does not inherit without challenge. His claim is opposed. Trials are held. Judgment is required.
This establishes a condition. What is rightful is not secured by origin alone. It must be proven and recognized.
The conflict with Seth is not incidental. It defines the process.
This creates a pattern:
claim → challenge → judgment → establishment
Without this, position can be taken without legitimacy.
Heru defines a continuous condition:
• what is claimed must be tested
• what is tested must be judged
• what is judged must be established
Where this holds, order remains within Ma’at. Where it fails, position is seized without basis and Isfet spreads.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'isfet',
    title: 'Isfet',
    glyph: '𓊹',
    body: '''
Isfet is the principle of breakdown.
“I have established Ma’at in place of Isfet.”
— Pyramid Texts, Utterance 177
This establishes the relationship. Ma’at must be placed. If it is not, Isfet is present.
Isfet is not built. It appears when what should hold does not.
When:
* separation collapses
* measure is ignored
* speech is misused
* restoration is abandoned
Isfet spreads.
It does not correct itself. It continues unless acted upon.
This establishes a pattern. Failure is not contained to a single point. It expands.
Isfet defines a continuous condition:
• what is not maintained breaks down
• what breaks down spreads
• what spreads does not resolve on its own
Where Ma’at is not actively established, Isfet is present.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Shu', targetId: 'shu'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
    ],
  ),
  KemeticNode(
    id: 'ra',
    title: 'Ra',
    glyph: '𓇳',
    body: '''
Ra is the principle of continuation through completed movement. In Kemetic texts, existence does not remain in place—it must move, pass, and return.
“Ra travels across the sky by day and passes through the Duat by night.”
— early solar tradition
This establishes a condition. What exists must continue through its course. It does not persist without movement.
Each cycle is opposed.
In the night journey, forces arise to stop the passage:
“Apophis is cut… he is repelled.”
— solar texts
If the movement fails, return does not occur.
This is not repetition. It is reestablishment.
Each completion restores what has been set.
This establishes a pattern:
what begins must continue
what continues must complete
what completes allows return
Ra defines a continuous condition:
• what is set in motion must be carried through
• what is interrupted breaks continuity
• what completes its course restores what depends on it
Where this is maintained, life continues within Ma’at. Where it is not, interruption leads to Isfet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Apophis', targetId: 'serpent'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'ka',
    title: 'Ka',
    glyph: '𓂓',
    body: '''
The Ka is the principle of sustained presence. In Kemetic texts, what exists does not continue on its own—it must be supported, maintained, and fed.
“O king, your bread is your Ka,
your beer is your Ka.”
— Pyramid Texts, Ut. 32, §51–52
This establishes a condition. What is given becomes what sustains.
The Ka is not contained within the body alone. It accompanies.
“Your Ka is behind you,
your Ka is before you.”
— Pyramid Texts, Ut. 213, §134
This describes a presence that remains with a person, extending beyond a single position.
The Ka can be strengthened or diminished. It depends on what is provided.
Offerings are not symbolic. They maintain the Ka. Without support, what exists begins to decline.
This establishes a pattern:
what exists must be sustained
what is sustained must be fed
what is not fed diminishes
The Ka defines a continuous condition:
• what exists must be supported
• what is supported must be maintained
• what is not maintained weakens
Where this is upheld, presence continues within Ma’at. Where it is not, depletion occurs and Isfet follows.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'ba',
    title: 'Ba',
    glyph: '𓅽',
    body: '''
The Ba is the principle of movement and return. In Kemetic texts, what belongs to a person is not fixed—it can depart and must return.
“Your Ba shall not be turned away from you.”
— Pyramid Texts, Ut. 467, §894
This establishes a condition. What defines a being can separate. It is not bound to remain.
The Ba moves between states. It leaves and comes back.
“O king, you go as a Ba… you return as a Ba.”
— Pyramid Texts, Ut. 556, §1378–1379
This movement is necessary. Without return, continuity is broken.
The Ba is often shown in the form of a bird. This reflects its nature:
it departs
it travels
it returns
This establishes a pattern:
what belongs to a being can move
what moves must remain connected
what does not return is lost
The Ba defines a continuous condition:
• what is essential must be able to move
• what moves must return
• what fails to return breaks continuity
Where this is maintained, identity holds within Ma’at. Where it is not, separation leads to Isfet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'akh',
    title: 'Akh',
    glyph: '𓅜',
    body: '''
The Akh is the principle of effective existence after transformation.
“Become an Akh…
become an effective one among the Akhu.”
— Pyramid Texts, Ut. 474, §932
This establishes a condition. What exists does not automatically endure. It must be made effective.
The Akh is not present at the beginning. It is achieved.
“The king is an Akh…
an imperishable star.”
— Pyramid Texts, Ut. 302, §458
It is associated with:
* the imperishable stars
* enduring presence
* continued ability to act
Transformation is required.
This depends on multiple conditions:
* the body is preserved
* the heart is justified
* the Ka is sustained
* the Ba returns
When these hold, what exists becomes something that does not diminish.
This establishes a pattern:
what exists must be prepared
what is prepared can be transformed
what is transformed becomes effective
The Akh defines a continuous condition:
• what is must be brought into alignment
• what is aligned becomes effective
• what is not aligned does not endure
Where this is achieved, existence continues within Ma’at. Where it is not, continuation fails.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Ba', targetId: 'ba'),
      KemeticNodeLink(phrase: 'heart', targetId: 'ib'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'ren',
    title: 'Ren (Name)',
    glyph: '𓂋𓈖',
    body: '''
The Ren is the principle of identity through being spoken. In Kemetic texts, a being does not remain without its name. What is not spoken does not continue.
“O king, your name lives upon earth…
your name endures.”
— Pyramid Texts, Ut. 424, §763–764
This establishes a condition. To exist is to be recognized. To be recognized, a name must be present.
The name is repeated in offering, in inscription, and in address. It is not written once. It is written again and again so that it does not fall away.
“May your name not perish on earth.”
— Pyramid Texts, Ut. 217, §156
This is not precaution. It is necessity. If the name is not maintained, it disappears.
What is not spoken is not recalled.
What is not recalled does not remain.
The Ren defines a continuous condition:
• what exists must be named
• what is named must be spoken
• what is not spoken fades
Where this is maintained, identity holds within Ma’at. Where it is not, disappearance follows and Isfet takes hold.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'ib',
    title: 'Ib (Heart)',
    glyph: '𓄣',
    body: '''
The Ib is the principle of inner thought, intention, and retained action. In Kemetic texts, it is not separate from the person—it is what remains within and cannot be set aside.
“My heart is in my body…
it will not be taken from me.”
— Pyramid Texts, Ut. 340, §553
This establishes a condition. What is done is not left behind. It remains.
The heart does not forget. It carries what has been done and what has been intended.
It is not exchanged. It is not replaced.
What is within the heart remains with the person.
In later judgment, this becomes explicit:
“The heart is weighed against Ma’at.”
— Book of Coming Forth by Day, Spell 125
This is not a new function. It is the continuation of what is already present.
What is carried is measured.
What is measured determines outcome.
The Ib defines a continuous condition:
• what is done is retained
• what is retained cannot be removed
• what cannot be removed will be weighed
Where this is aligned, the person continues within Ma’at. Where it is not, judgment fails and Isfet prevails.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'sheut',
    title: 'Sheut (Shadow)',
    glyph: '𓈐',
    body: '''
The Sheut is the principle of presence that extends from form. In Kemetic thought, what exists does not end at its boundary—it casts itself outward.
The shadow follows the body. It remains when the body stands. It disappears when the body is removed.
This establishes a condition. Presence is not contained. It is projected.
The shadow does not act independently, but it cannot be separated. It is bound to what produces it.
Where there is form, there is shadow.
Where there is no form, there is no shadow.
In later funerary texts:
“I have come that I may see my shadow.”
— Coffin Texts, Spell 91 (continuation of earlier concept)
This reflects what is already assumed: what exists must remain present beyond itself.
The Sheut defines a continuous condition:
• what exists extends beyond its form
• what extends must remain connected
• what is removed leaves no presence
Where this is maintained, presence holds within Ma’at. Where it is not, absence follows and Isfet takes hold.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'imhotep',
    title: 'Imhotep',
    glyph: '𓇋𓐍𓅓𓏏𓊪',
    aliases: ['Imhotep'],
    body: '''
Imhotep is the principle of constructed wisdom applied through skill and design. In early records, he is not described through myth, but through role and execution.
He appears in the Old Kingdom under the reign of the king:
* chancellor
* overseer of works
* chief of sculptors
* high priest of Ptah
— titles preserved in later inscriptions recalling earlier tradition
He is associated with the construction of the Step Pyramid, a form not found in nature and not produced without measure, planning, and placement.
This establishes a condition. What is known must be made into structure. What is structured must be executed correctly to endure.
His position as high priest of Ptah places him within the same domain where formation begins in the heart and is brought forth through command. What is conceived is not left in thought—it is carried into material form.
This extends through function. What Ptah forms, Imhotep builds.
Measure, proportion, and placement align him with Djehuty. What is reckoned must be applied. What is applied must hold.
The structure itself is the record:
layer placed upon layer
form rising from foundation
nothing misplaced
nothing without measure
This is not symbolic. It is carried out.
In later tradition, this same figure is remembered differently:
* as scribe
* as healer
* as one whose words and knowledge restore
This does not replace the earlier role. It reflects the same condition extended into other domains.
What is understood can be applied to the body as well as to stone.
What is structured can be written as well as built.
In instruction texts attributed to wise officials, such as those associated with Ptahhotep, knowledge is also made practical—ordered, measured, and applied to conduct. This is not a direct lineage, but it reflects the same pattern:
what is known must be usable
what is usable must be applied correctly
Imhotep defines a continuous condition:
• what is known must be structured
• what is structured must be executed
• what is executed must hold
Where this is maintained, what is built endures within Ma’at. Where it is not, what is made fails and Isfet spreads.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ptah', targetId: 'ptah'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'sopdet',
    title: 'Sopdet (Sirius)',
    glyph: '𓇼',
    aliases: ['Sopdet', 'Sothis', 'Sirius'],
    body: '''
Sopdet is the heliacal rising star that opened the Kemetic year and announced the flood.
Her appearance at dawn set the civil calendar and guided agricultural timing; she is a marker of renewal, not ornament.
Linked to Aset and Ausar, she signals that order returns through cyclical rising.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Aset', targetId: 'aset'),
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
    ],
  ),
  KemeticNode(
    id: 'coffin_texts',
    title: 'Coffin Texts',
    glyph: '𓏏',
    body: '''
The Coffin Texts are Middle Kingdom spells written inside coffins so non-royal dead could navigate the Duat.
They adapt Pyramid Text utterances and add journeys, transformations, and protections for the individual.
They bridge the Old Kingdom inscriptions and the later Book of the Dead, keeping knowledge active beyond the tomb.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'Book of the Dead', targetId: 'book_of_the_dead'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
    ],
  ),
  KemeticNode(
    id: 'papyrus_chester_beatty_iv',
    title: 'Papyrus Chester Beatty IV',
    glyph: '𓏞',
    body: '''
Papyrus Chester Beatty IV contains the "Immortality of Writers" teaching.
It argues that measured words endure longer than stone or offspring, preserving ren and Ka when bodies decay.
The text shows how scribal craft is bound to Maʿat and the renewal of memory.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'ren', targetId: 'ren'),
    ],
  ),
  KemeticNode(
    id: 'kemet',
    title: 'Kemet (Black Land)',
    glyph: '𓈎',
    body: '''
Kemet, the “Black Land,” names the dark silt left by the Nile and the country built upon it.
It stands in contrast to the red desert, marking the bounds where cultivation and settlement can hold.
Restoring those boundaries after inundation is part of keeping Maʿat in place.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Nile', targetId: 'nile'),
    ],
  ),
  KemeticNode(
    id: 'pyramid_texts',
    title: 'Pyramid Texts',
    glyph: '𓉐',
    body: '''
The Pyramid Texts are Old Kingdom utterances carved inside royal pyramids.
They provide ascent, protection, and identification with netjeru so the king joins the sky and travels the Duat.
Their formulas establish speech as action and become the base for later funerary corpora.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'hathor',
    title: 'Hathor',
    glyph: '𓇋𓏏𓆑',
    aliases: ['Hathor'],
    body: '''
Hathor embodies joy, music, and the sky-cow who carries Ra.
She is also the Eye of Ra who must be soothed, showing that delight and danger come from the same force when measure is lost.
Her cult at Dendera celebrates beauty as proof of alignment with Maʿat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Eye of Ra', targetId: 'eye_of_ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'dendera',
    title: 'Dendera',
    glyph: '𓉗',
    body: '''
Dendera is the principal temple of Hathor, home to rituals of music, fertility, and the rising of the Eye.
Its ceilings record star clocks and zodiacal imagery, linking observation of the sky to cult practice.
The site shows how celebration, astronomy, and renewal meet in daily service.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Hathor', targetId: 'hathor'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'decans', targetId: 'decans'),
    ],
  ),
  KemeticNode(
    id: 'sah',
    title: 'Sah (Orion)',
    glyph: '✷',
    body: '''
Sah is the constellation Orion, associated with Ausar.
Its rising with Sopdet marks seasonal change and affirms the god’s reappearance in the sky.
Sah frames night navigation and the idea that the dead travel with the stars.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Sopdet', targetId: 'sopdet'),
    ],
  ),
  KemeticNode(
    id: 'abydos',
    title: 'Abydos',
    glyph: '𓉐',
    body: '''
Abydos is the chief cult center of Ausar and a major necropolis.
Pilgrims left stelae to join his mysteries and secure remembrance in the west.
The site ties local burial to national myths of death and restoration.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'decans',
    title: 'Decans',
    glyph: '✵',
    body: '''
The decans are thirty-six star groups rising in roughly ten-day intervals.
Priest-astronomers used them to track hours of night, regulate ritual, and mirror the sun’s passage through the Duat.
They embody the practice of keeping time through recurring celestial order.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
    ],
  ),
  KemeticNode(
    id: 'duat',
    title: 'Duat',
    glyph: '𓁢',
    aliases: ['Duat'],
    body: '''
The Duat is the unseen realm the sun and the dead traverse each night.
It is ordered in gates and regions; safe passage depends on names, offerings, and measured speech.
Journeying through the Duat restores Ra and tests whether a person aligns with Maʿat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Book of the Dead', targetId: 'book_of_the_dead'),
    ],
  ),
  KemeticNode(
    id: 'renenutet',
    title: 'Renenutet',
    glyph: '𓆤',
    body: '''
Renenutet is the guardian of nourishment and harvest.
She oversees grain stores and the just distribution that sustains Ka and community.
Offerings to her acknowledge that abundance must be tended, not assumed.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'house_of_life',
    title: 'House of Life (Per Ankh)',
    glyph: '𓏠',
    body: '''
The House of Life is the temple library and scriptorium.
Scribes copied rituals, medical texts, astronomy, and instruction here, treating writing as service to the gods.
It joined intellectual labor to cult practice so knowledge stayed aligned with Maʿat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
    ],
  ),
  KemeticNode(
    id: 'instruction_ptahhotep',
    title: 'Instruction of Ptahhotep',
    glyph: '𓏏',
    body: '''
The Instruction of Ptahhotep teaches measured speech, humility, and fairness.
Its maxims link daily conduct to Maʿat and warn against arrogance or heated words.
Students copied it for centuries as practical ethics.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'sekhmet',
    title: 'Sekhmet',
    glyph: '𓃭',
    body: '''
Sekhmet is the fierce Eye of Ra whose heat can protect or destroy.
Rituals to cool and pacify her remind that power must be governed and returned to balance.
She embodies the discipline of directing force so it serves Maʿat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'rekh_wer',
    title: 'Rekh-Wer (Great Knowing)',
    glyph: '𓂋',
    body: '''
Rekh-Wer names knowledge applied to sustain order.
It emphasizes counting, surveying, and teaching so effort matches reality.
The concept pairs Djehuty’s measure with the restrained strength of Sekhmet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Djehuty', targetId: 'djehuty'),
      KemeticNodeLink(phrase: 'Sekhmet', targetId: 'sekhmet'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'set',
    title: 'Set',
    glyph: '𓋴',
    body: '''
Set embodies force and contest.
He defends Ra’s barque against Apophis yet opposes Heru in disputes of rule, showing power’s double edge.
Set must be placed and judged so his strength serves Maʿat rather than isfet.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Heru', targetId: 'heru'),
      KemeticNodeLink(phrase: 'Isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'esna_temple',
    title: 'Esna Temple',
    glyph: '𓉗',
    body: '''
The Temple of Esna, dedicated chiefly to Khnum, preserves late hymns and cosmology.
Its inscriptions include decan lists and festival texts that align local worship to wider celestial rhythms.
Esna shows how regional temples participated in national timekeeping and renewal.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Khnum', targetId: 'khnum'),
      KemeticNodeLink(phrase: 'decans', targetId: 'decans'),
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
    ],
  ),
  KemeticNode(
    id: 'shai',
    title: 'Šai (Destiny)',
    glyph: '𓋴',
    aliases: ['Šai', 'Shai', 'šai'],
    body: '''
Šai personifies allotment or destiny.
Wisdom texts invoke Šai to remind that outcomes must be met with proportion, not grasping.
Acknowledging Šai frames effort within limits without denying responsibility.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(
        phrase: 'Instruction of Amenemope',
        targetId: 'instruction_amenemope',
      ),
    ],
  ),
  KemeticNode(
    id: 'offering_formula',
    title: 'Offering Formula (ḥtp-dỉ-nsw)',
    glyph: '𓏏',
    body: '''
The offering formula grants bread, beer, oxen, and fowl to the dead through the king and the gods.
It ties giver, recipient, and divine order so Ka and ren remain supplied.
Its repetition on stelae shows how memory and sustenance are joined in Maʿat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'shemu',
    title: 'Shemu',
    glyph: '𓇯',
    body: '''
Shemu is the dry season of harvest and transport.
Work shifts to gathering, preserving, and carrying what inundation and growth provided.
The season teaches balance under heat and the discipline of circulation.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'amduat',
    title: 'Amduat',
    glyph: '𓁢',
    body: '''
The Amduat maps Ra’s twelve-hour journey through the Duat.
It names beings, gates, and transformations that allow sunrise.
The text models persistence through darkness with knowledge and measure.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'khepri',
    title: 'Khepri',
    glyph: '𓆣',
    body: '''
Khepri is the morning sun as scarab, continually becoming.
He rolls the light into being each day, teaching steady effort and renewal.
Meditating on Khepri aligns human labor with emergence rather than haste.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'hotep',
    title: 'ḥtp (Peace/Offering)',
    glyph: '𓊵',
    body: '''
ḥtp expresses satisfaction and balance achieved through correct offering.
It underlies formulas like ḥtp-dỉ-nsw and names that signal a state of settled order.
Cooling excess and giving rightly create ḥtp and keep Maʿat in place.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(
        phrase: 'Offering Formula',
        targetId: 'offering_formula',
      ),
    ],
  ),
  KemeticNode(
    id: 'instruction_amenemope',
    title: 'Instruction of Amenemope',
    glyph: '𓏏',
    body: '''
The Instruction of Amenemope guides restraint, patience, and fairness under pressure.
It counsels quiet endurance over grasping advantage, warning that excess invites isfet.
Its maxims shaped later wisdom traditions on speech and care for the vulnerable.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'isfet', targetId: 'isfet'),
    ],
  ),
  KemeticNode(
    id: 'eye_of_ra',
    title: 'Eye of Ra',
    glyph: '𓂋',
    body: '''
The Eye of Ra is the outward force of the sun, often manifest as Hathor or Sekhmet.
Sent to punish, it must be cooled and returned so creation survives its own intensity.
The Eye shows that power directed outward still requires measure and recall.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Hathor', targetId: 'hathor'),
      KemeticNodeLink(phrase: 'Sekhmet', targetId: 'sekhmet'),
    ],
  ),
  KemeticNode(
    id: 'tomb_inscriptions',
    title: 'Tomb Inscriptions',
    glyph: '𓐍',
    body: '''
Tomb inscriptions record names, deeds, and offering prayers to sustain the dead.
They join image and text so Ka and ren receive continued attention from the living.
Their presence affirms that memory and provision are required for continuity.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'ren', targetId: 'ren'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'middle_kingdom_funerary',
    title: 'Middle Kingdom Funerary Tradition',
    glyph: '𓊹',
    body: '''
Middle Kingdom funerary practice broadened access to afterlife knowledge.
Coffin Texts, stelae, and models show households preparing with spells, offerings, and remembered names.
The period links royal formulas to family care within Maʿat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Coffin Texts', targetId: 'coffin_texts'),
      KemeticNodeLink(phrase: 'Offering Formula', targetId: 'offering_formula'),
    ],
  ),
  KemeticNode(
    id: 'nut',
    title: 'Nut',
    glyph: '𓇯',
    body: '''
Nut is the sky who swallows the sun each night and births it each dawn.
She arches over Geb, creating the space where life unfolds.
Her embrace frames cycles of return and the promise of emergence.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'horizon',
    title: 'Akhet (Horizon)',
    glyph: '𓈌',
    body: '''
Akhet, the horizon, is where sky meets earth and where Ra rises.
It marks transition points—birth, rebirth, and the visible proof of return.
Temples align to the horizon to mirror cosmic order and welcome light correctly.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ra', targetId: 'ra'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'natron',
    title: 'Natron',
    glyph: '𓈗',
    body: '''
Natron is the mineral salt used to purify, preserve, and reset ritual space.
In mummification it dries and cleanses; in daily rites it prepares altars and vessels.
Its use shows that order depends on deliberate cleansing before renewal.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'nebet_het',
    title: 'Nebet-Het',
    glyph: '𓇓',
    aliases: ['Nebet-Het', 'Nephthys'],
    body: '''
Nebet-Het stands at thresholds and guards the dead with Aset.
She brings protection and lament that restores, present in rites of preparation and mourning.
Her role shows care at the boundaries between worlds.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Aset', targetId: 'aset'),
      KemeticNodeLink(phrase: 'Ausar', targetId: 'ausar'),
    ],
  ),
  KemeticNode(
    id: 'khnum',
    title: 'Khnum',
    glyph: '𓎛𓈖𓅓',
    body: '''
Khnum fashions bodies on the potter’s wheel and controls the inundation at Elephantine.
He embodies formation through craft and the measured release of water.
Temple hymns portray him shaping Ka and ensuring fertility.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ka', targetId: 'ka'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
      KemeticNodeLink(phrase: 'decans', targetId: 'decans'),
    ],
  ),
  KemeticNode(
    id: 'memphite_theology',
    title: 'Memphite Theology',
    glyph: '𓉐',
    aliases: ['Shabaka Stone', 'Memphite Theology'],
    body: '''
The Memphite Theology, preserved on the Shabaka Stone, describes creation through Ptah’s heart and tongue.
It centers thought and speech as the engines of formation and kingship.
The text shows inscription as preservation of Maʿat against decay.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Ptah', targetId: 'ptah'),
      KemeticNodeLink(phrase: 'Ma’at', targetId: 'maat'),
    ],
  ),
  KemeticNode(
    id: 'book_of_the_dead',
    title: 'Book of the Dead',
    glyph: '𓏏',
    aliases: ['Book of Coming Forth by Day', 'Book of the Dead'],
    body: '''
The Book of the Dead is a New Kingdom collection of spells for safe passage and vindication.
It draws on Pyramid and Coffin Texts, emphasizing judgment, names, and transformation.
Customized papyri show personal engagement with Maʿat and the Duat.''',
    linkMap: const [
      KemeticNodeLink(phrase: 'Coffin Texts', targetId: 'coffin_texts'),
      KemeticNodeLink(phrase: 'Pyramid Texts', targetId: 'pyramid_texts'),
      KemeticNodeLink(phrase: 'Duat', targetId: 'duat'),
    ],
  ),
];
