import 'offering_table_day_contract.dart';

class OfferingTableTimerState {
  const OfferingTableTimerState({
    this.elapsedMilliseconds = 0,
    this.runningSinceMilliseconds,
  });

  final int elapsedMilliseconds;
  final int? runningSinceMilliseconds;

  bool get isRunning => runningSinceMilliseconds != null;

  int elapsedAt(DateTime now) {
    final started = runningSinceMilliseconds;
    if (started == null) return elapsedMilliseconds;
    return elapsedMilliseconds +
        (now.millisecondsSinceEpoch - started).clamp(0, 1 << 31);
  }

  OfferingTableTimerState toggle(DateTime now, int targetSeconds) {
    final elapsed = elapsedAt(now).clamp(0, targetSeconds * 1000);
    if (isRunning) {
      return OfferingTableTimerState(elapsedMilliseconds: elapsed);
    }
    if (elapsed >= targetSeconds * 1000) return this;
    return OfferingTableTimerState(
      elapsedMilliseconds: elapsed,
      runningSinceMilliseconds: now.millisecondsSinceEpoch,
    );
  }

  OfferingTableTimerState settle(DateTime now, int targetSeconds) {
    final elapsed = elapsedAt(now);
    if (elapsed < targetSeconds * 1000) return this;
    return OfferingTableTimerState(elapsedMilliseconds: targetSeconds * 1000);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'elapsed_ms': elapsedMilliseconds,
    if (runningSinceMilliseconds != null)
      'running_since_ms': runningSinceMilliseconds,
  };

  factory OfferingTableTimerState.fromJson(Object? raw) {
    if (raw is! Map) return const OfferingTableTimerState();
    int? value(String key) => switch (raw[key]) {
      final int number => number,
      final num number => number.toInt(),
      _ => null,
    };
    return OfferingTableTimerState(
      elapsedMilliseconds: value('elapsed_ms') ?? 0,
      runningSinceMilliseconds: value('running_since_ms'),
    );
  }
}

class OfferingTableDayViewState {
  OfferingTableDayViewState({
    Map<String, bool>? actions,
    Map<String, String>? words,
    Map<String, String>? picks,
    Map<String, OfferingTableTimerState>? timers,
    Map<String, String>? timestamps,
  }) : actions = <String, bool>{...?actions},
       words = <String, String>{...?words},
       picks = <String, String>{...?picks},
       timers = <String, OfferingTableTimerState>{...?timers},
       timestamps = <String, String>{...?timestamps};

  final Map<String, bool> actions;
  final Map<String, String> words;
  final Map<String, String> picks;
  final Map<String, OfferingTableTimerState> timers;
  final Map<String, String> timestamps;

  OfferingTableDayViewState copy() => OfferingTableDayViewState(
    actions: actions,
    words: words,
    picks: picks,
    timers: timers,
    timestamps: timestamps,
  );

  bool moveDone(OfferingTableMoveContract move, {required DateTime now}) {
    switch (move.kind) {
      case OfferingTableMoveKind.name:
        return (words[move.slot ?? move.id] ?? '').trim().isNotEmpty;
      case OfferingTableMoveKind.pick:
        return (picks[move.id] ?? '').trim().isNotEmpty;
      case OfferingTableMoveKind.timer:
        final timer = timers[move.id] ?? const OfferingTableTimerState();
        final elapsed = timer.elapsedAt(now);
        if (move.completeUnderTarget) return elapsed > 0 && !timer.isRunning;
        return elapsed >= (move.targetSeconds ?? 0) * 1000;
      case OfferingTableMoveKind.tap:
      case OfferingTableMoveKind.drink:
      case OfferingTableMoveKind.truth:
        return actions[move.id] == true;
    }
  }

  bool dayComplete(OfferingTableDayContract contract, {required DateTime now}) {
    bool done(String id) =>
        moveDone(contract.moves.firstWhere((move) => move.id == id), now: now);
    if (contract.day == 8) {
      return done('hunger') && (done('portion') || done('schedule'));
    }
    if (contract.day == 23) {
      return done('delayed') && (done('moved') || done('truth'));
    }
    return contract.moves
        .where((move) => !move.optional)
        .every((move) => moveDone(move, now: now));
  }

  bool get isEmpty =>
      actions.values.every((value) => !value) &&
      words.values.every((value) => value.trim().isEmpty) &&
      picks.values.every((value) => value.trim().isEmpty) &&
      timers.values.every(
        (value) => value.elapsedMilliseconds == 0 && !value.isRunning,
      ) &&
      timestamps.values.every((value) => value.trim().isEmpty);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'actions': actions,
    'words': words,
    'picks': picks,
    'timers': timers.map((key, value) => MapEntry(key, value.toJson())),
    'timestamps': timestamps,
  };

  factory OfferingTableDayViewState.fromJson(Object? raw) {
    if (raw is! Map) return OfferingTableDayViewState();
    Map<String, dynamic> map(String key) {
      final value = raw[key];
      if (value is! Map) return <String, dynamic>{};
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    return OfferingTableDayViewState(
      actions: map('actions').map((key, value) => MapEntry(key, value == true)),
      words: map(
        'words',
      ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
      picks: map(
        'picks',
      ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
      timers: map('timers').map(
        (key, value) => MapEntry(key, OfferingTableTimerState.fromJson(value)),
      ),
      timestamps: map(
        'timestamps',
      ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
    );
  }
}
