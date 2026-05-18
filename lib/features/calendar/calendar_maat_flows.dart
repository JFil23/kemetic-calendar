part of 'calendar_page.dart';

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
    }
  }

  String _fmtGregorian(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  bool _useKemetic = false;
  DateTime? _picked;

  Future<void> _pickDate() async {
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
                  CupertinoSegmentedControl<bool>(
                    groupValue: localKemetic,
                    padding: const EdgeInsets.all(2),
                    children: const {
                      true: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text('Kemetic'),
                      ),
                      false: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text('Gregorian'),
                      ),
                    },
                    onValueChanged: (v) {
                      setSheetState(() {
                        if (v) {
                          final gNow = DateTime(gy, gm, gd);
                          final k = KemeticMath.fromGregorian(gNow);
                          ky = k.kYear;
                          km = k.kMonth;
                          kd = k.kDay;
                          final kMax = kemDayMax(ky, km);
                          if (kd > kMax) kd = kMax;
                          localKemetic = true;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            kYearCtrl.jumpToItem(
                              (ky - kYearStart).clamp(0, 400),
                            );
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
                            gYearCtrl.jumpToItem(
                              (gy - gYearStart).clamp(0, 39),
                            );
                            gMonthCtrl.jumpToItem((gm - 1).clamp(0, 11));
                            gDayCtrl.jumpToItem((gd - 1).clamp(0, 30));
                          });
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  GlossyText(
                    text: localKemetic
                        ? 'Start date (Kemetic)'
                        : 'Start date (Gregorian)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    gradient: localKemetic ? goldGloss : blueGloss,
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
                            : '${MaterialLocalizations.of(context).formatShortDate(DateTime.parse(upcoming.first.schedule.dateIso))} → ${MaterialLocalizations.of(context).formatShortDate(DateTime.parse(upcoming.last.schedule.dateIso))}';

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
                                        final id = await widget.addInstance(
                                          template: widget.template,
                                          trackSkyTimeZone: selectedTimeZone,
                                          alertMinutesBefore:
                                              selectedAlertMinutes!,
                                        );
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
              event.exactLabel,
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
        title: GlossyText(
          text: widget.template.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          gradient: goldGloss,
        ),
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
              final l10n = MaterialLocalizations.of(context);
              final firstDate = upcoming.isEmpty
                  ? null
                  : l10n.formatShortDate(
                      DateTime.parse(upcoming.first.schedule.dateIso),
                    );
              final lastDate = upcoming.isEmpty
                  ? null
                  : l10n.formatShortDate(
                      DateTime.parse(upcoming.last.schedule.dateIso),
                    );

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
                children: [
                  GlossyText(
                    text: widget.template.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    gradient: goldGloss,
                  ),
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
        title: GlossyText(
          text: widget.template.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          gradient: goldGloss,
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              GlossyText(
                text: widget.template.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                gradient: goldGloss,
              ),
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
                'Estimated from ${firstSchedule.referenceLocation.name} for ${_previewTrackSkyTimeZone.label}. First dawn: ${l10n.formatShortDate(selectedStart)} at $firstTime. Final dawn: ${l10n.formatShortDate(lastSchedule.startLocal)} at $lastTime.',
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
                  child: Text('Start: ${_fmtGregorian(selectedStart)}'),
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
        title: GlossyText(
          text: widget.template.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          gradient: goldGloss,
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, ctaBottom + 96),
            children: [
              GlossyText(
                text: widget.template.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                gradient: goldGloss,
              ),
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
                'Estimated from ${firstSchedule.referenceLocation.name} for ${_previewTrackSkyTimeZone.label}. First evening: ${l10n.formatShortDate(selectedStart)} at $firstTime. Final evening: ${l10n.formatShortDate(lastSchedule.startLocal)} at $lastTime.',
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
                      child: Text('Start: ${_fmtGregorian(selectedStart)}'),
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

  Widget _buildSequenceScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: Text(
          widget.template.title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          GlossyText(
            text: widget.template.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            gradient: goldGloss,
          ),
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
                          : 'Start: ${_fmtGregorian(_picked!)}'),
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
    return _buildSequenceScaffold(context);
  }
}

/* ───────────────────────── Search (notes) ───────────────────────── */
