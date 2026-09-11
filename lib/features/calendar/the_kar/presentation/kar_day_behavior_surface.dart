import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../widgets/keyboard_aware.dart';
import '../../maat_flow_visual_tokens.dart';
import '../../presentation/instrument_event_presentation_frame.dart';
import '../kar_repository.dart';
import '../the_kar_models.dart';
import 'kar_capture_editor.dart';
import 'kar_event_block_visual.dart';

class KarDayBehaviorSurface extends StatefulWidget {
  const KarDayBehaviorSurface({
    super.key,
    required this.repository,
    required this.netjer,
    required this.flowId,
    required this.stageIndex,
    this.onCompletionCommit,
    this.clock,
  });

  final KarRepository repository;
  final KarNetjer netjer;
  final int flowId;
  final int stageIndex;
  final Future<void> Function()? onCompletionCommit;
  final DateTime Function()? clock;

  @override
  State<KarDayBehaviorSurface> createState() => _KarDayBehaviorSurfaceState();
}

class _KarDayBehaviorSurfaceState extends State<KarDayBehaviorSurface> {
  KarShrine? _shrine;
  bool _loading = true;
  bool _saving = false;
  bool _showCue = false;
  bool _showArtifact = false;
  bool _replace = false;
  bool _walking = false;
  String? _captureMode;
  int _walkIndex = 0;
  final List<String> _outcomes = <String>[];

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  KarCycle? get _cycle {
    final shrine = _shrine;
    if (shrine == null) return null;
    for (final cycle in shrine.cycles.reversed) {
      if (cycle.flowId == widget.flowId) return cycle;
    }
    return shrine.activeCycle;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await widget.repository.loadOrCreate(widget.netjer);
      if (mounted) setState(() => _shrine = value);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(KarShrine Function(KarShrine value) mutation) async {
    if (_saving || _shrine == null) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.save(mutation(_shrine!));
      if (mounted) setState(() => _shrine = saved);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));

  Future<void> _finishReturn() async {
    await widget.onCompletionCommit?.call();
    if (mounted) Navigator.maybeOf(context)?.maybePop();
  }

  void _recordWalk(String outcome) {
    if (_outcomes.length == _walkIndex) {
      _outcomes.add(outcome);
    } else {
      _outcomes[_walkIndex] = outcome;
    }
    if (outcome == 'partial') {
      setState(() => _showCue = true);
      return;
    }
    if (outcome == 'revealed') {
      setState(() => _showArtifact = true);
      return;
    }
    _advanceWalk();
  }

  Future<void> _advanceWalk() async {
    if (_walkIndex < 4) {
      setState(() {
        _walkIndex += 1;
        _showCue = false;
        _showArtifact = false;
      });
      return;
    }
    final cycle = _cycle;
    if (cycle?.isActive == true) {
      await _mutate(
        (value) => value.completeWalk(now: _now, outcomes: _outcomes),
      );
    }
    await widget.onCompletionCommit?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 420,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AE43)),
        ),
      );
    }
    final cycle = _cycle;
    if (cycle == null) {
      return SizedBox(
        key: const ValueKey<String>('kar-day-missing-cycle'),
        height: 340,
        child: Center(
          child: Text(
            'This Kꜣr walk needs to be scheduled again from its detail sheet.',
            textAlign: TextAlign.center,
            style: _style(const Color(0xFFE8E2D6), 18, height: 1.35),
          ),
        ),
      );
    }
    return KeyboardAwareEditableSurface(
      child: Stack(
        children: <Widget>[
          InstrumentEventPresentationFrame(
            key: const ValueKey<String>('kar-day-presentation'),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.72),
                radius: 1.35,
                colors: <Color>[
                  Color(widget.netjer.deepValue),
                  const Color(0xFF0A0F11),
                  const Color(0xFF050504),
                ],
              ),
            ),
            initialLowerSheetPeek: 241.75,
            lowerSheetOverlaysInstrument: true,
            instrumentFooterHeight: 0,
            instrument: _buildHeroLayer(cycle),
            instrumentFooter: const SizedBox.shrink(),
            inputBuilder: (context, heroHeight, instrumentHeight) =>
                _buildHeroControls(cycle),
            body: _buildPracticeLayer(cycle),
            bodyScrollKey: const ValueKey<String>('kar-day-sheet-scroll'),
            lowerSheetKey: const ValueKey<String>('kar-practice-sheet'),
          ),
          if (_captureMode != null && widget.stageIndex != 5)
            _buildCaptureWindow(cycle, widget.stageIndex.clamp(0, 4)),
        ],
      ),
    );
  }

  bool _isReturn(KarCycle cycle) {
    if (widget.stageIndex == 5 || _replace) return false;
    return cycle.placements[widget.stageIndex.clamp(0, 4)].activeVersion !=
        null;
  }

  BoxDecoration _heroDecoration() => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF0C171B), Color(0xFF091114), Color(0xFF070B0D)],
      stops: <double>[0, .58, 1],
    ),
  );

  BoxDecoration _heroGlow() => BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(.68, -.84),
      radius: 1.25,
      colors: <Color>[
        Color(widget.netjer.accentValue).withValues(alpha: .13),
        Colors.transparent,
      ],
      stops: const <double>[0, .56],
    ),
  );

  Widget _buildHeroLayer(KarCycle cycle) {
    if (widget.stageIndex == 5) return _buildWalkHero(cycle);
    final stageIndex = widget.stageIndex.clamp(0, 4);
    final stage = kKarStages[stageIndex];
    final returning = _isReturn(cycle);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: _heroDecoration(),
      foregroundDecoration: _heroGlow(),
      child: returning
          ? Column(
              children: <Widget>[
                _KarDayMeta(
                  netjer: widget.netjer,
                  side: 'RETURN\n${stage.place.toUpperCase()}',
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 118,
                      height: 190,
                      child: KarDayShrineVisual(
                        color: Color(widget.netjer.accentValue),
                        placedStages: _placedStages(cycle),
                        currentStage: stageIndex,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _KarDayShrineStage(
              netjer: widget.netjer,
              cycle: cycle,
              stageIndex: stageIndex,
            ),
    );
  }

  Widget _buildHeroControls(KarCycle cycle) {
    if (widget.stageIndex == 5) {
      if (_walking) return const SizedBox.shrink();
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: Align(
              alignment: const Alignment(.55, .3),
              child: Semantics(
                button: true,
                label: 'Begin the Kꜣr walk',
                child: GestureDetector(
                  key: const ValueKey<String>('kar-begin-walk'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _walking = true),
                  child: const SizedBox(width: 205, height: 118),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (!_isReturn(cycle)) return const SizedBox.shrink();
    return Stack(
      children: <Widget>[
        Positioned(
          left: 146,
          right: 18,
          top: 174,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Is it here?',
                style: _style(
                  const Color(0xFFEEE7DB),
                  35,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 19),
              _ReturnButton(
                key: const ValueKey<String>('kar-return-here'),
                label: 'It’s here',
                primary: true,
                onTap: _finishReturn,
              ),
              _ReturnButton(
                key: const ValueKey<String>('kar-return-piece'),
                label: 'I have a piece',
                onTap: () => setState(() => _showCue = true),
              ),
              _ReturnButton(
                key: const ValueKey<String>('kar-return-not-yet'),
                label: 'Not yet',
                quiet: true,
                onTap: () => setState(() => _showArtifact = true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeLayer(KarCycle cycle) {
    if (widget.stageIndex == 5) {
      return _practiceShell(_buildWalkPractice(cycle));
    }
    final stageIndex = widget.stageIndex.clamp(0, 4);
    final active = cycle.placements[stageIndex].activeVersion;
    if (active != null && !_replace) {
      return _practiceShell(_buildReturnPractice(stageIndex, active.content));
    }
    return _practiceShell(_buildFreshPractice(cycle, stageIndex, active));
  }

  Widget _practiceShell(Widget child) => Container(
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      border: Border(
        top: BorderSide(
          color: Color(widget.netjer.accentValue).withValues(alpha: .21),
        ),
      ),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF0A0E0F), Color(0xFF07090A)],
      ),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0xA3000000),
          blurRadius: 32,
          offset: Offset(0, -15),
        ),
      ],
    ),
    child: Stack(
      children: <Widget>[
        const Positioned(left: 0, right: 0, top: 7, child: _SheetHandle()),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
          child: child,
        ),
      ],
    ),
  );

  Widget _buildFreshPractice(
    KarCycle cycle,
    int stageIndex,
    KarEntryVersion? active,
  ) {
    final stage = kKarStages[stageIndex];
    final draft = _shrine?.drafts['${cycle.id}:$stageIndex'];
    final promptParagraphs = _dayPromptParagraphs(
      widget.netjer.prompts[stageIndex],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${widget.netjer.name.toUpperCase()} · CYCLE ${cycle.sequence.toString().padLeft(2, '0')} · SITTING ${(stageIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
          style: _style(const Color(0xFF7198A4), 8, spacing: 1.7),
        ),
        const SizedBox(height: 7),
        Text(
          _dayTitle(widget.netjer, stageIndex),
          style: _style(const Color(0xFFE9E2D7), 23, weight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.only(bottom: 15),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x17232825))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < promptParagraphs.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == promptParagraphs.length - 1 ? 0 : 11,
                  ),
                  child: Text(
                    promptParagraphs[index],
                    style: _style(const Color(0xFFD9D2C7), 18.5, height: 1.38),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _KarCaptureChoice(
          netjer: widget.netjer,
          draft: draft,
          onDraw: () => setState(() => _captureMode = 'drawing'),
          onDescribe: () => setState(() => _captureMode = 'description'),
          onPlace: draft == null
              ? null
              : () => _placeDraft(cycle, stageIndex, active),
        ),
        const SizedBox(height: 18),
        _KarCourseBand(current: stageIndex, placedStages: _placedStages(cycle)),
      ],
    );
  }

  Future<void> _placeDraft(
    KarCycle cycle,
    int stageIndex,
    KarEntryVersion? active,
  ) async {
    await _mutate(
      (value) => value.placeDraft(
        stageIndex: stageIndex,
        cycleId: cycle.id,
        versionId: const Uuid().v4(),
        now: _now,
        source: active == null ? 'cycle_sitting' : 'return_replacement',
      ),
    );
    await widget.onCompletionCommit?.call();
    if (mounted) setState(() => _replace = false);
  }

  Widget _buildCaptureWindow(KarCycle cycle, int stageIndex) {
    final mode = _captureMode!;
    final stage = kKarStages[stageIndex];
    final draft = _shrine?.drafts['${cycle.id}:$stageIndex'];
    return Positioned.fill(
      key: const ValueKey<String>('kar-capture-window'),
      child: ColoredBox(
        color: const Color(0xB8000000),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _captureMode = null);
                  },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight - 12,
                  ),
                  child: Material(
                    color: const Color(0xFF090907),
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      side: BorderSide(
                        color: Color(
                          widget.netjer.accentValue,
                        ).withValues(alpha: .32),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${widget.netjer.name.toUpperCase()} · ${stage.place.toUpperCase()}',
                                    style: _style(
                                      const Color(0xFF8A7030),
                                      8,
                                      spacing: 1.5,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close capture',
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _captureMode = null);
                                },
                                icon: const Text(
                                  '×',
                                  style: TextStyle(
                                    color: Color(0xFF8D877E),
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            mode == 'drawing'
                                ? 'Draw what you picture'
                                : 'Describe what you picture',
                            style: _style(
                              const Color(0xFFECE5DA),
                              28,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            mode == 'drawing'
                                ? 'Bad drawings welcome.'
                                : 'A few words or a full scene. Both count.',
                            style: _style(
                              const Color(0xFF777169),
                              12,
                              style: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 14),
                          KarCaptureEditor(
                            key: ValueKey<String>(
                              'kar-capture-editor-$stageIndex-$mode',
                            ),
                            netjer: widget.netjer,
                            stageIndex: stageIndex,
                            initialDraft: draft,
                            initialMode: mode,
                            showHeading: false,
                            showModeSwitcher: false,
                            showPlaceAction: false,
                            onSaveDraft: (kind, content) => _mutate(
                              (value) => value.saveDraft(
                                stageIndex: stageIndex,
                                cycleId: cycle.id,
                                draft: KarDraft(
                                  kind: kind,
                                  content: content,
                                  savedAt: _now,
                                ),
                              ),
                            ),
                            onPlace: () async {},
                            onSaved: () {
                              FocusScope.of(context).unfocus();
                              setState(() => _captureMode = null);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnPractice(int stageIndex, String saved) {
    final stage = kKarStages[stageIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'THE ${stage.place.toUpperCase()}',
          style: _style(const Color(0xFF7198A4), 8, spacing: 1.7),
        ),
        const SizedBox(height: 7),
        Text(
          'Only ask for help if you need it.',
          style: _style(const Color(0xFFE9E2D7), 23, weight: FontWeight.w500),
        ),
        const SizedBox(height: 7),
        Text(
          'The place calls first. What you saved stays hidden.',
          style: _style(const Color(0xFF6D797C), 12, style: FontStyle.italic),
        ),
        if (_showCue) ...<Widget>[
          const SizedBox(height: 17),
          _RevealCard(
            label: 'A small cue',
            content: widget.netjer.partials[stageIndex],
            primaryLabel: 'It’s back',
            onPrimary: _finishReturn,
            secondaryLabel: 'Show me',
            onSecondary: () => setState(() => _showArtifact = true),
          ),
        ],
        if (_showArtifact) ...<Widget>[
          const SizedBox(height: 15),
          _RevealCard(
            label: 'What you placed here',
            content: saved,
            primaryLabel: 'Keep this place',
            onPrimary: _finishReturn,
            secondaryLabel: 'Make this place again',
            onSecondary: () => setState(() => _replace = true),
          ),
        ],
      ],
    );
  }

  Widget _buildWalkHero(KarCycle cycle) {
    final stage = _walking ? kKarStages[_walkIndex] : kKarStages[5];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: _heroDecoration(),
      foregroundDecoration: _heroGlow(),
      child: Column(
        children: <Widget>[
          _KarDayMeta(
            netjer: widget.netjer,
            side: _walking
                ? '${(_walkIndex + 1).toString().padLeft(2, '0')} OF 5\n${stage.place.toUpperCase()}'
                : 'DAY 30\nINNER CHAMBER',
          ),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 126,
                      child: KarDayShrineVisual(
                        color: const Color(0xFFD4AE43),
                        placedStages: _placedStages(cycle),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _walking ? stage.place : 'Walk the kꜣr',
                              style: _style(
                                const Color(0xFFEFE6D7),
                                31,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _walking
                                  ? 'Find this place before asking for what was saved.'
                                  : 'Enter at the threshold. Find the five places in order.',
                              style: _style(
                                const Color(0xFFA9A091),
                                17,
                                style: FontStyle.italic,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkPractice(KarCycle cycle) {
    if (!_walking) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'THE COMPLETE WALK',
            style: _style(const Color(0xFF7198A4), 8, spacing: 1.7),
          ),
          const SizedBox(height: 7),
          Text(
            'Five places. Nothing new to make.',
            style: _style(const Color(0xFFE9E2D7), 23, weight: FontWeight.w500),
          ),
          const SizedBox(height: 7),
          Text(
            'Only this cycle is walked. Dim historical places remain behind the route.',
            style: _style(const Color(0xFF6D797C), 12, style: FontStyle.italic),
          ),
        ],
      );
    }

    final placement = cycle.placements[_walkIndex].activeVersion;
    final stage = kKarStages[_walkIndex];
    if (placement == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${(_walkIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
            style: _style(const Color(0xFF7198A4), 8, spacing: 1.7),
          ),
          const SizedBox(height: 8),
          Text(
            'This place is open.',
            style: _style(const Color(0xFFE9E2D7), 25, weight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing from this cycle was placed here. Earlier cycles remain behind the place, but they are not part of this walk.',
            style: _style(const Color(0xFFC8C1B6), 17, height: 1.4),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              _outcomes.add('open');
              _advanceWalk();
            },
            child: const Text('Continue'),
          ),
          const SizedBox(height: 12),
          Text(
            '${_walkIndex + 1} of 5',
            textAlign: TextAlign.center,
            style: _style(const Color(0xFF657B82), 10),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${(_walkIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
          style: _style(const Color(0xFF7198A4), 8, spacing: 1.7),
        ),
        const SizedBox(height: 8),
        Text(
          'Is it here?',
          style: _style(const Color(0xFFE9E2D7), 28, weight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        _ReturnButton(
          label: 'It’s here',
          primary: true,
          onTap: () => _recordWalk('recalled'),
        ),
        _ReturnButton(
          label: 'I have a piece',
          onTap: () => _recordWalk('partial'),
        ),
        _ReturnButton(
          label: 'Not yet',
          quiet: true,
          onTap: () => _recordWalk('revealed'),
        ),
        if (_showCue) ...<Widget>[
          const SizedBox(height: 12),
          _RevealCard(
            label: 'A small cue',
            content: widget.netjer.partials[_walkIndex],
            primaryLabel: 'It’s back',
            onPrimary: _advanceWalk,
            secondaryLabel: 'Show me',
            onSecondary: () => setState(() => _showArtifact = true),
          ),
        ],
        if (_showArtifact) ...<Widget>[
          const SizedBox(height: 12),
          _RevealCard(
            label: 'What you placed here',
            content: placement.content,
            primaryLabel: 'Continue',
            onPrimary: _advanceWalk,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${_walkIndex + 1} of 5',
          textAlign: TextAlign.center,
          style: _style(const Color(0xFF657B82), 10),
        ),
      ],
    );
  }

  Set<int> _placedStages(KarCycle cycle) => <int>{
    for (final placement in cycle.placements)
      if (placement.activeVersion != null) placement.stageIndex,
  };
}

class _KarDayMeta extends StatelessWidget {
  const _KarDayMeta({required this.netjer, required this.side});

  final KarNetjer netjer;
  final String side;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 7,
              height: 7,
              child: CustomPaint(painter: _KarSparklePainter()),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'THE KꜣR · ${netjer.name.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(
                  const Color(0xFF96BBC7),
                  8.4,
                  spacing: 1.8,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Text(
        side,
        textAlign: TextAlign.right,
        style: _style(const Color(0xFF647A82), 8, spacing: .65, height: 1.5),
      ),
    ],
  );
}

// Reuses the four-point path geometry established by Follow the Sky instead
// of relying on a font glyph whose availability varies by platform.
class _KarSparklePainter extends CustomPainter {
  const _KarSparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(center.dx + .7, center.dy - .7, size.width, center.dy)
      ..quadraticBezierTo(
        center.dx + .7,
        center.dy + .7,
        center.dx,
        size.height,
      )
      ..quadraticBezierTo(center.dx - .7, center.dy + .7, 0, center.dy)
      ..quadraticBezierTo(center.dx - .7, center.dy - .7, center.dx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF96BBC7));
  }

  @override
  bool shouldRepaint(covariant _KarSparklePainter oldDelegate) => false;
}

class _KarDayShrineStage extends StatelessWidget {
  const _KarDayShrineStage({
    required this.netjer,
    required this.cycle,
    required this.stageIndex,
  });

  final KarNetjer netjer;
  final KarCycle cycle;
  final int stageIndex;

  @override
  Widget build(BuildContext context) {
    final accent = Color(netjer.accentValue);
    final accent2 = Color(netjer.accent2Value);
    final placedStages = <int>{
      for (final placement in cycle.placements)
        if (placement.activeVersion != null) placement.stageIndex,
    };
    final stage = kKarStages[stageIndex];
    final placeNumber = (stageIndex + 1).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
      child: Container(
        key: const ValueKey<String>('kar-day-shrine-stage'),
        constraints: const BoxConstraints(minHeight: 308),
        decoration: BoxDecoration(
          color: const Color(0xFF050504),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AE43).withValues(alpha: .28),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0AD4AE43),
              spreadRadius: -7,
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AE43).withValues(alpha: .055),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 27,
              child: Center(
                child: SizedBox(
                  width: 248,
                  height: 225,
                  child: KarShrineVisual(
                    color: accent,
                    placed: cycle.placedCount,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 17,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${netjer.name} kꜣr',
                            style: _style(const Color(0xFF9A8040), 10.5),
                          ),
                          TextSpan(
                            text:
                                ' · Cycle ${cycle.sequence} · ${placedStages.length} / 5',
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(
                        const Color(0xFF62562F),
                        10.5,
                        style: FontStyle.italic,
                        height: 1.18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$placeNumber · ${stage.place}',
                    textAlign: TextAlign.right,
                    style: _style(
                      Color.alphaBlend(
                        accent2.withValues(alpha: .68),
                        const Color(0xFF78683E),
                      ),
                      10.5,
                      style: FontStyle.italic,
                      height: 1.18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KarCourseBand extends StatelessWidget {
  const _KarCourseBand({required this.current, required this.placedStages});

  final int current;
  final Set<int> placedStages;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 23),
    padding: const EdgeInsets.only(top: 18),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0x14232825))),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              for (var index = 0; index < 5; index++)
                Container(
                  width: 21,
                  height: 3,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: placedStages.contains(index)
                        ? const Color(0xFFC9E3EB)
                        : index == current
                        ? const Color(0xFF91B7C7)
                        : const Color(0xFF243238),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Text(
          '${placedStages.length} of 5 this cycle',
          style: _style(const Color(0xFF657B82), 8, spacing: 1),
        ),
      ],
    ),
  );
}

class _KarCaptureChoice extends StatelessWidget {
  const _KarCaptureChoice({
    required this.netjer,
    required this.draft,
    required this.onDraw,
    required this.onDescribe,
    required this.onPlace,
  });

  final KarNetjer netjer;
  final KarDraft? draft;
  final VoidCallback onDraw;
  final VoidCallback onDescribe;
  final Future<void> Function()? onPlace;

  @override
  Widget build(BuildContext context) {
    final accent = Color(netjer.accentValue);
    final accent2 = Color(netjer.accent2Value);
    final drawingReady = draft?.kind == 'drawing';
    final descriptionReady = draft?.kind == 'description';
    return Container(
      padding: const EdgeInsets.only(top: 15),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x12E8E2D6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'KEEP THE SCENE',
            style: _style(const Color(0xFF7198A4), 8, spacing: 1.55),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _CaptureChoiceButton(
                  label: drawingReady ? 'Draw  ✓' : 'Draw',
                  ready: drawingReady,
                  accent: accent,
                  accent2: accent2,
                  onTap: onDraw,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CaptureChoiceButton(
                  label: descriptionReady ? 'Describe  ✓' : 'Describe',
                  ready: descriptionReady,
                  accent: accent,
                  accent2: accent2,
                  onTap: onDescribe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: OutlinedButton(
              key: const ValueKey<String>('kar-place-draft'),
              onPressed: onPlace == null ? null : () => onPlace!(),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent2,
                disabledForegroundColor: accent2.withValues(alpha: .28),
                side: BorderSide(color: accent.withValues(alpha: .43)),
                shape: const StadiumBorder(),
              ),
              child: const Text('Place in the kꜣr'),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'One is enough.',
            textAlign: TextAlign.center,
            style: _style(
              const Color(0xFF5D676A),
              10.5,
              style: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureChoiceButton extends StatelessWidget {
  const _CaptureChoiceButton({
    required this.label,
    required this.ready,
    required this.accent,
    required this.accent2,
    required this.onTap,
  });

  final String label;
  final bool ready;
  final Color accent;
  final Color accent2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 47,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: ready ? accent2 : const Color(0xFFAEB8B8),
        backgroundColor: ready
            ? accent.withValues(alpha: .045)
            : const Color(0xFF080B0C),
        side: BorderSide(
          color: ready
              ? accent.withValues(alpha: .52)
              : const Color(0x29E8E2D6),
        ),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: _style(ready ? accent2 : const Color(0xFFAEB8B8), 16),
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 46,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF3A372E),
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _ReturnButton extends StatelessWidget {
  const _ReturnButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.quiet = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool quiet;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary
            ? const Color(0xFFC9E3EB)
            : quiet
            ? const Color(0xFF636D70)
            : const Color(0xFF83939A),
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: primary ? const Color(0x6B91B7C7) : const Color(0x29725D2B),
        ),
        minimumSize: const Size.fromHeight(42),
      ),
      child: Text(label),
    ),
  );
}

String _dayTitle(KarNetjer netjer, int stageIndex) {
  if (netjer == KarNetjer.djehuty && stageIndex == 0) return 'Wisdom';
  return netjer.labels[stageIndex];
}

List<String> _dayPromptParagraphs(String prompt) {
  final sentences = prompt
      .split(RegExp(r'(?<=\.)\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return sentences.isEmpty ? <String>[prompt] : sentences;
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.label,
    required this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });
  final String label;
  final String content;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF070706),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0x33725D2B)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: _style(const Color(0xFF8A7030), 9.5, spacing: 1.15),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: _style(
            const Color(0xFFD6D0C6),
            16,
            style: FontStyle.italic,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AE43),
                  foregroundColor: const Color(0xFF050504),
                ),
                child: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

TextStyle _style(
  Color color,
  double size, {
  double? spacing,
  double? height,
  FontStyle? style,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  color: color,
  fontFamily: KarFlowVisualTokens.fontFamily,
  fontFamilyFallback: KarFlowVisualTokens.fontFallback,
  fontSize: size,
  fontWeight: weight,
  fontStyle: style,
  letterSpacing: spacing,
  height: height,
);
