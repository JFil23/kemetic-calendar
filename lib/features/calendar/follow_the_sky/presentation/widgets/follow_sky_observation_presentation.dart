import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';

import '../../domain/follow_sky_track_definition.dart';
import '../../services/follow_sky_turning_controller.dart';
import '../follow_sky_observation_presentation_model.dart';
import '../follow_sky_view_time_policy.dart';
import 'follow_sky_instrument_surface.dart';

class FollowSkyObservationPresentation extends StatefulWidget {
  const FollowSkyObservationPresentation({
    super.key,
    required this.model,
    this.now,
    this.clientEventId,
    this.completionIdentity,
    this.skyEventId,
    this.localDate,
    this.scheduledTimeSnapshot,
    this.intentionSnapshot,
    this.onWriteJournalResponse,
    this.onCommitCompletion,
    this.turningController,
  }) : assert(
         turningController != null ||
             (clientEventId == null &&
                 completionIdentity == null &&
                 skyEventId == null &&
                 localDate == null &&
                 scheduledTimeSnapshot == null &&
                 onCommitCompletion == null) ||
             (clientEventId != null &&
                 completionIdentity != null &&
                 skyEventId != null &&
                 localDate != null &&
                 scheduledTimeSnapshot != null &&
                 onCommitCompletion != null),
         'Provide either a complete Turning session or no persistence fields.',
       );

  final FollowSkyObservationPresentationModel model;
  final DateTime Function()? now;
  final String? clientEventId;
  final String? completionIdentity;
  final String? skyEventId;
  final DateTime? localDate;
  final DateTime? scheduledTimeSnapshot;
  final String? intentionSnapshot;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final FollowSkyCompletionCommit? onCommitCompletion;
  final FollowSkyTurningController? turningController;

  @override
  State<FollowSkyObservationPresentation> createState() =>
      _FollowSkyObservationPresentationState();
}

class _FollowSkyObservationPresentationState
    extends State<FollowSkyObservationPresentation> {
  static const _velvet = Color(0xFF080706);
  static const _bone = Color(0xFFE8E2D6);
  static const _gold = Color(0xFFD4AE43);
  static const _goldDim = Color(0xFF8A7030);
  static const _silverMid = Color(0xFF9E9A94);
  static const _silverLow = Color(0xFF6A6660);
  static const _separator = Color(0xFF2A2415);
  static const _periwinkle = Color(0xFF6876D8);
  static const _glow = Color(0xFFA4B1FF);
  static const _rose = Color(0xFFE5C3C6);
  static const _display = 'CormorantGaramond';
  static const _ui = 'GentiumPlus';
  static const _reflectionStyle = InstrumentEventReflectionStyle(
    activeColor: _glow,
    armedBackgroundColor: Color(0x1A6876D8),
    inactiveBackgroundColor: Color(0x06FFFFFF),
    inactiveIconColor: _bone,
    inactiveLabelColor: _silverMid,
    inactiveBorderColor: _separator,
    promptColor: _bone,
    reflectionTextColor: _glow,
    mutedColor: _silverLow,
    fieldFillColor: Color(0x08FFFFFF),
    microphoneBackgroundColor: Color(0x146876D8),
    displayFontFamily: _display,
    uiFontFamily: _ui,
  );

  final TextEditingController _reflectionController = TextEditingController();
  FollowSkyTurningController? _turning;
  late FollowSkyViewTimeController _instrumentController;
  Timer? _liveTickTimer;
  bool _isLiveTracking = false;
  bool _reflectionOpen = false;
  bool _hydratingReflection = false;
  bool _reflectionEditedBeforeHydration = false;
  bool _committingCompletion = false;
  CompletionStatus _completion = CompletionStatus.none;

  @override
  void initState() {
    super.initState();
    final now = _presentationNow();
    _instrumentController = FollowSkyViewTimeController(
      track: widget.model.track,
      now: now,
    );
    _reflectionController.addListener(_onReflectionChanged);
    _turning = _createTurningController();
    unawaited(_loadTurning());
    if (_isWithinTrackingWindow(now)) {
      _startLiveTracking(now);
    }
  }

  @override
  void didUpdateWidget(covariant FollowSkyObservationPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final turningChanged =
        oldWidget.turningController != widget.turningController ||
        oldWidget.clientEventId != widget.clientEventId ||
        oldWidget.skyEventId != widget.skyEventId;
    if (oldWidget.model != widget.model) {
      _stopLiveTracking();
      _instrumentController.dispose();
      final now = _presentationNow();
      _instrumentController = FollowSkyViewTimeController(
        track: widget.model.track,
        now: now,
      );
      if (_isWithinTrackingWindow(now)) {
        _startLiveTracking(now);
      }
      _reflectionOpen = false;
    }
    if (turningChanged) {
      final previous = _turning;
      _turning = _createTurningController();
      _reflectionEditedBeforeHydration = false;
      _hydratingReflection = true;
      _reflectionController.clear();
      _hydratingReflection = false;
      _completion = CompletionStatus.none;
      unawaited(previous?.close());
      unawaited(_loadTurning());
    }
  }

  @override
  void dispose() {
    _stopLiveTracking();
    _instrumentController.dispose();
    unawaited(_turning?.close());
    _reflectionController
      ..removeListener(_onReflectionChanged)
      ..dispose();
    super.dispose();
  }

  FollowSkyTurningController? _createTurningController() {
    final injected = widget.turningController;
    if (injected != null) return injected;
    final clientEventId = widget.clientEventId;
    final completionIdentity = widget.completionIdentity;
    final skyEventId = widget.skyEventId;
    final localDate = widget.localDate;
    final scheduledTimeSnapshot = widget.scheduledTimeSnapshot;
    final onCommitCompletion = widget.onCommitCompletion;
    if (clientEventId == null ||
        completionIdentity == null ||
        skyEventId == null ||
        localDate == null ||
        scheduledTimeSnapshot == null ||
        onCommitCompletion == null) {
      return null;
    }
    return FollowSkyTurningController.live(
      client: Supabase.instance.client,
      clientEventId: clientEventId,
      completionIdentity: completionIdentity,
      skyEventId: skyEventId,
      localDate: localDate,
      scheduledTimeSnapshot: scheduledTimeSnapshot,
      intentionSnapshot: widget.intentionSnapshot,
      onCommitCompletion: onCommitCompletion,
      onWriteJournalResponse: widget.onWriteJournalResponse,
    );
  }

  Future<void> _loadTurning() async {
    final turning = _turning;
    if (turning == null) return;
    try {
      final record = await turning.initialize();
      if (!mounted || !identical(turning, _turning)) return;
      if (!_reflectionEditedBeforeHydration) {
        _hydratingReflection = true;
        _reflectionController.text = record.reflectionText;
        _hydratingReflection = false;
      }
      setState(() => _completion = turning.completion);
    } on Object {
      // Keep the approved presentation available. The local-first Turning
      // Record path will retry the next time the sheet opens.
    }
  }

  void _onReflectionChanged() {
    if (_hydratingReflection) return;
    _reflectionEditedBeforeHydration = true;
    _turning?.scheduleReflection(_reflectionController.text);
  }

  DateTime _presentationNow() => followSkyWallTime(
    (widget.now ?? DateTime.now)(),
    widget.model.ianaTimeZone,
  );

  bool _isWithinTrackingWindow(DateTime now) {
    return isFollowSkyTrackLiveTime(now: now, track: widget.model.track);
  }

  void _startLiveTracking(DateTime now) {
    _isLiveTracking = true;
    _scheduleLiveTick(now);
  }

  void _scheduleLiveTick(DateTime now) {
    _liveTickTimer?.cancel();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _liveTickTimer = Timer(nextMinute.difference(now), _followClock);
  }

  void _followClock() {
    if (!_isLiveTracking || !mounted) return;
    final now = _presentationNow();
    final track = widget.model.track;
    if (now.isAfter(track.trackEnd)) {
      _instrumentController.selectTime(track.trackEnd, manual: false);
      _stopLiveTracking();
      return;
    }
    if (now.isBefore(track.trackStart)) {
      _stopLiveTracking();
      return;
    }
    _instrumentController.followClock(now);
    _scheduleLiveTick(now);
  }

  void _stopLiveTracking() {
    _isLiveTracking = false;
    _liveTickTimer?.cancel();
    _liveTickTimer = null;
  }

  void _selectFraction(double fraction) {
    _stopLiveTracking();
    _instrumentController.selectFraction(fraction);
  }

  @override
  Widget build(BuildContext context) {
    return InstrumentEventPresentationFrame(
      key: const ValueKey<String>('follow-sky-observation-presentation'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0, 0.34, 0.74],
          colors: <Color>[Color(0xFF1B1220), Color(0xFF140F1A), _velvet],
        ),
      ),
      instrument: _buildSky(),
      instrumentFooter: Column(
        children: <Widget>[
          Expanded(child: _buildFinder()),
          _buildDragInstruction(),
        ],
      ),
      inputBuilder: (context, heroHeight, _) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(height: heroHeight, child: _buildSkyInput()),
      ),
      body: _buildBody(),
      bodyScrollKey: const ValueKey<String>('follow-sky-presentation-body'),
      lowerSheetKey: const ValueKey<String>('follow-sky-static-lower-sheet'),
    );
  }

  Widget _buildSky() {
    final instrument = _instrumentController;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FollowSkyInstrumentSurface(
          data: widget.model.instrument,
          peakMarker: widget.model.peakMarker,
          controller: instrument,
        ),
        Positioned(
          top: 18,
          left: 20,
          right: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metaWidth = constraints.maxWidth < 330 ? 96.0 : 112.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      key: const ValueKey<String>(
                        'follow-sky-header-title-zone',
                      ),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            _SkySparkle(),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'FOLLOW THE SKY',
                                softWrap: true,
                                style: TextStyle(
                                  color: _gold,
                                  fontFamily: _ui,
                                  fontSize: 10.5,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.model.title,
                          key: const ValueKey<String>('follow-sky-event-title'),
                          maxLines: 4,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: _display,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                            height: 1.04,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black87, blurRadius: 22),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    key: const ValueKey<String>('follow-sky-header-meta-zone'),
                    width: metaWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '${widget.model.dateLabel}\n',
                                style: const TextStyle(
                                  color: _rose,
                                  letterSpacing: 1.05,
                                ),
                              ),
                              TextSpan(text: '${widget.model.locationLabel}\n'),
                              TextSpan(
                                text: widget.model.peakMarker.displayLabel,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: _silverLow,
                            fontFamily: _ui,
                            fontSize: 9.5,
                            height: 1.35,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: instrument,
                          builder: (context, selectedAt, _) => Text(
                            _formatSelection(
                              selectedAt,
                              widget.model.track,
                              multiline: true,
                            ),
                            key: const ValueKey<String>('follow-sky-view-time'),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: _glow,
                              fontFamily: _display,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              shadows: <Shadow>[
                                Shadow(color: _glow, blurRadius: 10),
                                Shadow(color: Colors.black87, blurRadius: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkyInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) {
          _selectFraction(
            ((position.dx - 42) / (constraints.maxWidth - 84)).clamp(0.0, 1.0),
          );
        }

        final instrument = _instrumentController;
        final gesture = GestureDetector(
          key: const ValueKey<String>('follow-sky-hero-drag'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => update(details.localPosition),
          onHorizontalDragDown: (details) => update(details.localPosition),
          onHorizontalDragUpdate: (details) => update(details.localPosition),
          child: const SizedBox.expand(),
        );
        return ValueListenableBuilder<DateTime>(
          valueListenable: instrument,
          child: gesture,
          builder: (context, selectedAt, child) {
            final reading = FollowSkyInstrumentSurface.readingFor(
              widget.model.instrument,
              widget.model.track,
              selectedAt,
            );
            final selectedFraction = instrument.fractionFor(selectedAt);
            return Semantics(
              label:
                  '${widget.model.locationLabel} ${widget.model.visual.semanticLabel} presentation instrument',
              value: reading.semanticsValue,
              increasedValue: _formatTime(
                instrument.timeAtFraction(
                  (selectedFraction + 0.02).clamp(0.0, 1.0),
                ),
              ),
              decreasedValue: _formatTime(
                instrument.timeAtFraction(
                  (selectedFraction - 0.02).clamp(0.0, 1.0),
                ),
              ),
              slider: true,
              onIncrease: () =>
                  _selectFraction((selectedFraction + 0.02).clamp(0.0, 1.0)),
              onDecrease: () =>
                  _selectFraction((selectedFraction - 0.02).clamp(0.0, 1.0)),
              child: child,
            );
          },
        );
      },
    );
  }

  Widget _buildFinder() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _instrumentController,
      builder: (context, selectedAt, _) {
        final reading = FollowSkyInstrumentSurface.readingFor(
          widget.model.instrument,
          widget.model.track,
          selectedAt,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  reading.primary,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    color: _glow,
                    fontFamily: _display,
                    fontSize: 23,
                    fontStyle: FontStyle.italic,
                    shadows: <Shadow>[Shadow(color: _glow, blurRadius: 10)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  reading.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _silverMid,
                    fontFamily: _ui,
                    fontSize: 12.5,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragInstruction() {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _instrumentController,
      builder: (context, selectedAt, _) => LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth < 350 ? 12.0 : 20.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 2, horizontal, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: widget.model.copy.dragLead),
                    TextSpan(
                      text:
                          'Your view time moves to ${_formatTime(selectedAt)}.',
                      style: const TextStyle(
                        color: _glow,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
                key: const ValueKey<String>('follow-sky-drag-instruction'),
                style: const TextStyle(
                  color: _silverLow,
                  fontFamily: _ui,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  height: 1.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      key: const ValueKey<String>('follow-sky-foreground-layer'),
      padding: const EdgeInsets.only(bottom: 22),
      decoration: const BoxDecoration(
        color: _velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0x3A6876D8))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.model.copy.lensLabel,
                  style: const TextStyle(
                    color: _periwinkle,
                    fontFamily: _ui,
                    fontSize: 10.5,
                    letterSpacing: 2.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.model.copy.lensStatement,
                  style: const TextStyle(
                    color: _bone,
                    fontFamily: _display,
                    fontSize: 21,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 17, 20, 0),
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _glow.withValues(alpha: 0.28)),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[
                  _periwinkle.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.018),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'YOU CHOSE',
                  style: TextStyle(
                    color: _glow,
                    fontFamily: _ui,
                    fontSize: 10,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.model.intention?.isNotEmpty == true
                      ? '“${widget.model.intention}”'
                      : 'No prior intention was saved for this turning.',
                  style: const TextStyle(
                    color: _bone,
                    fontFamily: _display,
                    fontSize: 21,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.model.copy.intentionContext,
                  style: const TextStyle(
                    color: _silverLow,
                    fontFamily: _ui,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          InstrumentEventReflectionSection(
            open: _reflectionOpen,
            onToggle: () => setState(() => _reflectionOpen = !_reflectionOpen),
            prompt: widget.model.copy.reflectionPrompt,
            controller: _reflectionController,
            fieldKey: const ValueKey<String>('follow-sky-fixture-reflection'),
            style: _reflectionStyle,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
            child: Row(
              children: <Widget>[
                const Text(
                  'COMPLETION',
                  style: TextStyle(
                    color: _goldDim,
                    fontFamily: _ui,
                    fontSize: 10.5,
                    letterSpacing: 2.7,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(child: Container(height: 1, color: _separator)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: <Widget>[
                _completionChip('Observed', CompletionStatus.observed),
                const SizedBox(width: 9),
                _completionChip('Partly', CompletionStatus.partial),
                const SizedBox(width: 9),
                _completionChip('Skipped', CompletionStatus.skipped),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _completionChip(String label, CompletionStatus value) {
    final selected = _completion == value;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => unawaited(_commitCompletion(value)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 45),
          padding: EdgeInsets.zero,
          foregroundColor: selected ? _glow : _silverMid,
          backgroundColor: selected
              ? _periwinkle.withValues(alpha: 0.13)
              : Colors.transparent,
          side: BorderSide(
            color: selected ? _glow : _bone.withValues(alpha: 0.18),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: _display,
            fontSize: 16.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _commitCompletion(CompletionStatus selected) async {
    if (_committingCompletion) return;
    final turning = _turning;
    if (turning == null) {
      setState(() {
        _completion = selected == _completion
            ? CompletionStatus.none
            : selected;
      });
      return;
    }
    final previous = _completion;
    _committingCompletion = true;
    try {
      final result = await turning.toggleCompletion(selected);
      if (!mounted || !identical(turning, _turning)) return;
      setState(() => _completion = result.status);
    } on Object {
      if (!mounted || !identical(turning, _turning)) return;
      setState(() => _completion = previous);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not record this turning.')),
      );
    } finally {
      _committingCompletion = false;
    }
  }
}

class _SkySparkle extends StatelessWidget {
  const _SkySparkle();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey<String>('follow-sky-sparkle'),
    width: 12,
    height: 12,
    child: CustomPaint(painter: _SkySparklePainter()),
  );
}

class _SkySparklePainter extends CustomPainter {
  const _SkySparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(
        center.dx + 1.2,
        center.dy - 1.2,
        size.width,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 1.2,
        center.dy + 1.2,
        center.dx,
        size.height,
      )
      ..quadraticBezierTo(center.dx - 1.2, center.dy + 1.2, 0, center.dy)
      ..quadraticBezierTo(center.dx - 1.2, center.dy - 1.2, center.dx, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _FollowSkyObservationPresentationState._gold,
    );
  }

  @override
  bool shouldRepaint(covariant _SkySparklePainter oldDelegate) => false;
}

String _formatTime(DateTime value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
}

String _formatSelection(
  DateTime value,
  FollowSkyTrackDefinition track, {
  bool multiline = false,
}) {
  if (!track.spansMultipleCivilDays) return _formatTime(value);
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final separator = multiline ? '\n' : ' · ';
  return '${months[value.month - 1]} ${value.day}$separator${_formatTime(value)}';
}
