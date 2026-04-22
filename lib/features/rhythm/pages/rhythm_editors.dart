import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/services/session_resume_service.dart';

import 'package:mobile/features/rhythm/rhythm_reminders.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';

import '../data/rhythm_repo.dart';
import '../theme/rhythm_theme.dart';
import '../viewmodels/rhythm_draft.dart';
import '../widgets/rhythm_states.dart';

const String kRhythmEditorResumeKind = 'rhythm_editor';

class RhythmEditorResumePayload {
  const RhythmEditorResumePayload({
    required this.category,
    required this.isTimed,
    required this.draft,
  });

  final String category;
  final bool isTimed;
  final RhythmDraft draft;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'isTimed': isTimed,
      'draft': {
        'id': draft.id,
        'title': draft.title,
        'description': draft.description,
        'category': draft.category,
        'isTimed': draft.isTimed,
        'showInAlignment': draft.showInAlignment,
        'sendReminders': draft.sendReminders,
        'trackContinuity': draft.trackContinuity,
        'patterns': [
          for (final pattern in draft.patterns)
            {
              'daysOfWeek': pattern.daysOfWeek,
              'allDay': pattern.allDay,
              'startHour': pattern.start?.hour,
              'startMinute': pattern.start?.minute,
              'endHour': pattern.end?.hour,
              'endMinute': pattern.end?.minute,
              'isOptional': pattern.isOptional,
            },
        ],
      },
    };
  }

  static RhythmEditorResumePayload? fromJson(Map<String, dynamic> json) {
    final draftJson = json['draft'];
    if (draftJson is! Map<String, dynamic>) return null;

    final category = json['category'] as String?;
    final isTimed = json['isTimed'] == true;
    final title = draftJson['title'] as String?;
    if (category == null || title == null) return null;

    final patternsRaw = draftJson['patterns'];
    final patterns = <TimePattern>[];
    if (patternsRaw is List) {
      for (final raw in patternsRaw) {
        if (raw is! Map<String, dynamic>) continue;
        patterns.add(
          TimePattern(
            daysOfWeek: ((raw['daysOfWeek'] as List?) ?? const [])
                .map((value) => (value as num).toInt())
                .toList(),
            allDay: raw['allDay'] == true,
            start: _timeOfDayFromJson(raw, 'start'),
            end: _timeOfDayFromJson(raw, 'end'),
            isOptional: raw['isOptional'] == true,
          ),
        );
      }
    }

    return RhythmEditorResumePayload(
      category: category,
      isTimed: isTimed,
      draft: RhythmDraft(
        id: draftJson['id'] as String?,
        title: title,
        description: draftJson['description'] as String?,
        category: (draftJson['category'] as String?) ?? category,
        isTimed: draftJson['isTimed'] == true,
        showInAlignment: draftJson['showInAlignment'] != false,
        sendReminders: draftJson['sendReminders'] == true,
        trackContinuity: draftJson['trackContinuity'] != false,
        patterns: patterns,
      ),
    );
  }

  static TimeOfDay? _timeOfDayFromJson(Map<String, dynamic> json, String key) {
    final hour = (json['${key}Hour'] as num?)?.toInt();
    final minute = (json['${key}Minute'] as num?)?.toInt();
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }
}

class TimedRhythmEditorPage extends StatefulWidget {
  const TimedRhythmEditorPage({
    super.key,
    this.initial,
    this.categoryDisplay = 'Rhythm of Day',
  });

  final RhythmDraft? initial;

  /// User-facing section (maps to metadata in [RhythmRepo.saveDraft]).
  final String categoryDisplay;

  @override
  State<TimedRhythmEditorPage> createState() => _TimedRhythmEditorPageState();
}

class _TimedRhythmEditorPageState extends State<TimedRhythmEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _showAlignment = true;
  bool _sendReminders = false;
  bool _trackContinuity = true;
  late List<TimePattern> _patterns;
  bool _saving = false;
  String? _friendlyError;

  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title.text = initial?.title ?? '';
    _description.text = initial?.description ?? '';
    _showAlignment = initial?.showInAlignment ?? true;
    _sendReminders = initial?.sendReminders ?? false;
    _trackContinuity = initial?.trackContinuity ?? true;
    _patterns = initial?.patterns.isNotEmpty == true
        ? List<TimePattern>.from(initial!.patterns)
        : [
            const TimePattern(
              daysOfWeek: [1, 2, 3, 4, 5],
              start: TimeOfDay(hour: 6, minute: 0),
            ),
          ];
    _title.addListener(_persistResumeState);
    _description.addListener(_persistResumeState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistResumeState();
    });
  }

  @override
  void dispose() {
    _title.removeListener(_persistResumeState);
    _description.removeListener(_persistResumeState);
    unawaited(
      SessionResumeService.clearResumeEntry(kind: kRhythmEditorResumeKind),
    );
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _persistResumeState() {
    final payload = RhythmEditorResumePayload(
      category: widget.categoryDisplay,
      isTimed: true,
      draft: RhythmDraft(
        id: widget.initial?.id,
        title: _title.text,
        description: _description.text.isEmpty ? null : _description.text,
        category: widget.categoryDisplay,
        isTimed: true,
        showInAlignment: _showAlignment,
        sendReminders: _sendReminders,
        trackContinuity: _trackContinuity,
        patterns: List<TimePattern>.from(_patterns),
      ),
    );
    unawaited(
      SessionResumeService.saveResumeEntry(
        baseRoute: '/rhythm/mycycle',
        kind: kRhythmEditorResumeKind,
        payload: payload.toJson(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timed rhythm'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  style: RhythmTheme.heading,
                  decoration: const InputDecoration(labelText: 'Item title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 18),
                Text('When this returns', style: RhythmTheme.heading),
                const SizedBox(height: 8),
                ..._patterns.asMap().entries.map((entry) {
                  final index = entry.key;
                  final pattern = entry.value;
                  return _PatternCard(
                    pattern: pattern,
                    onChanged: (updated) {
                      setState(() {
                        _patterns[index] = updated;
                      });
                      _persistResumeState();
                    },
                    onDelete: _patterns.length == 1
                        ? null
                        : () => setState(() {
                            _patterns.removeAt(index);
                            _persistResumeState();
                          }),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _patterns = [..._patterns, const TimePattern(allDay: true)];
                    _persistResumeState();
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Add time pattern'),
                ),
                const SizedBox(height: 18),
                Text('How the app uses it', style: RhythmTheme.heading),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  title: const Text('Show in Planner'),
                  value: _showAlignment,
                  onChanged: (v) {
                    setState(() => _showAlignment = v);
                    _persistResumeState();
                  },
                ),
                SwitchListTile.adaptive(
                  title: const Text('Send reminders'),
                  value: _sendReminders,
                  onChanged: (v) {
                    setState(() => _sendReminders = v);
                    _persistResumeState();
                  },
                ),
                SwitchListTile.adaptive(
                  title: const Text('Track continuity'),
                  value: _trackContinuity,
                  onChanged: (v) {
                    setState(() => _trackContinuity = v);
                    _persistResumeState();
                  },
                ),
                if (_friendlyError != null) ...[
                  const SizedBox(height: 12),
                  RhythmErrorStateCard(
                    title: 'Could not save yet',
                    message: _friendlyError!,
                    onRetry: _save,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _friendlyError = null;
    });

    final draft = RhythmDraft(
      id: widget.initial?.id,
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      category: widget.categoryDisplay,
      isTimed: true,
      showInAlignment: _showAlignment,
      sendReminders: _sendReminders,
      trackContinuity: _trackContinuity,
      patterns: _patterns,
    );

    final result = await _repo.saveDraft(draft);
    if (!mounted) return;

    if (result.missingTables) {
      setState(() {
        _friendlyError = 'My Cycle isn’t ready yet in this environment.';
        _saving = false;
      });
      return;
    }
    if (result.friendlyError != null) {
      setState(() {
        _friendlyError = RhythmUserMessages.saveFailed;
        _saving = false;
      });
      return;
    }

    final fieldId = result.data;
    try {
      await RhythmReminders.syncAfterSave(
        fieldId: fieldId,
        title: draft.title,
        sendReminders: _sendReminders,
        isTimed: true,
        patterns: _patterns,
      );
    } catch (_) {}

    unawaited(
      RhythmTelemetry.recordCycleFieldSaved(
        client: Supabase.instance.client,
        fieldId: fieldId,
        category: draft.category,
        isTimed: true,
        remindersEnabled: _sendReminders,
        patternCount: _patterns.length,
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    await SessionResumeService.clearResumeEntry(kind: kRhythmEditorResumeKind);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

class UntimedRhythmEditorPage extends StatefulWidget {
  const UntimedRhythmEditorPage({
    super.key,
    this.initial,
    required this.category,
  });

  final RhythmDraft? initial;
  final String category;

  @override
  State<UntimedRhythmEditorPage> createState() =>
      _UntimedRhythmEditorPageState();
}

class _UntimedRhythmEditorPageState extends State<UntimedRhythmEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _showAlignment = true;
  bool _sendReminders = false;
  bool _trackContinuity = true;
  bool _saving = false;
  String? _friendlyError;
  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title.text = initial?.title ?? '';
    _description.text = initial?.description ?? '';
    _showAlignment = initial?.showInAlignment ?? true;
    _sendReminders = initial?.sendReminders ?? false;
    _trackContinuity = initial?.trackContinuity ?? true;
    _title.addListener(_persistResumeState);
    _description.addListener(_persistResumeState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistResumeState();
    });
  }

  @override
  void dispose() {
    _title.removeListener(_persistResumeState);
    _description.removeListener(_persistResumeState);
    unawaited(
      SessionResumeService.clearResumeEntry(kind: kRhythmEditorResumeKind),
    );
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _persistResumeState() {
    final payload = RhythmEditorResumePayload(
      category: widget.category,
      isTimed: false,
      draft: RhythmDraft(
        id: widget.initial?.id,
        title: _title.text,
        description: _description.text.isEmpty ? null : _description.text,
        category: widget.category,
        isTimed: false,
        showInAlignment: _showAlignment,
        sendReminders: _sendReminders,
        trackContinuity: _trackContinuity,
      ),
    );
    unawaited(
      SessionResumeService.saveResumeEntry(
        baseRoute: '/rhythm/mycycle',
        kind: kRhythmEditorResumeKind,
        payload: payload.toJson(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  style: RhythmTheme.heading,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes, tags, or rituals',
                  ),
                ),
                const SizedBox(height: 18),
                Text('How the app uses it', style: RhythmTheme.heading),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  title: const Text('Show in Planner'),
                  value: _showAlignment,
                  onChanged: (v) {
                    setState(() => _showAlignment = v);
                    _persistResumeState();
                  },
                ),
                SwitchListTile.adaptive(
                  title: const Text('Send reminders'),
                  value: _sendReminders,
                  onChanged: (v) {
                    setState(() => _sendReminders = v);
                    _persistResumeState();
                  },
                ),
                SwitchListTile.adaptive(
                  title: const Text('Track continuity'),
                  value: _trackContinuity,
                  onChanged: (v) {
                    setState(() => _trackContinuity = v);
                    _persistResumeState();
                  },
                ),
                if (_friendlyError != null) ...[
                  const SizedBox(height: 12),
                  RhythmErrorStateCard(
                    title: 'Could not save yet',
                    message: _friendlyError!,
                    onRetry: _save,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _friendlyError = null;
    });

    final draft = RhythmDraft(
      id: widget.initial?.id,
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      category: widget.category,
      isTimed: false,
      showInAlignment: _showAlignment,
      sendReminders: _sendReminders,
      trackContinuity: _trackContinuity,
    );

    final result = await _repo.saveDraft(draft);
    if (!mounted) return;

    if (result.missingTables) {
      setState(() {
        _friendlyError = 'My Cycle isn’t ready yet in this environment.';
        _saving = false;
      });
      return;
    }
    if (result.friendlyError != null) {
      setState(() {
        _friendlyError = RhythmUserMessages.saveFailed;
        _saving = false;
      });
      return;
    }

    final fieldId = result.data;
    try {
      await RhythmReminders.syncAfterSave(
        fieldId: fieldId,
        title: draft.title,
        sendReminders: _sendReminders,
        isTimed: false,
        patterns: const [],
      );
    } catch (_) {}

    unawaited(
      RhythmTelemetry.recordCycleFieldSaved(
        client: Supabase.instance.client,
        fieldId: fieldId,
        category: draft.category,
        isTimed: false,
        remindersEnabled: _sendReminders,
        patternCount: 0,
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    await SessionResumeService.clearResumeEntry(kind: kRhythmEditorResumeKind);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

class CustomRhythmEditorPage extends StatelessWidget {
  const CustomRhythmEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UntimedRhythmEditorPage(category: 'Custom');
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.pattern,
    required this.onChanged,
    this.onDelete,
  });

  final TimePattern pattern;
  final ValueChanged<TimePattern> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final days = pattern.daysOfWeek;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: RhythmTheme.cardSurface(),
      padding: RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Pattern',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: onDelete,
                ),
            ],
          ),
          Wrap(spacing: 8, children: _buildDayChips(days)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: pattern.allDay
                      ? 'All day'
                      : (pattern.start != null
                            ? _fmt(pattern.start!)
                            : 'Start'),
                  onPressed: () async {
                    if (pattern.allDay) {
                      onChanged(pattern.copyWith(allDay: false));
                      return;
                    }
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: pattern.start ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      onChanged(pattern.copyWith(start: picked, allDay: false));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeButton(
                  label: pattern.allDay
                      ? 'No end'
                      : (pattern.end != null
                            ? _fmt(pattern.end!)
                            : 'End (optional)'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: pattern.end ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      onChanged(pattern.copyWith(end: picked, allDay: false));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: pattern.allDay,
                onChanged: (v) =>
                    onChanged(pattern.copyWith(allDay: v ?? false)),
              ),
              const Text('No fixed time'),
              const Spacer(),
              Checkbox(
                value: pattern.isOptional,
                onChanged: (v) =>
                    onChanged(pattern.copyWith(isOptional: v ?? false)),
              ),
              const Text('Optional'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayChips(List<int> days) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      ChoiceChip(
        label: const Text('Weekdays'),
        selected: _matches(days, const [1, 2, 3, 4, 5]),
        onSelected: (_) =>
            onChanged(pattern.copyWith(daysOfWeek: const [1, 2, 3, 4, 5])),
      ),
      ChoiceChip(
        label: const Text('Weekends'),
        selected: _matches(days, const [6, 7]),
        onSelected: (_) =>
            onChanged(pattern.copyWith(daysOfWeek: const [6, 7])),
      ),
      ...List.generate(7, (i) {
        final dayIndex = i + 1;
        final selected = days.contains(dayIndex);
        return FilterChip(
          label: Text(labels[i]),
          selected: selected,
          onSelected: (v) {
            final updated = [...days];
            if (v) {
              updated.add(dayIndex);
            } else {
              updated.remove(dayIndex);
            }
            onChanged(pattern.copyWith(daysOfWeek: updated));
          },
        );
      }),
    ];
  }

  bool _matches(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final aa = [...a]..sort();
    final bb = [...b]..sort();
    for (int i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
  }

  String _fmt(TimeOfDay t) {
    final isPm = t.hour >= 12;
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    return '$h12:$mm ${isPm ? 'PM' : 'AM'}';
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
