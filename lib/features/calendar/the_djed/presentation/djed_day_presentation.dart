import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';

enum DjedPracticeStageVisual {
  orientation,
  makeMove,
  putOnCalendar,
  readResult,
  blocker,
  smallerRetry,
  finalRaising,
}

enum DjedResultVisualState { none, helped, noChange, notDone }

enum DjedCompletionVisualState { none, observed, partly, skipped }

@immutable
class DjedDayVisualFixture {
  const DjedDayVisualFixture({
    required this.sittingNumber,
    required this.stage,
    required this.supportSlot,
    required this.supportName,
    this.move = '',
    this.result = DjedResultVisualState.none,
    this.completion = DjedCompletionVisualState.none,
    this.resultNote = '',
    this.smallerMove = '',
    this.raised = false,
    this.raisingActive = false,
    this.raisingSecondsRemaining = 30,
  });

  final int sittingNumber;
  final DjedPracticeStageVisual stage;
  final int supportSlot;
  final String supportName;
  final String move;
  final DjedResultVisualState result;
  final DjedCompletionVisualState completion;
  final String resultNote;
  final String smallerMove;
  final bool raised;
  final bool raisingActive;
  final int raisingSecondsRemaining;
}

const DjedDayVisualFixture kDjedDayVisualFixture = DjedDayVisualFixture(
  sittingNumber: 4,
  stage: DjedPracticeStageVisual.makeMove,
  supportSlot: 2,
  supportName: 'the weekly call with my sister',
);

abstract final class DjedDayTokens {
  static const Color page = Color(0xFF050403);
  static const Color lower = Color(0xFF090705);
  static const Color bone = Color(0xFFF3EADF);
  static const Color silver = Color(0xFFA0968A);
  static const Color low = Color(0xFF6E655B);
  static const Color gold = Color(0xFFE0873C);
  static const Color goldBright = Color(0xFFF5B963);
  static const Color separator = Color(0xFF2C2016);
}

/// Djed v2 fixture presentation on the existing layered Day View frame.
class DjedDayPresentation extends StatelessWidget {
  const DjedDayPresentation({
    super.key,
    this.fixture = kDjedDayVisualFixture,
    this.supports = kDjedSupportFixtures,
    this.onStageAction,
    this.onMoveChanged,
    this.onDoToday,
    this.onPutOnCalendar,
    this.onResultSelected,
    this.onResultNoteChanged,
    this.onSmallerMoveChanged,
    this.onCloseBeam,
    this.onRaise,
    this.onCompletionSelected,
  });

  final DjedDayVisualFixture fixture;
  final List<DjedSupportFixture> supports;
  final VoidCallback? onStageAction;
  final ValueChanged<String>? onMoveChanged;
  final VoidCallback? onDoToday;
  final VoidCallback? onPutOnCalendar;
  final ValueChanged<DjedResultVisualState>? onResultSelected;
  final ValueChanged<String>? onResultNoteChanged;
  final ValueChanged<String>? onSmallerMoveChanged;
  final VoidCallback? onCloseBeam;
  final VoidCallback? onRaise;
  final ValueChanged<DjedCompletionVisualState>? onCompletionSelected;

  @override
  Widget build(BuildContext context) {
    return InstrumentEventPresentationFrame(
      key: const ValueKey<String>('djed-day-presentation'),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.55),
          radius: 1.1,
          colors: <Color>[
            Color(0xFF3A1A0B),
            Color(0xFF150B06),
            DjedDayTokens.page,
          ],
        ),
      ),
      initialLowerSheetPeek: 30,
      instrumentFooterHeight: 0,
      instrument: _DjedInstrument(fixture: fixture, supports: supports),
      instrumentFooter: const SizedBox.shrink(),
      inputBuilder: (_, _, _) => const SizedBox.shrink(),
      body: _DjedPracticeSheet(
        fixture: fixture,
        onStageAction: onStageAction,
        onMoveChanged: onMoveChanged,
        onDoToday: onDoToday,
        onPutOnCalendar: onPutOnCalendar,
        onResultSelected: onResultSelected,
        onResultNoteChanged: onResultNoteChanged,
        onSmallerMoveChanged: onSmallerMoveChanged,
        onCloseBeam: onCloseBeam,
        onRaise: onRaise,
        onCompletionSelected: onCompletionSelected,
      ),
      bodyScrollKey: const ValueKey<String>('djed-presentation-body'),
      lowerSheetKey: const ValueKey<String>('djed-practice-sheet'),
    );
  }
}

class _DjedInstrument extends StatelessWidget {
  const _DjedInstrument({required this.fixture, required this.supports});

  final DjedDayVisualFixture fixture;
  final List<DjedSupportFixture> supports;

  @override
  Widget build(BuildContext context) {
    final sitting =
        kDjedSittingFixtures[(fixture.sittingNumber - 1).clamp(
          0,
          kDjedSittingFixtures.length - 1,
        )];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF120C07), Color(0xFF0C0906)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SITTING ${fixture.sittingNumber.toString().padLeft(2, '0')} · DAY ${sitting.flowDay} · ${_sheetPhase(fixture.sittingNumber, sitting.phase)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8A7030),
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
            style: const TextStyle(
              color: Color(0xFFE7C66C),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 29,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${sitting.timeLabel} · ${sitting.durationLabel}',
            style: TextStyle(
              color: Color(0xFF77736D),
              fontFamily: 'GentiumPlus',
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 74),
            padding: const EdgeInsets.fromLTRB(13, 10, 0, 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0x7AD4AE43), width: 2),
              ),
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
                    height: 1,
                    letterSpacing: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Text(
                    _sheetContext(fixture.sittingNumber),
                    maxLines: 3,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      color: Color(0xFFBEB7AB),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 14.5,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Transform.translate(
              offset: const Offset(-5, 0),
              child: SizedBox(
                width: double.infinity,
                child: _DjedSheetStage(
                  key: const ValueKey<String>('djed-day-live-stage'),
                  fixture: fixture,
                  supports: supports,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedSheetStage extends StatelessWidget {
  const _DjedSheetStage({
    super.key,
    required this.fixture,
    required this.supports,
  });

  final DjedDayVisualFixture fixture;
  final List<DjedSupportFixture> supports;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DjedSheetStagePainter(fixture: fixture, supports: supports),
    );
  }
}

class _DjedSheetStagePainter extends CustomPainter {
  const _DjedSheetStagePainter({required this.fixture, required this.supports});

  final DjedDayVisualFixture fixture;
  final List<DjedSupportFixture> supports;

  @override
  void paint(Canvas canvas, Size size) {
    final stageRect = Offset.zero & size;
    canvas.drawRect(
      stageRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, .72),
          radius: .78,
          colors: <Color>[Color(0x16D4AE43), Color(0x00D4AE43)],
        ).createShader(stageRect),
    );

    // SVG viewBox defaults to preserveAspectRatio="xMidYMid meet". Using
    // separate X/Y factors deforms the Djed after rotation, so keep one
    // uniform scale and center the 390 × 214 drawing in the stage.
    final scale = math.min(size.width / 390, size.height / 214);
    final drawingSize = Size(390 * scale, 214 * scale);
    final drawingOffset = Offset(
      (size.width - drawingSize.width) / 2,
      (size.height - drawingSize.height) / 2,
    );

    canvas.drawLine(
      Offset(17, size.height - 27),
      Offset(size.width - 17, size.height - 27),
      Paint()
        ..color = const Color(0x2ED4AE43)
        ..strokeWidth = 1,
    );

    canvas.save();
    canvas.translate(drawingOffset.dx, drawingOffset.dy);
    canvas.scale(scale);

    if (fixture.sittingNumber == 4 || fixture.sittingNumber == 5) {
      final rope = Paint()
        ..color = const Color(0xFF7A6A46)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
        canvas,
        const Offset(198, 100),
        const Offset(74, 181),
        rope,
      );
      _drawDashedLine(
        canvas,
        const Offset(198, 100),
        const Offset(318, 181),
        rope,
      );
    }

    canvas.save();
    canvas.translate(200, 186);
    canvas.rotate(_sheetAngle(fixture.sittingNumber) * math.pi / 180);
    canvas.translate(-200, -186);

    final shaftPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF6B4E24),
          Color(0xFFD4AE43),
          Color(0xFF8B652F),
          Color(0xFF4C3518),
        ],
        stops: <double>[0, .42, .7, 1],
      ).createShader(const Rect.fromLTWH(150, 0, 100, 190));
    _drawRoundedRect(
      canvas,
      const Rect.fromLTWH(170, 176, 60, 12),
      5,
      shaftPaint,
    );
    _drawRoundedRect(
      canvas,
      const Rect.fromLTWH(192, 88, 16, 92),
      7,
      shaftPaint,
    );

    const ys = <double>[28, 46, 64, 82];
    const widths = <double>[142, 136, 130, 122];
    final active = (fixture.supportSlot - 1).clamp(0, 3);
    for (var supportIndex = 0; supportIndex < 4; supportIndex++) {
      final slot = 3 - supportIndex;
      final rect = Rect.fromLTWH(
        200 - widths[slot] / 2,
        ys[slot],
        widths[slot],
        13,
      );
      final barPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFD9C99D),
            Color(0xFFAC8C50),
            Color(0xFF705129),
          ],
          stops: <double>[0, .54, 1],
        ).createShader(rect);
      _drawRoundedRect(canvas, rect, 6.5, barPaint);
      if (supportIndex == active) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6.5)),
          Paint()
            ..color = const Color(0xFFF0C96A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.35,
        );
      }
      final rawName = supportIndex < supports.length
          ? supports[supportIndex].name.trim()
          : '';
      final name =
          supportIndex == active && fixture.supportName.trim().isNotEmpty
          ? fixture.supportName.trim()
          : rawName.isEmpty
          ? 'support ${(supportIndex + 1).toString().padLeft(2, '0')}'
          : rawName;
      final clipped = name.length > 20 ? '${name.substring(0, 19)}…' : name;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(supportIndex + 1).toString().padLeft(2, '0')} · $clipped',
          style: const TextStyle(
            color: Color(0xFF25190B),
            fontFamily: MaatFlowListTokens.fontFamily,
            fontSize: 10.5,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: rect.width - 8);
      textPainter.paint(
        canvas,
        Offset(200 - textPainter.width / 2, rect.top + 1.25),
      );
    }
    _drawRoundedRect(
      canvas,
      const Rect.fromLTWH(150, 8, 100, 11),
      5.5,
      shaftPaint,
    );
    canvas.restore();
    canvas.restore();

    final angleText = TextPainter(
      text: TextSpan(
        text: _sheetAngleLabel(fixture.sittingNumber),
        style: const TextStyle(
          color: Color(0xFF6C6049),
          fontFamily: 'GentiumPlus',
          fontSize: 9,
          height: 1,
          letterSpacing: 1.05,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    angleText.paint(
      canvas,
      Offset(
        size.width - 10 - angleText.width,
        size.height - 8 - angleText.height,
      ),
    );
  }

  void _drawRoundedRect(Canvas canvas, Rect rect, double radius, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    final direction = delta / distance;
    for (double position = 0; position < distance; position += 7) {
      canvas.drawLine(
        start + direction * position,
        start + direction * math.min(position + 3, distance),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DjedSheetStagePainter oldDelegate) =>
      oldDelegate.fixture != fixture || oldDelegate.supports != supports;
}

class _DjedPracticeSheet extends StatelessWidget {
  const _DjedPracticeSheet({
    required this.fixture,
    this.onStageAction,
    this.onMoveChanged,
    this.onDoToday,
    this.onPutOnCalendar,
    this.onResultSelected,
    this.onResultNoteChanged,
    this.onSmallerMoveChanged,
    this.onCloseBeam,
    this.onRaise,
    this.onCompletionSelected,
  });

  final DjedDayVisualFixture fixture;
  final VoidCallback? onStageAction;
  final ValueChanged<String>? onMoveChanged;
  final VoidCallback? onDoToday;
  final VoidCallback? onPutOnCalendar;
  final ValueChanged<DjedResultVisualState>? onResultSelected;
  final ValueChanged<String>? onResultNoteChanged;
  final ValueChanged<String>? onSmallerMoveChanged;
  final VoidCallback? onCloseBeam;
  final VoidCallback? onRaise;
  final ValueChanged<DjedCompletionVisualState>? onCompletionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B0805), Color(0xFF080604)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0x36D4AE43))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x9E000000),
            blurRadius: 32,
            offset: Offset(0, -15),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            left: 0,
            right: 0,
            top: 7,
            child: Center(
              child: SizedBox(
                width: 38,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF4E3B1B),
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DjedFocusCard(fixture: fixture),
                const SizedBox(height: 14),
                _DjedDecisionSurface(
                  fixture: fixture,
                  onStageAction: onStageAction,
                  onMoveChanged: onMoveChanged,
                  onDoToday: onDoToday,
                  onPutOnCalendar: onPutOnCalendar,
                  onResultSelected: onResultSelected,
                  onResultNoteChanged: onResultNoteChanged,
                  onSmallerMoveChanged: onSmallerMoveChanged,
                  onCloseBeam: onCloseBeam,
                ),
                if (fixture.sittingNumber == 9 &&
                    fixture.result != DjedResultVisualState.none) ...<Widget>[
                  const SizedBox(height: 14),
                  _DjedRaisingSurface(fixture: fixture, onRaise: onRaise),
                ],
                const SizedBox(height: 17),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: DjedDayTokens.separator),
                    ),
                  ),
                  child: TextButton(
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
                    onPressed: () {},
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Why this belongs at the Djed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('+'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                _DjedCompletion(
                  selected: fixture.completion,
                  onSelected: onCompletionSelected,
                ),
                const SizedBox(height: 18),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE7C66C),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.centerLeft,
                    textStyle: const TextStyle(
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back to Day View'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedFocusCard extends StatelessWidget {
  const _DjedFocusCard({required this.fixture});

  final DjedDayVisualFixture fixture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x15D4AE43))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              fixture.sittingNumber == 1
                  ? 'Four supports'
                  : fixture.supportName,
              style: const TextStyle(
                color: Color(0xFFE8E2D6),
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.02,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fixture.sittingNumber == 1 ? 'ONE AT A TIME' : 'NEUTRAL',
            style: const TextStyle(
              color: Color(0xFF9B8248),
              fontFamily: 'GentiumPlus',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedDecisionSurface extends StatelessWidget {
  const _DjedDecisionSurface({
    required this.fixture,
    this.onStageAction,
    this.onMoveChanged,
    this.onDoToday,
    this.onPutOnCalendar,
    this.onResultSelected,
    this.onResultNoteChanged,
    this.onSmallerMoveChanged,
    this.onCloseBeam,
  });

  final DjedDayVisualFixture fixture;
  final VoidCallback? onStageAction;
  final ValueChanged<String>? onMoveChanged;
  final VoidCallback? onDoToday;
  final VoidCallback? onPutOnCalendar;
  final ValueChanged<DjedResultVisualState>? onResultSelected;
  final ValueChanged<String>? onResultNoteChanged;
  final ValueChanged<String>? onSmallerMoveChanged;
  final VoidCallback? onCloseBeam;

  bool get _isPlan => <int>{2, 4, 6, 8}.contains(fixture.sittingNumber);
  bool get _isReview => <int>{3, 5, 7, 9}.contains(fixture.sittingNumber);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x33D4AE43)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF100C06), Color(0xFF090805)],
        ),
      ),
      child: _isPlan
          ? _buildPlan()
          : _isReview
          ? _buildReview()
          : _buildOrientation(),
    );
  }

  Widget _buildPlan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _DecisionLabel('ONE SMALL MOVE'),
        const SizedBox(height: 7),
        const Text(
          'What is one useful thing you can do that is fully in your hands?',
          style: _decisionQuestionStyle,
        ),
        const SizedBox(height: 11),
        TextFormField(
          key: const ValueKey<String>('djed-move-field'),
          initialValue: fixture.move,
          onChanged: onMoveChanged,
          minLines: 1,
          maxLines: 2,
          style: const TextStyle(
            color: Color(0xFFE0D3B6),
            fontFamily: MaatFlowListTokens.fontFamily,
            fontSize: 17,
            fontStyle: FontStyle.italic,
            height: 1.25,
          ),
          decoration: const InputDecoration(
            isDense: true,
            hintText:
                'send one message · make one call · take one step · practice for 10 minutes',
            hintStyle: TextStyle(color: Color(0xFF544A38)),
            contentPadding: EdgeInsets.fromLTRB(0, 8, 0, 9),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0x47D4AE43)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xBFE7C66C)),
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Keep it small enough to finish before you return.',
          style: _decisionNoteStyle,
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 1, color: Color(0x1AD4AE43)),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            Expanded(
              child: _DecisionTextButton(
                label: 'Do today',
                onPressed: onDoToday ?? onStageAction,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _DecisionTextButton(
                label: 'Put on calendar',
                color: Color(0xFFC9912F),
                onPressed: onPutOnCalendar ?? onStageAction,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _DecisionLabel('THE MOVE'),
        const SizedBox(height: 7),
        Text(
          fixture.move.trim().isEmpty
              ? 'The move you chose last sitting'
              : fixture.move,
          style: _decisionQuestionStyle,
        ),
        const SizedBox(height: 9),
        const Text('What happened?', style: _decisionNoteStyle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            _DjedChoiceButton(
              label: 'It helped',
              selected: fixture.result == DjedResultVisualState.helped,
              onPressed: () =>
                  onResultSelected?.call(DjedResultVisualState.helped),
            ),
            _DjedChoiceButton(
              label: 'No change',
              selected: fixture.result == DjedResultVisualState.noChange,
              onPressed: () =>
                  onResultSelected?.call(DjedResultVisualState.noChange),
            ),
            _DjedChoiceButton(
              label: "I didn't do it",
              selected: fixture.result == DjedResultVisualState.notDone,
              ember: true,
              onPressed: () =>
                  onResultSelected?.call(DjedResultVisualState.notDone),
            ),
          ],
        ),
        if (fixture.result != DjedResultVisualState.none) ...<Widget>[
          const SizedBox(height: 14),
          Text(switch (fixture.result) {
            DjedResultVisualState.helped => 'What worked?',
            DjedResultVisualState.noChange => 'What did you learn?',
            DjedResultVisualState.notDone => 'What got in the way?',
            DjedResultVisualState.none => '',
          }, style: _decisionQuestionStyle),
          const SizedBox(height: 7),
          TextFormField(
            key: const ValueKey<String>('djed-result-note-field'),
            initialValue: fixture.resultNote,
            onChanged: onResultNoteChanged,
            minLines: 1,
            maxLines: 2,
            style: _decisionInputStyle,
            decoration: InputDecoration(
              isDense: true,
              hintText: switch (fixture.result) {
                DjedResultVisualState.helped => 'the part worth repeating',
                DjedResultVisualState.noChange => 'one thing you know now',
                DjedResultVisualState.notDone => 'the thing that blocked it',
                DjedResultVisualState.none => '',
              },
              hintStyle: const TextStyle(color: Color(0xFF544A38)),
              contentPadding: const EdgeInsets.fromLTRB(0, 7, 0, 8),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0x47D4AE43)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xBFE7C66C)),
              ),
            ),
          ),
          if (fixture.result == DjedResultVisualState.notDone) ...<Widget>[
            const SizedBox(height: 14),
            const Text('Make the move smaller.', style: _decisionQuestionStyle),
            const SizedBox(height: 7),
            TextFormField(
              key: const ValueKey<String>('djed-smaller-move-field'),
              initialValue: fixture.smallerMove,
              onChanged: onSmallerMoveChanged,
              minLines: 1,
              maxLines: 2,
              style: _decisionInputStyle,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'a version you could do today',
                hintStyle: TextStyle(color: Color(0xFF544A38)),
                contentPadding: EdgeInsets.fromLTRB(0, 7, 0, 8),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0x47D4AE43)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xBFE7C66C)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 11),
          _DecisionTextButton(
            label: fixture.result == DjedResultVisualState.notDone
                ? 'Do smaller today'
                : 'Close this beam',
            onPressed: onCloseBeam,
          ),
        ],
      ],
    );
  }

  Widget _buildOrientation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _DecisionLabel('START SMALL'),
        const SizedBox(height: 7),
        const Text('Pick one ten-minute reset.', style: _decisionQuestionStyle),
        const SizedBox(height: 9),
        const Text(
          'Small is the point. Start by giving yourself one quick piece of control.',
          style: _decisionNoteStyle,
        ),
        const SizedBox(height: 12),
        _DecisionTextButton(label: 'Do today', onPressed: onStageAction),
      ],
    );
  }
}

class _DecisionLabel extends StatelessWidget {
  const _DecisionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF9B8248),
      fontFamily: 'GentiumPlus',
      fontSize: 8.5,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: 1.3,
    ),
  );
}

class _DecisionTextButton extends StatelessWidget {
  const _DecisionTextButton({
    required this.label,
    required this.onPressed,
    this.color = const Color(0xFFE7C66C),
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 5),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: MaatFlowListTokens.fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    ),
    onPressed: onPressed,
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _DjedChoiceButton extends StatelessWidget {
  const _DjedChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.ember = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool ember;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: selected
          ? ember
                ? const Color(0xFFE6B699)
                : const Color(0xFFE4D4AB)
          : const Color(0xFF827C70),
      backgroundColor: selected
          ? ember
                ? const Color(0x1AB96D4B)
                : const Color(0x14D4AE43)
          : Colors.transparent,
      side: BorderSide(
        color: selected
            ? ember
                  ? const Color(0xFFB96D4B)
                  : const Color(0xA8D4AE43)
            : const Color(0x33D4AE43),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'GentiumPlus',
        fontSize: 11,
        height: 1,
      ),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

const TextStyle _decisionQuestionStyle = TextStyle(
  color: Color(0xFFE9E4DB),
  fontFamily: MaatFlowListTokens.fontFamily,
  fontSize: 22,
  fontWeight: FontWeight.w500,
  height: 1.08,
);

const TextStyle _decisionNoteStyle = TextStyle(
  color: Color(0xFF756B58),
  fontFamily: 'GentiumPlus',
  fontSize: 11.5,
  height: 1.35,
);

const TextStyle _decisionInputStyle = TextStyle(
  color: Color(0xFFE0D3B6),
  fontFamily: MaatFlowListTokens.fontFamily,
  fontSize: 17,
  fontStyle: FontStyle.italic,
  height: 1.25,
);

class _DjedRaisingSurface extends StatelessWidget {
  const _DjedRaisingSurface({required this.fixture, this.onRaise});

  final DjedDayVisualFixture fixture;
  final VoidCallback? onRaise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x33D4AE43)),
        color: const Color(0xFF0D0906),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DecisionLabel(fixture.raised ? 'UPRIGHT' : 'THE RAISING'),
          const SizedBox(height: 7),
          Text(
            fixture.raised
                ? 'Four beams. Four attempts. One method you can use again.'
                : 'Stand. Raise the whole structure.',
            style: _decisionQuestionStyle,
          ),
          const SizedBox(height: 8),
          if (fixture.raised)
            const Text(
              'Find the part that is in your hands. Make one small move. Return and read the result.',
              style: _decisionNoteStyle,
            )
          else ...<Widget>[
            FilledButton(
              key: const ValueKey<String>('djed-raise-button'),
              onPressed: fixture.raisingActive ? null : onRaise,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB57925),
                foregroundColor: const Color(0xFF120B05),
              ),
              child: Text(
                fixture.raisingActive
                    ? 'Hold with the pillar · ${fixture.raisingSecondsRemaining}s'
                    : 'Begin 30-second raising',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DjedCompletion extends StatelessWidget {
  const _DjedCompletion({required this.selected, this.onSelected});

  final DjedCompletionVisualState selected;
  final ValueChanged<DjedCompletionVisualState>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x06D4AE43),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x29D4AE43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'COMPLETION',
            style: TextStyle(
              color: Color(0xFFA88135),
              fontFamily: 'GentiumPlus',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final option in const <DjedCompletionVisualState>[
                DjedCompletionVisualState.observed,
                DjedCompletionVisualState.partly,
                DjedCompletionVisualState.skipped,
              ]) ...<Widget>[
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => onSelected?.call(option),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: selected == option
                            ? const Color(0xFF160F08)
                            : const Color(0xFF9F9383),
                        backgroundColor: selected == option
                            ? const Color(0xFFD4AE43)
                            : const Color(0xFF0D0906),
                        side: BorderSide(
                          color: selected == option
                              ? const Color(0xFFE0B958)
                              : const Color(0xFF3E2E1C),
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(_completionLabel(option)),
                    ),
                  ),
                ),
                if (option != DjedCompletionVisualState.skipped)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class DjedDayFooterChrome extends StatelessWidget {
  const DjedDayFooterChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xD6070503), Color(0xFF070503)],
          stops: <double>[0, .3],
        ),
        border: Border(top: BorderSide(color: Color(0x1AD4AE43))),
      ),
      child: child,
    );
  }
}

class DjedDayFooterActions extends StatelessWidget {
  const DjedDayFooterActions({super.key, this.onMakeTodo, this.onCalendar});

  final VoidCallback? onMakeTodo;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    return DjedDayFooterChrome(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: TextButton(
              onPressed: onMakeTodo,
              style: _djedFooterButtonStyle,
              child: const Text(
                '≡✓  Make to-do',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: TextButton(
              onPressed: onCalendar,
              style: _djedFooterButtonStyle,
              child: const Text(
                'Calendar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle get _djedFooterButtonStyle => TextButton.styleFrom(
  foregroundColor: const Color(0xFFD9B45D),
  padding: EdgeInsets.zero,
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(
    fontFamily: 'GentiumPlus',
    fontSize: 15,
    fontWeight: FontWeight.w700,
  ),
);

String _sheetPhase(int sittingNumber, String fallback) =>
    sittingNumber == 1 ? 'ORIENTATION' : fallback;

String _sheetContext(int sittingNumber) => switch (sittingNumber) {
  1 =>
    'You do not have to fix everything at once. For each support: make one small move, then return and see what happened.',
  2 =>
    'You do not have to solve this. Find one useful part that is fully in your hands.',
  3 =>
    'Come back to the move you chose. Read what actually happened before deciding anything else.',
  4 =>
    'Same method, new beam. One useful move. Small enough to complete before you return.',
  5 =>
    'The work already happened outside the app. This sitting only asks what the move taught you.',
  6 =>
    'You know the pattern now: find the part you can move, keep it small, put it in time.',
  7 =>
    'Look at the result, not the intention. What happened is enough to tell you what comes next.',
  8 =>
    'Last beam. Do not make the move bigger because it is last. Small and doable still wins.',
  _ => 'Read the last result. Then stand and raise the whole structure.',
};

double _sheetAngle(int sittingNumber) => switch (sittingNumber.clamp(1, 9)) {
  1 => -74,
  2 => -66,
  3 => -56,
  4 => -42,
  5 => -32,
  6 => -24,
  7 => -16,
  8 => -8,
  _ => 0,
};

String _sheetAngleLabel(int sittingNumber) =>
    switch (sittingNumber.clamp(1, 9)) {
      1 => 'LYING · NOT YET RAISED',
      2 => 'NAMED · STILL LOW',
      3 => 'INVENTORY HELD',
      4 => 'UNDER LOAD · 42°',
      5 => 'ENGAGEMENT · 32°',
      6 => 'AFTER THE BATTLE · 24°',
      7 => 'PREPARING TO RAISE · 16°',
      8 => 'NEAR UPRIGHT · 8°',
      _ => 'UPRIGHT',
    };

String _completionLabel(DjedCompletionVisualState state) {
  return switch (state) {
    DjedCompletionVisualState.observed => 'Observed',
    DjedCompletionVisualState.partly => 'Partly',
    DjedCompletionVisualState.skipped => 'Skipped',
    DjedCompletionVisualState.none => '',
  };
}
