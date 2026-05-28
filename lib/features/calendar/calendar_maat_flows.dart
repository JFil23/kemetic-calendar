part of 'calendar_page.dart';

class _MaatFlowsListPageWithSnapshot extends StatefulWidget {
  const _MaatFlowsListPageWithSnapshot({
    required this.initialSnapshot,
    required this.loadSnapshot,
    required this.onPickTemplate,
    required this.onCreateNew,
    required this.title,
    required this.templates,
  });

  final _MyFlowsFilingSnapshot? initialSnapshot;
  final Future<_MyFlowsFilingSnapshot> Function() loadSnapshot;
  final Future<void> Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;

  @override
  State<_MaatFlowsListPageWithSnapshot> createState() =>
      _MaatFlowsListPageWithSnapshotState();
}

class _MaatFlowsListPageWithSnapshotState
    extends State<_MaatFlowsListPageWithSnapshot> {
  _MyFlowsFilingSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    unawaited(_refreshSnapshot());
  }

  Future<void> _refreshSnapshot() async {
    try {
      final snapshot = await widget.loadSnapshot();
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[maatFlows] snapshot refresh failed: $e');
        _calendarDebugPrint('$st');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MaatFlowsListPage(
      title: widget.title,
      templates: widget.templates,
      hasActiveForKey: (key) =>
          CalendarPage._snapshotHasActiveMaatInstanceFor(_snapshot, key),
      onPickTemplate: widget.onPickTemplate,
      onCreateNew: widget.onCreateNew,
    );
  }
}

class _MaatFlowsListPage extends StatelessWidget {
  const _MaatFlowsListPage({
    required this.hasActiveForKey,
    required this.onPickTemplate,
    required this.onCreateNew,
    required this.title,
    required this.templates,
  });

  final bool Function(String key) hasActiveForKey;
  final Future<void> Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: GlossyText(
          text: title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          gradient: goldGloss,
        ),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(Icons.add, color: _silver),
            onPressed: onCreateNew,
          ),
        ],
      ),
      body: templates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No Ma’at flows yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: templates.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 12, color: Colors.white10),
              itemBuilder: (ctx, i) {
                final t = templates[i];
                final added = hasActiveForKey(t.key);
                return ListTile(
                  onTap: () async => onPickTemplate(t),
                  leading: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _glossFromColor(t.color),
                    ),
                  ),
                  title: GlossyText(
                    text: t.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    gradient: goldGloss,
                  ),
                  subtitle: Text(
                    '${_maatFlowTemplateDurationLabel(t)} • ${t.overview.isEmpty ? '—' : 'Tap for details'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: added
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _gold, width: 1.2),
                          ),
                          child: const GlossyText(
                            text: 'Added',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            gradient: _maatBadgeGoldGloss,
                          ),
                        )
                      : const Icon(Icons.chevron_right, color: _silver),
                );
              },
            ),
    );
  }
}

/* ───────────────────────── Template detail (Add Flow) ───────────────────────── */

class _MaatFlowTemplateDetailPage extends StatefulWidget {
  const _MaatFlowTemplateDetailPage({
    required this.template,
    required this.addInstance,
  });

  final _MaatFlowTemplate template;
  final Future<int> Function({
    required _MaatFlowTemplate template,
    DateTime? startDate,
    bool? useKemetic,
    TrackSkyTimeZone? trackSkyTimeZone,
    int? alertMinutesBefore,
    bool? dawnDiscreetMode,
    DawnHouseRiteLens? dawnLens,
    bool? eveningDiscreetMode,
    EveningThresholdRiteLens? eveningLens,
    int? eveningFallbackMinutesAfterMidnight,
    TheWeighingLens? theWeighingLens,
    OfferingTableLens? offeringTableLens,
    bool? offeringNoCupMode,
    TheTendingLens? theTendingLens,
    KeptWordLens? keptWordLens,
    CourseLens? courseLens,
    MoonReturnLens? moonReturnLens,
    WagLens? wagLens,
    DecanWatchLens? decanWatchLens,
    OpenHandLens? openHandLens,
    DjedLens? djedLens,
  })
  addInstance;

  @override
  State<_MaatFlowTemplateDetailPage> createState() =>
      _MaatFlowTemplateDetailPageState();
}

class _MaatFlowTemplateDetailPageState
    extends State<_MaatFlowTemplateDetailPage> {
  late TrackSkyTimeZone _previewTrackSkyTimeZone;
  Future<TrackSkyFlowData>? _trackSkyFuture;
  bool _dawnDiscreetMode = false;
  DawnHouseRiteLens _dawnLens = DawnHouseRiteLens.neutral;
  bool _dawnStartDateTouched = false;
  bool _dawnJoinInFlight = false;
  bool _eveningDiscreetMode = false;
  EveningThresholdRiteLens _eveningLens = EveningThresholdRiteLens.neutral;
  bool _eveningStartDateTouched = false;
  int _eveningFallbackMinutes = kEveningThresholdDefaultFallbackMinutes;
  bool _eveningJoinInFlight = false;
  TheWeighingLens _theWeighingLens = TheWeighingLens.neutral;
  bool _theWeighingStartDateTouched = false;
  bool _theWeighingJoinInFlight = false;
  OfferingTableLens _offeringTableLens = OfferingTableLens.neutral;
  bool _offeringNoCupMode = false;
  bool _offeringStartDateTouched = false;
  bool _offeringJoinInFlight = false;
  TheTendingLens _theTendingLens = TheTendingLens.neutral;
  bool _theTendingStartDateTouched = false;
  bool _theTendingJoinInFlight = false;
  KeptWordLens _keptWordLens = KeptWordLens.neutral;
  bool _keptWordStartDateTouched = false;
  bool _keptWordJoinInFlight = false;
  CourseLens _courseLens = CourseLens.neutral;
  bool _courseStartDateTouched = false;
  bool _courseJoinInFlight = false;
  MoonReturnLens _moonReturnLens = MoonReturnLens.neutral;
  bool _moonReturnStartDateTouched = false;
  bool _moonReturnJoinInFlight = false;
  WagLens _wagLens = WagLens.neutral;
  bool _wagStartDateTouched = false;
  bool _wagJoinInFlight = false;
  DecanWatchLens _decanWatchLens = DecanWatchLens.neutral;
  bool _decanWatchStartDateTouched = false;
  bool _decanWatchJoinInFlight = false;
  bool _daysOutsideYearStartDateTouched = false;
  bool _daysOutsideYearJoinInFlight = false;
  OpenHandLens _openHandLens = OpenHandLens.neutral;
  bool _openHandStartDateTouched = false;
  bool _openHandJoinInFlight = false;
  DjedLens _djedLens = DjedLens.neutral;
  bool _djedStartDateTouched = false;
  bool _djedJoinInFlight = false;

  @override
  void initState() {
    super.initState();
    _previewTrackSkyTimeZone = detectTrackSkyTimeZone();
    if (widget.template.kind == _MaatFlowTemplateKind.trackSky) {
      _trackSkyFuture = loadTrackSkyFlowData(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.dawnHouseRite) {
      _picked = defaultDawnHouseRiteStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind ==
        _MaatFlowTemplateKind.eveningThresholdRite) {
      _picked = defaultEveningThresholdRiteStartDate(
        _previewTrackSkyTimeZone,
        fallbackMinutesAfterMidnight: _eveningFallbackMinutes,
      );
    } else if (widget.template.kind == _MaatFlowTemplateKind.theWeighing) {
      _picked = defaultTheWeighingStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.offeringTable) {
      _picked = defaultOfferingTableStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.theTending) {
      _picked = defaultTheTendingStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.keptWord) {
      _picked = defaultKeptWordStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.theCourse) {
      _picked = defaultTheCourseStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.moonReturn) {
      _picked = moonReturnDefaultStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.theWag) {
      _picked = defaultTheWagStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.decanWatch) {
      _picked = defaultTheDecanWatchStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind ==
        _MaatFlowTemplateKind.daysOutsideTheYear) {
      _picked = defaultTheDaysOutsideYearStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.theOpenHand) {
      _picked = defaultTheOpenHandStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.theDjed) {
      _picked = defaultTheDjedStartDate(_previewTrackSkyTimeZone);
    }
  }

  String _kemeticLabelFor(DateTime g) {
    final k = KemeticMath.fromGregorian(g);
    final lastDay = (k.kMonth == 13)
        ? (KemeticMath.isLeapKemeticYear(k.kYear) ? 6 : 5)
        : 30;
    final yStart = KemeticMath.toGregorian(k.kYear, k.kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(k.kYear, k.kMonth, lastDay).year;
    final yLabel = (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
    final month = getMonthById(k.kMonth).displayFull;
    return '$month ${k.kDay} • $yLabel';
  }

  bool _useKemetic = true;
  DateTime? _picked;

  void _toggleDateMode() {
    setState(() {
      _useKemetic = !_useKemetic;
    });
  }

  String _dateLabel(BuildContext context, DateTime date) {
    if (_useKemetic) return _kemeticLabelFor(date);
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  String _startDateButtonLabel(BuildContext context, DateTime date) {
    return 'Start: ${_dateLabel(context, date)}';
  }

  T? _tryEnrollmentWindow<T>(String debugLabel, T Function() resolve) {
    try {
      return resolve();
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint(
          '[$debugLabel] enrollment window unavailable: '
          'timezone=${_previewTrackSkyTimeZone.key} '
          'selectedDate=${_picked?.toIso8601String() ?? 'none'} '
          'now=${DateTime.now().toIso8601String()} '
          'error=$e',
        );
        _calendarDebugPrint('$st');
      }
      return null;
    }
  }

  Widget _buildEnrollmentUnavailableScaffold(
    BuildContext context, {
    required String debugLabel,
  }) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + media.padding.bottom),
          children: [
            _buildDateModeTitle(title: widget.template.title),
            const SizedBox(height: 12),
            Text(
              widget.template.overview,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0C0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold, width: 1.1),
              ),
              child: const Text(
                'No enrollment window is available right now. Try another timezone or retry in a moment.',
                style: TextStyle(
                  color: Color(0xFFFFD486),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const GlossyText(
              text: 'Timezone',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              gradient: silverGloss,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TrackSkyTimeZone.values.map((timezone) {
                return ChoiceChip(
                  label: Text(timezone.shortLabel),
                  selected: _previewTrackSkyTimeZone == timezone,
                  onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                  selectedColor: _gold,
                  labelStyle: TextStyle(
                    color: _previewTrackSkyTimeZone == timezone
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF15171B),
                  side: const BorderSide(color: Colors.white24),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold, width: 1.1),
                ),
                onPressed: () {
                  if (kDebugMode) {
                    _calendarDebugPrint('[$debugLabel] retry enrollment');
                  }
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateModeTitle({
    required String title,
    double fontSize = 20,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Semantics(
      button: true,
      label: _useKemetic ? 'Show Gregorian dates' : 'Show Kemetic dates',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleDateMode,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: GlossyText(
            text: title,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            gradient: _useKemetic ? goldGloss : whiteGloss,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    if (widget.template.kind == _MaatFlowTemplateKind.moonReturn) {
      await _pickMoonReturnWindowDate();
      return;
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theWag) {
      await _pickWagWindowDate();
      return;
    }
    if (widget.template.kind == _MaatFlowTemplateKind.decanWatch) {
      await _pickDecanWatchWindowDate();
      return;
    }
    if (widget.template.kind == _MaatFlowTemplateKind.daysOutsideTheYear) {
      await _pickDaysOutsideYearWindowDate();
      return;
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theOpenHand) {
      await _pickOpenHandWindowDate();
      return;
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theDjed) {
      await _pickDjedWindowDate();
      return;
    }
    bool localKemetic = _useKemetic;

    final now = DateUtils.dateOnly(DateTime.now());
    DateTime gSeed =
        _picked ??
        (() {
          int y = now.year, m = now.month, d = now.day + 1;
          final maxD = DateUtils.getDaysInMonth(y, m);
          if (d > maxD) {
            d = 1;
            m = (m == 12) ? 1 : m + 1;
            if (m == 1) y++;
          }
          return DateTime(y, m, d);
        })();
    int gy = gSeed.year, gm = gSeed.month, gd = gSeed.day;

    var kSeed = KemeticMath.fromGregorian(
      _picked ?? now.add(const Duration(days: 1)),
    );
    int ky = kSeed.kYear, km = kSeed.kMonth, kd = kSeed.kDay;

    int gregDayMax(int y, int m) => DateUtils.getDaysInMonth(y, m);
    int kemDayMax(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    final int gYearStart = now.year;
    final gYearCtrl = FixedExtentScrollController(
      initialItem: (gy - gYearStart).clamp(0, 399),
    );
    final gMonthCtrl = FixedExtentScrollController(
      initialItem: (gm - 1).clamp(0, 11),
    );
    final gDayCtrl = FixedExtentScrollController(
      initialItem: (gd - 1).clamp(0, 30),
    );

    final int kYearStart = ky;
    final kYearCtrl = FixedExtentScrollController(
      initialItem: (ky - kYearStart).clamp(0, 400),
    );
    final kMonthCtrl = FixedExtentScrollController(
      initialItem: (km - 1).clamp(0, 12),
    );
    final kDayCtrl = FixedExtentScrollController(
      initialItem: (kd - 1).clamp(0, 29),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final gMax = gregDayMax(gy, gm);
            if (gd > gMax) gd = gMax;
            final kMax = kemDayMax(ky, km);
            if (kd > kMax) kd = kMax;

            void toggleSheetDateMode() {
              setSheetState(() {
                if (!localKemetic) {
                  final gNow = DateTime(gy, gm, gd);
                  final k = KemeticMath.fromGregorian(gNow);
                  ky = k.kYear;
                  km = k.kMonth;
                  kd = k.kDay;
                  final kMax = kemDayMax(ky, km);
                  if (kd > kMax) kd = kMax;
                  localKemetic = true;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    kYearCtrl.jumpToItem((ky - kYearStart).clamp(0, 400));
                    kMonthCtrl.jumpToItem((km - 1).clamp(0, 12));
                    kDayCtrl.jumpToItem((kd - 1).clamp(0, 29));
                  });
                } else {
                  final g = KemeticMath.toGregorian(ky, km, kd);
                  gy = g.year;
                  gm = g.month;
                  gd = g.day;
                  final gMax = gregDayMax(gy, gm);
                  if (gd > gMax) gd = gMax;
                  localKemetic = false;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    gYearCtrl.jumpToItem((gy - gYearStart).clamp(0, 39));
                    gMonthCtrl.jumpToItem((gm - 1).clamp(0, 11));
                    gDayCtrl.jumpToItem((gd - 1).clamp(0, 30));
                  });
                }
              });
            }

            Widget gregWheel() => SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: gMonthCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          gm = (i % 12) + 1;
                          final mx = gregDayMax(gy, gm);
                          if (gd > mx && gDayCtrl.hasClients) {
                            gd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => gDayCtrl.jumpToItem(gd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(12, (i) {
                        return Center(
                          child: GlossyText(
                            text: _gregMonthNames[i + 1],
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: gDayCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          final mx = gregDayMax(gy, gm);
                          gd = (i % mx) + 1;
                        });
                      },
                      children: List.generate(gregDayMax(gy, gm), (i) {
                        final dd = i + 1;
                        return Center(
                          child: GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: gYearCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          gy = gYearStart + i;
                          final mx = gregDayMax(gy, gm);
                          if (gd > mx && gDayCtrl.hasClients) {
                            gd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => gDayCtrl.jumpToItem(gd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(40, (i) {
                        final yy = gYearStart + i;
                        return Center(
                          child: GlossyText(
                            text: '$yy',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );

            Widget kemWheel() => SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: kMonthCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          km = (i % 13) + 1;
                          final mx = kemDayMax(ky, km);
                          if (kd > mx && kDayCtrl.hasClients) {
                            kd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => kDayCtrl.jumpToItem(kd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(13, (i) {
                        final m = i + 1;
                        return Center(
                          child: MonthNameText(
                            getMonthById(m).displayFull,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: kDayCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          final mx = kemDayMax(ky, km);
                          kd = (i % mx) + 1;
                        });
                      },
                      children: List.generate(kemDayMax(ky, km), (i) {
                        final dd = i + 1;
                        return Center(
                          child: GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: kYearCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          ky = kYearStart + i;
                          final mx = kemDayMax(ky, km);
                          if (kd > mx && kDayCtrl.hasClients) {
                            kd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => kDayCtrl.jumpToItem(kd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(401, (i) {
                        final y = kYearStart + i;
                        final last = (km == 13)
                            ? (KemeticMath.isLeapKemeticYear(y) ? 6 : 5)
                            : 30;
                        final yStart = KemeticMath.toGregorian(y, km, 1).year;
                        final yEnd = KemeticMath.toGregorian(y, km, last).year;
                        final label = (yStart == yEnd)
                            ? '$yStart'
                            : '$yStart/$yEnd';
                        return Center(
                          child: GlossyText(
                            text: label,
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: localKemetic
                        ? 'Show Gregorian date picker'
                        : 'Show Kemetic date picker',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: toggleSheetDateMode,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GlossyText(
                          text: localKemetic
                              ? 'Start date (Kemetic)'
                              : 'Start date (Gregorian)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          gradient: localKemetic ? goldGloss : whiteGloss,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  localKemetic ? kemWheel() : gregWheel(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: silver, width: 1.25),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: localKemetic ? _gold : _blue,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            final DateTime chosen = localKemetic
                                ? KemeticMath.toGregorian(ky, km, kd)
                                : DateUtils.dateOnly(DateTime(gy, gm, gd));
                            setState(() {
                              _useKemetic = localKemetic;
                              _picked = chosen;
                              if (widget.template.kind ==
                                  _MaatFlowTemplateKind.dawnHouseRite) {
                                _dawnStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.eveningThresholdRite) {
                                _eveningStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.theWeighing) {
                                _theWeighingStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.offeringTable) {
                                _offeringStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.theTending) {
                                _theTendingStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.keptWord) {
                                _keptWordStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.theCourse) {
                                _courseStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.moonReturn) {
                                _moonReturnStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.theWag) {
                                _wagStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.decanWatch) {
                                _decanWatchStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.daysOutsideTheYear) {
                                _daysOutsideYearStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.theOpenHand) {
                                _openHandStartDateTouched = true;
                              } else if (widget.template.kind ==
                                  _MaatFlowTemplateKind.theDjed) {
                                _djedStartDateTouched = true;
                              }
                            });
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('Use this date'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickMoonReturnWindowDate() async {
    final windows = moonReturnUpcomingEnrollmentWindows(
      _previewTrackSkyTimeZone,
      count: 12,
    );
    if (windows.isEmpty) return;
    final l10n = MaterialLocalizations.of(context);
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const GlossyText(
                  text: 'Moon Return Start Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This picker only shows designated new-moon enrollment windows.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: windows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final window = windows[index];
                      final selected =
                          _picked != null &&
                          DateUtils.isSameDay(
                            DateUtils.dateOnly(_picked!),
                            DateUtils.dateOnly(window.opensAtLocal),
                          );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? _gold : Colors.white38,
                        ),
                        title: Text(
                          _dateLabel(context, window.opensAtLocal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Opens ${timeLabel(window.opensAtLocal)} • New moon ${_dateLabel(context, window.newMoonInstantLocal)} • ${window.enrollProminence.label}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _picked = DateUtils.dateOnly(window.opensAtLocal);
                            _moonReturnStartDateTouched = true;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickWagWindowDate() async {
    final windows = wagUpcomingEnrollmentWindows(
      _previewTrackSkyTimeZone,
      count: 6,
    );
    if (windows.isEmpty) return;
    final l10n = MaterialLocalizations.of(context);
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const GlossyText(
                  text: 'Wag Start Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This picker only shows designated Wep Ronpet enrollment windows.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: windows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final window = windows[index];
                      final selected =
                          _picked != null &&
                          DateUtils.isSameDay(
                            DateUtils.dateOnly(_picked!),
                            DateUtils.dateOnly(window.opensAtLocal),
                          );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? _gold : Colors.white38,
                        ),
                        title: Text(
                          'Wep Ronpet ${window.opensAtLocal.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Opens ${_dateLabel(context, window.opensAtLocal)} at ${timeLabel(window.opensAtLocal)} • closes ${_dateLabel(context, window.closesAtLocal)} at ${timeLabel(window.closesAtLocal)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _picked = DateUtils.dateOnly(window.opensAtLocal);
                            _wagStartDateTouched = true;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDecanWatchWindowDate() async {
    final windows = decanWatchUpcomingEnrollmentWindows(
      _previewTrackSkyTimeZone,
      count: 12,
    );
    if (windows.isEmpty) return;
    final l10n = MaterialLocalizations.of(context);
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const GlossyText(
                  text: 'Decan Watch Start Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This picker only shows designated decan-opening enrollment windows.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: windows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final window = windows[index];
                      final occurrence = window.openingOccurrence;
                      final selected =
                          _picked != null &&
                          DateUtils.isSameDay(
                            DateUtils.dateOnly(_picked!),
                            DateUtils.dateOnly(window.opensAtLocal),
                          );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? _gold : Colors.white38,
                        ),
                        title: Text(
                          occurrence.decanName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${window.opensAtLocal.year} · M${occurrence.kMonth} D${occurrence.decanStartDay} · opens ${_dateLabel(context, window.opensAtLocal)} at ${timeLabel(window.opensAtLocal)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _picked = DateUtils.dateOnly(window.opensAtLocal);
                            _decanWatchStartDateTouched = true;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickOpenHandWindowDate() async {
    final windows = openHandUpcomingEnrollmentWindows(
      _previewTrackSkyTimeZone,
      count: 12,
    );
    if (windows.isEmpty) return;
    final l10n = MaterialLocalizations.of(context);
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const GlossyText(
                  text: 'Open Hand Start Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This picker only shows designated decan-opening enrollment windows.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: windows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final window = windows[index];
                      final occurrence = window.openingOccurrence;
                      final selected =
                          _picked != null &&
                          DateUtils.isSameDay(
                            DateUtils.dateOnly(_picked!),
                            DateUtils.dateOnly(window.opensAtLocal),
                          );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? _gold : Colors.white38,
                        ),
                        title: Text(
                          occurrence.decanName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${window.opensAtLocal.year} · M${occurrence.kMonth} D${occurrence.decanStartDay} · opens ${_dateLabel(context, window.opensAtLocal)} at ${timeLabel(window.opensAtLocal)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _picked = DateUtils.dateOnly(window.opensAtLocal);
                            _openHandStartDateTouched = true;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDjedWindowDate() async {
    final windows = djedUpcomingEnrollmentWindows(
      _previewTrackSkyTimeZone,
      count: 12,
    );
    if (windows.isEmpty) return;
    final l10n = MaterialLocalizations.of(context);
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const GlossyText(
                  text: 'Djed Start Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This picker only shows designated decan-opening enrollment windows.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: windows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final window = windows[index];
                      final occurrence = window.openingOccurrence;
                      final selected =
                          _picked != null &&
                          DateUtils.isSameDay(
                            DateUtils.dateOnly(_picked!),
                            DateUtils.dateOnly(window.opensAtLocal),
                          );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? _gold : Colors.white38,
                        ),
                        title: Text(
                          occurrence.decanName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${window.opensAtLocal.year} · M${occurrence.kMonth} D${occurrence.decanStartDay} · opens ${_dateLabel(context, window.opensAtLocal)} at ${timeLabel(window.opensAtLocal)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _picked = DateUtils.dateOnly(window.opensAtLocal);
                            _djedStartDateTouched = true;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDaysOutsideYearWindowDate() async {
    final windows = daysOutsideYearUpcomingEnrollmentWindows(
      _previewTrackSkyTimeZone,
      count: 6,
    );
    if (windows.isEmpty) return;
    final l10n = MaterialLocalizations.of(context);
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetCtx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const GlossyText(
                  text: 'Year-Closing Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This picker only shows designated year-closing enrollment windows.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: windows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final window = windows[index];
                      final selected =
                          _picked != null &&
                          DateUtils.isSameDay(
                            DateUtils.dateOnly(_picked!),
                            DateUtils.dateOnly(window.opensAtLocal),
                          );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? _gold : Colors.white38,
                        ),
                        title: Text(
                          'Year Closing ${window.opensAtLocal.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'M12 D28 opens ${_dateLabel(context, window.opensAtLocal)} at ${timeLabel(window.opensAtLocal)} • closes before ${_dateLabel(context, window.closesAtLocal)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _picked = DateUtils.dateOnly(window.opensAtLocal);
                            _daysOutsideYearStartDateTouched = true;
                          });
                          Navigator.pop(sheetCtx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setTrackSkyPreviewTimeZone(
    TrackSkyTimeZone timezone, {
    bool forceReload = false,
  }) {
    if (!forceReload && _previewTrackSkyTimeZone == timezone) return;
    if (forceReload) {
      clearTrackSkyFlowCache(timezone);
    }
    setState(() {
      _previewTrackSkyTimeZone = timezone;
      if (widget.template.kind == _MaatFlowTemplateKind.trackSky) {
        _trackSkyFuture = loadTrackSkyFlowData(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.dawnHouseRite &&
          !_dawnStartDateTouched) {
        _picked = defaultDawnHouseRiteStartDate(timezone);
      } else if (widget.template.kind ==
              _MaatFlowTemplateKind.eveningThresholdRite &&
          !_eveningStartDateTouched) {
        _picked = defaultEveningThresholdRiteStartDate(
          timezone,
          fallbackMinutesAfterMidnight: _eveningFallbackMinutes,
        );
      } else if (widget.template.kind == _MaatFlowTemplateKind.theWeighing &&
          !_theWeighingStartDateTouched) {
        _picked = defaultTheWeighingStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.offeringTable &&
          !_offeringStartDateTouched) {
        _picked = defaultOfferingTableStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.theTending &&
          !_theTendingStartDateTouched) {
        _picked = defaultTheTendingStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.keptWord &&
          !_keptWordStartDateTouched) {
        _picked = defaultKeptWordStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.theCourse &&
          !_courseStartDateTouched) {
        _picked = defaultTheCourseStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.moonReturn &&
          !_moonReturnStartDateTouched) {
        _picked = moonReturnDefaultStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.theWag &&
          !_wagStartDateTouched) {
        _picked = defaultTheWagStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.decanWatch &&
          !_decanWatchStartDateTouched) {
        _picked = defaultTheDecanWatchStartDate(timezone);
      } else if (widget.template.kind ==
              _MaatFlowTemplateKind.daysOutsideTheYear &&
          !_daysOutsideYearStartDateTouched) {
        _picked = defaultTheDaysOutsideYearStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.theOpenHand &&
          !_openHandStartDateTouched) {
        _picked = defaultTheOpenHandStartDate(timezone);
      } else if (widget.template.kind == _MaatFlowTemplateKind.theDjed &&
          !_djedStartDateTouched) {
        _picked = defaultTheDjedStartDate(timezone);
      }
    });
  }

  String _dawnLensExplanation(DawnHouseRiteLens lens) {
    switch (lens) {
      case DawnHouseRiteLens.neutral:
        return 'Neutral keeps the standard rite text with no added emphasis.';
      case DawnHouseRiteLens.solar:
        return 'Solar adds a short focus on first light, renewal, and restored direction.';
      case DawnHouseRiteLens.ancestor:
        return 'Ancestor adds a short focus on memory, lineage, and the remembered dead.';
      case DawnHouseRiteLens.household:
        return 'Household adds a short focus on rooms, shared resources, and relationships at home.';
      case DawnHouseRiteLens.thothic:
        return 'Thothic adds a short focus on recordkeeping, measure, and truthful observation.';
      case DawnHouseRiteLens.protection:
        return 'Protection adds a short focus on clean boundaries, safety, and guarding against disorder.';
    }
  }

  String _eveningLensExplanation(EveningThresholdRiteLens lens) {
    switch (lens) {
      case EveningThresholdRiteLens.neutral:
        return 'Neutral keeps the standard evening rite text with no added emphasis.';
      case EveningThresholdRiteLens.solar:
        return 'Solar adds a short focus on sunset as the beginning of the hidden solar journey.';
      case EveningThresholdRiteLens.ancestor:
        return 'Ancestor adds a short focus on memory, lineage, and quiet remembrance.';
      case EveningThresholdRiteLens.household:
        return 'Household adds a short focus on rooms, shared resources, and evening speech at home.';
      case EveningThresholdRiteLens.protection:
        return 'Protection adds a short focus on boundaries that protect rest, safety, truth, or peace.';
      case EveningThresholdRiteLens.hiddenRenewal:
        return 'Hidden Renewal adds a short focus on rest as restoration after the visible day closes.';
    }
  }

  String _theWeighingLensExplanation(TheWeighingLens lens) {
    switch (lens) {
      case TheWeighingLens.neutral:
        return 'Neutral keeps the flow focused on record, measure, and conduct without added devotional framing.';
      case TheWeighingLens.djehuty:
        return 'Djehuty adds a short keeper-of-records line to each sitting.';
    }
  }

  String _offeringTableLensExplanation(OfferingTableLens lens) {
    switch (lens) {
      case OfferingTableLens.neutral:
        return 'Neutral keeps the table focused on water, provision, and truthful care.';
      case OfferingTableLens.hapy:
        return 'Hapy adds a short abundance-and-flow line to each sitting.';
      case OfferingTableLens.ausar:
        return 'Ausar adds a short restoration line for provision that has gone dry.';
    }
  }

  String _theTendingLensExplanation(TheTendingLens lens) {
    switch (lens) {
      case TheTendingLens.neutral:
        return 'Neutral keeps the flow focused on care, labor, and repair without added devotional framing.';
      case TheTendingLens.heru:
        return 'Heru adds a short standing-and-restoration line to each sitting.';
      case TheTendingLens.aset:
        return 'Aset adds a short searching-and-gathering line to each sitting.';
    }
  }

  String _keptWordLensExplanation(KeptWordLens lens) {
    switch (lens) {
      case KeptWordLens.neutral:
        return 'Neutral keeps the flow focused on agreements, conversation, and order without added devotional framing.';
      case KeptWordLens.djehuty:
        return 'Djehuty adds a short exact-record line to each sitting.';
      case KeptWordLens.maat:
        return 'Ma\'at adds a short right-order line to each sitting.';
    }
  }

  String _courseLensExplanation(CourseLens lens) {
    switch (lens) {
      case CourseLens.neutral:
        return 'Neutral keeps the flow focused on day card, decan, and season without added devotional framing.';
      case CourseLens.ra:
        return 'Ra adds a short solar-course line to each sitting.';
      case CourseLens.khepri:
        return 'Khepri adds a short dawn-and-emergence line to each sitting.';
    }
  }

  String _moonReturnLensExplanation(MoonReturnLens lens) {
    switch (lens) {
      case MoonReturnLens.neutral:
        return 'Neutral keeps the flow focused on the lunar empty/fill rhythm without added devotional framing.';
      case MoonReturnLens.heru:
        return 'Heru adds the Eye restored after damage frame to each event.';
      case MoonReturnLens.djehuty:
        return 'Djehuty adds the lunar count and clean-record frame to each event.';
    }
  }

  String _wagLensExplanation(WagLens lens) {
    switch (lens) {
      case WagLens.neutral:
        return 'Neutral keeps the ancestor practice framed as naming, provision, and yearly continuity.';
      case WagLens.ausar:
        return 'Ausar adds a short restoration frame for the blessed dead and what continues through them.';
      case WagLens.anpu:
        return 'Anpu adds a threshold frame for right passage between living memory and the dead.';
    }
  }

  String _decanWatchLensExplanation(DecanWatchLens lens) {
    switch (lens) {
      case DecanWatchLens.neutral:
        return 'Neutral keeps the watch focused on sky, decan, record, and the next ten-day bearing.';
      case DecanWatchLens.ra:
        return 'Ra adds a short night-journey frame for the hidden solar passage through the Duat.';
      case DecanWatchLens.nut:
        return 'Nut adds a short sky-body frame for standing beneath the one who holds the night.';
    }
  }

  TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final normalized = minutes.clamp(0, (24 * 60) - 1).toInt();
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  int _minutesFromTimeOfDay(TimeOfDay time) {
    return (time.hour * 60) + time.minute;
  }

  Future<void> _pickEveningFallbackTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromMinutes(_eveningFallbackMinutes),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _gold,
              onPrimary: Colors.black,
              surface: Color(0xFF101115),
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _eveningFallbackMinutes = _minutesFromTimeOfDay(picked);
      if (!_eveningStartDateTouched &&
          widget.template.kind == _MaatFlowTemplateKind.eveningThresholdRite) {
        _picked = defaultEveningThresholdRiteStartDate(
          _previewTrackSkyTimeZone,
          fallbackMinutesAfterMidnight: _eveningFallbackMinutes,
        );
      }
    });
  }

  Future<void> _joinDawnHouseRiteFlow(DateTime selectedStart) async {
    if (_dawnJoinInFlight) return;
    setState(() {
      _dawnJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        dawnDiscreetMode: _dawnDiscreetMode,
        dawnLens: _dawnLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[dawnHouseRite] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join Dawn House Rite. Please retry.'),
        ),
      );
      setState(() {
        _dawnJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _dawnJoinInFlight = false;
    });
  }

  Future<void> _joinEveningThresholdRiteFlow(DateTime selectedStart) async {
    if (_eveningJoinInFlight) return;
    setState(() {
      _eveningJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        eveningDiscreetMode: _eveningDiscreetMode,
        eveningLens: _eveningLens,
        eveningFallbackMinutesAfterMidnight: _eveningFallbackMinutes,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[eveningThresholdRite] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join Evening Threshold Rite. Please retry.'),
        ),
      );
      setState(() {
        _eveningJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _eveningJoinInFlight = false;
    });
  }

  Future<void> _joinTheWeighingFlow(DateTime selectedStart) async {
    if (_theWeighingJoinInFlight) return;
    setState(() {
      _theWeighingJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        theWeighingLens: _theWeighingLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[theWeighing] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Weighing. Please retry.'),
        ),
      );
      setState(() {
        _theWeighingJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _theWeighingJoinInFlight = false;
    });
  }

  Future<void> _joinOfferingTableFlow(DateTime selectedStart) async {
    if (_offeringJoinInFlight) return;
    setState(() {
      _offeringJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        offeringTableLens: _offeringTableLens,
        offeringNoCupMode: _offeringNoCupMode,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[offeringTable] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Offering Table. Please retry.'),
        ),
      );
      setState(() {
        _offeringJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _offeringJoinInFlight = false;
    });
  }

  Future<void> _joinTheTendingFlow(DateTime selectedStart) async {
    if (_theTendingJoinInFlight) return;
    setState(() {
      _theTendingJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        theTendingLens: _theTendingLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[theTending] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Tending. Please retry.'),
        ),
      );
      setState(() {
        _theTendingJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _theTendingJoinInFlight = false;
    });
  }

  Future<void> _joinKeptWordFlow(DateTime selectedStart) async {
    if (_keptWordJoinInFlight) return;
    setState(() {
      _keptWordJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        keptWordLens: _keptWordLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[keptWord] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Kept Word. Please retry.'),
        ),
      );
      setState(() {
        _keptWordJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _keptWordJoinInFlight = false;
    });
  }

  Future<void> _joinTheCourseFlow(DateTime selectedStart) async {
    if (_courseJoinInFlight) return;
    setState(() {
      _courseJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        courseLens: _courseLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[theCourse] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Course. Please retry.'),
        ),
      );
      setState(() {
        _courseJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _courseJoinInFlight = false;
    });
  }

  Future<void> _joinMoonReturnFlow(DateTime selectedStart) async {
    if (_moonReturnJoinInFlight) return;
    setState(() {
      _moonReturnJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        moonReturnLens: _moonReturnLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[moonReturn] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Moon Return. Please retry.'),
        ),
      );
      setState(() {
        _moonReturnJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _moonReturnJoinInFlight = false;
    });
  }

  Future<void> _joinWagFlow(DateTime selectedStart) async {
    if (_wagJoinInFlight) return;
    setState(() {
      _wagJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        wagLens: _wagLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[theWag] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join The Wag. Please retry.')),
      );
      setState(() {
        _wagJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _wagJoinInFlight = false;
    });
  }

  Future<void> _joinDecanWatchFlow(DateTime selectedStart) async {
    if (_decanWatchJoinInFlight) return;
    setState(() {
      _decanWatchJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        decanWatchLens: _decanWatchLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[decanWatch] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Decan Watch. Please retry.'),
        ),
      );
      setState(() {
        _decanWatchJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _decanWatchJoinInFlight = false;
    });
  }

  Future<void> _joinOpenHandFlow(DateTime selectedStart) async {
    if (_openHandJoinInFlight) return;
    setState(() {
      _openHandJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        openHandLens: _openHandLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[openHand] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Open Hand. Please retry.'),
        ),
      );
      setState(() {
        _openHandJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _openHandJoinInFlight = false;
    });
  }

  Future<void> _joinDjedFlow(DateTime selectedStart) async {
    if (_djedJoinInFlight) return;
    setState(() {
      _djedJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        djedLens: _djedLens,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[djed] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join The Djed. Please retry.')),
      );
      setState(() {
        _djedJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _djedJoinInFlight = false;
    });
  }

  Future<void> _joinDaysOutsideYearFlow(DateTime selectedStart) async {
    if (_daysOutsideYearJoinInFlight) return;
    setState(() {
      _daysOutsideYearJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[daysOutsideYear] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not join The Days Outside the Year. Please retry.',
          ),
        ),
      );
      setState(() {
        _daysOutsideYearJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() {
      _daysOutsideYearJoinInFlight = false;
    });
  }

  Future<void> _openTrackSkyJoinSheet() async {
    TrackSkyTimeZone selectedTimeZone = _previewTrackSkyTimeZone;
    int? selectedAlertMinutes;
    bool isWorking = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        final media = MediaQuery.of(sheetCtx);
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: FractionallySizedBox(
                  heightFactor: 0.88,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + media.padding.bottom,
                    ),
                    child: FutureBuilder<TrackSkyFlowData>(
                      future: loadTrackSkyFlowData(selectedTimeZone),
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final upcoming = data == null
                            ? const <TrackSkyEvent>[]
                            : upcomingTrackSkyEvents(data);
                        final dateRange = upcoming.isEmpty
                            ? null
                            : '${_dateLabel(context, DateTime.parse(upcoming.first.schedule.dateIso))} → ${_dateLabel(context, DateTime.parse(upcoming.last.schedule.dateIso))}';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  const GlossyText(
                                    text: 'Join Follow the sky',
                                    gradient: _maatBadgeGoldGloss,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Choose your timezone and alert preference. The remaining sky events for that timezone will be added to your calendar.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Timezone',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  RadioGroup<TrackSkyTimeZone>(
                                    groupValue: selectedTimeZone,
                                    onChanged: (value) {
                                      if (isWorking || value == null) return;
                                      setSheetState(() {
                                        selectedTimeZone = value;
                                      });
                                    },
                                    child: Column(
                                      children: TrackSkyTimeZone.values
                                          .map((timezone) {
                                            return RadioListTile<
                                              TrackSkyTimeZone
                                            >(
                                              value: timezone,
                                              enabled: !isWorking,
                                              activeColor: _gold,
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                timezone.label,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              subtitle: Text(
                                                timezone.shortLabel,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(growable: false),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Alert',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Alert preference',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      selectedAlertMinutes == null
                                          ? 'Choose when you want to be reminded'
                                          : _alertLabelFor(
                                              selectedAlertMinutes,
                                            ),
                                      style: TextStyle(
                                        color: selectedAlertMinutes == null
                                            ? _gold
                                            : Colors.white54,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: _silver,
                                    ),
                                    onTap: isWorking
                                        ? null
                                        : () async {
                                            final picked =
                                                await _pickAlertMinutes(
                                                  sheetCtx,
                                                  selectedAlertMinutes,
                                                );
                                            if (picked == null) return;
                                            setSheetState(() {
                                              selectedAlertMinutes = picked;
                                            });
                                          },
                                  ),
                                  if (snapshot.hasError) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Could not load sky events for this timezone.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _gold,
                                          side: const BorderSide(
                                            color: _gold,
                                            width: 1.1,
                                          ),
                                        ),
                                        onPressed: isWorking
                                            ? null
                                            : () {
                                                clearTrackSkyFlowCache(
                                                  selectedTimeZone,
                                                );
                                                setSheetState(() {});
                                              },
                                        child: const Text('Retry'),
                                      ),
                                    ),
                                  ] else if (snapshot.connectionState ==
                                      ConnectionState.waiting)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      upcoming.isEmpty
                                          ? 'No upcoming sky events remain in this timezone.'
                                          : '${upcoming.length} events will be added${dateRange == null ? '' : ' • $dateRange'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  if (selectedAlertMinutes == null) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Choose an alert preference before joining.',
                                      style: TextStyle(
                                        color: _gold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed:
                                    isWorking ||
                                        snapshot.hasError ||
                                        snapshot.connectionState ==
                                            ConnectionState.waiting
                                    ? null
                                    : () async {
                                        if (selectedAlertMinutes == null) {
                                          final picked =
                                              await _pickAlertMinutes(
                                                sheetCtx,
                                                _alertNoneMinutes,
                                              );
                                          if (picked == null) return;
                                          setSheetState(() {
                                            selectedAlertMinutes = picked;
                                          });
                                          return;
                                        }
                                        setSheetState(() => isWorking = true);
                                        final int id;
                                        try {
                                          id = await widget.addInstance(
                                            template: widget.template,
                                            trackSkyTimeZone: selectedTimeZone,
                                            alertMinutesBefore:
                                                selectedAlertMinutes!,
                                          );
                                        } catch (e, st) {
                                          if (kDebugMode) {
                                            _calendarDebugPrint(
                                              '[trackSky] join failed: $e',
                                            );
                                            _calendarDebugPrint('$st');
                                          }
                                          if (!mounted || !sheetCtx.mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Could not join Follow the sky. Please retry.',
                                              ),
                                            ),
                                          );
                                          setSheetState(
                                            () => isWorking = false,
                                          );
                                          return;
                                        }
                                        if (!mounted || !sheetCtx.mounted) {
                                          return;
                                        }
                                        if (id > 0) {
                                          Navigator.of(sheetCtx).pop();
                                          Navigator.of(context).pop(id);
                                        } else {
                                          setSheetState(
                                            () => isWorking = false,
                                          );
                                        }
                                      },
                                child: Text(
                                  isWorking
                                      ? 'Joining…'
                                      : selectedAlertMinutes == null
                                      ? 'Choose Alert'
                                      : 'Join Flow',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackSkyCategorySection(
    BuildContext context,
    String category,
    List<TrackSkyEvent> events,
  ) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        GlossyText(
          text: '$category (${events.length})',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          gradient: silverGloss,
        ),
        const SizedBox(height: 8),
        ...events.map((event) => _buildTrackSkyEventTile(context, event)),
      ],
    );
  }

  Widget _buildTrackSkyEventTile(BuildContext context, TrackSkyEvent event) {
    final detailSummary = event.detailSummary;
    final scheduleDate = DateTime.parse(event.schedule.dateIso);
    final scheduleTime =
        event.schedule.allDay || event.schedule.startTime24 == null
        ? ''
        : event.schedule.endTime24 == null
        ? event.schedule.startTime24!
        : '${event.schedule.startTime24}–${event.schedule.endTime24}';
    final subtitle = _useKemetic
        ? '${_dateLabel(context, scheduleDate)}${scheduleTime.isEmpty ? '' : ' · $scheduleTime'}'
        : event.exactLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: detailSummary.isEmpty
              ? const <Widget>[]
              : <Widget>[
                  Text(
                    detailSummary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildTemplateStickyJoinButton({
    required double buttonWidth,
    required VoidCallback? onPressed,
    String text = 'Join Flow',
  }) {
    return Center(
      child: SizedBox(
        width: buttonWidth,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF090A0D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            side: const BorderSide(color: _gold, width: 1.15),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: GlossyText(
            text: text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            gradient: goldGloss,
          ),
        ),
      ),
    );
  }

  Widget _buildTrackSkyScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          FutureBuilder<TrackSkyFlowData>(
            future: _trackSkyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not load sky events.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: const BorderSide(color: _gold, width: 1.1),
                          ),
                          onPressed: () => _setTrackSkyPreviewTimeZone(
                            _previewTrackSkyTimeZone,
                            forceReload: true,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return const SizedBox.shrink();
              }
              final upcoming = upcomingTrackSkyEvents(data);
              final firstDate = upcoming.isEmpty
                  ? null
                  : _dateLabel(
                      context,
                      DateTime.parse(upcoming.first.schedule.dateIso),
                    );
              final lastDate = upcoming.isEmpty
                  ? null
                  : _dateLabel(
                      context,
                      DateTime.parse(upcoming.last.schedule.dateIso),
                    );

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
                children: [
                  _buildDateModeTitle(title: widget.template.title),
                  const SizedBox(height: 8),
                  Text(
                    widget.template.overview,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  const GlossyText(
                    text: 'Preview Timezone',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    gradient: silverGloss,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TrackSkyTimeZone.values.map((timezone) {
                      return ChoiceChip(
                        label: Text(timezone.shortLabel),
                        selected: _previewTrackSkyTimeZone == timezone,
                        onSelected: (_) =>
                            _setTrackSkyPreviewTimeZone(timezone),
                        selectedColor: _gold,
                        labelStyle: TextStyle(
                          color: _previewTrackSkyTimeZone == timezone
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: const Color(0xFF15171B),
                        side: const BorderSide(color: Colors.white24),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    upcoming.isEmpty
                        ? 'No upcoming sky events remain in ${_previewTrackSkyTimeZone.label}.'
                        : 'Previewing ${upcoming.length} upcoming events in ${_previewTrackSkyTimeZone.label}${firstDate == null || lastDate == null ? '' : ' • $firstDate → $lastDate'}.',
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only events with a usable viewing window are included when you join. You can confirm timezone and alert settings from the Join Flow button.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  for (final category in kTrackSkyCategoryOrder)
                    _buildTrackSkyCategorySection(
                      context,
                      category,
                      upcoming
                          .where((event) => event.category == category)
                          .toList(),
                    ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              onPressed: _openTrackSkyJoinSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDawnHouseRiteDayTile(
    BuildContext context,
    DawnHouseRiteDay day,
  ) {
    final detail = dawnHouseRiteDetailText(
      day,
      discreet: _dawnDiscreetMode,
      lens: _dawnLens,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            dawnHouseRiteEventTitle(day),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              day.section,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDawnHouseRiteScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultDawnHouseRiteStartDate(_previewTrackSkyTimeZone);
    final firstSchedule = dawnHouseRiteScheduleForDate(
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final lastSchedule = dawnHouseRiteScheduleForDate(
      selectedStart.add(Duration(days: kDawnHouseRiteDays.length - 1)),
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final lastTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: lastSchedule.startLocal.hour,
        minute: lastSchedule.startLocal.minute,
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              _buildDateModeTitle(title: widget.template.title),
              const SizedBox(height: 8),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Estimated from ${firstSchedule.referenceLocation.name} for ${_previewTrackSkyTimeZone.label}. First dawn: ${_dateLabel(context, selectedStart)} at $firstTime. Final dawn: ${_dateLabel(context, lastSchedule.startLocal)} at $lastTime.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(_startDateButtonLabel(context, selectedStart)),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _gold,
                value: _dawnDiscreetMode,
                onChanged: (value) {
                  setState(() {
                    _dawnDiscreetMode = value;
                  });
                },
                title: const Text(
                  'Discreet mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Changes wording only. Turn this on when the rite needs to look ordinary in public or shared space; event text avoids visible ritual terms such as altar, shrine, offering, incense, flame, deity names, and ma’at.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds a short emphasis to each day’s guidance. It does not change the dawn times, duration, or thirty-day sequence.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DawnHouseRiteLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _dawnLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _dawnLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _dawnLens == lens ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _dawnLensExplanation(_dawnLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '30-Day Outline',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kDawnHouseRiteDays.map(
                (day) => _buildDawnHouseRiteDayTile(context, day),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _dawnJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _dawnJoinInFlight
                  ? null
                  : () => _joinDawnHouseRiteFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEveningThresholdRiteDayTile(
    BuildContext context,
    EveningThresholdRiteDay day,
  ) {
    final detail = eveningThresholdRiteDetailText(
      day,
      discreet: _eveningDiscreetMode,
      lens: _eveningLens,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            eveningThresholdRiteEventTitle(day),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              day.section,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEveningThresholdRiteScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ??
        defaultEveningThresholdRiteStartDate(
          _previewTrackSkyTimeZone,
          fallbackMinutesAfterMidnight: _eveningFallbackMinutes,
        );
    final firstSchedule = eveningThresholdScheduleForDate(
      selectedStart,
      _previewTrackSkyTimeZone,
      fallbackMinutesAfterMidnight: _eveningFallbackMinutes,
    );
    final lastSchedule = eveningThresholdScheduleForDate(
      selectedStart.add(Duration(days: kEveningThresholdRiteDays.length - 1)),
      _previewTrackSkyTimeZone,
      fallbackMinutesAfterMidnight: _eveningFallbackMinutes,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final lastTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: lastSchedule.startLocal.hour,
        minute: lastSchedule.startLocal.minute,
      ),
    );
    final fallbackTime = l10n.formatTimeOfDay(
      _timeOfDayFromMinutes(_eveningFallbackMinutes),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              _buildDateModeTitle(title: widget.template.title),
              const SizedBox(height: 8),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Estimated from ${firstSchedule.referenceLocation.name} for ${_previewTrackSkyTimeZone.label}. First evening: ${_dateLabel(context, selectedStart)} at $firstTime. Final evening: ${_dateLabel(context, lastSchedule.startLocal)} at $lastTime.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The default schedule is sunset + 20 minutes. If sunset data is unavailable, the app uses your fallback evening time: $fallbackTime.',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: silver, width: 1.25),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: _pickDate,
                      child: Text(
                        _startDateButtonLabel(context, selectedStart),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: silver, width: 1.25),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: _pickEveningFallbackTime,
                      child: Text('Fallback: $fallbackTime'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _gold,
                value: _eveningDiscreetMode,
                onChanged: (value) {
                  setState(() {
                    _eveningDiscreetMode = value;
                  });
                },
                title: const Text(
                  'Discreet mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Changes wording only. Turn this on when the rite needs to look ordinary in public or shared space; event text avoids visible ritual terms such as altar, offering, incense, flame, and spoken recitation.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds a short emphasis to each evening’s guidance. It does not change the sunset timing, duration, fallback time, or thirty-day sequence.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EveningThresholdRiteLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _eveningLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _eveningLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _eveningLens == lens ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _eveningLensExplanation(_eveningLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '30-Day Outline',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kEveningThresholdRiteDays.map(
                (day) => _buildEveningThresholdRiteDayTile(context, day),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _eveningJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _eveningJoinInFlight
                  ? null
                  : () => _joinEveningThresholdRiteFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTheWeighingEventTile(
    BuildContext context,
    TheWeighingEvent event,
  ) {
    final detail = theWeighingDetailText(event, lens: _theWeighingLens);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            theWeighingEventTitle(event),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${event.decanSection} · ${theWeighingTimingLabel(event)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTheWeighingScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultTheWeighingStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kTheWeighingEvents.first;
    final lastEvent = kTheWeighingEvents.last;
    final firstSchedule = theWeighingScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final lastSchedule = theWeighingScheduleForDate(
      lastEvent,
      selectedStart.add(Duration(days: lastEvent.flowDay - 1)),
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final lastTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: lastSchedule.startLocal.hour,
        minute: lastSchedule.startLocal.minute,
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kTheWeighingGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kTheWeighingTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Three-Decan Arc',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              const Text(
                'Material Ledger (D1-10) -> Spoken Record (D11-20) -> Record You Leave (D21-30).',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'First sitting: ${_dateLabel(context, selectedStart)} at $firstTime. Final sitting: ${_dateLabel(context, lastSchedule.startLocal)} at $lastTime. Midday checks default to 11:00 local.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(_startDateButtonLabel(context, selectedStart)),
                ),
              ),
              const SizedBox(height: 12),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the nine sittings, timing, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TheWeighingLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _theWeighingLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _theWeighingLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _theWeighingLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _theWeighingLensExplanation(_theWeighingLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '9 Sittings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kTheWeighingEvents.map(
                (event) => _buildTheWeighingEventTile(context, event),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _theWeighingJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _theWeighingJoinInFlight
                  ? null
                  : () => _joinTheWeighingFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTheTendingEventTile(
    BuildContext context,
    TheTendingEvent event,
  ) {
    final detail = theTendingDetailText(event, lens: _theTendingLens);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            theTendingEventTitle(event),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${event.decanSection} · ${theTendingTimingLabel(event)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTheTendingScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultTheTendingStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kTheTendingEvents.first;
    final lastEvent = kTheTendingEvents.last;
    final firstSchedule = theTendingScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final lastSchedule = theTendingScheduleForDate(
      lastEvent,
      selectedStart.add(Duration(days: lastEvent.flowDay - 1)),
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final lastTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: lastSchedule.startLocal.hour,
        minute: lastSchedule.startLocal.minute,
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kTheTendingGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kTheTendingTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              const Text(
                kTheTendingEnrollmentCopy,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7A6B9E)),
                ),
                child: const Text(
                  'Privacy: care names and tending notes stay on this device. Synced calendar events contain only generic prompts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Three-Decan Arc',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              const Text(
                'Find and See (D1-10) -> Gather and Attend (D11-20) -> Stand and Restore (D21-30).',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'First sitting: ${_dateLabel(context, selectedStart)} at $firstTime. Final sitting: ${_dateLabel(context, lastSchedule.startLocal)} at $lastTime. Midday checks default to 11:00 local.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(_startDateButtonLabel(context, selectedStart)),
                ),
              ),
              const SizedBox(height: 12),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the nine sittings, timing, privacy boundary, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TheTendingLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _theTendingLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _theTendingLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _theTendingLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _theTendingLensExplanation(_theTendingLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '9 Sittings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kTheTendingEvents.map(
                (event) => _buildTheTendingEventTile(context, event),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _theTendingJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _theTendingJoinInFlight
                  ? null
                  : () => _joinTheTendingFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeptWordEventTile(BuildContext context, KeptWordEvent event) {
    final detail = keptWordDetailText(event, lens: _keptWordLens);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.requiresConversation
              ? const Color(0xFF8B7355)
              : Colors.white12,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            keptWordEventTitle(event),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${event.decanSection} · ${keptWordTimingLabel(event)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeptWordScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultKeptWordStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kKeptWordEvents.first;
    final lastEvent = kKeptWordEvents.last;
    final firstSchedule = keptWordScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final lastSchedule = keptWordScheduleForDate(
      lastEvent,
      selectedStart.add(Duration(days: lastEvent.flowDay - 1)),
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final lastTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: lastSchedule.startLocal.hour,
        minute: lastSchedule.startLocal.minute,
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kKeptWordGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kKeptWordTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              const Text(
                kKeptWordEnrollmentCopy,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B7355)),
                ),
                child: const Text(
                  'Privacy: agreement inventories, names, and conversation notes stay on this device. Synced calendar events contain only generic prompts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14100B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFD486).withValues(alpha: 0.38),
                  ),
                ),
                child: const Text(
                  'Bring to Process: Events 4-6 involve another person. If the conversation cannot be had safely, pause the flow locally rather than forcing contact.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Three-Decan Arc',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              const Text(
                'Name the State (D1-10) -> Bring to Process (D11-20) -> Confirm the Order (D21-30).',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'First sitting: ${_dateLabel(context, selectedStart)} at $firstTime. Final sitting: ${_dateLabel(context, lastSchedule.startLocal)} at $lastTime. Midday checks default to 11:00 local.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(_startDateButtonLabel(context, selectedStart)),
                ),
              ),
              const SizedBox(height: 12),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the nine sittings, timing, privacy boundary, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: KeptWordLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _keptWordLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _keptWordLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _keptWordLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _keptWordLensExplanation(_keptWordLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '9 Sittings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kKeptWordEvents.map(
                (event) => _buildKeptWordEventTile(context, event),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _keptWordJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _keptWordJoinInFlight
                  ? null
                  : () => _joinKeptWordFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseEventTile(
    BuildContext context,
    CourseEvent event,
    DateTime selectedStart,
  ) {
    final eventDate = selectedStart.add(Duration(days: event.flowDay - 1));
    final courseContext = courseContextForGregorianDate(eventDate);
    final detail = courseDetailText(
      event,
      lens: _courseLens,
      context: courseContext,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.scheduleKind == CourseScheduleKind.solarDusk
              ? const Color(0xFFE8B84A)
              : event.seasonAware
              ? const Color(0xFF6FC2A1)
              : Colors.white12,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            courseEventTitle(event),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${event.decanSection} · ${courseTimingLabel(event)} · ${courseContext.seasonLabel}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  MoonReturnEnrollmentWindow? _resolveMoonReturnPreviewWindow() {
    return _tryEnrollmentWindow('moonReturn', () {
      final picked = _picked;
      if (picked != null) {
        final selected = moonReturnEnrollmentWindowForStartDate(
          picked,
          _previewTrackSkyTimeZone,
        );
        if (selected != null) return selected;
      }
      return moonReturnNextEnrollmentWindow(_previewTrackSkyTimeZone);
    });
  }

  Widget _buildMoonReturnOccurrenceTile(
    BuildContext context,
    MoonReturnOccurrence occurrence,
  ) {
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: occurrence.startLocal.hour,
        minute: occurrence.startLocal.minute,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: occurrence.variant == MoonReturnCopyVariant.standard
              ? Colors.white12
              : const Color(0xFF8FA8FF),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          moonReturnEventTitle(occurrence),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_dateLabel(context, occurrence.startLocal)} at $time • ${occurrence.variant.label}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ),
    );
  }

  WagEnrollmentWindow? _resolveWagPreviewWindow() {
    return _tryEnrollmentWindow('theWag', () {
      final picked = _picked;
      if (picked != null) {
        final selected = wagEnrollmentWindowForStartDate(
          picked,
          _previewTrackSkyTimeZone,
        );
        if (selected != null) return selected;
      }
      return wagNextEnrollmentWindow(_previewTrackSkyTimeZone);
    });
  }

  Widget _buildWagEventTile(BuildContext context, WagEvent event, int kYear) {
    final schedule = wagScheduleForEvent(
      event: event,
      kYear: kYear,
      timezone: _previewTrackSkyTimeZone,
    );
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: schedule.startLocal.hour,
        minute: schedule.startLocal.minute,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              event.kind == WagEventKind.vigil ||
                  event.kind == WagEventKind.feast
              ? _gold
              : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          wagEventTitle(event),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${wagTimingLabel(event)} • ${_dateLabel(context, schedule.startLocal)} at $time',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildWagScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final WagEnrollmentWindow? window = _resolveWagPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(context, debugLabel: 'theWag');
    }
    final selectedStart = DateUtils.dateOnly(window.opensAtLocal);
    final nextFeast = wagNextFeastGregorian(window.kYear);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 104),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kTheWagGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kTheWagTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold, width: 1.1),
                ),
                child: Text(
                  'Selected Wep Ronpet start for ${window.opensAtLocal.year}: ${_dateLabel(context, window.opensAtLocal)}. Add it now and the Month 1 events will prompt when the year opens.',
                  style: const TextStyle(
                    color: Color(0xFFFFD486),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kTheWagConfidenceLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Privacy',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'Ancestor names are sacred data. Write them on paper; optional in-app notes stay on this device and are never synced in event detail.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(
                    'Window opens: ${_dateLabel(context, window.opensAtLocal)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Wag feast this cycle: ${_dateLabel(context, wagEventGregorian(window.kYear, 18))}. Next year: ${_dateLabel(context, nextFeast)}.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the annual dates, privacy rules, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WagLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _wagLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _wagLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _wagLens == lens ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _wagLensExplanation(_wagLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Month 1 Events',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kWagEvents.map(
                (event) => _buildWagEventTile(context, event, window.kYear),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _wagJoinInFlight ? 'Joining…' : 'Add Flow',
              onPressed: _wagJoinInFlight
                  ? null
                  : () => _joinWagFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  DecanWatchEnrollmentWindow? _resolveDecanWatchPreviewWindow() {
    return _tryEnrollmentWindow('decanWatch', () {
      final picked = _picked;
      if (picked != null) {
        final selected = decanWatchEnrollmentWindowForStartDate(
          picked,
          _previewTrackSkyTimeZone,
        );
        if (selected != null) return selected;
      }
      return decanWatchNextEnrollmentWindow(_previewTrackSkyTimeZone);
    });
  }

  Widget _buildDecanWatchOccurrenceTile(
    BuildContext context,
    DecanWatchOccurrence occurrence,
  ) {
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: occurrence.startLocal.hour,
        minute: occurrence.startLocal.minute,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          decanWatchEventTitle(occurrence),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'M${occurrence.kMonth} D${occurrence.decanStartDay} · ${_dateLabel(context, occurrence.startLocal)} at $time',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDecanWatchScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final DecanWatchEnrollmentWindow? window =
        _resolveDecanWatchPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: 'decanWatch',
      );
    }
    final selectedStart = DateUtils.dateOnly(window.opensAtLocal);
    final preview = <DecanWatchOccurrence>[
      window.openingOccurrence,
      ...upcomingDecanWatchOccurrences(
        timezone: _previewTrackSkyTimeZone,
        fromLocal: window.openingOccurrence.startLocal.add(
          const Duration(days: 1),
        ),
        count: 2,
      ),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 104),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kDecanWatchGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kDecanWatchTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold, width: 1.1),
                ),
                child: Text(
                  'Selected decan opening: ${_dateLabel(context, window.opensAtLocal)}, when ${window.openingOccurrence.decanName} begins. Add it now and the first watch will prompt on that opening.',
                  style: const TextStyle(
                    color: Color(0xFFFFD486),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kDecanWatchConfidenceLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Practice',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'Outdoor is the default. If weather, safety, access, or mobility prevents that, use the inside/threshold completion state and keep the record honest. Sky note and intention stay on this device.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'The Course orients you by day. The Decan Watch orients you by night. Many keep both.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Default watch time is 9:00 PM local. Editing is clamped to 6:00 PM-midnight.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(
                    'Window opens: ${_dateLabel(context, window.opensAtLocal)}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the decan boundary, outdoor requirement, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DecanWatchLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _decanWatchLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _decanWatchLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _decanWatchLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _decanWatchLensExplanation(_decanWatchLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Next Watches',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...preview.map(
                (occurrence) =>
                    _buildDecanWatchOccurrenceTile(context, occurrence),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _decanWatchJoinInFlight ? 'Joining…' : 'Add Flow',
              onPressed: _decanWatchJoinInFlight
                  ? null
                  : () => _joinDecanWatchFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  OpenHandEnrollmentWindow? _resolveOpenHandPreviewWindow() {
    return _tryEnrollmentWindow('openHand', () {
      final picked = _picked;
      if (picked != null) {
        final selected = openHandEnrollmentWindowForStartDate(
          picked,
          _previewTrackSkyTimeZone,
        );
        if (selected != null) return selected;
      }
      return openHandNextEnrollmentWindow(_previewTrackSkyTimeZone);
    });
  }

  Widget _buildOpenHandEventTile(
    BuildContext context,
    OpenHandEvent event,
    DateTime flowStart,
  ) {
    final schedule = openHandScheduleForEvent(
      event,
      flowStart,
      _previewTrackSkyTimeZone,
    );
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: schedule.startLocal.hour,
        minute: schedule.startLocal.minute,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.requiresOutwardAct ? _gold : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          openHandEventTitle(event),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${openHandTimingLabel(event)} · ${_dateLabel(context, schedule.startLocal)} at $time${event.requiresOutwardAct ? ' · act first' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenHandScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final OpenHandEnrollmentWindow? window = _resolveOpenHandPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: 'openHand',
      );
    }
    final flowStart = DateUtils.dateOnly(window.opensAtLocal);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 104),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kTheOpenHandGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kTheOpenHandTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold, width: 1.1),
                ),
                child: Text(
                  'Selected decan opening: ${_dateLabel(context, window.opensAtLocal)}, when ${window.openingOccurrence.decanName} begins. Add it now and the nine sittings will prompt from that start date.',
                  style: const TextStyle(
                    color: Color(0xFFFFD486),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kOpenHandConfidenceLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Provision',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'Bread means food. Water means the immediate resource in front of you. Clothing means dignity and protection. Boat means access, transport, introduction, or skill. Time is provision too.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'You have provisioned yourself in The Offering Table. The Open Hand extends provision outward. Names, needs, and giving records stay on this device.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Openings are dawn + 30 minutes; midpoints default to 11:00 local; closes are sunset + 30 minutes.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(
                    'Window opens: ${_dateLabel(context, window.opensAtLocal)}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OpenHandLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _openHandLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _openHandLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _openHandLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _openHandLens.detailLine.isEmpty
                    ? 'Neutral keeps the practice centered on provision and record.'
                    : _openHandLens.detailLine,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Nine Sittings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kOpenHandEvents.map(
                (event) => _buildOpenHandEventTile(context, event, flowStart),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _openHandJoinInFlight ? 'Joining…' : 'Add Flow',
              onPressed: _openHandJoinInFlight
                  ? null
                  : () => _joinOpenHandFlow(flowStart),
            ),
          ),
        ],
      ),
    );
  }

  DjedEnrollmentWindow? _resolveDjedPreviewWindow() {
    return _tryEnrollmentWindow('djed', () {
      final picked = _picked;
      if (picked != null) {
        final selected = djedEnrollmentWindowForStartDate(
          picked,
          _previewTrackSkyTimeZone,
        );
        if (selected != null) return selected;
      }
      return djedNextEnrollmentWindow(_previewTrackSkyTimeZone);
    });
  }

  Widget _buildDjedEventTile(
    BuildContext context,
    DjedEvent event,
    DateTime flowStart,
  ) {
    final schedule = djedScheduleForEvent(
      event,
      flowStart,
      _previewTrackSkyTimeZone,
    );
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: schedule.startLocal.hour,
        minute: schedule.startLocal.minute,
      ),
    );
    final highlight = event.physicalRaising || event.requiresDirectEngagement;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.physicalRaising
              ? const Color(0xFF9BD0A5)
              : highlight
              ? _gold
              : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          djedEventTitle(event),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${djedTimingLabel(event)} · ${_dateLabel(context, schedule.startLocal)} at $time'
            '${event.requiresDirectEngagement ? ' · direct engagement' : ''}'
            '${event.physicalRaising ? ' · stand + raise' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDjedScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final DjedEnrollmentWindow? window = _resolveDjedPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(context, debugLabel: 'djed');
    }
    final flowStart = DateUtils.dateOnly(window.opensAtLocal);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 104),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kTheDjedGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kTheDjedTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold, width: 1.1),
                ),
                child: Text(
                  'Selected decan opening: ${_dateLabel(context, window.opensAtLocal)}, when ${window.openingOccurrence.decanName} begins. Add it now and the Djed sittings will prompt from that start date.',
                  style: const TextStyle(
                    color: Color(0xFFFFD486),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kDjedConfidenceLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Practice Shape',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'Name the spine, engage the structural threat directly, then raise the Djed. The mock battle means a concrete stabilizing act, not harmful confrontation.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF9BD0A5).withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'Event 9 requires standing room for about 30 seconds. Spine labels, wobble notes, and battle commitments stay on this device.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Openings are dawn + 30 minutes; midpoints default to 11:00 local; the second decan closes at sunset + 30 minutes. Event 3 and Event 9 are dawn events by specification.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(
                    'Window opens: ${_dateLabel(context, window.opensAtLocal)}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DjedLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _djedLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _djedLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _djedLens == lens ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _djedLens.detailLine.isEmpty
                    ? 'Neutral keeps the work centered on stability, contest, and raising.'
                    : _djedLens.detailLine,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Nine Sittings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kDjedEvents.map(
                (event) => _buildDjedEventTile(context, event, flowStart),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _djedJoinInFlight ? 'Joining…' : 'Add Flow',
              onPressed: _djedJoinInFlight
                  ? null
                  : () => _joinDjedFlow(flowStart),
            ),
          ),
        ],
      ),
    );
  }

  DaysOutsideYearEnrollmentWindow? _resolveDaysOutsideYearPreviewWindow() {
    return _tryEnrollmentWindow('daysOutsideYear', () {
      final picked = _picked;
      if (picked != null) {
        final selected = daysOutsideYearEnrollmentWindowForStartDate(
          picked,
          _previewTrackSkyTimeZone,
        );
        if (selected != null) return selected;
      }
      return daysOutsideYearNextEnrollmentWindow(_previewTrackSkyTimeZone);
    });
  }

  Widget _buildDaysOutsideYearEventTile(
    BuildContext context,
    DaysOutsideEvent event,
    int closingKYear,
  ) {
    final schedule = daysOutsideScheduleForEvent(
      event: event,
      closingKYear: closingKYear,
      timezone: _previewTrackSkyTimeZone,
    );
    final l10n = MaterialLocalizations.of(context);
    final time = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: schedule.startLocal.hour,
        minute: schedule.startLocal.minute,
      ),
    );
    final border = event.kind == DaysOutsideEventKind.wepRonpetOpening
        ? _gold
        : event.kMonth == 13
        ? const Color(0xFFB8A8FF)
        : Colors.white12;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          daysOutsideEventTitle(event),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'M${event.kMonth} D${event.kDay} · ${event.schedule.label} · ${_dateLabel(context, schedule.startLocal)} at $time',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDaysOutsideYearScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 320.0);
    final ctaBottom = media.padding.bottom + 12;
    final DaysOutsideYearEnrollmentWindow? window =
        _resolveDaysOutsideYearPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: 'daysOutsideYear',
      );
    }
    final selectedStart = DateUtils.dateOnly(window.opensAtLocal);
    final yearClose = daysOutsideEventGregorian(
      closingKYear: window.closingKYear,
      kMonth: 12,
      kDay: 30,
    );
    final epi1 = daysOutsideEventGregorian(
      closingKYear: window.closingKYear,
      kMonth: 13,
      kDay: 1,
    );
    final wep = daysOutsideFlowEndGregorian(window.closingKYear);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 104),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kDaysOutsideTheYearGlyph,
                    style: TextStyle(fontSize: 26, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(
                          title: widget.template.title,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          kDaysOutsideTheYearTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold, width: 1.1),
                ),
                child: Text(
                  'Selected year-closing start for ${window.opensAtLocal.year}: ${_dateLabel(context, window.opensAtLocal)}. Add it now and the threshold events will prompt when the year closes.',
                  style: const TextStyle(
                    color: Color(0xFFFFD486),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                kDaysOutsideTheYearConfidenceLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Calendar Anchor',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              Text(
                'Enrollment opens on M12 D28. Event 0 is M12 D30 at dusk, the five births are M13 D1-D5 at dawn, and Wep Ronpet is M1 D1 of the next Kemetic year. Leap-year M13 D6 has no event.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Year close: ${_dateLabel(context, yearClose)} · First outside day: ${_dateLabel(context, epi1)} · Wep Ronpet: ${_dateLabel(context, wep)}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Privacy',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'Year-close names, received qualities, and the year intention stay on this device. Event detail syncs generic steps only.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'The Days Outside the Year opens the year; The Wag tends the ancestors through Month 1. Many keep both.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(
                    'Window opens: ${_dateLabel(context, window.opensAtLocal)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This is a window-only picker. Arbitrary Kemetic dates are rejected on join.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Seven Events',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kDaysOutsideEvents.map(
                (event) => _buildDaysOutsideYearEventTile(
                  context,
                  event,
                  window.closingKYear,
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _daysOutsideYearJoinInFlight ? 'Joining…' : 'Add Flow',
              onPressed: _daysOutsideYearJoinInFlight
                  ? null
                  : () => _joinDaysOutsideYearFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonReturnScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final MoonReturnEnrollmentWindow? window =
        _resolveMoonReturnPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: 'moonReturn',
      );
    }
    final selectedStart = DateUtils.dateOnly(window.opensAtLocal);
    final occurrences = moonReturnOccurrencesForWindow(window: window);
    final preview = occurrences.take(4).toList(growable: false);
    final emptyEyeCandidates = occurrences
        .where((occurrence) => occurrence.kind == MoonReturnEventKind.emptyEye)
        .toList(growable: false);
    final emptyEye = emptyEyeCandidates.isEmpty
        ? null
        : emptyEyeCandidates.first;
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 104),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kMoonReturnGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kMoonReturnTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold, width: 1.1),
                ),
                child: Text(
                  'Selected new-moon start: ${_dateLabel(context, window.opensAtLocal)}. Add it now and the first Empty Eye will prompt at the appointed dusk.',
                  style: const TextStyle(
                    color: Color(0xFFFFD486),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (window.enrollProminence !=
                  MoonReturnCopyVariant.standard) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111625),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8FA8FF)),
                  ),
                  child: Text(
                    window.enrollProminence ==
                            MoonReturnCopyVariant.wepRonpetNew
                        ? 'Highest threshold: total solar eclipse with Wep Ronpet year-opening copy.'
                        : 'Elevated threshold: solar eclipse new moon enrollment.',
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                kMoonReturnConfidenceLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(
                    'Window opens: ${_dateLabel(context, window.opensAtLocal)}',
                  ),
                ),
              ),
              if (emptyEye != null) ...[
                const SizedBox(height: 8),
                Text(
                  'First Empty Eye: ${_dateLabel(context, emptyEye.startLocal)} at ${timeLabel(emptyEye.startLocal)}. Future events sync for about twelve months.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the lunar timing or observed/skipped completion.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MoonReturnLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _moonReturnLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _moonReturnLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _moonReturnLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _moonReturnLensExplanation(_moonReturnLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Upcoming Events',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...preview.map(
                (occurrence) =>
                    _buildMoonReturnOccurrenceTile(context, occurrence),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _moonReturnJoinInFlight ? 'Joining…' : 'Add Flow',
              onPressed: _moonReturnJoinInFlight
                  ? null
                  : () => _joinMoonReturnFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultTheCourseStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kTheCourseEvents.first;
    final duskEvent = kTheCourseEvents[1];
    final lastEvent = kTheCourseEvents.last;
    final firstSchedule = courseScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final duskSchedule = courseScheduleForDate(
      duskEvent,
      selectedStart.add(Duration(days: duskEvent.flowDay - 1)),
      _previewTrackSkyTimeZone,
    );
    final lastSchedule = courseScheduleForDate(
      lastEvent,
      selectedStart.add(Duration(days: lastEvent.flowDay - 1)),
      _previewTrackSkyTimeZone,
    );
    String timeLabel(DateTime value) {
      return l10n.formatTimeOfDay(
        TimeOfDay(hour: value.hour, minute: value.minute),
      );
    }

    final currentContext = courseContextForGregorianDate(DateTime.now());

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kTheCourseGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kTheCourseTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              const Text(
                kTheCourseEnrollmentCopy,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14100B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE8B84A).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'You are in ${currentContext.decanName}, ${currentContext.kemeticDateLabel} of ${currentContext.seasonLabel}. The flow continues from here.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Three-Decan Arc',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              const Text(
                'Daily Course (D1-10) -> Decan Course (D11-20) -> Seasonal Course (D21-30).',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'First sitting: ${_dateLabel(context, selectedStart)} at ${timeLabel(firstSchedule.startLocal)}. Event 2 is dusk on ${_dateLabel(context, duskSchedule.startLocal)} at ${timeLabel(duskSchedule.startLocal)}. Final sitting: ${_dateLabel(context, lastSchedule.startLocal)} at ${timeLabel(lastSchedule.startLocal)}. Midday sittings default to 11:00 local.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(_startDateButtonLabel(context, selectedStart)),
                ),
              ),
              const SizedBox(height: 12),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change day-card use, timing, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourseLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _courseLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _courseLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _courseLens == lens ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _courseLensExplanation(_courseLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '9 Sittings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              ...kTheCourseEvents.map(
                (event) => _buildCourseEventTile(context, event, selectedStart),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _courseJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _courseJoinInFlight
                  ? null
                  : () => _joinTheCourseFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingTableDayTile(
    BuildContext context,
    OfferingTableDay day,
  ) {
    final detail = offeringTableDetailText(
      day,
      lens: _offeringTableLens,
      noCupMode: _offeringNoCupMode,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          collapsedIconColor: _silver,
          iconColor: _gold,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            offeringTableEventTitle(day),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${day.section} · ${offeringTableTimingLabel(day)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          children: [
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferingTableScaffold(BuildContext context) {
    final media = MediaQuery.of(context);
    final buttonWidth = math.min(media.size.width - 32, 280.0);
    final ctaBottom = media.padding.bottom + 12;
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultOfferingTableStartDate(_previewTrackSkyTimeZone);
    final firstDay = kOfferingTableDays.first;
    final lastDay = kOfferingTableDays.last;
    final firstSchedule = offeringTableScheduleForDate(
      firstDay,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final lastSchedule = offeringTableScheduleForDate(
      lastDay,
      selectedStart.add(Duration(days: lastDay.dayNumber - 1)),
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final lastTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: lastSchedule.startLocal.hour,
        minute: lastSchedule.startLocal.minute,
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    kOfferingTableGlyph,
                    style: TextStyle(fontSize: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateModeTitle(title: widget.template.title),
                        const SizedBox(height: 2),
                        const Text(
                          kOfferingTableTagline,
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.template.overview,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 12),
              const Text(
                kOfferingTableEnrollmentCopy,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Three-Decan Arc',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              const Text(
                'Personal Table (D1-10) -> Household Table (D11-20) -> Flowing Table (D21-30).',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: 'Timezone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrackSkyTimeZone.values.map((timezone) {
                  return ChoiceChip(
                    label: Text(timezone.shortLabel),
                    selected: _previewTrackSkyTimeZone == timezone,
                    onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _previewTrackSkyTimeZone == timezone
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'First sitting: ${_dateLabel(context, selectedStart)} at $firstTime. Final sitting: ${_dateLabel(context, lastSchedule.startLocal)} at $lastTime. Daily sitting defaults to 7:30 local and clamps to dawn if needed.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: silver, width: 1.25),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: _pickDate,
                  child: Text(_startDateButtonLabel(context, selectedStart)),
                ),
              ),
              const SizedBox(height: 12),
              const GlossyText(
                text: 'Lens',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 6),
              const Text(
                'A lens adds one short framing line. It does not change the thirty sittings, timing, or completion states.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OfferingTableLens.values.map((lens) {
                  return ChoiceChip(
                    label: Text(lens.label),
                    selected: _offeringTableLens == lens,
                    onSelected: (_) {
                      setState(() {
                        _offeringTableLens = lens;
                      });
                    },
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: _offeringTableLens == lens
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF15171B),
                    side: const BorderSide(color: Colors.white24),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _offeringTableLensExplanation(_offeringTableLens),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0C0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SwitchListTile.adaptive(
                  value: _offeringNoCupMode,
                  activeThumbColor: _gold,
                  title: const Text(
                    'Use the cup you’re already holding',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Commute alternative; the water step remains part of the sitting.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _offeringNoCupMode = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              const GlossyText(
                text: '30-Day Table',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                gradient: silverGloss,
              ),
              const SizedBox(height: 8),
              for (final section in const <String>[
                'Personal Table',
                'Household Table',
                'Flowing Table',
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    section,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...kOfferingTableDays
                    .where((day) => day.section == section)
                    .map((day) => _buildOfferingTableDayTile(context, day)),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ctaBottom,
            child: _buildTemplateStickyJoinButton(
              buttonWidth: buttonWidth,
              text: _offeringJoinInFlight ? 'Joining…' : 'Join Flow',
              onPressed: _offeringJoinInFlight
                  ? null
                  : () => _joinOfferingTableFlow(selectedStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSequenceScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: _buildDateModeTitle(title: widget.template.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildDateModeTitle(title: widget.template.title),
          const SizedBox(height: 8),
          Text(
            widget.template.overview,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 16),
          const GlossyText(
            text: '10-Day Outline',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            gradient: silverGloss,
          ),
          const SizedBox(height: 8),
          ...List.generate(widget.template.days.length, (i) {
            final d = widget.template.days[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...d.notes.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final slot = entry.value;
                    final start = l10n.formatTimeOfDay(slot.start);
                    final end = l10n.formatTimeOfDay(slot.end);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: idx == d.notes.length - 1 ? 0 : 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$start – $end',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slot.title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          if ((slot.detail ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                slot.detail!.trim(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.35,
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
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: silver, width: 1.25),
                alignment: Alignment.centerLeft,
              ),
              onPressed: _pickDate,
              child: Text(
                _picked == null
                    ? 'Pick start date'
                    : (_useKemetic
                          ? 'Start: ${_kemeticLabelFor(_picked!)}'
                          : 'Start: ${_dateLabel(context, _picked!)}'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_picked != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _useKemetic ? 'Mode: Kemetic' : 'Mode: Gregorian',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _picked == null
                ? null
                : () async {
                    final id = await widget.addInstance(
                      template: widget.template,
                      startDate: _picked!,
                      useKemetic: _useKemetic,
                    );
                    if (id > 0 && context.mounted) {
                      Navigator.of(context).pop(id);
                    }
                  },
            child: const Text('Add Flow'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.template.kind == _MaatFlowTemplateKind.trackSky) {
      return _buildTrackSkyScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.dawnHouseRite) {
      return _buildDawnHouseRiteScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.eveningThresholdRite) {
      return _buildEveningThresholdRiteScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theWeighing) {
      return _buildTheWeighingScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.offeringTable) {
      return _buildOfferingTableScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theTending) {
      return _buildTheTendingScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.keptWord) {
      return _buildKeptWordScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theCourse) {
      return _buildCourseScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.moonReturn) {
      return _buildMoonReturnScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theWag) {
      return _buildWagScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.decanWatch) {
      return _buildDecanWatchScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.daysOutsideTheYear) {
      return _buildDaysOutsideYearScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theOpenHand) {
      return _buildOpenHandScaffold(context);
    }
    if (widget.template.kind == _MaatFlowTemplateKind.theDjed) {
      return _buildDjedScaffold(context);
    }
    return _buildSequenceScaffold(context);
  }
}

/* ───────────────────────── Search (notes) ───────────────────────── */
