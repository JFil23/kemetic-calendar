import '../../features/pages/pages_arrangement.dart';
import '../../features/pages/pages_models.dart';
import '../../features/calendar/the_reading_house/reading_house_room_repository.dart';
import '../flow_post_model.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../account_view_cache.dart';
import '../event_filing_engine.dart';
import '../event_filing_repo.dart';
import '../flows_repo.dart';
import '../profile_repo.dart';
import '../journal_repo.dart';
import '../commons_repo.dart';
import '../commons_question_selection.dart';
import '../decan_reflection_repo.dart';
import '../maat_guidance_repo.dart';
import '../user_events_repo.dart';
import '../flow_appearance_store.dart';
import '../../repositories/dm_conversation_repo.dart';
import '../../features/calendar/calendar_invalidation.dart';
import '../../features/rhythm/data/rhythm_repo.dart';
import 'pages_warm_resources.dart';
import 'warm_snapshot_store.dart';
import 'warm_work_queue.dart';

/// One app lifetime owner. No hidden widgets, writes, read receipts, or analytics.
class AppWarmState with WidgetsBindingObserver {
  AppWarmState(this.client);
  final SupabaseClient client;
  final _queue = WarmWorkQueue();
  final _cache = AccountViewCache.instance;
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<CalendarInvalidated>? _calendar;
  Timer? _timer;
  String? _uid;
  bool _foreground = true, _disposed = false;
  DateTime? _lastSweep;
  String _day = '';
  final _scheduledFlows = <int>{};
  int? _priorityFlow;
  bool get _current =>
      !_disposed &&
      _foreground &&
      _uid != null &&
      client.auth.currentUser?.id == _uid;
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _auth = client.auth.onAuthStateChange.listen((_) => _accountChanged());
    _calendar = CalendarInvalidationBus.instance.stream.listen((event) {
      final uid = _uid;
      if (uid == null) return;
      for (final prefix in ['pages.', 'filing.', 'flow.']) {
        WarmSnapshotStore.instance.invalidate(uid, prefix: prefix);
      }
      _cache.invalidatePrefix(uid, 'pages.');
      _sweep(force: true);
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _sweep());
    _cache.changes.addListener(_pagesChanged);
    _accountChanged();
  }

  void _accountChanged() {
    final uid = client.auth.currentUser?.id;
    if (uid == _uid) return;
    final previous = _uid;
    _queue.pause();
    _uid = uid;
    _lastSweep = null;
    _scheduledFlows.clear();
    _priorityFlow = null;
    if (previous != null) {
      FlowAppearanceStore.forgetAccount(previous);
      unawaited(WarmSnapshotStore.instance.forgetAccount(previous));
    }
    _cache.enterAccount(uid ?? 'signed-out');
    if (uid == null) return;
    unawaited(WarmSnapshotStore.instance.restore(uid));
    if (_foreground) {
      _queue.resume();
      _sweep(force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _queue.pause();
      return;
    }
    _queue.resume();
    _sweep(force: true);
  }

  void _pagesChanged() {
    if (_cache.changes.value == 'pages.flows' ||
        _cache.changes.value == 'pages.events') {
      _prioritizePagesFlow();
    }
  }

  void _prioritizePagesFlow() {
    if (!_current) return;
    final uid = _uid!;
    final selected = selectPagesStudio(
      _cache.peek<List<PagesFlow>>(uid, 'pages.flows') ?? const [],
      _cache.peek<PagesEventWindow>(uid, 'pages.events')?.events ?? const [],
      DateTime.now(),
    );
    final id = int.tryParse(selected.flow?.id ?? '');
    if (id == null || id == _priorityFlow) return;
    _priorityFlow = id;
    _enqueueFlow(id, priority: true);
  }

  void _enqueueFlow(int id, {bool priority = false}) {
    if (!_current) return;
    final uid = _uid!;
    final key = '$uid:flow:$id';
    if (!_scheduledFlows.add(id)) {
      if (priority) _queue.prioritize(key);
      return;
    }
    bool current() =>
        _current &&
        _uid == uid &&
        ((Zone.current[warmReadGuard] as bool Function()?)?.call() ?? true);
    _queue.enqueue(key, () async {
      while (current()) {
        try {
          final row = await FlowsRepo(client).getFlowById(id);
          if (!current() || row == null) return;
          await UserEventsRepo(client).getFlowDetailEvents(id);
          final path = row.appearance.imageObjectPath;
          if (path != null && current()) {
            await FlowAppearanceStore(client).imageBytes(path);
          }
          return;
        } on WarmReadCancelled {
          // An acknowledged edit can invalidate an otherwise current read.
          // Continue with its fresh version; departed queue generations stop.
          if (!current()) rethrow;
        }
      }
    }, priority: priority);
  }

  void _sweep({bool force = false}) {
    if (!_current) return;
    final now = DateTime.now();
    final day =
        '${now.year}-${now.month}-${now.day}:${now.timeZoneOffset.inMinutes}';
    final boundary = day != _day;
    if (!force &&
        !boundary &&
        _lastSweep != null &&
        now.difference(_lastSweep!) < const Duration(minutes: 5)) {
      return;
    }
    if (boundary && _day.isNotEmpty) {
      for (final prefix in [
        'pages.planner.',
        'pages.journal.',
        'pages.calendar.',
        'pages.events.',
        'pages.commons.',
        'rhythm.',
        'commons.',
      ]) {
        WarmSnapshotStore.instance.invalidate(_uid!, prefix: prefix);
      }
      for (final prefix in [
        'planner.overview',
        'journal.overview',
        'pages.calendar',
        'pages.events',
        'social.commons',
      ]) {
        _cache.evictPrefix(_uid!, prefix);
      }
    }
    _day = day;
    _lastSweep = now;
    _scheduledFlows.clear();
    _priorityFlow = null;
    _prioritizePagesFlow();
    final uid = _uid!;
    bool current() => _current && _uid == uid;
    _cache.beginRefreshCycle();
    final resources = PagesWarmResources(client, _cache, current);
    _queue.enqueue('$uid:restore', resources.restore);
    for (final entry in resources.reads(cachedOnly: false).entries) {
      _queue.enqueue('$uid:${entry.key}', () async {
        await _cache.load<Object>(
          uid,
          entry.key,
          () async {
            final data = await entry.value();
            if (data == null) throw WarmCacheMiss(entry.key);
            return data;
          },
          mayFetch: current,
          stale: true,
        );
      });
    }
    final rhythm = RhythmRepo(client);
    final profile = ProfileRepo(client);
    final rooms = SupabaseReadingHouseRoomRepository(client);
    final jobs = <String, Future<Object?> Function()>{
      'readingHouse': () async {
        final summaries = await rooms.listSummaries();
        for (final room in summaries.where((s) => !s.ended).take(6)) {
          _queue.enqueue(
            '$uid:readingHouse:${room.identity.calendarId}:${room.identity.flowId}',
            () async {
              if (current()) await rooms.listMessages(identity: room.identity);
            },
          );
        }
        return null;
      },
      'profile.posts': () async {
        final posts = await profile.getFlowPosts(uid);
        for (final post in posts) {
          _queue.enqueue('$uid:post:${post.id}', () async {
            if (current()) await profile.getFlowPostById(post.id, strict: true);
          });
        }
        return null;
      },
      'planner.alignment': rhythm.fetchTodaysAlignment,
      'planner.todos': rhythm.fetchTodos,
      'planner.tracker': rhythm.fetchContinuity,
      'planner.notes': rhythm.fetchAlignmentNotes,
      'journal.archive': () =>
          JournalRepo(client).listRecent(days: 90, strict: true),
      'feed': () async {
        final feed = await profile.getProfileFeedResult();
        if (feed.hasError || !current()) return null;
        final posts = feed.data
            .map((item) => item.flowPost)
            .whereType<FlowPost>();
        for (final post in posts) {
          _queue.enqueue('$uid:post:${post.id}', () async {
            if (current()) await profile.getFlowPostById(post.id, strict: true);
          });
        }
        return null;
      },
      'commons': () {
        final seed = commonsQuestionSeed(now);
        return CommonsRepo(client).getCommonsHome(
          localDate: now,
          questionId: seed.id,
          questionText: seed.text,
          strict: true,
        );
      },
      'reflections': () => DecanReflectionRepo(client).listMineResult(),
      'guidance.archive': () =>
          MaatGuidanceRepo(client).listDecanOpeningsForArchive(),
      'dm': () => DmConversationRepo(client).getConversationSummaries(),
      'notes': () => EventFilingRepo(client).getOwnedItemsPage(
        kind: FiledItemKind.note,
        offset: 0,
        startsOnOrAfterUtc: DateTime(now.year, now.month, now.day).toUtc(),
      ),
      'reminders': () => EventFilingRepo(
        client,
      ).getOwnedItemsPage(kind: FiledItemKind.reminder, offset: 0),
      'flow.details': () async {
        final rows = await FlowsRepo(client).listMyFiledFlows();
        for (final flow in rows.where(
          (f) => f.visibleInActiveList && !f.isHidden && !f.isReminder,
        )) {
          if (current()) _enqueueFlow(flow.id);
        }
        return null;
      },
    };
    for (final entry in jobs.entries) {
      _queue.enqueue('$uid:${entry.key}', () async {
        if (current()) await entry.value();
      });
    }
    _queue.enqueue('$uid:recent-details', () async {
      for (final key in WarmSnapshotStore.instance.recentKeys(uid, limit: 6)) {
        if (!current()) return;
        try {
          if (key.startsWith('flow.detail.')) {
            final id = int.parse(key.substring('flow.detail.'.length));
            _enqueueFlow(id);
          } else if (key.startsWith('social.post.')) {
            await profile.getFlowPostById(
              key.substring('social.post.'.length),
              strict: true,
            );
          } else if (key.startsWith('journal.entry.')) {
            await JournalRepo(
              client,
            ).getById(key.substring('journal.entry.'.length), strict: true);
          } else if (key.startsWith('reflection.')) {
            await DecanReflectionRepo(
              client,
            ).getById(key.substring('reflection.'.length), strict: true);
          } else if (key.startsWith('dm.messages.')) {
            await DmConversationRepo(
              client,
            ).getMessages(key.substring('dm.messages.'.length));
          } else if (key.startsWith('guidance.')) {
            await MaatGuidanceRepo(
              client,
            ).getById(key.substring('guidance.'.length));
          }
        } catch (_) {
          /* other recent destinations can still warm */
        }
      }
    });
  }

  void dispose() {
    _disposed = true;
    _queue.pause();
    _cache.changes.removeListener(_pagesChanged);
    _timer?.cancel();
    unawaited(_auth?.cancel());
    unawaited(_calendar?.cancel());
    WidgetsBinding.instance.removeObserver(this);
  }
}
