import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../utils/detail_sanitizer.dart';
import '../calendar/calendar_page.dart';
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
  late InboxShareItem _share = widget.share;
  late EventInviteResponseStatus _responseStatus = widget.share.responseStatus;
  StreamSubscription<List<InboxShareItem>>? _shareSubscription;
  bool _submitting = false;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;
  bool get _isRecipient => _share.recipientId == _currentUserId;

  @override
  void initState() {
    super.initState();
    _shareSubscription = _repo.watchInbox().listen(_syncShareFromInbox);
    unawaited(_markViewedIfRecipient());
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _syncShareFromInbox(List<InboxShareItem> items) {
    for (final item in items) {
      if (item.shareId != _share.shareId) continue;
      if (!mounted) return;
      setState(() {
        _share = item;
        if (!_submitting) {
          _responseStatus = item.responseStatus;
        }
      });
      return;
    }
  }

  Future<void> _markViewedIfRecipient() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null ||
        _share.recipientId != currentUserId ||
        _share.viewedAt != null) {
      return;
    }
    await _repo.markViewed(_share.shareId, isFlow: false);
  }

  Future<void> _respond(EventInviteResponseStatus nextStatus) async {
    if (_submitting || !_isRecipient) return;

    setState(() {
      _submitting = true;
      _responseStatus = nextStatus;
    });

    final ok = await _repo.respondToEventInvite(
      shareId: _share.shareId,
      responseStatus: nextStatus,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (!ok) {
        _responseStatus = _share.responseStatus;
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

    unawaited(CalendarPage.globalKey.currentState?.reloadFromOutside());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Response saved: ${nextStatus.label}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openConversation() {
    final openingSentInvite = _currentUserId == _share.senderId;
    final otherUserId = openingSentInvite
        ? _share.recipientId
        : _share.senderId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InboxConversationPage(
          otherUserId: otherUserId,
          otherProfile: ConversationUser(
            id: otherUserId,
            displayName: openingSentInvite
                ? _share.recipientDisplayName
                : _share.senderName,
            handle: openingSentInvite
                ? _share.recipientHandle
                : _share.senderHandle,
            avatarUrl: openingSentInvite
                ? _share.recipientAvatarUrl
                : _share.senderAvatar,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _share.eventPayload;
    final title = payload?.title ?? _share.title;
    final senderName = _share.senderName?.trim().isNotEmpty == true
        ? _share.senderName!.trim()
        : (_share.senderHandle?.trim().isNotEmpty == true
              ? '@${_share.senderHandle!.trim()}'
              : 'Someone');
    final whenText = _formatWhen(payload);
    final detail = cleanFlowDetail(payload?.detail);

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'From $senderName',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
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
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      detail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
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
              _isRecipient ? 'Your response' : 'Invite response',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (_isRecipient)
              EventInviteActionRow(
                currentStatus: _responseStatus,
                busy: _submitting,
                onSelected: _respond,
              )
            else
              _ResponseSummary(status: _responseStatus),
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
    final startsAt = payload?.startsAt ?? _share.eventDate;
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

class _ResponseSummary extends StatelessWidget {
  const _ResponseSummary({required this.status});

  final EventInviteResponseStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      EventInviteResponseStatus.accepted => ('Yes', Colors.greenAccent),
      EventInviteResponseStatus.declined => ('No', Colors.redAccent),
      EventInviteResponseStatus.maybe => ('Maybe', Colors.orangeAccent),
      EventInviteResponseStatus.noResponse => (
        'Awaiting response',
        Colors.white70,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: status.isPending ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: status.isPending ? 0.18 : 0.3),
        ),
      ),
      child: Text(
        status.isPending ? label : 'Current response: $label',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
