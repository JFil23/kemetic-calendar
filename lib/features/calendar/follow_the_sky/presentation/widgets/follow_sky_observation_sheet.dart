import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

import '../../domain/observing_place.dart';
import '../../domain/sky_instrument_data.dart';
import '../../domain/turning_record.dart';
import '../../services/follow_sky_photo_store.dart';
import '../../services/full_moon_instrument_data_provider.dart';
import '../../services/observing_place_store.dart';
import '../../services/sky_catalog_repository.dart';
import '../../services/follow_sky_turning_controller.dart';
import '../../services/turning_record_repository.dart';
import 'lunar_path_instrument.dart';

typedef FollowSkyTimeCommit = Future<bool> Function(DateTime newStartLocal);

class FollowSkyObservationSheet extends StatefulWidget {
  const FollowSkyObservationSheet({
    super.key,
    required this.clientEventId,
    required this.completionIdentity,
    required this.skyEventId,
    required this.title,
    required this.localDate,
    required this.startMinute,
    required this.endMinute,
    required this.intentionSnapshot,
    required this.onCommitStartTime,
    required this.onCommitCompletion,
    this.onWriteJournalResponse,
    this.completionPickerStyle,
    this.onUseMyLocation,
    this.onChoosePlace,
  });

  final String clientEventId;
  final String completionIdentity;
  final String skyEventId;
  final String title;
  final DateTime localDate;
  final int startMinute;
  final int endMinute;
  final String? intentionSnapshot;
  final FollowSkyTimeCommit onCommitStartTime;
  final FollowSkyCompletionCommit onCommitCompletion;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final CalendarCompletionPickerStyle? completionPickerStyle;
  final Future<ObservingPlace?> Function()? onUseMyLocation;
  final Future<ObservingPlace?> Function()? onChoosePlace;

  @override
  State<FollowSkyObservationSheet> createState() =>
      _FollowSkyObservationSheetState();
}

class _FollowSkyObservationSheetState extends State<FollowSkyObservationSheet> {
  static const Color _gold = Color(0xFFFFD486);
  static const Color _blue = Color(0xFF617CAC);

  final TextEditingController _reflectionController = TextEditingController();
  late FollowSkyTurningController _turning;
  late final FollowSkyPhotoStore _photos = FollowSkyPhotoStore(
    Supabase.instance.client,
  );
  final FollowSkyPhotoReplacementCoordinator _photoReplacement =
      const FollowSkyPhotoReplacementCoordinator();
  TurningRecord? _record;
  SkyInstrumentData? _instrument;
  Uint8List? _photoPreview;
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;
  bool _capturing = false;
  bool _listening = false;
  bool _rescheduling = false;
  bool _pendingCloudSync = false;
  bool _hydratingText = false;
  late DateTime _authoritativeTime;
  late DateTime _previewTime;
  String? _movementMessage;
  CompletionStatus _completion = CompletionStatus.none;
  String _dictationBase = '';

  @override
  void initState() {
    super.initState();
    _authoritativeTime = _scheduledTime;
    _previewTime = _scheduledTime;
    _turning = _createTurningController();
    _reflectionController.addListener(_onReflectionChanged);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FollowSkyObservationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientEventId != widget.clientEventId ||
        oldWidget.skyEventId != widget.skyEventId) {
      unawaited(_turning.close());
      _turning = _createTurningController();
      _authoritativeTime = _scheduledTime;
      _previewTime = _scheduledTime;
      unawaited(_load());
      return;
    }
    if (oldWidget.startMinute != widget.startMinute && !_rescheduling) {
      _authoritativeTime = _scheduledTime;
      _previewTime = _scheduledTime;
    }
  }

  DateTime get _scheduledTime => DateTime(
    widget.localDate.year,
    widget.localDate.month,
    widget.localDate.day,
    widget.startMinute ~/ 60,
    widget.startMinute % 60,
  );

  @override
  void dispose() {
    unawaited(_turning.close());
    _reflectionController
      ..removeListener(_onReflectionChanged)
      ..dispose();
    if (_listening) unawaited(_FollowSkySpeechInput.instance.stop());
    super.dispose();
  }

  FollowSkyTurningController _createTurningController() {
    return FollowSkyTurningController.live(
      client: Supabase.instance.client,
      clientEventId: widget.clientEventId,
      completionIdentity: widget.completionIdentity,
      skyEventId: widget.skyEventId,
      localDate: widget.localDate,
      scheduledTimeSnapshot: _scheduledTime,
      intentionSnapshot: widget.intentionSnapshot,
      onCommitCompletion: widget.onCommitCompletion,
      onWriteJournalResponse: widget.onWriteJournalResponse,
    );
  }

  Future<void> _load() async {
    final turning = _turning;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final catalog = await SkyCatalogRepository().load();
      final anchor = catalog.byId(widget.skyEventId);
      if (anchor == null || anchor.mergedIntoId != null) {
        throw StateError('This observing night is not in the sky catalog.');
      }
      final night = catalog.observingNight(anchor);
      final place = await const ObservingPlaceStore().load();
      final instrument = await FullMoonInstrumentDataProvider().resolve(
        night: night,
        place: place,
      );
      final scheduled = _scheduledTime;
      final record = await turning.initialize();
      if (!mounted || !identical(turning, _turning)) return;
      _hydratingText = true;
      _reflectionController.text = record.reflectionText;
      _hydratingText = false;
      setState(() {
        _record = record;
        _instrument = instrument;
        _authoritativeTime = scheduled;
        _previewTime = _clampToViewingWindow(scheduled, instrument);
        _pendingCloudSync = turning.pendingCloudSync;
        _completion = turning.completion;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _onReflectionChanged() {
    if (_hydratingText) return;
    if (mounted) setState(() {});
    _turning.scheduleReflection(_reflectionController.text);
  }

  Future<TurningRecordSaveResult> _mutateRecord(
    TurningRecord Function(TurningRecord current) mutation,
  ) async {
    if (mounted) setState(() => _saving = true);
    try {
      final result = await _turning.mutateRecord(mutation);
      if (mounted) {
        setState(() {
          _record = result.record;
          _pendingCloudSync = _turning.pendingCloudSync;
          _saving = false;
        });
      }
      return result;
    } on Object {
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
  }

  Future<void> _commitPreview(DateTime selected) async {
    if (_rescheduling || selected.isAtSameMomentAs(_authoritativeTime)) return;
    final previous = _authoritativeTime;
    setState(() {
      _rescheduling = true;
      _movementMessage = null;
    });
    final moved = await widget.onCommitStartTime(selected);
    if (!mounted) return;
    setState(() {
      _rescheduling = false;
      if (moved) {
        _authoritativeTime = selected;
        _previewTime = selected;
        _movementMessage =
            'Your observation moved to ${_formatDateTime(selected)}.';
      } else {
        _previewTime = _clampToViewingWindow(previous, _instrument!);
        _movementMessage = 'The calendar could not move this observation.';
      }
    });
  }

  Future<void> _commitCompletion(CompletionStatus selected) async {
    if (_saving || _record == null) return;
    final previous = _completion;
    setState(() => _saving = true);
    try {
      final result = await _turning.toggleCompletion(selected);
      if (!mounted) return;
      setState(() {
        _record = result.record;
        _completion = result.status;
        _pendingCloudSync = _turning.pendingCloudSync;
        _saving = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _completion = previous;
        _saving = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not record this turning.')),
      );
    }
  }

  Future<void> _capturePhoto() async {
    final current = _record;
    if (current == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final capture = await _FollowSkyCameraInput.instance.capture();
      if (capture == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final bytes = capture.bytes;
      final extension = capture.extension;
      final contentType = capture.contentType;
      final previousObjectPath = current.photoObjectPath;
      final result = await _photoReplacement.replace(
        previousObjectPath: previousObjectPath,
        uploadNew: () => _photos.upload(
          record: current,
          bytes: bytes,
          contentType: contentType,
          extension: extension,
        ),
        persistNewReference: (objectPath) => _mutateRecord(
          (latest) => latest.copyWith(
            photoObjectPath: objectPath,
            lastEditedAt: DateTime.now().toUtc(),
          ),
        ),
        deleteObject: _photos.delete,
      );
      if (!mounted) return;
      setState(() {
        _record = result.record;
        _photoPreview = bytes;
        _capturing = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Could not archive the photo: $error')),
      );
    }
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _FollowSkySpeechInput.instance.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _dictationBase = _reflectionController.text.trimRight();
    final available = await _FollowSkySpeechInput.instance.start(
      onResult: _onSpeechResult,
      onListeningChanged: (listening) {
        if (mounted) setState(() => _listening = listening);
      },
    );
    if (!available && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Dictation is unavailable. The keyboard still works.'),
        ),
      );
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();
    final separator = _dictationBase.isEmpty || words.isEmpty ? '' : ' ';
    _reflectionController
      ..text = '$_dictationBase$separator$words'
      ..selection = TextSelection.collapsed(
        offset: '$_dictationBase$separator$words'.length,
      );
  }

  DateTime _clampToViewingWindow(DateTime value, SkyInstrumentData data) {
    if (value.isBefore(data.viewingWindowStart)) {
      return data.viewingWindowStart;
    }
    if (value.isAfter(data.viewingWindowEnd)) return data.viewingWindowEnd;
    return value;
  }

  String _formatTime(DateTime value) {
    final hour = value.hour;
    final minutes = value.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:${minutes.toString().padLeft(2, '0')} $period';
  }

  String _formatDateTime(DateTime value) {
    const months = <String>[
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
    return '${months[value.month - 1]} ${value.day} · ${_formatTime(value)}';
  }

  Future<void> _useMyLocation() async {
    final resolver = widget.onUseMyLocation;
    if (resolver == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Device location is not enabled here yet. Choose a place instead.',
          ),
        ),
      );
      return;
    }
    final place = await resolver();
    if (place == null) return;
    await const ObservingPlaceStore().save(place);
    await _load();
  }

  Future<void> _choosePlace() async {
    final resolver = widget.onChoosePlace;
    final selected = resolver == null
        ? await _showManualPlaceDialog()
        : await resolver();
    if (selected == null) return;
    await const ObservingPlaceStore().save(selected);
    await _load();
  }

  Future<ObservingPlace?> _showManualPlaceDialog() async {
    final label = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final timeZone = TextEditingController(text: 'America/Los_Angeles');
    try {
      return await showDialog<ObservingPlace>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF111114),
          title: const Text(
            'Choose an observing place',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  decoration: const InputDecoration(labelText: 'Place name'),
                ),
                TextField(
                  controller: latitude,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                TextField(
                  controller: longitude,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                TextField(
                  controller: timeZone,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  decoration: const InputDecoration(
                    labelText: 'IANA time zone',
                    hintText: 'America/Los_Angeles',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final lat = double.tryParse(latitude.text.trim());
                final lon = double.tryParse(longitude.text.trim());
                final zone = timeZone.text.trim();
                final name = label.text.trim();
                var validTimeZone = false;
                if (zone.isNotEmpty) {
                  try {
                    tzdata.initializeTimeZones();
                    tz.getLocation(zone);
                    validTimeZone = true;
                  } on Object {
                    validTimeZone = false;
                  }
                }
                if (lat == null ||
                    lon == null ||
                    lat < -90 ||
                    lat > 90 ||
                    lon < -180 ||
                    lon > 180 ||
                    !validTimeZone ||
                    name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter a valid place.')),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ObservingPlace(
                    latitude: lat,
                    longitude: lon,
                    ianaTimeZone: zone,
                    label: name,
                    source: ObservingPlaceSource.manual,
                  ),
                );
              },
              child: const Text('Use place'),
            ),
          ],
        ),
      );
    } finally {
      label.dispose();
      latitude.dispose();
      longitude.dispose();
      timeZone.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }
    if (_loadError != null || _instrument == null || _record == null) {
      final mismatch = _loadError is FullMoonInstrumentProvenanceMismatch;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FOLLOW THE SKY',
              style: TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mismatch
                  ? 'Catalog and computed astronomy do not agree closely enough. Local geometry is withheld; your calendar event is unchanged.'
                  : 'The instrument could not open. Your calendar event is unchanged.',
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final instrument = _instrument!;
    final hasPhoto = _record!.photoObjectPath?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FOLLOW THE SKY',
            style: TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'CormorantGaramond',
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.03,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatDateTime(_authoritativeTime)} · ${instrument.visibility.summary}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              Text(
                instrument.visibility.isLocal
                    ? 'LOCAL SKY'
                    : instrument.visibility.isTimeFallback
                    ? 'TIME FALLBACK'
                    : 'LOCAL TIME',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _instrumentWidget(instrument),
          if (!instrument.visibility.isLocal) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _useMyLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use my location'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _choosePlace,
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Choose a place'),
                  ),
                ),
              ],
            ),
          ],
          if (_rescheduling)
            const Center(
              child: Text(
                'Moving calendar and reminder…',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else if (_movementMessage != null)
            Center(
              child: Text(
                _movementMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _movementMessage!.startsWith('Your')
                      ? _gold
                      : Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'YOU CHOSE',
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.intentionSnapshot?.trim().isNotEmpty == true
                ? '“${widget.intentionSnapshot!.trim()}”'
                : 'No prior intention was saved for this turning.',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'CormorantGaramond',
              fontSize: 21,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'REFLECT',
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _reflectionController,
            scrollPadding: keyboardManagedTextFieldScrollPadding,
            minLines: 3,
            maxLines: 7,
            style: const TextStyle(color: Colors.white, height: 1.35),
            decoration: InputDecoration(
              hintText:
                  'What did staying true to your choice look like tonight?',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black26,
              suffixIcon: IconButton(
                tooltip: _listening ? 'Stop dictation' : 'Dictate reflection',
                onPressed: _toggleDictation,
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none,
                  color: _listening ? _gold : Colors.white54,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _gold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_photoPreview != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _photoPreview!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (_photoPreview != null) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _capturing ? null : _capturePhoto,
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: Color(0x88FFD486)),
              backgroundColor: Colors.black26,
            ),
            icon: Icon(hasPhoto ? Icons.flip_camera_ios : Icons.camera_alt),
            label: Text(
              _capturing
                  ? 'Archiving…'
                  : hasPhoto
                  ? 'Retake photo'
                  : 'Capture one photo',
            ),
          ),
          const SizedBox(height: 12),
          CalendarCompletionPicker(
            current: _completion,
            saving: _saving,
            loading: false,
            style: widget.completionPickerStyle,
            onChanged: (status) => unawaited(_commitCompletion(status)),
          ),
          const SizedBox(height: 9),
          Text(
            _saving
                ? 'Saving turning…'
                : _turning.hasPendingReflection
                ? 'Autosaving…'
                : _pendingCloudSync
                ? 'Saved on this device · cloud sync pending'
                : 'Saved as one turning record',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _instrumentWidget(SkyInstrumentData data) {
    return switch (data) {
      LunarPathData value => LunarPathInstrument(
        data: value,
        selectedAt: _previewTime,
        enabled: !_rescheduling,
        onPreview: (selected) => setState(() {
          _previewTime = selected;
          _movementMessage = null;
        }),
        onCommit: (selected) => unawaited(_commitPreview(selected)),
      ),
      MeteorWindowData value => MeteorWindowInstrument(data: value),
      OppositionData value => OppositionInstrument(data: value),
      ElongationData value => ElongationInstrument(data: value),
      ConjunctionData value => ConjunctionInstrument(data: value),
      SolarThresholdData value => SolarThresholdInstrument(data: value),
      SolarEclipseData value => SolarEclipseInstrument(data: value),
    };
  }
}

class MeteorWindowInstrument extends StatelessWidget {
  const MeteorWindowInstrument({super.key, required this.data});
  final MeteorWindowData data;
  @override
  Widget build(BuildContext context) =>
      _UnavailableInstrument(family: 'Meteor window', data: data);
}

class OppositionInstrument extends StatelessWidget {
  const OppositionInstrument({super.key, required this.data});
  final OppositionData data;
  @override
  Widget build(BuildContext context) =>
      _UnavailableInstrument(family: 'Opposition', data: data);
}

class ElongationInstrument extends StatelessWidget {
  const ElongationInstrument({super.key, required this.data});
  final ElongationData data;
  @override
  Widget build(BuildContext context) =>
      _UnavailableInstrument(family: 'Elongation', data: data);
}

class ConjunctionInstrument extends StatelessWidget {
  const ConjunctionInstrument({super.key, required this.data});
  final ConjunctionData data;
  @override
  Widget build(BuildContext context) =>
      _UnavailableInstrument(family: 'Conjunction', data: data);
}

class SolarThresholdInstrument extends StatelessWidget {
  const SolarThresholdInstrument({super.key, required this.data});
  final SolarThresholdData data;
  @override
  Widget build(BuildContext context) =>
      _UnavailableInstrument(family: 'Solar threshold', data: data);
}

class SolarEclipseInstrument extends StatelessWidget {
  const SolarEclipseInstrument({super.key, required this.data});
  final SolarEclipseData data;
  @override
  Widget build(BuildContext context) =>
      _UnavailableInstrument(family: 'Solar eclipse', data: data);
}

class _UnavailableInstrument extends StatelessWidget {
  const _UnavailableInstrument({required this.family, required this.data});
  final String family;
  final SkyInstrumentData data;

  @override
  Widget build(BuildContext context) => _TimingOnlyInstrument(
    title: '$family instrument not enabled',
    detail:
        'Catalog window ${_instrumentTimeRange(data.viewingWindowStart, data.viewingWindowEnd)}',
    note: 'No visual sky geometry is shown without an ephemeris provider.',
  );
}

class _TimingOnlyInstrument extends StatelessWidget {
  const _TimingOnlyInstrument({
    required this.title,
    required this.detail,
    required this.note,
  });
  final String title;
  final String detail;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule, color: Color(0xFFFFD486), size: 22),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: Color(0xFFB8C6E2))),
          const SizedBox(height: 5),
          Text(
            note,
            style: const TextStyle(color: Colors.white54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

String _instrumentTimeRange(DateTime start, DateTime end) {
  String time(DateTime value) {
    final period = value.hour >= 12 ? 'PM' : 'AM';
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
  }

  final crossesDate =
      start.year != end.year ||
      start.month != end.month ||
      start.day != end.day;
  if (!crossesDate) return '${time(start)}–${time(end)}';
  return '${start.month}/${start.day} ${time(start)}–${end.month}/${end.day} ${time(end)}';
}

class _FollowSkySpeechInput {
  _FollowSkySpeechInput._();
  static final _FollowSkySpeechInput instance = _FollowSkySpeechInput._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  ValueChanged<bool>? _onListeningChanged;

  Future<bool> start({
    required ValueChanged<SpeechRecognitionResult> onResult,
    required ValueChanged<bool> onListeningChanged,
  }) async {
    _onListeningChanged = onListeningChanged;
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          final listening = status == 'listening';
          _onListeningChanged?.call(listening);
        },
        onError: (_) => _onListeningChanged?.call(false),
      );
    }
    if (!_initialized) return false;
    await _speech.listen(onResult: onResult);
    _onListeningChanged?.call(true);
    return true;
  }

  Future<void> stop() async {
    await _speech.stop();
    _onListeningChanged?.call(false);
  }
}

class _FollowSkyCameraInput {
  _FollowSkyCameraInput._();
  static final _FollowSkyCameraInput instance = _FollowSkyCameraInput._();

  final ImagePicker _picker = ImagePicker();

  Future<_FollowSkyCapturedPhoto?> capture() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 2200,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    return _FollowSkyCapturedPhoto(
      bytes: await file.readAsBytes(),
      extension: extension,
      contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
  }
}

class _FollowSkyCapturedPhoto {
  const _FollowSkyCapturedPhoto({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}
