import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../maat_flow_palette.dart';
import '../../maat_flow_visual_tokens.dart';
import '../../track_sky_timezone.dart';
import '../domain/follow_sky_timezone.dart';
import '../domain/sky_catalog.dart';
import '../domain/sky_event.dart';
import '../domain/sky_event_function.dart';
import '../domain/track_sky_course.dart';
import '../services/course_candidate_engine.dart';
import '../services/course_measurement_service.dart';
import '../services/sky_catalog_repository.dart';
import '../services/sky_visibility_service.dart';
import '../services/track_sky_course_metadata_codec.dart';
import '../services/track_sky_enrollment_service.dart';
import '../services/track_sky_materializer.dart';
import 'course_picker.dart';

/// Follow the Sky V2 detail surface — built from Ma'at tokens, not V1 scaffold.
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
    this.catalogRepository,
    this.initialCatalog,
    this.now,
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
  final SkyCatalogRepository? catalogRepository;
  final SkyCatalog? initialCatalog;
  final DateTime? now;

  @override
  State<FollowSkyDetailPage> createState() => _FollowSkyDetailPageState();
}

class _FollowSkyDetailPageState extends State<FollowSkyDetailPage> {
  late final SkyCatalogRepository _catalogRepo;
  late final TrackSkyEnrollmentService _enrollment;
  late final CourseCandidateEngine _candidateEngine;
  late final CourseMeasurementService _measurement;
  late final TrackSkyCourseMetadataCodec _codec;

  SkyCatalog? _catalog;
  Object? _error;
  TrackSkyCourse? _course;
  bool _coursePromptDismissed = false;
  bool _joining = false;
  String? _ritualDoneFor;

  @override
  void initState() {
    super.initState();
    _ensureTz();
    _catalogRepo = widget.catalogRepository ?? SkyCatalogRepository();
    _candidateEngine = const CourseCandidateEngine();
    _measurement = const CourseMeasurementService();
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
    if (widget.initialCatalog != null) {
      _catalog = widget.initialCatalog;
    } else {
      _load();
    }
  }

  void _ensureTz() {
    // Skip heavy timezone DB init in pure widget tests when catalog is injected.
    if (widget.initialCatalog != null) return;
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}
  }

  DateTime _toLocal(DateTime utc, String iana) {
    try {
      final location = tz.getLocation(iana);
      return tz.TZDateTime.from(utc.toUtc(), location);
    } catch (_) {
      return utc.toLocal();
    }
  }

  DateTime _toUtc(DateTime local, String iana) {
    try {
      final location = tz.getLocation(iana);
      final zoned = tz.TZDateTime(
        location,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      );
      return zoned.toUtc();
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
    // Prefer precomputed signals passed in; if empty, no filler chips.
    return _candidateEngine.suggest(widget.candidates, now: _now);
  }

  @override
  Widget build(BuildContext context) {
    final palette = MaatFlowPalette.resolve(
      flowId: 'track-the-sky',
      accent: const Color(0xFF6876D8),
    );

    return Scaffold(
      backgroundColor: MaatFlowListTokens.pageBg,
      appBar: AppBar(
        backgroundColor: MaatFlowListTokens.pageBg,
        foregroundColor: MaatFlowPalette.gold,
        title: const Text(
          'Follow the Sky',
          style: TextStyle(
            fontFamily: MaatFlowListTokens.fontFamily,
            color: MaatFlowPalette.gold,
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Text(
                'Could not load sky catalog.',
                style: TextStyle(color: MaatFlowPalette.silverMid),
              ),
            )
          : _catalog == null
              ? const Center(
                  child: CircularProgressIndicator(color: MaatFlowPalette.gold),
                )
              : _buildBody(palette),
    );
  }

  Widget _buildBody(MaatFlowPalette palette) {
    final needsCourse = widget.isJoined &&
        _course == null &&
        !_coursePromptDismissed;

    if (needsCourse) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _hero(palette),
          const SizedBox(height: 24),
          Text(
            'Follow the Sky now carries one course across the turnings you already follow.',
            style: TextStyle(color: MaatFlowPalette.silverMid, height: 1.4),
          ),
          const SizedBox(height: 20),
          FollowSkyCoursePicker(
            candidates: _chips,
            onSetLater: () => setState(() => _coursePromptDismissed = true),
            onSubmit: _handleCourseSubmit,
          ),
        ],
      );
    }

    final next = _catalog!.nextTurning(nowUtc: _now);
    final measurement = _course == null
        ? null
        : _measurement.measure(
            course: _course!,
            now: _now,
            intervals: widget.measurementIntervals,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        _hero(palette),
        const SizedBox(height: 20),
        if (!widget.isJoined) ...[
          _sectionLabel('Promise'),
          Text(
            'Keep what matters from drifting. When the sky turns, Hꜣw helps you measure and protect the course you choose.',
            style: TextStyle(color: MaatFlowPalette.silverMid, height: 1.45),
          ),
          const SizedBox(height: 22),
          _sectionLabel('First course'),
          FollowSkyCoursePicker(
            candidates: _chips,
            showSetLater: false,
            submitLabel: 'Join with this course',
            onSubmit: (cand, text) async {
              await _handleCourseSubmit(cand, text, joinAfter: true);
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _joining ? null : () => _joinWithoutCourse(),
            child: Text(
              'Join without a course yet',
              style: TextStyle(color: palette.glowColor),
            ),
          ),
        ] else ...[
          if (_course != null) ...[
            _sectionLabel('Your course'),
            Text(
              _course!.label,
              style: const TextStyle(
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 26,
                color: MaatFlowPalette.gold,
              ),
            ),
            Text(
              _course!.isLinked
                  ? 'Linked · measuring from your calendar'
                  : 'Unlinked · tracking from here forward',
              style: TextStyle(color: MaatFlowPalette.silverLo, fontSize: 12),
            ),
            const SizedBox(height: 18),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MaatFlowListTokens.joinedCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MaatFlowListTokens.joinedCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a course to use turnings for course correction.',
                    style: TextStyle(color: MaatFlowPalette.silverHi),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _coursePromptDismissed = false),
                    child: const Text('Set your course'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (next != null) ...[
            _sectionLabel('Next turning'),
            _turningCard(next, palette),
            const SizedBox(height: 18),
          ],
          if (_course != null && measurement != null) ...[
            _sectionLabel('What Hꜣw can measure'),
            if (!measurement.available)
              Text(
                measurement.unavailableReason ??
                    'No measurement until this course is linked.',
                style: TextStyle(color: MaatFlowPalette.silverMid),
              )
            else ...[
              Text(
                'Previous 14 days: ${CourseMeasurementService.formatDuration(measurement.previousMinutes)}',
                style: TextStyle(color: MaatFlowPalette.silverHi),
              ),
              Text(
                'Current 14 days: ${CourseMeasurementService.formatDuration(measurement.recentMinutes)}',
                style: TextStyle(color: MaatFlowPalette.silverHi),
              ),
              if (measurement.deltaFraction != null)
                Text(
                  'Delta: ${(measurement.deltaFraction! * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: palette.glowColor),
                ),
            ],
            const SizedBox(height: 18),
            _sectionLabel('One choice'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice
                    in _enrollment.availableChoices(hasCourse: true))
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MaatFlowPalette.gold,
                      side: const BorderSide(color: MaatFlowPalette.gold),
                    ),
                    onPressed: () => _onChoice(choice),
                    child: Text(choice.label),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (next != null) ...[
            _sectionLabel('Ritual'),
            Text(
              _ritualCopy(next),
              style: TextStyle(color: MaatFlowPalette.silverMid, height: 1.4),
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _ritualDoneFor = next.id),
              child: Text(
                _ritualDoneFor == next.id ? 'Witnessed' : 'Meet the turning',
              ),
            ),
            if (_ritualDoneFor == next.id) ...[
              const SizedBox(height: 12),
              _sectionLabel('History'),
              Text(
                'You met ${next.name}. Course history counts from ${_course == null ? 'when you set a course' : _formatDay(_course!.createdAt)}.',
                style: TextStyle(color: MaatFlowPalette.silverMid),
              ),
            ],
          ],
        ],
        const SizedBox(height: 28),
        _sectionLabel('How the sky helps'),
        ..._upcomingExamples(),
      ],
    );
  }

  Widget _hero(MaatFlowPalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: palette.glowColor, width: 3),
        ),
        gradient: LinearGradient(
          colors: [
            palette.accent.withValues(alpha: 0.18),
            MaatFlowListTokens.joinedCardBg,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FOLLOW THE SKY',
            style: TextStyle(
              letterSpacing: 1.4,
              fontSize: 11,
              color: palette.glowColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep what matters from drifting.',
            style: TextStyle(
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 28,
              height: 1.15,
              color: MaatFlowPalette.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _turningCard(SkyEvent event, MaatFlowPalette palette) {
    final local = _toLocal(event.primaryInstantUtc, widget.timezone.ianaName);
    final decision = const SkyVisibilityService().decide(event);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MaatFlowListTokens.joinedCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MaatFlowListTokens.joinedCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            style: TextStyle(
              fontFamily: MaatFlowListTokens.fontFamily,
              fontSize: 22,
              color: palette.glowColor,
            ),
          ),
          Text(
            '${_formatDay(local)} · Function: ${event.function.displayLabel}',
            style: TextStyle(color: MaatFlowPalette.silverMid),
          ),
          if (decision.userFacingNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              decision.userFacingNote,
              style: TextStyle(color: MaatFlowPalette.silverLo, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _upcomingExamples() {
    final upcoming = _catalog!.upcoming(nowUtc: _now).take(4);
    return [
      for (final e in upcoming)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${e.name} · ${e.function.displayLabel}',
            style: TextStyle(color: MaatFlowPalette.silverMid),
          ),
        ),
    ];
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          color: MaatFlowListTokens.sectionLabel,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _ritualCopy(SkyEvent event) {
    switch (event.function) {
      case SkyEventFunction.measure:
        return 'Step outside at the equinox. Measure what your course actually received.';
      case SkyEventFunction.reveal:
        return 'Meet the full moon. Notice what is ready to finish or show.';
      case SkyEventFunction.reconsider:
        return 'An eclipse invites reconsideration — without inventing meaning you did not choose.';
      case SkyEventFunction.turn:
        return 'At the solstice, take stock and choose what deserves the next season.';
      case SkyEventFunction.attend:
        return 'Attend the sky. Let awe interrupt the drift.';
    }
  }

  String _formatDay(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  Future<void> _handleCourseSubmit(
    TrackSkyCourseCandidate? candidate,
    String? freeText, {
    bool joinAfter = false,
  }) async {
    final TrackSkyCourse course;
    if (candidate != null) {
      course = _enrollment.createCourseFromCandidate(candidate, createdAt: _now);
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
    await widget.onCourseSaved?.call(course, notes);
    if (joinAfter) {
      await _joinWithCourse(course);
    }
  }

  Future<void> _joinWithoutCourse() async {
    await _joinWithCourse(null);
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
          const SnackBar(content: Text('Course kept.')),
        );
        break;
      case FollowSkyProductChoice.changeCourse:
        setState(() {
          _course = null;
          _coursePromptDismissed = false;
        });
        break;
      case FollowSkyProductChoice.giveMoreRoom:
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
        break;
    }
  }
}

/// Maps FollowSkyTimeZone ↔ shared TrackSkyTimeZone for enrollment notes.
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
