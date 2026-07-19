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

typedef WagWindowResolver =
    WagEnrollmentWindow? Function({
      required TrackSkyTimeZone timezone,
      DateTime? startDate,
    });

typedef WagScheduleResolver =
    WagOccurrenceSchedule Function({
      required WagEvent event,
      required int kYear,
      required TrackSkyTimeZone timezone,
    });

typedef WagNowProvider = DateTime Function(TrackSkyTimeZone timezone);

typedef DaysOutsideYearWindowResolver =
    DaysOutsideYearEnrollmentWindow? Function({
      required TrackSkyTimeZone timezone,
      DateTime? startDate,
    });

typedef DaysOutsideYearScheduleResolver =
    DaysOutsideOccurrenceSchedule Function({
      required DaysOutsideEvent event,
      required int closingKYear,
      required TrackSkyTimeZone timezone,
    });

typedef DaysOutsideYearNowProvider =
    DateTime Function(TrackSkyTimeZone timezone);

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
      required DjedEvent event,
      required DateTime flowStart,
      required TrackSkyTimeZone timezone,
    });

typedef DjedNowProvider = DateTime Function(TrackSkyTimeZone timezone);

typedef DawnHouseRiteStartDateResolver =
    DateTime Function(TrackSkyTimeZone timezone);

typedef DawnHouseRiteScheduleResolver =
    DawnHouseRiteOccurrenceSchedule Function(
      DateTime date,
      TrackSkyTimeZone timezone,
    );

typedef EveningThresholdRiteStartDateResolver =
    DateTime Function(
      TrackSkyTimeZone timezone, {
      required int fallbackMinutesAfterMidnight,
    });

typedef EveningThresholdRiteScheduleResolver =
    EveningThresholdOccurrenceSchedule Function(
      DateTime date,
      TrackSkyTimeZone timezone, {
      required int fallbackMinutesAfterMidnight,
    });

typedef TheWeighingStartDateResolver =
    DateTime Function(TrackSkyTimeZone timezone);

typedef TheWeighingScheduleResolver =
    TheWeighingOccurrenceSchedule Function(
      TheWeighingEvent event,
      DateTime date,
      TrackSkyTimeZone timezone,
    );

typedef OfferingTableStartDateResolver =
    DateTime Function(TrackSkyTimeZone timezone);

typedef OfferingTableScheduleResolver =
    OfferingTableOccurrenceSchedule Function(
      OfferingTableDay day,
      DateTime date,
      TrackSkyTimeZone timezone,
    );

typedef TheTendingStartDateResolver =
    DateTime Function(TrackSkyTimeZone timezone);

typedef TheTendingScheduleResolver =
    TheTendingOccurrenceSchedule Function(
      TheTendingEvent event,
      DateTime date,
      TrackSkyTimeZone timezone,
    );

typedef KeptWordStartDateResolver =
    DateTime Function(TrackSkyTimeZone timezone);

typedef KeptWordScheduleResolver =
    KeptWordOccurrenceSchedule Function(
      KeptWordEvent event,
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

enum FlowJoinFailureCode { noEnrollmentWindow, noOccurrences }

class FlowJoinResult {
  const FlowJoinResult._({
    required this.succeeded,
    required this.flowId,
    required this.clientEventIds,
    this.failureCode,
  });

  const FlowJoinResult.success({
    required int flowId,
    required List<String> clientEventIds,
  }) : this._(succeeded: true, flowId: flowId, clientEventIds: clientEventIds);

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
  final FlowJoinFailureCode? failureCode;

  int get flowIdOrZero => succeeded ? flowId! : 0;
  int get flowIdOrNegativeOne => succeeded ? flowId! : -1;
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
    WagWindowResolver? resolveWagWindow,
    WagScheduleResolver? wagScheduleForEvent,
    WagNowProvider? wagNowInZone,
    List<WagEvent>? wagEvents,
    DaysOutsideYearWindowResolver? resolveDaysOutsideYearWindow,
    DaysOutsideYearScheduleResolver? daysOutsideYearScheduleForEvent,
    DaysOutsideYearNowProvider? daysOutsideYearNowInZone,
    List<DaysOutsideEvent>? daysOutsideYearEvents,
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
    List<DjedEvent>? djedEvents,
    DawnHouseRiteStartDateResolver? resolveDawnHouseRiteDefaultStartDate,
    DawnHouseRiteScheduleResolver? dawnHouseRiteScheduleForDate,
    List<DawnHouseRiteDay>? dawnHouseRiteDays,
    EveningThresholdRiteStartDateResolver?
    resolveEveningThresholdRiteDefaultStartDate,
    EveningThresholdRiteScheduleResolver? eveningThresholdScheduleForDate,
    List<EveningThresholdRiteDay>? eveningThresholdRiteDays,
    TheWeighingStartDateResolver? resolveTheWeighingDefaultStartDate,
    TheWeighingScheduleResolver? theWeighingScheduleForDate,
    List<TheWeighingEvent>? theWeighingEvents,
    OfferingTableStartDateResolver? resolveOfferingTableDefaultStartDate,
    OfferingTableScheduleResolver? offeringTableScheduleForDate,
    List<OfferingTableDay>? offeringTableDays,
    TheTendingStartDateResolver? resolveTheTendingDefaultStartDate,
    TheTendingScheduleResolver? theTendingScheduleForDate,
    List<TheTendingEvent>? theTendingEvents,
    KeptWordStartDateResolver? resolveKeptWordDefaultStartDate,
    KeptWordScheduleResolver? keptWordScheduleForDate,
    List<KeptWordEvent>? keptWordEvents,
    CourseStartDateResolver? resolveTheCourseDefaultStartDate,
    CourseScheduleResolver? courseScheduleForDate,
    List<CourseEvent>? courseEvents,
  }) : _userEventsRepo = userEventsRepo,
       _eventFiling = eventFiling ?? EventFilingService(),
       _upsertFlow = upsertFlow,
       _upsertEvent = upsertEvent,
       _fileHeadlessEventDelivery =
           fileHeadlessEventDelivery ?? CalendarPage._fileHeadlessEventDelivery,
       _publishHeadlessCalendarInvalidation =
           publishHeadlessCalendarInvalidation ??
           CalendarPage._publishHeadlessCalendarInvalidation,
       _persistEveningThresholdInitialCarry =
           persistEveningThresholdInitialCarry ??
           _defaultPersistEveningThresholdInitialCarry,
       _resolveMoonReturnWindow =
           resolveMoonReturnWindow ?? _defaultResolveMoonReturnWindow,
       _moonReturnOccurrencesForWindow =
           moonReturnOccurrencesForWindow ??
           _defaultMoonReturnOccurrencesForWindow,
       _moonReturnNowInZone =
           moonReturnNowInZone ?? _defaultMoonReturnNowInZone,
       _resolveWagWindow = resolveWagWindow ?? _defaultResolveWagWindow,
       _wagScheduleForEvent =
           wagScheduleForEvent ?? _defaultWagScheduleForEvent,
       _wagNowInZone = wagNowInZone ?? _defaultWagNowInZone,
       _wagEvents = wagEvents ?? kWagEvents,
       _resolveDaysOutsideYearWindow =
           resolveDaysOutsideYearWindow ?? _defaultResolveDaysOutsideYearWindow,
       _daysOutsideYearScheduleForEvent =
           daysOutsideYearScheduleForEvent ??
           _defaultDaysOutsideYearScheduleForEvent,
       _daysOutsideYearNowInZone =
           daysOutsideYearNowInZone ?? _defaultDaysOutsideYearNowInZone,
       _daysOutsideYearEvents = daysOutsideYearEvents ?? kDaysOutsideEvents,
       _resolveDecanWatchWindow =
           resolveDecanWatchWindow ?? _defaultResolveDecanWatchWindow,
       _decanWatchOccurrencesForWindow =
           decanWatchOccurrencesForWindow ??
           _defaultDecanWatchOccurrencesForWindow,
       _decanWatchNowInZone =
           decanWatchNowInZone ?? _defaultDecanWatchNowInZone,
       _resolveOpenHandWindow =
           resolveOpenHandWindow ?? _defaultResolveOpenHandWindow,
       _openHandScheduleForEvent =
           openHandScheduleForEvent ?? _defaultOpenHandScheduleForEvent,
       _openHandNowInZone = openHandNowInZone ?? _defaultOpenHandNowInZone,
       _openHandEvents = openHandEvents ?? kOpenHandEvents,
       _resolveDjedWindow = resolveDjedWindow ?? _defaultResolveDjedWindow,
       _djedScheduleForEvent =
           djedScheduleForEvent ?? _defaultDjedScheduleForEvent,
       _djedNowInZone = djedNowInZone ?? _defaultDjedNowInZone,
       _djedEvents = djedEvents ?? kDjedEvents,
       _resolveDawnHouseRiteDefaultStartDate =
           resolveDawnHouseRiteDefaultStartDate ??
           _defaultResolveDawnHouseRiteStartDate,
       _dawnHouseRiteScheduleForDate =
           dawnHouseRiteScheduleForDate ?? _defaultDawnHouseRiteScheduleForDate,
       _dawnHouseRiteDays = dawnHouseRiteDays ?? kDawnHouseRiteDays,
       _resolveEveningThresholdRiteDefaultStartDate =
           resolveEveningThresholdRiteDefaultStartDate ??
           _defaultResolveEveningThresholdRiteStartDate,
       _eveningThresholdScheduleForDate =
           eveningThresholdScheduleForDate ??
           _defaultEveningThresholdScheduleForDate,
       _eveningThresholdRiteDays =
           eveningThresholdRiteDays ?? kEveningThresholdRiteDays,
       _resolveTheWeighingDefaultStartDate =
           resolveTheWeighingDefaultStartDate ??
           _defaultResolveTheWeighingStartDate,
       _theWeighingScheduleForDate =
           theWeighingScheduleForDate ?? _defaultTheWeighingScheduleForDate,
       _theWeighingEvents = theWeighingEvents ?? kTheWeighingEvents,
       _resolveOfferingTableDefaultStartDate =
           resolveOfferingTableDefaultStartDate ??
           _defaultResolveOfferingTableStartDate,
       _offeringTableScheduleForDate =
           offeringTableScheduleForDate ?? _defaultOfferingTableScheduleForDate,
       _offeringTableDays = offeringTableDays ?? kOfferingTableDays,
       _resolveTheTendingDefaultStartDate =
           resolveTheTendingDefaultStartDate ??
           _defaultResolveTheTendingStartDate,
       _theTendingScheduleForDate =
           theTendingScheduleForDate ?? _defaultTheTendingScheduleForDate,
       _theTendingEvents = theTendingEvents ?? kTheTendingEvents,
       _resolveKeptWordDefaultStartDate =
           resolveKeptWordDefaultStartDate ?? _defaultResolveKeptWordStartDate,
       _keptWordScheduleForDate =
           keptWordScheduleForDate ?? _defaultKeptWordScheduleForDate,
       _keptWordEvents = keptWordEvents ?? kKeptWordEvents,
       _resolveTheCourseDefaultStartDate =
           resolveTheCourseDefaultStartDate ??
           _defaultResolveTheCourseStartDate,
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
  final FlowJoinPersistEveningThresholdInitialCarry
  _persistEveningThresholdInitialCarry;
  final MoonReturnWindowResolver _resolveMoonReturnWindow;
  final MoonReturnOccurrenceResolver _moonReturnOccurrencesForWindow;
  final MoonReturnNowProvider _moonReturnNowInZone;
  final WagWindowResolver _resolveWagWindow;
  final WagScheduleResolver _wagScheduleForEvent;
  final WagNowProvider _wagNowInZone;
  final List<WagEvent> _wagEvents;
  final DaysOutsideYearWindowResolver _resolveDaysOutsideYearWindow;
  final DaysOutsideYearScheduleResolver _daysOutsideYearScheduleForEvent;
  final DaysOutsideYearNowProvider _daysOutsideYearNowInZone;
  final List<DaysOutsideEvent> _daysOutsideYearEvents;
  final DecanWatchWindowResolver _resolveDecanWatchWindow;
  final DecanWatchOccurrenceResolver _decanWatchOccurrencesForWindow;
  final DecanWatchNowProvider _decanWatchNowInZone;
  final OpenHandWindowResolver _resolveOpenHandWindow;
  final OpenHandScheduleResolver _openHandScheduleForEvent;
  final OpenHandNowProvider _openHandNowInZone;
  final List<OpenHandEvent> _openHandEvents;
  final DjedWindowResolver _resolveDjedWindow;
  final DjedScheduleResolver _djedScheduleForEvent;
  final DjedNowProvider _djedNowInZone;
  final List<DjedEvent> _djedEvents;
  final DawnHouseRiteStartDateResolver _resolveDawnHouseRiteDefaultStartDate;
  final DawnHouseRiteScheduleResolver _dawnHouseRiteScheduleForDate;
  final List<DawnHouseRiteDay> _dawnHouseRiteDays;
  final EveningThresholdRiteStartDateResolver
  _resolveEveningThresholdRiteDefaultStartDate;
  final EveningThresholdRiteScheduleResolver _eveningThresholdScheduleForDate;
  final List<EveningThresholdRiteDay> _eveningThresholdRiteDays;
  final TheWeighingStartDateResolver _resolveTheWeighingDefaultStartDate;
  final TheWeighingScheduleResolver _theWeighingScheduleForDate;
  final List<TheWeighingEvent> _theWeighingEvents;
  final OfferingTableStartDateResolver _resolveOfferingTableDefaultStartDate;
  final OfferingTableScheduleResolver _offeringTableScheduleForDate;
  final List<OfferingTableDay> _offeringTableDays;
  final TheTendingStartDateResolver _resolveTheTendingDefaultStartDate;
  final TheTendingScheduleResolver _theTendingScheduleForDate;
  final List<TheTendingEvent> _theTendingEvents;
  final KeptWordStartDateResolver _resolveKeptWordDefaultStartDate;
  final KeptWordScheduleResolver _keptWordScheduleForDate;
  final List<KeptWordEvent> _keptWordEvents;
  final CourseStartDateResolver _resolveTheCourseDefaultStartDate;
  final CourseScheduleResolver _courseScheduleForDate;
  final List<CourseEvent> _courseEvents;

  UserEventsRepo get _repo =>
      _userEventsRepo ?? UserEventsRepo(Supabase.instance.client);

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
    final window = _resolveMoonReturnWindow(
      timezone: timezone,
      startDate: startDate,
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
    final nowLocal = _moonReturnNowInZone(timezone);
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
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinWagHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    WagLens lens = WagLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final window = _resolveWagWindow(timezone: timezone, startDate: startDate);
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final events = _wagEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final kYear = window.kYear;
    final schedules = <WagEvent, WagOccurrenceSchedule>{
      for (final event in events)
        event: _wagScheduleForEvent(
          event: event,
          kYear: kYear,
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

    final nowLocal = _wagNowInZone(timezone);
    final notes = [
      'mode=kemetic',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'wag_kyear=$kYear',
      'wag_tz=${timezone.key}',
      'wag_lens=${lens.key}',
      'wag_enrolled_at=${nowLocal.toIso8601String()}',
      'wag_window_open=${CalendarPage._formatDetachedGregorian(window.opensAtLocal)}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: DateUtils.dateOnly(wagYearStartGregorian(kYear)),
      endDate: DateUtils.dateOnly(wagYearEndGregorian(kYear)),
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
      final variant = wagCopyVariantForEvent(event: event, kYear: kYear);
      final clientEventId = wagClientEventId(
        flowId: flowId,
        kYear: kYear,
        event: event,
      );
      final title = wagEventTitle(event);
      final detail = wagDetailText(
        event,
        lens: lens,
        variant: variant,
        nextWagDate: event.sharePromptOnComplete
            ? wagNextFeastGregorian(kYear)
            : null,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: schedule.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: wagActionId(event),
        behaviorPayload: wagBehaviorPayload(
          event: event,
          kYear: kYear,
          timezoneKey: timezone.key,
          ianaTimezone: timezone.ianaName,
          scheduleType: schedule.scheduleType,
          referenceLocationName: schedule.referenceLocationName,
          usedFallback: schedule.usedFallback,
          lens: lens,
          variant: variant,
        ),
        caller: 'wag_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'wagHeadless',
        clientEventId: clientEventId,
        startsAtLocal: schedule.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinDaysOutsideYearHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    int alertOffsetMinutes = 0,
  }) async {
    final window = _resolveDaysOutsideYearWindow(
      timezone: timezone,
      startDate: startDate,
    );
    if (window == null) {
      return const FlowJoinResult.failure(
        FlowJoinFailureCode.noEnrollmentWindow,
      );
    }

    final events = _daysOutsideYearEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final closingKYear = window.closingKYear;
    final schedules = <DaysOutsideEvent, DaysOutsideOccurrenceSchedule>{
      for (final event in events)
        event: _daysOutsideYearScheduleForEvent(
          event: event,
          closingKYear: closingKYear,
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

    final nowLocal = _daysOutsideYearNowInZone(timezone);
    final notes = [
      'mode=kemetic',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'doy_kyear=$closingKYear',
      'doy_tz=${timezone.key}',
      'doy_enrolled_at=${nowLocal.toIso8601String()}',
      'doy_window_open=${CalendarPage._formatDetachedGregorian(window.opensAtLocal)}',
    ].join(';');

    final flowId = await _upsertFlowRow(
      id: null,
      name: templateTitle,
      color: templateColor.toARGB32(),
      active: true,
      calendarId: personalCalendarId,
      startDate: DateUtils.dateOnly(window.opensAtLocal),
      endDate: DateUtils.dateOnly(daysOutsideFlowEndGregorian(closingKYear)),
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
      final gregorian = daysOutsideEventGregorian(
        closingKYear: closingKYear,
        kMonth: event.kMonth,
        kDay: event.kDay,
      );
      final variant = daysOutsideCopyVariantForEvent(
        event: event,
        gregorianDate: gregorian,
      );
      final clientEventId = daysOutsideClientEventId(
        flowId: flowId,
        closingKYear: closingKYear,
        event: event,
      );
      final title = daysOutsideEventTitle(event);
      final detail = daysOutsideDetailText(
        event,
        closingKYear: closingKYear,
        variant: variant,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: schedule.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: daysOutsideActionId(event),
        behaviorPayload: daysOutsideBehaviorPayload(
          event: event,
          closingKYear: closingKYear,
          timezoneKey: timezone.key,
          ianaTimezone: timezone.ianaName,
          scheduleType: schedule.scheduleType,
          referenceLocationName: schedule.referenceLocationName,
          usedFallback: schedule.usedFallback,
          variant: variant,
        ),
        caller: 'days_outside_year_join_headless',
      );
      clientEventIds.add(clientEventId);
      await _fileHeadlessJoinDelivery(
        debugLabel: 'daysOutsideYearHeadless',
        clientEventId: clientEventId,
        startsAtLocal: schedule.startLocal,
        alertOffsetMinutes: alertOffsetMinutes,
        title: title,
        body: detail,
      );
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
    final window = _resolveDecanWatchWindow(
      timezone: timezone,
      startDate: startDate,
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
    final nowLocal = _decanWatchNowInZone(timezone);
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
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
    final window = _resolveOpenHandWindow(
      timezone: timezone,
      startDate: startDate,
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

    final nowLocal = _openHandNowInZone(timezone);
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
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
    int alertOffsetMinutes = 0,
  }) async {
    final window = _resolveDjedWindow(timezone: timezone, startDate: startDate);
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
    final schedules = <DjedEvent, DjedOccurrenceSchedule>{
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

    final nowLocal = _djedNowInZone(timezone);
    final notes = [
      'mode=gregorian',
      'split=1',
      if (templateOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(templateOverview.trim())}',
      'maat=$templateKey',
      'djed_start=${CalendarPage._formatDetachedGregorian(flowStart)}',
      'djed_tz=${timezone.key}',
      'djed_lens=${lens.key}',
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
      final clientEventId = djedClientEventId(flowId: flowId, event: event);
      final title = djedEventTitle(event);
      final detail = djedDetailText(event, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: schedule.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: djedActionId(event),
        behaviorPayload: djedBehaviorPayload(
          event: event,
          schedule: schedule,
          lens: lens,
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
    final window = _resolveDecanWatchWindow(
      timezone: timezone,
      startDate: startDate,
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

    final nowLocal = maatDecanFlowNowInZone(timezone);
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
        detail: detail,
        allDay: false,
        endsAtUtc: schedule.endUtc,
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinDawnHouseRiteHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    bool discreet = false,
    DawnHouseRiteLens lens = DawnHouseRiteLens.neutral,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final days = _dawnHouseRiteDays;
    if (days.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ?? _resolveDawnHouseRiteDefaultStartDate(timezone),
    );
    final occurrences = <DawnHouseRiteOccurrenceSchedule>[
      for (var i = 0; i < days.length; i++)
        _dawnHouseRiteScheduleForDate(
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
      'dawn_tz=${timezone.key}',
      'dawn_discreet=${discreet ? 1 : 0}',
      'dawn_lens=${lens.key}',
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
      final clientEventId = EventCidUtil.buildClientEventId(
        ky: k.kYear,
        km: k.kMonth,
        kd: k.kDay,
        title: dawnHouseRiteEventTitle(day),
        startHour: occurrence.startLocal.hour,
        startMinute: occurrence.startLocal.minute,
        allDay: false,
        flowId: flowId,
      );
      final title = dawnHouseRiteEventTitle(day);
      final detail = dawnHouseRiteDetailText(
        day,
        discreet: discreet,
        lens: lens,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: dawnHouseRiteActionId(day),
        behaviorPayload: dawnHouseRiteBehaviorPayload(
          day: day,
          schedule: occurrence,
          discreet: discreet,
          lens: lens,
        ),
        caller: 'dawn_house_rite_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'dawnHouseRiteHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinEveningThresholdRiteHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    bool discreet = false,
    EveningThresholdRiteLens lens = EveningThresholdRiteLens.neutral,
    int fallbackMinutesAfterMidnight = kEveningThresholdDefaultFallbackMinutes,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final days = _eveningThresholdRiteDays;
    if (days.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ??
          _resolveEveningThresholdRiteDefaultStartDate(
            timezone,
            fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
          ),
    );
    final occurrences = <EveningThresholdOccurrenceSchedule>[
      for (var i = 0; i < days.length; i++)
        _eveningThresholdScheduleForDate(
          firstGregorian.add(Duration(days: i)),
          timezone,
          fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
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
      'evening_tz=${timezone.key}',
      'evening_discreet=${discreet ? 1 : 0}',
      'evening_lens=${lens.key}',
      'evening_fallback=$fallbackMinutesAfterMidnight',
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
      final title = eveningThresholdRiteEventTitle(day);
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
      final detail = eveningThresholdRiteDetailText(
        day,
        discreet: discreet,
        lens: lens,
      );
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: eveningThresholdRiteActionId(day),
        behaviorPayload: eveningThresholdRiteBehaviorPayload(
          day: day,
          schedule: occurrence,
          discreet: discreet,
          lens: lens,
        ),
        caller: 'evening_threshold_rite_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'eveningThresholdRiteHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
    bool deferRemainingEvents = false,
  }) async {
    if (kEveningThresholdEvents.isEmpty || materializedDays <= 0) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ??
          defaultEveningThresholdStartDate(
            timezone,
            defaultMinutesAfterMidnight: defaultMinutesAfterMidnight,
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
    if (trimmedInitialCarry != null && trimmedInitialCarry.isNotEmpty) {
      await _persistEveningThresholdInitialCarry(
        localDate: firstGregorian,
        carryText: trimmedInitialCarry,
      );
    }

    Future<String> upsertOccurrence(int index, {required String caller}) async {
      final entry = schedules[index];
      final occurrence = occurrences[index];
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
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: eveningThresholdActionId(entry.event),
        behaviorPayload: eveningThresholdBehaviorPayload(
          event: entry.event,
          schedule: occurrence,
        ),
        caller: caller,
      );

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
      return clientEventId;
    }

    final clientEventIds = <String>[];
    final firstReturnIndex = schedules.indexWhere(
      (entry) => entry.event.kind == EveningThresholdEventKind.theReturn,
    );
    final synchronousIndexes = deferRemainingEvents
        ? <int>{firstReturnIndex >= 0 ? firstReturnIndex : 0}
        : {for (var i = 0; i < schedules.length; i++) i};
    for (final index in synchronousIndexes) {
      clientEventIds.add(
        await upsertOccurrence(
          index,
          caller: 'evening_threshold_join_headless',
        ),
      );
    }

    if (deferRemainingEvents && schedules.length > synchronousIndexes.length) {
      final deferredIndexes = <int>[
        for (var i = 0; i < schedules.length; i++)
          if (!synchronousIndexes.contains(i)) i,
      ];
      unawaited(
        Future<void>(() async {
          final deferredClientEventIds = <String>[];
          for (final index in deferredIndexes) {
            try {
              deferredClientEventIds.add(
                await upsertOccurrence(
                  index,
                  caller: 'evening_threshold_join_headless_deferred',
                ),
              );
            } catch (error, stackTrace) {
              if (kDebugMode) {
                _calendarDebugPrint(
                  '[eveningThresholdHeadless] deferred event creation failed: $error',
                );
                _calendarDebugPrint('$stackTrace');
              }
            }
          }
          if (deferredClientEventIds.isNotEmpty) {
            _publishHeadlessCalendarInvalidation(
              reason: CalendarInvalidationReason.flowJoined,
              flowId: flowId,
              clientEventIds: deferredClientEventIds,
            );
          }
        }),
      );
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinTheWeighingHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    TheWeighingLens lens = TheWeighingLens.neutral,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final events = _theWeighingEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ?? _resolveTheWeighingDefaultStartDate(timezone),
    );
    final occurrences = <TheWeighingOccurrenceSchedule>[
      for (final event in events)
        _theWeighingScheduleForDate(
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
      'weighing_tz=${timezone.key}',
      'weighing_lens=${lens.key}',
      'weighing_midday_hour=$kTheWeighingDefaultMiddayHour',
      'weighing_midday_minute=$kTheWeighingDefaultMiddayMinute',
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
      final k = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startLocal),
      );
      final title = theWeighingEventTitle(event);
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
      final detail = theWeighingDetailText(event, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: theWeighingActionId(event),
        behaviorPayload: theWeighingBehaviorPayload(
          event: event,
          schedule: occurrence,
          lens: lens,
        ),
        caller: 'the_weighing_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'theWeighingHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
      startDate ?? _resolveOfferingTableDefaultStartDate(timezone),
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
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinTheTendingHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    TheTendingLens lens = TheTendingLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final events = _theTendingEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ?? _resolveTheTendingDefaultStartDate(timezone),
    );
    final occurrences = <TheTendingOccurrenceSchedule>[
      for (final event in events)
        _theTendingScheduleForDate(
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
      'tending_tz=${timezone.key}',
      'tending_lens=${lens.key}',
      'tending_midday_hour=$kTheTendingDefaultMiddayHour',
      'tending_midday_minute=$kTheTendingDefaultMiddayMinute',
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
      final k = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startLocal),
      );
      final title = theTendingEventTitle(event);
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
      final detail = theTendingDetailText(event, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: theTendingActionId(event),
        behaviorPayload: theTendingBehaviorPayload(
          event: event,
          schedule: occurrence,
          lens: lens,
        ),
        caller: 'the_tending_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'theTendingHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinReadingHouseHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    ReadingHousePlan plan = const ReadingHousePlan(),
    List<ReadingHouseSitting>? readingHouseSittings,
    int alertOffsetMinutes = kEventFilingNoAlertMinutes,
  }) async {
    final sittings = normalizeReadingHouseSittingOrder(
      readingHouseSittings ?? kReadingHouseSittings,
    );
    if (sittings.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ?? defaultReadingHouseStartDate(timezone),
    );
    final occurrences = <ReadingHouseOccurrenceSchedule>[
      for (final sitting in sittings)
        readingHouseScheduleForSitting(sitting, firstGregorian, timezone),
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
      'reading_house_tz=${timezone.key}',
      ...readingHouseFlowNoteTokens(plan),
      'reading_house_hour=$kReadingHouseDefaultHour',
      'reading_house_minute=$kReadingHouseDefaultMinute',
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
    for (var i = 0; i < sittings.length; i++) {
      final sitting = sittings[i];
      final occurrence = occurrences[i];
      final k = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startLocal),
      );
      final title = readingHouseSittingTitle(sitting);
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
      final detail = readingHouseDetailText(sitting, plan: plan);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Study',
        actionId: readingHouseActionId(sitting),
        behaviorPayload: readingHouseBehaviorPayload(
          sitting: sitting,
          schedule: occurrence,
          plan: plan,
        ),
        caller: 'reading_house_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'readingHouseHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
  }

  Future<FlowJoinResult> joinKeptWordHeadless({
    required String templateKey,
    required String templateTitle,
    required String templateOverview,
    required Color templateColor,
    required String? personalCalendarId,
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
    KeptWordLens lens = KeptWordLens.neutral,
    int alertOffsetMinutes = 0,
  }) async {
    final events = _keptWordEvents;
    if (events.isEmpty) {
      return const FlowJoinResult.failure(FlowJoinFailureCode.noOccurrences);
    }

    final firstGregorian = DateUtils.dateOnly(
      startDate ?? _resolveKeptWordDefaultStartDate(timezone),
    );
    final occurrences = <KeptWordOccurrenceSchedule>[
      for (final event in events)
        _keptWordScheduleForDate(
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
      'kept_word_tz=${timezone.key}',
      'kept_word_lens=${lens.key}',
      'kept_word_midday_hour=$kKeptWordDefaultMiddayHour',
      'kept_word_midday_minute=$kKeptWordDefaultMiddayMinute',
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
      final k = KemeticMath.fromGregorian(
        DateUtils.dateOnly(occurrence.startLocal),
      );
      final title = keptWordEventTitle(event);
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
      final detail = keptWordDetailText(event, lens: lens);
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: keptWordActionId(event),
        behaviorPayload: keptWordBehaviorPayload(
          event: event,
          schedule: occurrence,
          lens: lens,
        ),
        caller: 'the_kept_word_join_headless',
      );
      clientEventIds.add(clientEventId);
      if (alertOffsetMinutes != kEventFilingNoAlertMinutes) {
        await _fileHeadlessJoinDelivery(
          debugLabel: 'keptWordHeadless',
          clientEventId: clientEventId,
          startsAtLocal: occurrence.startLocal,
          alertOffsetMinutes: alertOffsetMinutes,
          title: title,
          body: detail,
        );
      }
    }

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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
      startDate ?? _resolveTheCourseDefaultStartDate(timezone),
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
      await _upsertEventRow(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: occurrence.startUtc,
        detail: detail,
        allDay: false,
        endsAtUtc: occurrence.endUtc,
        calendarId: personalCalendarId,
        flowLocalId: flowId,
        category: 'Ritual',
        actionId: courseActionId(event),
        behaviorPayload: courseBehaviorPayload(
          event: event,
          schedule: occurrence,
          lens: lens,
          context: context,
        ),
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

    return _completeHeadlessJoin(
      flowId: flowId,
      clientEventIds: clientEventIds,
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

  FlowJoinResult _completeHeadlessJoin({
    required int flowId,
    required List<String> clientEventIds,
  }) {
    _publishHeadlessCalendarInvalidation(
      reason: CalendarInvalidationReason.flowJoined,
      flowId: flowId,
      clientEventIds: clientEventIds,
    );
    return FlowJoinResult.success(
      flowId: flowId,
      clientEventIds: List.unmodifiable(clientEventIds),
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
  }) {
    final upsert = _upsertFlow;
    if (upsert != null) {
      return upsert(
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
    }
    return _repo.upsertFlow(
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
  }

  Future<void> _upsertEventRow({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    bool allDay = false,
    DateTime? endsAtUtc,
    int? flowLocalId,
    String? category,
    String? actionId,
    Map<String, dynamic>? behaviorPayload,
    String? calendarId,
    String? caller,
  }) async {
    final upsert = _upsertEvent;
    if (upsert != null) {
      return upsert(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: startsAtUtc,
        detail: detail,
        allDay: allDay,
        endsAtUtc: endsAtUtc,
        flowLocalId: flowLocalId,
        category: category,
        actionId: actionId,
        behaviorPayload: behaviorPayload,
        calendarId: calendarId,
        caller: caller,
      );
    }
    await _repo.upsertByClientId(
      clientEventId: clientEventId,
      title: title,
      startsAtUtc: startsAtUtc,
      detail: detail,
      allDay: allDay,
      endsAtUtc: endsAtUtc,
      flowLocalId: flowLocalId,
      category: category,
      actionId: actionId,
      behaviorPayload: behaviorPayload,
      calendarId: calendarId,
      caller: caller,
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

  static DateTime _defaultMoonReturnNowInZone(TrackSkyTimeZone timezone) {
    return moonReturnNowInZone(timezone);
  }

  static WagEnrollmentWindow? _defaultResolveWagWindow({
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
  }) {
    return resolveWagEnrollmentWindowSafely(
      timezone: timezone,
      startDate: startDate,
    );
  }

  static WagOccurrenceSchedule _defaultWagScheduleForEvent({
    required WagEvent event,
    required int kYear,
    required TrackSkyTimeZone timezone,
  }) {
    return wagScheduleForEvent(event: event, kYear: kYear, timezone: timezone);
  }

  static DateTime _defaultWagNowInZone(TrackSkyTimeZone timezone) {
    return wagNowInZone(timezone);
  }

  static DaysOutsideYearEnrollmentWindow? _defaultResolveDaysOutsideYearWindow({
    required TrackSkyTimeZone timezone,
    DateTime? startDate,
  }) {
    return resolveDaysOutsideYearEnrollmentWindowSafely(
      timezone: timezone,
      startDate: startDate,
    );
  }

  static DaysOutsideOccurrenceSchedule _defaultDaysOutsideYearScheduleForEvent({
    required DaysOutsideEvent event,
    required int closingKYear,
    required TrackSkyTimeZone timezone,
  }) {
    return daysOutsideScheduleForEvent(
      event: event,
      closingKYear: closingKYear,
      timezone: timezone,
    );
  }

  static DateTime _defaultDaysOutsideYearNowInZone(TrackSkyTimeZone timezone) {
    return daysOutsideNowInZone(timezone);
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

  static DateTime _defaultDecanWatchNowInZone(TrackSkyTimeZone timezone) {
    return decanWatchNowInZone(timezone);
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

  static DateTime _defaultOpenHandNowInZone(TrackSkyTimeZone timezone) {
    return openHandNowInZone(timezone);
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
    required DjedEvent event,
    required DateTime flowStart,
    required TrackSkyTimeZone timezone,
  }) {
    return djedScheduleForEvent(event, flowStart, timezone);
  }

  static DateTime _defaultDjedNowInZone(TrackSkyTimeZone timezone) {
    return djedNowInZone(timezone);
  }

  static DateTime _defaultResolveDawnHouseRiteStartDate(
    TrackSkyTimeZone timezone,
  ) {
    return defaultDawnHouseRiteStartDate(timezone);
  }

  static DawnHouseRiteOccurrenceSchedule _defaultDawnHouseRiteScheduleForDate(
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return dawnHouseRiteScheduleForDate(date, timezone);
  }

  static DateTime _defaultResolveEveningThresholdRiteStartDate(
    TrackSkyTimeZone timezone, {
    required int fallbackMinutesAfterMidnight,
  }) {
    return defaultEveningThresholdRiteStartDate(
      timezone,
      fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
    );
  }

  static EveningThresholdOccurrenceSchedule
  _defaultEveningThresholdScheduleForDate(
    DateTime date,
    TrackSkyTimeZone timezone, {
    required int fallbackMinutesAfterMidnight,
  }) {
    return eveningThresholdScheduleForDate(
      date,
      timezone,
      fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
    );
  }

  static DateTime _defaultResolveTheWeighingStartDate(
    TrackSkyTimeZone timezone,
  ) {
    return defaultTheWeighingStartDate(timezone);
  }

  static TheWeighingOccurrenceSchedule _defaultTheWeighingScheduleForDate(
    TheWeighingEvent event,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return theWeighingScheduleForDate(event, date, timezone);
  }

  static DateTime _defaultResolveOfferingTableStartDate(
    TrackSkyTimeZone timezone,
  ) {
    return defaultOfferingTableStartDate(timezone);
  }

  static OfferingTableOccurrenceSchedule _defaultOfferingTableScheduleForDate(
    OfferingTableDay day,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return offeringTableScheduleForDate(day, date, timezone);
  }

  static DateTime _defaultResolveTheTendingStartDate(
    TrackSkyTimeZone timezone,
  ) {
    return defaultTheTendingStartDate(timezone);
  }

  static TheTendingOccurrenceSchedule _defaultTheTendingScheduleForDate(
    TheTendingEvent event,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return theTendingScheduleForDate(event, date, timezone);
  }

  static DateTime _defaultResolveKeptWordStartDate(TrackSkyTimeZone timezone) {
    return defaultKeptWordStartDate(timezone);
  }

  static KeptWordOccurrenceSchedule _defaultKeptWordScheduleForDate(
    KeptWordEvent event,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return keptWordScheduleForDate(event, date, timezone);
  }

  static DateTime _defaultResolveTheCourseStartDate(TrackSkyTimeZone timezone) {
    return defaultTheCourseStartDate(timezone);
  }

  static CourseOccurrenceSchedule _defaultCourseScheduleForDate(
    CourseEvent event,
    DateTime date,
    TrackSkyTimeZone timezone,
  ) {
    return courseScheduleForDate(event, date, timezone);
  }
}
