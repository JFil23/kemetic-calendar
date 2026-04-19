import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../inbox/conversation_user.dart';
import '../inbox/inbox_conversation_page.dart';
import 'event_invite_action_row.dart';

class EventInviteDetailsPage extends StatefulWidget {
  const EventInviteDetailsPage({super.key, required this.share});

  final InboxShareItem share;

  @override
  State<EventInviteDetailsPage> createState() => _EventInviteDetailsPageState();
}

class _EventInviteDetailsPageState extends State<EventInviteDetailsPage> {
  late final ShareRepo _repo = ShareRepo(Supabase.instance.client);
  late EventInviteResponseStatus _responseStatus = widget.share.responseStatus;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _respond(EventInviteResponseStatus nextStatus) async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _responseStatus = nextStatus;
    });

    final ok = await _repo.respondToEventInvite(
      shareId: widget.share.shareId,
      responseStatus: nextStatus,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (!ok) {
        _responseStatus = widget.share.responseStatus;
      }
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your RSVP. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Response saved: ${nextStatus.label}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openConversation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InboxConversationPage(
          otherUserId: widget.share.senderId,
          otherProfile: ConversationUser(
            id: widget.share.senderId,
            displayName: widget.share.senderName,
            handle: widget.share.senderHandle,
            avatarUrl: widget.share.senderAvatar,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.share.eventPayload;
    final title = payload?.title ?? widget.share.title;
    final senderName = widget.share.senderName?.trim().isNotEmpty == true
        ? widget.share.senderName!.trim()
        : (widget.share.senderHandle?.trim().isNotEmpty == true
              ? '@${widget.share.senderHandle!.trim()}'
              : 'Someone');
    final whenText = _formatWhen(payload);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Event Invite',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'From $senderName',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.74),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (whenText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _MetaRow(icon: Icons.schedule, text: whenText),
                  ],
                  if ((payload?.location?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 10),
                    _MetaRow(
                      icon: Icons.location_on_outlined,
                      text: payload!.location!,
                    ),
                  ],
                  if ((payload?.detail?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 14),
                    Text(
                      payload!.detail!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        height: 1.4,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your response',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            EventInviteActionRow(
              currentStatus: _responseStatus,
              busy: _submitting,
              onSelected: _respond,
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: _openConversation,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Open conversation'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFC145),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWhen(EventSharePayload? payload) {
    final startsAt = payload?.startsAt ?? widget.share.eventDate;
    if (startsAt == null) return '';

    final local = startsAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final year = local.year.toString();
    if (payload?.allDay ?? false) {
      return '$month/$day/$year • All day';
    }

    final minute = local.minute.toString().padLeft(2, '0');
    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    var text = '$month/$day/$year • $hour12:$minute $period';

    final endsAt = payload?.endsAt?.toLocal();
    if (endsAt != null) {
      final endMinute = endsAt.minute.toString().padLeft(2, '0');
      final endHour24 = endsAt.hour;
      final endPeriod = endHour24 >= 12 ? 'PM' : 'AM';
      final endHour12 = endHour24 == 0
          ? 12
          : (endHour24 > 12 ? endHour24 - 12 : endHour24);
      text = '$text - $endHour12:$endMinute $endPeriod';
    }

    return text;
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
