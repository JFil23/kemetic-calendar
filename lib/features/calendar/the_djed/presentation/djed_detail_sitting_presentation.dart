import 'package:flutter/material.dart';

import '../../maat_flow_visual_tokens.dart';
import '../../the_djed_v2_flow.dart';
import 'djed_day_presentation.dart';

/// Detail-entry sitting content from the Djed detail reference.
///
/// This owns a single conventional scrolling column and deliberately does not
/// use the Day View layered foreground, completion picker, menu, or footer.
class DjedDetailSittingPresentation extends StatelessWidget {
  const DjedDetailSittingPresentation({
    super.key,
    required this.event,
    required this.sitting,
    required this.fixture,
    required this.supports,
    required this.onBack,
    this.onMoveChanged,
    this.onDoToday,
    this.onPutOnCalendar,
    this.onResultSelected,
    this.onResultNoteChanged,
    this.onSmallerMoveChanged,
    this.onCloseBeam,
    this.onRaise,
  });

  final DjedV2Event event;
  final DjedSittingFixture sitting;
  final DjedDayVisualFixture fixture;
  final List<DjedSupportFixture> supports;
  final VoidCallback onBack;
  final ValueChanged<String>? onMoveChanged;
  final VoidCallback? onDoToday;
  final VoidCallback? onPutOnCalendar;
  final ValueChanged<DjedResultVisualState>? onResultSelected;
  final ValueChanged<String>? onResultNoteChanged;
  final ValueChanged<String>? onSmallerMoveChanged;
  final VoidCallback? onCloseBeam;
  final VoidCallback? onRaise;

  @override
  Widget build(BuildContext context) {
    final focusStateLabel = _detailFocusStateLabel(fixture, supports);
    return DecoratedBox(
      key: const ValueKey<String>('djed-detail-sitting-presentation'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0D0B08),
            Color(0xFF080805),
            Color(0xFF060604),
          ],
          stops: <double>[0, .42, 1],
        ),
      ),
      child: ListView(
        key: const PageStorageKey<String>('djed-detail-sitting-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 9, 20, 34),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          Text(
            'SITTING ${sitting.number.toString().padLeft(2, '0')} · '
            'DAY ${event.flowDay} · ${event.phase}',
            key: const ValueKey<String>('djed-detail-sitting-kicker'),
            style: const TextStyle(
              color: Color(0xFF8A5A28),
              fontFamily: 'GentiumPlus',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 1.55,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sitting.title,
            key: const ValueKey<String>('djed-detail-sitting-title'),
            style: const TextStyle(
              color: Color(0xFFF5B963),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 29,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${sitting.timeLabel} · ${sitting.durationLabel}',
            style: const TextStyle(
              color: Color(0xFF77736D),
              fontFamily: 'GentiumPlus',
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _DjedTodayContext(contextText: event.context),
          const SizedBox(height: 13),
          SizedBox(
            height: 214,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stageWidth = constraints.maxWidth + 10;
                return OverflowBox(
                  alignment: Alignment.center,
                  minWidth: stageWidth,
                  maxWidth: stageWidth,
                  minHeight: 214,
                  maxHeight: 214,
                  child: SizedBox(
                    key: const ValueKey<String>('djed-detail-sitting-stage'),
                    width: stageWidth,
                    height: 214,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: DjedSittingStage(
                        fixture: fixture,
                        supports: supports,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          DjedSittingActionContent(
            fixture: fixture,
            focusStateLabel: focusStateLabel,
            onMoveChanged: onMoveChanged,
            onDoToday: onDoToday,
            onPutOnCalendar: onPutOnCalendar,
            onResultSelected: onResultSelected,
            onResultNoteChanged: onResultNoteChanged,
            onSmallerMoveChanged: onSmallerMoveChanged,
            onCloseBeam: onCloseBeam,
            onRaise: onRaise,
            disabledActionColor: const Color(0xFF8A8378),
          ),
          const SizedBox(height: 17),
          _DjedDetailSourceDisclosure(source: event.source),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey<String>('djed-detail-back-to-djed'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5B963),
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
              onPressed: onBack,
              child: const Text('Back to the Djed'),
            ),
          ),
        ],
      ),
    );
  }
}

String? _detailFocusStateLabel(
  DjedDayVisualFixture fixture,
  List<DjedSupportFixture> supports,
) {
  if (fixture.sittingNumber == 1) return null;
  final index = fixture.supportSlot - 1;
  if (index < 0 || index >= supports.length) return 'NEUTRAL';
  final support = supports[index];
  if (support.released) return 'RELEASED';
  return switch (support.condition) {
    DjedSupportCondition.holding => 'HOLDING',
    DjedSupportCondition.underPressure => 'UNDER PRESSURE',
    DjedSupportCondition.wobbling => 'WOBBLING',
    DjedSupportCondition.unassessed => 'NEUTRAL',
  };
}

class _DjedTodayContext extends StatelessWidget {
  const _DjedTodayContext({required this.contextText});

  final String contextText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 0, 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x6BE0873C), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'TODAY',
            style: TextStyle(
              color: Color(0xFF9A8039),
              fontFamily: 'GentiumPlus',
              fontSize: 8,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
              height: 1,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            contextText,
            style: const TextStyle(
              color: Color(0xFFBEB7AB),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 14.5,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedDetailSourceDisclosure extends StatefulWidget {
  const _DjedDetailSourceDisclosure({required this.source});

  final String source;

  @override
  State<_DjedDetailSourceDisclosure> createState() =>
      _DjedDetailSourceDisclosureState();
}

class _DjedDetailSourceDisclosureState
    extends State<_DjedDetailSourceDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2C2016))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            expanded: _expanded,
            child: TextButton(
              key: const ValueKey<String>('djed-detail-source-disclosure'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8A8378),
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.centerLeft,
                textStyle: const TextStyle(
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1,
                ),
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Why this belongs at the Djed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_expanded ? '\u2212' : '+'),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              key: const ValueKey<String>('djed-detail-source-body'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.source,
                style: const TextStyle(
                  color: Color(0xFF74766F),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
