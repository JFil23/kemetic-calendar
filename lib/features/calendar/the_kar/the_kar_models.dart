import 'package:flutter/material.dart';

enum KarNetjer { djehuty, maat, sekhmet, hetHeru, khepri, ptah }

extension KarNetjerContent on KarNetjer {
  String get key => switch (this) {
    KarNetjer.djehuty => 'djehuty',
    KarNetjer.maat => 'maat',
    KarNetjer.sekhmet => 'sekhmet',
    KarNetjer.hetHeru => 'hetheru',
    KarNetjer.khepri => 'khepri',
    KarNetjer.ptah => 'ptah',
  };

  String get name => switch (this) {
    KarNetjer.djehuty => 'Djehuty',
    KarNetjer.maat => 'Maat',
    KarNetjer.sekhmet => 'Sekhmet',
    KarNetjer.hetHeru => 'Het-Heru',
    KarNetjer.khepri => 'Khepri',
    KarNetjer.ptah => 'Ptah',
  };

  String get kemeticName => switch (this) {
    KarNetjer.djehuty => 'Ḏḥwty',
    KarNetjer.maat => 'Mꜣꜥt',
    KarNetjer.sekhmet => 'Sḫmt',
    KarNetjer.hetHeru => 'Ḥwt-Ḥr',
    KarNetjer.khepri => 'Ḫprj',
    KarNetjer.ptah => 'Ptḥ',
  };

  String get historicalSource => switch (this) {
    KarNetjer.djehuty => 'Dyn. 4 · Wadi Maghara · likely Ḏḥwty',
    KarNetjer.maat => 'Old Kingdom texts · period-style reconstruction',
    KarNetjer.sekhmet =>
      'Dyn. 5 · Sekhmet attested · lioness-form reconstruction',
    KarNetjer.hetHeru => 'Dyn. 4 · Menkaura Valley Temple · Giza',
    KarNetjer.khepri =>
      'Old Kingdom ḫprr scarab symbolism · conservative Khepri reconstruction',
    KarNetjer.ptah => 'Dyn. 1 · Tarkhan bowl · early Ptah re-composed',
  };

  String get familiar => switch (this) {
    KarNetjer.djehuty => 'Djehuty · Ḏḥwty',
    KarNetjer.maat => 'Maat · Mꜣꜥt · truth, right measure, right order',
    KarNetjer.sekhmet => 'Sekhmet · Sḫmt · power, protection, healing',
    KarNetjer.hetHeru => 'Het-Heru · Ḥwt-Ḥr · joy, welcome, generative warmth',
    KarNetjer.khepri => 'Khepri · Ḫprj · becoming, emergence, renewal',
    KarNetjer.ptah => 'Ptah · Ptḥ · craft, creation, making real',
  };

  String get role => switch (this) {
    KarNetjer.djehuty => 'discernment · learning · clarification',
    KarNetjer.maat => 'truth · right measure · right order',
    KarNetjer.sekhmet => 'power · protection · healing',
    KarNetjer.hetHeru => 'joy · welcome · generative warmth',
    KarNetjer.khepri => 'becoming · emergence · renewal',
    KarNetjer.ptah => 'craft · creation · making real',
  };

  String get phrase => switch (this) {
    KarNetjer.djehuty => 'Wisdom',
    KarNetjer.maat => 'Measure',
    KarNetjer.sekhmet => 'Strength',
    KarNetjer.hetHeru => 'Joy',
    KarNetjer.khepri => 'The self that can become again',
    KarNetjer.ptah => 'The imagined thing made real',
  };

  String get flow => switch (this) {
    KarNetjer.djehuty =>
      'Five impossible images that let wisdom take a form that belongs to you.',
    KarNetjer.maat =>
      'Five impossible images that make size, time, skill and proportion physical.',
    KarNetjer.sekhmet =>
      'Five impossible images where weight, scale and physical power stop obeying normal rules.',
    KarNetjer.hetHeru =>
      'Five impossible images built from the forms, people, music and daydreams that already feel joyful to you.',
    KarNetjer.khepri =>
      'Five impossible images that let ability, ambition and change become visible on you.',
    KarNetjer.ptah =>
      'Five impossible images that give projects, tools and unfinished ideas physical form.',
  };

  String get asset => 'assets/the_kar/$key.png';

  int get accentValue => switch (this) {
    KarNetjer.djehuty => 0xFF91B7C7,
    KarNetjer.maat => 0xFFD4AE43,
    KarNetjer.sekhmet => 0xFFB87962,
    KarNetjer.hetHeru => 0xFFC78FA9,
    KarNetjer.khepri => 0xFF6FA78A,
    KarNetjer.ptah => 0xFF9B8DB8,
  };

  int get accent2Value => switch (this) {
    KarNetjer.djehuty => 0xFFC9E3EB,
    KarNetjer.maat => 0xFFF1D98D,
    KarNetjer.sekhmet => 0xFFE3AF94,
    KarNetjer.hetHeru => 0xFFECC7D8,
    KarNetjer.khepri => 0xFFB7DEC8,
    KarNetjer.ptah => 0xFFD2C8E6,
  };

  int get deepValue => switch (this) {
    KarNetjer.djehuty => 0xFF16252B,
    KarNetjer.maat => 0xFF2C2411,
    KarNetjer.sekhmet => 0xFF2B1712,
    KarNetjer.hetHeru => 0xFF2A1721,
    KarNetjer.khepri => 0xFF14251C,
    KarNetjer.ptah => 0xFF211B2B,
  };

  List<String> get labels => switch (this) {
    KarNetjer.djehuty => const [
      'Wisdom, dressed',
      'The throne',
      'What you figured out',
      'Inside the object',
      'Ninety years old',
    ],
    KarNetjer.maat => const [
      'Measure a mountain',
      'Measure a goal',
      'Twenty-four feet',
      'The skill balloon',
      'Make the scale level',
    ],
    KarNetjer.sekhmet => const [
      'Back pocket',
      'One fingertip',
      'The feather',
      'Hold the sun',
      'Walk the ocean',
    ],
    KarNetjer.hetHeru => const [
      'Your animal-self',
      'Wear the song',
      'The meal',
      'Cloud daydream',
      'Bestow joy',
    ],
    KarNetjer.khepri => const [
      'Your stage',
      'Childhood ambition',
      'The new advantage',
      'Step out',
      'The next poster',
    ],
    KarNetjer.ptah => const [
      'Give it a face',
      'Hold the project',
      'Toolbox hands',
      'Invent the object',
      'Finished',
    ],
  };

  List<String> get prompts => switch (this) {
    KarNetjer.djehuty => const [
      'Picture yourself in an outfit and room that represent wisdom. Place the one object in your hand that a wise person would carry.',
      'Make your wisdom object large enough to use as a throne. Picture yourself sitting on it in the same outfit.',
      'Think of something you finally figured out. Take one real object from that moment and place it in your wisdom room. Make it enormous.',
      'Make your wisdom object transparent. Fill it with tiny versions of things you know well.',
      'Picture yourself at ninety years old in the same room. Keep the outfit and object, but show what decades of use have done to both.',
    ],
    KarNetjer.maat => const [
      'Imagine you had to measure every inch of a mountain. You can be a giant or normal size. Invent a tool to get the job done.',
      'Imagine one of your personal goals as a physical object of your choosing. Use your invented tool to measure it.',
      'Imagine tomorrow as a 24-foot ribbon. Use your tool to cut off exactly as much time as you want for yourself. Picture the two pieces.',
      'Imagine a skill you are proud of as a balloon. Blow it up as big as you can. It will never pop.',
      'Put yourself on one side of a giant scale. Put everything that gets your time on the other. Make the scale level.',
    ],
    KarNetjer.sekhmet => const [
      'Imagine something too large to carry—a car, a building, anything. Put it in your back pocket without changing its proportions.',
      'Take the huge thing out of your pocket and balance it on one fingertip. Keep yourself normal size.',
      'Picture the strongest person you can think of struggling to lift a feather. Then pick the feather up and hand it to them.',
      'Imagine yourself larger than the sun. Grab it with your dominant hand. Notice it does not burn. What will you do with it?',
      'Envision yourself walking across the ocean to a vacation destination of your choosing. You have a boat on a leash like a pet. How large is the boat and what is on it?',
    ],
    KarNetjer.hetHeru => const [
      'Picture yourself as your favorite animal doing a thing that brings joy to your life. You can be alone or with people.',
      'Turn the song you never skip into an outfit for your animal-self. Picture yourself wearing it.',
      'You are sharing a meal with two of your favorite people. Each bite you take causes something that makes you happy to appear in the room with you. What does the room look like halfway through your meal?',
      'Imagine yourself floating in a lake looking up at the sky. The clouds above you are shaped like a daydream that makes you happy. What do the clouds show?',
      'Picture yourself as the netjer Het-Heru. You are allowed to bestow joy on one person you care for. How do you do it?',
    ],
    KarNetjer.khepri => const [
      'Think of something you are good at. Picture yourself doing it in front of a huge audience. Make sure people you respect are there.',
      'Think of a goal or ambition you held as a child. Envision yourself as a character in a movie achieving that goal.',
      'Think of something you want to become better at. Give yourself one exaggerated body part that would make you incredible at it.',
      'Picture one version of yourself you have outgrown as an outfit. Imagine yourself stepping out of it. What are you wearing underneath?',
      'Imagine a movie poster for the next version of your life. Picture your outfit, your pose, and the one object you are holding.',
    ],
    KarNetjer.ptah => const [
      'Think of a task or project you want to finish. Give it a face and personality. Put the first positive thing it says to you in a speech bubble.',
      'Make the project small enough to fit in your hand without removing any details. Picture yourself holding it.',
      'Turn your hands into a toolbox. Replace each finger with a tool you use—or wish existed.',
      'Think of a problem you deal with often. Invent one object that could solve it instantly. Picture the object in your hands.',
      'Bring back the project from your first image. Picture it completely finished and the same height as you. Give it an outfit that matches its personality.',
    ],
  };

  List<String> get partials => switch (this) {
    KarNetjer.djehuty => const [
      'Your wisdom outfit, room, and the one object in your hand.',
      'Your wisdom object is large enough to sit on.',
      'One real object from something you finally figured out, made enormous.',
      'Your wisdom object is transparent and filled with tiny things you know well.',
      'The same room, outfit, and object decades later.',
    ],
    KarNetjer.maat => const [
      'A mountain and the tool you invented to measure every inch of it.',
      'One personal goal as a physical object, measured with your tool.',
      'Tomorrow is a 24-foot ribbon cut into two pieces.',
      'A skill you are proud of is a balloon that cannot pop.',
      'You are on one side of a giant scale; everything that gets your time is on the other.',
    ],
    KarNetjer.sekhmet => const [
      'Something impossibly large is in your back pocket without changing size.',
      'The huge thing is balanced on one fingertip while you stay normal size.',
      'The strongest person you can think of cannot lift a feather. You can.',
      'You are larger than the sun and it does not burn your hand.',
      'You are walking across the ocean with a boat on a leash.',
    ],
    KarNetjer.hetHeru => const [
      'You are your favorite animal, doing something that brings you joy.',
      'The song you never skip has become an outfit for your animal-self.',
      'You are halfway through a meal with two favorite people; happy things keep appearing in the room.',
      'You are floating in a lake beneath clouds shaped like a happy daydream.',
      'You are Het-Heru and can bestow joy on one person you care for.',
    ],
    KarNetjer.khepri => const [
      'You are doing something you are good at before a huge audience that includes people you respect.',
      'A childhood ambition has become a movie, and you are the character achieving it.',
      'One exaggerated body part makes you incredible at something you want to improve.',
      'An outgrown version of you is an outfit you can step out of.',
      'The next version of your life is a movie poster with your outfit, pose, and one object.',
    ],
    KarNetjer.ptah => const [
      'Your unfinished project has a face, a personality, and one positive thing to say.',
      'The project fits in your hand without losing any details.',
      'Your hands are toolboxes; each finger is a tool you use or wish existed.',
      'One object you invented can instantly solve a problem you deal with often.',
      'The project from your first image is finished, your height, and dressed to match its personality.',
    ],
  };

  static KarNetjer fromKey(String raw) => KarNetjer.values.firstWhere(
    (value) => value.key == raw,
    orElse: () => KarNetjer.djehuty,
  );
}

@immutable
class KarStage {
  const KarStage(this.day, this.place);
  final int day;
  final String place;
}

const List<KarStage> kKarStages = <KarStage>[
  KarStage(1, 'Threshold'),
  KarStage(4, 'Left jamb'),
  KarStage(9, 'Right jamb'),
  KarStage(15, 'Lintel'),
  KarStage(22, 'Base'),
  KarStage(30, 'Inner chamber'),
];

enum KarCycleStatus { active, completed, abandoned }

@immutable
class KarEntryVersion {
  const KarEntryVersion({
    required this.id,
    required this.kind,
    required this.content,
    required this.createdAt,
    required this.source,
    this.supersedesId,
  });
  final String id;
  final String kind;
  final String content;
  final DateTime createdAt;
  final String source;
  final String? supersedesId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'content': content,
    'created_at': createdAt.toUtc().toIso8601String(),
    'source': source,
    if (supersedesId != null) 'supersedes_id': supersedesId,
  };

  factory KarEntryVersion.fromJson(Map<String, dynamic> json) =>
      KarEntryVersion(
        id: json['id'] as String,
        kind: json['kind'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        source: json['source'] as String? ?? 'cycle_sitting',
        supersedesId: json['supersedes_id'] as String?,
      );
}

@immutable
class KarPlacement {
  const KarPlacement({
    required this.stageIndex,
    this.activeVersionId,
    this.versions = const [],
  });
  final int stageIndex;
  final String? activeVersionId;
  final List<KarEntryVersion> versions;
  KarEntryVersion? get activeVersion {
    for (final version in versions.reversed) {
      if (version.id == activeVersionId) return version;
    }
    return null;
  }

  KarPlacement place(KarEntryVersion version) => KarPlacement(
    stageIndex: stageIndex,
    activeVersionId: version.id,
    versions: <KarEntryVersion>[...versions, version],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'stage_index': stageIndex,
    'active_version_id': activeVersionId,
    'versions': versions.map((value) => value.toJson()).toList(),
  };

  factory KarPlacement.fromJson(Map<String, dynamic> json) => KarPlacement(
    stageIndex: (json['stage_index'] as num).toInt(),
    activeVersionId: json['active_version_id'] as String?,
    versions: [
      for (final raw in json['versions'] as List? ?? const [])
        KarEntryVersion.fromJson(Map<String, dynamic>.from(raw as Map)),
    ],
  );
}

@immutable
class KarWalkRecord {
  const KarWalkRecord({required this.completedAt, required this.outcomes});
  final DateTime completedAt;
  final List<String> outcomes;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'completed_at': completedAt.toUtc().toIso8601String(),
    'outcomes': outcomes,
  };
  factory KarWalkRecord.fromJson(Map<String, dynamic> json) => KarWalkRecord(
    completedAt: DateTime.parse(json['completed_at'] as String),
    outcomes: List<String>.from(json['outcomes'] as List? ?? const []),
  );
}

@immutable
class KarCycle {
  const KarCycle({
    required this.id,
    required this.sequence,
    required this.status,
    required this.anchorDate,
    required this.placements,
    this.flowId,
    this.scheduleStale = false,
    this.completedAt,
    this.walks = const [],
  });
  final String id;
  final int sequence;
  final KarCycleStatus status;
  final DateTime anchorDate;
  final int? flowId;
  final bool scheduleStale;
  final DateTime? completedAt;
  final List<KarPlacement> placements;
  final List<KarWalkRecord> walks;

  int get placedCount =>
      placements.where((value) => value.activeVersion != null).length;
  bool get isActive => status == KarCycleStatus.active;
  DateTime dateForStage(int index) =>
      anchorDate.add(Duration(days: kKarStages[index].day - 1));

  KarCycle copyWith({
    KarCycleStatus? status,
    DateTime? anchorDate,
    int? flowId,
    bool? scheduleStale,
    DateTime? completedAt,
    List<KarPlacement>? placements,
    List<KarWalkRecord>? walks,
  }) => KarCycle(
    id: id,
    sequence: sequence,
    status: status ?? this.status,
    anchorDate: anchorDate ?? this.anchorDate,
    flowId: flowId ?? this.flowId,
    scheduleStale: scheduleStale ?? this.scheduleStale,
    completedAt: completedAt ?? this.completedAt,
    placements: placements ?? this.placements,
    walks: walks ?? this.walks,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sequence': sequence,
    'status': status.name,
    'anchor_date': _date(anchorDate),
    'flow_id': flowId,
    'schedule_stale': scheduleStale,
    if (completedAt != null)
      'completed_at': completedAt!.toUtc().toIso8601String(),
    'placements': placements.map((value) => value.toJson()).toList(),
    'walks': walks.map((value) => value.toJson()).toList(),
  };

  factory KarCycle.fromJson(Map<String, dynamic> json) => KarCycle(
    id: json['id'] as String,
    sequence: (json['sequence'] as num).toInt(),
    status: KarCycleStatus.values.byName(json['status'] as String),
    anchorDate: DateTime.parse(json['anchor_date'] as String),
    flowId: (json['flow_id'] as num?)?.toInt(),
    scheduleStale: json['schedule_stale'] as bool? ?? false,
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
    placements: [
      for (final raw in json['placements'] as List? ?? const [])
        KarPlacement.fromJson(Map<String, dynamic>.from(raw as Map)),
    ],
    walks: [
      for (final raw in json['walks'] as List? ?? const [])
        KarWalkRecord.fromJson(Map<String, dynamic>.from(raw as Map)),
    ],
  );
}

@immutable
class KarDraft {
  const KarDraft({
    required this.kind,
    required this.content,
    required this.savedAt,
  });
  final String kind;
  final String content;
  final DateTime savedAt;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    'content': content,
    'saved_at': savedAt.toUtc().toIso8601String(),
  };
  factory KarDraft.fromJson(Map<String, dynamic> json) => KarDraft(
    kind: json['kind'] as String,
    content: json['content'] as String,
    savedAt: DateTime.parse(json['saved_at'] as String),
  );
}

@immutable
class KarShrine {
  const KarShrine({
    required this.id,
    required this.netjer,
    required this.revision,
    required this.cycles,
    this.activeCycleId,
    this.drafts = const {},
  });
  final String id;
  final KarNetjer netjer;
  final int revision;
  final String? activeCycleId;
  final List<KarCycle> cycles;
  final Map<String, KarDraft> drafts;

  KarCycle? get activeCycle {
    for (final cycle in cycles.reversed) {
      if (cycle.id == activeCycleId && cycle.isActive) return cycle;
    }
    return null;
  }

  List<KarCycle> get earlierCycles =>
      List.unmodifiable(cycles.where((value) => value.id != activeCycleId));

  KarShrine copyWith({
    int? revision,
    String? activeCycleId,
    bool clearActiveCycle = false,
    List<KarCycle>? cycles,
    Map<String, KarDraft>? drafts,
  }) => KarShrine(
    id: id,
    netjer: netjer,
    revision: revision ?? this.revision,
    activeCycleId: clearActiveCycle
        ? null
        : activeCycleId ?? this.activeCycleId,
    cycles: cycles ?? this.cycles,
    drafts: drafts ?? this.drafts,
  );

  KarShrine beginCycle({
    required String cycleId,
    required DateTime anchorDate,
    required int flowId,
  }) {
    if (activeCycle != null) {
      throw StateError('This Kꜣr already has an active walk.');
    }
    final cycle = KarCycle(
      id: cycleId,
      sequence: cycles.length + 1,
      status: KarCycleStatus.active,
      anchorDate: DateUtils.dateOnly(anchorDate),
      flowId: flowId,
      placements: List<KarPlacement>.generate(
        5,
        (index) => KarPlacement(stageIndex: index),
      ),
    );
    return copyWith(activeCycleId: cycle.id, cycles: [...cycles, cycle]);
  }

  KarCycle _editableCycle(String? cycleId) {
    final candidateId = cycleId ?? activeCycleId;
    for (final cycle in cycles.reversed) {
      if (cycle.id == candidateId && cycle.status != KarCycleStatus.abandoned) {
        return cycle;
      }
    }
    throw StateError('Start or select a Kꜣr cycle before saving a scene.');
  }

  KarShrine saveDraft({
    required int stageIndex,
    required KarDraft draft,
    String? cycleId,
  }) {
    final cycle = _editableCycle(cycleId);
    return copyWith(drafts: {...drafts, '${cycle.id}:$stageIndex': draft});
  }

  KarShrine placeDraft({
    required int stageIndex,
    required String versionId,
    required DateTime now,
    String source = 'cycle_sitting',
    String? cycleId,
  }) {
    final cycle = _editableCycle(cycleId);
    final draftKey = '${cycle.id}:$stageIndex';
    final draft = drafts[draftKey];
    if (draft == null || draft.content.trim().isEmpty) {
      throw StateError('Save a drawing or description first.');
    }
    final placements = [...cycle.placements];
    final previous = placements[stageIndex].activeVersion;
    placements[stageIndex] = placements[stageIndex].place(
      KarEntryVersion(
        id: versionId,
        kind: draft.kind,
        content: draft.content,
        createdAt: now,
        source: source,
        supersedesId: previous?.id,
      ),
    );
    final cyclesCopy = [
      for (final value in cycles)
        value.id == cycle.id ? cycle.copyWith(placements: placements) : value,
    ];
    final draftsCopy = {...drafts}..remove(draftKey);
    return copyWith(cycles: cyclesCopy, drafts: draftsCopy);
  }

  KarShrine reanchor({required DateTime anchorDate, required int flowId}) {
    final cycle = activeCycle;
    if (cycle == null) {
      throw StateError('Only an active Kꜣr cycle can be rescheduled.');
    }
    final updated = cycle.copyWith(
      anchorDate: DateUtils.dateOnly(anchorDate),
      flowId: flowId,
      scheduleStale: false,
    );
    return copyWith(
      cycles: [
        for (final value in cycles) value.id == cycle.id ? updated : value,
      ],
    );
  }

  KarShrine completeWalk({
    required DateTime now,
    required List<String> outcomes,
  }) {
    final cycle = activeCycle;
    if (cycle == null) throw StateError('No active Kꜣr cycle.');
    final updated = cycle.copyWith(
      status: KarCycleStatus.completed,
      completedAt: now,
      walks: [
        ...cycle.walks,
        KarWalkRecord(completedAt: now, outcomes: outcomes),
      ],
    );
    return copyWith(
      clearActiveCycle: true,
      cycles: [
        for (final value in cycles) value.id == cycle.id ? updated : value,
      ],
    );
  }

  Map<String, dynamic> toStateJson() => <String, dynamic>{
    'schema_version': 1,
    'active_cycle_id': activeCycleId,
    'cycles': cycles.map((value) => value.toJson()).toList(),
    'drafts': drafts.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory KarShrine.fromRow(Map<String, dynamic> row) {
    final state = Map<String, dynamic>.from(row['state'] as Map? ?? const {});
    final draftsRaw = Map<String, dynamic>.from(
      state['drafts'] as Map? ?? const {},
    );
    return KarShrine(
      id: row['id'] as String,
      netjer: KarNetjerContent.fromKey(row['netjer_key'] as String),
      revision: (row['revision'] as num?)?.toInt() ?? 0,
      activeCycleId: state['active_cycle_id'] as String?,
      cycles: [
        for (final raw in state['cycles'] as List? ?? const [])
          KarCycle.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      drafts: {
        for (final entry in draftsRaw.entries)
          entry.key: KarDraft.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
