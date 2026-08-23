import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../maat_flow_palette.dart';
import '../../maat_flow_visual_tokens.dart';
import '../../track_sky_timezone.dart';
import '../domain/follow_sky_timezone.dart';
import '../domain/sky_catalog.dart';
import '../domain/sky_event_function.dart';
import '../domain/sky_event_kind.dart';
import '../domain/sky_observing_night.dart';
import '../domain/track_sky_course.dart';
import '../follow_sky_cut_freeze.dart';
import '../services/course_candidate_engine.dart';
import '../services/course_function_service.dart';
import '../services/course_measurement_service.dart';
import '../services/sky_catalog_repository.dart';
import '../services/sky_visibility_service.dart';
import '../services/track_sky_course_metadata_codec.dart';
import '../services/track_sky_enrollment_service.dart';
import '../services/track_sky_materializer.dart';
import 'course_picker.dart';

/// Follow the Sky V2 detail content.
///
/// Presentation only: Ma’at shell tokens + V7 course/function copy.
/// Prefer embedding via [standalone] = false inside `_buildMaatFlowDetailScaffold`.
class FollowSkyDetailPage extends StatefulWidget {
  const FollowSkyDetailPage({
    super.key,
    this.existingFlowNotes,
    this.existingFlowId,
    this.isJoined = false,
    this.candidates = const [],
    this.measurementIntervals = const [],
    this.timezone = FollowSkyTimeZone.pacific,
    this.onJoin,
    this.onCourseSaved,
    this.onProtectTime,
    this.onHierarchyChanged,
    this.catalogRepository,
    this.initialCatalog,
    this.now,
    this.standalone = true,
    this.omitIdentityHero = false,
    this.identityHero,
    this.title = 'Follow the sky',
    this.subtitle =
        'Sky · Track the year\'s astronomical events in Kemetic time',
    this.historicalContext =
        'Kemetic timekeeping was tied to repeated observation of the Sun, Moon, stars, and seasons. Lunar reckonings and the rising of Sothis helped orient calendars, seasons, and festivals.',
    this.productPromiseHeadline = 'Keep what matters from drifting.',
    this.productPromiseBody =
        'At major turnings in the sky, ḥꜣw compares the life you’re actually scheduling with the course you chose. It helps you make one useful correction — and puts it on your calendar.',
  });

  final String? existingFlowNotes;
  final int? existingFlowId;
  final bool isJoined;
  final List<CourseActivitySignal> candidates;
  final List<CourseMeasurementInterval> measurementIntervals;
  final FollowSkyTimeZone timezone;
  final Future<void> Function(TrackSkyEnrollmentDraft draft)? onJoin;
  final Future<void> Function(TrackSkyCourse course, String notes)? onCourseSaved;
  final Future<void> Function({
    required TrackSkyCourse course,
    required DateTime startLocal,
    required DateTime endLocal,
  })? onProtectTime;
  final VoidCallback? onHierarchyChanged;
  final SkyCatalogRepository? catalogRepository;
  final SkyCatalog? initialCatalog;
  final DateTime? now;

  /// When true, provides its own Scaffold/AppBar (tests / harness).
  /// Production Ma’at detail passes false and supplies the parent shell.
  final bool standalone;

  /// When true, skip the icon+title row (parent already rendered it).
  final bool omitIdentityHero;

  /// Optional parent-built identity hero (preferred in production).
  final Widget? identityHero;

  final String title;
  final String subtitle;
  final String historicalContext;
  final String productPromiseHeadline;
  final String productPromiseBody;

  @override
  State<FollowSkyDetailPage> createState() => FollowSkyDetailPageState();
}

class FollowSkyDetailPageState extends State<FollowSkyDetailPage> {
  late final SkyCatalogRepository _catalogRepo;
  late final TrackSkyEnrollmentService _enrollment;
  late final CourseCandidateEngine _candidateEngine;
  late final CourseMeasurementService _measurement;
  late final CourseFunctionService _functionService;
  late final TrackSkyCourseMetadataCodec _codec;
  final GlobalKey<FollowSkyCoursePickerState> _coursePickerKey =
      GlobalKey<FollowSkyCoursePickerState>();
  final GlobalKey _courseSectionKey = GlobalKey();

  SkyCatalog? _catalog;
  Object? _error;
  TrackSkyCourse? _course;
  bool _coursePromptDismissed = false;
  bool _joining = false;

  bool get hasActiveCourse => _course != null;

  /// Dock “Join Flow” entry for the parent Ma’at scaffold.
  Future<void> joinFromDock() => _joinWithCourse(_course);

  /// Joined / no-course: dock CTA submits the course draft (or focuses input).
  Future<void> carryCourseFromDock() async {
    setState(() => _coursePromptDismissed = false);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    void act() {
      _scrollToCourse();
      final picker = _coursePickerKey.currentState;
      if (picker == null) return;
      if (!picker.submitIfReady()) {
        picker.focusField();
      }
    }

    if (_coursePickerKey.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) act();
      });
      return;
    }
    act();
  }

  /// Joined / with-course: open the next observing night sheet.
  Future<void> openNextTurningFromDock() async {
    final next = _catalog?.nextObservingNight(nowUtc: _now);
    if (next == null) return;
    await _openTurningSheet(next);
  }

  @visibleForTesting
  Future<void> openTurningSheetForTest(SkyObservingNight night) =>
      _openTurningSheet(night);

  /// Function sheet gated CTA when no course yet.
  void requestSetCourse() {
    setState(() => _coursePromptDismissed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCourse();
      _coursePickerKey.currentState?.focusField();
    });
  }

  /// Attach calendar evidence to the existing Course — never clears the Course.
  void requestConnectActivity() {
    final course = _course;
    if (course == null) {
      // No Course yet — only then invite setting one. Connect is not “edit Course”.
      setState(() => _coursePromptDismissed = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToCourse();
        _coursePickerKey.currentState?.focusField();
      });
      return;
    }
    unawaited(_openConnectActivitySheet());
  }

  /// Pop a turning sheet first, then open Connect on the next frame.
  /// Immediate nested showModalBottomSheet after pop is unreliable.
  Future<void> _closeTurningThenConnect(BuildContext turningContext) async {
    final preserved = _course;
    Navigator.of(turningContext).pop();
    // Defer until after the turning route is gone — do not clear the Course.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_course == null && preserved != null) {
        setState(() {
          _course = preserved;
          _coursePromptDismissed = true;
        });
      }
      if (_course == null) return;
      unawaited(_openConnectActivitySheet());
    });
  }

  Future<void> _openConnectActivitySheet() async {
    final course = _course;
    if (course == null) return;
    final eligible = _candidateEngine.eligibleForConnect(widget.candidates);
    final palette = _palette;

    if (kDebugMode) {
      debugPrint(
        '[FollowSky][connect] stamp=${FollowSkyCutFreeze.cut2RuntimeStamp} '
        'course=${course.label} linked=${course.isLinked} '
        'eligible=${eligible.length}',
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF0A0910),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xD933270E)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3743),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CONNECT ACTIVITY',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w600,
                      color: palette.glowColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Which part of your calendar belongs to “${course.label}”?',
                    style: const TextStyle(
                      color: MaatFlowPalette.silverHi,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (eligible.isEmpty) ...[
                    const Text(
                      'NO ACTIVITY TO CONNECT YET',
                      style: TextStyle(
                        color: MaatFlowPalette.silverHi,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Protect some time for this course and Hꜣw can start tracking it from there.',
                      style: TextStyle(
                        color: MaatFlowPalette.silverMid,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MaatFlowPalette.gold,
                          side: const BorderSide(
                            color: MaatFlowPalette.gold,
                            width: 1.5,
                          ),
                          backgroundColor:
                              MaatFlowPalette.gold.withValues(alpha: 0.055),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _protectTimeForCourse();
                        },
                        child: const Text(
                          'Protect time for this course',
                          style: TextStyle(
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback:
                                MaatFlowListTokens.fontFallback,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: palette.glowColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    for (final activity in eligible) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MaatFlowPalette.gold,
                          side: const BorderSide(color: MaatFlowPalette.gold),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _linkCourseToActivity(activity);
                        },
                        child: Text(
                          activity.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'None of these',
                        style: TextStyle(
                          color: palette.glowColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    // Cancel / dismiss must leave the Course active and unlinked-as-before.
    if (mounted && _course == null && course.label.isNotEmpty) {
      setState(() {
        _course = course;
        _coursePromptDismissed = true;
      });
      _notifyHierarchy();
    }
  }

  Future<void> _linkCourseToActivity(TrackSkyCourseCandidate activity) async {
    final current = _course;
    if (current == null) return;
    final linked = _enrollment.linkCourseToActivity(
      course: current,
      activity: activity,
    );
    final notes = _enrollment.notesWithCourse(
      existingNotes: widget.existingFlowNotes,
      course: linked,
      timezoneKey: widget.timezone.key,
    );
    setState(() => _course = linked);
    _notifyHierarchy();
    await widget.onCourseSaved?.call(linked, notes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected “${current.label}” to ${activity.label}.'),
      ),
    );
  }

  String? _linkedActivityLabel() {
    final course = _course;
    if (course == null || !course.isLinked) return null;
    for (final signal in widget.candidates) {
      if (signal.sourceId == course.sourceId) return signal.label;
    }
    return null;
  }

  void _scrollToCourse() {
    final ctx = _courseSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  void _notifyHierarchy() {
    widget.onHierarchyChanged?.call();
  }

  @override
  void initState() {
    super.initState();
    _ensureTz();
    _catalogRepo = widget.catalogRepository ?? SkyCatalogRepository();
    _candidateEngine = const CourseCandidateEngine();
    _measurement = const CourseMeasurementService();
    _functionService = const CourseFunctionService();
    _codec = TrackSkyCourseMetadataCodec();
    final materializer = TrackSkyMaterializer(
      toLocal: _toLocal,
      toUtc: _toUtc,
    );
    _enrollment = TrackSkyEnrollmentService(
      materializer: materializer,
      visibilityService: const SkyVisibilityService(),
    );
    _course = _codec.decode(widget.existingFlowNotes);
    if (kDebugMode) {
      debugPrint(
        '[FollowSky][runtime] stamp=${FollowSkyCutFreeze.cut2RuntimeStamp} '
        'course=${_course?.label ?? '(none)'} '
        'linked=${_course?.isLinked}',
      );
    }
    if (widget.initialCatalog != null) {
      _catalog = widget.initialCatalog;
    } else {
      _load();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyHierarchy();
    });
  }

  @override
  void didUpdateWidget(covariant FollowSkyDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingFlowNotes != widget.existingFlowNotes) {
      final decoded = _codec.decode(widget.existingFlowNotes);
      if (decoded != null) {
        _course = decoded;
      }
    }
  }

  void _ensureTz() {
    if (widget.initialCatalog != null) return;
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}
  }

  DateTime _toLocal(DateTime utc, String iana) {
    try {
      return tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana));
    } catch (_) {
      return utc.toLocal();
    }
  }

  DateTime _toUtc(DateTime local, String iana) {
    try {
      final location = tz.getLocation(iana);
      return tz.TZDateTime(
        location,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ).toUtc();
    } catch (_) {
      return local.toUtc();
    }
  }

  Future<void> _load() async {
    try {
      final catalog = await _catalogRepo.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  DateTime get _now => widget.now ?? DateTime.now().toUtc();

  List<TrackSkyCourseCandidate> get _chips {
    final out = _candidateEngine.suggest(widget.candidates, now: _now);
    assert(() {
      for (final c in out) {
        final matched = widget.candidates.any(
          (s) => s.sourceId == c.sourceId && s.label.trim() == c.label.trim(),
        );
        assert(
          matched,
          'Chip provenance failed: ${c.provenance} — not in live activity signals',
        );
        debugPrint('[FollowSky][chip] ${c.provenance}');
      }
      return true;
    }());
    return out;
  }

  MaatFlowPalette get _palette => MaatFlowPalette.resolve(
        flowId: 'track-the-sky',
        accent: const Color(0xFF6876D8),
      );

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final body = _error != null
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Could not load sky catalog.',
              style: TextStyle(color: MaatFlowPalette.silverMid),
            ),
          )
        : _catalog == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: MaatFlowPalette.gold),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildSections(palette),
              );

    final stamped = !kDebugMode
        ? body
        : Semantics(
            identifier:
                'follow_sky_runtime_${FollowSkyCutFreeze.cut2RuntimeStamp}',
            container: true,
            child: body,
          );

    if (!widget.standalone) return stamped;

    return Scaffold(
      backgroundColor: MaatFlowListTokens.pageBg,
      appBar: AppBar(
        backgroundColor: MaatFlowListTokens.pageBg,
        foregroundColor: MaatFlowListTokens.gold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            color: MaatFlowListTokens.gold,
            fontSize: 25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        children: [body],
      ),
    );
  }

  List<Widget> _buildSections(MaatFlowPalette palette) {
    final next = _catalog!.nextObservingNight(nowUtc: _now);
    final upcoming = _catalog!.upcomingNights(nowUtc: _now).take(8).toList();
    final showCoursePrompt = widget.isJoined &&
        _course == null &&
        !_coursePromptDismissed;
    final measurement = _course == null
        ? null
        : _measurement.measure(
            course: _course!,
            now: _now,
            intervals: widget.measurementIntervals,
          );
    final measureEvidence = _course == null
        ? null
        : _functionService.evidenceFor(
            function: SkyEventFunction.measure,
            course: _course!,
            now: _now,
            intervals: widget.measurementIntervals,
          );

    return [
      if (!widget.omitIdentityHero) ...[
        widget.identityHero ?? _fallbackIdentityHero(palette),
        const SizedBox(height: 16),
      ],
      Text(
        widget.productPromiseHeadline,
        style: const TextStyle(
          color: MaatFlowPalette.gold,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        widget.productPromiseBody,
        style: const TextStyle(
          color: MaatFlowPalette.silverHi,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
      if (!widget.isJoined) ...[
        SizedBox(key: _courseSectionKey, height: 20),
        FollowSkyCoursePicker(
          key: _coursePickerKey,
          candidates: _chips,
          showSetLater: false,
          onDraftChanged: _notifyHierarchy,
          onSubmit: (cand, text) async {
            await _handleCourseSubmit(cand, text, joinAfter: true);
          },
        ),
        TextButton(
          onPressed: _joining ? null : () => _joinWithCourse(null),
          child: Text(
            'Join without a course yet',
            style: TextStyle(color: palette.glowColor, fontSize: 14),
          ),
        ),
      ] else ...[
        const SizedBox(height: 20),
        if (showCoursePrompt)
          KeyedSubtree(
            key: _courseSectionKey,
            child: FollowSkyCoursePicker(
              key: _coursePickerKey,
              candidates: _chips,
              // Dock owns "Carry this course" when embedded in Ma’at shell.
              showSubmitButton: widget.standalone,
              onDraftChanged: _notifyHierarchy,
              onSetLater: () {
                setState(() => _coursePromptDismissed = true);
                _notifyHierarchy();
              },
              onSubmit: (cand, text) => _handleCourseSubmit(cand, text),
            ),
          )
        else if (_course != null)
          KeyedSubtree(
            key: _courseSectionKey,
            child: _yourCourseBlock(palette),
          )
        else
          KeyedSubtree(
            key: _courseSectionKey,
            child: _setCourseLaterBanner(palette),
          ),
      ],
      if (next != null) ...[
        const SizedBox(height: 20),
        _nextTurningSurface(next, palette),
      ],
      if (widget.isJoined &&
          _course != null &&
          next?.function == SkyEventFunction.measure &&
          measureEvidence != null &&
          measureEvidence.available &&
          measurement != null) ...[
        const SizedBox(height: 16),
        _microLabel('WHAT ḤꜣW CAN MEASURE'),
        const SizedBox(height: 6),
        Text(
          'Previous 14 days: ${CourseMeasurementService.formatDuration(measurement.previousMinutes)}',
          style: const TextStyle(
            color: MaatFlowPalette.silverMid,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        Text(
          'Current 14 days: ${CourseMeasurementService.formatDuration(measurement.recentMinutes)}',
          style: const TextStyle(
            color: MaatFlowPalette.silverMid,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 14),
      _inKemetBlock(),
      const SizedBox(height: 18),
      _sectionRuleLabel('What you\'ll follow'),
      const SizedBox(height: 8),
      _whatYoullFollowArc(palette),
      const SizedBox(height: 8),
      Text(
        '${_catalog!.observingNightCount} observing nights through ${_formatCoverageMonth(_catalog!.coverageEnd)}. '
        'Including ${_catalog!.eclipseFullMoonNightCount} Full Moons that are also lunar eclipses.',
        style: const TextStyle(
          color: MaatFlowPalette.silverLo,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 18),
      _sectionRuleLabel('Upcoming turnings'),
      ..._upcomingRows(upcoming, next?.skyEventId, palette),
    ];
  }

  Widget _fallbackIdentityHero(MaatFlowPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: MaatFlowListTokens.iconSize,
          height: MaatFlowListTokens.iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.iconGradientStops ??
                  [palette.accent, palette.glowColor],
            ),
          ),
          child: Icon(Icons.nightlight_round, color: palette.glowColor, size: 28),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: MaatFlowPalette.gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: MaatFlowPalette.silverHi,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _yourCourseBlock(MaatFlowPalette palette) {
    final created = _formatShortDay(_course!.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _microLabel('YOUR COURSE'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _course!.label,
                    style: const TextStyle(
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: MaatFlowPalette.gold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Carried since $created',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: MaatFlowPalette.silverLo,
                    ),
                  ),
                  if (!_course!.isLinked) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.measurementIntervals.isEmpty
                          ? 'No calendar activity connected yet'
                          : 'Hꜣw is tracking the time you protect for this',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: MaatFlowPalette.silverMid,
                        height: 1.35,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: requestConnectActivity,
                        child: Text(
                          'Connect activity',
                          style: TextStyle(
                            color: palette.glowColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      _linkedActivityLabel() == null
                          ? 'Calendar activity connected'
                          : 'Connected to ${_linkedActivityLabel()}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: MaatFlowPalette.silverMid,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _course = null;
                  _coursePromptDismissed = false;
                });
                _notifyHierarchy();
              },
              child: Text(
                'Change',
                style: TextStyle(color: palette.glowColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _setCourseLaterBanner(MaatFlowPalette palette) {
    return MaatFlowSurface(
      palette: palette,
      borderRadius: BorderRadius.circular(14),
      baseColor: MaatFlowPalette.unjoinedBase,
      border: Border.all(color: MaatFlowListTokens.unjoinedCardBorder),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'This is not a streak. Missing a turning doesn’t break anything. At the next one, ḥꜣw simply helps you find your course again.',
              style: TextStyle(
                color: MaatFlowPalette.silverMid,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _coursePromptDismissed = false);
              _notifyHierarchy();
            },
            child: Text(
              'Set course',
              style: TextStyle(color: palette.glowColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextTurningSurface(SkyObservingNight night, MaatFlowPalette palette) {
    final local = _toLocal(night.primaryInstantUtc, widget.timezone.ianaName);
    final decision = const SkyVisibilityService().decide(night.windowSource);
    final useLine = _useLine(night);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MaatFlowListTokens.joinedCardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 2, color: palette.glowColor),
              Expanded(
                child: MaatFlowSurface(
                  palette: palette,
                  borderRadius: BorderRadius.zero,
                  showCrown: true,
                  washOpacity: 0.08,
                  border: null,
                  padding: const EdgeInsets.fromLTRB(15, 16, 17, 17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _microLabel('NEXT TURNING'),
                      const SizedBox(height: 8),
                      Text(
                        night.displayName,
                        style: TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: palette.glowColor,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatFriendlyDay(local)} · around ${_formatApproxTime(local)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: MaatFlowPalette.silverLo,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        useLine,
                        style: const TextStyle(
                          color: MaatFlowPalette.silverHi,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Not every turning asks you to do more. Some are for awe, release, rest, or company.',
                        style: TextStyle(
                          color: MaatFlowPalette.silverLo,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                      if (decision.userFacingNote.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          decision.userFacingNote,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: MaatFlowPalette.silverLo,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (widget.isJoined && _course != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 43,
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.glowColor,
                              side: BorderSide(
                                color: palette.accent.withValues(alpha: 0.65),
                              ),
                              backgroundColor:
                                  palette.accent.withValues(alpha: 0.06),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _openTurningSheet(night),
                            child: Text(
                              _functionPrimaryCta(night),
                              style: const TextStyle(
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontFamilyFallback:
                                    MaatFlowListTokens.fontFallback,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inKemetBlock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      decoration: BoxDecoration(
        color: MaatFlowListTokens.unjoinedCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MaatFlowListTokens.unjoinedCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _microLabel('IN KEMET'),
          const SizedBox(height: 8),
          Text(
            widget.historicalContext,
            style: const TextStyle(
              color: MaatFlowPalette.silverMid,
              fontSize: 13.5,
              height: 1.45,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whatYoullFollowArc(MaatFlowPalette palette) {
    Widget cell(String title, String sub) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MaatFlowListTokens.joinedTitle,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MaatFlowPalette.silverLo,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: MaatFlowListTokens.unjoinedCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MaatFlowListTokens.unjoinedCardBorder),
      ),
      child: Row(
        children: [
          cell('Solar', 'equinoxes + solstices'),
          Container(width: 1, height: 64, color: MaatFlowPalette.separator),
          cell('Lunar', 'full Moons + eclipses'),
          Container(width: 1, height: 64, color: MaatFlowPalette.separator),
          cell('Sky', 'meteors + planets'),
        ],
      ),
    );
  }

  List<Widget> _upcomingRows(
    List<SkyObservingNight> nights,
    String? nextId,
    MaatFlowPalette palette,
  ) {
    if (nights.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'No upcoming turnings remain in this catalog window.',
            style: TextStyle(color: MaatFlowPalette.silverLo, fontSize: 13.5),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < nights.length; i++)
        _eventRow(
          index: i + 1,
          night: nights[i],
          isNext: nights[i].skyEventId == nextId,
          palette: palette,
          isLast: i == nights.length - 1,
        ),
    ];
  }

  Widget _eventRow({
    required int index,
    required SkyObservingNight night,
    required bool isNext,
    required MaatFlowPalette palette,
    required bool isLast,
  }) {
    final local = _toLocal(night.primaryInstantUtc, widget.timezone.ianaName);
    return InkWell(
      onTap: widget.isJoined ? () => _openTurningSheet(night) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: MaatFlowPalette.separator, width: 1),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: MaatFlowListTokens.sectionLabel,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    night.displayName,
                    style: TextStyle(
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: isNext
                          ? MaatFlowPalette.gold
                          : MaatFlowPalette.goldDim,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatFriendlyDay(local),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4E422B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _rowFunctionLine(night),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: MaatFlowPalette.silverLo,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: palette.glowColor.withValues(alpha: 0.78),
            ),
          ],
        ),
      ),
    );
  }

  Widget _microLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600,
        color: MaatFlowListTokens.sectionLabel,
      ),
    );
  }

  Widget _sectionRuleLabel(String text) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: MaatFlowListTokens.sectionLabel,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: MaatFlowPalette.separator),
        ),
      ],
    );
  }

  /// Compact "Use:" line on the detail card (v5/v7 authority).
  String _useLine(SkyObservingNight night) {
    switch (night.serviceKind) {
      case SkyEventKind.equinox:
        return 'Use: rebalance something that’s getting crowded out.';
      case SkyEventKind.fullMoon:
        return 'Use: finish or reveal one thing that’s been open too long.';
      case SkyEventKind.lunarEclipse:
      case SkyEventKind.solarEclipse:
        return 'Reconsider · something familiar changes under shadow.';
      case SkyEventKind.solstice:
        return 'Use: choose what deserves the next season.';
      case SkyEventKind.meteorShower:
        return 'Use: awe, company, and nothing to optimize.';
      case SkyEventKind.planetOpposition:
      case SkyEventKind.planetElongation:
      case SkyEventKind.planetConjunction:
        return 'Use: awe, company, and nothing to optimize.';
    }
  }

  String _rowFunctionLine(SkyObservingNight night) {
    if (night.serviceKind == SkyEventKind.lunarEclipse ||
        night.serviceKind == SkyEventKind.solarEclipse) {
      return 'Reconsider · something familiar changes under shadow.';
    }
    return '${night.function.displayLabel} · ${_useLine(night).replaceFirst(RegExp(r'^Use:\s*'), '')}';
  }

  /// First CTA on the turning sheet — system function, not ritual yet.
  String _functionPrimaryCta(SkyObservingNight night) {
    if (_course == null && _functionRequiresCourse(night.function)) {
      return 'Set a course to use this turning';
    }
    switch (night.function) {
      case SkyEventFunction.measure:
        return 'Measure my course';
      case SkyEventFunction.reveal:
        return 'Choose what to finish';
      case SkyEventFunction.reconsider:
        return 'Reconsider what I’m carrying';
      case SkyEventFunction.turn:
        return 'Take stock of the season';
      case SkyEventFunction.attend:
        return 'Plan to watch';
    }
  }

  bool _functionRequiresCourse(SkyEventFunction function) {
    switch (function) {
      case SkyEventFunction.measure:
      case SkyEventFunction.reveal:
      case SkyEventFunction.reconsider:
      case SkyEventFunction.turn:
        return true;
      case SkyEventFunction.attend:
        return false;
    }
  }

  /// Expanded sheet: sky fact (function name lives in the label above).
  String _expandedFunctionLead(SkyObservingNight night) {
    switch (night.serviceKind) {
      case SkyEventKind.fullMoon:
        return 'The Moon’s visible face is fully illuminated.';
      case SkyEventKind.equinox:
        return 'Day and night stand in balance.';
      case SkyEventKind.solstice:
        return 'The Sun reaches its seasonal extreme.';
      case SkyEventKind.lunarEclipse:
      case SkyEventKind.solarEclipse:
        return 'Something familiar changes under shadow.';
      case SkyEventKind.meteorShower:
        return 'Meteors cut quickly across a dark sky.';
      case SkyEventKind.planetOpposition:
      case SkyEventKind.planetElongation:
      case SkyEventKind.planetConjunction:
        return 'A planet stands well placed for naked-eye watching.';
    }
  }

  String _expandedServiceCopy(SkyObservingNight night) {
    switch (night.serviceKind) {
      case SkyEventKind.fullMoon:
        return 'ḥꜣw surfaces one unfinished thing that has followed you across multiple weeks. Finish it, show it, or finally name it.';
      case SkyEventKind.equinox:
        // Measure sheet: sky fact + data (or no-evidence CTAs). No lecture copy.
        return '';
      case SkyEventKind.solstice:
        return 'ḥꜣw helps you choose what deserves the next season — without inventing meaning you did not choose.';
      case SkyEventKind.lunarEclipse:
      case SkyEventKind.solarEclipse:
        // Reconsider sheet owns service copy; avoid repeating “reconsider”.
        return '';
      case SkyEventKind.meteorShower:
      case SkyEventKind.planetOpposition:
      case SkyEventKind.planetElongation:
      case SkyEventKind.planetConjunction:
        return 'Not every turning asks you to do more. Some are for awe, release, rest, or company.';
    }
  }

  String _continueObservationLabel(SkyObservingNight night) {
    if (night.serviceKind == SkyEventKind.lunarEclipse ||
        night.serviceKind == SkyEventKind.solarEclipse) {
      return 'Continue to the eclipse';
    }
    return 'Continue to the turning';
  }

  Future<void> _openTurningSheet(SkyObservingNight night) async {
    final palette = _palette;
    final local = _toLocal(night.primaryInstantUtc, widget.timezone.ianaName);
    final evidence = _course == null
        ? null
        : _functionService.evidenceFor(
            function: night.function,
            course: _course!,
            now: _now,
            intervals: widget.measurementIntervals,
          );
    final hasEvidenceObject = evidence?.available ?? false;
    final choices = _enrollment.availableChoices(
      hasCourse: _course != null,
      hasEvidenceObject: hasEvidenceObject,
      function: night.function,
    );
    final isReconsider = night.function == SkyEventFunction.reconsider;
    final isMeasure = night.function == SkyEventFunction.measure;
    final noEvidenceService = (isReconsider || isMeasure) &&
        _course != null &&
        evidence != null &&
        !evidence.available;
    final withEvidenceService =
        (isReconsider || isMeasure) && hasEvidenceObject;
    final serviceCopy = _expandedServiceCopy(night);
    final showPrimaryCta = !noEvidenceService && !withEvidenceService;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0910),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xD933270E)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3743),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    night.displayName,
                    style: const TextStyle(
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 24,
                      color: MaatFlowPalette.gold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    '${_formatFriendlyDay(local)} · ${_formatApproxTime(local)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: MaatFlowPalette.silverLo,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    night.function.displayLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.7,
                      fontWeight: FontWeight.w600,
                      color: palette.glowColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _expandedFunctionLead(night),
                    style: const TextStyle(
                      color: MaatFlowPalette.silverHi,
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (serviceCopy.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      serviceCopy,
                      style: const TextStyle(
                        color: MaatFlowPalette.silverMid,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (_course != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'YOUR COURSE',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.7,
                        fontWeight: FontWeight.w600,
                        color: palette.glowColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _course!.label,
                      style: const TextStyle(
                        color: MaatFlowPalette.silverHi,
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (noEvidenceService && isMeasure) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'No calendar activity connected yet',
                        style: TextStyle(
                          color: MaatFlowPalette.silverHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hꜣw can start measuring the time you protect for this course from here.',
                        style: TextStyle(
                          color: MaatFlowPalette.silverMid,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MaatFlowPalette.gold,
                            side: const BorderSide(
                              color: MaatFlowPalette.gold,
                              width: 1.5,
                            ),
                            backgroundColor:
                                MaatFlowPalette.gold.withValues(alpha: 0.055),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _protectTimeForCourse();
                          },
                          child: const Text(
                            'Protect time for this course',
                            style: TextStyle(
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          unawaited(_closeTurningThenConnect(ctx));
                        },
                        child: Text(
                          'Connect activity',
                          style: TextStyle(
                            color: palette.glowColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ] else if (noEvidenceService && isReconsider) ...[
                      const SizedBox(height: 14),
                      Text(
                        evidence.unavailableReason ??
                            'There isn’t any Hꜣw activity connected to this course yet.',
                        style: const TextStyle(
                          color: MaatFlowPalette.silverHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Once you schedule or link something to it, Hꜣw can notice what keeps getting carried forward.',
                        style: TextStyle(
                          color: MaatFlowPalette.silverMid,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MaatFlowPalette.gold,
                            side: const BorderSide(
                              color: MaatFlowPalette.gold,
                              width: 1.5,
                            ),
                            backgroundColor:
                                MaatFlowPalette.gold.withValues(alpha: 0.055),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            unawaited(_closeTurningThenConnect(ctx));
                          },
                          child: const Text(
                            'Connect activity',
                            style: TextStyle(
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          _continueObservationLabel(night),
                          style: TextStyle(
                            color: palette.glowColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ] else if (evidence != null && !evidence.available) ...[
                      const SizedBox(height: 8),
                      Text(
                        evidence.unavailableReason ??
                            'No calendar activity connected yet.',
                        style: const TextStyle(
                          color: MaatFlowPalette.silverLo,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (evidence != null && evidence.available) ...[
                      const SizedBox(height: 12),
                      if (evidence.lead.isNotEmpty) ...[
                        Text(
                          evidence.lead,
                          style: const TextStyle(
                            color: MaatFlowPalette.silverHi,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (evidence.body.isNotEmpty)
                          const SizedBox(height: 6),
                      ],
                      if (evidence.body.isNotEmpty)
                        Text(
                          evidence.body,
                          style: const TextStyle(
                            color: MaatFlowPalette.silverMid,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                    ],
                    if (choices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final choice in choices)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MaatFlowPalette.gold,
                                side: const BorderSide(
                                  color: MaatFlowPalette.gold,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _onChoice(choice);
                              },
                              child: Text(choice.label),
                            ),
                        ],
                      ),
                    ],
                  ],
                  if (showPrimaryCta) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MaatFlowPalette.gold,
                          side: const BorderSide(
                            color: MaatFlowPalette.gold,
                            width: 1.5,
                          ),
                          backgroundColor:
                              MaatFlowPalette.gold.withValues(alpha: 0.055),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          if (_course == null &&
                              _functionRequiresCourse(night.function)) {
                            Navigator.of(ctx).pop();
                            requestSetCourse();
                            return;
                          }
                          // Stay on the sheet so the function work remains visible.
                        },
                        child: Text(
                          _functionPrimaryCta(night),
                          style: const TextStyle(
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback:
                                MaatFlowListTokens.fontFallback,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCoverageMonth(DateTime utc) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = utc.toLocal();
    return '${months[local.month - 1]} ${local.year}';
  }

  String _formatFriendlyDay(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatApproxTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:00 $suffix';
  }

  String _formatShortDay(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Future<void> _handleCourseSubmit(
    TrackSkyCourseCandidate? candidate,
    String? freeText, {
    bool joinAfter = false,
  }) async {
    final TrackSkyCourse course;
    if (candidate != null) {
      course =
          _enrollment.createCourseFromCandidate(candidate, createdAt: _now);
    } else {
      final label = freeText?.trim() ?? '';
      if (label.isEmpty) return;
      course = _enrollment.createCourse(
        label: label,
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: _now,
      );
    }
    final notes = _enrollment.notesWithCourse(
      existingNotes: widget.existingFlowNotes,
      course: course,
      timezoneKey: widget.timezone.key,
    );
    setState(() => _course = course);
    _notifyHierarchy();
    await widget.onCourseSaved?.call(course, notes);
    if (joinAfter) {
      await _joinWithCourse(course);
    }
  }

  Future<void> _joinWithCourse(TrackSkyCourse? course) async {
    if (_catalog == null || widget.onJoin == null) return;
    setState(() => _joining = true);
    try {
      final draft = _enrollment.buildJoinDraft(
        catalog: _catalog!,
        nowUtc: _now,
        ianaTimeZone: widget.timezone.ianaName,
        timezoneKey: widget.timezone.key,
        course: course,
      );
      await widget.onJoin!(draft);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _onChoice(FollowSkyProductChoice choice) async {
    if (_course == null) return;
    switch (choice) {
      case FollowSkyProductChoice.keepCourse:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kept.')),
        );
        break;
      case FollowSkyProductChoice.changeCourse:
        setState(() {
          _course = null;
          _coursePromptDismissed = false;
        });
        _notifyHierarchy();
        break;
      case FollowSkyProductChoice.releaseCourse:
        setState(() {
          _course = null;
          _coursePromptDismissed = true;
        });
        _notifyHierarchy();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Released for now.')),
        );
        break;
      case FollowSkyProductChoice.giveMoreRoom:
        await _protectTimeForCourse();
        break;
    }
  }

  Future<void> _protectTimeForCourse() async {
    if (_course == null) return;
    final nowLocal = _toLocal(_now, widget.timezone.ianaName);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: nowLocal.hour, minute: 0),
    );
    if (picked == null) return;
    final start = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      picked.hour,
      picked.minute,
    );
    final end = start.add(const Duration(hours: 1));
    await widget.onProtectTime?.call(
      course: _course!,
      startLocal: start,
      endLocal: end,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Protected ${_course!.label} · ${picked.format(context)}',
        ),
      ),
    );
  }
}

extension FollowSkyTimeZoneBridge on FollowSkyTimeZone {
  TrackSkyTimeZone get asTrackSky {
    switch (this) {
      case FollowSkyTimeZone.pacific:
        return TrackSkyTimeZone.pacific;
      case FollowSkyTimeZone.mountain:
        return TrackSkyTimeZone.mountain;
      case FollowSkyTimeZone.central:
        return TrackSkyTimeZone.central;
      case FollowSkyTimeZone.eastern:
        return TrackSkyTimeZone.eastern;
    }
  }
}
