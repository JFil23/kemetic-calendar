import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile/core/completion_status.dart';

import 'calendar_completion.dart';

const int kFlowEnrollmentInputMaxCharacters = 280;

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
