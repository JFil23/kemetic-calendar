part of 'calendar_page.dart';

@visibleForTesting
const Key kMaatFlowInitialPromptSectionKey = ValueKey<String>(
  'maat_flow_initial_prompt_section',
);

@visibleForTesting
const Key kMaatFlowPracticeDisclaimerFooterKey = ValueKey<String>(
  'maat_flow_practice_disclaimer_footer',
);

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
            height: 1.0,
            letterSpacing: 0,
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: meduNeterFontFallback,
          ),
        ),
      ),
    );
  }
}

class _MaatFlowPrivacyFooter extends StatelessWidget {
  const _MaatFlowPrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        'Privacy note: private reflections and names are never included in notification previews.',
        style: TextStyle(
          color: Colors.white38,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 11.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class _MaatFlowPracticeDisclaimerFooter extends StatelessWidget {
  const _MaatFlowPracticeDisclaimerFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: kMaatFlowPracticeDisclaimerFooterKey,
      padding: EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        'This is a reflective practice, not medical, psychological, or professional advice. Adapt anything that does not suit you, and seek qualified help for health or crisis concerns.',
        style: TextStyle(
          color: Colors.white38,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 11.5,
          height: 1.35,
        ),
      ),
    );
  }
}

class _MaatFlowsListPageWithSnapshot extends StatefulWidget {
  const _MaatFlowsListPageWithSnapshot({
    required this.initialSnapshot,
    required this.loadSnapshot,
    required this.onPickTemplate,
    required this.onCreateNew,
    required this.title,
    required this.templates,
    this.onClose,
  });

  final _MyFlowsFilingSnapshot? initialSnapshot;
  final Future<_MyFlowsFilingSnapshot> Function() loadSnapshot;
  final Future<int?> Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;
  final VoidCallback? onClose;

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
      progressForKey: (key) =>
          CalendarPage._snapshotMaatCompletionStatusFor(_snapshot, key),
      onPickTemplate: widget.onPickTemplate,
      onCreateNew: widget.onCreateNew,
      onClose: widget.onClose,
    );
  }
}

class _MaatFlowsListPage extends StatefulWidget {
  const _MaatFlowsListPage({
    required this.hasActiveForKey,
    this.progressForKey,
    required this.onPickTemplate,
    required this.onCreateNew,
    required this.title,
    required this.templates,
    this.onClose,
  });

  final bool Function(String key) hasActiveForKey;
  final _MaatFlowCompletionStatus? Function(String key)? progressForKey;
  final Future<int?> Function(_MaatFlowTemplate tpl) onPickTemplate;
  final VoidCallback onCreateNew;
  final String title;
  final List<_MaatFlowTemplate> templates;
  final VoidCallback? onClose;

  @override
  State<_MaatFlowsListPage> createState() => _MaatFlowsListPageState();
}

@visibleForTesting
Widget buildMaatFlowsListPreviewForTesting({
  Set<String> joinedKeys = const <String>{},
  Map<String, (int total, int remaining)> completionCounts =
      const <String, (int total, int remaining)>{},
  Future<int?> Function(String templateKey)? onPickTemplate,
  VoidCallback? onCreateNew,
  VoidCallback? onClose,
}) {
  return _MaatFlowsListPage(
    title: _kMaatFlowsDisplayTitle,
    templates: _kMaatFlowTemplates,
    hasActiveForKey: (key) =>
        joinedKeys.contains(key) ||
        CalendarPage._hasRememberedJoinedMaatTemplate(key),
    progressForKey: (key) {
      final counts = completionCounts[key];
      if (counts == null) return null;
      return CalendarPage._maatCompletionStatusFromCounts(
        totalEventCount: counts.$1,
        remainingEventCount: counts.$2,
      );
    },
    onPickTemplate: (template) async {
      return onPickTemplate == null ? null : await onPickTemplate(template.key);
    },
    onCreateNew: onCreateNew ?? () {},
    onClose: onClose,
  );
}

@visibleForTesting
Widget buildMaatFlowTemplateDetailPreviewForTesting({
  String templateKey = 'the-weighing',
}) {
  final template = _kMaatFlowTemplates.firstWhere(
    (candidate) => candidate.key == templateKey,
  );
  return _MaatFlowTemplateDetailPage(
    template: template,
    addInstance:
        ({
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
          String? eveningThresholdInitialCarry,
        }) async => 1,
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

class _MaatFlowsListPageState extends State<_MaatFlowsListPage> {
  final GlobalKey _addFlowHelperKey = GlobalKey(
    debugLabel: 'flow_studio_maat_add_flow_helper',
  );
  final Set<String> _locallyJoinedTemplateKeys = <String>{};
  bool _helperPrompted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeShowFlowStudioAddFlowHelper());
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
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  Future<void> _handlePickTemplate(_MaatFlowTemplate template) async {
    unawaited(
      _markFlowStudioHelperCompleted(
        OnboardingHelperRegistry.flowStudioMaatFlows.id,
      ),
    );
    final joinedFlowId = await widget.onPickTemplate(template);
    if (!mounted || joinedFlowId == null || joinedFlowId <= 0) return;
    CalendarPage._rememberJoinedMaatFlowTemplate(
      templateKey: template.key,
      flowId: joinedFlowId,
    );
    setState(() {
      _locallyJoinedTemplateKeys.add(template.key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = <_MaatFlowListEntry>[
      for (var i = 0; i < widget.templates.length; i++)
        _MaatFlowListEntry(
          template: widget.templates[i],
          status: _statusForTemplate(
            widget.templates[i],
            joined:
                _locallyJoinedTemplateKeys.contains(widget.templates[i].key) ||
                widget.hasActiveForKey(widget.templates[i].key),
            completion: widget.progressForKey?.call(widget.templates[i].key),
          ),
          originalIndex: i,
        ),
    ];
    final joined = entries.where((entry) => entry.status.joined).toList()
      ..sort((a, b) {
        final progressOrder = b.status.sortProgress.compareTo(
          a.status.sortProgress,
        );
        if (progressOrder != 0) return progressOrder;
        return a.originalIndex.compareTo(b.originalIndex);
      });
    final waiting = entries
        .where((entry) => !entry.status.joined)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: MaatFlowListTokens.pageBg,
      appBar: AppBar(
        backgroundColor: MaatFlowListTokens.pageBg,
        foregroundColor: MaatFlowListTokens.gold,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leadingWidth: 64,
        iconTheme: const IconThemeData(color: MaatFlowListTokens.gold),
        leading: IconButton(
          tooltip: 'Back',
          padding: const EdgeInsets.only(left: 15),
          alignment: Alignment.centerLeft,
          icon: const Icon(
            Icons.arrow_back,
            color: MaatFlowListTokens.gold,
            size: 22,
          ),
          onPressed: _handleClose,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFF17150F)),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: MaatFlowListTokens.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 25,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: IconButton(
              key: _addFlowHelperKey,
              tooltip: 'New flow',
              icon: const Icon(
                Icons.add,
                color: MaatFlowListTokens.gold,
                size: 22,
              ),
              onPressed: _handleCreateNew,
            ),
          ),
        ],
      ),
      body: widget.templates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No Ma’at flows yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                MaatFlowListTokens.cardHorizontalMargin,
                24,
                MaatFlowListTokens.cardHorizontalMargin,
                AppBottomInsets.contentBottomPadding(context),
              ),
              itemCount: _visualItemCount(joined, waiting),
              separatorBuilder: (_, _) => const SizedBox(height: 0),
              itemBuilder: (ctx, i) {
                final item = _visualItemAt(i, joined, waiting);
                switch (item) {
                  case _MaatFlowSectionVisual(:final label):
                    return _MaatFlowSectionLabel(label: label);
                  case _MaatFlowCardVisual(:final entry):
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.status.joined
                            ? MaatFlowListTokens.joinedCardGap
                            : MaatFlowListTokens.unjoinedCardGap,
                      ),
                      child: _MaatFlowCard(
                        entry: entry,
                        onTap: () async => _handlePickTemplate(entry.template),
                      ),
                    );
                  case _MaatFlowDividerVisual():
                    return const SizedBox(
                      height: MaatFlowListTokens.joinedToUnjoinedGap,
                    );
                }
              },
            ),
    );
  }

  _MaatFlowCardStatus _statusForTemplate(
    _MaatFlowTemplate template, {
    required bool joined,
    _MaatFlowCompletionStatus? completion,
  }) {
    if (!joined) return const _MaatFlowCardStatus.waiting();
    return _MaatFlowCardStatus.joined(
      completionProgress: completion?.progress,
      statusLabel: completion?.label ?? 'active',
    );
  }

  int _visualItemCount(
    List<_MaatFlowListEntry> joined,
    List<_MaatFlowListEntry> waiting,
  ) {
    var count = 0;
    if (joined.isNotEmpty) count += 1 + joined.length;
    if (joined.isNotEmpty && waiting.isNotEmpty) count += 1;
    if (waiting.isNotEmpty) count += 1 + waiting.length;
    return count;
  }

  _MaatFlowListVisual _visualItemAt(
    int index,
    List<_MaatFlowListEntry> joined,
    List<_MaatFlowListEntry> waiting,
  ) {
    var cursor = 0;
    if (joined.isNotEmpty) {
      if (index == cursor) {
        return const _MaatFlowSectionVisual('JOINED');
      }
      cursor += 1;
      final joinedEnd = cursor + joined.length;
      if (index < joinedEnd) {
        return _MaatFlowCardVisual(joined[index - cursor]);
      }
      cursor = joinedEnd;
    }
    if (joined.isNotEmpty && waiting.isNotEmpty) {
      if (index == cursor) return const _MaatFlowDividerVisual();
      cursor += 1;
    }
    if (waiting.isNotEmpty) {
      if (index == cursor) {
        return const _MaatFlowSectionVisual('NOT YET JOINED');
      }
      cursor += 1;
      return _MaatFlowCardVisual(waiting[index - cursor]);
    }
    throw RangeError.index(index, const <Object>[]);
  }
}

class _MaatFlowListEntry {
  const _MaatFlowListEntry({
    required this.template,
    required this.status,
    required this.originalIndex,
  });

  final _MaatFlowTemplate template;
  final _MaatFlowCardStatus status;
  final int originalIndex;
}

class _MaatFlowCardStatus {
  const _MaatFlowCardStatus.joined({
    required this.completionProgress,
    required this.statusLabel,
  }) : joined = true;

  const _MaatFlowCardStatus.waiting()
    : joined = false,
      completionProgress = null,
      statusLabel = '';

  final bool joined;
  final double? completionProgress;
  final String statusLabel;

  double get sortProgress => completionProgress ?? -1;
}

class _MaatFlowListPalette {
  const _MaatFlowListPalette({required this.accent, required this.glow});

  final Color accent;
  final Color glow;

  Color borderFor(bool joined) =>
      accent.withValues(alpha: joined ? 0.35 : 0.16);

  Color categoryFor(bool joined) =>
      accent.withValues(alpha: joined ? 0.70 : 0.58);

  Color chevronFor(bool joined) =>
      accent.withValues(alpha: joined ? 0.80 : 0.32);

  Color stripeFor(bool joined) => accent.withValues(alpha: joined ? 1.0 : 0.55);
}

_MaatFlowListPalette _maatFlowListPaletteFor(_MaatFlowTemplate template) {
  return _MaatFlowListPalette(
    accent: template.color,
    glow: switch (template.kind) {
      _MaatFlowTemplateKind.theWeighing => const Color(0xFFF5E8CB),
      _MaatFlowTemplateKind.trackSky => const Color(0xFFA4B1FF),
      _MaatFlowTemplateKind.dawnHouseRite => const Color(0xFFFFD08A),
      _MaatFlowTemplateKind.eveningThresholdRite => const Color(0xFF7FE0D4),
      _ => template.color,
    },
  );
}

sealed class _MaatFlowListVisual {
  const _MaatFlowListVisual();
}

class _MaatFlowSectionVisual extends _MaatFlowListVisual {
  const _MaatFlowSectionVisual(this.label);

  final String label;
}

class _MaatFlowCardVisual extends _MaatFlowListVisual {
  const _MaatFlowCardVisual(this.entry);

  final _MaatFlowListEntry entry;
}

class _MaatFlowDividerVisual extends _MaatFlowListVisual {
  const _MaatFlowDividerVisual();
}

class _MaatFlowSectionLabel extends StatelessWidget {
  const _MaatFlowSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MaatFlowListTokens.sectionLabelPadding,
      child: Text(
        label,
        style: const TextStyle(
          color: MaatFlowListTokens.sectionLabel,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 2.0,
          height: 1,
        ),
      ),
    );
  }
}

class _MaatFlowCard extends StatelessWidget {
  const _MaatFlowCard({required this.entry, required this.onTap});

  final _MaatFlowListEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final template = entry.template;
    final status = entry.status;
    final palette = _maatFlowListPaletteFor(template);
    final subtitleParts = _MaatFlowSubtitleParts.parse(template.subtitle);
    final cardPadding = status.joined
        ? MaatFlowListTokens.joinedCardPadding
        : MaatFlowListTokens.unjoinedCardPadding;
    final titleColor = status.joined
        ? MaatFlowListTokens.joinedTitle
        : MaatFlowListTokens.unjoinedTitle;
    final excerptColor = status.joined
        ? MaatFlowListTokens.joinedDescription
        : MaatFlowListTokens.unjoinedDescription;

    final card = Semantics(
      button: true,
      label: status.joined
          ? '${template.title}, joined, ${status.statusLabel}'
          : template.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MaatFlowListTokens.cardRadius),
          splashColor: MaatFlowListTokens.gold.withValues(alpha: 0.06),
          highlightColor: MaatFlowListTokens.gold.withValues(alpha: 0.035),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                MaatFlowListTokens.cardRadius,
              ),
              border: Border.all(
                color: palette.borderFor(status.joined),
                width: MaatFlowListTokens.cardBorderWidth,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                MaatFlowListTokens.cardRadius,
              ),
              child: Stack(
                children: [
                  _MaatFlowCardBaseLayer(joined: status.joined),
                  _MaatFlowCardColorWash(
                    accent: palette.accent,
                    joined: status.joined,
                  ),
                  if (status.joined) const _MaatFlowCardSurfaceLight(),
                  _MaatFlowCardStripe(color: palette.stripeFor(status.joined)),
                  _MaatFlowCardGlowLine(
                    glowColor: palette.glow,
                    joined: status.joined,
                  ),
                  Padding(
                    padding: cardPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MaatFlowIcon(
                          template: template,
                          status: status,
                          listPalette: palette,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  subtitleParts.category.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.categoryFor(status.joined),
                                    fontFamily: MaatFlowListTokens.fontFamily,
                                    fontFamilyFallback:
                                        MaatFlowListTokens.fontFallback,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.65,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  template.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontFamily: MaatFlowListTokens.fontFamily,
                                    fontFamilyFallback:
                                        MaatFlowListTokens.fontFallback,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                    height: 1.08,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitleParts.excerpt,
                                  maxLines: status.joined ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: excerptColor,
                                    fontFamily: MaatFlowListTokens.fontFamily,
                                    fontFamilyFallback:
                                        MaatFlowListTokens.fontFallback,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    height: 1.36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _MaatFlowCardTrailing(status: status, palette: palette),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return status.joined ? card : Opacity(opacity: 0.88, child: card);
  }
}

class _MaatFlowSubtitleParts {
  const _MaatFlowSubtitleParts({required this.category, required this.excerpt});

  final String category;
  final String excerpt;

  static _MaatFlowSubtitleParts parse(String subtitle) {
    final parts = subtitle.split('·');
    if (parts.length >= 2) {
      return _MaatFlowSubtitleParts(
        category: parts.first.trim(),
        excerpt: parts.sublist(1).join('·').trim(),
      );
    }
    return _MaatFlowSubtitleParts(category: 'Flow', excerpt: subtitle.trim());
  }
}

class _MaatFlowCardTrailing extends StatelessWidget {
  const _MaatFlowCardTrailing({required this.status, required this.palette});

  final _MaatFlowCardStatus status;
  final _MaatFlowListPalette palette;

  @override
  Widget build(BuildContext context) {
    if (!status.joined) {
      return SizedBox(
        width: 22,
        height: 66,
        child: Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.chevron_right,
            color: palette.chevronFor(false),
            size: 16,
          ),
        ),
      );
    }

    return SizedBox(
      width: 52,
      height: 78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(Icons.chevron_right, color: palette.chevronFor(true), size: 18),
          const Spacer(),
          const SizedBox(
            width: 52,
            height: 13,
            child: FittedBox(
              alignment: Alignment.centerRight,
              fit: BoxFit.scaleDown,
              child: Text(
                'JOINED',
                maxLines: 1,
                style: TextStyle(
                  color: MaatFlowListTokens.joinedStatus,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.55,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status.statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MaatFlowListTokens.joinedProgress,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaatFlowCardBaseLayer extends StatelessWidget {
  const _MaatFlowCardBaseLayer({required this.joined});

  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: joined
              ? MaatFlowListTokens.joinedCardBg
              : MaatFlowListTokens.unjoinedCardBg,
        ),
      ),
    );
  }
}

class _MaatFlowCardColorWash extends StatelessWidget {
  const _MaatFlowCardColorWash({required this.accent, required this.joined});

  final Color accent;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final colors = joined
        ? [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0.03),
            Colors.transparent,
          ]
        : [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.05),
            Colors.transparent,
          ];
    final stops = joined
        ? const [0.0, 0.35, 0.60, 0.80]
        : const [0.0, 0.35, 0.65];
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}

class _MaatFlowCardStripe extends StatelessWidget {
  const _MaatFlowCardStripe({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(MaatFlowListTokens.cardRadius),
          ),
        ),
        child: const SizedBox(width: 3),
      ),
    );
  }
}

class _MaatFlowCardGlowLine extends StatelessWidget {
  const _MaatFlowCardGlowLine({required this.glowColor, required this.joined});

  final Color glowColor;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          widthFactor: 0.84,
          child: SizedBox(
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0.0, 0.36, 0.5, 0.64, 1.0],
                  colors: [
                    Colors.transparent,
                    glowColor.withValues(alpha: joined ? 0.24 : 0.10),
                    glowColor.withValues(alpha: joined ? 0.55 : 0.20),
                    glowColor.withValues(alpha: joined ? 0.24 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaatFlowCardSurfaceLight extends StatelessWidget {
  const _MaatFlowCardSurfaceLight();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -1.4),
              radius: 0.85,
              colors: [
                Color(0x24FFF8E6),
                Color(0x0FFFF8E6),
                Colors.transparent,
              ],
              stops: [0.0, 0.42, 0.75],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaatFlowIcon extends StatelessWidget {
  const _MaatFlowIcon({
    required this.template,
    required this.status,
    this.listPalette,
    this.detailPalette,
  });

  final _MaatFlowTemplate template;
  final _MaatFlowCardStatus status;
  final _MaatFlowListPalette? listPalette;
  final MaatFlowPalette? detailPalette;

  @override
  Widget build(BuildContext context) {
    final iconSize = listPalette == null
        ? MaatFlowListTokens.iconSize
        : status.joined
        ? MaatFlowListTokens.joinedListIconSize
        : MaatFlowListTokens.unjoinedListIconSize;
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: CustomPaint(
        painter: _MaatFlowIconPainter(
          kind: template.kind,
          glyph: template.glyph,
          joined: status.joined,
          completionProgress: status.completionProgress,
          listAccent: listPalette?.accent,
          detailPalette: detailPalette,
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
    final circleRect = Rect.fromCircle(center: center, radius: radius);
    final circlePaint = Paint()..style = PaintingStyle.fill;
    final gradientStops = detailPalette?.iconGradientStops;
    if (gradientStops != null) {
      circlePaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientStops,
      ).createShader(circleRect);
    } else if (accent != null) {
      circlePaint.shader = RadialGradient(
        center: const Alignment(0.0, -0.3),
        radius: 1.0,
        colors: [
          accent.withValues(alpha: joined ? 0.30 : 0.14),
          detailPalette == null && !joined
              ? const Color(0xFF141008)
              : MaatFlowPalette.warmDark,
        ],
        stops: [0.0, joined ? 0.65 : 0.70],
      ).createShader(circleRect);
    } else {
      circlePaint.color = joined
          ? MaatFlowListTokens.joinedIconBg
          : MaatFlowListTokens.unjoinedIconBg;
    }
    final circleStrokePaint = Paint()
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
      canvas.drawCircle(center, radius, circlePaint);
      if (accent != null && (joined || detailPalette != null)) {
        final crownPaint = Paint()
          ..style = PaintingStyle.fill
          ..shader = const RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.0,
            colors: [Color(0x33FFF8E6), Colors.transparent],
            stops: [0.0, 0.70],
          ).createShader(circleRect);
        canvas.drawCircle(center, radius, crownPaint);
      }
      canvas.drawCircle(center, radius, circleStrokePaint);
    }

    final lineColor = accent != null
        ? accent.withValues(
            alpha: detailPalette == null && !joined ? 0.75 : 1.0,
          )
        : gold;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = detailPalette != null
          ? 1.25
          : joined
          ? MaatFlowListTokens.joinedIconStrokeWidth
          : MaatFlowListTokens.unjoinedIconStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progress = completionProgress;
    if (paintBackground && joined && progress != null) {
      final trackPaint = Paint()
        ..color =
            accent?.withValues(alpha: 0.20) ?? MaatFlowListTokens.progressTrack
        ..strokeWidth = MaatFlowListTokens.progressRingStrokeWidth
        ..style = PaintingStyle.stroke;
      final progressPaint = Paint()
        ..color =
            accent?.withValues(alpha: 0.90) ??
            MaatFlowListTokens.gold.withValues(
              alpha: 0.65 + (0.20 * progress.clamp(0, 1)),
            )
        ..strokeWidth = MaatFlowListTokens.progressRingStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, trackPaint);
      canvas.drawArc(
        circleRect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0, 1),
        false,
        progressPaint,
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(MaatFlowListTokens.iconGlyphScale);
    switch (kind) {
      case _MaatFlowTemplateKind.theWeighing:
        _drawWeighing(canvas, linePaint);
      case _MaatFlowTemplateKind.trackSky:
        _drawSky(canvas, linePaint);
      case _MaatFlowTemplateKind.dawnHouseRite:
        _drawDawnHouse(canvas, linePaint);
      case _MaatFlowTemplateKind.eveningThresholdRite:
        _drawEveningThreshold(canvas, linePaint);
      case _MaatFlowTemplateKind.offeringTable:
        _drawOfferingTable(canvas, linePaint);
      case _MaatFlowTemplateKind.theTending:
        _drawTending(canvas, linePaint);
      default:
        _drawFallbackGlyph(canvas, size, lineColor);
    }
    canvas.restore();
  }

  void _drawWeighing(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(-13, 2), const Offset(13, 2), paint);
    canvas.drawLine(const Offset(0, -15), const Offset(0, 15), paint);
    canvas.drawCircle(
      const Offset(0, -8),
      2.5,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(const Offset(0, 8), 2.2, paint);
    canvas.drawLine(const Offset(-10, 2), const Offset(-14, 6), paint);
    canvas.drawLine(const Offset(10, 2), const Offset(14, 6), paint);
    canvas.drawLine(const Offset(-17, 6), const Offset(-7, 6), paint);
    canvas.drawLine(const Offset(7, 6), const Offset(17, 6), paint);
  }

  void _drawSky(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(0, -8), 5.1, paint);
    canvas.drawArc(
      const Rect.fromLTWH(-11, -6, 22, 22),
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      paint,
    );
    canvas.drawLine(const Offset(0, -2), const Offset(0, 14), paint);
    canvas.drawLine(const Offset(0, -2), const Offset(-8, 7), paint);
    canvas.drawLine(const Offset(0, -2), const Offset(8, 7), paint);
  }

  void _drawDawnHouse(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(0, -15), const Offset(0, -7), paint);
    canvas.drawLine(const Offset(-10, -7), const Offset(10, -7), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -3, 26, 16),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawLine(const Offset(-8, 6), const Offset(8, 6), paint);
  }

  void _drawEveningThreshold(Canvas canvas, Paint paint) {
    canvas.drawArc(
      const Rect.fromLTWH(-13, -8, 26, 18),
      math.pi,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(const Offset(-15, 8), const Offset(15, 8), paint);
    canvas.drawLine(const Offset(-10, 12), const Offset(10, 12), paint);
  }

  void _drawOfferingTable(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(-14, 2), const Offset(14, 2), paint);
    canvas.drawCircle(const Offset(-12, 2), 4.1, paint);
    canvas.drawCircle(const Offset(12, 2), 4.1, paint);
    canvas.drawLine(const Offset(-4, 2), const Offset(4, 2), paint);
    canvas.drawLine(const Offset(-12, 2), const Offset(-12, 9), paint);
    canvas.drawLine(const Offset(12, 2), const Offset(12, 9), paint);
  }

  void _drawTending(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(-11, 13), const Offset(11, 13), paint);
    canvas.drawLine(const Offset(-8, 13), const Offset(-8, -12), paint);
    canvas.drawLine(const Offset(0, 13), const Offset(0, -14), paint);
    canvas.drawLine(const Offset(8, 13), const Offset(8, -12), paint);
  }

  void _drawFallbackGlyph(Canvas canvas, Size size, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: color,
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

class _MaatFlowGlyphTile extends StatelessWidget {
  const _MaatFlowGlyphTile({required this.template, required this.palette});

  final _MaatFlowTemplate template;
  final MaatFlowPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: palette.iconGradientStops == null
            ? RadialGradient(
                center: const Alignment(0.0, -0.3),
                radius: 1.0,
                colors: [
                  palette.accent.withValues(alpha: 0.30),
                  MaatFlowPalette.warmDark,
                ],
                stops: const [0.0, 0.65],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.iconGradientStops!,
              ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.40),
          width: MaatFlowListTokens.cardBorderWidth,
        ),
      ),
      child: CustomPaint(
        painter: _MaatFlowIconPainter(
          kind: template.kind,
          glyph: template.glyph,
          joined: true,
          completionProgress: null,
          listAccent: null,
          detailPalette: palette,
          paintBackground: false,
        ),
      ),
    );
  }
}

/* ───────────────────────── First Ma'at flow onboarding ───────────────────────── */

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

  Map<String, _MaatFlowTemplate> get _templateByKey => {
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

  String _goalLabel(FirstRhythmGoal goal) {
    switch (goal) {
      case FirstRhythmGoal.followTheSky:
        return 'Follow the sky';
      case FirstRhythmGoal.buildDailyDiscipline:
        return 'Build daily discipline';
      case FirstRhythmGoal.reflectAndJournal:
        return 'Reflect and journal';
      case FirstRhythmGoal.careForTheBody:
        return 'Care for the body';
      case FirstRhythmGoal.studyAndRemember:
        return 'Study and remember';
    }
  }

  String _timeLabel(RhythmTimePreference time) {
    switch (time) {
      case RhythmTimePreference.dawn:
        return 'Dawn';
      case RhythmTimePreference.midday:
        return 'Midday';
      case RhythmTimePreference.evening:
        return 'Evening';
      case RhythmTimePreference.flexible:
        return 'Flexible';
    }
  }

  String _durationLabel(RhythmDuration duration) {
    switch (duration) {
      case RhythmDuration.twoMinutes:
        return '2 minutes';
      case RhythmDuration.tenMinutes:
        return '10 minutes';
      case RhythmDuration.twentyMinutes:
        return '20 minutes';
    }
  }

  Widget _question<T>({
    required String title,
    required T? value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          children: [
            for (final option in values)
              _choiceChip<T>(
                value: option,
                groupValue: value,
                label: labelFor(option),
                onChanged: onChanged,
              ),
          ],
        ),
      ],
    );
  }

  Widget _choiceChip<T>({
    required T value,
    required T? groupValue,
    required String label,
    required ValueChanged<T> onChanged,
  }) {
    final selected = value == groupValue;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white.withValues(alpha: 0.84),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: KemeticGold.base,
      backgroundColor: Colors.white.withValues(alpha: 0.07),
      side: BorderSide(
        color: selected
            ? KemeticGold.base
            : Colors.white.withValues(alpha: 0.16),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => onChanged(value),
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
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: suggestion.prominent
              ? [
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
          children: [
            MaatFlowGlyph(glyph: template.glyph, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: Row(
                    children: [
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
                    children: [
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
                        onChanged: (value) {
                          setState(() {
                            _goal = value;
                            _selectedTemplateKey = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      _question<RhythmTimePreference>(
                        title: 'When do you want this rhythm to meet you?',
                        value: _timePreference,
                        values: RhythmTimePreference.values,
                        labelFor: _timeLabel,
                        onChanged: (value) {
                          setState(() {
                            _timePreference = value;
                            _selectedTemplateKey = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      _question<RhythmDuration>(
                        title: 'How much time do you want to give it?',
                        value: _duration,
                        values: RhythmDuration.values,
                        labelFor: _durationLabel,
                        onChanged: (value) {
                          setState(() {
                            _duration = value;
                            _selectedTemplateKey = null;
                          });
                        },
                      ),
                      if (_answered) ...[
                        const SizedBox(height: 24),
                        KemeticGold.text(
                          'Starter Ma’at Flows',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final suggestion in recommendations) ...[
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
                        disabledBackgroundColor: KemeticGold.base.withValues(
                          alpha: 0.28,
                        ),
                        disabledForegroundColor: Colors.black.withValues(
                          alpha: 0.42,
                        ),
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

/* ───────────────────────── Template detail (Add Flow) ───────────────────────── */

class _MaatFlowTemplateDetailPage extends StatefulWidget {
  const _MaatFlowTemplateDetailPage({
    required this.template,
    required this.addInstance,
    this.onJoined,
    this.showBackButton = true,
    this.embeddedInOnboarding = false,
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
    String? eveningThresholdInitialCarry,
  })
  addInstance;
  final Future<void> Function(int flowId)? onJoined;
  final bool showBackButton;
  final bool embeddedInOnboarding;

  @override
  State<_MaatFlowTemplateDetailPage> createState() =>
      _MaatFlowTemplateDetailPageState();
}

class _MaatFlowArcBlock {
  const _MaatFlowArcBlock({
    required this.range,
    required this.title,
    required this.act,
  });

  final String range;
  final String title;
  final String act;
}

class _MaatFlowDetailContent {
  const _MaatFlowDetailContent({
    required this.orientingSentence,
    required this.chips,
    required this.arcBlocks,
  });

  final String orientingSentence;
  final List<String> chips;
  final List<_MaatFlowArcBlock> arcBlocks;
}

class _MaatFlowDetailSeparator extends StatelessWidget {
  const _MaatFlowDetailSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: MaatFlowPalette.separator,
      ),
    );
  }
}

class _MaatFlowDetailSectionLabel extends StatelessWidget {
  const _MaatFlowDetailSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        label,
        style: const TextStyle(
          color: MaatFlowPalette.goldMute,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          height: 1,
        ),
      ),
    );
  }
}

class _MaatFlowArcDivider extends StatelessWidget {
  const _MaatFlowArcDivider({required this.palette});

  final MaatFlowPalette palette;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.20),
        ),
        child: const SizedBox(width: MaatFlowListTokens.cardBorderWidth),
      ),
    );
  }
}

class _MaatFlowArcChevron extends StatelessWidget {
  const _MaatFlowArcChevron({required this.palette});

  final MaatFlowPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      '›',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: palette.accent.withValues(alpha: 0.50),
        fontFamily: MaatFlowListTokens.fontFamily,
        fontFamilyFallback: MaatFlowListTokens.fontFallback,
        fontSize: 18,
        height: 1,
      ),
    );
  }
}

class _MaatFlowTemplateDetailPageState
    extends State<_MaatFlowTemplateDetailPage> {
  late TrackSkyTimeZone _previewTrackSkyTimeZone;
  Future<TrackSkyFlowData>? _trackSkyFuture;
  bool _dawnDiscreetMode = false;
  DawnHouseRiteLens _dawnLens = DawnHouseRiteLens.neutral;
  bool _dawnStartDateTouched = false;
  bool _dawnJoinInFlight = false;
  bool _eveningThresholdStartDateTouched = false;
  bool _eveningThresholdJoinInFlight = false;
  final TextEditingController _eveningThresholdInitialCarryController =
      TextEditingController();
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
  bool _maatDecanStartDateTouched = false;
  bool _maatDecanJoinInFlight = false;
  bool _descriptionExpanded = false;

  MaatFlowPalette get _palette => MaatFlowPalette.resolve(
    flowId: widget.template.key,
    accent: widget.template.color,
  );

  Future<void> _completeJoin(int id) async {
    final onJoined = widget.onJoined;
    if (onJoined != null) {
      await onJoined(id);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  @override
  void initState() {
    super.initState();
    _previewTrackSkyTimeZone = detectTrackSkyTimeZone();
    if (widget.template.kind == _MaatFlowTemplateKind.trackSky) {
      _trackSkyFuture = loadTrackSkyFlowData(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.dawnHouseRite) {
      _picked = defaultDawnHouseRiteStartDate(_previewTrackSkyTimeZone);
    } else if (widget.template.kind == _MaatFlowTemplateKind.eveningThreshold) {
      _picked = defaultEveningThresholdStartDate(_previewTrackSkyTimeZone);
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
    } else if (widget.template.kind == _MaatFlowTemplateKind.maatDecan) {
      _picked = defaultTheDecanWatchStartDate(_previewTrackSkyTimeZone);
    }
  }

  @override
  void dispose() {
    _eveningThresholdInitialCarryController.dispose();
    super.dispose();
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

  Map<String, MaatFlowResponseValue> _initialPromptDraftValuesForFlow(
    String flowKey,
  ) {
    return kMaatFlowResponseDraftStore.valuesForFlow(flowKey);
  }

  void _rememberInitialPromptValue(MaatFlowResponseValue value) {
    kMaatFlowResponseDraftStore.rememberValue(
      flowKey: widget.template.key,
      value: value,
    );
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
    return _buildMaatFlowDetailScaffold(
      context,
      joinButton: _buildTemplateStickyJoinButton(
        text: 'Retry',
        onPressed: () {
          if (kDebugMode) {
            _calendarDebugPrint('[$debugLabel] retry enrollment');
          }
          setState(() {});
        },
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: widget.template.subtitle,
          extraOverviewNote: _buildMaatFlowNotice(
            'No enrollment window is available right now. Try another timezone or retry in a moment.',
            borderColor: MaatFlowPalette.gold.withValues(alpha: 0.38),
            textColor: MaatFlowPalette.gold,
          ),
          configurationControls: [
            const _MaatFlowDetailSectionLabel('TIMEZONE'),
            _buildTimezoneSelector(),
            const SizedBox(height: 14),
            _buildMaatFlowDetailText(
              'Enrollment windows are calculated from your selected timezone and date.',
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 10),
              _buildMaatFlowDetailText(
                'Debug label: $debugLabel',
                color: MaatFlowPalette.silverLo,
                fontSize: 12,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDateModeTitle({
    required String title,
    Color? color,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
    double? height,
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
            style: TextStyle(
              color: color,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              height: height,
            ),
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
    if (widget.template.kind == _MaatFlowTemplateKind.maatDecan) {
      await _pickMaatDecanWindowDate();
      return;
    }
    final picked = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _picked,
      initialMode: _useKemetic
          ? MaatFlowDatePickerMode.kemetic
          : MaatFlowDatePickerMode.gregorian,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _useKemetic = picked.mode == MaatFlowDatePickerMode.kemetic;
      _picked = DateUtils.dateOnly(picked.date);
      _markGenericMaatStartDateTouched();
    });
  }

  void _markGenericMaatStartDateTouched() {
    if (widget.template.kind == _MaatFlowTemplateKind.dawnHouseRite) {
      _dawnStartDateTouched = true;
    } else if (widget.template.kind == _MaatFlowTemplateKind.eveningThreshold) {
      _eveningThresholdStartDateTouched = true;
    } else if (widget.template.kind ==
        _MaatFlowTemplateKind.eveningThresholdRite) {
      _eveningStartDateTouched = true;
    } else if (widget.template.kind == _MaatFlowTemplateKind.theWeighing) {
      _theWeighingStartDateTouched = true;
    } else if (widget.template.kind == _MaatFlowTemplateKind.offeringTable) {
      _offeringStartDateTouched = true;
    } else if (widget.template.kind == _MaatFlowTemplateKind.theTending) {
      _theTendingStartDateTouched = true;
    } else if (widget.template.kind == _MaatFlowTemplateKind.keptWord) {
      _keptWordStartDateTouched = true;
    } else if (widget.template.kind == _MaatFlowTemplateKind.theCourse) {
      _courseStartDateTouched = true;
    }
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

  Future<void> _pickMaatDecanWindowDate() async {
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
                GlossyText(
                  text: '${widget.template.title} Start Windows',
                  gradient: _maatBadgeGoldGloss,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
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
                            _maatDecanStartDateTouched = true;
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
              _MaatFlowTemplateKind.eveningThreshold &&
          !_eveningThresholdStartDateTouched) {
        _picked = defaultEveningThresholdStartDate(timezone);
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
      } else if (widget.template.kind == _MaatFlowTemplateKind.maatDecan &&
          !_maatDecanStartDateTouched) {
        _picked = defaultTheDecanWatchStartDate(timezone);
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
      await _completeJoin(id);
      return;
    }
    setState(() {
      _dawnJoinInFlight = false;
    });
  }

  Future<void> _joinEveningThresholdFlow(DateTime selectedStart) async {
    if (_eveningThresholdJoinInFlight) return;
    final initialCarry = _eveningThresholdInitialCarryController.text.trim();
    if (initialCarry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name what you carry today first.')),
      );
      return;
    }
    setState(() {
      _eveningThresholdJoinInFlight = true;
    });

    final int id;
    try {
      id = await widget.addInstance(
        template: widget.template,
        startDate: selectedStart,
        trackSkyTimeZone: _previewTrackSkyTimeZone,
        eveningThresholdInitialCarry: initialCarry,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _calendarDebugPrint('[eveningThreshold] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Evening Threshold. Please retry.'),
        ),
      );
      setState(() {
        _eveningThresholdJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      await _completeJoin(id);
      return;
    }
    setState(() {
      _eveningThresholdJoinInFlight = false;
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
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
      await _completeJoin(id);
      return;
    }
    setState(() {
      _djedJoinInFlight = false;
    });
  }

  Future<void> _joinMaatDecanFlow(
    DateTime selectedStart,
    MaatDecanFlowDefinition definition,
  ) async {
    if (_maatDecanJoinInFlight) return;
    setState(() {
      _maatDecanJoinInFlight = true;
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
        _calendarDebugPrint('[${definition.key}] join failed: $e');
        _calendarDebugPrint('$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not join ${definition.title}. Please retry.'),
        ),
      );
      setState(() {
        _maatDecanJoinInFlight = false;
      });
      return;
    }

    if (!mounted) return;
    if (id > 0) {
      await _completeJoin(id);
      return;
    }
    setState(() {
      _maatDecanJoinInFlight = false;
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
      await _completeJoin(id);
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
                                          await _completeJoin(id);
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
        _MaatFlowDetailSectionLabel('$category (${events.length})'),
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

    return _buildExpandableFlowEventTile(
      title: event.title,
      subtitle: subtitle,
      detailText: detailSummary.isEmpty
          ? 'DETAIL\nNo additional preview.'
          : detailSummary,
    );
  }

  Widget _buildTemplateStickyJoinButton({
    double buttonWidth = double.infinity,
    required VoidCallback? onPressed,
    String text = 'Join Flow',
    Widget? leading,
  }) {
    return Semantics(
      button: true,
      label: text,
      child: SizedBox(
        width: buttonWidth,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: MaatFlowListTokens.pageBg,
            foregroundColor: MaatFlowListTokens.gold,
            disabledBackgroundColor: MaatFlowListTokens.pageBg,
            disabledForegroundColor: MaatFlowListTokens.joinedCategory,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            side: const BorderSide(color: MaatFlowListTokens.gold, width: 1.15),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 18)],
              Text(
                text,
                style: const TextStyle(
                  color: MaatFlowListTokens.gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMaatFlowDetailAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MaatFlowListTokens.pageBg,
      foregroundColor: MaatFlowListTokens.gold,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 58,
      leadingWidth: 64,
      iconTheme: const IconThemeData(color: MaatFlowListTokens.gold),
      leading: widget.showBackButton
          ? IconButton(
              tooltip: 'Back',
              padding: const EdgeInsets.only(left: 15),
              alignment: Alignment.centerLeft,
              icon: const Icon(
                Icons.arrow_back,
                color: MaatFlowListTokens.gold,
                size: 22,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMaatFlowDetailScaffold(
    BuildContext context, {
    required List<Widget> children,
    required Widget joinButton,
    bool appendInitialPrompt = true,
  }) {
    final initialPromptSlot = appendInitialPrompt
        ? _buildCurrentInitialPromptSlot()
        : null;
    final detailChildren = initialPromptSlot == null
        ? children
        : <Widget>[...children, initialPromptSlot];
    final media = MediaQuery.of(context);
    const ctaHeight = 52.0;
    final embedded = widget.embeddedInOnboarding;
    final scrollBottomPadding =
        ctaHeight +
        (embedded ? 0 : media.padding.bottom) +
        (embedded ? 18 : 24);
    final bodyPadding = embedded
        ? EdgeInsets.fromLTRB(16, 18, 16, scrollBottomPadding)
        : EdgeInsets.fromLTRB(14, 16, 14, scrollBottomPadding);
    final ctaPadding = embedded
        ? const EdgeInsets.fromLTRB(14, 10, 14, 14)
        : const EdgeInsets.fromLTRB(18, 14, 18, 22);
    return Scaffold(
      backgroundColor: MaatFlowListTokens.pageBg,
      appBar: embedded ? null : _buildMaatFlowDetailAppBar(context),
      body: SafeArea(
        top: !embedded,
        bottom: false,
        child: ListView(
          padding: bodyPadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: detailChildren,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: !embedded,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, MaatFlowListTokens.pageBg],
              stops: [0.0, 0.45],
            ),
          ),
          child: Padding(
            padding: ctaPadding,
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: joinButton,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildCurrentInitialPromptSlot({
    bool includeLeadingSeparator = true,
  }) {
    final spec = resolveMaatFlowInitialPromptSpec(flowKey: widget.template.key);
    if (spec == null) return null;
    return _buildMaatFlowInitialPromptSlot(
      spec,
      includeLeadingSeparator: includeLeadingSeparator,
    );
  }

  Widget _buildMaatFlowInitialPromptSlot(
    MaatFlowInitialPromptSpec spec, {
    bool includeLeadingSeparator = true,
  }) {
    assert(spec.isRenderable);
    final subtitle = spec.subtitle.trim();
    return Column(
      key: kMaatFlowInitialPromptSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeLeadingSeparator) const _MaatFlowDetailSeparator(),
        MaatFlowSurface(
          palette: _palette,
          borderRadius: BorderRadius.circular(8),
          showCrown: true,
          showTopGlow: true,
          washOpacity: 0.08,
          border: Border.all(
            color: _palette.accent.withValues(alpha: 0.26),
            width: MaatFlowListTokens.cardBorderWidth,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spec.title,
                style: TextStyle(
                  color: _palette.accent,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: MaatFlowPalette.silverMid,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              MaatFlowResponseSection(
                specs: spec.fields,
                values: _initialPromptDraftValuesForFlow(spec.flowKey),
                onChanged: _rememberInitialPromptValue,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMaatFlowOverviewZones({
    required _MaatFlowDetailContent content,
    required String tagline,
    required List<Widget> configurationControls,
    Widget? extraOverviewNote,
    Widget? initialPromptSlot,
  }) {
    final palette = _palette;
    return [
      _buildMaatFlowDetailHero(tagline: tagline),
      const SizedBox(height: 16),
      Text(
        content.orientingSentence,
        style: const TextStyle(
          color: MaatFlowPalette.silverHi,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.52,
        ),
      ),
      if (initialPromptSlot != null) ...[
        const SizedBox(height: 16),
        initialPromptSlot,
      ],
      if (extraOverviewNote != null) ...[
        const SizedBox(height: 12),
        extraOverviewNote,
      ],
      const SizedBox(height: 20),
      _buildAtAGlanceChips(content.chips),
      const _MaatFlowDetailSeparator(),
      const _MaatFlowDetailSectionLabel('THREE-DECAN ARC'),
      _buildMaatFlowArc(content.arcBlocks, palette: palette),
      const _MaatFlowDetailSeparator(),
      ...configurationControls,
      const SizedBox(height: 22),
      _buildFullDescriptionToggle(widget.template.overview),
    ];
  }

  Widget _buildMaatFlowDetailHero({required String tagline}) {
    final palette = _palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final iconSize = MaatFlowListTokens.iconSize;
        final gap = compact ? 13.0 : 15.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: Center(
                child: _MaatFlowIcon(
                  template: widget.template,
                  status: const _MaatFlowCardStatus.joined(
                    completionProgress: null,
                    statusLabel: '',
                  ),
                  detailPalette: palette,
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDateModeTitle(
                    title: widget.template.title,
                    color: MaatFlowPalette.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    height: 1.05,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MaatFlowPalette.silverHi,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      height: 1.2,
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

  Widget _buildAtAGlanceChips(List<String> chips) {
    final palette = _palette;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Semantics(
              label: chips[i],
              child: ExcludeSemantics(
                child: MaatFlowSurface(
                  palette: palette,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  showCrown: true,
                  showTopGlow: true,
                  washOpacity: 0.10,
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.28),
                    width: MaatFlowListTokens.cardBorderWidth,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chips[i],
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: palette.accent.withValues(alpha: 0.75),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 14,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaatFlowArc(
    List<_MaatFlowArcBlock> blocks, {
    required MaatFlowPalette palette,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useVertical = constraints.maxWidth < 330 || textScale > 1.3;
        if (useVertical) {
          return Column(
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                _buildMaatFlowArcCard(blocks[i], palette: palette),
                if (i < blocks.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '↓',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.accent.withValues(alpha: 0.50),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 18,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ],
          );
        }

        return MaatFlowSurface(
          palette: palette,
          borderRadius: BorderRadius.circular(14),
          showCrown: true,
          showTopGlow: true,
          washOpacity: 0.08,
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.22),
            width: MaatFlowListTokens.cardBorderWidth,
          ),
          child: SizedBox(
            height: 132,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final block in blocks)
                      Expanded(child: _buildMaatFlowArcSegment(block)),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        _MaatFlowArcDivider(palette: palette),
                        const Expanded(child: SizedBox.shrink()),
                        _MaatFlowArcDivider(palette: palette),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        _MaatFlowArcChevron(palette: palette),
                        const Expanded(child: SizedBox.shrink()),
                        _MaatFlowArcChevron(palette: palette),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaatFlowArcCard(
    _MaatFlowArcBlock block, {
    required MaatFlowPalette palette,
  }) {
    return SizedBox(
      width: double.infinity,
      child: MaatFlowSurface(
        palette: palette,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        borderRadius: BorderRadius.circular(14),
        showCrown: true,
        showTopGlow: true,
        washOpacity: 0.08,
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.22),
          width: MaatFlowListTokens.cardBorderWidth,
        ),
        child: _buildMaatFlowArcText(block),
      ),
    );
  }

  Widget _buildMaatFlowArcSegment(_MaatFlowArcBlock block) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: _buildMaatFlowArcText(block, compact: true),
    );
  }

  Widget _buildMaatFlowArcText(
    _MaatFlowArcBlock block, {
    bool compact = false,
  }) {
    final rangeSize = compact ? 9.0 : 10.0;
    final titleSize = compact ? 16.0 : 16.0;
    final actSize = compact ? 13.0 : 14.0;
    final gap = compact ? 7.0 : 8.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          block.range.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          style: TextStyle(
            color: MaatFlowPalette.silverLo,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: rangeSize,
            letterSpacing: compact ? 1.45 : 1.6,
            height: 1.1,
          ),
        ),
        SizedBox(height: gap),
        Text(
          block.title,
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          style: TextStyle(
            color: MaatFlowPalette.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        SizedBox(height: gap),
        Text(
          block.act,
          textAlign: TextAlign.center,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          style: TextStyle(
            color: MaatFlowPalette.silverMid,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: actSize,
            fontStyle: FontStyle.italic,
            height: compact ? 1.2 : 1.28,
          ),
        ),
      ],
    );
  }

  Widget _buildTimezoneSelector() {
    final palette = _palette;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: TrackSkyTimeZone.values
          .map((timezone) {
            final selected = _previewTrackSkyTimeZone == timezone;
            return ChoiceChip(
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Text(
                      '✓',
                      style: TextStyle(
                        color: MaatFlowListTokens.pageBg,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    timezone.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              selected: selected,
              onSelected: (_) => _setTrackSkyPreviewTimeZone(timezone),
              selectedColor: MaatFlowPalette.gold,
              backgroundColor: MaatFlowPalette.joinedBase,
              side: BorderSide(
                color: selected
                    ? MaatFlowPalette.gold
                    : palette.accent.withValues(alpha: 0.22),
                width: MaatFlowListTokens.cardBorderWidth,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              labelStyle: TextStyle(
                color: selected
                    ? MaatFlowListTokens.pageBg
                    : palette.accent.withValues(alpha: 0.75),
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildStartDateRow(
    BuildContext context,
    DateTime selectedStart, {
    String? label,
  }) {
    final palette = _palette;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: MaatFlowPalette.silverMid,
          side: BorderSide(
            color: palette.accent.withValues(alpha: 0.22),
            width: MaatFlowListTokens.cardBorderWidth,
          ),
          backgroundColor: MaatFlowPalette.joinedBase,
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(60),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 18,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            height: 1.1,
          ),
        ),
        onPressed: _pickDate,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label ?? _startDateButtonLabel(context, selectedStart),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChoiceChips<T>({
    required Iterable<T> values,
    required T selectedValue,
    required String Function(T value) labelFor,
    required ValueChanged<T> onSelected,
  }) {
    final palette = _palette;
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: values
          .map((value) {
            final selected = value == selectedValue;
            return ChoiceChip(
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Text(
                      '✓',
                      style: TextStyle(
                        color: MaatFlowListTokens.pageBg,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontFamilyFallback: MaatFlowListTokens.fontFallback,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    labelFor(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              selected: selected,
              onSelected: (_) => onSelected(value),
              selectedColor: MaatFlowPalette.gold,
              backgroundColor: MaatFlowPalette.joinedBase,
              side: BorderSide(
                color: selected
                    ? MaatFlowPalette.gold
                    : palette.accent.withValues(alpha: 0.22),
                width: MaatFlowListTokens.cardBorderWidth,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              labelStyle: TextStyle(
                color: selected
                    ? MaatFlowListTokens.pageBg
                    : palette.accent.withValues(alpha: 0.75),
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildFullDescriptionToggle(String description) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: _descriptionExpanded
              ? 'Collapse full description'
              : 'Expand full description',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _descriptionExpanded = !_descriptionExpanded;
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  const Expanded(
                    child: Divider(
                      color: MaatFlowPalette.separator,
                      thickness: 0.5,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'FULL DESCRIPTION',
                          style: TextStyle(
                            color: MaatFlowPalette.goldMute,
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: 12,
                            letterSpacing: 1.6,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _descriptionExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: MaatFlowPalette.goldMute,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      color: MaatFlowPalette.separator,
                      thickness: 0.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 16),
            child: Text(
              description,
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 15,
                height: 1.58,
              ),
            ),
          ),
          crossFadeState: _descriptionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }

  _MaatFlowDetailContent _detailContentForTemplate({
    required List<String>? overrideChips,
  }) {
    final content = _baseDetailContentForTemplate(widget.template.kind);
    if (overrideChips == null) return content;
    return _MaatFlowDetailContent(
      orientingSentence: content.orientingSentence,
      chips: overrideChips,
      arcBlocks: content.arcBlocks,
    );
  }

  _MaatFlowDetailContent _baseDetailContentForTemplate(
    _MaatFlowTemplateKind kind,
  ) {
    switch (kind) {
      case _MaatFlowTemplateKind.trackSky:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Sky observation flow. Track visible sky events and keep one clear line of witness when the sky changes.',
          chips: [
            'Through final event',
            'Seasonal events',
            'Step outside and observe',
          ],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: '4 events',
              title: 'Solar Events',
              act: 'Solstices and equinoxes',
            ),
            _MaatFlowArcBlock(
              range: 'Monthly',
              title: 'Lunar Events',
              act: 'Moon phases and peaks',
            ),
            _MaatFlowArcBlock(
              range: 'As they occur',
              title: 'Sky Events',
              act: 'Meteors and planetary highlights',
            ),
          ],
        );
      case _MaatFlowTemplateKind.dawnHouseRite:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Morning intention and purification ritual. Commit one purifying act and speak one mantra before the day begins.',
          chips: ['Daily practice', 'Dawn timing', '10 minutes or less'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Each dawn',
              title: 'Water',
              act: 'Place and acknowledge it',
            ),
            _MaatFlowArcBlock(
              range: 'Each dawn',
              title: 'Light',
              act: 'Name what the day opens into',
            ),
            _MaatFlowArcBlock(
              range: 'Each dawn',
              title: 'One Act',
              act: 'One right thing before anything else',
            ),
          ],
        );
      case _MaatFlowTemplateKind.eveningThreshold:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Each evening, return to the morning measure, name what happened, then choose what crosses into tomorrow.',
          chips: ['Daily practice', '7 PM local', 'Two taps'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Event 1',
              title: 'The Return',
              act: 'Name how the morning measure landed',
            ),
            _MaatFlowArcBlock(
              range: 'Event 2',
              title: 'The Carry',
              act: 'Carry forward or release completely',
            ),
            _MaatFlowArcBlock(
              range: 'Tomorrow',
              title: 'The Threshold',
              act: 'Only what was carried follows',
            ),
          ],
        );
      case _MaatFlowTemplateKind.eveningThresholdRite:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Evening release ritual. Close one loop, settle the house, and leave the day at the threshold.',
          chips: ['Daily practice', 'Sunset timing', '10 minutes or less'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Each evening',
              title: 'Close',
              act: 'Name what is finished',
            ),
            _MaatFlowArcBlock(
              range: 'Each evening',
              title: 'Witness',
              act: 'What moved today',
            ),
            _MaatFlowArcBlock(
              range: 'Each evening',
              title: 'Cross',
              act: 'Step into night with intention',
            ),
          ],
        );
      case _MaatFlowTemplateKind.theWeighing:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Reckoning practice. Put one material, spoken, or conduct record on the scale and name one correction.',
          chips: ['30 days', '3 sittings per decan', 'Written record'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Days 1-10',
              title: 'Material Ledger',
              act: 'What you have and owe',
            ),
            _MaatFlowArcBlock(
              range: 'Days 11-20',
              title: 'Spoken Record',
              act: 'What you said and kept',
            ),
            _MaatFlowArcBlock(
              range: 'Days 21-30',
              title: 'Record You Leave',
              act: 'What you show by how you move',
            ),
          ],
        );
      case _MaatFlowTemplateKind.offeringTable:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Provision ritual. Begin with water, then feed what needs food, rest, or care.',
          chips: ['Daily practice', 'Any time of day', 'Physical acts'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'First',
              title: 'Water',
              act: 'Drink before anything else',
            ),
            _MaatFlowArcBlock(
              range: 'Second',
              title: 'Food and Rest',
              act: 'Fuel and recovery',
            ),
            _MaatFlowArcBlock(
              range: 'Third',
              title: 'Care',
              act: 'What the people around you need',
            ),
          ],
        );
      case _MaatFlowTemplateKind.theTending:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Specific care practice. Name who or what needs tending and complete one concrete act of care.',
          chips: ['Each decan', 'One person or place', 'Concrete labor'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Days 1-3',
              title: 'Find',
              act: 'Identify who or what needs tending',
            ),
            _MaatFlowArcBlock(
              range: 'Days 4-9',
              title: 'Do',
              act: 'The actual labor',
            ),
            _MaatFlowArcBlock(
              range: 'Day 10',
              title: 'Confirm',
              act: 'Did it land? Was it received?',
            ),
          ],
        );
      case _MaatFlowTemplateKind.keptWord:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Agreement practice. Name one word, repair, or conversation that needs clearer order.',
          chips: ['Each decan', 'Spoken record', 'Honest accounting'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Days 1-3',
              title: 'Name',
              act: 'What was said and not kept',
            ),
            _MaatFlowArcBlock(
              range: 'Days 4-9',
              title: 'Weigh',
              act: 'What the gap actually cost',
            ),
            _MaatFlowArcBlock(
              range: 'Day 10',
              title: 'Restore',
              act: 'One act toward right order',
            ),
          ],
        );
      case _MaatFlowTemplateKind.theCourse:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Time-orientation practice. Locate yourself in the day, decan, and season, then choose one fitting action.',
          chips: [
            '30 days · 9 sittings',
            '3 times per decan',
            'One act per sitting',
          ],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Days 1-10',
              title: 'Daily Course',
              act: 'Where you are in the day',
            ),
            _MaatFlowArcBlock(
              range: 'Days 11-20',
              title: 'Decan Course',
              act: 'Where you are in the decan',
            ),
            _MaatFlowArcBlock(
              range: 'Days 21-30',
              title: 'Seasonal Course',
              act: 'Where you are in the season',
            ),
          ],
        );
      case _MaatFlowTemplateKind.moonReturn:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Lunar release and return practice. Set something down at the new moon and notice what fills at the full.',
          chips: [
            'New moon window',
            'Lunar observations',
            'Observed or skipped',
          ],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'New moon',
              title: 'Empty Eye',
              act: 'Begin from dark and mark the opening',
            ),
            _MaatFlowArcBlock(
              range: 'Waxing',
              title: 'Returning Light',
              act: 'Observe what becomes visible',
            ),
            _MaatFlowArcBlock(
              range: 'Fullness',
              title: 'Record',
              act: 'Keep the honest lunar account',
            ),
          ],
        );
      case _MaatFlowTemplateKind.theWag:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Ancestor remembrance cycle. Keep the table, carry a gift or memory, and return with what remains.',
          chips: ['Annual window', 'Month 1 events', 'Ancestor rite'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Opening',
              title: 'Vigil',
              act: 'Hold the threshold of the year',
            ),
            _MaatFlowArcBlock(
              range: 'Middle',
              title: 'Procession',
              act: 'Name and tend the honored dead',
            ),
            _MaatFlowArcBlock(
              range: 'Feast',
              title: 'Return',
              act: 'Close with provision and memory',
            ),
          ],
        );
      case _MaatFlowTemplateKind.decanWatch:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Night-sky boundary practice. Watch the decan opening honestly and carry one bearing into the next ten days.',
          chips: ['Decan openings', 'Night watch', 'Outdoor or threshold'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Opening',
              title: 'Step Out',
              act: 'Meet the decan boundary',
            ),
            _MaatFlowArcBlock(
              range: 'Watch',
              title: 'Observe',
              act: 'Name what the sky allows',
            ),
            _MaatFlowArcBlock(
              range: 'Record',
              title: 'Keep',
              act: 'Mark the honest completion state',
            ),
          ],
        );
      case _MaatFlowTemplateKind.daysOutsideTheYear:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Year-threshold practice. Close the old year, receive the outside days, and open Wep Ronpet cleanly.',
          chips: ['Year-closing window', 'Seven events', 'Wep Ronpet opening'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'M12 D30',
              title: 'Close',
              act: 'Seal the year at dusk',
            ),
            _MaatFlowArcBlock(
              range: 'M13 D1-D5',
              title: 'Outside',
              act: 'Keep the birth days apart',
            ),
            _MaatFlowArcBlock(
              range: 'M1 D1',
              title: 'Open',
              act: 'Enter Wep Ronpet cleanly',
            ),
          ],
        );
      case _MaatFlowTemplateKind.theOpenHand:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Outward provision practice. Meet one visible need with time, care, skill, resource, or protection.',
          chips: ['9 sittings', 'Provision acts', 'Act first'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'Open',
              title: 'See Need',
              act: 'Name the provision required',
            ),
            _MaatFlowArcBlock(
              range: 'Middle',
              title: 'Give',
              act: 'Put the resource into the world',
            ),
            _MaatFlowArcBlock(
              range: 'Close',
              title: 'Account',
              act: 'Record what was received',
            ),
          ],
        );
      case _MaatFlowTemplateKind.theDjed:
        return const _MaatFlowDetailContent(
          orientingSentence:
              'Stability practice. Name what must stand upright and restore one load-bearing part of life.',
          chips: ['9 sittings', 'Stability work', 'Stand and raise'],
          arcBlocks: [
            _MaatFlowArcBlock(
              range: 'First',
              title: 'Name',
              act: 'Find the spine of the matter',
            ),
            _MaatFlowArcBlock(
              range: 'Second',
              title: 'Contest',
              act: 'Meet the wobble directly',
            ),
            _MaatFlowArcBlock(
              range: 'Third',
              title: 'Raise',
              act: 'Stand the structure back up',
            ),
          ],
        );
      case _MaatFlowTemplateKind.maatDecan:
        final definition = maatDecanFlowDefinitionForKey(widget.template.key);
        return _MaatFlowDetailContent(
          orientingSentence: definition == null
              ? widget.template.overview
              : _maatDecanDetailShortDescription(definition),
          chips: const ['9 sittings', 'Decan window', 'One act per sitting'],
          arcBlocks: const [
            _MaatFlowArcBlock(
              range: 'Opening',
              title: 'Locate',
              act: 'Enter the decan with the assigned work',
            ),
            _MaatFlowArcBlock(
              range: 'Middle',
              title: 'Act',
              act: 'Carry the work into the day',
            ),
            _MaatFlowArcBlock(
              range: 'Closing',
              title: 'Record',
              act: 'Seal what changed',
            ),
          ],
        );
      default:
        return _MaatFlowDetailContent(
          orientingSentence: widget.template.overview,
          chips: const ['Guided practice', 'Calendar flow', 'Written record'],
          arcBlocks: const [
            _MaatFlowArcBlock(
              range: 'Begin',
              title: 'Open',
              act: 'Start with the first scheduled act',
            ),
            _MaatFlowArcBlock(
              range: 'Continue',
              title: 'Keep',
              act: 'Return to the rhythm',
            ),
            _MaatFlowArcBlock(
              range: 'Complete',
              title: 'Seal',
              act: 'Close the record clearly',
            ),
          ],
        );
    }
  }

  String _maatDecanDetailShortDescription(MaatDecanFlowDefinition definition) {
    switch (definition.key) {
      case kFairHearingFlowKey:
        return 'Fairness practice. Hear fully before deciding, keep the measure even, and pronounce what is clear.';
      case kFirstArrangementFlowKey:
        return 'Space-order practice. Choose one physical space, see what belongs, and put it back into order.';
      case kLivingPatternFlowKey:
        return 'Observation practice. Watch one natural pattern patiently and carry its principle into action.';
      case kHouseOfLifeFlowKey:
        return 'Knowledge practice. Learn accurately, preserve one useful note, and transmit it with care.';
      case kBoundaryStoneFlowKey:
        return 'Boundary practice. Name what moved, restore one marker, and return measure to its place.';
      case kHotepFlowKey:
        return 'Evening peace practice. Name what was given, release what is enough, and cool the heart before sleep.';
      case kOpenMouthFlowKey:
        return 'Speech practice. Govern one word, repair what needs repair, and let speech serve Ma’at.';
      case kLivingRecordFlowKey:
        return 'Record practice. Turn one decan into a living record across calendar, journal, and body.';
      case kHetHeruFlowKey:
        return 'Cooling practice. Meet the hot force with beauty, joy, rest, or feast until it returns.';
      case kTheShoreFlowKey:
        return 'Exchange practice. Bring one gift, labor, or return closer to honest measure.';
      case kTheAutobiographyFlowKey:
        return 'Life-record practice. Name one capacity, work, gift, or claim with clearer evidence.';
      case kTrueNameFlowKey:
        return 'Private naming practice. Measure a false account against the record and stand closer to the accurate name.';
      case kLivingTextFlowKey:
        return 'Library practice. Let one line become question, insight, application, or living mark.';
      case kClearingFlowKey:
        return 'Temperance practice. Make space before response and act from the cleared place.';
      case kWanderingFlowKey:
        return 'Grief accompaniment. Honor what was lost and notice one thing that remains.';
      case kKhatFlowKey:
        return 'Body-care practice. Listen to what the body asks and answer with one concrete act of care.';
      case kOracleFlowKey:
        return 'Dream-question practice. Carry one question, receive without forcing meaning, and test through grounded action.';
      default:
        return definition.routingSummary;
    }
  }

  Widget _buildExpandableFlowEventTile({
    required String title,
    required String subtitle,
    required String detailText,
    List<String> badges = const <String>[],
    Color borderColor = Colors.white12,
    Color badgeAccent = _gold,
  }) {
    final palette = _palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MaatFlowSurface(
        palette: palette,
        borderRadius: BorderRadius.circular(14),
        showCrown: false,
        showTopGlow: true,
        washOpacity: 0.07,
        border: Border.all(
          color: borderColor == Colors.white12
              ? palette.accent.withValues(alpha: 0.22)
              : borderColor,
          width: MaatFlowListTokens.cardBorderWidth,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            collapsedIconColor: MaatFlowListTokens.joinedChevron,
            iconColor: MaatFlowListTokens.joinedChevron,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              title,
              style: const TextStyle(
                color: MaatFlowPalette.gold,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: MaatFlowPalette.silverMid,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildEventBadgeRow(badges, accent: badgeAccent),
                  ],
                ],
              ),
            ),
            children: [
              SizedBox(
                width: double.infinity,
                child: _buildMaatFlowDetailSections(detailText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaatFlowSittingTile({
    required String title,
    required String subtitle,
    required String detailText,
    Color? borderColor,
  }) {
    final palette = _palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MaatFlowSurface(
        palette: palette,
        borderRadius: BorderRadius.circular(14),
        showCrown: false,
        showTopGlow: true,
        washOpacity: 0.07,
        border: Border.all(
          color: borderColor ?? palette.accent.withValues(alpha: 0.22),
          width: MaatFlowListTokens.cardBorderWidth,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 3,
            ),
            collapsedIconColor: MaatFlowListTokens.joinedChevron,
            iconColor: MaatFlowListTokens.joinedChevron,
            childrenPadding: EdgeInsets.zero,
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MaatFlowPalette.gold,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MaatFlowPalette.silverMid,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.25,
                ),
              ),
            ),
            children: [
              const Divider(
                height: 1,
                thickness: 0.5,
                color: MaatFlowPalette.separator,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                child: _buildMaatFlowDetailSections(detailText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaatFlowDetailSections(String detailText) {
    final sections = detailText
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .map((section) => section.trim())
        .where((section) => section.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) _buildMaatFlowDetailSection(section),
      ],
    );
  }

  Widget _buildMaatFlowNotice(
    String text, {
    Color? borderColor,
    Color textColor = MaatFlowPalette.silverMid,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final palette = _palette;
    return MaatFlowSurface(
      palette: palette,
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(14),
      showCrown: false,
      showTopGlow: true,
      washOpacity: 0.08,
      border: Border.all(
        color: borderColor ?? palette.accent.withValues(alpha: 0.24),
        width: MaatFlowListTokens.cardBorderWidth,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 13,
          fontWeight: fontWeight,
          height: 1.38,
        ),
      ),
    );
  }

  Widget _buildMaatFlowDetailText(
    String text, {
    Color color = MaatFlowPalette.silverMid,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontFamily: MaatFlowListTokens.fontFamily,
        fontFamilyFallback: MaatFlowListTokens.fontFallback,
        fontSize: fontSize,
        fontStyle: FontStyle.italic,
        fontWeight: fontWeight,
        height: 1.35,
      ),
    );
  }

  Widget _buildWindowStartRow(BuildContext context, DateTime windowStart) {
    return _buildStartDateRow(
      context,
      windowStart,
      label: 'Window opens: ${_dateLabel(context, windowStart)}',
    );
  }

  void _showMaatFlowInfoBubble({required String title, required String text}) {
    final palette = _palette;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss $title information',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).maybePop(),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 118, 18, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: MaatFlowSurface(
                      palette: palette,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                      borderRadius: BorderRadius.circular(14),
                      showCrown: true,
                      showTopGlow: true,
                      washOpacity: 0.12,
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.42),
                        width: MaatFlowListTokens.cardBorderWidth,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: MaatFlowPalette.gold,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: const TextStyle(
                              color: MaatFlowPalette.silverHi,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.38,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaatFlowSwitchSurface({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    String? subtitle,
    String? infoText,
    String? infoTooltip,
  }) {
    final palette = _palette;
    final cleanSubtitle = subtitle?.trim() ?? '';
    return MaatFlowSurface(
      palette: palette,
      borderRadius: BorderRadius.circular(14),
      showCrown: false,
      showTopGlow: true,
      washOpacity: 0.07,
      border: Border.all(
        color: palette.accent.withValues(alpha: 0.22),
        width: MaatFlowListTokens.cardBorderWidth,
      ),
      child: SwitchListTile.adaptive(
        value: value,
        activeThumbColor: MaatFlowPalette.gold,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: MaatFlowPalette.gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (infoText != null && infoText.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: infoTooltip ?? 'About $title',
                child: IconButton(
                  tooltip: infoTooltip ?? 'About $title',
                  icon: _buildMaatFlowInfoGlyph(
                    color: palette.accent.withValues(alpha: 0.90),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () => _showMaatFlowInfoBubble(
                    title: title,
                    text: infoText.trim(),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: cleanSubtitle.isEmpty
            ? null
            : Text(
                cleanSubtitle,
                style: const TextStyle(
                  color: MaatFlowPalette.silverMid,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMaatFlowInfoGlyph({required Color color}) {
    return SizedBox.square(
      dimension: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.15),
        ),
        child: Center(
          child: Text(
            'i',
            style: TextStyle(
              color: color,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaatFlowDetailSection(String section) {
    final firstLineEnd = section.indexOf('\n');
    final label = firstLineEnd == -1
        ? ''
        : section.substring(0, firstLineEnd).trim();
    final body = firstLineEnd == -1
        ? section.trim()
        : section.substring(firstLineEnd + 1).trim();
    final normalized = label.toUpperCase();
    final isWords = normalized == 'WORDS';
    final isSteps = normalized == 'STEPS';
    final bodyStyle = TextStyle(
      color: isWords ? MaatFlowPalette.silverMid : MaatFlowPalette.silverHi,
      fontFamily: MaatFlowListTokens.fontFamily,
      fontFamilyFallback: MaatFlowListTokens.fontFallback,
      fontSize: 15,
      fontWeight: isWords ? FontWeight.w500 : FontWeight.w400,
      fontStyle: isWords ? FontStyle.italic : FontStyle.normal,
      height: isSteps ? 1.7 : 1.56,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              normalized,
              style: const TextStyle(
                color: MaatFlowPalette.interiorLabel,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
          ],
          isSteps
              ? _buildMaatFlowStepsText(body, bodyStyle)
              : Text(body, style: bodyStyle),
        ],
      ),
    );
  }

  Widget _buildMaatFlowStepsText(String body, TextStyle bodyStyle) {
    final spans = <TextSpan>[];
    final numberPattern = RegExp(r'(^|\n)(\d+\.)');
    var cursor = 0;
    for (final match in numberPattern.allMatches(body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, match.start)));
      }
      final prefix = match.group(1);
      if (prefix != null && prefix.isNotEmpty) {
        spans.add(TextSpan(text: prefix));
      }
      spans.add(
        TextSpan(
          text: match.group(2),
          style: bodyStyle.copyWith(color: MaatFlowPalette.silverLo),
        ),
      );
      cursor = match.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }
    return Text.rich(TextSpan(style: bodyStyle, children: spans));
  }

  Widget _buildEventBadgeRow(List<String> badges, {required Color accent}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges
          .map((badge) => _buildEventBadge(badge, accent: accent))
          .toList(growable: false),
    );
  }

  Widget _buildEventBadge(String label, {required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.75), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTrackSkyScaffold(BuildContext context) {
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        onPressed: _openTrackSkyJoinSheet,
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: widget.template.subtitle,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            FutureBuilder<TrackSkyFlowData>(
              future: _trackSkyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MaatFlowPalette.gold,
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMaatFlowNotice('Could not load sky events.'),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MaatFlowPalette.gold,
                          side: const BorderSide(
                            color: MaatFlowPalette.gold,
                            width: 1.1,
                          ),
                        ),
                        onPressed: () => _setTrackSkyPreviewTimeZone(
                          _previewTrackSkyTimeZone,
                          forceReload: true,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMaatFlowDetailText(
                      upcoming.isEmpty
                          ? 'No upcoming sky events remain.'
                          : 'Previewing ${upcoming.length} upcoming events${firstDate == null || lastDate == null ? '' : ' • $firstDate -> $lastDate'}.',
                    ),
                    const SizedBox(height: 8),
                    _buildMaatFlowDetailText(
                      'Only events with a usable viewing window are included. You can confirm alert settings from the Join Flow button.',
                      color: MaatFlowPalette.silverLo,
                      fontSize: 13,
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
          ],
        ),
        const _MaatFlowPracticeDisclaimerFooter(),
      ],
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
    return _buildMaatFlowSittingTile(
      title: dawnHouseRiteEventTitle(day),
      subtitle: day.section,
      detailText: detail,
    );
  }

  Widget _buildDawnHouseRiteScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultDawnHouseRiteStartDate(_previewTrackSkyTimeZone);
    final firstSchedule = dawnHouseRiteScheduleForDate(
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _dawnJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _dawnJoinInFlight
            ? null
            : () => _joinDawnHouseRiteFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: widget.template.subtitle,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 12),
            _buildMaatFlowSwitchSurface(
              value: _dawnDiscreetMode,
              title: 'Discreet mode',
              infoTooltip: 'About Discreet mode',
              infoText:
                  'Changes wording only. Turn this on when the rite needs to look ordinary in public or shared space; event text avoids visible ritual terms such as altar, shrine, offering, incense, flame, deity names, and ma’at.',
              onChanged: (value) {
                setState(() {
                  _dawnDiscreetMode = value;
                });
              },
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<DawnHouseRiteLens>(
              values: DawnHouseRiteLens.values,
              selectedValue: _dawnLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _dawnLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _dawnLensExplanation(_dawnLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('30-DAY OUTLINE'),
        ...kDawnHouseRiteDays.map(
          (day) => _buildDawnHouseRiteDayTile(context, day),
        ),
        const _MaatFlowPracticeDisclaimerFooter(),
      ],
    );
  }

  Widget _buildEveningThresholdEventTile(
    BuildContext context,
    EveningThresholdEvent event,
  ) {
    return _buildMaatFlowSittingTile(
      title: eveningThresholdEventTitle(event),
      subtitle: event.eventNumber == 1
          ? 'Evening landing for today\'s carry'
          : 'Morning crossing from yesterday\'s landing',
      detailText: eveningThresholdDetailText(event),
    );
  }

  Widget _buildEveningThresholdScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultEveningThresholdStartDate(_previewTrackSkyTimeZone);
    final initialCarryReady = _eveningThresholdInitialCarryController.text
        .trim()
        .isNotEmpty;
    final firstEvent = kEveningThresholdEvents.first;
    final firstSchedule = dailyEveningThresholdScheduleForDate(
      localDate: selectedStart,
      timezone: _previewTrackSkyTimeZone,
      event: firstEvent,
    );
    final finalSchedule = dailyEveningThresholdScheduleForDate(
      localDate: selectedStart.add(
        const Duration(days: kEveningThresholdMaterializedDays - 1),
      ),
      timezone: _previewTrackSkyTimeZone,
      event: kEveningThresholdEvents.last,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final finalTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: finalSchedule.endLocal.hour,
        minute: finalSchedule.endLocal.minute,
      ),
    );

    return _buildMaatFlowDetailScaffold(
      context,
      joinButton: _buildTemplateStickyJoinButton(
        text: _eveningThresholdJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _eveningThresholdJoinInFlight || !initialCarryReady
            ? null
            : () => _joinEveningThresholdFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(
            overrideChips: const <String>[
              'Evening landing',
              'Morning crossing',
              'Carry text',
            ],
          ),
          tagline: widget.template.subtitle,
          configurationControls: [
            const _MaatFlowDetailSectionLabel('WHAT DO YOU CARRY TODAY?'),
            TextField(
              controller: _eveningThresholdInitialCarryController,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 15,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: 'What do you carry today?',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.36),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.28),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _palette.accent.withValues(alpha: 0.28),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _palette.accent),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _MaatFlowDetailSectionLabel('TIMEZONE'),
            _buildTimezoneSelector(),
            const SizedBox(height: 14),
            Text(
              'Starts ${_dateLabel(context, selectedStart)} at $firstTime in ${_previewTrackSkyTimeZone.label}. The installed window runs $kEveningThresholdMaterializedDays evening landings and $kEveningThresholdMaterializedDays next-morning crossing decisions, ending ${_dateLabel(context, finalSchedule.endLocal)} at $finalTime.',
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The evening event carries the 7:00 PM reminder. The crossing decision appears the next morning and remains an explicit choice.',
              style: TextStyle(
                color: MaatFlowPalette.silverLo,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _buildStartDateRow(context, selectedStart),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('DAILY THRESHOLD'),
        ...kEveningThresholdEvents.map(
          (event) => _buildEveningThresholdEventTile(context, event),
        ),
      ],
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
    return _buildMaatFlowSittingTile(
      title: eveningThresholdRiteEventTitle(day),
      subtitle: day.section,
      detailText: detail,
    );
  }

  Widget _buildEveningThresholdRiteScaffold(BuildContext context) {
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
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final fallbackTime = l10n.formatTimeOfDay(
      _timeOfDayFromMinutes(_eveningFallbackMinutes),
    );
    final palette = _palette;
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _eveningJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _eveningJoinInFlight
            ? null
            : () => _joinEveningThresholdRiteFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: widget.template.subtitle,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: MaatFlowPalette.silverMid,
                  side: BorderSide(
                    color: palette.accent.withValues(alpha: 0.22),
                    width: MaatFlowListTokens.cardBorderWidth,
                  ),
                  backgroundColor: MaatFlowPalette.joinedBase,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    height: 1.1,
                  ),
                ),
                onPressed: _pickEveningFallbackTime,
                child: Text(
                  'Fallback: $fallbackTime',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildMaatFlowSwitchSurface(
              value: _eveningDiscreetMode,
              title: 'Discreet mode',
              infoTooltip: 'About Discreet mode',
              infoText:
                  'Changes wording only. Turn this on when the rite needs to look ordinary in public or shared space; event text avoids visible ritual terms such as altar, offering, incense, flame, and spoken recitation.',
              onChanged: (value) {
                setState(() {
                  _eveningDiscreetMode = value;
                });
              },
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<EveningThresholdRiteLens>(
              values: EveningThresholdRiteLens.values,
              selectedValue: _eveningLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _eveningLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _eveningLensExplanation(_eveningLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('30-DAY OUTLINE'),
        ...kEveningThresholdRiteDays.map(
          (day) => _buildEveningThresholdRiteDayTile(context, day),
        ),
        const _MaatFlowPracticeDisclaimerFooter(),
      ],
    );
  }

  Widget _buildTheWeighingEventTile(
    BuildContext context,
    TheWeighingEvent event,
  ) {
    final detail = theWeighingDetailText(event, lens: _theWeighingLens);
    return _buildMaatFlowSittingTile(
      title: theWeighingEventTitle(event),
      subtitle: '${event.decanSection} · ${theWeighingTimingLabel(event)}',
      detailText: detail,
    );
  }

  Widget _buildTheWeighingScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultTheWeighingStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kTheWeighingEvents.first;
    final firstSchedule = theWeighingScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _theWeighingJoinInFlight ? 'Joining…' : 'Join Flow',
        leading: _MaatFlowGlyphTile(
          template: widget.template,
          palette: _palette,
        ),
        onPressed: _theWeighingJoinInFlight
            ? null
            : () => _joinTheWeighingFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kTheWeighingTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<TheWeighingLens>(
              values: TheWeighingLens.values,
              selectedValue: _theWeighingLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _theWeighingLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _theWeighingLensExplanation(_theWeighingLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('9 SITTINGS'),
        ...kTheWeighingEvents.map(
          (event) => _buildTheWeighingEventTile(context, event),
        ),
        const _MaatFlowPrivacyFooter(),
      ],
    );
  }

  Widget _buildTheTendingEventTile(
    BuildContext context,
    TheTendingEvent event,
  ) {
    final detail = theTendingDetailText(event, lens: _theTendingLens);
    return _buildMaatFlowSittingTile(
      title: theTendingEventTitle(event),
      subtitle: '${event.decanSection} · ${theTendingTimingLabel(event)}',
      detailText: detail,
    );
  }

  Widget _buildTheTendingScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultTheTendingStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kTheTendingEvents.first;
    final firstSchedule = theTendingScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _theTendingJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _theTendingJoinInFlight
            ? null
            : () => _joinTheTendingFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kTheTendingTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<TheTendingLens>(
              values: TheTendingLens.values,
              selectedValue: _theTendingLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _theTendingLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _theTendingLensExplanation(_theTendingLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('9 SITTINGS'),
        ...kTheTendingEvents.map(
          (event) => _buildTheTendingEventTile(context, event),
        ),
        const _MaatFlowPrivacyFooter(),
      ],
    );
  }

  Widget _buildKeptWordEventTile(BuildContext context, KeptWordEvent event) {
    final detail = keptWordDetailText(event, lens: _keptWordLens);
    return _buildMaatFlowSittingTile(
      title: keptWordEventTitle(event),
      subtitle: '${event.decanSection} · ${keptWordTimingLabel(event)}',
      detailText: detail,
      borderColor: event.requiresConversation ? const Color(0xFF8B7355) : null,
    );
  }

  Widget _buildKeptWordScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultKeptWordStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kKeptWordEvents.first;
    final firstSchedule = keptWordScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _keptWordJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _keptWordJoinInFlight
            ? null
            : () => _joinKeptWordFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kKeptWordTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<KeptWordLens>(
              values: KeptWordLens.values,
              selectedValue: _keptWordLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _keptWordLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _keptWordLensExplanation(_keptWordLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('9 SITTINGS'),
        ...kKeptWordEvents.map(
          (event) => _buildKeptWordEventTile(context, event),
        ),
        _buildMaatFlowNotice(
          'Bring to Process: Events 4-6 involve another person. If the conversation cannot be had safely, pause the flow locally rather than forcing contact.',
          borderColor: MaatFlowPalette.gold.withValues(alpha: 0.38),
        ),
        const SizedBox(height: 10),
        const _MaatFlowPrivacyFooter(),
      ],
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
    return _buildMaatFlowSittingTile(
      title: courseEventTitle(event),
      subtitle:
          '${event.decanSection} · ${courseTimingLabel(event)} · ${courseContext.seasonLabel}',
      detailText: detail,
      borderColor: event.scheduleKind == CourseScheduleKind.solarDusk
          ? const Color(0xFFE8B84A)
          : event.seasonAware
          ? const Color(0xFF6FC2A1)
          : null,
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
    final title = moonReturnEventTitle(occurrence);
    final subtitle =
        '${_dateLabel(context, occurrence.startLocal)} at $time • ${occurrence.variant.label}';
    final highlight = occurrence.variant != MoonReturnCopyVariant.standard;
    final accent = highlight ? const Color(0xFF8FA8FF) : _silver;
    final badges = <String>[if (highlight) occurrence.variant.label];
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: moonReturnDetailText(occurrence, lens: _moonReturnLens),
      badges: badges,
      borderColor: highlight ? accent : Colors.white12,
      badgeAccent: accent,
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
    final highlight =
        event.kind == WagEventKind.vigil || event.kind == WagEventKind.feast;
    final badges = <String>[
      if (event.kind == WagEventKind.vigil) 'Vigil',
      if (event.kind == WagEventKind.feast) 'Feast',
    ];
    final title = wagEventTitle(event);
    final subtitle =
        '${wagTimingLabel(event)} • ${_dateLabel(context, schedule.startLocal)} at $time';
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: wagDetailText(event, lens: _wagLens),
      badges: badges,
      borderColor: highlight ? _gold : Colors.white12,
      badgeAccent: _gold,
    );
  }

  Widget _buildWagScaffold(BuildContext context) {
    final WagEnrollmentWindow? window = _resolveWagPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(context, debugLabel: 'theWag');
    }
    final selectedStart = DateUtils.dateOnly(window.opensAtLocal);
    final nextFeast = wagNextFeastGregorian(window.kYear);
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _wagJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _wagJoinInFlight ? null : () => _joinWagFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kTheWagTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<WagLens>(
              values: WagLens.values,
              selectedValue: _wagLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _wagLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildMaatFlowDetailText(_wagLensExplanation(_wagLens)),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('MONTH 1 EVENTS'),
        ...kWagEvents.map(
          (event) => _buildWagEventTile(context, event, window.kYear),
        ),
        _buildMaatFlowDetailText(
          'Wag feast this cycle: ${_dateLabel(context, wagEventGregorian(window.kYear, 18))}. Next year: ${_dateLabel(context, nextFeast)}.',
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
        ),
        const SizedBox(height: 10),
        const _MaatFlowPrivacyFooter(),
      ],
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
    final title = decanWatchEventTitle(occurrence);
    final subtitle =
        'M${occurrence.kMonth} D${occurrence.decanStartDay} · ${_dateLabel(context, occurrence.startLocal)} at $time';
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: decanWatchDetailText(occurrence, lens: _decanWatchLens),
    );
  }

  Widget _buildDecanWatchScaffold(BuildContext context) {
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
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _decanWatchJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _decanWatchJoinInFlight
            ? null
            : () => _joinDecanWatchFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kDecanWatchTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<DecanWatchLens>(
              values: DecanWatchLens.values,
              selectedValue: _decanWatchLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _decanWatchLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildMaatFlowDetailText(
              _decanWatchLensExplanation(_decanWatchLens),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('NEXT WATCHES'),
        ...preview.map(
          (occurrence) => _buildDecanWatchOccurrenceTile(context, occurrence),
        ),
        _buildMaatFlowDetailText(
          'Default watch time is 9:00 PM local. Editing is clamped to 6:00 PM-midnight.',
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'Outdoor is the default. If weather, safety, access, or mobility prevents that, use the inside/threshold completion state and keep the record honest.',
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'The Course orients you by day. The Decan Watch orients you by night. Many keep both.',
        ),
        const SizedBox(height: 10),
        const _MaatFlowPrivacyFooter(),
      ],
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
    final badges = <String>[
      if (event.requiresOutwardAct) 'Action',
      if (event.strangerAct) 'Stranger act',
    ];
    final title = openHandEventTitle(event);
    final subtitle =
        '${openHandTimingLabel(event)} · ${_dateLabel(context, schedule.startLocal)} at $time${event.requiresOutwardAct ? ' · act first' : ''}';
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: openHandDetailText(event, lens: _openHandLens),
      badges: badges,
      borderColor: event.requiresOutwardAct ? _gold : Colors.white12,
      badgeAccent: _gold,
    );
  }

  DecanWatchEnrollmentWindow? _resolveMaatDecanPreviewWindow() {
    return _tryEnrollmentWindow('maatDecan:${widget.template.key}', () {
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

  Widget _buildMaatDecanFlowEventTile(
    BuildContext context,
    MaatDecanFlowDefinition definition,
    MaatDecanFlowEvent event,
    DateTime flowStart,
  ) {
    final schedule = maatDecanFlowScheduleForEvent(
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
    final highlight =
        event.requiresRealWorldAction ||
        event.extraCompletionStatusLabels.isNotEmpty;
    final badges = <String>[
      if (event.requiresRealWorldAction) 'Action',
      if (event.extraCompletionStatusLabels.isNotEmpty) 'Milestone',
    ];
    final title = maatDecanFlowEventTitle(definition, event);
    final subtitle =
        '${maatDecanFlowTimingLabel(event)} · ${_dateLabel(context, schedule.startLocal)} at $time${event.requiresRealWorldAction ? ' · act first' : ''}';
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: maatDecanFlowDetailText(definition, event),
      badges: badges,
      borderColor: highlight ? _gold : Colors.white12,
      badgeAccent: _gold,
    );
  }

  Widget _buildMaatDecanFlowScaffold(BuildContext context) {
    final definition = maatDecanFlowDefinitionForKey(widget.template.key);
    if (definition == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: 'maatDecan:${widget.template.key}',
      );
    }
    final DecanWatchEnrollmentWindow? window = _resolveMaatDecanPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: definition.key,
      );
    }
    final flowStart = DateUtils.dateOnly(window.opensAtLocal);
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      joinButton: _buildTemplateStickyJoinButton(
        text: _maatDecanJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _maatDecanJoinInFlight
            ? null
            : () => _joinMaatDecanFlow(flowStart, definition),
      ),
      appendInitialPrompt: false,
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: definition.tagline,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
          ],
          initialPromptSlot: initialPromptSlot,
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('NINE SITTINGS'),
        ...definition.events.map(
          (event) => _buildMaatDecanFlowEventTile(
            context,
            definition,
            event,
            flowStart,
          ),
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'Selected decan opening: ${_dateLabel(context, window.opensAtLocal)}, when ${window.openingOccurrence.decanName} begins. Add it now and the nine sittings will prompt from that start date.',
          borderColor: MaatFlowPalette.gold.withValues(alpha: 0.38),
        ),
        const SizedBox(height: 10),
        _buildMaatFlowDetailText(
          'Morning sittings use dawn + 30 minutes, any-time sittings default to 11:00 local, and evening sittings use sunset + 30 minutes.',
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(definition.routingSummary),
        if (definition.safetyNote != null) ...[
          const SizedBox(height: 10),
          _buildMaatFlowNotice(
            definition.safetyNote!,
            borderColor: MaatFlowPalette.gold.withValues(alpha: 0.34),
          ),
        ],
        const _MaatFlowPrivacyFooter(),
      ],
    );
  }

  Widget _buildOpenHandScaffold(BuildContext context) {
    final OpenHandEnrollmentWindow? window = _resolveOpenHandPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(
        context,
        debugLabel: 'openHand',
      );
    }
    final flowStart = DateUtils.dateOnly(window.opensAtLocal);
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _openHandJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _openHandJoinInFlight
            ? null
            : () => _joinOpenHandFlow(flowStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kTheOpenHandTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
            const SizedBox(height: 18),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<OpenHandLens>(
              values: OpenHandLens.values,
              selectedValue: _openHandLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _openHandLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildMaatFlowDetailText(
              _openHandLens.detailLine.isEmpty
                  ? 'Neutral keeps the practice centered on provision and record.'
                  : _openHandLens.detailLine,
              color: MaatFlowPalette.silverLo,
              fontSize: 13,
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('NINE SITTINGS'),
        ...kOpenHandEvents.map(
          (event) => _buildOpenHandEventTile(context, event, flowStart),
        ),
        _buildMaatFlowDetailText(
          'Openings are dawn + 30 minutes; midpoints default to 11:00 local; closes are sunset + 30 minutes.',
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'Bread means food. Water means the immediate resource in front of you. Clothing means dignity and protection. Boat means access, transport, introduction, or skill. Time is provision too.',
        ),
        const SizedBox(height: 10),
        const _MaatFlowPrivacyFooter(),
      ],
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
    final accent = event.physicalRaising
        ? const Color(0xFF9BD0A5)
        : highlight
        ? _gold
        : _silver;
    final badges = <String>[
      if (event.requiresDirectEngagement) 'Direct engagement',
      if (event.physicalRaising) 'Stand + raise',
    ];
    final title = djedEventTitle(event);
    final subtitle =
        '${djedTimingLabel(event)} · ${_dateLabel(context, schedule.startLocal)} at $time'
        '${event.requiresDirectEngagement ? ' · direct engagement' : ''}'
        '${event.physicalRaising ? ' · stand + raise' : ''}';
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: djedDetailText(event, lens: _djedLens),
      badges: badges,
      borderColor: highlight ? accent : Colors.white12,
      badgeAccent: accent,
    );
  }

  Widget _buildDjedScaffold(BuildContext context) {
    final DjedEnrollmentWindow? window = _resolveDjedPreviewWindow();
    if (window == null) {
      return _buildEnrollmentUnavailableScaffold(context, debugLabel: 'djed');
    }
    final flowStart = DateUtils.dateOnly(window.opensAtLocal);
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _djedJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _djedJoinInFlight ? null : () => _joinDjedFlow(flowStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kTheDjedTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
            const SizedBox(height: 18),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<DjedLens>(
              values: DjedLens.values,
              selectedValue: _djedLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _djedLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildMaatFlowDetailText(
              _djedLens.detailLine.isEmpty
                  ? 'Neutral keeps the work centered on stability, contest, and raising.'
                  : _djedLens.detailLine,
              color: MaatFlowPalette.silverLo,
              fontSize: 13,
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('NINE SITTINGS'),
        ...kDjedEvents.map(
          (event) => _buildDjedEventTile(context, event, flowStart),
        ),
        _buildMaatFlowDetailText(
          'Openings are dawn + 30 minutes; midpoints default to 11:00 local; the second decan closes at sunset + 30 minutes. Event 3 and Event 9 are dawn events by specification.',
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'Name the spine, engage the structural threat directly, then raise the Djed. The mock battle means a concrete stabilizing act, not harmful confrontation.',
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'Event 9 requires standing room for about 30 seconds. Name the spine, address the wobble, and complete the raising before marking it done.',
          borderColor: const Color(0xFF9BD0A5).withValues(alpha: 0.5),
        ),
        const SizedBox(height: 10),
        const _MaatFlowPrivacyFooter(),
      ],
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
    final variant = daysOutsideCopyVariantForEvent(
      event: event,
      gregorianDate: schedule.startLocal,
    );
    final badges = <String>[
      if (event.kind == DaysOutsideEventKind.wepRonpetOpening) 'Wep Ronpet',
      if (event.kMonth == 13) 'Birth',
      if (variant != DaysOutsideCopyVariant.standard) 'Eclipse',
    ];
    final title = daysOutsideEventTitle(event);
    final subtitle =
        'M${event.kMonth} D${event.kDay} · ${event.schedule.label} · ${_dateLabel(context, schedule.startLocal)} at $time';
    final accent = variant != DaysOutsideCopyVariant.standard
        ? const Color(0xFFB8A8FF)
        : event.kind == DaysOutsideEventKind.wepRonpetOpening
        ? _gold
        : event.kMonth == 13
        ? const Color(0xFFB8A8FF)
        : _silver;
    return _buildExpandableFlowEventTile(
      title: title,
      subtitle: subtitle,
      detailText: daysOutsideDetailText(
        event,
        closingKYear: closingKYear,
        variant: variant,
      ),
      badges: badges,
      borderColor: border,
      badgeAccent: accent,
    );
  }

  Widget _buildDaysOutsideYearScaffold(BuildContext context) {
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
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _daysOutsideYearJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _daysOutsideYearJoinInFlight
            ? null
            : () => _joinDaysOutsideYearFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kDaysOutsideTheYearTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('SEVEN EVENTS'),
        ...kDaysOutsideEvents.map(
          (event) => _buildDaysOutsideYearEventTile(
            context,
            event,
            window.closingKYear,
          ),
        ),
        _buildMaatFlowNotice(
          'Enrollment opens on M12 D28. Event 0 is M12 D30 at dusk, the five births are M13 D1-D5 at dawn, and Wep Ronpet is M1 D1 of the next Kemetic year. Leap-year M13 D6 has no event.',
        ),
        const SizedBox(height: 10),
        _buildMaatFlowDetailText(
          'Year close: ${_dateLabel(context, yearClose)} · First outside day: ${_dateLabel(context, epi1)} · Wep Ronpet: ${_dateLabel(context, wep)}',
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
        ),
        const SizedBox(height: 10),
        _buildMaatFlowNotice(
          'The Days Outside the Year opens the year; The Wag tends the ancestors through Month 1. Many keep both.',
        ),
        const SizedBox(height: 10),
        _buildMaatFlowDetailText(
          'This is a window-only picker. Arbitrary Kemetic dates are rejected on join.',
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
        ),
        const SizedBox(height: 10),
        const _MaatFlowPrivacyFooter(),
      ],
    );
  }

  Widget _buildMoonReturnScaffold(BuildContext context) {
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
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _moonReturnJoinInFlight ? 'Joining…' : 'Add Flow',
        onPressed: _moonReturnJoinInFlight
            ? null
            : () => _joinMoonReturnFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kMoonReturnTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildWindowStartRow(context, window.opensAtLocal),
            const SizedBox(height: 18),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<MoonReturnLens>(
              values: MoonReturnLens.values,
              selectedValue: _moonReturnLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _moonReturnLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildMaatFlowDetailText(
              _moonReturnLensExplanation(_moonReturnLens),
              color: MaatFlowPalette.silverLo,
              fontSize: 13,
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('UPCOMING EVENTS'),
        ...preview.map(
          (occurrence) => _buildMoonReturnOccurrenceTile(context, occurrence),
        ),
        const _MaatFlowPrivacyFooter(),
      ],
    );
  }

  Widget _buildCourseScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultTheCourseStartDate(_previewTrackSkyTimeZone);
    final firstEvent = kTheCourseEvents.first;
    final firstSchedule = courseScheduleForDate(
      firstEvent,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );

    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _courseJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _courseJoinInFlight
            ? null
            : () => _joinTheCourseFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kTheCourseTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<CourseLens>(
              values: CourseLens.values,
              selectedValue: _courseLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _courseLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _courseLensExplanation(_courseLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('9 SITTINGS'),
        ...kTheCourseEvents.map(
          (event) => _buildCourseEventTile(context, event, selectedStart),
        ),
        const _MaatFlowPracticeDisclaimerFooter(),
      ],
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
    return _buildMaatFlowSittingTile(
      title: offeringTableEventTitle(day),
      subtitle: '${day.section} · ${offeringTableTimingLabel(day)}',
      detailText: detail,
    );
  }

  Widget _buildOfferingTableScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart =
        _picked ?? defaultOfferingTableStartDate(_previewTrackSkyTimeZone);
    final firstDay = kOfferingTableDays.first;
    final firstSchedule = offeringTableScheduleForDate(
      firstDay,
      selectedStart,
      _previewTrackSkyTimeZone,
    );
    final firstTime = l10n.formatTimeOfDay(
      TimeOfDay(
        hour: firstSchedule.startLocal.hour,
        minute: firstSchedule.startLocal.minute,
      ),
    );
    final initialPromptSlot = _buildCurrentInitialPromptSlot(
      includeLeadingSeparator: false,
    );

    return _buildMaatFlowDetailScaffold(
      context,
      appendInitialPrompt: false,
      joinButton: _buildTemplateStickyJoinButton(
        text: _offeringJoinInFlight ? 'Joining…' : 'Join Flow',
        onPressed: _offeringJoinInFlight
            ? null
            : () => _joinOfferingTableFlow(selectedStart),
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: kOfferingTableTagline,
          initialPromptSlot: initialPromptSlot,
          configurationControls: [
            _buildStartDateRow(
              context,
              selectedStart,
              label:
                  'Start: ${_dateLabel(context, selectedStart)} at $firstTime',
            ),
            const SizedBox(height: 28),
            const _MaatFlowDetailSectionLabel('LENS'),
            _buildDetailChoiceChips<OfferingTableLens>(
              values: OfferingTableLens.values,
              selectedValue: _offeringTableLens,
              labelFor: (lens) => lens.label,
              onSelected: (lens) {
                setState(() {
                  _offeringTableLens = lens;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              _offeringTableLensExplanation(_offeringTableLens),
              style: const TextStyle(
                color: MaatFlowPalette.silverMid,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _buildMaatFlowSwitchSurface(
              value: _offeringNoCupMode,
              title: 'Use the cup you’re already holding',
              subtitle:
                  'Commute alternative; the water step remains part of the sitting.',
              onChanged: (value) {
                setState(() {
                  _offeringNoCupMode = value;
                });
              },
            ),
          ],
        ),
        const _MaatFlowDetailSeparator(),
        const _MaatFlowDetailSectionLabel('30-DAY TABLE'),
        for (final section in const <String>[
          'Personal Table',
          'Household Table',
          'Flowing Table',
        ]) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              section,
              style: const TextStyle(
                color: MaatFlowPalette.interiorLabel,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...kOfferingTableDays
              .where((day) => day.section == section)
              .map((day) => _buildOfferingTableDayTile(context, day)),
        ],
        const _MaatFlowPracticeDisclaimerFooter(),
      ],
    );
  }

  Widget _buildSequenceScaffold(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final selectedStart = _picked ?? DateUtils.dateOnly(DateTime.now());
    final startLabel = _picked == null
        ? 'Pick start date'
        : _startDateButtonLabel(context, _picked!);

    return _buildMaatFlowDetailScaffold(
      context,
      joinButton: _buildTemplateStickyJoinButton(
        text: 'Add Flow',
        onPressed: _picked == null
            ? null
            : () async {
                final id = await widget.addInstance(
                  template: widget.template,
                  startDate: _picked!,
                  useKemetic: _useKemetic,
                );
                if (id > 0 && context.mounted) {
                  await _completeJoin(id);
                }
              },
      ),
      children: [
        ..._buildMaatFlowOverviewZones(
          content: _detailContentForTemplate(overrideChips: null),
          tagline: widget.template.subtitle,
          configurationControls: [
            const _MaatFlowDetailSectionLabel('START'),
            _buildStartDateRow(context, selectedStart, label: startLabel),
            if (_picked != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _useKemetic ? 'Mode: Kemetic' : 'Mode: Gregorian',
                  style: const TextStyle(
                    color: MaatFlowPalette.silverLo,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (widget.template.days.isNotEmpty) ...[
          const _MaatFlowDetailSeparator(),
          const _MaatFlowDetailSectionLabel('10-DAY OUTLINE'),
          ...List.generate(widget.template.days.length, (i) {
            final day = widget.template.days[i];
            final detailText = day.notes
                .map((slot) {
                  final start = l10n.formatTimeOfDay(slot.start);
                  final end = l10n.formatTimeOfDay(slot.end);
                  final detail = (slot.detail ?? '').trim();
                  return [
                    '$start - $end',
                    slot.title,
                    if (detail.isNotEmpty) detail,
                  ].join('\n');
                })
                .join('\n\n');
            return _buildMaatFlowSittingTile(
              title: 'Day ${i + 1}',
              subtitle:
                  '${day.notes.length} scheduled act${day.notes.length == 1 ? '' : 's'}',
              detailText: detailText,
            );
          }),
        ],
      ],
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
    if (widget.template.kind == _MaatFlowTemplateKind.eveningThreshold) {
      return _buildEveningThresholdScaffold(context);
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
    if (widget.template.kind == _MaatFlowTemplateKind.maatDecan) {
      return _buildMaatDecanFlowScaffold(context);
    }
    return _buildSequenceScaffold(context);
  }
}

/* ───────────────────────── Search (notes) ───────────────────────── */
