import 'package:flutter/material.dart';

import '../../maat_flow_response_draft_store.dart';
import '../../maat_flow_response_models.dart';
import '../../presentation/instrument_event_presentation_frame.dart';
import '../../the_offering_table_flow.dart';
import 'offering_table_day_components.dart';
import 'offering_table_presentation_copy.dart';

class OfferingTableDayPresentation extends StatefulWidget {
  const OfferingTableDayPresentation({
    super.key,
    required this.day,
    required this.localDate,
    required this.startMinute,
    required this.initialNeed,
    required this.lens,
    required this.completionPanel,
    this.persistResponses = true,
  });

  final OfferingTableDay day;
  final DateTime localDate;
  final int startMinute;
  final String initialNeed;
  final OfferingTableLens lens;
  final Widget completionPanel;
  final bool persistResponses;

  @override
  State<OfferingTableDayPresentation> createState() =>
      _OfferingTableDayPresentationState();
}

class _OfferingTableDayPresentationState
    extends State<OfferingTableDayPresentation> {
  static const _velvet = Color(0xFF080604);
  static const _bone = Color(0xFFE8DED0);
  static const _gold = Color(0xFFD4AE43);
  static const _goldDim = Color(0xFF8A7030);
  static const _silverLow = Color(0xFF6F685F);
  static const _separator = Color(0xFF2A2115);
  static const _water = Color(0xFF83BEB9);
  static const _display = 'CormorantGaramond';
  static const _ui = 'GentiumPlus';

  double _placement = 0;
  late Map<String, bool> _checkedSteps;

  OfferingTablePracticePresentation get _presentation =>
      offeringTablePracticePresentation(widget.day);

  String _stepId(int index) =>
      'offering-table-day-${widget.day.dayNumber.toString().padLeft(2, '0')}-step-${index + 1}';

  @override
  void initState() {
    super.initState();
    final drafts = widget.persistResponses
        ? kMaatFlowResponseDraftStore.valuesForFlow(kOfferingTableFlowKey)
        : const <String, MaatFlowResponseValue>{};
    _checkedSteps = <String, bool>{
      for (var index = 0; index < _presentation.steps.length; index++)
        _stepId(index): drafts[_stepId(index)]?.checked == true,
    };
  }

  void _selectPlacement(double value) {
    setState(() => _placement = value.clamp(0.0, 1.0));
  }

  void _toggleStep(int index) {
    final id = _stepId(index);
    final checked = !(_checkedSteps[id] ?? false);
    setState(() => _checkedSteps[id] = checked);
    if (!widget.persistResponses) return;
    kMaatFlowResponseDraftStore.rememberValue(
      flowKey: kOfferingTableFlowKey,
      value: MaatFlowResponseValue.checkbox(specId: id, checked: checked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InstrumentEventPresentationFrame(
      key: const ValueKey<String>('offering-table-day-presentation'),
      decoration: const BoxDecoration(color: _velvet),
      fixedHeroHeight: 238,
      instrument: _buildCupHero(),
      instrumentFooter: _buildPlacementControl(),
      inputBuilder: (context, _, instrumentHeight) => Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: InstrumentEventPresentationFrame.footerHeight,
          child: _buildCupInput(),
        ),
      ),
      body: _buildBody(),
      bodyScrollKey: const ValueKey<String>('offering-table-presentation-body'),
      lowerSheetKey: const ValueKey<String>(
        'offering-table-static-lower-sheet',
      ),
    );
  }

  Widget _buildCupHero() {
    final stage = offeringTableStage(widget.day.dayNumber);
    final stageDay = ((widget.day.dayNumber - 1) % 10) + 1;
    final need = widget.initialNeed.trim().isEmpty
        ? 'What matters to me.'
        : widget.initialNeed.trim();
    return Stack(
      key: const ValueKey<String>('offering-table-cup-hero'),
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _OfferingCupInstrumentPainter(
              placement: _placement,
              foreground: false,
            ),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final surfaceY = constraints.maxHeight * (168 / 238);
              final wordTop =
                  constraints.maxHeight * (96 / 238) +
                  (_placement * constraints.maxHeight * (70 / 238));
              final scale = 1 - (_placement * 0.18);
              final fontSize = need.length > 46
                  ? 14.5
                  : need.length > 28
                  ? 16.0
                  : 17.5;
              Widget word({
                required Key key,
                required Color color,
                required bool submerged,
              }) {
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      left: (constraints.maxWidth - 176) / 2,
                      top: wordTop,
                      width: 176,
                      child: Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.diagonal3Values(
                          submerged ? scale * 1.04 : scale,
                          scale,
                          1,
                        ),
                        child: Text(
                          need,
                          key: key,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: color,
                            fontFamily: _display,
                            fontSize: fontSize,
                            fontStyle: FontStyle.italic,
                            height: need.length > 46 ? 1.24 : 1.3,
                            letterSpacing: 0.35,
                            shadows: submerged
                                ? const <Shadow>[
                                    Shadow(color: _water, blurRadius: 6),
                                  ]
                                : const <Shadow>[
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 12,
                                    ),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipPath(
                    clipper: _OfferingWaterEllipseClipper(surfaceY),
                    child: ClipRect(
                      clipper: _OfferingBelowWaterClipper(surfaceY),
                      child: word(
                        key: const ValueKey<String>(
                          'offering-table-intention-water',
                        ),
                        color: const Color(0xFFA9DCD5),
                        submerged: true,
                      ),
                    ),
                  ),
                  ClipRect(
                    clipper: _OfferingAboveWaterClipper(surfaceY),
                    child: word(
                      key: const ValueKey<String>(
                        'offering-table-intention-air',
                      ),
                      color: const Color(0xFFE8B27C),
                      submerged: false,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _OfferingCupInstrumentPainter(
              placement: _placement,
              foreground: true,
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 20,
          right: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metaWidth = constraints.maxWidth < 330 ? 96.0 : 112.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Text(
                              '✦',
                              style: TextStyle(
                                color: _gold,
                                fontFamily: _ui,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'THE OFFERING TABLE',
                                style: TextStyle(
                                  color: _gold,
                                  fontFamily: _ui,
                                  fontSize: 10.5,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.day.title,
                          key: const ValueKey<String>(
                            'offering-table-event-title',
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: _display,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                            height: 1.04,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black87, blurRadius: 22),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: metaWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '${_dateLabel(widget.localDate)}\n',
                                style: const TextStyle(
                                  color: Color(0xFFB7906B),
                                  letterSpacing: 1.05,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${stage.name.toUpperCase()} · DAY $stageDay',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: _silverLow,
                            fontFamily: _ui,
                            fontSize: 9.5,
                            height: 1.35,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _formatMinute(widget.startMinute),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF9C8161),
                            fontFamily: _display,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black87, blurRadius: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCupInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) {
          _selectPlacement(
            ((position.dx - 42) / (constraints.maxWidth - 84)).clamp(0.0, 1.0),
          );
        }

        return Semantics(
          label: 'Offering Table intention placement instrument',
          value: '${(_placement * 100).round()} percent placed',
          increasedValue:
              '${((_placement + 0.02).clamp(0.0, 1.0) * 100).round()} percent placed',
          decreasedValue:
              '${((_placement - 0.02).clamp(0.0, 1.0) * 100).round()} percent placed',
          slider: true,
          onIncrease: () =>
              _selectPlacement((_placement + 0.02).clamp(0.0, 1.0)),
          onDecrease: () =>
              _selectPlacement((_placement - 0.02).clamp(0.0, 1.0)),
          child: GestureDetector(
            key: const ValueKey<String>('offering-table-intention-drag'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => update(details.localPosition),
            onHorizontalDragDown: (details) => update(details.localPosition),
            onHorizontalDragUpdate: (details) => update(details.localPosition),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  Widget _buildPlacementControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(
            height: 28,
            child: Text(
              'Place your intention in the water',
              key: ValueKey<String>('offering-table-placement-label'),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: Color(0xFFE8B27C),
                fontFamily: _display,
                fontSize: 23,
                fontStyle: FontStyle.italic,
                shadows: <Shadow>[
                  Shadow(color: Color(0x55E8B27C), blurRadius: 10),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const inset = 22.0;
                const thumbSize = 22.0;
                final trackWidth = (constraints.maxWidth - inset * 2).clamp(
                  1.0,
                  double.infinity,
                );
                final thumbCenter = inset + trackWidth * _placement;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Positioned(
                      left: inset,
                      right: inset,
                      top: 16,
                      child: SizedBox(
                        height: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF3A2B1D),
                            borderRadius: BorderRadius.all(Radius.circular(99)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: inset,
                      top: 16,
                      width: trackWidth * _placement,
                      child: const SizedBox(
                        height: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFE8B27C),
                            borderRadius: BorderRadius.all(Radius.circular(99)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: thumbCenter - thumbSize / 2,
                      top: 6,
                      child: Container(
                        key: const ValueKey<String>(
                          'offering-table-placement-thumb',
                        ),
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.25, -0.35),
                            colors: <Color>[
                              Color(0xFFC58A5C),
                              Color(0xFF7E4C2E),
                            ],
                          ),
                          border: Border.all(color: const Color(0xFFF0C99B)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Color(0x33E8B27C), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final stage = offeringTableStage(widget.day.dayNumber);
    final stageDay = ((widget.day.dayNumber - 1) % 10) + 1;
    return Container(
      key: const ValueKey<String>('offering-table-foreground-layer'),
      padding: const EdgeInsets.only(bottom: 22),
      decoration: const BoxDecoration(
        color: _velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0x3AD4AE43))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${stage.name.toUpperCase()} · DAY $stageDay',
              style: const TextStyle(
                color: _goldDim,
                fontFamily: _ui,
                fontSize: 10.5,
                letterSpacing: 2.7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _stageStatement(widget.day.dayNumber),
              style: const TextStyle(
                color: _bone,
                fontFamily: _display,
                fontSize: 21,
                height: 1.3,
              ),
            ),
            Container(
              key: const ValueKey<String>('offering-table-named-need'),
              margin: const EdgeInsets.only(top: 17),
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE8B27C).withValues(alpha: 0.24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[
                    const Color(0xFFC08A52).withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.016),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'THE NEED YOU NAMED',
                    style: TextStyle(
                      color: Color(0xFFE8B27C),
                      fontFamily: _ui,
                      fontSize: 10,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(
                            0xFFE8B27C,
                          ).withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                    child: Text(
                      widget.initialNeed.trim().isEmpty
                          ? 'No need was named when this table was carried.'
                          : widget.initialNeed.trim(),
                      style: const TextStyle(
                        color: Color(0xFFE8B27C),
                        fontFamily: _display,
                        fontSize: 19,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 300;
                final gap = narrow ? 6.0 : 11.0;
                return Row(
                  children: <Widget>[
                    Text(
                      "TODAY'S RITUAL",
                      style: TextStyle(
                        color: _goldDim,
                        fontFamily: _ui,
                        fontSize: 10.5,
                        letterSpacing: narrow ? 1.7 : 2.7,
                      ),
                    ),
                    SizedBox(width: gap),
                    const Expanded(
                      child: Divider(color: _separator, height: 1),
                    ),
                    SizedBox(width: gap),
                    Text(
                      '${_presentation.steps.length} ${_presentation.steps.length == 1 ? 'step' : 'steps'}',
                      style: const TextStyle(
                        color: _silverLow,
                        fontFamily: _ui,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.022),
                border: Border.all(color: _separator),
                borderRadius: BorderRadius.circular(15),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: <Widget>[
                  for (
                    var index = 0;
                    index < _presentation.steps.length;
                    index++
                  )
                    _OfferingChecklistStep(
                      key: ValueKey<String>(_stepId(index)),
                      number: index + 1,
                      text: _presentation.steps[index],
                      checked: _checkedSteps[_stepId(index)] ?? false,
                      showTopBorder: index > 0,
                      onTap: () => _toggleStep(index),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OfferingTableContextDisclosure(
              day: widget.day,
              lens: widget.lens,
              why: _presentation.why,
            ),
            const SizedBox(height: 24),
            const Row(
              children: <Widget>[
                Text(
                  'COMPLETION',
                  style: TextStyle(
                    color: _goldDim,
                    fontFamily: _ui,
                    fontSize: 10.5,
                    letterSpacing: 2.7,
                  ),
                ),
                SizedBox(width: 11),
                Expanded(child: Divider(color: _separator, height: 1)),
              ],
            ),
            const SizedBox(height: 14),
            widget.completionPanel,
          ],
        ),
      ),
    );
  }

  String _stageStatement(int dayNumber) {
    if (dayNumber <= 10) return 'Begin with what you chose for yourself.';
    if (dayNumber <= 20) return 'Provide for what depends on you.';
    return 'Return provision to the larger flow.';
  }

  String _dateLabel(DateTime date) {
    const weekdays = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1]} · ${months[date.month - 1]} ${date.day}';
  }

  String _formatMinute(int minuteOfDay) {
    final hour24 = minuteOfDay ~/ 60;
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
  }
}

class _OfferingChecklistStep extends StatelessWidget {
  const _OfferingChecklistStep({
    super.key,
    required this.number,
    required this.text,
    required this.checked,
    required this.showTopBorder,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool checked;
  final bool showTopBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: checked,
      label: 'Step $number: $text',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            border: showTopBorder
                ? const Border(
                    top: BorderSide(
                      color: _OfferingTableDayPresentationState._separator,
                    ),
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checked
                      ? const Color(0xFFC08A52).withValues(alpha: 0.13)
                      : const Color(0xFFC08A52).withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: checked
                        ? const Color(0xFFE8B27C)
                        : const Color(0xFFE8B27C).withValues(alpha: 0.42),
                  ),
                ),
                child: checked
                    ? const Text(
                        '✓',
                        style: TextStyle(
                          color: Color(0xFFE8B27C),
                          fontFamily: _OfferingTableDayPresentationState._ui,
                          fontSize: 14,
                          height: 1,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: checked
                        ? const Color(0xFF9D9488)
                        : _OfferingTableDayPresentationState._bone,
                    fontFamily: _OfferingTableDayPresentationState._display,
                    fontSize: 17,
                    height: 1.25,
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

class _OfferingCupInstrumentPainter extends CustomPainter {
  const _OfferingCupInstrumentPainter({
    required this.placement,
    required this.foreground,
  });

  final double placement;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 370, size.height / 238);
    const field = Rect.fromLTWH(0, 0, 370, 238);
    const rim = Rect.fromLTWH(119, 154, 132, 28);

    if (foreground) {
      final glowOpacity = 0.10 + placement * 0.55;
      canvas.drawOval(
        const Rect.fromLTWH(99, 138, 172, 60),
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[Color(0x8CBFE3DC), Color(0x007FB4B0)],
          ).createShader(const Rect.fromLTWH(99, 138, 172, 60))
          ..color = Colors.white.withValues(alpha: glowOpacity),
      );
      canvas.drawOval(
        const Rect.fromLTWH(121, 156, 128, 26),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x529FCFC9), Color(0x473E706C)],
          ).createShader(const Rect.fromLTWH(121, 156, 128, 26)),
      );
      for (var index = 0; index < 3; index++) {
        final phase = (placement * 1.6 + index * 0.33) % 1;
        final radiusX = 12 + phase * 54;
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(185, 169),
            width: radiusX * 2,
            height: radiusX * 0.41,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFFCFEDE7).withValues(
              alpha: (1 - phase) * 0.30 * (placement * 3).clamp(0.0, 1.0),
            ),
        );
      }
      canvas.drawOval(
        const Rect.fromLTWH(131, 158, 108, 16),
        Paint()..color = const Color(0x1FD6F0EA),
      );
      final meniscus = Path()
        ..moveTo(122, 167)
        ..quadraticBezierTo(185, 152, 248, 167);
      canvas.drawPath(
        meniscus,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0x73F0C9A6),
      );
      canvas.drawOval(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFE0AA80),
      );
      final baseHighlight = Path()
        ..moveTo(127, 212)
        ..quadraticBezierTo(185, 230, 243, 212);
      canvas.drawPath(
        baseHighlight,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0x2EE3A477),
      );
      canvas.restore();
      return;
    }

    canvas.drawRect(
      field,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.88),
          radius: 1.12,
          colors: <Color>[
            Color(0xFF3A2415),
            Color(0xFF1A110A),
            Color(0xFF080604),
          ],
          stops: <double>[0, 0.48, 1],
        ).createShader(field),
    );
    canvas.drawOval(
      const Rect.fromLTWH(89, 220, 192, 24),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final body = Path()
      ..moveTo(111, 166)
      ..quadraticBezierTo(185, 186, 259, 166)
      ..lineTo(245, 216)
      ..quadraticBezierTo(185, 234, 125, 216)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF8C5638),
            Color(0xFF63391F),
            Color(0xFF402316),
            Color(0xFF2A1610),
          ],
          stops: <double>[0, 0.42, 0.78, 1],
        ).createShader(const Rect.fromLTWH(111, 166, 148, 68)),
    );
    final backEdge = Path()
      ..moveTo(111, 166)
      ..quadraticBezierTo(185, 186, 259, 166);
    canvas.drawPath(
      backEdge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x73D89C6E),
    );
    canvas.drawOval(rim, Paint()..color = const Color(0xFF160E0A));
    canvas.drawOval(
      const Rect.fromLTWH(121, 156, 128, 26),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF2A5450), Color(0xFF0E2422)],
        ).createShader(const Rect.fromLTWH(121, 156, 128, 26))
        ..color = Colors.white.withValues(alpha: 0.75 + placement * 0.25),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OfferingCupInstrumentPainter oldDelegate) =>
      oldDelegate.placement != placement ||
      oldDelegate.foreground != foreground;
}

class _OfferingAboveWaterClipper extends CustomClipper<Rect> {
  const _OfferingAboveWaterClipper(this.waterline);

  final double waterline;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, waterline);

  @override
  bool shouldReclip(covariant _OfferingAboveWaterClipper oldClipper) =>
      oldClipper.waterline != waterline;
}

class _OfferingBelowWaterClipper extends CustomClipper<Rect> {
  const _OfferingBelowWaterClipper(this.waterline);

  final double waterline;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, waterline, size.width, size.height - waterline);

  @override
  bool shouldReclip(covariant _OfferingBelowWaterClipper oldClipper) =>
      oldClipper.waterline != waterline;
}

class _OfferingWaterEllipseClipper extends CustomClipper<Path> {
  const _OfferingWaterEllipseClipper(this.waterline);

  final double waterline;

  @override
  Path getClip(Size size) => Path()
    ..addOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, waterline),
        width: size.width * (128 / 370),
        height: size.height * (108 / 238),
      ),
    );

  @override
  bool shouldReclip(covariant _OfferingWaterEllipseClipper oldClipper) =>
      oldClipper.waterline != waterline;
}
