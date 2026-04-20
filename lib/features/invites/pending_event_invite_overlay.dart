import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../calendar/calendar_page.dart';
import 'event_invite_action_row.dart';
import 'event_invite_details_page.dart';

class PendingEventInviteOverlay extends StatefulWidget {
  const PendingEventInviteOverlay({super.key});

  @override
  State<PendingEventInviteOverlay> createState() =>
      _PendingEventInviteOverlayState();
}

class _PendingEventInviteOverlayState extends State<PendingEventInviteOverlay> {
  late final ShareRepo _repo = ShareRepo(Supabase.instance.client);
  String? _respondingShareId;
  final Map<String, EventInviteResponseStatus> _optimisticStatuses = {};

  Future<void> _respond(
    InboxShareItem invite,
    EventInviteResponseStatus nextStatus,
  ) async {
    if (_respondingShareId != null) return;
    setState(() {
      _respondingShareId = invite.shareId;
      _optimisticStatuses[invite.shareId] = nextStatus;
    });
    final ok = await _repo.respondToEventInvite(
      shareId: invite.shareId,
      responseStatus: nextStatus,
    );
    if (!mounted) return;
    setState(() {
      _respondingShareId = null;
      if (!ok) {
        _optimisticStatuses.remove(invite.shareId);
      }
    });
    if (ok) {
      unawaited(CalendarPage.globalKey.currentState?.reloadFromOutside());
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your RSVP. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openInvite(InboxShareItem invite) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventInviteDetailsPage(share: invite)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InboxShareItem>>(
      stream: _repo.watchPendingEventInvites(),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? const <InboxShareItem>[];
        if (invites.isEmpty) return const SizedBox.shrink();

        final invite = invites.first;
        final payload = invite.eventPayload;
        final displayStatus =
            _optimisticStatuses[invite.shareId] ?? invite.responseStatus;
        final media = MediaQuery.of(context);
        final moreCount = invites.length - 1;
        final sender = invite.senderName?.trim().isNotEmpty == true
            ? invite.senderName!.trim()
            : (invite.senderHandle?.trim().isNotEmpty == true
                  ? '@${invite.senderHandle!.trim()}'
                  : 'Someone');

        return Positioned(
          left: 16,
          right: 16,
          bottom: 78 + media.padding.bottom,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openInvite(invite),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available_outlined,
                          color: Color(0xFFFFC145),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            moreCount > 0
                                ? 'Event Invite • ${moreCount + 1} waiting'
                                : 'Event Invite',
                            style: const TextStyle(
                              color: Color(0xFFFFC145),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payload?.title ?? invite.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(sender, payload, invite),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    EventInviteActionRow(
                      currentStatus: displayStatus,
                      busy: _respondingShareId == invite.shareId,
                      compact: true,
                      onSelected: (status) => _respond(invite, status),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildSubtitle(
    String sender,
    EventSharePayload? payload,
    InboxShareItem invite,
  ) {
    final when = payload?.startsAt ?? invite.eventDate;
    if (when == null) {
      return 'From $sender';
    }
    final local = when.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final timeText = payload?.allDay ?? false
        ? '$month/$day • All day'
        : '$month/$day • $hour12:$minute $period';
    return 'From $sender • $timeText';
  }
}
