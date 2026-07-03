import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/planner_launch_intent.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/app_bottom_insets.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/core/kemetic_converter.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/data/nutrition_items_cache.dart';
import 'package:mobile/features/rhythm/planner/planner_input_helpers.dart';
import 'package:mobile/features/rhythm/todo_day_window.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';
import 'package:mobile/services/app_haptics.dart';
import 'package:mobile/services/daily_reflection_widget_bridge.dart'
    if (dart.library.html) 'package:mobile/services/daily_reflection_widget_bridge_web.dart';
import 'package:mobile/services/navigation_trace.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/shared/kemetic_text.dart';
import 'package:mobile/widgets/kemetic_app_bar_action.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/services/session_resume_service.dart';

import 'package:mobile/core/day_key.dart';
import '../data/planner_badge_repo.dart';
import '../data/rhythm_repo.dart';
import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import '../widgets/planner/planner_completed_section.dart';
import '../widgets/planner/planner_horizon.dart';
import '../widgets/planner/planner_notes_section.dart';
import '../widgets/planner/planner_nutrition_section.dart';
import '../widgets/planner/planner_todo_section.dart';
import '../widgets/planner/planner_wall.dart';
import '../widgets/planner/planner_warm_background.dart';
import '../widgets/planner/planner_weighing_header.dart';
import '../widgets/planner/planner_visual_tokens.dart';
import '../widgets/rhythm_state_button.dart';
import '../widgets/rhythm_states.dart';
import '../widgets/rhythm_todo_row.dart';

class TodaysAlignmentPage extends StatefulWidget {
  const TodaysAlignmentPage({
    super.key,
    this.embedded = false,
    this.openedFromCalendar = false,
    this.openDayCardOnLoad = false,
    this.launchIntent,
  });

  final bool embedded;
  final bool openedFromCalendar;
  final bool openDayCardOnLoad;
  final PlannerLaunchIntent? launchIntent;

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
  final UserEventsRepo _eventsRepo = UserEventsRepo(Supabase.instance.client);
  final PlannerBadgeRepo _plannerBadgeRepo = PlannerBadgeRepo(
    Supabase.instance.client,
  );
  late Future<void> _future;
  final TextEditingController _commitmentInputController =
      TextEditingController();
  final TextEditingController _noteInputController = TextEditingController();
  late PageController _todoPageController;
  final PageController _notePageController = PageController(
    viewportFraction: PlannerVisualTokens.notesCarouselViewportFraction,
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
  bool _nutritionLocalOnly = false;
  String? _nutritionError;
  bool _nutritionStatesLoaded = false;
  bool _nutritionLocalNoticeShown = false;
  int _activeNutritionDayIndex = 0;
  bool _nutritionFormOpen = false;
  bool _nutritionEveryDay = false;
  Timer? _sessionPersistDebounce;
  String? _lastPublishedWidgetReflectionKey;
  bool _buildTraceRecorded = false;

  bool get _tracksSessionState =>
      !widget.embedded && !widget.openedFromCalendar;

  String _routeForNavigationTrace(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return '<unknown>';
    }
  }

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
      viewportFraction: PlannerVisualTokens.nutritionCarouselViewportFraction,
      initialPage: _activeNutritionDayIndex,
    );
    _bindSessionListeners();
    final restoreFuture = _restoreSessionState();
    _future = restoreFuture.then((_) => _loadWithTrace('initial')).then((_) {
      _publishDailyReflectionWidgetData();
    });
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
    });
  }

  @override
  void didUpdateWidget(covariant TodaysAlignmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launchIntent?.routeLocation !=
            widget.launchIntent?.routeLocation ||
        oldWidget.openDayCardOnLoad != widget.openDayCardOnLoad) {
      _todoDays = buildTodoDayWindow(anchorDay: _todayLocal);
      _todosByDay = {for (final day in _todoDays) day: <RhythmTodo>[]};
      _activeNutritionDayIndex = (_currentDecanDay() - 1).clamp(0, 9);
      _future = _loadWithTrace('widgetUpdate').then((_) {
        _publishDailyReflectionWidgetData();
      });
      unawaited(_loadNutrition());
      unawaited(_loadNutritionStates());
      _scheduleMidnightRefresh();
    }
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
    _nutritionEveryDay = state['nutritionEveryDay'] as bool? ?? false;
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
      'nutritionEveryDay': _nutritionEveryDay,
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

  Future<void> _loadWithTrace(String reason) async {
    final route = _routeForNavigationTrace(context);
    NavigationTrace.instance.record(
      'Planner load start',
      state: <String, Object?>{
        'reason': reason,
        'route': route,
        'mounted': mounted,
      },
    );
    try {
      await _load();
      NavigationTrace.instance.record(
        'Planner load done',
        state: <String, Object?>{
          'reason': reason,
          'route': route,
          'mounted': mounted,
        },
      );
    } catch (error, stackTrace) {
      NavigationTrace.instance.recordError(
        'Planner load error',
        error,
        stackTrace,
        state: <String, Object?>{
          'reason': reason,
          'route': route,
          'mounted': mounted,
        },
      );
      rethrow;
    }
  }

  Future<void> _loadNutrition() async {
    final uid = _currentUserId;
    setState(() {
      _nutritionLoading = true;
      _nutritionError = null;
      _nutritionMissingTable = false;
    });
    final cachedFuture = NutritionItemsCache.load(uid);
    if (uid == null) {
      final cached = await cachedFuture;
      if (!mounted) return;
      setState(() {
        _nutritionItems = cached;
        _nutritionLoading = false;
        _nutritionLocalOnly = cached.isNotEmpty;
        _nutritionError = cached.isNotEmpty
            ? 'Nutrition sources are saved only on this device. Cloud sync is unavailable.'
            : null;
      });
      return;
    }
    try {
      final items = await _nutritionRepo.getAll();
      final cached = await cachedFuture;
      final offlineAdds = cached.where(NutritionItemsCache.isLocal).toList();
      final uploaded = <NutritionItem>[];
      final remainingLocal = <NutritionItem>[];
      final replacementIds = <String, String>{};
      var uploadFailed = false;
      for (final item in offlineAdds) {
        try {
          final saved = await _nutritionRepo.upsert(item);
          uploaded.add(saved);
          replacementIds[item.id] = saved.id;
        } catch (_) {
          uploadFailed = true;
          remainingLocal.add(item);
        }
      }
      final mergedItems = uploadFailed
          ? [...items, ...uploaded, ...remainingLocal]
          : [...items, ...uploaded];
      await NutritionItemsCache.save(mergedItems, uid: uid);
      var updatedStates = _nutritionStatesByKey;
      if (replacementIds.isNotEmpty) {
        final storedStates = await _loadNutritionStatesFromPrefs(uid);
        final migratedStoredStates = _replaceNutritionStateItemIds(
          storedStates,
          replacementIds,
        );
        await _saveNutritionStatesToPrefs(migratedStoredStates, uid: uid);
        updatedStates = _replaceNutritionStateItemIds(
          _nutritionStatesByKey,
          replacementIds,
        );
      }
      if (!mounted) return;
      setState(() {
        _nutritionItems = mergedItems;
        _nutritionStatesByKey = updatedStates;
        _nutritionLoading = false;
        _nutritionLocalOnly = uploadFailed && offlineAdds.isNotEmpty;
        _nutritionError = _nutritionLocalOnly
            ? 'Nutrition sources are saved only on this device. Cloud sync is unavailable.'
            : null;
      });
      if (_nutritionLocalOnly) {
        _showLocalNutritionWarningOnce();
      }
      if (_nutritionStatesLoaded) {
        unawaited(_reconcileNutritionPlannerBadges());
      }
    } on StateError catch (e) {
      final msg = e.toString().toLowerCase();
      final missing = msg.contains('nutrition_items');
      final cached = await cachedFuture;
      if (!mounted) return;
      setState(() {
        _nutritionItems = cached;
        _nutritionLoading = false;
        _nutritionMissingTable = missing;
        _nutritionLocalOnly = cached.isNotEmpty;
        _nutritionError = cached.isNotEmpty
            ? 'Nutrition sources are saved only on this device. Cloud sync is unavailable.'
            : missing
            ? 'Nutrition storage is not available in this environment yet.'
            : 'Could not load nutrition sources.';
      });
    } catch (_) {
      final cached = await cachedFuture;
      if (!mounted) return;
      setState(() {
        _nutritionItems = cached;
        _nutritionLoading = false;
        _nutritionLocalOnly = cached.isNotEmpty;
        _nutritionError = cached.isNotEmpty
            ? 'Nutrition sources are saved only on this device. Cloud sync is unavailable.'
            : 'Could not load nutrition sources.';
      });
    }
  }

  void _showLocalNutritionWarningOnce() {
    if (_nutritionLocalNoticeShown || !mounted) return;
    _nutritionLocalNoticeShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nutrition sources are saved only on this device. Cloud sync is unavailable.',
        ),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final newItem = plannerNutritionWithEveryDayMapping(
      NutritionItem(
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
      ),
      activeDecanDay: decanDay,
      everyDay: _nutritionEveryDay,
    );
    if (_nutritionMissingTable) {
      await _saveNutritionItemLocally(newItem);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await _nutritionRepo.upsert(newItem);
      if (!mounted) return;
      final updated = [..._nutritionItems, saved];
      setState(() {
        _nutritionItems = updated;
        _nutritionLocalOnly = false;
        _nutritionError = null;
      });
      await NutritionItemsCache.save(updated, uid: _currentUserId);
      if (!mounted) return;
      _nutritionNutrientController.clear();
      _nutritionSourceController.clear();
      _nutritionPurposeController.clear();
      setState(() {
        _nutritionEveryDay = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Saved to Day $decanDay of this decan.')),
      );
    } catch (_) {
      await _saveNutritionItemLocally(newItem);
    }
  }

  Future<void> _saveNutritionItemLocally(NutritionItem item) async {
    if (!mounted) return;
    final fallback = item.copyWith(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
    );
    final updated = [..._nutritionItems, fallback];
    setState(() {
      _nutritionItems = updated;
      _nutritionLocalOnly = true;
      _nutritionError =
          'Nutrition sources are saved only on this device. Cloud sync is unavailable.';
    });
    await NutritionItemsCache.save(updated, uid: _currentUserId);
    if (!mounted) return;
    _nutritionNutrientController.clear();
    _nutritionSourceController.clear();
    _nutritionPurposeController.clear();
    setState(() {
      _nutritionEveryDay = false;
    });
    _showLocalNutritionWarningOnce();
  }

  Future<List<NutritionItem>> _saveNutritionItemEdits(
    List<NutritionItem> items,
  ) async {
    final uid = _currentUserId;
    if (uid == null || _nutritionMissingTable) {
      return _saveNutritionItemEditsLocally(items);
    }

    final savedItems = <NutritionItem>[];
    final replacementIds = <String, String>{};
    try {
      for (final item in items) {
        final saved = await _nutritionRepo.upsert(item);
        savedItems.add(saved);
        if (item.id.isNotEmpty && item.id != saved.id) {
          replacementIds[item.id] = saved.id;
        }
      }
    } catch (_) {
      return _saveNutritionItemEditsLocally(items);
    }
    if (!mounted) return savedItems;

    final savedByOriginalId = <String, NutritionItem>{};
    final savedByRemoteId = <String, NutritionItem>{};
    for (var i = 0; i < items.length; i++) {
      savedByOriginalId[items[i].id] = savedItems[i];
      savedByRemoteId[savedItems[i].id] = savedItems[i];
    }
    final updatedItems = [
      for (final item in _nutritionItems)
        savedByOriginalId[item.id] ?? savedByRemoteId[item.id] ?? item,
    ];
    var updatedStates = _nutritionStatesByKey;
    if (replacementIds.isNotEmpty) {
      final storedStates = await _loadNutritionStatesFromPrefs(uid);
      final migratedStoredStates = _replaceNutritionStateItemIds(
        storedStates,
        replacementIds,
      );
      await _saveNutritionStatesToPrefs(migratedStoredStates, uid: uid);
      updatedStates = _replaceNutritionStateItemIds(
        _nutritionStatesByKey.isEmpty
            ? migratedStoredStates
            : _nutritionStatesByKey,
        replacementIds,
      );
    }
    setState(() {
      _nutritionItems = updatedItems;
      _nutritionStatesByKey = updatedStates;
      _nutritionLocalOnly = updatedItems.any(NutritionItemsCache.isLocal);
      _nutritionError = _nutritionLocalOnly
          ? 'Nutrition sources are saved only on this device. Cloud sync is unavailable.'
          : null;
    });
    await NutritionItemsCache.save(updatedItems, uid: uid);
    if (replacementIds.isNotEmpty) {
      unawaited(_reconcileNutritionPlannerBadges());
    }
    return savedItems;
  }

  Future<List<NutritionItem>> _saveNutritionItemEditsLocally(
    List<NutritionItem> items,
  ) async {
    final editedById = {for (final item in items) item.id: item};
    final updated = [
      for (final item in _nutritionItems) editedById[item.id] ?? item,
    ];
    await NutritionItemsCache.save(updated, uid: _currentUserId);
    if (mounted) {
      setState(() {
        _nutritionItems = updated;
        _nutritionLocalOnly = true;
        _nutritionError =
            'Nutrition sources are saved only on this device. Cloud sync is unavailable.';
      });
    }
    _showLocalNutritionWarningOnce();
    return items;
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
    } catch (error, stackTrace) {
      debugPrint('[TodaysAlignment] planner badge sync failed: $error');
      debugPrint('$stackTrace');
      synced = false;
    }
    if (synced) {
      unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
    }
  }

  Future<void> _moveTodoToTomorrow(int index) async {
    final activeDay = _activeTodoDay;
    final dayTodos = [...(_todosByDay[activeDay] ?? _todos)];
    if (index < 0 || index >= dayTodos.length) return;
    final todo = dayTodos[index];
    if (todo.id.isEmpty || todo.state == RhythmItemState.done) return;

    final previousMap = {
      for (final entry in _todosByDay.entries)
        entry.key: List<RhythmTodo>.from(entry.value),
    };
    final previousDays = List<DateTime>.from(_todoDays);
    final previousTodos = List<RhythmTodo>.from(_todos);
    final targetDay = _normalizeDate(activeDay.add(const Duration(days: 1)));
    final moveResult = plannerMoveTodoToNextDayInMap(
      todosByDay: _todosByDay,
      sourceDay: activeDay,
      sourceIndex: index,
    );
    if (moveResult == null) return;

    setState(() {
      _todosByDay = moveResult.todosByDay;
      if (!_todoDays.any((day) => _sameDay(day, targetDay))) {
        _todoDays = [..._todoDays, targetDay]..sort((a, b) => a.compareTo(b));
      }
      _todos = _todosByDay[activeDay] ?? const <RhythmTodo>[];
    });

    final result = await _repo.updateTodoDueDate(todo.id, targetDay);
    if (!mounted) return;
    if (result.friendlyError != null ||
        result.missingTables ||
        result.data == null) {
      setState(() {
        _todosByDay = previousMap;
        _todoDays = previousDays;
        _todos = previousTodos;
      });
      final msg = result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not move task.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final savedTodo = result.data!;
    final targetTodos = _todosByDay[targetDay] ?? const <RhythmTodo>[];
    setState(() {
      _todosByDay = {
        ..._todosByDay,
        targetDay: [
          for (final current in targetTodos)
            if (current.id == savedTodo.id) savedTodo else current,
        ],
      };
    });

    var synced = false;
    try {
      await _plannerBadgeRepo.deleteTodoBadge(todoId: todo.id, date: activeDay);
      await _plannerBadgeRepo.syncTodoState(todo: savedTodo, date: targetDay);
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

  Future<void> _deleteTodo(int index) async {
    final activeDay = _activeTodoDay;
    final dayTodos = [...(_todosByDay[activeDay] ?? _todos)];
    if (index < 0 || index >= dayTodos.length) return;
    final todo = dayTodos[index];
    if (todo.id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Delete to-do?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes the commitment from this day.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = [...dayTodos]..removeAt(index);
    _updateTodosForDay(activeDay, updated);

    final result = await _repo.deleteTodo(todo.id);
    if (!mounted) return;
    if (result.friendlyError != null || result.missingTables) {
      _updateTodosForDay(activeDay, dayTodos);
      final msg = result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not delete task.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    var badgeDeleted = false;
    try {
      await _plannerBadgeRepo.deleteTodoBadge(
        todoId: todo.id,
        date: _normalizeDate(todo.dueDate ?? activeDay),
      );
      badgeDeleted = true;
    } catch (_) {
      badgeDeleted = false;
    }
    if (badgeDeleted) {
      unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
    }
  }

  String _prefsKeyForUser(String? uid) =>
      'today_alignment_notes${uid == null ? '' : '_$uid'}';

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  DateTime get _todayLocal =>
      DateUtils.dateOnly(widget.launchIntent?.localDate ?? DateTime.now());

  bool get _shouldOpenDayCardOnLoad =>
      widget.openDayCardOnLoad || widget.launchIntent?.openDayCard == true;

  bool get _shouldStartOnTodoSection =>
      widget.launchIntent?.route == '/rhythm/todo';

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

  Map<String, RhythmItemState> _replaceNutritionStateItemIds(
    Map<String, RhythmItemState> states,
    Map<String, String> replacementIds,
  ) {
    if (replacementIds.isEmpty || states.isEmpty) return states;
    final updated = <String, RhythmItemState>{};
    states.forEach((key, state) {
      final parts = key.split('::');
      if (parts.length != 2) {
        updated[key] = state;
        return;
      }
      final replacementId = replacementIds[parts[1]];
      updated[replacementId == null ? key : '${parts[0]}::$replacementId'] =
          state;
    });
    return updated;
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
    final dailyQuestion = dailyReflectionQuestionForDate(
      _todayLocal,
      converter: _kemeticConverter,
    );
    if (dailyQuestion == null) return null;
    return (
      dayKey: dailyQuestion.dayKey,
      kYear: dailyQuestion.kYear,
      reflection: dailyQuestion.question,
    );
  }

  void _publishDailyReflectionWidgetData() {
    final plannerAction = _todayPlannerAction();
    if (plannerAction == null) return;
    final date = DateFormat('yyyy-MM-dd').format(_todayLocal);
    final publishKey =
        '$date|${plannerAction.dayKey}|${plannerAction.kYear}|${plannerAction.reflection}';
    if (_lastPublishedWidgetReflectionKey == publishKey) return;
    _lastPublishedWidgetReflectionKey = publishKey;

    unawaited(
      publishDailyReflectionWidgetData(
        date: date,
        dateLabel: _formatDateLabel(_todayLocal, short: true),
        dayKey: plannerAction.dayKey,
        kYear: plannerAction.kYear,
        question: plannerAction.reflection,
      ),
    );
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
    context.go('/rhythm/decan/${Uri.encodeComponent(dayKey)}');
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
        _future = _load().then((_) {
          _publishDailyReflectionWidgetData();
        });
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
    } catch (error, stackTrace) {
      debugPrint('[TodaysAlignment] planner badge reconcile failed: $error');
      debugPrint('$stackTrace');
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
    final monthName = getMonthById(kd.month).displayShort;
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

  String _nutritionItemLabel(NutritionItem item) {
    final nutrient = item.nutrient.trim();
    if (nutrient.isNotEmpty) return nutrient;
    final source = item.source.trim();
    if (source.isNotEmpty) return source;
    return 'this nutrition item';
  }

  Future<void> _deleteNutritionItem(NutritionItem item) async {
    if (!NutritionItemsCache.isLocal(item)) {
      await _eventsRepo.deleteByClientIdPrefix('nutrition:${item.id}:');
      await _nutritionRepo.delete(item.id);
    }

    final updatedStates = Map<String, RhythmItemState>.from(
      _nutritionStatesByKey,
    )..removeWhere((key, _) => key.endsWith('::${item.id}'));
    await _saveNutritionStatesToPrefs(updatedStates);
    final updatedItems = [
      for (final current in _nutritionItems)
        if (current.id != item.id) current,
    ];
    await NutritionItemsCache.save(updatedItems, uid: _currentUserId);

    if (mounted) {
      setState(() {
        _nutritionItems = updatedItems;
        _nutritionStatesByKey = updatedStates;
      });
    }

    var badgesDeleted = false;
    try {
      await _plannerBadgeRepo.deleteNutritionBadgesForItem(item.id);
      badgesDeleted = true;
    } catch (_) {
      badgesDeleted = false;
    }
    if (badgesDeleted) {
      unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
    }
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

  Future<void> _openCalendarQuickAdd() async {
    await CalendarPage.openQuickAddFromAnyContext(context);
  }

  void _openProfilePage() {
    NavigationTrace.instance.record('Profile app-bar tap fired');
    unawaited(CalendarPage.openProfileFromAnyContext(context));
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
    if (_todoDays.isEmpty) return 220;
    double maxHeight = 220;
    for (final day in _todoDays) {
      final count = _todosByDay[day]?.length ?? 0;
      final estimated = 160 + count * 110;
      maxHeight = math.max(maxHeight, estimated.toDouble());
    }
    return maxHeight.clamp(220.0, 540.0).toDouble();
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
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.16),
            ),
            borderRadius: BorderRadius.circular(
              PlannerVisualTokens.plateRadius,
            ),
            border: Border.all(
              color: PlannerVisualTokens.gold.withValues(
                alpha: PlannerVisualTokens.liftedAlpha(0.08),
              ),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Text(
            'No to-dos for this day. Add one above to anchor it.',
            textAlign: TextAlign.center,
            style: PlannerVisualTokens.captionItalic.copyWith(fontSize: 15),
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
              onMoveToTomorrow: todos[i].state == RhythmItemState.done
                  ? null
                  : () => unawaited(_moveTodoToTomorrow(i)),
              onDelete: () => unawaited(_deleteTodo(i)),
            ),
            if (i != todos.length - 1)
              Divider(
                height: 20,
                thickness: 0.5,
                color: PlannerVisualTokens.gold.withValues(
                  alpha: PlannerVisualTokens.liftedAlpha(0.07),
                ),
              ),
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
            scrollPadding: keyboardManagedTextFieldScrollPadding,
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
    ValueChanged<NutritionItem>? onOpenItem,
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

    final columns = <DataColumn>[
      const DataColumn(label: Text('Nutrient')),
      const DataColumn(label: Text('Source')),
      const DataColumn(label: Text('Purpose')),
    ];

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
                columns: columns,
                rows: items
                    .map(
                      (item) => DataRow(
                        onSelectChanged: onOpenItem == null
                            ? null
                            : (_) => onOpenItem(item),
                        cells: [
                          DataCell(Text(_presentableText(item.nutrient))),
                          DataCell(Text(_presentableText(item.source))),
                          DataCell(Text(_presentableText(item.purpose))),
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

  String _nutritionTimeLabel(BuildContext context, NutritionItem item) {
    return item.schedule.time.format(context);
  }

  Future<void> _removeNutritionItemFromDay(
    NutritionItem item, {
    required int decanDay,
  }) async {
    final targetDate = _nutritionDateForDecanDay(decanDay);
    final stateKey = _nutritionCompletionKey(targetDate, item.id);
    final updatedStates = Map<String, RhythmItemState>.from(
      _nutritionStatesByKey,
    )..remove(stateKey);
    await _saveNutritionStatesToPrefs(updatedStates);

    final result = plannerRemoveNutritionDayMappings([
      item,
    ], decanDay: decanDay);
    if (result.deletedItemIds.contains(item.id)) {
      await _deleteNutritionItem(item);
      return;
    } else if (result.items.isNotEmpty) {
      await _saveNutritionItemEdits([result.items.first]);
      final dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
      await _eventsRepo.deleteByClientIdPrefix('nutrition:${item.id}:$dateKey');
      await _plannerBadgeRepo.syncNutritionState(
        item: item,
        date: targetDate,
        state: RhythmItemState.pending,
      );
    }

    if (mounted) {
      setState(() {
        _nutritionStatesByKey = updatedStates;
      });
    }
  }

  Future<bool> _confirmRemoveNutritionItemFromDay(
    NutritionItem item, {
    required int decanDay,
    required BuildContext dialogContext,
  }) async {
    final label = _nutritionItemLabel(item);
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Delete nutrition item?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove "$label" from Day $decanDay?',
          style: const TextStyle(color: Colors.white70),
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
    if (confirmed != true) return false;
    await _removeNutritionItemFromDay(item, decanDay: decanDay);
    return true;
  }

  Future<bool> _showNutritionItemEditor(
    NutritionItem item, {
    required int decanDay,
    required BuildContext sheetContext,
  }) async {
    final sourceController = TextEditingController(text: item.source);
    final nutrientController = TextEditingController(text: item.nutrient);
    final purposeController = TextEditingController(text: item.purpose);
    var everyDay = plannerNutritionAppliesEveryDay(item);
    var isSaving = false;
    String? error;

    try {
      final changed = await showModalBottomSheet<bool>(
        context: sheetContext,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              InputDecoration fieldDecoration(String label) {
                return InputDecoration(
                  labelText: label,
                  labelStyle: PlannerVisualTokens.captionItalic.copyWith(
                    color: PlannerVisualTokens.gold.withValues(
                      alpha: PlannerVisualTokens.liftedAlpha(0.46),
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: RhythmTheme.aurora),
                  ),
                );
              }

              Widget field({
                required TextEditingController controller,
                required String label,
              }) {
                return TextField(
                  controller: controller,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: RhythmTheme.subheading,
                  decoration: fieldDecoration(label),
                );
              }

              final bottomInset = keyboardInsetOf(context);
              return SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: KemeticGold.text(
                                'Day $decanDay nutrition',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'GentiumPlus',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
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
                              error!,
                              style: RhythmTheme.subheading.copyWith(
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        field(controller: sourceController, label: 'Source'),
                        const SizedBox(height: 12),
                        field(
                          controller: nutrientController,
                          label: 'Nutrient',
                        ),
                        const SizedBox(height: 12),
                        field(controller: purposeController, label: 'Purpose'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Time',
                              style: RhythmTheme.label.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _nutritionTimeLabel(context, item),
                              style: RhythmTheme.subheading.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: everyDay,
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setSheetState(() {
                                        everyDay = value ?? false;
                                      });
                                    },
                              activeColor: PlannerVisualTokens.gold,
                              checkColor: Colors.black,
                            ),
                            Text('Every day', style: RhythmTheme.subheading),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final removed =
                                          await _confirmRemoveNutritionItemFromDay(
                                            item,
                                            decanDay: decanDay,
                                            dialogContext: context,
                                          );
                                      if (removed && context.mounted) {
                                        Navigator.of(context).pop(true);
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Delete'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: RhythmTheme.aurora,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final source = sourceController.text
                                          .trim();
                                      final nutrient = nutrientController.text
                                          .trim();
                                      final purpose = purposeController.text
                                          .trim();
                                      if (source.isEmpty && nutrient.isEmpty) {
                                        setSheetState(() {
                                          error =
                                              'Add a nutrient or source first.';
                                        });
                                        return;
                                      }
                                      setSheetState(() {
                                        isSaving = true;
                                        error = null;
                                      });
                                      final edited =
                                          plannerNutritionWithEveryDayMapping(
                                            item.copyWith(
                                              source: source,
                                              nutrient: nutrient,
                                              purpose: purpose,
                                            ),
                                            activeDecanDay: decanDay,
                                            everyDay: everyDay,
                                          );
                                      try {
                                        await _saveNutritionItemEdits([edited]);
                                        if (context.mounted) {
                                          Navigator.of(context).pop(true);
                                        }
                                      } catch (_) {
                                        if (!context.mounted) return;
                                        setSheetState(() {
                                          isSaving = false;
                                          error =
                                              'Could not update nutrition item.';
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return changed == true;
    } finally {
      sourceController.dispose();
      nutrientController.dispose();
      purposeController.dispose();
    }
  }

  Future<void> _showNutritionFullscreen(int decanDay, String decanName) async {
    var dialogItems = _itemsForDecanDay(
      decanDay,
    ).map((item) => item.copyWith()).toList();
    var isSaving = false;
    String? dialogError;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Nutrition detail',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> deleteAllForDay() async {
              final confirmed = await showDialog<bool>(
                context: modalContext,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.black87,
                  title: const Text(
                    'Delete all?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    'Remove all nutrition entries from Day $decanDay?',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete all'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              setModalState(() {
                isSaving = true;
                dialogError = null;
              });
              try {
                for (final item in [...dialogItems]) {
                  await _removeNutritionItemFromDay(item, decanDay: decanDay);
                }
                if (!modalContext.mounted) return;
                setModalState(() {
                  dialogItems = _itemsForDecanDay(
                    decanDay,
                  ).map((item) => item.copyWith()).toList();
                  isSaving = false;
                });
              } catch (_) {
                if (!modalContext.mounted) return;
                setModalState(() {
                  isSaving = false;
                  dialogError = 'Could not delete nutrition entries.';
                });
              }
            }

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
                          if (dialogItems.isNotEmpty)
                            TextButton(
                              onPressed: isSaving ? null : deleteAllForDay,
                              child: const Text('Delete all'),
                            ),
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
                          onOpenItem: isSaving
                              ? null
                              : (item) async {
                                  final changed =
                                      await _showNutritionItemEditor(
                                        item,
                                        decanDay: decanDay,
                                        sheetContext: modalContext,
                                      );
                                  if (!modalContext.mounted || !changed) {
                                    return;
                                  }
                                  setModalState(() {
                                    dialogItems = _itemsForDecanDay(
                                      decanDay,
                                    ).map((item) => item.copyWith()).toList();
                                    dialogError = null;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap a row to view or edit.',
                        style: RhythmTheme.label.copyWith(
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
  }

  Widget _nutritionGridPage({required int index, required String decanName}) {
    final decanDay = index + 1;
    final items = _itemsForDecanDay(decanDay);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: items.isEmpty
          ? () => _showNutritionFullscreen(decanDay, decanName)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(0.16),
          ),
          borderRadius: BorderRadius.circular(PlannerVisualTokens.plateRadius),
          border: Border.all(
            color: PlannerVisualTokens.gold.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.08),
            ),
            width: 0.5,
          ),
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
                        fontFamily: PlannerVisualTokens.serifFamily,
                        fontFamilyFallback: PlannerVisualTokens.serifFallback,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: PlannerVisualTokens.gold.withValues(
                      alpha: PlannerVisualTokens.liftedAlpha(0.08),
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: PlannerVisualTokens.gold.withValues(
                        alpha: PlannerVisualTokens.liftedAlpha(0.28),
                      ),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'Day $decanDay',
                    style: TextStyle(
                      color: PlannerVisualTokens.gold.withValues(
                        alpha: PlannerVisualTokens.liftedAlpha(0.74),
                      ),
                      fontFamily: PlannerVisualTokens.sansFamily,
                      fontFamilyFallback: PlannerVisualTokens.sansFallback,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
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
                        style: PlannerVisualTokens.captionItalic.copyWith(
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 14,
                        thickness: 0.5,
                        color: PlannerVisualTokens.gold.withValues(
                          alpha: PlannerVisualTokens.liftedAlpha(0.07),
                        ),
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
                              state: itemState,
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
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => unawaited(
                                  _showNutritionItemEditor(
                                    item,
                                    decanDay: decanDay,
                                    sheetContext: context,
                                  ),
                                ),
                                child: Text(
                                  source,
                                  style: PlannerVisualTokens.plateBody.copyWith(
                                    color: const Color(0xFFE0C897).withValues(
                                      alpha: PlannerVisualTokens.liftedAlpha(
                                        0.78,
                                      ),
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
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
              'Tap a source to view or edit.',
              style: PlannerVisualTokens.captionItalic.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSection() {
    final decanName = _currentDecanName();

    return PlannerNutritionSection(
      decanName: decanName,
      activeNutritionDayIndex: _activeNutritionDayIndex,
      nutritionFormOpen: _nutritionFormOpen,
      nutritionLoading: _nutritionLoading,
      nutritionMissingTable: _nutritionMissingTable,
      nutritionLocalOnly: _nutritionLocalOnly,
      nutritionError: _nutritionError,
      nutritionEveryDay: _nutritionEveryDay,
      nutritionPageController: _nutritionPageController,
      nutritionSourceController: _nutritionSourceController,
      nutritionNutrientController: _nutritionNutrientController,
      nutritionPurposeController: _nutritionPurposeController,
      onToggleFormOpen: () {
        setState(() {
          _nutritionFormOpen = !_nutritionFormOpen;
        });
      },
      onNutritionEveryDayChanged: (value) {
        setState(() {
          _nutritionEveryDay = value;
        });
        _persistSessionStateSoon();
      },
      onAddNutritionItem: () => unawaited(_addNutritionItem()),
      onRetryNutrition: () => unawaited(_loadNutrition()),
      onNutritionPageChanged: (index) {
        setState(() {
          _activeNutritionDayIndex = index;
        });
        _persistSessionStateSoon();
      },
      onOpenDecanInfo: _openDecanInfo,
      nutritionPageBuilder: (context, index) {
        return _nutritionGridPage(index: index, decanName: decanName);
      },
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
          : const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PlannerVisualTokens.plateRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.18),
            ),
            Colors.black.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.38),
            ),
          ],
        ),
        border: Border.all(
          color: PlannerVisualTokens.gold.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(0.11),
          ),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.42),
            ),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                          fontFamily: PlannerVisualTokens.serifFamily,
                          fontFamilyFallback: PlannerVisualTokens.serifFallback,
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
                  fontFamily: PlannerVisualTokens.serifFamily,
                  fontFamilyFallback: PlannerVisualTokens.serifFallback,
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
              color: const Color(0xFF100B06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  PlannerVisualTokens.plateRadius,
                ),
              ),
              icon: Icon(
                Icons.more_vert,
                color: PlannerVisualTokens.gold.withValues(
                  alpha: PlannerVisualTokens.liftedAlpha(0.62),
                ),
              ),
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
    return PlannerNotesSection(
      notesLocalOnly: _notesLocalOnly,
      noteInputController: _noteInputController,
      notes: _notes,
      activeNoteIndex: _activeNoteIndex,
      notePageController: _notePageController,
      addHeroTag: widget.embedded ? null : 'today_alignment_add_note',
      onAddNote: () => unawaited(_addNote()),
      onShowNotePicker: _showNotePicker,
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
      noteCardBuilder: (context, index) {
        return _noteCard(context, _notes[index], index: index);
      },
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

  Widget _plannerLoadingBar({double widthFactor = 1, double height = 10}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildPlannerLoadingSlot({
    required String label,
    String? detail,
    double minHeight = 86,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(14),
      decoration: RhythmTheme.frostSurface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: RhythmTheme.subheading.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: RhythmTheme.label.copyWith(color: Colors.white54),
            ),
          ],
          const SizedBox(height: 12),
          _plannerLoadingBar(widthFactor: 0.82),
          const SizedBox(height: 8),
          _plannerLoadingBar(widthFactor: 0.56),
        ],
      ),
    );
  }

  Widget _plannerContent({bool embedded = false}) {
    final dateLabel = _formatDateLabel(_todayLocal);
    final content = FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        final plannerLoading =
            snapshot.connectionState == ConnectionState.waiting;

        if (!plannerLoading && snapshot.hasError) {
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

        if (!plannerLoading && _missingTables) {
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

        if (!plannerLoading && _friendlyError != null) {
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
        final progressPercent = (progress * 100).round();
        final plannerAction = _todayPlannerAction();
        final listBottomPadding = bottomPaddingAboveGlobalChrome(context, 32);
        final keyboardInset = keyboardInsetOf(context);
        final effectiveListBottomPadding = math.max(
          listBottomPadding,
          keyboardInset + 32,
        );

        final question = plannerAction == null
            ? null
            : KemeticDayButton(
                dayKey: plannerAction.dayKey,
                kYear: plannerAction.kYear,
                autoOpen: _shouldOpenDayCardOnLoad,
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
              );

        final plannerHeaderSections = <Widget>[
          PlannerWeighingHeader(
            percent: progressPercent,
            dateLabel: dateLabel,
            question: question,
          ),
          const PlannerHorizon(),
        ];

        final todoSection = PlannerTodoSection(
          activeDayLabel: _formatDateLabel(_activeTodoDay, short: true),
          activeDayIsToday: _sameDay(_activeTodoDay, _todayLocal),
          dateAccentColor: _dateAccentColor(),
          commitmentInputController: _commitmentInputController,
          plannerLoading: plannerLoading,
          loadingSlot: _buildPlannerLoadingSlot(
            label: 'Restoring commitments',
            detail: 'Your to-dos will fill in here.',
            minHeight: _todoPageHeightEstimate(),
          ),
          todoPageHeight: _todoPageHeightEstimate(),
          todoPageController: _todoPageController,
          todoDayCount: _todoDays.length,
          activeTodoDayIndex: _activeTodoDayIndex,
          onAddTodo: () => unawaited(_commitNewTodo()),
          onTodoPageChanged: _onTodoPageChanged,
          todoPageBuilder: (context, index) {
            final day = _todoDays[index];
            return _buildTodoDayPage(day);
          },
        );

        final completedSection = PlannerCompletedSection(
          plannerLoading: plannerLoading,
          loadingSlot: _buildPlannerLoadingSlot(
            label: 'Restoring completed moments',
            detail: 'Finished items will appear in this same slot.',
          ),
          completedItems: _completed(),
        );

        const todoCenterKey = ValueKey<String>('planner-todo-scroll-center');
        final list = _shouldStartOnTodoSection
            ? CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                center: todoCenterKey,
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate(plannerHeaderSections),
                  ),
                  SliverToBoxAdapter(
                    child: PlannerWall(
                      bottomPadding: 0,
                      children: [
                        _buildNotesSection(),
                        _buildNutritionSection(),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    key: todoCenterKey,
                    child: PlannerWall(
                      topPadding: PlannerVisualTokens.plateGap,
                      bottomPadding: effectiveListBottomPadding,
                      children: [todoSection, completedSection],
                    ),
                  ),
                ],
              )
            : CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate(plannerHeaderSections),
                  ),
                  SliverToBoxAdapter(
                    child: PlannerWall(
                      bottomPadding: effectiveListBottomPadding,
                      children: [
                        _buildNotesSection(),
                        _buildNutritionSection(),
                        todoSection,
                        completedSection,
                      ],
                    ),
                  ),
                ],
              );

        return PlannerWarmBackground(
          percent: progressPercent,
          enabled: !embedded,
          child: Stack(children: [list, _fullscreenOverlay()]),
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
        child: KemeticKeyboardRevealScope(enabled: false, child: content),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: true,
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
        KemeticAppBarAction(
          tooltip: 'New note',
          icon: const GlossyIcon(
            icon: Icons.add,
            gradient: goldGloss,
            size: 23,
          ),
          onPressed: () {
            unawaited(_openCalendarQuickAdd());
          },
        ),
        KemeticAppBarAction(
          tooltip: 'Search notes',
          icon: const KemeticAppBarSearchIcon(),
          onPressed: () {
            unawaited(CalendarPage.openSearchFromAnyContext(context));
          },
        ),
        KemeticAppBarAction(
          tooltip: 'Today',
          icon: const KemeticAppBarTodayIcon(),
          onPressed: () {
            NavigationTrace.instance.record('Today app-bar tap fired');
            CalendarPage.openMainCalendarAtToday(context);
          },
        ),
        KemeticAppBarAction(
          tooltip: 'My Profile',
          icon: const KemeticAppBarProfileIcon(),
          onPressed: _openProfilePage,
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_buildTraceRecorded && !widget.embedded) {
      _buildTraceRecorded = true;
      NavigationTrace.instance.record(
        'PlannerPage build first frame',
        state: <String, Object?>{
          'timestampMs': DateTime.now().millisecondsSinceEpoch,
          'openedFromCalendar': widget.openedFromCalendar,
          'route': _routeForNavigationTrace(context),
          'mounted': mounted,
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavigationTrace.instance.record(
          'PlannerPage first frame completed',
          state: <String, Object?>{
            'timestampMs': DateTime.now().millisecondsSinceEpoch,
            'openedFromCalendar': widget.openedFromCalendar,
            'route': _routeForNavigationTrace(context),
            'mounted': mounted,
          },
        );
      });
    }
    final content = _plannerContent(embedded: widget.embedded);

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: content,
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

class DecanInfoPage extends StatelessWidget {
  const DecanInfoPage({super.key, required this.dayKey, required this.info});

  final String dayKey;
  final KemeticDayInfo info;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          onPressed: () => popOrGo(context, '/rhythm/today'),
        ),
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
                  MeduGlyphText(
                    info.meduNeter.glyph,
                    style: RhythmTheme.subheading,
                  ),
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
