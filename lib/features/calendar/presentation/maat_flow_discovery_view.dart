import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/core/app_bottom_insets.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

@immutable
class MaatFlowDiscoveryCardData {
  const MaatFlowDiscoveryCardData({
    required this.flowKey,
    required this.title,
    required this.heroAsset,
    required this.glyph,
    required this.worldLine,
    required this.possibility,
    required this.arrivalLabel,
    required this.arrivalTitle,
    required this.arrivalPrompt,
    required this.accent,
    this.heroAlignment = Alignment.center,
  });

  final String flowKey;
  final String title;
  final String heroAsset;
  final Alignment heroAlignment;
  final String glyph;
  final String worldLine;
  final String possibility;
  final String arrivalLabel;
  final String arrivalTitle;
  final String arrivalPrompt;
  final Color accent;
}

const List<MaatFlowDiscoveryCardData>
kFourMaatFlowDiscoveryFixtures = <MaatFlowDiscoveryCardData>[
  MaatFlowDiscoveryCardData(
    flowKey: 'track-the-sky',
    title: 'Follow the Sky',
    heroAsset: 'assets/follow_the_sky/hero.png',
    heroAlignment: Alignment(0, 0.16),
    glyph: '𓇯',
    worldLine: 'Sky · as turnings occur',
    possibility:
        'The sky keeps moving. What you’re working toward moves with it.',
    arrivalLabel: 'Next turning',
    arrivalTitle: 'Autumn Equinox',
    arrivalPrompt: '“What do you want to make more room for so it can grow?”',
    accent: Color(0xFFA4B1FF),
  ),
  MaatFlowDiscoveryCardData(
    flowKey: 'the-offering-table',
    title: 'The Offering Table',
    heroAsset: 'assets/the_offering_table/hero.png',
    heroAlignment: Alignment(0, 0.16),
    glyph: '𓊵',
    worldLine: 'Provision · every morning for thirty days',
    possibility: 'Declare your intention before the day asks anything of you.',
    arrivalLabel: 'First morning',
    arrivalTitle: 'The First Water',
    arrivalPrompt: '“Before food, phone, or work, fill the cup.”',
    accent: Color(0xFFD8A442),
  ),
  MaatFlowDiscoveryCardData(
    flowKey: 'the-reading-house',
    title: 'The Reading House',
    heroAsset: 'assets/the_reading_house/hero.png',
    heroAlignment: Alignment(-0.18, 0.04),
    glyph: '𓉐',
    worldLine: 'House · on dates the host sets',
    possibility:
        'A guided book club. Choose your book, invite readers, or open it to anyone.',
    arrivalLabel: 'Starter sitting',
    arrivalTitle: 'Open the Text',
    arrivalPrompt: '“What is this opening asking you to hold privately?”',
    accent: Color(0xFFA8E6D1),
  ),
  MaatFlowDiscoveryCardData(
    flowKey: 'the-djed',
    title: 'The Djed',
    heroAsset: 'assets/the_djed/hero.png',
    heroAlignment: Alignment(0, 0.08),
    glyph: '𓊽',
    worldLine: 'Stability · nine sittings across thirty days',
    possibility:
        'Strengthen four parts of your life, one small move at a time.',
    arrivalLabel: 'First sitting',
    arrivalTitle: 'Set your footing',
    arrivalPrompt: '“Pick one ten-minute reset.”',
    accent: Color(0xFFE7C66C),
  ),
];

typedef MaatFlowDiscoveryOpen = void Function(String flowKey);

@immutable
class _DiscoveryOverlayCopy {
  const _DiscoveryOverlayCopy({
    required this.arrivalLabel,
    required this.calendarLabel,
    required this.inputLabel,
    required this.when,
    required this.entry,
    required this.observation,
    required this.prompt,
    required this.placeholder,
    required this.help,
    required this.emptyMessage,
    required this.filledMessage,
    required this.requiresInput,
    required this.marks,
  });

  final String arrivalLabel;
  final String calendarLabel;
  final String inputLabel;
  final String when;
  final String entry;
  final String observation;
  final String prompt;
  final String placeholder;
  final String help;
  final String emptyMessage;
  final String filledMessage;
  final bool requiresInput;
  final List<int> marks;
}

const Map<String, _DiscoveryOverlayCopy> _kDiscoveryOverlayCopy =
    <String, _DiscoveryOverlayCopy>{
      'track-the-sky': _DiscoveryOverlayCopy(
        arrivalLabel: 'The next turning',
        calendarLabel: 'The next thirty days in Kemetic time',
        inputLabel: 'Your intention for this turning',
        when: 'Balance',
        entry: 'Autumn Equinox',
        observation: 'Day and night come nearly even.',
        prompt: 'What do you want to make more room for so it can grow?',
        placeholder: 'Make room for…',
        help: 'Choose now or leave this open until the equinox returns to you.',
        emptyMessage: 'Flow carried. The intention is still open.',
        filledMessage: 'Flow carried with this intention.',
        requiresInput: false,
        marks: <int>[4, 13, 22, 29],
      ),
      'the-offering-table': _DiscoveryOverlayCopy(
        arrivalLabel: 'First morning',
        calendarLabel: 'Thirty mornings in Kemetic time',
        inputLabel: 'What was fed?',
        when: 'Personal Table · Day 1',
        entry: 'The First Water',
        observation: 'Before food, phone, or work, fill the cup.',
        prompt:
            'Name one basic need that has been unmet for three days or more.',
        placeholder: 'What did you provide today?',
        help:
            'Required: place water and speak the line. Everything else is optional. Two minutes is enough.',
        emptyMessage:
            'Flow carried. The First Water is ready for your morning.',
        filledMessage: 'Flow carried. Your first provision stays private.',
        requiresInput: false,
        marks: <int>[
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          17,
          18,
          19,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
          30,
        ],
      ),
      'the-reading-house': _DiscoveryOverlayCopy(
        arrivalLabel: 'A starter sitting',
        calendarLabel: 'Sittings in Kemetic time',
        inputLabel: 'First book',
        when: 'Private first',
        entry: 'Open the Text',
        observation: '',
        prompt: 'What is this opening asking you to hold privately?',
        placeholder: 'Book title',
        help:
            'Choose a book, decide who may enter, and give invited readers time to answer before anyone has to place a sitting.',
        emptyMessage: 'Name the book before opening the house.',
        filledMessage: 'The house is open. It is not scheduled yet.',
        requiresInput: true,
        marks: <int>[],
      ),
      'the-djed': _DiscoveryOverlayCopy(
        arrivalLabel: 'First sitting',
        calendarLabel: 'Nine sittings across thirty days',
        inputLabel: 'Your first reset',
        when: 'Personal pillar · Sitting 1',
        entry: 'Set your footing',
        observation: '',
        prompt: 'Pick one ten-minute reset.',
        placeholder: 'Name the first reset',
        help:
            'Name the first move, or carry the pillar and decide at the first sitting.',
        emptyMessage: 'Flow carried. The first sitting is ready.',
        filledMessage: 'Flow carried. Your first reset stays private.',
        requiresInput: false,
        marks: <int>[1, 4, 8, 12, 16, 20, 24, 27, 30],
      ),
    };

/// Fixture-first visual authority for the four-flow discovery surface.
///
/// Routing and joined-state behavior are deliberately injected. The widget
/// owns only the approved hierarchy and responsive presentation.
class MaatFlowDiscoveryView extends StatefulWidget {
  const MaatFlowDiscoveryView({
    super.key,
    this.cards = kFourMaatFlowDiscoveryFixtures,
    this.onOpen,
    this.onCreate,
    this.onClose,
    this.createKey,
  });

  final List<MaatFlowDiscoveryCardData> cards;
  final MaatFlowDiscoveryOpen? onOpen;
  final VoidCallback? onCreate;
  final VoidCallback? onClose;
  final Key? createKey;

  @override
  State<MaatFlowDiscoveryView> createState() => _MaatFlowDiscoveryViewState();
}

class _MaatFlowDiscoveryViewState extends State<MaatFlowDiscoveryView> {
  MaatFlowDiscoveryCardData? _openCard;
  final TextEditingController _intentionController = TextEditingController();
  String _carryMessage = '';

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  void _openOverlay(MaatFlowDiscoveryCardData card) {
    _intentionController.clear();
    setState(() {
      _openCard = card;
      _carryMessage = '';
    });
  }

  void _closeOverlay() {
    _intentionController.clear();
    setState(() {
      _openCard = null;
      _carryMessage = '';
    });
  }

  void _carryOpenCard() {
    final card = _openCard;
    if (card == null) return;
    final copy =
        _kDiscoveryOverlayCopy[card.flowKey] ??
        _kDiscoveryOverlayCopy['track-the-sky']!;
    final value = _intentionController.text.trim();
    final blocked = copy.requiresInput && value.isEmpty;
    setState(() {
      _carryMessage = blocked
          ? copy.emptyMessage
          : (value.isEmpty ? copy.emptyMessage : copy.filledMessage);
    });
    if (blocked) return;
    widget.onOpen?.call(card.flowKey);
  }

  @override
  Widget build(BuildContext context) {
    final openCard = _openCard;
    return PopScope(
      canPop: openCard == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || openCard == null) return;
        _closeOverlay();
      },
      child: Scaffold(
        key: const ValueKey<String>('maat-flow-discovery-view'),
        backgroundColor: MaatFlowListTokens.pageBg,
        appBar: AppBar(
          backgroundColor: MaatFlowListTokens.pageBg,
          foregroundColor: MaatFlowListTokens.gold,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 64,
          leadingWidth: 70,
          leading: openCard != null
              ? IconButton(
                  key: const ValueKey<String>('maat-flow-discovery-back'),
                  tooltip: 'Back to Flows',
                  padding: const EdgeInsets.only(left: 15),
                  alignment: Alignment.centerLeft,
                  onPressed: _closeOverlay,
                  icon: const Text(
                    '←',
                    style: TextStyle(
                      color: Color(0xFFD4AE43),
                      fontSize: 28,
                      height: 1,
                    ),
                  ),
                )
              : widget.onClose == null
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 18),
                    child: Text(
                      'ḥꜣw',
                      style: TextStyle(
                        color: Color(0xFF8A7030),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 21,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Back',
                  padding: const EdgeInsets.only(left: 15),
                  alignment: Alignment.centerLeft,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back, size: 22),
                ),
          title: Text(
            openCard?.title ?? 'Flows',
            style: const TextStyle(
              color: Color(0xFFD4AE43),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 25,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: IconButton(
                key:
                    widget.createKey ??
                    const ValueKey<String>('maat-flow-discovery-create'),
                tooltip: 'Create a flow',
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add, size: 24),
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFF17150F)),
          ),
        ),
        body: openCard != null
            ? _MaatFlowDiscoveryOverlay(
                card: openCard,
                copy:
                    _kDiscoveryOverlayCopy[openCard.flowKey] ??
                    _kDiscoveryOverlayCopy['track-the-sky']!,
                intentionController: _intentionController,
                message: _carryMessage,
                onCarry: _carryOpenCard,
              )
            : widget.cards.isEmpty
            ? const _DiscoveryEmptyState()
            : ListView.builder(
                key: const ValueKey<String>('maat-flow-discovery-scroll'),
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  math.max(
                    30,
                    AppBottomInsets.contentBottomPadding(context) + 14,
                  ),
                ),
                itemCount: widget.cards.length + 1,
                itemBuilder: (context, index) {
                  if (index == widget.cards.length) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(0, 8, 0, 14),
                      child: Center(
                        child: Text(
                          '𓂀',
                          style: TextStyle(
                            color: Color(0xFF45381A),
                            fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                            fontSize: 24,
                          ),
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: MaatFlowDiscoveryCard(
                      data: widget.cards[index],
                      featured: index == 0,
                      onOpen: () => _openOverlay(widget.cards[index]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class MaatFlowDiscoveryCard extends StatelessWidget {
  const MaatFlowDiscoveryCard({
    super.key,
    required this.data,
    required this.featured,
    this.onOpen,
  });

  final MaatFlowDiscoveryCardData data;
  final bool featured;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final imageHeight =
        (featured ? 216.0 : 190.0) + ((textScale - 1).clamp(0, 1) * 10);
    return Semantics(
      container: true,
      label: data.title,
      child: DecoratedBox(
        key: ValueKey<String>('maat-flow-discovery-card-${data.flowKey}'),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0B07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF261E0D)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 42,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      data.heroAsset,
                      key: ValueKey<String>(
                        'maat-flow-discovery-image-${data.flowKey}',
                      ),
                      fit: BoxFit.cover,
                      alignment: data.heroAlignment,
                      filterQuality: FilterQuality.medium,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: <double>[0.25, 0.58, 1],
                          colors: <Color>[
                            Color(0x0A000000),
                            Color(0x29050504),
                            Color(0xFF0D0B07),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            data.glyph,
                            style: TextStyle(
                              color: data.accent,
                              fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                              fontSize: 21,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.worldLine.toUpperCase(),
                              style: TextStyle(
                                color: data.accent,
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontSize: 11,
                                letterSpacing: 1.8,
                                height: 1.25,
                                shadows: const <Shadow>[
                                  Shadow(color: Colors.black, blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _HawStewardshipMark(),
                    const SizedBox(height: 5),
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Color(0xFFD4AE43),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                        height: 0.98,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.possibility,
                      style: const TextStyle(
                        color: Color(0xFFD5D1C8),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 19,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Divider(height: 1, color: Color(0xFF2A2415)),
                    const SizedBox(height: 13),
                    Text(
                      data.arrivalLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF8A7030),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 10,
                        letterSpacing: 2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.arrivalTitle,
                      style: const TextStyle(
                        color: Color(0xFFC8C4BC),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.arrivalPrompt,
                      style: const TextStyle(
                        color: Color(0xFFC8C4BC),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 42,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 105),
                          child: OutlinedButton(
                            key: ValueKey<String>(
                              'maat-flow-discovery-open-${data.flowKey}',
                            ),
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD8B64E),
                              disabledForegroundColor: const Color(0xFFD8B64E),
                              backgroundColor: const Color(0xFF070604),
                              side: const BorderSide(color: Color(0xFF9D8238)),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('Open'),
                          ),
                        ),
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
}

class _HawStewardshipMark extends StatelessWidget {
  const _HawStewardshipMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF0A0805),
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF5A4A20)),
              ),
            ),
            child: const Text(
              'ḥ',
              style: TextStyle(
                color: Color(0xFF8A7030),
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ḥꜣw',
            style: TextStyle(
              color: Color(0xFF6A6660),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryEmptyState extends StatelessWidget {
  const _DiscoveryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          'No flows are available right now.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF918D87),
            fontFamily: MaatFlowListTokens.fontFamily,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _MaatFlowDiscoveryOverlay extends StatelessWidget {
  const _MaatFlowDiscoveryOverlay({
    required this.card,
    required this.copy,
    required this.intentionController,
    required this.message,
    required this.onCarry,
  });

  final MaatFlowDiscoveryCardData card;
  final _DiscoveryOverlayCopy copy;
  final TextEditingController intentionController;
  final String message;
  final VoidCallback onCarry;

  static const List<String> _decanNumerals = <String>['I', 'II', 'III'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey<String>('maat-flow-discovery-detail-${card.flowKey}'),
      padding: EdgeInsets.only(
        bottom: math.max(25, AppBottomInsets.contentBottomPadding(context) + 14),
      ),
      children: <Widget>[
        SizedBox(
          height: 258,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                card.heroAsset,
                fit: BoxFit.cover,
                alignment: card.heroAlignment,
                filterQuality: FilterQuality.medium,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x14000000), Color(0xFF050504)],
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 25,
                child: Text(
                  '${card.glyph}  ${card.worldLine}'.toUpperCase(),
                  style: TextStyle(
                    color: card.accent,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 11,
                    letterSpacing: 1.9,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                card.title,
                style: const TextStyle(
                  color: Color(0xFFD4AE43),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  height: 0.98,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.possibility,
                style: const TextStyle(
                  color: Color(0xFFD5D1C8),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 19,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Kept by ḥꜣw',
                style: TextStyle(
                  color: Color(0xFF6A6660),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 23),
              _overlaySectionLabel(copy.arrivalLabel),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: card.accent, width: 2),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 3, 0, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.when.toUpperCase(),
                      style: TextStyle(
                        color: card.accent,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      copy.entry,
                      style: const TextStyle(
                        color: Color(0xFFC8C4BC),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                        height: 1.05,
                      ),
                    ),
                    if (copy.observation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        copy.observation,
                        style: const TextStyle(
                          color: Color(0xFF918D87),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      copy.prompt,
                      style: const TextStyle(
                        color: Color(0xFFC8C4BC),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _overlaySectionLabel(copy.calendarLabel),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF2A2415))),
                ),
                child: Column(
                  children: <Widget>[
                    for (var band = 0; band < 3; band++)
                      _overlayDecanBand(
                        numeral: _decanNumerals[band],
                        firstDay: band * 10 + 1,
                        accent: card.accent,
                        marks: copy.marks,
                      ),
                  ],
                ),
              ),
              _overlaySectionLabel(copy.inputLabel),
              SizedBox(
                height: 51,
                child: TextField(
                  key: const ValueKey<String>('maat-flow-discovery-intention'),
                  controller: intentionController,
                  cursorColor: const Color(0xFFD4AE43),
                  style: const TextStyle(
                    color: Color(0xFFC8C4BC),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                  ),
                  decoration: InputDecoration(
                    hintText: copy.placeholder,
                    hintStyle: const TextStyle(
                      color: Color(0xFF5D5751),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0A0908),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(9),
                        topRight: Radius.circular(9),
                      ),
                      borderSide: BorderSide(color: Color(0xFF2A2314)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(9),
                        topRight: Radius.circular(9),
                      ),
                      borderSide: BorderSide(color: Color(0xFF8A7030)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                copy.help,
                style: const TextStyle(
                  color: Color(0xFF6A6660),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  key: const ValueKey<String>('maat-flow-discovery-carry'),
                  onPressed: onCarry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD8B64E),
                    backgroundColor: const Color(0xFF070604),
                    side: const BorderSide(color: Color(0xFFD4AE43), width: 1.5),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Carry this flow'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 20,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA8A094),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _overlaySectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 11),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2415))),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 17),
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8A7030),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 10,
              letterSpacing: 2.2,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _overlayDecanBand({
    required String numeral,
    required int firstDay,
    required Color accent,
    required List<int> marks,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 13, 0, 17),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2415))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
              child: Text(
                '$numeral · days $firstDay–${firstDay + 9}'.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF8A7030),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 11,
                  letterSpacing: 1.7,
                ),
              ),
            ),
            Row(
              children: <Widget>[
                for (var n = firstDay; n < firstDay + 10; n++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: marks.contains(n)
                                      ? accent
                                      : const Color(0xFF30250F),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$n',
                                  style: TextStyle(
                                    color: marks.contains(n)
                                        ? const Color(0xFFC8C4BC)
                                        : const Color(0xFF9D8654),
                                    fontFamily: MaatFlowListTokens.fontFamily,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (marks.contains(n))
                              Positioned(
                                bottom: -5,
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
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
          ],
        ),
      ),
    );
  }
}
