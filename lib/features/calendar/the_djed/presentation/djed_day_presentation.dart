import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_presentation_copy.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_sitting_models.dart';

export 'djed_sitting_models.dart';

abstract final class DjedDayTokens {
  static const Color page = Color(0xFF050403);
  static const Color lower = Color(0xFF090705);
  static const Color bone = Color(0xFFF3EADF);
  static const Color silver = Color(0xFFA0968A);
  static const Color low = Color(0xFF6E655B);
  static const Color gold = Color(0xFFE0873C);
  static const Color goldBright = Color(0xFFF5B963);
  static const Color separator = Color(0xFF2C2016);
  static const double unselectedSupportOpacity = .34;
  static const double orientationSupportOpacity = .78;
  static const Color raisingGlow = Color(0xFFF0C96A);
  static const List<double> supportGradientStops = <double>[0, .54, 1];
  static const List<double> wobblingSupportGradientStops = <double>[0, .5, 1];
  static const List<Color> unassessedSupportGradient = <Color>[
    Color(0xFFD9C99D),
    Color(0xFFAC8C50),
    Color(0xFF705129),
  ];
  static const List<Color> holdingSupportGradient = <Color>[
    Color(0xFFF4E4B2),
    Color(0xFFD2AE63),
    Color(0xFF8D662B),
  ];
  static const List<Color> underPressureSupportGradient = <Color>[
    Color(0xFFEBCBAD),
    Color(0xFFC58D61),
    Color(0xFF7D4D32),
  ];
  static const List<Color> wobblingSupportGradient = <Color>[
    Color(0xFFE4C782),
    Color(0xFFB28A42),
    Color(0xFF695021),
  ];
}

const double _djedInstrumentTopPadding = 18;
const double _djedInstrumentTitleSize = 29;
const double _djedInstrumentTitleToStageGap = 12;
const double _djedInstrumentBottomPadding = 24;

double _djedInstrumentStageHeight(BuildContext context) {
  final view = View.of(context);
  final viewportHeight = view.physicalSize.height / view.devicePixelRatio;
  return viewportHeight <= 720 ? 205 : 230;
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
    final stageHeight = _djedInstrumentStageHeight(context);
    final completeInstrumentHeight =
        _djedInstrumentTopPadding +
        MediaQuery.textScalerOf(context).scale(_djedInstrumentTitleSize) +
        _djedInstrumentTitleToStageGap +
        stageHeight +
        _djedInstrumentBottomPadding;
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
      fixedHeroHeight: completeInstrumentHeight,
      instrumentFooterHeight: 0,
      instrument: _DjedInstrument(
        fixture: fixture,
        supports: supports,
        stageHeight: stageHeight,
      ),
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
  const _DjedInstrument({
    required this.fixture,
    required this.supports,
    required this.stageHeight,
  });

  final DjedDayVisualFixture fixture;
  final List<DjedSupportFixture> supports;
  final double stageHeight;

  @override
  Widget build(BuildContext context) {
    final sitting =
        kDjedSittingFixtures[(fixture.sittingNumber - 1).clamp(
          0,
          kDjedSittingFixtures.length - 1,
        )];
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF120C07), Color(0xFF0C0906)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            15,
            _djedInstrumentTopPadding,
            15,
            _djedInstrumentBottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  sitting.title,
                  key: const ValueKey<String>('djed-instrument-title'),
                  style: const TextStyle(
                    color: Color(0xFFE7C66C),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: _djedInstrumentTitleSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: _djedInstrumentTitleToStageGap),
              SizedBox(
                height: stageHeight,
                width: double.infinity,
                child: DjedSittingStage(
                  key: const ValueKey<String>('djed-day-live-stage'),
                  fixture: fixture,
                  supports: supports,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DjedSittingStage extends StatelessWidget {
  const DjedSittingStage({
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
    final raising = fixture.sittingNumber == 9;
    _drawEllipticalRadialGradient(
      canvas,
      clip: stageRect,
      center: Offset(size.width * .5, size.height * (raising ? .54 : .86)),
      radiusX: size.width * (raising ? .58 : .78),
      radiusY: size.height * (raising ? .78 : .72),
      color: (raising ? DjedDayTokens.raisingGlow : const Color(0xFFD4AE43))
          .withValues(alpha: raising ? .18 : .085),
      fadeStop: raising ? .68 : .64,
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

    if (fixture.sittingNumber == 9) {
      const raisingGlowBounds = Rect.fromLTWH(82, 10, 236, 204);
      _drawEllipticalRadialGradient(
        canvas,
        clip: raisingGlowBounds,
        center: const Offset(200, 112),
        radiusX: 118,
        radiusY: 102,
        color: DjedDayTokens.raisingGlow.withValues(alpha: .34),
      );
    }

    if (fixture.sittingNumber >= 3 && fixture.sittingNumber <= 8) {
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

    final active = fixture.sittingNumber == 1
        ? -1
        : (fixture.supportSlot - 1).clamp(0, 3);
    _drawPillar(
      canvas,
      angle: _sheetAngle(fixture.sittingNumber),
      activeSupport: active,
    );
    canvas.restore();

    if (fixture.raised) {
      final progressText = TextPainter(
        text: const TextSpan(
          text: 'RAISED',
          style: TextStyle(
            color: Color(0xFFE7C66C),
            fontFamily: 'GentiumPlus',
            fontSize: 8,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      progressText.paint(
        canvas,
        Offset(11, size.height - 8 - progressText.height),
      );
    }

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

  void _drawPillar(
    Canvas canvas, {
    required double angle,
    required int activeSupport,
  }) {
    canvas.save();
    canvas.translate(200, 186);
    canvas.rotate(angle * math.pi / 180);
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
    for (var supportIndex = 0; supportIndex < 4; supportIndex++) {
      final slot = 3 - supportIndex;
      final rect = Rect.fromLTWH(
        200 - widths[slot] / 2,
        ys[slot],
        widths[slot],
        13,
      );
      final condition = supportIndex < supports.length
          ? supports[supportIndex].condition
          : DjedSupportCondition.unassessed;
      final supportOpacity = fixture.sittingNumber == 1
          ? DjedDayTokens.orientationSupportOpacity
          : supportIndex == activeSupport
          ? 1.0
          : DjedDayTokens.unselectedSupportOpacity;
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            for (final color in _supportGradient(condition))
              color.withValues(alpha: supportOpacity),
          ],
          stops: _supportGradientStops(condition),
        ).createShader(rect);
      _drawRoundedRect(canvas, rect, 6.5, barPaint);
      if (supportIndex == activeSupport) {
        final selectedBar = RRect.fromRectAndRadius(
          rect,
          const Radius.circular(6.5),
        );
        canvas.drawRRect(
          selectedBar,
          Paint()
            ..color = const Color(0xFFF0C96A).withValues(alpha: .28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.35
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawRRect(
          selectedBar,
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
          supportIndex == activeSupport && fixture.supportName.trim().isNotEmpty
          ? fixture.supportName.trim()
          : rawName;
      final label = djedSheetSupportBarLabel(
        slotNumber: supportIndex + 1,
        name: name,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: const Color(0xFF25190B).withValues(alpha: supportOpacity),
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
  }

  void _drawRoundedRect(Canvas canvas, Rect rect, double radius, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  void _drawEllipticalRadialGradient(
    Canvas canvas, {
    required Rect clip,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    double fadeStop = 1,
  }) {
    final unitCircle = Rect.fromCircle(center: Offset.zero, radius: 1);
    canvas.save();
    canvas.clipRect(clip);
    canvas.translate(center.dx, center.dy);
    canvas.scale(radiusX, radiusY);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          // Flutter measures this against the shader box's full short side;
          // .5 therefore reaches the unit circle's radius exactly.
          radius: .5,
          colors: <Color>[color, color.withValues(alpha: 0)],
          stops: <double>[0, fadeStop],
        ).createShader(unitCircle),
    );
    canvas.restore();
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

List<Color> _supportGradient(DjedSupportCondition condition) =>
    switch (condition) {
      DjedSupportCondition.unassessed =>
        DjedDayTokens.unassessedSupportGradient,
      DjedSupportCondition.holding => DjedDayTokens.holdingSupportGradient,
      DjedSupportCondition.underPressure =>
        DjedDayTokens.underPressureSupportGradient,
      DjedSupportCondition.wobbling => DjedDayTokens.wobblingSupportGradient,
    };

List<double> _supportGradientStops(DjedSupportCondition condition) =>
    condition == DjedSupportCondition.wobbling
    ? DjedDayTokens.wobblingSupportGradientStops
    : DjedDayTokens.supportGradientStops;

/// Shared sitting controls. The Day View and detail-entry presentations own
/// their sheet composition independently and reuse only this action content.
class DjedSittingActionContent extends StatelessWidget {
  const DjedSittingActionContent({
    super.key,
    required this.fixture,
    this.focusStateLabel,
    this.onStageAction,
    this.onMoveChanged,
    this.onDoToday,
    this.onPutOnCalendar,
    this.onResultSelected,
    this.onResultNoteChanged,
    this.onSmallerMoveChanged,
    this.onCloseBeam,
    this.onRaise,
  });

  final DjedDayVisualFixture fixture;
  final String? focusStateLabel;
  final VoidCallback? onStageAction;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DjedFocusCard(fixture: fixture, stateLabel: focusStateLabel),
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
      ],
    );
  }
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DjedSittingActionContent(
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
            ),
            const SizedBox(height: 17),
            const _DjedInKemetDisclosure(),
            const SizedBox(height: 5),
            _DjedCompletion(
              selected: fixture.completion,
              onSelected: onCompletionSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _DjedInKemetDisclosure extends StatefulWidget {
  const _DjedInKemetDisclosure();

  @override
  State<_DjedInKemetDisclosure> createState() => _DjedInKemetDisclosureState();
}

class _DjedInKemetDisclosureState extends State<_DjedInKemetDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DjedDayTokens.separator)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            expanded: _expanded,
            child: TextButton(
              key: const ValueKey<String>('djed-in-kemet-disclosure'),
              style: _djedDisclosureButtonStyle,
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'In Kemet',
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
            const Padding(
              key: ValueKey<String>('djed-in-kemet-explanation'),
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                djedInKemetExplanation,
                style: TextStyle(
                  color: Color(0xFFA69A83),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 14,
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

ButtonStyle get _djedDisclosureButtonStyle => TextButton.styleFrom(
  foregroundColor: const Color(0xFF8A8378),
  padding: const EdgeInsets.symmetric(vertical: 13),
  alignment: Alignment.centerLeft,
  textStyle: const TextStyle(
    fontFamily: MaatFlowListTokens.fontFamily,
    fontSize: 14,
    fontStyle: FontStyle.italic,
    height: 1,
  ),
);

class _DjedFocusCard extends StatelessWidget {
  const _DjedFocusCard({required this.fixture, this.stateLabel});

  final DjedDayVisualFixture fixture;
  final String? stateLabel;

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
            stateLabel ??
                (fixture.sittingNumber == 1 ? 'ONE AT A TIME' : 'NEUTRAL'),
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
    return _DjedOrientationDecision(
      onDoToday: onDoToday ?? onStageAction,
      onPutOnCalendar: onPutOnCalendar ?? onStageAction,
    );
  }
}

class _DjedOrientationDecision extends StatefulWidget {
  const _DjedOrientationDecision({this.onDoToday, this.onPutOnCalendar});

  final VoidCallback? onDoToday;
  final VoidCallback? onPutOnCalendar;

  @override
  State<_DjedOrientationDecision> createState() =>
      _DjedOrientationDecisionState();
}

class _DjedOrientationDecisionState extends State<_DjedOrientationDecision> {
  String? _choice;

  static const List<(String, String)> _choices = <(String, String)>[
    ('clear', 'clear one space'),
    ('prepare', 'prepare something you need'),
    ('outside', 'step outside'),
    ('move', 'move for 10 minutes'),
    ('reach', 'reach out to someone'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _DecisionLabel('START SMALL'),
        const SizedBox(height: 7),
        const Text('Pick one ten-minute reset.', style: _decisionQuestionStyle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final choice in _choices)
              _DjedChoiceButton(
                label: choice.$2,
                selected: _choice == choice.$1,
                onPressed: () => setState(() => _choice = choice.$1),
              ),
          ],
        ),
        const SizedBox(height: 9),
        const Text(
          'Small is the point. Start by giving yourself one quick piece of control.',
          style: _decisionNoteStyle,
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: Color(0x1AD4AE43)),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            Expanded(
              child: _DecisionTextButton(
                label: 'Do today',
                onPressed: widget.onDoToday,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _DecisionTextButton(
                label: 'Put on calendar',
                color: Color(0xFFC9912F),
                onPressed: widget.onPutOnCalendar,
              ),
            ),
          ],
        ),
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
            OutlinedButton(
              key: const ValueKey<String>('djed-raise-button'),
              onPressed: fixture.raisingActive ? null : onRaise,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: const Color(0xFFE7C66C),
                disabledForegroundColor: const Color(0xFFE7C66C),
                backgroundColor: const Color(0x0AD4AE43),
                side: const BorderSide(color: Color(0x7AD4AE43)),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
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
      key: const ValueKey<String>('djed-completion-picker'),
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
  const DjedDayFooterActions({
    super.key,
    this.onMakeTodo,
    this.onCalendar,
    this.makeTodoUnavailable = false,
  });

  final VoidCallback? onMakeTodo;
  final VoidCallback? onCalendar;
  final bool makeTodoUnavailable;

  @override
  Widget build(BuildContext context) {
    final makeTodoLabel = makeTodoUnavailable
        ? 'Make to-do unavailable'
        : '≡✓  Make to-do';
    return DjedDayFooterChrome(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: TextButton(
              key: ValueKey<String>(
                makeTodoUnavailable
                    ? 'djed-detail-make-todo-unavailable'
                    : 'djed-detail-make-todo',
              ),
              onPressed: onMakeTodo,
              style: _djedFooterButtonStyle,
              child: Text(
                makeTodoLabel,
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
