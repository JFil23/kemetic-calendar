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
    final summary = _controller.summary;
    final memberCount = summary?.memberCount ?? 0;
    final fixture = readingHouseRoomVisualFixture(
      context: context,
      controller: _controller,
      currentUserId: widget.dataSource.currentUserId,
      newMessageCount: _controller.newMessageCount,
      roomGlyph: '𓉐',
      roomSubtitle: summary == null
          ? 'The Reading House'
          : 'The Reading House · ${summary.title} · $memberCount ${memberCount == 1 ? 'reader' : 'readers'}',
    );
    final mediaHeight = MediaQuery.sizeOf(context).height * 0.78;
    final sheetHeight = mediaHeight < 720 ? mediaHeight : 720.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF0D1712),
              Color(0xFF08100C),
              Color(0xFF060906),
            ],
            stops: <double>[0, 0.38, 1],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 42,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF514D42),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 13,
              child: IconButton(
                key: const ValueKey<String>('reading-house-chat-sheet-close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 28, color: Color(0xFFD8B23C)),
              ),
            ),
            Positioned(
              top: 42,
              left: 0,
              right: 0,
              bottom: 0,
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
          ],
        ),
      ),
    );
  }
}
