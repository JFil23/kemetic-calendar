import 'dart:async';
import '../../data/warm_state/warm_snapshot_store.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/account_view_cache.dart';
import '../../data/event_filing_engine.dart';
import '../../data/event_filing_repo.dart';
import '../../data/flows_repo.dart';
import '../../utils/flow_filter_engine.dart';
import '../calendar/calendar_invalidation.dart';
import 'pages_collections.dart';

/// Visible, on-demand projections only. Classification and persistence remain
/// in the existing filing view and flow repository.
class PagesCollectionsController extends ValueNotifier<PagesCollectionState> {
  PagesCollectionsController(
    this.client, {
    AccountViewCache? cache,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       cache = cache ?? AccountViewCache.instance,
       uid = client.auth.currentUser!.id,
       super(const PagesCollectionState()) {
    this.cache.enterAccount(uid);
    _changes = CalendarInvalidationBus.instance.stream.listen((_) {
      this.cache.invalidatePrefix(uid, 'pages.collection.');
      _pages.clear();
      if (_active && value.collection != null) unawaited(_load());
    });
  }
  final SupabaseClient client;
  final AccountViewCache cache;
  final String uid;
  final DateTime Function() now;
  DateTime? _notesDay;
  DateTime get _today {
    final local = now().toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  void refreshDate() {
    if (_active &&
        value.collection == PagesCollection.notes &&
        _notesDay != _today) {
      unawaited(_load());
    }
  }

  final _pages = <PagesCollection, List<PagesCollectionItem>>{};
  StreamSubscription? _changes;
  bool _visible = false, _disposed = false;
  int _request = 0;
  bool get _active =>
      _visible && !_disposed && client.auth.currentUser?.id == uid;

  void setVisible(bool visible) {
    final entering = visible && !_visible;
    _visible = visible;
    if (entering && value.collection != null) unawaited(_load());
  }

  void select(PagesCollection? collection) {
    _request++;
    final retained = collection == PagesCollection.notes && _notesDay != _today
        ? null
        : _pages[collection];
    value = PagesCollectionState(
      collection: collection,
      items: retained ?? const [],
    );
    if (collection != null && _active) unawaited(_load());
  }

  Future<void> retry() async {
    cache.beginVisibleEntry();
    await _load();
  }

  Future<void> loadMore() => _load(more: true);

  Future<List<PagesCollectionItem>> _fetch(
    PagesCollection kind,
    int offset,
    DateTime? notesDay, {
    bool cachedOnly = false,
  }) async {
    if (kind == PagesCollection.flows) {
      final repo = FlowsRepo(client);
      final rows = cachedOnly
          ? await repo.restoreCachedFiledFlows()
          : await repo.listMyFiledFlows();
      if (rows == null) throw const WarmCacheMiss('pages.flows');
      return rows
          .where(
            (f) =>
                f.visibleInActiveList &&
                !f.isHidden &&
                !f.isReminder &&
                !hasRepeatingNoteFlowMetadata(f.notes),
          )
          .map(
            (f) => PagesCollectionItem(
              id: 'flow:${f.id}',
              title: f.name,
              color: 0xff000000 | f.color,
              flowId: f.id,
            ),
          )
          .toList();
    }
    final rows = await EventFilingRepo(client).getOwnedItemsPage(
      kind: kind == PagesCollection.notes
          ? FiledItemKind.note
          : FiledItemKind.reminder,
      offset: offset,
      cachedOnly: cachedOnly,
      startsOnOrAfterUtc: notesDay?.toUtc(),
    );
    return rows
        .map(
          (f) => PagesCollectionItem(
            id: f.event.id,
            title: f.event.title,
            event: f,
            color: 0xff000000 | (f.calendar.color ?? 0xd4af37),
            detail: f.event.allDay
                ? DateFormat.yMMMd().format(f.event.startsAt.toLocal())
                : DateFormat.yMMMd().add_jm().format(
                    f.event.startsAt.toLocal(),
                  ),
          ),
        )
        .toList();
  }

  Future<void> _load({bool more = false, bool retryDiscarded = true}) async {
    final kind = value.collection;
    if (!_active ||
        kind == null ||
        (more && (value.loading || !value.hasMore))) {
      return;
    }
    final notesDay = kind == PagesCollection.notes ? _today : null;
    if (notesDay != null && notesDay != _notesDay) {
      _notesDay = notesDay;
      _pages.remove(PagesCollection.notes);
      value = PagesCollectionState(collection: kind, loading: true);
      more = false;
    }
    final token = ++_request;
    final prior = more
        ? (_pages[kind] ?? const <PagesCollectionItem>[])
        : const <PagesCollectionItem>[];
    final offset = prior.length;
    final dateScope = notesDay == null ? '' : '.${notesDay.toIso8601String()}';
    final key = 'pages.collection.${kind.name}$dateScope.$offset';
    final at = cache.loadedAt(uid, key);
    final stale =
        at != null &&
        DateTime.now().difference(at) > const Duration(minutes: 5);
    var cached = cache.peek<List<PagesCollectionItem>>(uid, key);
    if (cached == null) {
      try {
        cached = await _fetch(kind, offset, notesDay, cachedOnly: true);
        if (_disposed || token != _request || !_active) return;
        cache.publish(uid, key, cached);
        cache.invalidate(uid, key);
      } catch (_) {
        /* no complete local page yet */
      }
    }
    // Reuse the existing account-scoped flow snapshot on first entry.
    if (kind == PagesCollection.flows && cached == null && at == null) {
      final rows = FlowsRepo(client).cachedMyFiledFlowsSync();
      if (rows != null) {
        cache.publish(
          uid,
          key,
          rows
              .where(
                (f) =>
                    f.visibleInActiveList &&
                    !f.isHidden &&
                    !f.isReminder &&
                    !hasRepeatingNoteFlowMetadata(f.notes),
              )
              .map(
                (f) => PagesCollectionItem(
                  id: 'flow:${f.id}',
                  title: f.name,
                  flowId: f.id,
                  color: 0xff000000 | f.color,
                ),
              )
              .toList(),
        );
      }
    }
    value = PagesCollectionState(
      collection: kind,
      items: more ? prior : (cached ?? _pages[kind] ?? const []),
      loading: more || (cached == null && !_pages.containsKey(kind)),
    );
    final result = await cache.load<List<PagesCollectionItem>>(
      uid,
      key,
      () => _fetch(kind, offset, notesDay),
      stale: stale,
      mayFetch: () => _active && value.collection == kind,
    );
    if (_disposed ||
        token != _request ||
        !_active ||
        value.collection != kind) {
      return;
    }
    if (retryDiscarded &&
        result == null &&
        !cache.failed(key) &&
        cache.loadedAt(uid, key) == null) {
      // An invalidation during the read discarded its response. Re-read once
      // through the cache after that pending request has settled.
      cache.beginVisibleEntry();
      await _load(retryDiscarded: false);
      return;
    }
    final page = result ?? cached ?? const <PagesCollectionItem>[];
    final items = [...prior, ...page];
    _pages[kind] = items;
    value = PagesCollectionState(
      collection: kind,
      items: items,
      failed: cache.failed(key),
      hasMore: kind != PagesCollection.flows && page.length == 50,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
