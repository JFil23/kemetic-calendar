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
    aliases: ['Osiris', 'Ausar'],
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
];
