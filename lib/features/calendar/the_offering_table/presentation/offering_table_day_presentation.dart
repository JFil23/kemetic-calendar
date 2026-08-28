import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../maat_flow_response_draft_store.dart';
import '../../maat_flow_response_models.dart';
import '../../the_offering_table_flow.dart';
import 'offering_table_day_sheet.dart';
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
  });

  final OfferingTableDay day;
  final DateTime localDate;
  final int startMinute;
  final String initialNeed;
  final OfferingTableLens lens;
  final Widget completionPanel;

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
  static const _silverMid = Color(0xFF9E968B);
  static const _silverLow = Color(0xFF6F685F);
  static const _separator = Color(0xFF2A2115);
  static const _water = Color(0xFF83BEB9);
  static const _display = 'CormorantGaramond';
  static const _ui = 'GentiumPlus';

  double _placement = 0.42;
  late Map<String, bool> _checkedSteps;

  OfferingTablePracticePresentation get _presentation =>
      offeringTablePracticePresentation(widget.day);

  String _stepId(int index) =>
      'offering-table-day-${widget.day.dayNumber.toString().padLeft(2, '0')}-step-${index + 1}';

  @override
  void initState() {
    super.initState();
    final drafts = kMaatFlowResponseDraftStore.valuesForFlow(
      kOfferingTableFlowKey,
    );
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
    kMaatFlowResponseDraftStore.rememberValue(
      flowKey: kOfferingTableFlowKey,
      value: MaatFlowResponseValue.checkbox(specId: id, checked: checked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 620.0;
        final heroHeight = math.min(
          282.0,
          math.max(238.0, boundedHeight * 0.46),
        );
        final instrumentHeight = heroHeight + 76;
        return DecoratedBox(
          key: const ValueKey<String>('offering-table-day-presentation'),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[0, 0.38, 0.76],
              colors: <Color>[Color(0xFF211309), Color(0xFF140D07), _velvet],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: instrumentHeight,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: heroHeight,
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: RepaintBoundary(child: _buildCupHero()),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 76,
                      child: Column(
                        children: <Widget>[
                          Expanded(child: _buildFinder()),
                          _buildDragInstruction(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              CustomScrollView(
                key: const ValueKey<String>('offering-table-presentation-body'),
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: instrumentHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: heroHeight,
                          child: _buildCupInput(),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      key: const ValueKey<String>(
                        'offering-table-static-lower-sheet',
                      ),
                      child: _buildBody(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCupHero() {
    final stage = offeringTableStage(widget.day.dayNumber);
    final stageDay = ((widget.day.dayNumber - 1) % 10) + 1;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.2, 0.72),
              radius: 0.74,
              colors: <Color>[
                Color(0x4FD4AE43),
                Color(0x1A9A603D),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _OfferingCupInstrumentPainter(placement: _placement),
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
                            Icon(
                              Icons.water_drop_outlined,
                              color: _gold,
                              size: 13,
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'THE OFFERING TABLE',
                                style: TextStyle(
                                  color: _gold,
                                  fontFamily: _ui,
                                  fontSize: 10.5,
                                  letterSpacing: 2.2,
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
                                  color: Color(0xFFE0B777),
                                  letterSpacing: 1.05,
                                ),
                              ),
                              TextSpan(text: '${stage.name}\n'),
                              TextSpan(text: 'Day $stageDay of 10'),
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
                            color: _water,
                            fontFamily: _display,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            shadows: <Shadow>[
                              Shadow(color: _water, blurRadius: 10),
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
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const wordHeight = 54.0;
              final waterline = constraints.maxHeight * 0.47;
              final wordTop =
                  waterline - 58 + (51 * _placement.clamp(0.0, 1.0));
              final cutoff = (waterline - wordTop).clamp(0.0, wordHeight);
              final text = widget.initialNeed.trim().isEmpty
                  ? 'Name what needs feeding.'
                  : widget.initialNeed.trim();
              const style = TextStyle(
                fontFamily: _display,
                fontSize: 18,
                fontStyle: FontStyle.italic,
                height: 1.12,
              );
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned(
                    left: 54,
                    right: 54,
                    top: wordTop,
                    height: wordHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ClipRect(
                          clipper: _OfferingIntentionUpperClipper(cutoff),
                          child: Text(
                            text,
                            key: const ValueKey<String>(
                              'offering-table-intention-air',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.fade,
                            style: style.copyWith(
                              color: _bone,
                              shadows: const <Shadow>[
                                Shadow(color: Colors.black87, blurRadius: 12),
                              ],
                            ),
                          ),
                        ),
                        ClipRect(
                          clipper: _OfferingIntentionLowerClipper(cutoff),
                          child: Transform.translate(
                            offset: const Offset(0, 1.2),
                            child: Text(
                              text,
                              key: const ValueKey<String>(
                                'offering-table-intention-water',
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.fade,
                              style: style.copyWith(
                                color: const Color(0xFFBFE3DC),
                                shadows: const <Shadow>[
                                  Shadow(color: _water, blurRadius: 9),
                                ],
                              ),
                            ),
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

  Widget _buildFinder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          const Flexible(
            child: Text(
              'Place your intention in the water.',
              key: ValueKey<String>('offering-table-placement-label'),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: _water,
                fontFamily: _display,
                fontSize: 21,
                fontStyle: FontStyle.italic,
                shadows: <Shadow>[Shadow(color: _water, blurRadius: 10)],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(_placement * 100).round()}%',
            key: const ValueKey<String>('offering-table-placement-value'),
            style: const TextStyle(
              color: _silverMid,
              fontFamily: _ui,
              fontSize: 12.5,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragInstruction() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Drag across the water to place it where it feels true.',
          style: TextStyle(
            color: _silverLow,
            fontFamily: _ui,
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            height: 1.2,
          ),
        ),
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
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _water.withValues(alpha: 0.28)),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: <Color>[
                    const Color(0xFF9A603D).withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.018),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'THE NEED YOU NAMED',
                    style: TextStyle(
                      color: _water,
                      fontFamily: _ui,
                      fontSize: 10,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.initialNeed.trim().isEmpty
                        ? 'No need was named when this table was carried.'
                        : '“${widget.initialNeed.trim()}”',
                    style: const TextStyle(
                      color: _bone,
                      fontFamily: _display,
                      fontSize: 21,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      height: 1.28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                const Text(
                  "TODAY'S RITUAL",
                  style: TextStyle(
                    color: _gold,
                    fontFamily: _ui,
                    fontSize: 10.5,
                    letterSpacing: 2.7,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(child: Divider(color: _separator, height: 1)),
                const SizedBox(width: 11),
                Text(
                  '${_presentation.steps.length} ${_presentation.steps.length == 1 ? 'step' : 'steps'}',
                  style: const TextStyle(
                    color: _silverLow,
                    fontFamily: _ui,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < _presentation.steps.length; index++)
              _OfferingChecklistStep(
                key: ValueKey<String>(_stepId(index)),
                number: index + 1,
                text: _presentation.steps[index],
                checked: _checkedSteps[_stepId(index)] ?? false,
                onTap: () => _toggleStep(index),
              ),
            const SizedBox(height: 16),
            OfferingTableContextDisclosure(
              day: widget.day,
              lens: widget.lens,
              why: _presentation.why,
            ),
            const SizedBox(height: 18),
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
    required this.onTap,
  });

  final int number;
  final String text;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: checked,
      label: 'Step $number: $text',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checked
                      ? _OfferingTableDayPresentationState._gold
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _OfferingTableDayPresentationState._goldDim,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF120C05),
                      )
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: _OfferingTableDayPresentationState._gold,
                          fontFamily: _OfferingTableDayPresentationState._ui,
                          fontSize: 11,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: checked
                        ? _OfferingTableDayPresentationState._silverLow
                        : _OfferingTableDayPresentationState._silverMid,
                    fontFamily: _OfferingTableDayPresentationState._ui,
                    fontSize: 14,
                    height: 1.4,
                    decoration: checked ? TextDecoration.lineThrough : null,
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
  const _OfferingCupInstrumentPainter({required this.placement});

  final double placement;

  @override
  void paint(Canvas canvas, Size size) {
    final cupWidth = math.min(size.width * 0.56, 210.0);
    final cupHeight = math.min(size.height * 0.48, 126.0);
    final center = Offset(size.width / 2, size.height * 0.64);
    final body = Path()
      ..moveTo(center.dx - cupWidth * 0.46, center.dy - cupHeight * 0.42)
      ..quadraticBezierTo(
        center.dx,
        center.dy - cupHeight * 0.2,
        center.dx + cupWidth * 0.46,
        center.dy - cupHeight * 0.42,
      )
      ..lineTo(center.dx + cupWidth * 0.34, center.dy + cupHeight * 0.48)
      ..quadraticBezierTo(
        center.dx,
        center.dy + cupHeight * 0.66,
        center.dx - cupWidth * 0.34,
        center.dy + cupHeight * 0.48,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFC47B4E),
            Color(0xFF713B24),
            Color(0xFF2C150B),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFE1B07D),
    );

    final rim = Rect.fromCenter(
      center: center.translate(0, -cupHeight * 0.38),
      width: cupWidth * 0.92,
      height: cupHeight * 0.25,
    );
    canvas.drawOval(rim, Paint()..color = const Color(0xFF251109));
    final water = Rect.fromCenter(
      center: rim.center.translate((placement - 0.5) * cupWidth * 0.08, 1),
      width: rim.width * (0.72 + placement * 0.13),
      height: rim.height * (0.48 + placement * 0.12),
    );
    canvas.drawOval(
      water,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFFB8E0D8), Color(0xFF5A9E9A)],
        ).createShader(water),
    );
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFE1B07D),
    );

    final trackY = center.dy + cupHeight * 0.72;
    final left = 42.0;
    final right = size.width - 42.0;
    canvas.drawLine(
      Offset(left, trackY),
      Offset(right, trackY),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x5583BEB9),
    );
    final thumbX = left + (right - left) * placement;
    canvas.drawCircle(
      Offset(thumbX, trackY),
      6,
      Paint()
        ..color = const Color(0xFF83BEB9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      Offset(thumbX, trackY),
      3.5,
      Paint()..color = const Color(0xFFD9F0EB),
    );
  }

  @override
  bool shouldRepaint(covariant _OfferingCupInstrumentPainter oldDelegate) =>
      oldDelegate.placement != placement;
}

class _OfferingIntentionUpperClipper extends CustomClipper<Rect> {
  const _OfferingIntentionUpperClipper(this.cutoff);

  final double cutoff;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, cutoff);

  @override
  bool shouldReclip(covariant _OfferingIntentionUpperClipper oldClipper) =>
      oldClipper.cutoff != cutoff;
}

class _OfferingIntentionLowerClipper extends CustomClipper<Rect> {
  const _OfferingIntentionLowerClipper(this.cutoff);

  final double cutoff;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, cutoff, size.width, size.height - cutoff);

  @override
  bool shouldReclip(covariant _OfferingIntentionLowerClipper oldClipper) =>
      oldClipper.cutoff != cutoff;
}
