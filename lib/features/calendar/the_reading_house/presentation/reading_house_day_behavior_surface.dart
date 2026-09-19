import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/reading_house_private_margin_store.dart';
import 'package:mobile/features/calendar/reading_house_shared_fragments_repo.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_controller.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';

import 'reading_house_day_presentation.dart';

typedef ReadingHouseCompletionCommit =
    Future<void> Function(
      ReadingHouseCompletionVisualState state,
      Map<String, MaatFlowResponseValue> privateValues,
    );

/// Connects the approved Reading House Day View composition to one isolated
/// House-room controller. It owns behavior state only; the presentation file
/// remains the visual authority.
class ReadingHouseDayBehaviorSurface extends StatefulWidget {
  const ReadingHouseDayBehaviorSurface({
    super.key,
    required this.identity,
    required this.clientEventId,
    required this.eventNumber,
    required this.completionIdentity,
    required this.roomDataSource,
    required this.practiceRepository,
    required this.onCompletionCommit,
    required this.onPostSharedNote,
    this.privateMarginStore = const ReadingHousePrivateMarginStore(),
    this.solo = false,
  });

  final ReadingHouseRoomIdentity identity;
  final String clientEventId;
  final int? eventNumber;
  final String completionIdentity;
  final ReadingHouseRoomDataSource roomDataSource;
  final ReadingHouseSharedFragmentsRepo practiceRepository;
  final ReadingHousePrivateMarginStore privateMarginStore;
  final ReadingHouseCompletionCommit onCompletionCommit;
  final Future<void> Function(String body) onPostSharedNote;
  final bool solo;

  @override
  State<ReadingHouseDayBehaviorSurface> createState() =>
      _ReadingHouseDayBehaviorSurfaceState();
}

class _ReadingHouseDayBehaviorSurfaceState
    extends State<ReadingHouseDayBehaviorSurface> {
  late final ReadingHouseRoomController _roomController;
  late final ScrollController _chatScrollController;
  Timer? _reflectionSaveDebounce;
  int _announcementLoadGeneration = 0;
  bool _canModerate = false;
  String _hostAnnouncement = '';
  String _privateReflection = '';
  ReadingHouseCompletionVisualState _completion =
      ReadingHouseCompletionVisualState.none;

  @override
  void initState() {
    super.initState();
    _chatScrollController = ScrollController();
    _roomController = ReadingHouseRoomController(
      dataSource: widget.roomDataSource,
      identity: widget.identity,
    )..addListener(_handleRoomChanged);
    unawaited(_loadPracticeState());
    unawaited(_roomController.start());
  }

  @override
  void didUpdateWidget(covariant ReadingHouseDayBehaviorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      oldWidget.identity == widget.identity,
      'ReadingHouseDayBehaviorSurface must be keyed by House identity.',
    );
  }

  @override
  void dispose() {
    _reflectionSaveDebounce?.cancel();
    unawaited(_savePrivateReflection());
    _roomController
      ..removeListener(_handleRoomChanged)
      ..dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _handleRoomChanged() {
    if (!mounted) return;
    setState(() {});
    if (_roomController.status == ReadingHouseRoomStatus.ready) {
      unawaited(_loadAnnouncement());
    }
  }

  Future<void> _loadPracticeState() async {
    final results = await Future.wait<Object>(<Future<Object>>[
      widget.practiceRepository.canModerateHouse(
        calendarId: widget.identity.calendarId,
      ),
      widget.privateMarginStore.loadValues(
        flowId: widget.identity.flowId,
        eventNumber: widget.eventNumber,
      ),
      const CalendarCompletionLocalStore().load(widget.completionIdentity),
    ]);
    if (!mounted) return;
    final privateValues = results[1] as Map<String, MaatFlowResponseValue>;
    setState(() {
      _canModerate = results[0] as bool;
      _privateReflection =
          privateValues[kReadingHousePrivateReflectionSpecId]?.text ?? '';
      _completion = _visualCompletion(
        (results[2] as CalendarCompletionRecord).completionStatus,
      );
    });
    await _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    if (widget.solo) return;
    final generation = ++_announcementLoadGeneration;
    try {
      final announcements = await widget.practiceRepository.listAnnouncements(
        calendarId: widget.identity.calendarId,
        flowId: widget.identity.flowId,
      );
      if (!mounted || generation != _announcementLoadGeneration) return;
      ReadingHouseAnnouncement? selected;
      for (final announcement in announcements) {
        if (announcement.clientEventId == widget.clientEventId) {
          selected = announcement;
          break;
        }
      }
      selected ??= announcements.isEmpty ? null : announcements.first;
      setState(() => _hostAnnouncement = selected?.body ?? '');
    } catch (_) {
      // Room state remains usable when the separate announcement lane fails.
    }
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _sendMessage(String body) {
    unawaited(() async {
      try {
        await _roomController.send(body);
        if (_chatScrollController.hasClients) {
          await _chatScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      } catch (_) {
        _showFeedback('Could not send this chat message.');
      }
    }());
  }

  void _deleteMessage(String messageId) {
    unawaited(() async {
      try {
        await _roomController.deleteMessage(messageId);
      } catch (_) {
        _showFeedback('Could not delete this chat message.');
      }
    }());
  }

  void _jumpToLatest() {
    unawaited(() async {
      if (_chatScrollController.hasClients) {
        await _chatScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
      await _roomController.jumpToLatest();
    }());
  }

  void _postAnnouncement(String body) {
    if (!_canModerate) return;
    unawaited(() async {
      try {
        await widget.practiceRepository.createAnnouncement(
          calendarId: widget.identity.calendarId,
          flowId: widget.identity.flowId,
          clientEventId: widget.clientEventId,
          eventNumber: widget.eventNumber,
          body: body,
        );
        await _loadAnnouncement();
        _showFeedback('Host announcement added.');
      } catch (_) {
        _showFeedback('Could not add this announcement.');
      }
    }());
  }

  void _postSharedNote(String body) {
    unawaited(() async {
      try {
        await widget.onPostSharedNote(body);
      } catch (_) {
        _showFeedback('Could not post this shared note.');
      }
    }());
  }

  void _privateReflectionChanged(String value) {
    _privateReflection = value;
    _reflectionSaveDebounce?.cancel();
    _reflectionSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_savePrivateReflection()),
    );
  }

  Map<String, MaatFlowResponseValue> get _privateValues {
    final reflection = _privateReflection.trim();
    return <String, MaatFlowResponseValue>{
      if (reflection.isNotEmpty)
        kReadingHousePrivateReflectionSpecId: MaatFlowResponseValue.text(
          specId: kReadingHousePrivateReflectionSpecId,
          text: reflection,
          multiline: true,
        ),
    };
  }

  Future<void> _savePrivateReflection() {
    return widget.privateMarginStore.saveValues(
      flowId: widget.identity.flowId,
      eventNumber: widget.eventNumber,
      values: _privateValues,
    );
  }

  void _completionSelected(ReadingHouseCompletionVisualState selected) {
    unawaited(() async {
      final next = selected == _completion
          ? ReadingHouseCompletionVisualState.none
          : selected;
      try {
        await _savePrivateReflection();
        await widget.onCompletionCommit(next, _privateValues);
        await const CalendarCompletionLocalStore().save(
          identity: widget.completionIdentity,
          status: _completionStatus(next),
        );
        if (!mounted) return;
        setState(() => _completion = next);
        if (next == ReadingHouseCompletionVisualState.observed) {
          _showFeedback(
            _privateReflection.trim().isEmpty
                ? 'Observed.'
                : 'Observed · private reflection saved to Journal.',
          );
        }
      } catch (_) {
        _showFeedback('Could not record this sitting.');
      }
    }());
  }

  ReadingHouseDayVisualFixture _fixture(BuildContext context) {
    return readingHouseRoomVisualFixture(
      context: context,
      controller: _roomController,
      currentUserId: widget.roomDataSource.currentUserId,
      solo: widget.solo,
      newMessageCount: _roomController.newMessageCount,
      completion: _completion,
      hostAnnouncement: _hostAnnouncement,
      privateReflection: _privateReflection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReadingHouseDayPresentation(
      fixture: _fixture(context),
      chatScrollController: _chatScrollController,
      onFollowingLatestChanged: _roomController.setFollowingLatest,
      onLoadOlderMessages: () => unawaited(_roomController.loadOlder()),
      onSendMessage: _sendMessage,
      onDeleteMessage: _deleteMessage,
      onJumpToLatest: _jumpToLatest,
      onPostAnnouncement: _canModerate ? _postAnnouncement : null,
      onPostSharedNote: _postSharedNote,
      onPrivateReflectionChanged: _privateReflectionChanged,
      onCompletionSelected: _completionSelected,
    );
  }
}

ReadingHouseDayVisualFixture readingHouseRoomVisualFixture({
  required BuildContext context,
  required ReadingHouseRoomController controller,
  required String? currentUserId,
  bool solo = false,
  int newMessageCount = 0,
  ReadingHouseCompletionVisualState completion =
      ReadingHouseCompletionVisualState.none,
  String hostAnnouncement = '',
  String privateReflection = '',
  String? roomSubtitle,
  String roomGlyph = '◌',
}) {
  final summary = controller.summary;
  final members = summary?.members ?? const <ReadingHouseRoomMember>[];
  final messages = controller.messages
      .map((message) {
        ReadingHouseRoomMember? member;
        for (final candidate in members) {
          if (candidate.userId == message.authorId) {
            member = candidate;
            break;
          }
        }
        final mine = message.authorId == currentUserId;
        final author = mine ? 'You' : _memberLabel(member);
        return ReadingHouseChatMessageFixture(
          id: message.id,
          author: author,
          initials: mine ? 'Y' : _initials(author),
          timeLabel: MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(message.createdAt.toLocal()),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          body: message.body,
          host: _isHost(member),
          mine: mine,
        );
      })
      .toList(growable: false);
  final memberInitials = members
      .map((member) {
        if (member.userId == currentUserId) return 'Y';
        return _initials(_memberLabel(member));
      })
      .take(3)
      .toList(growable: false);
  return ReadingHouseDayVisualFixture(
    roomState: _readingHouseRoomVisualState(
      controller: controller,
      summary: summary,
      solo: solo,
    ),
    messages: messages,
    memberInitials: memberInitials,
    memberCount: summary?.memberCount ?? (solo ? 1 : 0),
    newMessageCount: newMessageCount,
    completion: completion,
    hostAnnouncement: hostAnnouncement,
    privateReflection: privateReflection,
    roomSubtitle: roomSubtitle ?? 'Logistics and quick notes',
    roomGlyph: roomGlyph,
  );
}

ReadingHouseRoomVisualState _readingHouseRoomVisualState({
  required ReadingHouseRoomController controller,
  required ReadingHouseRoomSummary? summary,
  required bool solo,
}) {
  if (solo) return ReadingHouseRoomVisualState.solo;
  return switch (controller.status) {
    ReadingHouseRoomStatus.idle ||
    ReadingHouseRoomStatus.loading => ReadingHouseRoomVisualState.loading,
    ReadingHouseRoomStatus.error => ReadingHouseRoomVisualState.error,
    ReadingHouseRoomStatus.ready =>
      summary?.ended == true
          ? ReadingHouseRoomVisualState.ended
          : summary?.locked == true || summary == null
          ? ReadingHouseRoomVisualState.locked
          : controller.messages.isEmpty
          ? ReadingHouseRoomVisualState.empty
          : ReadingHouseRoomVisualState.active,
  };
}

String _memberLabel(ReadingHouseRoomMember? member) {
  final displayName = member?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final handle = member?.handle?.trim();
  if (handle != null && handle.isNotEmpty) return handle;
  return 'House member';
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (words.isEmpty) return 'R';
  return words.map((word) => word.characters.first.toUpperCase()).join();
}

bool _isHost(ReadingHouseRoomMember? member) {
  final role = member?.role.trim().toLowerCase();
  return role == 'owner' || role == 'host' || role == 'moderator';
}

ReadingHouseCompletionVisualState _visualCompletion(CompletionStatus status) {
  return switch (status) {
    CompletionStatus.observed => ReadingHouseCompletionVisualState.observed,
    CompletionStatus.partial => ReadingHouseCompletionVisualState.partly,
    CompletionStatus.skipped => ReadingHouseCompletionVisualState.skipped,
    CompletionStatus.none => ReadingHouseCompletionVisualState.none,
  };
}

CompletionStatus _completionStatus(ReadingHouseCompletionVisualState status) {
  return switch (status) {
    ReadingHouseCompletionVisualState.observed => CompletionStatus.observed,
    ReadingHouseCompletionVisualState.partly => CompletionStatus.partial,
    ReadingHouseCompletionVisualState.skipped => CompletionStatus.skipped,
    ReadingHouseCompletionVisualState.none => CompletionStatus.none,
  };
}
