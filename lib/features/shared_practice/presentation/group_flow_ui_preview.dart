import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/flow_appearance.dart';
import '../../../widgets/profile_avatar.dart';
import '../../calendar/presentation/user_flow_appearance_visual.dart';
import '../../calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import '../../profile/posted_flow_artifact.dart';
import '../../profile/social_flow_post_tile.dart';

@immutable
class GroupFlowParticipantPreview {
  const GroupFlowParticipantPreview({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.avatarGlyphIds = const <String>[],
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final List<String> avatarGlyphIds;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final value = parts.map((part) => part.characters.first).join();
    return value.isEmpty ? 'P' : value.toUpperCase();
  }
}

@immutable
class GroupFlowChatMessagePreview {
  const GroupFlowChatMessagePreview({
    required this.id,
    required this.author,
    required this.initials,
    required this.body,
    required this.timeLabel,
    this.mine = false,
  });

  final String id;
  final String author;
  final String initials;
  final String body;
  final String timeLabel;
  final bool mine;
}

class GroupFlowChatSurface extends StatelessWidget {
  const GroupFlowChatSurface({
    super.key,
    required this.flowTitle,
    required this.positionLabel,
    required this.appearance,
    required this.accent,
    required this.memberInitials,
    required this.memberCount,
    required this.messages,
    this.localImageBytes,
    this.compact = false,
    this.height,
    this.completedOccurrences = 0,
    this.totalOccurrences = 0,
    this.animationRevision = 0,
    this.animationFromCompletedOccurrences,
    this.onSendMessage,
    this.onPostMessage,
    this.onObserve,
  });

  final String flowTitle;
  final String positionLabel;
  final FlowAppearance appearance;
  final Color accent;
  final List<String> memberInitials;
  final int memberCount;
  final List<GroupFlowChatMessagePreview> messages;
  final Uint8List? localImageBytes;
  final bool compact;
  final double? height;
  final int completedOccurrences;
  final int totalOccurrences;
  final int animationRevision;
  final int? animationFromCompletedOccurrences;
  final ValueChanged<String>? onSendMessage;
  final ValueChanged<GroupFlowChatMessagePreview>? onPostMessage;
  final VoidCallback? onObserve;

  @override
  Widget build(BuildContext context) {
    final surfaceHeight = height ?? (compact ? 128.0 : 320.0);
    final dense = !compact && surfaceHeight < 240;
    final hasMerkhet = appearance.hasSign;
    final displayedMessages = compact
        ? messages.take(2).toList(growable: false)
        : messages;
    final topInset = compact
        ? 45.0
        : dense
        ? 65.0
        : (hasMerkhet ? 92.0 : 76.0);
    final bottomInset = compact
        ? 25.0
        : dense
        ? 47.0
        : 62.0;

    return SizedBox(
      key: const ValueKey<String>('group-flow-chat-surface'),
      height: surfaceHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 10 : 20),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            UserFlowAppearanceHero(
              appearance: appearance,
              accent: accent,
              localImageBytes: localImageBytes,
              height: surfaceHeight,
              borderRadius: BorderRadius.zero,
              imageOpacityOverride: appearance.hasImage ? 0.16 : null,
              showSignVisual: false,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color.alphaBlend(
                        accent.withValues(alpha: 0.15),
                        const Color(0xE8070B09),
                      ),
                      const Color(0xEE07100C),
                      const Color(0xFA050806),
                    ],
                    stops: const <double>[0, 0.48, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: compact ? 9 : 16,
              right: hasMerkhet ? (compact ? 58 : 92) : (compact ? 9 : 16),
              top: compact
                  ? 8
                  : dense
                  ? 7
                  : 14,
              height: compact
                  ? 31
                  : dense
                  ? 48
                  : 53,
              child: _GroupFlowChatHeader(
                flowTitle: flowTitle,
                positionLabel: positionLabel,
                memberInitials: memberInitials,
                memberCount: memberCount,
                accent: accent,
                compact: compact,
              ),
            ),
            if (hasMerkhet)
              Positioned(
                key: const ValueKey<String>('group-flow-compact-merkhet'),
                top: compact
                    ? 7
                    : dense
                    ? 6
                    : 12,
                right: compact
                    ? 8
                    : dense
                    ? 8
                    : 14,
                child: InkWell(
                  key: const ValueKey<String>('group-flow-observe-widget'),
                  onTap: onObserve,
                  borderRadius: BorderRadius.circular(compact ? 10 : 16),
                  child: Container(
                    width: compact
                        ? 44
                        : dense
                        ? 52
                        : 70,
                    height: compact
                        ? 38
                        : dense
                        ? 46
                        : 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xC8070B09),
                      borderRadius: BorderRadius.circular(compact ? 10 : 16),
                      border: Border.all(color: accent.withValues(alpha: 0.28)),
                    ),
                    child: FlowSignVisual(
                      kind: appearance.signKind!,
                      color: accent,
                      compact: true,
                      size: compact
                          ? 29
                          : dense
                          ? 36
                          : 52,
                      completedOccurrences: completedOccurrences,
                      totalOccurrences: totalOccurrences,
                      animationRevision: animationRevision,
                      animationFromCompletedOccurrences:
                          animationFromCompletedOccurrences,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: compact ? 10 : 16,
              right: compact ? 10 : 16,
              top: topInset,
              bottom: bottomInset,
              child: displayedMessages.isEmpty
                  ? Center(
                      child: Text(
                        'The conversation begins here.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontFamily: 'GentiumPlus',
                          fontSize: compact ? 10 : 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: compact
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      itemCount: displayedMessages.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: compact ? 3 : 9),
                      itemBuilder: (context, index) {
                        final message = displayedMessages[index];
                        return _GroupFlowMessageRow(
                          message: message,
                          compact: compact,
                          onPost: onPostMessage != null
                              ? () => onPostMessage!(message)
                              : null,
                        );
                      },
                    ),
            ),
            if (compact)
              Positioned(
                left: 9,
                right: 9,
                bottom: 6,
                height: 19,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xB507100C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.18)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Message group flow',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.34),
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: dense ? 42 : 54,
                child: ReadingHouseChatComposer(
                  state: ReadingHouseRoomVisualState.active,
                  newMessageCount: 0,
                  activeHintText: 'Message group flow',
                  onSend: onSendMessage,
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupFlowChatHeader extends StatelessWidget {
  const _GroupFlowChatHeader({
    required this.flowTitle,
    required this.positionLabel,
    required this.memberInitials,
    required this.memberCount,
    required this.accent,
    required this.compact,
  });

  final String flowTitle;
  final String positionLabel;
  final List<String> memberInitials;
  final int memberCount;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 24 : 34,
            height: compact ? 24 : 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
            ),
            child: Icon(
              Icons.groups_2_outlined,
              color: accent,
              size: compact ? 13 : 17,
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  flowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFE8EEE9),
                    fontFamily: 'GentiumPlus',
                    fontSize: compact ? 11.5 : 18,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                Text(
                  positionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF7D9188),
                    fontFamily: 'GentiumPlus',
                    fontSize: compact ? 7.5 : 10.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...<Widget>[
            for (
              var index = 0;
              index < memberInitials.length && index < 3;
              index++
            )
              Transform.translate(
                offset: Offset(index == 0 ? 0 : -5, 0),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Color.alphaBlend(
                    accent.withValues(alpha: 0.22),
                    const Color(0xFF0A120E),
                  ),
                  child: Text(
                    memberInitials[index],
                    style: const TextStyle(
                      color: Color(0xFFD5EEE5),
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '$memberCount',
              style: const TextStyle(color: Color(0xFF879C93), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupFlowMessageRow extends StatelessWidget {
  const _GroupFlowMessageRow({
    required this.message,
    required this.compact,
    this.onPost,
  });

  final GroupFlowChatMessagePreview message;
  final bool compact;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: compact ? 7 : 13,
          backgroundColor: const Color(0xFF15382F),
          child: Text(
            message.initials,
            style: TextStyle(
              color: const Color(0xFFCCE8DE),
              fontSize: compact ? 5.5 : 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: compact ? 5 : 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    message.author,
                    style: TextStyle(
                      color: const Color(0xFFDCE7E2),
                      fontSize: compact ? 7.5 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: compact ? 3 : 6),
                  Text(
                    message.timeLabel,
                    style: TextStyle(
                      color: const Color(0xFF63776E),
                      fontSize: compact ? 6 : 9,
                    ),
                  ),
                  const Spacer(),
                  if (onPost != null && !compact)
                    IconButton(
                      key: ValueKey<String>('post_group_quote_${message.id}'),
                      tooltip: 'Post this quote to Commons',
                      onPressed: onPost,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 28,
                      ),
                      icon: const Icon(
                        Icons.format_quote_rounded,
                        size: 15,
                        color: Color(0xFF7FD9BC),
                      ),
                    ),
                ],
              ),
              Text(
                message.body,
                maxLines: compact ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFD6E0DB),
                  fontFamily: 'GentiumPlus',
                  fontSize: compact ? 8.5 : 15,
                  height: compact ? 1.05 : 1.18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _GroupFlowPreviewPage { flow, feed, commons, inbox }

enum _GroupFlowVisibilityPreview { private, public }

enum _GroupFlowAudiencePreview {
  nobody,
  creatorFriends,
  participantFriends,
  anyone,
}

class GroupFlowUiPreviewSheet extends StatefulWidget {
  const GroupFlowUiPreviewSheet({
    super.key,
    required this.flowTitle,
    required this.appearance,
    required this.accent,
    required this.participants,
    this.localImageBytes,
  });

  final String flowTitle;
  final FlowAppearance appearance;
  final Color accent;
  final List<GroupFlowParticipantPreview> participants;
  final Uint8List? localImageBytes;

  static Future<void> show(
    BuildContext context, {
    required String flowTitle,
    required FlowAppearance appearance,
    required Color accent,
    required List<GroupFlowParticipantPreview> participants,
    Uint8List? localImageBytes,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GroupFlowUiPreviewSheet(
        flowTitle: flowTitle,
        appearance: appearance,
        accent: accent,
        participants: participants,
        localImageBytes: localImageBytes,
      ),
    );
  }

  @override
  State<GroupFlowUiPreviewSheet> createState() =>
      _GroupFlowUiPreviewSheetState();
}

class _GroupFlowUiPreviewSheetState extends State<GroupFlowUiPreviewSheet> {
  _GroupFlowPreviewPage _page = _GroupFlowPreviewPage.flow;
  _GroupFlowVisibilityPreview _visibility = _GroupFlowVisibilityPreview.private;
  _GroupFlowAudiencePreview _audience =
      _GroupFlowAudiencePreview.creatorFriends;
  bool _requestPending = false;
  bool _feedRequestPending = false;
  bool _feedMutualFriends = true;
  bool _requestAccepted = false;
  bool _liked = false;
  bool _quoteLiked = false;
  bool _showPublicName = true;
  int _completedOccurrences = 11;
  int _animationRevision = 0;
  late List<GroupFlowChatMessagePreview> _messages;

  GroupFlowParticipantPreview get _friend => widget.participants.first;

  @override
  void initState() {
    super.initState();
    _messages = <GroupFlowChatMessagePreview>[
      GroupFlowChatMessagePreview(
        id: 'preview-friend-1',
        author: _friend.name,
        initials: _friend.initials,
        body: 'I joined you where the flow is today.',
        timeLabel: '7:18',
      ),
      const GroupFlowChatMessagePreview(
        id: 'preview-you-1',
        author: 'You',
        initials: 'Y',
        body: 'Perfect. We are on day 12 together.',
        timeLabel: '7:20',
        mine: true,
      ),
    ];
  }

  void _send(String body) {
    setState(() {
      _messages = <GroupFlowChatMessagePreview>[
        ..._messages,
        GroupFlowChatMessagePreview(
          id: 'preview-${_messages.length + 1}',
          author: 'You',
          initials: 'Y',
          body: body,
          timeLabel: 'now',
          mine: true,
        ),
      ];
    });
  }

  void _showPreviewNotice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message · preview only')));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        key: const ValueKey<String>('group-flow-ui-preview-sheet'),
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFF070604),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x443FA98A))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A5448),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Group flow preview',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFF0E7D8),
                                    fontFamily: 'GentiumPlus',
                                    fontSize: 25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _PreviewPill(accent: widget.accent),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Explore the app flow without saving or sending anything.',
                            style: TextStyle(
                              color: Color(0xFF887D6B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFFD4AE43)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildPageSelector(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_page) {
                    _GroupFlowPreviewPage.flow => _buildFlowPreview(),
                    _GroupFlowPreviewPage.feed => _buildFeedPreview(),
                    _GroupFlowPreviewPage.commons => _buildCommonsPreview(),
                    _GroupFlowPreviewPage.inbox => _buildInboxPreview(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageSelector() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0906),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF33260E)),
      ),
      child: Row(
        children: <Widget>[
          for (final page in _GroupFlowPreviewPage.values)
            Expanded(
              child: InkWell(
                key: ValueKey<String>('group-flow-preview-${page.name}'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _page = page),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _page == page
                        ? widget.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _page == page
                          ? widget.accent.withValues(alpha: 0.48)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    switch (page) {
                      _GroupFlowPreviewPage.flow => 'Flow',
                      _GroupFlowPreviewPage.feed => 'Feed',
                      _GroupFlowPreviewPage.commons => 'Commons',
                      _GroupFlowPreviewPage.inbox => 'Inbox',
                    },
                    style: TextStyle(
                      color: _page == page
                          ? const Color(0xFFF0E7D8)
                          : const Color(0xFF766C5D),
                      fontFamily: 'GentiumPlus',
                      fontSize: 15,
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

  Widget _buildFeedPreview() {
    return ListView(
      key: const ValueKey<String>('group-flow-preview-feed-page'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: <Widget>[
        const Text(
          'Feed shows a solo flow. Together appears only when the viewer and creator follow each other.',
          style: TextStyle(
            color: Color(0xFF918777),
            fontFamily: 'GentiumPlus',
            fontSize: 15,
            fontStyle: FontStyle.italic,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF272018)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SocialPostAuthorHeader(
                displayName: _friend.name,
                handle: 'amina',
                showHandle: true,
                avatarUrl: _friend.avatarUrl,
                avatarGlyphIds: _friend.avatarGlyphIds,
                relationshipLabel: 'Mutual',
                relationshipColor: widget.accent,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              const Text(
                'Day twelve. I am finding a steadier pace.',
                style: TextStyle(
                  color: Color(0xFFF2ECE0),
                  fontFamily: 'CormorantGaramond',
                  fontSize: 21,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              PostedFlowArtifact(
                name: widget.flowTitle,
                color: widget.appearance.accentArgb ?? widget.accent.toARGB32(),
                notes: 'A thirty-day practice for strength and steadiness.',
                startDate: DateTime(2026, 9, 13),
                endDate: DateTime(2026, 10, 12),
                appearance: widget.appearance,
                localImageBytes: widget.localImageBytes,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _showPreviewNotice('Post liked'),
                    icon: const Icon(Icons.favorite_border_rounded, size: 17),
                    label: const Text('Like'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showPreviewNotice('Flow saved'),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                    label: const Text('Save'),
                  ),
                  if (_feedMutualFriends)
                    Expanded(
                      child: TextButton.icon(
                        key: const ValueKey<String>(
                          'group-flow-preview-feed-together',
                        ),
                        onPressed: () => setState(
                          () => _feedRequestPending = !_feedRequestPending,
                        ),
                        icon: Icon(
                          _feedRequestPending
                              ? Icons.hourglass_top_rounded
                              : Icons.people_outline_rounded,
                          size: 17,
                        ),
                        label: Text(
                          _feedRequestPending ? 'Requested' : 'Together',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0D100D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Preview mutual-follow eligibility',
                      style: TextStyle(
                        color: Color(0xFFE7DED0),
                        fontFamily: 'GentiumPlus',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Off removes Together completely—not disabled.',
                      style: TextStyle(
                        color: Color(0xFF81786A),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const ValueKey<String>(
                  'group-flow-preview-feed-mutual-toggle',
                ),
                value: _feedMutualFriends,
                activeTrackColor: widget.accent,
                onChanged: (value) =>
                    setState(() => _feedMutualFriends = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowPreview() {
    return ListView(
      key: const ValueKey<String>('group-flow-preview-flow-page'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: <Widget>[
        GroupFlowChatSurface(
          flowTitle: widget.flowTitle,
          positionLabel: 'Day 12 of 30 · host position',
          appearance: widget.appearance,
          accent: widget.accent,
          localImageBytes: widget.localImageBytes,
          memberInitials: <String>[
            'Y',
            ...widget.participants.map((participant) => participant.initials),
          ],
          memberCount: widget.participants.length + 1,
          messages: _messages,
          completedOccurrences: _completedOccurrences,
          totalOccurrences: 30,
          animationRevision: _animationRevision,
          onSendMessage: _send,
          onPostMessage: (_) => _showPreviewNotice('Quote posted to Commons'),
        ),
        const SizedBox(height: 18),
        const Text(
          'COMPLETION',
          style: TextStyle(
            color: Color(0xFFD4AE43),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (final label in const <String>['Observed', 'Partly', 'Skipped'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    key: ValueKey<String>(
                      'group-flow-preview-${label.toLowerCase()}',
                    ),
                    onPressed: () {
                      if (label == 'Observed') {
                        setState(() {
                          _completedOccurrences = (_completedOccurrences + 1)
                              .clamp(0, 30);
                          _animationRevision++;
                        });
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: label == 'Observed'
                          ? const Color(0xFFC9D7FF)
                          : const Color(0xFFB9B2A7),
                      side: BorderSide(
                        color: label == 'Observed'
                            ? const Color(0xFF7188FF)
                            : const Color(0xFF38352F),
                      ),
                    ),
                    child: Text(label),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'The host’s day is shared. Each person’s Observed state remains their own.',
          style: TextStyle(
            color: Color(0xFF81786A),
            fontFamily: 'GentiumPlus',
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D100D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Show my name publicly',
                      style: TextStyle(
                        color: Color(0xFFE7DED0),
                        fontFamily: 'GentiumPlus',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Only affects the member list shown in Commons.',
                      style: TextStyle(color: Color(0xFF81786A), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const ValueKey<String>(
                  'group-flow-preview-public-name-toggle',
                ),
                value: _showPublicName,
                activeTrackColor: widget.accent,
                onChanged: (value) => setState(() => _showPublicName = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommonsPreview() {
    final memberCount = widget.participants.length + 1;
    final appearsInCommons =
        !_requestAccepted || _visibility == _GroupFlowVisibilityPreview.public;
    final canRequest = _audience != _GroupFlowAudiencePreview.nobody;
    final visibleParticipants = <GroupFlowParticipantPreview>[
      if (_showPublicName)
        const GroupFlowParticipantPreview(id: 'you', name: 'You'),
      ...widget.participants,
    ];
    return ListView(
      key: const ValueKey<String>('group-flow-preview-commons-page'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: <Widget>[
        const Text(
          'Only public group flows appear here. The room conversation remains private.',
          style: TextStyle(
            color: Color(0xFF918777),
            fontFamily: 'GentiumPlus',
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 14),
        if (!appearsInCommons)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D100D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2F382F)),
            ),
            child: const Text(
              'This group flow is private, so viewers will not find it in Commons.',
              style: TextStyle(
                color: Color(0xFFB0A795),
                fontFamily: 'GentiumPlus',
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...<Widget>[
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0B07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _PreviewPill(accent: widget.accent, label: 'PUBLIC GROUP'),
                    const Spacer(),
                    Text(
                      '$memberCount members',
                      style: const TextStyle(
                        color: Color(0xFF8C9D95),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.flowTitle,
                  style: const TextStyle(
                    color: Color(0xFFF0E7D8),
                    fontFamily: 'GentiumPlus',
                    fontSize: 29,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    for (final participant in visibleParticipants.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ProfileAvatar(
                          radius: 15,
                          displayName: participant.name,
                          avatarUrl: participant.avatarUrl,
                          avatarGlyphIds: participant.avatarGlyphIds,
                          backgroundColor: const Color(0xFF15382F),
                          foregroundColor: const Color(0xFFCCE8DE),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _showPublicName
                            ? 'Visible names are chosen by each participant.'
                            : 'Your name is private; the member count remains visible.',
                        style: const TextStyle(
                          color: Color(0xFF82796D),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    TextButton.icon(
                      key: const ValueKey<String>('group-flow-preview-like'),
                      onPressed: () => setState(() => _liked = !_liked),
                      icon: Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                      ),
                      label: Text(_liked ? '1' : 'Like'),
                      style: TextButton.styleFrom(
                        foregroundColor: _liked
                            ? const Color(0xFFC4DCE8)
                            : const Color(0xFF9E9A94),
                      ),
                    ),
                    if (canRequest) ...<Widget>[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey<String>(
                            'group-flow-preview-request',
                          ),
                          onPressed: () => setState(
                            () => _requestPending = !_requestPending,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            foregroundColor: _requestPending
                                ? const Color(0xFF9E9A94)
                                : const Color(0xFFE4CC8B),
                            side: BorderSide(
                              color: _requestPending
                                  ? const Color(0xFF45413A)
                                  : widget.accent.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            _requestPending ? 'Requested' : 'Practice Together',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(color: Color(0xFF252018)),
                const Text(
                  'Likes only on the group-flow post. Quotes published from chat can receive likes and comments.',
                  style: TextStyle(
                    color: Color(0xFF7F7568),
                    fontFamily: 'GentiumPlus',
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildQuotePostPreview(),
        ],
      ],
    );
  }

  Widget _buildQuotePostPreview() {
    return Container(
      key: const ValueKey<String>('group-flow-preview-quote-post'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0A08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF302A20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _PreviewPill(accent: widget.accent, label: 'FROM GROUP CHAT'),
              const Spacer(),
              const Icon(
                Icons.format_quote_rounded,
                color: Color(0xFF80786B),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Text(
            '“Perfect. We are on day 12 together.”',
            style: TextStyle(
              color: Color(0xFFE8DED0),
              fontFamily: 'GentiumPlus',
              fontSize: 20,
              fontStyle: FontStyle.italic,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showPublicName ? 'Posted by You' : 'Posted by a participant',
            style: const TextStyle(color: Color(0xFF7F7568), fontSize: 11),
          ),
          const Divider(color: Color(0xFF252018), height: 24),
          Row(
            children: <Widget>[
              TextButton.icon(
                key: const ValueKey<String>('group-flow-preview-quote-like'),
                onPressed: () => setState(() => _quoteLiked = !_quoteLiked),
                icon: Icon(
                  _quoteLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text(_quoteLiked ? '13' : '12'),
              ),
              TextButton.icon(
                key: const ValueKey<String>('group-flow-preview-quote-comment'),
                onPressed: () => _showPreviewNotice('Comments opened'),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: const Text('2'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInboxPreview() {
    return ListView(
      key: const ValueKey<String>('group-flow-preview-inbox-page'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF160B08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF593024)),
          ),
          child: _requestAccepted
              ? Row(
                  children: <Widget>[
                    Icon(Icons.check_circle, color: widget.accent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_friend.name} joined ${widget.flowTitle}.',
                        style: const TextStyle(
                          color: Color(0xFFEADFD2),
                          fontFamily: 'GentiumPlus',
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        ProfileAvatar(
                          radius: 20,
                          displayName: _friend.name,
                          avatarUrl: _friend.avatarUrl,
                          avatarGlyphIds: _friend.avatarGlyphIds,
                          backgroundColor: const Color(0xFF2A1510),
                          foregroundColor: const Color(0xFFD4AE43),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_friend.name} wants to join ${widget.flowTitle}.',
                            style: const TextStyle(
                              color: Color(0xFFEADFD2),
                              fontFamily: 'GentiumPlus',
                              fontSize: 18,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _showPreviewNotice('Request declined'),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey<String>(
                              'group-flow-preview-accept',
                            ),
                            onPressed: () =>
                                setState(() => _requestAccepted = true),
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.accent,
                              foregroundColor: const Color(0xFF07100C),
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        if (_requestAccepted) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey<String>('group-flow-preview-policy'),
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF0D110D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.accent.withValues(alpha: 0.34)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'This is now a group flow.',
                  style: TextStyle(
                    color: Color(0xFFF0E7D8),
                    fontFamily: 'GentiumPlus',
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'It stays private until you choose otherwise.',
                  style: TextStyle(color: Color(0xFF8B8172), fontSize: 12),
                ),
                const SizedBox(height: 18),
                const _PolicyLabel('Who can see this flow?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final value in _GroupFlowVisibilityPreview.values)
                      ChoiceChip(
                        key: ValueKey<String>(
                          'group-flow-preview-visibility-${value.name}',
                        ),
                        selected: _visibility == value,
                        onSelected: (_) => setState(() => _visibility = value),
                        label: Text(
                          value == _GroupFlowVisibilityPreview.private
                              ? 'Private'
                              : 'Public in Commons',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const _PolicyLabel('Who can request to join?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final value in _GroupFlowAudiencePreview.values)
                      ChoiceChip(
                        key: ValueKey<String>(
                          'group-flow-preview-audience-${value.name}',
                        ),
                        selected: _audience == value,
                        onSelected: (_) => setState(() => _audience = value),
                        label: Text(switch (value) {
                          _GroupFlowAudiencePreview.nobody => 'Nobody',
                          _GroupFlowAudiencePreview.creatorFriends =>
                            'Friends of creator',
                          _GroupFlowAudiencePreview.participantFriends =>
                            'Friends of participants',
                          _GroupFlowAudiencePreview.anyone => 'Anyone',
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => _showPreviewNotice('Group settings saved'),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: const Color(0xFF07100C),
                  ),
                  child: const Text('Save group settings'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.accent, this.label = 'PREVIEW'});

  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _PolicyLabel extends StatelessWidget {
  const _PolicyLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFDCCFAF),
        fontFamily: 'GentiumPlus',
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
