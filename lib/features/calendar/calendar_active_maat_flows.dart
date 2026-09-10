part of 'calendar_page.dart';

@visibleForTesting
const Key kMaatFlowInitialPromptSectionKey = ValueKey<String>(
  'maat_flow_initial_prompt_section',
);

@visibleForTesting
const Key kMaatFlowPracticeDisclaimerFooterKey = ValueKey<String>(
  'maat_flow_practice_disclaimer_footer',
);

@visibleForTesting
const Key kMaatFlowDetailSurfaceHostKey = ValueKey<String>(
  'maat-flow-detail-surface-host',
);

// Kept as negative-contract keys so tests can prove the retired catalog tabs
// never return to the active discovery surface.
@visibleForTesting
const Key kMaatFlowCategoryDailyRhythmTabKey = ValueKey<String>(
  'maat_flow_category_daily_rhythm_tab',
);

@visibleForTesting
const Key kMaatFlowCategoryInnerWorkTabKey = ValueKey<String>(
  'maat_flow_category_inner_work_tab',
);

@visibleForTesting
const Key kMaatFlowCategoryLivingInMaatTabKey = ValueKey<String>(
  'maat_flow_category_living_in_maat_tab',
);

@visibleForTesting
Key maatFlowCatalogCardKeyForTesting(String flowKey) =>
    ValueKey<String>('maat-flow-discovery-card-$flowKey');

@visibleForTesting
List<String> knownMaatFlowTemplateKeysForTesting() => List<String>.unmodifiable(
  _kMaatFlowTemplates.map((template) => template.key),
);

@visibleForTesting
List<String> coreMaatFlowTemplateKeysForTesting() => List<String>.unmodifiable(
  _kCoreMaatFlowTemplates.map((template) => template.key),
);

@visibleForTesting
Map<String, String> coreMaatFlowTemplateTitlesForTesting() =>
    Map<String, String>.unmodifiable(<String, String>{
      for (final template in _kCoreMaatFlowTemplates)
        template.key: template.title,
    });

class _MaatExpandableEventDetail extends StatefulWidget {
  const _MaatExpandableEventDetail({
    required this.expanded,
    required this.collapseInstantly,
    required this.child,
    super.key,
  });

  final bool expanded;
  final bool collapseInstantly;
  final Widget child;

  @override
  State<_MaatExpandableEventDetail> createState() =>
      _MaatExpandableEventDetailState();
}

class _MaatExpandableEventDetailState
    extends State<_MaatExpandableEventDetail> {
  int _animationGeneration = 0;

  @override
  void didUpdateWidget(covariant _MaatExpandableEventDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded && !widget.expanded && widget.collapseInstantly) {
      _animationGeneration += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      key: ValueKey<int>(_animationGeneration),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: widget.expanded ? widget.child : const SizedBox.shrink(),
    );
  }
}

class MaatFlowGlyph extends StatelessWidget {
  const MaatFlowGlyph({required this.glyph, this.size = 34, super.key});

  final String glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    assert(glyph.trim().isNotEmpty, 'Ma’at Flow glyph cannot be empty');
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Text(
          glyph,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            height: 1,
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: meduNeterFontFallback,
          ),
        ),
      ),
    );
  }
}

class _MaatFlowIconPainter extends CustomPainter {
  const _MaatFlowIconPainter({
    required this.kind,
    required this.glyph,
    required this.joined,
    required this.completionProgress,
    required this.listAccent,
    required this.detailPalette,
    this.paintBackground = true,
  });

  final _MaatFlowTemplateKind kind;
  final String glyph;
  final bool joined;
  final double? completionProgress;
  final Color? listAccent;
  final MaatFlowPalette? detailPalette;
  final bool paintBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final usesListSurface = listAccent != null;
    final radius = math.min(
      usesListSurface && joined
          ? MaatFlowListTokens.progressRingRadius
          : math.min(MaatFlowListTokens.iconSize, size.width) / 2 - 2,
      math.min(size.width, size.height) / 2 - 2,
    );
    final gold = joined
        ? MaatFlowListTokens.joinedIconStroke
        : MaatFlowListTokens.unjoinedIconStroke;
    final accent = detailPalette?.accent ?? listAccent;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final fill = Paint()..style = PaintingStyle.fill;
    final gradientStops = detailPalette?.iconGradientStops;
    if (gradientStops != null) {
      fill.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientStops,
      ).createShader(bounds);
    } else if (accent != null) {
      fill.shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 1,
        colors: <Color>[
          accent.withValues(alpha: joined ? 0.30 : 0.14),
          detailPalette == null && !joined
              ? const Color(0xFF141008)
              : MaatFlowPalette.warmDark,
        ],
        stops: <double>[0, joined ? 0.65 : 0.70],
      ).createShader(bounds);
    } else {
      fill.color = joined
          ? MaatFlowListTokens.joinedIconBg
          : MaatFlowListTokens.unjoinedIconBg;
    }
    final stroke = Paint()
      ..color = accent != null
          ? accent.withValues(
              alpha: detailPalette == null && !joined ? 0.22 : 0.50,
            )
          : gold
      ..strokeWidth = accent != null
          ? MaatFlowListTokens.cardBorderWidth
          : joined
          ? MaatFlowListTokens.joinedIconStrokeWidth
          : MaatFlowListTokens.unjoinedIconStrokeWidth
      ..style = PaintingStyle.stroke;
    if (paintBackground) {
      canvas.drawCircle(center, radius, fill);
      if (accent != null && (joined || detailPalette != null)) {
        final crown = Paint()
          ..style = PaintingStyle.fill
          ..shader = const RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1,
            colors: <Color>[Color(0x33FFF8E6), Colors.transparent],
            stops: <double>[0, 0.70],
          ).createShader(bounds);
        canvas.drawCircle(center, radius, crown);
      }
      canvas.drawCircle(center, radius, stroke);
    }
    final progress = completionProgress;
    if (paintBackground && joined && progress != null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color =
              accent?.withValues(alpha: 0.20) ??
              MaatFlowListTokens.progressTrack
          ..strokeWidth = MaatFlowListTokens.progressRingStrokeWidth
          ..style = PaintingStyle.stroke,
      );
      canvas.drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0, 1),
        false,
        Paint()
          ..color =
              accent?.withValues(alpha: 0.90) ??
              MaatFlowListTokens.gold.withValues(
                alpha: 0.65 + (0.20 * progress.clamp(0, 1)),
              )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = MaatFlowListTokens.progressRingStrokeWidth,
      );
    }
    final lineColor = accent != null
        ? accent.withValues(alpha: detailPalette == null && !joined ? 0.75 : 1)
        : gold;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(MaatFlowListTokens.iconGlyphScale);
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: lineColor,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: MaatFlowListTokens.iconInnerSize,
          height: 1,
        ),
      ),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaatFlowIconPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.glyph != glyph ||
        oldDelegate.joined != joined ||
        oldDelegate.completionProgress != completionProgress ||
        oldDelegate.listAccent != listAccent ||
        oldDelegate.detailPalette != detailPalette ||
        oldDelegate.paintBackground != paintBackground;
  }
}

typedef _MaatFlowDetailSurfaceBuilder =
    Widget Function(
      _MaatFlowTemplate template,
      _Flow? activeInstance,
      VoidCallback onBack,
    );

class _MaatFlowsListPageWithSnapshot extends StatefulWidget {
  const _MaatFlowsListPageWithSnapshot({
    required this.initialSnapshot,
    required this.loadSnapshot,
    required this.detailBuilder,
    required this.onCreateNew,
    required this.title,
    required this.templates,
    this.initialTemplateKey,
    this.onSelectedTemplateChanged,
    this.onClose,
  });

  final _MyFlowsFilingSnapshot? initialSnapshot;
  final Future<_MyFlowsFilingSnapshot> Function() loadSnapshot;
  final _MaatFlowDetailSurfaceBuilder detailBuilder;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;
  final String? initialTemplateKey;
  final ValueChanged<String?>? onSelectedTemplateChanged;
  final VoidCallback? onClose;

  @override
  State<_MaatFlowsListPageWithSnapshot> createState() =>
      _MaatFlowsListPageWithSnapshotState();
}

class _MaatFlowsListPageWithSnapshotState
    extends State<_MaatFlowsListPageWithSnapshot> {
  _MyFlowsFilingSnapshot? _snapshot;
  int _refreshSerial = 0;
  int _flowLifecycleRevision = 0;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    EndFlowVisibilityStore.instance.addListener(_handleVisibilityChanged);
    unawaited(_refreshSnapshot());
  }

  void _handleVisibilityChanged() {
    if (mounted) setState(() => _flowLifecycleRevision += 1);
  }

  Future<void> _refreshSnapshot() async {
    final serial = ++_refreshSerial;
    try {
      final snapshot = await widget.loadSnapshot();
      if (!mounted || serial != _refreshSerial) return;
      setState(() => _snapshot = snapshot);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        _calendarDebugPrint('[maatFlows] snapshot refresh failed: $error');
        _calendarDebugPrint('$stackTrace');
      }
    }
  }

  @override
  void dispose() {
    EndFlowVisibilityStore.instance.removeListener(_handleVisibilityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot == null
        ? null
        : CalendarPage._applyEndFlowVisibilityOverlay(_snapshot!);
    return _MaatFlowsListPage(
      key: ValueKey<int>(_flowLifecycleRevision),
      title: widget.title,
      templates: widget.templates,
      activeInstanceForKey: (key) => snapshot == null
          ? null
          : CalendarPage._visibleSnapshotActiveMaatInstanceFor(snapshot, key),
      progressForKey: (key) => snapshot == null
          ? null
          : CalendarPage._visibleSnapshotMaatCompletionStatusFor(snapshot, key),
      detailBuilder: widget.detailBuilder,
      onCreateNew: widget.onCreateNew,
      initialTemplateKey: widget.initialTemplateKey,
      onSelectedTemplateChanged: widget.onSelectedTemplateChanged,
      onClose: widget.onClose,
    );
  }
}

class _MaatFlowsListPage extends StatefulWidget {
  const _MaatFlowsListPage({
    super.key,
    required this.activeInstanceForKey,
    this.progressForKey,
    required this.detailBuilder,
    required this.onCreateNew,
    required this.title,
    required this.templates,
    this.initialTemplateKey,
    this.onSelectedTemplateChanged,
    this.onClose,
  });

  final _Flow? Function(String) activeInstanceForKey;
  final _MaatFlowCompletionStatus? Function(String)? progressForKey;
  final _MaatFlowDetailSurfaceBuilder detailBuilder;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;
  final String? initialTemplateKey;
  final ValueChanged<String?>? onSelectedTemplateChanged;
  final VoidCallback? onClose;

  @override
  State<_MaatFlowsListPage> createState() => _MaatFlowsListPageState();
}

class _MaatFlowsListPageState extends State<_MaatFlowsListPage> {
  final GlobalKey _addFlowHelperKey = GlobalKey(
    debugLabel: 'flow_studio_maat_add_flow_helper',
  );
  bool _helperPrompted = false;
  String? _selectedTemplateKey;

  @override
  void initState() {
    super.initState();
    _selectedTemplateKey = _canonicalTemplateKey(widget.initialTemplateKey);
    EndFlowVisibilityStore.instance.addListener(_handleVisibilityChanged);
    unawaited(_maybeShowFlowStudioAddFlowHelper());
  }

  @override
  void didUpdateWidget(covariant _MaatFlowsListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTemplateKey != widget.initialTemplateKey) {
      _selectedTemplateKey = _canonicalTemplateKey(widget.initialTemplateKey);
    }
  }

  String? _canonicalTemplateKey(String? candidate) {
    final key = candidate?.trim();
    if (key == null || key.isEmpty) return null;
    for (final template in widget.templates) {
      if (template.key == key) return key;
    }
    return null;
  }

  _MaatFlowTemplate? get _selectedTemplate {
    final key = _selectedTemplateKey;
    if (key == null) return null;
    for (final template in widget.templates) {
      if (template.key == key) return template;
    }
    return null;
  }

  void _handleVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    EndFlowVisibilityStore.instance.removeListener(_handleVisibilityChanged);
    super.dispose();
  }

  Future<void> _maybeShowFlowStudioAddFlowHelper() async {
    if (_helperPrompted) return;
    final String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return;
    }
    if (userId == null || userId.isEmpty) return;
    final helperUserId = userId;
    const helper = OnboardingHelperRegistry.flowStudioAddFlow;
    final helperService = OnboardingHelperCompletionService.instance;
    if (!await helperService.shouldShowHelper(helperUserId, helper.id)) return;
    _helperPrompted = true;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await helperService.hydrateUser(helperUserId);
    if (!mounted ||
        !helperService.shouldShowHelperSync(helperUserId, helper.id)) {
      return;
    }
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        key: _addFlowHelperKey,
        title: helper.title,
        body: helper.body,
        placement: CoachmarkPlacement.below,
        variant: CoachmarkVariant.helperBubble,
        showDismissButton: true,
        dismissLabel: 'Got it',
        helperId: helper.id,
        helperUserId: helperUserId,
        sourceWidget: OnboardingHelperRegistry.maatFlowListAddFlowSourceWidget,
        onDismiss: () async {
          final completion = helperService.markHelperCompleted(
            helperUserId,
            helper.id,
          );
          GuidedOnboardingController.instance.clear();
          await completion;
        },
      ),
    );
    unawaited(
      Events.trackIfAuthed(helper.analyticsEvent, const <String, dynamic>{}),
    );
  }

  Future<void> _markFlowStudioHelperCompleted(String helperId) async {
    final String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return;
    }
    if (userId == null || userId.isEmpty) return;
    final completion = OnboardingHelperCompletionService.instance
        .markHelperCompleted(userId, helperId);
    if (GuidedOnboardingController.instance.target?.variant ==
        CoachmarkVariant.helperBubble) {
      GuidedOnboardingController.instance.clear();
    }
    await completion;
  }

  void _handleCreateNew() {
    unawaited(
      _markFlowStudioHelperCompleted(
        OnboardingHelperRegistry.flowStudioAddFlow.id,
      ),
    );
    widget.onCreateNew();
  }

  void _handleClose() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    final close = widget.onClose;
    if (close != null) {
      close();
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) rootNavigator.pop();
  }

  void _handleOpenTemplate(_MaatFlowTemplate template) {
    unawaited(
      _markFlowStudioHelperCompleted(
        OnboardingHelperRegistry.flowStudioMaatFlows.id,
      ),
    );
    setState(() => _selectedTemplateKey = template.key);
    widget.onSelectedTemplateChanged?.call(template.key);
  }

  void _handleDetailBack() {
    if (_selectedTemplateKey == null) return;
    setState(() => _selectedTemplateKey = null);
    widget.onSelectedTemplateChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTemplate = _selectedTemplate;
    if (selectedTemplate != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleDetailBack();
        },
        child: SizedBox.expand(
          key: kMaatFlowDetailSurfaceHostKey,
          child: KeyedSubtree(
            key: ValueKey<String>(
              'maat-flow-discovery-detail-${selectedTemplate.key}',
            ),
            child: widget.detailBuilder(
              selectedTemplate,
              widget.activeInstanceForKey(selectedTemplate.key),
              _handleDetailBack,
            ),
          ),
        ),
      );
    }

    final templatesByKey = <String, _MaatFlowTemplate>{
      for (final template in widget.templates) template.key: template,
    };
    final cards = kCoreMaatFlowDiscoveryFixtures
        .where(
          (card) =>
              isMaatFlowDiscoverable(card.flowKey) &&
              templatesByKey.containsKey(card.flowKey),
        )
        .toList(growable: false);
    return MaatFlowDiscoveryView(
      cards: cards,
      onOpen: (flowKey) {
        final template = templatesByKey[flowKey];
        if (template == null) return;
        _handleOpenTemplate(template);
      },
      onCreate: _handleCreateNew,
      onClose: _handleClose,
      createKey: _addFlowHelperKey,
    );
  }
}

@visibleForTesting
Widget buildMaatFlowsListPreviewForTesting({
  Set<String> joinedKeys = const <String>{},
  Map<String, (int total, int remaining)> completionCounts =
      const <String, (int total, int remaining)>{},
  ValueChanged<String>? onSelectTemplate,
  VoidCallback? onCreateNew,
  VoidCallback? onClose,
  KarRepository? karRepository,
}) {
  return _MaatFlowsListPage(
    title: _kMaatFlowsDisplayTitle,
    templates: _kCoreMaatFlowTemplates,
    activeInstanceForKey: (key) {
      if (!joinedKeys.contains(key)) return null;
      final template = _kCoreMaatFlowTemplates.firstWhere(
        (candidate) => candidate.key == key,
      );
      return _Flow(
        id: key.hashCode.abs() + 1,
        name: template.title,
        color: template.color,
        active: true,
        rules: const <FlowRule>[],
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
        notes: 'maat=$key',
      );
    },
    progressForKey: (key) {
      final counts = completionCounts[key];
      if (counts == null) return null;
      return CalendarPage._maatCompletionStatusFromCounts(
        totalEventCount: counts.$1,
        remainingEventCount: counts.$2,
      );
    },
    detailBuilder: (template, activeInstance, onBack) =>
        buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: template.key,
          joinedStartDate: activeInstance?.start,
          joinedFlowId: activeInstance?.id ?? 957,
          onBack: onBack,
          karRepository: karRepository,
        ),
    onSelectedTemplateChanged: (templateKey) {
      if (templateKey != null) onSelectTemplate?.call(templateKey);
    },
    onCreateNew: onCreateNew ?? () {},
    onClose: onClose,
  );
}

typedef _ActiveMaatFlowAddInstance =
    Future<int> Function({
      required _MaatFlowTemplate template,
      DateTime? startDate,
      bool? useKemetic,
      TrackSkyTimeZone? trackSkyTimeZone,
      int? alertMinutesBefore,
      OfferingTableLens? offeringTableLens,
      bool? offeringNoCupMode,
      DjedLens? djedLens,
      DjedV2Configuration? djedConfiguration,
      List<ReadingHouseSitting>? readingHouseSittings,
    });

@visibleForTesting
Widget buildMaatFlowTemplateDetailPreviewForTesting({
  String templateKey = kTheDjedFlowKey,
  bool emptyEvents = false,
  DateTime? joinedStartDate,
  int joinedFlowId = 957,
  Future<int> Function()? onJoin,
  VoidCallback? onBack,
  KarRepository? karRepository,
}) {
  final template = _kCoreMaatFlowTemplates.firstWhere(
    (candidate) => candidate.key == templateKey,
  );
  return _ActiveMaatFlowDetailSurface(
    template: template,
    onBack: onBack,
    karRepository: karRepository,
    joinedFlow: joinedStartDate == null
        ? null
        : _Flow(
            id: joinedFlowId,
            name: template.title,
            color: template.color,
            active: true,
            rules: <FlowRule>[
              _RuleDates(
                dates: <DateTime>{
                  for (var offset = 0; offset < 30; offset++)
                    DateUtils.dateOnly(
                      joinedStartDate.add(Duration(days: offset)),
                    ),
                },
              ),
            ],
            start: DateUtils.dateOnly(joinedStartDate),
            end: DateUtils.dateOnly(
              joinedStartDate.add(const Duration(days: 29)),
            ),
            notes:
                'maat=${template.key};offering_tz=pacific;offering_lens=neutral;no_cup_mode=0',
          ),
    addInstance:
        ({
          required _MaatFlowTemplate template,
          DateTime? startDate,
          bool? useKemetic,
          TrackSkyTimeZone? trackSkyTimeZone,
          int? alertMinutesBefore,
          OfferingTableLens? offeringTableLens,
          bool? offeringNoCupMode,
          DjedLens? djedLens,
          DjedV2Configuration? djedConfiguration,
          List<ReadingHouseSitting>? readingHouseSittings,
        }) => onJoin?.call() ?? Future<int>.value(1),
  );
}

Future<int> _joinOfferingTableFromDetailAuthority({
  required _MaatFlowTemplate template,
  required DateTime startDate,
  required TrackSkyTimeZone timezone,
  required OfferingTableLens lens,
  required bool noCupMode,
  String? personalCalendarIdOverride,
  FlowJoinService? joinService,
  Future<void> Function()? clearFiledFlowsCache,
}) async {
  final id = await CalendarPage._joinOfferingTableHeadless(
    template: template,
    completionRequired: false,
    personalCalendarIdOverride: personalCalendarIdOverride,
    startDate: startDate,
    timezone: timezone,
    lens: lens,
    noCupMode: noCupMode,
    joinService: joinService,
  );
  if (id <= 0) {
    throw StateError('The Offering Table did not produce a staged flow.');
  }
  CalendarPage._rememberJoinedMaatFlowTemplate(
    templateKey: template.key,
    flowId: id,
  );
  unawaited(
    clearFiledFlowsCache?.call() ??
        FlowsRepo(Supabase.instance.client).clearMyFiledFlowsCache(),
  );
  return id;
}

@visibleForTesting
Future<int> joinOfferingTableThroughProductionForTesting({
  required FlowJoinService joinService,
  required DateTime startDate,
  TrackSkyTimeZone timezone = TrackSkyTimeZone.pacific,
  OfferingTableLens lens = OfferingTableLens.neutral,
  bool noCupMode = false,
  String personalCalendarId = 'personal-calendar',
  Future<void> Function()? clearFiledFlowsCache,
}) {
  final template = _kCoreMaatFlowTemplates.firstWhere(
    (candidate) => candidate.kind == _MaatFlowTemplateKind.offeringTable,
  );
  return _joinOfferingTableFromDetailAuthority(
    template: template,
    startDate: startDate,
    timezone: timezone,
    lens: lens,
    noCupMode: noCupMode,
    personalCalendarIdOverride: personalCalendarId,
    joinService: joinService,
    clearFiledFlowsCache: clearFiledFlowsCache,
  );
}

@visibleForTesting
void resetMaatFlowJoinedStateForTesting() {
  CalendarPage._clearRememberedJoinedMaatFlowTemplates();
  kMaatFlowResponseDraftStore.clearForTesting();
}

@visibleForTesting
bool maatFlowTemplateMatchesActiveFlowForTesting({
  required String templateKey,
  required String flowName,
  String? flowNotes,
  bool active = true,
  bool isHidden = false,
  bool isReminder = false,
  DateTime? end,
}) {
  return CalendarPage._flowMatchesActiveMaatTemplate(
    _Flow(
      id: 1,
      name: flowName,
      color: Colors.white,
      active: active,
      rules: const <FlowRule>[],
      end: end,
      notes: flowNotes,
      isHidden: isHidden,
      isReminder: isReminder,
    ),
    templateKey,
  );
}

@visibleForTesting
bool maatFlowFilingSnapshotMarksInstanceActiveForTesting({
  required bool visibleInActiveList,
  bool flowActive = true,
}) {
  final flow = _Flow(
    id: 1,
    name: 'The Djed',
    color: Colors.white,
    active: flowActive,
    rules: const <FlowRule>[],
    notes: 'maat=$kTheDjedFlowKey',
  );
  return CalendarPage._snapshotHasActiveMaatInstanceFor(
    _MyFlowsFilingSnapshot(
      flows: <_Flow>[flow],
      activeFlowIds: visibleInActiveList ? const <int>{1} : const <int>{},
      savedFlowIds: const <int>{},
      totalEventCounts: const <int, int>{1: 9},
      remainingEventCounts: const <int, int>{1: 9},
    ),
    kTheDjedFlowKey,
  );
}

class _FirstMaatFlowOnboardingSheet extends StatefulWidget {
  const _FirstMaatFlowOnboardingSheet({
    required this.templates,
    required this.onAddFlow,
  });

  final List<_MaatFlowTemplate> templates;
  final Future<void> Function(_MaatFlowTemplate template) onAddFlow;

  @override
  State<_FirstMaatFlowOnboardingSheet> createState() =>
      _FirstMaatFlowOnboardingSheetState();
}

class _FirstMaatFlowOnboardingSheetState
    extends State<_FirstMaatFlowOnboardingSheet> {
  FirstRhythmGoal? _goal;
  RhythmTimePreference? _timePreference;
  RhythmDuration? _duration;
  String? _selectedTemplateKey;
  bool _adding = false;

  bool get _answered =>
      _goal != null && _timePreference != null && _duration != null;

  Map<String, _MaatFlowTemplate> get _templateByKey =>
      <String, _MaatFlowTemplate>{
        for (final template in widget.templates) template.key: template,
      };

  List<StarterMaatFlow> get _recommendations {
    final goal = _goal;
    final timePreference = _timePreference;
    final duration = _duration;
    if (goal == null || timePreference == null || duration == null) {
      return const <StarterMaatFlow>[];
    }
    final templates = _templateByKey;
    return const StarterFlowRecommendationService()
        .recommend(
          goal: goal,
          timePreference: timePreference,
          duration: duration,
        )
        .where((flow) => templates.containsKey(flow.templateKey))
        .toList(growable: false);
  }

  Future<void> _addSelectedFlow() async {
    final selectedKey = _selectedTemplateKey;
    if (selectedKey == null || _adding) return;
    final template = _templateByKey[selectedKey];
    if (template == null) return;
    setState(() => _adding = true);
    try {
      await widget.onAddFlow(template);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  String _goalLabel(FirstRhythmGoal goal) => switch (goal) {
    FirstRhythmGoal.followTheSky => 'Follow the sky',
    FirstRhythmGoal.buildDailyDiscipline => 'Build daily discipline',
    FirstRhythmGoal.reflectAndJournal => 'Reflect and journal',
    FirstRhythmGoal.careForTheBody => 'Care for the body',
    FirstRhythmGoal.studyAndRemember => 'Study and remember',
  };

  String _timeLabel(RhythmTimePreference time) => switch (time) {
    RhythmTimePreference.dawn => 'Dawn',
    RhythmTimePreference.midday => 'Midday',
    RhythmTimePreference.evening => 'Evening',
    RhythmTimePreference.flexible => 'Flexible',
  };

  String _durationLabel(RhythmDuration duration) => switch (duration) {
    RhythmDuration.twoMinutes => '2 minutes',
    RhythmDuration.tenMinutes => '10 minutes',
    RhythmDuration.twentyMinutes => '20 minutes',
  };

  Widget _question<T>({
    required String title,
    required T? value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFFFE6A3),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final option in values)
              ChoiceChip(
                selected: option == value,
                label: Text(labelFor(option)),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: option == value
                      ? Colors.black
                      : Colors.white.withValues(alpha: 0.84),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: KemeticGold.base,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                side: BorderSide(
                  color: option == value
                      ? KemeticGold.base
                      : Colors.white.withValues(alpha: 0.16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (_) => onChanged(option),
              ),
          ],
        ),
      ],
    );
  }

  Widget _recommendationCard(StarterMaatFlow suggestion) {
    final template = _templateByKey[suggestion.templateKey];
    if (template == null) return const SizedBox.shrink();
    final selected = _selectedTemplateKey == suggestion.templateKey;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _adding
          ? null
          : () => setState(() => _selectedTemplateKey = suggestion.templateKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? KemeticGold.base.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected || suggestion.prominent
                ? KemeticGold.base.withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.14),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: suggestion.prominent
              ? <BoxShadow>[
                  BoxShadow(
                    color: KemeticGold.base.withValues(alpha: 0.14),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MaatFlowGlyph(glyph: template.glyph, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: KemeticGold.text(
                          suggestion.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (suggestion.prominent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: KemeticGold.base.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: KemeticGold.base.withValues(alpha: 0.55),
                            ),
                          ),
                          child: const Text(
                            'Dawn',
                            style: TextStyle(
                              color: Color(0xFFFFE4A0),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    suggestion.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 13,
                      height: 1.34,
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

  @override
  Widget build(BuildContext context) {
    final recommendations = _recommendations;
    if (_answered &&
        _selectedTemplateKey == null &&
        recommendations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedTemplateKey != null) return;
        setState(
          () => _selectedTemplateKey = recommendations.first.templateKey,
        );
      });
    }
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Material(
          color: const Color(0xFF050505),
          child: SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: KemeticGold.text(
                          'Begin with Ma’at.',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _adding
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      0,
                      18,
                      AppBottomInsets.contentBottomPadding(context),
                    ),
                    children: <Widget>[
                      Text(
                        'Ma’at is the living order of balance, truth, rhythm, and right action. Connect to the spirit of Ma’at by adding your first flow.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 14,
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _question<FirstRhythmGoal>(
                        title:
                            'What do you want your first rhythm to help you do?',
                        value: _goal,
                        values: FirstRhythmGoal.values,
                        labelFor: _goalLabel,
                        onChanged: (value) => setState(() {
                          _goal = value;
                          _selectedTemplateKey = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      _question<RhythmTimePreference>(
                        title: 'When do you want this rhythm to meet you?',
                        value: _timePreference,
                        values: RhythmTimePreference.values,
                        labelFor: _timeLabel,
                        onChanged: (value) => setState(() {
                          _timePreference = value;
                          _selectedTemplateKey = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      _question<RhythmDuration>(
                        title: 'How much time do you want to give it?',
                        value: _duration,
                        values: RhythmDuration.values,
                        labelFor: _durationLabel,
                        onChanged: (value) => setState(() {
                          _duration = value;
                          _selectedTemplateKey = null;
                        }),
                      ),
                      if (_answered) ...<Widget>[
                        const SizedBox(height: 24),
                        KemeticGold.text(
                          'Starter Ma’at Flows',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final suggestion in recommendations) ...<Widget>[
                          _recommendationCard(suggestion),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: KemeticGold.base,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          _answered && _selectedTemplateKey != null && !_adding
                          ? _addSelectedFlow
                          : null,
                      child: _adding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Add This Flow',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveMaatFlowDetailSurface extends StatefulWidget {
  const _ActiveMaatFlowDetailSurface({
    required this.template,
    required this.addInstance,
    this.onJoined,
    this.joinedFlow,
    this.onBack,
    this.followSkyCandidates = const <CourseActivitySignal>[],
    this.followSkyMeasurementIntervals = const <CourseMeasurementInterval>[],
    this.followSkyCalendarPreview = FollowSkyCalendarPreview.empty,
    this.onFollowSkyCourseSaved,
    this.onFollowSkyProtectTime,
    this.onEndFlow,
    this.karRepository,
  });

  final _MaatFlowTemplate template;
  final _ActiveMaatFlowAddInstance addInstance;
  final Future<void> Function(int flowId)? onJoined;
  final _Flow? joinedFlow;
  final VoidCallback? onBack;
  final List<CourseActivitySignal> followSkyCandidates;
  final List<CourseMeasurementInterval> followSkyMeasurementIntervals;
  final FollowSkyCalendarPreview followSkyCalendarPreview;
  final Future<void> Function(TrackSkyCourse? course, String notes)?
  onFollowSkyCourseSaved;
  final Future<void> Function({
    required TrackSkyCourse course,
    required DateTime startLocal,
    required DateTime endLocal,
  })?
  onFollowSkyProtectTime;
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final KarRepository? karRepository;

  bool get alreadyJoined => joinedFlow != null;

  @override
  State<_ActiveMaatFlowDetailSurface> createState() =>
      _ActiveMaatFlowDetailSurfaceState();
}

class _ActiveMaatFlowDetailSurfaceState
    extends State<_ActiveMaatFlowDetailSurface> {
  late final TrackSkyTimeZone _timezone;
  final GlobalKey<FollowSkyDetailSurfaceState> _followSkyDetailKey =
      GlobalKey<FollowSkyDetailSurfaceState>();
  ReadingHouseAuthority? _readingHouseAuthority;
  KarRepository? _karRepository;
  bool _djedJoinInFlight = false;

  @override
  void initState() {
    super.initState();
    _timezone = detectTrackSkyTimeZone();
  }

  Future<void> _completeJoin(int flowId) async {
    final onJoined = widget.onJoined;
    if (onJoined != null) {
      await onJoined(flowId);
      return;
    }
    if (mounted) Navigator.of(context).pop(flowId);
  }

  List<DateTime> _joinedDateRuleDates(_Flow? flow) {
    if (flow == null) return const <DateTime>[];
    final dates = <DateTime>{};
    for (final rule in flow.rules) {
      if (rule is _RuleDates) {
        dates.addAll(rule.dates.map(DateUtils.dateOnly));
      }
    }
    final ordered = dates.toList()..sort();
    return List<DateTime>.unmodifiable(ordered);
  }

  Widget _buildFollowSky() {
    final surface = FollowSkyDetailSurface(
      key: _followSkyDetailKey,
      onBack: widget.onBack,
      isJoined: widget.alreadyJoined,
      existingFlowNotes: widget.joinedFlow?.notes,
      existingFlowId: widget.joinedFlow?.id,
      calendarPreview: widget.followSkyCalendarPreview,
      title: widget.template.title,
      timezone:
          FollowSkyTimeZoneX.tryParse(_timezone.key) ??
          FollowSkyTimeZone.pacific,
      onHierarchyChanged: () {
        if (mounted) setState(() {});
      },
      onJoin: (draft) async {
        final result = await FlowJoinService().joinTrackSkyV2Headless(
          templateKey: widget.template.key,
          templateTitle: widget.template.title,
          templateOverview: widget.template.overview,
          templateColor: widget.template.color,
          personalCalendarId: null,
          draft: draft,
        );
        final id = CalendarPage._stageHeadlessMaatFlowJoinResult(
          result: result,
          template: widget.template,
          completionRequired: false,
        );
        if (id <= 0) {
          throw StateError('Follow the Sky did not produce a staged flow.');
        }
        CalendarPage._rememberJoinedMaatFlowTemplate(
          templateKey: widget.template.key,
          flowId: id,
        );
        unawaited(FlowsRepo(Supabase.instance.client).clearMyFiledFlowsCache());
      },
    );
    return KeyboardAwareEditableSurface(child: surface);
  }

  Widget _buildOfferingTable() {
    final joinedFlow = widget.joinedFlow;
    return OfferingTableDetailSurface(
      timezone: offeringTableTimeZoneFromNotes(
        joinedFlow?.notes,
        fallback: _timezone,
      ),
      calendarPreview: widget.followSkyCalendarPreview,
      joinedFlowId: joinedFlow?.id,
      joinedStartDate: joinedFlow?.start,
      joinedScheduleDates: _joinedDateRuleDates(joinedFlow),
      lens: offeringTableLensFromNotes(joinedFlow?.notes),
      noCupMode: offeringTableNoCupModeFromNotes(joinedFlow?.notes),
      onBack: widget.onBack,
      onJoin:
          ({
            required startDate,
            required timezone,
            required lens,
            required noCupMode,
          }) {
            return _joinOfferingTableFromDetailAuthority(
              template: widget.template,
              startDate: startDate,
              timezone: timezone,
              lens: lens,
              noCupMode: noCupMode,
            );
          },
    );
  }

  Future<void> _joinDjed(
    DateTime startDate,
    DjedV2Configuration configuration,
  ) async {
    if (_djedJoinInFlight) return;
    setState(() => _djedJoinInFlight = true);
    try {
      final id = await widget.addInstance(
        template: widget.template,
        startDate: DateUtils.dateOnly(startDate),
        trackSkyTimeZone: _timezone,
        djedLens: DjedLens.neutral,
        djedConfiguration: configuration,
      );
      if (id <= 0) {
        throw StateError('The Djed did not produce a staged flow.');
      }
      CalendarPage._rememberJoinedMaatFlowTemplate(
        templateKey: widget.template.key,
        flowId: id,
      );
      await _completeJoin(id);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        _calendarDebugPrint('[djed] join failed: $error');
        _calendarDebugPrint('$stackTrace');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not join The Djed. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _djedJoinInFlight = false);
    }
  }

  Widget _buildDjed() {
    final joinedFlow = widget.joinedFlow;
    final startDate =
        joinedFlow?.start ?? djedNextEnrollmentWindow(_timezone).opensAtLocal;
    final configuration = djedV2ConfigurationFromNotes(joinedFlow?.notes);
    final supports = configuration == null
        ? kDjedSupportFixtures
        : <DjedSupportFixture>[
            for (final support in configuration.supports)
              DjedSupportFixture(
                name: support.name,
                condition: switch (support.initialCondition) {
                  DjedV2SupportCondition.holding =>
                    DjedSupportCondition.holding,
                  DjedV2SupportCondition.underPressure =>
                    DjedSupportCondition.underPressure,
                  DjedV2SupportCondition.wobbling =>
                    DjedSupportCondition.wobbling,
                },
              ),
          ];
    return DjedDetailSurface(
      startDate: DateUtils.dateOnly(startDate),
      supports: supports,
      joined: widget.alreadyJoined,
      busy: _djedJoinInFlight,
      onCarryConfiguration: widget.alreadyJoined
          ? null
          : (value) => unawaited(_joinDjed(startDate, value)),
      onBack: widget.onBack,
    );
  }

  Widget _buildReadingHouse() {
    final draftPlan = readingHousePlanFromDraftValues(
      kMaatFlowResponseDraftStore.valuesForFlow(kReadingHouseFlowKey),
    );
    final initialPlan = readingHousePlanFromFlowNotes(
      widget.joinedFlow?.notes,
      fallback: draftPlan,
    );
    return ReadingHouseDetailSurface(
      timezone: _timezone,
      initialStartDate: widget.joinedFlow?.start,
      initialPlan: initialPlan,
      initialSittings: readingHouseStarterSittingsForAuthoring(),
      initiallyHeld: widget.alreadyJoined,
      initialFlowId: widget.joinedFlow?.id,
      initialCalendarId: widget.joinedFlow?.calendarId,
      authority: _readingHouseAuthority ??= LiveReadingHouseAuthority(
        Supabase.instance.client,
      ),
      resolvePersonalCalendarId: CalendarPage._loadHeadlessPersonalCalendarId,
      onHeld: (flowId) {
        final onJoined = widget.onJoined;
        if (onJoined != null) unawaited(onJoined(flowId));
      },
      onEndFlow: widget.onEndFlow,
      onBack: widget.onBack,
    );
  }

  Future<int> _scheduleKar({
    required KarNetjer netjer,
    required String cycleId,
    required int cycleSequence,
    required DateTime startDate,
    int? existingFlowId,
  }) async {
    final result = await FlowJoinService().joinKarHeadless(
      templateKey: widget.template.key,
      templateTitle: widget.template.title,
      templateOverview: widget.template.overview,
      templateColor: widget.template.color,
      personalCalendarId: await CalendarPage._loadHeadlessPersonalCalendarId(),
      timezone: _timezone,
      startDate: startDate,
      netjer: netjer,
      cycleId: cycleId,
      cycleSequence: cycleSequence,
      existingFlowId: existingFlowId,
    );
    final id = CalendarPage._stageHeadlessMaatFlowJoinResult(
      result: result,
      template: widget.template,
      completionRequired: false,
    );
    if (id > 0) {
      CalendarPage._rememberJoinedMaatFlowTemplate(
        templateKey: widget.template.key,
        flowId: id,
      );
      unawaited(FlowsRepo(Supabase.instance.client).clearMyFiledFlowsCache());
    }
    return id;
  }

  Widget _buildKar() {
    final joined = widget.joinedFlow;
    return KarDetailSurface(
      repository: _karRepository ??=
          widget.karRepository ??
          (Supabase.instance.client.auth.currentUser == null
              ? MemoryKarRepository()
              : SupabaseKarRepository(Supabase.instance.client)),
      initialNetjer: karNetjerFromFlowNotes(joined?.notes),
      joinedFlowId: joined?.id,
      joinedStartDate: joined?.start,
      onBack: widget.onBack,
      onJoin: _scheduleKar,
      onReschedule:
          ({
            required oldFlowId,
            required netjer,
            required cycleId,
            required cycleSequence,
            required startDate,
          }) => _scheduleKar(
            netjer: netjer,
            cycleId: cycleId,
            cycleSequence: cycleSequence,
            startDate: startDate,
            existingFlowId: oldFlowId,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.template.key) {
      'track-the-sky' => _buildFollowSky(),
      kOfferingTableFlowKey => _buildOfferingTable(),
      kReadingHouseFlowKey => _buildReadingHouse(),
      kTheDjedFlowKey => _buildDjed(),
      kKarFlowKey => _buildKar(),
      _ => ArchivedMaatFlowDetailView(
        fixture: ArchivedMaatFlowFixture(
          flowKey: widget.template.key,
          title: widget.template.title,
          glyph: widget.template.glyph,
          dateRange: _archivedDateRange(widget.joinedFlow),
          events: const <ArchivedMaatFlowEventFixture>[],
          responses: const <ArchivedMaatFlowResponseFixture>[],
          ended: widget.joinedFlow?.active == false,
        ),
        onBack: widget.onBack,
      ),
    };
  }
}

String _archivedDateRange(_Flow? flow) {
  String format(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final start = flow?.start;
  final end = flow?.end;
  if (start == null && end == null) return 'Dates preserved with the flow';
  if (start == null) return 'Through ${format(end!)}';
  if (end == null) return 'From ${format(start)}';
  return '${format(start)}–${format(end)}';
}
