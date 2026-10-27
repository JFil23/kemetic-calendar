import 'package:flutter/material.dart';
import '../../core/theme/app_fonts.dart';
import 'ask_haw_flow_contract.dart';

/// Validates authored guidance through the same contract used by Ask ḥꜣw.
String? validateAskHawFlowAssistance(Object? raw) {
  final contract = AskHawFlowContract.tryFromJson(raw);
  if (contract == null) {
    return 'Use unique step keys, positive lengths, and prerequisites without a cycle.';
  }
  for (final step in contract.steps) {
    if (step.title.trim().isEmpty || step.guidance.trim().isEmpty) {
      return 'Give each step a title and guidance.';
    }
    for (final alternative in step.alternatives) {
      if (alternative.label.trim().isEmpty ||
          alternative.guidance.trim().isEmpty) {
        return 'Give each shorter option a name and guidance.';
      }
      if (step.minutes == null || alternative.minutes >= step.minutes!) {
        return 'A shorter option needs a length below its step’s normal length.';
      }
    }
  }
  return null;
}

/// An optional section of the canonical Flow editor, never a separate editor.
/// Invalid in-progress fields can use the existing Flow draft store; only a
/// validated contract is emitted as the definition that may be saved.
class AskHawFlowContractEditor extends StatefulWidget {
  const AskHawFlowContractEditor({
    super.key,
    this.value,
    this.draft,
    required this.onChanged,
    this.onDraftChanged,
    this.accent = const Color(0xFFC9AB68),
    this.initiallyExpanded = false,
  });
  final Map<String, dynamic>? value, draft;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final ValueChanged<Map<String, dynamic>?>? onDraftChanged;
  final Color accent;
  final bool initiallyExpanded;
  @override
  State<AskHawFlowContractEditor> createState() =>
      AskHawFlowContractEditorState();
}

class AskHawFlowContractEditorState extends State<AskHawFlowContractEditor> {
  final _form = GlobalKey<FormState>();
  Map<String, dynamic>? _original;
  final _steps = <_StepFields>[];
  final _adaptations = <String>{};
  String _guidance = '';
  String? _error, _notice;
  bool _expanded = false, _changed = false, _replacement = false;
  int _nextIdentity = 0;

  bool get _unsupported =>
      _original != null &&
      AskHawFlowContract.tryFromJson(_original) == null &&
      !_replacement;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool ignoreDraft = false}) {
    _original = widget.value;
    final draft = ignoreDraft ? null : widget.draft;
    _expanded = widget.initiallyExpanded || draft != null;
    _replacement = draft?['replacement'] == true;
    _changed = draft != null;
    final rawDraft = draft?['contract'];
    final raw = rawDraft is Map
        ? Map<String, dynamic>.from(rawDraft)
        : _unsupported
        ? null
        : widget.value;
    _guidance = raw?['guidance'] is String ? raw!['guidance'] as String : '';
    _adaptations
      ..clear()
      ..addAll(
        (raw?['adaptations'] is List ? raw!['adaptations'] as List : const [])
            .whereType<String>(),
      );
    _steps.clear();
    final rows = raw?['steps'];
    if (rows is List) {
      for (final row in rows.whereType<Map>()) {
        _steps.add(
          _StepFields(Map<String, dynamic>.from(row), _nextIdentity++),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant AskHawFlowContractEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent changes value on acknowledgement or changes Flow identity.
    // A local draft is retained while its parent merely persists keystrokes.
    if (oldWidget.value != widget.value && widget.value != _original) {
      _load();
    }
  }

  Map<String, dynamic> _raw() => {
    if (!_replacement && _original != null) ..._original!,
    'version': 1,
    'guidance': _guidance,
    'adaptations': _adaptations.toList()..sort(),
    'steps': _steps.map((step) => step.toJson()).toList(),
  };

  void _touch() {
    setState(() {
      _changed = true;
      _error = _notice = null;
    });
    widget.onDraftChanged?.call({
      'replacement': _replacement,
      'contract': _raw(),
    });
  }

  /// Called by the enclosing Flow Save action as well as this section's Apply.
  bool validateAndCommit() {
    if (!_changed) return true;
    final raw = _raw();
    final error = validateAskHawFlowAssistance(raw);
    final fieldsValid = _form.currentState?.validate() ?? true;
    if (error != null || !fieldsValid) {
      setState(() {
        _expanded = true;
        _error = error ?? 'Review the highlighted fields.';
      });
      return false;
    }
    // Preserve optional extension fields, including fields of a supported step.
    _original = raw;
    setState(() {
      _changed = false;
      _error = null;
      _notice = 'Guidance is ready to save with this Flow.';
    });
    widget.onChanged(raw);
    widget.onDraftChanged?.call(null);
    return true;
  }

  void _replace() {
    _replacement = true;
    _guidance = '';
    _steps.clear();
    _adaptations.clear();
    _touch();
  }

  void _remove() {
    const disabled = <String, dynamic>{
      'version': 1,
      'guidance': '',
      'steps': [],
      'adaptations': [],
    };
    setState(() {
      _original = disabled;
      _steps.clear();
      _guidance = '';
      _adaptations.clear();
      _changed = _replacement = _expanded = false;
      _error = _notice = null;
    });
    // A nonnull, empty contract explicitly disables assistance through existing
    // optional upserts without confusing removal with an omitted field.
    widget.onChanged(disabled);
    widget.onDraftChanged?.call(null);
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Color(0xFFB6A995), fontSize: 13),
    hintStyle: const TextStyle(color: Color(0xFF776B5B)),
    filled: true,
    fillColor: const Color(0xFF050403),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: widget.accent.withValues(alpha: .24)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: widget.accent.withValues(alpha: .18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: widget.accent.withValues(alpha: .6)),
    ),
  );

  Widget _text(
    String key,
    String label,
    String value,
    ValueChanged<String> change, {
    String? hint,
    bool required = false,
    bool minutes = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      key: ValueKey(key),
      initialValue: value,
      style: const TextStyle(
        fontFamily: 'GentiumPlus',
        fontSize: 17,
        color: Color(0xFFE8E1D5),
        height: 1.3,
      ),
      maxLines: lines,
      keyboardType: minutes
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: _decoration(label, hint: hint),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        if (minutes &&
            value?.trim().isNotEmpty == true &&
            (int.tryParse(value!) == null || int.parse(value) <= 0)) {
          return 'Use a positive number of minutes';
        }
        return null;
      },
      onChanged: (value) {
        change(value);
        _touch();
      },
    ),
  );

  Widget _button(String label, VoidCallback action, {Key? key}) => TextButton(
    key: key,
    onPressed: action,
    style: TextButton.styleFrom(
      foregroundColor: widget.accent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
    ),
    child: Text(
      label,
      style: const TextStyle(fontFamily: 'GentiumPlus', fontSize: 17),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('ask-haw-flow-contract-editor'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        key: const ValueKey('ask-haw-assistance-expand'),
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF050403),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.accent.withValues(alpha: .18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ask ḥꜣw guidance',
                      style: TextStyle(
                        fontFamily: 'GentiumPlus',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8D9C3),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _original == null
                          ? 'Optional · steps and approved adjustments'
                          : _unsupported
                          ? 'Saved guidance is kept unchanged'
                          : '${_steps.length} authored steps · Review',
                      style: const TextStyle(
                        color: Color(0xFF968976),
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: widget.accent,
              ),
            ],
          ),
        ),
      ),
      if (_expanded) ...[
        const SizedBox(height: 12),
        if (_unsupported) ...[
          _copy(
            'This guidance uses an unsupported format. Saving other Flow changes keeps it. Replace it only if you want to write new guidance.',
          ),
          _button(
            'Replace assistance settings',
            _replace,
            key: const ValueKey('ask-haw-assistance-replace'),
          ),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _copy(
                  'Describe what is allowed. Ask ḥꜣw proposes only these adjustments; it never marks a step complete by itself.',
                ),
                _text(
                  'ask-haw-contract-guidance',
                  'Guidance for this Flow',
                  _guidance,
                  (value) => _guidance = value,
                  lines: 3,
                ),
                const SizedBox(height: 20),
                _heading('Permitted adjustments'),
                for (final adaptation in AskHawAdaptation.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    key: ValueKey('ask-haw-permit-${adaptation.name}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: widget.accent,
                    title: Text(
                      switch (adaptation) {
                        AskHawAdaptation.shorten =>
                          'Use an authored shorter option',
                        AskHawAdaptation.reschedule =>
                          'Reschedule an occurrence',
                        AskHawAdaptation.skip => 'Skip an occurrence',
                        AskHawAdaptation.pause => 'Pause this Flow',
                        AskHawAdaptation.resume => 'Resume this Flow',
                      },
                      style: const TextStyle(
                        color: Color(0xFFE8E1D5),
                        fontSize: 14,
                      ),
                    ),
                    value: _adaptations.contains(adaptation.name),
                    onChanged: (value) {
                      if (value == true) {
                        _adaptations.add(adaptation.name);
                      } else {
                        _adaptations.remove(adaptation.name);
                      }
                      _touch();
                    },
                  ),
                for (var index = 0; index < _steps.length; index++)
                  _step(_steps[index], index),
                _button('Add step', () {
                  _steps.add(
                    _StepFields({
                      'id': 'step-${_nextIdentity + 1}',
                    }, _nextIdentity++),
                  );
                  _touch();
                }, key: const ValueKey('ask-haw-add-step')),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                if (_notice != null) _copy(_notice!),
                _button(
                  'Use this guidance',
                  validateAndCommit,
                  key: const ValueKey('ask-haw-assistance-apply'),
                ),
                if (_changed)
                  _button(
                    'Discard guidance changes',
                    () {
                      setState(() => _load(ignoreDraft: true));
                      widget.onDraftChanged?.call(null);
                    },
                    key: const ValueKey('ask-haw-assistance-discard'),
                  ),
                if (_original != null)
                  _button(
                    'Remove assistance settings',
                    _remove,
                    key: const ValueKey('ask-haw-assistance-remove'),
                  ),
              ],
            ),
          ),
      ],
    ],
  );

  Widget _step(_StepFields step, int index) => Container(
    key: ValueKey('ask-haw-step-${step.identity}'),
    width: double.infinity,
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0805),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: widget.accent.withValues(alpha: .18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Step ${index + 1}'),
        _text(
          'ask-haw-step-${step.identity}-id',
          'Step key',
          step.id,
          (value) => step.id = value,
          hint: 'A stable name, such as prepare',
          required: true,
        ),
        _text(
          'ask-haw-step-${step.identity}-title',
          'Step title',
          step.title,
          (value) => step.title = value,
          required: true,
        ),
        _text(
          'ask-haw-step-${step.identity}-guidance',
          'What to do',
          step.guidance,
          (value) => step.guidance = value,
          required: true,
          lines: 3,
        ),
        _text(
          'ask-haw-step-${step.identity}-minutes',
          'Normal length in minutes',
          step.minutes,
          (value) => step.minutes = value,
          minutes: true,
        ),
        _text(
          'ask-haw-step-${step.identity}-prerequisites',
          'Prerequisite step keys',
          step.prerequisites,
          (value) => step.prerequisites = value,
          hint: 'Separate keys with commas; leave empty for none',
        ),
        _text(
          'ask-haw-step-${step.identity}-completion',
          'What completion means',
          step.completion,
          (value) => step.completion = value,
          lines: 2,
        ),
        _text(
          'ask-haw-step-${step.identity}-recovery',
          'When returning after a gap',
          step.recovery,
          (value) => step.recovery = value,
          lines: 2,
        ),
        for (final alternative in step.alternatives)
          _alternative(step, alternative),
        _button(
          'Add shorter option',
          () {
            step.alternatives.add(
              _AlternativeFields({
                'id': 'short-${_nextIdentity + 1}',
              }, _nextIdentity++),
            );
            _touch();
          },
          key: ValueKey('ask-haw-step-${step.identity}-add-alternative'),
        ),
        _button('Remove step', () {
          _steps.remove(step);
          _touch();
        }, key: ValueKey('ask-haw-step-${step.identity}-remove')),
      ],
    ),
  );

  Widget _alternative(
    _StepFields step,
    _AlternativeFields alternative,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Approved shorter option'),
        _text(
          'ask-haw-alternative-${alternative.identity}-id',
          'Option key',
          alternative.id,
          (value) => alternative.id = value,
          required: true,
        ),
        _text(
          'ask-haw-alternative-${alternative.identity}-label',
          'Name',
          alternative.label,
          (value) => alternative.label = value,
          required: true,
        ),
        _text(
          'ask-haw-alternative-${alternative.identity}-minutes',
          'Length in minutes',
          alternative.minutes,
          (value) => alternative.minutes = value,
          required: true,
          minutes: true,
        ),
        _text(
          'ask-haw-alternative-${alternative.identity}-guidance',
          'Guidance',
          alternative.guidance,
          (value) => alternative.guidance = value,
          required: true,
          lines: 3,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          key: ValueKey('ask-haw-alternative-${alternative.identity}-counts'),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: widget.accent,
          title: const Text(
            'Counts as this step when completed',
            style: TextStyle(color: Color(0xFFE8E1D5), fontSize: 14),
          ),
          value: alternative.counts,
          onChanged: (value) {
            alternative.counts = value == true;
            _touch();
          },
        ),
        _button(
          'Remove shorter option',
          () {
            step.alternatives.remove(alternative);
            _touch();
          },
          key: ValueKey('ask-haw-alternative-${alternative.identity}-remove'),
        ),
      ],
    ),
  );

  static Widget _heading(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFFD4C4A6),
      letterSpacing: 1,
    ),
  );
  static Widget _copy(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFB6A995),
        fontFamily: 'GentiumPlus',
        fontSize: 16,
        height: 1.4,
      ),
    ),
  );
}

String? askHawAuthoredStepId(Map<String, dynamic>? behaviorPayload) {
  final raw = behaviorPayload?['ask_haw'];
  if (raw is! Map || raw['contract_version'] != 1) return null;
  final id = raw['step_id'];
  return id is String && id.trim().isNotEmpty ? id : null;
}

Map<String, dynamic>? withAskHawAuthoredStep(
  Map<String, dynamic>? behaviorPayload,
  String? id,
) {
  final next = <String, dynamic>{...?behaviorPayload};
  if (id == null || id.isEmpty) {
    next.remove('ask_haw');
  } else {
    next['ask_haw'] = {'step_id': id, 'contract_version': 1};
  }
  return next.isEmpty ? null : next;
}

/// A link inside the existing occurrence editor; a title match grants no link.
class AskHawStepSelector extends StatelessWidget {
  const AskHawStepSelector({
    super.key,
    required this.contract,
    required this.stepId,
    required this.onChanged,
    this.decoration,
  });
  final AskHawFlowContract contract;
  final String? stepId;
  final ValueChanged<String?> onChanged;
  final InputDecoration? decoration;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey('ask-haw-step-link-${stepId ?? ''}'),
    initialValue: stepId ?? '',
    isExpanded: true,
    itemHeight: null,
    dropdownColor: const Color(0xFF0A0805),
    style: const TextStyle(
      color: Color(0xFFE8E1D5),
      fontFamily: 'GentiumPlus',
      fontSize: 16,
    ),
    decoration:
        decoration ??
        const InputDecoration(labelText: 'Authored step (optional)'),
    items: [
      const DropdownMenuItem(value: '', child: Text('No authored step')),
      if (stepId != null && contract.step(stepId!) == null)
        DropdownMenuItem(
          value: stepId,
          child: const Text('Saved step unavailable in this guidance'),
        ),
      for (final step in contract.steps)
        DropdownMenuItem(
          value: step.id,
          child: Text('${step.title} · ${step.id}'),
        ),
    ],
    onChanged: (value) => onChanged(value == '' ? null : value),
  );
}

class _StepFields {
  _StepFields(this.original, this.identity) {
    id = _string(original['id']);
    title = _string(original['title']);
    guidance = _string(original['guidance']);
    minutes = _string(original['minutes']);
    final dependencies = original['prerequisites'];
    prerequisites = dependencies is List
        ? dependencies.whereType<String>().join(', ')
        : '';
    completion = _string(original['completionMeaning']);
    recovery = _string(original['recoveryGuidance']);
    final options = original['alternatives'];
    if (options is List) {
      var index = 0;
      for (final option in options.whereType<Map>()) {
        alternatives.add(
          _AlternativeFields(
            Map<String, dynamic>.from(option),
            // Separate identity space keeps input states stable while editing.
            -1000000 - identity * 1000 - index++,
          ),
        );
      }
    }
  }
  final Map<String, dynamic> original;
  final int identity;
  late String id, title, guidance, minutes, prerequisites, completion, recovery;
  final alternatives = <_AlternativeFields>[];
  Map<String, dynamic> toJson() => {
    ...original,
    'id': id.trim(),
    'title': title.trim(),
    'guidance': guidance.trim(),
    'minutes': minutes.trim().isEmpty ? null : int.tryParse(minutes) ?? minutes,
    'prerequisites': prerequisites
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'completionMeaning': completion.trim(),
    'recoveryGuidance': recovery.trim(),
    'alternatives': alternatives.map((value) => value.toJson()).toList(),
  };
}

class _AlternativeFields {
  _AlternativeFields(this.original, this.identity) {
    id = _string(original['id']);
    label = _string(original['label']);
    minutes = _string(original['minutes']);
    guidance = _string(original['guidance']);
    counts = original['countsAsCompletion'] == true;
  }
  final Map<String, dynamic> original;
  final int identity;
  late String id, label, minutes, guidance;
  late bool counts;
  Map<String, dynamic> toJson() => {
    ...original,
    'id': id.trim(),
    'label': label.trim(),
    'minutes': int.tryParse(minutes) ?? minutes,
    'guidance': guidance.trim(),
    'countsAsCompletion': counts,
  };
}

String _string(Object? value) => value?.toString() ?? '';
