import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_behavior_surface.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_controller.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';

class ReadingHouseRoomSheet extends StatefulWidget {
  const ReadingHouseRoomSheet({
    super.key,
    required this.identity,
    required this.dataSource,
  });

  final ReadingHouseRoomIdentity identity;
  final ReadingHouseRoomDataSource dataSource;

  static Future<void> show(
    BuildContext context, {
    required ReadingHouseRoomIdentity identity,
    required ReadingHouseRoomDataSource dataSource,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ReadingHouseRoomSheet(identity: identity, dataSource: dataSource),
    );
  }

  @override
  State<ReadingHouseRoomSheet> createState() => _ReadingHouseRoomSheetState();
}

class _ReadingHouseRoomSheetState extends State<ReadingHouseRoomSheet> {
  late final ReadingHouseRoomController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = ReadingHouseRoomController(
      dataSource: widget.dataSource,
      identity: widget.identity,
    )..addListener(_rebuild);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _send(String body) {
    unawaited(() async {
      try {
        await _controller.send(body);
        await _moveToLatest();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send this chat message.')),
        );
      }
    }());
  }

  void _delete(String messageId) {
    unawaited(() async {
      try {
        await _controller.deleteMessage(messageId);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this chat message.')),
        );
      }
    }());
  }

  Future<void> _moveToLatest() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    await _controller.jumpToLatest();
  }

  @override
  Widget build(BuildContext context) {
    final fixture = readingHouseRoomVisualFixture(
      context: context,
      controller: _controller,
      currentUserId: widget.dataSource.currentUserId,
      newMessageCount: _controller.newMessageCount,
    );
    return FractionallySizedBox(
      heightFactor: 0.84,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ReadingHouseChatPresentation(
          fixture: fixture,
          chatScrollController: _scrollController,
          onFollowingLatestChanged: _controller.setFollowingLatest,
          onLoadOlderMessages: () => unawaited(_controller.loadOlder()),
          onSendMessage: _send,
          onDeleteMessage: _delete,
          onJumpToLatest: () => unawaited(_moveToLatest()),
        ),
      ),
    );
  }
}
