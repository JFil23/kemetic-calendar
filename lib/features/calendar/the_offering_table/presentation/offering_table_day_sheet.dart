import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../presentation/maat_flow_preview_day.dart';
import '../../the_offering_table_flow.dart';
import 'offering_table_presentation_copy.dart';

@immutable
class OfferingTablePreviewOccurrence {
  const OfferingTablePreviewOccurrence({
    required this.day,
    required this.date,
    required this.startLocal,
  });

  final OfferingTableDay day;
  final DateTime date;
  final DateTime startLocal;
}

Future<void> showOfferingTableDaySheet({
  required BuildContext context,
  required OfferingTablePreviewOccurrence occurrence,
  required OfferingTableLens lens,
  required bool noCupMode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: const Color(0xFF0C0905),
    barrierColor: Colors.black.withValues(alpha: 0.66),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0x4AC99A3D)),
    ),
    builder: (context) => OfferingTableDaySheet(
      occurrence: occurrence,
      lens: lens,
      noCupMode: noCupMode,
    ),
  );
}

class OfferingTableDaySheet extends StatelessWidget {
  const OfferingTableDaySheet({
    super.key,
    required this.occurrence,
    required this.lens,
    required this.noCupMode,
  });

  final OfferingTablePreviewOccurrence occurrence;
  final OfferingTableLens lens;
  final bool noCupMode;

  static const _background = Color(0xFF0C0905);
  static const _panel = Color(0xFF110C07);
  static const _gold = Color(0xFFC99A3D);
  static const _goldBright = Color(0xFFF0C96A);
  static const _ivory = Color(0xFFD7CDBA);
  static const _silver = Color(0xFFA59D91);
  static const _muted = Color(0xFF91877A);
  static const _separator = Color(0xFF302313);

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final stage = _offeringStage(day.dayNumber);
    final stageDay = ((day.dayNumber - 1) % 10) + 1;
    final presentation = offeringTablePracticePresentation(day);

    return SafeArea(
      key: const ValueKey<String>('offering-table-day-sheet'),
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: ColoredBox(
          color: _background,
          child: SingleChildScrollView(
            key: const ValueKey<String>('offering-table-day-sheet-scroll'),
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B4033),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'DAY ${day.dayNumber.toString().padLeft(2, '0')} OF 30 · ${stage.name.toUpperCase()}',
                          style: const TextStyle(
                            color: _gold,
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.7,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'offering-table-day-sheet-top-close',
                      ),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: _silver, size: 25),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  day.title,
                  style: const TextStyle(
                    color: _ivory,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${gregorianDateLabel(occurrence.date)}, ${occurrence.date.year} · ${_formatTime(occurrence.startLocal)}',
                  style: const TextStyle(
                    color: _silver,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 11.5,
                    letterSpacing: 0.25,
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stage.progressLanguage,
                        style: const TextStyle(
                          color: Color(0xFF9D8C70),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.05,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$stageDay/10',
                      style: const TextStyle(
                        color: Color(0xFF9D8C70),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.05,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    key: const ValueKey<String>(
                      'offering-table-day-sheet-progress',
                    ),
                    value: stageDay / 10,
                    minHeight: 3,
                    backgroundColor: const Color(0xFF2A2117),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _goldBright,
                    ),
                  ),
                ),
                const _SheetDivider(),
                const _SheetLabel('YOUR MOVE'),
                const SizedBox(height: 9),
                Container(
                  key: const ValueKey<String>(
                    'offering-table-day-sheet-your-move',
                  ),
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3C2B16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        presentation.instruction,
                        style: const TextStyle(
                          color: Color(0xFFE4D8C3),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 19,
                          height: 1.35,
                        ),
                      ),
                      if (presentation.steps.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        for (
                          var index = 0;
                          index < presentation.steps.length;
                          index++
                        ) ...[
                          _OfferingStep(
                            number: index + 1,
                            text: presentation.steps[index],
                          ),
                          if (index != presentation.steps.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
                const _SheetDivider(),
                const _SheetLabel('CLOSE THE RITUAL'),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0B08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF302719)),
                  ),
                  child: const Row(
                    children: [
                      _WaterIcon(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Drink the water.',
                              style: TextStyle(
                                color: _ivory,
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontFamilyFallback:
                                    MaatFlowListTokens.fontFallback,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Provision returns to life through you.',
                              style: TextStyle(
                                color: Color(0xFF968B7C),
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontFamilyFallback:
                                    MaatFlowListTokens.fontFallback,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _OfferingContextDisclosure(
                  day: day,
                  lens: lens,
                  why: presentation.why,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: TextButton(
                    key: const ValueKey<String>(
                      'offering-table-day-sheet-close',
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF120C05),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Back to the table',
                      style: TextStyle(
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(color: OfferingTableDaySheet._separator, height: 1),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: OfferingTableDaySheet._gold,
        fontFamily: MaatFlowListTokens.fontFamily,
        fontFamilyFallback: MaatFlowListTokens.fontFallback,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        height: 1.2,
      ),
    );
  }
}

class _OfferingStep extends StatelessWidget {
  const _OfferingStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 23,
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF755927)),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Color(0xFFD2AA57),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBAAF9E),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _WaterIcon extends StatelessWidget {
  const _WaterIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF78602E)),
      ),
      child: const Icon(
        Icons.water_drop_outlined,
        color: Color(0xFFD5AF58),
        size: 18,
      ),
    );
  }
}

class _OfferingContextDisclosure extends StatefulWidget {
  const _OfferingContextDisclosure({
    required this.day,
    required this.lens,
    required this.why,
  });

  final OfferingTableDay day;
  final OfferingTableLens lens;
  final String why;

  @override
  State<_OfferingContextDisclosure> createState() =>
      _OfferingContextDisclosureState();
}

class _OfferingContextDisclosureState
    extends State<_OfferingContextDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sourceNote = widget.day.sourceNote?.trim();
    final lensLine = widget.lens.detailLine.trim();
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: OfferingTableDaySheet._separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey<String>(
              'offering-table-day-sheet-context-toggle',
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Why this belongs at the Offering Table',
                      style: TextStyle(
                        color: Color(0xFF9D8F7A),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _expanded ? '−' : '+',
                    style: const TextStyle(
                      color: OfferingTableDaySheet._gold,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SheetLabel('WHY THIS DAY'),
                          const SizedBox(height: 8),
                          Text(widget.why, style: _whyStyle),
                          const SizedBox(height: 14),
                          if (sourceNote?.isNotEmpty == true) ...[
                            Text(sourceNote!, style: _contextStyle),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            '“${offeringTableDecanLine(widget.day.dayNumber)}”',
                            style: _contextStyle.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (lensLine.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(lensLine, style: _contextStyle),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  static const _contextStyle = TextStyle(
    color: OfferingTableDaySheet._muted,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 13,
    height: 1.48,
  );

  static const _whyStyle = TextStyle(
    color: OfferingTableDaySheet._ivory,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 15,
    height: 1.42,
  );
}

class _OfferingStage {
  const _OfferingStage({required this.name, required this.progressLanguage});

  final String name;
  final String progressLanguage;
}

_OfferingStage _offeringStage(int dayNumber) {
  if (dayNumber <= 10) {
    return const _OfferingStage(
      name: 'Personal Table',
      progressLanguage: 'Provide for yourself',
    );
  }
  if (dayNumber <= 20) {
    return const _OfferingStage(
      name: 'Household Table',
      progressLanguage: 'Provide for what depends on you',
    );
  }
  return const _OfferingStage(
    name: 'Flowing Table',
    progressLanguage: 'Return provision to the larger flow',
  );
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
