import 'package:flutter/material.dart';
import '../../data/nutrition_repo.dart';

/// A dialog that allows the user to configure when a nutrient should be taken.
///
/// The dialog lets the user choose between scheduling by weekdays or by decan
/// days (1–10 in any decan). It also supports toggling repetition, picking
/// a time of day and specifying an optional alert offset in minutes.
///
/// When the user taps **Save**, the dialog returns a new [IntakeSchedule].
class SchedulePickerDialog extends StatefulWidget {
  final IntakeSchedule initial;

  const SchedulePickerDialog({Key? key, required this.initial}) : super(key: key);

  @override
  State<SchedulePickerDialog> createState() => _SchedulePickerDialogState();
}

class _SchedulePickerDialogState extends State<SchedulePickerDialog> {
  late IntakeMode _mode;
  late Set<int> _weekdaySelection;
  late Set<int> _decanSelection;
  late bool _repeat;
  late TimeOfDay _time;
  int? _alertMinutes;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _mode = s.mode;
    _weekdaySelection = {...s.daysOfWeek};
    _decanSelection = {...s.decanDays};
    _repeat = s.repeat;
    _time = s.time;
    _alertMinutes = s.alertOffset?.inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text('When to take', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 12),
            if (_mode == IntakeMode.weekday) _buildWeekdayPicker(),
            if (_mode == IntakeMode.decan) _buildDecanPicker(),
            const SizedBox(height: 8),
            _buildRepeatSwitch(),
            const SizedBox(height: 8),
            _buildTimePicker(context),
            const SizedBox(height: 8),
            _buildAlertDropdown(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _saveAndClose,
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Weekdays'),
          selected: _mode == IntakeMode.weekday,
          onSelected: (v) {
            if (v) setState(() => _mode = IntakeMode.weekday);
          },
          selectedColor: Colors.white24,
          labelStyle: TextStyle(
            color: _mode == IntakeMode.weekday ? Colors.white : Colors.white70,
          ),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('Decan'),
          selected: _mode == IntakeMode.decan,
          onSelected: (v) {
            if (v) setState(() => _mode = IntakeMode.decan);
          },
          selectedColor: Colors.white24,
          labelStyle: TextStyle(
            color: _mode == IntakeMode.decan ? Colors.white : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayPicker() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final selected = _weekdaySelection.contains(dayNum);
        return FilterChip(
          label: Text(labels[i]),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _weekdaySelection.add(dayNum);
              } else {
                _weekdaySelection.remove(dayNum);
              }
            });
          },
          selectedColor: Colors.white24,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.white70,
          ),
        );
      }),
    );
  }

  Widget _buildDecanPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(10, (i) {
        final dayNum = i + 1;
        final selected = _decanSelection.contains(dayNum);
        return FilterChip(
          label: Text('Day $dayNum'),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _decanSelection.add(dayNum);
              } else {
                _decanSelection.remove(dayNum);
              }
            });
          },
          selectedColor: Colors.white24,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.white70,
          ),
        );
      }),
    );
  }

  Widget _buildRepeatSwitch() {
    return SwitchListTile(
      value: _repeat,
      onChanged: (v) => setState(() => _repeat = v),
      title: const Text('Repeat', style: TextStyle(color: Colors.white)),
      activeColor: Colors.white,
    );
  }

  Widget _buildTimePicker(BuildContext context) {
    return ListTile(
      title: const Text('Time of day', style: TextStyle(color: Colors.white)),
      subtitle: Text(
        _time.format(context),
        style: const TextStyle(color: Colors.blueAccent),
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _time,
        );
        if (picked != null) {
          setState(() => _time = picked);
        }
      },
    );
  }

  Widget _buildAlertDropdown() {
    return DropdownButtonFormField<int?>(
      value: _alertMinutes,
      onChanged: (v) => setState(() => _alertMinutes = v),
      style: const TextStyle(color: Colors.white),
      dropdownColor: Colors.black,
      decoration: const InputDecoration(
        labelText: 'Alert',
        labelStyle: TextStyle(color: Colors.white70),
      ),
      items: const [
        DropdownMenuItem<int?>(value: null, child: Text('No alert')),
        DropdownMenuItem<int?>(value: 5, child: Text('5 min before')),
        DropdownMenuItem<int?>(value: 10, child: Text('10 min before')),
        DropdownMenuItem<int?>(value: 15, child: Text('15 min before')),
        DropdownMenuItem<int?>(value: 30, child: Text('30 min before')),
      ],
    );
  }

  void _saveAndClose() {
    final schedule = IntakeSchedule(
      mode: _mode,
      daysOfWeek: _weekdaySelection,
      decanDays: _decanSelection,
      repeat: _repeat,
      time: _time,
      alertOffset: _alertMinutes == null ? null : Duration(minutes: _alertMinutes!),
    );
    Navigator.of(context).pop(schedule);
  }
}

