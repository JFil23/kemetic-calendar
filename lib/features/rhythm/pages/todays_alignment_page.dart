import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/kemetic_converter.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/rhythm/rhythm_add_flow.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/rhythm_repo.dart';
import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import '../widgets/alignment_item_row.dart';
import '../widgets/rhythm_section_card.dart';
import '../widgets/rhythm_states.dart';
import '../widgets/rhythm_todo_row.dart';

class TodaysAlignmentPage extends StatefulWidget {
  const TodaysAlignmentPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TodaysAlignmentPage> createState() => _TodaysAlignmentPageState();
}

class _TodaysAlignmentPageState extends State<TodaysAlignmentPage> {
  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);
  late Future<void> _future;
  final TextEditingController _commitmentInputController =
      TextEditingController();
  final TextEditingController _noteInputController = TextEditingController();
  final PageController _todoPageController = PageController(
    viewportFraction: 0.96,
  );
  final PageController _notePageController = PageController(
    viewportFraction: 0.9,
  );
  PageController? _fullscreenPageController;
  final KemeticConverter _kemeticConverter = KemeticConverter();
  int? _pendingTodoPageIndex;
  bool _pendingTodoPageAnimate = false;
  bool _todoPageJumpScheduled = false;

  List<RhythmItem> _alignmentItems = [];
  List<RhythmTodo> _todos = [];
  Map<DateTime, List<RhythmTodo>> _todosByDay = {};
  List<DateTime> _todoDays = [];
  List<RhythmNote> _notes = [];
  int _activeNoteIndex = 0;
  int _activeTodoDayIndex = 0;
  RhythmNote? _fullscreenNote;
  bool _isSyncingNotePages = false;
  bool _missingTables = false;
  String? _friendlyError;
  bool _notesLocalOnly = false;
  bool _notesLocalNoticeShown = false;
  bool _showGregorianDates = false;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    unawaited(_loadNotes());
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
  void dispose() {
    _commitmentInputController.dispose();
    _noteInputController.dispose();
    _todoPageController.dispose();
    _notePageController.dispose();
    _fullscreenPageController?.dispose();
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.fetchTodaysAlignment();
      final todos = await _repo.fetchTodos();
      if (!mounted) return;
      final repoErr = items.friendlyError ?? todos.friendlyError;
      setState(() {
        _missingTables = items.missingTables || todos.missingTables;
        _friendlyError = repoErr != null
            ? RhythmUserMessages.loadFailedTodayAlignment
            : null;
        _alignmentItems = items.data;
      });
      _hydrateTodos(todos.data, focusDay: _todayLocal);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _missingTables = false;
        _friendlyError = RhythmUserMessages.loadFailedTodayAlignment;
        _alignmentItems = [];
        _todos = [];
        _todoDays = [_todayLocal];
        _todosByDay = {_todayLocal: []};
        _activeTodoDayIndex = 0;
      });
    }
  }

  void _updateAlignment(int index, RhythmItemState state) {
    setState(() {
      _alignmentItems = [
        for (int i = 0; i < _alignmentItems.length; i++)
          i == index
              ? _alignmentItems[i].copyWith(state: state)
              : _alignmentItems[i],
      ];
    });
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
    if (!result.data) return;
    _commitmentInputController.clear();
    setState(() {
      _future = _load();
    });
  }

  String _prefsKeyForUser(String? uid) =>
      'today_alignment_notes${uid == null ? '' : '_$uid'}';

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  DateTime get _todayLocal =>
      DateUtils.dateOnly(DateTime.now());

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

  Map<DateTime, List<RhythmTodo>> _groupTodosByDay(
    List<RhythmTodo> todos,
  ) {
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
    final days = grouped.keys
        .map(_normalizeDate)
        .where((d) => !d.isAfter(today))
        .toSet()
        .toList();
    if (!days.any((d) => _sameDay(d, today))) {
      days.add(today);
    }
    // Order oldest -> newest so past days sit to the left of today.
    days.sort((a, b) => a.compareTo(b));
    final start = days.length > 5 ? days.length - 5 : 0;
    final limited = days.sublist(start);

    for (final d in limited) {
      grouped.putIfAbsent(d, () => []);
    }
    return limited.isEmpty ? [today] : limited;
  }

  void _hydrateTodos(List<RhythmTodo> todos, {DateTime? focusDay}) {
    final grouped = _groupTodosByDay(todos);
    final days = _buildTodoDays(grouped);
    final targetDay = focusDay != null ? _normalizeDate(focusDay) : _todayLocal;
    final activeIndex = days.indexWhere((d) => _sameDay(d, targetDay));
    final resolvedIndex = activeIndex >= 0 ? activeIndex : 0;
    final activeDay = days[resolvedIndex];
    setState(() {
      _todosByDay = grouped;
      _todoDays = days;
      _activeTodoDayIndex = resolvedIndex;
      _todos = grouped[activeDay] ?? [];
    });
    _requestTodoPage(resolvedIndex);
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
      _scheduleMidnightRefresh();
    });
  }

  String _formatKemeticDate(DateTime date, {bool short = false}) {
    final kd = _kemeticConverter.fromGregorian(_normalizeDate(date));
    if (kd.epagomenal) {
      return short
          ? 'Epagomenal ${kd.day} · Y${kd.year}'
          : 'Epagomenal Day ${kd.day} · Y${kd.year}';
    }
    final monthName = getMonthById(kd.month).hellenized;
    final base = '$monthName ${kd.day}';
    if (short) {
      return '$base · Y${kd.year}';
    }
    final season = getSeasonName(kd.month);
    final buffer = StringBuffer(base);
    if (season != null) buffer.write(' · $season');
    buffer.write(' · Y${kd.year}');
    return buffer.toString();
  }

  String _formatDateLabel(DateTime date, {bool short = false}) {
    if (_showGregorianDates) {
      final fmt = short ? DateFormat('MMM d, yyyy') : DateFormat('EEEE · MMM d, yyyy');
      return fmt.format(_normalizeDate(date));
    }
    return _formatKemeticDate(date, short: short);
  }

  Color _dateAccentColor() {
    return _showGregorianDates
        ? blue
        : (RhythmTheme.subheading.color ?? Colors.white70);
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

  void _jumpToTodayTodos() {
    final today = _todayLocal;
    final updatedMap = {..._todosByDay}..putIfAbsent(today, () => []);
    final orderedDays = _buildTodoDays(updatedMap);
    final todayIndex =
        orderedDays.indexWhere((d) => _sameDay(d, today)).clamp(0, orderedDays.length - 1);
    setState(() {
      _todoDays = orderedDays;
      _todosByDay = updatedMap;
      _activeTodoDayIndex = todayIndex;
      _todos = updatedMap[orderedDays[todayIndex]] ?? [];
      _future = _load();
    });
    _requestTodoPage(todayIndex, animate: true);
  }

  void _openCalendarShortcut() {
    if (!mounted) return;
    context.go('/');
  }

  void _openProfilePage() {
    final uid = _currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to view your profile.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: uid,
          isMyProfile: true,
        ),
      ),
    );
  }

  void _onTodoPageChanged(int index) {
    if (index < 0 || index >= _todoDays.length) return;
    setState(() {
      _activeTodoDayIndex = index;
      _todos = _todosByDay[_todoDays[index]] ?? [];
    });
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
              onStateChanged: (state) =>
                  unawaited(_persistTodoState(i, state)),
            ),
            if (i != todos.length - 1)
              const Divider(
                height: 18,
                thickness: 0.6,
                color: Colors.white12,
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
                createdAt: DateTime.tryParse(decoded['createdAt'] as String? ?? '') ??
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

  Future<void> _saveNotesToPrefs(
    List<RhythmNote> notes, {
    String? uid,
  }) async {
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
    final result = await _repo.fetchAlignmentNotes();
    final uid = _currentUserId;
    if (!mounted) return;

    final cached = await _loadNotesFromPrefs(uid);

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
    if (_fullscreenPageController?.hasClients == true &&
        updated.isNotEmpty) {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.friendlyError!)));
        return;
      } else if (mounted) {
        setState(() {
          _notesLocalOnly = false;
        });
      }
    }

    final updated = [..._notes]
      ..[index] = original.copyWith(text: updatedText);
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
    await _syncNotes(
      reindexed,
      activeIndex: newActive,
      persistOrder: true,
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
                  const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 18),
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
                  heroTag:
                      widget.embedded ? null : 'today_alignment_add_note',
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
    if (_fullscreenNote == null || _notes.isEmpty)
      return const SizedBox.shrink();
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

        final list = ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
            const SizedBox(height: 14),
            _buildNotesSection(),
            const SizedBox(height: 14),
            RhythmSectionCard(
              title: 'To Do',
              subtitle: 'Add what you want to move today. Tap below to add.',
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
                      hintText: 'Type a commitment, then press return',
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
                    'Swipe to revisit the last 5 days of to-dos.',
                    textAlign: TextAlign.center,
                    style: RhythmTheme.label.copyWith(
                      color: Colors.white54,
                    ),
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
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
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
          ],
        );

        return Stack(children: [list, _fullscreenOverlay()]);
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
          tooltip: 'Today',
          icon: const GlossyIcon(icon: Icons.today, gradient: goldGloss),
          onPressed: _jumpToTodayTodos,
        ),
        IconButton(
          tooltip: 'Calendar',
          icon: const GlossyIcon(icon: Icons.apps, gradient: goldGloss),
          onPressed: _openCalendarShortcut,
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: content,
    );
  }

  double _progress() {
    // Primary progress is driven by To Do list completion.
    if (_todos.isNotEmpty) {
      final totalTodos = _todos.length.toDouble();
      final doneTodos = _todos
          .where((t) => t.state == RhythmItemState.done)
          .length;
      final partialTodos = _todos
          .where((t) => t.state == RhythmItemState.partial)
          .length;
      return (doneTodos + partialTodos * 0.5) / totalTodos;
    }

    // Fallback: use alignment items if no to-dos exist.
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
