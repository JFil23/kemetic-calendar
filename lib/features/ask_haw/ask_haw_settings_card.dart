import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/glossy_text.dart';
import 'ask_haw_catalog.dart';
import 'ask_haw_memory.dart';
import 'ask_haw_memory_repository.dart';

typedef AskHawMemoryRepositoryFactory =
    AskHawMemoryRepository Function(SupabaseClient client);
typedef _MemoryChange = Map<String, dynamic> Function(AskHawMemory current);

/// Account memory is loaded only when Manage is pressed. Keeping the reader in
/// this child leaves Settings startup and the warm-state scheduler unchanged.
class AskHawSettingsCard extends StatefulWidget {
  const AskHawSettingsCard({
    super.key,
    required this.client,
    this.repositoryFactory,
  });
  final SupabaseClient client;
  final AskHawMemoryRepositoryFactory? repositoryFactory;
  @override
  State<AskHawSettingsCard> createState() => _AskHawSettingsCardState();
}

class _AskHawSettingsCardState extends State<AskHawSettingsCard> {
  AskHawMemoryRepository? _repository;
  AskHawMemory? _memory;
  StreamSubscription<AuthState>? _auth;
  String? _owner, _notice;
  int _generation = 0;
  bool _expanded = false, _loading = false, _busy = false;
  bool _readFailed = false, _retryClear = false;
  _MemoryChange? _retryChange;
  late final _publicTitles = {
    for (final content in buildAskHawCatalog().entries)
      content.id: content.title,
  };

  @override
  void initState() {
    super.initState();
    _bindAccount();
  }

  void _bindAccount() {
    _owner = widget.client.auth.currentUser?.id;
    _auth = widget.client.auth.onAuthStateChange.listen((event) {
      final owner = event.session?.user.id;
      if (event.event != AuthChangeEvent.signedOut && owner == _owner) return;
      _release();
      if (!mounted) return;
      setState(() {
        _owner = owner;
        _memory = null;
        _expanded = _loading = _busy = _readFailed = _retryClear = false;
        _retryChange = null;
        _notice = null;
      });
    });
  }

  @override
  void didUpdateWidget(covariant AskHawSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client ||
        oldWidget.repositoryFactory != widget.repositoryFactory) {
      unawaited(_auth?.cancel());
      _release();
      _memory = null;
      _expanded = _loading = _busy = _readFailed = _retryClear = false;
      _retryChange = null;
      _notice = null;
      _bindAccount();
    }
  }

  void _release() {
    _generation++;
    _repository?.dispose();
    _repository = null;
  }

  bool _current(int generation, String owner) =>
      mounted &&
      generation == _generation &&
      _owner == owner &&
      widget.client.auth.currentUser?.id == owner;

  AskHawMemoryRepository get _store => _repository ??=
      widget.repositoryFactory?.call(widget.client) ??
      AskHawMemoryRepository(widget.client);

  Future<void> _read() async {
    final owner = _owner;
    if (owner == null || _loading || _busy) return;
    final generation = ++_generation;
    setState(() {
      _expanded = true;
      _loading = true;
      _notice = null;
    });
    try {
      final memory = await _store.read();
      if (!_current(generation, owner)) return;
      setState(() {
        _memory = memory;
        _readFailed = false;
        _retryChange = null;
        _retryClear = false;
      });
    } catch (_) {
      if (!_current(generation, owner)) return;
      setState(() {
        _readFailed = true;
        _notice = 'Remembered details could not be loaded. Try again.';
      });
    } finally {
      if (_current(generation, owner)) setState(() => _loading = false);
    }
  }

  Future<void> _save(_MemoryChange? change, {bool clear = false}) async {
    final owner = _owner;
    if (owner == null || _memory == null || _busy || _loading) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _notice = null;
      _retryChange = change;
      _retryClear = clear;
    });
    try {
      final store = _store;
      // Rebase the single requested preference/removal on a fresh acknowledged
      // document, so another device's unrelated preferences are preserved.
      final current = clear ? null : await store.read();
      if (!_current(generation, owner)) return;
      final saved = clear
          ? await store.clear()
          : await store.update(change!(current!));
      if (!_current(generation, owner)) return;
      setState(() {
        _memory = saved;
        _retryChange = null;
        _retryClear = false;
        _notice = clear
            ? 'Remembered details cleared.'
            : 'Remembered details updated.';
      });
    } catch (error) {
      if (!_current(generation, owner)) return;
      setState(() {
        if (error is AskHawMemoryConflict) _memory = error.current;
        _notice = error is AskHawMemoryConflict
            ? error.toString()
            : 'The change could not be confirmed. Your request is kept. Try again.';
      });
    } finally {
      if (_current(generation, owner)) setState(() => _busy = false);
    }
  }

  void _preference(String key, Object? value) => unawaited(
    _save(
      (current) => {
        'preferences': {...current.preferences, key: value},
      },
    ),
  );

  void _planningWindow(String? value) {
    final parts = value?.split(':');
    if (parts != null && parts.length != 2) return;
    final start = parts == null ? null : int.tryParse(parts[0]);
    final end = parts == null ? null : int.tryParse(parts[1]);
    if (value != null &&
        (start == null ||
            end == null ||
            start < 0 ||
            end > 24 ||
            start >= end)) {
      return;
    }
    unawaited(
      _save(
        (_) => {
          'preferences': {'availableStartHour': start, 'availableEndHour': end},
        },
      ),
    );
  }

  void _removeFlowDuration(String id) => unawaited(
    _save(
      (_) => {
        'preferences': {
          'flowDurationMinutes': {id: null},
          'flowDurationTitles': {id: null},
        },
      },
    ),
  );

  TimeOfDay? _usualTime(Map<String, dynamic> preferences) {
    final rawHour = preferences['preferredHour'];
    final rawMinute = preferences['preferredMinute'] ?? 0;
    if (rawHour is! num || rawMinute is! num) return null;
    final hour = rawHour.toInt(), minute = rawMinute.toInt();
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _changeUsualTime() async {
    final owner = _owner;
    final initial = _usualTime(_memory?.preferences ?? const {});
    if (owner == null || initial == null || _busy || _loading) return;
    final generation = _generation;
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Usual start time',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: KemeticGold.base,
            surface: Color(0xFF0C0C0C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !_current(generation, owner)) return;
    await _save(
      (_) => {
        'preferences': {
          'preferredHour': selected.hour,
          'preferredMinute': selected.minute,
        },
      },
    );
  }

  void _resetUsualTime() => unawaited(
    _save(
      (_) => {
        'preferences': {'preferredHour': null, 'preferredMinute': null},
      },
    ),
  );

  void _timeOfDayPreference(String value) => unawaited(
    _save(
      (_) => {
        'preferences': {
          'preferredTimeOfDay': value,
          'preferredHour': null,
          'preferredMinute': null,
        },
      },
    ),
  );

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;
    final duration = memory?.preferences['preferredDurationMinutes'];
    final timeOfDay = memory?.preferences['preferredTimeOfDay'];
    final preferences = memory?.preferences ?? const <String, dynamic>{};
    final startHour = preferences['availableStartHour'];
    final endHour = preferences['availableEndHour'];
    final flowDurations = preferences['flowDurationMinutes'];
    final flowTitles = preferences['flowDurationTitles'];
    final titles = <String, String>{
      if (memory != null) ..._publicTitles,
      if (memory != null)
        for (final signal in memory.signals.entries)
          if (signal.value is Map && (signal.value as Map)['title'] is String)
            signal.key: (signal.value as Map)['title'] as String,
    };
    return AskHawSettingsView(
      expanded: _expanded,
      loading: _loading,
      available: memory != null,
      busy: _busy,
      suggestionsEnabled: memory?.suggestionsEnabled ?? true,
      preferredDurationMinutes: duration is num ? duration.toInt() : null,
      preferredTimeOfDay: timeOfDay is String ? timeOfDay : 'any',
      usualStartTime: _usualTime(preferences),
      planningWindowKey: startHour == null && endHour == null
          ? null
          : '${startHour ?? '?'}:${endHour ?? '?'}',
      flowDurationMinutes: {
        if (flowDurations is Map)
          for (final entry in flowDurations.entries)
            if (entry.key is String && entry.value is num)
              entry.key as String: (entry.value as num).toInt(),
      },
      flowDurationTitles: {
        if (flowTitles is Map)
          for (final entry in flowTitles.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      },
      bindings: memory?.bindings ?? const {},
      hiddenSuggestions: memory?.hiddenSuggestions ?? const {},
      contentTitles: titles,
      notice: _owner == null
          ? 'Sign in to manage remembered details.'
          : _notice,
      onOpen: _owner == null ? null : () => unawaited(_read()),
      onRetry: _readFailed
          ? () => unawaited(_read())
          : _retryChange != null || _retryClear
          ? () => unawaited(_save(_retryChange, clear: _retryClear))
          : null,
      onSuggestionsChanged: (value) => _preference('suggestionsEnabled', value),
      onDurationChanged: (value) =>
          _preference('preferredDurationMinutes', value),
      onTimeOfDayChanged: _timeOfDayPreference,
      onChangeUsualTime: () => unawaited(_changeUsualTime()),
      onResetUsualTime: _resetUsualTime,
      onPlanningWindowChanged: _planningWindow,
      onRemoveFlowDuration: _removeFlowDuration,
      onRemoveBinding: (phrase) => unawaited(
        _save(
          (_) => {
            'bindings': {phrase: null},
          },
        ),
      ),
      onRestoreSuggestion: (id) => unawaited(
        _save(
          (current) => {
            'hidden': current.hiddenSuggestions
                .where((value) => value != id)
                .toList(),
          },
        ),
      ),
      onClear: () => unawaited(_save(null, clear: true)),
    );
  }
}

/// The same compact Settings presentation is used by live controls and previews.
class AskHawSettingsView extends StatelessWidget {
  const AskHawSettingsView({
    super.key,
    this.expanded = false,
    this.loading = false,
    this.available = true,
    this.busy = false,
    this.suggestionsEnabled = true,
    this.preferredDurationMinutes,
    this.preferredTimeOfDay = 'any',
    this.planningWindowKey,
    this.usualStartTime,
    this.flowDurationMinutes = const {},
    this.flowDurationTitles = const {},
    this.bindings = const {},
    this.hiddenSuggestions = const {},
    this.contentTitles = const {},
    this.notice,
    this.onOpen,
    this.onRetry,
    this.onSuggestionsChanged,
    this.onDurationChanged,
    this.onTimeOfDayChanged,
    this.onPlanningWindowChanged,
    this.onChangeUsualTime,
    this.onResetUsualTime,
    this.onRemoveFlowDuration,
    this.onRemoveBinding,
    this.onRestoreSuggestion,
    this.onClear,
  });

  final bool expanded, loading, available, busy, suggestionsEnabled;
  final int? preferredDurationMinutes;
  final String preferredTimeOfDay;
  final String? planningWindowKey;
  final TimeOfDay? usualStartTime;
  final Map<String, int> flowDurationMinutes;
  final Map<String, String> flowDurationTitles;
  final Map<String, dynamic> bindings;
  final Set<String> hiddenSuggestions;
  final Map<String, String> contentTitles;
  final String? notice;
  final VoidCallback? onOpen, onRetry, onClear;
  final VoidCallback? onChangeUsualTime, onResetUsualTime;
  final ValueChanged<bool>? onSuggestionsChanged;
  final ValueChanged<int?>? onDurationChanged;
  final ValueChanged<String>? onTimeOfDayChanged;
  final ValueChanged<String?>? onPlanningWindowChanged;
  final ValueChanged<String>? onRemoveFlowDuration;
  final ValueChanged<String>? onRemoveBinding, onRestoreSuggestion;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('ask-haw-settings-card'),
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0C0C),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF242424)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ask ḥꜣw',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Review the preferences and phrases you have chosen to remember.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        if (!expanded) ...[
          const SizedBox(height: 12),
          _button(
            'Manage remembered details',
            onOpen,
            key: const ValueKey('ask-haw-memory-open'),
          ),
        ] else if (loading) ...[
          const SizedBox(height: 16),
          Semantics(
            label: 'Loading remembered details',
            child: const LinearProgressIndicator(color: KemeticGold.base),
          ),
        ] else if (available) ...[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            key: const ValueKey('ask-haw-suggestions-toggle'),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: KemeticGold.base,
            title: const Text(
              'Optional suggestions',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Show relevant choices when you ask.',
              style: TextStyle(color: Colors.white60),
            ),
            value: suggestionsEnabled,
            onChanged: busy ? null : onSuggestionsChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('ask-haw-duration-$preferredDurationMinutes-$busy'),
            initialValue: preferredDurationMinutes ?? 0,
            isExpanded: true,
            itemHeight: null,
            decoration: _field('Preferred session length'),
            dropdownColor: const Color(0xFF101010),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Ask each time')),
              if (preferredDurationMinutes != null &&
                  preferredDurationMinutes != 0 &&
                  !const [
                    10,
                    20,
                    30,
                    45,
                    60,
                  ].contains(preferredDurationMinutes))
                DropdownMenuItem(
                  value: preferredDurationMinutes,
                  child: Text('$preferredDurationMinutes minutes'),
                ),
              for (final minutes in const [10, 20, 30, 45, 60])
                DropdownMenuItem(
                  value: minutes,
                  child: Text('$minutes minutes'),
                ),
            ],
            onChanged: busy
                ? null
                : (value) => onDurationChanged?.call(value == 0 ? null : value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('ask-haw-time-$preferredTimeOfDay-$busy'),
            initialValue:
                const [
                  'any',
                  'morning',
                  'afternoon',
                  'evening',
                ].contains(preferredTimeOfDay)
                ? preferredTimeOfDay
                : 'any',
            isExpanded: true,
            itemHeight: null,
            decoration: _field('Preferred time'),
            dropdownColor: const Color(0xFF101010),
            items: const [
              DropdownMenuItem(value: 'any', child: Text('No preference')),
              DropdownMenuItem(value: 'morning', child: Text('Morning')),
              DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
              DropdownMenuItem(value: 'evening', child: Text('Evening')),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) onTimeOfDayChanged?.call(value);
                  },
          ),
          const SizedBox(height: 12),
          if (usualStartTime != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Usual start time',
                          style: TextStyle(color: Colors.white),
                        ),
                        _line(usualStartTime!.format(context)),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('ask-haw-usual-time-change'),
                  onPressed: busy ? null : onChangeUsualTime,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Change'),
                ),
                IconButton(
                  key: const ValueKey('ask-haw-usual-time-reset'),
                  tooltip: 'Reset usual start time',
                  onPressed: busy ? null : onResetUsualTime,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white60,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey('ask-haw-window-${planningWindowKey ?? ''}-$busy'),
            initialValue: planningWindowKey ?? '',
            isExpanded: true,
            itemHeight: null,
            decoration: _field('Planning window'),
            dropdownColor: const Color(0xFF101010),
            items: [
              const DropdownMenuItem(value: '', child: Text('Ask each time')),
              const DropdownMenuItem(
                value: '7:9',
                child: Text('Morning · 7–9 a.m.'),
              ),
              const DropdownMenuItem(
                value: '9:17',
                child: Text('Daytime · 9 a.m.–5 p.m.'),
              ),
              const DropdownMenuItem(
                value: '18:21',
                child: Text('Evening · 6–9 p.m.'),
              ),
              if (planningWindowKey != null &&
                  !const ['7:9', '9:17', '18:21'].contains(planningWindowKey))
                DropdownMenuItem(
                  value: planningWindowKey,
                  child: Text(_windowLabel(planningWindowKey!)),
                ),
            ],
            onChanged: busy
                ? null
                : (value) =>
                      onPlanningWindowChanged?.call(value == '' ? null : value),
          ),
          if (flowDurationMinutes.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Session lengths for Flows',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final entry in flowDurationMinutes.entries)
              _removable(
                '${flowDurationTitles[entry.key] ?? 'Personal Flow'} · ${entry.value} minutes',
                'Remove session preference',
                () => onRemoveFlowDuration?.call(entry.key),
                key: ValueKey('ask-haw-remove-flow-duration-${entry.key}'),
              ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Remembered phrases',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          if (bindings.isEmpty)
            _line('No phrases remembered yet.')
          else
            for (final phrase in bindings.keys)
              _removable(
                phrase,
                'Forget phrase',
                () => onRemoveBinding?.call(phrase),
                key: ValueKey('ask-haw-forget-$phrase'),
                meaning: _bindingMeaning(bindings[phrase]),
              ),
          const SizedBox(height: 16),
          const Text(
            'Hidden suggestions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          if (hiddenSuggestions.isEmpty)
            _line('No suggestions hidden.')
          else
            for (final suggestion in hiddenSuggestions)
              _removable(
                _titleFor(suggestion),
                'Restore suggestion',
                () => onRestoreSuggestion?.call(suggestion),
                key: ValueKey('ask-haw-restore-$suggestion'),
              ),
          const SizedBox(height: 16),
          _button(
            'Clear remembered details',
            busy ? null : onClear,
            key: const ValueKey('ask-haw-memory-clear'),
          ),
          _line(
            'Clearing removes these preferences, phrases, and hidden choices.',
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: _line(notice!)),
        ],
        if (onRetry != null)
          TextButton(
            onPressed: busy ? null : onRetry,
            child: const Text('Try again'),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(color: KemeticGold.base),
          ),
      ],
    ),
  );

  Widget _removable(
    String title,
    String label,
    VoidCallback action, {
    required Key key,
    String? meaning,
  }) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                if (meaning != null) _line(meaning),
              ],
            ),
          ),
        ),
        IconButton(
          key: key,
          tooltip: label,
          onPressed: busy ? null : action,
          icon: const Icon(Icons.close, color: Colors.white60, size: 20),
        ),
      ],
    ),
  );

  String _titleFor(String id) =>
      contentTitles[id] ??
      (id.startsWith('library:') ? 'Library reading' : 'Personal Flow');

  static String _windowLabel(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return 'Saved custom window';
    String hour(String raw) {
      final value = int.tryParse(raw);
      if (value == null || value < 0 || value > 24) return raw;
      if (value == 0 || value == 24) return 'midnight';
      if (value == 12) return 'noon';
      return '${value > 12 ? value - 12 : value} ${value < 12 ? 'a.m.' : 'p.m.'}';
    }

    return 'Custom · ${hour(parts[0])}–${hour(parts[1])}';
  }

  String _bindingMeaning(Object? value) {
    if (value is! Map) return 'A phrase you chose to remember.';
    final content = value['contentId'];
    final query = value['query'];
    final savedTitle = value['title'];
    final target = content is String
        ? contentTitles[content] ??
              (savedTitle is String && savedTitle.trim().isNotEmpty
                  ? savedTitle.trim()
                  : _titleFor(content))
        : query is String && query.trim().isNotEmpty
        ? query.trim()
        : null;
    return switch (value['intent']) {
      'find' || 'discover' =>
        target == null ? 'Find a Flow or reading.' : 'Find $target.',
      'explain' =>
        target == null ? 'Explain a Library topic.' : 'Explain $target.',
      'next' => 'Show what comes next.',
      'fit' => 'Find an activity that fits your time.',
      'plan' => 'Help plan your day.',
      'move' => 'Move the activity you choose.',
      'shorten' => 'Use an approved shorter activity.',
      'skip' => 'Skip the occurrence you choose.',
      'pause' => 'Pause the Flow you choose.',
      'resume' => 'Resume the Flow you choose.',
      _ => target == null ? 'A phrase you chose to remember.' : 'Open $target.',
    };
  }

  static Widget _line(String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      value,
      style: const TextStyle(color: Colors.white60, height: 1.4),
    ),
  );

  static Widget _button(String text, VoidCallback? action, {Key? key}) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          key: key,
          onPressed: action,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF3A3A3A)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(text),
        ),
      );

  static InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.black,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF303030)),
    ),
  );
}
