import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../widgets/keyboard_aware.dart';
import '../../../../widgets/maat_flow_date_picker.dart';
import '../../maat_flow_visual_tokens.dart';
import '../../presentation/maat_flow_detail_shell.dart';
import '../kar_repository.dart';
import '../the_kar_models.dart';
import 'kar_capture_editor.dart';
import 'kar_event_block_visual.dart';

typedef KarJoinCallback =
    Future<int> Function({
      required KarNetjer netjer,
      required String cycleId,
      required int cycleSequence,
      required DateTime startDate,
    });

typedef KarRescheduleCallback =
    Future<int> Function({
      required int oldFlowId,
      required KarNetjer netjer,
      required String cycleId,
      required int cycleSequence,
      required DateTime startDate,
    });

abstract final class KarDetailTokens {
  static const page = Color(0xFF050504);
  static const sheet = Color(0xFF090907);
  static const bone = Color(0xFFE8E2D6);
  static const gold = Color(0xFFD4AE43);
  static const goldDim = Color(0xFF8A7030);
  static const silver = Color(0xFF9E9A94);
  static const low = Color(0xFF6A6660);
  static const sep = Color(0xFF25231E);
  static const theme = MaatFlowDetailTheme(
    pageBackground: page,
    sheetBackground: sheet,
    sheetBorder: Color(0x5791B7C7),
    accent: Color(0xFF91B7C7),
    primaryText: bone,
    secondaryText: silver,
    mutedText: low,
    separator: sep,
    glow: Color(0xFFC9E3EB),
  );
}

class KarDetailSurface extends StatefulWidget {
  const KarDetailSurface({
    super.key,
    required this.repository,
    required this.onJoin,
    this.onReschedule,
    this.initialNetjer = KarNetjer.djehuty,
    this.joinedFlowId,
    this.joinedStartDate,
    this.onBack,
    this.clock,
  });

  final KarRepository repository;
  final KarJoinCallback onJoin;
  final KarRescheduleCallback? onReschedule;
  final KarNetjer initialNetjer;
  final int? joinedFlowId;
  final DateTime? joinedStartDate;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<KarDetailSurface> createState() => _KarDetailSurfaceState();
}

class _KarDetailSurfaceState extends State<KarDetailSurface> {
  late KarNetjer _netjer;
  late DateTime _startDate;
  KarShrine? _shrine;
  int _loadSerial = 0;
  int? _expandedStage;
  String? _selectedCycleId;
  bool _joining = false;
  bool _rescheduling = false;
  bool _saving = false;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  KarCycle? get _cycle => _shrine?.activeCycle;
  KarCycle? get _visibleCycle {
    final shrine = _shrine;
    if (shrine == null) return null;
    final selectedCycleId = _selectedCycleId;
    if (selectedCycleId != null) {
      for (final cycle in shrine.cycles.reversed) {
        if (cycle.id == selectedCycleId) return cycle;
      }
    }
    return shrine.activeCycle;
  }

  bool get _hasActiveCycle => _cycle != null;
  bool get _needsResume {
    final cycle = _cycle;
    if (cycle == null || cycle.flowId == null) return false;
    return cycle.dateForStage(5).isBefore(DateUtils.dateOnly(_now));
  }

  @override
  void initState() {
    super.initState();
    _netjer = widget.initialNetjer;
    _startDate = DateUtils.dateOnly(
      widget.joinedStartDate ?? _now.add(const Duration(days: 1)),
    );
    unawaited(_loadShrine());
  }

  Future<void> _loadShrine() async {
    final serial = ++_loadSerial;
    final selected = _netjer;
    try {
      final shrine = await widget.repository.loadOrCreate(selected);
      if (!mounted || serial != _loadSerial || selected != _netjer) return;
      setState(() {
        _shrine = shrine;
        final cycle = shrine.activeCycle;
        if (cycle != null) {
          _selectedCycleId = cycle.id;
          _startDate = cycle.anchorDate;
        }
      });
    } catch (error) {
      if (!mounted || serial != _loadSerial) return;
      _showError(error);
    }
  }

  Future<void> _selectNetjer(KarNetjer value) async {
    if (value == _netjer) return;
    setState(() {
      _netjer = value;
      _shrine = null;
      _expandedStage = null;
      _selectedCycleId = null;
    });
    await _loadShrine();
  }

  Future<void> _pickStart() async {
    if (_cycle != null) return;
    final result = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _startDate,
      initialMode: MaatFlowDatePickerMode.gregorian,
    );
    if (result != null && mounted) setState(() => _startDate = result.date);
  }

  Future<void> _join() async {
    if (_joining || _cycle != null) return;
    final shrine = _shrine;
    if (shrine == null) return;
    setState(() => _joining = true);
    final cycleId = const Uuid().v4();
    try {
      final flowId = await widget.onJoin(
        netjer: _netjer,
        cycleId: cycleId,
        cycleSequence: shrine.cycles.length + 1,
        startDate: _startDate,
      );
      if (flowId <= 0) {
        throw StateError('The Kꜣr did not produce a calendar walk.');
      }
      final saved = await widget.repository.save(
        shrine.beginCycle(
          cycleId: cycleId,
          anchorDate: _startDate,
          flowId: flowId,
        ),
      );
      if (mounted) {
        setState(() {
          _shrine = saved;
          _selectedCycleId = cycleId;
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _reschedule() async {
    final cycle = _cycle;
    final callback = widget.onReschedule;
    if (_rescheduling || cycle?.flowId == null || callback == null) return;
    final result = await MaatFlowDatePicker.show(
      context: context,
      initialDate: DateUtils.dateOnly(_now.add(const Duration(days: 1))),
      initialMode: MaatFlowDatePickerMode.gregorian,
    );
    if (result == null || !mounted) return;
    setState(() => _rescheduling = true);
    try {
      final flowId = await callback(
        oldFlowId: cycle!.flowId!,
        netjer: _netjer,
        cycleId: cycle.id,
        cycleSequence: cycle.sequence,
        startDate: result.date,
      );
      if (flowId <= 0) {
        throw StateError('The Kꜣr walk was not scheduled again.');
      }
      final saved = await widget.repository.save(
        _shrine!.reanchor(anchorDate: result.date, flowId: flowId),
      );
      if (mounted) {
        setState(() {
          _shrine = saved;
          _startDate = DateUtils.dateOnly(result.date);
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _rescheduling = false);
    }
  }

  Future<void> _mutate(KarShrine Function(KarShrine value) mutation) async {
    if (_saving) return;
    final current = _shrine;
    if (current == null) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.save(mutation(current));
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

  @override
  Widget build(BuildContext context) {
    final accent = Color(_netjer.accentValue);
    final accent2 = Color(_netjer.accent2Value);
    final theme = MaatFlowDetailTheme(
      pageBackground: KarDetailTokens.page,
      sheetBackground: KarDetailTokens.sheet,
      sheetBorder: accent.withValues(alpha: .34),
      accent: accent,
      primaryText: KarDetailTokens.bone,
      secondaryText: KarDetailTokens.silver,
      mutedText: KarDetailTokens.low,
      separator: KarDetailTokens.sep,
      glow: accent2,
    );
    final hasHistory = _shrine?.cycles.isNotEmpty == true;
    final body = MaatFlowDetailShell(
      theme: theme,
      referenceHeroHeight: 236,
      referenceSheetOverlap: 24,
      scrollKey: const ValueKey<String>('kar-detail-scroll'),
      heroLayerKey: const ValueKey<String>('kar-hero-layer'),
      sheetKey: const ValueKey<String>('kar-shared-sheet'),
      hero: _KarHero(theme: theme),
      sheet: _buildSheet(accent, accent2),
      bottomDock: MaatFlowDetailDock(
        theme: theme,
        joined: _hasActiveCycle,
        busy: _joining,
        onPressed: _join,
        onJoinedPressed: () => setState(() => _expandedStage ??= 0),
        actionLabel: hasHistory ? 'Begin another cycle' : 'Carry this flow',
        actionNote: hasHistory
            ? '${_netjer.name} · ${_shrine!.cycles.where((cycle) => cycle.status == KarCycleStatus.completed).length} completed cycle${_shrine!.cycles.where((cycle) => cycle.status == KarCycleStatus.completed).length == 1 ? '' : 's'}'
            : '${_netjer.name} · first kꜣr · five scenes · one walk',
        joinedLabel: 'Continue this cycle',
        joinedNote:
            '${_netjer.name} · Cycle ${_cycle?.sequence ?? 1} · ${_cycle?.placedCount ?? 0} of 5${_needsResume ? ' · schedule needs a new anchor' : ''}',
        actionKey: const ValueKey<String>('kar-begin-cycle'),
        joinedKey: const ValueKey<String>('kar-cycle-joined'),
      ),
    );
    return Material(
      key: const ValueKey<String>('kar-detail-surface'),
      color: KarDetailTokens.page,
      child: KeyboardAwareEditableSurface(
        child: Stack(
          children: <Widget>[
            body,
            if (widget.onBack != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 6,
                left: 16,
                child: MaatFlowDetailBackButton(
                  key: const ValueKey<String>('kar-back'),
                  color: KarDetailTokens.gold,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.transparent,
                  size: 40,
                  iconSize: 27,
                  icon: Icons.chevron_left,
                  onPressed: widget.onBack!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(Color accent, Color accent2) {
    final cycle = _visibleCycle;
    final placed = cycle?.placedCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Handle(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CHOOSE A NETJER',
                      style: _style(KarDetailTokens.goldDim, 10, spacing: 1.75),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Historically informed reconstructions anchored in Early Dynastic and Old Kingdom evidence.',
                      style: _style(
                        const Color(0xFF625E56),
                        11,
                        style: FontStyle.italic,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_netjer.index + 1} of 6',
                style: _style(
                  const Color(0xFF615F59),
                  11,
                  style: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 408,
            child: ListView.separated(
              key: const ValueKey<String>('kar-netjer-carousel'),
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),
              itemCount: KarNetjer.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final value = KarNetjer.values[index];
                return _NetjerCard(
                  netjer: value,
                  selected: value == _netjer,
                  objectStatus: value == _netjer && cycle != null
                      ? 'Cycle ${cycle.sequence} · ${cycle.placedCount}/5'
                      : null,
                  onTap: () => _selectNetjer(value),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Swipe to browse',
                style: _style(
                  const Color(0xFF615F59),
                  11,
                  style: FontStyle.italic,
                ),
              ),
              Text('←   →', style: _style(KarDetailTokens.goldDim, 17)),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.only(left: 13),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accent.withValues(alpha: .42)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _netjer.phrase,
                  style: _style(
                    accent2,
                    22,
                    weight: FontWeight.w600,
                    style: FontStyle.italic,
                    height: 1.13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _netjer.flow,
                  style: _style(const Color(0xFF8F8B83), 13.5, height: 1.42),
                ),
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x12E8E2D6))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'THE MONTH',
                        style: _style(
                          KarDetailTokens.goldDim,
                          9.5,
                          spacing: 1.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Five short imagination sittings. Keep each as a drawing or description.',
                          style: _style(
                            KarDetailTokens.silver,
                            12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(_netjer.familiar, style: _style(accent, 10.5)),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Divider(color: KarDetailTokens.sep, height: 1),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'YOUR KꜣR',
                      style: _style(KarDetailTokens.goldDim, 10, spacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Five scenes live here',
                      style: _style(
                        KarDetailTokens.bone,
                        29,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$placed / 5', style: _style(accent, 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Each sitting adds one scene to the kꜣr. Touch the shrine to reveal its places. On Day 30, return through all five.',
            style: _style(KarDetailTokens.silver, 14.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          _ShrineStage(
            netjer: _netjer,
            placed: placed,
            onTap: cycle == null
                ? null
                : () => setState(() => _expandedStage = (_expandedStage ?? 0)),
          ),
          const SizedBox(height: 24),
          const _Contract(),
          const SizedBox(height: 24),
          _ArrivalCard(
            netjer: _netjer,
            onTap: cycle == null
                ? null
                : () => setState(() => _expandedStage = 0),
          ),
          if (_expandedStage != null && cycle != null) ...[
            const SizedBox(height: 14),
            _buildCapture(cycle, _expandedStage!),
          ],
          const SizedBox(height: 30),
          Text(
            'Thirty days',
            style: _style(KarDetailTokens.bone, 29, weight: FontWeight.w600),
          ),
          const SizedBox(height: 9),
          Text(
            'Five imagination sittings are spaced across the month. Day 30 is the first complete walk. After a scene is placed, Hꜣw can bring that place back later without asking for another entry.',
            style: _style(KarDetailTokens.silver, 14.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            'The first image arrives ${_hasActiveCycle ? 'on its saved date' : 'on ${DateFormat.MMMd().format(_startDate)}'}. The final sitting is a return through all five.',
            style: _style(accent2, 14, style: FontStyle.italic, height: 1.35),
          ),
          if (_needsResume && widget.onReschedule != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const ValueKey<String>('kar-reschedule-cycle'),
              onPressed: _rescheduling ? null : _reschedule,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _rescheduling ? 'Scheduling…' : 'Schedule this walk again',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent2,
                side: BorderSide(color: accent.withValues(alpha: .45)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Nothing moves until you choose a new start date.',
              textAlign: TextAlign.center,
              style: _style(KarDetailTokens.low, 11, style: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 18),
          _ThirtyDayStrip(
            startDate: _startDate,
            accent: accent,
            onChange: cycle == null ? _pickStart : null,
          ),
          const SizedBox(height: 24),
          Text(
            'The month',
            style: _style(KarDetailTokens.bone, 22, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < kKarStages.length; index++) ...[
            KarEventBlockVisual(
              netjer: _netjer,
              stageIndex: index,
              title: index == 5 ? 'Walk the kꜣr' : _netjer.labels[index],
              placedCount: placed,
              height: index == 5 ? 96 : 106,
              onTap: cycle == null || index == 5
                  ? null
                  : () => setState(() => _expandedStage = index),
            ),
            if (index < kKarStages.length - 1) const SizedBox(height: 12),
          ],
          if ((_shrine?.earlierCycles.length ?? 0) > 0) ...[
            const SizedBox(height: 28),
            Text(
              'Earlier walks',
              style: _style(KarDetailTokens.bone, 24, weight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            Text(
              'Earlier scenes remain accessible as history. They never fill an empty place in this walk.',
              style: _style(KarDetailTokens.silver, 14, height: 1.35),
            ),
            const SizedBox(height: 10),
            for (final history in _shrine!.earlierCycles)
              ListTile(
                key: ValueKey<String>('kar-history-cycle-${history.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Walk ${history.sequence}',
                  style: _style(accent2, 17),
                ),
                subtitle: Text(
                  '${DateFormat.yMMMd().format(history.anchorDate)} · ${history.placedCount} / 5 scenes · ${history.status.name}',
                  style: _style(KarDetailTokens.silver, 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: KarDetailTokens.goldDim,
                ),
                onTap: () => setState(() {
                  _selectedCycleId = history.id;
                  _startDate = history.anchorDate;
                  _expandedStage = 0;
                }),
              ),
          ],
          const SizedBox(height: 28),
          Text(
            'After the month',
            style: _style(KarDetailTokens.bone, 29, weight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            'The kꜣr stays available. When one of its places returns, Hꜣw asks what comes back before showing what you saved there.',
            style: _style(KarDetailTokens.silver, 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            'If a scene stops working for you, make that place again. The newest version is the one used in future walks.',
            style: _style(accent2, 17, style: FontStyle.italic, height: 1.35),
          ),
          const SizedBox(height: 24),
          const _WhyKar(),
        ],
      ),
    );
  }

  Widget _buildCapture(KarCycle cycle, int stageIndex) {
    final key = '${cycle.id}:$stageIndex';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Collapse scene editor',
            onPressed: () => setState(() => _expandedStage = null),
            icon: const Icon(
              Icons.keyboard_arrow_up,
              color: KarDetailTokens.gold,
            ),
          ),
        ),
        Text(
          '${_netjer.name.toUpperCase()} · SITTING ${(stageIndex + 1).toString().padLeft(2, '0')} · ${kKarStages[stageIndex].place.toUpperCase()}',
          style: _style(KarDetailTokens.goldDim, 10, spacing: 1.25),
        ),
        const SizedBox(height: 6),
        Text(
          _netjer.labels[stageIndex],
          style: _style(KarDetailTokens.bone, 28, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _netjer.prompts[stageIndex],
          style: _style(
            KarDetailTokens.bone,
            17,
            style: FontStyle.italic,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        KarCaptureEditor(
          netjer: _netjer,
          stageIndex: stageIndex,
          initialDraft: _shrine?.drafts[key],
          placed: cycle.placements[stageIndex].activeVersion != null,
          onSaveDraft: (kind, content) => _mutate(
            (value) => value.saveDraft(
              stageIndex: stageIndex,
              cycleId: cycle.id,
              draft: KarDraft(kind: kind, content: content, savedAt: _now),
            ),
          ),
          onPlace: () => _mutate(
            (value) => value.placeDraft(
              stageIndex: stageIndex,
              cycleId: cycle.id,
              versionId: const Uuid().v4(),
              now: _now,
            ),
          ),
        ),
      ],
    );
  }
}

class _KarHero extends StatelessWidget {
  const _KarHero({required this.theme});
  final MaatFlowDetailTheme theme;
  @override
  Widget build(BuildContext context) => MaatFlowDetailHero(
    theme: theme,
    background: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/the_kar/hero.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -.04),
          color: const Color(0xCCFFFFFF),
          colorBlendMode: BlendMode.modulate,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x22050504),
                Color(0x22050504),
                KarDetailTokens.page,
              ],
              stops: <double>[0, .55, 1],
            ),
          ),
        ),
      ],
    ),
    glyph: 'KꜣR',
    glyphContent: const Text(
      'KꜣR',
      style: TextStyle(
        color: Color(0xFFC9E3EB),
        fontFamily: MaatFlowListTokens.fontFamily,
        fontSize: 12,
        letterSpacing: 1.4,
      ),
    ),
    title: 'The Kꜣr',
    subtitle: '',
    contentBottom: 24,
    contentLeft: 23,
    titleFontSize: 44,
    glyphToTitleSpacing: 9,
  );
}

class _NetjerCard extends StatelessWidget {
  const _NetjerCard({
    required this.netjer,
    required this.selected,
    required this.objectStatus,
    required this.onTap,
  });
  final KarNetjer netjer;
  final bool selected;
  final String? objectStatus;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '${netjer.name}, ${netjer.role}',
    child: InkWell(
      key: ValueKey<String>('kar-netjer-${netjer.key}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        width: 306,
        height: 408,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: selected
                ? Color(netjer.accent2Value)
                : const Color(0x332E2B25),
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(netjer.asset, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Color(0x00050504),
                    Color(0x48050504),
                    Color(0xE8050504),
                    Color(0xFF080806),
                  ],
                  stops: <double>[0, .48, .62, .82, 1],
                ),
              ),
            ),
            Positioned(
              top: 13,
              left: 13,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x9E050504),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x24E8E2D6)),
                ),
                child: Text(
                  netjer.historicalSource,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style(
                    const Color(0xFFBDB5A6),
                    9.5,
                    spacing: .28,
                    height: 1.08,
                  ),
                ),
              ),
            ),
            if (objectStatus != null)
              Positioned(
                top: 13,
                right: 13,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 118),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xAD050504),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Color(netjer.accent2Value).withValues(alpha: .24),
                    ),
                  ),
                  child: Text(
                    objectStatus!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(
                      Color(netjer.accent2Value).withValues(alpha: .72),
                      8.5,
                      spacing: .55,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 17,
              right: 17,
              bottom: 15,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 8,
                          runSpacing: 4,
                          children: <Widget>[
                            Text(
                              netjer.name,
                              style: _style(
                                const Color(0xFFF6F0E7),
                                32,
                                weight: FontWeight.w600,
                                height: .95,
                              ),
                            ),
                            Text(
                              netjer.kemeticName,
                              style: _style(
                                Color(
                                  netjer.accent2Value,
                                ).withValues(alpha: .66),
                                13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          netjer.role,
                          style: _style(
                            selected
                                ? Color(
                                    netjer.accent2Value,
                                  ).withValues(alpha: .74)
                                : const Color(0xFF89857D),
                            12,
                            style: FontStyle.italic,
                            height: 1.15,
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
      ),
    ),
  );
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 11),
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF3A372E),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    ),
  );
}

class _ShrineStage extends StatelessWidget {
  const _ShrineStage({required this.netjer, required this.placed, this.onTap});
  final KarNetjer netjer;
  final int placed;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey<String>('kar-shrine-stage'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(19),
    child: Container(
      height: 302,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: Color(netjer.accentValue).withValues(alpha: .22),
        ),
        gradient: RadialGradient(
          colors: <Color>[Color(netjer.deepValue), KarDetailTokens.page],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            height: 218,
            child: KarShrineVisual(
              color: Color(netjer.accentValue),
              placed: placed,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: Text(
                    placed == 0 ? 'Touch the kꜣr' : '$placed scenes placed',
                    maxLines: 2,
                    style: _style(
                      Color(netjer.accent2Value),
                      10.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'the places appear when you touch it',
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    style: _style(
                      const Color(0xFF625E57),
                      10.5,
                      style: FontStyle.italic,
                    ),
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

class _WhyKar extends StatefulWidget {
  const _WhyKar();

  @override
  State<_WhyKar> createState() => _WhyKarState();
}

class _WhyKarState extends State<_WhyKar> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextButton(
        key: const ValueKey<String>('kar-why-toggle'),
        onPressed: () => setState(() => _open = !_open),
        style: TextButton.styleFrom(
          foregroundColor: KarDetailTokens.bone,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Row(
          children: <Widget>[
            Text('Why a kꜣr?', style: _style(KarDetailTokens.bone, 18)),
            const Spacer(),
            Text(_open ? '−' : '+', style: _style(KarDetailTokens.gold, 20)),
          ],
        ),
      ),
      if (_open) ...<Widget>[
        const SizedBox(height: 4),
        Text(
          'Kemetic cult images were kept in shrines and treated as visible bodies through which a divine presence could be encountered. Hꜣw borrows the enclosure—not the ancient rite—to give a chosen quality a stable place to live.',
          style: _style(KarDetailTokens.silver, 13, height: 1.45),
        ),
        const SizedBox(height: 10),
        Text(
          'The divine domains are historically grounded. Hꜣw uses them here as a modern imaginative lens for building a personal kꜣr.',
          style: _style(KarDetailTokens.silver, 13, height: 1.45),
        ),
      ],
    ],
  );
}

class _Contract extends StatelessWidget {
  const _Contract();
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (final item in const [
        '1 NETJER',
        '5 SCENES',
        '30 DAYS',
        '1 WALK',
      ]) ...[
        if (item != '1 NETJER')
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              color: KarDetailTokens.sep,
            ),
          ),
        Text(
          item,
          style: _style(
            KarDetailTokens.goldDim,
            8.5,
            spacing: .7,
            weight: FontWeight.w600,
          ),
        ),
      ],
    ],
  );
}

class _ArrivalCard extends StatelessWidget {
  const _ArrivalCard({required this.netjer, this.onTap});
  final KarNetjer netjer;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey<String>('kar-arrival-card'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(19),
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 82, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: Color(netjer.accentValue).withValues(alpha: .30),
        ),
        color: const Color(0xFF0B0A07),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '01 · Threshold',
                style: _style(KarDetailTokens.goldDim, 10, spacing: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                netjer.labels.first,
                style: _style(
                  const Color(0xFFFBF7EF),
                  29,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                netjer.prompts.first,
                style: _style(
                  const Color(0xFFD6D0C6),
                  17,
                  style: FontStyle.italic,
                  height: 1.31,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Keep it: drawing or description. One is enough.',
                style: _style(Color(netjer.accent2Value), 11.5),
              ),
            ],
          ),
          Positioned(
            right: -70,
            bottom: 0,
            width: 66,
            height: 70,
            child: KarShrineMark(color: Color(netjer.accentValue)),
          ),
        ],
      ),
    ),
  );
}

class _ThirtyDayStrip extends StatelessWidget {
  const _ThirtyDayStrip({
    required this.startDate,
    required this.accent,
    this.onChange,
  });
  final DateTime startDate;
  final Color accent;
  final VoidCallback? onChange;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      border: Border.all(color: accent.withValues(alpha: .22)),
      borderRadius: BorderRadius.circular(17),
      color: const Color(0xFF070706),
    ),
    child: Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '30-DAY WALK',
              style: _style(KarDetailTokens.goldDim, 9.5, spacing: 1.2),
            ),
            Flexible(
              child: TextButton(
                onPressed: onChange,
                child: Text(
                  onChange == null
                      ? DateFormat.MMMd().format(startDate)
                      : 'Begins ${DateFormat.MMMd().format(startDate)} · Change',
                  textAlign: TextAlign.end,
                  style: _style(accent, 11),
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 5,
          runSpacing: 7,
          children: <Widget>[
            for (var day = 1; day <= 30; day++)
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kKarStages.any((value) => value.day == day)
                      ? accent.withValues(alpha: .18)
                      : Colors.transparent,
                  border: kKarStages.any((value) => value.day == day)
                      ? Border.all(color: accent.withValues(alpha: .6))
                      : null,
                ),
                child: Text(
                  '$day',
                  style: _style(
                    kKarStages.any((value) => value.day == day)
                        ? accent
                        : const Color(0xFF625E57),
                    9.5,
                  ),
                ),
              ),
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
