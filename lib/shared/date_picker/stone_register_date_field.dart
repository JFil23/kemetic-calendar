import 'package:flutter/material.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

class StoneRegisterDateField<T> extends StatelessWidget {
  const StoneRegisterDateField({
    super.key,
    required this.value,
    required this.adapter,
    required this.mode,
    required this.onChanged,
    this.label,
    this.allowModeSwitch = true,
    this.title = 'Pick a date',
    this.enabled = true,
    this.showCalendarIcon = true,
  });

  final T value;
  final StoneDatePickerAdapter<T> adapter;
  final StoneDatePickerCalendarMode mode;
  final ValueChanged<T> onChanged;
  final String? label;
  final bool allowModeSwitch;
  final String title;
  final bool enabled;
  final bool showCalendarIcon;

  @override
  Widget build(BuildContext context) {
    final display = adapter.formatValue(value, mode);
    return Semantics(
      button: enabled,
      label: label == null ? display : '$label, $display',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => _openPicker(context) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF191309),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E2616)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null) ...[
                      Text(
                        label!,
                        style: const TextStyle(
                          color: StoneRegisterDatePickerTheme.silverLow,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StoneRegisterDatePickerTheme.silverHigh,
                        fontFamily:
                            StoneRegisterDatePickerTheme.serifFontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showCalendarIcon)
                const Icon(
                  Icons.calendar_month_outlined,
                  color: StoneRegisterDatePickerTheme.silverMid,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await StoneRegisterDatePicker.show<T>(
      context,
      initialValue: value,
      adapter: adapter,
      initialMode: mode,
      allowModeSwitch: allowModeSwitch,
      title: title,
    );
    if (result != null) onChanged(result);
  }
}
