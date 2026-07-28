import 'package:flutter/material.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_sheet.dart';

export 'stone_register_date_picker_sheet.dart'
    show
        StoneDatePickerAdapter,
        StoneDatePickerCalendarMode,
        StoneDatePickerVariant;
export 'stone_register_date_wheel.dart'
    show StoneWheelColumn, StoneWheelSelection;

class StoneRegisterDatePicker {
  const StoneRegisterDatePicker._();

  static Future<T?> show<T>(
    BuildContext context, {
    required T initialValue,
    required StoneDatePickerAdapter<T> adapter,
    StoneDatePickerCalendarMode initialMode =
        StoneDatePickerCalendarMode.kemetic,
    bool allowModeSwitch = true,
    StoneDatePickerVariant variant = StoneDatePickerVariant.fullSheet,
    String title = 'Pick a date',
    String? subtitle,
    String confirmLabel = 'Done',
    String cancelLabel = 'Cancel',
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StoneRegisterDatePickerSheet<T>(
        initialValue: initialValue,
        adapter: adapter,
        initialMode: initialMode,
        allowModeSwitch: allowModeSwitch,
        variant: variant,
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  }
}
