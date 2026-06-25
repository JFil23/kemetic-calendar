import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile/core/completion_status.dart';

import 'calendar_completion.dart';
import 'maat_flow_response_models.dart';

const int kFlowEnrollmentInputMaxCharacters = 280;
const Key kMaatFlowResponseSectionKey = ValueKey<String>(
  'maat-flow-response-section',
);
const Key kMaatFlowResponseJournalPreviewKey = ValueKey<String>(
  'maat-flow-response-journal-preview',
);

Key maatFlowResponseFieldKey(String specId) {
  return ValueKey<String>('maat-flow-response-field:${specId.trim()}');
}

class FlowEnrollmentInputField extends StatelessWidget {
  const FlowEnrollmentInputField({
    super.key,
    required this.controller,
    this.label = 'Response',
    this.hintText,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.maxCharacters = kFlowEnrollmentInputMaxCharacters,
  }) : assert(maxCharacters > 0),
       assert(maxCharacters <= kFlowEnrollmentInputMaxCharacters);

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final int maxCharacters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      maxLength: maxCharacters,
      maxLines: 1,
      minLines: 1,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(maxCharacters),
      ],
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        counterText: '',
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.62),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.34),
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFD486)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
    );
  }
}

class FlowCarryBanner extends StatelessWidget {
  const FlowCarryBanner({
    super.key,
    required this.value,
    this.label = 'Carrying',
  });

  final String? value;
  final String label;

  static bool shouldShow(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    return trimmed.toLowerCase() != 'skipped';
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = value?.trim();
    if (!shouldShow(trimmed)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trimmed!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class MaatFlowResponseSection extends StatefulWidget {
  const MaatFlowResponseSection({
    super.key,
    required this.specs,
    this.values = const <String, MaatFlowResponseValue>{},
    this.journalPreviews = const <MaatFlowResponseJournalPreview>[],
    this.isJournalPreviewIncluded,
    this.onJournalPreviewInclusionChanged,
    this.onChanged,
  });

  final List<MaatFlowResponseSpec> specs;
  final Map<String, MaatFlowResponseValue> values;
  final List<MaatFlowResponseJournalPreview> journalPreviews;
  final bool Function(MaatFlowResponseJournalPreview preview)?
  isJournalPreviewIncluded;
  final void Function(MaatFlowResponseJournalPreview preview, bool included)?
  onJournalPreviewInclusionChanged;
  final ValueChanged<MaatFlowResponseValue>? onChanged;

  @override
  State<MaatFlowResponseSection> createState() =>
      _MaatFlowResponseSectionState();
}

class _MaatFlowResponseSectionState extends State<MaatFlowResponseSection> {
  late Map<String, MaatFlowResponseValue> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, MaatFlowResponseValue>.from(widget.values);
  }

  @override
  void didUpdateWidget(covariant MaatFlowResponseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      _values = Map<String, MaatFlowResponseValue>.from(widget.values);
    }
  }

  void _setValue(MaatFlowResponseValue value) {
    setState(() {
      _values[value.specId] = value;
    });
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.specs.isEmpty) return const SizedBox.shrink();

    return Container(
      key: kMaatFlowResponseSectionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final spec in widget.specs) ...[
            _MaatFlowResponseField(
              spec: spec,
              value: _values[spec.id],
              onChanged: _setValue,
            ),
            if (spec != widget.specs.last) const SizedBox(height: 10),
          ],
          if (widget.journalPreviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MaatFlowResponseJournalPreviewList(
              previews: widget.journalPreviews,
              isPreviewIncluded: widget.isJournalPreviewIncluded,
              onPreviewInclusionChanged:
                  widget.onJournalPreviewInclusionChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _MaatFlowResponseJournalPreviewList extends StatelessWidget {
  const _MaatFlowResponseJournalPreviewList({
    required this.previews,
    this.isPreviewIncluded,
    this.onPreviewInclusionChanged,
  });

  final List<MaatFlowResponseJournalPreview> previews;
  final bool Function(MaatFlowResponseJournalPreview preview)?
  isPreviewIncluded;
  final void Function(MaatFlowResponseJournalPreview preview, bool included)?
  onPreviewInclusionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: kMaatFlowResponseJournalPreviewKey,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Journal preview',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          for (final preview in previews) ...[
            Text(
              preview.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
            if (preview.requiresUserChoice &&
                onPreviewInclusionChanged != null) ...[
              const SizedBox(height: 8),
              _MaatFlowResponseJournalOfferToggle(
                included: isPreviewIncluded?.call(preview) ?? false,
                onChanged: (included) =>
                    onPreviewInclusionChanged?.call(preview, included),
              ),
            ],
            if (preview != previews.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _MaatFlowResponseJournalOfferToggle extends StatelessWidget {
  const _MaatFlowResponseJournalOfferToggle({
    required this.included,
    required this.onChanged,
  });

  final bool included;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!included),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: included,
            onChanged: (value) => onChanged(value == true),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Text(
            'Add to journal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaatFlowResponseField extends StatefulWidget {
  const _MaatFlowResponseField({
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  final MaatFlowResponseSpec spec;
  final MaatFlowResponseValue? value;
  final ValueChanged<MaatFlowResponseValue> onChanged;

  @override
  State<_MaatFlowResponseField> createState() => _MaatFlowResponseFieldState();
}

class _MaatFlowResponseFieldState extends State<_MaatFlowResponseField> {
  TextEditingController? _textController;

  bool get _usesTextController {
    switch (widget.spec.kind) {
      case MaatFlowResponseKind.text:
      case MaatFlowResponseKind.multiline:
      case MaatFlowResponseKind.statusNote:
        return true;
      case MaatFlowResponseKind.choice:
      case MaatFlowResponseKind.chips:
      case MaatFlowResponseKind.checkbox:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_usesTextController) {
      _textController = TextEditingController(text: widget.value?.text ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant _MaatFlowResponseField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_usesTextController) {
      _textController?.dispose();
      _textController = null;
      return;
    }
    final controller = _textController ??= TextEditingController();
    final nextText = widget.value?.text ?? '';
    if (controller.text != nextText) {
      controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.spec.prompt?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.spec.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (prompt != null && prompt.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            prompt,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 6),
        _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    final spec = widget.spec;
    final value = widget.value;
    switch (spec.kind) {
      case MaatFlowResponseKind.text:
      case MaatFlowResponseKind.multiline:
      case MaatFlowResponseKind.statusNote:
        return TextFormField(
          key: maatFlowResponseFieldKey(spec.id),
          controller: _textController,
          minLines: spec.kind == MaatFlowResponseKind.text ? 1 : 2,
          maxLines: spec.kind == MaatFlowResponseKind.text ? 1 : 5,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: spec.placeholder,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFD486)),
            ),
          ),
          onChanged: (text) {
            final multiline = spec.kind != MaatFlowResponseKind.text;
            final next = spec.kind == MaatFlowResponseKind.statusNote
                ? MaatFlowResponseValue.statusNote(specId: spec.id, text: text)
                : MaatFlowResponseValue.text(
                    specId: spec.id,
                    text: text,
                    multiline: multiline,
                  );
            widget.onChanged(next);
          },
        );
      case MaatFlowResponseKind.choice:
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in spec.options)
              ChoiceChip(
                key: maatFlowResponseFieldKey('${spec.id}:${option.id}'),
                label: Text(option.label),
                selected: value?.optionIds.contains(option.id) == true,
                onSelected: (selected) {
                  widget.onChanged(
                    MaatFlowResponseValue.choice(
                      specId: spec.id,
                      optionId: selected ? option.id : '',
                    ),
                  );
                },
              ),
          ],
        );
      case MaatFlowResponseKind.chips:
        final selected = value?.optionIds.toSet() ?? const <String>{};
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final option in spec.options)
              FilterChip(
                key: maatFlowResponseFieldKey('${spec.id}:${option.id}'),
                label: Text(option.label),
                selected: selected.contains(option.id),
                onSelected: (checked) {
                  final next = <String>{...selected};
                  if (checked) {
                    next.add(option.id);
                  } else {
                    next.remove(option.id);
                  }
                  widget.onChanged(
                    MaatFlowResponseValue.chips(
                      specId: spec.id,
                      optionIds: next.toList(growable: false),
                    ),
                  );
                },
              ),
          ],
        );
      case MaatFlowResponseKind.checkbox:
        return CheckboxListTile(
          key: maatFlowResponseFieldKey(spec.id),
          value: value?.checked == true,
          onChanged: (checked) {
            widget.onChanged(
              MaatFlowResponseValue.checkbox(
                specId: spec.id,
                checked: checked == true,
              ),
            );
          },
          title: Text(
            spec.placeholder?.trim().isNotEmpty == true
                ? spec.placeholder!.trim()
                : spec.label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
    }
  }
}

class FlowTapCompletionResult {
  const FlowTapCompletionResult._({required this.saved, required this.changed});

  const FlowTapCompletionResult.saved() : this._(saved: true, changed: true);

  const FlowTapCompletionResult.unchanged()
    : this._(saved: true, changed: false);

  const FlowTapCompletionResult.failed() : this._(saved: false, changed: false);

  final bool saved;
  final bool changed;
}

typedef FlowTapCompletionSave =
    Future<FlowTapCompletionResult> Function(CompletionStatus status);

class FlowTapCompletionPanel extends StatefulWidget {
  const FlowTapCompletionPanel({
    super.key,
    required this.currentStatus,
    required this.onSave,
    this.canSave,
    this.onCanonicalCompletionPulse,
    this.loading = false,
    this.showPartial = true,
    this.failureMessage = 'Could not record completion.',
    this.pickerStyle,
  });

  final CompletionStatus currentStatus;
  final FlowTapCompletionSave onSave;
  final FutureOr<bool> Function(CompletionStatus status)? canSave;
  final ValueChanged<CompletionStatus>? onCanonicalCompletionPulse;
  final bool loading;
  final bool showPartial;
  final String failureMessage;
  final CalendarCompletionPickerStyle? pickerStyle;

  @override
  State<FlowTapCompletionPanel> createState() => _FlowTapCompletionPanelState();
}

class _FlowTapCompletionPanelState extends State<FlowTapCompletionPanel> {
  late CompletionStatus _status = widget.currentStatus;
  late CompletionStatus _committedStatus = widget.currentStatus;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant FlowTapCompletionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus) {
      _status = widget.currentStatus;
      _committedStatus = widget.currentStatus;
    }
  }

  Future<void> _handleStatus(CompletionStatus next) async {
    if (_saving || widget.loading) return;
    if (next == CompletionStatus.none || next == _committedStatus) return;

    final allowed = await widget.canSave?.call(next) ?? true;
    if (!allowed) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final result = await widget.onSave(next);
      if (!mounted) return;
      if (!result.saved) {
        setState(() => _saving = false);
        if (widget.failureMessage.trim().isNotEmpty) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(widget.failureMessage)));
        }
        return;
      }

      setState(() {
        _status = next;
        _committedStatus = next;
        _saving = false;
      });

      if (result.changed && calendarCompletionStatusTriggersFeedback(next)) {
        widget.onCanonicalCompletionPulse?.call(next);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (widget.failureMessage.trim().isNotEmpty) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(widget.failureMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CalendarCompletionPicker(
      current: _status,
      saving: _saving,
      loading: widget.loading,
      showPartial: widget.showPartial,
      style: widget.pickerStyle,
      onChanged: (status) {
        unawaited(_handleStatus(status));
      },
    );
  }
}

class FlowTrackedItem {
  const FlowTrackedItem({
    required this.id,
    required this.label,
    this.detail,
    this.completed = false,
  });

  final String id;
  final String label;
  final String? detail;
  final bool completed;
}

class FlowTrackedItemList extends StatelessWidget {
  const FlowTrackedItemList({
    super.key,
    required this.items,
    this.onChanged,
    this.emptyLabel = 'Nothing tracked yet.',
  });

  final List<FlowTrackedItem> items;
  final ValueChanged<FlowTrackedItem>? onChanged;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.54),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _FlowTrackedItemRow(item: item, onChanged: onChanged),
          ),
      ],
    );
  }
}

class _FlowTrackedItemRow extends StatelessWidget {
  const _FlowTrackedItemRow({required this.item, required this.onChanged});

  final FlowTrackedItem item;
  final ValueChanged<FlowTrackedItem>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Checkbox(
              value: item.completed,
              onChanged: onChanged == null ? null : (_) => onChanged!(item),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  if (item.detail != null && item.detail!.trim().isNotEmpty)
                    Text(
                      item.detail!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
