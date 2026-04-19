import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';

import '../../data/share_models.dart';

class EventInviteActionRow extends StatelessWidget {
  const EventInviteActionRow({
    super.key,
    required this.currentStatus,
    required this.onSelected,
    this.busy = false,
    this.compact = false,
  });

  final EventInviteResponseStatus currentStatus;
  final ValueChanged<EventInviteResponseStatus> onSelected;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      (
        status: EventInviteResponseStatus.accepted,
        label: 'Yes',
        color: Colors.greenAccent,
      ),
      (
        status: EventInviteResponseStatus.declined,
        label: 'No',
        color: Colors.redAccent,
      ),
      (
        status: EventInviteResponseStatus.maybe,
        label: 'Maybe',
        color: Colors.orangeAccent,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < buttons.length; index++) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == buttons.length - 1 ? 0 : 8,
              ),
              child: _ResponseButton(
                label: buttons[index].label,
                color: buttons[index].color,
                selected: currentStatus == buttons[index].status,
                busy: busy,
                compact: compact,
                onTap: busy ? null : () => onSelected(buttons[index].status),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResponseButton extends StatelessWidget {
  const _ResponseButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.busy,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool busy;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : (compact ? 36.0 : 42.0);

    return SizedBox(
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: withExpandedTouchTargets(
          context,
          OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
            foregroundColor: selected ? Colors.black : color,
            backgroundColor: selected ? color : color.withValues(alpha: 0.08),
            side: BorderSide(
              color: color.withValues(alpha: selected ? 0.7 : 0.24),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
          ),
        ),
        child: busy && selected
            ? SizedBox(
                width: compact ? 14 : 16,
                height: compact ? 14 : 16,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
