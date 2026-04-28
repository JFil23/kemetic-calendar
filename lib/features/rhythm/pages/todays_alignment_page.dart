import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/page_navigation_swipe.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/data/flow_onboarding_state_repo.dart';
import 'package:mobile/data/flow_progress_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/core/kemetic_converter.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/todo_day_window.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';
import 'package:mobile/services/app_haptics.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/inbox_icon_with_badge.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/session_resume_service.dart';

import 'package:mobile/core/day_key.dart';
import '../data/planner_badge_repo.dart';
import '../data/rhythm_repo.dart';
import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import '../widgets/rhythm_section_card.dart';
import '../widgets/rhythm_state_button.dart';
import '../widgets/rhythm_states.dart';
import '../widgets/rhythm_todo_row.dart';

class TodaysAlignmentPage extends StatefulWidget {
  const TodaysAlignmentPage({
    super.key,
    this.embedded = false,
    this.openedFromCalendar = false,
    this.openedFromCalendarSwipe = false,
  });

  final bool embedded;
  final bool openedFromCalendar;
  final bool openedFromCalendarSwipe;

  @override
  State<TodaysAlignmentPage> createState() => _TodaysAlignmentPageState();
}

class _TodaysAlignmentPageState extends State<TodaysAlignmentPage> {
  static const String _sessionScopeKey = 'today_alignment_page';
  static const Gradient _plannerReflectionGloss = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFFF1BF),
      Color(0xFFF2CF63),
      Color(0xFFFFF8D9),
      Color(0xFFF4D97A),
    ],
    stops: [0.0, 0.34, 0.62, 1.0],
  );

  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);
  final NutritionRepo _nutritionRepo = NutritionRepo(Supabase.instance.client);
  final PlannerBadgeRepo _plannerBadgeRepo = PlannerBadgeRepo(
    Supabase.instance.client,
  );
  final FlowOnboardingStateRepo _flowOnboardingStateRepo =
      FlowOnboardingStateRepo();
  final FlowProgressRepo _flowProgressRepo = FlowProgressRepo(
    Supabase.instance.client,
  );
  late Future<void> _future;
  final TextEditingController _commitmentInputController =
      TextEditingController();
  final TextEditingController _noteInputController = TextEditingController();
  late PageController _todoPageController;
  final PageController _notePageController = PageController(
    viewportFraction: 0.9,
  );
  late PageController _nutritionPageController;
  PageController? _fullscreenPageController;
  final KemeticConverter _kemeticConverter = KemeticConverter();
  int? _pendingTodoPageIndex;
  bool _pendingTodoPageAnimate = false;
  bool _todoPageJumpScheduled = false;

  final TextEditingController _nutritionNutrientController =
      TextEditingController();
  final TextEditingController _nutritionSourceController =
      TextEditingController();
  final TextEditingController _nutritionPurposeController =
      TextEditingController();

  List<RhythmItem> _alignmentItems = [];
  List<RhythmTodo> _todos = [];
  Map<DateTime, List<RhythmTodo>> _todosByDay = {};
  List<DateTime> _todoDays = [];
  List<RhythmNote> _notes = [];
  int _activeNoteIndex = 0;
  int _activeTodoDayIndex = defaultTodoPreviousDayCount;
  RhythmNote? _fullscreenNote;
  bool _isSyncingNotePages = false;
  bool _missingTables = false;
  String? _friendlyError;
  bool _notesLocalOnly = false;
  bool _notesLocalNoticeShown = false;
  bool _showGregorianDates = false;
  Timer? _midnightTimer;
  List<NutritionItem> _nutritionItems = [];
  Map<String, RhythmItemState> _nutritionStatesByKey = {};
  bool _nutritionLoading = true;
  bool _nutritionMissingTable = false;
  String? _nutritionError;
  bool _nutritionStatesLoaded = false;
  int _activeNutritionDayIndex = 0;
  bool _nutritionFormOpen = false;
  bool _calendarRevealNavigationInFlight = false;
  bool _flowActivationPromptScheduled = false;
  bool _flowActivationInFlight = false;
  Timer? _sessionPersistDebounce;

  bool get _tracksSessionState =>
      !widget.embedded &&
      !widget.openedFromCalendar &&
      !widget.openedFromCalendarSwipe;

  PageController _buildTodoPageController(int initialPage) {
    return PageController(viewportFraction: 0.96, initialPage: initialPage);
  }

  void _resetTodoPageController(int initialPage) {
    final previous = _todoPageController;
    _todoPageController = _buildTodoPageController(initialPage);
    previous.dispose();
  }

  @override
  void initState() {
    super.initState();
    _todoDays = buildTodoDayWindow(anchorDay: _todayLocal);
    _todosByDay = {for (final day in _todoDays) day: <RhythmTodo>[]};
    _todoPageController = _buildTodoPageController(_activeTodoDayIndex);
    _activeNutritionDayIndex = (_currentDecanDay() - 1).clamp(0, 9);
    _nutritionPageController = PageController(
      viewportFraction: 0.94,
      initialPage: _activeNutritionDayIndex,
    );
    _bindSessionListeners();
    final restoreFuture = _restoreSessionState();
    _future = restoreFuture.then((_) => _load());
    unawaited(restoreFuture.then((_) => _loadNotes()));
    unawaited(_loadNutrition());
    unawaited(_loadNutritionStates());
    _scheduleMidnightRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        RhythmTelemetry.trackScreen(
          Supabase.instance.client,
          'today_alignment',
        ),
      );
      unawaited(_maybePromptFlowActivationOnboarding());
    });
  }

  @override
  void dispose() {
    _sessionPersistDebounce?.cancel();
    _commitmentInputController.dispose();
    _noteInputController.dispose();
    _todoPageController.dispose();
    _notePageController.dispose();
    _nutritionNutrientController.dispose();
    _nutritionSourceController.dispose();
    _nutritionPurposeController.dispose();
    _nutritionPageController.dispose();
    _fullscreenPageController?.dispose();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _bindSessionListeners() {
    if (!_tracksSessionState) return;
    _commitmentInputController.addListener(_persistSessionStateSoon);
    _noteInputController.addListener(_persistSessionStateSoon);
    _nutritionNutrientController.addListener(_persistSessionStateSoon);
    _nutritionSourceController.addListener(_persistSessionStateSoon);
    _nutritionPurposeController.addListener(_persistSessionStateSoon);
  }

  Future<void> _restoreSessionState() async {
    if (!_tracksSessionState) return;
    final state = await SessionResumeService.readScopedState(_sessionScopeKey);
    if (!mounted || state == null) return;

    _commitmentInputController.text = state['commitmentDraft'] as String? ?? '';
    _noteInputController.text = state['noteDraft'] as String? ?? '';
    _nutritionNutrientController.text =
        state['nutritionNutrientDraft'] as String? ?? '';
    _nutritionSourceController.text =
        state['nutritionSourceDraft'] as String? ?? '';
    _nutritionPurposeController.text =
        state['nutritionPurposeDraft'] as String? ?? '';
    _activeNoteIndex = ((state['activeNoteIndex'] as num?)?.toInt() ?? 0).clamp(
      0,
      1 << 20,
    );
    _activeNutritionDayIndex =
        ((state['activeNutritionDayIndex'] as num?)?.toInt() ??
                _activeNutritionDayIndex)
            .clamp(0, 9);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_nutritionPageController.hasClients) return;
      _nutritionPageController.jumpToPage(_activeNutritionDayIndex);
    });
  }

  void _persistSessionStateSoon() {
    if (!_tracksSessionState) return;
    _sessionPersistDebounce?.cancel();
    _sessionPersistDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistSessionState());
    });
  }

  Future<void> _persistSessionState() async {
    if (!_tracksSessionState) return;
    await SessionResumeService.saveScopedState(_sessionScopeKey, {
      'commitmentDraft': _commitmentInputController.text,
      'noteDraft': _noteInputController.text,
      'nutritionNutrientDraft': _nutritionNutrientController.text,
      'nutritionSourceDraft': _nutritionSourceController.text,
      'nutritionPurposeDraft': _nutritionPurposeController.text,
      'activeNoteIndex': _activeNoteIndex,
      'activeNutritionDayIndex': _activeNutritionDayIndex,
    });
  }

  void _syncNotePageToActiveIndex() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_notePageController.hasClients || _notes.isEmpty) return;
      final clamped = _clampNoteIndex(_notes.length);
      final currentPage = (_notePageController.page ?? clamped.toDouble())
          .round();
      if (currentPage != clamped) {
        _notePageController.jumpToPage(clamped);
      }
    });
  }

  Future<void> _load() async {
    try {
      final itemsFuture = _repo.fetchTodaysAlignment();
      final todosFuture = _repo.fetchTodos();
      final items = await itemsFuture;
      final todos = await todosFuture;
      if (!mounted) return;
      final focusDay = _sameDay(_currentTodoWindowAnchorDay(), _todayLocal)
          ? _activeTodoDay
          : _todayLocal;
      final repoErr = items.friendlyError ?? todos.friendlyError;
      setState(() {
        _missingTables = items.missingTables || todos.missingTables;
        _friendlyError = repoErr != null
            ? RhythmUserMessages.loadFailedTodayAlignment
            : null;
        _alignmentItems = items.data;
      });
      _hydrateTodos(todos.data, focusDay: focusDay);
      _persistSessionStateSoon();
      unawaited(_reconcileTodoPlannerBadges(todos.data));
    } catch (_) {
      final windowDays = buildTodoDayWindow(anchorDay: _todayLocal);
      if (!mounted) return;
      setState(() {
        _missingTables = false;
        _friendlyError = RhythmUserMessages.loadFailedTodayAlignment;
        _alignmentItems = [];
        _todos = [];
        _todoDays = windowDays;
        _todosByDay = {for (final day in windowDays) day: <RhythmTodo>[]};
        _activeTodoDayIndex = resolveTodoDayWindowIndex(
          windowDays,
          today: _todayLocal,
        );
      });
      _persistSessionStateSoon();
    }
  }

  Future<void> _loadNutrition() async {
    setState(() {
      _nutritionLoading = true;
      _nutritionError = null;
      _nutritionMissingTable = false;
    });
    try {
      final items = await _nutritionRepo.getAll();
      if (!mounted) return;
      setState(() {
        _nutritionItems = items;
        _nutritionLoading = false;
      });
      if (_nutritionStatesLoaded) {
        unawaited(_reconcileNutritionPlannerBadges());
      }
    } on StateError catch (e) {
      final msg = e.toString().toLowerCase();
      final missing = msg.contains('nutrition_items');
      if (!mounted) return;
      setState(() {
        _nutritionItems = [];
        _nutritionLoading = false;
        _nutritionMissingTable = missing;
        _nutritionError = missing
            ? 'Nutrition storage is not available in this environment yet.'
            : 'Could not load nutrition sources.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nutritionItems = [];
        _nutritionLoading = false;
        _nutritionError = 'Could not load nutrition sources.';
      });
    }
  }

  Future<void> _addNutritionItem() async {
    final nutrient = _nutritionNutrientController.text.trim();
    final source = _nutritionSourceController.text.trim();
    final purpose = _nutritionPurposeController.text.trim();
    final decanDay = _activeNutritionDayIndex + 1;
    if (nutrient.isEmpty && source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a nutrient or source first.')),
      );
      return;
    }
    if (_nutritionMissingTable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nutrition storage is not available in this environment yet.',
          ),
        ),
      );
      return;
    }
    final newItem = NutritionItem(
      id: '',
      nutrient: nutrient,
      source: source,
      purpose: purpose,
      enabled: true,
      schedule: IntakeSchedule(
        mode: IntakeMode.decan,
        decanDays: {decanDay},
        daysOfWeek: const {},
        repeat: true,
        time: const TimeOfDay(hour: 9, minute: 0),
      ),
    );
    try {
      final saved = await _nutritionRepo.upsert(newItem);
      if (!mounted) return;
      setState(() {
        _nutritionItems = [..._nutritionItems, saved];
      });
      _nutritionNutrientController.clear();
      _nutritionSourceController.clear();
      _nutritionPurposeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Day $decanDay of this decan.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save nutrition item.')),
      );
    }
  }

  Future<List<NutritionItem>> _saveNutritionItemEdits(
    List<NutritionItem> items,
  ) async {
    final savedItems = <NutritionItem>[];
    for (final item in items) {
      savedItems.add(await _nutritionRepo.upsert(item));
    }
    if (!mounted) return savedItems;

    final savedById = {for (final item in savedItems) item.id: item};
    setState(() {
      _nutritionItems = [
        for (final item in _nutritionItems) savedById[item.id] ?? item,
      ];
    });
    return savedItems;
  }

  Future<void> _persistTodoState(int index, RhythmItemState state) async {
    final activeDay = _activeTodoDay;
    final dayTodos = [...(_todosByDay[activeDay] ?? _todos)];
    if (index < 0 || index >= dayTodos.length) return;
    final id = dayTodos[index].id;
    if (id.isEmpty) return;
    final prev = dayTodos[index].state;
    final updated = [
      for (int i = 0; i < dayTodos.length; i++)
        if (i == index)
          RhythmTodo(
            id: dayTodos[i].id,
            title: dayTodos[i].title,
            notes: dayTodos[i].notes,
            dueDate: dayTodos[i].dueDate,
            dueTime: dayTodos[i].dueTime,
            isChecklist: dayTodos[i].isChecklist,
            isCalendar: dayTodos[i].isCalendar,
            state: state,
          )
        else
          dayTodos[i],
    ];
    _updateTodosForDay(activeDay, updated);
    final result = await _repo.updateTodoState(id, state);
    if (!mounted) return;
    if (result.friendlyError != null || result.missingTables) {
      final reverted = [
        for (int i = 0; i < updated.length; i++)
          if (i == index)
            RhythmTodo(
              id: updated[i].id,
              title: updated[i].title,
              notes: updated[i].notes,
              dueDate: updated[i].dueDate,
              dueTime: updated[i].dueTime,
              isChecklist: updated[i].isChecklist,
              isCalendar: updated[i].isCalendar,
              state: prev,
            )
          else
            updated[i],
      ];
      _updateTodosForDay(activeDay, reverted);
      final msg = result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not update task.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    if (state == RhythmItemState.done && prev != RhythmItemState.done) {
      unawaited(AppHaptics.productiveAction());
    }

    var synced = false;
    try {
      await _plannerBadgeRepo.syncTodoState(
        todo: updated[index],
        date: activeDay,
      );
      synced = true;
    } catch (_) {
      synced = false;
    }
    if (synced) {
      unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
    }
  }

  Future<void> _commitNewTodo() async {
    final text = _commitmentInputController.text;
    if (text.trim().isEmpty) {
      return;
    }
    final result = await _repo.insertTodaysCommitment(
      text,
      dueDate: _activeTodoDay,
    );
    if (!mounted) return;
    if (result.friendlyError != null || result.missingTables) {
      final msg = result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not add task.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    final savedTodo = result.data;
    if (savedTodo == null) return;
    _commitmentInputController.clear();
    _appendTodoToDay(savedTodo);
  }

  String _prefsKeyForUser(String? uid) =>
      'today_alignment_notes${uid == null ? '' : '_$uid'}';

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  DateTime get _todayLocal => DateUtils.dateOnly(DateTime.now());

  String _nutritionChecksPrefsKeyForUser(String? uid) =>
      'today_alignment_nutrition_checks${uid == null ? '' : '_$uid'}';

  String _nutritionBadgeMigrationPrefsKeyForUser(String? uid) =>
      'today_alignment_nutrition_badges_migrated${uid == null ? '' : '_$uid'}';

  Future<bool> _hasMigratedNutritionBadgeState([String? uid]) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          _nutritionBadgeMigrationPrefsKeyForUser(uid ?? _currentUserId),
        ) ??
        false;
  }

  Future<void> _markNutritionBadgeStateMigrated({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _nutritionBadgeMigrationPrefsKeyForUser(uid ?? _currentUserId),
      true,
    );
  }

  Future<Map<String, RhythmItemState>> _loadNutritionStatesFromPrefs([
    String? uid,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues =
        prefs.getStringList(
          _nutritionChecksPrefsKeyForUser(uid ?? _currentUserId),
        ) ??
        const <String>[];
    final states = <String, RhythmItemState>{};
    RhythmItemState? parseState(String stateName) {
      for (final state in RhythmItemState.values) {
        if (state.name == stateName) return state;
      }
      return null;
    }

    for (final raw in rawValues) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('::');
      if (parts.length >= 3) {
        final key = '${parts[0]}::${parts[1]}';
        final stateName = parts.sublist(2).join('::');
        final state = parseState(stateName);
        if (state != null && state != RhythmItemState.pending) {
          states[key] = state;
        }
        continue;
      }
      if (parts.length == 2) {
        states[trimmed] = RhythmItemState.done;
      }
    }
    return states;
  }

  Future<void> _saveNutritionStatesToPrefs(
    Map<String, RhythmItemState> states, {
    String? uid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final values =
        states.entries
            .where((entry) => entry.value != RhythmItemState.pending)
            .map((entry) => '${entry.key}::${entry.value.name}')
            .toList()
          ..sort();
    await prefs.setStringList(
      _nutritionChecksPrefsKeyForUser(uid ?? _currentUserId),
      values,
    );
  }

  ({DateTime start, DateTime end}) _currentNutritionDecanRange() {
    return (
      start: _nutritionDateForPageIndex(0),
      end: _nutritionDateForPageIndex(9),
    );
  }

  bool _nutritionStateKeyInRange(
    String key,
    ({DateTime start, DateTime end}) range,
  ) {
    final parts = key.split('::');
    if (parts.length < 2) return false;
    final parsedDate = DateTime.tryParse(parts.first);
    if (parsedDate == null) return false;
    final day = _normalizeDate(parsedDate);
    return !day.isBefore(_normalizeDate(range.start)) &&
        !day.isAfter(_normalizeDate(range.end));
  }

  Map<String, RhythmItemState> _mergeNutritionStatesWithServerAuthority(
    Map<String, RhythmItemState> localStates,
    Map<String, RhythmItemState> remoteStates,
    ({DateTime start, DateTime end}) range,
  ) {
    final merged = <String, RhythmItemState>{};
    localStates.forEach((key, value) {
      if (_nutritionStateKeyInRange(key, range)) return;
      merged[key] = value;
    });
    merged.addAll(remoteStates);
    return merged;
  }

  Future<void> _loadNutritionStates() async {
    final range = _currentNutritionDecanRange();
    final localStatesFuture = _loadNutritionStatesFromPrefs();
    final migratedFuture = _hasMigratedNutritionBadgeState();
    final remoteStatesFuture = _plannerBadgeRepo.fetchNutritionStateMap(
      start: range.start,
      end: range.end,
    );
    final localStates = await localStatesFuture;
    final migrated = await migratedFuture;
    Map<String, RhythmItemState> remoteStates = const {};
    var remoteLoaded = false;
    try {
      remoteStates = await remoteStatesFuture;
      remoteLoaded = true;
    } catch (_) {
      remoteStates = const {};
      remoteLoaded = false;
    }
    final mergedStates = remoteLoaded && migrated
        ? _mergeNutritionStatesWithServerAuthority(
            localStates,
            remoteStates,
            range,
          )
        : <String, RhythmItemState>{...localStates, ...remoteStates};
    if (remoteLoaded && !migrated) {
      await _markNutritionBadgeStateMigrated();
    }
    await _saveNutritionStatesToPrefs(mergedStates);
    if (!mounted) return;
    setState(() {
      _nutritionStatesByKey = mergedStates;
      _nutritionStatesLoaded = true;
    });
    if (_nutritionItems.isNotEmpty) {
      unawaited(_reconcileNutritionPlannerBadges());
    }
  }

  int _decanDayForKemetic(KemeticDate kd) {
    if (kd.epagomenal) {
      return kd.day.clamp(1, 10);
    }
    return ((kd.day - 1) % 10) + 1;
  }

  int _currentDecanDay() {
    final kd = _kemeticConverter.fromGregorian(_todayLocal);
    return _decanDayForKemetic(kd);
  }

  String _currentDecanName() {
    final kd = _kemeticConverter.fromGregorian(_todayLocal);
    if (kd.epagomenal) return 'Epagomenal';
    return DecanMetadata.decanNameFor(kMonth: kd.month, kDay: kd.day);
  }

  DateTime _nutritionDateForPageIndex(int index) {
    final normalizedToday = _todayLocal;
    final offset = index - (_currentDecanDay() - 1);
    return _normalizeDate(normalizedToday.add(Duration(days: offset)));
  }

  DateTime _nutritionDateForDecanDay(int decanDay) {
    return _nutritionDateForPageIndex((decanDay.clamp(1, 10)) - 1);
  }

  String _nutritionCompletionKey(DateTime date, String itemId) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_normalizeDate(date));
    return '$dateKey::$itemId';
  }

  RhythmItemState _nutritionStateForItem(
    NutritionItem item, {
    int? decanDay,
    DateTime? date,
  }) {
    final targetDate =
        date ??
        (decanDay != null ? _nutritionDateForDecanDay(decanDay) : _todayLocal);
    return _nutritionStatesByKey[_nutritionCompletionKey(
          targetDate,
          item.id,
        )] ??
        RhythmItemState.pending;
  }

  Future<void> _setNutritionItemState(
    NutritionItem item, {
    required DateTime date,
    required RhythmItemState state,
  }) async {
    final key = _nutritionCompletionKey(date, item.id);
    final updatedStates = Map<String, RhythmItemState>.from(
      _nutritionStatesByKey,
    );
    if (state == RhythmItemState.pending) {
      updatedStates.remove(key);
    } else {
      updatedStates[key] = state;
    }
    setState(() {
      _nutritionStatesByKey = updatedStates;
    });
    await _saveNutritionStatesToPrefs(updatedStates);
    var synced = false;
    try {
      await _plannerBadgeRepo.syncNutritionState(
        item: item,
        date: date,
        state: state,
      );
      synced = true;
    } catch (_) {
      synced = false;
    }
    if (synced) {
      unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
    }
  }

  Future<void> _toggleNutritionItemDone(
    NutritionItem item, {
    required int decanDay,
  }) async {
    final targetDate = _nutritionDateForDecanDay(decanDay);
    final currentState = _nutritionStateForItem(item, date: targetDate);
    final nextState = currentState == RhythmItemState.done
        ? RhythmItemState.pending
        : RhythmItemState.done;
    await _setNutritionItemState(item, date: targetDate, state: nextState);
    if (nextState == RhythmItemState.done) {
      unawaited(AppHaptics.productiveAction());
    }
  }

  /// Resolves the Kemetic day key for the nutrition pager's active decan day.
  /// We anchor off today's decan so swiping days 1–10 lines up with the
  /// current decan block in the calendar.
  String _nutritionDayKeyForActivePage() {
    final kd = _kemeticConverter.fromGregorian(_todayLocal);
    final decanDayToday = _currentDecanDay();
    final baseDay = kd.day - (decanDayToday - 1); // day 1 of this decan
    final targetDay = (baseDay + _activeNutritionDayIndex).clamp(
      1,
      kd.epagomenal ? 5 : 30,
    );
    final kMonth = kd.epagomenal ? 13 : kd.month;
    return kemeticDayKey(kMonth, targetDay);
  }

  ({String dayKey, int kYear, String reflection})? _todayPlannerAction() {
    final kd = _kemeticConverter.fromGregorian(_todayLocal);
    final dayKey = kemeticDayKey(kd.epagomenal ? 13 : kd.month, kd.day);
    final info = KemeticDayData.getInfoForDay(dayKey);
    if (info == null) return null;

    for (final flowDay in info.decanFlow) {
      if (flowDay.day == kd.day) {
        return (dayKey: dayKey, kYear: kd.year, reflection: flowDay.reflection);
      }
    }

    return null;
  }

  Future<void> _openDecanInfo() async {
    final dayKey = _nutritionDayKeyForActivePage();
    final info = KemeticDayData.getInfoForDay(dayKey);
    if (info == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Decan details are not available yet.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DecanInfoPage(dayKey: dayKey, info: info),
      ),
    );
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime a, DateTime b) => DateUtils.isSameDay(a, b);

  DateTime get _activeTodoDay {
    if (_todoDays.isEmpty) return _todayLocal;
    final safeIndex = _activeTodoDayIndex
        .clamp(0, math.max(0, _todoDays.length - 1))
        .toInt();
    return _todoDays[safeIndex];
  }

  Map<DateTime, List<RhythmTodo>> _groupTodosByDay(List<RhythmTodo> todos) {
    final today = _todayLocal;
    final grouped = <DateTime, List<RhythmTodo>>{};
    for (final todo in todos) {
      final day = _normalizeDate(todo.dueDate ?? today);
      grouped.putIfAbsent(day, () => []).add(todo);
    }
    return grouped;
  }

  List<DateTime> _buildTodoDays(Map<DateTime, List<RhythmTodo>> grouped) {
    final today = _todayLocal;
    final days = buildTodoDayWindow(anchorDay: today);
    for (final d in days) {
      grouped.putIfAbsent(d, () => []);
    }
    return days;
  }

  DateTime _currentTodoWindowAnchorDay() {
    if (_todoDays.length <= defaultTodoPreviousDayCount) {
      return _todayLocal;
    }
    return _todoDays[defaultTodoPreviousDayCount];
  }

  void _hydrateTodos(List<RhythmTodo> todos, {DateTime? focusDay}) {
    final grouped = _groupTodosByDay(todos);
    final days = _buildTodoDays(grouped);
    final resolvedIndex = resolveTodoDayWindowIndex(
      days,
      today: _todayLocal,
      focusDay: focusDay,
    );
    final activeDay = days[resolvedIndex];
    setState(() {
      _todosByDay = grouped;
      _todoDays = days;
      _activeTodoDayIndex = resolvedIndex;
      _todos = grouped[activeDay] ?? [];
    });
    if (_todoPageController.hasClients) {
      _requestTodoPage(resolvedIndex);
      return;
    }
    if (_todoPageController.initialPage != resolvedIndex) {
      _resetTodoPageController(resolvedIndex);
    }
  }

  void _updateTodosForDay(DateTime day, List<RhythmTodo> updated) {
    final normalized = _normalizeDate(day);
    setState(() {
      _todosByDay = {..._todosByDay, normalized: updated};
      if (_sameDay(normalized, _activeTodoDay)) {
        _todos = updated;
      }
    });
  }

  void _appendTodoToDay(RhythmTodo todo) {
    final targetDay = _normalizeDate(todo.dueDate ?? _todayLocal);
    final current = _todosByDay[targetDay] ?? const <RhythmTodo>[];
    _updateTodosForDay(targetDay, [...current, todo]);
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      unawaited(_loadNutrition());
      unawaited(_loadNutritionStates());
      _scheduleMidnightRefresh();
    });
  }

  Future<void> _reconcileTodoPlannerBadges(List<RhythmTodo> todos) async {
    if (todos.isEmpty) return;
    final cutoff = _todayLocal.subtract(const Duration(days: 20));
    final futures = <Future<void>>[];
    for (final todo in todos) {
      final dueDay = _normalizeDate(todo.dueDate ?? _todayLocal);
      if (dueDay.isBefore(cutoff) || dueDay.isAfter(_todayLocal)) continue;
      futures.add(_plannerBadgeRepo.syncTodoState(todo: todo, date: dueDay));
    }
    if (futures.isEmpty) return;
    try {
      await Future.wait(futures);
    } catch (_) {
      return;
    }
    unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
  }

  Future<void> _reconcileNutritionPlannerBadges() async {
    if (_nutritionItems.isEmpty) return;
    final futures = <Future<void>>[];
    for (int decanDay = 1; decanDay <= 10; decanDay++) {
      final targetDate = _nutritionDateForDecanDay(decanDay);
      for (final item in _itemsForDecanDay(decanDay)) {
        futures.add(
          _plannerBadgeRepo.syncNutritionState(
            item: item,
            date: targetDate,
            state: _nutritionStateForItem(item, date: targetDate),
          ),
        );
      }
    }
    if (futures.isEmpty) return;
    try {
      await Future.wait(futures);
    } catch (_) {
      return;
    }
    unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
  }

  String _formatKemeticDate(DateTime date, {bool short = false}) {
    final kd = _kemeticConverter.fromGregorian(_normalizeDate(date));
    if (kd.epagomenal) {
      return short ? 'Epagomenal ${kd.day}' : 'Epagomenal Day ${kd.day}';
    }
    final monthName = getMonthById(kd.month).hellenized;
    final base = '$monthName ${kd.day}';
    if (short) {
      return base;
    }
    final season = getSeasonName(kd.month);
    final buffer = StringBuffer(base);
    buffer.write(' · $season');
    return buffer.toString();
  }

  String _formatDateLabel(DateTime date, {bool short = false}) {
    if (_showGregorianDates) {
      final fmt = short
          ? DateFormat('MMM d, yyyy')
          : DateFormat('EEEE · MMM d, yyyy');
      return fmt.format(_normalizeDate(date));
    }
    return _formatKemeticDate(date, short: short);
  }

  Color _dateAccentColor() {
    return _showGregorianDates
        ? blue
        : (RhythmTheme.subheading.color ?? Colors.white70);
  }

  List<NutritionItem> _itemsForDecanDay(int decanDay) {
    if (decanDay < 1 || decanDay > 10) return const [];
    final items = _nutritionItems
        .where(
          (n) =>
              n.enabled &&
              n.schedule.mode == IntakeMode.decan &&
              n.schedule.decanDays.contains(decanDay),
        )
        .toList();
    items.sort((a, b) {
      final aTime = a.schedule.time;
      final bTime = b.schedule.time;
      final hourCmp = aTime.hour.compareTo(bTime.hour);
      if (hourCmp != 0) return hourCmp;
      final minuteCmp = aTime.minute.compareTo(bTime.minute);
      if (minuteCmp != 0) return minuteCmp;
      return a.nutrient.toLowerCase().compareTo(b.nutrient.toLowerCase());
    });
    return items;
  }

  List<NutritionItem> _todayNutritionItems() {
    final kd = _kemeticConverter.fromGregorian(_todayLocal);
    return _itemsForDecanDay(_decanDayForKemetic(kd));
  }

  String _presentableText(String value, {String fallback = '—'}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _formatTodoDue(RhythmTodo todo, DateTime fallbackDay) {
    DateTime? day = todo.dueDate;
    if (day == null && todo.dueTime == null) {
      return null;
    }
    day ??= fallbackDay;
    final normalized = _normalizeDate(day);
    final dayText = _formatDateLabel(normalized, short: true);
    if (todo.dueTime == null) return dayText;
    final dt = DateTime(
      normalized.year,
      normalized.month,
      normalized.day,
      todo.dueTime!.hour,
      todo.dueTime!.minute,
    );
    final timeText = DateFormat('h:mm a').format(dt);
    return '$dayText · $timeText';
  }

  Future<void> _openCalendarMenu(BuildContext context) async {
    final calendarState = CalendarPage.globalKey.currentState;
    if (calendarState != null) {
      await calendarState.showActionsMenuFromOutside(
        context,
        includeNewNote: false,
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menu is unavailable right now.')),
    );
  }

  Future<void> _openCalendarQuickAdd() async {
    final calendarState = CalendarPage.globalKey.currentState;
    if (calendarState != null) {
      await calendarState.openQuickAddFromOutside();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New note is unavailable right now.')),
    );
  }

  void _openProfilePage() {
    final uid = _currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to view your profile.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: uid, isMyProfile: true),
      ),
    );
  }

  Future<void> _openFlowStudio({int? flowId}) async {
    final calendarState = CalendarPage.globalKey.currentState;
    if (calendarState != null) {
      await calendarState.openMyFlowsFromOutside(initialFlowId: flowId);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Flow Studio is unavailable right now.')),
    );
  }

  Future<void> _maybePromptFlowActivationOnboarding() async {
    if (_flowActivationPromptScheduled || !mounted || widget.embedded) {
      return;
    }
    final userId = _currentUserId;
    if (userId == null) return;
    _flowActivationPromptScheduled = true;

    final alreadySeen = await _flowOnboardingStateRepo.hasSeenActivationPrompt(
      userId,
    );
    if (!mounted || alreadySeen) return;

    final tracker = await _flowProgressRepo.loadPrimaryTracker();
    if (!mounted || tracker != null) return;

    await _flowOnboardingStateRepo.markActivationPromptSeen(userId);
    if (!mounted) return;
    await _openStandardFlowActivation(
      source: 'planner_first_session',
      autoPresented: true,
    );
  }

  Future<void> _openStandardFlowActivation({
    String source = 'planner_activation',
    bool autoPresented = false,
  }) async {
    if (_flowActivationInFlight || !mounted) return;
    _flowActivationInFlight = true;
    final tracker = UserEventsRepo(Supabase.instance.client);
    try {
      await tracker.track(
        event: 'flow_onboarding_started',
        properties: {
          'source': source,
          'auto_presented': autoPresented,
          'current_decan_name': _currentDecanName(),
          'current_decan_day': _currentDecanDay(),
        },
      );
      if (!mounted) return;
      await _openFlowStudio();
    } finally {
      _flowActivationInFlight = false;
    }
  }

  void _onTodoPageChanged(int index) {
    if (index < 0 || index >= _todoDays.length) return;
    setState(() {
      _activeTodoDayIndex = index;
      _todos = _todosByDay[_todoDays[index]] ?? [];
    });
    _persistSessionStateSoon();
  }

  double _todoPageHeightEstimate() {
    if (_todoDays.isEmpty) return 120;
    final count = _todosByDay[_activeTodoDay]?.length ?? _todos.length;
    if (count <= 0) return 120;
    final estimated = 110 + count * 90;
    return estimated.clamp(120, 420).toDouble();
  }

  void _requestTodoPage(int index, {bool animate = false}) {
    _pendingTodoPageIndex = index;
    _pendingTodoPageAnimate = animate;
    _scheduleTodoPageJump();
  }

  void _scheduleTodoPageJump() {
    if (_todoPageJumpScheduled) return;
    _todoPageJumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _todoPageJumpScheduled = false;
      if (!mounted) return;
      final target = _pendingTodoPageIndex;
      if (target == null) return;
      if (_todoPageController.hasClients) {
        if (_pendingTodoPageAnimate) {
          _todoPageController.animateToPage(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        } else {
          _todoPageController.jumpToPage(target);
        }
        _pendingTodoPageIndex = null;
        _pendingTodoPageAnimate = false;
      } else {
        _scheduleTodoPageJump();
      }
    });
  }

  Widget _buildTodoDayPage(DateTime day) {
    final todos = _todosByDay[day] ?? const <RhythmTodo>[];
    if (todos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Container(
          decoration: RhythmTheme.frostSurface(),
          padding: const EdgeInsets.all(14),
          child: Text(
            'No to-dos for this day. Add one above to anchor it.',
            style: RhythmTheme.subheading,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < todos.length; i++) ...[
            RhythmTodoRow(
              todo: todos[i],
              dueTextOverride: _formatTodoDue(todos[i], day),
              dueTextColor: _dateAccentColor(),
              onStateChanged: (state) => unawaited(_persistTodoState(i, state)),
            ),
            if (i != todos.length - 1)
              const Divider(height: 18, thickness: 0.6, color: Colors.white12),
          ],
        ],
      ),
    );
  }

  int _clampNoteIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activeNoteIndex;
    if (target < 0) return 0;
    if (target >= length) return length - 1;
    return target;
  }

  Future<List<RhythmNote>> _loadNotesFromPrefs([String? uid]) async {
    final userKey = _prefsKeyForUser(uid ?? _currentUserId);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(userKey) ?? [];
    return [
      for (int i = 0; i < stored.length; i++)
        () {
          // Try JSON payload first.
          try {
            final decoded = jsonDecode(stored[i]);
            if (decoded is Map<String, dynamic>) {
              return RhythmNote(
                id: (decoded['id'] as String?) ?? 'local_$i',
                text: (decoded['text'] as String?) ?? '',
                position: (decoded['position'] as num?)?.toInt() ?? i,
                createdAt:
                    DateTime.tryParse(decoded['createdAt'] as String? ?? '') ??
                    DateTime.now(),
              );
            }
          } catch (_) {
            // Fall through to legacy format.
          }
          // Legacy: text only.
          return RhythmNote(
            id: 'local_$i',
            text: stored[i],
            position: i,
            createdAt: DateTime.now(),
          );
        }(),
    ];
  }

  Future<void> _saveNotesToPrefs(List<RhythmNote> notes, {String? uid}) async {
    final userKey = _prefsKeyForUser(uid ?? _currentUserId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      userKey,
      notes
          .map(
            (n) => jsonEncode({
              'id': n.id,
              'text': n.text,
              'position': n.position,
              'createdAt': n.createdAt.toIso8601String(),
            }),
          )
          .toList(),
    );
  }

  void _showLocalNotesWarningOnce() {
    if (_notesLocalNoticeShown || !mounted) return;
    _notesLocalNoticeShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Planner notes are saved only on this device. Cloud sync is unavailable.',
        ),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isLocalNote(RhythmNote note) => note.id.startsWith('local_');

  List<RhythmNote> _withPositions(List<RhythmNote> notes) {
    return [
      for (int i = 0; i < notes.length; i++) notes[i].copyWith(position: i),
    ];
  }

  Future<void> _loadNotes() async {
    final uid = _currentUserId;
    final resultFuture = _repo.fetchAlignmentNotes();
    final cachedFuture = _loadNotesFromPrefs(uid);
    final result = await resultFuture;
    if (!mounted) return;

    final cached = await cachedFuture;

    final useLocalOnly =
        result.missingTables || result.friendlyError != null || uid == null;
    if (useLocalOnly) {
      _showLocalNotesWarningOnce();
      if (!mounted) return;
      setState(() {
        _notesLocalOnly = true;
        _notes = cached;
        _activeNoteIndex = _clampNoteIndex(cached.length);
        _fullscreenNote = null;
      });
      _syncNotePageToActiveIndex();
      _persistSessionStateSoon();
      return;
    }

    var notes = result.data;
    if (notes.isEmpty && cached.any(_isLocalNote)) {
      final inserted = <RhythmNote>[];
      for (int i = 0; i < cached.length; i++) {
        final res = await _repo.insertAlignmentNote(
          cached[i].text,
          position: i,
        );
        if (res.data != null) {
          inserted.add(res.data!);
        }
      }
      if (inserted.isNotEmpty) {
        notes = inserted;
      } else {
        notes = cached;
      }
    } else if (notes.isEmpty && cached.isNotEmpty) {
      // Remote empty but cached reflects previously synced notes; show cached
      // without re-inserting.
      notes = cached;
    } else if (notes.isNotEmpty && cached.any(_isLocalNote)) {
      final offlineAdds = cached.where(_isLocalNote).toList();
      final inserted = <RhythmNote>[];
      for (int i = 0; i < offlineAdds.length; i++) {
        final res = await _repo.insertAlignmentNote(
          offlineAdds[i].text,
          position: notes.length + i,
        );
        if (res.data != null) {
          inserted.add(res.data!);
        }
      }
      if (inserted.isNotEmpty) {
        notes = [...notes, ...inserted];
      }
    }

    await _saveNotesToPrefs(notes, uid: uid);
    if (!mounted) return;
    setState(() {
      _notesLocalOnly = false;
      _notes = notes;
      _activeNoteIndex = _clampNoteIndex(notes.length);
      _fullscreenNote = null;
    });
    _syncNotePageToActiveIndex();
    _persistSessionStateSoon();
  }

  Future<void> _addNote() async {
    final text = _noteInputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Write a note first.')));
      return;
    }

    final result = await _repo.insertAlignmentNote(
      text,
      position: _notes.length,
    );
    if (!mounted) return;

    if (result.missingTables) {
      _showLocalNotesWarningOnce();
      final fallback = RhythmNote(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        position: _notes.length,
        createdAt: DateTime.now(),
      );
      final updated = [..._notes, fallback];
      _noteInputController.clear();
      setState(() {
        _notesLocalOnly = true;
        _notes = updated;
        _activeNoteIndex = updated.length - 1;
        _fullscreenNote = null;
      });
      await _saveNotesToPrefs(updated);
      return;
    }

    if (result.friendlyError != null || result.data == null) {
      final msg = result.friendlyError ?? 'Could not save note.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final note = result.data!;
    final updated = [..._notes, note];
    _noteInputController.clear();
    setState(() {
      _notesLocalOnly = false;
      _notes = updated;
      _activeNoteIndex = updated.length - 1;
      _fullscreenNote = null;
    });
    await _saveNotesToPrefs(updated);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_notePageController.hasClients) return;
      _notePageController.animateToPage(
        _activeNoteIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showNotePicker() async {
    if (_notes.isEmpty) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KemeticGold.text(
                      'Your notes',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'GentiumPlus',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 360,
                    minHeight: 180,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    proxyDecorator: (child, index, animation) =>
                        Material(color: Colors.transparent, child: child),
                    itemCount: _notes.length,
                    onReorder: (oldIndex, newIndex) =>
                        unawaited(_reorderNotes(oldIndex, newIndex)),
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return ListTile(
                        key: ValueKey('note_$index'),
                        contentPadding: EdgeInsets.zero,
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle,
                            color: Colors.white54,
                          ),
                        ),
                        title: Text(
                          note.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RhythmTheme.subheading,
                        ),
                        trailing: index == _activeNoteIndex
                            ? const Icon(
                                Icons.visibility,
                                color: Colors.white70,
                                size: 18,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    await _jumpToNote(selected, fromOverlay: _fullscreenNote != null);
    if (_fullscreenNote != null &&
        _fullscreenPageController?.hasClients == true) {
      _fullscreenPageController!.jumpToPage(selected);
    }
  }

  Future<void> _jumpToNote(int index, {bool fromOverlay = false}) async {
    if (_notes.isEmpty) return;
    final clamped = index.clamp(0, _notes.length - 1);
    setState(() {
      _activeNoteIndex = clamped;
      if (_fullscreenNote != null) {
        _fullscreenNote = _notes[clamped];
      }
    });

    if (fromOverlay) {
      if (_notePageController.hasClients) {
        _isSyncingNotePages = true;
        await _notePageController.animateToPage(
          clamped,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        _isSyncingNotePages = false;
      }
    } else {
      if (_fullscreenPageController?.hasClients == true) {
        _fullscreenPageController!.jumpToPage(clamped);
      }
    }
    _persistSessionStateSoon();
  }

  void _enterFullscreen([int? noteIndex]) {
    if (_notes.isEmpty) return;
    final target = (noteIndex ?? _activeNoteIndex).clamp(0, _notes.length - 1);
    _fullscreenPageController?.dispose();
    _fullscreenPageController = PageController(initialPage: target);
    setState(() {
      _activeNoteIndex = target;
      _fullscreenNote = _notes[target];
    });
  }

  void _closeFullscreen() {
    setState(() {
      _fullscreenNote = null;
    });
    _fullscreenPageController?.dispose();
    _fullscreenPageController = null;
  }

  Future<void> _syncNotes(
    List<RhythmNote> updated, {
    int? activeIndex,
    bool persistOrder = false,
  }) async {
    final clampedIndex = _clampNoteIndex(updated.length, activeIndex);
    setState(() {
      _notes = updated;
      _activeNoteIndex = clampedIndex;
      if (updated.isEmpty) {
        _fullscreenNote = null;
      } else if (_fullscreenNote != null) {
        _fullscreenNote = updated[clampedIndex];
      }
    });

    await _saveNotesToPrefs(updated);
    _syncNotePageToActiveIndex();
    _persistSessionStateSoon();

    if (persistOrder) {
      final remote = <RhythmNote>[];
      for (int i = 0; i < updated.length; i++) {
        final note = updated[i];
        if (_isLocalNote(note)) continue;
        remote.add(note.copyWith(position: i));
      }
      if (remote.isNotEmpty) {
        final result = await _repo.reorderAlignmentNotes(remote);
        if (result.missingTables || result.friendlyError != null) {
          _showLocalNotesWarningOnce();
          if (mounted) {
            setState(() {
              _notesLocalOnly = true;
            });
          }
        } else if (mounted) {
          setState(() {
            _notesLocalOnly = false;
          });
        }
      }
    }

    if (_notePageController.hasClients && updated.isNotEmpty) {
      unawaited(
        _notePageController.animateToPage(
          clampedIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    }
    if (_fullscreenPageController?.hasClients == true && updated.isNotEmpty) {
      _fullscreenPageController!.jumpToPage(clampedIndex);
    }
  }

  Future<void> _editNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final original = _notes[index];
    final controller = TextEditingController(text: original.text);
    final updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Edit note', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Update your note',
              hintStyle: TextStyle(color: Colors.white54),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (updatedText == null) return;
    if (!mounted) return;
    if (updatedText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note cannot be empty.')));
      return;
    }

    if (!_isLocalNote(original)) {
      final result = await _repo.updateAlignmentNote(original.id, updatedText);
      if (result.missingTables) {
        // fall through to local persistence
        _showLocalNotesWarningOnce();
        if (mounted) {
          setState(() {
            _notesLocalOnly = true;
          });
        }
      } else if (result.friendlyError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.friendlyError!)));
        return;
      } else if (mounted) {
        setState(() {
          _notesLocalOnly = false;
        });
      }
    }

    final updated = [..._notes]..[index] = original.copyWith(text: updatedText);
    await _syncNotes(updated, activeIndex: index);
  }

  Future<void> _deleteNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final note = _notes[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Delete note?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!_isLocalNote(note)) {
      final result = await _repo.deleteAlignmentNote(note.id);
      if (result.missingTables || result.friendlyError != null) {
        // Fall back to local deletion below.
        _showLocalNotesWarningOnce();
        if (mounted) {
          setState(() {
            _notesLocalOnly = true;
          });
        }
      } else if (mounted) {
        setState(() {
          _notesLocalOnly = false;
        });
      }
    }

    final updated = [..._notes]..removeAt(index);
    final reindexed = _withPositions(updated);
    await _syncNotes(
      reindexed,
      activeIndex: reindexed.isEmpty ? 0 : (index - 1),
      persistOrder: true,
    );
  }

  Future<void> _reorderNotes(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final updated = [..._notes];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    var newActive = _activeNoteIndex;
    if (_activeNoteIndex == oldIndex) {
      newActive = newIndex;
    } else {
      if (_activeNoteIndex > oldIndex && _activeNoteIndex <= newIndex) {
        newActive -= 1;
      } else if (_activeNoteIndex < oldIndex && _activeNoteIndex >= newIndex) {
        newActive += 1;
      }
    }

    final reindexed = _withPositions(updated);
    await _syncNotes(reindexed, activeIndex: newActive, persistOrder: true);
  }

  Widget _buildNutritionTable(
    List<NutritionItem> items, {
    bool editable = false,
    Map<String, TextEditingController>? nutrientControllers,
    Map<String, TextEditingController>? sourceControllers,
    Map<String, TextEditingController>? purposeControllers,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No sources mapped to this decan day yet.',
          style: RhythmTheme.subheading,
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.06),
                ),
                dataRowColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.02),
                ),
                columnSpacing: 22,
                headingTextStyle: RhythmTheme.subheading.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                dataTextStyle: RhythmTheme.subheading,
                columns: const [
                  DataColumn(label: Text('Nutrient')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Purpose')),
                ],
                rows: items
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(
                            editable
                                ? _buildNutritionEditableCell(
                                    controller: nutrientControllers?[item.id],
                                    hintText: 'Nutrient',
                                    width: 170,
                                  )
                                : Text(_presentableText(item.nutrient)),
                          ),
                          DataCell(
                            editable
                                ? _buildNutritionEditableCell(
                                    controller: sourceControllers?[item.id],
                                    hintText: 'Source',
                                    width: 220,
                                  )
                                : Text(_presentableText(item.source)),
                          ),
                          DataCell(
                            editable
                                ? _buildNutritionEditableCell(
                                    controller: purposeControllers?[item.id],
                                    hintText: 'Purpose',
                                    width: 220,
                                  )
                                : Text(_presentableText(item.purpose)),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionEditableCell({
    required TextEditingController? controller,
    required String hintText,
    required double width,
  }) {
    if (controller == null) {
      return SizedBox(width: width);
    }

    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        style: RhythmTheme.subheading,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: RhythmTheme.label.copyWith(color: Colors.white38),
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RhythmTheme.aurora),
          ),
        ),
      ),
    );
  }

  Future<void> _showNutritionFullscreen(int decanDay, String decanName) async {
    var dialogItems = _itemsForDecanDay(
      decanDay,
    ).map((item) => item.copyWith()).toList();
    var isEditing = false;
    var isSaving = false;
    String? dialogError;
    final nutrientControllers = <String, TextEditingController>{};
    final sourceControllers = <String, TextEditingController>{};
    final purposeControllers = <String, TextEditingController>{};

    void syncControllers(List<NutritionItem> items) {
      for (final item in items) {
        nutrientControllers
                .putIfAbsent(
                  item.id,
                  () => TextEditingController(text: item.nutrient),
                )
                .text =
            item.nutrient;
        sourceControllers
                .putIfAbsent(
                  item.id,
                  () => TextEditingController(text: item.source),
                )
                .text =
            item.source;
        purposeControllers
                .putIfAbsent(
                  item.id,
                  () => TextEditingController(text: item.purpose),
                )
                .text =
            item.purpose;
      }
    }

    void disposeControllers(Map<String, TextEditingController> controllers) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }

    List<NutritionItem> draftItems() {
      return [
        for (final item in dialogItems)
          item.copyWith(
            nutrient:
                nutrientControllers[item.id]?.text.trim() ?? item.nutrient,
            source: sourceControllers[item.id]?.text.trim() ?? item.source,
            purpose: purposeControllers[item.id]?.text.trim() ?? item.purpose,
          ),
      ];
    }

    syncControllers(dialogItems);

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Nutrition detail',
        barrierColor: Colors.black.withValues(alpha: 0.86),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return StatefulBuilder(
            builder: (modalContext, setModalState) {
              return SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.94),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: KemeticGold.text(
                                '$decanName · Day $decanDay',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'GentiumPlus',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (dialogItems.isNotEmpty && !isEditing)
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    syncControllers(dialogItems);
                                    dialogError = null;
                                    isEditing = true;
                                  });
                                },
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit'),
                              ),
                            if (isEditing) ...[
                              TextButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setModalState(() {
                                          syncControllers(dialogItems);
                                          dialogError = null;
                                          isEditing = false;
                                        });
                                      },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 4),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: RhythmTheme.aurora,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        setModalState(() {
                                          dialogError = null;
                                          isSaving = true;
                                        });

                                        final updatedItems = draftItems();
                                        final hasEmptyRequiredRow = updatedItems
                                            .any(
                                              (item) =>
                                                  item.nutrient
                                                      .trim()
                                                      .isEmpty &&
                                                  item.source.trim().isEmpty,
                                            );
                                        if (hasEmptyRequiredRow) {
                                          setModalState(() {
                                            isSaving = false;
                                            dialogError =
                                                'Each row needs at least a nutrient or source.';
                                          });
                                          return;
                                        }

                                        try {
                                          final savedItems =
                                              await _saveNutritionItemEdits(
                                                updatedItems,
                                              );
                                          if (!modalContext.mounted) return;
                                          setModalState(() {
                                            dialogItems = savedItems;
                                            syncControllers(dialogItems);
                                            isEditing = false;
                                            isSaving = false;
                                          });
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Updated Day $decanDay nutrition table.',
                                              ),
                                            ),
                                          );
                                        } catch (_) {
                                          if (!modalContext.mounted) return;
                                          setModalState(() {
                                            isSaving = false;
                                            dialogError =
                                                'Could not update nutrition table.';
                                          });
                                        }
                                      },
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.black,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: Text(isSaving ? 'Saving' : 'Save'),
                              ),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              onPressed: () => Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).maybePop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              dialogError!,
                              style: RhythmTheme.subheading.copyWith(
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildNutritionTable(
                            dialogItems,
                            editable: isEditing,
                            nutrientControllers: nutrientControllers,
                            sourceControllers: sourceControllers,
                            purposeControllers: purposeControllers,
                          ),
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Edit the nutrient, source, and purpose fields, then save.',
                            style: RhythmTheme.label.copyWith(
                              color: Colors.white54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        transitionBuilder: (context, anim, secondaryAnim, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      disposeControllers(nutrientControllers);
      disposeControllers(sourceControllers);
      disposeControllers(purposeControllers);
    }
  }

  Widget _nutritionGridPage({required int index, required String decanName}) {
    final decanDay = index + 1;
    final items = _itemsForDecanDay(decanDay);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => _showNutritionFullscreen(decanDay, decanName),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: KemeticGold.text(
                      decanName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'GentiumPlus',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: RhythmTheme.aurora.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RhythmTheme.aurora.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Day $decanDay',
                    style: RhythmTheme.label.copyWith(
                      color: RhythmTheme.aurora,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No sources mapped to Day $decanDay.',
                        style: RhythmTheme.subheading,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 14,
                        thickness: 0.6,
                        color: Colors.white12,
                      ),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final source = _presentableText(
                          item.source,
                          fallback: 'Source not set',
                        );
                        final itemState = _nutritionStateForItem(
                          item,
                          decanDay: decanDay,
                        );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            RhythmStateDot(
                              state: itemState == RhythmItemState.pending
                                  ? RhythmItemState.done
                                  : itemState,
                              isActive: itemState != RhythmItemState.pending,
                              onTap: () => unawaited(
                                _toggleNutritionItemDone(
                                  item,
                                  decanDay: decanDay,
                                ),
                              ),
                              padding: const EdgeInsets.all(3),
                              iconSize: 11,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                source,
                                style: RhythmTheme.subheading.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Double-tap for nutrient + purpose.',
              style: RhythmTheme.label.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSection() {
    final decanName = _currentDecanName();

    return RhythmSectionCard(
      title: 'Nutrition',
      subtitle: 'Swipe across the decan to remember your sources.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add to Day ${_activeNutritionDayIndex + 1}',
                          style: RhythmTheme.subheading.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _nutritionFormOpen
                            ? 'Hide add form'
                            : 'Show add form',
                        icon: Icon(
                          _nutritionFormOpen
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _nutritionFormOpen = !_nutritionFormOpen;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  crossFadeState: _nutritionFormOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 200),
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nutritionSourceController,
                          style: RhythmTheme.subheading,
                          decoration: InputDecoration(
                            labelText: 'Source',
                            hintText: 'e.g., Apple, Supplement, Tea',
                            labelStyle: RhythmTheme.label.copyWith(
                              color: Colors.white70,
                            ),
                            hintStyle: RhythmTheme.label.copyWith(
                              color: Colors.white38,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nutritionNutrientController,
                          style: RhythmTheme.subheading,
                          decoration: InputDecoration(
                            labelText: 'Nutrient (optional)',
                            hintText: 'e.g., Vitamin C, Magnesium',
                            labelStyle: RhythmTheme.label.copyWith(
                              color: Colors.white70,
                            ),
                            hintStyle: RhythmTheme.label.copyWith(
                              color: Colors.white38,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nutritionPurposeController,
                          style: RhythmTheme.subheading,
                          decoration: InputDecoration(
                            labelText: 'Purpose (optional)',
                            hintText: 'e.g., Energy, Sleep, Recovery',
                            labelStyle: RhythmTheme.label.copyWith(
                              color: Colors.white70,
                            ),
                            hintStyle: RhythmTheme.label.copyWith(
                              color: Colors.white38,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => unawaited(_addNutritionItem()),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RhythmTheme.aurora,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _nutritionLoading
                                ? null
                                : () => unawaited(_addNutritionItem()),
                            icon: const Icon(Icons.add),
                            label: const Text('Add to grid'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_nutritionMissingTable)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nutrition tracking is not available in this environment yet.',
                      style: RhythmTheme.subheading.copyWith(
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_nutritionError != null && !_nutritionMissingTable)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _nutritionError!,
                      style: RhythmTheme.subheading.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_loadNutrition()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (_nutritionLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 230,
                  child: PageView.builder(
                    controller: _nutritionPageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: 10,
                    onPageChanged: (index) {
                      setState(() {
                        _activeNutritionDayIndex = index;
                      });
                      _persistSessionStateSoon();
                    },
                    itemBuilder: (context, index) {
                      return _nutritionGridPage(
                        index: index,
                        decanName: decanName,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 10; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 8,
                        width: _activeNutritionDayIndex == i ? 18 : 8,
                        decoration: BoxDecoration(
                          color: _activeNutritionDayIndex == i
                              ? RhythmTheme.aurora
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openDecanInfo,
                  child: Text(
                    'Viewing $decanName — decan day ${_activeNutritionDayIndex + 1} of 10. Swipe or double-tap for detail.',
                    textAlign: TextAlign.center,
                    style: RhythmTheme.label.copyWith(color: Colors.white54),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _noteCard(
    BuildContext context,
    RhythmNote note, {
    required int index,
    bool fullscreen = false,
  }) {
    final size = MediaQuery.of(context).size;
    final card = Container(
      width: fullscreen ? size.width - 24 : null,
      constraints: fullscreen
          ? BoxConstraints(
              minHeight: size.height * 0.35,
              maxHeight: size.height * 0.8,
            )
          : null,
      padding: fullscreen ? const EdgeInsets.all(24) : const EdgeInsets.all(18),
      margin: fullscreen
          ? null
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RhythmTheme.aurora.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: fullscreen
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: KemeticGold.text(
                        note.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'GentiumPlus',
                          height: 1.15,
                        ),
                        maxLines: null,
                        softWrap: true,
                      ),
                    ),
                  ),
                );
              },
            )
          : Center(
              child: KemeticGold.text(
                note.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GentiumPlus',
                  height: 1.15,
                ),
                maxLines: 6,
                softWrap: true,
              ),
            ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: fullscreen ? null : () => _enterFullscreen(index),
      onLongPress: _showNotePicker,
      child: Stack(
        children: [
          card,
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              color: Colors.black87,
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) {
                if (value == 'edit') {
                  unawaited(_editNote(index));
                } else if (value == 'delete') {
                  unawaited(_deleteNote(index));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return RhythmSectionCard(
      title: 'Notes',
      subtitle: 'Affirmations to keep front-of-mind. Double-tap to spotlight.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_notesLocalOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Planner notes are saved only on this device. Cloud sync is unavailable.',
                      style: RhythmTheme.subheading.copyWith(
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Stack(
            children: [
              TextField(
                controller: _noteInputController,
                minLines: 2,
                maxLines: 4,
                style: RhythmTheme.subheading,
                decoration: InputDecoration(
                  hintText: 'Write a note, affirmation, or reminder',
                  hintStyle: RhythmTheme.subheading.copyWith(
                    color: Colors.white38,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: RhythmTheme.aurora.withValues(alpha: 0.6),
                    ),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 70, 14),
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => unawaited(_addNote()),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: FloatingActionButton.small(
                  heroTag: widget.embedded ? null : 'today_alignment_add_note',
                  backgroundColor: RhythmTheme.aurora,
                  foregroundColor: Colors.black,
                  onPressed: () => unawaited(_addNote()),
                  child: const Icon(Icons.add, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'No notes yet. Add a quick reminder to keep it in your field today.',
                style: RhythmTheme.subheading,
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    controller: _notePageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _notes.length,
                    onPageChanged: (index) {
                      if (_isSyncingNotePages) {
                        setState(() {
                          _activeNoteIndex = index;
                          if (_fullscreenNote != null) {
                            _fullscreenNote = _notes[index];
                          }
                        });
                        _persistSessionStateSoon();
                        return;
                      }
                      unawaited(_jumpToNote(index));
                    },
                    itemBuilder: (context, index) {
                      return _noteCard(context, _notes[index], index: index);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _notes.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _activeNoteIndex == i ? 18 : 8,
                        decoration: BoxDecoration(
                          color: _activeNoteIndex == i
                              ? RhythmTheme.aurora
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    IconButton(
                      onPressed: _showNotePicker,
                      icon: const Icon(
                        Icons.list_alt,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'See all notes',
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _fullscreenOverlay() {
    if (_fullscreenNote == null || _notes.isEmpty) {
      return const SizedBox.shrink();
    }
    _fullscreenPageController ??= PageController(initialPage: _activeNoteIndex);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeFullscreen,
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _fullscreenPageController,
                  itemCount: _notes.length,
                  physics: const PageScrollPhysics(),
                  onPageChanged: (index) {
                    unawaited(_jumpToNote(index, fromOverlay: true));
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 28,
                      ),
                      child: _noteCard(
                        context,
                        _notes[index],
                        index: index,
                        fullscreen: true,
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: _closeFullscreen,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _plannerContent({bool embedded = false}) {
    final dateLabel = _formatDateLabel(_todayLocal);
    final content = FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: RhythmLoadingShell(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RhythmErrorStateCard(
              title: 'The day is still forming',
              message: RhythmUserMessages.loadInterrupted,
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            ),
          );
        }

        if (_missingTables) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RhythmErrorStateCard(
              title: 'Today’s Alignment isn’t ready yet.',
              message:
                  'This environment is missing the rhythm tables. You can retry after migrations run.',
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            ),
          );
        }

        if (_friendlyError != null) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RhythmErrorStateCard(
              title: 'The day is still forming',
              message: _friendlyError!,
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            ),
          );
        }

        final progress = _progress();
        final plannerAction = _todayPlannerAction();

        final scroll = SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RhythmSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KemeticGold.text(
                      'Planner',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'GentiumPlus',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Move through today with clarity and grace.',
                      style: RhythmTheme.subheading,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: RhythmTheme.frostSurface(),
                          child: KemeticGold.icon(
                            Icons.wb_sunny_rounded,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateLabel,
                                style: RhythmTheme.subheading.copyWith(
                                  color: _dateAccentColor(),
                                ),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  RhythmTheme.aurora,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(progress * 100).round()}% aligned so far',
                                style: RhythmTheme.subheading.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (plannerAction != null) ...[
                const SizedBox(height: 12),
                KemeticDayButton(
                  dayKey: plannerAction.dayKey,
                  kYear: plannerAction.kYear,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: GlossyText(
                        text: plannerAction.reflection,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        gradient: _plannerReflectionGloss,
                        style: RhythmTheme.subheading.copyWith(height: 1.35),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 14),
              _buildNotesSection(),
              const SizedBox(height: 14),
              _buildNutritionSection(),
              const SizedBox(height: 14),
              RhythmSectionCard(
                title: 'To Do',
                subtitle:
                    'Add what you want to move for this day. Press return or tap Add.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: _dateAccentColor(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDateLabel(_activeTodoDay, short: true),
                            style: RhythmTheme.subheading.copyWith(
                              color: _dateAccentColor(),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _commitmentInputController,
                          builder: (context, value, child) {
                            final hasText = value.text.trim().isNotEmpty;
                            return ElevatedButton.icon(
                              style: withExpandedTouchTargets(
                                context,
                                ElevatedButton.styleFrom(
                                  backgroundColor: RhythmTheme.aurora,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.white
                                      .withValues(alpha: 0.08),
                                  disabledForegroundColor: Colors.white38,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              onPressed: hasText
                                  ? () => unawaited(_commitNewTodo())
                                  : null,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                            );
                          },
                        ),
                        if (_sameDay(_activeTodoDay, _todayLocal))
                          const SizedBox(width: 8),
                        if (_sameDay(_activeTodoDay, _todayLocal))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commitmentInputController,
                      style: RhythmTheme.subheading,
                      decoration: InputDecoration(
                        hintText:
                            'Type a commitment, then press return or tap Add',
                        hintStyle: RhythmTheme.subheading.copyWith(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: RhythmTheme.aurora.withValues(alpha: 0.6),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_commitNewTodo()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: _todoPageHeightEstimate(),
                      child: PageView.builder(
                        controller: _todoPageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: _onTodoPageChanged,
                        itemCount: _todoDays.length,
                        itemBuilder: (context, index) {
                          final day = _todoDays[index];
                          return _buildTodoDayPage(day);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < _todoDays.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _activeTodoDayIndex == i ? 18 : 8,
                            decoration: BoxDecoration(
                              color: _activeTodoDayIndex == i
                                  ? RhythmTheme.aurora
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Swipe to review the previous 2 days or plan 2 days ahead.',
                      textAlign: TextAlign.center,
                      style: RhythmTheme.label.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              RhythmSectionCard(
                title: 'Completed',
                subtitle: 'Moments you already honored.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _completed().isEmpty
                      ? [
                          Text(
                            'Nothing checked off yet. Start small; one step brings momentum.',
                            style: RhythmTheme.subheading,
                          ),
                        ]
                      : _completed()
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: RhythmTheme.subheading,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [scroll, _fullscreenOverlay()],
        );
      },
    );

    return Container(
      color: Colors.black,
      child: SafeArea(
        top: !embedded,
        bottom: true,
        left: true,
        right: true,
        child: content,
      ),
    );
  }

  Widget _buildCalendarRevealSwipeGate() {
    return PageNavigationEdgeSwipe(
      direction: PageNavigationSwipeDirection.rightToLeft,
      enabled: !_calendarRevealNavigationInFlight,
      onCommit: () {
        unawaited(_returnToCalendarFromSwipe());
      },
    );
  }

  Future<void> _returnToCalendarFromSwipe() async {
    if (_calendarRevealNavigationInFlight || !mounted) return;

    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;

    _calendarRevealNavigationInFlight = true;
    try {
      await navigator.maybePop();
    } finally {
      _calendarRevealNavigationInFlight = false;
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: !widget.openedFromCalendarSwipe,
      backgroundColor: Colors.black,
      elevation: 0.5,
      centerTitle: false,
      titleSpacing: 12,
      iconTheme: const IconThemeData(color: KemeticGold.base),
      title: GestureDetector(
        onTap: () => setState(() => _showGregorianDates = !_showGregorianDates),
        child: Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: GlossyText(
            text: 'ḥꜣw',
            gradient: _showGregorianDates ? whiteGloss : goldGloss,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'GentiumPlus',
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'New note',
          icon: const GlossyIcon(icon: Icons.add, gradient: goldGloss),
          onPressed: () {
            unawaited(_openCalendarQuickAdd());
          },
        ),
        IconButton(
          tooltip: 'Today',
          icon: const GlossyIcon(icon: Icons.today, gradient: goldGloss),
          onPressed: () => CalendarPage.openMainCalendarAtToday(context),
        ),
        Builder(
          builder: (btnCtx) => IconButton(
            tooltip: 'Menu',
            icon: const InboxUnreadDotOverlay(
              child: GlossyIcon(icon: Icons.apps, gradient: goldGloss),
            ),
            onPressed: () => _openCalendarMenu(btnCtx),
          ),
        ),
        IconButton(
          tooltip: 'My Profile',
          icon: const GlossyIcon(icon: Icons.person, gradient: goldGloss),
          onPressed: _openProfilePage,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _plannerContent(embedded: widget.embedded);

    if (widget.embedded) {
      return content;
    }

    final canRevealCalendar =
        widget.openedFromCalendar && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          content,
          if (canRevealCalendar) _buildCalendarRevealSwipeGate(),
        ],
      ),
    );
  }

  double _progressWeight(RhythmItemState state) {
    switch (state) {
      case RhythmItemState.done:
        return 1;
      case RhythmItemState.partial:
        return 0.5;
      case RhythmItemState.skipped:
      case RhythmItemState.pending:
        return 0;
    }
  }

  double _progress() {
    final todayTodos = _todosByDay[_todayLocal] ?? const <RhythmTodo>[];
    final todayNutrition = _todayNutritionItems();
    final totalTracked = todayTodos.length + todayNutrition.length;

    if (totalTracked > 0) {
      final todoProgress = todayTodos.fold<double>(
        0,
        (sum, todo) => sum + _progressWeight(todo.state),
      );
      final nutritionProgress = todayNutrition.fold<double>(
        0,
        (sum, item) =>
            sum +
            _progressWeight(_nutritionStateForItem(item, date: _todayLocal)),
      );
      return (todoProgress + nutritionProgress) / totalTracked;
    }

    if (_alignmentItems.isEmpty) return 0;
    final totalAlignment = _alignmentItems.length.toDouble();
    final doneAlignment = _alignmentItems
        .where((i) => i.state == RhythmItemState.done)
        .length;
    final partialAlignment = _alignmentItems
        .where((i) => i.state == RhythmItemState.partial)
        .length;
    return (doneAlignment + partialAlignment * 0.5) / totalAlignment;
  }

  List<RhythmItem> _completed() {
    final doneAlignment = _alignmentItems.where(
      (i) => i.state == RhythmItemState.done,
    );
    final doneTodos = _todos
        .where((t) => t.state == RhythmItemState.done)
        .map(
          (t) => RhythmItem(
            title: t.title,
            summary: t.notes ?? 'Completed',
            chips: const [RhythmChipKind.alignment],
            state: RhythmItemState.done,
          ),
        );
    return [...doneAlignment, ...doneTodos];
  }
}

class _DecanInfoPage extends StatelessWidget {
  const _DecanInfoPage({required this.dayKey, required this.info});

  final String dayKey;
  final KemeticDayInfo info;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: KemeticGold.base),
        title: KemeticGold.text(
          info.decanName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'GentiumPlus',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: RhythmTheme.cardSurface(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.kemeticDate,
                    style: RhythmTheme.subheading.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${info.season} · ${info.month} · $dayKey',
                    style: RhythmTheme.label.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(info.cosmicContext, style: RhythmTheme.subheading),
                  const SizedBox(height: 12),
                  Text(
                    'Medu Neter',
                    style: RhythmTheme.subheading.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(info.meduNeter.glyph, style: RhythmTheme.subheading),
                  const SizedBox(height: 4),
                  Text(
                    info.meduNeter.mantra,
                    style: RhythmTheme.label.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Decan Flow',
              style: RhythmTheme.subheading.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...info.decanFlow.map(
              (d) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${d.day}: ${d.theme}',
                      style: RhythmTheme.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(d.action, style: RhythmTheme.subheading),
                    const SizedBox(height: 4),
                    Text(
                      d.reflection,
                      style: RhythmTheme.label.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
