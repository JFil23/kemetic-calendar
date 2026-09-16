import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/instrument_event_presentation_frame.dart';
import 'offering_table_day_contract.dart';
import 'offering_table_day_instrument.dart';
import 'offering_table_day_state.dart';

class OfferingTableDayV8Presentation extends StatefulWidget {
  const OfferingTableDayV8Presentation({
    super.key,
    required this.contract,
    required this.localDate,
    required this.startMinute,
    required this.initialState,
    required this.completionPanel,
    required this.onSaveState,
    this.courseStates = const <int, OfferingTableDayViewState>{},
    this.clock,
    this.saveDebounce = const Duration(milliseconds: 350),
  });

  final OfferingTableDayContract contract;
  final DateTime localDate;
  final int startMinute;
  final OfferingTableDayViewState initialState;
  final Map<int, OfferingTableDayViewState> courseStates;
  final Widget completionPanel;
  final Future<void> Function(OfferingTableDayViewState state) onSaveState;
  final DateTime Function()? clock;
  final Duration saveDebounce;

  @override
  State<OfferingTableDayV8Presentation> createState() =>
      _OfferingTableDayV8PresentationState();
}

class _OfferingTableDayV8PresentationState
    extends State<OfferingTableDayV8Presentation> {
  static const _velvet = Color(0xFF080604);
  static const _bone = Color(0xFFE8DED0);
  static const _goldGlow = Color(0xFFF0C96A);
  static const _display = 'CormorantGaramond';
  static const _ui = 'GentiumPlus';

  late OfferingTableDayViewState _state;
  final Map<String, TextEditingController> _wordControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _wordFocusNodes = <String, FocusNode>{};
  final Map<String, GlobalKey> _wordKeys = <String, GlobalKey>{};
  Timer? _saveTimer;
  Timer? _timerTicker;
  Future<void> _writeTail = Future<void>.value();
  bool _dirty = false;
  bool _syncingControllers = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toLocal();

  @override
  void initState() {
    super.initState();
    _state = widget.initialState.copy();
    for (final move in widget.contract.moves) {
      if (move.kind != OfferingTableMoveKind.name) continue;
      final id = move.slot ?? move.id;
      final controller = TextEditingController(text: _state.words[id] ?? '');
      controller.addListener(() => _onWordChanged(id, controller.text));
      _wordControllers[id] = controller;
      _wordFocusNodes[id] = FocusNode();
      _wordKeys[id] = GlobalKey();
    }
    _startTickerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OfferingTableDayV8Presentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dirty ||
        oldWidget.initialState.toJson().toString() ==
            widget.initialState.toJson().toString()) {
      return;
    }
    _state = widget.initialState.copy();
    _syncingControllers = true;
    for (final entry in _wordControllers.entries) {
      final next = _state.words[entry.key] ?? '';
      if (entry.value.text == next) continue;
      entry.value.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
    _syncingControllers = false;
    _startTickerIfNeeded();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _timerTicker?.cancel();
    unawaited(_flushState());
    for (final controller in _wordControllers.values) {
      controller.dispose();
    }
    for (final node in _wordFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onWordChanged(String id, String value) {
    if (_syncingControllers) return;
    _state.words[id] = value;
    setState(() {});
    _scheduleSave();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(widget.saveDebounce, () => unawaited(_flushState()));
  }

  Future<void> _flushState() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    final snapshot = _state.copy();
    final operation = _writeTail.then((_) => widget.onSaveState(snapshot));
    _writeTail = operation.then<void>((_) {}, onError: (_, _) {});
    try {
      await operation;
    } on Object {
      _dirty = true;
    }
  }

  void _startTickerIfNeeded() {
    final running = _state.timers.values.any((timer) => timer.isRunning);
    if (!running) {
      _timerTicker?.cancel();
      _timerTicker = null;
      return;
    }
    _timerTicker ??= Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _tickTimers(),
    );
  }

  void _tickTimers() {
    var changed = false;
    final now = _now;
    for (final move in widget.contract.moves) {
      if (move.kind != OfferingTableMoveKind.timer) continue;
      final timer = _state.timers[move.id];
      if (timer == null || !timer.isRunning) continue;
      final settled = timer.settle(now, move.targetSeconds ?? 0);
      if (!identical(settled, timer)) {
        _state.timers[move.id] = settled;
        changed = true;
      }
    }
    if (mounted) setState(() {});
    if (changed) _scheduleSave();
    _startTickerIfNeeded();
  }

  void _toggleAction(OfferingTableMoveContract move) {
    if (move.kind == OfferingTableMoveKind.name) {
      _focusWord(move.slot ?? move.id);
      return;
    }
    if (move.kind == OfferingTableMoveKind.pick) return;
    if (move.kind == OfferingTableMoveKind.timer) {
      final target = move.targetSeconds ?? 0;
      final current = _state.timers[move.id] ?? const OfferingTableTimerState();
      setState(() => _state.timers[move.id] = current.toggle(_now, target));
      _scheduleSave();
      _startTickerIfNeeded();
      return;
    }

    final next = !(_state.actions[move.id] ?? false);
    setState(() {
      _state.actions[move.id] = next;
      if (widget.contract.day == 8 && next) {
        if (move.id == 'portion') _state.actions['schedule'] = false;
        if (move.id == 'schedule') _state.actions['portion'] = false;
      }
      if (move.kind == OfferingTableMoveKind.drink) {
        if (next) {
          _state.timestamps[move.id] = _timeLabel(_now);
        } else {
          _state.timestamps.remove(move.id);
        }
      }
    });
    _scheduleSave();
  }

  void _selectPick(OfferingTableMoveContract move, String value) {
    setState(() {
      _state.picks[move.id] = _state.picks[move.id] == value ? '' : value;
    });
    _scheduleSave();
  }

  void _focusWord(String id) {
    final keyContext = _wordKeys[id]?.currentContext;
    if (keyContext == null) return;
    unawaited(
      Scrollable.ensureVisible(
        keyContext,
        alignment: .12,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
      ).then((_) {
        if (mounted) _wordFocusNodes[id]?.requestFocus();
      }),
    );
  }

  void _resetDay() {
    for (final controller in _wordControllers.values) {
      controller.clear();
    }
    setState(() => _state = OfferingTableDayViewState());
    _timerTicker?.cancel();
    _timerTicker = null;
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    return InstrumentEventPresentationFrame(
      key: const ValueKey<String>('offering-table-day-presentation-v8'),
      decoration: const BoxDecoration(color: _velvet),
      initialLowerSheetPeek: 28,
      instrumentFooterHeight: 0,
      instrument: _buildHero(now),
      instrumentFooter: const SizedBox.shrink(),
      inputBuilder: (context, heroHeight, _) => _buildHeroInputs(heroHeight),
      body: _buildPracticeLayer(now),
      bodyScrollKey: const ValueKey<String>('offering-table-presentation-body'),
      lowerSheetKey: const ValueKey<String>(
        'offering-table-layered-practice-sheet',
      ),
    );
  }

  Widget _buildHero(DateTime now) {
    return Container(
      key: const ValueKey<String>('offering-table-fixed-hero'),
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF130C07), Color(0xFF0D0906)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Semantics(
                      label: '✦',
                      child: const CustomPaint(
                        size: Size.square(7),
                        painter: _OfferingTableSparkPainter(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'THE OFFERING TABLE',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: Color(0xFFC7963A),
                          fontFamily: _ui,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_dateLabel(widget.localDate)}\n${widget.contract.stage.toUpperCase()} · DAY ${widget.contract.day.toString().padLeft(2, '0')}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF816C4C),
                  fontFamily: _ui,
                  fontSize: 8,
                  height: 1.55,
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
                  widget.contract.title,
                  key: const ValueKey<String>('offering-table-event-title'),
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                    color: Color(0xFFEFE5D8),
                    fontFamily: _display,
                    fontSize: 27,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatMinute(widget.startMinute),
                style: const TextStyle(
                  color: Color(0xFFA98348),
                  fontFamily: _display,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.contract.orientation,
            maxLines: 2,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: Color(0xFFB9AA95),
              fontFamily: _display,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 11),
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 238,
                maxHeight: 238,
                child: SizedBox(
                  height: 238,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 43,
                        child: Center(
                          child: SizedBox(
                            height: widget.contract.isWideInstrument
                                ? 204
                                : 226,
                            child: OfferingTableDayInstrument(
                              contract: widget.contract,
                              state: _state,
                              now: now,
                              courseStates: <int, OfferingTableDayViewState>{
                                ...widget.courseStates,
                                widget.contract.day: _state,
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(flex: 57, child: SizedBox.expand()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroInputs(double heroHeight) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: <Widget>[
            const Expanded(flex: 43, child: SizedBox.expand()),
            const SizedBox(width: 10),
            Expanded(
              flex: 57,
              child: CustomSingleChildLayout(
                delegate: const _OfferingMoveListLayout(centerY: 237),
                child: _MoveList(
                  contract: widget.contract,
                  state: _state,
                  now: () => _now,
                  onMove: _toggleAction,
                  onPick: _selectPick,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeLayer(DateTime now) {
    final complete = _state.dayComplete(widget.contract, now: now);
    final noMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      key: const ValueKey<String>('offering-table-foreground-layer'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B0805), Color(0xFF080604)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0x30C99A3D))),
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
                Text(
                  '${widget.contract.stage.toUpperCase()} · DAY ${widget.contract.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFF95732D),
                    fontFamily: _ui,
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.contract.instruction,
                  style: const TextStyle(
                    color: Color(0xFFD2C6B5),
                    fontFamily: _display,
                    fontSize: 17,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFields(),
                Container(
                  margin: const EdgeInsets.only(top: 29),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: const BoxDecoration(
                    color: Color(0xFF080604),
                    border: Border(top: BorderSide(color: Color(0x12C99A3D))),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Color(0xFF080604), spreadRadius: 20),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _OfferingTableV8CourseTrack(
                        dayNumber: widget.contract.day,
                        stageLabel: widget.contract.stage
                            .split(' ')
                            .first
                            .toUpperCase(),
                      ),
                      AnimatedOpacity(
                        key: const ValueKey<String>(
                          'offering-table-practice-returned',
                        ),
                        opacity: complete ? 1 : 0,
                        duration: noMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 550),
                        child: Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x47C99A3D)),
                            color: const Color(0x0FC99A3D),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: 'Provision returns to life through you.\n',
                              children: <InlineSpan>[
                                TextSpan(
                                  text: widget.contract.day < 30
                                      ? 'Day ${widget.contract.day + 1} arrives tomorrow at 7:30.'
                                      : 'The thirty-day table is complete.',
                                  style: const TextStyle(
                                    color: Color(0xFFA59D91),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              color: _bone,
                              fontFamily: _display,
                              fontSize: 18,
                              height: 1.32,
                            ),
                          ),
                        ),
                      ),
                      _OfferingTableV8ContextDisclosure(
                        contextCopy: widget.contract.context,
                        instruction: widget.contract.instruction,
                        disableAnimations: noMotion,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey<String>(
                            'offering-table-day-reset',
                          ),
                          onPressed: _resetDay,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF5F5648),
                            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
                            textStyle: const TextStyle(
                              fontFamily: _ui,
                              fontSize: 12,
                            ),
                          ),
                          child: const Text('reset this day'),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 22),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    final fields = widget.contract.moves
        .where((move) => move.kind == OfferingTableMoveKind.name)
        .toList(growable: false);
    if (fields.isEmpty) {
      return const Text(
        'No written field is required for this day.',
        style: TextStyle(
          color: Color(0xFF665D51),
          fontFamily: _display,
          fontSize: 14,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      );
    }
    return Column(
      children: <Widget>[for (final move in fields) _buildField(move)],
    );
  }

  Widget _buildField(OfferingTableMoveContract move) {
    final id = move.slot ?? move.id;
    return Container(
      key: _wordKeys[id],
      constraints: const BoxConstraints(minHeight: 49),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF332413))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 10),
              child: Text(
                move.fieldLabel ?? id.toUpperCase(),
                style: const TextStyle(
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
              key: ValueKey<String>('offering-table-field-$id'),
              controller: _wordControllers[id],
              focusNode: _wordFocusNodes[id],
              cursorColor: _goldGlow,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_flushState()),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(0, 5, 0, 8),
                hintText: move.placeholder ?? 'name it…',
                hintStyle: const TextStyle(
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
    );
  }

  static String _dateLabel(DateTime date) {
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

  static String _formatMinute(int minuteOfDay) {
    final hour24 = minuteOfDay ~/ 60;
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _OfferingTableSparkPainter extends CustomPainter {
  const _OfferingTableSparkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(center.dx + .5, center.dy - .5, size.width, center.dy)
      ..quadraticBezierTo(
        center.dx + .5,
        center.dy + .5,
        center.dx,
        size.height,
      )
      ..quadraticBezierTo(center.dx - .5, center.dy + .5, 0, center.dy)
      ..quadraticBezierTo(center.dx - .5, center.dy - .5, center.dx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFC7963A));
  }

  @override
  bool shouldRepaint(_OfferingTableSparkPainter oldDelegate) => false;
}

class _OfferingMoveListLayout extends SingleChildLayoutDelegate {
  const _OfferingMoveListLayout({required this.centerY});

  final double centerY;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(0, centerY - childSize.height / 2);

  @override
  bool shouldRelayout(covariant _OfferingMoveListLayout oldDelegate) =>
      oldDelegate.centerY != centerY;
}

class _OfferingTableV8CourseTrack extends StatelessWidget {
  const _OfferingTableV8CourseTrack({
    required this.dayNumber,
    required this.stageLabel,
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
              for (var day = 1; day <= 30; day++)
                Expanded(child: Align(child: _point(day))),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          stageLabel,
          style: const TextStyle(
            color: Color(0xFFA98136),
            fontFamily: 'GentiumPlus',
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _point(int day) {
    final seal = day % 10 == 0;
    final past = day < dayNumber;
    final current = day == dayNumber;
    final color = current
        ? const Color(0xFFFFD56C)
        : past
        ? seal
              ? const Color(0xFF6F5521)
              : const Color(0xFF7C6128)
        : const Color(0xFF2C2318);
    return Transform.rotate(
      angle: seal ? math.pi / 4 : 0,
      child: Container(
        width: seal
            ? 7
            : current
            ? 8
            : 4,
        height: seal
            ? 7
            : current
            ? 8
            : 4,
        decoration: BoxDecoration(
          color: seal && !past && !current ? Colors.transparent : color,
          shape: seal ? BoxShape.rectangle : BoxShape.circle,
          border: seal
              ? Border.all(
                  color: current
                      ? const Color(0xFFFFD56C)
                      : past
                      ? const Color(0xFF6F5521)
                      : const Color(0xFF493716),
                )
              : null,
          boxShadow: current
              ? const <BoxShadow>[
                  BoxShadow(color: Color(0x7AFFD56C), blurRadius: 10),
                ]
              : null,
        ),
      ),
    );
  }
}

class _OfferingTableV8ContextDisclosure extends StatefulWidget {
  const _OfferingTableV8ContextDisclosure({
    required this.contextCopy,
    required this.instruction,
    required this.disableAnimations,
  });

  final String contextCopy;
  final String instruction;
  final bool disableAnimations;

  @override
  State<_OfferingTableV8ContextDisclosure> createState() =>
      _OfferingTableV8ContextDisclosureState();
}

class _OfferingTableV8ContextDisclosureState
    extends State<_OfferingTableV8ContextDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF392817))),
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
              padding: const EdgeInsets.fromLTRB(2, 25, 2, 22),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Why this belongs at the Offering Table',
                      style: TextStyle(
                        color: Color(0xFFA99D8E),
                        fontFamily: 'CormorantGaramond',
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Text(
                    _expanded ? '−' : '+',
                    key: const ValueKey<String>(
                      'offering-table-day-sheet-context-sign',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFA99D8E),
                      fontFamily: 'GentiumPlus',
                      fontSize: 21,
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
              duration: widget.disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(widget.contextCopy, style: _bodyStyle),
                          const SizedBox(height: 12),
                          Text(widget.instruction, style: _bodyStyle),
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

  static const _bodyStyle = TextStyle(
    color: Color(0xFF766C60),
    fontFamily: 'GentiumPlus',
    fontSize: 13,
    height: 1.42,
  );
}

class _MoveList extends StatelessWidget {
  const _MoveList({
    required this.contract,
    required this.state,
    required this.now,
    required this.onMove,
    required this.onPick,
  });

  final OfferingTableDayContract contract;
  final OfferingTableDayViewState state;
  final DateTime Function() now;
  final ValueChanged<OfferingTableMoveContract> onMove;
  final void Function(OfferingTableMoveContract move, String value) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final move in contract.moves) _move(context, move),
      ],
    );
  }

  Widget _move(BuildContext context, OfferingTableMoveContract move) {
    final complete = state.moveDone(move, now: now());
    return Container(
      key: ValueKey<String>(
        'offering-table-day-${contract.day.toString().padLeft(2, '0')}-move-${move.id}',
      ),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xC4302313))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => onMove(move),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CustomPaint(
                    painter: _MoveMarkPainter(
                      complete: complete,
                      optional: move.optional,
                      drink: move.kind == OfferingTableMoveKind.drink,
                    ),
                    child: complete
                        ? const Icon(
                            Icons.check,
                            size: 9,
                            color: Color(0xFF171006),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    move.label,
                    style: TextStyle(
                      color: complete
                          ? const Color(0xFFDFD4C3)
                          : const Color(0xFFA89B89),
                      fontFamily: 'CormorantGaramond',
                      fontSize: 11.4,
                      height: 1.22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (move.kind == OfferingTableMoveKind.pick)
            Padding(
              padding: const EdgeInsets.only(left: 21, top: 5),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: <Widget>[
                  for (final option in move.options)
                    InkWell(
                      onTap: () => onPick(move, option),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: state.picks[move.id] == option
                              ? const Color(0xFF1B1208)
                              : const Color(0xFF100B06),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: state.picks[move.id] == option
                                ? const Color(0xFFB1853A)
                                : const Color(0xFF463319),
                          ),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            color: state.picks[move.id] == option
                                ? const Color(0xFFE2D5C1)
                                : const Color(0xFF8F8375),
                            fontFamily: 'GentiumPlus',
                            fontSize: 7.7,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (move.kind == OfferingTableMoveKind.timer)
            Padding(
              padding: const EdgeInsets.only(left: 21, top: 2),
              child: Text(
                _timerMeta(move),
                style: const TextStyle(
                  color: Color(0xFF685E52),
                  fontFamily: 'GentiumPlus',
                  fontSize: 7.7,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _timerMeta(OfferingTableMoveContract move) {
    final target = move.targetSeconds ?? 0;
    final timer = state.timers[move.id] ?? const OfferingTableTimerState();
    final elapsed = timer.elapsedAt(now()).clamp(0, target * 1000);
    final seconds = (elapsed / 1000).floor();
    final remaining = (target - seconds).clamp(0, target);
    return '${timer.isRunning
        ? 'tap to pause'
        : seconds > 0
        ? 'tap to resume'
        : 'tap to begin'} · ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  }
}

class _MoveMarkPainter extends CustomPainter {
  const _MoveMarkPainter({
    required this.complete,
    required this.optional,
    required this.drink,
  });

  final bool complete;
  final bool optional;
  final bool drink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 1) / 2;
    if (complete) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.fill
          ..color = drink ? const Color(0xFF83BEB9) : const Color(0xFFD4A13D),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFE4B754),
      );
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF6B5327);
    if (!optional) {
      canvas.drawCircle(center, radius, paint);
      return;
    }
    const dashAngle = math.pi / 5;
    const gapAngle = math.pi / 8;
    var start = -math.pi / 2;
    while (start < math.pi * 1.5) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
      start += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MoveMarkPainter oldDelegate) =>
      oldDelegate.complete != complete ||
      oldDelegate.optional != optional ||
      oldDelegate.drink != drink;
}
