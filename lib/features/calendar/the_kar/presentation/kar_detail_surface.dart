import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../widgets/kemetic_date_picker.dart';
import '../../../../widgets/maat_flow_date_picker.dart';
import '../../follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import '../../kemetic_month_metadata.dart';
import '../../maat_flow_visual_tokens.dart';
import '../../presentation/instrument_event_presentation_frame.dart';
import '../../presentation/maat_flow_detail_shell.dart';
import '../kar_repository.dart';
import '../the_kar_flow.dart';
import '../the_kar_models.dart';
import 'kar_day_behavior_surface.dart';
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
    this.calendarPreview = FollowSkyCalendarPreview.empty,
    this.onBack,
    this.clock,
  });

  final KarRepository repository;
  final KarJoinCallback onJoin;
  final KarRescheduleCallback? onReschedule;
  final KarNetjer initialNetjer;
  final int? joinedFlowId;
  final DateTime? joinedStartDate;
  final FollowSkyCalendarPreview calendarPreview;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<KarDetailSurface> createState() => _KarDetailSurfaceState();
}

class _KarDetailSurfaceState extends State<KarDetailSurface> {
  late KarNetjer _netjer;
  late DateTime _startDate;
  late final PageController _netjerPageController;
  KarShrine? _shrine;
  int _loadSerial = 0;
  String? _selectedCycleId;
  bool _joining = false;
  bool _rescheduling = false;

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
    _netjerPageController = PageController(
      initialPage: _netjer.index,
      viewportFraction: .92,
    );
    _startDate = DateUtils.dateOnly(
      widget.joinedStartDate ?? _now.add(const Duration(days: 1)),
    );
    unawaited(_loadShrine());
  }

  @override
  void dispose() {
    _netjerPageController.dispose();
    super.dispose();
  }

  Future<void> _loadShrine() async {
    final serial = ++_loadSerial;
    final selected = _netjer;
    try {
      final shrine = await widget.repository.loadOrCreate(selected);
      if (!mounted || serial != _loadSerial || selected != _netjer) return;
      setState(() {
        _shrine = shrine;
        final requestedCycleId = _selectedCycleId;
        final cycle = requestedCycleId == null
            ? shrine.activeCycle
            : shrine.cycles.cast<KarCycle?>().firstWhere(
                (candidate) => candidate?.id == requestedCycleId,
                orElse: () => shrine.activeCycle,
              );
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

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));

  Future<void> _openStageSheet(KarCycle? cycle, int stageIndex) async {
    final flowId = cycle?.flowId;
    FocusManager.instance.primaryFocus?.unfocus();
    await showCalendarEventDetailSheetModal<void>(
      context: context,
      builder: (sheetContext) => InstrumentEventSheetHost(
        key: ValueKey<String>('kar-detail-event-sheet-$stageIndex'),
        semanticLabel: 'Resize Kꜣr event sheet',
        handleColor: const Color(0xFF33444A),
        initialExtent: .71,
        geometry: InstrumentEventSheetGeometry.layered,
        trailing: IconButton(
          key: ValueKey<String>('kar-detail-event-sheet-close-$stageIndex'),
          tooltip: 'Close',
          onPressed: () => Navigator.of(sheetContext).maybePop(),
          icon: const Text(
            '×',
            style: TextStyle(
              color: Color(0xFF8CA0A6),
              fontFamily: 'GentiumPlus',
              fontSize: 22,
              height: 1,
            ),
          ),
        ),
        body: flowId == null
            ? KarDayBehaviorSurface.preview(
                netjer: _netjer,
                stageIndex: stageIndex,
              )
            : KarDayBehaviorSurface(
                repository: widget.repository,
                netjer: _netjer,
                flowId: flowId,
                stageIndex: stageIndex,
              ),
      ),
    );
    if (mounted) await _loadShrine();
  }

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
        onJoinedPressed: _cycle == null
            ? null
            : () => unawaited(_openStageSheet(_cycle!, 0)),
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
    );
  }

  Widget _buildSheet(Color accent, Color accent2) {
    final cycle = _visibleCycle;
    final placed = cycle?.placedCount ?? 0;
    final placedStages = <int>{
      for (final placement in cycle?.placements ?? const <KarPlacement>[])
        if (placement.activeVersion != null) placement.stageIndex,
    };
    final targetStage = cycle == null
        ? 0
        : cycle.placements.indexWhere(
            (placement) => placement.activeVersion == null,
          );
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
            child: PageView.builder(
              key: const ValueKey<String>('kar-netjer-carousel'),
              controller: _netjerPageController,
              padEnds: true,
              physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: KarNetjer.values.length,
              onPageChanged: (index) =>
                  unawaited(_selectNetjer(KarNetjer.values[index])),
              itemBuilder: (context, index) {
                final value = KarNetjer.values[index];
                return Center(
                  child: _NetjerCard(
                    netjer: value,
                    selected: value == _netjer,
                    objectStatus: value == _netjer && cycle != null
                        ? 'Cycle ${cycle.sequence} · ${cycle.placedCount}/5'
                        : null,
                    onTap: () {
                      if (!_netjerPageController.hasClients) {
                        unawaited(_selectNetjer(value));
                        return;
                      }
                      unawaited(
                        _netjerPageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        ),
                      );
                    },
                  ),
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
            onTap: () => unawaited(_openStageSheet(cycle, 0)),
          ),
          const SizedBox(height: 24),
          const _Contract(),
          const SizedBox(height: 24),
          _ArrivalCard(
            netjer: _netjer,
            onTap: () => unawaited(_openStageSheet(cycle, 0)),
          ),
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
          _ThirtyDayStrip(accent: accent),
          const SizedBox(height: 24),
          Text(
            'The month',
            style: _style(KarDetailTokens.bone, 22, weight: FontWeight.w600),
          ),
          const SizedBox(height: 17),
          for (var index = 0; index < 5; index++) ...[
            _KarScheduleDay(
              netjer: _netjer,
              stageIndex: index,
              date:
                  cycle?.dateForStage(index) ??
                  _startDate.add(Duration(days: kKarStages[index].day - 1)),
              title: _netjer.labels[index],
              placedCount: placed,
              placedStages: placedStages,
              state: placedStages.contains(index)
                  ? _KarScheduleState.placed
                  : index == targetStage
                  ? _KarScheduleState.current
                  : _KarScheduleState.future,
              ordinaryRows: _calendarRowsForStage(cycle, index),
              calendarCoverageComplete: widget.calendarPreview.coverageComplete,
              onTap: () => unawaited(_openStageSheet(cycle, index)),
            ),
            if (index < 4) const SizedBox(height: 14),
          ],
          const SizedBox(height: 20),
          Text(
            'DAY 30 · CLOSING WALK',
            style: _style(
              const Color(0xFF756435),
              8.5,
              spacing: 1.5,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _KarWalkRow(
            completed: cycle?.status == KarCycleStatus.completed,
            onTap: () => unawaited(_openStageSheet(cycle, 5)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(1, 12, 1, 2),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x172E2B25))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AFTER A SCENE IS PLACED',
                  style: _style(const Color(0xFF635A49), 8, spacing: 1.15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Its place can return later on its own. No new drawing or description is required.',
                  style: _style(
                    const Color(0xFF5E5A54),
                    11,
                    style: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 43,
            child: OutlinedButton(
              key: const ValueKey<String>('kar-start-choice'),
              onPressed: cycle == null ? _pickStart : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: KarDetailTokens.gold,
                disabledForegroundColor: KarDetailTokens.goldDim,
                side: const BorderSide(color: Color(0x7AD4AE43)),
                shape: const StadiumBorder(),
              ),
              child: Text(
                cycle == null
                    ? 'Begins ${DateFormat.MMMd().format(_startDate)} · Change'
                    : 'Began ${DateFormat.MMMd().format(cycle.anchorDate)}',
                style: _style(KarDetailTokens.gold, 16),
              ),
            ),
          ),
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
                onTap: () {
                  setState(() {
                    _selectedCycleId = history.id;
                    _startDate = history.anchorDate;
                  });
                  unawaited(_openStageSheet(history, 0));
                },
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

  List<FollowSkyCalendarPreviewRow> _calendarRowsForStage(
    KarCycle? cycle,
    int stageIndex,
  ) {
    final date = DateUtils.dateOnly(
      cycle?.dateForStage(stageIndex) ??
          _startDate.add(Duration(days: kKarStages[stageIndex].day - 1)),
    );
    final rows = widget.calendarPreview.rows.where((row) {
      if (!DateUtils.isSameDay(row.localDay, date)) return false;
      final flowName = row.flowName?.trim().toLowerCase();
      return flowName != kKarTitle.toLowerCase() && flowName != kKarFlowKey;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
    return List<FollowSkyCalendarPreviewRow>.unmodifiable(rows);
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
        fontFamily: KarFlowVisualTokens.fontFamily,
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
            if (objectStatus != null)
              Positioned(
                top: 13,
                right: 13,
                child: Container(
                  key: ValueKey<String>('kar-netjer-cycle-${netjer.key}'),
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

enum _KarScheduleState { placed, current, future }

class _KarScheduleDay extends StatelessWidget {
  const _KarScheduleDay({
    required this.netjer,
    required this.stageIndex,
    required this.date,
    required this.title,
    required this.placedCount,
    required this.placedStages,
    required this.state,
    required this.ordinaryRows,
    required this.calendarCoverageComplete,
    this.onTap,
  });

  final KarNetjer netjer;
  final int stageIndex;
  final DateTime date;
  final String title;
  final int placedCount;
  final Set<int> placedStages;
  final _KarScheduleState state;
  final List<FollowSkyCalendarPreviewRow> ordinaryRows;
  final bool calendarCoverageComplete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kemetic = KemeticMath.fromGregorian(date);
    final month = getMonthById(kemetic.kMonth);
    final event = KarEventBlockVisual(
      netjer: netjer,
      stageIndex: stageIndex,
      title: title,
      placedCount: placedCount,
      placedStages: placedStages,
      height: 106,
      onTap: onTap,
    );
    return RepaintBoundary(
      key: ValueKey<String>('kar-schedule-day-$stageIndex'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 19, 15, 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x2ED4AE43)),
          borderRadius: BorderRadius.circular(17),
          gradient: const RadialGradient(
            center: Alignment(-.86, -1),
            radius: 1.2,
            colors: <Color>[Color(0xFF12110D), Color(0xFF0D0D09)],
            stops: <double>[0, .55],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${month.displayShort} ${kemetic.kDay}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(
                      KarDetailTokens.gold,
                      22,
                      weight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${DateFormat.E().format(date)} · ${DateFormat.MMMd().format(date)}',
                  style: _style(
                    const Color(0xFF9D8757),
                    10.5,
                    spacing: 1.55,
                    weight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Opacity(
              opacity: switch (state) {
                _KarScheduleState.current => 1,
                _KarScheduleState.placed => .84,
                _KarScheduleState.future => .52,
              },
              child: event,
            ),
            const SizedBox(height: 11),
            const Divider(color: Color(0x21D4AE43), height: 1),
            if (ordinaryRows.isNotEmpty)
              for (var index = 0; index < ordinaryRows.length; index++)
                _KarScheduleContextRow(
                  row: ordinaryRows[index],
                  showDivider: index < ordinaryRows.length - 1,
                )
            else
              _KarScheduleContextStatus(
                stageIndex: stageIndex,
                loading: !calendarCoverageComplete,
              ),
          ],
        ),
      ),
    );
  }
}

class _KarScheduleContextStatus extends StatelessWidget {
  const _KarScheduleContextStatus({
    required this.stageIndex,
    required this.loading,
  });

  final int stageIndex;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey<String>(
      loading
          ? 'kar-schedule-calendar-loading-$stageIndex'
          : 'kar-schedule-calendar-empty-$stageIndex',
    ),
    height: 47,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        loading ? 'Loading calendar…' : 'No other calendar entries',
        style: _style(const Color(0xFF777169), 11, style: FontStyle.italic),
      ),
    ),
  );
}

class _KarScheduleContextRow extends StatelessWidget {
  const _KarScheduleContextRow({required this.row, required this.showDivider});

  final FollowSkyCalendarPreviewRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 47),
    decoration: showDivider
        ? const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1AD4AE43))),
          )
        : null,
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 7,
          child: Center(
            child: Container(
              width: 4,
              height: 15,
              decoration: BoxDecoration(
                color: row.eventColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 67,
          child: Text(
            row.allDay ? 'All day' : DateFormat.jm().format(row.start),
            maxLines: 1,
            style: _style(const Color(0xFF8F8B83), 10.5),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            row.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(const Color(0xFFCBC5BA), 16, height: 1.15),
          ),
        ),
      ],
    ),
  );
}

class _KarWalkRow extends StatelessWidget {
  const _KarWalkRow({required this.completed, this.onTap});

  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: completed ? .84 : .58,
    child: InkWell(
      key: const ValueKey<String>('kar-closing-walk-row'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13.5, horizontal: 1),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x172E2B25)),
            bottom: BorderSide(color: Color(0x172E2B25)),
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 29,
              child: Text(
                '06',
                style: _style(KarDetailTokens.goldDim, 10, spacing: 1.1),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Walk the kꜣr',
                    style: _style(const Color(0xFF918B80), 20, height: 1.08),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Day 30 · Inner chamber',
                    style: _style(const Color(0xFF5F5B55), 11, height: 1.25),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4F4A40), size: 18),
          ],
        ),
      ),
    ),
  );
}

class _ThirtyDayStrip extends StatelessWidget {
  const _ThirtyDayStrip({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      RepaintBoundary(
        key: const ValueKey<String>('kar-thirty-day-calendar'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x1FD4AE43)),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF070706),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (var decan = 0; decan < 3; decan++)
                _KarDecanRow(decan: decan, accent: accent),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 6,
        children: <Widget>[
          _KarCalendarLegend(
            color: Color.lerp(accent, Colors.white, .35)!,
            size: 6,
            label: 'first image / first walk',
          ),
          _KarCalendarLegend(
            color: accent,
            size: 5,
            label: 'imagination sittings',
          ),
        ],
      ),
    ],
  );
}

class _KarDecanRow extends StatelessWidget {
  const _KarDecanRow({required this.decan, required this.accent});

  final int decan;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
    decoration: BoxDecoration(
      border: decan == 0
          ? null
          : const Border(top: BorderSide(color: Color(0x14D4AE43))),
    ),
    child: Column(
      children: <Widget>[
        SizedBox(
          height: 19,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                'Decan ${const <String>['I', 'II', 'III'][decan]}',
                style: _style(
                  const Color(0xFFA79B7A),
                  14,
                  weight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'days ${decan * 10 + 1}–${decan * 10 + 10}',
                style: _style(
                  const Color(0xFF625F58),
                  10.5,
                  style: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 49,
          child: Row(
            children: <Widget>[
              for (var offset = 1; offset <= 10; offset++)
                Expanded(
                  child: _KarCalendarDay(
                    day: decan * 10 + offset,
                    accent: accent,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _KarCalendarDay extends StatelessWidget {
  const _KarCalendarDay({required this.day, required this.accent});

  final int day;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final milestone = kKarStages.any((stage) => stage.day == day);
    final major = day == 1 || day == 30;
    return Stack(
      key: ValueKey<String>('kar-calendar-day-$day'),
      alignment: Alignment.center,
      children: <Widget>[
        if (day == 1)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x6BD4AE43)),
            ),
          ),
        Text(
          '$day',
          style: _style(
            day == 1 ? KarDetailTokens.bone : const Color(0xFF5A5852),
            20,
            weight: FontWeight.w500,
          ),
        ),
        if (milestone)
          Positioned(
            bottom: 2,
            child: Container(
              width: major ? 6 : 4,
              height: major ? 6 : 4,
              decoration: BoxDecoration(
                color: major ? Color.lerp(accent, Colors.white, .35) : accent,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: .38),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KarCalendarLegend extends StatelessWidget {
  const _KarCalendarLegend({
    required this.color,
    required this.size,
    required this.label,
  });

  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: _style(const Color(0xFF625E56), 10, height: 1.2)),
    ],
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
