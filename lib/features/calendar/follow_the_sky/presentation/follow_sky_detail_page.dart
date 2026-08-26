import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/follow_sky_timezone.dart';
import '../domain/sky_catalog.dart';
import '../domain/sky_observing_night.dart';
import '../services/course_candidate_engine.dart';
import '../services/course_measurement_service.dart';
import '../domain/track_sky_course.dart';
import '../services/sky_catalog_repository.dart';
import '../services/sky_visibility_service.dart';
import '../services/track_sky_enrollment_service.dart';
import '../services/track_sky_materializer.dart';
import 'follow_sky_calendar_preview.dart';
import 'turning_meaning.dart';
import 'widgets/follow_sky_all_turnings_list.dart';
import 'widgets/follow_sky_preview_calendar.dart';
import 'widgets/follow_sky_scroll_shell.dart';
import 'widgets/follow_sky_thirty_day_strip.dart';
import 'widgets/follow_sky_turning_example.dart';
import 'widgets/follow_sky_turning_sheet.dart';
import 'widgets/follow_sky_v11_dock.dart';
import 'widgets/follow_sky_v11_tokens.dart';

/// Follow the Sky V11 detail orchestrator.
class FollowSkyDetailPage extends StatefulWidget {
  const FollowSkyDetailPage({
    super.key,
    this.existingFlowNotes,
    this.existingFlowId,
    this.isJoined = false,
    this.calendarPreview = FollowSkyCalendarPreview.empty,
    this.candidates = const [],
    this.measurementIntervals = const [],
    this.timezone = FollowSkyTimeZone.pacific,
    this.onJoin,
    this.onCourseSaved,
    this.onProtectTime,
    this.catalogRepository,
    this.initialCatalog,
    this.now,
    this.standalone = true,
    this.title = 'Follow the sky',
    this.subtitle = FollowSkyV11Tokens.heroSubtitle,
    this.onHierarchyChanged,
  });

  final String? existingFlowNotes;
  final int? existingFlowId;
  final bool isJoined;
  final FollowSkyCalendarPreview calendarPreview;
  final List<CourseActivitySignal> candidates;
  final List<CourseMeasurementInterval> measurementIntervals;
  final FollowSkyTimeZone timezone;
  final Future<void> Function(TrackSkyEnrollmentDraft draft)? onJoin;
  final Future<void> Function(TrackSkyCourse? course, String notes)?
  onCourseSaved;
  final Future<void> Function({
    required TrackSkyCourse course,
    required DateTime startLocal,
    required DateTime endLocal,
  })?
  onProtectTime;
  final SkyCatalogRepository? catalogRepository;
  final SkyCatalog? initialCatalog;
  final DateTime? now;
  final bool standalone;
  final String title;
  final String subtitle;
  final VoidCallback? onHierarchyChanged;

  @override
  State<FollowSkyDetailPage> createState() => FollowSkyDetailPageState();
}

class FollowSkyDetailPageState extends State<FollowSkyDetailPage> {
  static const int _expandedTurningCount = 5;

  late final SkyCatalogRepository _catalogRepo;
  late final TrackSkyEnrollmentService _enrollment;
  final TurningMeaningResolver _meaningResolver =
      const TurningMeaningResolver();
  final TextEditingController _exampleIntentionController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _excludedSkyEventIds = <String>{};
  final Map<String, String> _draftIntentions = <String, String>{};
  bool _allTurningsExpanded = false;
  bool _joining = false;
  late bool _carried;
  SkyCatalog? _catalog;
  Object? _error;

  bool get hasActiveCourse => false;

  Future<void> joinFromDock() => _carry();

  Future<void> carryCourseFromDock() => _carry();

  Future<void> openNextTurningFromDock() async {
    final next = _catalog?.nextObservingNight(nowUtc: _now);
    if (next == null) return;
    await _openTurningSheet(next);
  }

  @visibleForTesting
  Future<void> openTurningSheetForTest(SkyObservingNight night) =>
      _openTurningSheet(night);

  DateTime get _now => widget.now ?? DateTime.now().toUtc();

  List<SkyObservingNight> get _thirtyDayNights {
    final catalog = _catalog;
    if (catalog == null) return const [];
    final until = _now.add(const Duration(days: 30));
    return catalog.upcomingNights(nowUtc: _now, untilUtc: until);
  }

  List<SkyObservingNight> get _upcomingNights {
    final catalog = _catalog;
    if (catalog == null) return const [];
    return catalog.upcomingNights(nowUtc: _now);
  }

  List<SkyObservingNight> get _previewNights =>
      _upcomingNights.take(_expandedTurningCount).toList(growable: false);

  List<SkyObservingNight> get _intentionPreviewNights {
    final preview = _previewNights;
    return preview.isEmpty ? _thirtyDayNights : preview;
  }

  SkyObservingNight? get _firstEclipsePreview {
    final nights = _intentionPreviewNights;
    for (final night in nights) {
      if (_excludedSkyEventIds.contains(night.skyEventId)) continue;
      if (night.companion != null ||
          night.displayName.toLowerCase().contains('eclipse')) {
        return night;
      }
    }
    return nights.isNotEmpty ? nights.first : null;
  }

  @override
  void initState() {
    super.initState();
    _carried = widget.isJoined;
    _ensureTz();
    _catalogRepo = widget.catalogRepository ?? SkyCatalogRepository();
    final materializer = TrackSkyMaterializer(toLocal: _toLocal, toUtc: _toUtc);
    _enrollment = TrackSkyEnrollmentService(
      materializer: materializer,
      visibilityService: const SkyVisibilityService(),
    );
    if (widget.initialCatalog != null) {
      _catalog = widget.initialCatalog;
    } else {
      unawaited(_load());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onHierarchyChanged?.call();
    });
  }

  @override
  void didUpdateWidget(covariant FollowSkyDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isJoined != oldWidget.isJoined && widget.isJoined != _carried) {
      _carried = widget.isJoined;
    }
  }

  @override
  void dispose() {
    _exampleIntentionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setDraftIntentionForSkyNight(SkyObservingNight night, String value) {
    final nextValue = value.trim().isEmpty ? null : value;
    final currentValue = _draftIntentions[night.skyEventId];
    final exampleNight = _firstEclipsePreview;
    final nextExampleText = nextValue ?? '';
    final shouldSyncExample =
        exampleNight?.skyEventId == night.skyEventId &&
        _exampleIntentionController.text != nextExampleText;

    if (shouldSyncExample) {
      _exampleIntentionController.value = TextEditingValue(
        text: nextExampleText,
        selection: TextSelection.collapsed(offset: nextExampleText.length),
      );
    }
    if (currentValue == nextValue) return;

    setState(() {
      if (nextValue == null) {
        _draftIntentions.remove(night.skyEventId);
      } else {
        _draftIntentions[night.skyEventId] = nextValue;
      }
    });
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

  void _ensureTz() {
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

  Future<void> _carry() async {
    if (_catalog == null || widget.onJoin == null || _joining) return;
    setState(() => _joining = true);
    try {
      final included = _thirtyDayNights
          .map((n) => n.skyEventId)
          .where((id) => !_excludedSkyEventIds.contains(id))
          .toSet();
      final draft = _enrollment.buildJoinDraft(
        catalog: _catalog!,
        nowUtc: _now,
        ianaTimeZone: widget.timezone.ianaName,
        timezoneKey: widget.timezone.key,
        includedSkyEventIds: included,
        intentionBySkyEventId: Map<String, String>.from(_draftIntentions),
      );
      await widget.onJoin!(draft);
      if (mounted) setState(() => _carried = true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _openTurningSheet(SkyObservingNight night) async {
    final returnOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    final meaning = _meaningResolver.forNight(night);
    await showFollowSkyTurningSheet(
      context: context,
      night: night,
      meaning: meaning,
      initialIntention: _draftIntentions[night.skyEventId] ?? '',
      onSetIntention: (text) => _setDraftIntentionForSkyNight(night, text),
    );
    // Navigator results arrive before the bottom-sheet reverse transition has
    // fully released its view insets. Restore after that transition so the
    // underlying course returns to the exact reading position.
    await Future<void>.delayed(kThemeAnimationDuration);
    if (!mounted || returnOffset == null || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    position.jumpTo(
      returnOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _error != null
        ? const Center(
            child: Text(
              'Could not load sky catalog.',
              style: TextStyle(color: FollowSkyV11Tokens.silverMid),
            ),
          )
        : _catalog == null
        ? const Center(
            child: CircularProgressIndicator(color: FollowSkyV11Tokens.gold),
          )
        : _buildV11Body();

    if (!widget.standalone) {
      final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Material(
          color: FollowSkyV11Tokens.pageBg,
          child: Stack(
            children: [
              body,
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: FollowSkyV11Tokens.gold,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(backgroundColor: FollowSkyV11Tokens.pageBg, body: body);
  }

  Widget _buildV11Body() {
    final windowStart = DateUtils.dateOnly(_now.toLocal());
    final exampleMeaning = TurningMeaningResolver.approvedLunarEclipse;
    final exampleNight = _firstEclipsePreview;
    final orderedUpcomingNights = _upcomingNights;
    final previewNights = orderedUpcomingNights
        .take(_expandedTurningCount)
        .toList(growable: false);
    final remainingNights = orderedUpcomingNights
        .skip(previewNights.length)
        .toList(growable: false);

    return FollowSkyScrollShell(
      scrollController: _scrollController,
      hero: FollowSkyHero(title: widget.title, subtitle: widget.subtitle),
      bottomBar: FollowSkyV11Dock(
        joined: _carried,
        joining: _joining,
        onCarry: _carried ? null : _carry,
      ),
      sheet: Container(
        decoration: const BoxDecoration(
          color: FollowSkyV11Tokens.sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Color(0x2ED4AE43))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FollowSkyThirtyDayStrip(
              windowStart: windowStart,
              skyNights: _thirtyDayNights,
              calendarRows: widget.calendarPreview.rows,
              excludedSkyEventIds: _excludedSkyEventIds,
              carried: _carried,
            ),
            FollowSkyTurningExample(
              meaning: exampleMeaning,
              controller: _exampleIntentionController,
              onChanged: (text) {
                if (exampleNight != null) {
                  _setDraftIntentionForSkyNight(exampleNight, text);
                }
              },
            ),
            FollowSkyPreviewCalendar(
              skyNights: previewNights,
              calendarRows: widget.calendarPreview.rows,
              excludedSkyEventIds: _excludedSkyEventIds,
              carried: _carried,
              draftIntentions: _draftIntentions,
              onOpenSkyNight: _openTurningSheet,
              onExcludeSkyNight: (night) {
                setState(() => _excludedSkyEventIds.add(night.skyEventId));
              },
              meaningResolver: _meaningResolver,
            ),
            const SizedBox(height: 8),
            FollowSkyAllTurningsList(
              catalog: _catalog!,
              remainingNights: remainingNights,
              surfacedCount: previewNights.length,
              expanded: _allTurningsExpanded,
              onToggle: () =>
                  setState(() => _allTurningsExpanded = !_allTurningsExpanded),
              meaningResolver: _meaningResolver,
              onOpenNight: _openTurningSheet,
            ),
          ],
        ),
      ),
    );
  }
}
