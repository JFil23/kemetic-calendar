import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/completion_status.dart';
import '../../data/flow_appearance.dart';
import '../../data/shared_practice_models.dart';
import '../../data/shared_practice_repo.dart';
import 'presentation/group_flow_ui_preview.dart';
import 'shared_practice_completion_sheet.dart';

typedef TogetherRoomForFlowLoader = Future<String?> Function(int flowId);
typedef TogetherRoomSnapshotLoader =
    Future<SharedPracticeRoomSnapshot> Function(
      String roomId,
      DateTime localDate,
    );
typedef TogetherMessageWatcher = Stream<void> Function(String roomId);

class TogetherFlowDayHero extends StatefulWidget {
  const TogetherFlowDayHero({
    super.key,
    required this.flowId,
    required this.clientEventId,
    required this.flowTitle,
    required this.calendarName,
    required this.appearance,
    required this.accent,
    required this.completedOccurrences,
    required this.totalOccurrences,
    required this.animationRevision,
    required this.fallback,
    this.animationFromCompletedOccurrences,
    this.resolveRoom,
    this.loadSnapshot,
    this.watchMessageChanges,
  });

  final int flowId;
  final String clientEventId;
  final String flowTitle;
  final String calendarName;
  final FlowAppearance appearance;
  final Color accent;
  final int completedOccurrences;
  final int totalOccurrences;
  final int animationRevision;
  final int? animationFromCompletedOccurrences;
  final Widget fallback;
  final TogetherRoomForFlowLoader? resolveRoom;
  final TogetherRoomSnapshotLoader? loadSnapshot;
  final TogetherMessageWatcher? watchMessageChanges;

  @override
  State<TogetherFlowDayHero> createState() => _TogetherFlowDayHeroState();
}

class _TogetherFlowDayHeroState extends State<TogetherFlowDayHero> {
  late final SharedPracticeRepo _repo = SharedPracticeRepo(
    Supabase.instance.client,
  );
  SharedPracticeRoomSnapshot? _snapshot;
  StreamSubscription<void>? _messageChangesSubscription;
  Timer? _refreshDebounce;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant TogetherFlowDayHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.clientEventId != widget.clientEventId) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    unawaited(_messageChangesSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    await _messageChangesSubscription?.cancel();
    _messageChangesSubscription = null;
    try {
      final roomId = await (widget.resolveRoom ?? _repo.getTogetherRoomForFlow)(
        widget.flowId,
      );
      if (roomId == null || roomId.isEmpty) {
        if (mounted) setState(() => _snapshot = null);
        return;
      }
      final snapshot = await (widget.loadSnapshot ?? _loadSnapshot)(
        roomId,
        DateTime.now(),
      );
      final todayClientEventId = snapshot.todayStep?.clientEventId.trim();
      final memberCount = snapshot.room.memberCount > snapshot.members.length
          ? snapshot.room.memberCount
          : snapshot.members.length;
      final isCurrentHostStep =
          todayClientEventId != null &&
          todayClientEventId.isNotEmpty &&
          todayClientEventId == widget.clientEventId.trim();
      if (!snapshot.viewerIsMember || memberCount < 2 || !isCurrentHostStep) {
        if (mounted) setState(() => _snapshot = null);
        return;
      }
      if (mounted) setState(() => _snapshot = snapshot);
      final watcher =
          widget.watchMessageChanges ?? _repo.watchSharedPracticeChanges;
      _messageChangesSubscription = watcher(roomId).listen((_) {
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 120), () {
          if (mounted) unawaited(_refreshSnapshot(roomId));
        });
      }, onError: (_) {});
    } catch (_) {
      if (mounted) setState(() => _snapshot = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<SharedPracticeRoomSnapshot> _loadSnapshot(
    String roomId,
    DateTime localDate,
  ) => _repo.getSharedPracticeRoom(roomId: roomId, localDate: localDate);

  Future<void> _refreshSnapshot(String roomId) async {
    try {
      final snapshot = await (widget.loadSnapshot ?? _loadSnapshot)(
        roomId,
        DateTime.now(),
      );
      final todayClientEventId = snapshot.todayStep?.clientEventId.trim();
      final memberCount = snapshot.room.memberCount > snapshot.members.length
          ? snapshot.room.memberCount
          : snapshot.members.length;
      final remainsCurrent =
          snapshot.viewerIsMember &&
          memberCount >= 2 &&
          todayClientEventId != null &&
          todayClientEventId.isNotEmpty &&
          todayClientEventId == widget.clientEventId.trim();
      if (mounted) {
        setState(() => _snapshot = remainsCurrent ? snapshot : null);
      }
    } catch (_) {
      if (mounted) setState(() => _snapshot = null);
    }
  }

  String? _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final initials = parts.map((part) => part.characters.first).join();
    return initials.isEmpty ? 'P' : initials.toUpperCase();
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  List<GroupFlowChatMessagePreview> _messages(
    SharedPracticeRoomSnapshot snapshot,
  ) {
    final currentUserId = _currentUserId();
    return snapshot.messages
        .map(
          (message) => GroupFlowChatMessagePreview(
            id: message.id,
            author: message.authorLabel,
            initials: _initials(message.authorLabel),
            body: message.bodyText,
            timeLabel: _timeLabel(message.createdAt),
            mine: currentUserId != null && message.userId == currentUserId,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _sendMessage(String body) async {
    final snapshot = _snapshot;
    final clean = body.trim();
    if (snapshot == null || clean.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendSharedPracticeMessage(
        roomId: snapshot.room.id,
        bodyText: clean,
      );
      await _refreshSnapshot(snapshot.room.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send that message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _postMessage(GroupFlowChatMessagePreview message) async {
    try {
      final post = await _repo.requestSharedPracticeQuotePost(message.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            post.approvalRequired
                ? 'Sent to ${message.author} for approval.'
                : 'Quote posted to Commons.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post that quote.')),
        );
      }
    }
  }

  Future<void> _observe(SharedPracticeRoomSnapshot snapshot) async {
    final step = snapshot.todayStep;
    if (step == null || step.clientEventId.isEmpty || step.flowId <= 0) return;
    final saved = await showSharedPracticeCompletionSheet(
      context: context,
      roomId: snapshot.room.id,
      calendarName: widget.calendarName,
      clientEventId: step.clientEventId,
      flowId: step.flowId,
      completedOn: snapshot.localDate,
      initialStatus: CompletionStatus.observed,
      stepTitle: step.title,
      completionMetadata: <String, dynamic>{
        'completion_status': CompletionStatus.observed.wireName,
        'source_type': 'maat_flow',
        'completed_on': _dateOnly(snapshot.localDate),
        'flow_title': snapshot.room.title,
        'event_title': step.title,
        if (snapshot.room.flowKey?.trim().isNotEmpty == true)
          'flow_key': snapshot.room.flowKey!.trim(),
      },
    );
    if (saved && mounted) await _refreshSnapshot(snapshot.room.id);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_loading || snapshot == null) return widget.fallback;
    final step = snapshot.todayStep;
    final positionLabel = step?.stepIndex != null && step?.totalSteps != null
        ? 'Day ${step!.stepIndex} of ${step.totalSteps} · host position'
        : 'Host’s current position';
    final memberCount = snapshot.room.memberCount > snapshot.members.length
        ? snapshot.room.memberCount
        : snapshot.members.length;
    return GroupFlowChatSurface(
      key: const ValueKey<String>('together-flow-day-chat'),
      flowTitle: widget.flowTitle,
      positionLabel: positionLabel,
      appearance: widget.appearance,
      accent: widget.accent,
      memberInitials: snapshot.members
          .map((member) => _initials(member.displayLabel))
          .take(3)
          .toList(growable: false),
      memberCount: memberCount,
      messages: _messages(snapshot),
      height: 190,
      completedOccurrences: widget.completedOccurrences,
      totalOccurrences: widget.totalOccurrences,
      animationRevision: widget.animationRevision,
      animationFromCompletedOccurrences:
          widget.animationFromCompletedOccurrences,
      onSendMessage: (body) => unawaited(_sendMessage(body)),
      onPostMessage: (message) => unawaited(_postMessage(message)),
      onObserve: () => unawaited(_observe(snapshot)),
    );
  }
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
