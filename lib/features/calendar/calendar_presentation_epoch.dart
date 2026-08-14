import 'package:flutter/foundation.dart';

enum CalendarPresentationTransactionKind { gesture, today }

@immutable
final class CalendarPresentationTransaction {
  const CalendarPresentationTransaction._({
    required this.serial,
    required this.kind,
    required this.userScope,
  });

  final int serial;
  final CalendarPresentationTransactionKind kind;
  final String userScope;
}

/// One immutable projection paired with the geometry revision that describes
/// its extent-affecting content.
@immutable
final class CalendarPresentationEpoch<T> {
  CalendarPresentationEpoch({
    required String userScope,
    required this.sequence,
    required String viewRevision,
    required String geometryRevision,
    required this.extentAffecting,
    required Iterable<String> affectedSections,
    required this.projection,
  }) : userScope = userScope.trim(),
       viewRevision = viewRevision.trim(),
       geometryRevision = geometryRevision.trim(),
       affectedSections = Set<String>.unmodifiable(affectedSections) {
    if (this.userScope.isEmpty ||
        this.viewRevision.isEmpty ||
        this.geometryRevision.isEmpty) {
      throw ArgumentError(
        'Presentation epoch identities and user scope must not be empty.',
      );
    }
    if (sequence < 0) {
      throw ArgumentError.value(sequence, 'sequence', 'must not be negative');
    }
    if (extentAffecting && this.affectedSections.isEmpty) {
      throw ArgumentError(
        'Extent-affecting epochs must name their affected sections.',
      );
    }
  }

  final String userScope;
  final int sequence;
  final String viewRevision;
  final String geometryRevision;
  final bool extentAffecting;
  final Set<String> affectedSections;
  final T projection;
}

typedef CalendarPresentationActivator<T> =
    void Function(CalendarPresentationEpoch<T> epoch);

/// Owns the authoritative server-data → visible-projection handoff.
///
/// Extent-affecting epochs are staged while a gesture or Today transaction is
/// active. At settle, only the newest consistent projection/geometry pair is
/// activated. The coordinator never replays intermediate staged epochs.
final class CalendarPresentationEpochCoordinator<T> {
  CalendarPresentationEpochCoordinator({
    required CalendarPresentationActivator<T> activate,
    required void Function(String previousUserScope) clearUserScope,
  }) : _activate = activate,
       _clearUserScope = clearUserScope;

  final CalendarPresentationActivator<T> _activate;
  final void Function(String previousUserScope) _clearUserScope;
  final Map<int, CalendarPresentationTransaction> _transactions = {};
  int _nextTransactionSerial = 0;
  String? _userScope;
  CalendarPresentationEpoch<T>? _pending;
  CalendarPresentationEpoch<T>? _active;

  CalendarPresentationEpoch<T>? get active => _active;
  CalendarPresentationEpoch<T>? get pending => _pending;
  bool get transactionActive => _transactions.isNotEmpty;

  CalendarPresentationTransaction begin({
    required CalendarPresentationTransactionKind kind,
    required String userScope,
  }) {
    _adoptScope(userScope);
    final transaction = CalendarPresentationTransaction._(
      serial: ++_nextTransactionSerial,
      kind: kind,
      userScope: userScope.trim(),
    );
    _transactions[transaction.serial] = transaction;
    return transaction;
  }

  /// Returns true when the epoch became visible immediately.
  bool publish(CalendarPresentationEpoch<T> epoch) {
    _adoptScope(epoch.userScope);
    final activeSequence = _active?.sequence;
    final pendingSequence = _pending?.sequence;
    final newestSequence = pendingSequence == null
        ? activeSequence
        : activeSequence == null
        ? pendingSequence
        : pendingSequence > activeSequence
        ? pendingSequence
        : activeSequence;
    if (newestSequence != null && epoch.sequence < newestSequence) {
      return false;
    }
    // Once an extent-affecting epoch is staged, later projection updates are
    // based on that pending view and must coalesce with it. Publishing one
    // around the stage would split projection and geometry again.
    if (transactionActive && (epoch.extentAffecting || _pending != null)) {
      _pending = epoch;
      return false;
    }
    _activateNow(epoch);
    return true;
  }

  void settle(CalendarPresentationTransaction transaction) {
    final registered = _transactions.remove(transaction.serial);
    if (registered == null || registered.userScope != transaction.userScope) {
      return;
    }
    if (_transactions.isNotEmpty) return;
    final pending = _pending;
    _pending = null;
    if (pending != null && pending.userScope == _userScope) {
      _activateNow(pending);
    }
  }

  void cancel(CalendarPresentationTransaction transaction) {
    _transactions.remove(transaction.serial);
    if (_transactions.isEmpty) _pending = null;
  }

  /// Account changes are security boundaries, not scroll transactions.
  /// Staged content from the previous user can never publish afterward.
  void changeUserScope(String? nextUserScope) {
    final normalized = nextUserScope?.trim();
    final previous = _userScope;
    if (previous == normalized) return;
    _transactions.clear();
    _pending = null;
    _active = null;
    _userScope = normalized == null || normalized.isEmpty ? null : normalized;
    if (previous != null && previous.isNotEmpty) _clearUserScope(previous);
  }

  void _adoptScope(String userScope) {
    final normalized = userScope.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userScope, 'userScope', 'must not be empty');
    }
    if (_userScope == null) {
      _userScope = normalized;
      return;
    }
    if (_userScope != normalized) changeUserScope(normalized);
  }

  void _activateNow(CalendarPresentationEpoch<T> epoch) {
    _pending = null;
    _active = epoch;
    _activate(epoch);
  }
}
