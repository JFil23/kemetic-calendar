import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../maat_flow_response_draft_store.dart';
import '../../maat_flow_response_journal_blocks.dart';
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
    required this.initialIntention,
    required this.lens,
    required this.completionPanel,
    this.persistResponses = true,
    this.clientEventId,
    this.onSaveIntention,
    this.onWriteJournalResponse,
    this.intentionSaveDebounce = const Duration(milliseconds: 350),
    this.reflectionSaveDebounce = const Duration(milliseconds: 450),
  });

  final OfferingTableDay day;
  final DateTime localDate;
  final int startMinute;
  final String initialIntention;
  final OfferingTableLens lens;
  final Widget completionPanel;
  final bool persistResponses;
  final String? clientEventId;
  final Future<void> Function(String value)? onSaveIntention;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Duration intentionSaveDebounce;
  final Duration reflectionSaveDebounce;

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
  static const _reflectionPrompt =
      'What did you notice about what needs to be fed?';
  static const _reflectionStyle = InstrumentEventReflectionStyle(
    activeColor: _gold,
    armedBackgroundColor: Color(0x1AD4AE43),
    inactiveBackgroundColor: Color(0x06FFFFFF),
    inactiveIconColor: _bone,
    inactiveLabelColor: _silverLow,
    inactiveBorderColor: _separator,
    promptColor: _bone,
    reflectionTextColor: Color(0xFFE8B27C),
    mutedColor: _silverLow,
    fieldFillColor: Color(0x08FFFFFF),
    microphoneBackgroundColor: Color(0x14C08A52),
    displayFontFamily: _display,
    uiFontFamily: _ui,
  );

  final TextEditingController _intentionController = TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();
  Future<void> _intentionWriteTail = Future<void>.value();
  Future<void> _journalWriteTail = Future<void>.value();
  Timer? _intentionSaveTimer;
  Timer? _reflectionSaveTimer;
  String? _lastSavedIntention;
  String? _lastWrittenReflection;
  bool _intentionDirty = false;
  bool _updatingIntentionFromWidget = false;
  bool _reflectionDirty = false;
  bool _reflectionOpen = false;
  int _contextGeneration = 0;
  double _placement = 0;
  late Map<String, bool> _checkedSteps;

  OfferingTablePracticePresentation get _presentation =>
      offeringTablePracticePresentation(widget.day);

  String _stepId(int index) =>
      'offering-table-day-${widget.day.dayNumber.toString().padLeft(2, '0')}-step-${index + 1}';

  @override
  void initState() {
    super.initState();
    final initialIntention = widget.initialIntention.trim();
    _intentionController.text = initialIntention;
    _lastSavedIntention = initialIntention;
    _intentionController.addListener(_onIntentionChanged);
    _reflectionController.addListener(_onReflectionChanged);
    final drafts = widget.persistResponses
        ? kMaatFlowResponseDraftStore.valuesForFlow(kOfferingTableFlowKey)
        : const <String, MaatFlowResponseValue>{};
    _checkedSteps = <String, bool>{
      for (var index = 0; index < _presentation.steps.length; index++)
        _stepId(index): drafts[_stepId(index)]?.checked == true,
    };
  }

  @override
  void didUpdateWidget(covariant OfferingTableDayPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIntention == widget.initialIntention ||
        _intentionDirty) {
      return;
    }
    final intention = widget.initialIntention.trim();
    if (_intentionController.text == intention) return;
    _updatingIntentionFromWidget = true;
    _intentionController.text = intention;
    _updatingIntentionFromWidget = false;
    _lastSavedIntention = intention;
  }

  @override
  void dispose() {
    _intentionSaveTimer?.cancel();
    unawaited(_flushIntention());
    _reflectionSaveTimer?.cancel();
    unawaited(_flushReflection());
    _intentionController
      ..removeListener(_onIntentionChanged)
      ..dispose();
    _reflectionController
      ..removeListener(_onReflectionChanged)
      ..dispose();
    super.dispose();
  }

  void _onIntentionChanged() {
    if (_updatingIntentionFromWidget) return;
    setState(() {});
    final saver = widget.onSaveIntention;
    if (saver == null) return;
    _intentionDirty = true;
    _intentionSaveTimer?.cancel();
    _intentionSaveTimer = Timer(
      widget.intentionSaveDebounce,
      () => unawaited(_flushIntention()),
    );
  }

  Future<void> _flushIntention() async {
    _intentionSaveTimer?.cancel();
    _intentionSaveTimer = null;
    final saver = widget.onSaveIntention;
    if (saver == null || !_intentionDirty) return;
    final intention = _intentionController.text.trim();
    if (intention == _lastSavedIntention) {
      _intentionDirty = false;
      return;
    }
    _intentionDirty = false;
    final operation = _intentionWriteTail.then((_) => saver(intention));
    _intentionWriteTail = operation.then<void>((_) {}, onError: (_, _) {});
    try {
      await operation;
      _lastSavedIntention = intention;
    } on Object {
      if (_intentionController.text.trim() == intention) {
        _intentionDirty = true;
      }
    }
  }

  void _onReflectionChanged() {
    if (widget.onWriteJournalResponse == null) return;
    _reflectionDirty = true;
    _reflectionSaveTimer?.cancel();
    _reflectionSaveTimer = Timer(
      widget.reflectionSaveDebounce,
      () => unawaited(_flushReflection()),
    );
  }

  Future<void> _flushReflection() async {
    _reflectionSaveTimer?.cancel();
    _reflectionSaveTimer = null;
    final writer = widget.onWriteJournalResponse;
    if (writer == null || !_reflectionDirty) return;
    final reflection = _reflectionController.text;
    if (reflection == _lastWrittenReflection) {
      _reflectionDirty = false;
      return;
    }
    _reflectionDirty = false;
    final sourceId = buildMaatFlowResponseSourceId(
      flowKey: kOfferingTableFlowKey,
      responseSpecId: 'offering-table-reflection',
      clientEventId: widget.clientEventId,
      localDate: widget.localDate,
      eventKey: 'day-${widget.day.dayNumber}',
    );
    final block = MaatJournalResponseBlock(
      sourceId: sourceId,
      text: reflection,
      localDate: widget.localDate,
      sourceMetadata: <String, dynamic>{
        'kind': 'offering_table_reflection',
        'flow_key': kOfferingTableFlowKey,
        'day': widget.day.dayNumber,
        if (widget.clientEventId?.trim().isNotEmpty == true)
          'client_event_id': widget.clientEventId!.trim(),
      },
    );
    final operation = _journalWriteTail.then((_) => writer(block));
    _journalWriteTail = operation.then<void>((_) {}, onError: (_, _) {});
    try {
      await operation;
      _lastWrittenReflection = reflection;
    } on Object {
      // CalendarPage's journal writer remains authoritative. A later edit or
      // close retries without introducing another Offering persistence path.
      if (mounted && _reflectionController.text == reflection) {
        _reflectionDirty = true;
      }
    }
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

  void _resetDay() {
    _intentionController.clear();
    _reflectionController.clear();
    setState(() {
      _placement = 0;
      _reflectionOpen = false;
      _contextGeneration += 1;
      for (final id in _checkedSteps.keys) {
        _checkedSteps[id] = false;
        if (widget.persistResponses) {
          kMaatFlowResponseDraftStore.rememberValue(
            flowKey: kOfferingTableFlowKey,
            value: MaatFlowResponseValue.checkbox(specId: id, checked: false),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayOneHeroHeight = MediaQuery.sizeOf(context).width < 350
        ? 488.0
        : 470.0;
    return InstrumentEventPresentationFrame(
      key: const ValueKey<String>('offering-table-day-presentation'),
      decoration: const BoxDecoration(color: _velvet),
      fixedHeroHeight: widget.day.dayNumber == 1 ? dayOneHeroHeight : 360,
      initialLowerSheetPeek: widget.day.dayNumber == 1 ? 28 : null,
      instrument: _buildCupHero(),
      instrumentFooter: _buildPlacementControl(),
      inputBuilder: (context, _, instrumentHeight) {
        if (widget.day.dayNumber == 1) return const SizedBox.shrink();
        return Stack(
          children: <Widget>[
            Positioned(
              top: 108,
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 43,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: InstrumentEventPresentationFrame.footerHeight,
                        child: _buildCupInput(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 57,
                    child: _OfferingHeroRitual(
                      steps: _presentation.steps,
                      checkedSteps: _checkedSteps,
                      stepId: _stepId,
                      onToggle: _toggleStep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      body: _buildBody(),
      bodyScrollKey: const ValueKey<String>('offering-table-presentation-body'),
      lowerSheetKey: const ValueKey<String>(
        'offering-table-static-lower-sheet',
      ),
    );
  }

  Widget _buildCupHero() {
    if (widget.day.dayNumber == 1) return _buildSmallSupplyHero();
    final stage = offeringTableStage(widget.day.dayNumber);
    final stageDay = ((widget.day.dayNumber - 1) % 10) + 1;
    final intention = _intentionController.text.trim();
    return Stack(
      key: const ValueKey<String>('offering-table-cup-hero'),
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          top: 108,
          left: 10,
          right: 10,
          bottom: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 43,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: _OfferingCupInstrumentPainter(
                        placement: _placement,
                        foreground: false,
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (intention.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final surfaceY = constraints.maxHeight * (168 / 238);
                        final wordTop =
                            constraints.maxHeight * (96 / 238) +
                            (_placement * constraints.maxHeight * (70 / 238));
                        final scale = 1 - (_placement * 0.18);
                        final fontSize = intention.length > 46
                            ? 14.5
                            : intention.length > 28
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
                                    intention,
                                    key: key,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.fade,
                                    style: TextStyle(
                                      color: color,
                                      fontFamily: _display,
                                      fontSize: fontSize,
                                      fontStyle: FontStyle.italic,
                                      height: intention.length > 46
                                          ? 1.24
                                          : 1.3,
                                      letterSpacing: 0.35,
                                      shadows: submerged
                                          ? const <Shadow>[
                                              Shadow(
                                                color: _water,
                                                blurRadius: 6,
                                              ),
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
                    CustomPaint(
                      painter: _OfferingCupInstrumentPainter(
                        placement: _placement,
                        foreground: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(flex: 57, child: SizedBox.expand()),
            ],
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
                        const SizedBox(height: 8),
                        Text(
                          _presentation.previewSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB9AA95),
                            fontFamily: _display,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.28,
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

  Widget _buildSmallSupplyHero() {
    return Container(
      key: const ValueKey<String>('offering-table-small-supply-hero'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF130C07), Color(0xFF0D0906)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Text(
                  '✦  THE OFFERING TABLE',
                  style: TextStyle(
                    color: Color(0xFFC7963A),
                    fontFamily: _ui,
                    fontSize: 8.5,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
              Text(
                '${_dateLabel(widget.localDate)}\nPERSONAL TABLE · DAY 01',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF816C4C),
                  fontFamily: _ui,
                  fontSize: 7.5,
                  height: 1.25,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.day.title,
                  key: const ValueKey<String>('offering-table-event-title'),
                  style: const TextStyle(
                    color: _bone,
                    fontFamily: _display,
                    fontSize: 27,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              Text(
                _formatMinute(widget.startMinute),
                style: const TextStyle(
                  color: Color(0xFFCBA268),
                  fontFamily: _display,
                  fontSize: 18,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _presentation.previewSummary,
            style: const TextStyle(
              color: Color(0xFFD7CDBA),
              fontFamily: _display,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 11),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const authoredHeight = 254.0;
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: math.min(authoredHeight, constraints.maxHeight),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: authoredHeight,
                        child: const Row(
                          children: <Widget>[
                            Expanded(
                              flex: 43,
                              child: OfferingTableSmallSupplyJarVisual(),
                            ),
                            SizedBox(width: 10),
                            Expanded(flex: 57, child: _SmallSupplyRitualCard()),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
    if (widget.day.dayNumber == 1) {
      return const _SmallSupplyInstrumentFooter();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(
            height: 28,
            child: Text(
              'Speak your intention into the water',
              key: ValueKey<String>('offering-table-placement-label'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: Color(0xC2E8B27C),
                fontFamily: _display,
                fontSize: 17,
                fontStyle: FontStyle.italic,
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
    if (widget.day.dayNumber == 1) return _buildSmallSupplyBody();
    final stage = offeringTableStage(widget.day.dayNumber);
    final stageDay = ((widget.day.dayNumber - 1) % 10) + 1;
    return Container(
      key: const ValueKey<String>('offering-table-foreground-layer'),
      padding: const EdgeInsets.only(bottom: 22),
      decoration: const BoxDecoration(
        color: _velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0x3AD4AE43))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${stage.name.toUpperCase()} · DAY $stageDay',
              style: const TextStyle(
                color: Color(0xFF95732D),
                fontFamily: _ui,
                fontSize: 8,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _presentation.previewSummary,
              style: const TextStyle(
                color: Color(0xFFD2C6B5),
                fontFamily: _display,
                fontSize: 17,
                height: 1.25,
              ),
            ),
            Container(
              key: const ValueKey<String>('offering-table-named-need'),
              margin: const EdgeInsets.only(top: 16),
              constraints: const BoxConstraints(minHeight: 49),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF332413))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const SizedBox(
                    width: 76,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10, right: 10),
                      child: Text(
                        'INTENTION',
                        style: TextStyle(
                          color: Color(0xFF81682E),
                          fontFamily: _ui,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>(
                        'offering-table-intention-field',
                      ),
                      controller: _intentionController,
                      cursorColor: const Color(0xFFF0C96A),
                      minLines: 1,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_flushIntention()),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(0, 5, 0, 8),
                        hintText: 'name it…',
                        hintStyle: TextStyle(
                          color: Color(0xFF5E564C),
                          fontFamily: _display,
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          height: 1.1,
                        ),
                      ),
                      style: const TextStyle(
                        color: Color(0xFFE8B27C),
                        fontFamily: _display,
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OfferingTableContextDisclosure(
              key: ValueKey<int>(_contextGeneration),
              context: _presentation.context,
              instruction: _presentation.instruction,
            ),
            InstrumentEventReflectionSection(
              key: const ValueKey<String>('offering-table-reflection-section'),
              open: _reflectionOpen,
              onToggle: () =>
                  setState(() => _reflectionOpen = !_reflectionOpen),
              prompt: _reflectionPrompt,
              controller: _reflectionController,
              fieldKey: const ValueKey<String>(
                'offering-table-reflection-field',
              ),
              style: _reflectionStyle,
              horizontalPadding: 0,
            ),
            const SizedBox(height: 26),
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

  Widget _buildSmallSupplyBody() {
    return Container(
      key: const ValueKey<String>('offering-table-foreground-layer'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B0805), Color(0xFF080604)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0x303A2C17))),
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
            top: 7,
            left: 0,
            right: 0,
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
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'PERSONAL · DAY 01',
                  style: TextStyle(
                    color: Color(0xFF95732D),
                    fontFamily: _ui,
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _presentation.instruction,
                  style: const TextStyle(
                    color: Color(0xFFD2C6B5),
                    fontFamily: _display,
                    fontSize: 17,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(minHeight: 49),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF332413)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const SizedBox(
                        width: 76,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'SUPPLY',
                            style: TextStyle(
                              color: Color(0xFF81682E),
                              fontFamily: _ui,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey<String>(
                            'offering-table-intention-field',
                          ),
                          controller: _intentionController,
                          cursorColor: const Color(0xFFF0C96A),
                          minLines: 1,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'supply…',
                            hintStyle: TextStyle(color: Color(0xFF5E564C)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 8),
                          ),
                          style: const TextStyle(
                            color: Color(0xFFE8B27C),
                            fontFamily: _display,
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 58),
                const OfferingTableCourseTrack(),
                const SizedBox(height: 141),
                OfferingTableContextDisclosure(
                  key: ValueKey<int>(_contextGeneration),
                  context: _presentation.context,
                  instruction: _presentation.instruction,
                ),
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey<String>('offering-table-day-reset'),
                      onPressed: _resetDay,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF5F5648),
                        padding: const EdgeInsets.only(left: 12),
                        textStyle: const TextStyle(
                          fontFamily: _ui,
                          fontSize: 12,
                        ),
                      ),
                      child: const Text('reset this day'),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x06C99A3D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x293E2E1C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'COMPLETION',
                        style: TextStyle(
                          color: Color(0xFFA88135),
                          fontFamily: _ui,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      widget.completionPanel,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _OfferingHeroRitual extends StatelessWidget {
  const _OfferingHeroRitual({
    required this.steps,
    required this.checkedSteps,
    required this.stepId,
    required this.onToggle,
  });

  final List<String> steps;
  final Map<String, bool> checkedSteps;
  final String Function(int index) stepId;
  final void Function(int index) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text(
          'TODAY',
          style: TextStyle(
            color: Color(0xFF9A7635),
            fontFamily: _OfferingTableDayPresentationState._ui,
            fontSize: 7.5,
            letterSpacing: 1.35,
          ),
        ),
        const SizedBox(height: 3),
        for (var index = 0; index < steps.length; index++)
          _OfferingChecklistStep(
            key: ValueKey<String>(stepId(index)),
            number: index + 1,
            text: steps[index],
            checked: checkedSteps[stepId(index)] ?? false,
            last: index == steps.length - 1,
            onTap: () => onToggle(index),
          ),
      ],
    );
  }
}

class _OfferingChecklistStep extends StatelessWidget {
  const _OfferingChecklistStep({
    super.key,
    required this.number,
    required this.text,
    required this.checked,
    required this.last,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool checked;
  final bool last;
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
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xC7302313))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? const Color(0xFFD4A13D) : Colors.transparent,
                  border: Border.all(
                    color: checked
                        ? const Color(0xFFE4B754)
                        : const Color(0xFF6B5327),
                  ),
                  boxShadow: checked
                      ? const <BoxShadow>[
                          BoxShadow(color: Color(0x47DCAB46), blurRadius: 8),
                        ]
                      : null,
                ),
                child: checked
                    ? const Text(
                        '✓',
                        style: TextStyle(
                          color: Color(0xFF161008),
                          fontFamily: _OfferingTableDayPresentationState._ui,
                          fontSize: 8,
                          height: 1,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: checked
                        ? const Color(0xFFDFD4C3)
                        : const Color(0xFFA89B89),
                    fontFamily: _OfferingTableDayPresentationState._display,
                    fontSize: 11.4,
                    height: 1.22,
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

class _SmallSupplyRitualCard extends StatelessWidget {
  const _SmallSupplyRitualCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          'TODAY',
          style: TextStyle(
            color: Color(0xFF9A7635),
            fontFamily: _OfferingTableDayPresentationState._ui,
            fontSize: 7.5,
            letterSpacing: 1.35,
          ),
        ),
        SizedBox(height: 3),
        _SmallSupplyLine('Name one supply running low.'),
        _SmallSupplyLine('Refill it, or write down the next step.'),
        _SmallSupplyLine('Put it in sight or set one reminder.'),
      ],
    );
  }
}

class _SmallSupplyLine extends StatelessWidget {
  const _SmallSupplyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xC4302313))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 13,
            height: 13,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6B5327), width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFA89B89),
                fontFamily: _OfferingTableDayPresentationState._display,
                fontSize: 11.4,
                height: 1.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfferingTableSmallSupplyJarVisual extends StatelessWidget {
  const OfferingTableSmallSupplyJarVisual({
    super.key,
    this.label = 'supply…',
    this.refilled = false,
    this.visible = false,
    this.complete = false,
  });

  final String label;
  final bool refilled;
  final bool visible;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: key ?? const ValueKey<String>('offering-table-small-supply-jar'),
      painter: _SmallSupplyJarPainter(
        label: label,
        refilled: refilled,
        visible: visible,
        complete: complete,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SmallSupplyJarPainter extends CustomPainter {
  const _SmallSupplyJarPainter({
    required this.label,
    required this.refilled,
    required this.visible,
    required this.complete,
  });

  final String label;
  final bool refilled;
  final bool visible;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 142, size.height / 204);
    canvas.save();
    canvas.translate(
      (size.width - 142 * scale) / 2,
      (size.height - 204 * scale) / 2,
    );
    canvas.scale(scale);

    final halo = Rect.fromCenter(
      center: const Offset(71, 110),
      width: 130,
      height: 124,
    );
    if (complete) {
      canvas.drawOval(
        halo,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[Color(0x57F0C96A), Color(0x00F0C96A)],
          ).createShader(halo),
      );
    }

    final jar = Path()
      ..moveTo(42, 43)
      ..lineTo(100, 43)
      ..lineTo(108, 60)
      ..lineTo(108, 157)
      ..quadraticBezierTo(71, 172, 34, 157)
      ..lineTo(34, 60)
      ..close();
    canvas.drawPath(
      jar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFC99A3D),
    );
    if (refilled) {
      canvas
        ..save()
        ..clipPath(jar)
        ..drawRect(
          const Rect.fromLTRB(34, 110, 108, 165),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFCBEAE6), Color(0xFF5A928D)],
            ).createShader(const Rect.fromLTRB(34, 110, 108, 165)),
        )
        ..restore();
      canvas.drawLine(
        const Offset(35, 111),
        const Offset(107, 111),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFFBFE4DF),
      );
    }
    final cap = Path()
      ..moveTo(42, 43)
      ..lineTo(48, 31)
      ..lineTo(94, 31)
      ..lineTo(100, 43);
    canvas.drawPath(
      cap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFC99A3D),
    );
    if (visible) {
      final provisionMark = Path()
        ..moveTo(112, 72)
        ..lineTo(131, 72)
        ..lineTo(131, 136)
        ..lineTo(112, 136)
        ..moveTo(117, 80)
        ..lineTo(126, 80);
      canvas.drawPath(
        provisionMark,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFF0C96A),
      );
    }
    canvas.drawLine(
      const Offset(45, 94),
      const Offset(97, 94),
      Paint()
        ..strokeWidth = .8
        ..color = const Color(0x57C99A3D),
    );
    final labelSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: refilled ? const Color(0xFFE8B27C) : const Color(0x61E8B27C),
        fontFamily: _OfferingTableDayPresentationState._display,
        fontSize: 9,
        fontStyle: FontStyle.italic,
      ),
    );
    final painter = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, Offset(71 - painter.width / 2, 79));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SmallSupplyJarPainter oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.refilled != refilled ||
      oldDelegate.visible != visible ||
      oldDelegate.complete != complete;
}

class _SmallSupplyInstrumentFooter extends StatelessWidget {
  const _SmallSupplyInstrumentFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 11),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0906),
        border: Border(top: BorderSide(color: Color(0xFF302313))),
      ),
      child: const Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'THE SUPPLY IN VIEW  ·  Medication, groceries, soap…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFD7CDBA),
                fontFamily: _OfferingTableDayPresentationState._display,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Text(
            'PERSONAL · 01',
            style: TextStyle(
              color: Color(0xFFC99A3D),
              fontFamily: _OfferingTableDayPresentationState._ui,
              fontSize: 8,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class OfferingTableCourseTrack extends StatelessWidget {
  const OfferingTableCourseTrack({
    super.key,
    this.dayNumber = 1,
    this.stageLabel = 'PERSONAL',
  });

  final int dayNumber;
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              for (var index = 1; index <= 30; index++)
                Expanded(
                  child: Align(
                    child: Transform.rotate(
                      angle: index % 10 == 0 ? .7853981633974483 : 0,
                      child: Container(
                        width: index % 10 == 0
                            ? 7
                            : index == dayNumber
                            ? 5
                            : 4,
                        height: index % 10 == 0
                            ? 7
                            : index == dayNumber
                            ? 5
                            : 4,
                        decoration: BoxDecoration(
                          color: index < dayNumber
                              ? const Color(0xFF8A7030)
                              : index == dayNumber
                              ? const Color(0xFFF0C96A)
                              : const Color(0xFF2C2318),
                          shape: index % 10 == 0
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          border: index % 10 == 0
                              ? Border.all(color: const Color(0xFF4B3B1F))
                              : null,
                          boxShadow: index == dayNumber
                              ? const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x75F0C96A),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          stageLabel,
          style: const TextStyle(
            color: Color(0xFF8F6D2C),
            fontFamily: _OfferingTableDayPresentationState._ui,
            fontSize: 8,
            letterSpacing: 1.2,
          ),
        ),
      ],
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
