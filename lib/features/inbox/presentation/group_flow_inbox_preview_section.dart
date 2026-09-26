import 'package:flutter/material.dart';
import 'package:mobile/data/shared_practice_models.dart';

const Color _gold = Color(0xFFD4AF37);
const Color _ink = Color(0xFFF3EBDD);
const Color _muted = Color(0xFF9E9A94);
const Color _panel = Color(0xFF17120B);
const String _serif = 'CormorantGaramond';

enum _GroupFlowVisibilityPreview { private, public }

enum _GroupFlowRequestAudiencePreview {
  nobody,
  creatorFriends,
  participantFriends,
  anyone,
}

enum GroupFlowInboxSectionStatus { loading, loaded, error }

class GroupFlowInboxSection extends StatelessWidget {
  const GroupFlowInboxSection({
    super.key,
    required this.snapshot,
    required this.status,
    required this.onRespondToRequest,
    required this.onRespondToInvitation,
    required this.onSavePolicy,
    required this.onRespondToQuoteApproval,
    required this.onRequestDecision,
    required this.onOpenRoom,
    required this.onRetry,
  });

  final TogetherInboxSnapshot snapshot;
  final GroupFlowInboxSectionStatus status;
  final Future<void> Function(SharedPracticeJoinRequest request, bool accept)
  onRespondToRequest;
  final Future<void> Function(TogetherInboxInvitation invitation, bool accept)
  onRespondToInvitation;
  final Future<void> Function(
    TogetherPolicyPrompt prompt,
    SharedPracticeRoomVisibility visibility,
    SharedPracticeRequestAudience requestAudience,
  )
  onSavePolicy;
  final Future<void> Function(TogetherQuoteApproval approval, bool accept)
  onRespondToQuoteApproval;
  final Future<void> Function(TogetherRequestDecision decision, bool open)
  onRequestDecision;
  final Future<void> Function(TogetherInboxRoom room) onOpenRoom;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (status == GroupFlowInboxSectionStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: _PreviewPanel(
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
            ),
          ),
        ),
      );
    }
    if (status == GroupFlowInboxSectionStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _PreviewPanel(
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Practice Together requests could not load.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (snapshot.isEmpty) return const SizedBox.shrink();

    final cards = <Widget>[
      for (final room in snapshot.activeRooms)
        _LiveRoomCard(room: room, onOpen: () => onOpenRoom(room)),
      for (final request in snapshot.joinRequests)
        _LiveActionCard(
          key: ValueKey<String>('group-flow-request-${request.id}'),
          initials: _initials(request.requesterLabel),
          headline: '${request.requesterLabel} wants to practice together',
          detail: request.title ?? 'Group flow',
          acceptKey: ValueKey<String>(
            'group-flow-request-accept-${request.id}',
          ),
          declineKey: ValueKey<String>(
            'group-flow-request-decline-${request.id}',
          ),
          onAccept: () => onRespondToRequest(request, true),
          onDecline: () => onRespondToRequest(request, false),
        ),
      for (final invitation in snapshot.invitations)
        _LiveActionCard(
          key: ValueKey<String>('group-flow-invitation-${invitation.roomId}'),
          initials: _initials(invitation.hostLabel),
          headline: '${invitation.hostLabel} invited you to practice together',
          detail: invitation.title,
          acceptKey: ValueKey<String>(
            'group-flow-invitation-accept-${invitation.roomId}',
          ),
          declineKey: ValueKey<String>(
            'group-flow-invitation-decline-${invitation.roomId}',
          ),
          onAccept: () => onRespondToInvitation(invitation, true),
          onDecline: () => onRespondToInvitation(invitation, false),
        ),
      for (final prompt in snapshot.policyPrompts)
        _LivePolicyCard(
          key: ValueKey<String>('group-flow-policy-${prompt.roomId}'),
          prompt: prompt,
          onSave: (visibility, audience) =>
              onSavePolicy(prompt, visibility, audience),
        ),
      for (final approval in snapshot.quoteApprovals)
        _LiveActionCard(
          key: ValueKey<String>('group-flow-quote-approval-${approval.id}'),
          initials: _initials(approval.submitterLabel),
          headline: '${approval.submitterLabel} wants to post your chat quote',
          detail: '${approval.flowTitle} · “${approval.bodyText}”',
          acceptKey: ValueKey<String>(
            'group-flow-quote-approval-accept-${approval.id}',
          ),
          declineKey: ValueKey<String>(
            'group-flow-quote-approval-decline-${approval.id}',
          ),
          onAccept: () => onRespondToQuoteApproval(approval, true),
          onDecline: () => onRespondToQuoteApproval(approval, false),
        ),
      for (final decision in snapshot.requestDecisions)
        _LiveDecisionCard(
          key: ValueKey<String>('group-flow-decision-${decision.id}'),
          decision: decision,
          onOpen: () => onRequestDecision(decision, true),
          onDismiss: () => onRequestDecision(decision, false),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < cards.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 12),
            cards[index],
          ],
        ],
      ),
    );
  }
}

class _LiveRoomCard extends StatelessWidget {
  const _LiveRoomCard({required this.room, required this.onOpen});

  final TogetherInboxRoom room;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.34)),
            ),
            child: const Icon(Icons.groups_outlined, color: _gold, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontFamily: _serif,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${room.memberCount} practicing · ${room.hostLabel}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: ValueKey<String>('group-flow-open-${room.roomId}'),
            onPressed: () => onOpen(),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _LiveDecisionCard extends StatefulWidget {
  const _LiveDecisionCard({
    super.key,
    required this.decision,
    required this.onOpen,
    required this.onDismiss,
  });

  final TogetherRequestDecision decision;
  final Future<void> Function() onOpen;
  final Future<void> Function() onDismiss;

  @override
  State<_LiveDecisionCard> createState() => _LiveDecisionCardState();
}

class _LiveDecisionCardState extends State<_LiveDecisionCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _LiveLabel('PRACTICE TOGETHER'),
          const SizedBox(height: 12),
          Text(
            decision.approved
                ? '${decision.hostLabel} accepted your request'
                : '${decision.hostLabel} closed your request',
            style: const TextStyle(
              color: _ink,
              fontFamily: _serif,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            decision.title,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              if (decision.approved) ...<Widget>[
                Expanded(
                  child: FilledButton(
                    key: ValueKey<String>(
                      'group-flow-decision-open-${decision.id}',
                    ),
                    onPressed: _busy ? null : () => _run(widget.onOpen),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF1C1204),
                    ),
                    child: const Text('Open flow'),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: OutlinedButton(
                  key: ValueKey<String>(
                    'group-flow-decision-dismiss-${decision.id}',
                  ),
                  onPressed: _busy ? null : () => _run(widget.onDismiss),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: BorderSide(color: _gold.withValues(alpha: 0.36)),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveActionCard extends StatefulWidget {
  const _LiveActionCard({
    super.key,
    required this.initials,
    required this.headline,
    required this.detail,
    required this.acceptKey,
    required this.declineKey,
    required this.onAccept,
    required this.onDecline,
  });

  final String initials;
  final String headline;
  final String detail;
  final Key acceptKey;
  final Key declineKey;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<_LiveActionCard> createState() => _LiveActionCardState();
}

class _LiveActionCardState extends State<_LiveActionCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _LiveLabel('PRACTICE TOGETHER'),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InitialAvatar(initials: widget.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.headline,
                      style: const TextStyle(
                        color: _ink,
                        fontFamily: _serif,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.detail,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  key: widget.acceptKey,
                  onPressed: _busy ? null : () => _run(widget.onAccept),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: const Color(0xFF1C1204),
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(
                  key: widget.declineKey,
                  onPressed: _busy ? null : () => _run(widget.onDecline),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: BorderSide(color: _gold.withValues(alpha: 0.36)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePolicyCard extends StatefulWidget {
  const _LivePolicyCard({
    super.key,
    required this.prompt,
    required this.onSave,
  });

  final TogetherPolicyPrompt prompt;
  final Future<void> Function(
    SharedPracticeRoomVisibility,
    SharedPracticeRequestAudience,
  )
  onSave;

  @override
  State<_LivePolicyCard> createState() => _LivePolicyCardState();
}

class _LivePolicyCardState extends State<_LivePolicyCard> {
  late SharedPracticeRoomVisibility _visibility = widget.prompt.visibility;
  late SharedPracticeRequestAudience _audience = widget.prompt.requestAudience;
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(_visibility, _audience);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _LiveLabel('GROUP FLOW SETTINGS'),
          const SizedBox(height: 12),
          Text(
            '${widget.prompt.joinedLabel} joined your flow',
            style: const TextStyle(
              color: _ink,
              fontFamily: _serif,
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.prompt.title} now has ${widget.prompt.memberCount} people.',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('DISPLAY IN COMMONS'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final value in <SharedPracticeRoomVisibility>[
                SharedPracticeRoomVisibility.private,
                SharedPracticeRoomVisibility.public,
              ])
                _ChoicePill(
                  label: value.label,
                  selected: _visibility == value,
                  onTap: () => setState(() => _visibility = value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('WHO CAN REQUEST TO JOIN'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final value in SharedPracticeRequestAudience.values)
                _ChoicePill(
                  label: value.label,
                  selected: _audience == value,
                  onTap: () => setState(() => _audience = value),
                ),
            ],
          ),
          if (_visibility == SharedPracticeRoomVisibility.public &&
              _audience == SharedPracticeRequestAudience.nobody) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              'Visible in Commons without a request-to-join button.',
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF1C1204),
            ),
            child: const Text('Save group settings'),
          ),
        ],
      ),
    );
  }
}

class _LiveLabel extends StatelessWidget {
  const _LiveLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _gold,
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

String _initials(String label) {
  final words = label
      .replaceFirst('@', '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  final initials = words.map((word) => word.characters.first).join();
  return initials.isEmpty ? 'G' : initials.toUpperCase();
}

class GroupFlowInboxPreviewSection extends StatefulWidget {
  const GroupFlowInboxPreviewSection({super.key});

  @override
  State<GroupFlowInboxPreviewSection> createState() =>
      _GroupFlowInboxPreviewSectionState();
}

class _GroupFlowInboxPreviewSectionState
    extends State<GroupFlowInboxPreviewSection> {
  bool _accepted = false;
  bool _declined = false;
  _GroupFlowVisibilityPreview _visibility = _GroupFlowVisibilityPreview.private;
  _GroupFlowRequestAudiencePreview _audience =
      _GroupFlowRequestAudiencePreview.creatorFriends;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _declined
            ? _DeclinedPreviewCard(
                key: const ValueKey<String>(
                  'group-flow-inbox-request-declined',
                ),
                onUndo: () => setState(() => _declined = false),
              )
            : _accepted
            ? _SecondMemberPolicyPreview(
                key: const ValueKey<String>('group-flow-second-member-policy'),
                visibility: _visibility,
                audience: _audience,
                onVisibilityChanged: (value) =>
                    setState(() => _visibility = value),
                onAudienceChanged: (value) => setState(() => _audience = value),
                onSave: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings saved locally · UI preview'),
                    ),
                  );
                },
              )
            : _JoinRequestPreviewCard(
                key: const ValueKey<String>('group-flow-inbox-request'),
                onAccept: () => setState(() => _accepted = true),
                onDecline: () => setState(() => _declined = true),
              ),
      ),
    );
  }
}

class _JoinRequestPreviewCard extends StatelessWidget {
  const _JoinRequestPreviewCard({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PreviewLabel(),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _InitialAvatar(initials: 'AM'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text(
                      'Amina wants to practice together',
                      style: TextStyle(
                        color: _ink,
                        fontFamily: _serif,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Dawn Strength Practice · requested now',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>(
                    'group-flow-inbox-request-accept',
                  ),
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: const Color(0xFF1C1204),
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>(
                    'group-flow-inbox-request-decline',
                  ),
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: BorderSide(color: _gold.withValues(alpha: 0.36)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecondMemberPolicyPreview extends StatelessWidget {
  const _SecondMemberPolicyPreview({
    super.key,
    required this.visibility,
    required this.audience,
    required this.onVisibilityChanged,
    required this.onAudienceChanged,
    required this.onSave,
  });

  final _GroupFlowVisibilityPreview visibility;
  final _GroupFlowRequestAudiencePreview audience;
  final ValueChanged<_GroupFlowVisibilityPreview> onVisibilityChanged;
  final ValueChanged<_GroupFlowRequestAudiencePreview> onAudienceChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PreviewLabel(),
          const SizedBox(height: 12),
          Row(
            children: const <Widget>[
              _InitialAvatar(initials: 'AM'),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Amina joined your flow',
                      style: TextStyle(
                        color: _ink,
                        fontFamily: _serif,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Dawn Strength Practice now has 2 people.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _FieldLabel('DISPLAY IN COMMONS'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _ChoicePill(
                key: const ValueKey<String>('group-flow-visibility-private'),
                label: 'Private',
                selected: visibility == _GroupFlowVisibilityPreview.private,
                onTap: () =>
                    onVisibilityChanged(_GroupFlowVisibilityPreview.private),
              ),
              _ChoicePill(
                key: const ValueKey<String>('group-flow-visibility-public'),
                label: 'Public',
                selected: visibility == _GroupFlowVisibilityPreview.public,
                onTap: () =>
                    onVisibilityChanged(_GroupFlowVisibilityPreview.public),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('WHO CAN REQUEST TO JOIN'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final option in _GroupFlowRequestAudiencePreview.values)
                _ChoicePill(
                  key: ValueKey<String>(
                    'group-flow-request-audience-${option.name}',
                  ),
                  label: _audienceLabel(option),
                  selected: audience == option,
                  onTap: () => onAudienceChanged(option),
                ),
            ],
          ),
          if (visibility == _GroupFlowVisibilityPreview.public &&
              audience == _GroupFlowRequestAudiencePreview.nobody) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              'Visible in Commons without a request-to-join button.',
              key: ValueKey<String>('group-flow-public-closed-note'),
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey<String>('group-flow-policy-save'),
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF1C1204),
            ),
            child: const Text('Save preview settings'),
          ),
        ],
      ),
    );
  }
}

class _DeclinedPreviewCard extends StatelessWidget {
  const _DeclinedPreviewCard({super.key, required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'Request removed locally · UI preview',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          TextButton(
            key: const ValueKey<String>('group-flow-request-undo'),
            onPressed: onUndo,
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.28)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _gold.withValues(alpha: 0.35)),
          ),
          child: const Text(
            'UI PREVIEW',
            style: TextStyle(
              color: _gold,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'No live request will be changed',
            style: TextStyle(color: _muted, fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _gold.withValues(alpha: 0.13),
        border: Border.all(color: _gold.withValues(alpha: 0.42)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: _gold,
          fontFamily: _serif,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _muted,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _gold.withValues(alpha: 0.22),
      backgroundColor: Colors.black.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected
            ? _gold.withValues(alpha: 0.66)
            : Colors.white.withValues(alpha: 0.10),
      ),
      labelStyle: TextStyle(
        color: selected ? _gold : _ink.withValues(alpha: 0.72),
        fontSize: 11,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _audienceLabel(_GroupFlowRequestAudiencePreview value) {
  return switch (value) {
    _GroupFlowRequestAudiencePreview.nobody => 'No one',
    _GroupFlowRequestAudiencePreview.creatorFriends => 'Creator’s friends',
    _GroupFlowRequestAudiencePreview.participantFriends =>
      'Participants’ friends',
    _GroupFlowRequestAudiencePreview.anyone => 'Anyone',
  };
}
