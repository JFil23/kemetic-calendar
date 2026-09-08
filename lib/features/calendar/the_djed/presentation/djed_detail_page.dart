import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;

enum DjedSupportCondition { unassessed, holding, underPressure, wobbling }

@immutable
class DjedSupportFixture {
  const DjedSupportFixture({required this.name, required this.condition});

  final String name;
  final DjedSupportCondition condition;
}

@immutable
class DjedSittingFixture {
  const DjedSittingFixture({
    required this.number,
    required this.flowDay,
    required this.phase,
    required this.title,
    required this.timeLabel,
    required this.durationLabel,
  });

  final int number;
  final int flowDay;
  final String phase;
  final String title;
  final String timeLabel;
  final String durationLabel;
}

const List<DjedSupportFixture> kDjedSupportFixtures = <DjedSupportFixture>[
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
];

const List<DjedSittingFixture> kDjedSittingFixtures = <DjedSittingFixture>[
  DjedSittingFixture(
    number: 1,
    flowDay: 1,
    phase: 'FIND YOUR FOOTING',
    title: 'Set your footing',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 2,
    flowDay: 5,
    phase: 'SUPPORT 01',
    title: 'Make one move',
    timeLabel: '11:00 local',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 3,
    flowDay: 9,
    phase: 'SUPPORT 01',
    title: 'Read the result',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 4,
    flowDay: 11,
    phase: 'SUPPORT 02',
    title: 'Make one move',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 5,
    flowDay: 15,
    phase: 'SUPPORT 02',
    title: 'Read the result',
    timeLabel: '11:00 local',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 6,
    flowDay: 19,
    phase: 'SUPPORT 03',
    title: 'Make one move',
    timeLabel: 'Sunset + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 7,
    flowDay: 21,
    phase: 'SUPPORT 03',
    title: 'Read the result',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 8,
    flowDay: 25,
    phase: 'SUPPORT 04',
    title: 'Make one move',
    timeLabel: '11:00 local',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 9,
    flowDay: 29,
    phase: 'SUPPORT 04',
    title: 'Read the result',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '10–15 min',
  ),
];

abstract final class DjedDetailTokens {
  static const Color page = Color(0xFF050403);
  static const Color sheet = Color(0xFF090705);
  static const Color bone = Color(0xFFF2EADD);
  static const Color ivory = Color(0xFFD8D0C3);
  static const Color gold = Color(0xFFE0873C);
  static const Color goldBright = Color(0xFFF5B963);
  static const Color goldDim = Color(0xFF8A5A28);
  static const Color emberDeep = Color(0xFFB4552A);
  static const Color coal = Color(0xFF1E120A);
  static const Color coal2 = Color(0xFF3A1F0E);
  static const Color silver = Color(0xFFA0968A);
  static const Color low = Color(0xFF6E655B);
  static const Color separator = Color(0xFF2C2016);
  static const String heroAsset = 'assets/the_djed/hero.png';

  static const MaatFlowDetailTheme theme = MaatFlowDetailTheme(
    pageBackground: page,
    sheetBackground: sheet,
    sheetBorder: Color(0x42E0873C),
    accent: gold,
    primaryText: bone,
    secondaryText: silver,
    mutedText: low,
    separator: separator,
    glow: goldBright,
  );
}

class DjedDetailPage extends StatefulWidget {
  const DjedDetailPage({
    super.key,
    this.startDate,
    this.supports = kDjedSupportFixtures,
    this.sittings = kDjedSittingFixtures,
    this.joined = false,
    this.busy = false,
    this.onCarry,
    this.onCarryConfiguration,
    this.onJoinedPressed,
    this.onBack,
  });

  final DateTime? startDate;
  final List<DjedSupportFixture> supports;
  final List<DjedSittingFixture> sittings;
  final bool joined;
  final bool busy;
  final VoidCallback? onCarry;
  final ValueChanged<DjedV2Configuration>? onCarryConfiguration;
  final VoidCallback? onJoinedPressed;
  final VoidCallback? onBack;

  DateTime get _windowStart => startDate ?? DateTime(2026, 9, 6);

  @override
  State<DjedDetailPage> createState() => _DjedDetailPageState();
}

class _DjedDetailPageState extends State<DjedDetailPage> {
  late List<DjedSupportFixture> _supports;
  late final List<FocusNode> _supportFocusNodes;
  int _activeSupport = 0;

  @override
  void initState() {
    super.initState();
    _supportFocusNodes = List<FocusNode>.generate(4, (index) {
      final node = FocusNode(debugLabel: 'djed-support-${index + 1}-name');
      node.addListener(() {
        if (node.hasFocus && mounted && _activeSupport != index) {
          setState(() => _activeSupport = index);
        }
      });
      return node;
    });
    _supports = List<DjedSupportFixture>.from(widget.supports.take(4));
    while (_supports.length < 4) {
      _supports.add(
        const DjedSupportFixture(
          name: '',
          condition: DjedSupportCondition.unassessed,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final node in _supportFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DjedDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supports != widget.supports) {
      _supports = List<DjedSupportFixture>.from(widget.supports.take(4));
      while (_supports.length < 4) {
        _supports.add(
          const DjedSupportFixture(
            name: '',
            condition: DjedSupportCondition.unassessed,
          ),
        );
      }
    }
  }

  void _updateName(int index, String value) {
    setState(() {
      _activeSupport = index;
      _supports[index] = DjedSupportFixture(
        name: value,
        condition: _supports[index].condition,
      );
    });
  }

  void _updateCondition(int index, DjedSupportCondition condition) {
    final advance = _supports[index].name.trim().isNotEmpty && index < 3;
    setState(() {
      _supports[index] = DjedSupportFixture(
        name: _supports[index].name,
        condition: condition,
      );
      _activeSupport = advance ? index + 1 : index;
    });
    if (advance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _supportFocusNodes[index + 1].requestFocus();
      });
    }
  }

  void _selectSupport(int index, {bool focusName = false}) {
    if (index < 0 || index >= _supports.length) return;
    if (_activeSupport != index) {
      setState(() => _activeSupport = index);
    }
    if (focusName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _supportFocusNodes[index].requestFocus();
      });
    }
  }

  void _carry() {
    final definitions = <DjedV2SupportDefinition>[];
    for (final (index, support) in _supports.indexed) {
      final name = support.name.trim();
      final condition = switch (support.condition) {
        DjedSupportCondition.holding => DjedV2SupportCondition.holding,
        DjedSupportCondition.underPressure =>
          DjedV2SupportCondition.underPressure,
        DjedSupportCondition.wobbling => DjedV2SupportCondition.wobbling,
        DjedSupportCondition.unassessed => null,
      };
      if (name.isEmpty || condition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name all four supports and choose each condition.'),
          ),
        );
        return;
      }
      definitions.add(
        DjedV2SupportDefinition(
          slot: index + 1,
          name: name,
          initialCondition: condition,
        ),
      );
    }
    final callback = widget.onCarryConfiguration;
    if (callback != null) {
      callback(DjedV2Configuration(supports: definitions));
    } else {
      widget.onCarry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DjedDetailTokens.page,
      body: Stack(
        children: <Widget>[
          MaatFlowDetailShell(
            theme: DjedDetailTokens.theme,
            referenceHeroHeight: 258,
            referenceSheetOverlap: 26,
            scrollKey: const ValueKey<String>('djed-detail-scroll'),
            heroLayerKey: const ValueKey<String>('djed-hero-layer'),
            sheetKey: const ValueKey<String>('djed-sheet'),
            hero: const _DjedHero(),
            sheet: _DjedSheet(
              startDate: widget._windowStart,
              supports: _supports,
              sittings: widget.sittings,
              activeSupport: _activeSupport,
              supportFocusNodes: _supportFocusNodes,
              onSupportSelected: _selectSupport,
              onNameChanged: _updateName,
              onConditionChanged: _updateCondition,
            ),
            bottomDock: MaatFlowDetailDock(
              theme: DjedDetailTokens.theme,
              joined: widget.joined,
              busy: widget.busy,
              onPressed: widget.busy ? null : _carry,
              onJoinedPressed: widget.onJoinedPressed,
              actionLabel: 'Carry this djed',
              actionNote: 'Nothing is scheduled until you carry it.',
              joinedLabel: 'Carried in My Flows',
              joinedNote: 'Your four supports and nine sittings stay together.',
              actionKey: const ValueKey<String>('djed-carry'),
              joinedKey: const ValueKey<String>('djed-carried'),
              showNote: false,
            ),
          ),
          Positioned(
            left: 18,
            top: MediaQuery.paddingOf(context).top + 6,
            child: MaatFlowDetailBackButton(
              key: const ValueKey<String>('djed-back'),
              color: DjedDetailTokens.gold,
              backgroundColor: const Color(0xA60D0905),
              onPressed: widget.onBack ?? () => popMaatFlowDetailOrGo(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedHero extends StatelessWidget {
  const _DjedHero();

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      key: const ValueKey<String>('djed-hero'),
      theme: DjedDetailTokens.theme,
      contentBottom: 25,
      contentLeft: 23,
      contentRight: 150,
      glyphToTitleSpacing: 10,
      titleFontSize: 46,
      titleHeight: 0.96,
      titleLetterSpacing: -0.46,
      subtitleSpacing: 8,
      subtitleWidth: 225,
      subtitleFontSize: 17,
      subtitleColor: Color(0xFFC8C4BC),
      subtitleHeight: 1.15,
      glyph: '𓊽',
      glyphKey: const ValueKey<String>('djed-hero-glyph'),
      title: 'The Djed',
      subtitle: 'Strengthen four parts of your life, one small move at a time.',
      glyphGradient: const RadialGradient(
        center: Alignment(-0.25, -0.45),
        colors: <Color>[
          Color(0xFF7E6327),
          Color(0xFF33250F),
          Color(0xFF0B0905),
        ],
      ),
      glyphBorder: const Color(0xB8E0873C),
      background: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            DjedDetailTokens.heroAsset,
            key: const ValueKey<String>('djed-hero-image'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xBD050504),
                  Color(0x57050504),
                  Color(0x0F050504),
                  Color(0x14050504),
                ],
                stops: <double>[0, 0.34, 0.66, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x14050504),
                  Color(0x05050504),
                  Color(0x33050504),
                  Color(0xD1050504),
                ],
                stops: <double>[0, 0.42, 0.68, 1],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 118,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Color(0x38050504),
                    Color(0xE0050504),
                    Color(0xFF050403),
                  ],
                  stops: <double>[0, 0.34, 0.82, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedSheet extends StatelessWidget {
  const _DjedSheet({
    required this.startDate,
    required this.supports,
    required this.sittings,
    required this.activeSupport,
    required this.supportFocusNodes,
    required this.onSupportSelected,
    required this.onNameChanged,
    required this.onConditionChanged,
  });

  final DateTime startDate;
  final List<DjedSupportFixture> supports;
  final List<DjedSittingFixture> sittings;
  final int activeSupport;
  final List<FocusNode> supportFocusNodes;
  final void Function(int index, {bool focusName}) onSupportSelected;
  final void Function(int index, String value) onNameChanged;
  final void Function(int index, DjedSupportCondition condition)
  onConditionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _DjedHandle(),
        const _DjedContract(),
        _DjedSupports(
          supports: supports,
          activeSupport: activeSupport,
          supportFocusNodes: supportFocusNodes,
          onSupportSelected: onSupportSelected,
          onNameChanged: onNameChanged,
          onConditionChanged: onConditionChanged,
        ),
        _DjedThirtyDayCalendar(startDate: startDate, sittings: sittings),
        _DjedSittings(sittings: sittings, startDate: startDate),
        const _DjedHistory(),
      ],
    );
  }
}

class _DjedThirtyDayCalendar extends StatelessWidget {
  const _DjedThirtyDayCalendar({
    required this.startDate,
    required this.sittings,
  });

  final DateTime startDate;
  final List<DjedSittingFixture> sittings;

  @override
  Widget build(BuildContext context) {
    final sittingDays = <int>{for (final sitting in sittings) sitting.flowDay};
    return Container(
      key: const ValueKey<String>('djed-thirty-day-calendar'),
      padding: const EdgeInsets.fromLTRB(22, 27, 22, 29),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DjedDetailTokens.separator)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('The thirty days', style: _displayStyle(fontSize: 29)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final copy = Text(
                'Find your footing. Work each beam twice. Then raise the Djed.',
                style: _uiStyle(
                  fontSize: 13,
                  color: DjedDetailTokens.low,
                  height: 1.45,
                ),
              );
              final rangeLabel = _calendarRange(startDate);
              final rangeStyle = _uiStyle(
                fontSize: 11,
                color: const Color(0xFF676963),
                fontStyle: FontStyle.italic,
              );
              final range = Text(rangeLabel, style: rangeStyle);
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final rangePainter = TextPainter(
                text: TextSpan(text: rangeLabel, style: rangeStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              final rangeWidth = rangePainter.width;
              rangePainter.dispose();
              final shouldStack =
                  constraints.maxWidth < 310 ||
                  textScale > 1.15 ||
                  rangeWidth + 8 + 96 > constraints.maxWidth;
              if (shouldStack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[copy, const SizedBox(height: 6), range],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: copy),
                  const SizedBox(width: 8),
                  range,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF070605),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x1FE0873C)),
              ),
              child: Column(
                children: <Widget>[
                  for (var phase = 0; phase < 3; phase++)
                    Container(
                      constraints: const BoxConstraints(minHeight: 82),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      decoration: BoxDecoration(
                        border: phase == 0
                            ? null
                            : const Border(
                                top: BorderSide(color: Color(0x1AE0873C)),
                              ),
                      ),
                      child: Column(
                        children: <Widget>[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final decan = Text(
                                _phaseDecanName(startDate, phase),
                                style: _displayStyle(
                                  fontSize: 13.5,
                                  color: const Color(0xFFAA9A70),
                                ),
                              );
                              final phaseName = Text(
                                const <String>[
                                  'FIND YOUR FOOTING',
                                  'WORK THE BEAMS',
                                  'RAISE THE DJED',
                                ][phase],
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                style: _uiStyle(
                                  fontSize: 8,
                                  color: DjedDetailTokens.goldDim,
                                  letterSpacing: .9,
                                ),
                              );
                              final dates = Text(
                                _decanRange(startDate, phase),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: _uiStyle(
                                  fontSize: 9.5,
                                  color: const Color(0xFF5F5B54),
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1);
                              if (constraints.maxWidth < 280 ||
                                  textScale > 1.15) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        decan,
                                        const SizedBox(width: 6),
                                        Expanded(child: phaseName),
                                      ],
                                    ),
                                    dates,
                                  ],
                                );
                              }
                              return SizedBox(
                                height: 22,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Flexible(child: decan),
                                    const SizedBox(width: 6),
                                    Expanded(child: phaseName),
                                    Flexible(child: dates),
                                  ],
                                ),
                              );
                            },
                          ),
                          SizedBox(
                            height: 50,
                            child: Row(
                              children: <Widget>[
                                for (var offset = 1; offset <= 10; offset++)
                                  Expanded(
                                    child: _DjedCalendarDay(
                                      day: _kemeticDayNumber(
                                        startDate,
                                        phase * 10 + offset,
                                      ),
                                      sitting: sittingDays.contains(
                                        phase * 10 + offset,
                                      ),
                                      start: phase == 0 && offset == 1,
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
        ],
      ),
    );
  }
}

class _DjedCalendarDay extends StatelessWidget {
  const _DjedCalendarDay({
    required this.day,
    required this.sitting,
    required this.start,
  });

  final int day;
  final bool sitting;
  final bool start;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        if (start)
          Positioned(
            top: 0,
            child: Text(
              'START',
              style: _uiStyle(
                fontSize: 6,
                color: DjedDetailTokens.gold,
                letterSpacing: .6,
              ),
            ),
          ),
        if (sitting)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x09F5B963),
              border: Border.all(color: const Color(0x6BF5B963)),
            ),
          ),
        Text(
          '$day',
          style: _displayStyle(
            fontSize: 18,
            color: sitting ? const Color(0xFFC8C0A9) : const Color(0xFF686860),
          ),
        ),
        if (sitting)
          const Positioned(
            bottom: 2,
            child: SizedBox(
              width: 3,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DjedDetailTokens.goldBright,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

DateTime _djedFlowDate(DateTime startDate, int flowDay) => DateTime(
  startDate.year,
  startDate.month,
  startDate.day,
).add(Duration(days: flowDay - 1));

int _kemeticDayNumber(DateTime startDate, int flowDay) =>
    KemeticMath.fromGregorian(_djedFlowDate(startDate, flowDay)).kDay;

String _kemeticMonthDay(DateTime date) {
  final kemetic = KemeticMath.fromGregorian(date);
  return '${getMonthById(kemetic.kMonth).displayShort} ${kemetic.kDay}';
}

String _calendarRange(DateTime startDate) {
  final last = _djedFlowDate(startDate, 30);
  return '${_kemeticMonthDay(startDate)} → ${_kemeticMonthDay(last)}';
}

String _phaseDecanName(DateTime startDate, int phase) {
  final kemetic = KemeticMath.fromGregorian(
    startDate.add(Duration(days: phase * 10)),
  );
  return DecanMetadata.decanNameFor(kMonth: kemetic.kMonth, kDay: kemetic.kDay);
}

String _decanRange(DateTime startDate, int phase) {
  final first = startDate.add(Duration(days: phase * 10));
  final last = first.add(const Duration(days: 9));
  final firstK = KemeticMath.fromGregorian(first);
  final lastK = KemeticMath.fromGregorian(last);
  final firstMonth = getMonthById(firstK.kMonth).displayShort;
  final lastMonth = getMonthById(lastK.kMonth).displayShort;
  if (firstK.kMonth == lastK.kMonth) {
    return '$firstMonth ${firstK.kDay}–${lastK.kDay}';
  }
  return '$firstMonth ${firstK.kDay}–$lastMonth ${lastK.kDay}';
}

class _DjedHandle extends StatelessWidget {
  const _DjedHandle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment(0, -0.25),
        child: SizedBox(
          width: 44,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF3A3429),
              borderRadius: BorderRadius.all(Radius.circular(99)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DjedContract extends StatelessWidget {
  const _DjedContract();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(0, 5, 0, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: DjedDetailTokens.separator)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Row(
            children: <Widget>[
              _ContractLabel('30 DAYS'),
              _ContractDot(),
              _ContractLabel('4 SUPPORTS'),
              _ContractDot(),
              _ContractLabel('9 SITTINGS'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractLabel extends StatelessWidget {
  const _ContractLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: _uiStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: DjedDetailTokens.gold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContractDot extends StatelessWidget {
  const _ContractDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      child: Center(
        child: SizedBox(
          width: 3,
          height: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF544426),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _DjedSupports extends StatelessWidget {
  const _DjedSupports({
    required this.supports,
    required this.activeSupport,
    required this.supportFocusNodes,
    required this.onSupportSelected,
    required this.onNameChanged,
    required this.onConditionChanged,
  });

  final List<DjedSupportFixture> supports;
  final int activeSupport;
  final List<FocusNode> supportFocusNodes;
  final void Function(int index, {bool focusName}) onSupportSelected;
  final void Function(int index, String value) onNameChanged;
  final void Function(int index, DjedSupportCondition condition)
  onConditionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('djed-supports-section'),
      padding: const EdgeInsets.fromLTRB(22, 23, 22, 30),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: DjedDetailTokens.separator),
          bottom: BorderSide(color: DjedDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Your Djed', style: _displayStyle(fontSize: 29)),
          const SizedBox(height: 7),
          Text(
            'Name four parts of your life you want to feel more steady in. You will work them one at a time.',
            style: _uiStyle(
              fontSize: 13,
              color: DjedDetailTokens.low,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          DjedSpineVisual(
            supports: supports,
            activeSupport: activeSupport,
            onSupportSelected: (index) =>
                onSupportSelected(index, focusName: true),
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < supports.length; index++)
            _DjedSupportRow(
              index: index,
              support: supports[index],
              active: index == activeSupport,
              focusNode: supportFocusNodes[index],
              onActivate: () => onSupportSelected(index),
              onNameChanged: onNameChanged,
              onConditionChanged: onConditionChanged,
            ),
        ],
      ),
    );
  }
}

class DjedSpineVisual extends StatelessWidget {
  const DjedSpineVisual({
    super.key,
    required this.supports,
    this.activeSupport = 0,
    this.onSupportSelected,
  });

  final List<DjedSupportFixture> supports;
  final int activeSupport;
  final ValueChanged<int>? onSupportSelected;

  @override
  Widget build(BuildContext context) {
    final visible = supports.take(4).toList(growable: false);
    return Container(
      key: const ValueKey<String>('djed-live-spine'),
      height: 214,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x2BE0873C)),
        gradient: const RadialGradient(
          center: Alignment(0, -0.12),
          radius: 0.95,
          colors: <Color>[Color(0x1AE0873C), Color(0xFF0D0D0A)],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            left: 22,
            right: 22,
            bottom: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0x00E0873C),
                    Color(0x2EE0873C),
                    Color(0x00E0873C),
                  ],
                ),
              ),
              child: SizedBox(height: 1),
            ),
          ),
          Center(
            child: SizedBox(
              width: 258,
              height: 176,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 143,
                    decoration: _shaftDecoration(),
                  ),
                  Positioned(
                    top: 1,
                    child: Container(
                      width: 56,
                      height: 25,
                      decoration: _capDecoration(),
                    ),
                  ),
                  for (var index = 0; index < visible.length; index++)
                    Positioned(
                      top: 30.0 + (visible.length - 1 - index) * 31,
                      left: 28,
                      right: 28,
                      child: Semantics(
                        button: onSupportSelected != null,
                        selected: index == activeSupport,
                        label: 'Support ${index + 1}: ${visible[index].name}',
                        child: InkWell(
                          key: ValueKey<String>(
                            'djed-spine-support-${index + 1}',
                          ),
                          onTap: onSupportSelected == null
                              ? null
                              : () => onSupportSelected!(index),
                          child: Opacity(
                            opacity: index == activeSupport ? 1 : .42,
                            child: _DjedSpineBeam(
                              index: index,
                              support: visible[index],
                              active: index == activeSupport,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 66,
                      height: 21,
                      decoration: _baseDecoration(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DjedSupportRow extends StatelessWidget {
  const _DjedSupportRow({
    required this.index,
    required this.support,
    required this.active,
    required this.focusNode,
    required this.onActivate,
    required this.onNameChanged,
    required this.onConditionChanged,
  });

  final int index;
  final DjedSupportFixture support;
  final bool active;
  final FocusNode focusNode;
  final VoidCallback onActivate;
  final void Function(int index, String value) onNameChanged;
  final void Function(int index, DjedSupportCondition condition)
  onConditionChanged;

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: ValueKey<String>('djed-support-row-${index + 1}'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onActivate(),
      child: Opacity(
        opacity: active ? 1 : .48,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 13, 0, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x17E0873C))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  SizedBox(
                    width: 62,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Text(
                        'SUPPORT ${(index + 1).toString().padLeft(2, '0')}',
                        style: _uiStyle(fontSize: 9, letterSpacing: 1.25),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 33,
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x38E0873C)),
                        ),
                      ),
                      child: TextFormField(
                        key: ValueKey<String>('djed-support-name-${index + 1}'),
                        focusNode: focusNode,
                        initialValue: support.name,
                        onChanged: (value) => onNameChanged(index, value),
                        maxLines: 1,
                        style: _displayStyle(
                          fontSize: 19,
                          color: DjedDetailTokens.bone,
                          fontStyle: FontStyle.italic,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: 'what needs strengthening',
                          hintStyle: _displayStyle(
                            fontSize: 19,
                            color: const Color(0xFF4F4B43),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Row(
                  children: <Widget>[
                    for (final condition in const <DjedSupportCondition>[
                      DjedSupportCondition.holding,
                      DjedSupportCondition.underPressure,
                      DjedSupportCondition.wobbling,
                    ]) ...<Widget>[
                      Expanded(
                        child: InkWell(
                          key: ValueKey<String>(
                            'djed-support-${index + 1}-${condition.name}',
                          ),
                          onTap: () => onConditionChanged(index, condition),
                          child: Container(
                            height: 18,
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: support.condition == condition
                                      ? _conditionAccent(condition)
                                      : const Color(0x172E160B),
                                ),
                              ),
                            ),
                            child: Text(
                              _labelForCondition(condition),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              style: _uiStyle(
                                fontSize: 11,
                                color: support.condition == condition
                                    ? _conditionAccent(condition)
                                    : const Color(0xFF6F6C66),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (condition != DjedSupportCondition.wobbling)
                        const SizedBox(width: 13),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DjedSpineBeam extends StatelessWidget {
  const _DjedSpineBeam({
    required this.index,
    required this.support,
    required this.active,
  });

  final int index;
  final DjedSupportFixture support;
  final bool active;

  @override
  Widget build(BuildContext context) {
    Widget beam = Container(
      height: 26,
      alignment: Alignment.center,
      decoration: _conditionDecoration(support.condition, active: active),
      child: Text(
        'SUPPORT ${(index + 1).toString().padLeft(2, '0')}${support.name.isEmpty ? '' : ' · ${support.name.toUpperCase()}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _displayStyle(
          fontSize: 15.5,
          color: support.condition == DjedSupportCondition.unassessed
              ? const Color(0xFF302416)
              : const Color(0xFF21170B),
        ),
      ),
    );
    beam = switch (support.condition) {
      DjedSupportCondition.underPressure => Transform.scale(
        scaleX: 0.94,
        child: beam,
      ),
      DjedSupportCondition.wobbling => Transform.translate(
        offset: const Offset(7, 0),
        child: Transform.rotate(angle: -1.5 * math.pi / 180, child: beam),
      ),
      _ => beam,
    };
    return beam;
  }
}

class _DjedSittings extends StatefulWidget {
  const _DjedSittings({required this.sittings, required this.startDate});

  final List<DjedSittingFixture> sittings;
  final DateTime startDate;

  @override
  State<_DjedSittings> createState() => _DjedSittingsState();
}

class _DjedSittingsState extends State<_DjedSittings> {
  bool _showRemaining = false;

  @override
  Widget build(BuildContext context) {
    final remaining = widget.sittings.skip(5).toList(growable: false);
    return Container(
      key: const ValueKey<String>('djed-sittings-section'),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DjedDetailTokens.separator)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('The sittings', style: _displayStyle(fontSize: 29)),
          const SizedBox(height: 18),
          for (final sitting in widget.sittings.take(5)) ...<Widget>[
            _DjedScheduleCard(
              sitting: sitting,
              date: widget.startDate.add(Duration(days: sitting.flowDay - 1)),
            ),
            const SizedBox(height: 14),
          ],
          if (remaining.isNotEmpty) ...<Widget>[
            InkWell(
              key: const ValueKey<String>('djed-see-remaining-sittings'),
              onTap: () => setState(() => _showRemaining = !_showRemaining),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _showRemaining
                            ? 'Hide remaining sittings'
                            : 'See remaining ${remaining.length} sittings',
                        style: const TextStyle(
                          color: Color(0xFFA58B4B),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Text(
                      _showRemaining ? '–' : '+',
                      style: const TextStyle(
                        color: Color(0xFF7E6E43),
                        fontFamily: 'GentiumPlus',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showRemaining) ...<Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 3, bottom: 5),
                child: Text(
                  'SITTINGS 06–09',
                  style: TextStyle(
                    color: Color(0xFF756435),
                    fontFamily: 'GentiumPlus',
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              for (final sitting in remaining)
                _CompactSittingRow(sitting: sitting),
            ],
          ],
        ],
      ),
    );
  }
}

class _DjedScheduleCard extends StatelessWidget {
  const _DjedScheduleCard({required this.sitting, required this.date});

  final DjedSittingFixture sitting;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 19, 15, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x33E0873C)),
        gradient: const RadialGradient(
          center: Alignment(-0.86, -1),
          radius: 1.2,
          colors: <Color>[Color(0x09E0873C), Color(0xFF0D0D09)],
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
          _ScheduleDate(date: date),
          const SizedBox(height: 13),
          DjedEventBlockVisual(
            sittingNumber: sitting.number,
            title: sitting.title,
            phase: sitting.phase,
            timeLabel: sitting.timeLabel,
            durationLabel: sitting.durationLabel,
          ),
          _DjedCalendarContextRows(sittingNumber: sitting.number),
        ],
      ),
    );
  }
}

class _ScheduleDate extends StatelessWidget {
  const _ScheduleDate({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const gregorianMonths = <String>[
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
    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final kemetic = KemeticMath.fromGregorian(date);
    final month = getMonthById(kemetic.kMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            '${month.displayShort} ${kemetic.kDay}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DjedDetailTokens.gold,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '${weekdays[date.weekday - 1]} · ${gregorianMonths[date.month - 1]} ${date.day}',
          style: _uiStyle(
            fontSize: 10.5,
            letterSpacing: 1.55,
            color: const Color(0xFFA98950),
          ),
        ),
      ],
    );
  }
}

class _CompactSittingRow extends StatelessWidget {
  const _CompactSittingRow({required this.sitting});
  final DjedSittingFixture sitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DjedDetailTokens.separator)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 25,
            child: Text(
              sitting.number.toString().padLeft(2, '0'),
              style: _uiStyle(fontSize: 9, letterSpacing: 1),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sitting.title,
                  style: _displayStyle(
                    fontSize: 18,
                    color: const Color(0xFFD7D0C5),
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Day ${sitting.flowDay} · ${sitting.timeLabel} · ${sitting.durationLabel}',
                  style: _uiStyle(
                    fontSize: 10.5,
                    color: const Color(0xFF656962),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 17,
            color: DjedDetailTokens.goldDim,
          ),
        ],
      ),
    );
  }
}

class _DjedCalendarContextRows extends StatelessWidget {
  const _DjedCalendarContextRows({required this.sittingNumber});

  final int sittingNumber;

  static const Map<int, List<(Color, String, String)>> _rows =
      <int, List<(Color, String, String)>>{
        1: <(Color, String, String)>[
          (Color(0xFF72C766), '8:00 AM', 'journal every day'),
          (Color(0xFF399BEA), '12:00 PM', 'Bits and Operations'),
          (Color(0xFF72C766), '9:30 PM', 'journal every night'),
        ],
        2: <(Color, String, String)>[
          (Color(0xFF72C766), '8:00 AM', 'journal every day'),
          (Color(0xFFF5696B), '12:00 PM', "The Spider's Shortcut"),
          (Color(0xFF72C766), '9:30 PM', 'journal every night'),
        ],
        3: <(Color, String, String)>[
          (Color(0xFF72C766), '8:00 AM', 'journal every day'),
          (Color(0xFF72C766), '9:30 PM', 'journal every night'),
        ],
        4: <(Color, String, String)>[
          (Color(0xFF72C766), '8:00 AM', 'journal every day'),
          (Color(0xFF399BEA), '12:00 PM', 'Bits and Operations'),
          (Color(0xFF72C766), '9:30 PM', 'journal every night'),
        ],
        5: <(Color, String, String)>[
          (Color(0xFF72C766), '8:00 AM', 'journal every day'),
          (Color(0xFF72C766), '9:30 PM', 'journal every night'),
        ],
      };

  @override
  Widget build(BuildContext context) {
    final rows = _rows[sittingNumber];
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x24E0873C))),
        ),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < rows.length; index++)
              Container(
                constraints: const BoxConstraints(minHeight: 47),
                decoration: BoxDecoration(
                  border: index == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: Color(0x1FE0873C)),
                        ),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 7,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 15,
                          decoration: BoxDecoration(
                            color: rows[index].$1,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    SizedBox(
                      width: 67,
                      child: Text(
                        rows[index].$2,
                        style: _uiStyle(
                          fontSize: 10.5,
                          color: const Color(0xFF8F8B83),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        rows[index].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _displayStyle(
                          fontSize: 16,
                          color: const Color(0xFFCBC5BA),
                          height: 1.15,
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
}

class _DjedHistory extends StatefulWidget {
  const _DjedHistory();

  @override
  State<_DjedHistory> createState() => _DjedHistoryState();
}

class _DjedHistoryState extends State<_DjedHistory> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 27, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>('djed-in-kemet'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'In Kemet',
                      style: TextStyle(
                        color: Color(0xFFAAA197),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    _open ? '–' : '+',
                    style: const TextStyle(
                      color: Color(0xFFAAA197),
                      fontFamily: 'GentiumPlus',
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 0, 4),
              child: Text(
                'The djed pillar carried the idea of stability and uprightness. Its raising made that stability physical: the pillar had to stand. This flow keeps that logic intact by asking what actually bears weight, what has been tested, and what can be raised again.',
                style: TextStyle(
                  color: Color(0xFF858B86),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 15,
                  height: 1.52,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _labelForCondition(DjedSupportCondition condition) =>
    switch (condition) {
      DjedSupportCondition.unassessed => 'choose',
      DjedSupportCondition.holding => 'holding',
      DjedSupportCondition.underPressure => 'under pressure',
      DjedSupportCondition.wobbling => 'wobbling',
    };

BoxDecoration _conditionDecoration(
  DjedSupportCondition condition, {
  bool active = false,
}) {
  final colors = switch (condition) {
    DjedSupportCondition.unassessed => const <Color>[
      Color(0xFFA08663),
      Color(0xFF77583A),
      Color(0xFF3F2C1B),
    ],
    DjedSupportCondition.holding => const <Color>[
      Color(0xFFFBDCA4),
      Color(0xFFE0873C),
      Color(0xFF8A4418),
    ],
    DjedSupportCondition.underPressure => const <Color>[
      Color(0xFFEBCBAD),
      Color(0xFFC58D61),
      Color(0xFF7D4D32),
    ],
    DjedSupportCondition.wobbling => const <Color>[
      Color(0xFFD9B47A),
      Color(0xFFB07A45),
      Color(0xFF69451F),
    ],
  };
  return BoxDecoration(
    borderRadius: BorderRadius.circular(15),
    border: active
        ? Border.all(color: const Color(0x61F5B963), width: 1)
        : null,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ),
    boxShadow: <BoxShadow>[
      const BoxShadow(
        color: Color(0x3D000000),
        blurRadius: 7,
        offset: Offset(0, 3),
      ),
      if (active) const BoxShadow(color: Color(0x1FF5B963), blurRadius: 15),
    ],
  );
}

BoxDecoration _capDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(13),
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFE8D59F), Color(0xFFC7A85F), Color(0xFF7B5826)],
    stops: <double>[0, .58, 1],
  ),
);

BoxDecoration _shaftDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(8),
  gradient: const LinearGradient(
    colors: <Color>[
      Color(0xFF7A4418),
      Color(0xFFE9A253),
      Color(0xFFB4682C),
      Color(0xFF4E2A10),
    ],
    stops: <double>[0, .42, .70, 1],
  ),
);

BoxDecoration _baseDecoration() => BoxDecoration(
  borderRadius: BorderRadius.circular(10),
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFE2C98C), Color(0xFFAD8340), Color(0xFF65461F)],
    stops: <double>[0, .58, 1],
  ),
);

Color _conditionAccent(DjedSupportCondition condition) => switch (condition) {
  DjedSupportCondition.unassessed => const Color(0xFF6F6C66),
  DjedSupportCondition.holding => const Color(0xFFCDB77A),
  DjedSupportCondition.underPressure => const Color(0xFFC99376),
  DjedSupportCondition.wobbling => const Color(0xFFE8B98A),
};

TextStyle _displayStyle({
  required double fontSize,
  Color color = DjedDetailTokens.bone,
  FontStyle? fontStyle,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    fontStyle: fontStyle,
    height: height,
  );
}

TextStyle _uiStyle({
  required double fontSize,
  Color color = DjedDetailTokens.goldDim,
  double? letterSpacing,
  FontStyle? fontStyle,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'GentiumPlus',
    fontSize: fontSize,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    height: height,
  );
}
