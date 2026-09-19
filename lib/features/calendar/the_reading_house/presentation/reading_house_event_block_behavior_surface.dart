import 'dart:async';

import 'package:flutter/material.dart';

import '../reading_house_room_repository.dart';
import 'reading_house_event_block_visual.dart';

class ReadingHouseEventBlockBehaviorSurface extends StatefulWidget {
  const ReadingHouseEventBlockBehaviorSurface({
    super.key,
    required this.identity,
    required this.dataSource,
    required this.sittingNumber,
    required this.title,
    required this.prompt,
    this.width,
    this.height,
  });

  final ReadingHouseRoomIdentity identity;
  final ReadingHouseRoomDataSource? dataSource;
  final int sittingNumber;
  final String title;
  final String prompt;
  final double? width;
  final double? height;

  @override
  State<ReadingHouseEventBlockBehaviorSurface> createState() =>
      _ReadingHouseEventBlockBehaviorSurfaceState();
}

class _ReadingHouseEventBlockBehaviorSurfaceState
    extends State<ReadingHouseEventBlockBehaviorSurface> {
  StreamSubscription<List<ReadingHouseRoomSummary>>? _subscription;
  ReadingHouseRoomSummary? _summary;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(
    covariant ReadingHouseEventBlockBehaviorSurface oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        !identical(oldWidget.dataSource, widget.dataSource)) {
      unawaited(_subscription?.cancel());
      _summary = null;
      _subscribe();
    }
  }

  void _subscribe() {
    final source = widget.dataSource;
    if (source == null || !widget.identity.isValid) return;
    _subscription = source.watchSummaries().listen((summaries) {
      ReadingHouseRoomSummary? next;
      for (final summary in summaries) {
        if (summary.identity == widget.identity) {
          next = summary;
          break;
        }
      }
      if (!mounted || identical(next, _summary)) return;
      setState(() => _summary = next);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membership = readingHouseEventBlockMembership(
      summary: _summary,
      currentUserId: widget.dataSource?.currentUserId,
    );
    return ReadingHouseEventBlockVisual(
      size: ReadingHouseEventBlockSize.compact,
      sittingNumber: widget.sittingNumber,
      title: widget.title,
      prompt: widget.prompt,
      memberInitials: membership.initials,
      memberLabel: membership.label,
      width: widget.width,
      height: widget.height,
    );
  }
}

@immutable
class ReadingHouseEventBlockMembership {
  const ReadingHouseEventBlockMembership({
    required this.initials,
    required this.label,
  });

  final List<String> initials;
  final String label;
}

ReadingHouseEventBlockMembership readingHouseEventBlockMembership({
  required ReadingHouseRoomSummary? summary,
  required String? currentUserId,
}) {
  final members = summary?.members ?? const <ReadingHouseRoomMember>[];
  final count = (summary?.memberCount ?? 1).clamp(1, 9999).toInt();
  final initials = members
      .map((member) {
        if (member.userId == currentUserId) return 'Y';
        final name = member.displayName?.trim().isNotEmpty == true
            ? member.displayName!.trim()
            : member.handle?.trim() ?? '';
        return _initials(name);
      })
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: true);
  if (initials.isEmpty) initials.add('Y');

  return ReadingHouseEventBlockMembership(
    initials: List<String>.unmodifiable(initials),
    label: switch (count) {
      1 => 'You',
      2 => 'You and 1 other reader',
      _ => 'You and ${count - 1} other readers',
    },
  );
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
