import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../track_sky_timezone.dart';
import '../domain/follow_sky_timezone.dart';
import '../domain/sky_catalog.dart';
import '../domain/sky_observing_night.dart';
import '../services/course_candidate_engine.dart';
import '../services/course_measurement_service.dart';
import '../domain/track_sky_course.dart';
import '../services/sky_catalog_repository.dart';
import '../services/sky_visibility_service.dart';
import '../services/track_sky_course_metadata_codec.dart';
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
    this.subtitle =
        'Sky · Major turnings in the sky carry a meaning. Attach your own intention to that meaning.',
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
  })? onProtectTime;
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
  late final SkyCatalogRepository _catalogRepo;
  late final TrackSkyEnrollmentService _enrollment;
  late final TrackSkyCourseMetadataCodec _codec;
  final TurningMeaningResolver _meaningResolver = const TurningMeaningResolver();
  final TextEditingController _exampleIntentionController =
      TextEditingController();
  final Set<String> _excludedSkyEventIds = <String>{};
  final Map<String, String> _draftIntentions = <String, String>{};
  bool _allTurningsExpanded = false;
  bool _joining = false;
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

  SkyObservingNight? get _lastSurfacedNight {
    final nights = _thirtyDayNights
        .where((n) => !_excludedSkyEventIds.contains(n.skyEventId))
        .toList();
    return nights.isEmpty ? null : nights.last;
  }

  SkyObservingNight? get _firstEclipsePreview {
    for (final night in _thirtyDayNights) {
      if (_excludedSkyEventIds.contains(night.skyEventId)) continue;
      if (night.companion != null ||
          night.displayName.toLowerCase().contains('eclipse')) {
        return night;
      }
    }
    return _thirtyDayNights.isNotEmpty ? _thirtyDayNights.first : null;
  }

  @override
  void initState() {
    super.initState();
    _ensureTz();
    _catalogRepo = widget.catalogRepository ?? SkyCatalogRepository();
    _codec = TrackSkyCourseMetadataCodec();
    final materializer = TrackSkyMaterializer(
      toLocal: _toLocal,
      toUtc: _toUtc,
    );
    _enrollment = TrackSkyEnrollmentService(
      materializer: materializer,
      visibilityService: const SkyVisibilityService(),
    );
    if (widget.initialCatalog != null) {
      _catalog = widget.initialCatalog;
    } else {
      unawaited(_load());
    }
    _exampleIntentionController.addListener(_onExampleIntentionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onHierarchyChanged?.call();
    });
  }

  @override
  void dispose() {
    _exampleIntentionController.removeListener(_onExampleIntentionChanged);
    _exampleIntentionController.dispose();
    super.dispose();
  }

  void _onExampleIntentionChanged() {
    final text = _exampleIntentionController.text;
    final eclipse = _firstEclipsePreview;
    if (eclipse == null) return;
    setState(() {
      if (text.trim().isEmpty) {
        _draftIntentions.remove(eclipse.skyEventId);
      } else {
        _draftIntentions[eclipse.skyEventId] = text;
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
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _openTurningSheet(SkyObservingNight night) async {
    final meaning = _meaningResolver.forNight(night);
    await showFollowSkyTurningSheet(
      context: context,
      night: night,
      meaning: meaning,
      initialIntention: _draftIntentions[night.skyEventId] ?? '',
      onSetIntention: (text) {
        setState(() {
          if (text.isEmpty) {
            _draftIntentions.remove(night.skyEventId);
          } else {
            _draftIntentions[night.skyEventId] = text;
          }
        });
      },
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
      return Stack(
        children: [
          body,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: FollowSkyV11Tokens.gold),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: FollowSkyV11Tokens.pageBg,
      body: body,
    );
  }

  Widget _buildV11Body() {
    final windowStart = DateUtils.dateOnly(_now.toLocal());
    final exampleMeaning = TurningMeaningResolver.approvedLunarEclipse;

    return FollowSkyScrollShell(
      hero: FollowSkyHero(title: widget.title, subtitle: widget.subtitle),
      bottomBar: FollowSkyV11Dock(
        joined: widget.isJoined,
        joining: _joining,
        onCarry: widget.isJoined ? null : _carry,
      ),
      sheet: Container(
        decoration: const BoxDecoration(
          color: FollowSkyV11Tokens.sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FollowSkyThirtyDayStrip(windowStart: windowStart),
            const SizedBox(height: 24),
            FollowSkyTurningExample(
              meaning: exampleMeaning,
              controller: _exampleIntentionController,
              onChanged: (_) {},
            ),
            const SizedBox(height: 24),
            FollowSkyPreviewCalendar(
              windowStart: windowStart,
              skyNights: _thirtyDayNights,
              calendarRows: widget.calendarPreview.rows,
              excludedSkyEventIds: _excludedSkyEventIds,
              carried: widget.isJoined,
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
              nowUtc: _now,
              lastSurfacedNight: _lastSurfacedNight,
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
