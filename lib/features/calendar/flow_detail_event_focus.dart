import 'package:flutter/material.dart';
import '../../data/user_events_repo.dart';

/// An occurrence identity, never a title/date guess or a permission grant.
@immutable
class FlowDetailEventTarget {
  const FlowDetailEventTarget({this.eventId, this.clientEventId});
  final String? eventId, clientEventId;

  static FlowDetailEventTarget? fromUri(Uri uri) {
    final id = uri.queryParameters['event'];
    final client = uri.queryParameters['occurrence'];
    if ((id == null || id.isEmpty) && (client == null || client.isEmpty)) {
      return null;
    }
    return FlowDetailEventTarget(eventId: id, clientEventId: client);
  }

  bool matches(FlowEventRow event) => clientEventId?.isNotEmpty == true
      ? event.clientEventId == clientEventId
      : eventId?.isNotEmpty == true && event.id == eventId;

  FlowEventRow? resolve(List<FlowEventRow> events) =>
      events.where(matches).firstOrNull;
}

/// The canonical detail owns focus after its repository has resolved the row.
/// This contains only transient navigation state; no event is copied or saved.
class FlowDetailEventFocus extends StatefulWidget {
  const FlowDetailEventFocus({super.key, this.event, required this.child});
  final FlowEventRow? event;
  final Widget child;

  static FlowEventRow? eventOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_EventFocusScope>()
      ?.state
      .widget
      .event;

  @override
  State<FlowDetailEventFocus> createState() => _FlowDetailEventFocusState();
}

class _FlowDetailEventFocusState extends State<FlowDetailEventFocus> {
  bool claimed = false;
  @override
  void didUpdateWidget(covariant FlowDetailEventFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event?.id != widget.event?.id ||
        oldWidget.event?.clientEventId != widget.event?.clientEventId) {
      claimed = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _EventFocusScope(state: this, child: widget.child);
}

class _EventFocusScope extends InheritedWidget {
  const _EventFocusScope({required this.state, required super.child});
  final _FlowDetailEventFocusState state;
  @override
  bool updateShouldNotify(_EventFocusScope oldWidget) => true;
}

/// Reuses each authored event's normal expansion/open action, then reveals it.
class FlowDetailEventAnchor extends StatefulWidget {
  const FlowDetailEventAnchor({
    super.key,
    required this.matches,
    required this.child,
    this.onOpen,
  });
  final bool matches;
  final Widget child;
  final VoidCallback? onOpen;
  @override
  State<FlowDetailEventAnchor> createState() => _FlowDetailEventAnchorState();
}

class _FlowDetailEventAnchorState extends State<FlowDetailEventAnchor> {
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_EventFocusScope>();
    if (widget.matches && scope != null && !scope.state.claimed) {
      scope.state.claimed = true;
      final event = scope.state.widget.event;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !widget.matches || scope.state.widget.event != event) {
          return;
        }
        await Scrollable.ensureVisible(context, alignment: .15);
        if (mounted && widget.matches && scope.state.widget.event == event) {
          widget.onOpen?.call();
        }
      });
    }
    return Semantics(selected: widget.matches, child: widget.child);
  }
}
