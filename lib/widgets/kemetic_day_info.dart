import 'package:flutter/material.dart';

/// Model for Kemetic day information
class KemeticDayInfo {
  final String gregorianDate;
  final String kemeticDate;
  final String season;
  final String month;
  final String decanName;
  final String starCluster;
  final String maatPrinciple;
  final String cosmicContext;
  final List<DecanDayInfo> decanFlow;
  final MeduNeterKey meduNeter;

  KemeticDayInfo({
    required this.gregorianDate,
    required this.kemeticDate,
    required this.season,
    required this.month,
    required this.decanName,
    required this.starCluster,
    required this.maatPrinciple,
    required this.cosmicContext,
    required this.decanFlow,
    required this.meduNeter,
  });
}

class DecanDayInfo {
  final int day;
  final String theme;
  final String action;
  final String reflection;

  DecanDayInfo({
    required this.day,
    required this.theme,
    required this.action,
    required this.reflection,
  });
}

class MeduNeterKey {
  final String glyph;
  final String colorFrequency;
  final String mantra;

  MeduNeterKey({
    required this.glyph,
    required this.colorFrequency,
    required this.mantra,
  });
}

/// Sample data for Day 11 (Renwet II, Day 1)
class KemeticDayData {
  static final Map<String, KemeticDayInfo> dayInfoMap = {
    'renwet_11_2025': KemeticDayInfo(
      gregorianDate: 'October 26, 2025',
      kemeticDate: 'Renwet II, Day 1 (Day 11 of Renwet)',
      season: '🌾 Peret – Season of Emergence',
      month: 'Renwet (Month of Fertility and Growth)',
      decanName: 'Khery Heped en Renwet ("The Follower of Renwet\'s Offering")',
      starCluster: '✨ Likely linked to Orion\'s Belt (aligned with early Peret decans as Sahu rises higher).',
      maatPrinciple: 'Reciprocity / Right Exchange — what you give returns, and what you withhold decays.',
      cosmicContext: '''You're in the middle current of the Year of Djehuty — the season when Renwet's blessings (abundance, fertility, renewal) are converted into sustainable order.

This decan's light emerges after the initial burst of new life — it's about directing growth toward purpose.

• Solar phase: The Sun sits in Libra–Scorpio transition — balance giving way to transformation.

• Cosmic mirror: As Orion climbs and Sirius recedes, it's time to balance inner offerings (discipline, generosity) with outer work (structure, creation).''',
      decanFlow: [
        DecanDayInfo(
          day: 11,
          theme: 'Offering Begins',
          action: 'Dedicate your current project to something beyond self.',
          reflection: '"Who benefits from my effort?"',
        ),
        DecanDayInfo(
          day: 12,
          theme: 'Exchange',
          action: 'Trade or share an idea/resource.',
          reflection: '"What flows because I gave?"',
        ),
        DecanDayInfo(
          day: 13,
          theme: 'Circulation',
          action: 'Movement or travel; stretch your field.',
          reflection: '"What did I learn from contact?"',
        ),
        DecanDayInfo(
          day: 14,
          theme: 'Refinement',
          action: 'Edit, polish, or temper excess.',
          reflection: '"What strengthens through restraint?"',
        ),
        DecanDayInfo(
          day: 15,
          theme: 'Balance Check',
          action: 'Rest or fast; observe silence.',
          reflection: '"Where am I overspending energy?"',
        ),
        DecanDayInfo(
          day: 16,
          theme: 'Reconnection',
          action: 'Meet, call, or honor others.',
          reflection: '"Who restores my alignment?"',
        ),
        DecanDayInfo(
          day: 17,
          theme: 'Recommitment',
          action: 'Renew an oath, plan, or ritual.',
          reflection: '"What deserves another push?"',
        ),
        DecanDayInfo(
          day: 18,
          theme: 'Abundance Flow',
          action: 'Accept prosperity or recognition gracefully.',
          reflection: '"How do I receive with Ma\'at?"',
        ),
        DecanDayInfo(
          day: 19,
          theme: 'Return Offering',
          action: 'Give back again; a loop completes.',
          reflection: '"How can I close this exchange?"',
        ),
        DecanDayInfo(
          day: 20,
          theme: 'Transition',
          action: 'Prepare for the next decan.',
          reflection: '"What lesson is ready to move forward?"',
        ),
      ],
      meduNeter: MeduNeterKey(
        glyph: '𓂓 (Ka in motion) — symbolizes the act of extending energy outward in rightful proportion.',
        colorFrequency: 'Deep gold or warm copper (energy in movement).',
        mantra: '"My offering sustains the balance."',
      ),
    ),
  };

  static KemeticDayInfo? getInfoForDay(String dayKey) {
    return dayInfoMap[dayKey];
  }
}

/// Dropdown card widget for displaying Kemetic day information
class KemeticDayDropdown extends StatelessWidget {
  final KemeticDayInfo dayInfo;
  final VoidCallback onClose;

  const KemeticDayDropdown({
    Key? key,
    required this.dayInfo,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 600,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '☀️ Current Kemetic Date Alignment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('Gregorian Date:', dayInfo.gregorianDate),
                    _buildInfoSection('Kemetic Date:', dayInfo.kemeticDate),
                    _buildInfoSection('Season:', dayInfo.season),
                    _buildInfoSection('Month:', dayInfo.month),
                    _buildInfoSection('Decan Name:', dayInfo.decanName),
                    _buildInfoSection('Star Cluster:', dayInfo.starCluster),
                    _buildInfoSection('Ma\'at Principle:', dayInfo.maatPrinciple),
                    const SizedBox(height: 16),
                    _buildSectionHeader('△ Cosmic Context'),
                    const SizedBox(height: 8),
                    Text(
                      dayInfo.cosmicContext,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('▽ Decan 2 Flow (Renwet II, Days 11–20)'),
                    const SizedBox(height: 12),
                    _buildDecanFlowTable(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader('▽ Medu Neter Key'),
                    const SizedBox(height: 12),
                    _buildMeduNeterSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.white),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDecanFlowTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Day',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Theme',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Action',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Reflection',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...dayInfo.decanFlow.map((day) => _buildTableRow(context, day)),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, DecanDayInfo dayData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              dayData.day.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dayData.theme,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              dayData.action,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              dayData.reflection,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeduNeterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(
                  text: '• Glyph: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: dayInfo.meduNeter.glyph),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(
                  text: '• Color Frequency: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: dayInfo.meduNeter.colorFrequency),
              ],
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text: '• Mantra: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: dayInfo.meduNeter.mantra),
            ],
          ),
        ),
      ],
    );
  }
}

/// Controller/Service for managing the dropdown overlay
class KemeticDayDropdownController {
  OverlayEntry? _overlayEntry;

  void show({
    required BuildContext context,
    required String dayKey,
    required Offset buttonPosition,
    required Size buttonSize,
  }) {
    final dayInfo = KemeticDayData.getInfoForDay(dayKey);
    if (dayInfo == null) return;

    // Remove existing overlay if any
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: hide,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // Dropdown card
          Positioned(
            top: buttonPosition.dy + buttonSize.height + 8,
            left: buttonPosition.dx,
            right: MediaQuery.of(context).size.width - buttonPosition.dx - buttonSize.width,
            child: KemeticDayDropdown(
              dayInfo: dayInfo,
              onClose: hide,
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  bool get isShowing => _overlayEntry != null;
}

/// Wrapper widget to make any widget tappable for showing Kemetic day info
class KemeticDayButton extends StatefulWidget {
  final Widget child;
  final String dayKey;

  const KemeticDayButton({
    Key? key,
    required this.child,
    required this.dayKey,
  }) : super(key: key);

  @override
  State<KemeticDayButton> createState() => _KemeticDayButtonState();
}

class _KemeticDayButtonState extends State<KemeticDayButton> {
  final KemeticDayDropdownController _controller = KemeticDayDropdownController();
  final GlobalKey _buttonKey = GlobalKey();

  void _showDropdown() {
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _controller.show(
      context: context,
      dayKey: widget.dayKey,
      buttonPosition: position,
      buttonSize: size,
    );
  }

  @override
  void dispose() {
    _controller.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _showDropdown,
      child: widget.child,
    );
  }
}

