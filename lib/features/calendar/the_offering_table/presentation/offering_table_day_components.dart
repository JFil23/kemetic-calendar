import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../the_offering_table_flow.dart';

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

class OfferingTableContextDisclosure extends StatefulWidget {
  const OfferingTableContextDisclosure({
    super.key,
    required this.day,
    required this.lens,
    required this.why,
  });

  final OfferingTableDay day;
  final OfferingTableLens lens;
  final String why;

  @override
  State<OfferingTableContextDisclosure> createState() =>
      _OfferingTableContextDisclosureState();
}

class _OfferingTableContextDisclosureState
    extends State<OfferingTableContextDisclosure> {
  static const _gold = Color(0xFFD4AE43);
  static const _separator = Color(0xFF2A2415);
  static const _muted = Color(0xFF8E867C);
  static const _ivory = Color(0xFFE8E2D6);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sourceNote = widget.day.sourceNote?.trim();
    final lensLine = widget.lens.detailLine.trim();
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _separator),
          bottom: BorderSide(color: _separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>(
              'offering-table-day-sheet-context-toggle',
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Why this belongs at the Offering Table',
                      style: TextStyle(
                        color: Color(0xFF9E9A94),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF7A4E2E),
                      size: 18,
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
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'WHY THIS DAY',
                            style: TextStyle(
                              color: _gold,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 10.5,
                              letterSpacing: 2.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(widget.why, style: _whyStyle),
                          if (sourceNote?.isNotEmpty == true) ...<Widget>[
                            const SizedBox(height: 14),
                            Text(sourceNote!, style: _contextStyle),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            '“${offeringTableDecanLine(widget.day.dayNumber)}”',
                            style: _contextStyle.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (lensLine.isNotEmpty) ...<Widget>[
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
    color: _muted,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 16,
    height: 1.45,
  );

  static const _whyStyle = TextStyle(
    color: _ivory,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 16,
    height: 1.45,
  );
}

class OfferingTableStage {
  const OfferingTableStage({
    required this.name,
    required this.progressLanguage,
  });

  final String name;
  final String progressLanguage;
}

OfferingTableStage offeringTableStage(int dayNumber) {
  if (dayNumber <= 10) {
    return const OfferingTableStage(
      name: 'Personal Table',
      progressLanguage: 'Provide for yourself',
    );
  }
  if (dayNumber <= 20) {
    return const OfferingTableStage(
      name: 'Household Table',
      progressLanguage: 'Provide for what depends on you',
    );
  }
  return const OfferingTableStage(
    name: 'Flowing Table',
    progressLanguage: 'Return provision to the larger flow',
  );
}
