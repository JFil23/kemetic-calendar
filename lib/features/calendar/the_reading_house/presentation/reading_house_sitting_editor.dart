import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

class ReadingHouseSittingEditorSheet extends StatefulWidget {
  const ReadingHouseSittingEditorSheet({
    super.key,
    required this.sitting,
    required this.initialDate,
    required this.initialTime,
    required this.flowDayForDate,
    required this.accentColor,
    required this.borderColor,
    this.onSave,
    this.manageKeyboardInset = true,
  });

  final ReadingHouseSitting sitting;
  final DateTime initialDate;
  final TimeOfDay initialTime;
  final int Function(DateTime date) flowDayForDate;
  final Color accentColor;
  final Color borderColor;
  final Future<bool> Function(ReadingHouseSitting sitting)? onSave;
  final bool manageKeyboardInset;

  static Future<ReadingHouseSitting?> show(
    BuildContext context, {
    required ReadingHouseSitting sitting,
    required DateTime initialDate,
    required TimeOfDay initialTime,
    required int Function(DateTime date) flowDayForDate,
    required Color accentColor,
    required Color borderColor,
    Future<bool> Function(ReadingHouseSitting sitting)? onSave,
    bool manageKeyboardInset = true,
  }) {
    return showModalBottomSheet<ReadingHouseSitting>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReadingHouseSittingEditorSheet(
        sitting: sitting,
        initialDate: initialDate,
        initialTime: initialTime,
        flowDayForDate: flowDayForDate,
        accentColor: accentColor,
        borderColor: borderColor,
        onSave: onSave,
        manageKeyboardInset: manageKeyboardInset,
      ),
    );
  }

  @override
  State<ReadingHouseSittingEditorSheet> createState() =>
      _ReadingHouseSittingEditorSheetState();
}

class _ReadingHouseSittingEditorSheetState
    extends State<ReadingHouseSittingEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _themeCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  late bool _placementChosen;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    final sitting = widget.sitting;
    _titleCtrl = TextEditingController(text: sitting.title);
    _sectionCtrl = TextEditingController(text: sitting.section);
    _themeCtrl = TextEditingController(text: sitting.theme);
    _promptCtrl = TextEditingController(text: sitting.privatePrompt);
    _noteCtrl = TextEditingController(text: sitting.hostNote);
    _scheduledDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _scheduledTime = widget.initialTime;
    _placementChosen = sitting.scheduledDate != null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sectionCtrl.dispose();
    _themeCtrl.dispose();
    _promptCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) {
    final k = KemeticMath.fromGregorian(date);
    final month = getMonthById(k.kMonth).displayFull;
    final gregorian =
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
    return '$month ${k.kDay} · $gregorian';
  }

  Future<void> _pickDate() async {
    final picked = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _scheduledDate,
      initialMode: MaatFlowDatePickerMode.kemetic,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scheduledDate = DateUtils.dateOnly(picked.date);
      _placementChosen = true;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scheduledTime = picked;
      _placementChosen = true;
    });
  }

  InputDecoration _fieldDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: Color(0xFF9C9086)),
      hintStyle: const TextStyle(color: Color(0xFF7E746B)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: widget.accentColor.withValues(alpha: 0.28),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: widget.accentColor),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    Key? key,
    String? hintText,
  }) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      scrollPadding: keyboardManagedTextFieldScrollPadding,
      style: const TextStyle(color: Color(0xFFE8D9C3)),
      decoration: _fieldDecoration(label, hintText: hintText),
    );
  }

  String _trimmedOrFallback(TextEditingController controller, String fallback) {
    final trimmed = controller.text.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    final sitting = widget.sitting;
    final edited = sitting
        .copyWith(
          title: _trimmedOrFallback(_titleCtrl, sitting.title),
          section: _trimmedOrFallback(_sectionCtrl, sitting.section),
          theme: _trimmedOrFallback(_themeCtrl, sitting.theme),
          privatePrompt: _trimmedOrFallback(_promptCtrl, sitting.privatePrompt),
          hostNote: _noteCtrl.text.trim(),
          scheduledDate: _placementChosen ? _scheduledDate : null,
          flowDay: _placementChosen
              ? widget.flowDayForDate(_scheduledDate)
              : sitting.flowDay,
          hour: _scheduledTime.hour,
          minute: _scheduledTime.minute,
        )
        .asHostAuthored();
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(edited);
      return;
    }

    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await onSave(edited);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(edited);
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = widget.manageKeyboardInset
        ? media.viewInsets.bottom
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: media.padding.bottom + 18,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF090907),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit sitting',
                  style: TextStyle(
                    color: widget.accentColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  'Sitting title',
                  _titleCtrl,
                  hintText: 'Name this sitting...',
                  key: const ValueKey<String>(
                    'reading_house_sitting_title_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Section',
                  _sectionCtrl,
                  hintText: 'Chapters, pages, maxims, or passage...',
                  key: const ValueKey<String>(
                    'reading_house_sitting_section_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Theme',
                  _themeCtrl,
                  maxLines: 2,
                  hintText: 'What should the house hold while reading?',
                  key: const ValueKey<String>(
                    'reading_house_sitting_theme_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Private prompt',
                  _promptCtrl,
                  maxLines: 3,
                  hintText: 'What should each reader sit with before sharing?',
                  key: const ValueKey<String>(
                    'reading_house_sitting_private_prompt_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Host note',
                  _noteCtrl,
                  maxLines: 2,
                  hintText: 'Optional note, passage to watch, or context...',
                  key: const ValueKey<String>(
                    'reading_house_sitting_host_note_field',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'reading_house_sitting_date_button',
                      ),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _placementChosen
                            ? _dateLabel(_scheduledDate)
                            : 'Choose date',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.accentColor,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'reading_house_sitting_time_button',
                      ),
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatTimeOfDay(_scheduledTime),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_saveFailed) ...[
                  Text(
                    'That sitting could not be saved. Your edits are still here.',
                    key: const ValueKey<String>(
                      'reading_house_sitting_save_error',
                    ),
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey<String>(
                      'reading_house_sitting_save_button',
                    ),
                    onPressed: _saving ? null : _saveDraft,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Saving…' : 'Save Sitting'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
