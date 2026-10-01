import '../../../data/account_storage/planner_account_store.dart';
import '../widgets/planner/planner_note_text.dart';
import 'dart:async';
import '../../../data/account_view_cache.dart';
import '../planner/planner_overview.dart';
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
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
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
    this.sheet = false,
  });

  final bool embedded;
  final bool openedFromCalendar;
  final bool openDayCardOnLoad;
  final PlannerLaunchIntent? launchIntent;
  final bool sheet;

  @override
  State<TodaysAlignmentPage> createState() => _TodaysAlignmentPageState();
}

const Key plannerSheetRouteKey = ValueKey<String>('planner-sheet-route');

class PlannerSheetRoutePage extends StatefulWidget {
  const PlannerSheetRoutePage({super.key, required this.launchIntent});

  final PlannerLaunchIntent launchIntent;

  @override
  State<PlannerSheetRoutePage> createState() => _PlannerSheetRoutePageState();
}

class _PlannerSheetRoutePageState extends State<PlannerSheetRoutePage> {
  final GlobalKey<_TodaysAlignmentPageState> _plannerKey = GlobalKey();
  bool _closeRequested = false;

  Future<void> _closeRoute() async {
    if (_closeRequested) return;
    _closeRequested = true;
    await _plannerKey.currentState?._persistSessionState();
    if (!mounted) return;
    closeOrReturn(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return UtilitySheetRouteScaffold(
      key: plannerSheetRouteKey,
      semanticLabel: 'Planner',
      onClose: () => unawaited(_closeRoute()),
      child: TodaysAlignmentPage(
        key: _plannerKey,
        sheet: true,
        launchIntent: widget.launchIntent,
      ),
    );
  }
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
  final PlannerAccountStore _plannerStorage = PlannerAccountStore.of(
    Supabase.instance.client,
  );
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

  bool _showGregorianDates = false;
  Timer? _midnightTimer;
  List<NutritionItem> _nutritionItems = [];
  Map<String, RhythmItemState> _nutritionStatesByKey = {};
  bool _nutritionLoading = true;

  bool _nutritionLocalOnly = false;
  String? _nutritionError;
  bool _nutritionStatesLoaded = false;

  int _activeNutritionDayIndex = 0;
  bool _nutritionFormOpen = false;
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
    _plannerStorage.addListener(_plannerChanged);
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
    _plannerStorage.removeListener(_plannerChanged);
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

  bool _hasWarmPlanner = false;
  Future<void> _load() async {
    final owner = _currentUserId;
    if (!_hasWarmPlanner && owner != null) {
      try {
        final local = RhythmRepo(Supabase.instance.client, cachedOnly: true);
        final items = await local.fetchTodaysAlignment();
        final todos = await local.fetchTodos();
        if (!mounted || _currentUserId != owner) return;
        if (items.friendlyError == null && todos.friendlyError == null) {
          setState(() {
            _alignmentItems = items.data;
            _missingTables = false;
            _friendlyError = null;
            _hasWarmPlanner = true;
          });
          _hydrateTodos(todos.data, focusDay: _activeTodoDay);
        }
      } catch (_) {}
    }
    final todosAtRead = _todosByDay;
    try {
      final itemsFuture = _repo.fetchTodaysAlignment();
      final todosFuture = _repo.fetchTodos();
      final items = await itemsFuture;
      final todos = await todosFuture;
      if (!mounted) return;
      if (!identical(todosAtRead, _todosByDay)) return;
      final focusDay = _sameDay(_currentTodoWindowAnchorDay(), _todayLocal)
          ? _activeTodoDay
          : _todayLocal;
      final repoErr = items.friendlyError ?? todos.friendlyError;
      if (_currentUserId != owner) return;
      if (repoErr != null && _hasWarmPlanner) return;
      _hasWarmPlanner = repoErr == null;
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
      if (_hasWarmPlanner) return;
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

  void _plannerChanged() {
    if (!mounted) return;
    final notes =
        _plannerStorage
            .rows('notes')
            .map(
              (r) => RhythmNote(
                id: r['id'] as String,
                text: r['body'] as String? ?? '',
                position: (r['position'] as num?)?.toInt() ?? 0,
                createdAt:
                    DateTime.tryParse(r['created_at'] as String? ?? '') ??
                    DateTime(1970),
              ),
            )
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final nutrition = _plannerStorage
        .rows('nutrition')
        .map(NutritionItem.fromRow)
        .toList();
    setState(() {
      _notes = notes;
      _activeNoteIndex = _clampNoteIndex(notes.length);
      if (_fullscreenNote != null) {
        _fullscreenNote = notes
            .where((n) => n.id == _fullscreenNote!.id)
            .firstOrNull;
      }
      _notesLocalOnly = _plannerStorage.message('notes') != null;
      _nutritionItems = nutrition;
      _nutritionLocalOnly = _plannerStorage.pending('nutrition');
      _nutritionError = _plannerStorage.message('nutrition');
      _nutritionLoading = false;
    });
  }

  Future<bool> _plannerWrite(Future<void> Function() write) async {
    try {
      await write();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Could not preserve this change. Please retry.',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _reviewPlannerChanges(String kind) async {
    final uid = _currentUserId;
    for (final conflict in _plannerStorage.conflicts(kind)) {
      if (!mounted || _currentUserId != uid) return;
      final request = Map<String, dynamic>.from(conflict['request'] as Map);
      final remote = (conflict['result'] as Map)['row'] as Map?;
      String describe(Map? row) {
        if (row == null) return 'Deleted';
        if (kind == 'notes') {
          return row.containsKey('body')
              ? '${row['body']}'
              : 'Note order: ${(row['position'] as num? ?? 0) + 1}';
        }
        const labels = {
          'nutrient': 'Nutrient',
          'source': 'Source',
          'purpose': 'Purpose',
          'mode': 'Schedule',
          'days_of_week': 'Weekdays',
          'decan_days': 'Decan days',
          'repeat': 'Repeat',
          'time_h': 'Hour',
          'time_m': 'Minute',
          'alert_offset_minutes': 'Reminder minutes before',
          'enabled': 'Enabled',
        };
        return labels.entries
            .where((e) => row.containsKey(e.key))
            .map((e) => '${e.value}: ${row[e.key] ?? 'None'}')
            .join('\n');
      }

      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Review saved versions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account version'),
                Text(describe(remote)),
                const SizedBox(height: 16),
                const Text('Your change'),
                Text(
                  request['delete'] == true
                      ? 'Delete this item'
                      : describe(request['change'] as Map),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep account'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use my version'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted || _currentUserId != uid) return;
      await _plannerWrite(
        () => _plannerStorage.resolve(conflict, keepMine: choice),
      );
    }
  }

  Future<void> _loadNutrition() async {
    await _plannerWrite(() async {
      await _plannerStorage.restore();
      await _plannerStorage.refresh('nutrition');
    });
  }

  Future<void> _addNutritionItem() async {
    final nutrient = _nutritionNutrientController.text.trim();
    final source = _nutritionSourceController.text.trim();
    if (nutrient.isEmpty && source.isEmpty) return;
    final item = NutritionItem(
      id: '',
      nutrient: nutrient,
      source: source,
      purpose: _nutritionPurposeController.text.trim(),
      enabled: true,
      schedule: IntakeSchedule(
        mode: IntakeMode.decan,
        decanDays: {_activeNutritionDayIndex + 1},
        repeat: true,
        time: const TimeOfDay(hour: 9, minute: 0),
      ),
    );
    final saved = await _plannerWrite(() async {
      final change = item.toInsert(userId: _currentUserId ?? '')
        ..remove('user_id');
      await _plannerStorage.save('nutrition', change);
    });
    if (saved && mounted) {
      _nutritionNutrientController.clear();
      _nutritionSourceController.clear();
      _nutritionPurposeController.clear();
    }
  }

  Future<List<NutritionItem>> _saveNutritionItemEdits(
    List<NutritionItem> items,
  ) async {
    for (final item in items) {
      final change = item.toInsert(userId: _currentUserId ?? '')
        ..remove('user_id');
      final saved = await _plannerWrite(() async {
        await _plannerStorage.save('nutrition', change, id: item.id);
      });
      if (!saved) return _nutritionItems;
    }
    return _nutritionItems;
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

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  DateTime get _todayLocal =>
      DateUtils.dateOnly(widget.launchIntent?.localDate ?? DateTime.now());

  bool get _shouldOpenDayCardOnLoad =>
      widget.openDayCardOnLoad || widget.launchIntent?.openDayCard == true;

  bool get _shouldStartOnTodoSection =>
      widget.launchIntent?.route == '/rhythm/todo';

  String _nutritionChecksPrefsKeyForUser(String? uid) =>
      'today_alignment_nutrition_checks${uid == null ? '' : '_$uid'}';

  Future<Map<String, RhythmItemState>> _loadNutritionStatesFromPrefs([
    String? uid,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues =
        prefs.getStringList(
          '${_nutritionChecksPrefsKeyForUser(uid ?? _currentUserId)}:account',
        ) ??
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
      '${_nutritionChecksPrefsKeyForUser(uid ?? _currentUserId)}:account',
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
    final uid = _currentUserId;
    final range = _currentNutritionDecanRange();
    final localStatesFuture = _loadNutritionStatesFromPrefs();
    final remoteStatesFuture = _plannerBadgeRepo.fetchNutritionStateMap(
      start: range.start,
      end: range.end,
    );
    await _plannerStorage.restore();
    final localStates = _replaceNutritionStateItemIds(
      await localStatesFuture,
      _plannerStorage.legacyIds,
    );
    if (!mounted || _currentUserId != uid) return;
    setState(() {
      _nutritionStatesByKey = localStates;
      _nutritionStatesLoaded = true;
    });
    final statesAtRead = _nutritionStatesByKey;
    Map<String, RhythmItemState> remoteStates = const {};
    var remoteLoaded = false;
    try {
      remoteStates = await remoteStatesFuture;
      remoteLoaded = true;
    } catch (_) {
      remoteStates = const {};
      remoteLoaded = false;
    }
    if (!mounted ||
        _currentUserId != uid ||
        !identical(statesAtRead, _nutritionStatesByKey)) {
      return;
    }
    final mergedStates = remoteLoaded
        ? _mergeNutritionStatesWithServerAuthority(
            localStates,
            remoteStates,
            range,
          )
        : <String, RhythmItemState>{...localStates, ...remoteStates};
    await _saveNutritionStatesToPrefs(mergedStates, uid: uid);
    if (!mounted ||
        _currentUserId != uid ||
        !identical(statesAtRead, _nutritionStatesByKey)) {
      return;
    }
    setState(() {
      _nutritionStatesByKey = mergedStates;
      _nutritionStatesLoaded = true;
    });
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
    final uid = _currentUserId;
    try {
      await _plannerStorage.flush();
      await _plannerBadgeRepo.syncNutritionState(
        item: item,
        date: date,
        state: state,
      );
    } catch (_) {
      if (mounted && _currentUserId == uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not confirm this checkmark in your account. Please retry.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted || _currentUserId != uid) return;
    final key = _nutritionCompletionKey(date, item.id);
    final updatedStates = Map<String, RhythmItemState>.from(
      _nutritionStatesByKey,
    );
    if (state == RhythmItemState.pending) {
      updatedStates.remove(key);
    } else {
      updatedStates[key] = state;
    }
    setState(() => _nutritionStatesByKey = updatedStates);
    await _saveNutritionStatesToPrefs(updatedStates, uid: uid);
    unawaited(_plannerBadgeRepo.refreshKnowledgeGraph());
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
    await openDetailRoute<void>(
      context,
      '/rhythm/decan/${Uri.encodeComponent(dayKey)}',
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
    if (!await _plannerWrite(() async {
      await _eventsRepo.deleteByClientIdPrefix('nutrition:${item.id}:');
      await _plannerStorage.save('nutrition', {}, id: item.id, delete: true);
    })) {
      return;
    }

    final updatedStates = Map<String, RhythmItemState>.from(
      _nutritionStatesByKey,
    )..removeWhere((key, _) => key.endsWith('::${item.id}'));
    await _saveNutritionStatesToPrefs(updatedStates);
    final updatedItems = [
      for (final current in _nutritionItems)
        if (current.id != item.id) current,
    ];

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

  List<RhythmNote> _withPositions(List<RhythmNote> notes) => [
    for (var i = 0; i < notes.length; i++) notes[i].copyWith(position: i),
  ];

  Future<void> _loadNotes() async {
    await _plannerWrite(() async {
      await _plannerStorage.restore();
      await _plannerStorage.refresh('notes');
    });
  }

  Future<void> _addNote() async {
    final text = _noteInputController.text.trim();
    if (text.isEmpty) return;
    String? id;
    final saved = await _plannerWrite(() async {
      id = await _plannerStorage.save('notes', {
        'body': text,
        'position': _notes.length,
      });
    });
    if (saved && mounted) {
      _noteInputController.clear();
      final index = _notes.indexWhere((n) => n.id == id);
      if (index >= 0) {
        setState(() => _activeNoteIndex = index);
        _syncNotePageToActiveIndex();
      }
    }
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

    _syncNotePageToActiveIndex();
    _persistSessionStateSoon();

    if (persistOrder) {
      for (var i = 0; i < updated.length; i++) {
        final note = updated[i];
        if (!await _plannerWrite(() async {
          await _plannerStorage.save('notes', {'position': i}, id: note.id);
        })) {
          break;
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
    final updatedText = await showEditableDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('Edit note', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            autofocus: false,
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

    await _plannerWrite(() async {
      await _plannerStorage.save('notes', {
        'body': updatedText,
      }, id: original.id);
    });
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

    if (!await _plannerWrite(() async {
      await _plannerStorage.save('notes', {}, id: note.id, delete: true);
    })) {
      return;
    }

    final updated = _notes.where((n) => n.id != note.id).toList();
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
    Future<void> Function(NutritionItem item)? onDeleteItem,
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
      if (editable && onDeleteItem != null)
        const DataColumn(label: Text('Delete')),
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
                          if (editable && onDeleteItem != null)
                            DataCell(
                              IconButton(
                                onPressed: () => unawaited(onDeleteItem(item)),
                                tooltip: 'Delete item',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
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

    void disposeItemControllers(String itemId) {
      nutrientControllers.remove(itemId)?.dispose();
      sourceControllers.remove(itemId)?.dispose();
      purposeControllers.remove(itemId)?.dispose();
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
                            onDeleteItem: isEditing && !isSaving
                                ? (item) async {
                                    final label = _nutritionItemLabel(item);
                                    final confirmed = await showDialog<bool>(
                                      context: modalContext,
                                      builder: (dialogContext) => AlertDialog(
                                        backgroundColor: Colors.black87,
                                        title: const Text(
                                          'Delete nutrition item?',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: Text(
                                          'Delete "$label"? This also removes its reminders and calendar entries.',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;

                                    setModalState(() {
                                      dialogError = null;
                                      isSaving = true;
                                    });
                                    try {
                                      await _deleteNutritionItem(item);
                                      if (!modalContext.mounted) return;
                                      disposeItemControllers(item.id);
                                      final remaining = [
                                        for (final current in dialogItems)
                                          if (current.id != item.id) current,
                                      ];
                                      setModalState(() {
                                        dialogItems = remaining;
                                        isEditing = remaining.isNotEmpty;
                                        isSaving = false;
                                      });
                                      ScaffoldMessenger.of(
                                        modalContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Deleted $label from nutrition.',
                                          ),
                                        ),
                                      );
                                    } catch (_) {
                                      if (!modalContext.mounted) return;
                                      setModalState(() {
                                        isSaving = false;
                                        dialogError =
                                            'Could not delete nutrition item.';
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Edit or delete rows, then save the remaining fields.',
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
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Double-tap for nutrient + purpose.',
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
      nutritionMissingTable: false,
      nutritionLocalOnly: _nutritionLocalOnly,
      nutritionError: _nutritionError,
      onReview: _plannerStorage.conflicts('nutrition').isEmpty
          ? null
          : () => unawaited(_reviewPlannerChanges('nutrition')),
      nutritionPageController: _nutritionPageController,
      nutritionSourceController: _nutritionSourceController,
      nutritionNutrientController: _nutritionNutrientController,
      nutritionPurposeController: _nutritionPurposeController,
      onToggleFormOpen: () {
        setState(() {
          _nutritionFormOpen = !_nutritionFormOpen;
        });
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
          : Center(child: PlannerNoteText(note.text)),
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
      syncMessage: _plannerStorage.message('notes'),
      onReview: _plannerStorage.conflicts('notes').isEmpty
          ? null
          : () => unawaited(_reviewPlannerChanges('notes')),
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

  Widget _plannerContent({bool embedded = false, bool sheet = false}) {
    final dateLabel = _formatDateLabel(_todayLocal);
    final content = FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        final plannerLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !_hasWarmPlanner;

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
        if (!plannerLoading &&
            !_nutritionLoading &&
            _nutritionStatesLoaded &&
            _friendlyError == null &&
            _nutritionError == null) {
          final uid = _currentUserId;
          if (uid != null) {
            final overview = PlannerOverview(
              todos: List.unmodifiable(
                _todosByDay.values.expand((rows) => rows),
              ),
              nutrition: List.unmodifiable(_nutritionItems),
              nutritionStates: Map.unmodifiable(_nutritionStatesByKey),
              alignment: List.unmodifiable(_alignmentItems),
              note: _notes.isEmpty
                  ? ''
                  : _notes[_activeNoteIndex.clamp(0, _notes.length - 1)].text,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _currentUserId == uid) {
                AccountViewCache.instance.publish(
                  uid,
                  'planner.overview',
                  overview,
                );
              }
            });
          }
        }
        final plannerAction = _todayPlannerAction();
        final listBottomPadding = bottomPaddingAboveGlobalChrome(context, 32);

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
                      bottomPadding: listBottomPadding,
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
                      bottomPadding: listBottomPadding,
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
        top: !embedded && !sheet,
        bottom: true,
        left: true,
        right: true,
        child: content,
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
    final content = _plannerContent(
      embedded: widget.embedded,
      sheet: widget.sheet,
    );

    if (widget.embedded) {
      return content;
    }

    if (widget.sheet) {
      return Material(color: Colors.black, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: content,
    );
  }

  double _progress() => plannerCompletion([
    ...(_todosByDay[_todayLocal] ?? const <RhythmTodo>[]).map((t) => t.state),
    ..._todayNutritionItems().map(
      (n) => _nutritionStateForItem(n, date: _todayLocal),
    ),
  ], _alignmentItems.map((a) => a.state));

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
