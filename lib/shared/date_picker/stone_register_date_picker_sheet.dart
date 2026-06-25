import 'package:flutter/material.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';
import 'package:mobile/shared/date_picker/stone_register_date_wheel.dart';

enum StoneDatePickerCalendarMode { kemetic, gregorian }

enum StoneDatePickerVariant { fullSheet, compactSheet, inlinePanel }

abstract class StoneDatePickerAdapter<T> {
  const StoneDatePickerAdapter();

  List<StoneWheelColumn> buildColumns(
    T value,
    StoneDatePickerCalendarMode mode,
  );

  T valueFromSelection(
    StoneWheelSelection selection,
    StoneDatePickerCalendarMode mode,
  );

  StoneWheelSelection selectionFromValue(
    T value,
    StoneDatePickerCalendarMode mode,
  );

  T clampOrNormalize(T value, StoneDatePickerCalendarMode mode);

  String formatValue(T value, StoneDatePickerCalendarMode mode);
}

class StoneRegisterDatePickerSheet<T> extends StatefulWidget {
  const StoneRegisterDatePickerSheet({
    super.key,
    required this.initialValue,
    required this.adapter,
    required this.initialMode,
    required this.allowModeSwitch,
    required this.variant,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final T initialValue;
  final StoneDatePickerAdapter<T> adapter;
  final StoneDatePickerCalendarMode initialMode;
  final bool allowModeSwitch;
  final StoneDatePickerVariant variant;
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<StoneRegisterDatePickerSheet<T>> createState() =>
      _StoneRegisterDatePickerSheetState<T>();
}

class _StoneRegisterDatePickerSheetState<T>
    extends State<StoneRegisterDatePickerSheet<T>> {
  final Map<String, ScrollController> _controllers = {};

  late T _value;
  late StoneDatePickerCalendarMode _mode;
  late List<StoneWheelColumn> _columns;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _value = widget.adapter.clampOrNormalize(widget.initialValue, _mode);
    _columns = widget.adapter.buildColumns(_value, _mode);
    _ensureControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.variant == StoneDatePickerVariant.compactSheet;
    final inline = widget.variant == StoneDatePickerVariant.inlinePanel;
    final accent = _accentForMode(_mode);
    final subtitle = widget.subtitle ?? _subtitleForMode(_mode);
    final horizontal = compact ? 14.0 : 18.0;
    final top = inline ? 0.0 : 12.0;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final content = Padding(
      padding: EdgeInsets.only(
        left: horizontal,
        right: horizontal,
        top: top,
        bottom: inline ? 0 : bottomInset + 14,
      ),
      child: Column(
        mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!inline) _DragHandle(accent: accent),
          if (widget.allowModeSwitch) ...[
            Center(
              child: _ModeSwitch(mode: _mode, onChanged: _setMode),
            ),
            SizedBox(height: compact ? 14 : 20),
          ],
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: StoneRegisterDatePickerTheme.titleStyle(context),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.lerp(
                StoneRegisterDatePickerTheme.silverLow,
                accent,
                0.78,
              ),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          Semantics(
            label: 'Selected date ${widget.adapter.formatValue(_value, _mode)}',
            child: StoneRegisterDateWheel(
              columns: _columns,
              controllers: _controllers,
              accent: accent,
              onSelectedItemChanged: _selectColumnIndex,
            ),
          ),
          if (!inline) ...[
            SizedBox(height: compact ? 14 : 18),
            _ActionRow(
              accent: accent,
              cancelLabel: widget.cancelLabel,
              confirmLabel: widget.confirmLabel,
              onCancel: () => Navigator.of(context).pop(null),
              onConfirm: () => Navigator.of(context).pop(_value),
            ),
          ],
        ],
      ),
    );

    if (inline) return content;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.35,
            colors: [
              Color(0xFF1A1509),
              StoneRegisterDatePickerTheme.base,
              StoneRegisterDatePickerTheme.baseDeep,
            ],
            stops: [0, 0.42, 1],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: content,
      ),
    );
  }

  void _setMode(StoneDatePickerCalendarMode nextMode) {
    if (nextMode == _mode) return;
    setState(() {
      _mode = nextMode;
      _value = widget.adapter.clampOrNormalize(_value, _mode);
      _columns = widget.adapter.buildColumns(_value, _mode);
      _ensureControllers();
    });
    _syncControllers();
  }

  void _selectColumnIndex(String columnId, int selectedIndex) {
    final selection = _selectionFromColumns().withIndex(
      columnId,
      selectedIndex,
    );
    setState(() {
      _value = widget.adapter.clampOrNormalize(
        widget.adapter.valueFromSelection(selection, _mode),
        _mode,
      );
      _columns = widget.adapter.buildColumns(_value, _mode);
      _ensureControllers();
    });
    _syncControllers(exceptColumnId: columnId);
  }

  StoneWheelSelection _selectionFromColumns() {
    return StoneWheelSelection({
      for (final column in _columns)
        column.id: _nearestControllerIndexFor(column),
    });
  }

  int _nearestControllerIndexFor(StoneWheelColumn column) {
    final controller = _controllers[column.id];
    if (controller != null && controller.hasClients) {
      return StoneRegisterWheelMetrics.selectedIndexForOffset(
        column,
        controller.offset,
      );
    }
    return column.selectedIndex
        .clamp(0, column.values.isEmpty ? 0 : column.values.length - 1)
        .toInt();
  }

  void _ensureControllers() {
    final liveIds = _columns.map((column) => column.id).toSet();
    final staleIds = _controllers.keys
        .where((id) => !liveIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _controllers.remove(id)?.dispose();
    }

    for (final column in _columns) {
      _controllers.putIfAbsent(
        column.id,
        () => ScrollController(
          initialScrollOffset: StoneRegisterWheelMetrics.initialOffsetFor(
            column,
          ),
        ),
      );
    }
  }

  void _syncControllers({String? exceptColumnId}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final column in _columns) {
        if (column.id == exceptColumnId) continue;
        if (column.values.isEmpty) continue;
        final controller = _controllers[column.id];
        if (controller == null || !controller.hasClients) continue;
        final targetOffset = StoneRegisterWheelMetrics.offsetForSelectedIndex(
          column,
          column.selectedIndex,
          currentOffset: controller.offset,
        );
        if ((controller.offset - targetOffset).abs() < 0.5) continue;
        controller.jumpTo(targetOffset);
      }
    });
  }

  Color _accentForMode(StoneDatePickerCalendarMode mode) {
    return mode == StoneDatePickerCalendarMode.gregorian
        ? StoneRegisterDatePickerTheme.gregorian
        : StoneRegisterDatePickerTheme.gold;
  }

  String _subtitleForMode(StoneDatePickerCalendarMode mode) {
    return mode == StoneDatePickerCalendarMode.gregorian
        ? 'Gregorian Calendar'
        : 'Kemetic Calendar';
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final StoneDatePickerCalendarMode mode;
  final ValueChanged<StoneDatePickerCalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C180F),
        border: Border.all(color: const Color(0xFF2A2417)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeButton(
              label: 'Kemetic',
              selected: mode == StoneDatePickerCalendarMode.kemetic,
              onTap: () => onChanged(StoneDatePickerCalendarMode.kemetic),
            ),
            _ModeButton(
              label: 'Gregorian',
              selected: mode == StoneDatePickerCalendarMode.gregorian,
              onTap: () => onChanged(StoneDatePickerCalendarMode.gregorian),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2E2715) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? StoneRegisterDatePickerTheme.silverHigh
                  : StoneRegisterDatePickerTheme.silverMid,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.accent,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final Color accent;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final accentSoft = StoneRegisterDatePickerTheme.accentSoftFor(accent);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: StoneRegisterDatePickerTheme.silverMid,
                side: const BorderSide(color: Color(0xFF251F13)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    StoneRegisterDatePickerTheme.buttonRadius,
                  ),
                ),
                textStyle: const TextStyle(
                  fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: onCancel,
              child: Text(cancelLabel),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  StoneRegisterDatePickerTheme.buttonRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.32),
                    blurRadius: 16,
                    spreadRadius: -9,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF140F06),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          StoneRegisterDatePickerTheme.buttonRadius,
                        ),
                      ),
                      textStyle: const TextStyle(
                        fontFamily:
                            StoneRegisterDatePickerTheme.serifFontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (_) => Color.lerp(accent, accentSoft, 0.35),
                      ),
                    ),
                onPressed: onConfirm,
                child: Text(confirmLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
