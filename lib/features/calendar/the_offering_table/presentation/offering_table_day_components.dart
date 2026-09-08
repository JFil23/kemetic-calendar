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
    required this.context,
    required this.instruction,
  });

  final String context;
  final String instruction;

  @override
  State<OfferingTableContextDisclosure> createState() =>
      _OfferingTableContextDisclosureState();
}

class _OfferingTableContextDisclosureState
    extends State<OfferingTableContextDisclosure> {
  static const _separator = Color(0xFF2A2415);
  static const _muted = Color(0xFF8E867C);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
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
                        color: Color(0xFFA99D8E),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _expanded ? '−' : '+',
                    key: const ValueKey<String>(
                      'offering-table-day-sheet-context-sign',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF7A4E2E),
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
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(widget.context, style: _contextStyle),
                          const SizedBox(height: 12),
                          Text(widget.instruction, style: _contextStyle),
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
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: <String>['Georgia', 'serif'],
    fontSize: 13,
    height: 1.42,
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
