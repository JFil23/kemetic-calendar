import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../../data/account_operation_fence.dart';
import '../../data/external_calendar_repository.dart';
import '../../data/flows_repo.dart';
import '../../data/profile_repo.dart';
import '../../data/user_events_repo.dart';
import '../calendar/calendar_invalidation.dart';
import '../calendar/maat_flow_temporal_policy.dart';
import '../calendar/maat_flow_temporal_controller.dart';
import '../calendar/notify.dart';
import '../../utils/kemetic_date_format.dart';
import 'ask_haw_catalog.dart';
import 'ask_haw_engine.dart';
import 'ask_haw_flow_contract.dart';
import 'ask_haw_memory.dart';
import 'ask_haw_memory_repository.dart';
import 'ask_haw_models.dart';
import 'ask_haw_planner.dart';
import 'ask_haw_recognizer.dart';
import 'ask_haw_response.dart';

typedef AskHawTimeParser =
    ({DateTime day, int? hour, int? minute})? Function(String text);

/// Lives only with the shared Quick Add sheet. Reads are requested by an intent;
/// it never participates in launch readiness, warming or notification schedules.
class AskHawController extends ChangeNotifier {
  AskHawController({
    required this.client,
    required this.parseTime,
    required this.navigate,
    required this.setInput,
    required this.addEvent,
    this.openEvent,
    this.rewriteDetail,
    this.onAccountChanged,
    Future<void> Function()? syncReminders,
    this.selectedFlowId,
    this.selectedEventId,
    this.selectedClientEventId,
    this.dateMode = 'kemetic',
    this.readDateMode,
    DateTime Function()? clock,
    Future<Map<String, dynamic>> Function(DateTime, DateTime)? readContext,
    Future<List<ExternalCalendarEvent>> Function(DateTime, DateTime)?
    readExternal,
    Future<Map<String, dynamic>> Function(String, List<Map<String, dynamic>>)?
    execute,
    AskHawMemoryRepository? memoryRepository,
    Future<List<Map<String, dynamic>>> Function()? readPendingActions,
  }) : _clock = clock ?? DateTime.now,
       _syncReminders = syncReminders ?? Notify.syncLocalDeliveryMode,
       _readContext =
           readContext ??
           ((from, until) => UserEventsRepo(
             client,
           ).readAskHawContext(fromUtc: from, untilUtc: until)),
       _readExternal =
           readExternal ??
           ((from, until) =>
               externalCalendarRepository(client).readBusyEvents(from, until)),
       _execute =
           execute ??
           ((id, actions) => UserEventsRepo(
             client,
           ).applyAskHawActions(mutationId: id, actions: actions)),
       _memoryRepo = memoryRepository ?? AskHawMemoryRepository(client),
       _readPendingActions =
           readPendingActions ?? UserEventsRepo(client).pendingAskHawActions,
       _account = AccountOperationFence(client) {
    _auth = client.auth.onAuthStateChange.listen((_) {
      if (_account.userId != null &&
          !_account.isCurrent &&
          !_disposed &&
          !_accountDeparted) {
        _accountDeparted = true;
        _generation++;
        _pending = null;
        _context = null;
        _flows = [];
        _memory = AskHawMemory();
        _raw = '';
        _request = null;
        _plan = null;
        _rawContext = null;
        _savedActions = [];
        _catalog = buildAskHawCatalog();
        if (_account.userId != null) onAccountChanged?.call();
        response = const AskHawResponse(
          title: 'Your account changed',
          body: 'Reopen Ask ḥꜣw to continue with this account.',
          kind: AskHawResponseKind.unavailable,
        );
        busy = false;
        notifyListeners();
      }
    });
  }
  final SupabaseClient client;
  final AskHawTimeParser parseTime;
  final Future<void> Function(String route) navigate;
  final ValueChanged<String> setInput;
  final Future<void> Function() addEvent;
  final Future<void> Function(AskHawEvent)? openEvent;
  final String Function(String? original, String guidance)? rewriteDetail;
  final VoidCallback? onAccountChanged;
  final Future<List<Map<String, dynamic>>> Function() _readPendingActions;
  final Future<void> Function() _syncReminders;
  String dateMode;
  final Future<String> Function()? readDateMode;
  int? selectedFlowId;
  String? selectedEventId, selectedClientEventId;
  final DateTime Function() _clock;
  final Future<Map<String, dynamic>> Function(DateTime, DateTime) _readContext;
  final Future<List<ExternalCalendarEvent>> Function(DateTime, DateTime)
  _readExternal;
  final Future<Map<String, dynamic>> Function(
    String,
    List<Map<String, dynamic>>,
  )
  _execute;
  final AskHawMemoryRepository _memoryRepo;
  final AccountOperationFence _account;
  late final StreamSubscription<AuthState> _auth;
  AskHawMemory _memory = AskHawMemory();
  AskHawCatalog _catalog = buildAskHawCatalog();
  AskHawContext? _context;
  List<Map<String, dynamic>> _flows = [];
  Map<String, dynamic>? _rawContext;
  AskHawRequest? _request;
  _AskHawPending? _pending;
  AskHawPlan? _plan;
  DateTime? _lastMovedStart;
  String _raw = '';
  int _generation = 0, _limit = 2;
  bool busy = false, _disposed = false;
  bool _memorySynced = false;
  bool _dateModeLoaded = false;
  bool _accountDeparted = false;
  List<Map<String, dynamic>> _savedActions = [];
  AskHawResponse? response;

  AskHawRequest recognize(String raw) =>
      const AskHawRecognizer().recognize(raw, memory: _memory);
  bool get _current =>
      !_disposed &&
      (_account.userId == null
          ? client.auth.currentUser == null
          : _account.isCurrent);
  bool _valid(int generation) => _current && generation == _generation;
  void dismiss() {
    _generation++;
    response = null;
    _pending = null;
    busy = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> restoreMemory() async {
    if (_account.userId == null) return;
    final generation = _generation;
    try {
      final restored = await _memoryRepo.restore();
      if (_valid(generation) && !_memorySynced) _memory = restored;
    } catch (_) {
      /* Public answers and ordinary Quick Add do not depend on memory sync. */
    }
  }

  Future<void> ask(String raw, {bool ignoreBinding = false}) async {
    AskHawRequest recognizeRequest() => const AskHawRecognizer().recognize(
      raw,
      memory: ignoreBinding
          ? _memory.copyWith(
              payload: {..._memory.payload, 'bindings': <String, dynamic>{}},
            )
          : _memory,
    );
    var request = recognizeRequest();
    if (request.isEvent) return;
    final generation = ++_generation;
    _raw = raw;
    _request = request;
    _pending = null;
    _plan = null;
    busy = true;
    response = null;
    notifyListeners();
    var ownSearchUnavailable = false;
    try {
      final personalRequest =
          _account.userId != null &&
          !const {
            AskHawIntent.event,
            AskHawIntent.explain,
            AskHawIntent.clarify,
          }.contains(request.intent);
      if (personalRequest) {
        if (!_memorySynced) {
          final memory = await _memoryRepo.read();
          if (!_valid(generation)) return;
          _memory = memory;
          _memorySynced = true;
          request = recognizeRequest();
          _request = request;
        }
        try {
          final saved = await _readPendingActions();
          if (!_valid(generation)) return;
          _savedActions = saved;
        } catch (_) {
          // Recovery storage failure cannot fabricate or submit a request.
        }
      }
      if (request.requiresAccount &&
          _account.userId == null &&
          request.intent != AskHawIntent.fit) {
        response = const AskHawResponse(
          title: 'Your calendar belongs to your account',
          body: 'Sign in to use your saved events and Flow preferences.',
          options: [
            AskHawOption(id: 'account:request', label: 'Sign in'),
            AskHawOption(
              id: 'help',
              label: 'Explore public help',
              secondary: true,
            ),
          ],
        );
        return;
      }
      final private =
          _account.userId != null &&
          (request.query == 'shorter sessions' ||
              const {
                AskHawIntent.next,
                AskHawIntent.fit,
                AskHawIntent.plan,
                AskHawIntent.move,
                AskHawIntent.shorten,
                AskHawIntent.skip,
                AskHawIntent.pause,
                AskHawIntent.resume,
              }.contains(request.intent));
      if (private) {
        if (!_dateModeLoaded && readDateMode != null) {
          final mode = await readDateMode!();
          if (!_valid(generation)) return;
          if (mode == 'kemetic' || mode == 'gregorian') dateMode = mode;
          _dateModeLoaded = true;
        }
        await _loadContext(request, generation: generation);
      }
      if (request.intent == AskHawIntent.find &&
          _account.userId != null &&
          request.contentId?.startsWith('post:') != true) {
        try {
          final flows = await FlowsRepo(
            client,
          ).listMyFlowsUnfiltered(limit: 1000);
          if (!_valid(generation)) return;
          _catalog = buildAskHawCatalog(
            flows: flows,
            editableFlowIds: flows
                .where((f) => f.userId == _account.userId)
                .map((f) => f.id)
                .toSet(),
          );
        } catch (_) {
          if (!_valid(generation)) return;
          _catalog = buildAskHawCatalog();
          ownSearchUnavailable = true;
        }
      }
      if (!_valid(generation)) return;
      response = const AskHawEngine().respond(
        request,
        catalog: _catalog,
        context: _context,
        memory: _memory,
        limit: _limit,
        nowUtc: _clock().toUtc(),
      );
      if (request.intent == AskHawIntent.preferences &&
          request.query == 'shorter sessions') {
        _showDurationChoices();
      }
      if (request.intent == AskHawIntent.find && _account.userId != null) {
        await _findShared(request, generation);
      }
      if (!_valid(generation)) return;
      if (ownSearchUnavailable && response != null) {
        final current = response!;
        response = AskHawResponse(
          title: 'Here is what I can confirm',
          kind: current.kind,
          body: [
            if (current.body != null) current.body!,
            'Your saved Flows could not be checked. These results may be incomplete.',
          ].join('\n\n'),
          options: current.options,
        );
      }
      if (request.intent == AskHawIntent.plan ||
          request.intent == AskHawIntent.fit) {
        if (_context case final context?) {
          _plan = const AskHawPlanner().plan(
            context,
            maxMinutes: request.intent == AskHawIntent.fit
                ? request.minutes
                : null,
          );
        }
      }
      if (request.intent == AskHawIntent.plan &&
          _context?.windows.isEmpty == true) {
        response = const AskHawResponse(
          title: 'When may I suggest activities?',
          body: 'Choose an availability window before I propose calendar time.',
          options: [
            AskHawOption(id: 'availability', label: 'Choose my available time'),
          ],
        );
      } else if (request.intent == AskHawIntent.plan &&
          (_plan?.allocations.length ?? 0) > 1 &&
          response != null) {
        final current = response!;
        response = AskHawResponse(
          title: current.title,
          body: current.body,
          kind: current.kind,
          options: [
            const AskHawOption(id: 'plan:all', label: 'Review the whole plan'),
            ...current.options,
          ],
        );
      }
      _appendCorrection();
      if (_savedActions.isNotEmpty && personalRequest && response != null) {
        final current = response!;
        response = AskHawResponse(
          title: current.title,
          body: current.body,
          kind: current.kind,
          options: [
            ...current.options,
            const AskHawOption(
              id: 'recover:saved',
              label: 'Review an unconfirmed change',
              secondary: true,
            ),
          ],
        );
      }
    } catch (_) {
      if (_valid(generation)) {
        response = const AskHawResponse(
          title: 'I couldn’t confirm that yet',
          body:
              'Your text is still here. Calendar changes require a complete, current account read.',
          kind: AskHawResponseKind.unavailable,
          options: [
            AskHawOption(id: 'retry', label: 'Try again'),
            AskHawOption(
              id: 'help',
              label: 'See supported requests',
              secondary: true,
            ),
          ],
        );
      }
    } finally {
      if (_valid(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _findShared(AskHawRequest request, int generation) async {
    // A bounded server search uses the existing published visibility authority.
    // Failure retains truthful bundled results without claiming a full search.
    try {
      if (request.contentId?.startsWith('post:') == true) {
        final post = await ProfileRepo(client).getFlowPostById(
          request.contentId!.substring(5),
          strict: true,
          refresh: true,
        );
        if (!_valid(generation)) return;
        response = post == null
            ? const AskHawResponse(
                title: 'That remembered Flow is unavailable',
                body: 'It may have been removed or its access changed.',
                options: [
                  AskHawOption(
                    id: 'binding:search',
                    label: 'Search for another Flow',
                  ),
                ],
              )
            : AskHawResponse(
                title: 'Your remembered Flow',
                kind: AskHawResponseKind.results,
                options: [
                  AskHawOption(
                    id: 'open:post:${post.id}',
                    label: post.name,
                    detail: 'Published Flow · Preview before adding',
                    reason: 'The meaning you confirmed.',
                  ),
                ],
              );
        return;
      }
      final raw = await client.rpc(
        'search_ask_haw_flows_v1',
        params: {
          'p_account': _account.userId,
          'p_query': askHawSearchTerms(
            normalizeAskHaw(request.query),
          ).join(' '),
          'p_limit': _limit + 1,
        },
      );
      if (!_valid(generation)) return;
      final search = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final resultRows = search['results'];
      final posts = resultRows is List
          ? resultRows
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList()
          : <Map<String, dynamic>>[];
      if (posts.isEmpty) return;
      final public =
          response?.options.where((o) => o.id.startsWith('open:')).toList() ??
          <AskHawOption>[];
      final shared = [
        for (final post in posts)
          AskHawOption(
            id: 'open:post:${post['id']}',
            label: post['name']?.toString() ?? 'Shared Flow',
            detail: 'Published Flow · Preview its schedule before adding',
            reason: 'Matches your requested topic.',
          ),
      ];
      response = AskHawResponse(
        title: 'Here is what I found',
        kind: AskHawResponseKind.results,
        options: [...public, ...shared].take(_limit).toList()
          ..addAll([
            if (public.length + shared.length > _limit)
              const AskHawOption(
                id: 'search:more',
                label: 'See more',
                secondary: true,
              ),
          ]),
      );
    } catch (_) {
      if (request.contentId?.startsWith('post:') == true &&
          _valid(generation)) {
        response = const AskHawResponse(
          title: 'I couldn’t confirm the remembered Flow',
          body: 'Try again before opening this saved meaning.',
          options: [
            AskHawOption(id: 'retry', label: 'Try again'),
            AskHawOption(
              id: 'binding:search',
              label: 'Search for another Flow',
              secondary: true,
            ),
          ],
        );
      } else if (_valid(generation) && response != null) {
        final current = response!;
        response = AskHawResponse(
          title: current.options.any((option) => option.id.startsWith('open:'))
              ? current.title
              : 'Published Flows could not be checked',
          body: [
            if (current.body != null) current.body!,
            'Published Flow search is unavailable. These results may be incomplete.',
          ].join('\n\n'),
          kind: current.kind,
          options: [
            ...current.options,
            const AskHawOption(
              id: 'retry',
              label: 'Try search again',
              secondary: true,
            ),
          ],
        );
      }
      /* This is optional discovery, not evidence of an empty shared catalog. */
    }
  }

  Future<void> _loadContext(AskHawRequest request, {int? generation}) async {
    bool valid() => _current && (generation == null || _valid(generation));
    final now = _clock().toUtc();
    final from = DateTime.utc(now.year, now.month, now.day - 1);
    final until = DateTime.utc(now.year, now.month, now.day + 30);
    final raw = await _readContext(from, until);
    if (!valid()) return;
    final zone =
        raw['timezone'] as String? ??
        MaatFlowDeviceTimeZone.currentIanaTimeZone;
    final temporal = MaatFlowTemporalContext.fromInstant(
      nowUtc: now.toUtc(),
      ianaTimeZone: zone,
    );
    final location = tz.getLocation(zone);
    final requestedDay =
        request.intent == AskHawIntent.plan &&
            (request.explicitTemporal ||
                RegExp(
                  r'\btomorrow\b',
                  caseSensitive: false,
                ).hasMatch(request.raw))
        ? parseTime(request.temporalText ?? request.raw)?.day
        : null;
    final date = requestedDay ?? temporal.presentLocalDate;
    // Availability is a user choice. Ask for it when no confirmed window exists.
    final prefs = _memory.preferences;
    final startHour = (prefs['availableStartHour'] as num?)?.toInt();
    final endHour = (prefs['availableEndHour'] as num?)?.toInt();
    final windows = <AskHawWindow>[];
    if (startHour != null &&
        endHour != null &&
        startHour >= 0 &&
        endHour <= 24 &&
        endHour > startHour) {
      windows.add(
        AskHawWindow(
          startUtc: tz.TZDateTime(
            location,
            date.year,
            date.month,
            date.day,
            startHour,
          ).toUtc(),
          endUtc: tz.TZDateTime(
            location,
            date.year,
            date.month,
            date.day,
            endHour,
          ).toUtc(),
        ),
      );
    }
    final events = <AskHawEvent>[];
    for (final value in raw['events'] as List? ?? []) {
      final event = Map<String, dynamic>.from(value as Map);
      if (event['flow_suspended'] == true) continue;
      final start = DateTime.parse(event['starts_at'] as String).toUtc();
      final local = tz.TZDateTime.from(start, location);
      final allDay = event['all_day'] == true;
      final effectiveStart = allDay
          ? tz.TZDateTime(location, local.year, local.month, local.day).toUtc()
          : start;
      final end = event['ends_at'] == null
          ? (allDay
                ? tz.TZDateTime(
                    location,
                    local.year,
                    local.month,
                    local.day + 1,
                  ).toUtc()
                : start)
          : DateTime.parse(event['ends_at'] as String).toUtc();
      events.add(
        AskHawEvent(
          id: event['id'].toString(),
          clientEventId: event['client_event_id'] as String?,
          title: event['title'] as String? ?? '',
          startUtc: effectiveStart,
          endUtc: end,
          allDay: allDay,
          durationKnown: event['ends_at'] != null || allDay,
          completion: switch (event['completion_status']) {
            'observed' || 'done' || 'completed' => AskHawCompletion.observed,
            'partial' || 'observed_partly' => AskHawCompletion.partial,
            'skipped' => AskHawCompletion.skipped,
            _ => AskHawCompletion.unknown,
          },
          eventRevision: event['event_revision']?.toString(),
          flowId:
              (event['filed_flow_id'] as num? ?? event['flow_local_id'] as num?)
                  ?.toInt(),
          editable: event['can_edit'] == true,
          calendarId: event['calendar_id'] as String?,
          stepId:
              ((event['behavior_payload'] as Map?)?['ask_haw']
                      as Map?)?['step_id']
                  as String?,
        ),
      );
    }
    final external = await _readExternal(from, until);
    if (!valid()) return;
    for (final event in external) {
      final sourceStart = event.startsAtUtc.toLocal();
      final sourceEnd = event.endsAtUtc.toLocal();
      events.add(
        AskHawEvent(
          id: 'external:${event.id}',
          clientEventId: event.clientEventId,
          title: event.title,
          startUtc: event.allDay
              ? tz.TZDateTime(
                  location,
                  sourceStart.year,
                  sourceStart.month,
                  sourceStart.day,
                ).toUtc()
              : event.startsAtUtc,
          endUtc: event.allDay
              ? tz.TZDateTime(
                  location,
                  sourceEnd.year,
                  sourceEnd.month,
                  sourceEnd.day,
                ).toUtc()
              : event.endsAtUtc,
          allDay: event.allDay,
        ),
      );
    }
    _flows = [
      for (final value in raw['flows'] as List? ?? [])
        Map<String, dynamic>.from(value as Map),
    ];
    final rows = _flows.map(FlowRow.fromRow).toList();
    final editable = _flows
        .where((r) => r['can_edit'] == true)
        .map((r) => (r['id'] as num).toInt())
        .toSet();
    _catalog = buildAskHawCatalog(flows: rows, editableFlowIds: editable);
    final activities = <AskHawActivity>[];
    final completions = raw['step_completions'] is Map
        ? Map<String, dynamic>.from(raw['step_completions'] as Map)
        : <String, dynamic>{};
    for (final flow in rows.where((flow) => flow.active && !flow.isHidden)) {
      final contract = AskHawFlowContract.tryFromJson(flow.assistance);
      if (contract == null || !editable.contains(flow.id)) continue;
      final saved = completions['${flow.id}'] as Map? ?? {};
      final statuses = <String, AskHawCompletion>{
        for (final step in contract.steps)
          step.id:
              AskHawCompletion.values
                  .where((v) => v.name == saved[step.id])
                  .firstOrNull ??
              AskHawCompletion.unknown,
      };
      for (final step in contract.steps) {
        // One pending step per Flow avoids scheduling every stage at once.
        if (statuses[step.id] == AskHawCompletion.observed ||
            statuses[step.id] == AskHawCompletion.skipped) {
          continue;
        }
        if (!step.eligible(statuses)) continue;
        if (events.any(
          (event) =>
              event.flowId == flow.id &&
              event.stepId == step.id &&
              event.endUtc.isAfter(now),
        )) {
          break;
        }
        var preferredHour =
            (prefs['preferredHour'] as num?)?.toInt() ??
            switch (_memory.preferredTimeOfDay) {
              'morning' => 8,
              'afternoon' => 14,
              'evening' => 19,
              _ => null,
            };
        final preferredMinute =
            (prefs['preferredMinute'] as num?)?.toInt() ?? 0;
        if (preferredHour != null &&
            (preferredHour < 0 ||
                preferredHour > 23 ||
                preferredMinute < 0 ||
                preferredMinute > 59)) {
          preferredHour = null;
        }
        activities.add(
          AskHawActivity(
            id: '${flow.id}:${step.id}',
            title: step.title,
            flowId: flow.id,
            stepId: step.id,
            contract: contract,
            revision: '${flow.assistanceRevision}',
            completions: statuses,
            paused: flow.pausedAt != null,
            preferredMinutes:
                ((prefs['flowDurationMinutes'] as Map?)?['${flow.id}'] as num?)
                    ?.toInt() ??
                _memory.preferredDurationMinutes,
            preferredStartUtc: preferredHour == null
                ? null
                : tz.TZDateTime(
                    location,
                    date.year,
                    date.month,
                    date.day,
                    preferredHour,
                    preferredMinute,
                  ).toUtc(),
          ),
        );
        break;
      }
    }
    if (selectedEventId == null && selectedClientEventId != null) {
      selectedEventId = events
          .where((e) => e.clientEventId == selectedClientEventId)
          .firstOrNull
          ?.id;
    }
    _rawContext = raw;
    _context = AskHawContext(
      nowUtc: now.toUtc(),
      timezone: zone,
      dateMode: dateMode,
      selectedEventId: selectedEventId,
      selectedFlowId: selectedFlowId,
      accountId: _account.userId,
      events: events,
      activities: activities,
      windows: windows,
      coverageComplete: (raw['coverage'] as Map?)?['complete'] == true,
      coverageStartUtc: from,
      coverageEndUtc: until,
      coverageRevision: jsonEncode([
        for (final e in events)
          [
            e.id,
            e.eventRevision,
            e.startUtc.toIso8601String(),
            e.endUtc.toIso8601String(),
          ],
        for (final f in _flows) [f['id'], f['assistance_revision']],
      ]),
    );
  }

  void showHelp() {
    response = const AskHawEngine().respond(
      const AskHawRequest(intent: AskHawIntent.clarify, raw: 'help'),
    );
    notifyListeners();
  }

  void _appendCorrection() {
    final current = response;
    if (current == null ||
        current.kind == AskHawResponseKind.success ||
        _account.userId == null) {
      return;
    }
    response = AskHawResponse(
      title: current.title,
      body: current.body,
      kind: current.kind,
      options: [
        for (final option in current.options)
          option.id.startsWith('open:')
              ? AskHawOption(
                  id: option.id,
                  label: option.label,
                  detail: option.detail,
                  reason: option.reason,
                  secondary: option.secondary,
                  menuOptions: [
                    if (const {
                      AskHawIntent.find,
                      AskHawIntent.explain,
                      AskHawIntent.fit,
                    }.contains(_request?.intent))
                      AskHawOption(
                        id: 'remember:${option.id.substring(5)}',
                        label: 'Remember this meaning',
                      ),
                    if (_catalog.byId(option.id.substring(5)) != null)
                      AskHawOption(
                        id: 'morelike:${option.id.substring(5)}',
                        label: 'Show me more like this',
                      ),
                    AskHawOption(
                      id: 'hide:${option.id.substring(5)}',
                      label: 'Hide suggestion',
                    ),
                  ],
                )
              : option,
        if (_request?.learned == true)
          const AskHawOption(
            id: 'correct',
            label: 'I meant something else',
            secondary: true,
          ),
      ],
    );
  }

  Future<void> choose(String id) async {
    if (busy || !_current) return;
    final generation = _generation;
    if (id == 'help') {
      showHelp();
      return;
    }
    if (id == 'retry') {
      await ask(_raw);
      return;
    }
    if (id == 'event:add') {
      await addEvent();
      return;
    }
    if (id == 'calendar:open') {
      await navigate('/');
      return;
    }
    if (id == 'memory:settings') {
      await navigate('/settings');
      return;
    }
    if (id == 'search:more') {
      _limit += 2;
      await ask(_raw);
      return;
    }
    if (id == 'binding:search') {
      final text = 'Find ${_request?.query ?? _raw}';
      setInput(text);
      await ask(text, ignoreBinding: true);
      return;
    }
    if (id.startsWith('input:')) {
      final text = id.substring(6);
      setInput(text);
      await ask(text);
      return;
    }
    if (id == 'correct') {
      response = const AskHawResponse(
        title: 'What did you mean?',
        kind: AskHawResponseKind.choices,
        options: [
          AskHawOption(id: 'correction:find', label: 'Find a Flow or reading'),
          AskHawOption(id: 'correction:event', label: 'Add an event'),
          AskHawOption(
            id: 'memory:settings',
            label: 'Edit remembered phrases',
            secondary: true,
          ),
        ],
      );
      notifyListeners();
      return;
    }
    if (id.startsWith('correction:')) {
      final intent = id.endsWith('event')
          ? AskHawIntent.event
          : AskHawIntent.find;
      final readingGoal = _request?.query == 'reading goal';
      if (_account.userId != null)
        await _rememberBinding(
          intent: intent.name,
          query: readingGoal ? 'reading' : _raw,
        );
      if (!_valid(generation)) return;
      if (intent == AskHawIntent.event) {
        await addEvent();
        return;
      }
      final text = readingGoal ? 'Find reading flows' : 'Find $_raw';
      setInput(text);
      await ask(text);
      return;
    }
    if (id.startsWith('open:')) {
      await _openContent(id.substring(5));
      return;
    }
    if (id.startsWith('target:event:')) {
      final eventId = id.substring('target:event:'.length);
      final event = _context?.events.where((e) => e.id == eventId).firstOrNull;
      if (event == null) return;
      if (_request != null &&
          const {
            AskHawIntent.move,
            AskHawIntent.shorten,
            AskHawIntent.skip,
          }.contains(_request!.intent)) {
        selectedEventId = event.id;
        _request = AskHawRequest(
          intent: _request!.intent,
          raw: _raw,
          targetText: 'this',
          temporalText: _request!.temporalText,
          minutes: _request!.minutes,
        );
        await _prepareAction(_request!.intent.name, event.id);
        return;
      }
      if (event.flowId != null) {
        await navigate(
          '/flows?flow=${event.flowId}&event=${Uri.encodeComponent(event.id)}',
        );
      } else {
        if (openEvent != null) {
          await openEvent!(event);
        } else {
          await navigate('/');
        }
      }
      return;
    }
    if (id.startsWith('action:')) {
      final parts = id.split(':');
      await _prepareAction(parts[1], parts.sublist(2).join(':'));
      return;
    }
    if (id.startsWith('proposal:')) {
      await _preparePlan(id.substring(9));
      return;
    }
    if (id == 'plan:all') {
      await _preparePlan(null);
      return;
    }
    if (id == 'apply') {
      await _apply();
      return;
    }
    if (id == 'recover:saved') {
      if (_savedActions.isEmpty) return;
      if (_context == null && _request != null) {
        busy = true;
        notifyListeners();
        try {
          await _loadContext(_request!, generation: generation);
        } catch (_) {
          if (_valid(generation)) {
            response = const AskHawResponse(
              title: 'The earlier request is still kept',
              body:
                  'I couldn’t load its calendar context. Try again when your calendar is available.',
              options: [AskHawOption(id: 'recover:saved', label: 'Try again')],
            );
          }
          return;
        } finally {
          if (_valid(generation)) {
            busy = false;
            notifyListeners();
          }
        }
      }
      if (!_valid(generation)) return;
      final saved = _savedActions.first;
      final actions = (saved['p_actions'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      _pending = _AskHawPending(
        id: saved['p_mutation'] as String,
        actions: actions,
        title: 'Confirm this earlier request?',
        body: actions
            .map((action) {
              final event = (action['event'] ?? action['patch']) as Map?;
              if (event != null) {
                final start = DateTime.tryParse(
                  event['starts_at']?.toString() ?? '',
                );
                final end = DateTime.tryParse(
                  event['ends_at']?.toString() ?? '',
                );
                final current = _context?.events
                    .where((e) => e.id == action['id'])
                    .firstOrNull;
                final title =
                    event['title'] ?? current?.title ?? 'your earlier event';
                final from = start ?? current?.startUtc;
                return '${action['kind'] == 'event_create' ? 'Add' : 'Update'} $title${from != null && end != null
                    ? '\n${_when(from, end)}'
                    : end != null
                    ? '\nRequested end: ${_when(end, end)}'
                    : ''}';
              }
              final flow = _flows
                  .where((f) => f['id'] == action['id'])
                  .firstOrNull;
              return '${action['kind'] == 'flow_pause' ? 'Pause' : 'Resume'} ${flow?['name'] ?? 'Flow ${action['id']}'}';
            })
            .join('\n\n'),
      )..submitted = true;
      _showPending();
      return;
    }
    if (id == 'cancel') {
      _pending = null;
      await ask(_raw);
      return;
    }
    if (id == 'availability') {
      response = const AskHawResponse(
        title: 'When may I suggest activities?',
        body:
            'This saves an availability window for planning. It does not change any event.',
        options: [
          AskHawOption(id: 'availability:9:17', label: '9 a.m.–5 p.m.'),
          AskHawOption(id: 'availability:18:21', label: '6–9 p.m.'),
          AskHawOption(id: 'availability:7:9', label: '7–9 a.m.'),
        ],
      );
      notifyListeners();
      return;
    }
    if (id.startsWith('availability:')) {
      final parts = id.split(':');
      final saved = await _saveMemory({
        'preferences': {
          'availableStartHour': int.parse(parts[1]),
          'availableEndHour': int.parse(parts[2]),
        },
      });
      if (_valid(generation) && saved) await ask(_raw);
      return;
    }
    if (id.startsWith('remember:')) {
      await _rememberBinding(
        intent: _request?.intent.name ?? 'find',
        query: _request?.query ?? '',
        contentId: id.substring(9),
      );
      return;
    }
    if (id.startsWith('hide:')) {
      await _saveMemory({
        'hidden': {..._memory.hiddenSuggestions, id.substring(5)}.toList(),
      });
      return;
    }
    if (id.startsWith('morelike:')) {
      final content = _catalog.byId(id.substring(9));
      if (content == null) return;
      final interests = {
        ...(_memory.preferences['interests'] as List? ?? [])
            .whereType<String>(),
        ...content.topics,
      };
      await _saveMemory({
        'preferences': {'interests': interests.take(30).toList()},
      });
      return;
    }
    if (id == 'default:time') {
      if (_lastMovedStart != null && _context != null) {
        final local = tz.TZDateTime.from(
          _lastMovedStart!,
          tz.getLocation(_context!.timezone),
        );
        await _saveMemory({
          'preferences': {
            'preferredHour': local.hour,
            'preferredMinute': local.minute,
          },
        });
      }
      return;
    }
    if (id.startsWith('duration:')) {
      final parts = id.split(':');
      if (parts.length != 4) return;
      final flowId = int.tryParse(parts[1]);
      final content = _catalog.byId('flow:$flowId');
      final step = content?.contract?.step(Uri.decodeComponent(parts[2]));
      final alternative = step?.alternatives
          .where((a) => a.id == Uri.decodeComponent(parts[3]))
          .firstOrNull;
      if (content == null ||
          !content.editable ||
          !content.active ||
          content.contract?.permits(AskHawAdaptation.shorten) != true ||
          step?.minutes == null ||
          alternative == null ||
          alternative.minutes >= step!.minutes!) {
        return;
      }
      await _saveMemory(
        {
          'preferences': {
            'flowDurationMinutes': {'$flowId': alternative.minutes},
            'flowDurationTitles': {'$flowId': content.title},
          },
        },
        savedBody:
            'Ask ḥꜣw will prefer this Flow’s approved ${alternative.minutes}-minute version when you ask for a future plan. Existing sessions have not changed.',
      );
      return;
    }
    if (id == 'shorter:more') {
      _limit += 2;
      _showDurationChoices();
      notifyListeners();
      return;
    }
  }

  void _showDurationChoices() {
    final choices = <AskHawOption>[];
    for (final flow in _flows.where(
      (f) =>
          f['active'] == true &&
          f['can_edit'] == true &&
          (selectedFlowId == null || f['id'] == selectedFlowId),
    )) {
      final contract = AskHawFlowContract.tryFromJson(flow['assistance']);
      if (contract?.permits(AskHawAdaptation.shorten) != true) continue;
      for (final step in contract!.steps) {
        for (final alternative in step.alternatives.where(
          (a) => step.minutes != null && a.minutes < step.minutes!,
        )) {
          choices.add(
            AskHawOption(
              id: 'duration:${flow['id']}:${Uri.encodeComponent(step.id)}:${Uri.encodeComponent(alternative.id)}',
              label: '${flow['name']} · ${alternative.minutes} minutes',
              detail: '${step.title}: ${alternative.guidance}',
              reason: alternative.countsAsCompletion
                  ? 'Approved shorter version.'
                  : 'A shorter practice; it does not complete the full step.',
            ),
          );
        }
      }
    }
    response = AskHawResponse(
      title: choices.isEmpty
          ? 'No approved shorter version is available'
          : 'Which shorter practice would you prefer?',
      body: choices.isEmpty
          ? 'Your active Flows keep their authored sessions. You can add approved alternatives in Flow Studio.'
          : 'Choose an authored alternative for future Ask ḥꜣw plans. Existing calendar sessions stay as they are.',
      options: [
        ...choices.take(_limit),
        if (choices.length > _limit)
          const AskHawOption(
            id: 'shorter:more',
            label: 'See more',
            secondary: true,
          ),
      ],
      kind: AskHawResponseKind.choices,
    );
  }

  Future<void> _openContent(String id) async {
    final content = _catalog.byId(id);
    if (_account.userId != null && content != null) {
      final previous = _memory.signals[id] as Map? ?? {};
      final signals = <String, dynamic>{
        ..._memory.signals,
        id: {
          'selectedCount':
              (((previous['selectedCount'] as num?)?.toInt() ?? 0) + 1).clamp(
                1,
                50,
              ),
          'title': content.title,
          'lastSelectedAt': _clock().toUtc().toIso8601String(),
        },
      };
      final oldest = signals.keys.where((key) => key != id).toList()
        ..sort(
          (a, b) => ((signals[a] as Map?)?['lastSelectedAt']?.toString() ?? '')
              .compareTo(
                (signals[b] as Map?)?['lastSelectedAt']?.toString() ?? '',
              ),
        );
      // Ranking history is disposable. Confirmed phrases and preferences never
      // participate in this bounded eviction.
      for (final key in oldest.take(
        (signals.length - 100).clamp(0, oldest.length),
      )) {
        signals[key] = null;
      }
      // A chosen result is a meaningful ranking signal, never a command binding.
      unawaited(_saveMemory({'signals': signals}, showResult: false));
    }
    if (id.startsWith('library:')) {
      await navigate('/nodes/${Uri.encodeComponent(id.substring(8))}');
    } else if (id.startsWith('maat:'))
      await navigate(
        '/flows?mode=maatTemplate&templateKey=${Uri.encodeComponent(id.substring(5))}',
      );
    else if (id.startsWith('flow:'))
      await navigate('/flows?flow=${Uri.encodeComponent(id.substring(5))}');
    else if (id.startsWith('post:'))
      await navigate('/flow-post/${Uri.encodeComponent(id.substring(5))}');
  }

  Future<void> _rememberBinding({
    required String intent,
    required String query,
    String? contentId,
  }) async {
    final title = contentId == null
        ? null
        : response?.options
              .where((o) => o.id == 'open:$contentId')
              .firstOrNull
              ?.label;
    await _saveMemory({
      'bindings': {
        normalizeAskHaw(_raw): {
          'intent': intent,
          'query': query,
          'contentId': contentId,
          'title': title,
          'minutes': null,
        },
      },
    });
  }

  Future<bool> _saveMemory(
    Map<String, dynamic> patch, {
    bool showResult = true,
    String? savedBody,
  }) async {
    final generation = _generation;
    if (showResult && _current) {
      busy = true;
      notifyListeners();
    }
    try {
      final value = await _memoryRepo.update(patch);
      if (!_current) return false;
      _memory = value;
      if (showResult && _valid(generation)) {
        response = AskHawResponse(
          title: 'Remembered for next time',
          body: savedBody ?? 'You can inspect or change this in Settings.',
          kind: AskHawResponseKind.success,
        );
      }
      if (_valid(generation) && showResult) {
        busy = false;
        notifyListeners();
      }
      return true;
    } catch (_) {
      if (_valid(generation) && showResult) {
        response = const AskHawResponse(
          title: 'This preference is waiting for confirmation',
          body:
              'Your requested change is kept. Open remembered details in Settings to review or retry it.',
          kind: AskHawResponseKind.unavailable,
          options: [
            AskHawOption(
              id: 'memory:settings',
              label: 'Open remembered details',
            ),
          ],
        );
      }
    }
    if (_valid(generation) && showResult) {
      busy = false;
      notifyListeners();
    }
    return false;
  }

  String _when(DateTime start, DateTime end) {
    final location = tz.getLocation(_context?.timezone ?? 'UTC');
    final local = tz.TZDateTime.from(start, location),
        finish = tz.TZDateTime.from(end, location);
    final gregorian = DateFormat('EEE, MMM d').format(local);
    final date = dateMode == 'gregorian'
        ? gregorian
        : '${formatKemeticDate(DateTime(local.year, local.month, local.day), includeGregorianYear: false)} · $gregorian';
    return '$date · ${DateFormat.jm().format(local)}–${DateFormat.jm().format(finish)}';
  }

  Future<void> _prepareAction(String intent, String target) async {
    final context = _context;
    if (context == null || _request == null) return;
    if (intent == 'pause' || intent == 'resume') {
      final flow = _flows
          .where((f) => '${f['id']}' == target && f['can_edit'] == true)
          .firstOrNull;
      if (flow == null ||
          flow['active'] != true ||
          (intent == 'pause' && flow['paused_at'] != null) ||
          (intent == 'resume' && flow['paused_at'] == null)) {
        return;
      }
      _pending = _AskHawPending(
        actions: [
          {
            'kind': 'flow_$intent',
            'id': flow['id'],
            'expected_revision': flow['assistance_revision'],
          },
        ],
        title: '${intent == 'pause' ? 'Pause' : 'Resume'} ${flow['name']}?',
        body: intent == 'pause'
            ? 'Upcoming occurrences and reminders pause. Your history stays with this Flow.'
            : 'Resume future occurrences. Missed dates stay paused; no catch-up sessions are added.',
      );
      _showPending();
      return;
    }
    final event = context.events.where((e) => e.id == target).firstOrNull;
    if (event == null || !event.editable || event.eventRevision == null) return;
    final requestedIntent = AskHawIntent.values
        .where((value) => value.name == intent)
        .firstOrNull;
    if (requestedIntent == null ||
        !askHawCanAdaptEvent(event, requestedIntent, _catalog)) {
      return;
    }
    if ((intent == 'move' || intent == 'shorten') && !event.durationKnown) {
      response = const AskHawResponse(
        title: 'Confirm this event’s end time first',
        body:
            'Open its existing editor to confirm the duration before I move or shorten it. Your event has not changed.',
        kind: AskHawResponseKind.unavailable,
      );
      notifyListeners();
      return;
    }
    final patch = <String, dynamic>{};
    DateTime? newStart;
    String body;
    if (intent == 'skip') {
      response = const AskHawResponse(
        title: 'Record an explicit skip',
        body:
            'Use the occurrence’s existing completion control. Skipping does not delete the event or assume a failure.',
        options: [AskHawOption(id: 'skip:open', label: 'Open occurrence')],
      );
      if (event.flowId != null) {
        await navigate(
          '/flows?flow=${event.flowId}&event=${Uri.encodeComponent(event.id)}',
        );
      } else if (openEvent != null) {
        await openEvent!(event);
      }
      return;
    } else if (intent == 'move') {
      final parsed = parseTime(_request!.temporalText ?? '');
      if (parsed == null) {
        response = const AskHawResponse(
          title: 'Choose a date or time',
          body: 'Try “move this to Friday at 3pm”.',
        );
        notifyListeners();
        return;
      }
      final location = tz.getLocation(context.timezone);
      final original = tz.TZDateTime.from(event.startUtc, location);
      final start = tz.TZDateTime(
        location,
        parsed.day.year,
        parsed.day.month,
        parsed.day.day,
        parsed.hour ?? original.hour,
        parsed.minute ?? original.minute,
      ).toUtc();
      final end = start.add(event.endUtc.difference(event.startUtc));
      if (!context.coverageComplete ||
          context.coverageStartUtc == null ||
          context.coverageEndUtc == null ||
          start.isBefore(context.coverageStartUtc!) ||
          end.isAfter(context.coverageEndUtc!)) {
        response = const AskHawResponse(
          title: 'That date needs a current calendar read',
          body:
              'Choose a date within the next 30 days, or use the event’s existing editor for a later date. Your event has not changed.',
        );
        notifyListeners();
        return;
      }
      if (context.events.any(
        (other) =>
            other.id != event.id &&
            other.startUtc.isBefore(end) &&
            (!other.durationKnown || other.endUtc.isAfter(start)),
      )) {
        response = const AskHawResponse(
          title: 'That time overlaps another commitment',
          body: 'Choose another time. Your existing event has not changed.',
        );
        notifyListeners();
        return;
      }
      patch.addAll({
        'starts_at': start.toIso8601String(),
        'ends_at': end.toIso8601String(),
      });
      newStart = start;
      body = _when(start, end);
    } else {
      final minutes = _request!.minutes;
      final contract = event.flowId == null
          ? null
          : _catalog.byId('flow:${event.flowId}')?.contract;
      final step = event.stepId == null && contract?.steps.length == 1
          ? contract!.steps.single
          : contract?.step(event.stepId ?? '');
      final alternatives = step?.alternatives ?? <AskHawAlternative>[];
      final alternative = alternatives
          .where((a) => a.minutes == minutes)
          .firstOrNull;
      if (minutes == null ||
          minutes <= 0 ||
          minutes >= event.endUtc.difference(event.startUtc).inMinutes ||
          (event.flowId != null && alternative == null)) {
        response = const AskHawResponse(
          title: 'No approved shorter version fits that request',
          body:
              'Choose another duration or open the Flow’s supported controls.',
        );
        notifyListeners();
        return;
      }
      final end = event.startUtc.add(Duration(minutes: minutes));
      patch['ends_at'] = end.toIso8601String();
      if (alternative != null) {
        final source = (_rawContext?['events'] as List? ?? [])
            .whereType<Map>()
            .where((e) => e['id'] == event.id)
            .firstOrNull;
        final original = source?['detail'] as String?;
        if (rewriteDetail != null) {
          patch['detail'] = rewriteDetail!(original, alternative.guidance);
        }
        final behavior = source?['behavior_payload'] is Map
            ? Map<String, dynamic>.from(source!['behavior_payload'] as Map)
            : <String, dynamic>{};
        patch['behavior_payload'] = {
          ...behavior,
          'ask_haw': {
            'step_id': step!.id,
            'alternative_id': alternative.id,
            'contract_version': 1,
            'counts_as_completion': alternative.countsAsCompletion,
          },
        };
      }
      body =
          '${_when(event.startUtc, end)}${alternative == null ? '' : '\n${alternative.guidance}'}';
    }
    _pending = _AskHawPending(
      actions: [
        {
          'kind': 'event_patch',
          'id': event.id,
          'expected_revision': int.parse(event.eventRevision!),
          if (event.flowId != null)
            'expected_flow_revision': _flows
                .where((flow) => flow['id'] == event.flowId)
                .firstOrNull?['assistance_revision'],
          'avoid_conflicts': true,
          'lane': externalCalendarBuildLane,
          'patch': patch,
        },
      ],
      title: '${intent == 'move' ? 'Move' : 'Shorten'} ${event.title}?',
      body: '$body\nOnly this occurrence changes.',
      newStart: newStart,
      flowId: event.flowId,
    );
    _showPending();
  }

  Future<void> _preparePlan(String? activityId) async {
    final context = _context, plan = _plan;
    if (context == null || plan == null) return;
    final selected = plan.allocations
        .where((a) => activityId == null || a.activityId == activityId)
        .toList();
    if (selected.isEmpty) return;
    final actions = <Map<String, dynamic>>[];
    for (final item in selected) {
      final flow = _flows
          .where((f) => f['id'] == item.flowId && f['can_edit'] == true)
          .firstOrNull;
      if (flow == null || flow['paused_at'] != null) return;
      actions.add({
        'kind': 'event_create',
        'client_event_id':
            'ask_haw:${_account.userId}:${item.flowId}:${item.stepId}:${item.startUtc.toIso8601String()}',
        'calendar_id':
            flow['calendar_id'] ?? _rawContext?['personal_calendar_id'],
        'expected_flow_revision': int.tryParse(item.sourceRevision),
        'avoid_conflicts': true,
        'lane': externalCalendarBuildLane,
        'event': {
          'title': item.title,
          'starts_at': item.startUtc.toIso8601String(),
          'ends_at': item.endUtc.toIso8601String(),
          'all_day': false,
          'flow_local_id': item.flowId,
          'detail': item.guidance,
          'behavior_payload': {
            'ask_haw': {
              'step_id': item.stepId,
              'alternative_id': item.alternativeId,
              'contract_version': 1,
              'counts_as_completion':
                  item.alternativeId == null || item.countsAsCompletion,
            },
          },
        },
      });
    }
    _pending = _AskHawPending(
      actions: actions,
      title: 'Add this practice?',
      body: selected
          .map(
            (a) => '${a.title}\n${_when(a.startUtc, a.endUtc)}\n${a.guidance}',
          )
          .join('\n\n'),
      plan: plan,
    );
    _showPending();
  }

  void _showPending() {
    final pending = _pending;
    if (pending == null) return;
    response = AskHawResponse(
      title: pending.title,
      body: pending.body,
      kind: AskHawResponseKind.proposal,
      options: [
        AskHawOption(id: 'apply', label: pending.submitted ? 'Retry confirmation' : 'Apply change'),
        AskHawOption(
          id: 'cancel',
          label: pending.submitted ? 'Leave this for later' : 'Keep my current calendar',
          secondary: true,
        ),
      ],
    );
    notifyListeners();
  }

  Future<void> _apply() async {
    final pending = _pending;
    if (pending == null || _request == null) return;
    final generation = _generation;
    busy = true;
    notifyListeners();
    try {
      if (pending.plan != null && !pending.submitted) {
        await _loadContext(_request!, generation: generation);
        if (!_valid(generation) ||
            _context == null ||
            !pending.plan!.isCurrent(_context!)) {
          throw StateError('The plan changed.');
        }
      }
      if (!_valid(generation)) return;
      // Once submitted, an interrupted acknowledgement must replay these exact
      // bytes. Re-planning first would hide an already committed receipt.
      pending.submitted = true;
      final receipt = await _execute(pending.id, pending.actions);
      if (!_current) return;
      if (receipt['status'] != 'applied' ||
          receipt['mutation_id'] != pending.id) {
        throw AskHawActionConflict(receipt);
      }
      CalendarInvalidationBus.instance.publish(
        CalendarInvalidated(
          reason: CalendarInvalidationReason.eventSaved,
          flowId: pending.flowId,
        ),
      );
      unawaited(_syncReminders().catchError((Object _) {}));
      if (!_valid(generation)) return;
      _pending = null;
      _savedActions.removeWhere((action) => action['p_mutation'] == pending.id);
      _lastMovedStart = pending.newStart;
      response = AskHawResponse(
        title: 'Your change is saved',
        body: pending.body,
        kind: AskHawResponseKind.success,
        options: [
          if (pending.newStart != null)
            const AskHawOption(
              id: 'default:time',
              label: 'Use this time by default',
              secondary: true,
            ),
        ],
      );
    } catch (_) {
      if (_valid(generation)) {
        response = const AskHawResponse(
          title: 'This change is not confirmed',
          body:
              'Your request is kept. Retry checks the same request; a changed calendar requires a new proposal.',
          kind: AskHawResponseKind.unavailable,
          options: [
            AskHawOption(id: 'apply', label: 'Retry confirmation'),
            AskHawOption(
              id: 'retry',
              label: 'Review current calendar',
              secondary: true,
            ),
          ],
        );
      }
    } finally {
      if (_valid(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_auth.cancel());
    _account.dispose();
    _memoryRepo.dispose();
    super.dispose();
  }
}

class _AskHawPending {
  _AskHawPending({
    String? id,
    required this.actions,
    required this.title,
    required this.body,
    this.newStart,
    this.flowId,
    this.plan,
  }) : id = id ?? const Uuid().v4();
  bool submitted = false;
  final String id, title, body;
  final List<Map<String, dynamic>> actions;
  final DateTime? newStart;
  final int? flowId;
  final AskHawPlan? plan;
}
