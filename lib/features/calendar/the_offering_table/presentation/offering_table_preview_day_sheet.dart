import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../the_offering_table_flow.dart';
import '../../../../widgets/keyboard_aware.dart';
import 'offering_table_day_components.dart';
import 'offering_table_day_presentation.dart';
import 'offering_table_presentation_copy.dart';

Future<void> showOfferingTablePreviewDaySheet({
  required BuildContext context,
  required OfferingTablePreviewOccurrence occurrence,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    backgroundColor: OfferingTablePreviewDaySheet.background,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      side: BorderSide(color: Color(0x4AC99A3D)),
    ),
    builder: (context) => OfferingTablePreviewDaySheet(occurrence: occurrence),
  );
}

/// Ritual-first practice opened by Offering Table detail events.
///
/// The HTML is the visual authority. Production daily copy, instrument, course,
/// and stage authorities are reused so this cannot drift into a second flow.
class OfferingTablePreviewDaySheet extends StatefulWidget {
  const OfferingTablePreviewDaySheet({super.key, required this.occurrence});

  final OfferingTablePreviewOccurrence occurrence;

  static const background = Color(0xFF0C0905);
  static const gold = Color(0xFFC99A3D);
  static const glow = Color(0xFFF0C96A);
  static const bone = Color(0xFFE8DED0);
  static const silver = Color(0xFFA59D91);
  static const intent = Color(0xFFE8B27C);
  static const separator = Color(0xFF302313);

  @override
  State<OfferingTablePreviewDaySheet> createState() =>
      _OfferingTablePreviewDaySheetState();
}

class _OfferingTablePreviewDaySheetState
    extends State<OfferingTablePreviewDaySheet> {
  late final TextEditingController _wordController;
  late final FocusNode _wordFocusNode;
  late List<bool> _moveDone;
  bool _contextExpanded = false;

  OfferingTableDay get _day => widget.occurrence.day;
  OfferingTablePracticePresentation get _presentation =>
      offeringTablePracticePresentation(_day);
  OfferingTableStage get _stage => offeringTableStage(_day.dayNumber);
  bool get _isNameMove => _day.dayNumber == 1;

  bool get _complete {
    if (_moveDone.isEmpty) return false;
    if (_isNameMove && _wordController.text.trim().isEmpty) return false;
    return _moveDone.skip(_isNameMove ? 1 : 0).every((done) => done);
  }

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController()..addListener(_onWordChanged);
    _wordFocusNode = FocusNode();
    _moveDone = List<bool>.filled(_presentation.steps.length, false);
  }

  @override
  void dispose() {
    _wordController
      ..removeListener(_onWordChanged)
      ..dispose();
    _wordFocusNode.dispose();
    super.dispose();
  }

  void _onWordChanged() {
    if (_isNameMove && _moveDone.isNotEmpty) {
      _moveDone[0] = _wordController.text.trim().isNotEmpty;
    }
    setState(() {});
  }

  void _toggleMove(int index) {
    if (_isNameMove && index == 0) {
      _wordFocusNode.requestFocus();
      return;
    }
    setState(() => _moveDone[index] = !_moveDone[index]);
  }

  void _reset() {
    _wordController.clear();
    setState(() {
      _moveDone = List<bool>.filled(_presentation.steps.length, false);
      _contextExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('offering-table-preview-sheet-host'),
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[0, .34, 1],
              colors: <Color>[
                Color(0xFF100B06),
                OfferingTablePreviewDaySheet.background,
                Color(0xFF090603),
              ],
            ),
          ),
          child: SingleChildScrollView(
            key: const ValueKey<String>('offering-table-preview-sheet-scroll'),
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              24 + keyboardInsetOf(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _PracticeHandle(),
                _buildTop(),
                const SizedBox(height: 5),
                Text(
                  _day.title,
                  style: const TextStyle(
                    color: OfferingTablePreviewDaySheet.bone,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 31,
                    fontWeight: FontWeight.w500,
                    height: 1.06,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_sheetDate(widget.occurrence.date)} · ${_formatTime(widget.occurrence.startLocal)}',
                  style: const TextStyle(
                    color: OfferingTablePreviewDaySheet.silver,
                    fontFamily: 'GentiumPlus',
                    fontSize: 11.5,
                    letterSpacing: .25,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _presentation.previewSummary,
                  style: const TextStyle(
                    color: Color(0xFFC9BCA6),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 18.5,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 19),
                _PracticeStage(
                  day: _day,
                  word: _wordController.text,
                  steps: _presentation.steps,
                  moveDone: _moveDone,
                  onMovePressed: _toggleMove,
                ),
                if (_isNameMove)
                  _PracticeWordField(
                    controller: _wordController,
                    focusNode: _wordFocusNode,
                  ),
                const SizedBox(height: 24),
                OfferingTableCourseTrack(
                  dayNumber: _day.dayNumber,
                  stageLabel: _stage.name
                      .replaceFirst(' Table', '')
                      .toUpperCase(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    opacity: _complete ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_complete,
                      child: _ProvisionReturned(dayNumber: _day.dayNumber),
                    ),
                  ),
                ),
                _buildContext(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const ValueKey<String>(
                            'offering-table-preview-sheet-back',
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                OfferingTablePreviewDaySheet.silver,
                            padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
                            textStyle: const TextStyle(
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 17,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0x59A59D91),
                            ),
                          ),
                          child: const Text('Back to the table'),
                        ),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        key: const ValueKey<String>(
                          'offering-table-preview-sheet-reset',
                        ),
                        onPressed: _reset,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF5F5648),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'GentiumPlus',
                            fontSize: 12,
                          ),
                        ),
                        child: const Text('reset this day'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'DAY ${_day.dayNumber.toString().padLeft(2, '0')} · ${_stage.name.toUpperCase()}',
              style: const TextStyle(
                color: OfferingTablePreviewDaySheet.gold,
                fontFamily: 'GentiumPlus',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.7,
                height: 1.25,
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('offering-table-preview-sheet-close'),
          tooltip: 'Close Offering Table practice',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close,
            color: OfferingTablePreviewDaySheet.silver,
            size: 25,
          ),
        ),
      ],
    );
  }

  Widget _buildContext() {
    return Container(
      margin: const EdgeInsets.only(top: 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: OfferingTablePreviewDaySheet.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>(
              'offering-table-preview-sheet-context-toggle',
            ),
            onTap: () => setState(() => _contextExpanded = !_contextExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Why this belongs at the Offering Table',
                      style: TextStyle(
                        color: Color(0xFF9D8F7A),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _contextExpanded ? '−' : '+',
                    style: const TextStyle(
                      color: OfferingTablePreviewDaySheet.gold,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 16,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _contextExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${_presentation.context}\n\n${_presentation.instruction}',
                      style: const TextStyle(
                        color: Color(0xFF8E8375),
                        fontFamily: 'GentiumPlus',
                        fontSize: 14.5,
                        height: 1.46,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PracticeHandle extends StatelessWidget {
  const _PracticeHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF4B4033),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _PracticeStage extends StatelessWidget {
  const _PracticeStage({
    required this.day,
    required this.word,
    required this.steps,
    required this.moveDone,
    required this.onMovePressed,
  });

  final OfferingTableDay day;
  final String word;
  final List<String> steps;
  final List<bool> moveDone;
  final ValueChanged<int> onMovePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 142,
          height: 204,
          child: day.dayNumber == 1
              ? OfferingTableSmallSupplyJarVisual(
                  key: const ValueKey<String>(
                    'offering-table-preview-practice-instrument',
                  ),
                  label: word.trim().isEmpty ? 'supply…' : word.trim(),
                  refilled: moveDone.length > 1 && moveDone[1],
                  visible: moveDone.length > 2 && moveDone[2],
                  complete:
                      moveDone.isNotEmpty &&
                      word.trim().isNotEmpty &&
                      moveDone.skip(1).every((done) => done),
                )
              : _OfferingTableGenericInstrument(
                  label: word.trim().isEmpty ? day.title : word.trim(),
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < steps.length; index++)
                  _PracticeMove(
                    key: ValueKey<String>(
                      'offering-table-preview-move-${index + 1}',
                    ),
                    text: steps[index],
                    done: moveDone[index],
                    onPressed: () => onMovePressed(index),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PracticeMove extends StatelessWidget {
  const _PracticeMove({
    super.key,
    required this.text,
    required this.done,
    required this.onPressed,
  });

  final String text;
  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xD1302313))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? OfferingTablePreviewDaySheet.glow
                      : Colors.transparent,
                  border: Border.all(
                    color: done
                        ? OfferingTablePreviewDaySheet.glow
                        : const Color(0xFF6B5327),
                  ),
                  boxShadow: done
                      ? const <BoxShadow>[
                          BoxShadow(color: Color(0x66F0C96A), blurRadius: 9),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: done
                        ? OfferingTablePreviewDaySheet.bone
                        : const Color(0xFF9E9384),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 14.2,
                    height: 1.34,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeWordField extends StatelessWidget {
  const _PracticeWordField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xEB302313))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const SizedBox(
            width: 68,
            child: Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'SUPPLY',
                style: TextStyle(
                  color: Color(0xFF786331),
                  fontFamily: 'GentiumPlus',
                  fontSize: 8.8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.35,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey<String>(
                'offering-table-preview-practice-field',
              ),
              controller: controller,
              focusNode: focusNode,
              maxLength: 90,
              cursorColor: OfferingTablePreviewDaySheet.glow,
              style: const TextStyle(
                color: OfferingTablePreviewDaySheet.intent,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 17,
                fontStyle: FontStyle.italic,
                height: 1.15,
              ),
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(0, 5, 0, 8),
                hintText: 'supply…',
                hintStyle: TextStyle(
                  color: Color(0x855F564C),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisionReturned extends StatelessWidget {
  const _ProvisionReturned({required this.dayNumber});

  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('offering-table-preview-provision-returned'),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x47C99A3D)),
        gradient: const RadialGradient(
          center: Alignment(-.8, 1),
          radius: 1.8,
          colors: <Color>[Color(0x21F0C96A), Color(0x00F0C96A)],
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            const TextSpan(text: 'Provision returns to life through you.\n'),
            TextSpan(
              text: dayNumber < 30
                  ? 'Day ${dayNumber + 1} arrives tomorrow at 7:30.'
                  : 'The thirty-day table is complete.',
              style: const TextStyle(
                color: OfferingTablePreviewDaySheet.silver,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          color: OfferingTablePreviewDaySheet.bone,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontSize: 18,
          height: 1.32,
        ),
      ),
    );
  }
}

class _OfferingTableGenericInstrument extends StatelessWidget {
  const _OfferingTableGenericInstrument({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GenericOfferingInstrumentPainter(label),
      child: const SizedBox.expand(),
    );
  }
}

class _GenericOfferingInstrumentPainter extends CustomPainter {
  const _GenericOfferingInstrumentPainter(this.label);

  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .52),
      width: size.width * .95,
      height: size.height * .58,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0x20F0C96A), Color(0x00F0C96A)],
        ).createShader(glow),
    );
    final line = Paint()
      ..color = OfferingTablePreviewDaySheet.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55;
    final vessel = Path()
      ..moveTo(size.width * .23, size.height * .38)
      ..quadraticBezierTo(
        size.width * .28,
        size.height * .78,
        size.width * .5,
        size.height * .79,
      )
      ..quadraticBezierTo(
        size.width * .72,
        size.height * .78,
        size.width * .77,
        size.height * .38,
      );
    canvas.drawPath(vessel, line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .38),
        width: size.width * .54,
        height: 14,
      ),
      line,
    );
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0x99E8B27C),
          fontFamily: MaatFlowListTokens.fontFamily,
          fontSize: 9,
          fontStyle: FontStyle.italic,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: size.width * .62);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, size.height * .51),
    );
  }

  @override
  bool shouldRepaint(covariant _GenericOfferingInstrumentPainter oldDelegate) =>
      oldDelegate.label != label;
}

String _sheetDate(DateTime date) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]} · ${months[date.month - 1]} ${date.day}';
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
