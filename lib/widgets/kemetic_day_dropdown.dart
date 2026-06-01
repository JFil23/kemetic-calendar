part of 'kemetic_day_info.dart';

/// Dropdown card widget for displaying Kemetic day information
class KemeticDayDropdown extends StatefulWidget {
  final KemeticDayInfo dayInfo;
  final VoidCallback onClose;
  final String dayKey;
  final int kYear;

  const KemeticDayDropdown({
    super.key,
    required this.dayInfo,
    required this.onClose,
    required this.dayKey,
    required this.kYear,
  });

  @override
  State<KemeticDayDropdown> createState() => _KemeticDayDropdownState();
}

class _KemeticDayDropdownState extends State<KemeticDayDropdown> {
  final ScrollController _scrollController = ScrollController();

  static const List<String> _meduFontFallback = ['GentiumPlus'];
  static const double _infoLineHeight = 1.35;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedKey = _parseDayKey(widget.dayKey);
    final bool isEpagomenal =
        parsedKey?.month == 13 || widget.dayKey.startsWith('epagomenal_');
    final int? epagomenalDay = isEpagomenal ? parsedKey?.day : null;
    final parsedDecan = _parseDayKeyForDecan(widget.dayKey);

    final String monthLine = isEpagomenal
        ? (widget.dayInfo.month.isNotEmpty
              ? widget.dayInfo.month
              : 'Heriu Renpet — The Births of the Gods — five days beyond the year')
        : widget.dayInfo.month;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.85;
    final canonicalDecanName = _canonicalDecanName(widget.dayKey).trim();
    final resolvedDecanName = canonicalDecanName.isNotEmpty
        ? canonicalDecanName
        : widget.dayInfo.decanName.trim();

    final String decanLine = isEpagomenal
        ? (widget.dayInfo.decanName.isNotEmpty
              ? widget.dayInfo.decanName
              : _epagomenalDayTitle(epagomenalDay))
        : resolvedDecanName;

    // Calculate the date string
    final String gregorianDateString = KemeticDayData.calculateGregorianDate(
      widget.dayKey,
      kYearParam: widget.kYear,
    );

    // Build speech lines (prefer curated speechName overrides when available)
    final monthId = parsedDecan?.kMonth;
    final KemeticMonth? monthMeta =
        (monthId != null && monthId >= 1 && monthId <= 13)
        ? getMonthById(monthId)
        : null;

    final String monthSpeakLine = monthMeta != null
        ? SpeechResolver.month(
            month: monthMeta,
            displayName: _stripEnglishCue(monthLine),
          )
        : _stripEnglishCue(widget.dayInfo.month);

    String decanSpeakLine;
    if (!isEpagomenal &&
        parsedDecan != null &&
        parsedDecan.kMonth >= 1 &&
        parsedDecan.kMonth <= 12 &&
        parsedDecan.decan >= 1 &&
        parsedDecan.decan <= 3) {
      final decanId = decanIdFromMonthAndIndex(
        monthIndex: parsedDecan.kMonth,
        decanInMonth: parsedDecan.decan,
      );
      final decanNames = DecanMetadata.decanNames[parsedDecan.kMonth];
      final decanLabel =
          (decanNames != null && decanNames.length >= parsedDecan.decan)
          ? decanNames[parsedDecan.decan - 1]
          : 'Decan ${parsedDecan.decan}';
      decanSpeakLine = SpeechResolver.decan(
        decanId: decanId,
        displayName: decanLabel,
      );
    } else {
      decanSpeakLine = SpeechResolver.decan(
        decanId: 0,
        displayName: _stripEnglishCue(decanLine),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: goldGloss,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF000000), // True black background
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF000000), // True black header
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: KemeticGold.text(
                              '☀️ Kemetic Date Alignment',
                              style: _goldTextStyle(fontSize: 18),
                            ),
                          ),
                          IconButton(
                            icon: KemeticGold.icon(Icons.close),
                            onPressed: () {
                              SpeechService.instance.stop();
                              widget.onClose();
                            },
                            padding: expandedIconButtonPadding(context),
                            constraints: expandedIconButtonConstraints(context),
                            visualDensity: expandedVisualDensity(context),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      decoration: const BoxDecoration(gradient: goldGloss),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontFamilyFallback: _meduFontFallback,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoSection(
                            'Gregorian Date:',
                            gregorianDateString,
                          ),
                          _buildInfoSection(
                            'Kemetic Date:',
                            widget.dayInfo.kemeticDate,
                          ),
                          _buildInfoSection('Season:', widget.dayInfo.season),
                          _buildInfoSectionWithSpeech(
                            label: 'Month:',
                            value: monthLine,
                            englishCue: null,
                            speakOverride: monthSpeakLine,
                            isPhonetic: true,
                          ),
                          _buildInfoSectionWithSpeech(
                            label: isEpagomenal
                                ? 'Epagomenal Day:'
                                : 'Decan Name:',
                            value: decanLine,
                            englishCue: null,
                            speakOverride: decanSpeakLine,
                            isPhonetic: true,
                          ),
                          if (!isEpagomenal)
                            _buildInfoSection(
                              'Star Cluster:',
                              widget.dayInfo.starCluster,
                            ),
                          _buildInfoSection(
                            'Ma\'at Principle:',
                            widget.dayInfo.maatPrinciple,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader('△ Cosmic Context'),
                          const SizedBox(height: 8),
                          Text(
                            widget.dayInfo.cosmicContext,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFCCCCCC),
                              height: 1.5,
                              fontFamilyFallback: _meduFontFallback,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            isEpagomenal ? '▽ Epagomenal Flow' : '▽ Decan Flow',
                          ),
                          const SizedBox(height: 12),
                          _buildDecanFlowTable(context),
                          const SizedBox(height: 24),
                          _buildSectionHeader('▽ Medu Neter Key'),
                          const SizedBox(height: 12),
                          _buildMeduNeterSection(context),
                          const SizedBox(height: 8), // Bottom padding
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

  String _epagomenalDayTitle(int? day) {
    switch (day) {
      case 1:
        return 'Birth of Asar (Osiris)';
      case 2:
        return 'Birth of Heru-wer (Horus the Elder)';
      case 3:
        return 'Birth of Set';
      case 4:
        return 'Birth of Aset (Isis)';
      case 5:
        return 'Birth of Nebet-Het (Nephthys)';
      default:
        return 'Heriu Renpet — Sacred Day';
    }
  }

  TextStyle _goldTextStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    double? height,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontFamilyFallback: _meduFontFallback,
    );
  }

  WidgetSpan _goldLabelSpan(
    String text, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    double? height,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: KemeticGold.text(
        text,
        style: _goldTextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        strutStyle: const StrutStyle(
          fontSize: 14,
          height: _infoLineHeight,
          forceStrutHeight: true,
        ),
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFCCCCCC),
            height: _infoLineHeight,
            fontFamilyFallback: _meduFontFallback,
          ),
          children: [
            _goldLabelSpan('$label ', height: _infoLineHeight),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _stripEnglishCue(String s) {
    // Remove anything in parentheses and trim.
    return s.split('(').first.trim();
  }

  Widget _buildInfoSectionWithSpeech({
    required String label,
    required String value,
    String? englishCue,
    String? speakOverride,
    bool isPhonetic = false,
  }) {
    final hasOverride =
        speakOverride != null && speakOverride.trim().isNotEmpty;
    final speakLine = hasOverride
        ? speakOverride.trim()
        : SpeechResolver.prose(base: value.trim(), englishCue: englishCue);
    final utteranceId = '${label.trim().toLowerCase()}:$speakLine';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              strutStyle: const StrutStyle(
                fontSize: 14,
                height: _infoLineHeight,
                forceStrutHeight: true,
              ),
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFCCCCCC),
                  height: _infoLineHeight,
                  fontFamilyFallback: _meduFontFallback,
                ),
                children: [
                  _goldLabelSpan('$label ', height: _infoLineHeight),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PronounceIconButton(
            speakText: speakLine,
            utteranceId: utteranceId,
            color: KemeticGold.base,
            size: 22,
            isPhonetic: isPhonetic,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return KemeticGold.text(title, style: _goldTextStyle(fontSize: 18));
  }

  Widget _buildDecanFlowTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3A3A3A)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF000000), // True black background
      ),
      child: Column(
        children: [
          // Table Header Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFF3A3A3A), width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: KemeticGold.text(
                    'Day',
                    style: _goldTextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: KemeticGold.text(
                    'Theme',
                    style: _goldTextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: KemeticGold.text(
                    'Action',
                    style: _goldTextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: KemeticGold.text(
                    'Reflection',
                    style: _goldTextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Table Data Rows
          ...widget.dayInfo.decanFlow.map((day) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF3A3A3A),
                    width: day == widget.dayInfo.decanFlow.last ? 0 : 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Column
                  SizedBox(
                    width: 50,
                    child: KemeticGold.text(
                      '${day.day}',
                      style: _goldTextStyle(fontSize: 12),
                    ),
                  ),
                  // Theme Column
                  Expanded(
                    flex: 2,
                    child: Text(
                      day.theme,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamilyFallback: _meduFontFallback,
                      ),
                    ),
                  ),
                  // Action Column
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        day.action,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCCCCCC),
                          fontFamilyFallback: _meduFontFallback,
                        ),
                      ),
                    ),
                  ),
                  // Reflection Column
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        day.reflection,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                          fontFamilyFallback: _meduFontFallback,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCCCCCC),
                fontFamilyFallback: _meduFontFallback,
              ),
              children: [
                _goldLabelSpan('• Glyph: '),
                TextSpan(text: widget.dayInfo.meduNeter.glyph),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCCCCCC),
                fontFamilyFallback: _meduFontFallback,
              ),
              children: [
                _goldLabelSpan('• Color Frequency: '),
                TextSpan(text: widget.dayInfo.meduNeter.colorFrequency),
              ],
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFCCCCCC),
              fontFamilyFallback: _meduFontFallback,
            ),
            children: [
              _goldLabelSpan('• Mantra: '),
              TextSpan(text: widget.dayInfo.meduNeter.mantra),
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

  // Dropdown width constant - good fit for mobile screens
  static const double dropdownWidth = 340;

  void show({
    required BuildContext context,
    required String dayKey,
    required int kYear,
    required Offset buttonPosition,
    required Size buttonSize,
  }) {
    hide(); // Hide any existing overlay

    final dayInfo = KemeticDayData.getInfoForDay(dayKey);

    if (dayInfo == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;

        return Stack(
          children: [
            // Background tap-to-dismiss
            GestureDetector(
              onTap: hide,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black54),
            ),
            // Dropdown centered horizontally, positioned below pressed date
            Positioned(
              // Center horizontally
              left: (screenWidth / 2) - (dropdownWidth / 2),
              // Keep vertical logic consistent (appears below pressed date)
              top: buttonPosition.dy + buttonSize.height + 8,
              child: SizedBox(
                width: dropdownWidth,
                child: KemeticDayDropdown(
                  dayInfo: dayInfo,
                  dayKey: dayKey,
                  kYear: kYear,
                  onClose: hide,
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// Button widget that shows the dropdown on long press
class KemeticDayButton extends StatefulWidget {
  final Widget child;
  final String dayKey;
  final int kYear;
  final bool openOnTap;
  final bool autoOpen;
  final VoidCallback? onOpen;

  const KemeticDayButton({
    super.key,
    required this.child,
    required this.dayKey,
    required this.kYear,
    this.openOnTap = false,
    this.autoOpen = false,
    this.onOpen,
  });

  @override
  State<KemeticDayButton> createState() => _KemeticDayButtonState();
}

class _KemeticDayButtonState extends State<KemeticDayButton> {
  final KemeticDayDropdownController _controller =
      KemeticDayDropdownController();
  final GlobalKey _buttonKey = GlobalKey();
  bool _autoOpenConsumed = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoOpenIfNeeded();
  }

  @override
  void didUpdateWidget(covariant KemeticDayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoOpen != widget.autoOpen ||
        oldWidget.dayKey != widget.dayKey ||
        oldWidget.kYear != widget.kYear) {
      _autoOpenConsumed = false;
    }
    _scheduleAutoOpenIfNeeded();
  }

  void _scheduleAutoOpenIfNeeded() {
    if (!widget.autoOpen || _autoOpenConsumed) return;
    _autoOpenConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showDropdown();
    });
  }

  void _showDropdown() {
    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _controller.show(
      context: context,
      dayKey: widget.dayKey,
      kYear: widget.kYear,
      buttonPosition: position,
      buttonSize: size,
    );
    widget.onOpen?.call();
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
      onTap: widget.openOnTap ? _showDropdown : null,
      onLongPress: _showDropdown,
      child: widget.child,
    );
  }
}
