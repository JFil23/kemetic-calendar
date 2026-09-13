import 'dart:async';

import 'package:flutter/material.dart';

import '../../maat_flow_response_draft_store.dart';
import '../../maat_flow_response_models.dart';
import '../../the_djed_v2_flow.dart';
import 'djed_day_presentation.dart';
import 'djed_detail_page.dart';

class DjedDayBehaviorSurface extends StatefulWidget {
  const DjedDayBehaviorSurface({
    super.key,
    required this.flowId,
    required this.event,
    required this.baseFixture,
    required this.supports,
    required this.onCompletionCommit,
    required this.onPutOnCalendar,
  });

  final int flowId;
  final DjedV2Event event;
  final DjedDayVisualFixture baseFixture;
  final List<DjedSupportFixture> supports;
  final Future<void> Function(
    DjedCompletionVisualState state,
    String move,
    DjedResultVisualState result,
    String resultNote,
    String smallerMove,
    bool raised,
  )
  onCompletionCommit;
  final Future<void> Function() onPutOnCalendar;

  @override
  State<DjedDayBehaviorSurface> createState() => _DjedDayBehaviorSurfaceState();
}

class _DjedDayBehaviorSurfaceState extends State<DjedDayBehaviorSurface> {
  late String _move;
  late DjedResultVisualState _result;
  DjedCompletionVisualState _completion = DjedCompletionVisualState.none;
  late String _resultNote;
  late String _smallerMove;
  late bool _raised;
  bool _raisingActive = false;
  int _raisingSecondsRemaining = 30;
  Timer? _raisingTimer;

  String get _draftScope => 'the-djed:v2:${widget.flowId}';
  int get _supportSlot => widget.event.supportSlot ?? 1;
  String get _moveSpecId => 'support-$_supportSlot-move';
  String get _resultSpecId => 'support-$_supportSlot-result';
  String get _resultNoteSpecId => 'support-$_supportSlot-result-note';
  String get _smallerMoveSpecId => 'support-$_supportSlot-smaller-move';
  String get _raisedSpecId => 'final-raising-complete';

  @override
  void initState() {
    super.initState();
    _hydrateDrafts();
  }

  @override
  void didUpdateWidget(covariant DjedDayBehaviorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.event.semanticStepId != widget.event.semanticStepId) {
      _completion = DjedCompletionVisualState.none;
      _hydrateDrafts();
    }
  }

  void _hydrateDrafts() {
    final values = kMaatFlowResponseDraftStore.valuesForFlow(_draftScope);
    _move = values[_moveSpecId]?.text?.trim() ?? widget.baseFixture.move;
    final resultIds = values[_resultSpecId]?.optionIds ?? const <String>[];
    _result = resultIds.isEmpty
        ? widget.baseFixture.result
        : _resultFromKey(resultIds.first);
    _resultNote = values[_resultNoteSpecId]?.text?.trim() ?? '';
    _smallerMove = values[_smallerMoveSpecId]?.text?.trim() ?? '';
    _raised = values[_raisedSpecId]?.checked == true;
  }

  void _saveMove(String value) {
    setState(() => _move = value);
    kMaatFlowResponseDraftStore.rememberValue(
      flowKey: _draftScope,
      value: MaatFlowResponseValue.text(specId: _moveSpecId, text: value),
    );
  }

  void _selectResult(DjedResultVisualState result) {
    setState(() => _result = result);
    kMaatFlowResponseDraftStore.rememberValue(
      flowKey: _draftScope,
      value: MaatFlowResponseValue.choice(
        specId: _resultSpecId,
        optionId: _resultKey(result),
      ),
    );
  }

  void _saveText(String specId, String value, void Function(String) update) {
    setState(() => update(value));
    kMaatFlowResponseDraftStore.rememberValue(
      flowKey: _draftScope,
      value: MaatFlowResponseValue.text(specId: specId, text: value),
    );
  }

  void _closeBeam() {
    if (_result == DjedResultVisualState.notDone &&
        _smallerMove.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Make the move smaller first.')),
      );
      return;
    }
    if (_result == DjedResultVisualState.notDone) {
      _saveMove(_smallerMove);
    }
  }

  void _beginRaising() {
    if (_raisingActive || _raised) return;
    setState(() {
      _raisingActive = true;
      _raisingSecondsRemaining = 30;
    });
    _raisingTimer?.cancel();
    _raisingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_raisingSecondsRemaining > 1) {
        setState(() => _raisingSecondsRemaining -= 1);
        return;
      }
      timer.cancel();
      setState(() {
        _raisingActive = false;
        _raisingSecondsRemaining = 0;
        _raised = true;
      });
      kMaatFlowResponseDraftStore.rememberValue(
        flowKey: _draftScope,
        value: MaatFlowResponseValue.checkbox(
          specId: _raisedSpecId,
          checked: true,
        ),
      );
    });
  }

  Future<void> _selectCompletion(DjedCompletionVisualState completion) async {
    setState(() => _completion = completion);
    if (completion == DjedCompletionVisualState.observed &&
        widget.event.finalRaising &&
        !_raised) {
      setState(() => _completion = DjedCompletionVisualState.none);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the 30-second raising before Observed.'),
        ),
      );
      return;
    }
    await widget.onCompletionCommit(
      completion,
      _move.trim(),
      _result,
      _resultNote.trim(),
      _smallerMove.trim(),
      _raised,
    );
  }

  @override
  void dispose() {
    _raisingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fixture = DjedDayVisualFixture(
      sittingNumber: widget.baseFixture.sittingNumber,
      stage: widget.baseFixture.stage,
      supportSlot: widget.baseFixture.supportSlot,
      supportName: widget.baseFixture.supportName,
      move: _move,
      result: _result,
      completion: _completion,
      resultNote: _resultNote,
      smallerMove: _smallerMove,
      raised: _raised,
      raisingActive: _raisingActive,
      raisingSecondsRemaining: _raisingSecondsRemaining,
    );
    return DjedDayPresentation(
      fixture: fixture,
      supports: widget.supports,
      onMoveChanged: _saveMove,
      onDoToday: () => _saveMove(_move),
      onPutOnCalendar: () => unawaited(widget.onPutOnCalendar()),
      onResultSelected: _selectResult,
      onResultNoteChanged: (value) =>
          _saveText(_resultNoteSpecId, value, (next) => _resultNote = next),
      onSmallerMoveChanged: (value) =>
          _saveText(_smallerMoveSpecId, value, (next) => _smallerMove = next),
      onCloseBeam: _closeBeam,
      onRaise: _beginRaising,
      onCompletionSelected: (value) => unawaited(_selectCompletion(value)),
    );
  }
}

String _resultKey(DjedResultVisualState result) => switch (result) {
  DjedResultVisualState.helped => 'helped',
  DjedResultVisualState.noChange => 'no_change',
  DjedResultVisualState.notDone => 'not_done',
  DjedResultVisualState.none => '',
};

DjedResultVisualState _resultFromKey(String key) => switch (key) {
  'helped' => DjedResultVisualState.helped,
  'no_change' => DjedResultVisualState.noChange,
  'not_done' => DjedResultVisualState.notDone,
  _ => DjedResultVisualState.none,
};
