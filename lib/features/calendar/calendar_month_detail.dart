part of 'calendar_page.dart';

class _MonthDetailPage extends StatefulWidget {
  const _MonthDetailPage({
    required this.kYear,
    required this.kMonth,
    required this.todayMonth,
    required this.todayDay,
    required this.showGregorian,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.noteColorResolver,
    required this.decanIndex, // null => month view; 0..2 => specific decan
    this.flowNameGetter,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
  });

  final int kYear;
  final int kMonth;
  final int? todayMonth;
  final int? todayDay;
  final bool showGregorian;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Color Function(_Note) noteColorResolver;
  final int? decanIndex;
  final String? Function(_Note)? flowNameGetter;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  @override
  State<_MonthDetailPage> createState() => _MonthDetailPageState();
}

class _MonthDetailPageState extends State<_MonthDetailPage> {
  final _tabTitles = const ['Info', 'Events', 'Planner'];
  // Track the visible month page (0-based) for horizontal swipes.
  late final PageController _pageController;
  static const int _pageSeed =
      12000; // Large seed to allow long-range swiping in both directions.
  static const int _monthsInYear = 13;
  late int _currentPage;
  int? _currentDecanIndex;
  int? _selectedDay;
  int _infoSelectionSerial = 0;

  @override
  void initState() {
    super.initState();
    _currentDecanIndex = widget.decanIndex;
    _selectedDay = null;
    _currentPage = _pageSeed;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    SpeechService.instance.stop();
    _pageController.dispose();
    super.dispose();
  }

  String? _extractEnglishCue(String? title) {
    if (title == null) return null;
    final match = RegExp(r'"([^"]+)"').firstMatch(title);
    return match?.group(1);
  }

  String _buildSpeakLine(int month, int? decanIndex) {
    final monthMeta = getMonthById(month);
    if (decanIndex == null) {
      return SpeechResolver.month(
        month: monthMeta,
        displayName: monthMeta.displayShort,
      );
    }
    if (month < 1 || month > 12) return monthMeta.displayFull;
    final decanInMonth = decanIndex + 1;
    final decanId = decanIdFromMonthAndIndex(
      monthIndex: month,
      decanInMonth: decanInMonth,
    );
    final shortName =
        (DecanMetadata.decanNames[month] ?? const [''])[decanInMonth - 1];
    final englishCue = _extractEnglishCue(DecanMetadata.decanTitles[shortName]);
    return SpeechResolver.decan(
      decanId: decanId,
      displayName: shortName,
      englishCue: englishCue,
    );
  }

  int _floorDiv(int a, int b) {
    // Dart's integer division truncates toward zero; adjust to true floor.
    return (a - (a % b)) ~/ b;
  }

  int _mod(int a, int b) {
    final r = a % b;
    return r < 0 ? r + b : r;
  }

  int _daysInMonth(int year, int month) {
    if (month == 13) {
      return KemeticMath.isLeapKemeticYear(year) ? 6 : 5;
    }
    return 30;
  }

  (int year, int month) _yearMonthForPage(int page) {
    final offset = page - _pageSeed;
    final totalMonths = (widget.kMonth - 1) + offset;
    final monthIndex = _mod(totalMonths, _monthsInYear); // 0-based
    final month = monthIndex + 1;
    final yearOffset = _floorDiv(totalMonths, _monthsInYear);
    final year = widget.kYear + yearOffset;
    return (year, month);
  }

  List<_Note> _notesFor(int ky, int km, int kd) {
    final state = CalendarPage.globalKey.currentState;
    if (state != null) {
      return state._getNotes(ky, km, kd);
    }
    return widget.notesGetter(km, kd);
  }

  List<Color> _flowColorsFor(int ky, int km, int kd) {
    final state = CalendarPage.globalKey.currentState;
    if (state != null) {
      return state.getFlowColorsForDay(ky, km, kd);
    }
    return widget.flowColorsGetter(ky, km, kd);
  }

  void _setInfoSelection({
    required int? decanIndex,
    required int? selectedDay,
  }) {
    setState(() {
      _currentDecanIndex = decanIndex;
      _selectedDay = selectedDay;
      _infoSelectionSerial++;
    });
    SpeechService.instance.stop();
  }

  void _handleDayTap(BuildContext ctx, int ky, int km, int kd) {
    final state = CalendarPage.globalKey.currentState;
    if (state != null) {
      state._openDayView(ctx, ky, km, kd);
      return;
    }
    widget.onDayTap(ctx, km, kd);
  }

  Future<void> _jumpToToday() async {
    final today = KemeticMath.fromGregorian(DateTime.now());
    final monthOffset =
        (today.kYear - widget.kYear) * _monthsInYear +
        (today.kMonth - widget.kMonth);
    final targetPage = _pageSeed + monthOffset;
    setState(() {
      _currentDecanIndex = null;
      _selectedDay = null;
      _infoSelectionSerial++;
    });
    SpeechService.instance.stop();
    await _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  String? _scrubDetail(String? detail) {
    if (detail == null) return null;
    final blocked = RegExp(
      r'google calendar|automatically created|official google calendar|gmail|mail\.google\.com|observance|holiday|to hide observances|created from an email|to see detailed information|use the official',
      caseSensitive: false,
    );
    final lines = detail
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !blocked.hasMatch(l))
        .toList();
    if (lines.isEmpty) return null;
    // If the only remaining line is a generic label (e.g., "Observance"), drop it.
    if (lines.length == 1 && lines.first.toLowerCase() == 'observance') {
      return null;
    }
    return lines.join('\n');
  }

  String _timeLabel(_Note n) {
    if (n.allDay) return 'All day';
    String fmt(TimeOfDay t) {
      final h = t.hour;
      final m = t.minute;
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    }

    final start = n.start ?? const TimeOfDay(hour: 9, minute: 0);
    final end = n.end;
    if (end == null) return fmt(start);
    return '${fmt(start)} – ${fmt(end)}';
  }

  List<_MonthEvent> _buildMonthEvents(int year, int month) {
    final items = <_MonthEvent>[];
    final daysInMonth = _daysInMonth(year, month);

    for (int day = 1; day <= daysInMonth; day++) {
      if (_selectedDay != null && day != _selectedDay) continue;
      if (month != 13 && _selectedDay == null && _currentDecanIndex != null) {
        final start = _currentDecanIndex! * 10 + 1;
        final end = start + 9;
        if (day < start || day > end) continue;
      }
      final notes = _notesFor(year, month, day);
      for (final n in notes) {
        final startMin = n.allDay
            ? -1
            : ((n.start?.hour ?? 9) * 60 + (n.start?.minute ?? 0));
        final flowName = widget.flowNameGetter?.call(n);
        final cleanedDetail = _scrubDetail(n.detail);
        final displayTitle = (() {
          final title = n.title.trim();
          if (title.isNotEmpty) return title;
          if (flowName != null && flowName.trim().isNotEmpty) {
            return flowName.trim();
          }
          return 'Event';
        })();

        items.add(
          _MonthEvent(
            day: day,
            note: n,
            displayTitle: displayTitle,
            flowName: flowName,
            timeLabel: _timeLabel(n),
            color: widget.noteColorResolver(n),
            sortKey: day * 1440 + startMin,
            detail: cleanedDetail,
            location: (n.location ?? '').trim().isEmpty
                ? null
                : n.location!.trim(),
          ),
        );
      }
    }
    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CalendarTone.calendarBlack,
      appBar: AppBar(
        backgroundColor: _CalendarTone.calendarBlack,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          icon: const _GlossyIcon(
            Icons.close,
            gradient: _CalendarTone.mutedGoldGloss,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextButton.icon(
          onPressed: _jumpToToday,
          icon: const KemeticAppBarTodayIcon(
            boxSize: 20,
            glyphSize: 16,
            glyphOffset: Offset(1.5, -1),
          ),
          label: const Text(
            'Today',
            style: TextStyle(
              color: _CalendarTone.antiqueGold,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _CalendarTone.antiqueGold.withValues(alpha: 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          if (!mounted) return;
          setState(() {
            _currentPage = page;
            _currentDecanIndex = null;
            _selectedDay = null;
            _infoSelectionSerial++;
          });
          SpeechService.instance.stop();
        },
        itemBuilder: (ctx, index) {
          final (pageYear, month) = _yearMonthForPage(index);
          final isActive = index == _currentPage;
          final decanIndex = (isActive && month != 13)
              ? _currentDecanIndex
              : null;
          final monthMeta = getMonthById(month);
          final seasonLabel = monthMeta.season.label;
          final infoTitle = (decanIndex == null)
              ? monthMeta.displayFull
              : (DecanMetadata.decanNames[month] ??
                    const ['Decan A', 'Decan B', 'Decan C'])[decanIndex];
          final infoBody = (decanIndex == null || month == 13)
              ? (_monthInfo[month] ?? '')
              : _decanInfo[(month - 1) * 3 + decanIndex];
          final infoLinks = (decanIndex == null || month == 13)
              ? (_monthLinkMap[month] ?? const [])
              : _decanLinkMap;
          final backLabel = decanIndex == null ? 'Month Info' : 'Decan Info';

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 10),
                  children: [
                    if (month == 13)
                      _EpagomenalCard(
                        kYear: pageYear,
                        todayMonth: widget.todayMonth,
                        todayDay: widget.todayDay,
                        todayDayKey: null,
                        notesGetter: (m, d) => _notesFor(pageYear, m, d),
                        flowColorsGetter: (ky, km, kd) =>
                            _flowColorsFor(pageYear, km, kd),
                        onDayTap: (c, m, d) =>
                            _setInfoSelection(decanIndex: null, selectedDay: d),
                        showGregorian: widget.showGregorian,
                        flowNameGetter: widget.flowNameGetter,
                        onManageFlows: widget.onManageFlows,
                        onEditNote: widget.onEditNote,
                        onDeleteNote: widget.onDeleteNote,
                        onShareNote: widget.onShareNote,
                        onEditReminder: widget.onEditReminder,
                        onEndReminder: widget.onEndReminder,
                        onShareReminder: widget.onShareReminder,
                        onEndFlow: widget.onEndFlow,
                        onAppendToJournal: widget.onAppendToJournal,
                      )
                    else
                      _MonthCard(
                        kYear: pageYear,
                        kMonth: month,
                        seasonShort: seasonLabel,
                        todayMonth: widget.todayMonth,
                        todayDay: widget.todayDay,
                        todayDayKey: null,
                        notesGetter: (m, d) => _notesFor(pageYear, m, d),
                        flowColorsGetter: (ky, km, kd) =>
                            _flowColorsFor(pageYear, km, kd),
                        onDayTap: (c, m, d) => _setInfoSelection(
                          decanIndex: ((d - 1) / 10).floor(),
                          selectedDay: d,
                        ),
                        showGregorian: widget.showGregorian,
                        framedSurface: true,
                        flowNameGetter: widget.flowNameGetter,
                        onManageFlows: widget.onManageFlows,
                        onEditNote: widget.onEditNote,
                        onDeleteNote: widget.onDeleteNote,
                        onShareNote: widget.onShareNote,
                        onEditReminder: widget.onEditReminder,
                        onEndReminder: widget.onEndReminder,
                        onShareReminder: widget.onShareReminder,
                        onEndFlow: widget.onEndFlow,
                        onAppendToJournal: widget.onAppendToJournal,
                        onMonthHeaderTap: (_) => _setInfoSelection(
                          decanIndex: null,
                          selectedDay: null,
                        ),
                        onDecanTap: (_, idx) => _setInfoSelection(
                          decanIndex: idx,
                          selectedDay: null,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x0FFFFFFF)),
              Expanded(
                child: DefaultTabController(
                  length: _tabTitles.length,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: _CalendarTone.antiqueGold.withValues(
                          alpha: 0.88,
                        ),
                        unselectedLabelColor: const Color(0xFF4C3F24),
                        indicatorColor: _CalendarTone.antiqueGold.withValues(
                          alpha: 0.76,
                        ),
                        indicatorWeight: 1.4,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: _CalendarTone.antiqueGold.withValues(
                          alpha: 0.055,
                        ),
                        labelStyle: const TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [for (final t in _tabTitles) Tab(text: t)],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _InfoTab(
                              title: infoTitle,
                              monthTitleShort: decanIndex == null
                                  ? monthMeta.displayShort
                                  : null,
                              monthTitleTransliteration: decanIndex == null
                                  ? monthMeta.displayTransliteration
                                  : null,
                              body: infoBody,
                              speakText: _buildSpeakLine(month, decanIndex),
                              linkMap: infoLinks,
                              backLabel: backLabel,
                              inlineNodes: _decanInlineNodes,
                              selectionSerial: _infoSelectionSerial,
                            ),
                            _EventsTab(
                              monthLabel: getMonthById(month).displayShort,
                              notes: _buildMonthEvents(pageYear, month),
                              onOpenDay: (d) =>
                                  _handleDayTap(context, pageYear, month, d),
                            ),
                            const TodaysAlignmentPage(embedded: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthEvent {
  final int day;
  final _Note note;
  final String displayTitle;
  final String? flowName;
  final String timeLabel;
  final Color color;
  final int sortKey;
  final String? detail;
  final String? location;

  _MonthEvent({
    required this.day,
    required this.note,
    required this.displayTitle,
    required this.flowName,
    required this.timeLabel,
    required this.color,
    required this.sortKey,
    this.detail,
    this.location,
  });
}

class _InfoTab extends StatefulWidget {
  final String title;
  final String? monthTitleShort;
  final String? monthTitleTransliteration;
  final String body;
  final String speakText;
  final List<KemeticNodeLink> linkMap;
  final String backLabel;
  final Map<String, _InlineNodeContent> inlineNodes;
  final int selectionSerial;

  const _InfoTab({
    required this.title,
    this.monthTitleShort,
    this.monthTitleTransliteration,
    required this.body,
    required this.speakText,
    required this.linkMap,
    required this.backLabel,
    required this.inlineNodes,
    required this.selectionSerial,
  });

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  static const TextStyle _bodyStyle = TextStyle(
    color: _CalendarTone.bodyStone,
    fontSize: _CalendarScale.infoBody,
    height: 1.47,
    fontFamily: 'CormorantGaramond',
    fontWeight: FontWeight.w400,
  );
  static const TextStyle _metaStyle = TextStyle(
    color: Color(0xFFAA9151),
    fontSize: _CalendarScale.infoMeta,
    height: 1.30,
    fontStyle: FontStyle.italic,
    fontFamily: 'CormorantGaramond',
    fontWeight: FontWeight.w400,
  );

  final ScrollController _infoController = ScrollController();
  final ScrollController _nodeController = ScrollController();
  final List<_InfoNodeEntry> _history = [];
  double _infoOffset = 0;

  @override
  void didUpdateWidget(covariant _InfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionSerial == oldWidget.selectionSerial) {
      return;
    }
    SpeechService.instance.stop();
    _history.clear();
    _infoOffset = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_infoController.hasClients) return;
      _infoController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _infoController.dispose();
    _nodeController.dispose();
    super.dispose();
  }

  _InfoNodeEntry? get _activeNode => _history.isEmpty ? null : _history.last;

  @override
  Widget build(BuildContext context) {
    final node = _activeNode;
    final isNodeView = node != null;
    final libraryNode = node?.node;
    final title = node?.title ?? widget.title;
    final body = node?.body ?? widget.body;
    final links = node?.links ?? widget.linkMap;
    final useMonthTitle =
        !isNodeView &&
        widget.monthTitleShort != null &&
        widget.monthTitleTransliteration != null;

    return SingleChildScrollView(
      controller: isNodeView ? _nodeController : _infoController,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNodeView) _buildBackRow(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: useMonthTitle
                    ? _SoftMonthNameTitle(
                        shortName: widget.monthTitleShort!,
                        transliteration: widget.monthTitleTransliteration!,
                        fontSize: _CalendarScale.monthTitleMain,
                        opacity: 0.96,
                      )
                    : Text(
                        title,
                        style: const TextStyle(
                          color: _CalendarTone.antiqueGold,
                          fontSize: _CalendarScale.infoHeading,
                          height: 1.08,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: [
                            'GentiumPlus',
                            'NotoSans',
                            'Roboto',
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
              ),
              if (!isNodeView) ...[
                const SizedBox(width: 8),
                PronounceIconButton(
                  speakText: widget.speakText,
                  utteranceId:
                      'calendar-info:${widget.selectionSerial}:${widget.title}',
                  color: _CalendarTone.antiqueGold.withValues(alpha: 0.72),
                  size: 16,
                  isPhonetic: true,
                ),
              ],
            ],
          ),
          if (isNodeView) ...[
            const SizedBox(height: 8),
            _buildNodeHeader(node),
          ],
          const SizedBox(height: 16),
          ..._buildParagraphs(body.trim(), links),
          if (isNodeView && libraryNode != null) ...[
            const SizedBox(height: 16),
            NodeUserInsightsSection(node: libraryNode),
          ],
        ],
      ),
    );
  }

  Widget _buildBackRow() {
    final previous = _history.length >= 2
        ? _history[_history.length - 2].title
        : null;
    final label = previous ?? 'Back to ${widget.backLabel}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _popNode,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeHeader(_InfoNodeEntry node) {
    final aliases = node.aliases.where((a) => a.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) =>
              _CalendarTone.mutedGoldGloss.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            node.glyph,
            style: const TextStyle(
              fontSize: 34,
              color: Colors.white,
              fontFamily: 'GentiumPlus',
              fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (aliases.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: aliases
                .map(
                  (alias) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      alias,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  List<Widget> _buildParagraphs(String body, List<KemeticNodeLink> linkMap) {
    final used = <String>{};
    final widgets = <Widget>[];
    var paragraphIndex = 0;
    for (final raw in body.split('\n\n')) {
      final paragraph = raw.trimRight();
      if (paragraph.isEmpty) continue;
      final style = paragraphIndex == 0 ? _metaStyle : _bodyStyle;
      final spans = _linkifyParagraph(paragraph, linkMap, used, style);
      widgets.add(
        RichText(
          text: TextSpan(style: style, children: spans),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
      widgets.add(SizedBox(height: paragraphIndex == 0 ? 18 : 14));
      paragraphIndex++;
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  List<InlineSpan> _linkifyParagraph(
    String paragraph,
    List<KemeticNodeLink> linkMap,
    Set<String> used,
    TextStyle baseStyle,
  ) {
    final matches = <_LinkMatch>[];
    for (final link in linkMap) {
      if (used.contains(link.phrase)) continue;
      if (!_canResolve(link.targetId)) continue;
      final matchIndex = _findFirstOccurrence(paragraph, link.phrase);
      if (matchIndex == null) continue;
      matches.add(
        _LinkMatch(
          link: link,
          start: matchIndex,
          end: matchIndex + link.phrase.length,
        ),
      );
      used.add(link.phrase);
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start < cursor) continue;
      if (match.start > cursor) {
        spans.add(TextSpan(text: paragraph.substring(cursor, match.start)));
      }
      spans.add(_buildLinkSpan(match.link, baseStyle));
      cursor = match.end;
    }
    if (cursor < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(cursor)));
    }

    if (spans.isEmpty) {
      return [TextSpan(text: paragraph)];
    }
    return spans;
  }

  InlineSpan _buildLinkSpan(KemeticNodeLink link, TextStyle baseStyle) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _openNode(link.targetId),
          child: ShaderMask(
            shaderCallback: (Rect bounds) =>
                _CalendarTone.mutedGoldGloss.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              link.phrase,
              style: baseStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                  Shadow(
                    color: Colors.white10,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openNode(String targetId) {
    final entry = _resolveNode(targetId);
    if (entry == null) return;
    final currentId = _activeNode?.id.toLowerCase();
    if (currentId != null && currentId == entry.id.toLowerCase()) return;
    if (_history.isEmpty && _infoController.hasClients) {
      _infoOffset = _infoController.offset;
    }
    SpeechService.instance.stop();
    setState(() {
      _history.add(entry);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nodeController.hasClients) {
        _nodeController.jumpTo(0);
      }
    });
  }

  _InfoNodeEntry? _resolveNode(String targetId) {
    final inline = widget.inlineNodes[targetId];
    if (inline != null) return _InfoNodeEntry.inline(inline);
    final libNode = KemeticNodeLibrary.resolve(targetId);
    if (libNode != null) return _InfoNodeEntry.library(libNode);
    return null;
  }

  bool _canResolve(String targetId) {
    return widget.inlineNodes.containsKey(targetId) ||
        KemeticNodeLibrary.resolve(targetId) != null;
  }

  bool _popNode() {
    if (_history.isEmpty) return false;
    SpeechService.instance.stop();
    setState(() {
      _history.removeLast();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_history.isEmpty) {
        if (_infoController.hasClients) {
          final max = _infoController.position.maxScrollExtent;
          final target = _infoOffset.clamp(0.0, max);
          _infoController.jumpTo(target);
        }
      } else {
        if (_nodeController.hasClients) {
          _nodeController.jumpTo(0);
        }
      }
    });
    return true;
  }

  int? _findFirstOccurrence(String paragraph, String phrase) {
    int? fallback;
    int index = paragraph.indexOf(phrase);
    while (index != -1) {
      final isWhole = _isWholeWordMatch(paragraph, index, phrase);
      if (!isWhole) {
        index = paragraph.indexOf(phrase, index + phrase.length);
        continue;
      }
      final insideQuote = _isInsideQuotedLine(paragraph, index, phrase.length);
      fallback ??= index;
      if (!insideQuote) {
        return index;
      }
      index = paragraph.indexOf(phrase, index + phrase.length);
    }
    return fallback;
  }

  bool _isWholeWordMatch(String source, int index, String phrase) {
    final beforeIndex = index - 1;
    final afterIndex = index + phrase.length;
    final before = beforeIndex >= 0 ? source[beforeIndex] : '';
    final after = afterIndex < source.length ? source[afterIndex] : '';
    final letterPattern = RegExp(r'[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]');
    final beforeIsLetter = letterPattern.hasMatch(before);
    final afterIsLetter = letterPattern.hasMatch(after);
    return !beforeIsLetter && !afterIsLetter;
  }

  bool _isInsideQuotedLine(String text, int index, int length) {
    final lineStart = text.lastIndexOf('\n', index) + 1;
    final lineEnd = text.indexOf('\n', index);
    final line = text
        .substring(lineStart, lineEnd == -1 ? text.length : lineEnd)
        .trimLeft();

    if (line.startsWith('“') ||
        line.startsWith('"') ||
        line.startsWith('‘') ||
        line.startsWith('—')) {
      return true;
    }

    final quotesBefore = RegExp(
      r'[“”"‘’]',
    ).allMatches(text.substring(0, index)).length;
    final quotesThrough = RegExp(
      r'[“”"‘’]',
    ).allMatches(text.substring(0, index + length)).length;

    return quotesBefore.isOdd && quotesThrough >= quotesBefore;
  }
}

class _InfoNodeEntry {
  final KemeticNode? node;
  final _InlineNodeContent? inlineNode;

  _InfoNodeEntry.library(this.node) : inlineNode = null;
  _InfoNodeEntry.inline(this.inlineNode) : node = null;

  String get id => (node?.id ?? inlineNode?.id) ?? '';
  String get title => (node?.title ?? inlineNode?.title) ?? '';
  String get glyph => (node?.glyph ?? inlineNode?.glyph ?? '★');
  String get body => (node?.body ?? inlineNode?.body) ?? '';
  List<KemeticNodeLink> get links =>
      node?.linkMap ?? inlineNode?.linkMap ?? const [];
  List<String> get aliases => node?.aliases ?? const [];
}

class _LinkMatch {
  final KemeticNodeLink link;
  final int start;
  final int end;

  const _LinkMatch({
    required this.link,
    required this.start,
    required this.end,
  });
}

class _EventsTab extends StatelessWidget {
  final String monthLabel;
  final List<_MonthEvent> notes;
  final void Function(int day) onOpenDay;

  const _EventsTab({
    required this.monthLabel,
    required this.notes,
    required this.onOpenDay,
  });

  Color _softEventAccent(Color color) {
    return _CalendarTone.softenAccent(
      color,
      saturationScale: 0.52,
      lightness: 0.49,
      goldBlend: 0.10,
    );
  }

  Color _eventTitleColor(Color color) {
    return _CalendarTone.eventTitle(color);
  }

  String _spacedCaps(String text) {
    final compact = text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return 'EVENT';
    return compact.split('').join(' ');
  }

  bool _isMaatFlow(_MonthEvent event) {
    final flow = event.flowName?.trim().toLowerCase();
    if (flow == null || flow.isEmpty) return false;
    return flow == kDawnHouseRiteTitle.toLowerCase() ||
        flow == kEveningThresholdRiteTitle.toLowerCase();
  }

  String _purposePreview(String? detail) {
    final raw = detail?.trim();
    if (raw == null || raw.isEmpty) return '';
    final lines = raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    final sectionHeading = RegExp(
      r"^(Purpose|Action|Water|Words|Quiet line|Ma'at act|Order act|Evening act|Steps|Provision|Optional|Drink|Privacy|Source|Lens|Cycle|Completion|Current ḥꜣw Context|Day Card|Season Instruction|Confidence|Variant|Outdoor)\s*:?\s*(.*)$",
      caseSensitive: false,
    );

    final purpose = <String>[];
    var collecting = false;
    for (final line in lines) {
      if (line.isEmpty) continue;
      final match = sectionHeading.firstMatch(line);
      if (match != null) {
        final heading = match.group(1)!.toLowerCase();
        final inline = match.group(2)?.trim();
        if (heading == 'purpose') {
          collecting = true;
          if (inline != null && inline.isNotEmpty) {
            purpose.add(inline);
          }
          continue;
        }
        if (collecting) break;
      }
      if (collecting) {
        purpose.add(line);
      }
    }

    if (purpose.isNotEmpty) return purpose.join(' ').trim();
    return raw;
  }

  Widget _chip(
    String text, {
    IconData? icon,
    Color? color,
    Color? textColor,
    double? maxWidth,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.5, vertical: 3.5),
        margin: const EdgeInsets.only(right: 7, bottom: 5),
        decoration: BoxDecoration(
          color: (color ?? _CalendarTone.mutedStone).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (color ?? _CalendarTone.mutedStone).withValues(alpha: 0.22),
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 10.5,
                color: (color ?? _CalendarTone.mutedStone).withValues(
                  alpha: 0.82,
                ),
              ),
              const SizedBox(width: 3.5),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color:
                      textColor ??
                      (color ?? _CalendarTone.mutedStone).withValues(
                        alpha: 0.84,
                      ),
                  fontSize: _CalendarScale.eventChip,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No events for this month yet.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: notes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = notes[i];
        final dateLabel = '$monthLabel ${e.day}';
        final flowName = e.flowName?.trim();
        final categoryLabel = flowName == null || flowName.isEmpty
            ? 'Event'
            : flowName;
        final categoryPrefix = _isMaatFlow(e) ? '✦  ' : '';
        final eventColor = e.color;
        final accent = _softEventAccent(eventColor);
        final cardBase = Color.alphaBlend(
          accent.withValues(alpha: 0.145),
          const Color(0xFF060504),
        );
        final titleColor = _eventTitleColor(eventColor).withValues(alpha: 0.96);
        final labelColor = accent.withValues(alpha: 0.80);
        final purpose = _purposePreview(e.detail);
        final cardRadius = BorderRadius.circular(14);

        return Container(
          decoration: BoxDecoration(
            color: cardBase,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accent.withValues(alpha: 0.13),
                accent.withValues(alpha: 0.064),
                accent.withValues(alpha: 0.026),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
            borderRadius: cardRadius,
            border: Border.all(
              color: accent.withValues(alpha: 0.20),
              width: 0.7,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: cardRadius,
              onTap: () => onOpenDay(e.day),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: accent.withValues(alpha: 0.72),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 24,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.62),
                          width: 1.7,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 38, 18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chipMaxWidth = constraints.maxWidth - 8;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$categoryPrefix${_spacedCaps(categoryLabel)}',
                              style: TextStyle(
                                color: labelColor,
                                fontSize: _CalendarScale.eventEyebrow,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 4.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              e.displayTitle,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: _CalendarScale.eventTitle,
                                height: 1.12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'CormorantGaramond',
                                fontFamilyFallback: const [
                                  'GentiumPlus',
                                  'NotoSans',
                                  'Roboto',
                                  'Arial',
                                  'sans-serif',
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 13),
                            Wrap(
                              children: [
                                _chip(
                                  e.timeLabel,
                                  icon: Icons.schedule,
                                  color: accent,
                                  maxWidth: chipMaxWidth,
                                ),
                                _chip(
                                  dateLabel,
                                  icon: Icons.calendar_today,
                                  color: accent,
                                  maxWidth: chipMaxWidth,
                                ),
                                // The full Gregorian date is available from
                                // the day view; the mockup keeps month cards
                                // quiet with only time and Kemetic-day chips.
                                if (e.note.isReminder)
                                  _chip(
                                    'Reminder',
                                    icon: Icons.notifications_active,
                                    color: accent,
                                    maxWidth: chipMaxWidth,
                                  ),
                              ],
                            ),
                            if ((e.location ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () =>
                                    _launchExternalPreviewTarget(e.location!),
                                child: Text(
                                  e.location!,
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.92),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: accent.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (purpose.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'P U R P O S E',
                                style: TextStyle(
                                  color: accent.withValues(alpha: 0.38),
                                  fontSize: _CalendarScale.eventPurpose,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4.0,
                                ),
                              ),
                              const SizedBox(height: 7),
                              RichText(
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Color(0xFFAEA292),
                                    fontSize: _CalendarScale.eventPurposeBody,
                                    height: 1.40,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'CormorantGaramond',
                                    fontWeight: FontWeight.w500,
                                    fontFamilyFallback: [
                                      'GentiumPlus',
                                      'NotoSans',
                                      'Roboto',
                                      'Arial',
                                      'sans-serif',
                                    ],
                                  ),
                                  children: _buildExternalLinkSpans(purpose),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
