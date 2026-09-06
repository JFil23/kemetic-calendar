part of 'calendar_page.dart';

typedef FlowJoinUpsertFlow =
    Future<int> Function({
      int? id,
      required String name,
      required int color,
      required bool active,
      String? calendarId,
      DateTime? startDate,
      DateTime? endDate,
      String? notes,
      required String rules,
      String? originType,
    });

typedef FlowJoinUpsertEvent =
    Future<void> Function({
      required String clientEventId,
      required String title,
      required DateTime startsAtUtc,
      String? detail,
      bool allDay,
      DateTime? endsAtUtc,
      int? flowLocalId,
      String? category,
      String? actionId,
      Map<String, dynamic>? behaviorPayload,
      String? calendarId,
      String? caller,
    });

typedef FlowJoinFileHeadlessEventDelivery =
    Future<void> Function({
      required EventFilingService eventFiling,
      required String debugLabel,
      required String clientEventId,
      required DateTime startsAtLocal,
      required int? alertOffsetMinutes,
      required String title,
      String? body,
    });

typedef FlowJoinPublishHeadlessCalendarInvalidation =
    void Function({
      required CalendarInvalidationReason reason,
      required int flowId,
      required List<String> clientEventIds,
    });

typedef FlowJoinPersistEveningThresholdInitialCarry =
    Future<void> Function({
      required DateTime localDate,
      required String carryText,
    });

typedef MoonReturnWindowResolver =
    MoonReturnEnrollmentWindow? Function({
      required TrackSkyTimeZone timezone,
      DateTime? startDate,
    });

typedef MoonReturnOccurrenceResolver =
    List<MoonReturnOccurrence> Function({
      required MoonReturnEnrollmentWindow window,
    });

typedef MoonReturnNowProvider = DateTime Function(TrackSkyTimeZone timezone);

typedef DecanWatchWindowResolver =
    DecanWatchEnrollmentWindow? Function({
      required TrackSkyTimeZone timezone,
      DateTime? startDate,
    });

typedef DecanWatchOccurrenceResolver =
    List<DecanWatchOccurrence> Function({
      required DecanWatchEnrollmentWindow window,
      required TrackSkyTimeZone timezone,
    });

typedef DecanWatchNowProvider = DateTime Function(TrackSkyTimeZone timezone);

typedef OpenHandWindowResolver =
    OpenHandEnrollmentWindow? Function({
      required TrackSkyTimeZone timezone,
      DateTime? startDate,
    });

typedef OpenHandScheduleResolver =
    OpenHandOccurrenceSchedule Function({
      required OpenHandEvent event,
      required DateTime flowStart,
      required TrackSkyTimeZone timezone,
    });

typedef OpenHandNowProvider = DateTime Function(TrackSkyTimeZone timezone);

typedef DjedWindowResolver =
    DjedEnrollmentWindow? Function({
      required TrackSkyTimeZone timezone,
      DateTime? startDate,
    });

typedef DjedScheduleResolver =
    DjedOccurrenceSchedule Function({
      required DjedV2Event event,
      required DateTime flowStart,
      required TrackSkyTimeZone timezone,
    });

typedef DjedNowProvider = DateTime Function(TrackSkyTimeZone timezone);

typedef OfferingTableStartDateResolver =
    DateTime Function(TrackSkyTimeZone timezone);

typedef OfferingTableScheduleResolver =
    OfferingTableOccurrenceSchedule Function(
      OfferingTableDay day,
      DateTime date,
      TrackSkyTimeZone timezone,
    );

typedef CourseStartDateResolver = DateTime Function(TrackSkyTimeZone timezone);

typedef CourseScheduleResolver =
    CourseOccurrenceSchedule Function(
      CourseEvent event,
      DateTime date,
      TrackSkyTimeZone timezone,
    );

enum FlowJoinFailureCode { noEnrollmentWindow, noOccurrences, notJoinable }

class FlowJoinResult {
  const FlowJoinResult._({
    required this.succeeded,
    required this.flowId,
    required this.clientEventIds,
    _Flow? localFlow,
    List<_PlannedNote> plannedNotes = const <_PlannedNote>[],
    this.persistInBackground,
    this.failureCode,
  }) : _localFlow = localFlow,
       _plannedNotes = plannedNotes;

  const FlowJoinResult.success({
    required int flowId,
    required List<String> clientEventIds,
    Future<void> Function()? persistInBackground,
  }) : this._(
         succeeded: true,
         flowId: flowId,
         clientEventIds: clientEventIds,
         persistInBackground: persistInBackground,
       );

  const FlowJoinResult._fastPathSuccess({
    required int flowId,
    required List<String> clientEventIds,
    required _Flow localFlow,
    required List<_PlannedNote> plannedNotes,
    required Future<void> Function() persistInBackground,
  }) : this._(
         succeeded: true,
         flowId: flowId,
         clientEventIds: clientEventIds,
         localFlow: localFlow,
         plannedNotes: plannedNotes,
         persistInBackground: persistInBackground,
       );

  const FlowJoinResult.failure(FlowJoinFailureCode failureCode)
    : this._(
        succeeded: false,
        flowId: null,
        clientEventIds: const <String>[],
        failureCode: failureCode,
      );

  final bool succeeded;
  final int? flowId;
  final List<String> clientEventIds;
  final _Flow? _localFlow;
  final List<_PlannedNote> _plannedNotes;
  final Future<void> Function()? persistInBackground;
  final FlowJoinFailureCode? failureCode;

  bool get hasLocalFastPath => _localFlow != null;
  int get plannedNoteCount => _plannedNotes.length;

  int get flowIdOrZero => succeeded ? flowId! : 0;
  int get flowIdOrNegativeOne => succeeded ? flowId! : -1;
}

class PlannedNoteWrite {
  PlannedNoteWrite({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.startsAtLocal,
    required this.endsAtLocal,
    required this.detail,
    required this.noteDetail,
    required this.location,
    required this.allDay,
    required this.calendarId,
    required this.calendarName,
    required this.flowId,
    required this.manualColor,
    required this.category,
    required this.isReminder,
    required this.reminderId,
    required this.actionId,
    required this.behaviorPayload,
    required this.caller,
    this.alertBody,
    this.alertDebugLabel,
    this.alertOffsetMinutes = kEventFilingNoAlertMinutes,
  });

  final String clientEventId;
  final String title;
  final DateTime startsAtUtc;
  final DateTime? endsAtUtc;
  final DateTime startsAtLocal;
  final DateTime? endsAtLocal;

  /// Detail encoded for persistence.
  final String? detail;

  /// User-facing detail kept in the staged local note.
  final String? noteDetail;
  final String? location;
  final bool allDay;
  final String? calendarId;
  final String? calendarName;
  final int flowId;
  final Color? manualColor;
  final String? category;
  final bool isReminder;
  final String? reminderId;
  final String? actionId;
  final Map<String, dynamic>? behaviorPayload;
  final String? caller;
  final String? alertBody;
  String? alertDebugLabel;
  int? alertOffsetMinutes;

  _PlannedNote get _plannedNote {
    final day = KemeticMath.fromGregorian(DateUtils.dateOnly(startsAtLocal));
    return _PlannedNote(
      ky: day.kYear,
      km: day.kMonth,
      kd: day.kDay,
      note: _Note(
        clientEventId: clientEventId,
        calendarId: calendarId,
        calendarName: calendarName,
        title: title,
        detail: noteDetail,
        location: location,
        allDay: allDay,
        start: allDay
            ? null
            : TimeOfDay(hour: startsAtLocal.hour, minute: startsAtLocal.minute),
        end: allDay || endsAtLocal == null
            ? null
            : TimeOfDay(hour: endsAtLocal!.hour, minute: endsAtLocal!.minute),
        flowId: flowId,
        manualColor: manualColor,
        category: category,
        isReminder: isReminder,
        reminderId: reminderId,
        alertOffsetMinutes: alertOffsetMinutes,
        actionId: actionId,
        behaviorPayload: behaviorPayload,
      ),
    );
  }
}

class _DeferredJoinContext {
  _DeferredJoinContext({required this.localFlow});

  final _Flow localFlow;
  final List<PlannedNoteWrite> writes = <PlannedNoteWrite>[];
}

class FlowJoinService {
  FlowJoinService({
    UserEventsRepo? userEventsRepo,
    EventFilingService? eventFiling,
    FlowJoinUpsertFlow? upsertFlow,
    FlowJoinUpsertEvent? upsertEvent,
    FlowJoinFileHeadlessEventDelivery? fileHeadlessEventDelivery,
    FlowJoinPublishHeadlessCalendarInvalidation?
    publishHeadlessCalendarInvalidation,
    FlowJoinPersistEveningThresholdInitialCarry?
    persistEveningThresholdInitialCarry,
    MoonReturnWindowResolver? resolveMoonReturnWindow,
    MoonReturnOccurrenceResolver? moonReturnOccurrencesForWindow,
    MoonReturnNowProvider? moonReturnNowInZone,
    DecanWatchWindowResolver? resolveDecanWatchWindow,
    DecanWatchOccurrenceResolver? decanWatchOccurrencesForWindow,
    DecanWatchNowProvider? decanWatchNowInZone,
    OpenHandWindowResolver? resolveOpenHandWindow,
    OpenHandScheduleResolver? openHandScheduleForEvent,
    OpenHandNowProvider? openHandNowInZone,
    List<OpenHandEvent>? openHandEvents,
    DjedWindowResolver? resolveDjedWindow,
    DjedScheduleResolver? djedScheduleForEvent,
    DjedNowProvider? djedNowInZone,
    List<DjedV2Event>? djedEvents,
    OfferingTableStartDateResolver? resolveOfferingTableDefaultStartDate,
    OfferingTableScheduleResolver? offeringTableScheduleForDate,
    List<OfferingTableDay>? offeringTableDays,
    CourseStartDateResolver? resolveTheCourseDefaultStartDate,
    CourseScheduleResolver? courseScheduleForDate,
    List<CourseEvent>? courseEvents,
    MaatFlowClock? clock,
    MaatFlowTemporalResolver temporalResolver =
        const MaatFlowTemporalResolver(),
  }) : _userEventsRepo = userEventsRepo,
       _eventFiling = eventFiling ?? EventFilingService(),
       _upsertFlow = upsertFlow,
       _upsertEvent = upsertEvent,
       _fileHeadlessEventDelivery =
           fileHeadlessEventDelivery ?? CalendarPage._fileHeadlessEventDelivery,
       _publishHeadlessCalendarInvalidation =
           publishHeadlessCalendarInvalidation ??
           CalendarPage._publishHeadlessCalendarInvalidation,
       _clock = clock ?? maatFlowSystemClock,
       _temporalResolver = temporalResolver,
       _persistEveningThresholdInitialCarry =
           persistEveningThresholdInitialCarry ??
           _defaultPersistEveningThresholdInitialCarry,
       _resolveMoonReturnWindow =
           resolveMoonReturnWindow ?? _defaultResolveMoonReturnWindow,
       _moonReturnOccurrencesForWindow =
           moonReturnOccurrencesForWindow ??
           _defaultMoonReturnOccurrencesForWindow,
       _moonReturnNowInZone = moonReturnNowInZone,
       _resolveDecanWatchWindow =
           resolveDecanWatchWindow ?? _defaultResolveDecanWatchWindow,
       _decanWatchOccurrencesForWindow =
           decanWatchOccurrencesForWindow ??
           _defaultDecanWatchOccurrencesForWindow,
       _decanWatchNowInZone = decanWatchNowInZone,
       _resolveOpenHandWindow =
           resolveOpenHandWindow ?? _defaultResolveOpenHandWindow,
       _openHandScheduleForEvent =
           openHandScheduleForEvent ?? _defaultOpenHandScheduleForEvent,
       _openHandNowInZone = openHandNowInZone,
       _openHandEvents = openHandEvents ?? kOpenHandEvents,
       _resolveDjedWindow = resolveDjedWindow ?? _defaultResolveDjedWindow,
       _djedScheduleForEvent =
           djedScheduleForEvent ?? _defaultDjedScheduleForEvent,
       _djedNowInZone = djedNowInZone,
       _djedEvents = djedEvents ?? kDjedV2Events,
       _resolveOfferingTableDefaultStartDate =
           resolveOfferingTableDefaultStartDate,
       _offeringTableScheduleForDate =
           offeringTableScheduleForDate ?? _defaultOfferingTableScheduleForDate,
       _offeringTableDays = offeringTableDays ?? kOfferingTableDays,
       _resolveTheCourseDefaultStartDate = resolveTheCourseDefaultStartDate,
       _courseScheduleForDate =
           courseScheduleForDate ?? _defaultCourseScheduleForDate,
       _courseEvents = courseEvents ?? kTheCourseEvents;

  final UserEventsRepo? _userEventsRepo;
  final EventFilingService _eventFiling;
  final FlowJoinUpsertFlow? _upsertFlow;
  final FlowJoinUpsertEvent? _upsertEvent;
  final FlowJoinFileHeadlessEventDelivery _fileHeadlessEventDelivery;
  final FlowJoinPublishHeadlessCalendarInvalidation
  _publishHeadlessCalendarInvalidation;
  final MaatFlowClock _clock;
  final MaatFlowTemporalResolver _temporalResolver;
  final FlowJoinPersistEveningThresholdInitialCarry
  _persistEveningThresholdInitialCarry;
  final MoonReturnWindowResolver _resolveMoonReturnWindow;
  final MoonReturnOccurrenceResolver _moonReturnOccurrencesForWindow;
  final MoonReturnNowProvider? _moonReturnNowInZone;
  final DecanWatchWindowResolver _resolveDecanWatchWindow;
  final DecanWatchOccurrenceResolver _decanWatchOccurrencesForWindow;
  final DecanWatchNowProvider? _decanWatchNowInZone;
  final OpenHandWindowResolver _resolveOpenHandWindow;
  final OpenHandScheduleResolver _openHandScheduleForEvent;
  final OpenHandNowProvider? _openHandNowInZone;
  final List<OpenHandEvent> _openHandEvents;
  final DjedWindowResolver _resolveDjedWindow;
  final DjedScheduleResolver _djedScheduleForEvent;
  final DjedNowProvider? _djedNowInZone;
  final List<DjedV2Event> _djedEvents;
  final OfferingTableStartDateResolver? _resolveOfferingTableDefaultStartDate;
  final OfferingTableScheduleResolver _offeringTableScheduleForDate;
  final List<OfferingTableDay> _offeringTableDays;
  final CourseStartDateResolver? _resolveTheCourseDefaultStartDate;
  final CourseScheduleResolver _courseScheduleForDate;
  final List<CourseEvent> _courseEvents;
  _DeferredJoinContext? _deferredJoinContext;

  UserEventsRepo get _repo =>
      _userEventsRepo ?? UserEventsRepo(Supabase.instance.client);

  MaatFlowTemporalContext _captureTemporalContext(TrackSkyTimeZone timezone) {
    return MaatFlowTemporalContext.capture(
      ianaTimeZone: MaatFlowDeviceTimeZone.currentIanaTimeZone,
      clock: _clock,
    );
  }

  DateTime _resolveTemporalStart(
    MaatFlowKind kind,
    TrackSkyTimeZone timezone, {
    MaatFlowTemporalContext? context,
    int eveningThresholdMinutes = kEveningThresholdDefaultMinutesAfterMidnight,
  }) {
    return _temporalResolver
        .resolve(
          kind: kind,
          context: context ?? _captureTemporalContext(timezone),
          scheduleTimeZone: timezone,
          eveningThresholdMinutes: eveningThresholdMinutes,
        )
        .startDate;
  }

  MaatFlowKind _registeredKindForKey(String flowKey) {
    final kind = resolveMaatFlowKind(
      behaviorPayload: <String, dynamic>{'flow_key': flowKey},
    );
    if (kind == null) {
      throw StateError('Ma’at Flow $flowKey has no registered identity.');
    }
    return kind;
  }

  static Future<void> _defaultPersistEveningThresholdInitialCarry({
    required DateTime localDate,
    required String carryText,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty || carryText.trim().isEmpty) {
      return;
    }
    await DailyOrientationRepo(Supabase.instance.client).setCarry(
      userId: userId,
      localDate: localDate,
      chosenReturn: carryText,
      source: 'initial_enrollment',
    );
  }

  Future<FlowJoinResult> joinTrackSkyV2Headless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyEnrollmentDraft draft,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final occurrences = draft.occurrences;
    if (occurrences.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }
    final dates = <DateTime>{
      for (final occ in occurrences) DateUtils.dateOnly(occ.startsAtLocal),
    };
    final orderedDates = dates.toList()..sort();
    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: orderedDates.last,
      notes: draft.flowNotes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = await _stageTrackSkyOccurrences(
      occurrences: occurrences,
      flowId: flowId,
      calendarId: personalCalendarId,
      alertOffsetMinutes: alertOffsetMinutes,
      caller: 'track_sky_v2_join_headless',
      alertDebugLabel: 'trackSkyV2Headless',
    );

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  /// Repairs one concrete joined Follow Sky flow without rewriting valid
  /// children. Stable ownership is the existing [flowId] plus `skyEventId`.
  Future<FlowJoinResult> reconcileTrackSkyV2Headless({
    required int flowId,
    required String flowName,
    required Color flowColor,
    required bool active,
    required String? personalCalendarId,
    required String existingFlowNotes,
    required TrackSkyEnrollmentDraft draft,
    List<PersistedTrackSkyChild>? existingChildren,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final occurrences = draft.occurrences;
    if (occurrences.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final persistedChildren =
        existingChildren ??
        <PersistedTrackSkyChild>[
          for (final row in await _repo.getEventsForFlow(
            flowId,
            flowEventsOnly: true,
          ))
            PersistedTrackSkyChild(
              clientEventId: row.clientEventId,
              behaviorPayload: row.behaviorPayload,
            ),
        ];
    final plan = const TrackSkyOccurrenceReconciler().plan(
      expectedOccurrences: occurrences,
      existingChildren: persistedChildren,
    );

    final dates = <DateTime>{
      for (final occurrence in occurrences)
        DateUtils.dateOnly(occurrence.startsAtLocal),
    };
    final orderedDates = dates.toList()..sort();
    final savedFlowId = await _upsertFlowRow(
      id: flowId,
      name: flowName,
      color: flowColor.toARGB32(),
      active: active,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: orderedDates.last,
      notes: existingFlowNotes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );
    if (savedFlowId != flowId) {
      _deferredJoinContext = null;
      throw StateError(
        'Follow Sky reconciliation changed flow identity '
        '$flowId → $savedFlowId.',
      );
    }

    if (plan.missingOccurrences.isEmpty) {
      _deferredJoinContext = null;
      return FlowJoinResult.success(
        flowId: flowId,
        clientEventIds: const <String>[],
      );
    }

    final clientEventIds = await _stageTrackSkyOccurrences(
      occurrences: plan.missingOccurrences,
      flowId: flowId,
      calendarId: personalCalendarId,
      alertOffsetMinutes: alertOffsetMinutes,
      caller: 'track_sky_v2_reconcile_headless',
      alertDebugLabel: 'trackSkyV2ReconcileHeadless',
    );
    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<List<String>> _stageTrackSkyOccurrences({
    required Iterable<MaterializedSkyOccurrence> occurrences,
    required int flowId,
    required String? calendarId,
    required int alertOffsetMinutes,
    required String caller,
    required String alertDebugLabel,
  }) async {
    final clientEventIds = <String>[];
    for (final occurrence in occurrences) {
      final day = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startsAtLocal),
      );
      final clientEventId = EventCidUtil.buildClientEventId(
        ky: day.kYear,
        km: day.kMonth,
        kd: day.kDay,
        title: occurrence.title,
        startHour: occurrence.startsAtLocal.hour,
        startMinute: occurrence.startsAtLocal.minute,
        allDay: occurrence.allDay,
        flowId: flowId,
      );
      final detail = _encodeDetailWithMeta(
        occurrence.detail,
        alertMinutes: alertOffsetMinutes,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: occurrence.title,
        startsAtUtc: occurrence.startsAtUtc,
        startsAtLocal: occurrence.startsAtLocal,
        detail: detail,
        allDay: occurrence.allDay,
        endsAtUtc: occurrence.endsAtUtc,
        endsAtLocal: occurrence.endsAtLocal,
        calendarId: calendarId,
        flowLocalId: flowId,
        category: occurrence.category,
        behaviorPayload: occurrence.behaviorPayload,
        caller: caller,
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: alertDebugLabel,
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startsAtLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: occurrence.title,
          body: detail,
        );
      }
    }
    return List<String>.unmodifiable(clientEventIds);
  }

  Future<FlowJoinResult> joinTrackSkyHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
    TrackSkyCourse? course,
  }) async {
    // Cut 3: V2 enrollment is the only path.
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}
    final catalog = await SkyCatalogRepository().load();
    final materializer = TrackSkyMaterializer(
      toLocal: (utc, iana) {
        final location = tz.getLocation(iana);
        return tz.TZDateTime.from(utc.toUtc(), location);
      },
      toUtc: (local, iana) {
        final location = tz.getLocation(iana);
        return tz.TZDateTime(
          location,
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        ).toUtc();
      },
    );
    final enrollment = TrackSkyEnrollmentService(
      materializer: materializer,
      visibilityService: const SkyVisibilityService(),
    );
    final temporal = _temporalResolver.resolve(
      kind: MaatFlowKind.trackSky,
      context: _captureTemporalContext(timezone),
      scheduleTimeZone: timezone,
      skyCatalog: catalog,
      skyEnrollment: enrollment,
    );
    final draft = enrollment.buildJoinDraft(
      catalog: catalog,
      eligibleNights: temporal.skyNights,
      ianaTimeZone: timezone.ianaName,
      timezoneKey: timezone.key,
      overview: templateOverview,
      course: course,
    );
    return joinTrackSkyV2Headless(
      templateKey: templateKey,
      templateTitle: templateTitle,
      templateOverview: templateOverview,
      templateColor: templateColor,
      personalCalendarId: personalCalendarId,
      draft: draft,
      alertOffsetMinutes: alertOffsetMinutes,
    );
  }

  Future<FlowJoinResult> _joinSequenceHeadless({
    required _MaatFlowTemplate template,
    required String? personalCalendarId,
    required DateTime startDate,
    required bool useKemetic,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final firstGregorian = useKemetic
        ? (() {
            final kemetic = KemeticMath.fromGregorian(startDate);
            return KemeticMath.toGregorian(
              kemetic.kYear,
              kemetic.kMonth,
              kemetic.kDay,
            );
          })()
        : DateUtils.dateOnly(startDate);
    final dates = <DateTime>{
      for (var i = 0; i < template.days.length; i++)
        DateUtils.dateOnly(firstGregorian.add(Duration(days: i))),
    };
    if (dates.isEmpty || template.days.every((day) => day.notes.isEmpty)) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }
    final orderedDates = dates.toList()..sort();
    final notes = [
      useKemetic ? 'mode=kemetic' : 'mode=gregorian',
      'split=1',
      if (template.overview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(template.overview.trim())}',
      'maat=${template.key}',
    ].join(';');
    final rules = <FlowRule>[
      _RuleDates(
        dates: dates,
        allDay: false,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 10, minute: 0),
      ),
    ];
    final flowId = await _upsertFlowRow(
      id: null,
      name: template.title,
      color: template.color.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: orderedDates.last,
      notes: notes,
      rules: jsonEncode(rules.map(CalendarPageState.ruleToJson).toList()),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (var dayIndex = 0; dayIndex < template.days.length; dayIndex++) {
      final gregorian = orderedDates[dayIndex];
      final kemetic = KemeticMath.fromGregorian(gregorian);
      for (final slot in template.days[dayIndex].notes) {
        final startsAtLocal = DateTime(
          gregorian.year,
          gregorian.month,
          gregorian.day,
          slot.start.hour,
          slot.start.minute,
        );
        var endsAtLocal = DateTime(
          gregorian.year,
          gregorian.month,
          gregorian.day,
          slot.end.hour,
          slot.end.minute,
        );
        if (!endsAtLocal.isAfter(startsAtLocal)) {
          endsAtLocal = endsAtLocal.add(const Duration(days: 1));
        }
        final clientEventId = EventCidUtil.buildClientEventId(
          ky: kemetic.kYear,
          km: kemetic.kMonth,
          kd: kemetic.kDay,
          title: slot.title,
          startHour: slot.start.hour,
          startMinute: slot.start.minute,
          allDay: false,
          flowId: flowId,
        );
        await _upsertEventRow(
          clientEventId: clientEventId,
          title: slot.title,
          startsAtUtc: startsAtLocal.toUtc(),
          startsAtLocal: startsAtLocal,
          detail: slot.detail,
          allDay: false,
          endsAtUtc: endsAtLocal.toUtc(),
          endsAtLocal: endsAtLocal,
          calendarId: personalCalendarId,
          flowLocalId: flowId,
          caller: 'maat_sequence_join_headless',
        );
        clientEventIds.add(clientEventId);
        if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
          await _fileHeadlessJoinDelivery(
            debugLabel: 'maatSequenceHeadless',
            clientEventId: clientEventId,
            startsAtLocal: startsAtLocal,
            alertOffsetMinutes: alertOffsetMinutes,
            title: slot.title,
            body: slot.detail,
          );
        }
      }
    }
    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinMoonReturnHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    MoonReturnLens lens = MoonReturnLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final temporalContext = _captureTemporalContext(timezone);
    final window = _resolveMoonReturnWindow(
      timezone: timezone,
      startDate:
          startDate ??
          _resolveTemporalStart(
            MaatFlowKind.moonReturn,
            timezone,
            context: temporalContext,
          ),
    );
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final occurrences = _moonReturnOccurrencesForWindow(window: window);
    if (occurrences.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final dates = <DateTime>{
      for (final occurrence in occurrences)
        DateUtils.dateOnly(occurrence.startLocal),
    };
    final orderedDates = dates.toList()..sort();
    final nowLocal =
        _moonReturnNowInZone?.call(timezone) ??
        temporalContext.presentLocalDateTime;
    final notes = [
      'mode=astronomy',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'moon_tz=${timezone.key}',
      'moon_lens=${lens.key}',
      'moon_enrolled_at=${nowLocal.toIso8601String()}',
      'moon_window_open=${CalendarPage._formatDetachedGregorian(window.opensAtLocal)}',
      'moon_new_moon=${window.newMoonDateIso}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: DateUtils.dateOnly(window.opensAtLocal),
      endDate: orderedDates.last,
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (final occurrence in occurrences) {
      final clientEventId = moonReturnClientEventId(
        flowId: flowId,
        occurrence: occurrence,
      );
      final title = moonReturnEventTitle(occurrence);
      final detail = moonReturnDetailText(occurrence, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        startsAtLocal: occurrence.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        endsAtLocal: occurrence.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: moonReturnActionId(occurrence),
        behaviorPayload: moonReturnBehaviorPayload(
          occurrence: occurrence,
          lens: lens,
        ),
        caller: 'moon_return_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'moonReturnHeadless',
        clientEventId: clientEventId,
        startsAtLocal: occurrence.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinDecanWatchHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    DecanWatchLens lens = DecanWatchLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final temporalContext = _captureTemporalContext(timezone);
    final window = _resolveDecanWatchWindow(
      timezone: timezone,
      startDate:
          startDate ??
          _resolveTemporalStart(
            MaatFlowKind.decanWatch,
            timezone,
            context: temporalContext,
          ),
    );
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final occurrences = _decanWatchOccurrencesForWindow(
      window: window,
      timezone: timezone,
    );
    if (occurrences.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final dates = <DateTime>{
      for (final occurrence in occurrences)
        DateUtils.dateOnly(occurrence.startLocal),
    };
    if (dates.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final orderedDates = dates.toList()..sort();
    final nowLocal =
        _decanWatchNowInZone?.call(timezone) ??
        temporalContext.presentLocalDateTime;
    final notes = [
      'mode=kemetic',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'dw_tz=${timezone.key}',
      'dw_lens=${lens.key}',
      'dw_enrolled_kyear=${window.openingOccurrence.kYear}',
      'dw_hour=$kDecanWatchDefaultHour',
      'dw_minute=$kDecanWatchDefaultMinute',
      'dw_enrolled_at=${nowLocal.toIso8601String()}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: orderedDates.last,
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (final occurrence in occurrences) {
      final clientEventId = decanWatchClientEventId(
        flowId: flowId,
        occurrence: occurrence,
      );
      final title = decanWatchEventTitle(occurrence);
      final context = courseContextForKemeticDate(
        kYear: occurrence.kYear,
        kMonth: occurrence.kMonth,
        kDay: occurrence.decanStartDay,
      );
      final detail = decanWatchDetailText(
        occurrence,
        lens: lens,
        context: context,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        startsAtLocal: occurrence.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        endsAtLocal: occurrence.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: decanWatchActionId(occurrence),
        behaviorPayload: decanWatchBehaviorPayload(
          occurrence: occurrence,
          lens: lens,
        ),
        caller: 'decan_watch_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'decanWatchHeadless',
        clientEventId: clientEventId,
        startsAtLocal: occurrence.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinOpenHandHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    OpenHandLens lens = OpenHandLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final temporalContext = _captureTemporalContext(timezone);
    final window = _resolveOpenHandWindow(
      timezone: timezone,
      startDate:
          startDate ??
          _resolveTemporalStart(
            MaatFlowKind.theOpenHand,
            timezone,
            context: temporalContext,
          ),
    );
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final events = _openHandEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final flowStart = DateUtils.dateOnly(window.opensAtLocal);
    final schedules = <OpenHandEvent, OpenHandOccurrenceSchedule>{
      for (final event in events)
        event: _openHandScheduleForEvent(
          event: event,
          flowStart: flowStart,
          timezone: timezone,
        ),
    };
    final dates = <DateTime>{
      for (final schedule in schedules.values)
        DateUtils.dateOnly(schedule.startLocal),
    };
    if (dates.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final nowLocal =
        _openHandNowInZone?.call(timezone) ??
        temporalContext.presentLocalDateTime;
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'oh_start=${CalendarPage._formatDetachedGregorian(flowStart)}',
      'oh_tz=${timezone.key}',
      'oh_lens=${lens.key}',
      'oh_midday_hour=$kOpenHandDefaultMiddayHour',
      'oh_midday_minute=$kOpenHandDefaultMiddayMinute',
      'oh_decan_kyear=${window.openingOccurrence.kYear}',
      'oh_decan_month=${window.openingOccurrence.kMonth}',
      'oh_decan_day=${window.openingOccurrence.decanStartDay}',
      'oh_enrolled_at=${nowLocal.toIso8601String()}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: flowStart,
      endDate: flowStart.add(const Duration(days: 29)),
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (final event in events) {
      final schedule = schedules[event]!;
      final clientEventId = openHandClientEventId(flowId: flowId, event: event);
      final title = openHandEventTitle(event);
      final detail = openHandDetailText(event, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: schedule.startUtc,
        startsAtLocal: schedule.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
        endsAtLocal: schedule.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: openHandActionId(event),
        behaviorPayload: openHandBehaviorPayload(
          event: event,
          schedule: schedule,
          lens: lens,
        ),
        caller: 'open_hand_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'openHandHeadless',
        clientEventId: clientEventId,
        startsAtLocal: schedule.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinDjedHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    DjedLens lens = DjedLens.neutral,
    required DjedV2Configuration configuration,
    int alertOffsetMinutes = 0,
  }) async {
    if (!configuration.isComplete) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }
    final temporalContext = _captureTemporalContext(timezone);
    final window = _resolveDjedWindow(
      timezone: timezone,
      startDate:
          startDate ??
          _resolveTemporalStart(
            MaatFlowKind.theDjed,
            timezone,
            context: temporalContext,
          ),
    );
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final events = _djedEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final flowStart = DateUtils.dateOnly(window.opensAtLocal);
    final schedules = <DjedV2Event, DjedOccurrenceSchedule>{
      for (final event in events)
        event: _djedScheduleForEvent(
          event: event,
          flowStart: flowStart,
          timezone: timezone,
        ),
    };
    final dates = <DateTime>{
      for (final schedule in schedules.values)
        DateUtils.dateOnly(schedule.startLocal),
    };
    if (dates.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final nowLocal =
        _djedNowInZone?.call(timezone) ?? temporalContext.presentLocalDateTime;
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'djed_start=${CalendarPage._formatDetachedGregorian(flowStart)}',
      'djed_tz=${timezone.key}',
      'djed_lens=${lens.key}',
      'djed_schema_version=$kDjedV2SchemaVersion',
      'djed_v2_config=${djedV2ConfigurationNotesToken(configuration)}',
      'djed_midday_hour=$kDjedDefaultMiddayHour',
      'djed_midday_minute=$kDjedDefaultMiddayMinute',
      'djed_decan_kyear=${window.openingOccurrence.kYear}',
      'djed_decan_month=${window.openingOccurrence.kMonth}',
      'djed_decan_day=${window.openingOccurrence.decanStartDay}',
      'djed_enrolled_at=${nowLocal.toIso8601String()}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: flowStart,
      endDate: flowStart.add(const Duration(days: 29)),
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (final event in events) {
      final schedule = schedules[event]!;
      final clientEventId = djedV2ClientEventId(flowId: flowId, event: event);
      final title = djedV2EventTitle(event);
      final detail = djedV2DetailText(event, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: schedule.startUtc,
        startsAtLocal: schedule.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
        endsAtLocal: schedule.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: djedV2ActionId(event),
        behaviorPayload: djedV2BehaviorPayload(
          event: event,
          schedule: schedule,
          lens: lens,
          configuration: configuration,
        ),
        caller: 'djed_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'djedHeadless',
        clientEventId: clientEventId,
        startsAtLocal: schedule.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinMaatDecanFlowHeadless({
    required MaatDecanFlowDefinition definition,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    int alertOffsetMinutes = 0,
  }) async {
    if (!isMaatFlowNewJoinAllowed(definition.key)) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.notJoinable);
    }
    final temporalContext = _captureTemporalContext(timezone);
    final window = _resolveDecanWatchWindow(
      timezone: timezone,
      startDate:
          startDate ??
          _resolveTemporalStart(
            _registeredKindForKey(definition.key),
            timezone,
            context: temporalContext,
          ),
    );
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final events = definition.events;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final flowStart = DateUtils.dateOnly(window.opensAtLocal);
    final schedules = <MaatDecanFlowEvent, MaatDecanFlowOccurrenceSchedule>{
      for (final event in events)
        event: maatDecanFlowScheduleForEvent(event, flowStart, timezone),
    };
    final dates = <DateTime>{
      for (final schedule in schedules.values)
        DateUtils.dateOnly(schedule.startLocal),
    };
    if (dates.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final nowLocal = temporalContext.presentLocalDateTime;
    final startIso = CalendarPage._formatDetachedGregorian(flowStart);
    final prefix = definition.notesPrefix;
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=${definition.key}',
      '${prefix}_start=$startIso',
      '${prefix}_tz=${timezone.key}',
      '${prefix}_anchor_hour=$kMaatDecanFlowDefaultMiddayHour',
      '${prefix}_anchor_minute=$kMaatDecanFlowDefaultMiddayMinute',
      '${prefix}_decan_kyear=${window.openingOccurrence.kYear}',
      '${prefix}_decan_month=${window.openingOccurrence.kMonth}',
      '${prefix}_decan_day=${window.openingOccurrence.decanStartDay}',
      '${prefix}_enrolled_at=${nowLocal.toIso8601String()}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: definition.title,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: flowStart,
      endDate: flowStart.add(const Duration(days: 29)),
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (final event in events) {
      final schedule = schedules[event]!;
      final clientEventId = maatDecanFlowClientEventId(
        flowId: flowId,
        definition: definition,
        event: event,
      );
      final title = maatDecanFlowEventTitle(definition, event);
      final detail = maatDecanFlowDetailText(definition, event);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: schedule.startUtc,
        startsAtLocal: schedule.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
        endsAtLocal: schedule.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: maatDecanFlowActionId(definition, event),
        behaviorPayload: maatDecanFlowBehaviorPayload(
          definition: definition,
          event: event,
          schedule: schedule,
        ),
        caller: 'maat_decan_flow_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'maatDecanFlowHeadless',
        clientEventId: clientEventId,
        startsAtLocal: schedule.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinEveningThresholdHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    int defaultMinutesAfterMidnight =
        kEveningThresholdDefaultMinutesAfterMidnight,
    int materializedDays = kEveningThresholdMaterializedDays,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
    String? initialCarryText,
  }) async {
    if (kEveningThresholdEvents.isEmpty || materializedDays <= 0) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ??
          _resolveTemporalStart(
            MaatFlowKind.eveningThreshold,
            timezone,
            eveningThresholdMinutes: defaultMinutesAfterMidnight,
          ),
    );
    final schedules = <({EveningThresholdEvent event, DateTime date})>[
      for (var dayIndex = 0; dayIndex < materializedDays; dayIndex++)
        for (final event in kEveningThresholdEvents)
          (event: event, date: firstGregorian.add(Duration(days: dayIndex))),
    ];
    if (schedules.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final occurrences = <DailyEveningThresholdOccurrenceSchedule>[
      for (final entry in schedules)
        dailyEveningThresholdScheduleForDate(
          localDate: entry.date,
          timezone: timezone,
          event: entry.event,
          defaultMinutesAfterMidnight: defaultMinutesAfterMidnight,
        ),
    ];
    final eveningDates = <DateTime>{
      for (var i = 0; i < schedules.length; i++)
        if (schedules[i].event.kind == EveningThresholdEventKind.theReturn)
          DateUtils.dateOnly(occurrences[i].startLocal),
    };
    final morningDates = <DateTime>{
      for (var i = 0; i < schedules.length; i++)
        if (schedules[i].event.kind == EveningThresholdEventKind.theCarry)
          DateUtils.dateOnly(occurrences[i].startLocal),
    };
    final dates = <DateTime>{...eveningDates, ...morningDates};
    final orderedDates = dates.toList()..sort();
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'evening_threshold_tz=${timezone.key}',
      'evening_threshold_default=$defaultMinutesAfterMidnight',
      'evening_threshold_morning_default=$kEveningThresholdDefaultMorningMinutesAfterMidnight',
      'daily_orientation_link=$kEveningThresholdLinkedTo',
      'carryover_field=$kEveningThresholdCarryoverField',
      'landing_field=$kEveningThresholdLandingField',
      'decision_table=$kEveningThresholdDecisionTable',
      'materialized_days=$materializedDays',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: orderedDates.last,
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          if (eveningDates.isNotEmpty)
            _RuleDates(
              dates: eveningDates,
              allDay: false,
              start: TimeOfDay(
                hour: defaultMinutesAfterMidnight ~/ 60,
                minute: defaultMinutesAfterMidnight % 60,
              ),
              end: TimeOfDay(
                hour:
                    (defaultMinutesAfterMidnight +
                        kEveningThresholdEventDurationMinutes) ~/
                    60,
                minute:
                    (defaultMinutesAfterMidnight +
                        kEveningThresholdEventDurationMinutes) %
                    60,
              ),
            ),
          if (morningDates.isNotEmpty)
            _RuleDates(
              dates: morningDates,
              allDay: false,
              start: const TimeOfDay(
                hour: kEveningThresholdDefaultMorningMinutesAfterMidnight ~/ 60,
                minute:
                    kEveningThresholdDefaultMorningMinutesAfterMidnight % 60,
              ),
              end: const TimeOfDay(
                hour:
                    (kEveningThresholdDefaultMorningMinutesAfterMidnight +
                        kEveningThresholdEventDurationMinutes) ~/
                    60,
                minute:
                    (kEveningThresholdDefaultMorningMinutesAfterMidnight +
                        kEveningThresholdEventDurationMinutes) %
                    60,
              ),
            ),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final trimmedInitialCarry = initialCarryText?.trim();

    final clientEventIds = <String>[];
    for (var i = 0; i < schedules.length; i++) {
      final entry = schedules[i];
      final occurrence = occurrences[i];
      final k = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startLocal),
      );
      final title = eveningThresholdEventTitle(entry.event);
      final detail = eveningThresholdDetailText(entry.event);
      final clientEventId = EventCidUtil.buildClientEventId(
        ky: k.kYear,
        km: k.kMonth,
        kd: k.kDay,
        title: title,
        startHour: occurrence.startLocal.hour,
        startMinute: occurrence.startLocal.minute,
        allDay: false,
        flowId: flowId,
      );

      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        startsAtLocal: occurrence.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        endsAtLocal: occurrence.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: eveningThresholdActionId(entry.event),
        behaviorPayload: eveningThresholdBehaviorPayload(
          event: entry.event,
          schedule: occurrence,
        ),
        caller: 'evening_threshold_join_headless',
      );
      clientEventIds.add(clientEventId);

      if (alertOffsetMinutes != kEventFilingNoAlertMinutes &&
          entry.event.kind == EveningThresholdEventKind.theReturn) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'eveningThresholdHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
      additionalPersistence:
          trimmedInitialCarry != null && trimmedInitialCarry.isNotEmpty
          ? () => _persistEveningThresholdInitialCarry(
              localDate: firstGregorian,
              carryText: trimmedInitialCarry,
            )
          : null,
    );
  }

  Future<FlowJoinResult> joinOfferingTableHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    OfferingTableLens lens = OfferingTableLens.neutral,
    bool noCupMode = false,
    int alertOffsetMinutes = 0,
  }) async {
    final days = _offeringTableDays;
    if (days.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ??
          _resolveOfferingTableDefaultStartDate?.call(timezone) ??
          _resolveTemporalStart(MaatFlowKind.offeringTable, timezone),
    );
    final occurrences = <OfferingTableOccurrenceSchedule>[
      for (var i = 0; i < days.length; i++)
        _offeringTableScheduleForDate(
          days[i],
          firstGregorian.add(Duration(days: i)),
          timezone,
        ),
    ];
    if (occurrences.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final dates = <DateTime>{
      for (final occurrence in occurrences)
        DateUtils.dateOnly(occurrence.startLocal),
    };
    if (dates.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final orderedDates = dates.toList()..sort();
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'offering_tz=${timezone.key}',
      'offering_lens=${lens.key}',
      'offering_hour=$kOfferingTableDefaultHour',
      'offering_minute=$kOfferingTableDefaultMinute',
      'no_cup_mode=${noCupMode ? 1 : 0}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: orderedDates.last,
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final occurrence = occurrences[i];
      final k = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startLocal),
      );
      final title = offeringTableEventTitle(day);
      final clientEventId = EventCidUtil.buildClientEventId(
        ky: k.kYear,
        km: k.kMonth,
        kd: k.kDay,
        title: title,
        startHour: occurrence.startLocal.hour,
        startMinute: occurrence.startLocal.minute,
        allDay: false,
        flowId: flowId,
      );
      final detail = offeringTableDetailText(
        day,
        lens: lens,
        noCupMode: noCupMode,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        startsAtLocal: occurrence.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        endsAtLocal: occurrence.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: offeringTableActionId(day),
        behaviorPayload: offeringTableBehaviorPayload(
          day: day,
          schedule: occurrence,
          lens: lens,
          noCupMode: noCupMode,
        ),
        caller: 'offering_table_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'offeringTableHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<FlowJoinResult> joinTheCourseHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    CourseLens lens = CourseLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final events = _courseEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ??
          _resolveTheCourseDefaultStartDate?.call(timezone) ??
          _resolveTemporalStart(MaatFlowKind.theCourse, timezone),
    );
    final joinedK = KemeticMath.fromGregorian(firstGregorian);
    final occurrences = <CourseOccurrenceSchedule>[
      for (final event in events)
        _courseScheduleForDate(
          event,
          firstGregorian.add(Duration(days: event.flowDay - 1)),
          timezone,
        ),
    ];
    if (occurrences.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final dates = <DateTime>{
      for (final occurrence in occurrences)
        DateUtils.dateOnly(occurrence.startLocal),
    };
    if (dates.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final orderedDates = dates.toList()..sort();
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'course_tz=${timezone.key}',
      'course_lens=${lens.key}',
      'course_midday_hour=$kTheCourseDefaultMiddayHour',
      'course_midday_minute=$kTheCourseDefaultMiddayMinute',
      'joined_ky=${joinedK.kYear}',
      'joined_km=${joinedK.kMonth}',
      'joined_kd=${joinedK.kDay}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: orderedDates.first,
      endDate: firstGregorian.add(const Duration(days: 29)),
      notes: notes,
      rules: jsonEncode(
        <FlowRule>[
          _RuleDates(dates: dates),
        ].map(CalendarPageState.ruleToJson).toList(),
      ),
      originType: 'template',
    );

    final clientEventIds = <String>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final occurrence = occurrences[i];
      final dayOnly = DateUtils.dateOnly(occurrence.startLocal);
      final k = KemeticMath.fromGregorian(dayOnly);
      final context = courseContextForKemeticDate(
        kYear: k.kYear,
        kMonth: k.kMonth,
        kDay: k.kDay,
      );
      final title = courseEventTitle(event);
      final clientEventId = EventCidUtil.buildClientEventId(
        ky: k.kYear,
        km: k.kMonth,
        kd: k.kDay,
        title: title,
        startHour: occurrence.startLocal.hour,
        startMinute: occurrence.startLocal.minute,
        allDay: false,
        flowId: flowId,
      );
      final detail = courseDetailText(event, lens: lens, context: context);
      final behaviorPayload = courseBehaviorPayload(
        event: event,
        schedule: occurrence,
        lens: lens,
        context: context,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        startsAtLocal: occurrence.startLocal,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        endsAtLocal: occurrence.endLocal,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: courseActionId(event),
        behaviorPayload: behaviorPayload,
        caller: 'the_course_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'theCourseHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    final staged = _takeDeferredJoinContext(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return stagePlannedNotesAndDeferPersist(
      flowId: flowId,
      localFlow: staged.localFlow,
      writes: staged.writes,
    );
  }

  Future<void> _fileHeadlessJoinDelivery({
    required String debugLabel,
    required String clientEventId,
    required DateTime startsAtLocal,
    required int? alertOffsetMinutes,
    required String title,
    String? body,
  }) {
    final deferred = _deferredJoinContext?.writes
        .where((write) => write.clientEventId == clientEventId)
        .lastOrNull;
    if (deferred != null) {
      deferred.alertDebugLabel = debugLabel;
      deferred.alertOffsetMinutes = alertOffsetMinutes;
      return Future<void>.value();
    }
    return _fileHeadlessEventDelivery(
      eventFiling: _eventFiling,
      debugLabel: debugLabel,
      clientEventId: clientEventId,
      startsAtLocal: startsAtLocal,
      alertOffsetMinutes: alertOffsetMinutes,
      title: title,
      body: body,
    );
  }

  _DeferredJoinContext _takeDeferredJoinContext({
    required int flowId,
    required List<String> clientEventIds,
  }) {
    final stagedContext = _deferredJoinContext;
    _deferredJoinContext = null;
    if (stagedContext == null || stagedContext.localFlow.id != flowId) {
      throw StateError('Missing staged event context for flow $flowId.');
    }
    final stagedClientEventIds = stagedContext.writes
        .map((write) => write.clientEventId)
        .toSet();
    if (!stagedClientEventIds.containsAll(clientEventIds)) {
      throw StateError('Staged event IDs do not match flow $flowId.');
    }
    return stagedContext;
  }

  // The calendar library intentionally keeps [_Flow] private; this method is
  // public so every producer uses one origin-neutral staging/persistence API.
  // ignore: library_private_types_in_public_api
  FlowJoinResult stagePlannedNotesAndDeferPersist({
    required int flowId,
    // ignore: library_private_types_in_public_api
    required _Flow localFlow,
    required List<PlannedNoteWrite> writes,
    Future<void> Function()? additionalPersistence,
    CalendarInvalidationReason invalidationReason =
        CalendarInvalidationReason.flowJoined,
  }) {
    if (localFlow.id != flowId) {
      throw StateError('Staged flow ID does not match flow $flowId.');
    }
    if (writes.isEmpty) {
      throw StateError('Flow $flowId produced no staged events.');
    }
    if (writes.any((write) => write.flowId != flowId)) {
      throw StateError('Staged event flow IDs do not match flow $flowId.');
    }
    final stagedWrites = List<PlannedNoteWrite>.unmodifiable(writes);
    final plannedNotes = List<_PlannedNote>.unmodifiable(
      stagedWrites.map((write) => write._plannedNote),
    );
    final clientEventIds = List<String>.unmodifiable(
      stagedWrites.map((write) => write.clientEventId),
    );

    Future<void> persistInBackground() async {
      final injectedUpsert = _upsertEvent;
      if (injectedUpsert != null) {
        for (final write in stagedWrites) {
          await injectedUpsert(
            clientEventId: write.clientEventId,
            title: write.title,
            startsAtUtc: write.startsAtUtc,
            detail: write.detail,
            allDay: write.allDay,
            endsAtUtc: write.endsAtUtc,
            flowLocalId: write.flowId,
            category: write.category,
            actionId: write.actionId,
            behaviorPayload: write.behaviorPayload,
            calendarId: write.calendarId,
            caller: write.caller,
          );
        }
      } else {
        final rows = <Map<String, dynamic>>[
          for (final write in stagedWrites)
            _repo.deterministicUpsertPayload(
              clientEventId: write.clientEventId,
              title: write.title,
              startsAtUtc: write.startsAtUtc,
              detail: write.detail,
              location: write.location,
              allDay: write.allDay,
              endsAtUtc: write.endsAtUtc,
              calendarId: write.calendarId,
              flowLocalId: write.flowId,
              category: write.category,
              actionId: write.actionId,
              behaviorPayload: write.behaviorPayload,
            ),
        ];
        await _repo.upsertManyDeterministic(rows);
      }

      if (additionalPersistence != null) {
        await additionalPersistence();
      }
      _publishHeadlessCalendarInvalidation(
        reason: invalidationReason,
        flowId: flowId,
        clientEventIds: clientEventIds,
      );

      for (final write in stagedWrites) {
        final alertOffset = write.alertOffsetMinutes;
        if (alertOffset == kEventFilingNoAlertMinutes) continue;
        unawaited(
          _fileHeadlessEventDelivery(
            eventFiling: _eventFiling,
            debugLabel: write.alertDebugLabel ?? 'stagedFlowPersist',
            clientEventId: write.clientEventId,
            startsAtLocal: write.startsAtLocal,
            alertOffsetMinutes: alertOffset,
            title: write.title,
            body: write.alertBody ?? write.noteDetail,
          ).catchError((Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              _calendarDebugPrint(
                '[stagedFlowPersist] background alert filing failed: $error',
              );
              _calendarDebugPrint('$stackTrace');
            }
          }),
        );
      }
    }

    return FlowJoinResult._fastPathSuccess(
      flowId: flowId,
      clientEventIds: clientEventIds,
      localFlow: localFlow,
      plannedNotes: plannedNotes,
      persistInBackground: persistInBackground,
    );
  }

  Future<int> _upsertFlowRow({
    int? id,
    required String name,
    required int color,
    required bool active,
    String? calendarId,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required String rules,
    String? originType,
  }) async {
    final upsert = _upsertFlow;
    final flowId = upsert != null
        ? await upsert(
            id: id,
            name: name,
            color: color,
            active: active,
            calendarId: calendarId,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            rules: rules,
            originType: originType,
          )
        : await _repo.upsertFlow(
            id: id,
            name: name,
            color: color,
            active: active,
            calendarId: calendarId,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            rules: rules,
            originType: originType,
          );
    final decodedRules = jsonDecode(rules);
    final localRules = decodedRules is List
        ? decodedRules
              .whereType<Map>()
              .map(
                (rule) =>
                    CalendarPage.ruleFromJson(Map<String, dynamic>.from(rule)),
              )
              .toList(growable: false)
        : const <FlowRule>[];
    _deferredJoinContext = _DeferredJoinContext(
      localFlow: _Flow(
        id: flowId,
        calendarId: calendarId,
        name: name,
        color: Color(color),
        active: active,
        rules: localRules,
        start: startDate,
        end: endDate,
        notes: notes,
      ),
    );
    return flowId;
  }

  Future<void> _upsertEventRow({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    required DateTime startsAtLocal,
    String? detail,
    bool allDay = false,
    DateTime? endsAtUtc,
    DateTime? endsAtLocal,
    int? flowLocalId,
    String? category,
    String? actionId,
    Map<String, dynamic>? behaviorPayload,
    String? calendarId,
    String? caller,
  }) async {
    final context = _deferredJoinContext;
    if (context == null || flowLocalId == null) {
      throw StateError('Event write attempted without a staged flow.');
    }
    context.writes.add(
      PlannedNoteWrite(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: startsAtUtc,
        endsAtUtc: endsAtUtc,
        startsAtLocal: startsAtLocal,
        endsAtLocal: endsAtLocal,
        detail: detail,
        noteDetail: detail,
        location: null,
        allDay: allDay,
        calendarId: calendarId,
        calendarName: null,
        flowId: flowLocalId,
        manualColor: null,
        category: category,
        isReminder: false,
        reminderId: null,
        actionId: actionId,
        behaviorPayload: behaviorPayload,
        caller: caller,
      ),
    );
  }

  static MoonReturnEnrollmentWindow? _defaultResolveMoonReturnWindow({
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
  }) {
    return resolveMoonReturnEnrollmentWindowSafely(
      timezone: timezone,
      startDate: startDate,
    );
  }

  static List<MoonReturnOccurrence> _defaultMoonReturnOccurrencesForWindow({
    required MoonReturnEnrollmentWindow window,
  }) {
    return moonReturnOccurrencesForWindow(window: window);
  }

  static DecanWatchEnrollmentWindow? _defaultResolveDecanWatchWindow({
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
  }) {
    return resolveDecanWatchEnrollmentWindowSafely(
      timezone: timezone,
      startDate: startDate,
    );
  }

  static List<DecanWatchOccurrence> _defaultDecanWatchOccurrencesForWindow({
    required DecanWatchEnrollmentWindow window,
    required TrackSkyTimeZone timezone,
  }) {
    return <DecanWatchOccurrence>[
      window.openingOccurrence,
      ...upcomingDecanWatchOccurrences(
        timezone: timezone,
        fromLocal: window.openingOccurrence.startLocal.add(
          const Duration(days: 1),
        ),
        count: 2,
      ),
    ];
  }

  static OpenHandEnrollmentWindow? _defaultResolveOpenHandWindow({
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
  }) {
    return resolveOpenHandEnrollmentWindowSafely(
      timezone: timezone,
      startDate: startDate,
    );
  }

  static OpenHandOccurrenceSchedule _defaultOpenHandScheduleForEvent({
    required OpenHandEvent event,
    required DateTime flowStart,
    required TrackSkyTimeZone timezone,
  }) {
    return openHandScheduleForEvent(event, flowStart, timezone);
  }

  static DjedEnrollmentWindow? _defaultResolveDjedWindow({
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
  }) {
    return resolveDjedEnrollmentWindowSafely(
      timezone: timezone,
      startDate: startDate,
    );
  }

  static DjedOccurrenceSchedule _defaultDjedScheduleForEvent({
    required DjedV2Event event,
    required DateTime flowStart,
    required TrackSkyTimeZone timezone,
  }) {
    return djedV2ScheduleForEvent(event, flowStart, timezone);
  }

  static OfferingTableOccurrenceSchedule _defaultOfferingTableScheduleForDate(
    OfferingTableDay day,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return offeringTableScheduleForDate(day, date, timezone);
  }

  static CourseOccurrenceSchedule _defaultCourseScheduleForDate(
    CourseEvent event,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return courseScheduleForDate(event, date, timezone);
  }
}
