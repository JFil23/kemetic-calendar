import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/account_view_cache.dart';
import '../../data/pages_read_repository.dart';
import '../../data/profile_repo.dart';
import '../../data/flows_repo.dart';
import '../../data/flow_post_model.dart';
import '../../data/flow_appearance.dart';
import '../../data/flow_appearance_store.dart';
import '../../data/share_repo.dart';
import '../../data/share_models.dart';
import '../../data/commons_models.dart';
import '../../data/shared_practice_models.dart';
import '../../data/shared_calendar_models.dart';
import '../../data/shared_calendars_repo.dart';
import '../nodes/library_read_progress_store.dart';
import '../nodes/library_read_state.dart';
import '../nodes/kemetic_node_library.dart';
import '../rhythm/planner/planner_overview.dart';
import '../calendar/calendar_invalidation.dart';
import '../calendar/calendar_page.dart' show notesDecode;
import 'pages_arrangement.dart';
import '../../widgets/kemetic_date_picker.dart' show KemeticMath;
import '../calendar/kemetic_month_metadata.dart';
import 'pages_models.dart';

/// A visible-only projection. The cache survives the route; listeners do not.
class PagesController {
  PagesController(this.client, {AccountViewCache? cache, this.onLocalBoundary})
    : cache = cache ?? AccountViewCache.instance {
    uid = client.auth.currentUser!.id;
    repository = PagesReadRepository(client, mayFetch: () => active);
    share = ShareRepo(client);
    this.cache.enterAccount(uid);
    this.cache.changes.addListener(_changed);
    _calendarChanges = CalendarInvalidationBus.instance.stream.listen((_) {
      this.cache.invalidate(uid, 'pages.calendar');
      this.cache.invalidate(uid, 'pages.events');
      this.cache.invalidate(uid, 'pages.flows');
      if (active) {
        unawaited(_loadCalendar());
        unawaited(_loadEvents());
        unawaited(_load('pages.flows', repository.flows));
      }
    });
    _unreadChanges = share.passiveUnreadChanges.listen((_) {
      _paintInbox();
      for (final key in [
        'social.activity',
        'social.together',
        'social.commons',
        'social.inbox',
      ]) {
        this.cache.invalidate(uid, key);
      }
      if (active) unawaited(_loadSocial());
    });
    _seed();
  }
  final VoidCallback? onLocalBoundary;
  final SupabaseClient client;
  final AccountViewCache cache;
  late final String uid;
  late final PagesReadRepository repository;
  late final ShareRepo share;
  final cards = [
    for (final d in PagesDestination.values) ValueNotifier(PagesCard(d)),
  ];
  StreamSubscription? _calendarChanges, _unreadChanges;
  Timer? _boundary;
  bool _visible = false, _disposed = false;
  bool get active =>
      _visible && !_disposed && client.auth.currentUser?.id == uid;
  T? _peek<T>(String key) => cache.peek<T>(uid, key);
  void _seed() {
    void seed<T extends Object>(String key, T? value) {
      if (value != null && _peek<T>(key) == null) {
        cache.publish(uid, key, value);
      }
    }

    seed('social.posts', ProfileRepo(client).getCachedFlowPostsSync(uid));
    seed('social.activity', share.cachedRecentActivitySync());
    seed('social.inbox', share.cachedInboxItemsSync());
    seed(
      'calendars.list',
      SharedCalendarsRepo(client).cachedAcceptedCalendarsSync(),
    );
    final flows = FlowsRepo(client).cachedMyFiledFlowsSync();
    if (flows != null) {
      seed(
        'pages.flows',
        flows
            .where((f) => f.visibleInActiveList && !f.isReminder && !f.isHidden)
            .map(flowFromRow)
            .toList(),
      );
    }
    _paintAll();
  }

  static PagesFlow flowFromRow(FlowRow f) => PagesFlow(
    id: '${f.id}',
    name: f.name,
    appearance: f.appearance,
    maatKey: notesDecode(f.notes).maatKey,
    notes: f.notes,
    color: 0xff000000 | f.color,
    total: f.totalEventCount,
    completed: (f.totalEventCount - f.remainingEventCount).clamp(
      0,
      f.totalEventCount,
    ),
    start: f.startDate,
    end: f.endDate,
  );
  static PagesFlow flowFromPost(FlowPost f) => PagesFlow(
    id: '${f.sourceFlowId ?? f.id}',
    name: f.name,
    appearance: FlowAppearance.fromJson(f.payloadJson?['appearance']),
    color: 0xff000000 | f.color,
    start: f.startDate,
    end: f.endDate,
  );
  Future<T?> _load<T extends Object>(
    String key,
    Future<T> Function() fetch, {
    bool stale = false,
  }) async {
    final result = await cache.load<T>(
      uid,
      key,
      fetch,
      mayFetch: () => active,
      stale: stale,
    );
    return result;
  }

  /// There is no Inbox TTL to shorten. A real background/foreground cycle
  /// expires only social snapshots that predate that background period.
  /// Newer snapshots from an existing notification remain fresh.
  void resumeAfter(DateTime backgroundedAt) {
    for (final key in [
      'social.activity',
      'social.together',
      'social.commons',
      'social.inbox',
    ]) {
      final loaded = cache.loadedAt(uid, key);
      if (loaded != null && !loaded.isAfter(backgroundedAt)) {
        cache.invalidate(uid, key);
      }
    }
  }

  void setVisible(bool visible, {bool resumed = false}) {
    if (_disposed) return;
    final entering = visible && !_visible;
    _visible = visible;
    if (!visible) {
      _boundary?.cancel();
      return;
    }
    if (entering || resumed) cache.beginVisibleEntry();
    _paintPlanner();
    _paintJournal();
    _paintStudio();
    unawaited(
      _load('planner.overview', () => repository.planner(DateTime.now())),
    );
    unawaited(
      _load('journal.overview', () => repository.journal(DateTime.now())),
    );
    unawaited(_loadCalendars());
    unawaited(_loadLibrary());
    unawaited(
      _load(
        'pages.hiddenCalendars',
        () => SharedCalendarsRepo(client).getHiddenCalendarIds(),
      ),
    );
    unawaited(_loadCalendar());
    unawaited(_loadEvents());
    unawaited(_load('pages.flows', repository.flows));
    unawaited(_loadSocial());
    _scheduleBoundary();
  }

  String _memberKey(SharedCalendarSummary c) => 'calendars.members.${c.id}';
  Future<void> _loadCalendars() async {
    final rows = await _load(
      'calendars.list',
      () => SharedCalendarsRepo(client).readAcceptedCalendarsOnly(),
    );
    if (rows == null || !active) return;
    final ranked = rows.toList()
      ..sort((a, b) => b.memberCount.compareTo(a.memberCount));
    final subjects = {
      for (final c in [
        ranked.firstOrNull,
        rows.where((r) => r.name.toLowerCase().contains('reading')).firstOrNull,
      ])
        if (c != null) c.id: c,
    };
    for (final c in subjects.values) {
      if (!active) return;
      if (c.isPersonal || c.isSystem) continue;
      final loaded = cache.loadedAt(uid, _memberKey(c));
      final listLoaded = cache.loadedAt(uid, 'calendars.list');
      await _load(
        _memberKey(c),
        () => repository.calendarMembers(c.id),
        stale:
            loaded != null && listLoaded != null && loaded.isBefore(listLoaded),
      );
    }
  }

  List<PagesPerson> _members(SharedCalendarSummary? c) {
    if (c == null) return const [];
    final loaded = _peek<List<PagesPerson>>(_memberKey(c));
    if (loaded != null) return loaded;
    final owner = ProfileRepo(client).getCachedProfileSync(c.ownerId);
    return c.isPersonal && owner != null
        ? [PagesPerson(owner.effectiveName, glyphIds: owner.avatarGlyphIds)]
        : const [];
  }

  Future<void> _loadLibrary() async {
    if (_peek<LibraryReadSnapshot>('library.progress') != null) return;
    final snapshot = await LibraryReadProgressStore(
      currentUserIdProvider: () => uid,
    ).readCachedSnapshotOnly();
    if (_disposed || client.auth.currentUser?.id != uid) return;
    if (snapshot != null) {
      cache.publish(uid, 'library.progress', snapshot);
    } else {
      _set(
        const PagesCard(
          PagesDestination.library,
          state: PagesLoadState.failed,
          meta: 'Progress unavailable',
        ),
      );
    }
  }

  Future<void> _loadCalendar() async {
    final now = DateTime.now();
    final current = _peek<PagesCard>('pages.calendar');
    final sameMonth =
        current?.calendarDate != null &&
        KemeticMath.fromGregorian(current!.calendarDate!).kYear ==
            KemeticMath.fromGregorian(now).kYear &&
        KemeticMath.fromGregorian(current.calendarDate!).kMonth ==
            KemeticMath.fromGregorian(now).kMonth;
    if (sameMonth &&
        current.state == PagesLoadState.ready &&
        !cache.failed('pages.calendar') &&
        cache.loadedAt(uid, 'pages.calendar') != null) {
      _paintKey('pages.calendar');
      return;
    }
    final flows = await _load('pages.flows', repository.flows);
    if (!active || flows == null) return;
    final hidden = await _load(
      'pages.hiddenCalendars',
      () => SharedCalendarsRepo(client).getHiddenCalendarIds(),
    );
    if (!active || hidden == null) return;
    await _load(
      'pages.calendar',
      () => repository.calendar(now, flows, hidden),
      stale: !sameMonth || current.state != PagesLoadState.ready,
    );
  }

  Future<void> _loadEvents() async {
    final window = _peek<PagesEventWindow>('pages.events');
    await _load('pages.events', () async {
      final hidden = await _load(
        'pages.hiddenCalendars',
        () => SharedCalendarsRepo(client).getHiddenCalendarIds(),
      );
      if (!active) throw const ViewReadCancelled();
      return repository.events(DateTime.now(), hidden: hidden ?? const {});
    }, stale: window != null && !window.end.isAfter(DateTime.now()));
    if (active) _scheduleBoundary();
  }

  Future<void> _loadSocial() async {
    await Future.wait([
      _load(
        'social.activity',
        () => share.getRecentActivity(
          limit: 20,
          strict: true,
          includeCommentBody: false,
        ),
      ),
      _load('social.together', repository.together),
      _load('social.commons', repository.commons),
      _load('social.posts', repository.ownPosts),
      _load('social.inbox', () => share.readInboxMetadata()),
    ]);
    if (!active) return;
    for (final bucket in InboxActivityBucket.values) {
      final seen = await share.getActivitySeenAt(bucket);
      if (!active) return;
      if (seen != null) cache.publish(uid, 'social.seen.${bucket.name}', seen);
    }
    final seen = _peek<DateTime>('social.seen.movement');
    final newestActivity =
        (_peek<List<InboxActivityItem>>('social.activity') ?? [])
            .where(
              (a) =>
                  a.type != InboxActivityType.follow &&
                  seen != null &&
                  a.createdAt.isAfter(seen),
            )
            .firstOrNull;
    final requests =
        (_peek<TogetherInboxSnapshot>('social.together')?.joinRequests ?? [])
            .where((r) => r.status == 'pending')
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            ),
          );
    final request = requests.firstOrNull;
    final posts = _peek<List<FlowPost>>('social.posts') ?? [];
    if (newestActivity != null &&
        (request == null ||
            newestActivity.createdAt.isAfter(
              request.createdAt ?? DateTime(1970),
            ))) {
      final id = newestActivity.flowPostId;
      if (id != null && !posts.any((p) => p.id == id)) {
        await _load(
          'social.post.$id',
          () => repository.activityPost(postId: id),
        );
      }
    } else if (request?.sourceFlowId != null) {
      final id = request!.sourceFlowId!;
      if (!posts.any((p) => p.sourceFlowId == id) &&
          !(_peek<List<PagesFlow>>('pages.flows') ?? []).any(
            (f) => f.id == '$id',
          )) {
        await _load(
          'social.request.$id',
          () => repository.activityPost(flowId: id),
        );
      }
    }
    if (!active) return;
    final commons = _peek<CommonsHomeSnapshot>('social.commons');
    final room = commons?.publicSharedPractices
        .where(isPagesJoinable)
        .firstOrNull;
    if (room != null &&
        !commons!.discover.any(
          (p) => p.flowPost?.sourceFlowId == room.sourceFlowId,
        )) {
      await _load(
        'social.appearance.${room.sourceFlowId}',
        () => repository.publicAppearance(room.sourceFlowId),
      );
    }
    _paintSocial();
  }

  void _changed() {
    if (_disposed) return;
    final key = cache.changes.value;
    if (key != null) _paintKey(key);
  }

  void _paintKey(String key) {
    if (key == 'pages.calendar') {
      final card = _peek<PagesCard>(key);
      if (card != null) {
        final now = DateTime.now();
        final k = KemeticMath.fromGregorian(now);
        _set(
          PagesCard(
            PagesDestination.calendar,
            state: card.state,
            primary: card.primary,
            meta:
                card.calendarDate != null &&
                    PagesReadRepository.dayKey(card.calendarDate!) ==
                        PagesReadRepository.dayKey(now)
                ? card.meta
                : '${card.calendarNotes[k.kDay]?.length ?? 0} today',
            calendarDate: DateTime(now.year, now.month, now.day),
            showGregorian: card.showGregorian,
            calendarNotes: card.calendarNotes,
            calendarFlowNames: card.calendarFlowNames,
            days: card.days,
          ),
        );
      } else if (cache.failed(key)) {
        _missing(PagesDestination.calendar, [key]);
      }
    }
    if (key == 'planner.overview') _paintPlanner();
    if (key == 'journal.overview') _paintJournal();
    if (key == 'library.progress') _paintLibrary();
    if (key.startsWith('calendars.members.')) _paintCalendars();
    if (key == 'calendars.list' && active) unawaited(_loadCalendars());
    if (key == 'calendars.list' || key == 'pages.hiddenCalendars') {
      _paintCalendars();
    }
    if (key == 'pages.flows' || key == 'pages.events') {
      _paintStudio();
      _paintSocial();
    }
    if (key.startsWith('social.')) _paintSocial();
    if (key.startsWith('image.')) {
      _paintStudio();
      _paintSocial();
    }
  }

  void _paintAll() {
    for (final key in [
      'pages.calendar',
      'planner.overview',
      'journal.overview',
      'library.progress',
      'calendars.list',
      'pages.events',
      'social.activity',
    ]) {
      _paintKey(key);
    }
  }

  void _set(PagesCard card) {
    if (_disposed) return;
    final target = cards[card.destination.index];
    if (_same(_cardData(target.value), _cardData(card))) return;
    target.value = card;
  }

  bool _same(Object? a, Object? b) {
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
    }
    return a == b;
  }

  List<Object?> _cardData(PagesCard c) {
    List<Object?> signal(PagesSignal s) => [
      s.title,
      s.label,
      s.detail,
      s.glyph,
      s.status,
      s.color,
      s.progress,
      s.glyphIds,
      for (final p in s.people) [p.name, p.glyphIds],
    ];
    final f = c.flow;
    return [
      c.state,
      c.meta,
      signal(c.primary),
      signal(c.upper),
      signal(c.lower),
      if (f != null)
        [
          f.occurrence?.at,
          f.occurrence?.behavior,
          f.occurrence?.localFlowId,
          f.id,
          f.name,
          f.appearance,
          f.maatKey,
          f.notes,
          f.color,
          f.completed,
          f.total,
          f.start,
          f.end,
          identityHashCode(f.imageBytes),
        ],
      for (final v in c.companionFlows)
        [
          v.occurrence?.at,
          v.occurrence?.behavior,
          v.occurrence?.localFlowId,
          v.id,
          v.name,
          v.appearance,
          v.maatKey,
          v.notes,
          v.color,
          v.completed,
          v.total,
          identityHashCode(v.imageBytes),
        ],
      for (final d in c.days) [d.day, d.today, d.past, d.colors],
      c.calendarDate,
      c.showGregorian,
      c.calendarNotes,
      c.calendarFlowNames,
      c.weekdays,
      c.week,
      c.calendars,
      c.unread,
    ];
  }

  PagesLoadState _state(Iterable<String> keys) =>
      keys.any(cache.failed) ? PagesLoadState.failed : PagesLoadState.loading;
  void _missing(PagesDestination d, List<String> keys) =>
      _set(PagesCard(d, state: _state(keys)));
  String _time(DateTime at) =>
      '${at.hour % 12 == 0 ? 12 : at.hour % 12}:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}';
  String _when(DateTime? at) =>
      at == null ? '' : '${at.month}/${at.day} · ${_time(at)}';
  void _paintPlanner() {
    final p = _peek<PlannerOverview>('planner.overview');
    if (p == null || cache.failed('planner.overview')) {
      _missing(PagesDestination.planner, ['planner.overview']);
      return;
    }
    final now = DateTime.now(),
        next = selectPagesPlanner(p.candidates(DateTime.now()), DateTime.now());
    _set(
      PagesCard(
        PagesDestination.planner,
        state: PagesLoadState.ready,
        meta: '${p.percent(now)}% aligned',
        primary: PagesSignal('Aligned', progress: p.percent(now).toDouble()),
        upper: PagesSignal(
          p.note.isEmpty ? 'Name a commitment' : p.note,
          label: 'Note',
        ),
        lower: PagesSignal(
          next?.title ?? 'All caught up',
          label: next == null
              ? ''
              : next.isNutrition
              ? 'Nutrition'
              : 'To do',
          detail: _when(next?.at),
        ),
      ),
    );
  }

  void _paintJournal() {
    final j = _peek<JournalOverview>('journal.overview');
    if (j == null || cache.failed('journal.overview')) {
      _missing(PagesDestination.journal, ['journal.overview']);
      return;
    }
    final now = DateTime.now();
    final today = PagesReadRepository.dayKey(now);
    final kemetic = KemeticMath.fromGregorian(now);
    _set(
      PagesCard(
        PagesDestination.journal,
        state: PagesLoadState.ready,
        meta: j.unsaved.contains(today)
            ? 'Draft on this device'
            : j.written.contains(today)
            ? 'Today is saved'
            : 'Today is open',
        primary:
            j.badges.firstOrNull ??
            PagesSignal(
              j.historyComplete ? 'Capture your day' : 'Badge unavailable',
            ),
        upper: PagesSignal(
          '${getMonthById(kemetic.kMonth).displayShort} ${kemetic.kDay}',
          label: 'Today',
          detail: j.unsaved.contains(today)
              ? 'Unsaved draft'
              : j.written.contains(today)
              ? '✓ Saved'
              : 'Still open',
        ),
        week: List.generate(
          7,
          (i) => j.written.contains(
            PagesReadRepository.dayKey(
              DateTime(now.year, now.month, now.day - 6 + i),
            ),
          ),
        ),
      ),
    );
  }

  void _paintLibrary() {
    final snapshot = _peek<LibraryReadSnapshot>('library.progress');
    if (snapshot == null) return;
    final nodes = {
      for (final n in KemeticNodeLibrary.nodes) n.id.toLowerCase(): n,
    };
    final progress =
        snapshot.progressByNodeId.values
            .where((p) => nodes.containsKey(p.normalizedNodeId))
            .toList()
          ..sort(
            (a, b) => b.automaticResumeTime.compareTo(a.automaticResumeTime),
          );
    final current = progress.where((p) => p.isInProgress).toList();
    PagesSignal signal(LibraryNodeProgress p) {
      final n = nodes[p.normalizedNodeId]!;
      return PagesSignal(
        n.title,
        glyph: n.glyph,
        progress: p.normalizedProgressPercent,
        detail: '${p.normalizedProgressPercent.round()}% read',
      );
    }

    final complete = progress.where((p) => p.isCompleted).firstOrNull;
    _set(
      PagesCard(
        PagesDestination.library,
        state: PagesLoadState.ready,
        meta: current.isEmpty ? 'The canon' : 'Continue reading',
        primary: current.isEmpty
            ? PagesSignal(
                progress.isEmpty ? 'Begin the canon' : 'Explore the canon',
              )
            : signal(current.first),
        upper: complete == null
            ? const PagesSignal('Keep reading')
            : PagesSignal(
                nodes[complete.normalizedNodeId]!.title,
                label: 'Completed',
                glyph: nodes[complete.normalizedNodeId]!.glyph,
              ),
        lower: current.length > 1
            ? signal(current[1])
            : const PagesSignal('Explore the canon'),
      ),
    );
  }

  PagesFlow _image(
    PagesFlow f, {
    bool fetch = true,
    PagesUpcomingEvent? occurrence,
  }) {
    final path = f.appearance.imageObjectPath;
    Uint8List? bytes = f.imageBytes;
    if (path != null) {
      bytes ??=
          _peek<Uint8List>('image.$path') ??
          FlowAppearanceStore(client).cachedImageBytes(path);
      if (bytes == null && active && fetch) {
        unawaited(
          _load(
            'image.$path',
            () => FlowAppearanceStore(client).imageBytes(path),
          ),
        );
      }
    }
    return PagesFlow(
      id: f.id,
      name: f.name,
      appearance: f.appearance,
      color: f.color,
      completed: f.completed,
      total: f.total,
      start: f.start,
      end: f.end,
      imageBytes: bytes,
      maatKey: f.maatKey,
      notes: f.notes,
      occurrence: occurrence ?? f.occurrence,
    );
  }

  void _paintStudio() {
    final flows = _peek<List<PagesFlow>>('pages.flows'),
        window = _peek<PagesEventWindow>('pages.events');
    if (flows == null ||
        window == null ||
        cache.failed('pages.flows') ||
        cache.failed('pages.events')) {
      _missing(PagesDestination.studio, ['pages.events', 'pages.flows']);
      return;
    }
    final selected = selectPagesStudio(flows, window.events, DateTime.now());
    final f = selected.flow;
    // Picture companions come from the same loaded, visible filed-flow slice.
    // Keep the lead selection authoritative and never fetch companion images.
    final companions = <PagesFlow>[];
    final remaining = flows.where((v) => v.id != f?.id).toList();
    while (remaining.isNotEmpty && companions.length < 2) {
      final nextSelection = selectPagesStudio(
        remaining,
        window.events,
        DateTime.now(),
      );
      final next = nextSelection.flow;
      if (next == null) break;
      companions.add(
        _image(next, fetch: false, occurrence: nextSelection.event),
      );
      remaining.removeWhere((v) => v.id == next.id);
    }
    _set(
      PagesCard(
        PagesDestination.studio,
        state: PagesLoadState.ready,
        meta: f == null ? 'Your flows' : f.name,
        flow: f == null ? null : _image(f, occurrence: selected.event),
        companionFlows: companions,
        primary: const PagesSignal('Create a flow'),
        upper: PagesSignal(
          selected.event?.title ?? 'No event scheduled',
          label: 'Next event',
          detail: _when(selected.event?.at),
        ),
        lower: PagesSignal(
          f == null
              ? ''
              : f.total > 0
              ? '${f.total - f.completed}'
              : '',
          detail: f == null || f.total == 0 ? '' : 'steps remaining',
        ),
      ),
    );
  }

  void _paintSocial() {
    _paintInbox();
    final activity = _peek<List<InboxActivityItem>>('social.activity'),
        together = _peek<TogetherInboxSnapshot>('social.together'),
        commons = _peek<CommonsHomeSnapshot>('social.commons'),
        posts = _peek<List<FlowPost>>('social.posts');
    if (activity == null ||
        together == null ||
        commons == null ||
        posts == null ||
        [
          'social.activity',
          'social.together',
          'social.commons',
          'social.posts',
        ].any(cache.failed)) {
      _missing(PagesDestination.feed, [
        'social.activity',
        'social.together',
        'social.commons',
        'social.posts',
      ]);
      return;
    }
    final flows = _peek<List<PagesFlow>>('pages.flows') ?? const [];
    final resolvedPosts = [
      ...posts,
      for (final a in activity)
        ...?_peek<List<FlowPost>>('social.post.${a.flowPostId}'),
      for (final r in together.joinRequests)
        ...?_peek<List<FlowPost>>('social.request.${r.sourceFlowId}'),
    ];
    final candidates = <PagesFeedCandidate>[];
    for (final a in activity) {
      final seen = _peek<DateTime>('social.seen.${a.bucket.name}');
      if (a.type == InboxActivityType.follow ||
          seen == null ||
          !a.createdAt.isAfter(seen)) {
        continue;
      }
      final p = resolvedPosts
          .where((p) => p.id == a.flowPostId && !p.isHidden)
          .firstOrNull;
      if (p != null) {
        candidates.add(
          PagesFeedCandidate(
            flow: flowFromPost(p),
            at: a.createdAt,
            reason: a.type == InboxActivityType.like
                ? 'Liked your flow'
                : 'Commented',
            actor: a.actorName ?? a.actorHandle ?? 'Someone',
            actorId: a.actorId,
            unresolved: true,
          ),
        );
      }
    }
    for (final request in together.joinRequests.where(
      (r) => r.status == 'pending',
    )) {
      final post = resolvedPosts
          .where((p) => p.sourceFlowId == request.sourceFlowId && !p.isHidden)
          .firstOrNull;
      final flow = post == null
          ? flows.where((f) => f.id == '${request.sourceFlowId}').firstOrNull
          : flowFromPost(post);
      if (flow != null) {
        candidates.add(
          PagesFeedCandidate(
            flow: flow,
            at: request.createdAt ?? DateTime(1970),
            reason: 'Wants to join',
            actor: request.requesterLabel,
            actorId: request.requesterId,
            unresolved: true,
          ),
        );
      }
    }
    final rooms = commons.publicSharedPractices.where(isPagesJoinable).toList();
    for (final room in rooms) {
      final post = commons.discover
          .map((p) => p.flowPost)
          .whereType<FlowPost>()
          .where((p) => p.sourceFlowId == room.sourceFlowId && !p.isHidden)
          .firstOrNull;
      final appearance = _peek<List<FlowRow>>(
        'social.appearance.${room.sourceFlowId}',
      )?.firstOrNull;
      final flow = post != null
          ? flowFromPost(post)
          : appearance == null
          ? null
          : flowFromRow(appearance);
      if (flow != null) {
        candidates.add(
          PagesFeedCandidate(
            flow: flow,
            at: room.updatedAt ?? room.createdAt ?? DateTime(1970),
            reason: 'Practice together',
            actor: room.ownerLabel,
            joinable: true,
          ),
        );
      }
    }
    for (final p in posts.where((p) => !p.isHidden)) {
      candidates.add(
        PagesFeedCandidate(
          flow: flowFromPost(p),
          at: p.createdAt,
          reason: 'Your shared flow',
          ownShared: true,
          actorId: uid,
        ),
      );
    }
    final selected = selectPagesFeed(candidates);
    _set(
      PagesCard(
        PagesDestination.feed,
        state: PagesLoadState.ready,
        meta: selected?.reason ?? 'Discover a flow',
        flow: selected == null ? null : _image(selected.flow),
        primary: const PagesSignal('Discover a flow'),
        upper: PagesSignal(
          selected?.ownShared == true
              ? 'Latest shared flow'
              : selected?.actor ?? '',
          glyphIds: _personGlyphs(selected?.actorId),
          label: selected?.ownShared == true ? 'Your flows' : '',
          detail: selected?.reason ?? 'Practice together',
        ),
        lower: pagesCommonsSignal(rooms.firstOrNull),
      ),
    );
  }

  List<String> _personGlyphs(String? personId) {
    if (personId == null || personId.isEmpty) return const [];
    final profile = ProfileRepo(client).getCachedProfileSync(personId);
    if (profile != null) return profile.avatarGlyphIds;
    final key = 'social.avatar.$personId';
    final glyphs = _peek<List<String>>(key);
    if (glyphs != null) return glyphs;
    if (active) unawaited(_load(key, () => repository.personGlyphs(personId)));
    return const [];
  }

  void _paintInbox() {
    final rows = _peek<List<InboxActivityItem>>('social.activity'),
        together = _peek<TogetherInboxSnapshot>('social.together');
    final shares = _peek<List<InboxShareItem>>('social.inbox');
    if (rows == null ||
        together == null ||
        shares == null ||
        [
          'social.activity',
          'social.together',
          'social.inbox',
        ].any(cache.failed)) {
      _missing(PagesDestination.inbox, [
        'social.activity',
        'social.together',
        'social.inbox',
      ]);
      return;
    }
    final latest = rows.firstOrNull,
        follow = rows
            .where((r) => r.type == InboxActivityType.follow)
            .firstOrNull;
    final invitation = together.invitations.firstOrNull;
    final updates =
        shares
            .where(
              (s) =>
                  s.kind != InboxShareKind.message &&
                  (s.senderId != uid ||
                      s.respondedAt != null ||
                      s.importedAt != null),
            )
            .toList()
          ..sort(
            (a, b) => (b.respondedAt ?? b.importedAt ?? b.createdAt).compareTo(
              a.respondedAt ?? a.importedAt ?? a.createdAt,
            ),
          );
    final update = updates.firstOrNull;
    final useShare =
        update != null &&
        (latest == null ||
            (update.respondedAt ?? update.importedAt ?? update.createdAt)
                .isAfter(latest.createdAt));
    final isSender = update?.senderId == uid;
    final updateName = isSender
        ? (update?.recipientDisplayName ?? update?.recipientHandle)
        : (update?.senderName ?? update?.senderHandle);

    String reason(InboxActivityItem a) => switch (a.type) {
      InboxActivityType.like => 'liked your flow',
      InboxActivityType.comment => 'commented',
      InboxActivityType.follow => 'followed you',
    };
    _set(
      PagesCard(
        PagesDestination.inbox,
        state: PagesLoadState.ready,
        meta: 'Your latest updates',
        unread: share.cachedUnreadStateOnly?.totalUnread ?? 0,
        primary: useShare
            ? PagesSignal(
                updateName ?? 'Someone',
                glyphIds: _personGlyphs(
                  isSender ? update.recipientId : update.senderId,
                ),
                label: 'Latest update',
                detail: pagesShareUpdateLabel(update, uid),
              )
            : latest == null
            ? const PagesSignal('All caught up')
            : PagesSignal(
                latest.actorName ?? latest.actorHandle ?? 'Someone',
                glyphIds: _personGlyphs(latest.actorId),
                label: 'Latest update',
                detail: reason(latest),
              ),
        upper: follow == null
            ? const PagesSignal('Community')
            : PagesSignal(
                follow.actorName ?? follow.actorHandle ?? 'Someone',
                glyphIds: _personGlyphs(follow.actorId),
                detail: 'followed you',
              ),
        lower: PagesSignal(
          invitation?.title ?? 'Reading House',
          glyph: invitation == null ? '𓉐' : '',
          detail: invitation == null ? 'Read together' : 'Invitation',
        ),
      ),
    );
  }

  void _paintCalendars() {
    final rows = _peek<List<SharedCalendarSummary>>('calendars.list'),
        hidden = _peek<Set<String>>('pages.hiddenCalendars');
    if (rows == null || hidden == null || cache.failed('calendars.list')) {
      _missing(PagesDestination.calendars, [
        'calendars.list',
        'pages.hiddenCalendars',
      ]);
      return;
    }
    final ranked = rows.toList()
      ..sort((a, b) => b.memberCount.compareTo(a.memberCount));
    final primary = ranked.firstOrNull;
    final reading = rows
        .where((r) => r.name.toLowerCase().contains('reading'))
        .firstOrNull;
    _set(
      PagesCard(
        PagesDestination.calendars,
        state: PagesLoadState.ready,
        meta:
            '${rows.where((r) => !hidden.contains(r.id)).length} active calendars',
        primary: primary == null
            ? const PagesSignal('Your calendars')
            : PagesSignal(
                primary.name,
                people: _members(primary),
                glyphIds:
                    ProfileRepo(
                      client,
                    ).getCachedProfileSync(primary.ownerId)?.avatarGlyphIds ??
                    const [],
                color: 0xff000000 | primary.colorValue,
                detail:
                    '${primary.memberCount} ${primary.memberCount == 1 ? 'member' : 'members'}',
              ),
        upper: PagesSignal(
          reading?.name ?? 'Reading House',
          people: _members(reading),
          color: 0xff000000 | (reading?.colorValue ?? 0x996ab5),
          detail: reading == null
              ? 'Read together'
              : '${reading.memberCount} members',
        ),
        calendars: rows
            .map(
              (r) => (
                color: 0xff000000 | r.colorValue,
                visible: !hidden.contains(r.id),
              ),
            )
            .toList(),
      ),
    );
  }

  void _scheduleBoundary() {
    _boundary?.cancel();
    if (!active) return;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day + 1);
    for (final e
        in _peek<PagesEventWindow>('pages.events')?.events ??
            <PagesUpcomingEvent>[]) {
      if (e.at.isAfter(now) && e.at.isBefore(next)) next = e.at;
    }
    _boundary = Timer(
      next.difference(now) + const Duration(milliseconds: 20),
      () {
        if (!active) return;
        onLocalBoundary?.call();
        unawaited(_loadCalendar());
        _paintPlanner();
        _paintJournal();
        _paintStudio();
        _scheduleBoundary();
      },
    );
  }

  List<PagesSearchRecord> searchRecords() => [
    for (final n in KemeticNodeLibrary.nodes)
      PagesSearchRecord(
        n.title,
        'Library',
        '/nodes/${Uri.encodeComponent(n.id)}',
      ),
    for (final f
        in _peek<List<PagesFlow>>('pages.flows') ?? const <PagesFlow>[])
      PagesSearchRecord(f.name, 'Flow Studio', '/flows/${f.id}/edit'),
    for (final t in _peek<PlannerOverview>('planner.overview')?.todos ?? [])
      PagesSearchRecord(t.title, 'Planner', '/rhythm/today'),
    for (final b in _peek<JournalOverview>('journal.overview')?.badges ?? [])
      PagesSearchRecord(b.title, 'Journal', '/journal'),
    for (final c
        in _peek<List<SharedCalendarSummary>>('calendars.list') ??
            const <SharedCalendarSummary>[])
      PagesSearchRecord(c.name, 'Calendars', '/calendars'),
  ];
  void dispose() {
    _disposed = true;
    _visible = false;
    _boundary?.cancel();
    cache.changes.removeListener(_changed);
    unawaited(_calendarChanges?.cancel());
    unawaited(_unreadChanges?.cancel());
    for (final card in cards) {
      card.dispose();
    }
  }
}
