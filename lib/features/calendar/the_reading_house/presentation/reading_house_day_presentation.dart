import 'package:flutter/material.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';

enum ReadingHouseRoomVisualState {
  active,
  empty,
  locked,
  solo,
  ended,
  loading,
  error,
}

enum ReadingHouseCompletionVisualState { none, observed, partly, skipped }

@immutable
class ReadingHouseChatMessageFixture {
  const ReadingHouseChatMessageFixture({
    this.id,
    required this.author,
    required this.initials,
    required this.timeLabel,
    required this.body,
    this.host = false,
    this.mine = false,
  });

  final String? id;
  final String author;
  final String initials;
  final String timeLabel;
  final String body;
  final bool host;
  final bool mine;
}

@immutable
class ReadingHouseDayVisualFixture {
  const ReadingHouseDayVisualFixture({
    required this.roomState,
    required this.messages,
    this.memberInitials = const <String>['Y', 'AR'],
    this.memberCount = 2,
    this.newMessageCount = 0,
    this.completion = ReadingHouseCompletionVisualState.none,
    this.hostAnnouncement = '',
    this.privateReflection = '',
    this.roomSubtitle = 'Logistics and quick notes',
    this.roomGlyph = '◌',
  });

  final ReadingHouseRoomVisualState roomState;
  final List<ReadingHouseChatMessageFixture> messages;
  final List<String> memberInitials;
  final int memberCount;
  final int newMessageCount;
  final ReadingHouseCompletionVisualState completion;
  final String hostAnnouncement;
  final String privateReflection;
  final String roomSubtitle;
  final String roomGlyph;
}

const ReadingHouseDayVisualFixture kReadingHouseDayVisualFixture =
    ReadingHouseDayVisualFixture(
      roomState: ReadingHouseRoomVisualState.active,
      messages: <ReadingHouseChatMessageFixture>[
        ReadingHouseChatMessageFixture(
          id: 'fixture-message-1',
          author: 'Amina',
          initials: 'AR',
          timeLabel: '7:18',
          body: 'Can we start fifteen minutes later?',
          host: false,
        ),
        ReadingHouseChatMessageFixture(
          id: 'fixture-message-2',
          author: 'You',
          initials: 'Y',
          timeLabel: '7:20',
          body: 'Works for me.',
          host: true,
          mine: true,
        ),
        ReadingHouseChatMessageFixture(
          id: 'fixture-message-3',
          author: 'Amina',
          initials: 'AR',
          timeLabel: '7:21',
          body: 'Perfect. I’m finishing the opening section now.',
          host: false,
        ),
      ],
    );

abstract final class ReadingHouseDayTokens {
  static const Color velvet = Color(0xFF070B09);
  static const Color upper = Color(0xFF0D1A15);
  static const Color lower = Color(0xFF080B09);
  static const Color mint = Color(0xFF7FD9BC);
  static const Color mintLow = Color(0xFF3FA98A);
  static const Color bone = Color(0xFFE8EEE9);
  static const Color copy = Color(0xFFB8C4BE);
  static const Color muted = Color(0xFF687B72);
  static const Color gold = Color(0xFFD4AE43);
  static const Color separator = Color(0xFF203129);
}

/// Fixture-first Reading House sitting presentation.
///
/// The existing instrument frame owns the fixed-upper/rising-lower geometry.
/// A later room controller can inject messages and callbacks without changing
/// the approved composition.
class ReadingHouseDayPresentation extends StatelessWidget {
  const ReadingHouseDayPresentation({
    super.key,
    this.fixture = kReadingHouseDayVisualFixture,
    this.onSendMessage,
    this.onJumpToLatest,
    this.onPostAnnouncement,
    this.onPostSharedNote,
    this.onPrivateReflectionChanged,
    this.onCompletionSelected,
    this.chatScrollController,
    this.onFollowingLatestChanged,
    this.onLoadOlderMessages,
    this.onDeleteMessage,
  });

  final ReadingHouseDayVisualFixture fixture;
  final ValueChanged<String>? onSendMessage;
  final VoidCallback? onJumpToLatest;
  final ValueChanged<String>? onPostAnnouncement;
  final ValueChanged<String>? onPostSharedNote;
  final ValueChanged<String>? onPrivateReflectionChanged;
  final ValueChanged<ReadingHouseCompletionVisualState>? onCompletionSelected;
  final ScrollController? chatScrollController;
  final ValueChanged<bool>? onFollowingLatestChanged;
  final VoidCallback? onLoadOlderMessages;
  final ValueChanged<String>? onDeleteMessage;

  @override
  Widget build(BuildContext context) {
    return InstrumentEventPresentationFrame(
      key: const ValueKey<String>('reading-house-day-presentation'),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.75, -0.9),
          radius: 1.4,
          colors: <Color>[
            Color(0xFF173127),
            ReadingHouseDayTokens.upper,
            ReadingHouseDayTokens.velvet,
          ],
        ),
      ),
      instrument: ReadingHouseChatRoom(
        fixture: fixture,
        scrollController: chatScrollController,
        onFollowingLatestChanged: onFollowingLatestChanged,
        onLoadOlderMessages: onLoadOlderMessages,
        onDeleteMessage: onDeleteMessage,
        onSendMessage: onSendMessage,
        onJumpToLatest: onJumpToLatest,
      ),
      instrumentInteractive: true,
      instrumentFooter: const SizedBox.shrink(),
      inputBuilder: (_, _, _) => const SizedBox.shrink(),
      body: _ReadingPracticeSheet(
        fixture: fixture,
        onPostAnnouncement: onPostAnnouncement,
        onPostSharedNote: onPostSharedNote,
        onPrivateReflectionChanged: onPrivateReflectionChanged,
      ),
      completion: _CompletionBlock(
        selected: fixture.completion,
        onSelected: onCompletionSelected,
      ),
      bodyScrollKey: const ValueKey<String>('reading-house-presentation-body'),
      lowerSheetKey: const ValueKey<String>('reading-house-practice-sheet'),
      graphicSpace: const MaatDayViewGraphicSpace.fixed(height: 292),
      foregroundStyle: const MaatDayViewForegroundStyle.color(
        color: ReadingHouseDayTokens.lower,
        borderColor: Color(0x337FD9BC),
      ),
    );
  }
}

class ReadingHouseChatRoom extends StatelessWidget {
  const ReadingHouseChatRoom({
    super.key,
    required this.fixture,
    this.scrollController,
    this.onFollowingLatestChanged,
    this.onLoadOlderMessages,
    this.onDeleteMessage,
    this.onSendMessage,
    this.onJumpToLatest,
    this.messagesTopAligned = false,
  });

  final ReadingHouseDayVisualFixture fixture;
  final ScrollController? scrollController;
  final ValueChanged<bool>? onFollowingLatestChanged;
  final VoidCallback? onLoadOlderMessages;
  final ValueChanged<String>? onDeleteMessage;
  final ValueChanged<String>? onSendMessage;
  final VoidCallback? onJumpToLatest;
  final bool messagesTopAligned;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey<String>('reading-house-fixed-chat-layer'),
      fit: StackFit.expand,
      children: <Widget>[
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF0D1A15),
                  Color(0xFF09120E),
                  Color(0xFF070B09),
                ],
                stops: <double>[0, 0.58, 1],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.85, -1),
                radius: 1.25,
                colors: <Color>[Color(0x243FA98A), Color(0x003FA98A)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          height: 54,
          child: _HouseChatHeader(fixture: fixture),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 80,
          bottom: 68,
          child: _HouseChatBody(
            fixture: fixture,
            scrollController: scrollController,
            onFollowingLatestChanged: onFollowingLatestChanged,
            onLoadOlderMessages: onLoadOlderMessages,
            onDeleteMessage: onDeleteMessage,
            messagesTopAligned: messagesTopAligned,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 10,
          height: 46,
          child: ReadingHouseChatComposer(
            state: fixture.roomState,
            newMessageCount: fixture.newMessageCount,
            onSend: onSendMessage,
            onJumpToLatest: onJumpToLatest,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _HouseChatHeader extends StatelessWidget {
  const _HouseChatHeader({required this.fixture});

  final ReadingHouseDayVisualFixture fixture;

  @override
  Widget build(BuildContext context) {
    final compactVerticalRhythm =
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x1C7FD9BC))),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(2, 1, 2, compactVerticalRhythm ? 8 : 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ReadingHouseDayTokens.mintLow.withValues(alpha: 0.09),
                  border: Border.all(
                    color: ReadingHouseDayTokens.mint.withValues(alpha: 0.35),
                  ),
                ),
                child: fixture.roomGlyph == '◌'
                    ? const Icon(
                        Icons.radio_button_unchecked,
                        color: ReadingHouseDayTokens.mint,
                        size: 17,
                      )
                    : Text(
                        fixture.roomGlyph,
                        style: const TextStyle(
                          color: ReadingHouseDayTokens.mint,
                          fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                          fontSize: 16,
                          height: 1,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'House Chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFE8EEE9),
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: compactVerticalRhythm ? 2 : 4),
                    Text(
                      fixture.roomSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687B72),
                        fontFamily: 'GentiumPlus',
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              for (
                var index = 0;
                index < fixture.memberInitials.length && index < 3;
                index++
              )
                _RoomAvatar(fixture.memberInitials[index], overlap: index > 0),
              const SizedBox(width: 7),
              Text(
                '${fixture.memberCount} ${fixture.memberCount == 1 ? 'reader' : 'readers'}',
                style: const TextStyle(
                  color: Color(0xFF779188),
                  fontFamily: 'GentiumPlus',
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar(this.initials, {this.overlap = false});

  final String initials;
  final bool overlap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(overlap ? -5 : 0, 0),
      child: Container(
        width: 25,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A4A3A),
          border: Border.all(color: const Color(0xFF0A120E)),
        ),
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFFCDECE0),
            fontFamily: 'GentiumPlus',
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HouseChatBody extends StatelessWidget {
  const _HouseChatBody({
    required this.fixture,
    this.scrollController,
    this.onFollowingLatestChanged,
    this.onLoadOlderMessages,
    this.onDeleteMessage,
    this.messagesTopAligned = false,
  });

  final ReadingHouseDayVisualFixture fixture;
  final ScrollController? scrollController;
  final ValueChanged<bool>? onFollowingLatestChanged;
  final VoidCallback? onLoadOlderMessages;
  final ValueChanged<String>? onDeleteMessage;
  final bool messagesTopAligned;

  Widget _messageList() => _MessageList(
    messages: fixture.messages,
    controller: scrollController,
    onFollowingLatestChanged: onFollowingLatestChanged,
    onLoadOlderMessages: onLoadOlderMessages,
    onDeleteMessage: onDeleteMessage,
    messagesTopAligned: messagesTopAligned,
  );

  @override
  Widget build(BuildContext context) {
    return switch (fixture.roomState) {
      ReadingHouseRoomVisualState.loading => const Center(
        child: SizedBox(
          width: 19,
          height: 19,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: ReadingHouseDayTokens.mint,
          ),
        ),
      ),
      ReadingHouseRoomVisualState.error => const _ChatEmpty(
        title: 'House Chat could not load.',
        detail: 'Try again when your connection returns.',
      ),
      ReadingHouseRoomVisualState.solo => const _ChatEmpty(
        title: 'House Chat',
        detail: 'Solo study keeps the sitting private.',
      ),
      ReadingHouseRoomVisualState.locked => const _ChatEmpty(
        title: 'House Chat opens when readers join.',
        detail: 'For logistics and quick notes.',
      ),
      ReadingHouseRoomVisualState.empty => const _ChatEmpty(
        title: 'No chat messages yet.',
        detail: 'Use House Chat for logistics and quick notes.',
      ),
      ReadingHouseRoomVisualState.ended => Column(
        children: <Widget>[
          Expanded(child: _messageList()),
          const Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text(
              'This House has ended · chat is read-only',
              style: TextStyle(
                color: ReadingHouseDayTokens.muted,
                fontFamily: 'GentiumPlus',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
      ReadingHouseRoomVisualState.active => _messageList(),
    };
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    this.controller,
    this.onFollowingLatestChanged,
    this.onLoadOlderMessages,
    this.onDeleteMessage,
    this.messagesTopAligned = false,
  });

  final List<ReadingHouseChatMessageFixture> messages;
  final ScrollController? controller;
  final ValueChanged<bool>? onFollowingLatestChanged;
  final VoidCallback? onLoadOlderMessages;
  final ValueChanged<String>? onDeleteMessage;
  final bool messagesTopAligned;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        onFollowingLatestChanged?.call(
          messagesTopAligned ? metrics.extentAfter <= 48 : metrics.pixels <= 48,
        );
        final reachedOlderEdge = messagesTopAligned
            ? metrics.pixels <= 48
            : metrics.pixels >= metrics.maxScrollExtent - 48;
        if (metrics.maxScrollExtent > 0 && reachedOlderEdge) {
          onLoadOlderMessages?.call();
        }
        return false;
      },
      child: ListView.builder(
        key: const ValueKey<String>('reading-house-chat-transcript'),
        controller: controller,
        reverse: !messagesTopAligned,
        padding: const EdgeInsets.symmetric(vertical: 5),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messagesTopAligned
              ? messages[index]
              : messages[messages.length - index - 1];
          return _ChatMessage(
            message: message,
            onDelete: message.mine && message.id != null
                ? () => onDeleteMessage?.call(message.id!)
                : null,
          );
        },
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  const _ChatMessage({required this.message, this.onDelete});

  final ReadingHouseChatMessageFixture message;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onLongPress: onDelete,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ReadingHouseDayTokens.mintLow.withValues(alpha: 0.10),
                  border: Border.all(
                    color: ReadingHouseDayTokens.mint.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  message.initials,
                  style: const TextStyle(
                    color: Color(0xFF8EDBBF),
                    fontFamily: 'GentiumPlus',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          message.author,
                          style: const TextStyle(
                            color: Color(0xFFC5D0CA),
                            fontFamily: 'GentiumPlus',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (message.host) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ReadingHouseDayTokens.gold.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                color: Color(0xFFBFA357),
                                fontFamily: 'GentiumPlus',
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 7),
                        Text(
                          message.timeLabel,
                          style: const TextStyle(
                            color: Color(0xFF52635B),
                            fontFamily: 'GentiumPlus',
                            fontSize: 9,
                          ),
                        ),
                        if (onDelete != null) ...<Widget>[
                          const Spacer(),
                          GestureDetector(
                            key: ValueKey<String>(
                              'reading-house-delete-message-${message.id}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: onDelete,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: CustomPaint(
                                size: Size(14, 10),
                                painter: _ReadingHouseDeleteGlyphPainter(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ReadingHouseDayTokens.copy,
                        fontFamily: 'GentiumPlus',
                        fontSize: 13.5,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingHouseDeleteGlyphPainter extends CustomPainter {
  const _ReadingHouseDeleteGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF645C58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outline = Path()
      ..moveTo(size.width, 1)
      ..lineTo(5, 1)
      ..lineTo(1, size.height / 2)
      ..lineTo(5, size.height - 1)
      ..lineTo(size.width, size.height - 1)
      ..close();
    canvas
      ..drawPath(outline, paint)
      ..drawLine(const Offset(8, 3), const Offset(11, 7), paint)
      ..drawLine(const Offset(11, 3), const Offset(8, 7), paint);
  }

  @override
  bool shouldRepaint(covariant _ReadingHouseDeleteGlyphPainter oldDelegate) =>
      false;
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFA9B8B1),
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReadingHouseDayTokens.muted,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReadingHouseChatComposer extends StatefulWidget {
  const ReadingHouseChatComposer({
    super.key,
    required this.state,
    required this.newMessageCount,
    this.onSend,
    this.onJumpToLatest,
    this.compact = false,
  });

  final ReadingHouseRoomVisualState state;
  final int newMessageCount;
  final ValueChanged<String>? onSend;
  final VoidCallback? onJumpToLatest;
  final bool compact;

  bool get _canDraft => switch (state) {
    ReadingHouseRoomVisualState.active ||
    ReadingHouseRoomVisualState.empty ||
    ReadingHouseRoomVisualState.locked => true,
    _ => false,
  };

  bool get _roomCanSend =>
      state == ReadingHouseRoomVisualState.active ||
      state == ReadingHouseRoomVisualState.empty;

  @override
  State<ReadingHouseChatComposer> createState() =>
      _ReadingHouseChatComposerState();
}

class _ReadingHouseChatComposerState extends State<ReadingHouseChatComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_draftChanged);
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_draftChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend =>
      widget._roomCanSend &&
      widget.onSend != null &&
      _controller.text.trim().isNotEmpty;

  void _submit([String? submitted]) {
    final body = (submitted ?? _controller.text).trim();
    if (!widget._roomCanSend || body.isEmpty || widget.onSend == null) return;
    widget.onSend!(body);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-chat-composer'),
      height: widget.compact ? 46 : null,
      padding: widget.compact
          ? const EdgeInsets.only(top: 7)
          : const EdgeInsets.fromLTRB(16, 7, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xEB070B09), Color(0xFF07100C)],
          stops: <double>[0, 0.28],
        ),
        border: Border(
          top: BorderSide(
            color: widget.compact
                ? const Color(0x1C7FD9BC)
                : ReadingHouseDayTokens.separator,
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    key: const ValueKey<String>(
                      'reading-house-chat-message-field',
                    ),
                    controller: _controller,
                    enabled: widget._canDraft,
                    onSubmitted: _canSend ? _submit : null,
                    style: const TextStyle(
                      color: Color(0xFFDCE5E0),
                      fontFamily: 'GentiumPlus',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: switch (widget.state) {
                        ReadingHouseRoomVisualState.ended =>
                          'This House is read-only',
                        ReadingHouseRoomVisualState.solo =>
                          'Solo study has no House Chat',
                        _ => 'Message House Chat',
                      },
                      hintStyle: const TextStyle(color: Color(0xFF506058)),
                      filled: true,
                      fillColor: const Color(0xFF07100C),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ReadingHouseDayTokens.mint.withValues(
                            alpha: 0.17,
                          ),
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: ReadingHouseDayTokens.separator,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ReadingHouseDayTokens.mint.withValues(
                            alpha: 0.46,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Opacity(
                opacity: _canSend ? 1 : 0.32,
                child: IconButton(
                  key: const ValueKey<String>('reading-house-chat-send'),
                  onPressed: _canSend ? _submit : null,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(36, 36),
                    backgroundColor: const Color(0xFF173C30),
                    disabledBackgroundColor: const Color(0xFF173C30),
                    foregroundColor: const Color(0xFFD5F0E6),
                    disabledForegroundColor: const Color(0xFFD5F0E6),
                    side: BorderSide(
                      color: ReadingHouseDayTokens.mint.withValues(alpha: 0.31),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                ),
              ),
            ],
          ),
          if (widget.newMessageCount > 0)
            Positioned(
              left: 0,
              right: 0,
              top: -39,
              child: Center(
                child: ActionChip(
                  key: const ValueKey<String>(
                    'reading-house-new-message-notice',
                  ),
                  onPressed: widget.onJumpToLatest,
                  backgroundColor: const Color(0xFF0D1713),
                  side: BorderSide(
                    color: ReadingHouseDayTokens.mint.withValues(alpha: 0.28),
                  ),
                  avatar: const Icon(
                    Icons.arrow_downward,
                    size: 13,
                    color: Color(0xFFD7EFE6),
                  ),
                  label: Text(
                    '${widget.newMessageCount} new ${widget.newMessageCount == 1 ? 'message' : 'messages'}',
                    style: const TextStyle(
                      color: Color(0xFFA8C6BA),
                      fontFamily: 'GentiumPlus',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadingPracticeSheet extends StatelessWidget {
  const _ReadingPracticeSheet({
    required this.fixture,
    this.onPostAnnouncement,
    this.onPostSharedNote,
    this.onPrivateReflectionChanged,
  });

  final ReadingHouseDayVisualFixture fixture;
  final ValueChanged<String>? onPostAnnouncement;
  final ValueChanged<String>? onPostSharedNote;
  final ValueChanged<String>? onPrivateReflectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _PracticeOutputBlock(
                title: 'Host announcement',
                initialText: fixture.hostAnnouncement,
                initialTextMetadata: 'HOST · just now',
                hintText: 'Host announcement',
                actionLabel: 'Post announcement',
                onAction: onPostAnnouncement,
                first: true,
              ),
              _PracticeOutputBlock(
                title: 'Shared note',
                hintText: 'What do you want to share publicly?',
                actionLabel: 'Post to Feed',
                onAction: onPostSharedNote,
                publicAction: true,
              ),
              _PrivateReflectionBlock(
                initialText: fixture.privateReflection,
                onChanged: onPrivateReflectionChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PracticeOutputBlock extends StatefulWidget {
  const _PracticeOutputBlock({
    required this.title,
    required this.hintText,
    required this.actionLabel,
    this.initialText,
    this.initialTextMetadata,
    this.onAction,
    this.first = false,
    this.publicAction = false,
  });

  final String title;
  final String hintText;
  final String actionLabel;
  final String? initialText;
  final String? initialTextMetadata;
  final ValueChanged<String>? onAction;
  final bool first;
  final bool publicAction;

  @override
  State<_PracticeOutputBlock> createState() => _PracticeOutputBlockState();
}

class _PracticeOutputBlockState extends State<_PracticeOutputBlock> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.onAction == null) return;
    widget.onAction!(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final previousText = widget.initialText?.trim();
    final hasPreviousText = previousText?.isNotEmpty == true;
    return Container(
      padding: EdgeInsets.fromLTRB(0, widget.first ? 0 : 10, 0, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1A7FD9BC))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: _practiceTitleStyle),
          if (hasPreviousText) ...<Widget>[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF080C0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x147FD9BC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (widget.initialTextMetadata != null) ...<Widget>[
                    Text(
                      widget.initialTextMetadata!,
                      style: const TextStyle(
                        color: Color(0xFF829188),
                        fontFamily: 'GentiumPlus',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Text(
                    previousText!,
                    style: const TextStyle(
                      color: Color(0xFFBBC6C0),
                      fontFamily: 'GentiumPlus',
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasPreviousText) const SizedBox(height: 9),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(
              color: ReadingHouseDayTokens.bone,
              fontFamily: 'GentiumPlus',
              fontSize: 14,
              height: 1.35,
            ),
            decoration: _practiceInputDecoration(widget.hintText),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onAction == null ? null : _submit,
              style: TextButton.styleFrom(
                foregroundColor: widget.publicAction
                    ? const Color(0xFFC8A94F)
                    : ReadingHouseDayTokens.mint,
                minimumSize: Size.zero,
                padding: const EdgeInsets.fromLTRB(0, 5, 0, 1),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              child: Text(widget.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateReflectionBlock extends StatefulWidget {
  const _PrivateReflectionBlock({required this.initialText, this.onChanged});

  final String initialText;
  final ValueChanged<String>? onChanged;

  @override
  State<_PrivateReflectionBlock> createState() =>
      _PrivateReflectionBlockState();
}

class _PrivateReflectionBlockState extends State<_PrivateReflectionBlock> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void didUpdateWidget(covariant _PrivateReflectionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-private-reflection'),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1A7FD9BC))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Private reflection', style: _practiceTitleStyle),
          TextField(
            key: const ValueKey<String>(
              'reading-house-private-reflection-field',
            ),
            controller: _controller,
            onChanged: widget.onChanged,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(
              color: ReadingHouseDayTokens.bone,
              fontFamily: 'GentiumPlus',
              fontSize: 14,
              height: 1.35,
            ),
            decoration: _practiceInputDecoration(
              'What did this section ask you to hold?',
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBlock extends StatelessWidget {
  const _CompletionBlock({required this.selected, this.onSelected});

  final ReadingHouseCompletionVisualState selected;
  final ValueChanged<ReadingHouseCompletionVisualState>? onSelected;

  @override
  Widget build(BuildContext context) {
    final status = switch (selected) {
      ReadingHouseCompletionVisualState.none => CompletionStatus.none,
      ReadingHouseCompletionVisualState.observed => CompletionStatus.observed,
      ReadingHouseCompletionVisualState.partly => CompletionStatus.partial,
      ReadingHouseCompletionVisualState.skipped => CompletionStatus.skipped,
    };
    return CalendarCompletionPicker(
      key: const ValueKey<String>('reading-house-completion-picker'),
      current: status,
      style: kMaatDayViewCompletionPickerStyle,
      onChanged: (next) => onSelected?.call(switch (next) {
        CompletionStatus.none => ReadingHouseCompletionVisualState.none,
        CompletionStatus.observed => ReadingHouseCompletionVisualState.observed,
        CompletionStatus.partial => ReadingHouseCompletionVisualState.partly,
        CompletionStatus.skipped => ReadingHouseCompletionVisualState.skipped,
      }),
    );
  }
}

const TextStyle _practiceTitleStyle = TextStyle(
  color: Color(0xFFE7E1D8),
  fontFamily: MaatFlowListTokens.fontFamily,
  fontSize: 21,
  fontWeight: FontWeight.w500,
  height: 1,
);

InputDecoration _practiceInputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF506058)),
    filled: true,
    fillColor: const Color(0xFF070A08),
    contentPadding: const EdgeInsets.all(10),
    constraints: const BoxConstraints(minHeight: 64),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0x297FD9BC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: ReadingHouseDayTokens.mint.withValues(alpha: 0.42),
      ),
    ),
  );
}
