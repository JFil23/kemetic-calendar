import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../presentation/maat_flow_preview_day.dart';
import '../../the_offering_table_flow.dart';
import '../../../../widgets/keyboard_aware.dart';
import 'offering_table_day_components.dart';
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
    barrierColor: Colors.black.withValues(alpha: 0.66),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0x4AC99A3D)),
    ),
    builder: (context) => OfferingTablePreviewDaySheet(occurrence: occurrence),
  );
}

/// The lightweight practice preview used only from the Offering flow detail.
///
/// Day View deliberately uses `OfferingTableDayPresentation` instead. Both
/// presentations derive their words from offeringTablePracticePresentation.
class OfferingTablePreviewDaySheet extends StatelessWidget {
  const OfferingTablePreviewDaySheet({super.key, required this.occurrence});

  final OfferingTablePreviewOccurrence occurrence;

  static const background = Color(0xFF0C0905);
  static const _panel = Color(0xFF110C07);
  static const _gold = Color(0xFFC99A3D);
  static const _goldBright = Color(0xFFF0C96A);
  static const _ivory = Color(0xFFD7CDBA);
  static const _silver = Color(0xFFA59D91);
  static const _separator = Color(0xFF302313);

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final stage = offeringTableStage(day.dayNumber);
    final stageDay = ((day.dayNumber - 1) % 10) + 1;
    final presentation = offeringTablePracticePresentation(day);
    final showInstruction =
        presentation.steps.isEmpty ||
        presentation.steps.first.trim() != presentation.instruction.trim();

    return SizedBox(
      key: const ValueKey<String>('offering-table-preview-sheet-host'),
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: SafeArea(
        top: false,
        child: ColoredBox(
          color: background,
          child: SingleChildScrollView(
            key: const ValueKey<String>('offering-table-preview-sheet-scroll'),
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              28 + keyboardInsetOf(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                  children: <Widget>[
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
                        'offering-table-preview-sheet-close',
                      ),
                      tooltip: 'Close Offering Table preview',
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
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        stage.progressLanguage.toUpperCase(),
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
                      'offering-table-preview-sheet-progress',
                    ),
                    value: stageDay / 10,
                    minHeight: 3,
                    backgroundColor: const Color(0xFF2A2117),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _goldBright,
                    ),
                  ),
                ),
                const _PreviewDivider(),
                const _PreviewLabel('WHY THIS DAY'),
                const SizedBox(height: 9),
                Text(
                  presentation.why,
                  key: const ValueKey<String>(
                    'offering-table-preview-sheet-why',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFD8CCBA),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 18,
                    height: 1.42,
                  ),
                ),
                const _PreviewDivider(),
                const _PreviewLabel('YOUR MOVE'),
                const SizedBox(height: 9),
                Container(
                  key: const ValueKey<String>(
                    'offering-table-preview-sheet-your-move',
                  ),
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3C2B16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (showInstruction)
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
                      if (presentation.steps.isNotEmpty) ...<Widget>[
                        if (showInstruction) const SizedBox(height: 15),
                        for (
                          var index = 0;
                          index < presentation.steps.length;
                          index++
                        ) ...<Widget>[
                          _PreviewStep(
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
                const _PreviewDivider(),
                const _PreviewLabel('CLOSE THE RITUAL'),
                const SizedBox(height: 9),
                Container(
                  key: const ValueKey<String>(
                    'offering-table-preview-sheet-water',
                  ),
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
                    children: <Widget>[
                      _PreviewWaterIcon(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
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
                _PreviewContextDisclosure(day: day),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: TextButton(
                    key: const ValueKey<String>(
                      'offering-table-preview-sheet-back',
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

class _PreviewDivider extends StatelessWidget {
  const _PreviewDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(color: OfferingTablePreviewDaySheet._separator, height: 1),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: OfferingTablePreviewDaySheet._gold,
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

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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

class _PreviewWaterIcon extends StatelessWidget {
  const _PreviewWaterIcon();

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

class _PreviewContextDisclosure extends StatefulWidget {
  const _PreviewContextDisclosure({required this.day});

  final OfferingTableDay day;

  @override
  State<_PreviewContextDisclosure> createState() =>
      _PreviewContextDisclosureState();
}

class _PreviewContextDisclosureState extends State<_PreviewContextDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final contextText = widget.day.sourceNote?.trim().isNotEmpty == true
        ? widget.day.sourceNote!.trim()
        : widget.day.purpose.trim();
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: OfferingTablePreviewDaySheet._separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>(
              'offering-table-preview-sheet-context-toggle',
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: <Widget>[
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
                      color: OfferingTablePreviewDaySheet._gold,
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
                      child: Text(
                        contextText,
                        style: const TextStyle(
                          color: Color(0xFF91877A),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 13,
                          height: 1.48,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}
