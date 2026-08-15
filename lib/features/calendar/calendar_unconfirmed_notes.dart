part of 'calendar_page.dart';

/// Whether a locally-inserted `_Note` has been confirmed by a hydration pass.
///
/// [confirmed] — derived from state hydration already agrees with (reminder
/// regeneration, shared-calendar seeding, warm-start paint, debug fixtures).
/// If a later pass drops the row, that is authoritative: the row should go.
///
/// [unconfirmed] — no hydration pass has returned this row yet. It may already
/// be persisted or its write may still be in flight (`_saveSingleNoteOnly`
/// inserts the optimistic projection before awaiting the upsert, as do Flow
/// Studio planned notes). Either way a pass that began before the write landed
/// will not contain it, so dropping it on commit is a bug rather than
/// authority. These are ledgered.
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
  /// Age at which a caller should verify the CID with a forced-live lookup.
  /// Expiry never removes an entry on its own: inability to verify must not
  /// erase an event whose write already succeeded.
  static const Duration ttl = Duration(minutes: 2);

  /// Registration is refused past this point rather than evicting the oldest
  /// entry: evicting would silently drop a still-live row, which is the exact
  /// failure this ledger exists to prevent.
  static const int maxEntries = 200;

  final List<_UnconfirmedNote> _entries = <_UnconfirmedNote>[];

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  bool containsCid(String clientEventId) {
    final cid = clientEventId.trim();
    if (cid.isEmpty) return false;
    return _entries.any((entry) => entry.note.clientEventId?.trim() == cid);
  }

  _UnconfirmedNote? entryForCid(String clientEventId) {
    final cid = clientEventId.trim();
    if (cid.isEmpty) return null;
    for (final entry in _entries) {
      if (entry.note.clientEventId?.trim() == cid) return entry;
    }
    return null;
  }

  @visibleForTesting
  List<_Note> get unconfirmedNotes =>
      _entries.map((e) => e.note).toList(growable: false);

  @visibleForTesting
  List<_UnconfirmedNote> get entries =>
      List<_UnconfirmedNote>.unmodifiable(_entries);

  /// Callers must supply a note carrying a `clientEventId`; without one,
  /// confirmation cannot be exact. Registration is refused rather than
  /// degrading to id, reminder identity, or title/time matching.
  bool register({
    required String dayKey,
    required _Note note,
    DateTime? createdAt,
  }) {
    final cid = note.clientEventId?.trim();
    if (cid == null || cid.isEmpty) {
      _calendarDebugPrint(
        '[unconfirmed] refused register without cid '
        'title=<redacted chars=${note.title.length}>',
      );
      return false;
    }

    final existing = _entries.indexWhere(
      (entry) => entry.note.clientEventId?.trim() == cid,
    );
    if (existing >= 0) {
      _entries[existing] = _UnconfirmedNote(
        dayKey: dayKey,
        note: note,
        createdAt: createdAt?.toUtc() ?? _entries[existing].createdAt,
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
      _UnconfirmedNote(
        dayKey: dayKey,
        note: note,
        createdAt: (createdAt ?? DateTime.now()).toUtc(),
      ),
    );
    return true;
  }

  /// Drops entries the user has since deleted, or whose write was rolled back.
  /// Must be called from every local-removal path — including the direct
  /// `_notes` mutators that bypass `_addNote` — or deleted notes resurrect on
  /// the next commit.
  int forgetCid(String? clientEventId) {
    final cid = clientEventId?.trim();
    if (cid == null || cid.isEmpty) return 0;
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.note.clientEventId?.trim() == cid);
    return before - _entries.length;
  }

  int forgetCids(Iterable<String> clientEventIds) {
    final cids = clientEventIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (cids.isEmpty) return 0;
    final before = _entries.length;
    _entries.removeWhere(
      (entry) => cids.contains(entry.note.clientEventId?.trim()),
    );
    return before - _entries.length;
  }

  List<_UnconfirmedNote> takeCids(Iterable<String> clientEventIds) {
    final cids = clientEventIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (cids.isEmpty) return const <_UnconfirmedNote>[];
    final removed = _entries
        .where((entry) => cids.contains(entry.note.clientEventId?.trim()))
        .toList(growable: false);
    if (removed.isNotEmpty) {
      _entries.removeWhere(
        (entry) => cids.contains(entry.note.clientEventId?.trim()),
      );
    }
    return removed;
  }

  void restore(Iterable<_UnconfirmedNote> entries) {
    for (final entry in entries) {
      final cid = entry.note.clientEventId?.trim();
      final alreadyPresent = _entries.any((candidate) {
        if (identical(candidate.note, entry.note)) return true;
        return cid != null &&
            cid.isNotEmpty &&
            candidate.note.clientEventId?.trim() == cid;
      });
      if (alreadyPresent || _entries.length >= maxEntries) continue;
      _entries.add(entry);
    }
  }

  void clear() => _entries.clear();

  /// Pure reducer inputs for the next calendar publication. Confirmation and
  /// retirement are decided by the shared visible-state reducer and applied
  /// only after the owning hydration transaction commits.
  List<CalendarPendingVisibleItem<_Note>> get visibleProjectionItems =>
      List<CalendarPendingVisibleItem<_Note>>.unmodifiable(
        _entries.map(
          (entry) => CalendarPendingVisibleItem<_Note>(
            dayKey: entry.dayKey,
            item: entry.note,
          ),
        ),
      );

  List<_UnconfirmedNote> dueForVerification({DateTime? now}) {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final cutoff = effectiveNow.subtract(ttl);
    return _entries
        .where((entry) => entry.createdAt.toUtc().isBefore(cutoff))
        .toList(growable: false);
  }
}
