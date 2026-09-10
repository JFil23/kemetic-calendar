import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../widgets/keyboard_aware.dart';
import '../../maat_flow_visual_tokens.dart';
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
      child: ColoredBox(
        color: const Color(0xFF090907),
        child: SingleChildScrollView(
          key: const ValueKey<String>('kar-day-sheet-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: widget.stageIndex == 5
              ? _buildWalk(cycle)
              : _buildScene(cycle),
        ),
      ),
    );
  }

  Widget _buildScene(KarCycle cycle) {
    final stageIndex = widget.stageIndex.clamp(0, 4);
    final stage = kKarStages[stageIndex];
    final placement = cycle.placements[stageIndex];
    final active = placement.activeVersion;
    final draft = _shrine?.drafts['${cycle.id}:$stageIndex'];
    if (active != null && !_replace) {
      return _buildReturn(cycle, stageIndex, active.content);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SheetHandle(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                '✦  THE KꜣR · ${widget.netjer.name.toUpperCase()}',
                style: _style(const Color(0xFF8A7030), 10, spacing: 1.1),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SITTING ${stageIndex + 1}\n${stage.place.toUpperCase()}',
              textAlign: TextAlign.right,
              style: _style(
                const Color(0xFF8A7030),
                9,
                spacing: .8,
                height: 1.25,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 258,
          child: Center(
            child: SizedBox(
              width: 246,
              height: 218,
              child: KarShrineVisual(
                color: Color(widget.netjer.accentValue),
                placed: cycle.placedCount,
              ),
            ),
          ),
        ),
        Text(
          '${widget.netjer.name.toUpperCase()} · SITTING ${(stageIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
          style: _style(const Color(0xFF8A7030), 10, spacing: 1.2),
        ),
        const SizedBox(height: 7),
        Text(
          widget.netjer.labels[stageIndex],
          style: _style(const Color(0xFFE8E2D6), 31, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          widget.netjer.prompts[stageIndex],
          style: _style(
            const Color(0xFFD6D0C6),
            18,
            style: FontStyle.italic,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        KarCaptureEditor(
          netjer: widget.netjer,
          stageIndex: stageIndex,
          initialDraft: draft,
          placed: active != null,
          onSaveDraft: (kind, content) => _mutate(
            (value) => value.saveDraft(
              stageIndex: stageIndex,
              cycleId: cycle.id,
              draft: KarDraft(kind: kind, content: content, savedAt: _now),
            ),
          ),
          onPlace: () async {
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
          },
        ),
      ],
    );
  }

  Widget _buildReturn(KarCycle cycle, int stageIndex, String saved) {
    final stage = kKarStages[stageIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SheetHandle(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                '✦  THE KꜣR · ${widget.netjer.name.toUpperCase()}',
                style: _style(const Color(0xFF8A7030), 10, spacing: 1.1),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'RETURN\n${stage.place.toUpperCase()}',
              textAlign: TextAlign.right,
              style: _style(
                const Color(0xFF8A7030),
                9,
                spacing: .8,
                height: 1.25,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            SizedBox(
              width: 125,
              height: 190,
              child: KarShrineMark(
                color: Color(widget.netjer.accentValue),
                placed: cycle.placedCount,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Is it here?',
                    style: _style(
                      const Color(0xFFE8E2D6),
                      31,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
        ),
        const SizedBox(height: 18),
        Text(
          'THE ${stage.place.toUpperCase()}',
          style: _style(const Color(0xFF8A7030), 10, spacing: 1.2),
        ),
        const SizedBox(height: 7),
        Text(
          'Only ask for help if you need it.',
          style: _style(const Color(0xFFE8E2D6), 27, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'The place calls first. What you saved stays hidden.',
          style: _style(const Color(0xFF625E57), 12, style: FontStyle.italic),
        ),
        if (_showCue) ...[
          const SizedBox(height: 15),
          _RevealCard(
            label: 'A small cue',
            content: widget.netjer.partials[stageIndex],
            primaryLabel: 'It’s back',
            onPrimary: _finishReturn,
            secondaryLabel: 'Show me',
            onSecondary: () => setState(() => _showArtifact = true),
          ),
        ],
        if (_showArtifact) ...[
          const SizedBox(height: 12),
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

  Widget _buildWalk(KarCycle cycle) {
    if (!_walking) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SheetHandle(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  '✦  THE KꜣR · ${widget.netjer.name.toUpperCase()}',
                  style: _style(const Color(0xFF8A7030), 10, spacing: 1.1),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'DAY 30\nINNER CHAMBER',
                textAlign: TextAlign.right,
                style: _style(
                  const Color(0xFF8A7030),
                  9,
                  spacing: .8,
                  height: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: Center(
              child: SizedBox(
                width: 175,
                height: 230,
                child: KarShrineMark(color: const Color(0xFFD4AE43), placed: 5),
              ),
            ),
          ),
          Text(
            'Walk the kꜣr',
            textAlign: TextAlign.center,
            style: _style(const Color(0xFFE8E2D6), 34, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter at the threshold. Find the five places in order.',
            textAlign: TextAlign.center,
            style: _style(const Color(0xFFC8C1B6), 17, height: 1.35),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey<String>('kar-begin-walk'),
            onPressed: () => setState(() => _walking = true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD4AE43),
              foregroundColor: const Color(0xFF050504),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Begin'),
          ),
          const SizedBox(height: 16),
          Text(
            'Five places. Nothing new to make.',
            style: _style(const Color(0xFFE8E2D6), 24, weight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            'The complete walk stays inside this sheet.',
            style: _style(const Color(0xFF625E57), 12, style: FontStyle.italic),
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
          const _SheetHandle(),
          Text(
            '${(_walkIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
            style: _style(const Color(0xFF8A7030), 10, spacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'This place is open.',
            style: _style(const Color(0xFFE8E2D6), 31, weight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing from this cycle was placed here. Earlier cycles remain behind the place, but they are not part of this walk.',
            style: _style(const Color(0xFFC8C1B6), 17, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
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
            style: _style(const Color(0xFF8A7030), 11),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SheetHandle(),
        Text(
          '${(_walkIndex + 1).toString().padLeft(2, '0')} · ${stage.place.toUpperCase()}',
          style: _style(const Color(0xFF8A7030), 10, spacing: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          stage.place,
          style: _style(const Color(0xFFE8E2D6), 34, weight: FontWeight.w600),
        ),
        const SizedBox(height: 22),
        Text(
          'Is it here?',
          style: _style(const Color(0xFFE8E2D6), 28, weight: FontWeight.w600),
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
        if (_showCue) ...[
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
        if (_showArtifact) ...[
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
          style: _style(const Color(0xFF8A7030), 11),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 46,
      height: 4,
      margin: const EdgeInsets.only(bottom: 18),
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
            ? const Color(0xFF050504)
            : quiet
            ? const Color(0xFF817C73)
            : const Color(0xFFC9E3EB),
        backgroundColor: primary ? const Color(0xFFC9E3EB) : Colors.transparent,
        side: const BorderSide(color: Color(0x55725D2B)),
        minimumSize: const Size.fromHeight(42),
      ),
      child: Text(label),
    ),
  );
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
  fontFamily: MaatFlowListTokens.fontFamily,
  fontFamilyFallback: MaatFlowListTokens.fontFallback,
  fontSize: size,
  fontWeight: weight,
  fontStyle: style,
  letterSpacing: spacing,
  height: height,
);
