import 'package:supabase_flutter/supabase_flutter.dart';
import '../account_view_cache.dart';
import '../pages_read_repository.dart';
import '../share_repo.dart';
import '../shared_calendars_repo.dart';
import '../../features/pages/pages_models.dart';

/// Reconstructs the same projections as Pages without mounting a hidden page.
/// Each job is a passive read; the app scheduler controls when it may run.
class PagesWarmResources {
  PagesWarmResources(this.client, this.cache, this.mayRead);
  final SupabaseClient client;
  final AccountViewCache cache;
  final bool Function() mayRead;

  Map<String, Future<Object?> Function()> reads({required bool cachedOnly}) {
    final repo = PagesReadRepository(
      client,
      mayFetch: mayRead,
      cachedOnly: cachedOnly,
    );
    final calendars = SharedCalendarsRepo(client);
    final share = ShareRepo(client);
    return {
      'planner.overview': () => repo.planner(DateTime.now()),
      'journal.overview': () => repo.journal(DateTime.now()),
      'pages.flows': repo.flows,
      'social.together': repo.together,
      'social.commons': repo.commons,
      'social.activity': () => cachedOnly
          ? share.restoreCachedRecentActivity(limit: 20)
          : share.getRecentActivity(
              limit: 20,
              strict: true,
              includeCommentBody: false,
            ),
      'social.inbox': () => cachedOnly
          ? share.restoreCachedInboxItems()
          : share.readInboxMetadata(),
      'calendars.list': () => cachedOnly
          ? calendars.restoreCachedAcceptedCalendars()
          : calendars.readAcceptedCalendarsOnly(),
      'pages.hiddenCalendars': calendars.getHiddenCalendarIds,
      'pages.calendar': () async {
        final uid = client.auth.currentUser!.id;
        final flows =
            cache.peek<List<PagesFlow>>(uid, 'pages.flows') ??
            await repo.flows();
        final hidden =
            cache.peek<Set<String>>(uid, 'pages.hiddenCalendars') ??
            await calendars.getHiddenCalendarIds();
        return repo.calendar(DateTime.now(), flows, hidden);
      },
      'pages.events': () async {
        final uid = client.auth.currentUser!.id;
        final hidden =
            cache.peek<Set<String>>(uid, 'pages.hiddenCalendars') ??
            await calendars.getHiddenCalendarIds();
        return repo.events(DateTime.now(), hidden: hidden);
      },
    };
  }

  Future<void> restore() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    for (final entry in reads(cachedOnly: true).entries) {
      if (!mayRead() || client.auth.currentUser?.id != uid) return;
      if (cache.peek<Object>(uid, entry.key) != null) continue;
      try {
        final value = await entry.value();
        if (value != null &&
            mayRead() &&
            client.auth.currentUser?.id == uid &&
            cache.peek<Object>(uid, entry.key) == null &&
            !cache.loading(entry.key)) {
          cache.publish(uid, entry.key, value);
          cache.invalidate(uid, entry.key);
        }
      } catch (_) {
        /* A missing/old snapshot is a cold read, not empty data. */
      }
    }
  }
}
