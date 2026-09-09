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
    heroAsset: 'assets/follow_the_sky/discovery_hero.jpg',
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
    heroAsset: 'assets/the_offering_table/discovery_hero.jpg',
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
    heroAsset: 'assets/the_reading_house/reference_hero.jpg',
    heroAlignment: Alignment(0, 0.04),
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

/// Fixture-first visual authority for the four-flow discovery surface.
///
/// Routing and joined-state behavior are deliberately injected. The widget
/// owns only the approved hierarchy and responsive presentation.
class MaatFlowDiscoveryView extends StatelessWidget {
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

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      primary: false,
      backgroundColor: MaatFlowListTokens.pageBg,
      foregroundColor: MaatFlowListTokens.gold,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 64,
      leadingWidth: 70,
      leading: onClose == null
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
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back, size: 22),
            ),
      title: const Text(
        'Flows',
        style: TextStyle(
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
                createKey ??
                const ValueKey<String>('maat-flow-discovery-create'),
            tooltip: 'Create a flow',
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 24),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF17150F)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('maat-flow-discovery-view'),
      backgroundColor: MaatFlowListTokens.pageBg,
      body: SafeArea(
        bottom: false,
        child: cards.isEmpty
            ? ListView(
                children: <Widget>[
                  SizedBox(height: 65, child: _buildHeader()),
                  const SizedBox(height: 360, child: _DiscoveryEmptyState()),
                ],
              )
            : ListView.builder(
                key: const ValueKey<String>('maat-flow-discovery-scroll'),
                padding: EdgeInsets.only(
                  bottom: math.max(
                    30,
                    AppBottomInsets.contentBottomPadding(context) + 14,
                  ),
                ),
                itemCount: cards.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SizedBox(height: 65, child: _buildHeader());
                  }
                  final cardIndex = index - 1;
                  if (cardIndex == cards.length) {
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
                  final card = cards[cardIndex];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                    child: MaatFlowDiscoveryCard(
                      data: card,
                      featured: cardIndex == 0,
                      onOpen: onOpen == null
                          ? null
                          : () => onOpen!(card.flowKey),
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
                        letterSpacing: -0.1,
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
