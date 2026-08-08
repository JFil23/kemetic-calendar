part of 'calendar_page.dart';

/// Whether a locally-inserted `_Note` has been confirmed by a hydration pass.
///
/// [confirmed] — derived from state hydration already agrees with (reminder
/// regeneration, shared-calendar seeding, warm-start paint, debug fixtures).
/// If a later pass drops the row, that is authoritative: the row should go.
///
/// [unconfirmed] — no hydration pass has returned this row yet. It may already
/// be persisted (`_saveSingleNoteOnly` upserts, *then* inserts locally) or the
/// write may still be in flight (Flow Studio planned notes). Either way a pass
/// that began before the write landed will not contain it, so dropping it on
/// commit is a bug rather than authority. These are ledgered.
enum NoteConfirmation { confirmed, unconfirmed }

class _UnconfirmedNote {
  _UnconfirmedNote({
    required this.dayKey,
    required this.note,
    required this.createdAt,
  });

  final String dayKey;
  final _Note note;
  final DateTime createdAt;
}

/// Keeps unconfirmed notes alive across the clear-and-replace in
/// `commitVisibleCalendarState`, retiring each entry as soon as a hydration
/// pass returns a matching row.
///
/// Deliberately *not* epoch-based: an in-flight load must still commit its
/// server data — it just must not erase rows hydration hasn't seen yet.
class _UnconfirmedNoteLedger {
  /// Backstop for rows whose write failed silently, or that were deleted on
  /// another device. Bounded resurrection beats unbounded.
  static const Duration ttl = Duration(minutes: 2);

  /// Registration is refused past this point rather than evicting the oldest
  /// entry: evicting would silently drop a still-live row, which is the exact
  /// failure this ledger exists to prevent.
  static const int maxEntries = 200;

  final List<_UnconfirmedNote> _entries = <_UnconfirmedNote>[];

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  @visibleForTesting
  List<_Note> get unconfirmedNotes =>
      _entries.map((e) => e.note).toList(growable: false);

  /// [isSameNote] should be `_sameStandaloneLaneNote`. Registering an identity
  /// that is already present replaces it, so edit-then-resave and double-add
  /// paths update in place instead of inflating the ledger and skewing the
  /// confirmed counts.
  ///
  /// Callers must supply a note carrying a `clientEventId`; without one,
  /// confirmation matching degrades to title+time and can retire the wrong
  /// entry. Registration is refused (and logged) rather than accepted blind.
  bool register({
    required String dayKey,
    required _Note note,
    required bool Function(_Note a, _Note b) isSameNote,
  }) {
    final cid = note.clientEventId?.trim();
    if (cid == null || cid.isEmpty) {
      _calendarDebugPrint(
        '[unconfirmed] refused register without cid '
        'title=<redacted chars=${note.title.length}>',
      );
      return false;
    }

    _pruneExpired();

    final existing = _entries.indexWhere(
      (entry) => isSameNote(entry.note, note),
    );
    if (existing >= 0) {
      _entries[existing] = _UnconfirmedNote(
        dayKey: dayKey,
        note: note,
        createdAt: _entries[existing].createdAt,
      );
      return true;
    }

    if (_entries.length >= maxEntries) {
      _calendarDebugPrint(
        '[unconfirmed] refused register: ledger full ($maxEntries)',
      );
      return false;
    }

    _entries.add(
      _UnconfirmedNote(dayKey: dayKey, note: note, createdAt: DateTime.now()),
    );
    return true;
  }

  /// Drops entries the user has since deleted, or whose write was rolled back.
  /// Must be called from every local-removal path — including the direct
  /// `_notes` mutators that bypass `_addNote` — or deleted notes resurrect on
  /// the next commit.
  int forget(bool Function(_Note note) matches) {
    final before = _entries.length;
    _entries.removeWhere((entry) => matches(entry.note));
    return before - _entries.length;
  }

  void clear() => _entries.clear();

  /// Single pass over the ledger during commit:
  ///   * incoming rows contain a match → hydration confirmed it; retire
  ///   * incoming rows do not          → re-add, so the row survives the commit
  ///
  /// A miss can also mean "outside the hydration window," where re-adding is
  /// still correct. [ttl] bounds the case where it means "the write never
  /// landed."
  ///
  /// Runs *before* `_dedupeVisibleDayNotes`, so genuine conflicts with incoming
  /// rows resolve under the existing dedupe rules rather than here. Flow-backed
  /// unconfirmed rows (maat joins) are matched by cid/id through [isSameNote];
  /// they must not be routed through `_mergePaintedStandaloneLaneInto`, which
  /// is scoped to the standalone lane.
  ({int preserved, int confirmed}) mergeInto(
    Map<String, List<_Note>> notesByDay, {
    required bool Function(_Note incoming, _Note pending) isSameNote,
  }) {
    _pruneExpired();
    if (_entries.isEmpty) return (preserved: 0, confirmed: 0);

    var preserved = 0;
    final confirmed = <_UnconfirmedNote>[];

    for (final entry in _entries) {
      final bucket = notesByDay.putIfAbsent(entry.dayKey, () => <_Note>[]);
      if (bucket.any((incoming) => isSameNote(incoming, entry.note))) {
        confirmed.add(entry);
        continue;
      }
      bucket.add(entry.note);
      preserved++;
    }

    for (final entry in confirmed) {
      _entries.remove(entry);
    }
    return (preserved: preserved, confirmed: confirmed.length);
  }

  void _pruneExpired() {
    final cutoff = DateTime.now().subtract(ttl);
    _entries.removeWhere((entry) => entry.createdAt.isBefore(cutoff));
  }
}
