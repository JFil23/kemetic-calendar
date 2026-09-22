part of 'calendar_page.dart';

extension _UserFlowDetailPresentation on _FlowPreviewPageState {
  bool _usesUserFlowDetailSurface(
    _Flow flow,
    ({bool kemetic, bool split, String overview, String? maatKey}) meta,
    ReminderRule? reminderRule,
  ) {
    if (widget.mode != _FlowPreviewMode.active &&
        widget.mode != _FlowPreviewMode.saved) {
      return false;
    }
    if (!widget.useMySavedExpansionParity || widget.actionPolicy != null) {
      return false;
    }
    return meta.maatKey == null && reminderRule == null && !flow.isReminder;
  }

  Widget _buildUserFlowDetailSurface({
    required _Flow flow,
    required ({bool kemetic, bool split, String overview, String? maatKey})
    meta,
    required List<FlowEventRow> events,
    required bool loading,
    required Object? error,
  }) {
    final palette = _MyFlowCardPalette.fromColor(flow.color);
    final theme = _userFlowDetailTheme(palette);
    final overview = _effectiveOverview(flow.notes, meta.overview);
    final partition = _partitionDashboardDays(flow, events);
    final days = _dashboardDaysFor(flow, events);
    final schedule = _userFlowScheduleBuckets(flow, days);
    final calendarPreview = _calendarPreviewForUserFlow(
      flow: flow,
      days: days,
      schedule: schedule,
    );
    final metrics = _metricsForFlow(flow, events);
    final total = metrics.totalEventCount > 0
        ? metrics.totalEventCount
        : events.length;

    return Material(
      key: ValueKey<String>('user-flow-detail-surface-${flow.id}'),
      color: theme.pageBackground,
      child: Stack(
        children: [
          MaatFlowDetailShell(
            theme: theme,
            scrollKey: ValueKey<String>('user-flow-detail-scroll-${flow.id}'),
            heroLayerKey: ValueKey<String>(
              'user-flow-detail-hero-layer-${flow.id}',
            ),
            sheetKey: ValueKey<String>('user-flow-detail-sheet-${flow.id}'),
            hero: _buildUserFlowDetailHero(
              flow: flow,
              theme: theme,
              metrics: metrics,
              total: total,
              partition: partition,
            ),
            sheet: _buildUserFlowDetailSheet(
              flow: flow,
              meta: meta,
              events: events,
              days: days,
              partition: partition,
              schedule: schedule,
              calendarPreview: calendarPreview,
              palette: palette,
              theme: theme,
              loading: loading,
              error: error,
              overview: overview,
            ),
            bottomDock: _buildUserFlowDetailDock(flow: flow, theme: theme),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 16,
            child: MaatFlowDetailBackButton(
              key: const ValueKey<String>('user-flow-detail-back'),
              color: MaatFlowListTokens.gold,
              backgroundColor: Colors.transparent,
              borderColor: Colors.transparent,
              size: 40,
              iconSize: 27,
              icon: Icons.chevron_left,
              onPressed: () => unawaited(Navigator.of(context).maybePop()),
            ),
          ),
          if (widget.showFlowOptions)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              right: 10,
              child: _buildUserFlowDetailOptions(flow, events, theme),
            ),
        ],
      ),
    );
  }

  MaatFlowDetailTheme _userFlowDetailTheme(_MyFlowCardPalette palette) {
    final accent = palette.accent;
    return MaatFlowDetailTheme(
      pageBackground: const Color(0xFF0B0906),
      sheetBackground: const Color(0xFF0A0805),
      sheetBorder: const Color(0xFF241F17),
      accent: accent,
      primaryText: const Color(0xFFF2ECE0),
      secondaryText: const Color(0xFF9E9A94),
      mutedText: const Color(0xFF6A6660),
      separator: const Color(0xFF1A160F),
      glow: Color.lerp(accent, const Color(0xFFF2ECE0), 0.24) ?? accent,
    );
  }

  MaatFlowThirtyDayCalendarTheme _userFlowCalendarTheme(
    MaatFlowDetailTheme theme,
  ) {
    return MaatFlowThirtyDayCalendarTheme(
      introText: theme.secondaryText,
      introEmphasis: theme.primaryText,
      border: theme.separator,
      month: theme.primaryText,
      monthTransliteration: theme.mutedText,
      decan: const Color(0xFF6E6144),
      day: const Color(0xFF5A5547),
      today: theme.primaryText,
      highlight: theme.accent,
    );
  }

  Widget _buildUserFlowDetailHero({
    required _Flow flow,
    required MaatFlowDetailTheme theme,
    required _FlowPreviewMetrics metrics,
    required int total,
    required _FlowDashboardPartition partition,
  }) {
    final appearance = flow.appearance.copyWith(clearSignLabel: true);
    final activeDay = partition.hero?.dayNumber ?? 1;
    final caption = widget.mode == _FlowPreviewMode.saved
        ? 'SAVED · $total ${total == 1 ? 'DAY' : 'DAYS'}'
        : 'DAY $activeDay OF $total';

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledOverlap =
            MaatFlowDetailGeometry.sheetOverlap *
            (constraints.maxWidth / MaatFlowDetailGeometry.referenceWidth);
        final titleBottom = math.max(62.0, scaledOverlap + 16);
        return Stack(
          fit: StackFit.expand,
          children: [
            UserFlowAppearanceHero(
              key: const ValueKey<String>('user-flow-detail-appearance'),
              appearance: appearance,
              accent: theme.accent,
              localImageBytes: widget.appearanceImageBytesForTesting,
              height: double.infinity,
              borderRadius: BorderRadius.zero,
              surface: UserFlowAppearanceSurface.fullDetail,
              completedOccurrences: metrics.completedEventCount,
              totalOccurrences: total,
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: titleBottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption,
                    key: const ValueKey<String>('user-flow-detail-caption'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.glow,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _UserFlowDetailTitle(
                    text: flow.name,
                    key: const ValueKey<String>('user-flow-detail-title'),
                    style: TextStyle(
                      color: theme.primaryText,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      height: 1.02,
                      shadows: const [
                        Shadow(color: Color(0xD0000000), blurRadius: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _userFlowInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '•';
    return trimmed.characters.first.toUpperCase();
  }

  Widget _buildUserFlowDetailSheet({
    required _Flow flow,
    required ({bool kemetic, bool split, String overview, String? maatKey})
    meta,
    required List<FlowEventRow> events,
    required List<_FlowDashboardDay> days,
    required _FlowDashboardPartition partition,
    required _UserFlowScheduleBuckets schedule,
    required FollowSkyCalendarPreview calendarPreview,
    required _MyFlowCardPalette palette,
    required MaatFlowDetailTheme theme,
    required bool loading,
    required Object? error,
    required String overview,
  }) {
    final isTrackSky = _isTrackSkyFlowName(flow.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Center(
            child: Container(
              key: const ValueKey<String>('user-flow-detail-handle'),
              width: 42,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3325),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        if (overview.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Text(
              overview.trim(),
              key: const ValueKey<String>('user-flow-detail-overview'),
              style: TextStyle(
                color: theme.secondaryText,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 17.5,
                fontWeight: FontWeight.w400,
                height: 1.48,
              ),
            ),
          ),
        if (!loading && error == null && events.isNotEmpty)
          _buildUserFlowCalendar(
            flow: flow,
            events: events,
            partition: partition,
            schedule: schedule,
            calendarPreview: calendarPreview,
            theme: theme,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: loading && events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 56),
                  child: Center(
                    child: CircularProgressIndicator(color: theme.accent),
                  ),
                )
              : error != null
              ? _buildDashboardMessage(
                  'Could not load flow days/notes.',
                  palette: palette,
                  isError: true,
                )
              : events.isEmpty
              ? _buildDashboardMessage(
                  'No days or notes for this flow yet.',
                  palette: palette,
                )
              : _buildUserFlowScheduleList(
                  flow: flow,
                  days: days,
                  partition: partition,
                  schedule: schedule,
                  calendarPreview: calendarPreview,
                  palette: palette,
                  theme: theme,
                  isTrackSky: isTrackSky,
                ),
        ),
      ],
    );
  }

  FollowSkyCalendarPreview _calendarPreviewForUserFlow({
    required _Flow flow,
    required List<_FlowDashboardDay> days,
    required _UserFlowScheduleBuckets schedule,
  }) {
    final provider = widget.calendarPreviewForWindow;
    if (provider == null) return FollowSkyCalendarPreview.unavailable;

    final start = _userFlowToday;
    var end = start.add(const Duration(days: 29));
    for (final day in schedule.visibleUpcoming) {
      final date = _userFlowDisplayDate(flow, day, days);
      if (date.isAfter(end)) end = date;
    }
    return provider(DateUtils.dateOnly(start), DateUtils.dateOnly(end));
  }

  MaatFlowPreviewTheme _userFlowPreviewTheme(MaatFlowDetailTheme theme) {
    return MaatFlowPreviewTheme(
      surface: const Color(0xFF100D08),
      border: theme.accent.withValues(alpha: 0.30),
      shadow: const Color(0x52000000),
      kemeticDate: theme.accent,
      gregorianDate: theme.glow.withValues(alpha: 0.82),
      divider: theme.accent.withValues(alpha: 0.17),
      primaryText: theme.primaryText,
      secondaryText: theme.secondaryText,
    );
  }

  Widget _buildUserFlowScheduleList({
    required _Flow flow,
    required List<_FlowDashboardDay> days,
    required _FlowDashboardPartition partition,
    required _UserFlowScheduleBuckets schedule,
    required FollowSkyCalendarPreview calendarPreview,
    required _MyFlowCardPalette palette,
    required MaatFlowDetailTheme theme,
    required bool isTrackSky,
  }) {
    final showPast = _showPastScheduleFlowIds.contains(flow.id);
    final showLater = _showLaterScheduleFlowIds.contains(flow.id);
    final visibleUpcoming = schedule.visibleUpcoming;
    return Column(
      key: ValueKey<String>('user-flow-schedule-${flow.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (schedule.past.isNotEmpty) ...[
          _buildUserFlowCollapsedScheduleSection(
            flow: flow,
            section: 'past',
            days: schedule.past,
            allDays: days,
            partition: partition,
            palette: palette,
            theme: theme,
            isTrackSky: isTrackSky,
            expanded: showPast,
            collapsedLabel:
                'See ${schedule.past.length} past ${schedule.past.length == 1 ? 'event' : 'events'}',
            expandedLabel: 'Hide past events',
            onToggle: () => _updateUserFlowDetail(() {
              if (showPast) {
                _showPastScheduleFlowIds.remove(flow.id);
              } else {
                _showPastScheduleFlowIds.add(flow.id);
              }
            }),
          ),
          const SizedBox(height: 22),
        ],
        Text(
          visibleUpcoming.isEmpty
              ? 'NO UPCOMING EVENTS'
              : 'NEXT ${visibleUpcoming.length} UPCOMING ${visibleUpcoming.length == 1 ? 'EVENT' : 'EVENTS'}',
          key: const ValueKey<String>('user-flow-next-five-heading'),
          style: TextStyle(
            color: theme.accent,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.1,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        for (final day in visibleUpcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: _buildUserFlowScheduleDay(
              flow: flow,
              day: day,
              allDays: days,
              partition: partition,
              calendarPreview: calendarPreview,
              palette: palette,
              theme: theme,
              isTrackSky: isTrackSky,
            ),
          ),
        if (schedule.later.isNotEmpty)
          _buildUserFlowCollapsedScheduleSection(
            flow: flow,
            section: 'later',
            days: schedule.later,
            allDays: days,
            partition: partition,
            palette: palette,
            theme: theme,
            isTrackSky: isTrackSky,
            expanded: showLater,
            collapsedLabel:
                'See ${schedule.later.length} later ${schedule.later.length == 1 ? 'event' : 'events'}',
            expandedLabel: 'Hide later events',
            onToggle: () => _updateUserFlowDetail(() {
              if (showLater) {
                _showLaterScheduleFlowIds.remove(flow.id);
              } else {
                _showLaterScheduleFlowIds.add(flow.id);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildUserFlowCollapsedScheduleSection({
    required _Flow flow,
    required String section,
    required List<_FlowDashboardDay> days,
    required List<_FlowDashboardDay> allDays,
    required _FlowDashboardPartition partition,
    required _MyFlowCardPalette palette,
    required MaatFlowDetailTheme theme,
    required bool isTrackSky,
    required bool expanded,
    required String collapsedLabel,
    required String expandedLabel,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey<String>(
            'user-flow-${expanded ? 'hide' : 'show'}-$section',
          ),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.accent.withValues(alpha: 0.22)),
                bottom: BorderSide(color: theme.accent.withValues(alpha: 0.22)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    expanded ? expandedLabel : collapsedLabel,
                    style: TextStyle(
                      color: theme.primaryText,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 16,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.expand_more, size: 18, color: theme.accent),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.ease,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    key: ValueKey<String>('user-flow-$section-schedule'),
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        for (final day in days)
                          _buildUserFlowRemainingDay(
                            flow: flow,
                            day: day,
                            allDays: allDays,
                            partition: partition,
                            palette: palette,
                            theme: theme,
                            isTrackSky: isTrackSky,
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }

  Widget _buildUserFlowScheduleDay({
    required _Flow flow,
    required _FlowDashboardDay day,
    required List<_FlowDashboardDay> allDays,
    required _FlowDashboardPartition partition,
    required FollowSkyCalendarPreview calendarPreview,
    required _MyFlowCardPalette palette,
    required MaatFlowDetailTheme theme,
    required bool isTrackSky,
  }) {
    final date = _userFlowDisplayDate(flow, day, allDays);
    final rows = _ordinaryUserFlowRowsForDay(
      flow: flow,
      day: day,
      date: date,
      calendarPreview: calendarPreview,
    );
    final state = calendarPreview.dateState(date);
    final expanded = _expandedDayKeys.contains(day.key);
    final completed = partition.completed.any((item) => item.key == day.key);
    final content = _contentForDashboardDay(day, isTrackSky: isTrackSky);
    final previewTheme = _userFlowPreviewTheme(theme);
    final detailKey = _dashboardDayDetailKeys.putIfAbsent(
      day.key,
      () => GlobalKey(debugLabel: 'user-flow-schedule-detail-${day.key}'),
    );
    final blockKey = _dashboardDayBlockKeys.putIfAbsent(
      day.key,
      () => GlobalKey(debugLabel: 'user-flow-schedule-block-${day.key}'),
    );

    return KeyedSubtree(
      key: ValueKey<String>('my_flow_day_row_${day.key}'),
      child: MaatFlowPreviewDayCard(
        key: ValueKey<String>('user-flow-schedule-day-${day.dayNumber}'),
        date: date,
        theme: previewTheme,
        children: [
          Builder(
            key: blockKey,
            builder: (rowContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUserFlowScheduleEventBlock(
                  flow: flow,
                  day: day,
                  content: content,
                  palette: palette,
                  theme: theme,
                  totalOccurrences: allDays.length,
                  completed: completed,
                  expanded: expanded,
                  onTap: () => _handleDashboardDayTap(
                    dayKey: day.key,
                    rowContext: rowContext,
                  ),
                ),
                _MaatExpandableEventDetail(
                  key: detailKey,
                  expanded: expanded,
                  collapseInstantly: _instantCollapseDayKey == day.key,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: _MyFlowDayContentCard(
                      key: ValueKey<String>('my_flow_day_card_${day.key}'),
                      content: content,
                      palette: palette,
                      variant: _MyFlowDayCardVariant.expandedInline,
                      eyebrow: 'DAY ${day.dayNumber}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final row in rows)
            MaatFlowPreviewEventRow(
              timeLabel: row.allDay ? 'All day' : _formatBasicTime(row.start),
              title: row.title,
              accent: row.eventColor,
              theme: previewTheme,
              subtitle: row.flowName,
            ),
          if (rows.isEmpty &&
              state != MaatFlowDateCalendarState.loadedEmpty &&
              state != MaatFlowDateCalendarState.loaded)
            _userFlowCalendarAvailabilityRow(state, theme),
        ],
      ),
    );
  }

  Widget _buildUserFlowRemainingDay({
    required _Flow flow,
    required _FlowDashboardDay day,
    required List<_FlowDashboardDay> allDays,
    required _FlowDashboardPartition partition,
    required _MyFlowCardPalette palette,
    required MaatFlowDetailTheme theme,
    required bool isTrackSky,
  }) {
    final expanded = _expandedDayKeys.contains(day.key);
    final completed = partition.completed.any((item) => item.key == day.key);
    final content = _contentForDashboardDay(day, isTrackSky: isTrackSky);
    final date = _userFlowDisplayDate(flow, day, allDays);
    final detailKey = _dashboardDayDetailKeys.putIfAbsent(
      day.key,
      () => GlobalKey(debugLabel: 'user-flow-remaining-detail-${day.key}'),
    );
    final blockKey = _dashboardDayBlockKeys.putIfAbsent(
      day.key,
      () => GlobalKey(debugLabel: 'user-flow-remaining-block-${day.key}'),
    );
    return Builder(
      key: blockKey,
      builder: (rowContext) => Column(
        key: ValueKey<String>('my_flow_day_row_${day.key}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey<String>('my_flow_day_tap_${day.key}'),
            onTap: () =>
                _handleDashboardDayTap(dayKey: day.key, rowContext: rowContext),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      day.dayNumber.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.primaryText,
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${gregorianDateLabel(date)} · ${_userFlowEventTimeLabel(day)}',
                          style: TextStyle(
                            color: theme.secondaryText,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (completed)
                    Icon(Icons.check, size: 16, color: theme.accent),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.expand_less : Icons.chevron_right,
                    size: 17,
                    color: theme.accent,
                  ),
                ],
              ),
            ),
          ),
          _MaatExpandableEventDetail(
            key: detailKey,
            expanded: expanded,
            collapseInstantly: _instantCollapseDayKey == day.key,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MyFlowDayContentCard(
                key: ValueKey<String>('my_flow_day_card_${day.key}'),
                content: content,
                palette: palette,
                variant: _MyFlowDayCardVariant.expandedInline,
                eyebrow: 'DAY ${day.dayNumber}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFlowScheduleEventBlock({
    required _Flow flow,
    required _FlowDashboardDay day,
    required _FlowDayContent content,
    required _MyFlowCardPalette palette,
    required MaatFlowDetailTheme theme,
    required int totalOccurrences,
    required bool completed,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('my_flow_day_tap_${day.key}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          key: ValueKey<String>('user-flow-schedule-block-${day.dayNumber}'),
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: theme.accent.withValues(alpha: 0.62)),
            gradient: LinearGradient(
              colors: [
                palette.cardBase,
                theme.accent.withValues(alpha: 0.12),
                palette.cardBase,
              ],
              stops: const [0, 0.62, 1],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${flow.name.toUpperCase()} · DAY ${day.dayNumber.toString().padLeft(2, '0')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primaryText,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _userFlowEventTimeLabel(day),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.secondaryText,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        if (completed) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check, size: 13, color: theme.accent),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (flow.appearance.hasSign)
                UserFlowAppearanceBadge(
                  appearance: flow.appearance,
                  accent: theme.accent,
                  localImageBytes: widget.appearanceImageBytesForTesting,
                  size: 52,
                  completedOccurrences: math.max(0, day.dayNumber - 1),
                  totalOccurrences: math.max(1, totalOccurrences),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: theme.accent.withValues(alpha: 0.36),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _userFlowInitial(flow.name),
                    style: TextStyle(
                      color: theme.glow,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 22,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                expanded ? Icons.expand_less : Icons.chevron_right,
                size: 16,
                color: theme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FollowSkyCalendarPreviewRow> _ordinaryUserFlowRowsForDay({
    required _Flow flow,
    required _FlowDashboardDay day,
    required DateTime date,
    required FollowSkyCalendarPreview calendarPreview,
  }) {
    final representedIds = <String>{
      if (day.event.id?.trim().isNotEmpty == true) day.event.id!.trim(),
      if (day.event.clientEventId?.trim().isNotEmpty == true)
        day.event.clientEventId!.trim(),
    };
    final rows =
        calendarPreview
            .rowsFor(date)
            .where((row) {
              final eventId = row.eventId?.trim();
              if (eventId != null && representedIds.contains(eventId)) {
                return false;
              }
              if (representedIds.isNotEmpty) return true;
              final sameFlow =
                  row.flowName?.trim().toLowerCase() ==
                  flow.name.trim().toLowerCase();
              final sameTitle =
                  row.title.trim().toLowerCase() ==
                  day.event.title.trim().toLowerCase();
              final eventStart = day.localStart;
              final sameTime =
                  row.start.hour == eventStart.hour &&
                  row.start.minute == eventStart.minute;
              return !(sameFlow && sameTitle && sameTime);
            })
            .toList(growable: false)
          ..sort((a, b) => a.start.compareTo(b.start));
    return rows;
  }

  Widget _userFlowCalendarAvailabilityRow(
    MaatFlowDateCalendarState state,
    MaatFlowDetailTheme theme,
  ) {
    return Padding(
      key: ValueKey<String>(
        'user-flow-calendar-${maatFlowDateCalendarKeySuffix(state)}',
      ),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Text(
        maatFlowDateCalendarLabel(state),
        style: TextStyle(
          color: theme.mutedText,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  String _userFlowEventTimeLabel(_FlowDashboardDay day) {
    if (day.event.allDay) return 'All day';
    final start = day.localStart;
    final end = day.localEnd;
    if (end == null) return _formatBasicTime(start);
    return '${_formatBasicTime(start)} – ${_formatBasicTime(end)}';
  }

  Widget _buildUserFlowCalendar({
    required _Flow flow,
    required List<FlowEventRow> events,
    required _FlowDashboardPartition partition,
    required _UserFlowScheduleBuckets schedule,
    required FollowSkyCalendarPreview calendarPreview,
    required MaatFlowDetailTheme theme,
  }) {
    final days = _dashboardDaysFor(flow, events);
    final today = _userFlowToday;
    final completedKeys = <String>{
      for (final day in partition.completed) day.key,
    };
    final daysByDate = <DateTime, _FlowDashboardDay>{
      for (final day in days) _userFlowDisplayDate(flow, day, days): day,
    };
    final firstDisplayDate = days.isEmpty
        ? null
        : _userFlowDisplayDate(flow, days.first, days);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: MaatFlowThirtyDayCalendar(
            key: ValueKey<String>('user-flow-calendar-${flow.id}'),
            windowStart: today,
            dayCount: 30,
            markers: [
              for (var offset = 0; offset < 30; offset++)
                () {
                  final date = today.add(Duration(days: offset));
                  final day = daysByDate[date];
                  final isSaved = widget.mode == _FlowPreviewMode.saved;
                  final isStart =
                      firstDisplayDate != null &&
                      DateUtils.isSameDay(date, firstDisplayDate);
                  final isOccurrence = day != null;
                  final isCurrent = day?.key == partition.hero?.key;
                  final ordinaryRows = day == null
                      ? calendarPreview.rowsFor(date)
                      : _ordinaryUserFlowRowsForDay(
                          flow: flow,
                          day: day,
                          date: date,
                          calendarPreview: calendarPreview,
                        );
                  return MaatFlowThirtyDayMarker(
                    date: date,
                    isToday: DateUtils.isSameDay(date, today),
                    highlighted: isStart || isOccurrence || isCurrent,
                    filled: day != null && completedKeys.contains(day.key),
                    accent: theme.accent,
                    secondaryColors: <Color>[
                      for (final row in ordinaryRows) row.eventColor,
                    ],
                    topLabel: isStart ? 'START DATE' : null,
                    onTopLabelTap: isStart && isSaved
                        ? () => _pickUserFlowDetailStart(flow)
                        : null,
                    topLabelSemanticLabel: isStart && isSaved
                        ? 'Change saved flow start date'
                        : isStart
                        ? 'Flow start date'
                        : null,
                    onTap: isSaved
                        ? () => _selectSavedStartFromCalendar(flow, date)
                        : day == null
                        ? null
                        : () => _selectUserFlowCalendarDay(
                            day.key,
                            flowId: flow.id,
                            revealLater: schedule.later.any(
                              (item) => item.key == day.key,
                            ),
                          ),
                    semanticLabel: isSaved
                        ? 'Start flow on ${_kemeticLongDate(date)}'
                        : day == null
                        ? null
                        : 'Open day ${day.dayNumber}: ${day.event.title}',
                  );
                }(),
            ],
            theme: _userFlowCalendarTheme(theme),
            introFirstLine: 'Your flow across the Kemetic calendar.',
            introSecondLine: 'Scheduled days and the life around them.',
            keyPrefix: 'user-flow-${flow.id}',
          ),
        ),
      ],
    );
  }

  DateTime get _userFlowToday =>
      DateUtils.dateOnly(widget.nowForTesting ?? DateTime.now());

  _UserFlowScheduleBuckets _userFlowScheduleBuckets(
    _Flow flow,
    List<_FlowDashboardDay> days,
  ) {
    final past = <_FlowDashboardDay>[];
    final upcoming = <_FlowDashboardDay>[];
    for (final day in days) {
      final date = _userFlowDisplayDate(flow, day, days);
      if (date.isBefore(_userFlowToday)) {
        past.add(day);
      } else {
        upcoming.add(day);
      }
    }
    return _UserFlowScheduleBuckets(
      past: List<_FlowDashboardDay>.unmodifiable(past),
      visibleUpcoming: List<_FlowDashboardDay>.unmodifiable(upcoming.take(5)),
      later: List<_FlowDashboardDay>.unmodifiable(upcoming.skip(5)),
    );
  }

  DateTime _userFlowDisplayDate(
    _Flow flow,
    _FlowDashboardDay day,
    List<_FlowDashboardDay> days,
  ) {
    final sourceDate = DateUtils.dateOnly(day.localStart);
    if (widget.mode != _FlowPreviewMode.saved || days.isEmpty) {
      return sourceDate;
    }
    final sourceStart = DateUtils.dateOnly(days.first.localStart);
    final offset = sourceDate.difference(sourceStart).inDays;
    return _savedDisplayStart(flow).add(Duration(days: offset));
  }

  void _selectSavedStartFromCalendar(_Flow flow, DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    _updateUserFlowDetail(() => _selectedStartForSaved = normalized);
  }

  void _selectUserFlowCalendarDay(
    String dayKey, {
    int? flowId,
    bool revealLater = false,
  }) {
    _updateUserFlowDetail(() {
      if (revealLater && flowId != null) {
        _showLaterScheduleFlowIds.add(flowId);
      }
      _expandedDayKeys
        ..remove(dayKey)
        ..add(dayKey);
      while (_expandedDayKeys.length > 2) {
        _expandedDayKeys.removeAt(0);
      }
    });
  }

  String _kemeticShortDate(DateTime date) {
    final kemetic = KemeticMath.fromGregorian(DateUtils.dateOnly(date));
    return '${getMonthById(kemetic.kMonth).displayShort} ${kemetic.kDay}';
  }

  String _kemeticLongDate(DateTime date) {
    final kemetic = KemeticMath.fromGregorian(DateUtils.dateOnly(date));
    return '${getMonthById(kemetic.kMonth).displayFull} ${kemetic.kDay}, ${date.year}';
  }

  Widget _buildUserFlowDetailDock({
    required _Flow flow,
    required MaatFlowDetailTheme theme,
  }) {
    if (widget.mode == _FlowPreviewMode.saved) {
      final date = _savedDisplayStart(flow);
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.4,
        child: MaatFlowDetailDock(
          theme: theme,
          joined: false,
          busy: _isImportingSaved,
          onPressed: _isImportingSaved ? null : () => _handleImportSaved(flow),
          actionLabel: 'Carry this flow',
          actionNote: '',
          actionNoteWidget: Semantics(
            button: true,
            label: 'Change start date, currently ${_kemeticLongDate(date)}',
            child: InkWell(
              key: const ValueKey<String>('user-flow-saved-start-control'),
              onTap: _isImportingSaved
                  ? null
                  : () => _pickUserFlowDetailStart(flow),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(
                  TextSpan(
                    text: 'Starts ',
                    children: [
                      TextSpan(
                        text: _kemeticShortDate(date),
                        style: TextStyle(
                          color: theme.glow,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.accent.withValues(alpha: 0.55),
                          decorationThickness: 1,
                        ),
                      ),
                      const TextSpan(
                        text: '. Nothing is added until you carry it.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.secondaryText,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          joinedLabel: 'Carried',
          joinedNote: '',
          actionKey: const ValueKey<String>('user-flow-carry'),
          joinedKey: const ValueKey<String>('user-flow-carried'),
        ),
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.4,
      child: MaatFlowDetailDock(
        theme: theme,
        joined: false,
        busy: false,
        onPressed: () => unawaited(_editAndRefreshFlow(flow)),
        actionLabel: 'Manage flow',
        actionNote: '',
        joinedLabel: 'Manage flow',
        joinedNote: '',
        actionKey: const ValueKey<String>('user-flow-manage'),
        joinedKey: const ValueKey<String>('user-flow-managed'),
        showNote: false,
      ),
    );
  }

  Widget _buildUserFlowDetailOptions(
    _Flow flow,
    List<FlowEventRow> events,
    MaatFlowDetailTheme theme,
  ) {
    return PopupMenuButton<String>(
      key: const ValueKey<String>('user-flow-detail-options'),
      icon: Icon(Icons.more_vert, color: theme.secondaryText),
      tooltip: 'Flow options',
      color: const Color(0xFF15110B),
      onSelected: (value) async {
        if (value == 'journal') {
          await _handleAddFlowToJournal(flow, events);
        } else if (value == 'edit') {
          await _editAndRefreshFlow(flow);
        } else if (value == 'share') {
          _FlowPreviewPageState._openShareSheet(context, flow);
        } else if (value == 'save') {
          await _toggleSaved(flow);
        }
      },
      itemBuilder: (context) => [
        _userFlowOption(
          value: 'journal',
          icon: Icons.check_circle,
          label: 'Done / Add to journal',
        ),
        _userFlowOption(value: 'edit', icon: Icons.edit, label: 'Edit Flow'),
        _userFlowOption(
          value: 'share',
          icon: Icons.ios_share,
          label: 'Share Flow',
        ),
        _userFlowOption(
          value: 'save',
          icon: flow.isSaved ? Icons.bookmark_remove : Icons.bookmark_add,
          label: flow.isSaved ? 'Remove from Saved Flows' : 'Save Flow',
        ),
      ],
    );
  }

  PopupMenuItem<String> _userFlowOption({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          KemeticGold.icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _UserFlowScheduleBuckets {
  const _UserFlowScheduleBuckets({
    required this.past,
    required this.visibleUpcoming,
    required this.later,
  });

  final List<_FlowDashboardDay> past;
  final List<_FlowDashboardDay> visibleUpcoming;
  final List<_FlowDashboardDay> later;
}

class _UserFlowDetailTitle extends StatelessWidget {
  const _UserFlowDetailTitle({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        final largeStyle = style.copyWith(fontSize: 40);
        final painter = TextPainter(
          text: TextSpan(text: text, style: largeStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final resolvedStyle = painter.didExceedMaxLines
            ? style.copyWith(fontSize: 34)
            : largeStyle;
        return Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: resolvedStyle,
        );
      },
    );
  }
}
