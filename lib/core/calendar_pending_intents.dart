import 'package:flutter/foundation.dart';

/// All stable names currently known for one materialized calendar record.
///
/// Database ids and client event ids are aliases for the same record. A
/// title/time fallback is used only when neither stable alias exists.
@immutable
class CalendarMutationIdentity {
  CalendarMutationIdentity._(Set<String> aliases)
    : aliases = Set<String>.unmodifiable(aliases);

  factory CalendarMutationIdentity.userEvent({
    String? databaseId,
    String? clientEventId,
    String? fallbackKey,
  }) {
    final aliases = <String>{};
    final id = databaseId?.trim();
    if (id != null && id.isNotEmpty) aliases.add('id:$id');
    final cid = clientEventId?.trim();
    if (cid != null && cid.isNotEmpty) aliases.add('cid:$cid');
    if (aliases.isEmpty) {
      final fallback = fallbackKey?.trim();
      if (fallback != null && fallback.isNotEmpty) {
        aliases.add('fallback:$fallback');
      }
    }
    return CalendarMutationIdentity._(aliases);
  }

  final Set<String> aliases;

  bool get isEmpty => aliases.isEmpty;

  bool matches(CalendarMutationIdentity other) =>
      aliases.any(other.aliases.contains);

  CalendarMutationIdentity merge(CalendarMutationIdentity other) =>
      CalendarMutationIdentity._(<String>{...aliases, ...other.aliases});
}

class _PendingDeleteIntent {
  _PendingDeleteIntent({
    required this.token,
    required this.identity,
    required this.localDate,
  });

  final int token;
  CalendarMutationIdentity identity;
  final DateTime localDate;
  int? acknowledgedAfterHydrationEpoch;
  final Set<int> observedHydrationEpochs = <int>{};
}

/// Keeps an accepted local delete painted until a later authoritative pass
/// covering that day no longer returns the deleted record.
class CalendarPendingDeleteLedger {
  final List<_PendingDeleteIntent> _entries = <_PendingDeleteIntent>[];
  int _nextToken = 0;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  int register({
    required CalendarMutationIdentity identity,
    required DateTime localDate,
  }) {
    if (identity.isEmpty) {
      throw ArgumentError('A pending delete requires a usable identity');
    }
    for (final entry in _entries) {
      if (!entry.identity.matches(identity)) continue;
      entry.identity = entry.identity.merge(identity);
      return entry.token;
    }
    final token = ++_nextToken;
    _entries.add(
      _PendingDeleteIntent(
        token: token,
        identity: identity,
        localDate: DateTime(localDate.year, localDate.month, localDate.day),
      ),
    );
    return token;
  }

  bool suppress(
    CalendarMutationIdentity identity, {
    int? observedInHydrationEpoch,
  }) {
    var matched = false;
    for (final entry in _entries) {
      if (!entry.identity.matches(identity)) continue;
      matched = true;
      if (observedInHydrationEpoch != null) {
        entry.observedHydrationEpochs.add(observedInHydrationEpoch);
      }
    }
    return matched;
  }

  bool acknowledge(
    int token, {
    required int currentHydrationEpoch,
    CalendarMutationIdentity? additionalIdentity,
  }) {
    final entry = _entryForToken(token);
    if (entry == null) return false;
    if (additionalIdentity != null && !additionalIdentity.isEmpty) {
      entry.identity = entry.identity.merge(additionalIdentity);
    }
    entry.acknowledgedAfterHydrationEpoch = currentHydrationEpoch;
    return true;
  }

  bool reject(int token) {
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.token == token);
    return _entries.length != before;
  }

  /// Retires only deletes acknowledged before this pass, whose complete local
  /// day was covered, and whose record was not observed in the raw response.
  int reconcileAcceptedHydration({
    required int hydrationEpoch,
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
  }) {
    final retired = <int>{};
    for (final entry in _entries) {
      final acknowledgedEpoch = entry.acknowledgedAfterHydrationEpoch;
      final dayStartUtc = entry.localDate.toLocal().toUtc();
      final dayEndUtc = DateTime(
        entry.localDate.year,
        entry.localDate.month,
        entry.localDate.day + 1,
      ).toUtc();
      final coversDay =
          !dayStartUtc.isBefore(windowStartUtc.toUtc()) &&
          !dayEndUtc.isAfter(windowEndUtc.toUtc());
      final observed = entry.observedHydrationEpochs.contains(hydrationEpoch);
      if (acknowledgedEpoch != null &&
          hydrationEpoch > acknowledgedEpoch &&
          coversDay &&
          !observed) {
        retired.add(entry.token);
      }
      entry.observedHydrationEpochs.removeWhere(
        (epoch) => epoch <= hydrationEpoch,
      );
    }
    if (retired.isNotEmpty) {
      _entries.removeWhere((entry) => retired.contains(entry.token));
    }
    return retired.length;
  }

  void clear() => _entries.clear();

  _PendingDeleteIntent? _entryForToken(int token) {
    for (final entry in _entries) {
      if (entry.token == token) return entry;
    }
    return null;
  }
}
