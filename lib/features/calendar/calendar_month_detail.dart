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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          icon: const _GlossyIcon(Icons.close, gradient: goldGloss),
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
              color: _gold,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _gold,
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
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: DefaultTabController(
                  length: _tabTitles.length,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: _gold,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: _gold,
                        tabs: [for (final t in _tabTitles) Tab(text: t)],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _InfoTab(
                              title: infoTitle,
                              body: infoBody,
                              speakText: _buildSpeakLine(month, decanIndex),
                              linkMap: infoLinks,
                              backLabel: backLabel,
                              inlineNodes: _decanInlineNodes,
                              selectionSerial: _infoSelectionSerial,
                            ),
                            _EventsTab(
                              kYear: pageYear,
                              kMonth: month,
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
  final String body;
  final String speakText;
  final List<KemeticNodeLink> linkMap;
  final String backLabel;
  final Map<String, _InlineNodeContent> inlineNodes;
  final int selectionSerial;

  const _InfoTab({
    required this.title,
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
    color: Colors.white,
    fontSize: 14,
    height: 1.35,
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

    return SingleChildScrollView(
      controller: isNodeView ? _nodeController : _infoController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNodeView) _buildBackRow(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GlossyText(
                  text: title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  gradient: silverGloss,
                ),
              ),
              if (!isNodeView) ...[
                const SizedBox(width: 8),
                PronounceIconButton(
                  speakText: widget.speakText,
                  utteranceId:
                      'calendar-info:${widget.selectionSerial}:${widget.title}',
                  color: _gold,
                  size: 22,
                  isPhonetic: true,
                ),
              ],
            ],
          ),
          if (isNodeView) ...[
            const SizedBox(height: 8),
            _buildNodeHeader(node),
          ],
          const SizedBox(height: 8),
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
          shaderCallback: (Rect bounds) => goldGloss.createShader(bounds),
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
    for (final raw in body.split('\n\n')) {
      final paragraph = raw.trimRight();
      if (paragraph.isEmpty) continue;
      final spans = _linkifyParagraph(paragraph, linkMap, used);
      widgets.add(
        RichText(
          text: TextSpan(style: _bodyStyle, children: spans),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
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
      spans.add(_buildLinkSpan(match.link));
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

  InlineSpan _buildLinkSpan(KemeticNodeLink link) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _openNode(link.targetId),
          child: ShaderMask(
            shaderCallback: (Rect bounds) => goldGloss.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              link.phrase,
              style: _bodyStyle.copyWith(
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
  final int kYear;
  final int kMonth;
  final String monthLabel;
  final List<_MonthEvent> notes;
  final void Function(int day) onOpenDay;

  const _EventsTab({
    required this.kYear,
    required this.kMonth,
    required this.monthLabel,
    required this.notes,
    required this.onOpenDay,
  });

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color ?? Colors.white70),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 12,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: notes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final e = notes[i];
        final g = KemeticMath.toGregorian(kYear, kMonth, e.day);
        final dateLabel = '$monthLabel ${e.day}';
        final gregLabel =
            '${g.month.toString().padLeft(2, '0')}/${g.day.toString().padLeft(2, '0')}/${g.year}';

        return Container(
          decoration: BoxDecoration(
            color: e.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: e.color, width: 3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpenDay(e.day),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 12.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final chipMaxWidth = constraints.maxWidth - 8;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                children: [
                                  _chip(
                                    e.timeLabel,
                                    icon: Icons.schedule,
                                    maxWidth: chipMaxWidth,
                                  ),
                                  _chip(
                                    gregLabel,
                                    icon: Icons.calendar_today,
                                    maxWidth: chipMaxWidth,
                                  ),
                                  if (e.flowName != null &&
                                      e.flowName!.trim().isNotEmpty)
                                    _chip(
                                      e.flowName!.trim(),
                                      icon: Icons.auto_awesome,
                                      color: e.color,
                                      textColor: e.color,
                                      maxWidth: chipMaxWidth,
                                    ),
                                  if (e.note.isReminder)
                                    _chip(
                                      'Reminder',
                                      icon: Icons.notifications_active,
                                      maxWidth: chipMaxWidth,
                                    ),
                                ],
                              ),
                              if ((e.location ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () =>
                                      _launchExternalPreviewTarget(e.location!),
                                  child: Text(
                                    e.location!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white54,
                                    ),
                                  ),
                                ),
                              ],
                              if ((e.detail ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    children: _buildExternalLinkSpans(
                                      e.detail!.trim(),
                                    ),
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
          ),
        );
      },
    );
  }
}
