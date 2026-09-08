import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

enum ReadingHouseInboxRoomStatus { active, locked, empty, ended }

enum ReadingHouseInboxSectionStatus { loaded, loading, error }

@immutable
class ReadingHouseInboxRoomFixture {
  const ReadingHouseInboxRoomFixture({
    required this.calendarId,
    required this.flowId,
    required this.houseTitle,
    required this.bookTitle,
    required this.latestMessage,
    required this.memberInitials,
    required this.memberCount,
    required this.unreadCount,
    this.status = ReadingHouseInboxRoomStatus.active,
  });

  final String calendarId;
  final int flowId;
  final String houseTitle;
  final String bookTitle;
  final String latestMessage;
  final List<String> memberInitials;
  final int memberCount;
  final int unreadCount;
  final ReadingHouseInboxRoomStatus status;
}

@immutable
class ReadingHousePendingInviteFixture {
  const ReadingHousePendingInviteFixture({
    required this.calendarId,
    required this.flowId,
    required this.inviterName,
    required this.bookTitle,
  });

  final String calendarId;
  final int flowId;
  final String inviterName;
  final String bookTitle;
}

typedef ReadingHouseInboxRoomOpen =
    void Function(String calendarId, int flowId);

const ReadingHouseInboxRoomFixture kReadingHouseInboxRoomVisualFixture =
    ReadingHouseInboxRoomFixture(
      calendarId: 'odyssey-house-calendar',
      flowId: 41,
      houseTitle: 'The Reading House',
      bookTitle: 'The Odyssey',
      latestMessage: 'Amina: Perfect. I’m finishing the opening section now.',
      memberInitials: <String>['Y', 'AR', 'M'],
      memberCount: 3,
      unreadCount: 2,
    );

const List<ReadingHouseInboxRoomFixture>
kReadingHouseInboxMultipleRoomVisualFixtures = <ReadingHouseInboxRoomFixture>[
  kReadingHouseInboxRoomVisualFixture,
  ReadingHouseInboxRoomFixture(
    calendarId: 'celestine-house-calendar',
    flowId: 82,
    houseTitle: 'The Reading House',
    bookTitle: 'The Celestine Prophecy',
    latestMessage: 'House Chat opens when another reader joins.',
    memberInitials: <String>['Y'],
    memberCount: 1,
    unreadCount: 0,
    status: ReadingHouseInboxRoomStatus.locked,
  ),
  ReadingHouseInboxRoomFixture(
    calendarId: 'beloved-house-calendar',
    flowId: 93,
    houseTitle: 'The Reading House',
    bookTitle: 'Beloved',
    latestMessage: 'This House has ended. The conversation is read-only.',
    memberInitials: <String>['Y', 'N'],
    memberCount: 2,
    unreadCount: 0,
    status: ReadingHouseInboxRoomStatus.ended,
  ),
];

const ReadingHousePendingInviteFixture kReadingHousePendingInviteFixture =
    ReadingHousePendingInviteFixture(
      calendarId: 'pending-house-calendar',
      flowId: 104,
      inviterName: 'Amina',
      bookTitle: 'The Odyssey',
    );

abstract final class ReadingHouseInboxTokens {
  static const Color page = Color(0xFF0E0B07);
  static const Color sheet = Color(0xFF121009);
  static const Color mint = Color(0xFF7FD9BC);
  static const Color mintLow = Color(0xFF3FA98A);
  static const Color gold = Color(0xFFD4AE43);
  static const Color bone = Color(0xFFEEF5F1);
  static const Color silver = Color(0xFF9EAAA4);
  static const Color low = Color(0xFF65776F);
  static const Color separator = Color(0xFF242017);
}

/// Dedicated typed Inbox source for Reading House rooms.
///
/// It deliberately accepts canonical House identity as calendar + flow and
/// has no dependency on the DM conversation model.
class ReadingHouseInboxRoomSection extends StatelessWidget {
  const ReadingHouseInboxRoomSection({
    super.key,
    required this.rooms,
    this.status = ReadingHouseInboxSectionStatus.loaded,
    this.onOpenRoom,
    this.onRetry,
  });

  final List<ReadingHouseInboxRoomFixture> rooms;
  final ReadingHouseInboxSectionStatus status;
  final ReadingHouseInboxRoomOpen? onOpenRoom;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (status == ReadingHouseInboxSectionStatus.loading) {
      return const _SectionNotice(
        key: ValueKey<String>('reading-house-inbox-loading'),
        label: 'Loading Reading Houses…',
        loading: true,
      );
    }
    if (status == ReadingHouseInboxSectionStatus.error) {
      return _SectionNotice(
        key: const ValueKey<String>('reading-house-inbox-error'),
        label: 'Reading Houses could not load.',
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }
    if (rooms.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey<String>('reading-house-inbox-room-section'),
      children: <Widget>[
        for (final room in rooms)
          ReadingHouseInboxRoomRow(
            room: room,
            onTap: onOpenRoom == null
                ? null
                : () => onOpenRoom!(room.calendarId, room.flowId),
          ),
      ],
    );
  }
}

class ReadingHouseInboxRoomRow extends StatelessWidget {
  const ReadingHouseInboxRoomRow({super.key, required this.room, this.onTap});

  final ReadingHouseInboxRoomFixture room;
  final VoidCallback? onTap;

  String get _preview => switch (room.status) {
    ReadingHouseInboxRoomStatus.locked =>
      'House Chat opens when another reader joins.',
    ReadingHouseInboxRoomStatus.empty => 'No chat messages yet.',
    ReadingHouseInboxRoomStatus.ended =>
      'This House has ended · conversation is read-only.',
    ReadingHouseInboxRoomStatus.active => room.latestMessage,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>(
          'reading-house-inbox-room-${room.calendarId}-${room.flowId}',
        ),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xDB08120E),
                Color(0x940B1410),
                Color(0x00120F09),
              ],
            ),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: ReadingHouseInboxTokens.mint.withValues(alpha: 0.06),
              ),
            ),
          ),
          foregroundDecoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.94, -1),
              radius: 1.3,
              colors: <Color>[Color(0x173FA98A), Color(0x003FA98A)],
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.28, -0.44),
                    colors: <Color>[
                      Color(0x2E7FD9BC),
                      Color(0xA617362E),
                      Color(0xFF0A1511),
                    ],
                    stops: <double>[0, 0.62, 1],
                  ),
                  border: Border.all(
                    color: ReadingHouseInboxTokens.mint.withValues(alpha: 0.28),
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x47000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  '𓉐',
                  style: TextStyle(
                    color: ReadingHouseInboxTokens.mint,
                    fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            room.houseTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ReadingHouseInboxTokens.bone,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1.08,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (room.status == ReadingHouseInboxRoomStatus.ended)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.lock_outline,
                              size: 13,
                              color: ReadingHouseInboxTokens.low,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ReadingHouseInboxTokens.silver,
                        fontFamily: MaatFlowListTokens.fontFamily,
                        fontSize: 16,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        _MiniAvatars(initials: room.memberInitials),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${room.bookTitle} · ${room.memberCount} ${room.memberCount == 1 ? 'reader' : 'readers'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ReadingHouseInboxTokens.low,
                              fontFamily: 'GentiumPlus',
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 48,
                height: 66,
                child: room.unreadCount > 0
                    ? Container(
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF254E40),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${room.unreadCount}',
                          style: const TextStyle(
                            color: Color(0xFFD8EEE6),
                            fontFamily: 'GentiumPlus',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF625E57),
                        size: 26,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReadingHousePendingInviteCard extends StatelessWidget {
  const ReadingHousePendingInviteCard({
    super.key,
    required this.invite,
    this.onAccept,
    this.onDecline,
  });

  final ReadingHousePendingInviteFixture invite;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-pending-invite'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0C08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: ReadingHouseInboxTokens.gold.withValues(alpha: 0.13),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ReadingHouseInboxTokens.gold.withValues(alpha: 0.10),
              border: Border.all(
                color: ReadingHouseInboxTokens.gold.withValues(alpha: 0.24),
              ),
            ),
            child: const Text(
              '𓉐',
              style: TextStyle(
                color: Color(0xFFDFB535),
                fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'The Reading House',
                  style: TextStyle(
                    color: Color(0xFFF3EEE2),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: '${invite.inviterName} invited you to read ',
                    children: <InlineSpan>[
                      TextSpan(
                        text: invite.bookTitle,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Color(0xFF8F8A82),
                    fontFamily: 'GentiumPlus',
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '3 starter sittings · invited house',
                  style: TextStyle(
                    color: Color(0xFF6F746F),
                    fontFamily: 'GentiumPlus',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: <Widget>[
                    TextButton(
                      key: const ValueKey<String>(
                        'reading-house-invite-accept',
                      ),
                      onPressed: onAccept,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8AD9BD),
                        disabledForegroundColor: const Color(0xFF8AD9BD),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Accept'),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      key: const ValueKey<String>(
                        'reading-house-invite-decline',
                      ),
                      onPressed: onDecline,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B7A70),
                        disabledForegroundColor: const Color(0xFF8B7A70),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReadingHouseInboxVisualFixturePage extends StatelessWidget {
  const ReadingHouseInboxVisualFixturePage({
    super.key,
    this.rooms = const <ReadingHouseInboxRoomFixture>[
      kReadingHouseInboxRoomVisualFixture,
    ],
    this.sectionStatus = ReadingHouseInboxSectionStatus.loaded,
    this.showPendingInvite = false,
  });

  final List<ReadingHouseInboxRoomFixture> rooms;
  final ReadingHouseInboxSectionStatus sectionStatus;
  final bool showPendingInvite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReadingHouseInboxTokens.page,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            ListView(
              key: const ValueKey<String>('reading-house-inbox-fixture-scroll'),
              padding: const EdgeInsets.only(bottom: 32),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Inbox',
                        style: TextStyle(
                          color: Color(0xFFF5E8CB),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '𓂀',
                        style: TextStyle(
                          color: ReadingHouseInboxTokens.gold,
                          fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                          fontSize: 23,
                        ),
                      ),
                    ],
                  ),
                ),
                const _SectionLabel('Activity'),
                const _SummaryRow(
                  glyph: '𓀀',
                  title: 'People',
                  subtitle: 'L. started following you',
                ),
                const _SummaryRow(
                  glyph: '𓂋',
                  title: 'Discussions',
                  subtitle: 'Flow comments and likes',
                ),
                _SummaryRow(
                  key: const ValueKey<String>('reading-house-invites-row'),
                  glyph: '𓉐',
                  title: 'Invites',
                  subtitle: showPendingInvite
                      ? 'The Reading House · waiting on you'
                      : 'No pending invites',
                ),
                ReadingHouseInboxRoomSection(
                  rooms: rooms,
                  status: sectionStatus,
                  onOpenRoom: (_, _) {},
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 26),
                  child: _SectionLabel('Messages'),
                ),
                const _MessageFixtureRow(
                  initial: 'P',
                  title: 'producedbyearth',
                  subtitle: '12-Day Bird Calls in Lea…',
                ),
                const _MessageFixtureRow(
                  initial: 'M',
                  title: 'Monroe/coconut',
                  subtitle: 'yes',
                ),
              ],
            ),
            if (showPendingInvite) const _PendingInviteSheet(),
          ],
        ),
      ),
    );
  }
}

class _PendingInviteSheet extends StatelessWidget {
  const _PendingInviteSheet();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x85000000),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            decoration: const BoxDecoration(
              color: ReadingHouseInboxTokens.sheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0x334F4123))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(
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
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey<String>('reading-house-invites-close'),
                    onPressed: null,
                    icon: const Icon(Icons.close, size: 28),
                    color: const Color(0xFFD8B23C),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
                const Text(
                  'Invites',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF5E8CB),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 25),
                const _SectionLabel('Pending'),
                ReadingHousePendingInviteCard(
                  invite: kReadingHousePendingInviteFixture,
                  onAccept: null,
                  onDecline: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF746F66),
          fontFamily: MaatFlowListTokens.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
  });

  final String glyph;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.45),
                  colors: <Color>[
                    Color(0xFFFFF1B7),
                    Color(0xFFE8BE54),
                    Color(0xFF7A5310),
                  ],
                ),
                border: Border.all(color: const Color(0x59FFEBA1)),
              ),
              child: Text(
                glyph,
                style: const TextStyle(
                  color: Color(0xFF1C1204),
                  fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFF8EA),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF97928B),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontSize: 17,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 28, color: Color(0xFF625E57)),
          ],
        ),
      ),
    );
  }
}

class _MiniAvatars extends StatelessWidget {
  const _MiniAvatars({required this.initials});

  final List<String> initials;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: initials.isEmpty ? 0 : 17 + (initials.length - 1) * 14,
      height: 17,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < initials.length; index++)
            Positioned(
              left: index * 14,
              child: Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF9BE2CA), Color(0xFF3FA98A)],
                  ),
                  border: Border.all(color: const Color(0xFF0D1511)),
                ),
                child: Text(
                  initials[index],
                  style: const TextStyle(
                    color: Color(0xFF07130E),
                    fontFamily: 'GentiumPlus',
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageFixtureRow extends StatelessWidget {
  const _MessageFixtureRow({
    required this.initial,
    required this.title,
    required this.subtitle,
  });

  final String initial;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF352D12),
                border: Border.all(color: const Color(0x383FA98A)),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFFD6AD2E),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 30,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _messageTitleStyle,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _messageSubtitleStyle,
                  ),
                ],
              ),
            ),
            const Text(
              '𓁷',
              style: TextStyle(
                color: Color(0xFFD6AD2E),
                fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionNotice extends StatelessWidget {
  const _SectionNotice({
    super.key,
    required this.label,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: <Widget>[
          if (loading) ...<Widget>[
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 1.4,
                color: ReadingHouseInboxTokens.mint,
              ),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ReadingHouseInboxTokens.silver,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

const TextStyle _messageTitleStyle = TextStyle(
  color: Color(0xFFFFF8EA),
  fontFamily: MaatFlowListTokens.fontFamily,
  fontSize: 22,
  fontWeight: FontWeight.w600,
);

const TextStyle _messageSubtitleStyle = TextStyle(
  color: Color(0xFF97928B),
  fontFamily: MaatFlowListTokens.fontFamily,
  fontSize: 16,
);
